#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/storage.env"

MODE="${1:-}"
shift || true
AUTHORIZE_NETWORK=NO
EVIDENCE_DIR=""
PHASE08_MANIFEST="${SABLE_EVIDENCE_ROOT}/titan2/n1b-phase-08-image-build-candidate/20260928_190313/repo-manifest-r.xml"
EXPECTED_MANIFEST_SHA="2ce10689772b122b1cd8810a302735a67826753e819e17ca35a576aaff6c21cc"
EXPECTED_TREBLE_REV="70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93"
EXPECTED_VNDK29_REV="16d658458c18835392bd4f2101eb28ba2e7b9e6f"

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/probe-n1b-pinned-source-remotes.sh preflight
  bash build/titan2/probe-n1b-pinned-source-remotes.sh probe --authorize-network     [--evidence-dir /absolute/path]

Scope: exactly two pinned Phase-08 source objects:
  device/phh/treble       70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93
  prebuilts/vndk/v29      16d658458c18835392bd4f2101eb28ba2e7b9e6f

The probe never runs repo sync, mutates Android source, builds Android, contacts
or flashes a device. Network mode creates temporary bare Git repositories and
sealed evidence only.
USAGE
}

fail() {
  echo "N1B_PINNED_REMOTE_PROBE=FAIL reason=$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --authorize-network) AUTHORIZE_NETWORK=YES; shift ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 64 ;;
  esac
done

case "$MODE" in
  preflight|probe) ;;
  *) usage; exit 64 ;;
esac

[[ -f "$PHASE08_MANIFEST" ]] || fail "manifest missing path=$PHASE08_MANIFEST"
manifest_sha="$(sha256sum "$PHASE08_MANIFEST" | awk '{print $1}')"
[[ "$manifest_sha" == "$EXPECTED_MANIFEST_SHA" ]] ||
  fail "manifest sha mismatch expected=$EXPECTED_MANIFEST_SHA actual=$manifest_sha"
command -v git >/dev/null 2>&1 || fail git_missing
command -v python3 >/dev/null 2>&1 || fail python3_missing
command -v sha256sum >/dev/null 2>&1 || fail sha256sum_missing

PROJECTS_TSV="$(mktemp)"
TMP_ROOT=""
cleanup() {
  rm -f "$PROJECTS_TSV"
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT

python3 - "$PHASE08_MANIFEST" > "$PROJECTS_TSV" <<'PY'
from __future__ import annotations
import sys
import xml.etree.ElementTree as ET

wanted = {"device/phh/treble", "prebuilts/vndk/v29"}
root = ET.parse(sys.argv[1]).getroot()

default_remote = ""
for child in root:
    if child.tag == "default":
        default_remote = child.attrib.get("remote", "")
        break

remotes = {}
for remote in root.iter("remote"):
    remotes[remote.attrib.get("name", "")] = remote.attrib.get("fetch", "")

rows = []
for project in root.iter("project"):
    path = project.attrib.get("path", project.attrib.get("name", ""))
    if path not in wanted:
        continue
    name = project.attrib.get("name", "")
    revision = project.attrib.get("revision", "")
    remote = project.attrib.get("remote", default_remote)
    fetch = remotes.get(remote, "")
    upstream = project.attrib.get("upstream", "")
    rows.append((path, name, revision, remote, fetch, upstream))

for row in sorted(rows):
    print("\t".join(row))
PY

[[ "$(wc -l < "$PROJECTS_TSV")" -eq 2 ]] || fail critical_project_count
grep -Fq "$EXPECTED_TREBLE_REV" "$PROJECTS_TSV" || fail treble_revision_mismatch
grep -Fq "$EXPECTED_VNDK29_REV" "$PROJECTS_TSV" || fail vndk29_revision_mismatch

build_url() {
  local fetch="$1"
  local name="$2"
  fetch="${fetch%/}"
  printf '%s/%s\n' "$fetch" "$name"
}

echo "===== N1B PINNED REMOTE AVAILABILITY ====="
echo "MODE=$MODE"
echo "PHASE08_MANIFEST=$PHASE08_MANIFEST"
echo "PHASE08_MANIFEST_SHA256=$manifest_sha"
echo "NETWORK_AUTHORIZED=$AUTHORIZE_NETWORK"
echo "REPO_SYNC_AUTHORIZED=NO"
echo "ANDROID_SOURCE_MUTATION_AUTHORIZED=NO"
echo "ANDROID_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "N1B_EXACT_REBUILD_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"

while IFS=$'\t' read -r path name revision remote fetch upstream; do
  url="$(build_url "$fetch" "$name")"
  echo "PROJECT_PATH=$path"
  echo "PROJECT_NAME=$name"
  echo "PROJECT_REVISION=$revision"
  echo "PROJECT_REMOTE=$remote"
  echo "PROJECT_FETCH_BASE=$fetch"
  echo "PROJECT_URL=$url"
  echo "PROJECT_UPSTREAM=$upstream"
done < "$PROJECTS_TSV"

if [[ "$MODE" == preflight ]]; then
  [[ "$AUTHORIZE_NETWORK" == NO ]] || fail "preflight does not accept network authorization"
  echo "N1B_PINNED_REMOTE_PREFLIGHT=PASS_NO_NETWORK"
  exit 0
fi

[[ "$AUTHORIZE_NETWORK" == YES ]] || fail "probe requires --authorize-network"

if [[ -z "$EVIDENCE_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_DIR="${SABLE_EVIDENCE_ROOT}/titan2/n1b-pinned-source-remote-probe/${stamp}"
fi
[[ "$EVIDENCE_DIR" = /* ]] || fail "evidence-dir must be absolute"
[[ ! -e "$EVIDENCE_DIR" ]] || fail "evidence-dir already exists path=$EVIDENCE_DIR"
mkdir -p "$EVIDENCE_DIR"
TMP_ROOT="$(mktemp -d)"

RESULTS="$EVIDENCE_DIR/results.tsv"
printf 'path\tname\trevision\tremote_url\tupstream\tstatus\tfetched_commit\n' > "$RESULTS"

all_available=YES
idx=0
while IFS=$'\t' read -r path name revision remote fetch upstream; do
  idx=$((idx + 1))
  url="$(build_url "$fetch" "$name")"
  slug="$(printf '%s' "$path" | tr '/:' '__')"
  bare="$TMP_ROOT/${idx}-${slug}.git"
  log="$EVIDENCE_DIR/${idx}-${slug}.fetch.log"

  git init --bare "$bare" >/dev/null

  echo "===== PROBE $path =====" | tee "$log"
  echo "REMOTE_URL=$url" | tee -a "$log"
  echo "REVISION=$revision" | tee -a "$log"
  echo "UPSTREAM=$upstream" | tee -a "$log"

  set +e
  GIT_TERMINAL_PROMPT=0     git --git-dir="$bare" -c protocol.version=2 fetch       --no-tags --depth=1 "$url" "$revision"       >>"$log" 2>&1
  fetch_rc=$?
  set -e

  status=UNAVAILABLE
  fetched_commit=""
  if [[ "$fetch_rc" -eq 0 ]] &&
     git --git-dir="$bare" cat-file -e "$revision^{commit}" 2>/dev/null; then
    fetched_commit="$(git --git-dir="$bare" rev-parse "$revision^{commit}")"
    [[ "$fetched_commit" == "$revision" ]] || fail "fetched commit mismatch project=$path"
    status=AVAILABLE_EXACT
    echo "EXACT_OBJECT_FETCH=PASS" | tee -a "$log"
    git --git-dir="$bare" show -s       --format='FETCHED_COMMIT_INFO=%H|%cI|%T|%P|%s' "$revision"       | tee -a "$log"
  else
    all_available=NO
    echo "EXACT_OBJECT_FETCH=FAIL rc=$fetch_rc" | tee -a "$log"

    if [[ -n "$upstream" ]]; then
      set +e
      GIT_TERMINAL_PROMPT=0 git ls-remote "$url" "$upstream"         >>"$log" 2>&1
      upstream_rc=$?
      set -e
      echo "UPSTREAM_LS_REMOTE_RC=$upstream_rc" | tee -a "$log"
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n'     "$path" "$name" "$revision" "$url" "$upstream" "$status" "$fetched_commit"     >> "$RESULTS"
  echo "N1B_REMOTE_OBJECT_STATUS=$status project=$path revision=$revision"
done < "$PROJECTS_TSV"

cp "$PHASE08_MANIFEST" "$EVIDENCE_DIR/repo-manifest-r.xml"
cp "$PROJECTS_TSV" "$EVIDENCE_DIR/critical-projects.tsv"

if [[ "$all_available" == YES ]]; then
  decision=PASS_ALL_EXACT_OBJECTS_REMOTE_AVAILABLE
  next=ISOLATED_PINNED_N1B_SOURCE_REMATERIALIZATION_DESIGN
else
  decision=FAIL_ONE_OR_MORE_EXACT_OBJECTS_UNAVAILABLE
  next=RETIRE_EXACT_N1B_RECONSTRUCTION_OR_LOCATE_ALTERNATE_AUTHENTIC_SOURCE
fi

cat > "$EVIDENCE_DIR/decision.env" <<EOF_DECISION
N1B_PINNED_REMOTE_AVAILABILITY=$decision
N1B_NEXT_STEP=$next
N1B_EXACT_REBUILD_AUTHORIZED=NO
N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO
N1E_BUILD_AUTHORIZED=NO
EOF_DECISION

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "N1B_PINNED_REMOTE_AVAILABILITY=$decision"
echo "N1B_NEXT_STEP=$next"
echo "N1B_EXACT_REBUILD_AUTHORIZED=NO"
echo "N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"
echo "N1B_PINNED_REMOTE_PROBE=PASS_BOUNDED_NETWORK"
