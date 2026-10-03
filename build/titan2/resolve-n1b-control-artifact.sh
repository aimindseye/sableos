#!/usr/bin/env bash
set -euo pipefail
umask 077

EXPECTED_SHA256="bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"
EXPECTED_BYTES=3180666880
PREFERRED=""
OUTPUT_ROOT="${SABLE_N1B_CONTROL_RECOVERY_ROOT:-/srv/data/sable-build/artifacts/titan2/n1b-control-recovered}"
REGISTRY_ROOT="${SABLE_RELEASE_REGISTRY_ROOT:-/srv/data/sable-build/release-registry}"

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/resolve-n1b-control-artifact.sh \
    [--preferred /old/or/current/system.img] \
    [--output-root /absolute/path]

Offline only. Searches retained local Sable build/evidence/artifact storage and
may recover IMAGES/system.img from an N1B target-files archive. It accepts an
artifact only if SHA-256 and byte size exactly match the historical N1B ledger.
USAGE
}

log() { printf '%s\n' "$*" >&2; }
fail() { log "N1B_CONTROL_ARTIFACT_RESOLVE=FAIL reason=$*"; exit 1; }
sha() { sha256sum "$1" | awk '{print $1}'; }

while (($#)); do
  case "$1" in
    --preferred) PREFERRED="${2:-}"; shift 2 ;;
    --output-root) OUTPUT_ROOT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 64 ;;
  esac
done

[[ "$OUTPUT_ROOT" = /* ]] || fail "output-root must be absolute"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum unavailable"

validate_image() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  [[ "$(stat -c '%s' "$path")" == "$EXPECTED_BYTES" ]] || return 1
  [[ "$(sha "$path")" == "$EXPECTED_SHA256" ]] || return 1
}

if [[ -n "$PREFERRED" ]] && validate_image "$PREFERRED"; then
  log "N1B_CONTROL_ARTIFACT_SOURCE=PREFERRED_EXACT"
  printf '%s\n' "$(readlink -f "$PREFERRED")"
  exit 0
fi

if [[ -d "$REGISTRY_ROOT/titan2/N1B" ]]; then
  registry_hit="$(python3 - "$REGISTRY_ROOT/titan2/N1B" "$EXPECTED_SHA256" "$EXPECTED_BYTES" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
expected_sha = sys.argv[2]
expected_bytes = int(sys.argv[3])
hits = []
for manifest in sorted(root.glob("*.json")):
    try:
        doc = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception:
        continue
    for item in (doc.get("artifacts") or {}).values():
        if not isinstance(item, dict):
            continue
        if item.get("sha256") != expected_sha:
            continue
        p = pathlib.Path(str(item.get("path", "")))
        if p.is_file() and p.stat().st_size == expected_bytes:
            hits.append(str(p.resolve()))
hits = sorted(set(hits))
if len(hits) == 1:
    print(hits[0])
PY
)"
  if [[ -n "$registry_hit" ]] && validate_image "$registry_hit"; then
    log "N1B_CONTROL_ARTIFACT_SOURCE=RELEASE_REGISTRY"
    printf '%s\n' "$registry_hit"
    exit 0
  fi
fi

roots=()
for root in   /srv/data/sable-build/workspaces   /srv/data/sable-build/evidence/titan2   /srv/data/sable-build/titan2/artifacts   /srv/data/sable-build/artifacts/titan2
do
  [[ -d "$root" ]] && roots+=("$root")
done
[[ "${#roots[@]}" -gt 0 ]] || fail "no local Sable artifact roots exist"

while IFS= read -r candidate; do
  [[ -f "$candidate" ]] || continue
  if validate_image "$candidate"; then
    log "N1B_CONTROL_ARTIFACT_SOURCE=LOCAL_EXACT_IMAGE"
    printf '%s\n' "$(readlink -f "$candidate")"
    exit 0
  fi
done < <(
  find "${roots[@]}"     -type f -size "${EXPECTED_BYTES}c"     \( -name '*.img' -o -name system \)     -print 2>/dev/null | LC_ALL=C sort -u
)

command -v unzip >/dev/null 2>&1 || fail "unzip unavailable and no exact standalone image found"

mkdir -p "$OUTPUT_ROOT"
OUTPUT="$OUTPUT_ROOT/system-$EXPECTED_SHA256.img"
SOURCE_RECORD="$OUTPUT_ROOT/system-$EXPECTED_SHA256.source.env"

if validate_image "$OUTPUT"; then
  log "N1B_CONTROL_ARTIFACT_SOURCE=PREVIOUSLY_RECOVERED_EXACT"
  printf '%s\n' "$OUTPUT"
  exit 0
fi
[[ ! -e "$OUTPUT" ]] || fail "existing recovered output has wrong identity path=$OUTPUT"

while IFS= read -r tf; do
  [[ -f "$tf" ]] || continue
  unzip -Z1 "$tf" 2>/dev/null | grep -Fxq 'IMAGES/system.img' || continue

  member_bytes="$(unzip -l "$tf" IMAGES/system.img 2>/dev/null |
    awk '$NF=="IMAGES/system.img" {print $1; exit}')"
  [[ "$member_bytes" == "$EXPECTED_BYTES" ]] || continue

  set +e
  member_sha="$(unzip -p "$tf" IMAGES/system.img 2>/dev/null | sha256sum | awk '{print $1}')"
  pipe_rc=$?
  set -e
  [[ "$pipe_rc" -eq 0 && "$member_sha" == "$EXPECTED_SHA256" ]] || continue

  tmp="$OUTPUT.tmp.$$"
  rm -f "$tmp"
  log "N1B_CONTROL_ARTIFACT_RECOVERY=EXTRACTING source=$tf"
  unzip -p "$tf" IMAGES/system.img > "$tmp" || {
    rm -f "$tmp"
    continue
  }
  if ! validate_image "$tmp"; then
    rm -f "$tmp"
    continue
  fi
  mv "$tmp" "$OUTPUT"
  chmod 0444 "$OUTPUT"
  source_sha="$(sha "$tf")"
  cat > "$SOURCE_RECORD" <<EOF
N1B_CONTROL_ARTIFACT_RECOVERY=PASS
RECOVERED_SYSTEM_IMG=$OUTPUT
SYSTEM_SHA256=$EXPECTED_SHA256
SYSTEM_BYTES=$EXPECTED_BYTES
SOURCE_TARGET_FILES=$tf
SOURCE_TARGET_FILES_SHA256=$source_sha
SOURCE_MEMBER=IMAGES/system.img
EOF
  chmod 0444 "$SOURCE_RECORD"
  log "N1B_CONTROL_ARTIFACT_SOURCE=TARGET_FILES_RECOVERY"
  log "N1B_CONTROL_ARTIFACT_SOURCE_TARGET_FILES=$tf"
  log "N1B_CONTROL_ARTIFACT_SOURCE_TARGET_FILES_SHA256=$source_sha"
  printf '%s\n' "$OUTPUT"
  exit 0
done < <(
  find "${roots[@]}"     -type f \( -iname '*target_files*.zip' -o -iname '*target-files*.zip' \)     -path '*n1b*' -print 2>/dev/null | LC_ALL=C sort -u
)

fail "exact historical N1B system image not found in registry, retained images, or N1B target-files archives"
