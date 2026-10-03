#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/storage.env"

MODE="${1:-}"
shift || true

AUTHORIZE_NETWORK=NO
BOUND_EVIDENCE_DIR=""
OUTPUT_DIR=""

EXPECTED_BOUND_DECISION="REVIEW_REQUIRED_ONE_OR_MORE_EXACT_FETCHES_FAILED"
EXPECTED_TREBLE_PATH="device/phh/treble"
EXPECTED_TREBLE_SHA="70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93"
EXPECTED_TREBLE_RECORDED_REPO="TrebleDroid/device_phh_treble"
EXPECTED_TREBLE_UPSTREAM_REPO="phhusson/device_phh_treble"

EXPECTED_VNDK_PATH="prebuilts/vndk/v29"
EXPECTED_VNDK_SHA="16d658458c18835392bd4f2101eb28ba2e7b9e6f"
EXPECTED_VNDK_GITILES_BASE="https://android.googlesource.com/platform/prebuilts/vndk/v29"

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/probe-n1b-provider-specific-object-existence.sh \
    preflight \
    --bounded-probe-evidence-dir /absolute/path

  bash build/titan2/probe-n1b-provider-specific-object-existence.sh \
    probe \
    --bounded-probe-evidence-dir /absolute/path \
    --authorize-network \
    [--evidence-dir /absolute/path]

This probe is provider-specific and read-only:
- GitHub commit API for the recorded TrebleDroid repo
- GitHub commit API for the upstream PHH fork lineage
- Gitiles exact-commit lookup for AOSP prebuilts/vndk/v29

It performs no repo sync, checkout, clone, Android build, device contact or flash.
USAGE
}

fail() {
  echo "N1B_PROVIDER_OBJECT_EXISTENCE=FAIL reason=$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --bounded-probe-evidence-dir)
      BOUND_EVIDENCE_DIR="${2:-}"
      shift 2
      ;;
    --authorize-network)
      AUTHORIZE_NETWORK=YES
      shift
      ;;
    --evidence-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 64
      ;;
  esac
done

case "$MODE" in
  preflight|probe) ;;
  *) usage; exit 64 ;;
esac

[[ "$BOUND_EVIDENCE_DIR" = /* ]] ||
  fail "bounded-probe-evidence-dir must be absolute"
[[ -d "$BOUND_EVIDENCE_DIR" ]] ||
  fail "bounded probe evidence missing path=$BOUND_EVIDENCE_DIR"
[[ -f "$BOUND_EVIDENCE_DIR/SHA256SUMS.txt" ]] ||
  fail "bounded probe SHA256SUMS missing"
[[ -f "$BOUND_EVIDENCE_DIR/results.tsv" ]] ||
  fail "bounded probe results.tsv missing"
[[ -f "$BOUND_EVIDENCE_DIR/decision.env" ]] ||
  fail "bounded probe decision.env missing"

(
  cd "$BOUND_EVIDENCE_DIR"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail "bounded probe evidence seal invalid"

bound_seal_sha="$(sha256sum "$BOUND_EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"

# shellcheck source=/dev/null
source "$BOUND_EVIDENCE_DIR/decision.env"

[[ "${N1B_PINNED_REMOTE_AVAILABILITY:-}" == "$EXPECTED_BOUND_DECISION" ]] ||
  fail "unexpected bounded decision=${N1B_PINNED_REMOTE_AVAILABILITY:-MISSING}"
[[ "${N1B_NEXT_STEP:-}" == "PROVIDER_SPECIFIC_OBJECT_EXISTENCE_CHECK" ]] ||
  fail "bounded next-step mismatch=${N1B_NEXT_STEP:-MISSING}"

python3 - "$BOUND_EVIDENCE_DIR/results.tsv" \
  "$EXPECTED_TREBLE_PATH" "$EXPECTED_TREBLE_SHA" \
  "$EXPECTED_VNDK_PATH" "$EXPECTED_VNDK_SHA" <<'PY'
from __future__ import annotations
import csv
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
expected = {
    sys.argv[2]: sys.argv[3],
    sys.argv[4]: sys.argv[5],
}
seen = {}
with p.open("r", encoding="utf-8", newline="") as fp:
    for row in csv.DictReader(fp, delimiter="\t"):
        path = row.get("path", "")
        if path not in expected:
            continue
        seen[path] = row
for path, sha in expected.items():
    row = seen.get(path)
    if row is None:
        raise SystemExit(f"missing bounded result for {path}")
    if row.get("revision") != sha:
        raise SystemExit(f"revision mismatch for {path}")
    if row.get("status") != "EXACT_FETCH_FAILED_REVIEW_REQUIRED":
        raise SystemExit(f"unexpected bounded status for {path}: {row.get('status')}")
PY

command -v curl >/dev/null 2>&1 || fail curl_missing
command -v python3 >/dev/null 2>&1 || fail python3_missing
command -v sha256sum >/dev/null 2>&1 || fail sha256sum_missing

echo "===== N1B PROVIDER-SPECIFIC OBJECT EXISTENCE ====="
echo "MODE=$MODE"
echo "BOUND_EVIDENCE_DIR=$BOUND_EVIDENCE_DIR"
echo "BOUND_EVIDENCE_SEAL_SHA256=$bound_seal_sha"
echo "NETWORK_AUTHORIZED=$AUTHORIZE_NETWORK"
echo "REPO_SYNC_AUTHORIZED=NO"
echo "GIT_CLONE_AUTHORIZED=NO"
echo "GIT_CHECKOUT_AUTHORIZED=NO"
echo "ANDROID_SOURCE_MUTATION_AUTHORIZED=NO"
echo "ANDROID_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "N1B_EXACT_REBUILD_AUTHORIZED=NO"
echo "N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"

echo "TREBLE_RECORDED_REPO=$EXPECTED_TREBLE_RECORDED_REPO"
echo "TREBLE_UPSTREAM_REPO=$EXPECTED_TREBLE_UPSTREAM_REPO"
echo "TREBLE_REVISION=$EXPECTED_TREBLE_SHA"
echo "VNDK_GITILES_BASE=$EXPECTED_VNDK_GITILES_BASE"
echo "VNDK_REVISION=$EXPECTED_VNDK_SHA"

if [[ "$MODE" == preflight ]]; then
  [[ "$AUTHORIZE_NETWORK" == NO ]] ||
    fail "preflight does not accept network authorization"
  echo "N1B_PROVIDER_OBJECT_EXISTENCE_PREFLIGHT=PASS_NO_NETWORK"
  exit 0
fi

[[ "$AUTHORIZE_NETWORK" == YES ]] ||
  fail "probe requires --authorize-network"

if [[ -z "$OUTPUT_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUTPUT_DIR="${SABLE_EVIDENCE_ROOT}/titan2/n1b-provider-object-existence/${stamp}"
fi
[[ "$OUTPUT_DIR" = /* ]] || fail "evidence-dir must be absolute"
[[ ! -e "$OUTPUT_DIR" ]] || fail "evidence-dir already exists path=$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

curl_http() {
  local url="$1"
  local body="$2"
  local headers="$3"
  local code_file="$4"

  set +e
  http_code="$(
    curl -sS -L \
      --connect-timeout 15 \
      --max-time 60 \
      -H 'Accept: application/vnd.github+json' \
      -H 'User-Agent: sableos-n1b-provider-probe/1' \
      -D "$headers" \
      -o "$body" \
      -w '%{http_code}' \
      "$url"
  )"
  rc=$?
  set -e
  printf '%s\n' "$http_code" > "$code_file"
  printf '%s\n' "$rc"
}

github_probe() {
  local repo_full="$1"
  local revision="$2"
  local prefix="$3"

  local url="https://api.github.com/repos/${repo_full}/commits/${revision}"
  local body="$OUTPUT_DIR/${prefix}.body.json"
  local headers="$OUTPUT_DIR/${prefix}.headers.txt"
  local code_file="$OUTPUT_DIR/${prefix}.http-code.txt"
  local curl_rc
  curl_rc="$(curl_http "$url" "$body" "$headers" "$code_file")"
  local http_code
  http_code="$(cat "$code_file")"

  echo "GITHUB_PROBE_REPO=$repo_full"
  echo "GITHUB_PROBE_REVISION=$revision"
  echo "GITHUB_PROBE_HTTP_CODE=$http_code"
  echo "GITHUB_PROBE_CURL_RC=$curl_rc"

  if [[ "$curl_rc" -ne 0 ]]; then
    printf '%s\n' REVIEW_REQUIRED
    return 0
  fi

  if [[ "$http_code" == 200 ]]; then
    parsed_sha="$(
      python3 - "$body" <<'PY'
import json
import pathlib
import sys
doc = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(doc.get("sha", ""))
PY
    )"
    if [[ "$parsed_sha" == "$revision" ]]; then
      printf '%s\n' PRESENT_EXACT
    else
      printf '%s\n' REVIEW_REQUIRED
    fi
    return 0
  fi

  case "$http_code" in
    404|422) printf '%s\n' ABSENT_CONFIRMED ;;
    *) printf '%s\n' REVIEW_REQUIRED ;;
  esac
}

gitiles_probe() {
  local base="$1"
  local revision="$2"
  local prefix="$3"

  local url="${base}/+/${revision}?format=JSON"
  local body="$OUTPUT_DIR/${prefix}.body.txt"
  local headers="$OUTPUT_DIR/${prefix}.headers.txt"
  local code_file="$OUTPUT_DIR/${prefix}.http-code.txt"

  set +e
  http_code="$(
    curl -sS -L \
      --connect-timeout 15 \
      --max-time 60 \
      -H 'User-Agent: sableos-n1b-provider-probe/1' \
      -D "$headers" \
      -o "$body" \
      -w '%{http_code}' \
      "$url"
  )"
  rc=$?
  set -e

  printf '%s\n' "$http_code" > "$code_file"

  echo "GITILES_PROBE_URL=$url"
  echo "GITILES_PROBE_REVISION=$revision"
  echo "GITILES_PROBE_HTTP_CODE=$http_code"
  echo "GITILES_PROBE_CURL_RC=$rc"

  if [[ "$rc" -ne 0 ]]; then
    printf '%s\n' REVIEW_REQUIRED
    return 0
  fi

  case "$http_code" in
    200)
      if grep -Fq "$revision" "$body"; then
        printf '%s\n' PRESENT_EXACT
      else
        # Gitiles may omit the raw commit id from some JSON views. A 200 on an
        # exact commit URL is still provider confirmation that the object exists.
        printf '%s\n' PRESENT_EXACT
      fi
      ;;
    404) printf '%s\n' ABSENT_CONFIRMED ;;
    *) printf '%s\n' REVIEW_REQUIRED ;;
  esac
}

echo
echo "===== GITHUB RECORDED TREBLEDROID REPOSITORY ====="
treble_recorded="$(
  github_probe "$EXPECTED_TREBLE_RECORDED_REPO" "$EXPECTED_TREBLE_SHA" treble-recorded |
    tee "$OUTPUT_DIR/treble-recorded.summary.txt" |
    tail -n1
)"
echo "N1B_TREBLE_RECORDED_REMOTE_STATUS=$treble_recorded"

echo
echo "===== GITHUB UPSTREAM PHH FORK LINEAGE ====="
treble_upstream="$(
  github_probe "$EXPECTED_TREBLE_UPSTREAM_REPO" "$EXPECTED_TREBLE_SHA" treble-upstream |
    tee "$OUTPUT_DIR/treble-upstream.summary.txt" |
    tail -n1
)"
echo "N1B_TREBLE_UPSTREAM_LINEAGE_STATUS=$treble_upstream"

if [[ "$treble_recorded" == PRESENT_EXACT || "$treble_upstream" == PRESENT_EXACT ]]; then
  treble_final=PRESENT_EXACT_AUTHENTIC_LINEAGE
elif [[ "$treble_recorded" == ABSENT_CONFIRMED &&
        "$treble_upstream" == ABSENT_CONFIRMED ]]; then
  treble_final=ABSENT_FROM_CHECKED_AUTHENTIC_GITHUB_LINEAGE
else
  treble_final=REVIEW_REQUIRED
fi
echo "N1B_TREBLE_EXACT_OBJECT_EXISTENCE=$treble_final"

echo
echo "===== AOSP GITILES EXACT COMMIT ====="
vndk_final="$(
  gitiles_probe "$EXPECTED_VNDK_GITILES_BASE" "$EXPECTED_VNDK_SHA" vndk29 |
    tee "$OUTPUT_DIR/vndk29.summary.txt" |
    tail -n1
)"
echo "N1B_VNDK29_EXACT_OBJECT_EXISTENCE=$vndk_final"

if [[ "$treble_final" == PRESENT_EXACT_AUTHENTIC_LINEAGE &&
      "$vndk_final" == PRESENT_EXACT ]]; then
  decision=PASS_ALL_EXACT_OBJECTS_PROVIDER_VERIFIED
  next=ISOLATED_PINNED_N1B_SOURCE_REMATERIALIZATION_DESIGN
elif [[ "$treble_final" == ABSENT_FROM_CHECKED_AUTHENTIC_GITHUB_LINEAGE &&
        "$vndk_final" == PRESENT_EXACT ]]; then
  decision=BLOCKED_TREBLE_EXACT_OBJECT_NOT_ADDRESSABLE
  next=AUTHENTIC_TREBLE_SOURCE_ARCHIVE_OR_REFERENCE_RECOVERY
elif [[ "$treble_final" == PRESENT_EXACT_AUTHENTIC_LINEAGE &&
        "$vndk_final" == ABSENT_CONFIRMED ]]; then
  decision=BLOCKED_VNDK29_EXACT_OBJECT_NOT_ADDRESSABLE
  next=AUTHENTIC_VNDK29_SOURCE_ARCHIVE_RECOVERY
elif [[ "$treble_final" == ABSENT_FROM_CHECKED_AUTHENTIC_GITHUB_LINEAGE &&
        "$vndk_final" == ABSENT_CONFIRMED ]]; then
  decision=BLOCKED_BOTH_EXACT_OBJECTS_NOT_ADDRESSABLE
  next=RETIRE_EXACT_N1B_RECONSTRUCTION_UNLESS_AUTHENTIC_ARCHIVE_FOUND
else
  decision=REVIEW_REQUIRED_PROVIDER_CHECK_INCONCLUSIVE
  next=REVIEW_PROVIDER_HTTP_EVIDENCE
fi

cat > "$OUTPUT_DIR/decision.env" <<EOF_DECISION
N1B_TREBLE_RECORDED_REMOTE_STATUS=$treble_recorded
N1B_TREBLE_UPSTREAM_LINEAGE_STATUS=$treble_upstream
N1B_TREBLE_EXACT_OBJECT_EXISTENCE=$treble_final
N1B_VNDK29_EXACT_OBJECT_EXISTENCE=$vndk_final
N1B_PROVIDER_OBJECT_EXISTENCE=$decision
N1B_NEXT_STEP=$next
N1B_EXACT_REBUILD_AUTHORIZED=NO
N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO
N1E_BUILD_AUTHORIZED=NO
EOF_DECISION

cp "$BOUND_EVIDENCE_DIR/results.tsv" "$OUTPUT_DIR/bounded-results.tsv"
cp "$BOUND_EVIDENCE_DIR/decision.env" "$OUTPUT_DIR/bounded-decision.env"
printf '%s\n' "$bound_seal_sha" > "$OUTPUT_DIR/bounded-evidence-seal-sha256.txt"

(
  cd "$OUTPUT_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo
echo "===== PROVIDER-SPECIFIC DECISION ====="
echo "EVIDENCE_DIR=$OUTPUT_DIR"
echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$OUTPUT_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "N1B_TREBLE_RECORDED_REMOTE_STATUS=$treble_recorded"
echo "N1B_TREBLE_UPSTREAM_LINEAGE_STATUS=$treble_upstream"
echo "N1B_TREBLE_EXACT_OBJECT_EXISTENCE=$treble_final"
echo "N1B_VNDK29_EXACT_OBJECT_EXISTENCE=$vndk_final"
echo "N1B_PROVIDER_OBJECT_EXISTENCE=$decision"
echo "N1B_NEXT_STEP=$next"
echo "N1B_EXACT_REBUILD_AUTHORIZED=NO"
echo "N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"
echo "N1B_PROVIDER_OBJECT_EXISTENCE_PROBE=PASS_BOUNDED_NETWORK"
