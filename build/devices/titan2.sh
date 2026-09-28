#!/usr/bin/env bash
# Titan 2 adapter: Treble/GSI preparation only.
# Flash execution remains blocked until the N0/N1 ledger is reviewed.

SABLE_DEVICE_CANONICAL=titan2
SABLE_DEVICE_EXPECTED_PRODUCT=UNQUALIFIED
SABLE_DEVICE_BUILD_SUPPORTED=NO
SABLE_DEVICE_QUALIFY_SUPPORTED=NO
SABLE_DEVICE_DEFAULT_QUALIFICATION_SUITE=none
SABLE_DEVICE_FLASH_SUPPORTED=NO
SABLE_DEVICE_ARTIFACT_REGISTRATION_SUPPORTED=YES
SABLE_DEVICE_FLASH_PLAN_SUPPORTED=YES
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO
SABLE_DEVICE_DEFAULT_ACCEPTANCE_SUITE=none
SABLE_DEVICE_ARTIFACT_KINDS="gsi-system-image"
SABLE_DEVICE_FLASH_TRANSPORT=titan2-fastbootd-ledger-only
SABLE_DEVICE_REQUIRES_FASTBOOT=NO

TITAN2_FASTBOOT_BOOT_SUPPORTED=NO
TITAN2_DSU_AVAILABLE=NO
TITAN2_DYNAMIC_PARTITIONS=YES
TITAN2_VIRTUAL_AB=YES
TITAN2_FLASH_EXECUTION_SUPPORTED=NO
TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO

sable_device_registry_field() {
  local registry_root="$1"
  local release="$2"
  local build_source="$3"
  local field_name="$4"
  python3 "$ROOT/build/deploy/artifact_registry.py" \
    --registry-root "$registry_root" field \
    --device titan2 \
    --release "$release" \
    --build-source "$build_source" \
    --field "$field_name"
}

sable_device_build() {
  echo "SABLE_DEVICE_BUILD=BLOCKED_UNQUALIFIED device=titan2" >&2
  return 78
}

sable_device_qualify() {
  echo "SABLE_DEVICE_QUALIFY=BLOCKED_UNQUALIFIED device=titan2" >&2
  return 78
}

sable_device_accept() {
  echo "SABLE_DEVICE_ACCEPT=BLOCKED_UNQUALIFIED device=titan2" >&2
  return 78
}

sable_device_artifact_gate() {
  local release="$1"
  local build_source="$2"
  local artifact_kind="$3"
  local primary_sha="$4"
  local evidence_dir="$5"

  case "$release" in
    N0|N0_A16|N1|N1B|n0|n0_a16|n1|n1b) ;;
    *)
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_UNQUALIFIED_TITAN_RELEASE release=$release"
      return 1
      ;;
  esac

  [[ "$artifact_kind" == gsi-system-image ]] || {
    echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_ARTIFACT_KIND kind=$artifact_kind"
    return 1
  }

  [[ "$primary_sha" =~ ^[0-9a-f]{64}$ ]] || {
    echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_PRIMARY_SHA256"
    return 1
  }

  [[ -n "$evidence_dir" && -d "$evidence_dir" ]] || {
    echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_BUILD_EVIDENCE_DIR"
    return 1
  }

  echo "SABLE_DEVICE_ARTIFACT_GATE=PASS_TITAN2_GSI"
  echo "TITAN2_FLASH_EXECUTION_SUPPORTED=NO"
  echo "TITAN2_N0_N1_FLASH_PLAN_REQUIRED=YES"
}

sable_device_flash_plan() {
  local release="$1"
  local build_source="$2"
  local registry_root="$3"
  local evidence_dir="$4"

  local artifact_kind primary path sha logical_bytes restore_report
  local bootloader_preflight fastbootd_preflight snapshot_status
  local system_current_bytes lp_action avb_action userdata_policy
  local titan_serial_required active_slot stock_baseline restore_verified

  artifact_kind="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifact_kind)" || return 1
  primary="$(sable_device_registry_field "$registry_root" "$release" "$build_source" primary_artifact)" || return 1
  path="$(sable_device_registry_field "$registry_root" "$release" "$build_source" "artifacts.$primary.path")" || return 1
  sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" "artifacts.$primary.sha256")" || return 1

  logical_bytes="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.artifact_logical_bytes 2>/dev/null || true)"
  restore_report="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.restore_report 2>/dev/null || true)"
  bootloader_preflight="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.bootloader_preflight 2>/dev/null || true)"
  fastbootd_preflight="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.fastbootd_preflight 2>/dev/null || true)"
  snapshot_status="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.snapshot_update_status 2>/dev/null || true)"
  system_current_bytes="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.system_current_bytes 2>/dev/null || true)"
  lp_action="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.lp_action 2>/dev/null || true)"
  avb_action="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.avb_action 2>/dev/null || true)"
  userdata_policy="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.userdata_policy 2>/dev/null || true)"
  titan_serial_required="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.explicit_titan_serial 2>/dev/null || true)"
  active_slot="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.active_slot 2>/dev/null || true)"
  stock_baseline="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.stock_baseline 2>/dev/null || true)"
  restore_verified="$(sable_device_registry_field "$registry_root" "$release" "$build_source" metadata.restore_path_verified 2>/dev/null || true)"

  bash "$ROOT/build/titan2/prepare-n0-n1-flash-plan.sh" \
    --release "$release" \
    --build-source "$build_source" \
    --artifact-kind "$artifact_kind" \
    --system-img "$path" \
    --expected-sha256 "$sha" \
    --artifact-logical-bytes "$logical_bytes" \
    --system-current-bytes "$system_current_bytes" \
    --restore-report "$restore_report" \
    --bootloader-preflight "$bootloader_preflight" \
    --fastbootd-preflight "$fastbootd_preflight" \
    --snapshot-update-status "$snapshot_status" \
    --lp-action "$lp_action" \
    --avb-action "$avb_action" \
    --userdata-policy "$userdata_policy" \
    --explicit-titan-serial "$titan_serial_required" \
    --active-slot "$active_slot" \
    --stock-baseline "$stock_baseline" \
    --restore-path-verified "$restore_verified" \
    --evidence-dir "$evidence_dir"
}
