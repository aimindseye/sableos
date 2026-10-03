#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="${SABLE_BUILD_ROOT:-/srv/data/sable-build}"
EVID="$ROOT/evidence/titan2"
EXPECTED_SYSTEM_SHA="bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"
EXPECTED_SYSTEM_BYTES=3180666880

fail() {
  echo "N1B_RETAINED_ARTIFACT_FORENSIC_AUDIT=FAIL reason=$*" >&2
  exit 1
}

show_file() {
  local f="$1"
  echo
  echo "===== FILE: $f ====="
  if [[ -f "$f" ]]; then
    sed -n '1,220p' "$f"
  else
    echo "MISSING"
  fi
}

[[ -d "$ROOT" ]] || fail "build_root_missing path=$ROOT"
[[ -d "$EVID" ]] || fail "titan2_evidence_missing path=$EVID"
command -v sha256sum >/dev/null 2>&1 || fail sha256sum_missing
command -v find >/dev/null 2>&1 || fail find_missing
command -v python3 >/dev/null 2>&1 || fail python3_missing

echo "===== N1B RETAINED-ARTIFACT FORENSIC AUDIT ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "NETWORK_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "ARTIFACT_MUTATION_AUTHORIZED=NO"
echo "EXPECTED_SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA"
echo "EXPECTED_SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES"

mapfile -t ENV_FILES < <(
  find "$EVID/n1b-phase-08-image-build-candidate"     -type f -name n1b-phase-08-image-build.env -print 2>/dev/null |
    LC_ALL=C sort
)
echo "PHASE08_ENV_COUNT=${#ENV_FILES[@]}"
[[ "${#ENV_FILES[@]}" -gt 0 ]] || fail phase08_build_env_missing

TMP_IDS="$(mktemp)"
trap 'rm -f "$TMP_IDS"' EXIT

for f in "${ENV_FILES[@]}"; do
  show_file "$f"
  awk -F= '
    $1=="SYSTEM_IMG" ||
    $1=="SYSTEM_SHA256" ||
    $1=="SYSTEM_BYTES" ||
    $1=="TARGET_FILES_ZIP" ||
    $1=="TARGET_FILES_SHA256" ||
    $1=="TARGET_FILES_BYTES" {
      print FILENAME "\t" $1 "\t" substr($0, index($0,"=")+1)
    }
  ' "$f" >> "$TMP_IDS"
done

show_file "$EVID/n1b2-cellular-static/20260929T131259Z/n1b1-system-img-sha256.txt"
show_file "$EVID/n1b2-cellular-static/20260929T131259Z/n1b1-system-img-file.txt"
show_file "$EVID/n1b2-cellular-static/20260929T131259Z/n1b1-target-files-telephony-probe.txt"
show_file "$EVID/n1b2-cellular-static/20260929T131259Z/n1b1-target-files-dirs.txt"

for f in "$EVID"/n1d-c0-offline-*/reports/C0_01_N1B_CANDIDATES.txt; do
  [[ -f "$f" ]] || continue
  echo
  echo "===== C0 CANDIDATES: $f ====="
  grep -Ei 'system\.img|target[_-]files|target-files|n1b-control|out_sable_t2_n1' "$f" |
    head -250 || true
done

REF_DIR="$EVID/n1c-sable-build-mount-cleanup-20260930_143705"
REF_ZIP="$REF_DIR/old-n1b-reference-pack.zip"
show_file "$REF_DIR/old-n1b-reference-pack.sha256"

if [[ -f "$REF_ZIP" ]]; then
  echo
  echo "===== OLD N1B REFERENCE PACK IDENTITY ====="
  stat -c 'REF_PACK_BYTES=%s' "$REF_ZIP"
  echo "REF_PACK_SHA256=$(sha256sum "$REF_ZIP" | awk '{print $1}')"

  if command -v unzip >/dev/null 2>&1; then
    echo
    echo "===== OLD N1B REFERENCE PACK RELEVANT MEMBERS ====="
    unzip -Z1 "$REF_ZIP" 2>/dev/null |
      grep -Ei '(^|/)(system\.img|.*target[_-]files.*\.zip|.*target-files.*\.zip|.*image.*sha.*|.*build.*env|repo-manifest|manifest.*xml|.*\.sha256)$' |
      head -300 || true
  else
    echo "OLD_N1B_REFERENCE_PACK_LISTING=SKIP_UNZIP_MISSING"
  fi
fi

echo
echo "===== RECORDED PHASE-08 ARTIFACT IDENTITIES ====="
cat "$TMP_IDS"

while IFS=$'\t' read -r _env key value; do
  case "$key" in
    SYSTEM_IMG|TARGET_FILES_ZIP)
      [[ -n "$value" ]] || continue
      if [[ -f "$value" ]]; then
        echo "RECORDED_PATH_EXISTS key=$key path=$value"
      else
        echo "RECORDED_PATH_MISSING key=$key path=$value"
      fi
      ;;
  esac
done < "$TMP_IDS"

echo
echo "===== EXACT SYSTEM-BYTE SEARCH ACROSS SABLE BUILD ROOT ====="
mapfile -t SYSTEM_SIZE_HITS < <(
  find "$ROOT" -type f -size "${EXPECTED_SYSTEM_BYTES}c" -print 2>/dev/null |
    LC_ALL=C sort -u
)
echo "SYSTEM_SIZE_HIT_COUNT=${#SYSTEM_SIZE_HITS[@]}"
SYSTEM_FOUND=NO
for f in "${SYSTEM_SIZE_HITS[@]}"; do
  h="$(sha256sum "$f" | awk '{print $1}')"
  echo "SYSTEM_SIZE_HIT sha256=$h path=$f"
  if [[ "$h" == "$EXPECTED_SYSTEM_SHA" ]]; then
    echo "N1B_EXACT_SYSTEM_FOUND=$f"
    SYSTEM_FOUND=YES
  fi
done

echo
echo "===== TARGET-FILES IDENTITY SEARCH ====="
mapfile -t TF_RECORDS < <(
  python3 - "$TMP_IDS" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
by = {}
for line in p.read_text(errors="replace").splitlines():
    try:
        env, key, value = line.split("\t", 2)
    except ValueError:
        continue
    by.setdefault(env, {})[key] = value

seen = set()
for env, record in sorted(by.items()):
    sha = record.get("TARGET_FILES_SHA256", "").strip()
    size = record.get("TARGET_FILES_BYTES", "").strip()
    path = record.get("TARGET_FILES_ZIP", "").strip()
    if sha and len(sha) == 64 and size.isdigit():
        item = (sha, size, path)
        if item not in seen:
            seen.add(item)
            print("\t".join(item))
PY
)

echo "TARGET_FILES_IDENTITY_COUNT=${#TF_RECORDS[@]}"
TARGET_FILES_FOUND=NO
SYSTEM_RECOVERABLE=NO

for rec in "${TF_RECORDS[@]}"; do
  IFS=$'\t' read -r tf_sha tf_bytes tf_path <<< "$rec"
  echo "TARGET_FILES_RECORDED sha256=$tf_sha bytes=$tf_bytes path=$tf_path"

  mapfile -t HITS < <(
    find "$ROOT" -type f -size "${tf_bytes}c"       \( -iname '*.zip' -o -iname '*.ota' \) -print 2>/dev/null |
      LC_ALL=C sort -u
  )
  echo "TARGET_FILES_SIZE_HIT_COUNT=${#HITS[@]} sha256=$tf_sha"

  for f in "${HITS[@]}"; do
    h="$(sha256sum "$f" | awk '{print $1}')"
    echo "TARGET_FILES_SIZE_HIT actual_sha256=$h path=$f"
    [[ "$h" == "$tf_sha" ]] || continue

    TARGET_FILES_FOUND=YES
    echo "N1B_EXACT_TARGET_FILES_FOUND=$f"

    if command -v unzip >/dev/null 2>&1 &&
       unzip -Z1 "$f" 2>/dev/null | grep -Fxq 'IMAGES/system.img'; then
      member_bytes="$(unzip -l "$f" IMAGES/system.img 2>/dev/null |
        awk '$NF=="IMAGES/system.img" {print $1; exit}')"
      member_sha="$(unzip -p "$f" IMAGES/system.img 2>/dev/null |
        sha256sum | awk '{print $1}')"
      echo "TARGET_FILES_SYSTEM_MEMBER_BYTES=$member_bytes"
      echo "TARGET_FILES_SYSTEM_MEMBER_SHA256=$member_sha"
      if [[ "$member_bytes" == "$EXPECTED_SYSTEM_BYTES" &&
            "$member_sha" == "$EXPECTED_SYSTEM_SHA" ]]; then
        SYSTEM_RECOVERABLE=YES
        echo "N1B_EXACT_SYSTEM_RECOVERABLE_FROM_TARGET_FILES=YES path=$f"
      fi
    fi
  done
done

echo
echo "===== AUDIT RESULT ====="
echo "N1B_EXACT_SYSTEM_PRESENT=$SYSTEM_FOUND"
echo "N1B_EXACT_TARGET_FILES_PRESENT=$TARGET_FILES_FOUND"
echo "N1B_EXACT_SYSTEM_RECOVERABLE_FROM_TARGET_FILES=$SYSTEM_RECOVERABLE"

if [[ "$SYSTEM_FOUND" == YES || "$SYSTEM_RECOVERABLE" == YES ]]; then
  echo "N1B_CONTROL_ARTIFACT_STATUS=RECOVERABLE_EXACT"
else
  echo "N1B_CONTROL_ARTIFACT_STATUS=NOT_FOUND_IN_RETAINED_STORAGE"
fi

echo "N1B_RETAINED_ARTIFACT_FORENSIC_AUDIT=PASS_READ_ONLY"
