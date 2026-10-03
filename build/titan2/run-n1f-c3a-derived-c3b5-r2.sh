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
    *) echo "N1F_R2=FAIL unknown_arg=$1" >&2; exit 64 ;;
  esac
done

fail() {
  echo "N1F_R2=FAIL reason=$1" >&2
  exit "${2:-1}"
}

C3A_SHA=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_BYTES=3146977280
SUPER_BYTES=9663676416
MAX_GROWTH=$((512 * 1024 * 1024))

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C3A="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td"
PRODUCT_OUT="$OUT_C3A/target/product/tdgsi_arm64_ab"
C3A_SYSTEM="$N1D_C3A_SYSTEM_IMG"
ROM_MK="$ANDROID_ROOT/device/phh/treble/rom.mk"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"

APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
ANDROID_BP="$ROOT/product/titan2/c3b/Android.bp"
APPS_MK="$ROOT/product/titan2/c3b/sable-titan2-apps.mk"
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
  local stage_evidence tmp project_count

  stage_evidence="$(latest_c3a_stage)"
  [[ -n "$stage_evidence" ]] || fail c3a_stage_evidence_missing
  [[ -f "$stage_evidence/SHA256SUMS.txt" ]] || fail c3a_stage_seal_missing
  [[ -f "$stage_evidence/postpatch-project-heads.tsv" ]] ||
    fail c3a_stage_heads_missing

  (
    cd "$stage_evidence"
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
      LC_ALL=C sort > "$tmp/dirty-projects.txt"
  )

  project_count="$(grep -cve '^$' "$tmp/current-heads.tsv" || true)"
  [[ "$project_count" == "$N1D_C3A_MANAGED_PROJECT_COUNT" ]] || {
    rm -rf "$tmp"
    fail "c3a_project_count=$project_count"
  }

  LC_ALL=C sort "$stage_evidence/postpatch-project-heads.tsv" \
    > "$tmp/expected-heads.tsv"
  cmp -s "$tmp/expected-heads.tsv" "$tmp/current-heads.tsv" || {
    diff -u "$tmp/expected-heads.tsv" "$tmp/current-heads.tsv" >&2 || true
    rm -rf "$tmp"
    fail c3a_project_heads_mismatch
  }

  printf '%s\n' build/soong device/phh/treble treble_app |
    LC_ALL=C sort > "$tmp/expected-dirty.tsv"
  cmp -s "$tmp/expected-dirty.tsv" "$tmp/dirty-projects.txt" || {
    diff -u "$tmp/expected-dirty.tsv" "$tmp/dirty-projects.txt" >&2 || true
    rm -rf "$tmp"
    fail c3a_dirty_project_set
  }

  rm -rf "$tmp"
  C3A_STAGE_EVIDENCE="$stage_evidence"
  echo "N1F_R2_C3A_SOURCE=PASS projects=$project_count dirty=3"
}

selfcheck() {
  bash -n "$0"
  [[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] ||
    fail integration_repo_dirty
  [[ -d "$ANDROID_ROOT/.repo" ]] || fail android_repo_missing
  [[ -f "$ROM_MK" ]] || fail rom_mk_missing
  [[ ! -e "$STAGE_ROOT" ]] || fail stage_root_already_present
  [[ -f "$C3A_SYSTEM" ]] || fail c3a_system_missing
  [[ "$(sha256sum "$C3A_SYSTEM" | awk '{print $1}')" == "$C3A_SHA" ]] ||
    fail c3a_sha
  [[ "$(stat -c '%s' "$C3A_SYSTEM")" == "$C3A_BYTES" ]] ||
    fail c3a_bytes
  [[ "$N1D_C3A_CONTROL_PATCH_COUNT" == 369 ]] || fail c3a_patch_count
  [[ "$N1D_C3B_E2_MODULE_COUNT" == 5 ]] || fail c3b_module_count

  verify_c3a_source

  git -C "$ROOT" merge-base --is-ancestor     "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD ||
    fail e2_source_import_not_ancestor
  git -C "$ROOT" diff --quiet     "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD --     apps/titan2/platform     config/DETEKT_PROVENANCE.env     config/QUALITY_SUPPRESSION_BUDGET.tsv     config/detekt.yml     third_party/phosphor-icons     third_party/pinyin_zh ||
    fail e2_source_changed

  for module in "${MODULES[@]}"; do
    grep -Fq "name: \"$module\"" "$ANDROID_BP" ||
      fail "android_bp_missing=$module"
    grep -Fq "$module" "$APPS_MK" ||
      fail "apps_mk_missing=$module"
  done

  python3 "$GSI_INFO" --image "$C3A_SYSTEM" |
    grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' ||
    fail c3a_image_geometry

  echo "N1F_R2_SELFTEST=PASS"
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
RUN_EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1f-c3a-derived-c3b5-r2/$STAMP"
C3A_HISTORY="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/$STAMP"
DERIVED="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3b5-app-bundle/$STAMP"
mkdir -p "$RUN_EVIDENCE"
exec > >(tee "$RUN_EVIDENCE/run.log") 2>&1

echo "===== N1F R2 C3A-DERIVED C3B5 BUILD + FLASH ====="
echo "FLASH_AUTHORIZED=YES_SYSTEM_A_ONCE"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "AUTOMATIC_FLASH_RETRY=NO"
echo "AVB_BOOT_VENDOR_BOOT_SUPER_SLOT_MUTATION=NO"

echo
echo "===== 0. ARCHIVE BOOT-QUALIFIED C3A ====="
mkdir -p "$C3A_HISTORY"
cp --reflink=auto --sparse=always "$C3A_SYSTEM" "$C3A_HISTORY/system.img"
cp "$ROOT/build/titan2/n1d-c3a-control-evidence.env" "$C3A_HISTORY/"
cp "$ROM_MK" "$C3A_HISTORY/device-phh-treble-rom.mk"
cp -a --reflink=auto "$N1D_C3A_EVIDENCE_DIR" "$C3A_HISTORY/build-evidence"
cp -a --reflink=auto "$C3A_STAGE_EVIDENCE" "$C3A_HISTORY/c3a-stage-evidence"

for evidence in \
  /srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan \
  /srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z
do
  [[ -d "$evidence" ]] || fail "archive_evidence_missing=$evidence"
  cp -a --reflink=auto "$evidence" "$C3A_HISTORY/"
done

for runtime_log in /tmp/c3a-v010014-physical-control.*.log; do
  [[ -f "$runtime_log" ]] && cp "$runtime_log" "$C3A_HISTORY/" || true
done
for radio_dir in /tmp/titan2-restless-radio-*; do
  [[ -d "$radio_dir" ]] &&
    cp -a --reflink=auto "$radio_dir" "$C3A_HISTORY/" || true
done

(
  cd "$ANDROID_ROOT"
  "$SABLE_REPO_TOOL" manifest -r -o "$C3A_HISTORY/repo-manifest-r.xml"
  "$SABLE_REPO_TOOL" forall -c \
    'printf "%s\\t%s\\n" "$REPO_PATH" "$(git rev-parse HEAD)"' |
    LC_ALL=C sort > "$C3A_HISTORY/all-project-heads.tsv"
  "$SABLE_REPO_TOOL" forall -c \
    's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "### %s\\n%s\\n" "$REPO_PATH" "$s"; fi' \
    > "$C3A_HISTORY/dirty-project-state.txt"
)
printf '%s\n' "$(git -C "$ROOT" rev-parse HEAD)" \
  > "$C3A_HISTORY/sableos-integration-head.txt"

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
EOF

(
  cd "$C3A_HISTORY"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$C3A_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
echo "C3A_HISTORY=PASS dir=$C3A_HISTORY"

echo
echo "===== 1. BUILD FIVE ADMITTED SABLE APKS OFFLINE ====="
bash "$APP_BUILD" --authorize-app-build --output-dir "$APP_BUNDLE"
(
  cd "$APP_BUNDLE/prebuilt"
  sha256sum -c ../SHA256SUMS.txt >/dev/null
)

echo
echo "===== 2. APPLY EXACT FIVE-APP DELTA ====="
mkdir -p "$STAGE_ROOT/prebuilt"
install -m 0644 "$ANDROID_BP" "$STAGE_ROOT/Android.bp"
install -m 0644 "$APPS_MK" "$STAGE_ROOT/sable-titan2-apps.mk"
for module in "${MODULES[@]}"; do
  install -m 0644     "$APP_BUNDLE/prebuilt/$module.apk"     "$STAGE_ROOT/prebuilt/$module.apk"
done
[[ "$(find "$STAGE_ROOT" -type f | wc -l | tr -d ' ')" == 7 ]] ||
  fail staged_file_count

ROM_BACKUP="$RUN_EVIDENCE/rom.mk.c3a"
cp "$ROM_MK" "$ROM_BACKUP"
ROM_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"

cleanup_source() {
  set +e
  [[ -f "$ROM_BACKUP" ]] && cp "$ROM_BACKUP" "$ROM_MK"
  if [[ -d "$STAGE_ROOT" ]]; then
    find "$STAGE_ROOT" -depth -mindepth 1 -delete
    rmdir "$STAGE_ROOT" 2>/dev/null || true
  fi
  set -e
}
trap cleanup_source EXIT

grep -Fq 'vendor/sable/titan2/sable-titan2-apps.mk' "$ROM_MK" &&
  fail apps_already_in_rom
cat >> "$ROM_MK" <<'EOF'

# SABLE_N1F_C3A_DERIVED_C3B5
$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)
EOF
echo "N1F_R2_SOURCE_DELTA=PASS_7_FILES_PLUS_1_INHERIT"
echo "N1F_R2_COMPATIBILITY_PATCH_DELTA=0"

echo
echo "===== 3. BUILD C3A-DERIVED SYSTEMIMAGE ====="
(
  cd "$ANDROID_ROOT"
  export OUT_DIR="$OUT_C3A"
  set +u
  source build/envsetup.sh
  lunch treble_arm64_bvN-bp4a-user
  set -u

  [[ "$(get_build_var TARGET_PRODUCT)" == treble_arm64_bvN ]] ||
    fail target_product
  [[ "$(get_build_var TARGET_RELEASE)" == bp4a ]] ||
    fail target_release
  [[ "$(get_build_var TARGET_BUILD_VARIANT)" == user ]] ||
    fail target_variant
  [[ "$(get_build_var TARGET_COPY_OUT_PRODUCT)" == system/product ]] ||
    fail product_copy_out

  product_packages="$(get_build_var PRODUCT_PACKAGES)"
  for module in "${MODULES[@]}"; do
    grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" \
      <<<"$product_packages" ||
      fail "product_packages_missing=$module"
  done

  set +e
  make systemimage -j"$JOBS" 2>&1 | tee "$RUN_EVIDENCE/systemimage.log"
  build_rc="${PIPESTATUS[0]}"
  set -e
  [[ "$build_rc" -eq 0 ]] || fail "systemimage_rc=$build_rc"
)

NEW_SYSTEM="$PRODUCT_OUT/system.img"
[[ -f "$NEW_SYSTEM" ]] || fail derived_system_missing
NEW_SHA="$(sha256sum "$NEW_SYSTEM" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$NEW_SYSTEM")"
[[ "$NEW_SHA" != "$C3A_SHA" ]] || fail derived_sha_same_as_c3a
[[ "$NEW_BYTES" -ge "$C3A_BYTES" ]] || fail derived_bytes_smaller
[[ "$NEW_BYTES" -le $((C3A_BYTES + MAX_GROWTH)) ]] ||
  fail derived_growth_excessive

python3 "$GSI_INFO" --image "$NEW_SYSTEM" |
  tee "$RUN_EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_image_geometry
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$RUN_EVIDENCE/system-image-info.txt" ||
  fail derived_image_format

AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
: > "$RUN_EVIDENCE/modules.tsv"
for i in "${!MODULES[@]}"; do
  module="${MODULES[$i]}"
  package="${PACKAGES[$i]}"
  apk="$PRODUCT_OUT/system/product/app/$module/$module.apk"
  [[ -f "$apk" ]] || fail "built_apk_missing=$module"
  actual_package="$(
    "$AAPT2" dump badging "$apk" |
      sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" |
      head -n1
  )"
  [[ "$actual_package" == "$package" ]] ||
    fail "package_mismatch=$module"
  "$APKSIGNER" verify "$apk" >/dev/null 2>&1 ||
    fail "system_apk_unsigned=$module"
  printf '%s\t%s\t%s\n'     "$module" "$package" "$(sha256sum "$apk" | awk '{print $1}')"     >> "$RUN_EVIDENCE/modules.tsv"
done

echo "N1F_R2_BUILD=PASS sha256=$NEW_SHA bytes=$NEW_BYTES modules=5"

echo
echo "===== 4. PRESERVE DERIVED IMAGE ====="
mkdir -p "$DERIVED"
cp --reflink=auto --sparse=always "$NEW_SYSTEM" "$DERIVED/system.img"
cp "$RUN_EVIDENCE/modules.tsv" "$DERIVED/"
cp "$RUN_EVIDENCE/system-image-info.txt" "$DERIVED/"
cp "$APP_BUNDLE/manifest.tsv" "$DERIVED/app-manifest.tsv"
cat > "$DERIVED/artifact.env" <<EOF
ROLE=C3A_DERIVED_C3B5_BOOT_ISOLATION
BASE_C3A_SHA256=$C3A_SHA
BASE_C3A_BYTES=$C3A_BYTES
COMPATIBILITY_PATCH_COUNT=369
COMPATIBILITY_PATCH_DELTA=0
SABLE_MODULE_COUNT=5
SYSTEM_SHA256=$NEW_SHA
SYSTEM_BYTES=$NEW_BYTES
TARGET_PARTITION=system_a
EOF
(
  cd "$DERIVED"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$NEW_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
echo "N1F_R2_ARTIFACT=PASS dir=$DERIVED"

cleanup_source
trap - EXIT
[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_SHA" ]] ||
  fail rom_restore
[[ ! -e "$STAGE_ROOT" ]] || fail stage_restore
echo "N1F_R2_SOURCE_RESTORE=PASS"

echo
echo "===== 5. VERIFY FASTBOOTD AND FLASH SYSTEM_A ONCE ====="

fastboot_seen() {
  "$SABLE_FASTBOOT" devices 2>/dev/null |
    awk -v serial="$SERIAL" '$1==serial {found=1} END {exit found?0:1}'
}
adb_seen() {
  "$SABLE_ADB" -s "$SERIAL" get-state >/dev/null 2>&1
}
wait_fastboot() {
  local _
  for _ in {1..60}; do
    fastboot_seen && return 0
    sleep 1
  done
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

[[ "$(fbvar product)" == Titan_2 ]] || fail product
[[ "$(fbvar current-slot)" == a ]] || fail slot
[[ "$(fbvar is-userspace)" == yes ]] || fail userspace
[[ "$(fbvar unlocked)" == yes ]] || fail unlocked
[[ "$(fbvar snapshot-update-status)" == none ]] || fail snapshot
SUPER_RAW="$(fbvar partition-size:super)"
[[ "$((SUPER_RAW))" -eq "$SUPER_BYTES" ]] || fail super_bytes
PRE_RAW="$(fbvar partition-size:system_a)"
PRE_BYTES=$((PRE_RAW))
[[ "$PRE_BYTES" -eq "$C3A_BYTES" ]] ||
  fail "preflash_system_bytes=$PRE_BYTES"

for cow in   system_a-cow system_ext_a-cow product_a-cow vendor_a-cow odm_a-cow   system_dlkm_a-cow vendor_dlkm_a-cow odm_dlkm_a-cow
do
  logical="$(fbvar "is-logical:$cow")"
  size_raw="$(fbvar "partition-size:$cow")"
  size=0
  [[ -z "$size_raw" ]] || size=$((size_raw))
  [[ "$logical" != yes && "$size" -eq 0 ]] ||
    fail "active_cow_present=$cow"
done

GROWTH=$((NEW_BYTES - PRE_BYTES))
[[ "$GROWTH" -ge 0 && "$GROWTH" -le "$MAX_GROWTH" ]] ||
  fail "growth_bytes=$GROWTH"
echo "N1F_R2_PREFLASH=PASS growth_bytes=$GROWTH"

set +e
"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$DERIVED/system.img"
FLASH_RC=$?
set -e
[[ "$FLASH_RC" -eq 0 ]] || fail "flash_failed_no_retry=$FLASH_RC"

POST_RAW="$(fbvar partition-size:system_a)"
POST_BYTES=$((POST_RAW))
[[ "$POST_BYTES" -eq "$NEW_BYTES" ]] ||
  fail "postflash_bytes=$POST_BYTES"
[[ "$(fbvar current-slot)" == a ]] || fail post_slot
[[ "$(fbvar is-userspace)" == yes ]] || fail post_fastbootd
[[ "$(fbvar snapshot-update-status)" == none ]] || fail post_snapshot
echo "N1F_R2_SYSTEM_A_FLASH=PASS"

"$SABLE_FASTBOOT" -s "$SERIAL" reboot
echo "N1F_R2_REBOOT=PASS_ONCE"
echo "FACTORY_RESET=NOT_PERFORMED"

LEFT_FASTBOOT=NO
for _ in {1..30}; do
  if ! fastboot_seen; then
    LEFT_FASTBOOT=YES
    break
  fi
  sleep 1
done
[[ "$LEFT_FASTBOOT" == YES ]] || fail reboot_did_not_leave_fastboot

for _ in {1..90}; do
  if fastboot_seen; then
    echo "N1F_R2_BOOT_RESULT=FAIL_FASTBOOT_RETURNED"
    exit 2
  fi

  if adb_seen; then
    completed="$(
      "$SABLE_ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null |
        tr -d '\r'
    )"
    if [[ "$completed" == 1 ]]; then
      missing=0
      for package in "${PACKAGES[@]}"; do
        path="$(
          "$SABLE_ADB" -s "$SERIAL" shell pm path "$package" 2>/dev/null |
            tr -d '\r'
        )"
        [[ "$path" == package:* ]] || missing=$((missing + 1))
      done
      [[ "$missing" -eq 0 ]] || fail "runtime_packages_missing=$missing"
      echo "N1F_R2_RUNTIME_PACKAGES=PASS count=5"
      echo "N1F_R2_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED"
      echo "N1F_R2=PASS"
      echo "C3A_HISTORY_DIR=$C3A_HISTORY"
      echo "N1F_ARTIFACT_DIR=$DERIVED"
      echo "RUN_EVIDENCE=$RUN_EVIDENCE"
      exit 0
    fi
  fi
  sleep 2
done

echo "N1F_R2_BOOT_RESULT=MANUAL_UI_CHECK_REQUIRED"
echo "N1F_R2=PASS_BUILD_FLASH_BOOT_OBSERVATION_INCONCLUSIVE"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "N1F_ARTIFACT_DIR=$DERIVED"
echo "RUN_EVIDENCE=$RUN_EVIDENCE"
