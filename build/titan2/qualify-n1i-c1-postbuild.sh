#!/usr/bin/env bash
# Read-only N1I-C1 post-build qualification for an already-produced Android 16
# systemimage. No device contact, flash, source mutation, or compilation.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
source "$ROOT/build/titan2/n1d-fresh-source.env"

SOURCE_COMMIT=""
OUT_DIR=""

fail() {
  echo "N1I_C1_POSTBUILD_QUALIFICATION=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/qualify-n1i-c1-postbuild.sh \
    --source-commit <40-hex-build-source> \
    --out-dir <existing-N1I-C1-OUT_DIR>
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --source-commit)
      [[ "$#" -ge 2 ]] || fail missing_source_commit_value 64
      SOURCE_COMMIT="$2"
      shift 2
      ;;
    --out-dir)
      [[ "$#" -ge 2 ]] || fail missing_out_dir_value 64
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown_argument=$1" 64
      ;;
  esac
done

[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail invalid_source_commit 64
[[ -n "$OUT_DIR" && -d "$OUT_DIR" ]] || fail out_dir_missing 64

EXPECTED_OUT_BASENAME="out-n1i-c1-${SOURCE_COMMIT:0:12}"
[[ "$(basename "$OUT_DIR")" == "$EXPECTED_OUT_BASENAME" ]] ||
  fail "out_dir_source_binding=$(basename "$OUT_DIR") expected=$EXPECTED_OUT_BASENAME"

PRODUCT_OUT="$OUT_DIR/target/product/tdgsi_arm64_ab"
SYSTEM="$PRODUCT_OUT/system.img"
COPYOUT="system/system_ext"
IMS="$PRODUCT_OUT/$COPYOUT/priv-app/ImsService/ImsService.apk"
FRAMEWORK_RES="$PRODUCT_OUT/system/framework/framework-res.apk"
BOOTPB="$PRODUCT_OUT/system/etc/classpaths/bootclasspath.pb"
ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"
ROM_MK="$ANDROID_ROOT/device/phh/treble/rom.mk"

AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"

N1F_SHA="dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a"
N1F_BYTES=3200540672
MAX_GROWTH=$((768 * 1024 * 1024))

MODULES=(
  SableTitan2Keyboard
  SableTitan2Camera
  SableTitan2DisplayCompat
  SableTitan2Setup
  SableTitan2RadioDiag
)
PACKAGES=(
  org.sableos.titan2.keyboard
  org.sableos.titan2.camera
  org.sableos.titan2.displaycompat
  org.sableos.titan2.setup
  org.sableos.titan2.radiodiag
)

file_sha256() {
  local file="$1" out rc
  out="$(sha256sum "$file" 2>&1)"
  rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  printf '%s\n' "${out%% *}"
}

apk_package_name() {
  local apk="$1" out rc package
  out="$("$AAPT2" dump badging "$apk" 2>&1)"
  rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  package="$(
    sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" <<<"$out" |
      sed -n '1p'
  )"
  [[ -n "$package" ]] || return 1
  printf '%s\n' "$package"
}

apk_shared_uid() {
  local apk="$1" out rc uid
  out="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$apk" 2>&1)"
  rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  uid="$(
    sed -n 's/.*sharedUserId[^=]*="\([^"]*\)".*/\1/p' <<<"$out" |
      sed -n '1p'
  )"
  [[ -n "$uid" ]] || return 1
  printf '%s\n' "$uid"
}

signer_sha256() {
  local apk="$1" out rc digest
  out="$("$APKSIGNER" verify --print-certs "$apk" 2>&1)"
  rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  digest="$(
    sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$out" |
      sed -n '1p'
  )"
  [[ -n "$digest" ]] || return 1
  printf '%s\n' "$digest"
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-postbuild-qualification/${STAMP}-${SOURCE_COMMIT:0:12}"
ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-cellular-isolation/${STAMP}-${SOURCE_COMMIT:0:12}-postbuild"

mkdir -p "$EVIDENCE" || fail evidence_dir_create
mkdir -p "$ARTIFACT" || fail artifact_dir_create
exec > >(tee "$EVIDENCE/qualify.log") 2>&1

echo "===== TITAN 2 N1I-C1 POST-BUILD QUALIFICATION ====="
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "OUT_DIR=$OUT_DIR"
echo "ANDROID_PLATFORM=16"
echo "BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

[[ -f "$SYSTEM" ]] || fail system_image_missing
SYSTEM_SHA="$(file_sha256 "$SYSTEM")" || fail system_sha256
SYSTEM_BYTES="$(stat -c '%s' "$SYSTEM" 2>/dev/null)"
rc=$?
[[ "$rc" -eq 0 && "$SYSTEM_BYTES" =~ ^[0-9]+$ ]] || fail system_stat
[[ "$SYSTEM_SHA" != "$N1F_SHA" ]] || fail unchanged_from_n1f
[[ "$SYSTEM_BYTES" -ge "$N1F_BYTES" ]] || fail "system_smaller_than_n1f=$SYSTEM_BYTES"
[[ "$SYSTEM_BYTES" -le $((N1F_BYTES + MAX_GROWTH)) ]] || fail "system_growth_excessive=$SYSTEM_BYTES"
echo "N1I_C1_SYSTEMIMAGE=PASS sha256=$SYSTEM_SHA bytes=$SYSTEM_BYTES"

GSI_REPORT="$EVIDENCE/system-image-info.txt"
python3 "$GSI_INFO" --image "$SYSTEM" > "$GSI_REPORT" 2>&1
rc=$?
cat "$GSI_REPORT"
[[ "$rc" -eq 0 ]] || fail "gsi_image_info_rc=$rc"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$GSI_REPORT" || fail gsi_image_info_marker
echo "N1I_C1_GSI_IMAGE_INFO=PASS"

echo "===== FIVE N1F APP COMPOSITION ====="
: > "$EVIDENCE/five-apps.tsv"
for i in "${!MODULES[@]}"; do
  module="${MODULES[$i]}"
  expected_package="${PACKAGES[$i]}"
  apk="$PRODUCT_OUT/system/product/app/$module/$module.apk"
  [[ -f "$apk" ]] || fail "n1f_apk_missing=$module"
  actual_package="$(apk_package_name "$apk")" || fail "n1f_package_parse=$module"
  [[ "$actual_package" == "$expected_package" ]] ||
    fail "n1f_package_mismatch=$module actual=$actual_package"
  "$APKSIGNER" verify "$apk" >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 0 ]] || fail "n1f_apk_signature=$module"
  apk_sha="$(file_sha256 "$apk")" || fail "n1f_apk_sha=$module"
  printf '%s\t%s\t%s\n' "$module" "$actual_package" "$apk_sha" >> "$EVIDENCE/five-apps.tsv"
done
echo "N1I_C1_N1F_FIVE_APPS=PASS count=5"

echo "===== OEM IMS IDENTITY / SIGNATURE ====="
[[ -f "$IMS" ]] || fail ims_apk_missing
IMS_PACKAGE="$(apk_package_name "$IMS")" || fail ims_package_parse
IMS_UID="$(apk_shared_uid "$IMS")" || fail ims_shared_uid_parse
[[ "$IMS_PACKAGE" == com.mediatek.ims ]] || fail "ims_package=$IMS_PACKAGE"
[[ "$IMS_UID" == android.uid.phone ]] || fail "ims_shared_uid=$IMS_UID"
[[ -f "$FRAMEWORK_RES" ]] || fail framework_res_missing
IMS_CERT="$(signer_sha256 "$IMS")" || fail ims_cert_read
PLATFORM_CERT="$(signer_sha256 "$FRAMEWORK_RES")" || fail platform_cert_read
[[ "$IMS_CERT" == "$PLATFORM_CERT" ]] || fail platform_signature_mismatch
echo "N1I_C1_OEM_IMS_IDENTITY=PASS package=$IMS_PACKAGE shared_uid=$IMS_UID"
echo "N1I_C1_OEM_IMS_PLATFORM_RESIGN=PASS cert=$IMS_CERT"

echo "===== BOOTCLASSPATH ====="
COMMON="$PRODUCT_OUT/$COPYOUT/framework/mediatek-common.jar"
IMSBASE="$PRODUCT_OUT/$COPYOUT/framework/mediatek-ims-base.jar"
[[ -f "$COMMON" ]] || fail mediatek_common_missing
[[ -f "$IMSBASE" ]] || fail mediatek_ims_base_missing
[[ -f "$BOOTPB" ]] || fail bootclasspath_pb_missing
if ! grep -aFq '/system_ext/framework/mediatek-common.jar' "$BOOTPB"; then
  if grep -aFq '/system_ext/framework/SableN1IC1MediatekCommon.jar' "$BOOTPB"; then
    fail bootclasspath_common_uses_module_name_not_installed_stem
  fi
  fail mediatek_common_bootclasspath_missing
fi
if ! grep -aFq '/system_ext/framework/mediatek-ims-base.jar' "$BOOTPB"; then
  if grep -aFq '/system_ext/framework/SableN1IC1MediatekImsBase.jar' "$BOOTPB"; then
    fail bootclasspath_ims_uses_module_name_not_installed_stem
  fi
  fail mediatek_ims_base_bootclasspath_missing
fi
echo "N1I_C1_BOOTCLASSPATH=PASS"

echo "===== CONFIG / SYSCONFIG ====="
CONFIG_PATHS=(
  /system_ext/etc/permissions/system-ext-permissions-mediatek.xml
  /system_ext/etc/sysconfig/com.mediatek.ims.config.xml
  /system/etc/permissions/privapp-permissions-mediatek.xml
)
for p in "${CONFIG_PATHS[@]}"; do
  case "$p" in
    /system_ext/*) host="$PRODUCT_OUT/$COPYOUT/${p#/system_ext/}" ;;
    /system/*) host="$PRODUCT_OUT/system/${p#/system/}" ;;
    *) fail "unsupported_config_path=$p" ;;
  esac
  [[ -f "$host" ]] || fail "config_missing=$p"
  echo "N1I_C1_CONFIG=PASS path=$p"
done
echo "N1I_C1_CONFIG=PASS_ALL_3"

echo "===== SELINUX OUTPUT ====="
PROP="$PRODUCT_OUT/$COPYOUT/etc/selinux/system_ext_property_contexts"
SVC="$PRODUCT_OUT/$COPYOUT/etc/selinux/system_ext_service_contexts"
[[ -f "$PROP" ]] || fail system_ext_property_contexts_missing
[[ -f "$SVC" ]] || fail system_ext_service_contexts_missing
grep -Fq 'vendor.ril.imsconfig.force.notify' "$PROP" || fail ims_property_context_missing
grep -Fq 'vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot1' "$SVC" || fail ims_slot1_context_missing
grep -Fq 'vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot2' "$SVC" || fail ims_slot2_context_missing
echo "N1I_C1_SELINUX=PASS_ENFORCING_BUILD_POLICY"

echo "===== ZERO STOCK NATIVE PREBUILTS ====="
NATIVE_INTERMEDIATES="$OUT_DIR/soong/.intermediates/vendor/sable/titan2/n1i-c1"
native_hit=""
if [[ -d "$NATIVE_INTERMEDIATES" ]]; then
  native_hit="$(find "$NATIVE_INTERMEDIATES" -type f -name '*.so' -print -quit 2>/dev/null)"
fi
[[ -z "$native_hit" ]] || fail "stock_native_intermediate=$native_hit"
echo "N1I_C1_STOCK_NATIVE_PREBUILT_COUNT=0"
echo "N1I_C1_A4_NATIVE_SUPERSET=REFERENCE_ONLY_B2_SUPERSEDES_IMPORT_AUTHORITY"

echo "===== SOURCE RESTORE ====="
[[ ! -e "$STAGE_ROOT" ]] || fail android_stage_not_restored
[[ -f "$ROM_MK" ]] || fail rom_mk_missing
if grep -Fq 'SABLE_N1I_C1_ANDROID16_CELLULAR_ISOLATION' "$ROM_MK"; then
  fail rom_mk_not_restored
fi
echo "N1I_C1_SOURCE_RESTORE=PASS"

echo "===== SEAL ARTIFACT ====="
cp --reflink=auto --sparse=always "$SYSTEM" "$ARTIFACT/system.img"
rc=$?
[[ "$rc" -eq 0 ]] || fail "artifact_system_copy_rc=$rc"
cp "$GSI_REPORT" "$ARTIFACT/system-image-info.txt"
rc=$?
[[ "$rc" -eq 0 ]] || fail "artifact_gsi_report_copy_rc=$rc"
cp "$EVIDENCE/five-apps.tsv" "$ARTIFACT/five-apps.tsv"
rc=$?
[[ "$rc" -eq 0 ]] || fail "artifact_five_apps_copy_rc=$rc"

cat > "$ARTIFACT/artifact.env" <<EOF
ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
QUALIFICATION_MODE=POSTBUILD_READONLY
SOURCE_COMMIT=$SOURCE_COMMIT
ANDROID_PLATFORM=16
AOSP_REVISION=android-16.0.0_r4
GRAPHENEOS_TAG=2026061600
REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F
OEM_IMS_PACKAGE=$IMS_PACKAGE
OEM_IMS_SHARED_UID=$IMS_UID
OEM_IMS_PLATFORM_RESIGNED=YES
STOCK_NATIVE_IMPORT_COUNT=0
SYSTEM_SHA256=$SYSTEM_SHA
SYSTEM_BYTES=$SYSTEM_BYTES
DEVICE_CONTACT=NONE
FLASH=NONE
EOF
rc=$?
[[ "$rc" -eq 0 ]] || fail "artifact_env_write_rc=$rc"

(
  cd "$ARTIFACT" || exit 1
  sha256sum artifact.env five-apps.tsv system-image-info.txt system.img > SHA256SUMS.txt
  rc=$?
  [[ "$rc" -eq 0 ]] || exit "$rc"
  sha256sum -c SHA256SUMS.txt
)
rc=$?
[[ "$rc" -eq 0 ]] || fail "artifact_seal_rc=$rc"

echo "N1I_C1_ARTIFACT_SEAL=PASS"
echo "===== N1I-C1 POST-BUILD QUALIFICATION COMPLETE ====="
echo "N1I_C1_POSTBUILD_QUALIFICATION=PASS"
echo "N1I_C1_READY_FOR_PHYSICAL_REVIEW=YES"
echo "N1I_C1_DEVICE_CONTACT=NONE"
echo "N1I_C1_FLASH=NONE"
echo "N1I_C1_ARTIFACT_DIR=$ARTIFACT"
echo "N1I_C1_EVIDENCE_DIR=$EVIDENCE"
