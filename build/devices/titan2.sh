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
SABLE_DEVICE_PRODUCT_COMPOSITION_SUPPORTED=YES
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO
SABLE_DEVICE_DEFAULT_ACCEPTANCE_SUITE=none
SABLE_DEVICE_ARTIFACT_KINDS="gsi-system-image"
SABLE_DEVICE_FLASH_TRANSPORT=titan2-fastbootd-ledger-only
SABLE_DEVICE_REQUIRES_FASTBOOT=NO

# N1B2 is registered as an audit/composition gate only.
# This does not authorize build, qualify, flash, fastboot, adb, or write-capable flows.
TITAN2_N1B2_RELEASE_GATE=AUDIT_ONLY_FAIL_CLOSED
TITAN2_N1B2_BUILD_SUPPORTED=NO
TITAN2_N1B2_QUALIFY_SUPPORTED=NO
TITAN2_N1B2_FLASH_EXECUTION_SUPPORTED=NO
TITAN2_N1B2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO

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
    N0|N0_A16|N1|N1B|N1B2|N1D|n0|n0_a16|n1|n1b|n1b2|n1d) ;;
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

  if [[ "${release^^}" == N1D ]]; then
    local expected_build_source expected_primary_sha build_state
    expected_build_source="caf98dde723d07a071d95aaa1ef27d578d3208d8"
    expected_primary_sha="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
    build_state="$evidence_dir/build-state.env"

    [[ "$build_source" == "$expected_build_source" ]] || {
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_BUILD_SOURCE expected=$expected_build_source actual=$build_source"
      return 1
    }
    [[ "$primary_sha" == "$expected_primary_sha" ]] || {
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_PRIMARY_SHA256 expected=$expected_primary_sha actual=$primary_sha"
      return 1
    }
    [[ -f "$build_state" ]] || {
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_BUILD_STATE path=$build_state"
      return 1
    }
    grep -Fxq 'N1D_C3B_E3_SYSTEMIMAGE=PASS' "$build_state" || {
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E3_PASS_MARKER"
      return 1
    }
    grep -Fxq "N1D_C3B_E3_CANONICAL_HEAD=$expected_build_source" "$build_state" || {
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E3_BUILD_SOURCE_MARKER"
      return 1
    }
    grep -Fxq "N1D_C3B_E3_SYSTEM_SHA256=$expected_primary_sha" "$build_state" || {
      echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E3_SHA_MARKER"
      return 1
    }
    echo "TITAN2_N1D_C3B_E3_ARTIFACT_GATE=PASS"
    echo "TITAN2_N1D_C3B_E5B_STANDARD_FLASH_PLAN_SUPPORTED=YES"
    echo "TITAN2_N1D_C3B_E5B_FLASH_EXECUTION_SUPPORTED=NO"
  fi

  echo "SABLE_DEVICE_ARTIFACT_GATE=PASS_TITAN2_GSI"
  echo "TITAN2_FLASH_EXECUTION_SUPPORTED=NO"
  echo "TITAN2_N1B2_RELEASE_GATE=AUDIT_ONLY_FAIL_CLOSED"
  echo "TITAN2_N0_N1_FLASH_PLAN_REQUIRED=YES"
}

titan2_n1b2_product_composition_emit() {
  local status="$1"
  local key="$2"
  local detail="${3:-}"

  printf '%s=%s' "$key" "$status"
  [[ -z "$detail" ]] || printf ' %s' "$detail"
  printf '\n'

  case "$status" in
    PASS) composition_passes=$((composition_passes + 1)) ;;
    FAIL) composition_failures=$((composition_failures + 1)) ;;
  esac
}

titan2_n1b2_product_composition_require_file() {
  local key="$1"
  local path="$2"

  [[ -f "$path" ]] \
    && titan2_n1b2_product_composition_emit PASS "$key" "path=$path" \
    || titan2_n1b2_product_composition_emit FAIL "$key" "missing=$path"
}

titan2_n1b2_product_composition_require_text() {
  local key="$1"
  local pattern="$2"
  local path="$3"

  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    titan2_n1b2_product_composition_emit PASS "$key" "pattern=$(printf '%q' "$pattern") path=$path"
  else
    titan2_n1b2_product_composition_emit FAIL "$key" "missing_pattern=$(printf '%q' "$pattern") path=$path"
  fi
}

sable_device_product_composition() {
  local release="$1"
  shift

  local android_root=""
  local active_product_mk="device/phh/treble/treble_arm64_bvN.mk"
  local active_product_path=""
  local profile_mk=""
  local composition_passes=0
  local composition_failures=0

  case "$release" in
    N1B2|n1b2) ;;
    *)
      echo "SABLE_PRODUCT_COMPOSITION=BLOCKED_UNQUALIFIED_TITAN_RELEASE release=$release"
      return 78
      ;;
  esac

  while (($#)); do
    case "$1" in
      --android-root) android_root="${2:-}"; shift 2 ;;
      --active-product-mk) active_product_mk="${2:-}"; shift 2 ;;
      -h|--help)
        cat <<'USAGE'
usage:
  bash build/sable.sh titan2 N1B2 product-composition \
    --android-root <android source root> \
    [--active-product-mk <path relative to android root>]
USAGE
        return 0
        ;;
      *)
        echo "SABLE_PRODUCT_COMPOSITION=FAIL_UNKNOWN_ARG arg=$1"
        return 64
        ;;
    esac
  done

  [[ -n "$android_root" ]] || {
    echo "SABLE_PRODUCT_COMPOSITION=FAIL_ANDROID_ROOT_REQUIRED"
    return 64
  }
  [[ "$active_product_mk" != /* ]] || {
    echo "SABLE_PRODUCT_COMPOSITION=FAIL_ACTIVE_PRODUCT_MK_ABSOLUTE"
    return 64
  }
  [[ -d "$android_root" ]] || {
    echo "SABLE_PRODUCT_COMPOSITION=FAIL_ANDROID_ROOT_NOT_FOUND path=$android_root"
    return 64
  }

  android_root="$(cd "$android_root" && pwd)"
  active_product_path="$android_root/$active_product_mk"
  profile_mk="$android_root/vendor/sable/n1b2/sable_n1b2_product_profile.mk"

  titan2_n1b2_product_composition_profile_has_module() {
    local module="$1"

    sed -E 's/#.*$//' "$profile_mk" \
      | grep -Eq "(^|[^A-Za-z0-9_])${module}([^A-Za-z0-9_]|$)"
  }

  cat <<EOF
===== TITAN2 N1B2 PRODUCT COMPOSITION =====
ROOT=$ROOT
RELEASE=$release
ANDROID_ROOT=$android_root
ACTIVE_PRODUCT_MK=$active_product_mk
ACTIVE_PRODUCT_PATH=$active_product_path
PROFILE_MK=$profile_mk
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
TITAN2_N1B2_RELEASE_GATE=AUDIT_ONLY_FAIL_CLOSED
TITAN2_N1B2_BUILD_SUPPORTED=NO
TITAN2_N1B2_QUALIFY_SUPPORTED=NO
TITAN2_N1B2_FLASH_EXECUTION_SUPPORTED=NO
TITAN2_N1B2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO
EOF

  titan2_n1b2_product_composition_require_file \
    TITAN2_N1B2_ACTIVE_PRODUCT_PRESENT \
    "$active_product_path"
  titan2_n1b2_product_composition_require_file \
    TITAN2_N1B2_PRODUCT_PROFILE_PRESENT \
    "$profile_mk"
  titan2_n1b2_product_composition_require_text \
    TITAN2_N1B2_ACTIVE_PRODUCT_INHERITS_PROFILE \
    "vendor/sable/n1b2/sable_n1b2_product_profile.mk" \
    "$active_product_path"

  titan2_n1b2_product_composition_require_file \
    TITAN2_N1B2_REQUIRED_SOURCE_SABLELAUNCHER_BP \
    "$android_root/packages/apps/SableStart/Android.bp"
  titan2_n1b2_product_composition_require_file \
    TITAN2_N1B2_REQUIRED_SOURCE_SABLELAUNCHER_MANIFEST \
    "$android_root/packages/apps/SableStart/AndroidManifest.xml"
  titan2_n1b2_product_composition_require_file \
    TITAN2_N1B2_REQUIRED_SOURCE_SABLEDESIGN_BP \
    "$android_root/packages/apps/SableDesign/Android.bp"

  if titan2_n1b2_product_composition_profile_has_module SableLauncher; then
    titan2_n1b2_product_composition_emit \
      PASS \
      TITAN2_N1B2_ALLOWED_MODULE_SABLELAUNCHER_SELECTED \
      "module=SableLauncher"
  else
    titan2_n1b2_product_composition_emit \
      FAIL \
      TITAN2_N1B2_ALLOWED_MODULE_SABLELAUNCHER_SELECTED \
      "module_not_selected=SableLauncher"
  fi

  local blocked_modules=(
    SableHub
    SableMail
    SableCalendar
    SableWeather
    SableMedia
    SableMessages
    SablePeople
    SableReader
    SableTextReader
    SableCommand
    SableSettings
    SablePhone
    SableContacts
    SableBrowser
    SableSystemUI
  )

  local module
  local key_module
  for module in "${blocked_modules[@]}"; do
    key_module="${module^^}"
    if titan2_n1b2_product_composition_profile_has_module "$module"; then
      titan2_n1b2_product_composition_emit \
        FAIL \
        "TITAN2_N1B2_BLOCKED_MODULE_${key_module}_NOT_SELECTED" \
        "unexpected_selected_module=$module"
    else
      titan2_n1b2_product_composition_emit \
        PASS \
        "TITAN2_N1B2_BLOCKED_MODULE_${key_module}_NOT_SELECTED" \
        "module_not_selected=$module"
    fi
  done

  echo "TITAN2_N1B2_PRODUCT_COMPOSITION_PASSES=$composition_passes"
  echo "TITAN2_N1B2_PRODUCT_COMPOSITION_FAILURES=$composition_failures"

  if (( composition_failures == 0 )); then
    echo "SABLE_PRODUCT_COMPOSITION=PASS"
    return 0
  fi

  echo "SABLE_PRODUCT_COMPOSITION=FAIL failures=$composition_failures"
  return 1
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
  local e5b_json e5b_json_sha auth_freeze_env auth_freeze_sha build_evidence_dir

  artifact_kind="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifact_kind)" || return 1
  primary="$(sable_device_registry_field "$registry_root" "$release" "$build_source" primary_artifact)" || return 1
  path="$(sable_device_registry_field "$registry_root" "$release" "$build_source" "artifacts.$primary.path")" || return 1
  sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" "artifacts.$primary.sha256")" || return 1

  if [[ "${release^^}" == N1D ]]; then
    e5b_json="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_decision.path 2>/dev/null || true)"
    e5b_json_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_decision.sha256 2>/dev/null || true)"
    auth_freeze_env="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_freeze.path 2>/dev/null || true)"
    auth_freeze_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_freeze.sha256 2>/dev/null || true)"
    build_evidence_dir="$(sable_device_registry_field "$registry_root" "$release" "$build_source" build_evidence_dir 2>/dev/null || true)"

    bash "$ROOT/build/titan2/prepare-n1d-c3b-e5b-flash-plan.sh" \
      --release "$release" \
      --build-source "$build_source" \
      --system-img "$path" \
      --expected-sha256 "$sha" \
      --e5b-json "$e5b_json" \
      --expected-e5b-json-sha256 "$e5b_json_sha" \
      --auth-freeze-env "$auth_freeze_env" \
      --expected-auth-freeze-sha256 "$auth_freeze_sha" \
      --registry-verified PASS \
      --build-evidence-dir "$build_evidence_dir" \
      --evidence-dir "$evidence_dir"
    return
  fi

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
