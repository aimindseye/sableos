#!/usr/bin/env bash
# Active Titan build drivers use explicit return-code checks instead of
# errexit/pipefail. Nounset remains enabled to catch missing contract inputs.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
source "$ROOT/build/titan2/n1d-fresh-source.env"
source "$ROOT/build/titan2/n1d-c3-trebledroid.env"
source "$ROOT/build/titan2/n1d-c3a-control-evidence.env"
source "$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
source "$ROOT/build/titan2/n1i-c-oem-ims-admission.env"

RELEASE="${1:-N1I}"
MODE="${2:---direct}"
JOBS="${SABLE_BUILD_JOBS:-$(nproc --all)}"

fail() { echo "N1I_C1_BUILD=FAIL reason=$1" >&2; exit "${2:-1}"; }

case "$RELEASE" in N1I|n1i) ;; *) fail "unsupported_release=$RELEASE" 64 ;; esac
case "$MODE" in --direct|--tmux) ;; *) fail "unsupported_mode=$MODE" 64 ;; esac
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail invalid_jobs 64

SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail bad_source_commit

if [[ "$MODE" == --tmux ]]; then
  SESSION="${SABLE_TMUX_SESSION:-sable-titan2-n1i-${SOURCE_COMMIT:0:12}}"
  tmux has-session -t "$SESSION" 2>/dev/null && fail "tmux_session_exists=$SESSION" 5
  self="$ROOT/build/titan2/run-n1i-c1-cellular-isolation.sh"
  tmux new-session -d -s "$SESSION" \
    "EXPECTED_SOURCE_COMMIT='$SOURCE_COMMIT' SABLE_BUILD_JOBS='$JOBS' bash '$self' N1I --direct; rc=\$?; echo; echo N1I_C1_BUILD_RC=\$rc; echo BUILD_DRIVER_EXITED=YES; exit \$rc" ||
    fail "tmux_new_session_failed=$SESSION"
  tmux set-window-option -t "$SESSION" remain-on-exit on >/dev/null ||
    fail "tmux_remain_on_exit_failed=$SESSION"
  echo "N1I_C1_BUILD=PASS_STARTED"
  echo "SESSION=$SESSION"
  echo "SESSION_RETENTION=remain-on-exit"
  echo "ATTACH=tmux attach -t $SESSION"
  exit 0
fi

[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$SOURCE_COMMIT" ]] || fail source_identity
[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] || fail sable_repo_dirty

# Hard Android 16 boundary and previously-approved N1I decisions.
[[ "$N1D_AOSP_REVISION" == android-16.0.0_r4 ]] || fail "aosp_revision=$N1D_AOSP_REVISION"
[[ "$N1D_GRAPHENE_MANIFEST_REF" == refs/tags/2026061600 ]] || fail "graphene_manifest_ref=$N1D_GRAPHENE_MANIFEST_REF"
[[ "$N1D_C3_GRAPHENEOS_TAG" == 2026061600 ]] || fail "graphene_tag=$N1D_C3_GRAPHENEOS_TAG"
[[ "$N1D_C3_RESTLESS_TAG" == 16.0.0-* ]] || fail "restless_tag=$N1D_C3_RESTLESS_TAG"
[[ "$N1D_C3_RELEASE_CONFIG" == bp4a ]] || fail "release_config=$N1D_C3_RELEASE_CONFIG"
[[ "$N1D_C3_GENERATED_PRODUCT" == treble_arm64_bvN ]] || fail "generated_product=$N1D_C3_GENERATED_PRODUCT"
[[ "$N1D_C3_CONTROL_PATCH_COUNT" == 369 ]] || fail "c3a_patch_count=$N1D_C3_CONTROL_PATCH_COUNT"
[[ "$N1I_C_REGISTRATION_DATA_AND_IMS_VOICE_EXPERIMENTS_SEPARATE" == YES ]] || fail n1i_separation
[[ "$N1I_C_APN_ONLY_FIX_JUSTIFIED" == NO ]] || fail apn_only_forbidden
[[ "$N1I_C_PROPERTY_HOLD_ALLOWED" == NO ]] || fail property_hold_forbidden
[[ "$N1I_C_PERIODIC_RIL_RESTART_ALLOWED" == NO ]] || fail ril_restart_forbidden
[[ "$N1I_C_PERMISSIVE_SELINUX_ALLOWED" == NO ]] || fail permissive_forbidden
[[ "$N1I_C_FULL_STOCK_SYSTEM_EXT_IMPORT_ALLOWED" == NO ]] || fail stock_system_ext_hybrid_forbidden
[[ "$N1I_C_FULL_STOCK_VENDOR_COPY_ALLOWED" == NO ]] || fail stock_vendor_copy_forbidden
[[ "$N1I_C_TREBLEDROID_MTK_IMS_RETRY_ALLOWED" == NO ]] || fail trebledroid_ims_retry_forbidden
[[ "$N1I_C_OEM_MTKIMS_NEXT_IMPLEMENTATION_PATH" == YES ]] || fail oem_ims_not_admitted

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_DIR_N1I="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-n1i-c1-${SOURCE_COMMIT:0:12}"
PRODUCT_OUT="$OUT_DIR_N1I/target/product/tdgsi_arm64_ab"
ROM_MK="$ANDROID_ROOT/device/phh/treble/rom.mk"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"
C3B_STAGE="$STAGE_ROOT/c3b"
C1_STAGE="$STAGE_ROOT/n1i-c1"

C3A_CONTROL="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/20261003T221350Z/system.img"
N1F_CONTROL="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img"
C3A_SHA="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
N1F_SHA="dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a"
N1F_BYTES=3200540672
MAX_GROWTH=$((768 * 1024 * 1024))

STOCK_REF="$SABLE_TITAN2_ROOT/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference"
STOCK_SYSTEM="$STOCK_REF/system.img"
STOCK_SYSTEM_EXT="$STOCK_REF/system_ext.img"
STOCK_SYSTEM_SHA="b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd"
STOCK_SYSTEM_EXT_SHA="1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170"

APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
C3B_TEMPLATE="$ROOT/product/titan2/c3b"
C1_TEMPLATE="$ROOT/product/titan2/n1i-c1"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"
CONTRACT="$ROOT/build/gates/n1i-c1-android16-contract.py"

MODULES=(SableTitan2Keyboard SableTitan2Camera SableTitan2DisplayCompat SableTitan2Setup SableTitan2RadioDiag)
PACKAGES=(org.sableos.titan2.keyboard org.sableos.titan2.camera org.sableos.titan2.displaycompat org.sableos.titan2.setup org.sableos.titan2.radiodiag)

latest_c3a_stage() {
  find "$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-prep" -mindepth 1 -maxdepth 1 -type d -name '*-trebledroid-stage' -print 2>/dev/null |
    LC_ALL=C sort | tail -1
}

verify_c3a_source() {
  local stage tmp count
  stage="$(latest_c3a_stage)"
  [[ -n "$stage" && -f "$stage/SHA256SUMS.txt" && -f "$stage/postpatch-project-heads.tsv" ]] || fail c3a_stage_evidence_missing
  (cd "$stage"; sha256sum -c SHA256SUMS.txt >/dev/null) || fail c3a_stage_seal
  tmp="$(mktemp -d)"
  (
    cd "$ANDROID_ROOT"
    "$SABLE_REPO_TOOL" forall -c 'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"' | LC_ALL=C sort > "$tmp/current.tsv"
    "$SABLE_REPO_TOOL" forall -c 's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "%s\n" "$REPO_PATH"; fi' | LC_ALL=C sort > "$tmp/dirty.tsv"
  )
  count="$(grep -cve '^$' "$tmp/current.tsv" || true)"
  [[ "$count" == "$N1D_C3A_MANAGED_PROJECT_COUNT" ]] || { rm -rf "$tmp"; fail "c3a_project_count=$count"; }
  LC_ALL=C sort "$stage/postpatch-project-heads.tsv" > "$tmp/expected.tsv"
  cmp -s "$tmp/expected.tsv" "$tmp/current.tsv" || { diff -u "$tmp/expected.tsv" "$tmp/current.tsv" >&2 || true; rm -rf "$tmp"; fail c3a_heads; }
  printf '%s\n' build/soong device/phh/treble treble_app | LC_ALL=C sort > "$tmp/expected-dirty.tsv"
  cmp -s "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" || { diff -u "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" >&2 || true; rm -rf "$tmp"; fail c3a_dirty_set; }
  rm -rf "$tmp"
  echo "N1I_C1_C3A_SOURCE=PASS projects=$count dirty=3"
}

verify_audit() {
  local e="$N1I_C_AUDIT_EVIDENCE_DIR"
  [[ "$(sha256sum "$e/N1I_A_V010014_OEM_IMS_REPORT.md" | awk '{print $1}')" == "$N1I_C_AUDIT_REPORT_SHA256" ]] || fail audit_report_hash
  [[ "$(sha256sum "$e/n1i-a-v010014-oem-ims.env" | awk '{print $1}')" == "$N1I_C_AUDIT_ENV_SHA256" ]] || fail audit_env_hash
  [[ "$(sha256sum "$e/a3-framework-jars.tsv" | awk '{print $1}')" == "$N1I_C_A3_FRAMEWORK_JARS_SHA256" ]] || fail audit_a3_hash
  [[ "$(sha256sum "$e/a4-native-closure.tsv" | awk '{print $1}')" == "$N1I_C_A4_NATIVE_CLOSURE_SHA256" ]] || fail audit_a4_hash
  [[ "$(sha256sum "$e/a6-permissions-sysconfig-overlays.tsv" | awk '{print $1}')" == "$N1I_C_A6_PERMISSIONS_SYSCONFIG_SHA256" ]] || fail audit_a6_hash
  [[ "$(sha256sum "$e/a7-selinux.tsv" | awk '{print $1}')" == "$N1I_C_A7_SELINUX_SHA256" ]] || fail audit_a7_hash
  grep -Fxq 'N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS' "$e/n1i-a-v010014-oem-ims.env" || fail audit_not_pass
  echo "N1I_C1_AUDIT_INPUTS=PASS_EXACT"
}

selfcheck() {
  bash -n "$0"
  python3 "$CONTRACT"
  [[ -d "$ANDROID_ROOT/.repo" && -f "$ROM_MK" ]] || fail android_workspace
  [[ ! -e "$STAGE_ROOT" ]] || fail stage_root_present
  [[ -f "$C3A_CONTROL" && "$(sha256sum "$C3A_CONTROL" | awk '{print $1}')" == "$C3A_SHA" ]] || fail c3a_control
  [[ -f "$N1F_CONTROL" && "$(sha256sum "$N1F_CONTROL" | awk '{print $1}')" == "$N1F_SHA" ]] || fail n1f_control
  [[ "$(stat -c '%s' "$N1F_CONTROL")" == "$N1F_BYTES" ]] || fail n1f_bytes
  [[ -f "$STOCK_SYSTEM" && "$(sha256sum "$STOCK_SYSTEM" | awk '{print $1}')" == "$STOCK_SYSTEM_SHA" ]] || fail stock_system
  [[ -f "$STOCK_SYSTEM_EXT" && "$(sha256sum "$STOCK_SYSTEM_EXT" | awk '{print $1}')" == "$STOCK_SYSTEM_EXT_SHA" ]] || fail stock_system_ext
  bash "$ROOT/build/host/verify-host-tools.sh" aosp-host >/dev/null
  for t in debugfs fsck.erofs; do command -v "$t" >/dev/null || fail "host_tool=$t"; done
  verify_c3a_source
  verify_audit
  grep -Fq 'Replaces the N1I-A keyword heuristic.' "$ROOT/build/titan2/n1i-b2-native.py" || fail b2_native_supersession_missing
  grep -Fq 'candidate/coverage evidence only; native import not authorized' "$ROOT/build/titan2/n1i-b2-ledger.py" || fail b2_native_import_boundary_missing
  echo "N1I_C1_B2_NATIVE_AUTHORITY=PASS_NO_INITIAL_STOCK_SO_IMPORT"
  git -C "$ROOT" merge-base --is-ancestor "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD || fail e2_source_import
  git -C "$ROOT" diff --quiet "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD -- apps/titan2/platform config/DETEKT_PROVENANCE.env config/QUALITY_SUPPRESSION_BUDGET.tsv config/detekt.yml third_party/phosphor-icons third_party/pinyin_zh || fail five_app_source_changed
  echo "N1I_C1_SELFTEST=PASS"
}

image_type() {
  local img="$1"
  if [[ "$(od -An -tx1 -j 0 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == 3aff26ed ]]; then echo sparse
  elif [[ "$(od -An -tx1 -j 1080 -N 2 "$img" 2>/dev/null | tr -d ' \n')" == 53ef ]]; then echo ext4
  elif [[ "$(od -An -tx1 -j 1024 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == e2e1f5e0 ]]; then echo erofs
  else echo unknown; fi
}

extract_fs() {
  local img="$1" dest="$2" kind raw
  kind="$(image_type "$img")"; mkdir -p "$dest"
  case "$kind" in
    sparse) raw="$dest.raw.img"; "$SABLE_SIMG2IMG" "$img" "$raw" >/dev/null; extract_fs "$raw" "$dest"; rm -f "$raw" ;;
    ext4) debugfs -R "rdump / $dest" "$img" >/dev/null 2>"$dest.debugfs.log" || fail "debugfs=$img" ;;
    erofs) fsck.erofs --extract="$dest" "$img" >/dev/null 2>"$dest.erofs.log" || fail "erofs=$img" ;;
    *) fail "unsupported_image=$img" ;;
  esac
}

stock_system_root() { [[ -f "$1/system/build.prop" ]] && printf '%s\n' "$1/system" || printf '%s\n' "$1"; }

copy_stock_path() {
  local p="$1" sys="$2" ext="$3" src dest rel
  case "$p" in
    /system_ext/*) rel="${p#/system_ext/}"; src="$ext/$rel" ;;
    /system/*) rel="${p#/system/}"; src="$sys/$rel" ;;
    *) fail "unsupported_payload=$p" ;;
  esac
  [[ -f "$src" ]] || fail "payload_missing=$p"
  dest="$C1_STAGE/prebuilt$p"; mkdir -p "$(dirname "$dest")"; install -m 0644 "$src" "$dest"
}

generate_property_policy() {
  local stock_cil="$1"
  local contexts="$2"
  local output="$3"
  [[ -f "$stock_cil" && -f "$contexts" ]] || fail property_policy_inputs
  python3 - "$stock_cil" "$contexts" "$output" <<'PY'
import re
import sys
from pathlib import Path

cil_path = Path(sys.argv[1])
contexts_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])
cil = cil_path.read_text(encoding="utf-8", errors="replace")

types = []
for raw in contexts_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    match = re.search(r":([A-Za-z0-9_]+):s0$", line.split()[-1])
    if not match:
        raise SystemExit(f"N1I_C1_PROPERTY_POLICY=FAIL_CONTEXT_PARSE line={line}")
    types.append(match.group(1))

if not types:
    raise SystemExit("N1I_C1_PROPERTY_POLICY=FAIL_TYPE_SET")

unique_types = sorted(set(types))
if len(types) != 9 or len(unique_types) != 5:
    raise SystemExit(
        "N1I_C1_PROPERTY_POLICY=FAIL_TYPE_SET "
        f"contexts={len(types)} unique_types={len(unique_types)}"
    )

classes = {
    "system_internal_property_type": "system_internal_prop",
    "system_restricted_property_type": "system_restricted_prop",
    "system_public_property_type": "system_public_prop",
}
members = {}
for attr, macro in classes.items():
    match = re.search(
        rf"\(typeattributeset\s+{re.escape(attr)}\s+\((.*?)\)\)",
        cil,
        re.S,
    )
    if not match:
        raise SystemExit(f"N1I_C1_PROPERTY_POLICY=FAIL_ATTRIBUTE_MISSING attr={attr}")
    members[attr] = set(re.findall(r"[A-Za-z0-9_]+", match.group(1)))

lines = [
    "# Generated at build time from pinned V01.00.14 system_ext_sepolicy.cil.",
    "# Classification is stock-derived; no property ownership class is guessed.",
]
for typ in unique_types:
    if not re.search(rf"\(type\s+{re.escape(typ)}\)", cil):
        raise SystemExit(f"N1I_C1_PROPERTY_POLICY=FAIL_TYPE_MISSING type={typ}")
    hits = [(attr, macro) for attr, macro in classes.items() if typ in members[attr]]
    if len(hits) != 1:
        raise SystemExit(
            f"N1I_C1_PROPERTY_POLICY=FAIL_CLASS_AMBIGUOUS type={typ} "
            f"classes={','.join(x[0] for x in hits) or 'none'}"
        )
    attr, macro = hits[0]
    lines.append(f"{macro}({typ})")
    print(f"N1I_C1_PROPERTY_TYPE={typ} class={attr}")

out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"N1I_C1_PROPERTY_CONTEXT_COUNT={len(types)}")
print(f"N1I_C1_PROPERTY_TYPE_COUNT={len(unique_types)}")
print("N1I_C1_PROPERTY_POLICY=PASS_STOCK_DERIVED")
PY
}

built_payload_path() {
  local p="$1"
  case "$p" in
    /system_ext/*) printf '%s/%s/%s\n' "$PRODUCT_OUT" "$COPYOUT" "${p#/system_ext/}" ;;
    /system/*) printf '%s/system/%s\n' "$PRODUCT_OUT" "${p#/system/}" ;;
    *) fail "unsupported_built_payload=$p" ;;
  esac
}

apk_package_name() {
  local apk="$1" out package
  out="$("$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump badging "$apk")" || return 1
  package="$(
    sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" <<<"$out" |
      sed -n '1p'
  )"
  [[ -n "$package" ]] || return 1
  printf '%s\n' "$package"
}

apk_shared_uid() {
  local apk="$1" out uid
  out="$("$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$apk")" || return 1
  uid="$(
    sed -n 's/.*sharedUserId[^=]*="\([^"]*\)".*/\1/p' <<<"$out" |
      sed -n '1p'
  )"
  [[ -n "$uid" ]] || return 1
  printf '%s\n' "$uid"
}

selfcheck

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-cellular-isolation/$STAMP"
ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-cellular-isolation/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-five-app-bundle/$STAMP"
WORK="$EVIDENCE/work"
[[ ! -e "$OUT_DIR_N1I" ]] || fail "fresh_out_required=$OUT_DIR_N1I"
mkdir -p "$EVIDENCE" "$ARTIFACT" "$WORK"
exec > >(tee "$EVIDENCE/build.log") 2>&1

echo "===== TITAN 2 N1I-C1 ANDROID 16 CELLULAR ISOLATION ====="
echo "ANDROID_PLATFORM=16"
echo "AOSP_REVISION=$N1D_AOSP_REVISION"
echo "GRAPHENEOS_TAG=$N1D_C3_GRAPHENEOS_TAG"
echo "RESTLESS_TAG=$N1D_C3_RESTLESS_TAG"
echo "RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
echo "BASE_CONTROL=N1F_C3A_PLUS_EXACT_FIVE_SABLE_MODULES"
echo "REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F"
echo "NEW_FUNCTIONAL_DELTA=OEM_MTK_IMS_COMPATIBILITY_ISLAND_ONLY"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

echo "===== BUILD FIVE N1F APPS OFFLINE ====="
bash "$APP_BUILD" --authorize-app-build --output-dir "$APP_BUNDLE"
(cd "$APP_BUNDLE/prebuilt"; sha256sum -c ../SHA256SUMS.txt >/dev/null)

echo "===== EXTRACT PINNED STOCK INPUTS ====="
extract_fs "$STOCK_SYSTEM" "$WORK/stock-system"
extract_fs "$STOCK_SYSTEM_EXT" "$WORK/stock-system-ext"
SYSROOT="$(stock_system_root "$WORK/stock-system")"
EXTROOT="$WORK/stock-system-ext"

echo "===== STAGE N1F + OEM IMS ISLAND ====="
ROM_BACKUP="$EVIDENCE/rom.mk.c3a"
cp "$ROM_MK" "$ROM_BACKUP"
ROM_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"
cleanup_source() {
  if [[ -f "$ROM_BACKUP" ]]; then
    cp "$ROM_BACKUP" "$ROM_MK" || true
  fi
  if [[ -d "$STAGE_ROOT" ]]; then
    find "$STAGE_ROOT" -depth -mindepth 1 -delete || true
    rmdir "$STAGE_ROOT" 2>/dev/null || true
  fi
}
trap cleanup_source EXIT

mkdir -p "$C3B_STAGE/prebuilt" "$C1_STAGE"
install -m 0644 "$C3B_TEMPLATE/Android.bp" "$C3B_STAGE/Android.bp"
install -m 0644 "$C3B_TEMPLATE/sable-titan2-apps.mk" "$C3B_STAGE/sable-titan2-apps.mk"
for module in "${MODULES[@]}"; do install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$C3B_STAGE/prebuilt/$module.apk"; done
install -m 0644 "$C1_TEMPLATE/Android.bp" "$C1_STAGE/Android.bp"
install -m 0644 "$C1_TEMPLATE/sable-titan2-n1i-c1.mk" "$C1_STAGE/sable-titan2-n1i-c1.mk"
cp -a "$C1_TEMPLATE/sepolicy" "$C1_STAGE/"
generate_property_policy \
  "$EXTROOT/etc/selinux/system_ext_sepolicy.cil" \
  "$C1_STAGE/sepolicy/system_ext/private/property_contexts" \
  "$C1_STAGE/sepolicy/system_ext/private/property.te"
copy_stock_path /system_ext/priv-app/ImsService/ImsService.apk "$SYSROOT" "$EXTROOT"
copy_stock_path /system_ext/framework/mediatek-common.jar "$SYSROOT" "$EXTROOT"
copy_stock_path /system_ext/framework/mediatek-ims-base.jar "$SYSROOT" "$EXTROOT"
while IFS= read -r p; do [[ -n "$p" ]] && copy_stock_path "$p" "$SYSROOT" "$EXTROOT"; done < "$C1_TEMPLATE/config-paths.txt"

if find "$C1_STAGE/prebuilt" -type f -name '*.so' -print -quit | grep -q .; then
  fail stock_native_payload_staged
fi
echo "N1I_C1_STOCK_NATIVE_IMPORT=PASS_ZERO_INITIAL"

[[ "$(sha256sum "$C1_STAGE/prebuilt/system_ext/priv-app/ImsService/ImsService.apk" | awk '{print $1}')" == "$N1I_C_OEM_IMS_APK_SHA256" ]] || fail ims_apk_hash
[[ "$(sha256sum "$C1_STAGE/prebuilt/system_ext/framework/mediatek-common.jar" | awk '{print $1}')" == 511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549 ]] || fail mediatek_common_hash
[[ "$(sha256sum "$C1_STAGE/prebuilt/system_ext/framework/mediatek-ims-base.jar" | awk '{print $1}')" == bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab ]] || fail mediatek_ims_base_hash

STAGED_IMS="$C1_STAGE/prebuilt/system_ext/priv-app/ImsService/ImsService.apk"
STAGED_IMS_PACKAGE="$(apk_package_name "$STAGED_IMS")" || fail staged_ims_package_parse
STAGED_IMS_UID="$(apk_shared_uid "$STAGED_IMS")" || fail staged_ims_shared_uid_parse
[[ "$STAGED_IMS_PACKAGE" == "$N1I_C_OEM_IMS_PACKAGE" ]] || fail "staged_ims_package=$STAGED_IMS_PACKAGE"
[[ "$STAGED_IMS_UID" == "$N1I_C_OEM_IMS_SHARED_UID" ]] || fail "staged_ims_shared_uid=$STAGED_IMS_UID"
echo "N1I_C1_STAGED_IMS_IDENTITY=PASS package=$STAGED_IMS_PACKAGE shared_uid=$STAGED_IMS_UID"

find "$C1_STAGE/prebuilt" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > "$EVIDENCE/payload-sha256.txt"

grep -Fq 'vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk' "$ROM_MK" && fail c1_already_in_rom
cat >> "$ROM_MK" <<'EOF'

# SABLE_N1I_C1_ANDROID16_CELLULAR_ISOLATION
$(call inherit-product, vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk)
EOF
echo "N1I_C1_SOURCE_DELTA=PASS_N1F_PLUS_OEM_IMS_ISLAND"
echo "N1I_C1_REGISTRATION_DATA_PATCH_DELTA=0"
echo "N1I_C1_COMPATIBILITY_PATCH_DELTA=0"

echo "===== BUILD ANDROID 16 SYSTEMIMAGE ====="
mkdir -p "$OUT_DIR_N1I"
(
  cd "$ANDROID_ROOT"; export OUT_DIR="$OUT_DIR_N1I"; set +u; source build/envsetup.sh; lunch treble_arm64_bvN-bp4a-user; set -u
  [[ "$(get_build_var TARGET_PRODUCT)" == treble_arm64_bvN ]] || fail target_product
  [[ "$(get_build_var TARGET_BUILD_VARIANT)" == user ]] || fail target_variant
  [[ "$(get_build_var BUILD_ID)" == BP4A.251205.006 ]] || fail build_id
  [[ "$(get_build_var PLATFORM_VERSION)" == 16 ]] || fail platform_version
  [[ "$(get_build_var TARGET_COPY_OUT_PRODUCT)" == system/product ]] || fail product_copy_out
  get_build_var TARGET_COPY_OUT_SYSTEM_EXT > "$EVIDENCE/system-ext-copyout.txt"
  pp="$(get_build_var PRODUCT_PACKAGES)"
  for module in "${MODULES[@]}" ImsService SableN1IC1MediatekCommon SableN1IC1MediatekImsBase; do
    grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" <<<"$pp" || fail "product_package=$module"
  done
  boot="$(get_build_var PRODUCT_BOOT_JARS)"
  grep -Fq 'system_ext:SableN1IC1MediatekCommon' <<<"$boot" || fail bootjar_common
  grep -Fq 'system_ext:SableN1IC1MediatekImsBase' <<<"$boot" || fail bootjar_ims

  jar_overrides="$(get_build_var PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES)"
  grep -Fq 'system_ext:SableN1IC1MediatekCommon:system_ext:mediatek-common' <<<"$jar_overrides" ||
    fail bootjar_location_override_common
  grep -Fq 'system_ext:SableN1IC1MediatekImsBase:system_ext:mediatek-ims-base' <<<"$jar_overrides" ||
    fail bootjar_location_override_ims
  echo "N1I_C1_BOOTJAR_LOCATION_OVERRIDES=PASS"

  make systemimage -j"$JOBS" > >(tee "$EVIDENCE/systemimage.log") 2>&1
  build_rc=$?
  [[ "$build_rc" -eq 0 ]] || fail "systemimage_rc=$build_rc"
)

NEW="$PRODUCT_OUT/system.img"; [[ -f "$NEW" ]] || fail system_image_missing
NEW_SHA="$(sha256sum "$NEW" | awk '{print $1}')"; NEW_BYTES="$(stat -c '%s' "$NEW")"
[[ "$NEW_SHA" != "$N1F_SHA" ]] || fail unchanged_from_n1f
[[ "$NEW_BYTES" -ge "$N1F_BYTES" && "$NEW_BYTES" -le $((N1F_BYTES + MAX_GROWTH)) ]] || fail "image_size=$NEW_BYTES"
python3 "$GSI_INFO" --image "$NEW" | tee "$EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$EVIDENCE/system-image-info.txt" || fail gsi_image_info

COPYOUT="$(cat "$EVIDENCE/system-ext-copyout.txt")"; [[ "$COPYOUT" == system/system_ext ]] || fail "system_ext_copyout=$COPYOUT"
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"; APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
IMS_OUT="$PRODUCT_OUT/$COPYOUT/priv-app/ImsService/ImsService.apk"; [[ -f "$IMS_OUT" ]] || fail ims_out

BUILT_IMS_PACKAGE="$(apk_package_name "$IMS_OUT")" || fail ims_package_parse
BUILT_IMS_UID="$(apk_shared_uid "$IMS_OUT")" || fail ims_shared_uid_parse
[[ "$BUILT_IMS_PACKAGE" == "$N1I_C_OEM_IMS_PACKAGE" ]] || fail "ims_package=$BUILT_IMS_PACKAGE"
[[ "$BUILT_IMS_UID" == "$N1I_C_OEM_IMS_SHARED_UID" ]] || fail "ims_shared_uid=$BUILT_IMS_UID"
echo "N1I_C1_BUILT_IMS_IDENTITY=PASS package=$BUILT_IMS_PACKAGE shared_uid=$BUILT_IMS_UID"

"$APKSIGNER" verify "$IMS_OUT" >/dev/null 2>&1 || fail ims_signature
FRAMEWORK_RES="$PRODUCT_OUT/system/framework/framework-res.apk"; [[ -f "$FRAMEWORK_RES" ]] || fail framework_res
IMS_CERT_OUT="$("$APKSIGNER" verify --print-certs "$IMS_OUT")" || fail ims_cert_read
PLATFORM_CERT_OUT="$("$APKSIGNER" verify --print-certs "$FRAMEWORK_RES")" || fail platform_cert_read
IMS_CERT="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$IMS_CERT_OUT" | sed -n '1p')"
PLATFORM_CERT="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$PLATFORM_CERT_OUT" | sed -n '1p')"
[[ -n "$IMS_CERT" && "$IMS_CERT" == "$PLATFORM_CERT" ]] || fail platform_resign

for jar in mediatek-common.jar mediatek-ims-base.jar; do [[ -f "$PRODUCT_OUT/$COPYOUT/framework/$jar" ]] || fail "jar=$jar"; done
BOOTPB="$PRODUCT_OUT/system/etc/classpaths/bootclasspath.pb"; [[ -f "$BOOTPB" ]] || fail bootclasspath_pb
grep -aFq '/system_ext/framework/mediatek-common.jar' "$BOOTPB" || fail bootclasspath_common
grep -aFq '/system_ext/framework/mediatek-ims-base.jar' "$BOOTPB" || fail bootclasspath_ims
while IFS= read -r p; do
  [[ -n "$p" ]] || continue
  built="$(built_payload_path "$p")"
  [[ -f "$built" ]] || fail "config_out=$p resolved=$built"
done < "$C1_TEMPLATE/config-paths.txt"

PROP="$PRODUCT_OUT/$COPYOUT/etc/selinux/system_ext_property_contexts"
SVC="$PRODUCT_OUT/$COPYOUT/etc/selinux/system_ext_service_contexts"
[[ -f "$PROP" && -f "$SVC" ]] || fail policy_outputs
grep -Fq 'vendor.ril.imsconfig.force.notify' "$PROP" || fail policy_property
grep -Fq 'vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot1' "$SVC" || fail policy_slot1
grep -Fq 'vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot2' "$SVC" || fail policy_slot2

echo "N1I_C1_SYSTEMIMAGE=PASS sha256=$NEW_SHA bytes=$NEW_BYTES"
echo "N1I_C1_OEM_IMS_IDENTITY=PASS package=$BUILT_IMS_PACKAGE shared_uid=$BUILT_IMS_UID"
echo "N1I_C1_OEM_IMS_PLATFORM_RESIGN=PASS cert=$IMS_CERT"
echo "N1I_C1_BOOTCLASSPATH=PASS"
echo "N1I_C1_STOCK_NATIVE_PREBUILT_COUNT=0"
echo "N1I_C1_A4_NATIVE_SUPERSET=REFERENCE_ONLY_B2_SUPERSEDES_IMPORT_AUTHORITY"
echo "N1I_C1_SELINUX=PASS_ENFORCING_BUILD_POLICY"

rm -rf --one-file-system "$WORK"
echo "N1I_C1_TEMP_EXTRACTION=PASS_REMOVED"

cp --reflink=auto --sparse=always "$NEW" "$ARTIFACT/system.img"
cp "$EVIDENCE/system-image-info.txt" "$ARTIFACT/"
cp "$EVIDENCE/payload-sha256.txt" "$ARTIFACT/"
cat > "$ARTIFACT/artifact.env" <<EOF
ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
SOURCE_COMMIT=$SOURCE_COMMIT
ANDROID_PLATFORM=16
AOSP_REVISION=$N1D_AOSP_REVISION
GRAPHENEOS_TAG=$N1D_C3_GRAPHENEOS_TAG
RESTLESS_TAG=$N1D_C3_RESTLESS_TAG
BASE_C3A_SHA256=$C3A_SHA
BASE_N1F_SHA256=$N1F_SHA
REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F
OEM_IMS_PACKAGE=$BUILT_IMS_PACKAGE
OEM_IMS_SHARED_UID=$BUILT_IMS_UID
OEM_IMS_PLATFORM_RESIGNED=YES
STOCK_NATIVE_IMPORT_COUNT=0
A4_NATIVE_SUPERSET_ROLE=REFERENCE_ONLY_B2_SUPERSEDES_IMPORT_AUTHORITY
SYSTEM_SHA256=$NEW_SHA
SYSTEM_BYTES=$NEW_BYTES
DEVICE_CONTACT=NONE
FLASH=NONE
EOF
(cd "$ARTIFACT"; find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt; printf '%s  ./system.img\n' "$NEW_SHA" >> SHA256SUMS.txt; sha256sum -c SHA256SUMS.txt >/dev/null)

cleanup_source; trap - EXIT
[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_SHA" ]] || fail rom_restore
[[ ! -e "$STAGE_ROOT" ]] || fail stage_restore

echo "N1I_C1_SOURCE_RESTORE=PASS"
echo "N1I_C1_BUILD=PASS"
echo "N1I_C1_ANDROID_PLATFORM=16"
echo "N1I_C1_REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F"
echo "N1I_C1_NEW_FUNCTIONAL_DELTA=OEM_MTK_IMS_ONLY"
echo "N1I_C1_STOCK_NATIVE_IMPORT_COUNT=0"
echo "N1I_C1_NATIVE_ESCALATION=RUNTIME_EVIDENCE_REQUIRED"
echo "N1I_C1_DEVICE_CONTACT=NONE"
echo "N1I_C1_FLASH=NONE"
echo "N1I_C1_READY_FOR_PHYSICAL_REVIEW=YES"
echo "N1I_C1_ARTIFACT_DIR=$ARTIFACT"
echo "N1I_C1_EVIDENCE_DIR=$EVIDENCE"
