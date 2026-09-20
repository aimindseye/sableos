#!/usr/bin/env bash
# Device adapter for Pixel 7 / panther.

SABLE_DEVICE_CANONICAL=panther
SABLE_DEVICE_EXPECTED_PRODUCT=panther
SABLE_DEVICE_BUILD_SUPPORTED=YES
SABLE_DEVICE_FLASH_SUPPORTED=YES
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=YES
SABLE_DEVICE_DEFAULT_ACCEPTANCE_SUITE=launcher

sable_device_build() {
  local release="$1"
  local mode="$2"
  bash "$ROOT/build/panther/run-release.sh" "$release" "$mode"
}

sable_device_accept() {
  local release="$1"
  local suite="$2"
  local serial="$3"
  local evidence_root="$4"

  case "$release:$suite" in
    R9:launcher|r9:launcher)
      local stamp evidence
      stamp="$(date -u +%Y%m%dT%H%M%SZ)"
      evidence="$evidence_root/panther/r9-physical/${stamp}_launcher-acceptance"
      SERIAL="$serial" \
      EVIDENCE_DIR="$evidence" \
        bash "$ROOT/tests/launcher3/device/r9_home_acceptance.sh"
      ;;
    *)
      echo "SABLE_DEVICE_ACCEPT=UNSUPPORTED device=panther release=$release suite=$suite" >&2
      return 64
      ;;
  esac
}


sable_device_artifact_gate() {
  local release="$1"
  local build_source="$2"
  local target_files_sha="$3"
  local evidence_dir="$4"

  [[ -n "$evidence_dir" && -d "$evidence_dir" ]] || {
    echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_EVIDENCE_DIR"
    return 1
  }

  case "$release" in
    R9|r9)
      local markers=(
        "SOURCE=$build_source"
        "TARGET_FILES_SHA256=$target_files_sha"
        "R9_TARGET_FILES_FRESHNESS=PASS"
        "R9_FRESH_FULL_BUILD=PASS"
        "R9_FULL_BUILD_CAUSALITY=PASS_ABSENT_OUT_TO_FRESH_TARGET_FILES"
        "R8_RELEASE_CANDIDATE=PASS"
      )
      local marker
      for marker in "${markers[@]}"; do
        if ! grep -R -Fq -- "$marker" "$evidence_dir" 2>/dev/null; then
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_MISSING_MARKER marker=$marker"
          return 1
        fi
      done
      ;;
    *)
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_UNQUALIFIED_RELEASE release=$release"
      return 1
      ;;
  esac

  echo "SABLE_DEVICE_ARTIFACT_GATE=PASS"
}
