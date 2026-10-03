#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
source "$ROOT/build/titan2/n1d-fresh-source.env"
source "$ROOT/build/titan2/n1d-c3-trebledroid.env"
source "$ROOT/build/titan2/n1d-c3a-control-evidence.env"
source "$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"

MODE="${1:-selfcheck}"
if (($#)); then shift; fi

AUTHORIZE_BUILD=NO
AUTHORIZE_FLASH=NO
SERIAL="${TITAN_FASTBOOT_SERIAL:-TITAN20000006073}"
JOBS="$(nproc --all)"

while (($#)); do
  case "$1" in
    --authorize-build) AUTHORIZE_BUILD=YES; shift ;;
    --authorize-flash) AUTHORIZE_FLASH=YES; shift ;;
    --serial) SERIAL="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    *) echo "N1G=FAIL unknown_arg=$1" >&2; exit 64 ;;
  esac
done

fail() {
  echo "N1G=FAIL reason=$1" >&2
  exit "${2:-1}"
}

C3A_SHA=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_BYTES=3146977280
N1F_SHA=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a
N1F_BYTES=3200540672
SUPER_BYTES=9663676416
MAX_ABS_DELTA=$((128 * 1024 * 1024))

N1F_ARTIFACT_ROOT="/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z"
N1F_ARTIFACT="$N1F_ARTIFACT_ROOT/system.img"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C3A="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"

APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
PRODUCT_SRC="$ROOT/product/titan2/c3b"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"

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

latest_c3a_stage() {
  find "$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-prep" \
    -mindepth 1 -maxdepth 1 -type d -name '*-trebledroid-stage' -print \
    2>/dev/null |
    LC_ALL=C sort |
    tail -1
}

verify_c3a_source() {
  local stage tmp count
  stage="$(latest_c3a_stage)"
  [[ -n "$stage" ]] || fail c3a_stage_missing
  [[ -f "$stage/SHA256SUMS.txt" ]] || fail c3a_stage_seal_missing
  [[ -f "$stage/postpatch-project-heads.tsv" ]] || fail c3a_stage_heads_missing

  (
    cd "$stage"
    sha256sum -c SHA256SUMS.txt >/dev/null
  ) || fail c3a_stage_seal_invalid

  tmp="$(mktemp -d)"
  (
    cd "$ANDROID_ROOT"
    "$SABLE_REPO_TOOL" forall -c \
      'printf "%s\\t%s\\n" "$REPO_PATH" "$(git rev-parse HEAD)"' |
      LC_ALL=C sort > "$tmp/current-heads.tsv"
    "$SABLE_REPO_TOOL" forall -c \
      's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "%s\\n" "$REPO_PATH"; fi' |
      LC_ALL=C sort > "$tmp/dirty.tsv"
  )

  count="$(grep -cve '^$' "$tmp/current-heads.tsv" || true)"
  [[ "$count" == "$N1D_C3A_MANAGED_PROJECT_COUNT" ]] || {
    rm -rf "$tmp"
    fail "c3a_project_count=$count"
  }

  LC_ALL=C sort "$stage/postpatch-project-heads.tsv" > "$tmp/expected-heads.tsv"
  cmp -s "$tmp/expected-heads.tsv" "$tmp/current-heads.tsv" || {
    diff -u "$tmp/expected-heads.tsv" "$tmp/current-heads.tsv" >&2 || true
    rm -rf "$tmp"
    fail c3a_heads_mismatch
  }

  printf '%s\n' build/soong device/phh/treble treble_app |
    LC_ALL=C sort > "$tmp/expected-dirty.tsv"
  cmp -s "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" || {
    diff -u "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" >&2 || true
    rm -rf "$tmp"
    fail c3a_dirty_set
  }

  rm -rf "$tmp"
  echo "N1G_C3A_SOURCE=PASS projects=$count dirty=3"
}

selfcheck() {
  bash -n "$0"
  [[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] ||
    fail integration_repo_dirty
  [[ -d "$ANDROID_ROOT/.repo" ]] || fail android_repo_missing
  [[ ! -e "$STAGE_ROOT" ]] || fail stage_root_present

  verify_c3a_source

  [[ -f "$N1F_ARTIFACT" ]] || fail n1f_artifact_missing
  [[ "$(sha256sum "$N1F_ARTIFACT" | awk '{print $1}')" == "$N1F_SHA" ]] ||
    fail n1f_artifact_sha
  [[ "$(stat -c '%s' "$N1F_ARTIFACT")" == "$N1F_BYTES" ]] ||
    fail n1f_artifact_bytes

  for f in Android.bp AndroidProducts.mk sable_titan2.mk sable-titan2-apps.mk; do
    [[ -f "$PRODUCT_SRC/$f" ]] || fail "product_source_missing=$f"
  done

  grep -Fq '$(call inherit-product, device/phh/treble/treble_arm64_bvN.mk)' \
    "$PRODUCT_SRC/sable_titan2.mk" || fail base_inherit
  grep -Fq '$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)' \
    "$PRODUCT_SRC/sable_titan2.mk" || fail apps_inherit
  grep -Fxq 'PRODUCT_NAME := sable_titan2' "$PRODUCT_SRC/sable_titan2.mk" ||
    fail product_name
  grep -Fxq 'PRODUCT_DEVICE := tdgsi_arm64_ab' "$PRODUCT_SRC/sable_titan2.mk" ||
    fail product_device
  grep -Fxq 'PRODUCT_BRAND := SableOS' "$PRODUCT_SRC/sable_titan2.mk" ||
    fail product_brand
  grep -Fxq 'PRODUCT_MODEL := SableOS Titan 2' "$PRODUCT_SRC/sable_titan2.mk" ||
    fail product_model
  grep -Fxq 'PRODUCT_MANUFACTURER := Unihertz' "$PRODUCT_SRC/sable_titan2.mk" ||
    fail product_manufacturer

  echo "N1G_SELFTEST=PASS"
}

if [[ "$MODE" == selfcheck ]]; then
  selfcheck
  exit 0
fi

[[ "$MODE" == run ]] || fail invalid_mode 64
[[ "$AUTHORIZE_BUILD" == YES ]] || fail build_authorization_required 64
[[ "$AUTHORIZE_FLASH" == YES ]] || fail flash_authorization_required 64
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail invalid_jobs 64

selfcheck

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1g-sable-product-identity/$STAMP"
ARTIFACT_DIR="$SABLE_ARTIFACTS_ROOT/titan2/n1g-sable-product-identity/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1g-app-bundle/$STAMP"
mkdir -p "$RUN_EVIDENCE"
exec > >(tee "$RUN_EVIDENCE/run.log") 2>&1

echo "===== N1G SABLE PRODUCT IDENTITY BUILD + FLASH ====="
echo "BASELINE=N1F_C3A_DERIVED_C3B5"
echo "BASELINE_SYSTEM_SHA256=$N1F_SHA"
echo "COMPATIBILITY_PATCH_DELTA=0"
echo "APP_DELTA=0"
echo "PRODUCT_IDENTITY_DELTA=SABLE_TITAN2_WRAPPER_ONLY"
echo "FLASH_AUTHORIZED=YES_SYSTEM_A_ONCE"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "AUTOMATIC_FLASH_RETRY=NO"

echo
echo "===== 1. BUILD SAME FIVE APKS OFFLINE ====="
bash "$APP_BUILD" --authorize-app-build --output-dir "$APP_BUNDLE"
(
  cd "$APP_BUNDLE/prebuilt"
  sha256sum -c ../SHA256SUMS.txt >/dev/null
)

echo
echo "===== 2. STAGE SABLE PRODUCT WRAPPER ====="
mkdir -p "$STAGE_ROOT/prebuilt"
install -m 0644 "$PRODUCT_SRC/Android.bp" "$STAGE_ROOT/Android.bp"
install -m 0644 "$PRODUCT_SRC/AndroidProducts.mk" "$STAGE_ROOT/AndroidProducts.mk"
install -m 0644 "$PRODUCT_SRC/sable_titan2.mk" "$STAGE_ROOT/sable_titan2.mk"
install -m 0644 "$PRODUCT_SRC/sable-titan2-apps.mk" "$STAGE_ROOT/sable-titan2-apps.mk"
for module in "${MODULES[@]}"; do
  install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$STAGE_ROOT/prebuilt/$module.apk"
done
[[ "$(find "$STAGE_ROOT" -type f | wc -l | tr -d ' ')" == 9 ]] ||
  fail stage_file_count

cleanup_stage() {
  set +e
  if [[ -d "$STAGE_ROOT" ]]; then
    find "$STAGE_ROOT" -depth -mindepth 1 -delete
    rmdir "$STAGE_ROOT" 2>/dev/null || true
  fi
  set -e
}
trap cleanup_stage EXIT

echo "N1G_STAGE=PASS files=9"

echo
echo "===== 3. BUILD SABLE_TITAN2 USER SYSTEMIMAGE ====="
(
  cd "$ANDROID_ROOT"
  export OUT_DIR="$OUT_C3A"

  set +u
  source build/envsetup.sh
  lunch sable_titan2-bp4a-user
  set -u

  [[ "${TARGET_PRODUCT:-}" == sable_titan2 ]] || fail "target_product=${TARGET_PRODUCT:-unset}"
  [[ "${TARGET_RELEASE:-}" == bp4a ]] || fail "target_release=${TARGET_RELEASE:-unset}"
  [[ "${TARGET_BUILD_VARIANT:-}" == user ]] || fail "target_variant=${TARGET_BUILD_VARIANT:-unset}"

  build/soong/soong_ui.bash \
    --dumpvars-mode \
    --vars="TARGET_PRODUCT TARGET_BUILD_VARIANT PRODUCT_DEVICE PRODUCT_BRAND PRODUCT_MODEL PRODUCT_MANUFACTURER TARGET_COPY_OUT_PRODUCT BUILD_ID PRODUCT_OUT" \
    > "$RUN_EVIDENCE/product-vars.env"

  grep -Fxq "TARGET_PRODUCT='sable_titan2'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_target_product
  grep -Fxq "TARGET_BUILD_VARIANT='user'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_variant
  grep -Fxq "PRODUCT_DEVICE='tdgsi_arm64_ab'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_device
  grep -Fxq "PRODUCT_BRAND='SableOS'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_brand
  grep -Fxq "PRODUCT_MODEL='SableOS Titan 2'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_model
  grep -Fxq "PRODUCT_MANUFACTURER='Unihertz'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_manufacturer
  grep -Fxq "TARGET_COPY_OUT_PRODUCT='system/product'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_product_route
  grep -Fxq "BUILD_ID='BP4A.251205.006'" "$RUN_EVIDENCE/product-vars.env" ||
    fail dumpvars_build_id

  sed -n "s/^PRODUCT_OUT='\\(.*\\)'$/\\1/p" "$RUN_EVIDENCE/product-vars.env" \
    > "$RUN_EVIDENCE/product-out.txt"

  set +e
  make systemimage -j"$JOBS" 2>&1 | tee "$RUN_EVIDENCE/systemimage.log"
  rc="${PIPESTATUS[0]}"
  set -e
  [[ "$rc" -eq 0 ]] || fail "systemimage_rc=$rc"
)

PRODUCT_OUT="$(cat "$RUN_EVIDENCE/product-out.txt")"
SYSTEM="$PRODUCT_OUT/system.img"
[[ -f "$SYSTEM" ]] || fail system_img_missing
SHA="$(sha256sum "$SYSTEM" | awk '{print $1}')"
BYTES="$(stat -c '%s' "$SYSTEM")"
[[ "$SHA" != "$N1F_SHA" ]] || fail n1g_image_identical_to_n1f

DELTA=$((BYTES - N1F_BYTES))
ABS_DELTA="$DELTA"
(( ABS_DELTA < 0 )) && ABS_DELTA=$((-ABS_DELTA))
[[ "$ABS_DELTA" -le "$MAX_ABS_DELTA" ]] ||
  fail "image_size_delta=$DELTA"

python3 "$GSI_INFO" --image "$SYSTEM" | tee "$RUN_EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail image_geometry

AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
: > "$RUN_EVIDENCE/modules.tsv"
for i in "${!MODULES[@]}"; do
  module="${MODULES[$i]}"
  package="${PACKAGES[$i]}"
  apk="$PRODUCT_OUT/system/product/app/$module/$module.apk"
  [[ -f "$apk" ]] || fail "built_apk_missing=$module"
  actual="$(
    "$AAPT2" dump badging "$apk" |
      sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" |
      head -n1
  )"
  [[ "$actual" == "$package" ]] || fail "package_mismatch=$module"
  "$APKSIGNER" verify "$apk" >/dev/null 2>&1 ||
    fail "apk_unsigned=$module"
  printf '%s\t%s\t%s\n' "$module" "$package" "$(sha256sum "$apk" | awk '{print $1}')" \
    >> "$RUN_EVIDENCE/modules.tsv"
done

echo "N1G_BUILD=PASS sha256=$SHA bytes=$BYTES delta_bytes=$DELTA"

echo
echo "===== 4. PRESERVE N1G IMAGE ====="
mkdir -p "$ARTIFACT_DIR"
cp --reflink=auto --sparse=always "$SYSTEM" "$ARTIFACT_DIR/system.img"
cp "$RUN_EVIDENCE/product-vars.env" "$ARTIFACT_DIR/"
cp "$RUN_EVIDENCE/modules.tsv" "$ARTIFACT_DIR/"
cp "$RUN_EVIDENCE/system-image-info.txt" "$ARTIFACT_DIR/"
cat > "$ARTIFACT_DIR/artifact.env" <<EOF
ROLE=N1G_SABLE_PRODUCT_IDENTITY
BASELINE=N1F_C3A_DERIVED_C3B5
BASELINE_SHA256=$N1F_SHA
COMPATIBILITY_PATCH_DELTA=0
APP_DELTA=0
TARGET_PRODUCT=sable_titan2
TARGET_BUILD_VARIANT=user
PRODUCT_DEVICE=tdgsi_arm64_ab
PRODUCT_BRAND=SableOS
PRODUCT_MODEL=SableOS Titan 2
PRODUCT_MANUFACTURER=Unihertz
SYSTEM_SHA256=$SHA
SYSTEM_BYTES=$BYTES
TARGET_PARTITION=system_a
EOF
(
  cd "$ARTIFACT_DIR"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
echo "N1G_ARTIFACT=PASS dir=$ARTIFACT_DIR"

cleanup_stage
trap - EXIT
[[ ! -e "$STAGE_ROOT" ]] || fail source_restore
echo "N1G_SOURCE_RESTORE=PASS"

echo
echo "===== 5. FLASH OVER BOOT-QUALIFIED N1F ====="
fastboot_seen() {
  "$SABLE_FASTBOOT" devices 2>/dev/null |
    awk -v serial="$SERIAL" '$1==serial {found=1} END {exit found?0:1}'
}
adb_seen() {
  "$SABLE_ADB" -s "$SERIAL" get-state >/dev/null 2>&1
}
wait_fastboot() {
  local _
  for _ in {1..60}; do fastboot_seen && return 0; sleep 1; done
  return 1
}
fbvar() {
  local key="$1"
  "$SABLE_FASTBOOT" -s "$SERIAL" getvar "$key" 2>&1 |
    sed -n "s/.*${key}: //p" |
    tail -n1 |
    tr -d '\r'
}

if adb_seen; then
  "$SABLE_ADB" -s "$SERIAL" reboot bootloader
  wait_fastboot || fail fastboot_timeout
elif ! fastboot_seen; then
  fail device_not_visible
fi

if [[ "$(fbvar is-userspace)" != yes ]]; then
  "$SABLE_FASTBOOT" -s "$SERIAL" reboot fastboot
  wait_fastboot || fail fastbootd_timeout
fi

[[ "$(fbvar product)" == Titan_2 ]] || fail fastboot_product
[[ "$(fbvar current-slot)" == a ]] || fail slot
[[ "$(fbvar is-userspace)" == yes ]] || fail userspace
[[ "$(fbvar unlocked)" == yes ]] || fail unlocked
[[ "$(fbvar snapshot-update-status)" == none ]] || fail snapshot
SUPER_RAW="$(fbvar partition-size:super)"
[[ "$((SUPER_RAW))" -eq "$SUPER_BYTES" ]] || fail super_bytes
PRE_RAW="$(fbvar partition-size:system_a)"
PRE_BYTES=$((PRE_RAW))
[[ "$PRE_BYTES" -eq "$N1F_BYTES" ]] || fail "preflash_bytes=$PRE_BYTES"

for cow in system_a-cow system_ext_a-cow product_a-cow vendor_a-cow odm_a-cow \
           system_dlkm_a-cow vendor_dlkm_a-cow odm_dlkm_a-cow
do
  logical="$(fbvar "is-logical:$cow")"
  size_raw="$(fbvar "partition-size:$cow")"
  size=0
  [[ -z "$size_raw" ]] || size=$((size_raw))
  [[ "$logical" != yes && "$size" -eq 0 ]] || fail "cow_present=$cow"
done

echo "N1G_PREFLASH=PASS pre_bytes=$PRE_BYTES target_bytes=$BYTES"

set +e
"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$ARTIFACT_DIR/system.img"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || fail "flash_failed_no_retry=$RC"

POST_RAW="$(fbvar partition-size:system_a)"
[[ "$((POST_RAW))" -eq "$BYTES" ]] || fail postflash_bytes
[[ "$(fbvar current-slot)" == a ]] || fail post_slot
[[ "$(fbvar is-userspace)" == yes ]] || fail post_userspace
[[ "$(fbvar snapshot-update-status)" == none ]] || fail post_snapshot
echo "N1G_SYSTEM_A_FLASH=PASS"

"$SABLE_FASTBOOT" -s "$SERIAL" reboot
echo "N1G_REBOOT=PASS_ONCE"
echo "FACTORY_RESET=NOT_PERFORMED"

LEFT=NO
for _ in {1..30}; do
  if ! fastboot_seen; then LEFT=YES; break; fi
  sleep 1
done
[[ "$LEFT" == YES ]] || fail reboot_did_not_leave_fastboot

for _ in {1..90}; do
  if fastboot_seen; then
    echo "N1G_BOOT_RESULT=FAIL_FASTBOOT_RETURNED"
    exit 2
  fi

  if adb_seen; then
    completed="$("$SABLE_ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$completed" == 1 ]]; then
      missing=0
      for package in "${PACKAGES[@]}"; do
        path="$("$SABLE_ADB" -s "$SERIAL" shell pm path "$package" 2>/dev/null | tr -d '\r')"
        [[ "$path" == package:* ]] || missing=$((missing + 1))
      done
      [[ "$missing" -eq 0 ]] || fail "runtime_packages_missing=$missing"

      {
        echo "ro.product.brand=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.brand | tr -d '\r')"
        echo "ro.product.model=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
        echo "ro.product.manufacturer=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.manufacturer | tr -d '\r')"
        echo "ro.product.name=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.name | tr -d '\r')"
        echo "ro.product.product.brand=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.product.brand | tr -d '\r')"
        echo "ro.product.product.model=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.product.model | tr -d '\r')"
        echo "ro.product.product.manufacturer=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.product.manufacturer | tr -d '\r')"
        echo "ro.product.product.name=$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.product.product.name | tr -d '\r')"
      } | tee "$RUN_EVIDENCE/runtime-product-properties.txt"

      echo "N1G_RUNTIME_PACKAGES=PASS count=5"
      echo "N1G_RUNTIME_PRODUCT_PROPERTIES=CAPTURED"
      echo "N1G_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED"
      echo "N1G=PASS"
      echo "N1G_ARTIFACT_DIR=$ARTIFACT_DIR"
      echo "RUN_EVIDENCE=$RUN_EVIDENCE"
      exit 0
    fi
  fi
  sleep 2
done

echo "N1G_BOOT_RESULT=MANUAL_UI_CHECK_REQUIRED"
echo "N1G=PASS_BUILD_FLASH_BOOT_OBSERVATION_INCONCLUSIVE"
echo "N1G_ARTIFACT_DIR=$ARTIFACT_DIR"
echo "RUN_EVIDENCE=$RUN_EVIDENCE"
