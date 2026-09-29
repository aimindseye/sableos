#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DEFAULT_LUNCH_TARGET="treble_arm64_bvN-bp4a-userdebug"
DEFAULT_ACTIVE_PRODUCT_MK="device/phh/treble/treble_arm64_bvN.mk"
DEFAULT_PRODUCT_OUT_REL="target/product/tdgsi_arm64_ab"

ANDROID_SRC=""
OUT_DIR=""
FULL_CI_EVIDENCE_DIR=""
LUNCH_TARGET="$DEFAULT_LUNCH_TARGET"
JOBS="$(nproc --all)"
REGISTER_ARTIFACT=YES

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/build-n1b2-image-candidate.sh \
    --android-src <restless/android source tree> \
    --full-ci-evidence-dir <local-ci evidence dir for current source commit> \
    [--out-dir <absolute out dir>] \
    [--jobs <n>] \
    [--no-register]

This builds and optionally registers the Titan2/N1B2 GSI system.img candidate.
It fails before build/packaging unless the N1B2 UX matrix, SableLauncher HOME,
Titan2 platform profiles, and product-profile gates pass.

It does not contact devices, does not run bootloader tooling, does not flash,
does not erase userdata, and does not make a public-release or production-signing
claim.
EOF
}

while (($#)); do
  case "$1" in
    --android-src) ANDROID_SRC="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --full-ci-evidence-dir) FULL_CI_EVIDENCE_DIR="$2"; shift 2 ;;
    --lunch-target) LUNCH_TARGET="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --no-register) REGISTER_ARTIFACT=NO; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B2_IMAGE_BUILD=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ -n "$ANDROID_SRC" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_ANDROID_SRC_REQUIRED"; usage; exit 64; }
[[ -n "$FULL_CI_EVIDENCE_DIR" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_FULL_CI_EVIDENCE_REQUIRED"; usage; exit 64; }
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "N1B2_IMAGE_BUILD=FAIL_JOBS value=$JOBS"; exit 64; }

ANDROID_SRC="$(cd "$ANDROID_SRC" && pwd)"
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(cd "$ANDROID_SRC/.." && pwd)/out_sable_t2_n1b2_sable_gsi"
fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
FULL_CI_EVIDENCE_DIR="$(cd "$FULL_CI_EVIDENCE_DIR" && pwd)"

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
SOURCE_DIRTY="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=normal)"
if [[ -n "$SOURCE_DIRTY" ]]; then
  echo "N1B2_IMAGE_BUILD=FAIL_DIRTY_SABLE_SOURCE"
  printf '%s\n' "$SOURCE_DIRTY"
  exit 2
fi

FULL_CI_LOG="$FULL_CI_EVIDENCE_DIR/local-ci.log"
[[ -f "$FULL_CI_LOG" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_FULL_CI_LOG path=$FULL_CI_LOG"; exit 65; }

grep -Fq "SABLE_LOCAL_CI=PASS" "$FULL_CI_LOG" || { echo "N1B2_IMAGE_BUILD=FAIL_FULL_CI_PASS_MARKER"; exit 65; }
grep -Fq "PROFILE=full" "$FULL_CI_LOG" || { echo "N1B2_IMAGE_BUILD=FAIL_FULL_CI_PROFILE"; exit 65; }
grep -Fq "SABLEOS_DEVICE=titan2" "$FULL_CI_LOG" || { echo "N1B2_IMAGE_BUILD=FAIL_FULL_CI_DEVICE"; exit 65; }
grep -Fq "SABLEOS_RELEASE_VERSION=N1B2" "$FULL_CI_LOG" || { echo "N1B2_IMAGE_BUILD=FAIL_FULL_CI_RELEASE"; exit 65; }
grep -Fq "SOURCE_COMMIT=$SOURCE_COMMIT" "$FULL_CI_LOG" || {
  echo "N1B2_IMAGE_BUILD=FAIL_FULL_CI_SOURCE_COMMIT expected=$SOURCE_COMMIT"
  exit 65
}

bash "$ROOT/build/gates/n1b2-product-closure-contract.sh"
bash "$ROOT/build/gates/n1b2-product-profile-implementation-contract.sh"
bash "$ROOT/build/gates/n1b2-titan2-ux-testbed-readiness-contract.sh" "$ROOT"

ACTIVE_PRODUCT_MK="$ANDROID_SRC/$DEFAULT_ACTIVE_PRODUCT_MK"
[[ -f "$ACTIVE_PRODUCT_MK" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_ACTIVE_PRODUCT_MK path=$ACTIVE_PRODUCT_MK"; exit 66; }
grep -Fq 'vendor/sable/n1b2/sable_n1b2_product_profile.mk' "$ACTIVE_PRODUCT_MK" || {
  echo "N1B2_IMAGE_BUILD=FAIL_ACTIVE_PRODUCT_GRAPH_MISSING_N1B2_PROFILE path=$DEFAULT_ACTIVE_PRODUCT_MK"
  exit 66
}

PROFILE_MK="$ANDROID_SRC/vendor/sable/n1b2/sable_n1b2_product_profile.mk"
PRODUCT_CLOSURE_ENV="$ANDROID_SRC/vendor/sable/n1b2/product-closure.env"
UX_READINESS_ENV="$ANDROID_SRC/vendor/sable/n1b2/ux-testbed-readiness.env"
PROFILE_DIR="$ANDROID_SRC/vendor/sable/n1b2/profiles/titan2"
SABLELAUNCHER_BP="$ANDROID_SRC/packages/apps/SableStart/Android.bp"
SABLELAUNCHER_MANIFEST="$ANDROID_SRC/packages/apps/SableStart/AndroidManifest.xml"
SABLE_DESIGN_BP="$ANDROID_SRC/packages/apps/SableDesign/Android.bp"

[[ -f "$PROFILE_MK" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_PROFILE_MK path=$PROFILE_MK"; exit 66; }
[[ -f "$PRODUCT_CLOSURE_ENV" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_PRODUCT_CLOSURE_ENV path=$PRODUCT_CLOSURE_ENV"; exit 66; }
[[ -f "$UX_READINESS_ENV" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_UX_READINESS_ENV path=$UX_READINESS_ENV"; exit 66; }
[[ -f "$SABLELAUNCHER_BP" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_SABLELAUNCHER_BP path=$SABLELAUNCHER_BP"; exit 66; }
[[ -f "$SABLELAUNCHER_MANIFEST" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_SABLELAUNCHER_MANIFEST path=$SABLELAUNCHER_MANIFEST"; exit 66; }
[[ -f "$SABLE_DESIGN_BP" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_SABLE_DESIGN_BP path=$SABLE_DESIGN_BP"; exit 66; }

grep -Fq "N1B2_SABLE_HOME_MODULE=SableLauncher" "$PRODUCT_CLOSURE_ENV" || {
  echo "N1B2_IMAGE_BUILD=FAIL_SABLE_HOME_MODULE marker=$PRODUCT_CLOSURE_ENV"
  exit 66
}
grep -Fq "N1B2_SABLE_HOME_MODULE_PRESENT=YES" "$PRODUCT_CLOSURE_ENV" || {
  echo "N1B2_IMAGE_BUILD=FAIL_SABLE_HOME_NOT_PRESENT marker=$PRODUCT_CLOSURE_ENV"
  exit 66
}
grep -Fq "N1B2_HOME_PACKAGE=org.sableos.launcher" "$PRODUCT_CLOSURE_ENV" || {
  echo "N1B2_IMAGE_BUILD=FAIL_HOME_PACKAGE marker=$PRODUCT_CLOSURE_ENV"
  exit 66
}
grep -Fq "N1B2_QUICKSTEP_ROLE=RECENTS_ONLY" "$PRODUCT_CLOSURE_ENV" || {
  echo "N1B2_IMAGE_BUILD=FAIL_QUICKSTEP_ROLE marker=$PRODUCT_CLOSURE_ENV"
  exit 66
}
grep -Fq 'name: "SableLauncher"' "$SABLELAUNCHER_BP" || {
  echo "N1B2_IMAGE_BUILD=FAIL_SABLELAUNCHER_MODULE path=$SABLELAUNCHER_BP"
  exit 66
}
grep -Fq 'package="org.sableos.launcher"' "$SABLELAUNCHER_MANIFEST" || {
  echo "N1B2_IMAGE_BUILD=FAIL_SABLELAUNCHER_PACKAGE path=$SABLELAUNCHER_MANIFEST"
  exit 66
}
grep -Fq "N1B2_TITAN2_UX_TESTBED_READINESS_MATRIX=PASS" "$UX_READINESS_ENV" || {
  echo "N1B2_IMAGE_BUILD=FAIL_UX_READINESS_MARKER path=$UX_READINESS_ENV"
  exit 66
}

PROFILE_FILES=(
  hardware.env
  display.env
  panel-power.env
  attention.env
  keyboard.env
  pointer.env
  critical-text-entry.env
  app-layout.env
)
for profile in "${PROFILE_FILES[@]}"; do
  [[ -f "$PROFILE_DIR/$profile" ]] || {
    echo "N1B2_IMAGE_BUILD=FAIL_TITAN2_PROFILE_SOURCE profile=$profile path=$PROFILE_DIR/$profile"
    exit 66
  }
done

grep -Fq "TITAN2_HARDWARE_PROFILE_PACKAGED=YES" "$PROFILE_DIR/hardware.env" || exit 66
grep -Fq "TITAN2_DISPLAY_PROFILE_PACKAGED=YES" "$PROFILE_DIR/display.env" || exit 66
grep -Fq "TITAN2_KEYBOARD_PROFILE_PACKAGED=YES" "$PROFILE_DIR/keyboard.env" || exit 66
grep -Fq "TITAN2_POINTER_PROFILE_PACKAGED=YES" "$PROFILE_DIR/pointer.env" || exit 66
grep -Fq "TITAN2_CRITICAL_TEXT_ENTRY_PROFILE_PACKAGED=YES" "$PROFILE_DIR/critical-text-entry.env" || exit 66
grep -Fq "TITAN2_APP_LAYOUT_PROFILE_PACKAGED=YES" "$PROFILE_DIR/app-layout.env" || exit 66

for forbidden in titan2-touchpadd 'uinput' 'SELINUX_IGNORE_NEVERALLOWS := true' 'BOARD_KERNEL_CMDLINE'; do
  if grep -Fq "$forbidden" "$ACTIVE_PRODUCT_MK"; then
    echo "N1B2_IMAGE_BUILD=FAIL_FORBIDDEN_ACTIVE_PRODUCT_TOKEN token=$forbidden"
    exit 66
  fi
done

[[ -f "$ANDROID_SRC/build/envsetup.sh" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_ENVSETUP path=$ANDROID_SRC/build/envsetup.sh"; exit 66; }

STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_ROOT="${SABLE_N1B2_IMAGE_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b2-image-build-candidate}"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/build.log") 2>&1

echo "===== N1B2 IMAGE BUILD CANDIDATE ====="
echo "ROOT=$ROOT"
echo "ANDROID_SRC=$ANDROID_SRC"
echo "OUT_DIR=$OUT_DIR"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "FULL_CI_EVIDENCE_DIR=$FULL_CI_EVIDENCE_DIR"
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=YES_N1B2_IMAGE_ONLY"
echo "IMAGE_BUILD_AUTHORIZED=YES_N1B2_CANDIDATE_ONLY"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"
echo "DEVICE=titan2"
echo "RELEASE=N1B2"
echo "ARTIFACT_KIND=gsi-system-image"
echo "PRIMARY_ARTIFACT=system"
echo "LUNCH_TARGET=$LUNCH_TARGET"
echo "ACTIVE_PRODUCT_MK=$DEFAULT_ACTIVE_PRODUCT_MK"
echo "REGISTER_ARTIFACT=$REGISTER_ARTIFACT"
echo "N1B2_UX_TESTBED_MATRIX_GATE=PASS"
echo "N1B2_PRODUCT_PROFILE_GATE=PASS"
echo "N1B2_SABLE_HOME_MODULE=SableLauncher"
echo "N1B2_HOME_PACKAGE=org.sableos.launcher"
echo "N1B2_QUICKSTEP_ROLE=RECENTS_ONLY"
echo "N1B2_PLATFORM_PROFILE_SOURCE_GATE=PASS"

(
  cd "$ANDROID_SRC"
  if command -v repo >/dev/null 2>&1 && [[ -d .repo ]]; then
    repo manifest -r > "$EVIDENCE_DIR/repo-manifest-r.xml"
    echo "N1B2_REPO_MANIFEST_R=PASS path=$EVIDENCE_DIR/repo-manifest-r.xml"
  else
    echo "N1B2_REPO_MANIFEST_R=SKIP_REPO_TOOL_OR_METADATA_ABSENT"
  fi

  export OUT_DIR="$OUT_DIR"
  set +e +u
  # shellcheck source=/dev/null
  source build/envsetup.sh
  envsetup_rc=$?
  set -euo pipefail
  if [[ "$envsetup_rc" -ne 0 ]]; then
    echo "N1B2_IMAGE_BUILD=FAIL_ENVSETUP_SOURCE rc=$envsetup_rc"
    exit "$envsetup_rc"
  fi
  echo "N1B2_ENVSETUP_SOURCE=PASS_NOUNSET_COMPAT"

  set +e +u
  lunch "$LUNCH_TARGET"
  lunch_rc=$?
  set -euo pipefail
  if [[ "$lunch_rc" -ne 0 ]]; then
    echo "N1B2_IMAGE_BUILD=FAIL_LUNCH rc=$lunch_rc"
    exit "$lunch_rc"
  fi
  echo "N1B2_LUNCH=PASS_NOUNSET_COMPAT target=$LUNCH_TARGET"

  echo "N1B2_BUILD_GOALS=systemimage,target-files-package,otatools"
  set +e +u
  m -j"$JOBS" systemimage target-files-package otatools
  build_rc=$?
  set -euo pipefail
  if [[ "$build_rc" -ne 0 ]]; then
    echo "N1B2_IMAGE_BUILD=FAIL_BUILD rc=$build_rc"
    exit "$build_rc"
  fi
)

PRODUCT_OUT="$OUT_DIR/$DEFAULT_PRODUCT_OUT_REL"
SYSTEM_IMG="$PRODUCT_OUT/system.img"
TARGET_FILES_DIR="$PRODUCT_OUT/obj/PACKAGING/target_files_intermediates"

[[ -f "$SYSTEM_IMG" ]] || { echo "N1B2_IMAGE_BUILD=FAIL_SYSTEM_IMG path=$SYSTEM_IMG"; exit 67; }

mapfile -t TARGET_FILES < <(find "$TARGET_FILES_DIR" -type f -name '*target_files*.zip' -print 2>/dev/null | sort)
if [[ "${#TARGET_FILES[@]}" -ne 1 ]]; then
  echo "N1B2_IMAGE_BUILD=FAIL_TARGET_FILES_COUNT count=${#TARGET_FILES[@]}"
  printf 'TARGET_FILES_CANDIDATE=%s\n' "${TARGET_FILES[@]:-}"
  exit 67
fi
TARGET_FILES_ZIP="${TARGET_FILES[0]}"

python3 - "$TARGET_FILES_ZIP" <<'PY'
from __future__ import annotations
import sys
import zipfile

target_files = sys.argv[1]
required = {
    "SYSTEM/etc/sableos/n1b2/product-closure.env",
    "SYSTEM/etc/sableos/n1b2/ux-testbed-readiness.env",
    "SYSTEM/etc/sableos/profiles/titan2/hardware.env",
    "SYSTEM/etc/sableos/profiles/titan2/display.env",
    "SYSTEM/etc/sableos/profiles/titan2/panel-power.env",
    "SYSTEM/etc/sableos/profiles/titan2/attention.env",
    "SYSTEM/etc/sableos/profiles/titan2/keyboard.env",
    "SYSTEM/etc/sableos/profiles/titan2/pointer.env",
    "SYSTEM/etc/sableos/profiles/titan2/critical-text-entry.env",
    "SYSTEM/etc/sableos/profiles/titan2/app-layout.env",
}
with zipfile.ZipFile(target_files) as zf:
    names = set(zf.namelist())
    missing = sorted(required - names)
    if missing:
        print("N1B2_TARGET_FILES_MARKERS=FAIL")
        for item in missing:
            print(f"N1B2_TARGET_FILES_MISSING={item}")
        raise SystemExit(1)

    payloads = {
        name: zf.read(name).decode("utf-8", errors="replace")
        for name in required
    }

required_tokens = {
    "SYSTEM/etc/sableos/n1b2/product-closure.env": [
        "N1B2_SABLE_HOME_MODULE=SableLauncher",
        "N1B2_SABLE_HOME_MODULE_PRESENT=YES",
        "N1B2_HOME_PACKAGE=org.sableos.launcher",
        "N1B2_QUICKSTEP_ROLE=RECENTS_ONLY",
    ],
    "SYSTEM/etc/sableos/profiles/titan2/hardware.env": [
        "TITAN2_HARDWARE_PROFILE_PACKAGED=YES",
    ],
    "SYSTEM/etc/sableos/profiles/titan2/display.env": [
        "TITAN2_DISPLAY_PROFILE_PACKAGED=YES",
    ],
    "SYSTEM/etc/sableos/profiles/titan2/keyboard.env": [
        "TITAN2_KEYBOARD_PROFILE_PACKAGED=YES",
        "GENERIC_KL_KCM_AS_FINAL_POLICY=NO",
    ],
    "SYSTEM/etc/sableos/profiles/titan2/pointer.env": [
        "TITAN2_POINTER_PROFILE_PACKAGED=YES",
    ],
    "SYSTEM/etc/sableos/profiles/titan2/critical-text-entry.env": [
        "TITAN2_CRITICAL_TEXT_ENTRY_PROFILE_PACKAGED=YES",
        "SOFTWARE_KEYBOARD_FALLBACK=REQUIRED",
        "LOCKSCREEN_PIN_PASSWORD=REQUIRED",
        "WIFI_PASSWORD_ENTRY=REQUIRED",
    ],
    "SYSTEM/etc/sableos/profiles/titan2/app-layout.env": [
        "TITAN2_APP_LAYOUT_PROFILE_PACKAGED=YES",
    ],
}
for path, tokens in required_tokens.items():
    text = payloads[path]
    for token in tokens:
        if token not in text:
            print("N1B2_TARGET_FILES_PROFILE_TOKEN=FAIL")
            print(f"N1B2_TARGET_FILES_PROFILE_PATH={path}")
            print(f"N1B2_TARGET_FILES_PROFILE_TOKEN_MISSING={token}")
            raise SystemExit(1)

print("N1B2_TARGET_FILES_PRODUCT_CLOSURE_MARKER=PASS")
print("N1B2_TARGET_FILES_UX_TESTBED_MARKER=PASS")
print("N1B2_TARGET_FILES_PROFILE_MARKERS=PASS")
print("TITAN2_HARDWARE_PROFILE_PACKAGED=YES")
print("TITAN2_DISPLAY_PROFILE_PACKAGED=YES")
print("TITAN2_KEYBOARD_PROFILE_PACKAGED=YES")
print("TITAN2_POINTER_PROFILE_PACKAGED=YES")
print("TITAN2_CRITICAL_TEXT_ENTRY_PROFILE_PACKAGED=YES")
print("TITAN2_APP_LAYOUT_PROFILE_PACKAGED=YES")
PY

SYSTEM_SHA256="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
TARGET_FILES_SHA256="$(sha256sum "$TARGET_FILES_ZIP" | awk '{print $1}')"
SYSTEM_BYTES="$(stat -c%s "$SYSTEM_IMG")"
TARGET_FILES_BYTES="$(stat -c%s "$TARGET_FILES_ZIP")"
SYSTEM_FILE_TYPE="$(file -b "$SYSTEM_IMG" 2>/dev/null || true)"

compute_logical_bytes() {
  local image="$1"
  local host_simg2img="$OUT_DIR/host/linux-x86/bin/simg2img"
  local raw
  raw="$(mktemp "$EVIDENCE_DIR/system.raw.XXXXXX")"
  if [[ -x "$host_simg2img" ]] && "$host_simg2img" "$image" "$raw" >/dev/null 2>&1; then
    stat -c%s "$raw"
    rm -f "$raw"
    return 0
  fi
  rm -f "$raw"
  stat -c%s "$image"
}

SYSTEM_LOGICAL_BYTES="$(compute_logical_bytes "$SYSTEM_IMG")"

cat > "$EVIDENCE_DIR/n1b2-image-build.env" <<EOF
N1B2_IMAGE_BUILD=PASS
DEVICE=titan2
RELEASE=N1B2
SOURCE_COMMIT=$SOURCE_COMMIT
ANDROID_SRC=$ANDROID_SRC
OUT_DIR=$OUT_DIR
PRODUCT_OUT=$PRODUCT_OUT
LUNCH_TARGET=$LUNCH_TARGET
ACTIVE_PRODUCT_MK=$DEFAULT_ACTIVE_PRODUCT_MK
FULL_CI_EVIDENCE_DIR=$FULL_CI_EVIDENCE_DIR
SYSTEM_IMG=$SYSTEM_IMG
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
SYSTEM_LOGICAL_BYTES=$SYSTEM_LOGICAL_BYTES
SYSTEM_FILE_TYPE=$SYSTEM_FILE_TYPE
TARGET_FILES_ZIP=$TARGET_FILES_ZIP
TARGET_FILES_SHA256=$TARGET_FILES_SHA256
TARGET_FILES_BYTES=$TARGET_FILES_BYTES
ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
N1B2_UX_TESTBED_MATRIX_GATE=PASS
N1B2_SABLE_HOME_MODULE=SableLauncher
N1B2_HOME_PACKAGE=org.sableos.launcher
N1B2_QUICKSTEP_ROLE=RECENTS_ONLY
N1B2_TARGET_FILES_PRODUCT_CLOSURE_MARKER=PASS
N1B2_TARGET_FILES_UX_TESTBED_MARKER=PASS
N1B2_TARGET_FILES_PROFILE_MARKERS=PASS
TITAN2_HARDWARE_PROFILE_PACKAGED=YES
TITAN2_DISPLAY_PROFILE_PACKAGED=YES
TITAN2_KEYBOARD_PROFILE_PACKAGED=YES
TITAN2_POINTER_PROFILE_PACKAGED=YES
TITAN2_CRITICAL_TEXT_ENTRY_PROFILE_PACKAGED=YES
TITAN2_APP_LAYOUT_PROFILE_PACKAGED=YES
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "SYSTEM_SHA256=$SYSTEM_SHA256"
echo "SYSTEM_BYTES=$SYSTEM_BYTES"
echo "SYSTEM_LOGICAL_BYTES=$SYSTEM_LOGICAL_BYTES"
echo "TARGET_FILES_ZIP=$TARGET_FILES_ZIP"
echo "TARGET_FILES_SHA256=$TARGET_FILES_SHA256"
echo "TARGET_FILES_BYTES=$TARGET_FILES_BYTES"
echo "N1B2_IMAGE_BUILD_EVIDENCE=$EVIDENCE_DIR"

if [[ "$REGISTER_ARTIFACT" == YES ]]; then
  bash "$ROOT/build/sable.sh" titan2 N1B2 register-artifact \
    --build-source "$SOURCE_COMMIT" \
    --artifact-kind gsi-system-image \
    --primary-artifact system \
    --artifact "system=$SYSTEM_IMG" \
    --expected-sha256 "system=$SYSTEM_SHA256" \
    --out-dir "$OUT_DIR" \
    --build-evidence-dir "$EVIDENCE_DIR" \
    --metadata "artifact_logical_bytes=$SYSTEM_LOGICAL_BYTES" \
    --metadata "n1b2_image_build_evidence_dir=$EVIDENCE_DIR" \
    --metadata "n1b2_full_local_ci_evidence_dir=$FULL_CI_EVIDENCE_DIR" \
    --metadata "n1b2_full_local_ci_profile=full" \
    --metadata "n1b2_ux_testbed_matrix_gate=PASS" \
    --metadata "n1b2_sable_home_module=SableLauncher" \
    --metadata "n1b2_home_package=org.sableos.launcher" \
    --metadata "n1b2_quickstep_role=RECENTS_ONLY" \
    --metadata "n1b2_target_files_product_closure_marker=PASS" \
    --metadata "n1b2_target_files_ux_testbed_marker=PASS" \
    --metadata "n1b2_target_files_profile_markers=PASS" \
    --metadata "titan2_hardware_profile_packaged=YES" \
    --metadata "titan2_display_profile_packaged=YES" \
    --metadata "titan2_keyboard_profile_packaged=YES" \
    --metadata "titan2_pointer_profile_packaged=YES" \
    --metadata "titan2_critical_text_entry_profile_packaged=YES" \
    --metadata "titan2_app_layout_profile_packaged=YES" \
    --metadata "active_product_mk=$DEFAULT_ACTIVE_PRODUCT_MK" \
    --metadata "lunch_target=$LUNCH_TARGET" \
    --metadata "device_contact_authorized=NO" \
    --metadata "flash_authorized=NO" \
    --metadata "public_release=NO" \
    --metadata "production_signing=NO"

  echo "N1B2_ARTIFACT_REGISTRATION=PASS"
else
  echo "N1B2_ARTIFACT_REGISTRATION=SKIP_NO_REGISTER"
fi

echo "===== N1B2 IMAGE BUILD CANDIDATE RESULT ====="
echo "FAILURES=0"
echo "N1B2_IMAGE_BUILD_CANDIDATE=PASS"
