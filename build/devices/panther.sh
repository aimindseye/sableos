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
