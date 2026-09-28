#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="$ROOT/docs/titan2/N1B_PHASE_09_GSI_DEPLOYMENT_READINESS.md"
QUALIFIER="$ROOT/build/titan2/qualify-n1b-phase-09-gsi-deployment-readiness.sh"

failures=0

echo "===== N1B PHASE 09 GSI DEPLOYMENT READINESS CONTRACT ====="
echo "ROOT=$ROOT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

require_file() {
  local path="$1"
  local marker="$2"
  if [[ -f "$path" ]]; then
    echo "$marker=PASS"
  else
    echo "$marker=FAIL path=$path"
    failures=$((failures + 1))
  fi
}

require_grep() {
  local pattern="$1"
  local path="$2"
  local marker="$3"
  if grep -Fq "$pattern" "$path"; then
    echo "$marker=PASS"
  else
    echo "$marker=FAIL pattern=$pattern path=$path"
    failures=$((failures + 1))
  fi
}

require_file "$DOC" "N1B_PHASE_09_DOC"
require_file "$QUALIFIER" "N1B_PHASE_09_QUALIFIER"

if [[ -f "$QUALIFIER" ]]; then
  if bash -n "$QUALIFIER"; then
    echo "N1B_PHASE_09_QUALIFIER_SYNTAX=PASS"
  else
    echo "N1B_PHASE_09_QUALIFIER_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
fi

if [[ -f "$DOC" ]]; then
  require_grep "ARTIFACT_KIND=gsi-system-image" "$DOC" "N1B_PHASE_09_DOC_GSI_MARKER"
  require_grep "N1B_COMBINES_N1A_IMAGE=NO" "$DOC" "N1B_PHASE_09_DOC_N1A_LINEAGE_MARKER"
  require_grep "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED" "$DOC" "N1B_PHASE_09_DOC_BLOCKED_MARKER"
  require_grep "N1B_PHASE_09_FLASH_PLAN_ALLOWED=NO" "$DOC" "N1B_PHASE_09_DOC_FLASH_PLAN_BLOCK_MARKER"
  require_grep "FLASH_AUTHORIZED=NO" "$DOC" "N1B_PHASE_09_DOC_NO_FLASH_MARKER"
fi

if [[ -f "$QUALIFIER" ]]; then
  require_grep "ADB_COMMANDS_RUN=NO" "$QUALIFIER" "N1B_PHASE_09_QUALIFIER_NO_ADB_MARKER"
  require_grep "FASTBOOT_COMMANDS_RUN=NO" "$QUALIFIER" "N1B_PHASE_09_QUALIFIER_NO_FASTBOOT_MARKER"
  require_grep "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED" "$QUALIFIER" "N1B_PHASE_09_QUALIFIER_BLOCKED_MARKER"
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

TEST_MANIFEST="$TMPDIR/n1b-artifact.json"
cat > "$TEST_MANIFEST" <<'JSON'
{
  "schema": 2,
  "device": "titan2",
  "release": "N1B",
  "build_source": "test-build-source",
  "tool_source": "test-tool-source",
  "out_dir": "/tmp/out",
  "primary_artifact": "system",
  "metadata": {
    "active_product_mk": "device/phh/treble/treble_arm64_bvN.mk",
    "artifact_logical_bytes": "3180666880",
    "device_contact_authorized": "NO",
    "flash_authorized": "NO",
    "n1b_full_local_ci_evidence_dir": "/tmp/ci",
    "n1b_full_local_ci_profile": "full",
    "n1b_phase_08_image_build_evidence_dir": "/tmp/image",
    "production_signing": "NO",
    "public_release": "NO"
  }
}
JSON

if bash "$QUALIFIER" --manifest "$TEST_MANIFEST" > "$TMPDIR/qualifier.log"; then
  if grep -Fq "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED" "$TMPDIR/qualifier.log" &&
     grep -Fq "N1B_PHASE_09_FLASH_PLAN_ALLOWED=NO" "$TMPDIR/qualifier.log"; then
    echo "N1B_PHASE_09_EXPECTED_BLOCKED_FIXTURE=PASS"
  else
    echo "N1B_PHASE_09_EXPECTED_BLOCKED_FIXTURE=FAIL_MARKERS"
    cat "$TMPDIR/qualifier.log"
    failures=$((failures + 1))
  fi
else
  echo "N1B_PHASE_09_EXPECTED_BLOCKED_FIXTURE=FAIL_EXIT"
  cat "$TMPDIR/qualifier.log"
  failures=$((failures + 1))
fi

if bash "$QUALIFIER" --manifest "$TEST_MANIFEST" --require-ready > "$TMPDIR/require-ready.log"; then
  echo "N1B_PHASE_09_REQUIRE_READY_BLOCKS_MISSING_PREFLIGHT=FAIL"
  cat "$TMPDIR/require-ready.log"
  failures=$((failures + 1))
else
  if grep -Fq "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED" "$TMPDIR/require-ready.log"; then
    echo "N1B_PHASE_09_REQUIRE_READY_BLOCKS_MISSING_PREFLIGHT=PASS"
  else
    echo "N1B_PHASE_09_REQUIRE_READY_BLOCKS_MISSING_PREFLIGHT=FAIL_MARKERS"
    cat "$TMPDIR/require-ready.log"
    failures=$((failures + 1))
  fi
fi

echo "===== N1B PHASE 09 GSI DEPLOYMENT READINESS CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS_CONTRACT=PASS"
else
  echo "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS_CONTRACT=FAIL"
  exit 1
fi
