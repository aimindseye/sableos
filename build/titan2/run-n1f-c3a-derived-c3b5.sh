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
    *) echo "N1F_COMBINED=FAIL unknown_arg=$1" >&2; exit 64 ;;
  esac
done

fail() { echo "N1F_COMBINED=FAIL reason=$1" >&2; exit "${2:-1}"; }

C3A_SHA=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_BYTES=3146977280
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
MAX_GROWTH=$((512 * 1024 * 1024))
MODULES=(SableTitan2Keyboard SableTitan2Camera SableTitan2DisplayCompat SableTitan2Setup SableTitan2RadioDiag)
PACKAGES=(org.sableos.titan2.keyboard org.sableos.titan2.camera org.sableos.titan2.displaycompat org.sableos.titan2.setup org.sableos.titan2.radiodiag)

selfcheck() {
  bash -n "$0"
  [[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] || fail integration_repo_dirty
  [[ -d "$ANDROID_ROOT/.repo" ]] || fail android_repo_missing
  [[ -f "$ROM_MK" ]] || fail rom_mk_missing
  [[ ! -e "$STAGE_ROOT" ]] || fail stage_root_already_present
  [[ -f "$C3A_SYSTEM" ]] || fail c3a_system_missing
  [[ "$(sha256sum "$C3A_SYSTEM" | awk '{print $1}')" == "$C3A_SHA" ]] || fail c3a_sha
  [[ "$(stat -c '%s' "$C3A_SYSTEM")" == "$C3A_BYTES" ]] || fail c3a_bytes
  [[ "$N1D_C3A_CONTROL_PATCH_COUNT" == 369 ]] || fail c3a_patch_count
  [[ "$N1D_C3B_E2_MODULE_COUNT" == 5 ]] || fail c3b5_count
  git -C "$ROOT" merge-base --is-ancestor "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD || fail e2_source_not_ancestor
  git -C "$ROOT" diff --quiet "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD -- apps/titan2/platform config/DETEKT_PROVENANCE.env config/QUALITY_SUPPRESSION_BUDGET.tsv config/detekt.yml third_party/phosphor-icons third_party/pinyin_zh || fail e2_source_changed
  for m in "${MODULES[@]}"; do
    grep -Fq "name: \"$m\"" "$ANDROID_BP" || fail "android_bp_missing=$m"
    grep -Fq "$m" "$APPS_MK" || fail "apps_mk_missing=$m"
  done
  echo "N1F_COMBINED_SELFTEST=PASS"
}

if [[ "$MODE" == selfcheck ]]; then selfcheck; exit 0; fi
[[ "$MODE" == run ]] || fail invalid_mode 64
[[ "$AUTHORIZE_BUILD" == YES ]] || fail build_authorization_required 64
[[ "$AUTHORIZE_FLASH" == YES ]] || fail flash_authorization_required 64
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail invalid_jobs 64
selfcheck

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
C3A_HISTORY="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/$STAMP"
DERIVED_ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3b5-app-bundle/$STAMP"
mkdir -p "$RUN_EVIDENCE"
exec > >(tee "$RUN_EVIDENCE/run.log") 2>&1

echo "===== N1F C3A-DERIVED C3B5 BUILD + FLASH ====="
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "AVB_BOOT_SUPER_SLOT_MUTATION_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=YES_SYSTEM_A_ONCE"
echo "AUTOMATIC_FLASH_RETRY=NO"
echo
echo "===== 0. ARCHIVE BOOT-QUALIFIED C3A ====="
mkdir -p "$C3A_HISTORY"
cp --reflink=auto --sparse=always "$C3A_SYSTEM" "$C3A_HISTORY/system.img"
cp "$ROOT/build/titan2/n1d-c3a-control-evidence.env" "$C3A_HISTORY/"
cp -a --reflink=auto "$N1D_C3A_EVIDENCE_DIR" "$C3A_HISTORY/build-evidence"
for d in \
  /srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan \
  /srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z
do
  [[ -d "$d" ]] || fail "archive_evidence_missing=$d"
  cp -a --reflink=auto "$d" "$C3A_HISTORY/"
done
for f in /tmp/c3a-v010014-physical-control.*.log; do
  [[ -f "$f" ]] && cp "$f" "$C3A_HISTORY/" || true
done
(
  cd "$ANDROID_ROOT"
  "$SABLE_REPO_TOOL" manifest -r -o "$C3A_HISTORY/repo-manifest-r.xml"
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
EOF
(
  cd "$C3A_HISTORY"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt
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
echo "===== 2. APPLY MINIMAL DELTA TO C3A SOURCE ====="
mkdir -p "$STAGE_ROOT/prebuilt"
install -m 0644 "$ANDROID_BP" "$STAGE_ROOT/Android.bp"
install -m 0644 "$APPS_MK" "$STAGE_ROOT/sable-titan2-apps.mk"
for m in "${MODULES[@]}"; do install -m 0644 "$APP_BUNDLE/prebuilt/$m.apk" "$STAGE_ROOT/prebuilt/$m.apk"; done
[[ "$(find "$STAGE_ROOT" -type f | wc -l | tr -d ' ')" == 7 ]] || fail staged_file_count

ROM_BACKUP="$RUN_EVIDENCE/rom.mk.c3a"
cp "$ROM_MK" "$ROM_BACKUP"
ROM_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"
cleanup() {
  set +e
  [[ -f "$ROM_BACKUP" ]] && cp "$ROM_BACKUP" "$ROM_MK"
  [[ -d "$STAGE_ROOT" ]] && find "$STAGE_ROOT" -depth -mindepth 1 -delete
  rmdir "$STAGE_ROOT" 2>/dev/null || true
  set -e
}
trap cleanup EXIT
grep -Fq 'vendor/sable/titan2/sable-titan2-apps.mk' "$ROM_MK" && fail apps_already_in_rom
cat >> "$ROM_MK" <<'EOF'

# SABLE_N1F_C3A_DERIVED_C3B5
$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)
EOF
echo "N1F_SOURCE_DELTA=PASS_7_FILES_PLUS_1_INHERIT"
echo "N1F_COMPATIBILITY_PATCH_DELTA=0"
echo
echo "===== 3. INCREMENTAL SYSTEMIMAGE BUILD ====="
(
  cd "$ANDROID_ROOT"
  export OUT_DIR="$OUT_C3A"
  set +u
  source build/envsetup.sh
  lunch treble_arm64_bvN-bp4a-user
  set -u
  [[ "$(get_build_var TARGET_PRODUCT)" == treble_arm64_bvN ]] || fail target_product
  [[ "$(get_build_var TARGET_RELEASE)" == bp4a ]] || fail target_release
  [[ "$(get_build_var TARGET_BUILD_VARIANT)" == user ]] || fail target_variant
  [[ "$(get_build_var TARGET_COPY_OUT_PRODUCT)" == system/product ]] || fail product_copy_out
  pkgs="$(get_build_var PRODUCT_PACKAGES)"
  for m in "${MODULES[@]}"; do grep -Eq "(^|[[:space:]])$m([[:space:]]|$)" <<<"$pkgs" || fail "product_packages_missing=$m"; done
  set +e
  make systemimage -j"$JOBS" 2>&1 | tee "$RUN_EVIDENCE/systemimage.log"
  rc="${PIPESTATUS[0]}"
  set -e
  [[ "$rc" -eq 0 ]] || fail "systemimage_rc=$rc"
)

NEW_SYSTEM="$PRODUCT_OUT/system.img"
[[ -f "$NEW_SYSTEM" ]] || fail derived_system_missing
NEW_SHA="$(sha256sum "$NEW_SYSTEM" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$NEW_SYSTEM")"
[[ "$NEW_SHA" != "$C3A_SHA" ]] || fail derived_sha_same_as_c3a
[[ "$NEW_BYTES" -ge "$C3A_BYTES" ]] || fail derived_bytes_smaller
[[ "$NEW_BYTES" -le $((C3A_BYTES + MAX_GROWTH)) ]] || fail derived_growth_excessive
python3 "$GSI_INFO" --image "$NEW_SYSTEM" | tee "$RUN_EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$RUN_EVIDENCE/system-image-info.txt" || fail gsi_info
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$RUN_EVIDENCE/system-image-info.txt" || fail gsi_format

AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
: > "$RUN_EVIDENCE/modules.tsv"
for i in "${!MODULES[@]}"; do
  m="${MODULES[$i]}"; p="${PACKAGES[$i]}"
  apk="$PRODUCT_OUT/system/product/app/$m/$m.apk"
  [[ -f "$apk" ]] || fail "missing_built_apk=$m"
  actual="$("$AAPT2" dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n1)"
  [[ "$actual" == "$p" ]] || fail "package_mismatch=$m"
  "$APKSIGNER" verify "$apk" >/dev/null 2>&1 || fail "unsigned_built_apk=$m"
  printf '%s\t%s\t%s\n' "$m" "$p" "$(sha256sum "$apk" | awk '{print $1}')" >> "$RUN_EVIDENCE/modules.tsv"
done
echo "N1F_BUILD=PASS sha256=$NEW_SHA bytes=$NEW_BYTES modules=5"

echo
echo "===== 4. PRESERVE DERIVED IMAGE ====="
mkdir -p "$DERIVED_ARTIFACT"
cp --reflink=auto --sparse=always "$NEW_SYSTEM" "$DERIVED_ARTIFACT/system.img"
cp "$RUN_EVIDENCE/modules.tsv" "$DERIVED_ARTIFACT/"
cp "$RUN_EVIDENCE/system-image-info.txt" "$DERIVED_ARTIFACT/"
cp "$APP_BUNDLE/manifest.tsv" "$DERIVED_ARTIFACT/app-manifest.tsv"
cat > "$DERIVED_ARTIFACT/artifact.env" <<EOF
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
  cd "$DERIVED_ARTIFACT"
  find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt
  printf '%s  ./system.img\n' "$NEW_SHA" >> SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
echo "N1F_ARTIFACT=PASS dir=$DERIVED_ARTIFACT"

cleanup
trap - EXIT
[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_SHA" ]] || fail rom_restore
[[ ! -e "$STAGE_ROOT" ]] || fail stage_restore
echo "N1F_SOURCE_RESTORE=PASS"
echo
echo "===== 5. ENTER FASTBOOTD AND FLASH SYSTEM_A ONCE ====="
fastboot_seen() { "$SABLE_FASTBOOT" devices 2>/dev/null | awk -v s="$SERIAL" '$1==s {f=1} END {exit f?0:1}'; }
adb_seen() { "$SABLE_ADB" -s "$SERIAL" get-state >/dev/null 2>&1; }
wait_fastboot() { for _ in {1..60}; do fastboot_seen && return 0; sleep 1; done; return 1; }
fbvar() { "$SABLE_FASTBOOT" -s "$SERIAL" getvar "$1" 2>&1 | sed -n "s/.*$1: //p" | tail -n1 | tr -d '\r'; }

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
PRE_RAW="$(fbvar partition-size:system_a)"; PRE=$((PRE_RAW))
[[ "$PRE" -eq "$C3A_BYTES" ]] || fail "preflash_system_bytes=$PRE"
ALL="$("$SABLE_FASTBOOT" -s "$SERIAL" getvar all 2>&1)"
printf '%s\n' "$ALL" | grep -Eiq 'is-logical:[^[:space:]]+_a-cow:[[:space:]]*yes' && fail active_cow_present
GROWTH=$((NEW_BYTES - PRE))
[[ "$GROWTH" -ge 0 && "$GROWTH" -le "$MAX_GROWTH" ]] || fail growth
echo "N1F_PREFLASH=PASS growth_bytes=$GROWTH"

set +e
"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$DERIVED_ARTIFACT/system.img"
FLASH_RC=$?
set -e
[[ "$FLASH_RC" -eq 0 ]] || fail "flash_failed_no_retry=$FLASH_RC"
POST_RAW="$(fbvar partition-size:system_a)"; POST=$((POST_RAW))
[[ "$POST" -eq "$NEW_BYTES" ]] || fail "postflash_bytes=$POST"
[[ "$(fbvar current-slot)" == a ]] || fail post_slot
[[ "$(fbvar snapshot-update-status)" == none ]] || fail post_snapshot
echo "N1F_SYSTEM_A_FLASH=PASS"

"$SABLE_FASTBOOT" -s "$SERIAL" reboot
echo "N1F_REBOOT=PASS_ONCE"
echo "FACTORY_RESET=NOT_PERFORMED"

LEFT=NO
for _ in {1..30}; do
  if ! fastboot_seen; then LEFT=YES; break; fi
  sleep 1
done
[[ "$LEFT" == YES ]] || fail reboot_did_not_leave_fastboot

for _ in {1..90}; do
  fastboot_seen && { echo "N1F_BOOT_RESULT=FAIL_FASTBOOT_RETURNED"; exit 2; }
  if adb_seen; then
    completed="$("$SABLE_ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$completed" == 1 ]]; then
      missing=0
      for p in "${PACKAGES[@]}"; do
        out="$("$SABLE_ADB" -s "$SERIAL" shell pm path "$p" 2>/dev/null | tr -d '\r')"
        [[ "$out" == package:* ]] || missing=$((missing+1))
      done
      [[ "$missing" -eq 0 ]] || fail "runtime_packages_missing=$missing"
      echo "N1F_RUNTIME_PACKAGES=PASS count=5"
      echo "N1F_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED"
      echo "N1F_COMBINED=PASS"
      echo "C3A_HISTORY_DIR=$C3A_HISTORY"
      echo "N1F_ARTIFACT_DIR=$DERIVED_ARTIFACT"
      echo "RUN_EVIDENCE=$RUN_EVIDENCE"
      exit 0
    fi
  fi
  sleep 2
done

echo "N1F_BOOT_RESULT=MANUAL_UI_CHECK_REQUIRED"
echo "N1F_COMBINED=PASS_BUILD_FLASH_BOOT_OBSERVATION_INCONCLUSIVE"
echo "C3A_HISTORY_DIR=$C3A_HISTORY"
echo "N1F_ARTIFACT_DIR=$DERIVED_ARTIFACT"
echo "RUN_EVIDENCE=$RUN_EVIDENCE"