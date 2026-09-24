#!/usr/bin/env bash
# Device adapter for Pixel 7 / panther.

SABLE_DEVICE_CANONICAL=panther
SABLE_DEVICE_EXPECTED_PRODUCT=panther
SABLE_DEVICE_BUILD_SUPPORTED=YES
SABLE_DEVICE_QUALIFY_SUPPORTED=YES
SABLE_DEVICE_DEFAULT_QUALIFICATION_SUITE=physical-ux
SABLE_DEVICE_FLASH_SUPPORTED=YES
SABLE_DEVICE_FLASH_PLAN_SUPPORTED=YES
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=YES
SABLE_DEVICE_DEFAULT_ACCEPTANCE_SUITE=launcher
SABLE_DEVICE_ARTIFACT_KINDS="target-files"
SABLE_DEVICE_FLASH_TRANSPORT=fastboot-ab-target-files
SABLE_DEVICE_REQUIRES_FASTBOOT=YES
SABLE_DEVICE_POSTBOOT_TIMEOUT=420

sable_device_registry_field() {
  local registry_root="$1"
  local release="$2"
  local build_source="$3"
  local field_name="$4"
  python3 "$ROOT/build/deploy/artifact_registry.py"     --registry-root "$registry_root" field     --device panther     --release "$release"     --build-source "$build_source"     --field "$field_name"
}

sable_device_build() {
  local release="$1"
  local mode="$2"
  SABLE_AUTO_REGISTER_ARTIFACT=YES   SABLEOS_DEVICE=panther     bash "$ROOT/build/panther/run-release.sh" "$release" "$mode"
}

sable_device_qualify() {
  local release="$1"
  local suite="$2"

  case "$release:$suite" in
    R9:physical-ux|r9:physical-ux)
      EXPECTED_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"         bash "$ROOT/build/panther/qualify-r9-physical-ux.sh"
      ;;
    R9:textreader|r9:textreader)
      EXPECTED_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"         bash "$ROOT/build/panther/qualify-r9-textreader.sh"
      ;;
    *)
      echo "SABLE_DEVICE_QUALIFY=UNSUPPORTED device=panther release=$release suite=$suite" >&2
      return 64
      ;;
  esac
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
      SERIAL="$serial"       EVIDENCE_DIR="$evidence"         bash "$ROOT/tests/launcher3/device/r9_home_acceptance.sh"
      ;;
    R9:identity|r9:identity)
      local stamp evidence
      stamp="$(date -u +%Y%m%dT%H%M%SZ)"
      evidence="$evidence_root/panther/r9-physical/${stamp}_system-identity"
      SERIAL="$serial"       EVIDENCE_DIR="$evidence"         bash "$ROOT/tests/systemui/device/r9_identity_audit.sh"
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
  local artifact_kind="$3"
  local primary_sha="$4"
  local evidence_dir="$5"

  [[ "$artifact_kind" == target-files ]] || {
    echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_ARTIFACT_KIND kind=$artifact_kind"
    return 1
  }
  [[ -n "$evidence_dir" && -d "$evidence_dir" ]] || {
    echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_EVIDENCE_DIR"
    return 1
  }

  case "$release" in
    R9|r9)
      local markers=(
        "SOURCE=$build_source"
        "TARGET_FILES_SHA256=$primary_sha"
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

sable_device_flash_plan() {
  local release="$1"
  local build_source="$2"
  local registry_root="$3"
  local evidence_dir="$4"
  local tf tf_sha android_info

  tf="$(sable_device_registry_field "$registry_root" "$release" "$build_source" target_files)"
  tf_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" target_files_sha256)"
  android_info="$(sable_device_registry_field "$registry_root" "$release" "$build_source" android_info)"

  python3 "$ROOT/build/deploy/target_files_plan.py"     --target-files "$tf"     --expected-sha256 "$tf_sha"     --evidence-dir "$evidence_dir"     --android-info "$android_info" || return 1
  echo "SABLE_DEVICE_FLASH_PLAN=PASS_TARGET_FILES_AB"
}

# K2 deployment callbacks.
# They intentionally consume the common flash driver's already-verified globals.

sable_device_flash_prepare_artifact() {
  [[ "$ARTIFACT_KIND" == target-files ]] || {
    echo "SABLE_PANTHER_FLASH_PREPARE=FAIL_ARTIFACT_KIND kind=$ARTIFACT_KIND"
    return 1
  }

  TF="$(field target_files)" || return 1
  EXPECTED_TF_SHA="$(field target_files_sha256)" || return 1
  ANDROID_INFO="$(field android_info)" || return 1
  EXPECTED_ANDROID_INFO_SHA="$(field android_info_sha256)" || return 1

  python3 "$PLAN"     --target-files "$TF"     --expected-sha256 "$EXPECTED_TF_SHA"     --evidence-dir "$EVIDENCE_DIR"     --stage-dir "$STAGE_DIR"     --android-info "$ANDROID_INFO" || return 1

  echo "TARGET_FILES=$TF"
  echo "TARGET_FILES_SHA256=$EXPECTED_TF_SHA"
  echo "ANDROID_INFO=$ANDROID_INFO"
  echo "ANDROID_INFO_SHA256=$EXPECTED_ANDROID_INFO_SHA"
  echo "SABLE_DEVICE_FLASH_ARTIFACT_PREPARE=PASS_TARGET_FILES"
}

sable_device_flash_preflight() {
  SLOT_SUFFIX="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.slot_suffix </dev/null | tr -d '\r')"
  LOCKED="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.flash.locked </dev/null | tr -d '\r')"
  VBMETA="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.vbmeta.device_state </dev/null | tr -d '\r')"

  echo "PRE_SLOT_SUFFIX=$SLOT_SUFFIX"
  echo "PRE_FLASH_LOCKED=$LOCKED"
  echo "PRE_VBMETA_DEVICE_STATE=$VBMETA"

  [[ "$SLOT_SUFFIX" =~ ^_[ab]$ ]] || {
    echo "SABLE_DEVICE_SLOT=FAIL unexpected=$SLOT_SUFFIX"
    return 1
  }
  [[ "$LOCKED" == 0 && "$VBMETA" == unlocked ]] || {
    echo "SABLE_DEVICE_UNLOCKED=FAIL"
    return 1
  }

  SLOT="${SLOT_SUFFIX#_}"
  echo "FLASH_TARGET_SLOT=$SLOT"

  echo "===== PRE-REBOOT ANDROID-INFO ====="
  cat "$ANDROID_INFO" || return 1
  REQUIRED_BOARD="$(sed -n 's/^require board=//p' "$ANDROID_INFO" | tail -n1)"
  [[ -z "$REQUIRED_BOARD" || "$REQUIRED_BOARD" == "$PRE_DEVICE_PRODUCT" ]] || {
    echo "SABLE_ANDROID_INFO_BOARD=FAIL expected=$REQUIRED_BOARD actual=$PRE_DEVICE_PRODUCT"
    return 1
  }

  echo "SABLE_DEVICE_FLASH_PREFLIGHT=PASS_PANTHER_AB"
}

sable_device_flash_execute() {
  echo "===== ENTER BOOTLOADER ====="
  "$ADB_BIN" -s "$SERIAL" reboot bootloader </dev/null || return 1
  REBOOTED_TO_FLASH_MODE=YES
  REBOOTED_TO_BOOTLOADER=YES

  sable_wait_fastboot_ready "$FASTBOOT_BIN" "$SERIAL" "$SABLE_DEVICE_EXPECTED_PRODUCT" 120     || return 1
  sable_require_fastboot_serial_exact_once "$FASTBOOT_BIN" "$SERIAL" || return 1

  FB_SLOT="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" current-slot)"
  FB_UNLOCKED="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" unlocked)"
  FB_BOOTLOADER="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" version-bootloader)"
  FB_BASEBAND="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" version-baseband)"

  echo "FASTBOOT_CURRENT_SLOT=$FB_SLOT"
  echo "FASTBOOT_UNLOCKED=$FB_UNLOCKED"
  echo "FASTBOOT_VERSION_BOOTLOADER=$FB_BOOTLOADER"
  echo "FASTBOOT_VERSION_BASEBAND=$FB_BASEBAND"

  [[ "$FB_SLOT" == "$SLOT" ]] || {
    echo "SABLE_FASTBOOT_SLOT=FAIL expected=$SLOT actual=$FB_SLOT"
    return 1
  }
  case "$FB_UNLOCKED" in yes|true|1) ;; *)
    echo "SABLE_FASTBOOT_UNLOCKED=FAIL"
    return 1
    ;;
  esac

  REQ_BOOTLOADER="$(sed -n 's/^require version-bootloader=//p' "$ANDROID_INFO" | tail -n1)"
  REQ_BASEBAND="$(sed -n 's/^require version-baseband=//p' "$ANDROID_INFO" | tail -n1)"
  if [[ -n "$REQ_BOOTLOADER" && "$FB_BOOTLOADER" != "$REQ_BOOTLOADER" ]]; then
    echo "SABLE_BOOTLOADER_REQUIREMENT=FAIL expected=$REQ_BOOTLOADER actual=$FB_BOOTLOADER"
    return 1
  fi
  if [[ -n "$REQ_BASEBAND" && "$FB_BASEBAND" != "$REQ_BASEBAND" ]]; then
    echo "SABLE_BASEBAND_REQUIREMENT=FAIL expected=$REQ_BASEBAND actual=$FB_BASEBAND"
    return 1
  fi

  while IFS= read -r part; do
    [[ -n "$part" ]] || continue
    has_slot="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" "has-slot:$part")"
    echo "FASTBOOT_PARTITION_EXISTS partition=$part has_slot=${has_slot:-UNOBSERVABLE}"
    case "$has_slot" in yes|no) ;; *)
      echo "SABLE_REQUIRED_PARTITION=FAIL partition=$part"
      return 1
      ;;
    esac
  done < <(sed -n 's/^require partition-exists=//p' "$ANDROID_INFO")
  echo "SABLE_FASTBOOT_PREFLASH_REQUIREMENTS=PASS"

  echo "===== VERIFY STAGED PAYLOAD BEFORE WRITE ====="
  (
    cd "$STAGE_DIR"
    sha256sum -c SHA256SUMS.txt
  ) || return 1
  echo "SABLE_STAGED_PAYLOAD_VERIFY=PASS"

  echo "===== CONTROLLED CURRENT-SLOT PRESERVED-DATA FLASH ====="
  echo "FLASH_METHOD=FASTBOOT_FLASHALL_STAGED_CURRENT_SLOT"
  echo "FLASH_TARGET_SLOT=$SLOT"
  echo "FLASH_SKIP_SECONDARY=YES"
  echo "FLASH_SKIP_REBOOT=YES"
  echo "FLASH_WIPE=NO"
  echo "FLASH_ANDROID_PRODUCT_OUT=$STAGE_DIR"

  FLASH_STARTED=YES
  set +e
  ANDROID_PRODUCT_OUT="$STAGE_DIR"     "$FASTBOOT_BIN" -s "$SERIAL"       --slot "$SLOT"       --set-active="$SLOT"       --skip-secondary       --skip-reboot       flashall       </dev/null 2>&1 | tee "$EVIDENCE_DIR/fastboot-flashall.log"
  FLASH_RC=${PIPESTATUS[0]}
  set -e
  echo "FASTBOOT_FLASHALL_RC=$FLASH_RC"
  if [[ "$FLASH_RC" -ne 0 ]]; then
    echo "FINAL_REBOOT_SUPPRESSED_DUE_TO_FLASH_FAILURE=YES"
    return 1
  fi

  sable_wait_fastboot_ready "$FASTBOOT_BIN" "$SERIAL" "$SABLE_DEVICE_EXPECTED_PRODUCT" 120     || return 1
  POST_SLOT="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" current-slot)"
  echo "POST_FLASH_PRE_REBOOT_SLOT=$POST_SLOT"
  if [[ "$POST_SLOT" != "$SLOT" ]]; then
    echo "FINAL_REBOOT_SUPPRESSED_DUE_TO_SLOT_MISMATCH=YES"
    return 1
  fi
  echo "SABLE_FLASH_EXECUTION=PASS"
  echo "SABLE_POSTFLASH_SLOT_PRESERVED=PASS"

  "$FASTBOOT_BIN" -s "$SERIAL" reboot </dev/null || return 1
  POSTFLASH_REBOOT_SENT=YES
  echo "FINAL_FASTBOOT_REBOOT=PASS"
}

sable_device_flash_recover_prewrite() {
  "$FASTBOOT_BIN" -s "$SERIAL" reboot </dev/null >/dev/null 2>&1 || return 1
  sable_wait_adb_boot_completed "$ADB_BIN" "$SERIAL" 300
}

sable_device_flash_postboot() {
  set +e
  sable_run_sablectl "$ROOT"     --adb "$ADB_BIN"     --serial "$SERIAL"     --output-root "$EVIDENCE_DIR/sablectl"     smoke     --target-files "$TF"     --baseline "$BASELINE"     --expected-device "$SABLE_DEVICE_EXPECTED_PRODUCT"     --expected-slot "$SLOT"     --hash-container     2>&1 | tee "$EVIDENCE_DIR/sablectl-smoke.log"
  SMOKE_RC=${PIPESTATUS[0]}
  set -e
  [[ "$SMOKE_RC" -eq 0 ]] || {
    echo "SABLE_POSTFLASH_SMOKE=FAIL rc=$SMOKE_RC"
    return 1
  }
  echo "SABLE_POSTFLASH_SMOKE=PASS"
}
