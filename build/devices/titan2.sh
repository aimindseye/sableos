#!/usr/bin/env bash
# Titan 2 adapter.
# N1I enables the canonical Android 16 cellular-isolation systemimage build.
# Flash execution remains separately fail-closed until an artifact-specific
# physical acceptance scope is admitted.

SABLE_DEVICE_CANONICAL=titan2
SABLE_DEVICE_EXPECTED_PRODUCT=UNQUALIFIED
SABLE_DEVICE_BUILD_SUPPORTED=YES
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

# N1D C3B E5B standardized execution qualification.
# Static Titan flash defaults remain fail-closed. sable_device_flash_policy()
# may open only this exact sealed N1D scope after an explicit scope token.
TITAN2_N1D_E5B_BUILD_SOURCE="caf98dde723d07a071d95aaa1ef27d578d3208d8"
TITAN2_N1D_E5B_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
TITAN2_N1D_E5B_DECISION_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
TITAN2_N1D_E5B_FREEZE_SHA256="a5df48f0e77c9372dadc1a7453f0bc265c1a01733132c0b50d4969ba2c041e3a"
TITAN2_N1D_E5B_PLAN_SEAL_SHA256="62f92bff11821979b070b5568038dbae132e6714c87b9b43016be9c5ae503d69"
TITAN2_N1D_E5B_SYSTEM_CURRENT_BYTES=757059584
TITAN2_N1D_E5B_SYSTEM_LOGICAL_BYTES=2994405376
TITAN2_N1D_E5B_SUPER_BYTES=9663676416
TITAN2_N1D_E5B_TARGET_PARTITION=system_a
TITAN2_N1D_E5B_EXPECTED_SLOT=a
TITAN2_N1D_E5B_EXPECTED_FASTBOOT_PRODUCT=Titan_2
TITAN2_N1D_E5B_SCOPE_TOKEN="N1D-C3B-E5B:system_a:2994405376:62f92bff11821979b070b5568038dbae132e6714c87b9b43016be9c5ae503d69"

TITAN2_N1D_E6_BUILD_SOURCE="36d5ee13f5a05b2ac19aeedf0b653a244e1eee3e"
TITAN2_N1D_E6_SYSTEM_SHA256="a048bde792636338cba4cab18301422179a7aa3322e7bd747f3218e90750502e"
TITAN2_N1D_E6_SYSTEM_CURRENT_BYTES=2994405376
TITAN2_N1D_E6_SYSTEM_LOGICAL_BYTES=2994388992
TITAN2_N1D_E6_SUPER_BYTES=9663676416
TITAN2_N1D_E6_TARGET_PARTITION=system_a
TITAN2_N1D_E6_EXPECTED_SLOT=a
TITAN2_N1D_E6_EXPECTED_FASTBOOT_PRODUCT=Titan_2
TITAN2_N1D_E6_SCOPE_PREFIX="N1D-C3B-E6-BM001:system_a:2994388992:"

# C3A diagnostic compatibility control.
# Registration and no-write flash-plan generation are qualified here.
# Physical execution remains blocked until a later plan-seal-bound scope change.
TITAN2_N1D_C3A_BUILD_SOURCE="e6bcd76885c6048da7cbd9f200a9b1102e6d91a2"
TITAN2_N1D_C3A_SYSTEM_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
TITAN2_N1D_C3A_SYSTEM_CURRENT_BYTES=2994388992
TITAN2_N1D_C3A_SYSTEM_LOGICAL_BYTES=3146977280
TITAN2_N1D_C3A_SUPER_BYTES=9663676416
TITAN2_N1D_C3A_TARGET_PARTITION=system_a
TITAN2_N1D_C3A_EXPECTED_SLOT=a
TITAN2_N1D_C3A_EXPECTED_FASTBOOT_PRODUCT=Titan_2
TITAN2_N1D_C3A_PREFLIGHT_SEAL_SHA256="47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893"
TITAN2_N1D_C3A_OFFLINE_SEAL_SHA256="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"
TITAN2_N1D_C3A_BASELINE_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
TITAN2_N1D_C3A_EXECUTION_SUPPORTED=NO_PENDING_PLAN_SCOPE

sable_device_flash_policy() {
  local release="$1"
  local build_source="$2"
  local scope_token="$3"

  [[ "${release^^}" == N1D ]] || {
    echo "TITAN2_STANDARD_FLASH_POLICY=BLOCKED_RELEASE release=$release"
    return 78
  }

  TITAN2_N1D_ACTIVE_PROFILE=""
  TITAN2_N1D_ACTIVE_BUILD_SOURCE=""
  TITAN2_N1D_ACTIVE_SYSTEM_SHA256=""
  TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES=""
  TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES=""
  TITAN2_N1D_ACTIVE_SUPER_BYTES=""
  TITAN2_N1D_ACTIVE_TARGET_PARTITION=""
  TITAN2_N1D_ACTIVE_EXPECTED_SLOT=""
  TITAN2_N1D_ACTIVE_EXPECTED_FASTBOOT_PRODUCT=""
  TITAN2_N1D_ACTIVE_PLAN_SEAL_SHA256=""

  case "$build_source" in
    "$TITAN2_N1D_E5B_BUILD_SOURCE")
      [[ "$scope_token" == "$TITAN2_N1D_E5B_SCOPE_TOKEN" ]] || {
        echo "TITAN2_STANDARD_FLASH_POLICY=BLOCKED_SCOPE_TOKEN"
        return 78
      }
      TITAN2_N1D_ACTIVE_PROFILE=E5B
      TITAN2_N1D_ACTIVE_BUILD_SOURCE="$TITAN2_N1D_E5B_BUILD_SOURCE"
      TITAN2_N1D_ACTIVE_SYSTEM_SHA256="$TITAN2_N1D_E5B_SYSTEM_SHA256"
      TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES="$TITAN2_N1D_E5B_SYSTEM_CURRENT_BYTES"
      TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES="$TITAN2_N1D_E5B_SYSTEM_LOGICAL_BYTES"
      TITAN2_N1D_ACTIVE_SUPER_BYTES="$TITAN2_N1D_E5B_SUPER_BYTES"
      TITAN2_N1D_ACTIVE_TARGET_PARTITION="$TITAN2_N1D_E5B_TARGET_PARTITION"
      TITAN2_N1D_ACTIVE_EXPECTED_SLOT="$TITAN2_N1D_E5B_EXPECTED_SLOT"
      TITAN2_N1D_ACTIVE_EXPECTED_FASTBOOT_PRODUCT="$TITAN2_N1D_E5B_EXPECTED_FASTBOOT_PRODUCT"
      TITAN2_N1D_ACTIVE_PLAN_SEAL_SHA256="$TITAN2_N1D_E5B_PLAN_SEAL_SHA256"
      ;;
    "$TITAN2_N1D_E6_BUILD_SOURCE")
      [[ "$scope_token" == "$TITAN2_N1D_E6_SCOPE_PREFIX"* ]] || {
        echo "TITAN2_STANDARD_FLASH_POLICY=BLOCKED_E6_SCOPE_PREFIX"
        return 78
      }
      TITAN2_N1D_ACTIVE_PLAN_SEAL_SHA256="${scope_token#"$TITAN2_N1D_E6_SCOPE_PREFIX"}"
      [[ "$TITAN2_N1D_ACTIVE_PLAN_SEAL_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
        echo "TITAN2_STANDARD_FLASH_POLICY=BLOCKED_E6_PLAN_SEAL"
        return 78
      }
      TITAN2_N1D_ACTIVE_PROFILE=E6_BM001
      TITAN2_N1D_ACTIVE_BUILD_SOURCE="$TITAN2_N1D_E6_BUILD_SOURCE"
      TITAN2_N1D_ACTIVE_SYSTEM_SHA256="$TITAN2_N1D_E6_SYSTEM_SHA256"
      TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES="$TITAN2_N1D_E6_SYSTEM_CURRENT_BYTES"
      TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES="$TITAN2_N1D_E6_SYSTEM_LOGICAL_BYTES"
      TITAN2_N1D_ACTIVE_SUPER_BYTES="$TITAN2_N1D_E6_SUPER_BYTES"
      TITAN2_N1D_ACTIVE_TARGET_PARTITION="$TITAN2_N1D_E6_TARGET_PARTITION"
      TITAN2_N1D_ACTIVE_EXPECTED_SLOT="$TITAN2_N1D_E6_EXPECTED_SLOT"
      TITAN2_N1D_ACTIVE_EXPECTED_FASTBOOT_PRODUCT="$TITAN2_N1D_E6_EXPECTED_FASTBOOT_PRODUCT"
      ;;
    *)
      echo "TITAN2_STANDARD_FLASH_POLICY=BLOCKED_BUILD_SOURCE"
      return 78
      ;;
  esac

  SABLE_DEVICE_EXPECTED_PRODUCT="$TITAN2_N1D_ACTIVE_EXPECTED_FASTBOOT_PRODUCT"
  SABLE_DEVICE_FLASH_SUPPORTED=YES
  SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=YES
  SABLE_DEVICE_REQUIRES_FASTBOOT=YES
  SABLE_DEVICE_FLASH_ENTRY_MODE=fastbootd
  SABLE_DEVICE_PRESERVED_DATA_BASELINE_REQUIRED=NO
  SABLE_DEVICE_POSTBOOT_POLICY=adapter-observe
  SABLE_DEVICE_POSTBOOT_TIMEOUT=240
  SABLE_DEVICE_FLASH_TRANSPORT=titan2-fastbootd-active-system-a

  echo "TITAN2_STANDARD_FLASH_POLICY=PASS_N1D_SCOPED"
  echo "TITAN2_N1D_EXECUTION_PROFILE=$TITAN2_N1D_ACTIVE_PROFILE"
  echo "TITAN2_N1D_TARGET_PARTITION=$TITAN2_N1D_ACTIVE_TARGET_PARTITION"
  echo "TITAN2_N1D_PREFLASH_SYSTEM_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES"
  echo "TITAN2_N1D_IMPLICIT_RESIZE_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES"
}
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
  local release="$1"
  local mode="$2"

  case "$release" in
    N1I|n1i)
      EXPECTED_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)" \
        bash "$ROOT/build/titan2/run-n1i-c1-cellular-isolation.sh" N1I "$mode"
      ;;
    *)
      echo "SABLE_DEVICE_BUILD=BLOCKED_UNQUALIFIED device=titan2 release=$release" >&2
      return 78
      ;;
  esac
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
    N0|N0_A16|N1|N1B|N1B2|N1D|N1I|n0|n0_a16|n1|n1b|n1b2|n1d|n1i) ;;
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
    local build_state

    case "$build_source" in
      "$TITAN2_N1D_E5B_BUILD_SOURCE")
        [[ "$primary_sha" == "$TITAN2_N1D_E5B_SYSTEM_SHA256" ]] || {
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E5B_PRIMARY_SHA256"
          return 1
        }
        build_state="$evidence_dir/build-state.env"
        [[ -f "$build_state" ]] || {
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E5B_BUILD_STATE path=$build_state"
          return 1
        }
        grep -Fxq 'N1D_C3B_E3_SYSTEMIMAGE=PASS' "$build_state" || return 1
        grep -Fxq "N1D_C3B_E3_CANONICAL_HEAD=$TITAN2_N1D_E5B_BUILD_SOURCE" "$build_state" || return 1
        grep -Fxq "N1D_C3B_E3_SYSTEM_SHA256=$TITAN2_N1D_E5B_SYSTEM_SHA256" "$build_state" || return 1
        echo "TITAN2_N1D_C3B_E3_ARTIFACT_GATE=PASS"
        ;;
      "$TITAN2_N1D_E6_BUILD_SOURCE")
        [[ "$primary_sha" == "$TITAN2_N1D_E6_SYSTEM_SHA256" ]] || {
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E6_PRIMARY_SHA256"
          return 1
        }
        build_state="$evidence_dir/e6-state.env"
        [[ -f "$build_state" ]] || {
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E6_BUILD_STATE path=$build_state"
          return 1
        }
        for marker in \
          'N1D_C3B_E6_SYSTEMIMAGE=PASS' \
          "N1D_C3B_E6_CANONICAL_HEAD=$TITAN2_N1D_E6_BUILD_SOURCE" \
          'N1D_C3B_E6_RUNTIME_PATCH_COUNT=1' \
          'N1D_C3B_E6_RUNTIME_PATCH=BM-001_REMOVE_INIT_VNDK_NODEF' \
          'N1D_C3B_E6_VNDK28_SEPOLICY_ADMISSION=NO' \
          "N1D_C3B_E6_SYSTEM_SHA256=$TITAN2_N1D_E6_SYSTEM_SHA256" \
          "N1D_C3B_E6_SYSTEM_BYTES=$TITAN2_N1D_E6_SYSTEM_LOGICAL_BYTES" \
          'N1D_C3B_E6_SABLE_MODULE_COUNT=5'
        do
          grep -Fxq -- "$marker" "$build_state" || {
            echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_E6_MARKER marker=$marker"
            return 1
          }
        done
        echo "TITAN2_N1D_C3B_E6_ARTIFACT_GATE=PASS"
        ;;
      "$TITAN2_N1D_C3A_BUILD_SOURCE")
        [[ "$primary_sha" == "$TITAN2_N1D_C3A_SYSTEM_SHA256" ]] || {
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_C3A_PRIMARY_SHA256"
          return 1
        }
        local c3a_env="$ROOT/build/titan2/n1d-c3a-control-evidence.env"
        [[ -f "$c3a_env" ]] || {
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_C3A_EVIDENCE_ENV path=$c3a_env"
          return 1
        }
        for marker in \
          'N1D_C3A_CONTROL_EVIDENCE_STATUS=PASS_SYSTEMIMAGE' \
          "N1D_C3A_REGISTRY_BUILD_SOURCE=$TITAN2_N1D_C3A_BUILD_SOURCE" \
          'N1D_C3A_REGISTRY_BUILD_SOURCE_ROLE=POSTBUILD_EVIDENCE_SEAL_COMMIT_NOT_RECORDED_BUILD_START_HEAD' \
          "N1D_C3A_SYSTEM_SHA256=$TITAN2_N1D_C3A_SYSTEM_SHA256" \
          "N1D_C3A_SYSTEM_BYTES=$TITAN2_N1D_C3A_SYSTEM_LOGICAL_BYTES" \
          'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION' \
          'N1D_C3A_MANAGED_PROJECT_COUNT=991' \
          'N1D_C3A_CONTROL_PATCH_COUNT=369'
        do
          grep -Fxq -- "$marker" "$c3a_env" || {
            echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_C3A_MARKER marker=$marker"
            return 1
          }
        done
        grep -Fxq "N1D_C3A_EVIDENCE_DIR=$evidence_dir" "$c3a_env" || {
          echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_C3A_BUILD_EVIDENCE_DIR actual=$evidence_dir"
          return 1
        }
        echo "TITAN2_N1D_C3A_ARTIFACT_GATE=PASS_CONTROL_ONLY"
        echo "TITAN2_N1D_C3A_FLASH_EXECUTION_SUPPORTED=NO_PENDING_PLAN_SCOPE"
        ;;
      *)
        echo "SABLE_DEVICE_ARTIFACT_GATE=FAIL_N1D_BUILD_SOURCE actual=$build_source"
        return 1
        ;;
    esac

    echo "TITAN2_N1D_STANDARD_FLASH_PLAN_SUPPORTED=YES"
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
  local c3a_preflight c3a_preflight_sha c3a_preflight_sums c3a_preflight_sums_sha
  local c3a_offline_plan c3a_offline_plan_sha c3a_offline_sums c3a_offline_sums_sha
  local c3a_baseline_e5a c3a_baseline_e5a_sha c3a_baseline_e5b c3a_baseline_e5b_sha

  artifact_kind="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifact_kind)" || return 1
  primary="$(sable_device_registry_field "$registry_root" "$release" "$build_source" primary_artifact)" || return 1
  path="$(sable_device_registry_field "$registry_root" "$release" "$build_source" "artifacts.$primary.path")" || return 1
  sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" "artifacts.$primary.sha256")" || return 1

  if [[ "${release^^}" == N1D ]]; then
    build_evidence_dir="$(sable_device_registry_field "$registry_root" "$release" "$build_source" build_evidence_dir 2>/dev/null || true)"

    if [[ "$build_source" == "$TITAN2_N1D_C3A_BUILD_SOURCE" ]]; then
      c3a_preflight="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_preflight.path)" || return 1
      c3a_preflight_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_preflight.sha256)" || return 1
      c3a_preflight_sums="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_preflight_sums.path)" || return 1
      c3a_preflight_sums_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_preflight_sums.sha256)" || return 1
      c3a_offline_plan="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_offline_plan.path)" || return 1
      c3a_offline_plan_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_offline_plan.sha256)" || return 1
      c3a_offline_sums="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_offline_sums.path)" || return 1
      c3a_offline_sums_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_offline_sums.sha256)" || return 1
      c3a_baseline_e5a="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_baseline_e5a.path)" || return 1
      c3a_baseline_e5a_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_baseline_e5a.sha256)" || return 1
      c3a_baseline_e5b="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_baseline_e5b.path)" || return 1
      c3a_baseline_e5b_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.c3a_baseline_e5b.sha256)" || return 1

      bash "$ROOT/build/titan2/prepare-c3a-v010014-standard-flash-plan.sh" \
        --release "$release" \
        --build-source "$build_source" \
        --system-img "$path" \
        --expected-system-sha256 "$sha" \
        --preflight-json "$c3a_preflight" \
        --preflight-json-sha256 "$c3a_preflight_sha" \
        --preflight-sums "$c3a_preflight_sums" \
        --preflight-sums-sha256 "$c3a_preflight_sums_sha" \
        --offline-plan "$c3a_offline_plan" \
        --offline-plan-sha256 "$c3a_offline_plan_sha" \
        --offline-sums "$c3a_offline_sums" \
        --offline-sums-sha256 "$c3a_offline_sums_sha" \
        --baseline-e5a "$c3a_baseline_e5a" \
        --baseline-e5a-sha256 "$c3a_baseline_e5a_sha" \
        --baseline-e5b "$c3a_baseline_e5b" \
        --baseline-e5b-sha256 "$c3a_baseline_e5b_sha" \
        --registry-verified PASS \
        --build-evidence-dir "$build_evidence_dir" \
        --evidence-dir "$evidence_dir"
      return
    fi

    e5b_json="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_decision.path 2>/dev/null || true)"
    e5b_json_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_decision.sha256 2>/dev/null || true)"
    auth_freeze_env="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_freeze.path 2>/dev/null || true)"
    auth_freeze_sha="$(sable_device_registry_field "$registry_root" "$release" "$build_source" artifacts.e5b_freeze.sha256 2>/dev/null || true)"
    if [[ "$build_source" == "$TITAN2_N1D_E6_BUILD_SOURCE" ]]; then
      bash "$ROOT/build/titan2/prepare-n1d-c3b-e6-bm001-flash-plan.sh" \
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
    else
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
    fi
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


# N1D C3B E5B standardized physical execution callbacks.
# They are reachable only after sable_device_flash_policy() opens the exact
# release/build/plan scope. There is no standalone Titan write entrypoint.

titan2_n1d_find_plan_dir() {
  local plan_root="$EVIDENCE_ROOT/titan2/n1d-physical"
  local sums seal
  local -a matches=()

  [[ "$TITAN2_N1D_ACTIVE_PLAN_SEAL_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
    echo "TITAN2_N1D_PLAN_BINDING=FAIL_PLAN_SEAL"
    return 1
  }
  [[ -d "$plan_root" ]] || {
    echo "TITAN2_N1D_PLAN_BINDING=FAIL_PLAN_ROOT path=$plan_root"
    return 1
  }

  while IFS= read -r sums; do
    [[ -f "$sums" ]] || continue
    seal="$(sha256sum "$sums" | awk '{print $1}')"
    [[ "$seal" == "$TITAN2_N1D_ACTIVE_PLAN_SEAL_SHA256" ]] &&
      matches+=("$(dirname "$sums")")
  done < <(
    find "$plan_root" -mindepth 2 -maxdepth 2 -type f -name SHA256SUMS.txt -print 2>/dev/null |
      LC_ALL=C sort
  )

  [[ "${#matches[@]}" -eq 1 ]] || {
    echo "TITAN2_N1D_PLAN_BINDING=FAIL_MATCH_COUNT count=${#matches[@]}"
    return 1
  }

  TITAN2_N1D_BOUND_PLAN_DIR="${matches[0]}"
  echo "TITAN2_N1D_PLAN_BINDING=PASS"
  echo "TITAN2_N1D_PLAN_DIR=$TITAN2_N1D_BOUND_PLAN_DIR"
}

sable_device_flash_prepare_artifact() {
  [[ "${RELEASE^^}" == N1D ]] || return 1
  [[ "$BUILD_SOURCE" == "$TITAN2_N1D_ACTIVE_BUILD_SOURCE" ]] || return 1
  [[ "$ARTIFACT_KIND" == gsi-system-image ]] || return 1
  [[ "$PRIMARY_ARTIFACT" == system ]] || return 1
  [[ "$PRIMARY_SHA" == "$TITAN2_N1D_ACTIVE_SYSTEM_SHA256" ]] || return 1
  [[ -f "$PRIMARY_PATH" ]] || return 1

  E5B_JSON="$(field artifacts.e5b_decision.path)" || return 1
  E5B_JSON_SHA="$(field artifacts.e5b_decision.sha256)" || return 1
  E5B_FREEZE="$(field artifacts.e5b_freeze.path)" || return 1
  E5B_FREEZE_SHA="$(field artifacts.e5b_freeze.sha256)" || return 1

  [[ "$E5B_JSON_SHA" == "$TITAN2_N1D_E5B_DECISION_SHA256" ]] || return 1
  [[ "$E5B_FREEZE_SHA" == "$TITAN2_N1D_E5B_FREEZE_SHA256" ]] || return 1

  titan2_n1d_find_plan_dir || return 1

  (
    cd "$TITAN2_N1D_BOUND_PLAN_DIR"
    sha256sum -c SHA256SUMS.txt
  ) > "$EVIDENCE_DIR/flash-plan-seal-verify.txt" || return 1

  case "$TITAN2_N1D_ACTIVE_PROFILE" in
    E5B)
      TITAN2_N1D_BOUND_PLAN="$TITAN2_N1D_BOUND_PLAN_DIR/titan2-n1d-c3b-e5b-standard-flash-plan.txt"
      PLAN_START_MARKER="N1D_C3B_E5B_STANDARD_FLASH_PLAN=PREPARED_NO_WRITE"
      PREFLASH_SIZE_MARKER="EXPECTED_SYSTEM_CURRENT_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES"
      ;;
    E6_BM001)
      TITAN2_N1D_BOUND_PLAN="$TITAN2_N1D_BOUND_PLAN_DIR/titan2-n1d-c3b-e6-bm001-standard-flash-plan.txt"
      PLAN_START_MARKER="N1D_C3B_E6_STANDARD_FLASH_PLAN=PREPARED_NO_WRITE"
      PREFLASH_SIZE_MARKER="EXPECTED_PREFLASH_SYSTEM_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES"
      ;;
    *)
      return 1
      ;;
  esac
  [[ -f "$TITAN2_N1D_BOUND_PLAN" ]] || return 1

  local marker
  for marker in \
    "$PLAN_START_MARKER" \
    "BUILD_SOURCE=$TITAN2_N1D_ACTIVE_BUILD_SOURCE" \
    "SYSTEM_SHA256=$TITAN2_N1D_ACTIVE_SYSTEM_SHA256" \
    "SYSTEM_FORMAT=raw" \
    "SYSTEM_LOGICAL_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" \
    "$PREFLASH_SIZE_MARKER" \
    "TARGET_PARTITION=$TITAN2_N1D_ACTIVE_TARGET_PARTITION" \
    "EXPECTED_ACTIVE_SLOT=$TITAN2_N1D_ACTIVE_EXPECTED_SLOT" \
    "EXPECTED_SUPER_BYTES=$TITAN2_N1D_ACTIVE_SUPER_BYTES" \
    "EXPECTED_ACTIVE_COW_COUNT=0" \
    "FASTBOOT_IMPLICIT_RESIZE=YES" \
    "FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" \
    "MANUAL_PRE_RESIZE_REQUIRED=NO" \
    "COW_DELETION_ALLOWED=NO" \
    "SLOT_CHANGE_ALLOWED=NO" \
    "AVB_MUTATION_ALLOWED=NO" \
    "BOOT_CHAIN_FLASH_ALLOWED=NO" \
    "WHOLE_SUPER_FLASH_ALLOWED=NO" \
    "USERDATA_ERASE_ALLOWED=NO" \
    "FACTORY_RESET_ALLOWED=NO" \
    "E5B_DECISION_PACKAGE_SHA256=$TITAN2_N1D_E5B_DECISION_SHA256" \
    "E5B_MANUAL_AUTH_FREEZE_SHA256=$TITAN2_N1D_E5B_FREEZE_SHA256"
  do
    grep -Fxq -- "$marker" "$TITAN2_N1D_BOUND_PLAN" || {
      echo "TITAN2_N1D_PLAN_MARKER=FAIL marker=$marker"
      return 1
    }
  done

  python3 "$ROOT/build/deploy/gsi_image_info.py" --image "$PRIMARY_PATH" \
    > "$EVIDENCE_DIR/system-image-geometry.txt" || return 1
  grep -Fxq "GSI_IMAGE_FORMAT=raw" "$EVIDENCE_DIR/system-image-geometry.txt" || return 1
  grep -Fxq "GSI_IMAGE_FILE_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" "$EVIDENCE_DIR/system-image-geometry.txt" || return 1
  grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" "$EVIDENCE_DIR/system-image-geometry.txt" || return 1

  E5A_JSON="$(dirname "$E5B_JSON")/e5a-readonly-device-state.json"
  [[ -f "$E5A_JSON" ]] || {
    echo "TITAN2_N1D_E5A_BINDING=FAIL_MISSING path=$E5A_JSON"
    return 1
  }

  local bindings="$EVIDENCE_DIR/e5a-execution-bindings.env"
  python3 - \
    "$E5B_JSON" \
    "$E5A_JSON" \
    "$TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES" \
    "$bindings" <<'PY'
from __future__ import annotations
import hashlib
import json
import pathlib
import sys

decision_path = pathlib.Path(sys.argv[1])
e5a_path = pathlib.Path(sys.argv[2])
current_system_bytes = int(sys.argv[3])
out = pathlib.Path(sys.argv[4])

decision = json.loads(decision_path.read_text(encoding="utf-8"))
e5a = json.loads(e5a_path.read_text(encoding="utf-8"))
actual_e5a_sha = hashlib.sha256(e5a_path.read_bytes()).hexdigest()
expected_e5a_sha = str(decision.get("e5a_source_json_sha256", ""))

if not expected_e5a_sha or actual_e5a_sha != expected_e5a_sha:
    raise SystemExit("TITAN2_N1D_E5A_BINDING=FAIL_SHA256")
if e5a.get("final_state") != "PASS_REVIEW_READY":
    raise SystemExit("TITAN2_N1D_E5A_BINDING=FAIL_FINAL_STATE")
if e5a.get("device_binding_verified") is not True:
    raise SystemExit("TITAN2_N1D_E5A_BINDING=FAIL_DEVICE_BINDING")

fastboot_hash = str(e5a.get("fastboot_device_binding_sha256", ""))
adb_hash = str(e5a.get("adb_device_binding_sha256", ""))
if len(fastboot_hash) != 64 or len(adb_hash) != 64:
    raise SystemExit("TITAN2_N1D_E5A_BINDING=FAIL_SERIAL_HASH")

baseline_allocated = int(decision.get("all_materialized_logical_bytes", 0))
baseline_system = int(decision.get("active_system_current_bytes", 0))
if baseline_allocated <= 0 or baseline_system <= 0:
    raise SystemExit("TITAN2_N1D_E5A_BINDING=FAIL_ALLOCATED_BYTES")
expected_allocated = baseline_allocated - baseline_system + current_system_bytes

out.write_text(
    "\n".join([
        f"EXPECTED_E5A_SHA256={expected_e5a_sha}",
        f"EXPECTED_FASTBOOT_BINDING_SHA256={fastboot_hash}",
        f"EXPECTED_ADB_BINDING_SHA256={adb_hash}",
        f"EXPECTED_MATERIALIZED_LOGICAL_BYTES={expected_allocated}",
        "",
    ]),
    encoding="utf-8",
)
PY
  [[ -f "$bindings" ]] || return 1
  # shellcheck source=/dev/null
  source "$bindings"

  echo "TITAN2_N1D_E5A_BINDING=PASS"
  echo "TITAN2_N1D_ARTIFACT_PREPARE=PASS profile=$TITAN2_N1D_ACTIVE_PROFILE"
}
sable_device_flash_preflight() {
  [[ "$SABLE_DEVICE_FLASH_ENTRY_MODE" == fastbootd ]] || return 1
  sable_require_fastboot_serial_exact_once "$FASTBOOT_BIN" "$SERIAL" || return 1

  local live_fastboot_hash
  live_fastboot_hash="$(printf '%s' "$SERIAL" | sha256sum | awk '{print $1}')"
  [[ "$live_fastboot_hash" == "$EXPECTED_FASTBOOT_BINDING_SHA256" ]] || {
    echo "TITAN2_N1D_FASTBOOT_SERIAL_BINDING=FAIL"
    return 1
  }
  echo "TITAN2_N1D_FASTBOOT_SERIAL_BINDING=PASS"

  LIVE_GETVAR_ALL="$EVIDENCE_DIR/fastboot-getvar-all-prewrite.txt"
  set +e
  "$FASTBOOT_BIN" -s "$SERIAL" getvar all </dev/null > "$LIVE_GETVAR_ALL" 2>&1
  local getvar_rc=$?
  set -e
  [[ "$getvar_rc" -eq 0 ]] || {
    echo "TITAN2_N1D_GETVAR_ALL=FAIL rc=$getvar_rc"
    return 1
  }

  LIVE_STATE_ENV="$EVIDENCE_DIR/fastboot-live-state.env"
  python3 - \
    "$LIVE_GETVAR_ALL" \
    "$TITAN2_N1D_ACTIVE_EXPECTED_FASTBOOT_PRODUCT" \
    "$TITAN2_N1D_ACTIVE_EXPECTED_SLOT" \
    "$TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES" \
    "$TITAN2_N1D_ACTIVE_SUPER_BYTES" \
    "$EXPECTED_MATERIALIZED_LOGICAL_BYTES" \
    "$LIVE_STATE_ENV" <<'PY'
from __future__ import annotations
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
expected_product = sys.argv[2]
expected_slot = sys.argv[3]
expected_system = int(sys.argv[4])
expected_super = int(sys.argv[5])
expected_allocated = int(sys.argv[6])
out = pathlib.Path(sys.argv[7])

values: dict[str, str] = {}
for raw in src.read_text(encoding="utf-8", errors="replace").splitlines():
    line = re.sub(r"^\s*\([^)]*\)\s*", "", raw.strip())
    if not line:
        continue
    match = re.match(r"^(.+):\s*([^:]+)$", line)
    if match:
        values.setdefault(match.group(1).strip(), match.group(2).strip())

def parse_int(value: str) -> int:
    token = value.strip().split()[0] if value.strip() else ""
    try:
        return int(token, 0)
    except ValueError:
        return 0

required = {
    "product": expected_product,
    "current-slot": expected_slot,
    "is-userspace": "yes",
    "unlocked": "yes",
    "snapshot-update-status": "none",
    "is-logical:system_a": "yes",
}
for key, expected in required.items():
    actual = values.get(key, "")
    if actual.lower() != expected.lower():
        raise SystemExit(
            f"TITAN2_N1D_LIVE_PREFLIGHT=FAIL key={key} expected={expected} actual={actual or 'MISSING'}"
        )

system_bytes = parse_int(values.get("partition-size:system_a", ""))
super_bytes = parse_int(values.get("partition-size:super", ""))
system_b_bytes = parse_int(values.get("partition-size:system_b", ""))

if system_bytes != expected_system:
    raise SystemExit(
        f"TITAN2_N1D_LIVE_PREFLIGHT=FAIL system_a_bytes={system_bytes} expected={expected_system}"
    )
if super_bytes != expected_super:
    raise SystemExit(
        f"TITAN2_N1D_LIVE_PREFLIGHT=FAIL super_bytes={super_bytes} expected={expected_super}"
    )
if system_b_bytes != 0:
    raise SystemExit(
        f"TITAN2_N1D_LIVE_PREFLIGHT=FAIL system_b_bytes={system_b_bytes} expected=0"
    )

logical_names = sorted(
    key.split(":", 1)[1]
    for key, value in values.items()
    if key.startswith("is-logical:") and value.lower() == "yes"
)
logical_sizes = {
    name: parse_int(values.get(f"partition-size:{name}", ""))
    for name in logical_names
}
if any(size <= 0 for size in logical_sizes.values()):
    bad = sorted(name for name, size in logical_sizes.items() if size <= 0)
    raise SystemExit(
        "TITAN2_N1D_LIVE_PREFLIGHT=FAIL logical_size_missing="
        + ",".join(bad)
    )

active_cows = sorted(name for name in logical_names if name.endswith("_a-cow"))
if active_cows:
    raise SystemExit(
        "TITAN2_N1D_LIVE_PREFLIGHT=FAIL active_cows="
        + ",".join(active_cows)
    )

allocated = sum(logical_sizes.values())
if allocated != expected_allocated:
    raise SystemExit(
        f"TITAN2_N1D_LIVE_PREFLIGHT=FAIL allocated={allocated} expected={expected_allocated}"
    )

out.write_text(
    "\n".join([
        f"LIVE_PRODUCT={values['product']}",
        f"LIVE_CURRENT_SLOT={values['current-slot']}",
        f"LIVE_IS_USERSPACE={values['is-userspace']}",
        f"LIVE_UNLOCKED={values['unlocked']}",
        f"LIVE_SNAPSHOT_UPDATE_STATUS={values['snapshot-update-status']}",
        f"LIVE_SYSTEM_A_BYTES={system_bytes}",
        f"LIVE_SYSTEM_B_BYTES={system_b_bytes}",
        f"LIVE_SUPER_BYTES={super_bytes}",
        f"LIVE_MATERIALIZED_LOGICAL_BYTES={allocated}",
        "LIVE_ACTIVE_COW_COUNT=0",
        "",
    ]),
    encoding="utf-8",
)
print("TITAN2_N1D_LIVE_PREFLIGHT=PASS")
PY
  [[ -f "$LIVE_STATE_ENV" ]] || return 1
  # shellcheck source=/dev/null
  source "$LIVE_STATE_ENV"

  echo "TITAN2_N1D_LIVE_PRODUCT=$LIVE_PRODUCT"
  echo "TITAN2_N1D_LIVE_CURRENT_SLOT=$LIVE_CURRENT_SLOT"
  echo "TITAN2_N1D_LIVE_SYSTEM_A_BYTES=$LIVE_SYSTEM_A_BYTES"
  echo "TITAN2_N1D_LIVE_SUPER_BYTES=$LIVE_SUPER_BYTES"
  echo "TITAN2_N1D_LIVE_ACTIVE_COW_COUNT=$LIVE_ACTIVE_COW_COUNT"
  echo "TITAN2_N1D_DEVICE_FLASH_PREFLIGHT=PASS"
}

sable_device_flash_execute() {
  echo "===== TITAN 2 N1D CONTROLLED ACTIVE-SYSTEM FLASH profile=$TITAN2_N1D_ACTIVE_PROFILE ====="
  echo "FLASH_TARGET_PARTITION=$TITAN2_N1D_ACTIVE_TARGET_PARTITION"
  echo "FLASH_IMAGE_LOGICAL_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES"
  echo "FLASH_IMPLICIT_LOGICAL_RESIZE=YES"
  echo "FLASH_MANUAL_PRE_RESIZE=NO"
  echo "FLASH_COW_DELETION=NO"
  echo "FLASH_SLOT_CHANGE=NO"
  echo "FLASH_AVB_MUTATION=NO"
  echo "FLASH_BOOT_CHAIN_MUTATION=NO"
  echo "FLASH_USERDATA_MUTATION=NO"
  echo "FLASH_FACTORY_RESET=NO"

  FLASH_STARTED=YES
  set +e
  "$FASTBOOT_BIN" -s "$SERIAL" flash system_a "$PRIMARY_PATH" </dev/null 2>&1 |
    tee "$EVIDENCE_DIR/fastboot-flash-system-a.log"
  local flash_rc=${PIPESTATUS[0]}
  set -e
  echo "FASTBOOT_FLASH_SYSTEM_A_RC=$flash_rc"
  [[ "$flash_rc" -eq 0 ]] || {
    echo "TITAN2_N1D_FLASH=FAIL_NO_AUTOMATIC_RETRY"
    return 1
  }

  local post_size post_slot post_userspace post_snapshot
  post_size="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" partition-size:system_a)"
  post_slot="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" current-slot)"
  post_userspace="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" is-userspace)"
  post_snapshot="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" snapshot-update-status)"

  python3 - "$post_size" "$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" <<'PY'
import sys
try:
    actual = int(sys.argv[1].strip().split()[0], 0)
except (ValueError, IndexError):
    raise SystemExit(1)
expected = int(sys.argv[2])
raise SystemExit(0 if actual == expected else 1)
PY
  [[ "$post_slot" == "$TITAN2_N1D_ACTIVE_EXPECTED_SLOT" ]] || return 1
  [[ "${post_userspace,,}" == yes ]] || return 1
  [[ "${post_snapshot,,}" == none ]] || return 1

  echo "TITAN2_N1D_POSTFLASH_SYSTEM_A_BYTES=PASS value=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES"
  echo "TITAN2_N1D_POSTFLASH_SLOT=PASS value=$post_slot"
  echo "TITAN2_N1D_POSTFLASH_FASTBOOTD=PASS"
  echo "TITAN2_N1D_POSTFLASH_SNAPSHOT=PASS_NONE"

  "$FASTBOOT_BIN" -s "$SERIAL" reboot </dev/null || return 1
  POSTFLASH_REBOOT_SENT=YES
  echo "TITAN2_N1D_FINAL_REBOOT=PASS_SENT_ONCE"
}

sable_device_flash_postboot() {
  local timeout="${SABLE_DEVICE_POSTBOOT_TIMEOUT:-180}"
  local start now
  local adb_serial="" adb_state="" boot_completed="" bootmode=""
  local fingerprint="" slot_suffix="" verified_boot=""
  local candidate candidate_hash
  local fastboot_seen_absent=NO fastboot_present=NO
  start="$(date +%s)"

  while :; do
    fastboot_present=NO
    if "$FASTBOOT_BIN" devices </dev/null 2>/dev/null |
       awk 'NF>=1 {print $1}' |
       grep -Fxq -- "$SERIAL"; then
      fastboot_present=YES
    fi

    if [[ "$fastboot_present" == NO ]]; then
      fastboot_seen_absent=YES
    elif [[ "$fastboot_seen_absent" == YES ]]; then
      echo "TITAN2_N1D_FIRST_BOOT_OBSERVATION=FASTBOOT_RETURNED"
      echo "TITAN2_N1D_FURTHER_MUTATION=BLOCKED_OWNER_REVIEW_REQUIRED"
      return 1
    fi

    adb_serial=""
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] || continue
      candidate_hash="$(printf '%s' "$candidate" | sha256sum | awk '{print $1}')"
      if [[ "$candidate_hash" == "$EXPECTED_ADB_BINDING_SHA256" ]]; then
        adb_serial="$candidate"
        break
      fi
    done < <("$ADB_BIN" devices </dev/null 2>/dev/null | awk 'NR>1 && NF>=1 {print $1}')

    if [[ -n "$adb_serial" ]]; then
      adb_state="$("$ADB_BIN" -s "$adb_serial" get-state </dev/null 2>/dev/null || true)"
      boot_completed="$("$ADB_BIN" -s "$adb_serial" shell getprop sys.boot_completed </dev/null 2>/dev/null | tr -d '\r')"
      bootmode="$("$ADB_BIN" -s "$adb_serial" shell getprop ro.bootmode </dev/null 2>/dev/null | tr -d '\r')"
      fingerprint="$("$ADB_BIN" -s "$adb_serial" shell getprop ro.build.fingerprint </dev/null 2>/dev/null | tr -d '\r')"
      slot_suffix="$("$ADB_BIN" -s "$adb_serial" shell getprop ro.boot.slot_suffix </dev/null 2>/dev/null | tr -d '\r')"
      verified_boot="$("$ADB_BIN" -s "$adb_serial" shell getprop ro.boot.verifiedbootstate </dev/null 2>/dev/null | tr -d '\r')"

      {
        echo "ADB_STATE=$adb_state"
        echo "SYS_BOOT_COMPLETED=$boot_completed"
        echo "RO_BOOTMODE=$bootmode"
        echo "RO_BUILD_FINGERPRINT=$fingerprint"
        echo "RO_BOOT_SLOT_SUFFIX=$slot_suffix"
        echo "RO_BOOT_VERIFIEDBOOTSTATE=$verified_boot"
      } > "$EVIDENCE_DIR/postboot-observation.env"

      if [[ "${bootmode,,}" == *recovery* ]]; then
        echo "TITAN2_N1D_FIRST_BOOT_OBSERVATION=RECOVERY"
        echo "TITAN2_N1D_FACTORY_RESET=NOT_AUTHORIZED"
        echo "TITAN2_N1D_FURTHER_MUTATION=BLOCKED_OWNER_REVIEW_REQUIRED"
        return 1
      fi

      if [[ "$boot_completed" == 1 ]]; then
        echo "TITAN2_N1D_FIRST_BOOT_OBSERVATION=ANDROID_BOOT_COMPLETED"
        echo "TITAN2_N1D_POSTBOOT_SLOT_SUFFIX=${slot_suffix:-UNKNOWN}"
        echo "TITAN2_N1D_POSTBOOT_VERIFIED_BOOT=${verified_boot:-UNKNOWN}"
        echo "TITAN2_N1D_POSTBOOT_FINGERPRINT=${fingerprint:-UNKNOWN}"
        return 0
      fi
    fi

    now="$(date +%s)"
    if (( now - start >= timeout )); then
      echo "TITAN2_N1D_FIRST_BOOT_OBSERVATION=TIMEOUT_NO_TERMINAL_STATE"
      echo "TITAN2_N1D_FURTHER_MUTATION=BLOCKED_OWNER_REVIEW_REQUIRED"
      return 1
    fi
    sleep 2
  done
}
