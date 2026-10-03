#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE="$ROOT/build/config/storage.env"
HOST_TOOLS="$ROOT/build/config/host-tools.env"
FRESH="$ROOT/build/titan2/n1d-fresh-source.env"
TD="$ROOT/build/titan2/n1d-c3-trebledroid.env"
C3A_EVIDENCE="$ROOT/build/titan2/n1d-c3a-control-evidence.env"
C3B_E2="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
ANDROID_BP="$ROOT/product/titan2/c3b/Android.bp"
APPS_MK="$ROOT/product/titan2/c3b/sable-titan2-apps.mk"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"

MODE="${1:-selfcheck}"
if (($#)); then shift; fi

AUTHORIZE_BUILD=NO
AUTHORIZE_FLASH=NO
SERIAL="${TITAN_FASTBOOT_SERIAL:-TITAN20000006073}"
JOBS="$(nproc --all)"
BOOT_OBSERVE_SECONDS=180

while (($#)); do
  case "$1" in
    --authorize-build) AUTHORIZE_BUILD=YES; shift ;;
    --authorize-flash) AUTHORIZE_FLASH=YES; shift ;;
    --serial) SERIAL="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --boot-observe-seconds) BOOT_OBSERVE_SECONDS="$2"; shift 2 ;;
    -h|--help)
      cat <<'USAGE'
usage:
  build/titan2/run-n1f-c3a-derived-c3b5.sh selfcheck

  build/titan2/run-n1f-c3a-derived-c3b5.sh run \
    --authorize-build \
    --authorize-flash \
    [--serial TITAN20000006073] \
    [--jobs N]

Combined Titan 2 engineering experiment:

  0. preserve the boot-qualified C3A system image and evidence history
  1. build the five admitted Sable APKs offline
  2. add only those five apps to the proven C3A Restless/TrebleDroid product
  3. incrementally rebuild systemimage in the existing C3A OUT tree
  4. preserve the derived image and build evidence
  5. restore the C3A source tree
  6. flash system_a exactly once and reboot exactly once
  7. observe boot; never factory-reset automatically

The experiment never writes vbmeta, boot, vendor_boot, super, userdata, metadata,
another slot, or a COW partition.
USAGE
      exit 0
      ;;
    *) echo "N1F_C3A_DERIVED_C3B5=FAIL unknown_arg=$1" >&2; exit 64 ;;
  esac
done

fail() {
  echo "N1F_C3A_DERIVED_C3B5=FAIL reason=$1" >&2
  exit "${2:-1}"
}

for f in "$STORAGE" "$HOST_TOOLS" "$FRESH" "$TD" "$C3A_EVIDENCE" "$C3B_E2"          "$APP_BUILD" "$ANDROID_BP" "$APPS_MK" "$GSI_INFO"; do
  [[ -f "$f" ]] || fail "missing_repo_input=$f"
done

# shellcheck source=/dev/null
source "$STORAGE"
# shellcheck source=/dev/null
source "$HOST_TOOLS"
# shellcheck source=/dev/null
source "$FRESH"
# shellcheck source=/dev/null
source "$TD"
# shellcheck source=/dev/null
source "$C3A_EVIDENCE"
# shellcheck source=/dev/null
source "$C3B_E2"

C3A_SHA="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
C3A_BYTES=3146977280
C3A_PRODUCT="treble_arm64_bvN"
C3A_LUNCH="treble_arm64_bvN-bp4a-user"
C3A_SYSTEM="$N1D_C3A_SYSTEM_IMG"
C3A_BUILD_EVIDENCE="$N1D_C3A_EVIDENCE_DIR"
ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C3A="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td"
PRODUCT_OUT="$OUT_C3A/target/product/tdgsi_arm64_ab"
ROM_MK="$ANDROID_ROOT/device/phh/treble/rom.mk"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"
MAX_ADDED_BYTES=$((512 * 1024 * 1024))

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

[[ "$N1D_C3A_CONTROL_EVIDENCE_STATUS" == PASS_SYSTEMIMAGE ]] || fail c3a_evidence_status
[[ "$N1D_C3A_SYSTEM_SHA256" == "$C3A_SHA" ]] || fail c3a_evidence_sha
[[ "$N1D_C3A_SYSTEM_BYTES" == "$C3A_BYTES" ]] || fail c3a_evidence_bytes
[[ "$N1D_C3A_CONTROL_PATCH_COUNT" == 369 ]] || fail c3a_patch_count
[[ "$N1D_C3B_E2_MODULE_COUNT" == 5 ]] || fail c3b5_module_count
[[ "$N1D_C3_GENERATED_PRODUCT" == "$C3A_PRODUCT" ]] || fail c3a_product
[[ "$N1D_C3_RELEASE_CONFIG" == bp4a ]] || fail c3a_release_config
[[ "$N1D_C3_FIRST_VARIANT" == user ]] || fail c3a_variant
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail jobs_value 64
[[ "$BOOT_OBSERVE_SECONDS" =~ ^[1-9][0-9]*$ ]] || fail boot_observe_seconds 64

selfcheck() {
  bash -n "$0"
  [[ -x "$APP_BUILD" ]] || fail app_build_not_executable
  [[ -d "$ANDROID_ROOT/.repo" ]] || fail android_repo_missing
  [[ -f "$ROM_MK" ]] || fail c3a_rom_missing
  [[ -f "$C3A_SYSTEM" ]] || fail c3a_system_missing
  [[ -d "$C3A_BUILD_EVIDENCE" ]] || fail c3a_build_evidence_missing
  [[ -x "$SABLE_FASTBOOT" ]] || fail fastboot_missing
  [[ -x "$SABLE_ADB" ]] || fail adb_missing
  [[ ! -e "$STAGE_ROOT" ]] || fail "c3b5_stage_root_already_present=$STAGE_ROOT"
  [[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] ||
    fail integration_repo_dirty

  local project_state project_count dirty_count
  project_state="$(mktemp -d)"
  (
    cd "$ANDROID_ROOT"
    "$SABLE_REPO_TOOL" forall -c 'printf "%s\\n" "$REPO_PATH"' |
      LC_ALL=C sort > "$project_state/projects.txt"
    "$SABLE_REPO_TOOL" forall -c \
      's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "%s\\n" "$REPO_PATH"; fi' |
      LC_ALL=C sort > "$project_state/dirty.txt"
  )
  project_count="$(grep -cve '^
  actual_sha="$(sha256sum "$C3A_SYSTEM" | awk '{print $1}')"
  actual_bytes="$(stat -c '%s' "$C3A_SYSTEM")"
  [[ "$actual_sha" == "$C3A_SHA" ]] || fail "c3a_system_sha actual=$actual_sha"
  [[ "$actual_bytes" == "$C3A_BYTES" ]] || fail "c3a_system_bytes actual=$actual_bytes"

  python3 "$GSI_INFO" --image "$C3A_SYSTEM" |
    grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' ||
    fail c3a_gsi_info

  for module in "${MODULES[@]}"; do
    grep -Fq "name: \"$module\"" "$ANDROID_BP" ||
      fail "android_bp_module_missing=$module"
    grep -Fq "$module" "$APPS_MK" ||
      fail "apps_mk_module_missing=$module"
  done

  grep -Fq 'default_dev_cert: true' "$ANDROID_BP" ||
    fail default_dev_cert_missing
  if grep -Eq 'presigned:[[:space:]]*true|certificate:[[:space:]]*"platform"|privileged:[[:space:]]*true' "$ANDROID_BP"; then
    fail forbidden_app_privilege_or_signing
  fi

  echo "N1F_COMBINED_SELFTEST=PASS"
  echo "C3A_SYSTEM_SHA256=$actual_sha"
  echo "C3A_SYSTEM_BYTES=$actual_bytes"
  echo "C3A_CONTROL_PATCH_COUNT=369"
  echo "C3B5_MODULE_COUNT=5"
  echo "BUILD_MODEL=INCREMENTAL_REUSE_C3A_OUT"
  echo "FLASH_MODEL=ONE_SYSTEM_A_WRITE_ONE_REBOOT_NO_FACTORY_RESET"
}

if [[ "$MODE" == selfcheck ]]; then
  selfcheck
  exit 0
fi
[[ "$MODE" == run ]] || fail "mode=$MODE" 64
[[ "$AUTHORIZE_BUILD" == YES ]] || fail build_authorization_required 64
[[ "$AUTHORIZE_FLASH" == YES ]] || fail flash_authorization_required 64

selfcheck

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
C3A_HISTORY="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/$STAMP"
C3B5_ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3b5-app-bundle/$STAMP"
mkdir -p "$RUN_EVIDENCE"
RUN_LOG="$RUN_EVIDENCE/run.log"
exec > >(tee "$RUN_LOG") 2>&1

echo "===== N1F C3A-DERIVED C3B5 COMBINED BUILD + FLASH ====="
echo "TIMESTAMP_UTC=$STAMP"
echo "SERIAL=$SERIAL"
echo "BUILD_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=YES_EXACT_SYSTEM_A_ONCE"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "BOOT_CHAIN_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "COW_CLEANUP_AUTHORIZED=NO"
echo "WHOLE_SUPER_FLASH_AUTHORIZED=NO"
echo "AUTOMATIC_FLASH_RETRY_AUTHORIZED=NO"

echo
echo "===== PHASE 0: PRESERVE BOOT-QUALIFIED C3A HISTORY ====="

mkdir -p "$C3A_HISTORY"
cp --reflink=auto --sparse=always "$C3A_SYSTEM" "$C3A_HISTORY/system.img"
cp "$C3A_EVIDENCE" "$C3A_HISTORY/n1d-c3a-control-evidence.env"
cp -a --reflink=auto "$C3A_BUILD_EVIDENCE" "$C3A_HISTORY/build-evidence"

OFFLINE_CONTROL="/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan"
FASTBOOT_PREFLIGHT="/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z"
[[ -d "$OFFLINE_CONTROL" ]] || fail offline_control_evidence_missing
[[ -d "$FASTBOOT_PREFLIGHT" ]] || fail fastboot_preflight_evidence_missing
cp -a --reflink=auto "$OFFLINE_CONTROL" "$C3A_HISTORY/offline-control"
cp -a --reflink=auto "$FASTBOOT_PREFLIGHT" "$C3A_HISTORY/fastboot-entry-preflight"

for runtime_log in /tmp/c3a-v010014-physical-control.*.log; do
  [[ -f "$runtime_log" ]] || continue
  cp "$runtime_log" "$C3A_HISTORY/"
done

(
  cd "$ANDROID_ROOT"
  "$SABLE_REPO_TOOL" manifest -r -o "$C3A_HISTORY/repo-manifest-r.xml"
  "$SABLE_REPO_TOOL" forall -c     'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'     > "$C3A_HISTORY/all-project-heads.tsv"
  "$SABLE_REPO_TOOL" forall -c     's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "### %s\n%s\n" "$REPO_PATH" "$s"; fi'     > "$C3A_HISTORY/dirty-project-state.txt"
)

cat > "$C3A_HISTORY/runtime-result.env" <<EOF
C3A_V010014_SYSTEM_FLASH=PASS
C3A_V010014_ANDROID_BOOT=PASS
C3A_V010014_VOICE_REGISTRATION=PASS
C3A_V010014_DATA_REGISTRATION=PASS
C3A_V010014_NR_NSA_CAPABILITY=PASS
C3A_V010014_RADIO_POSTBOOT_STABILITY=ISSUE_RECOVERABLE_BY_RADIO_CYCLE
C3A_V010014_COMPATIBILITY_BASELINE=PASS
C3A_SYSTEM_SHA256=$C3A_SHA
C3A_SYSTEM_BYTES=$C3A_BYTES
C3A_CONTROL_PATCH_COUNT=369
EOF

actual_history_sha="$(sha256sum "$C3A_HISTORY/system.img" | awk '{print $1}')"
actual_history_bytes="$(stat -c '%s' "$C3A_HISTORY/system.img")"
[[ "$actual_history_sha" == "$C3A_SHA" ]] || fail c3a_history_image_sha
[[ "$actual_history_bytes" == "$C3A_BYTES" ]] || fail c3a_history_image_bytes

(
  cd "$C3A_HISTORY"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$C3A_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
echo "C3A_HISTORY=PASS"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "C3A_HISTORY_SYSTEM_SHA256=$C3A_SHA"

echo
echo "===== PHASE 1: BUILD FIVE SOURCE-BOUND SABLE APKS ====="

bash "$APP_BUILD"   --authorize-app-build   --output-dir "$APP_BUNDLE"

(
  cd "$APP_BUNDLE/prebuilt"
  sha256sum -c ../SHA256SUMS.txt
)

echo
echo "===== PHASE 2: STAGE MINIMAL FIVE-APP DELTA ON C3A SOURCE ====="

[[ ! -e "$STAGE_ROOT" ]] || fail stage_root_became_present
mkdir -p "$STAGE_ROOT/prebuilt"
install -m 0644 "$ANDROID_BP" "$STAGE_ROOT/Android.bp"
install -m 0644 "$APPS_MK" "$STAGE_ROOT/sable-titan2-apps.mk"
for module in "${MODULES[@]}"; do
  install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$STAGE_ROOT/prebuilt/$module.apk"
done

ROM_BACKUP="$RUN_EVIDENCE/rom.mk.c3a-baseline"
cp "$ROM_MK" "$ROM_BACKUP"
ROM_BASE_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"

cleanup_source_delta() {
  set +e
  if [[ -f "$ROM_BACKUP" ]]; then
    cp "$ROM_BACKUP" "$ROM_MK"
  fi
  if [[ -d "$STAGE_ROOT" ]]; then
    find "$STAGE_ROOT" -depth -mindepth 1 -delete
    rmdir "$STAGE_ROOT" 2>/dev/null || true
  fi
  set -e
}
trap cleanup_source_delta EXIT

if grep -Fq 'vendor/sable/titan2/sable-titan2-apps.mk' "$ROM_MK"; then
  fail sable_apps_already_in_c3a_rom
fi
cat >> "$ROM_MK" <<'EOF'

# SABLE_N1F_C3A_DERIVED_C3B5_BEGIN
$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)
# SABLE_N1F_C3A_DERIVED_C3B5_END
EOF

STAGED_FILE_COUNT="$(find "$STAGE_ROOT" -type f | wc -l | tr -d ' ')"
[[ "$STAGED_FILE_COUNT" == 7 ]] || fail "staged_file_count=$STAGED_FILE_COUNT"
grep -Fxq '$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)' "$ROM_MK" ||
  fail rom_inherit_missing

{
  echo "ROM_BASE_SHA256=$ROM_BASE_SHA"
  echo "STAGED_FILE_COUNT=$STAGED_FILE_COUNT"
  find "$STAGE_ROOT" -type f -printf '%P\n' | LC_ALL=C sort
} > "$RUN_EVIDENCE/source-delta.txt"

echo "N1F_SOURCE_DELTA=PASS_EXACT_7_FILES_PLUS_ONE_ROM_INHERIT"
echo "N1F_COMPATIBILITY_PATCH_DELTA=ZERO"
echo "N1F_ADDED_APP_COUNT=5"

echo
echo "===== PHASE 3: INCREMENTAL C3A-DERIVED SYSTEMIMAGE BUILD ====="

(
  cd "$ANDROID_ROOT"
  export OUT_DIR="$OUT_C3A"

  set +u
  # shellcheck source=/dev/null
  source build/envsetup.sh
  set -u

  set +u
  lunch "$C3A_LUNCH"
  set -u

  actual_product="$(get_build_var TARGET_PRODUCT)"
  actual_release="$(get_build_var TARGET_RELEASE)"
  actual_variant="$(get_build_var TARGET_BUILD_VARIANT)"
  actual_product_out="$(get_build_var PRODUCT_OUT)"
  actual_copy_out="$(get_build_var TARGET_COPY_OUT_PRODUCT)"
  actual_packages="$(get_build_var PRODUCT_PACKAGES)"

  [[ "$actual_product" == "$C3A_PRODUCT" ]] || fail "target_product=$actual_product"
  [[ "$actual_release" == bp4a ]] || fail "target_release=$actual_release"
  [[ "$actual_variant" == user ]] || fail "target_variant=$actual_variant"
  [[ "$actual_product_out" == "$PRODUCT_OUT" ]] || fail "product_out=$actual_product_out"
  [[ "$actual_copy_out" == system/product ]] || fail "target_copy_out_product=$actual_copy_out"
  for module in "${MODULES[@]}"; do
    grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" <<<"$actual_packages" ||
      fail "module_not_in_product_packages=$module"
  done
  printf '%s\\n' "$actual_packages" > "$RUN_EVIDENCE/product-packages.txt"

  set +e
  make systemimage -j"$JOBS" 2>&1 | tee "$RUN_EVIDENCE/systemimage-build.log"
  build_rc="${PIPESTATUS[0]}"
  set -e
  [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
)

NEW_SYSTEM="$PRODUCT_OUT/system.img"
[[ -f "$NEW_SYSTEM" ]] || fail new_system_missing

NEW_SHA="$(sha256sum "$NEW_SYSTEM" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$NEW_SYSTEM")"
[[ "$NEW_SHA" != "$C3A_SHA" ]] || fail derived_image_identical_to_c3a
[[ "$NEW_BYTES" -ge "$C3A_BYTES" ]] || fail "derived_image_smaller_than_c3a bytes=$NEW_BYTES"
[[ "$NEW_BYTES" -le $((C3A_BYTES + MAX_ADDED_BYTES)) ]] ||
  fail "derived_image_growth_excessive bytes=$NEW_BYTES"

python3 "$GSI_INFO" --image "$NEW_SYSTEM" |
  tee "$RUN_EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_info
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_not_raw
grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$NEW_BYTES" "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_logical_size

AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
[[ -x "$AAPT2" ]] || fail aapt2_missing
[[ -x "$APKSIGNER" ]] || fail apksigner_missing

: > "$RUN_EVIDENCE/module-membership.txt"
for i in "${!MODULES[@]}"; do
  module="${MODULES[$i]}"
  package="${PACKAGES[$i]}"
  apk="$PRODUCT_OUT/system/product/app/$module/$module.apk"
  [[ -f "$apk" ]] || fail "module_output_missing=$apk"
  actual_package="$("$AAPT2" dump badging "$apk" |
    sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" |
    head -n1)"
  [[ "$actual_package" == "$package" ]] ||
    fail "package_mismatch module=$module expected=$package actual=$actual_package"
  "$APKSIGNER" verify "$apk" >/dev/null 2>&1 ||
    fail "system_product_apk_not_signed=$module"
  printf '%s\\t%s\\t%s\\t%s\\n' \
    "$module" "$package" "$apk" "$(sha256sum "$apk" | awk '{print $1}')" \
    >> "$RUN_EVIDENCE/module-membership.txt"
done

echo "N1F_BUILD=PASS"
echo "N1F_SYSTEM_IMG=$NEW_SYSTEM"
echo "N1F_SYSTEM_SHA256=$NEW_SHA"
echo "N1F_SYSTEM_BYTES=$NEW_BYTES"
echo "N1F_MODULE_MEMBERSHIP=PASS count=5"

echo
echo "===== PHASE 4: PRESERVE DERIVED IMAGE BEFORE DEVICE WRITE ====="

mkdir -p "$C3B5_ARTIFACT"
cp --reflink=auto --sparse=always "$NEW_SYSTEM" "$C3B5_ARTIFACT/system.img"
cp "$APP_BUNDLE/manifest.tsv" "$C3B5_ARTIFACT/app-manifest.tsv"
cp "$APP_BUNDLE/SHA256SUMS.txt" "$C3B5_ARTIFACT/app-SHA256SUMS.txt"
cp "$RUN_EVIDENCE/module-membership.txt" "$C3B5_ARTIFACT/module-membership.txt"
cp "$RUN_EVIDENCE/source-delta.txt" "$C3B5_ARTIFACT/source-delta.txt"
cp "$RUN_EVIDENCE/system-image-info.txt" "$C3B5_ARTIFACT/system-image-info.txt"

cat > "$C3B5_ARTIFACT/artifact.env" <<EOF
N1F_ROLE=C3A_DERIVED_C3B5_BOOT_ISOLATION
C3A_BASE_SYSTEM_SHA256=$C3A_SHA
C3A_BASE_SYSTEM_BYTES=$C3A_BYTES
C3A_CONTROL_PATCH_COUNT=369
SABLE_MODULE_COUNT=5
COMPATIBILITY_PATCH_DELTA=0
SYSTEM_SHA256=$NEW_SHA
SYSTEM_BYTES=$NEW_BYTES
TARGET_PARTITION=system_a
FACTORY_RESET_POLICY=NO_FOR_FIRST_ATTEMPT
EOF

(
  cd "$C3B5_ARTIFACT"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$NEW_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1F_ARTIFACT_HISTORY=PASS"
echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"

echo
echo "===== PHASE 5: RESTORE C3A SOURCE TREE ====="

cleanup_source_delta
trap - EXIT
[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_BASE_SHA" ]] ||
  fail rom_restore_sha
[[ ! -e "$STAGE_ROOT" ]] || fail stage_root_restore
echo "N1F_SOURCE_RESTORE=PASS"

echo
echo "===== PHASE 6: ENTER / VERIFY FASTBOOTD ====="

fastboot_present() {
  "$SABLE_FASTBOOT" devices 2>/dev/null |
    awk -v serial="$SERIAL" '$1==serial {found=1} END {exit found?0:1}'
}

adb_present() {
  "$SABLE_ADB" -s "$SERIAL" get-state >/dev/null 2>&1
}

wait_fastboot() {
  local i
  for ((i=0; i<60; i++)); do
    fastboot_present && return 0
    sleep 1
  done
  return 1
}

if adb_present; then
  echo "N1F_DEVICE_ENTRY=ADB_ANDROID"
  "$SABLE_ADB" -s "$SERIAL" reboot bootloader
  wait_fastboot || fail fastboot_after_adb_reboot
elif fastboot_present; then
  echo "N1F_DEVICE_ENTRY=FASTBOOT"
else
  fail device_not_visible_adb_or_fastboot
fi

fbvar() {
  local key="$1"
  "$SABLE_FASTBOOT" -s "$SERIAL" getvar "$key" 2>&1 |
    sed -n "s/.*${key}: //p" |
    tail -n1 |
    tr -d '\r'
}

IS_USERSPACE="$(fbvar is-userspace)"
if [[ "$IS_USERSPACE" != yes ]]; then
  "$SABLE_FASTBOOT" -s "$SERIAL" reboot fastboot
  wait_fastboot || fail fastbootd_mode_switch_timeout
fi

PRODUCT="$(fbvar product)"
SLOT="$(fbvar current-slot)"
IS_USERSPACE="$(fbvar is-userspace)"
UNLOCKED="$(fbvar unlocked)"
SNAPSHOT="$(fbvar snapshot-update-status)"
SYSTEM_PRE_RAW="$(fbvar partition-size:system_a)"
SYSTEM_PRE=$((SYSTEM_PRE_RAW))

echo "PRODUCT=$PRODUCT"
echo "CURRENT_SLOT=$SLOT"
echo "IS_USERSPACE=$IS_USERSPACE"
echo "UNLOCKED=$UNLOCKED"
echo "SNAPSHOT_UPDATE_STATUS=$SNAPSHOT"
echo "SYSTEM_A_PRE_BYTES=$SYSTEM_PRE"

[[ "$PRODUCT" == Titan_2 ]] || fail "product=$PRODUCT"
[[ "$SLOT" == a ]] || fail "slot=$SLOT"
[[ "$IS_USERSPACE" == yes ]] || fail not_fastbootd
[[ "$UNLOCKED" == yes ]] || fail bootloader_not_unlocked
[[ "$SNAPSHOT" == none ]] || fail "snapshot=$SNAPSHOT"
[[ "$SYSTEM_PRE" -eq "$C3A_BYTES" ]] ||
  fail "system_pre expected=$C3A_BYTES actual=$SYSTEM_PRE"

GETVAR_ALL="$("$SABLE_FASTBOOT" -s "$SERIAL" getvar all 2>&1)"
if printf '%s\n' "$GETVAR_ALL" |
  grep -Eiq 'is-logical:[^[:space:]]+_a-cow:[[:space:]]*yes'
then
  fail active_slot_cow_present
fi

GROWTH=$((NEW_BYTES - SYSTEM_PRE))
[[ "$GROWTH" -ge 0 ]] || fail negative_growth
[[ "$GROWTH" -le "$MAX_ADDED_BYTES" ]] || fail "growth_excessive=$GROWTH"

echo "N1F_PREFLASH=PASS"
echo "N1F_SYSTEM_GROWTH_BYTES=$GROWTH"
echo "N1F_ACTIVE_COW=PASS_ZERO"

echo
echo "===== PHASE 7: FLASH SYSTEM_A EXACTLY ONCE ====="

set +e
"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$C3B5_ARTIFACT/system.img"
FLASH_RC=$?
set -e
echo "N1F_FASTBOOT_FLASH_SYSTEM_A_RC=$FLASH_RC"
[[ "$FLASH_RC" -eq 0 ]] || fail "flash_failed_no_retry rc=$FLASH_RC"

SYSTEM_POST_RAW="$(fbvar partition-size:system_a)"
SYSTEM_POST=$((SYSTEM_POST_RAW))
POST_SLOT="$(fbvar current-slot)"
POST_USERSPACE="$(fbvar is-userspace)"
POST_SNAPSHOT="$(fbvar snapshot-update-status)"

echo "SYSTEM_A_POST_BYTES=$SYSTEM_POST"
echo "POST_SLOT=$POST_SLOT"
echo "POST_IS_USERSPACE=$POST_USERSPACE"
echo "POST_SNAPSHOT_UPDATE_STATUS=$POST_SNAPSHOT"

[[ "$SYSTEM_POST" -eq "$NEW_BYTES" ]] || fail "postflash_size expected=$NEW_BYTES actual=$SYSTEM_POST"
[[ "$POST_SLOT" == a ]] || fail postflash_slot
[[ "$POST_USERSPACE" == yes ]] || fail postflash_not_fastbootd
[[ "$POST_SNAPSHOT" == none ]] || fail postflash_snapshot

echo "N1F_SYSTEM_A_FLASH=PASS"

echo
echo "===== PHASE 8: REBOOT ONCE + BOOT OBSERVATION ====="

"$SABLE_FASTBOOT" -s "$SERIAL" reboot
echo "N1F_REBOOT=PASS_SENT_ONCE"
echo "FACTORY_RESET=NOT_PERFORMED"

FASTBOOT_LEFT=NO
for ((i=0; i<30; i++)); do
  if ! fastboot_present; then
    FASTBOOT_LEFT=YES
    break
  fi
  sleep 1
done
[[ "$FASTBOOT_LEFT" == YES ]] || fail reboot_did_not_leave_fastboot

iterations=$((BOOT_OBSERVE_SECONDS / 2))
(( iterations > 0 )) || iterations=1
for ((i=0; i<iterations; i++)); do
  if fastboot_present; then
    echo "N1F_BOOT_RESULT=FAIL_FASTBOOT_RETURNED"
    echo "N1F_FACTORY_RESET=NOT_PERFORMED"
    exit 2
  fi

  if adb_present; then
    BOOTMODE="$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.bootmode 2>/dev/null | tr -d '\r')"
    BOOT_COMPLETED="$("$SABLE_ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    echo "ADB_BOOTMODE=${BOOTMODE:-UNKNOWN}"
    echo "ADB_SYS_BOOT_COMPLETED=${BOOT_COMPLETED:-UNKNOWN}"

    if [[ "${BOOTMODE,,}" == *recovery* ]]; then
      echo "N1F_BOOT_RESULT=RECOVERY"
      echo "N1F_FACTORY_RESET=NOT_PERFORMED"
      exit 3
    fi

    if [[ "$BOOT_COMPLETED" == 1 ]]; then
      missing=0
      : > "$RUN_EVIDENCE/runtime-package-paths.txt"
      for package in "${PACKAGES[@]}"; do
        path="$("$SABLE_ADB" -s "$SERIAL" shell pm path "$package" 2>/dev/null | tr -d '\r')"
        printf '%s\t%s\n' "$package" "$path" | tee -a "$RUN_EVIDENCE/runtime-package-paths.txt"
        [[ "$path" == package:* ]] || missing=$((missing + 1))
      done
      [[ "$missing" -eq 0 ]] || fail "runtime_sable_packages_missing=$missing"

      echo "N1F_RUNTIME_SABLE_PACKAGES=PASS count=5"
      echo "N1F_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED"
      echo "N1F_FACTORY_RESET=NOT_PERFORMED"
      echo "N1F_COMBINED_BUILD_FLASH=PASS"
      echo "RUN_EVIDENCE=$RUN_EVIDENCE"
      echo "C3A_HISTORY_DIR=$C3A_HISTORY"
      echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"
      exit 0
    fi
  fi

  sleep 2
done

echo "N1F_BOOT_RESULT=MANUAL_UI_CHECK_REQUIRED_NO_FASTBOOT_RETURN"
echo "N1F_FACTORY_RESET=NOT_PERFORMED"
echo "N1F_COMBINED_BUILD_FLASH=PASS_BUILD_FLASH_OBSERVATION_INCONCLUSIVE"
echo "RUN_EVIDENCE=$RUN_EVIDENCE"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"
 "$project_state/projects.txt" || true)"
  dirty_count="$(grep -cve '^
  actual_sha="$(sha256sum "$C3A_SYSTEM" | awk '{print $1}')"
  actual_bytes="$(stat -c '%s' "$C3A_SYSTEM")"
  [[ "$actual_sha" == "$C3A_SHA" ]] || fail "c3a_system_sha actual=$actual_sha"
  [[ "$actual_bytes" == "$C3A_BYTES" ]] || fail "c3a_system_bytes actual=$actual_bytes"

  python3 "$GSI_INFO" --image "$C3A_SYSTEM" |
    grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' ||
    fail c3a_gsi_info

  for module in "${MODULES[@]}"; do
    grep -Fq "name: \"$module\"" "$ANDROID_BP" ||
      fail "android_bp_module_missing=$module"
    grep -Fq "$module" "$APPS_MK" ||
      fail "apps_mk_module_missing=$module"
  done

  grep -Fq 'default_dev_cert: true' "$ANDROID_BP" ||
    fail default_dev_cert_missing
  if grep -Eq 'presigned:[[:space:]]*true|certificate:[[:space:]]*"platform"|privileged:[[:space:]]*true' "$ANDROID_BP"; then
    fail forbidden_app_privilege_or_signing
  fi

  echo "N1F_COMBINED_SELFTEST=PASS"
  echo "C3A_SYSTEM_SHA256=$actual_sha"
  echo "C3A_SYSTEM_BYTES=$actual_bytes"
  echo "C3A_CONTROL_PATCH_COUNT=369"
  echo "C3B5_MODULE_COUNT=5"
  echo "BUILD_MODEL=INCREMENTAL_REUSE_C3A_OUT"
  echo "FLASH_MODEL=ONE_SYSTEM_A_WRITE_ONE_REBOOT_NO_FACTORY_RESET"
}

if [[ "$MODE" == selfcheck ]]; then
  selfcheck
  exit 0
fi
[[ "$MODE" == run ]] || fail "mode=$MODE" 64
[[ "$AUTHORIZE_BUILD" == YES ]] || fail build_authorization_required 64
[[ "$AUTHORIZE_FLASH" == YES ]] || fail flash_authorization_required 64

selfcheck

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
C3A_HISTORY="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/$STAMP"
C3B5_ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3b5-app-bundle/$STAMP"
mkdir -p "$RUN_EVIDENCE"
RUN_LOG="$RUN_EVIDENCE/run.log"
exec > >(tee "$RUN_LOG") 2>&1

echo "===== N1F C3A-DERIVED C3B5 COMBINED BUILD + FLASH ====="
echo "TIMESTAMP_UTC=$STAMP"
echo "SERIAL=$SERIAL"
echo "BUILD_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=YES_EXACT_SYSTEM_A_ONCE"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "BOOT_CHAIN_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "COW_CLEANUP_AUTHORIZED=NO"
echo "WHOLE_SUPER_FLASH_AUTHORIZED=NO"
echo "AUTOMATIC_FLASH_RETRY_AUTHORIZED=NO"

echo
echo "===== PHASE 0: PRESERVE BOOT-QUALIFIED C3A HISTORY ====="

mkdir -p "$C3A_HISTORY"
cp --reflink=auto --sparse=always "$C3A_SYSTEM" "$C3A_HISTORY/system.img"
cp "$C3A_EVIDENCE" "$C3A_HISTORY/n1d-c3a-control-evidence.env"
cp -a --reflink=auto "$C3A_BUILD_EVIDENCE" "$C3A_HISTORY/build-evidence"

OFFLINE_CONTROL="/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan"
FASTBOOT_PREFLIGHT="/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z"
[[ -d "$OFFLINE_CONTROL" ]] || fail offline_control_evidence_missing
[[ -d "$FASTBOOT_PREFLIGHT" ]] || fail fastboot_preflight_evidence_missing
cp -a --reflink=auto "$OFFLINE_CONTROL" "$C3A_HISTORY/offline-control"
cp -a --reflink=auto "$FASTBOOT_PREFLIGHT" "$C3A_HISTORY/fastboot-entry-preflight"

for runtime_log in /tmp/c3a-v010014-physical-control.*.log; do
  [[ -f "$runtime_log" ]] || continue
  cp "$runtime_log" "$C3A_HISTORY/"
done

(
  cd "$ANDROID_ROOT"
  "$SABLE_REPO_TOOL" manifest -r -o "$C3A_HISTORY/repo-manifest-r.xml"
  "$SABLE_REPO_TOOL" forall -c     'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'     > "$C3A_HISTORY/all-project-heads.tsv"
  "$SABLE_REPO_TOOL" forall -c     's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "### %s\n%s\n" "$REPO_PATH" "$s"; fi'     > "$C3A_HISTORY/dirty-project-state.txt"
)

cat > "$C3A_HISTORY/runtime-result.env" <<EOF
C3A_V010014_SYSTEM_FLASH=PASS
C3A_V010014_ANDROID_BOOT=PASS
C3A_V010014_VOICE_REGISTRATION=PASS
C3A_V010014_DATA_REGISTRATION=PASS
C3A_V010014_NR_NSA_CAPABILITY=PASS
C3A_V010014_RADIO_POSTBOOT_STABILITY=ISSUE_RECOVERABLE_BY_RADIO_CYCLE
C3A_V010014_COMPATIBILITY_BASELINE=PASS
C3A_SYSTEM_SHA256=$C3A_SHA
C3A_SYSTEM_BYTES=$C3A_BYTES
C3A_CONTROL_PATCH_COUNT=369
EOF

actual_history_sha="$(sha256sum "$C3A_HISTORY/system.img" | awk '{print $1}')"
actual_history_bytes="$(stat -c '%s' "$C3A_HISTORY/system.img")"
[[ "$actual_history_sha" == "$C3A_SHA" ]] || fail c3a_history_image_sha
[[ "$actual_history_bytes" == "$C3A_BYTES" ]] || fail c3a_history_image_bytes

(
  cd "$C3A_HISTORY"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$C3A_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
echo "C3A_HISTORY=PASS"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "C3A_HISTORY_SYSTEM_SHA256=$C3A_SHA"

echo
echo "===== PHASE 1: BUILD FIVE SOURCE-BOUND SABLE APKS ====="

bash "$APP_BUILD"   --authorize-app-build   --output-dir "$APP_BUNDLE"

(
  cd "$APP_BUNDLE/prebuilt"
  sha256sum -c ../SHA256SUMS.txt
)

echo
echo "===== PHASE 2: STAGE MINIMAL FIVE-APP DELTA ON C3A SOURCE ====="

[[ ! -e "$STAGE_ROOT" ]] || fail stage_root_became_present
mkdir -p "$STAGE_ROOT/prebuilt"
install -m 0644 "$ANDROID_BP" "$STAGE_ROOT/Android.bp"
install -m 0644 "$APPS_MK" "$STAGE_ROOT/sable-titan2-apps.mk"
for module in "${MODULES[@]}"; do
  install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$STAGE_ROOT/prebuilt/$module.apk"
done

ROM_BACKUP="$RUN_EVIDENCE/rom.mk.c3a-baseline"
cp "$ROM_MK" "$ROM_BACKUP"
ROM_BASE_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"

cleanup_source_delta() {
  set +e
  if [[ -f "$ROM_BACKUP" ]]; then
    cp "$ROM_BACKUP" "$ROM_MK"
  fi
  if [[ -d "$STAGE_ROOT" ]]; then
    find "$STAGE_ROOT" -depth -mindepth 1 -delete
    rmdir "$STAGE_ROOT" 2>/dev/null || true
  fi
  set -e
}
trap cleanup_source_delta EXIT

if grep -Fq 'vendor/sable/titan2/sable-titan2-apps.mk' "$ROM_MK"; then
  fail sable_apps_already_in_c3a_rom
fi
cat >> "$ROM_MK" <<'EOF'

# SABLE_N1F_C3A_DERIVED_C3B5_BEGIN
$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)
# SABLE_N1F_C3A_DERIVED_C3B5_END
EOF

STAGED_FILE_COUNT="$(find "$STAGE_ROOT" -type f | wc -l | tr -d ' ')"
[[ "$STAGED_FILE_COUNT" == 7 ]] || fail "staged_file_count=$STAGED_FILE_COUNT"
grep -Fxq '$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)' "$ROM_MK" ||
  fail rom_inherit_missing

{
  echo "ROM_BASE_SHA256=$ROM_BASE_SHA"
  echo "STAGED_FILE_COUNT=$STAGED_FILE_COUNT"
  find "$STAGE_ROOT" -type f -printf '%P\n' | LC_ALL=C sort
} > "$RUN_EVIDENCE/source-delta.txt"

echo "N1F_SOURCE_DELTA=PASS_EXACT_7_FILES_PLUS_ONE_ROM_INHERIT"
echo "N1F_COMPATIBILITY_PATCH_DELTA=ZERO"
echo "N1F_ADDED_APP_COUNT=5"

echo
echo "===== PHASE 3: INCREMENTAL C3A-DERIVED SYSTEMIMAGE BUILD ====="

(
  cd "$ANDROID_ROOT"
  export OUT_DIR="$OUT_C3A"

  set +u
  # shellcheck source=/dev/null
  source build/envsetup.sh
  set -u

  set +u
  lunch "$C3A_LUNCH"
  set -u

  set +e
  make systemimage -j"$JOBS" 2>&1 | tee "$RUN_EVIDENCE/systemimage-build.log"
  build_rc="${PIPESTATUS[0]}"
  set -e
  [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
)

NEW_SYSTEM="$PRODUCT_OUT/system.img"
[[ -f "$NEW_SYSTEM" ]] || fail new_system_missing

NEW_SHA="$(sha256sum "$NEW_SYSTEM" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$NEW_SYSTEM")"
[[ "$NEW_SHA" != "$C3A_SHA" ]] || fail derived_image_identical_to_c3a
[[ "$NEW_BYTES" -ge "$C3A_BYTES" ]] || fail "derived_image_smaller_than_c3a bytes=$NEW_BYTES"
[[ "$NEW_BYTES" -le $((C3A_BYTES + MAX_ADDED_BYTES)) ]] ||
  fail "derived_image_growth_excessive bytes=$NEW_BYTES"

python3 "$GSI_INFO" --image "$NEW_SYSTEM" |
  tee "$RUN_EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_info
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_not_raw
grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$NEW_BYTES" "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_logical_size

: > "$RUN_EVIDENCE/module-membership.txt"
for module in "${MODULES[@]}"; do
  mapfile -t hits < <(
    find "$PRODUCT_OUT/system/product" -type f -name "$module.apk" -print 2>/dev/null |
      LC_ALL=C sort
  )
  [[ "${#hits[@]}" -eq 1 ]] ||
    fail "module_output_count module=$module count=${#hits[@]}"
  printf '%s\t%s\n' "$module" "${hits[0]}" >> "$RUN_EVIDENCE/module-membership.txt"
done

echo "N1F_BUILD=PASS"
echo "N1F_SYSTEM_IMG=$NEW_SYSTEM"
echo "N1F_SYSTEM_SHA256=$NEW_SHA"
echo "N1F_SYSTEM_BYTES=$NEW_BYTES"
echo "N1F_MODULE_MEMBERSHIP=PASS count=5"

echo
echo "===== PHASE 4: PRESERVE DERIVED IMAGE BEFORE DEVICE WRITE ====="

mkdir -p "$C3B5_ARTIFACT"
cp --reflink=auto --sparse=always "$NEW_SYSTEM" "$C3B5_ARTIFACT/system.img"
cp "$APP_BUNDLE/manifest.tsv" "$C3B5_ARTIFACT/app-manifest.tsv"
cp "$APP_BUNDLE/SHA256SUMS.txt" "$C3B5_ARTIFACT/app-SHA256SUMS.txt"
cp "$RUN_EVIDENCE/module-membership.txt" "$C3B5_ARTIFACT/module-membership.txt"
cp "$RUN_EVIDENCE/source-delta.txt" "$C3B5_ARTIFACT/source-delta.txt"
cp "$RUN_EVIDENCE/system-image-info.txt" "$C3B5_ARTIFACT/system-image-info.txt"

cat > "$C3B5_ARTIFACT/artifact.env" <<EOF
N1F_ROLE=C3A_DERIVED_C3B5_BOOT_ISOLATION
C3A_BASE_SYSTEM_SHA256=$C3A_SHA
C3A_BASE_SYSTEM_BYTES=$C3A_BYTES
C3A_CONTROL_PATCH_COUNT=369
SABLE_MODULE_COUNT=5
COMPATIBILITY_PATCH_DELTA=0
SYSTEM_SHA256=$NEW_SHA
SYSTEM_BYTES=$NEW_BYTES
TARGET_PARTITION=system_a
FACTORY_RESET_POLICY=NO_FOR_FIRST_ATTEMPT
EOF

(
  cd "$C3B5_ARTIFACT"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$NEW_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1F_ARTIFACT_HISTORY=PASS"
echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"

echo
echo "===== PHASE 5: RESTORE C3A SOURCE TREE ====="

cleanup_source_delta
trap - EXIT
[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_BASE_SHA" ]] ||
  fail rom_restore_sha
[[ ! -e "$STAGE_ROOT" ]] || fail stage_root_restore
echo "N1F_SOURCE_RESTORE=PASS"

echo
echo "===== PHASE 6: ENTER / VERIFY FASTBOOTD ====="

fastboot_present() {
  "$SABLE_FASTBOOT" devices 2>/dev/null |
    awk -v serial="$SERIAL" '$1==serial {found=1} END {exit found?0:1}'
}

adb_present() {
  "$SABLE_ADB" -s "$SERIAL" get-state >/dev/null 2>&1
}

wait_fastboot() {
  local i
  for ((i=0; i<60; i++)); do
    fastboot_present && return 0
    sleep 1
  done
  return 1
}

if adb_present; then
  echo "N1F_DEVICE_ENTRY=ADB_ANDROID"
  "$SABLE_ADB" -s "$SERIAL" reboot bootloader
  wait_fastboot || fail fastboot_after_adb_reboot
elif fastboot_present; then
  echo "N1F_DEVICE_ENTRY=FASTBOOT"
else
  fail device_not_visible_adb_or_fastboot
fi

fbvar() {
  local key="$1"
  "$SABLE_FASTBOOT" -s "$SERIAL" getvar "$key" 2>&1 |
    sed -n "s/.*${key}: //p" |
    tail -n1 |
    tr -d '\r'
}

IS_USERSPACE="$(fbvar is-userspace)"
if [[ "$IS_USERSPACE" != yes ]]; then
  "$SABLE_FASTBOOT" -s "$SERIAL" reboot fastboot
  wait_fastboot || fail fastbootd_mode_switch_timeout
fi

PRODUCT="$(fbvar product)"
SLOT="$(fbvar current-slot)"
IS_USERSPACE="$(fbvar is-userspace)"
UNLOCKED="$(fbvar unlocked)"
SNAPSHOT="$(fbvar snapshot-update-status)"
SYSTEM_PRE_RAW="$(fbvar partition-size:system_a)"
SYSTEM_PRE=$((SYSTEM_PRE_RAW))

echo "PRODUCT=$PRODUCT"
echo "CURRENT_SLOT=$SLOT"
echo "IS_USERSPACE=$IS_USERSPACE"
echo "UNLOCKED=$UNLOCKED"
echo "SNAPSHOT_UPDATE_STATUS=$SNAPSHOT"
echo "SYSTEM_A_PRE_BYTES=$SYSTEM_PRE"

[[ "$PRODUCT" == Titan_2 ]] || fail "product=$PRODUCT"
[[ "$SLOT" == a ]] || fail "slot=$SLOT"
[[ "$IS_USERSPACE" == yes ]] || fail not_fastbootd
[[ "$UNLOCKED" == yes ]] || fail bootloader_not_unlocked
[[ "$SNAPSHOT" == none ]] || fail "snapshot=$SNAPSHOT"
[[ "$SYSTEM_PRE" -eq "$C3A_BYTES" ]] ||
  fail "system_pre expected=$C3A_BYTES actual=$SYSTEM_PRE"

GETVAR_ALL="$("$SABLE_FASTBOOT" -s "$SERIAL" getvar all 2>&1)"
if printf '%s\n' "$GETVAR_ALL" |
  grep -Eiq 'is-logical:[^[:space:]]+_a-cow:[[:space:]]*yes'
then
  fail active_slot_cow_present
fi

GROWTH=$((NEW_BYTES - SYSTEM_PRE))
[[ "$GROWTH" -ge 0 ]] || fail negative_growth
[[ "$GROWTH" -le "$MAX_ADDED_BYTES" ]] || fail "growth_excessive=$GROWTH"

echo "N1F_PREFLASH=PASS"
echo "N1F_SYSTEM_GROWTH_BYTES=$GROWTH"
echo "N1F_ACTIVE_COW=PASS_ZERO"

echo
echo "===== PHASE 7: FLASH SYSTEM_A EXACTLY ONCE ====="

set +e
"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$C3B5_ARTIFACT/system.img"
FLASH_RC=$?
set -e
echo "N1F_FASTBOOT_FLASH_SYSTEM_A_RC=$FLASH_RC"
[[ "$FLASH_RC" -eq 0 ]] || fail "flash_failed_no_retry rc=$FLASH_RC"

SYSTEM_POST_RAW="$(fbvar partition-size:system_a)"
SYSTEM_POST=$((SYSTEM_POST_RAW))
POST_SLOT="$(fbvar current-slot)"
POST_USERSPACE="$(fbvar is-userspace)"
POST_SNAPSHOT="$(fbvar snapshot-update-status)"

echo "SYSTEM_A_POST_BYTES=$SYSTEM_POST"
echo "POST_SLOT=$POST_SLOT"
echo "POST_IS_USERSPACE=$POST_USERSPACE"
echo "POST_SNAPSHOT_UPDATE_STATUS=$POST_SNAPSHOT"

[[ "$SYSTEM_POST" -eq "$NEW_BYTES" ]] || fail "postflash_size expected=$NEW_BYTES actual=$SYSTEM_POST"
[[ "$POST_SLOT" == a ]] || fail postflash_slot
[[ "$POST_USERSPACE" == yes ]] || fail postflash_not_fastbootd
[[ "$POST_SNAPSHOT" == none ]] || fail postflash_snapshot

echo "N1F_SYSTEM_A_FLASH=PASS"

echo
echo "===== PHASE 8: REBOOT ONCE + BOOT OBSERVATION ====="

"$SABLE_FASTBOOT" -s "$SERIAL" reboot
echo "N1F_REBOOT=PASS_SENT_ONCE"
echo "FACTORY_RESET=NOT_PERFORMED"

FASTBOOT_LEFT=NO
for ((i=0; i<30; i++)); do
  if ! fastboot_present; then
    FASTBOOT_LEFT=YES
    break
  fi
  sleep 1
done
[[ "$FASTBOOT_LEFT" == YES ]] || fail reboot_did_not_leave_fastboot

iterations=$((BOOT_OBSERVE_SECONDS / 2))
(( iterations > 0 )) || iterations=1
for ((i=0; i<iterations; i++)); do
  if fastboot_present; then
    echo "N1F_BOOT_RESULT=FAIL_FASTBOOT_RETURNED"
    echo "N1F_FACTORY_RESET=NOT_PERFORMED"
    exit 2
  fi

  if adb_present; then
    BOOTMODE="$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.bootmode 2>/dev/null | tr -d '\r')"
    BOOT_COMPLETED="$("$SABLE_ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    echo "ADB_BOOTMODE=${BOOTMODE:-UNKNOWN}"
    echo "ADB_SYS_BOOT_COMPLETED=${BOOT_COMPLETED:-UNKNOWN}"

    if [[ "${BOOTMODE,,}" == *recovery* ]]; then
      echo "N1F_BOOT_RESULT=RECOVERY"
      echo "N1F_FACTORY_RESET=NOT_PERFORMED"
      exit 3
    fi

    if [[ "$BOOT_COMPLETED" == 1 ]]; then
      missing=0
      : > "$RUN_EVIDENCE/runtime-package-paths.txt"
      for package in "${PACKAGES[@]}"; do
        path="$("$SABLE_ADB" -s "$SERIAL" shell pm path "$package" 2>/dev/null | tr -d '\r')"
        printf '%s\t%s\n' "$package" "$path" | tee -a "$RUN_EVIDENCE/runtime-package-paths.txt"
        [[ "$path" == package:* ]] || missing=$((missing + 1))
      done
      [[ "$missing" -eq 0 ]] || fail "runtime_sable_packages_missing=$missing"

      echo "N1F_RUNTIME_SABLE_PACKAGES=PASS count=5"
      echo "N1F_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED"
      echo "N1F_FACTORY_RESET=NOT_PERFORMED"
      echo "N1F_COMBINED_BUILD_FLASH=PASS"
      echo "RUN_EVIDENCE=$RUN_EVIDENCE"
      echo "C3A_HISTORY_DIR=$C3A_HISTORY"
      echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"
      exit 0
    fi
  fi

  sleep 2
done

echo "N1F_BOOT_RESULT=MANUAL_UI_CHECK_REQUIRED_NO_FASTBOOT_RETURN"
echo "N1F_FACTORY_RESET=NOT_PERFORMED"
echo "N1F_COMBINED_BUILD_FLASH=PASS_BUILD_FLASH_OBSERVATION_INCONCLUSIVE"
echo "RUN_EVIDENCE=$RUN_EVIDENCE"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"
 "$project_state/dirty.txt" || true)"
  [[ "$project_count" == 991 ]] || {
    rm -rf "$project_state"
    fail "c3a_project_count=$project_count"
  }
  printf '%s\\n' build/soong device/phh/treble treble_app |
    LC_ALL=C sort > "$project_state/expected-dirty.txt"
  cmp -s "$project_state/expected-dirty.txt" "$project_state/dirty.txt" || {
    echo "N1F_C3A_SOURCE_DIRTY_SET=FAIL" >&2
    diff -u "$project_state/expected-dirty.txt" "$project_state/dirty.txt" >&2 || true
    rm -rf "$project_state"
    fail "c3a_dirty_project_count=$dirty_count"
  }
  rm -rf "$project_state"

  local actual_sha actual_bytes
  actual_sha="$(sha256sum "$C3A_SYSTEM" | awk '{print $1}')"
  actual_bytes="$(stat -c '%s' "$C3A_SYSTEM")"
  [[ "$actual_sha" == "$C3A_SHA" ]] || fail "c3a_system_sha actual=$actual_sha"
  [[ "$actual_bytes" == "$C3A_BYTES" ]] || fail "c3a_system_bytes actual=$actual_bytes"

  python3 "$GSI_INFO" --image "$C3A_SYSTEM" |
    grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' ||
    fail c3a_gsi_info

  for module in "${MODULES[@]}"; do
    grep -Fq "name: \"$module\"" "$ANDROID_BP" ||
      fail "android_bp_module_missing=$module"
    grep -Fq "$module" "$APPS_MK" ||
      fail "apps_mk_module_missing=$module"
  done

  grep -Fq 'default_dev_cert: true' "$ANDROID_BP" ||
    fail default_dev_cert_missing
  if grep -Eq 'presigned:[[:space:]]*true|certificate:[[:space:]]*"platform"|privileged:[[:space:]]*true' "$ANDROID_BP"; then
    fail forbidden_app_privilege_or_signing
  fi

  echo "N1F_COMBINED_SELFTEST=PASS"
  echo "C3A_SYSTEM_SHA256=$actual_sha"
  echo "C3A_SYSTEM_BYTES=$actual_bytes"
  echo "C3A_CONTROL_PATCH_COUNT=369"
  echo "C3B5_MODULE_COUNT=5"
  echo "BUILD_MODEL=INCREMENTAL_REUSE_C3A_OUT"
  echo "FLASH_MODEL=ONE_SYSTEM_A_WRITE_ONE_REBOOT_NO_FACTORY_RESET"
}

if [[ "$MODE" == selfcheck ]]; then
  selfcheck
  exit 0
fi
[[ "$MODE" == run ]] || fail "mode=$MODE" 64
[[ "$AUTHORIZE_BUILD" == YES ]] || fail build_authorization_required 64
[[ "$AUTHORIZE_FLASH" == YES ]] || fail flash_authorization_required 64

selfcheck

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
C3A_HISTORY="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/$STAMP"
C3B5_ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3b5-app-bundle/$STAMP"
mkdir -p "$RUN_EVIDENCE"
RUN_LOG="$RUN_EVIDENCE/run.log"
exec > >(tee "$RUN_LOG") 2>&1

echo "===== N1F C3A-DERIVED C3B5 COMBINED BUILD + FLASH ====="
echo "TIMESTAMP_UTC=$STAMP"
echo "SERIAL=$SERIAL"
echo "BUILD_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=YES_EXACT_SYSTEM_A_ONCE"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "BOOT_CHAIN_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "COW_CLEANUP_AUTHORIZED=NO"
echo "WHOLE_SUPER_FLASH_AUTHORIZED=NO"
echo "AUTOMATIC_FLASH_RETRY_AUTHORIZED=NO"

echo
echo "===== PHASE 0: PRESERVE BOOT-QUALIFIED C3A HISTORY ====="

mkdir -p "$C3A_HISTORY"
cp --reflink=auto --sparse=always "$C3A_SYSTEM" "$C3A_HISTORY/system.img"
cp "$C3A_EVIDENCE" "$C3A_HISTORY/n1d-c3a-control-evidence.env"
cp -a --reflink=auto "$C3A_BUILD_EVIDENCE" "$C3A_HISTORY/build-evidence"

OFFLINE_CONTROL="/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan"
FASTBOOT_PREFLIGHT="/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z"
[[ -d "$OFFLINE_CONTROL" ]] || fail offline_control_evidence_missing
[[ -d "$FASTBOOT_PREFLIGHT" ]] || fail fastboot_preflight_evidence_missing
cp -a --reflink=auto "$OFFLINE_CONTROL" "$C3A_HISTORY/offline-control"
cp -a --reflink=auto "$FASTBOOT_PREFLIGHT" "$C3A_HISTORY/fastboot-entry-preflight"

for runtime_log in /tmp/c3a-v010014-physical-control.*.log; do
  [[ -f "$runtime_log" ]] || continue
  cp "$runtime_log" "$C3A_HISTORY/"
done

(
  cd "$ANDROID_ROOT"
  "$SABLE_REPO_TOOL" manifest -r -o "$C3A_HISTORY/repo-manifest-r.xml"
  "$SABLE_REPO_TOOL" forall -c     'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'     > "$C3A_HISTORY/all-project-heads.tsv"
  "$SABLE_REPO_TOOL" forall -c     's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "### %s\n%s\n" "$REPO_PATH" "$s"; fi'     > "$C3A_HISTORY/dirty-project-state.txt"
)

cat > "$C3A_HISTORY/runtime-result.env" <<EOF
C3A_V010014_SYSTEM_FLASH=PASS
C3A_V010014_ANDROID_BOOT=PASS
C3A_V010014_VOICE_REGISTRATION=PASS
C3A_V010014_DATA_REGISTRATION=PASS
C3A_V010014_NR_NSA_CAPABILITY=PASS
C3A_V010014_RADIO_POSTBOOT_STABILITY=ISSUE_RECOVERABLE_BY_RADIO_CYCLE
C3A_V010014_COMPATIBILITY_BASELINE=PASS
C3A_SYSTEM_SHA256=$C3A_SHA
C3A_SYSTEM_BYTES=$C3A_BYTES
C3A_CONTROL_PATCH_COUNT=369
EOF

actual_history_sha="$(sha256sum "$C3A_HISTORY/system.img" | awk '{print $1}')"
actual_history_bytes="$(stat -c '%s' "$C3A_HISTORY/system.img")"
[[ "$actual_history_sha" == "$C3A_SHA" ]] || fail c3a_history_image_sha
[[ "$actual_history_bytes" == "$C3A_BYTES" ]] || fail c3a_history_image_bytes

(
  cd "$C3A_HISTORY"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$C3A_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
echo "C3A_HISTORY=PASS"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "C3A_HISTORY_SYSTEM_SHA256=$C3A_SHA"

echo
echo "===== PHASE 1: BUILD FIVE SOURCE-BOUND SABLE APKS ====="

bash "$APP_BUILD"   --authorize-app-build   --output-dir "$APP_BUNDLE"

(
  cd "$APP_BUNDLE/prebuilt"
  sha256sum -c ../SHA256SUMS.txt
)

echo
echo "===== PHASE 2: STAGE MINIMAL FIVE-APP DELTA ON C3A SOURCE ====="

[[ ! -e "$STAGE_ROOT" ]] || fail stage_root_became_present
mkdir -p "$STAGE_ROOT/prebuilt"
install -m 0644 "$ANDROID_BP" "$STAGE_ROOT/Android.bp"
install -m 0644 "$APPS_MK" "$STAGE_ROOT/sable-titan2-apps.mk"
for module in "${MODULES[@]}"; do
  install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$STAGE_ROOT/prebuilt/$module.apk"
done

ROM_BACKUP="$RUN_EVIDENCE/rom.mk.c3a-baseline"
cp "$ROM_MK" "$ROM_BACKUP"
ROM_BASE_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"

cleanup_source_delta() {
  set +e
  if [[ -f "$ROM_BACKUP" ]]; then
    cp "$ROM_BACKUP" "$ROM_MK"
  fi
  if [[ -d "$STAGE_ROOT" ]]; then
    find "$STAGE_ROOT" -depth -mindepth 1 -delete
    rmdir "$STAGE_ROOT" 2>/dev/null || true
  fi
  set -e
}
trap cleanup_source_delta EXIT

if grep -Fq 'vendor/sable/titan2/sable-titan2-apps.mk' "$ROM_MK"; then
  fail sable_apps_already_in_c3a_rom
fi
cat >> "$ROM_MK" <<'EOF'

# SABLE_N1F_C3A_DERIVED_C3B5_BEGIN
$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)
# SABLE_N1F_C3A_DERIVED_C3B5_END
EOF

STAGED_FILE_COUNT="$(find "$STAGE_ROOT" -type f | wc -l | tr -d ' ')"
[[ "$STAGED_FILE_COUNT" == 7 ]] || fail "staged_file_count=$STAGED_FILE_COUNT"
grep -Fxq '$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)' "$ROM_MK" ||
  fail rom_inherit_missing

{
  echo "ROM_BASE_SHA256=$ROM_BASE_SHA"
  echo "STAGED_FILE_COUNT=$STAGED_FILE_COUNT"
  find "$STAGE_ROOT" -type f -printf '%P\n' | LC_ALL=C sort
} > "$RUN_EVIDENCE/source-delta.txt"

echo "N1F_SOURCE_DELTA=PASS_EXACT_7_FILES_PLUS_ONE_ROM_INHERIT"
echo "N1F_COMPATIBILITY_PATCH_DELTA=ZERO"
echo "N1F_ADDED_APP_COUNT=5"

echo
echo "===== PHASE 3: INCREMENTAL C3A-DERIVED SYSTEMIMAGE BUILD ====="

(
  cd "$ANDROID_ROOT"
  export OUT_DIR="$OUT_C3A"

  set +u
  # shellcheck source=/dev/null
  source build/envsetup.sh
  set -u

  set +u
  lunch "$C3A_LUNCH"
  set -u

  set +e
  make systemimage -j"$JOBS" 2>&1 | tee "$RUN_EVIDENCE/systemimage-build.log"
  build_rc="${PIPESTATUS[0]}"
  set -e
  [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
)

NEW_SYSTEM="$PRODUCT_OUT/system.img"
[[ -f "$NEW_SYSTEM" ]] || fail new_system_missing

NEW_SHA="$(sha256sum "$NEW_SYSTEM" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$NEW_SYSTEM")"
[[ "$NEW_SHA" != "$C3A_SHA" ]] || fail derived_image_identical_to_c3a
[[ "$NEW_BYTES" -ge "$C3A_BYTES" ]] || fail "derived_image_smaller_than_c3a bytes=$NEW_BYTES"
[[ "$NEW_BYTES" -le $((C3A_BYTES + MAX_ADDED_BYTES)) ]] ||
  fail "derived_image_growth_excessive bytes=$NEW_BYTES"

python3 "$GSI_INFO" --image "$NEW_SYSTEM" |
  tee "$RUN_EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_info
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_not_raw
grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$NEW_BYTES" "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_gsi_logical_size

: > "$RUN_EVIDENCE/module-membership.txt"
for module in "${MODULES[@]}"; do
  mapfile -t hits < <(
    find "$PRODUCT_OUT/system/product" -type f -name "$module.apk" -print 2>/dev/null |
      LC_ALL=C sort
  )
  [[ "${#hits[@]}" -eq 1 ]] ||
    fail "module_output_count module=$module count=${#hits[@]}"
  printf '%s\t%s\n' "$module" "${hits[0]}" >> "$RUN_EVIDENCE/module-membership.txt"
done

echo "N1F_BUILD=PASS"
echo "N1F_SYSTEM_IMG=$NEW_SYSTEM"
echo "N1F_SYSTEM_SHA256=$NEW_SHA"
echo "N1F_SYSTEM_BYTES=$NEW_BYTES"
echo "N1F_MODULE_MEMBERSHIP=PASS count=5"

echo
echo "===== PHASE 4: PRESERVE DERIVED IMAGE BEFORE DEVICE WRITE ====="

mkdir -p "$C3B5_ARTIFACT"
cp --reflink=auto --sparse=always "$NEW_SYSTEM" "$C3B5_ARTIFACT/system.img"
cp "$APP_BUNDLE/manifest.tsv" "$C3B5_ARTIFACT/app-manifest.tsv"
cp "$APP_BUNDLE/SHA256SUMS.txt" "$C3B5_ARTIFACT/app-SHA256SUMS.txt"
cp "$RUN_EVIDENCE/module-membership.txt" "$C3B5_ARTIFACT/module-membership.txt"
cp "$RUN_EVIDENCE/source-delta.txt" "$C3B5_ARTIFACT/source-delta.txt"
cp "$RUN_EVIDENCE/system-image-info.txt" "$C3B5_ARTIFACT/system-image-info.txt"

cat > "$C3B5_ARTIFACT/artifact.env" <<EOF
N1F_ROLE=C3A_DERIVED_C3B5_BOOT_ISOLATION
C3A_BASE_SYSTEM_SHA256=$C3A_SHA
C3A_BASE_SYSTEM_BYTES=$C3A_BYTES
C3A_CONTROL_PATCH_COUNT=369
SABLE_MODULE_COUNT=5
COMPATIBILITY_PATCH_DELTA=0
SYSTEM_SHA256=$NEW_SHA
SYSTEM_BYTES=$NEW_BYTES
TARGET_PARTITION=system_a
FACTORY_RESET_POLICY=NO_FOR_FIRST_ATTEMPT
EOF

(
  cd "$C3B5_ARTIFACT"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$NEW_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1F_ARTIFACT_HISTORY=PASS"
echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"

echo
echo "===== PHASE 5: RESTORE C3A SOURCE TREE ====="

cleanup_source_delta
trap - EXIT
[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_BASE_SHA" ]] ||
  fail rom_restore_sha
[[ ! -e "$STAGE_ROOT" ]] || fail stage_root_restore
echo "N1F_SOURCE_RESTORE=PASS"

echo
echo "===== PHASE 6: ENTER / VERIFY FASTBOOTD ====="

fastboot_present() {
  "$SABLE_FASTBOOT" devices 2>/dev/null |
    awk -v serial="$SERIAL" '$1==serial {found=1} END {exit found?0:1}'
}

adb_present() {
  "$SABLE_ADB" -s "$SERIAL" get-state >/dev/null 2>&1
}

wait_fastboot() {
  local i
  for ((i=0; i<60; i++)); do
    fastboot_present && return 0
    sleep 1
  done
  return 1
}

if adb_present; then
  echo "N1F_DEVICE_ENTRY=ADB_ANDROID"
  "$SABLE_ADB" -s "$SERIAL" reboot bootloader
  wait_fastboot || fail fastboot_after_adb_reboot
elif fastboot_present; then
  echo "N1F_DEVICE_ENTRY=FASTBOOT"
else
  fail device_not_visible_adb_or_fastboot
fi

fbvar() {
  local key="$1"
  "$SABLE_FASTBOOT" -s "$SERIAL" getvar "$key" 2>&1 |
    sed -n "s/.*${key}: //p" |
    tail -n1 |
    tr -d '\r'
}

IS_USERSPACE="$(fbvar is-userspace)"
if [[ "$IS_USERSPACE" != yes ]]; then
  "$SABLE_FASTBOOT" -s "$SERIAL" reboot fastboot
  wait_fastboot || fail fastbootd_mode_switch_timeout
fi

PRODUCT="$(fbvar product)"
SLOT="$(fbvar current-slot)"
IS_USERSPACE="$(fbvar is-userspace)"
UNLOCKED="$(fbvar unlocked)"
SNAPSHOT="$(fbvar snapshot-update-status)"
SYSTEM_PRE_RAW="$(fbvar partition-size:system_a)"
SYSTEM_PRE=$((SYSTEM_PRE_RAW))

echo "PRODUCT=$PRODUCT"
echo "CURRENT_SLOT=$SLOT"
echo "IS_USERSPACE=$IS_USERSPACE"
echo "UNLOCKED=$UNLOCKED"
echo "SNAPSHOT_UPDATE_STATUS=$SNAPSHOT"
echo "SYSTEM_A_PRE_BYTES=$SYSTEM_PRE"

[[ "$PRODUCT" == Titan_2 ]] || fail "product=$PRODUCT"
[[ "$SLOT" == a ]] || fail "slot=$SLOT"
[[ "$IS_USERSPACE" == yes ]] || fail not_fastbootd
[[ "$UNLOCKED" == yes ]] || fail bootloader_not_unlocked
[[ "$SNAPSHOT" == none ]] || fail "snapshot=$SNAPSHOT"
[[ "$SYSTEM_PRE" -eq "$C3A_BYTES" ]] ||
  fail "system_pre expected=$C3A_BYTES actual=$SYSTEM_PRE"

GETVAR_ALL="$("$SABLE_FASTBOOT" -s "$SERIAL" getvar all 2>&1)"
if printf '%s\n' "$GETVAR_ALL" |
  grep -Eiq 'is-logical:[^[:space:]]+_a-cow:[[:space:]]*yes'
then
  fail active_slot_cow_present
fi

GROWTH=$((NEW_BYTES - SYSTEM_PRE))
[[ "$GROWTH" -ge 0 ]] || fail negative_growth
[[ "$GROWTH" -le "$MAX_ADDED_BYTES" ]] || fail "growth_excessive=$GROWTH"

echo "N1F_PREFLASH=PASS"
echo "N1F_SYSTEM_GROWTH_BYTES=$GROWTH"
echo "N1F_ACTIVE_COW=PASS_ZERO"

echo
echo "===== PHASE 7: FLASH SYSTEM_A EXACTLY ONCE ====="

set +e
"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$C3B5_ARTIFACT/system.img"
FLASH_RC=$?
set -e
echo "N1F_FASTBOOT_FLASH_SYSTEM_A_RC=$FLASH_RC"
[[ "$FLASH_RC" -eq 0 ]] || fail "flash_failed_no_retry rc=$FLASH_RC"

SYSTEM_POST_RAW="$(fbvar partition-size:system_a)"
SYSTEM_POST=$((SYSTEM_POST_RAW))
POST_SLOT="$(fbvar current-slot)"
POST_USERSPACE="$(fbvar is-userspace)"
POST_SNAPSHOT="$(fbvar snapshot-update-status)"

echo "SYSTEM_A_POST_BYTES=$SYSTEM_POST"
echo "POST_SLOT=$POST_SLOT"
echo "POST_IS_USERSPACE=$POST_USERSPACE"
echo "POST_SNAPSHOT_UPDATE_STATUS=$POST_SNAPSHOT"

[[ "$SYSTEM_POST" -eq "$NEW_BYTES" ]] || fail "postflash_size expected=$NEW_BYTES actual=$SYSTEM_POST"
[[ "$POST_SLOT" == a ]] || fail postflash_slot
[[ "$POST_USERSPACE" == yes ]] || fail postflash_not_fastbootd
[[ "$POST_SNAPSHOT" == none ]] || fail postflash_snapshot

echo "N1F_SYSTEM_A_FLASH=PASS"

echo
echo "===== PHASE 8: REBOOT ONCE + BOOT OBSERVATION ====="

"$SABLE_FASTBOOT" -s "$SERIAL" reboot
echo "N1F_REBOOT=PASS_SENT_ONCE"
echo "FACTORY_RESET=NOT_PERFORMED"

FASTBOOT_LEFT=NO
for ((i=0; i<30; i++)); do
  if ! fastboot_present; then
    FASTBOOT_LEFT=YES
    break
  fi
  sleep 1
done
[[ "$FASTBOOT_LEFT" == YES ]] || fail reboot_did_not_leave_fastboot

iterations=$((BOOT_OBSERVE_SECONDS / 2))
(( iterations > 0 )) || iterations=1
for ((i=0; i<iterations; i++)); do
  if fastboot_present; then
    echo "N1F_BOOT_RESULT=FAIL_FASTBOOT_RETURNED"
    echo "N1F_FACTORY_RESET=NOT_PERFORMED"
    exit 2
  fi

  if adb_present; then
    BOOTMODE="$("$SABLE_ADB" -s "$SERIAL" shell getprop ro.bootmode 2>/dev/null | tr -d '\r')"
    BOOT_COMPLETED="$("$SABLE_ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    echo "ADB_BOOTMODE=${BOOTMODE:-UNKNOWN}"
    echo "ADB_SYS_BOOT_COMPLETED=${BOOT_COMPLETED:-UNKNOWN}"

    if [[ "${BOOTMODE,,}" == *recovery* ]]; then
      echo "N1F_BOOT_RESULT=RECOVERY"
      echo "N1F_FACTORY_RESET=NOT_PERFORMED"
      exit 3
    fi

    if [[ "$BOOT_COMPLETED" == 1 ]]; then
      missing=0
      : > "$RUN_EVIDENCE/runtime-package-paths.txt"
      for package in "${PACKAGES[@]}"; do
        path="$("$SABLE_ADB" -s "$SERIAL" shell pm path "$package" 2>/dev/null | tr -d '\r')"
        printf '%s\t%s\n' "$package" "$path" | tee -a "$RUN_EVIDENCE/runtime-package-paths.txt"
        [[ "$path" == package:* ]] || missing=$((missing + 1))
      done
      [[ "$missing" -eq 0 ]] || fail "runtime_sable_packages_missing=$missing"

      echo "N1F_RUNTIME_SABLE_PACKAGES=PASS count=5"
      echo "N1F_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED"
      echo "N1F_FACTORY_RESET=NOT_PERFORMED"
      echo "N1F_COMBINED_BUILD_FLASH=PASS"
      echo "RUN_EVIDENCE=$RUN_EVIDENCE"
      echo "C3A_HISTORY_DIR=$C3A_HISTORY"
      echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"
      exit 0
    fi
  fi

  sleep 2
done

echo "N1F_BOOT_RESULT=MANUAL_UI_CHECK_REQUIRED_NO_FASTBOOT_RETURN"
echo "N1F_FACTORY_RESET=NOT_PERFORMED"
echo "N1F_COMBINED_BUILD_FLASH=PASS_BUILD_FLASH_OBSERVATION_INCONCLUSIVE"
echo "RUN_EVIDENCE=$RUN_EVIDENCE"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "N1F_ARTIFACT_DIR=$C3B5_ARTIFACT"
