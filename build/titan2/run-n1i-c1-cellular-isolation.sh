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
source "$ROOT/build/titan2/n1i-c-oem-ims-admission.env"

RELEASE="${1:-N1I}"
MODE="${2:---direct}"

fail() {
  echo "N1I_C1_BUILD=FAIL reason=$1" >&2
  exit "${2:-1}"
}

case "$RELEASE" in N1I|n1i) ;; *) fail "unsupported_release=$RELEASE" 64 ;; esac
case "$MODE" in --direct|--tmux) ;; *) fail "unsupported_mode=$MODE" 64 ;; esac

SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail bad_source_commit

if [[ "$MODE" == --tmux ]]; then
  SESSION="${SABLE_TMUX_SESSION:-sable-n1i-titan2-${SOURCE_COMMIT:0:12}}"
  tmux has-session -t "$SESSION" 2>/dev/null && fail "tmux_session_exists=$SESSION" 5
  self="$ROOT/build/titan2/run-n1i-c1-cellular-isolation.sh"
  tmux new-session -d -s "$SESSION" \
    "EXPECTED_SOURCE_COMMIT='$SOURCE_COMMIT' bash '$self' N1I --direct; rc=\$?; echo; echo N1I_C1_BUILD_RC=\$rc; echo BUILD_DRIVER_EXITED=YES; exec bash"
  echo "N1I_C1_BUILD=PASS_STARTED"
  echo "SESSION=$SESSION"
  echo "ATTACH=tmux attach -t $SESSION"
  exit 0
fi

[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$SOURCE_COMMIT" ]] || fail source_identity
[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] || fail sable_repo_dirty

# Hard Android 16 boundary.
[[ "$N1D_AOSP_REVISION" == android-16.0.0_r4 ]] || fail "aosp_revision=$N1D_AOSP_REVISION"
[[ "$N1D_GRAPHENE_MANIFEST_REF" == refs/tags/2026061600 ]] || fail "graphene_ref=$N1D_GRAPHENE_MANIFEST_REF"
[[ "$N1D_C3_GRAPHENEOS_TAG" == 2026061600 ]] || fail "graphene_tag=$N1D_C3_GRAPHENEOS_TAG"
[[ "$N1D_C3_RESTLESS_TAG" == 16.0.0-* ]] || fail "restless_tag=$N1D_C3_RESTLESS_TAG"
[[ "$N1D_C3_RELEASE_CONFIG" == bp4a ]] || fail "release_config=$N1D_C3_RELEASE_CONFIG"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_DIR_N1I="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-n1i-c1"
PRODUCT_OUT="$OUT_DIR_N1I/target/product/tdgsi_arm64_ab"
ROM_MK="$ANDROID_ROOT/device/phh/treble/rom.mk"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"
CELL_ROOT="$STAGE_ROOT/n1i-c1"
PREBUILT="$CELL_ROOT/prebuilt"

STOCK_REF="$SABLE_TITAN2_ROOT/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference"
STOCK_SYSTEM="$STOCK_REF/system.img"
STOCK_SYSTEM_EXT="$STOCK_REF/system_ext.img"
C3A_SYSTEM="$N1D_C3A_SYSTEM_IMG"

STOCK_SYSTEM_SHA=b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd
STOCK_SYSTEM_EXT_SHA=1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170
C3A_SHA=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
IMS_SHA=30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539
MTK_COMMON_SHA=511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549
MTK_IMS_BASE_SHA=bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab

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

NATIVE_PATHS=(
  /system_ext/lib64/vendor.mediatek.hardware.mtkradioex.se-V1-ndk.so
  /system/lib64/android.hardware.radio-V4-ndk.so
  /system_ext/lib64/vendor.mediatek.hardware.mtkradioex.rsu-V1-ndk.so
  /system_ext/lib64/vendor.mediatek.hardware.mtkradioex.sim-V1-ndk.so
  /system_ext/lib64/vendor.mediatek.hardware.mtkradioex@3.0.so
  /system_ext/lib64/android.hardware.radio@1.5.so
  /system_ext/lib64/libsignal.so
  /system_ext/lib64/libcompress.so
  /system_ext/lib64/libsource.so
  /system_ext/lib64/libvcodec_cap.so
  /system/lib64/android.hardware.graphics.common-V6-ndk.so
  /system_ext/lib64/libvcodec_capenc.so
  /system_ext/lib64/libcomutils.so
  /system_ext/lib64/libaudioutilmtk.so
  /system_ext/lib64/libgpud_sys.so
  /system_ext/lib64/libgralloc_extra_sys.so
  /system_ext/lib64/libged_sys.so
  /system_ext/lib64/libsf_cpupolicy.so
  /system_ext/lib64/libstagefright_mbrain.so
  /system_ext/lib64/libmtk_vt_wrapper.so
  /system_ext/lib64/vendor.mediatek.hardware.videotelephony-V1-ndk.so
  /system_ext/lib64/vendor.mediatek.hardware.videotelephony@1.0.so
  /system/lib64/android.hardware.drm-V1-ndk.so
  /system_ext/lib64/libJpegOal.so
  /system_ext/lib64/libjpeg-alpha.so
  /system_ext/lib64/libjpeg-alpha-oal.so
  /system_ext/lib64/vendor.mediatek.hardware.mms@1.3.so
  /system_ext/lib64/vendor.mediatek.hardware.mms@1.2.so
  /system_ext/lib64/vendor.mediatek.hardware.mms@1.1.so
  /system_ext/lib64/vendor.mediatek.hardware.mms@1.0.so
  /system_ext/lib64/vendor.mediatek.hardware.mbrain-V2-ndk.so
  /system/lib64/libheif.so
  /system/lib64/libsuspend.so
)

echo "===== TITAN 2 N1I-C1 CELLULAR ISOLATION BUILD ====="
echo "ANDROID_PLATFORM=16"
echo "AOSP_REVISION=$N1D_AOSP_REVISION"
echo "GRAPHENEOS_TAG=$N1D_C3_GRAPHENEOS_TAG"
echo "RESTLESS_CONTROL_TAG=$N1D_C3_RESTLESS_TAG"
echo "RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
echo "BUILD_GOAL=systemimage"
echo "CELLULAR_SCOPE=C3A_PLUS_FIVE_SABLE_APPS_PLUS_OEM_MTK_IMS"
echo "REGISTRATION_DATA_DELTA=NONE_INITIAL_C1_PRESERVE_C3A"
echo "OEM_IMS_PLATFORM_RESIGN=YES"
echo "STOCK_BLOB_COMMIT_TO_GIT=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"

for t in python3 debugfs fsck.erofs sha256sum file "$SABLE_SIMG2IMG"; do
  if [[ "$t" == */* ]]; then [[ -x "$t" ]] || fail "tool_missing=$t"
  else command -v "$t" >/dev/null || fail "tool_missing=$t"
  fi
done

[[ -d "$ANDROID_ROOT/.repo" ]] || fail android_root_missing
[[ ! -e "$OUT_DIR_N1I" ]] || fail "fresh_out_required=$OUT_DIR_N1I"
[[ ! -e "$STAGE_ROOT" ]] || fail "stage_root_exists=$STAGE_ROOT"

for pair in \
  "$STOCK_SYSTEM:$STOCK_SYSTEM_SHA" \
  "$STOCK_SYSTEM_EXT:$STOCK_SYSTEM_EXT_SHA" \
  "$C3A_SYSTEM:$C3A_SHA"
do
  p="${pair%%:*}"; want="${pair#*:}"
  [[ -f "$p" ]] || fail "image_missing=$p"
  got="$(sha256sum "$p" | awk '{print $1}')"
  [[ "$got" == "$want" ]] || fail "image_sha path=$p expected=$want actual=$got"
done
echo "N1I_C1_INPUT_IMAGES=PASS_EXACT_ANDROID16"

# Reuse the physically proven C3A+five-app source-state selfcheck without flashing.
bash "$ROOT/build/titan2/run-n1f-c3a-derived-c3b5-r2.sh" selfcheck

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-cellular-isolation/$STAMP"
ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-cellular-isolation/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-app-bundle/$STAMP"
WORK="$EVIDENCE/work"
mkdir -p "$EVIDENCE" "$ARTIFACT" "$APP_BUNDLE" "$WORK"
exec > >(tee "$EVIDENCE/build.log") 2>&1

extract_fs() {
  local img="$1" dest="$2" magic
  mkdir -p "$dest"
  magic="$(od -An -tx1 -j 0 -N 4 "$img" 2>/dev/null | tr -d ' \n')"
  if [[ "$magic" == 3aff26ed ]]; then
    "$SABLE_SIMG2IMG" "$img" "$dest.raw.img"
    extract_fs "$dest.raw.img" "$dest"
    rm -f "$dest.raw.img"
    return
  fi
  if [[ "$(od -An -tx1 -j 1080 -N 2 "$img" 2>/dev/null | tr -d ' \n')" == 53ef ]]; then
    debugfs -R "rdump / $dest" "$img" >"$dest.debugfs.out" 2>"$dest.debugfs.err" ||
      fail "debugfs_extract=$img"
    return
  fi
  if [[ "$(od -An -tx1 -j 1024 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == e2e1f5e0 ]]; then
    fsck.erofs --extract="$dest" "$img" >"$dest.erofs.out" 2>"$dest.erofs.err" ||
      fail "erofs_extract=$img"
    return
  fi
  fail "unsupported_fs=$img"
}

echo
echo "===== BUILD FIVE KNOWN-GOOD SABLE APPS OFFLINE ====="
bash "$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh" \
  --authorize-app-build \
  --output-dir "$APP_BUNDLE"
(
  cd "$APP_BUNDLE/prebuilt"
  sha256sum -c ../SHA256SUMS.txt >/dev/null
)
echo "N1I_C1_SABLE_APPS=PASS count=5"

echo
echo "===== EXTRACT PINNED STOCK + C3A INPUTS ====="
extract_fs "$STOCK_SYSTEM" "$WORK/stock-system"
extract_fs "$STOCK_SYSTEM_EXT" "$WORK/stock-system-ext"
extract_fs "$C3A_SYSTEM" "$WORK/c3a-system"

stock_sys="$WORK/stock-system"
stock_ext="$WORK/stock-system-ext"
c3a_sys="$WORK/c3a-system"
[[ -f "$stock_sys/system/build.prop" ]] && stock_sys="$stock_sys/system"
[[ -f "$c3a_sys/system/build.prop" ]] && c3a_sys="$c3a_sys/system"

echo "N1I_C1_EXTRACTION=PASS"

ROM_BACKUP=""
ROM_SHA=""
cleanup_source() {
  set +e
  if [[ -n "$ROM_BACKUP" && -f "$ROM_BACKUP" ]]; then
    cp "$ROM_BACKUP" "$ROM_MK"
  fi
  if [[ -d "$STAGE_ROOT" ]]; then
    find "$STAGE_ROOT" -depth -mindepth 1 -delete
    rmdir "$STAGE_ROOT" 2>/dev/null || true
  fi
  set -e
}
trap cleanup_source EXIT

echo
echo "===== STAGE EXACT CELLULAR COMPATIBILITY ISLAND ====="
mkdir -p "$STAGE_ROOT/prebuilt"
install -m 0644 "$ROOT/product/titan2/c3b/Android.bp" "$STAGE_ROOT/Android.bp"
install -m 0644 "$ROOT/product/titan2/c3b/sable-titan2-apps.mk" "$STAGE_ROOT/sable-titan2-apps.mk"
for module in "${MODULES[@]}"; do
  install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$STAGE_ROOT/prebuilt/$module.apk"
done

mkdir -p "$CELL_ROOT"
install -m 0644 "$ROOT/product/titan2/n1i-c1/Android.bp" "$CELL_ROOT/Android.bp"
install -m 0644 "$ROOT/product/titan2/n1i-c1/sable-titan2-n1i-c1.mk" "$CELL_ROOT/sable-titan2-n1i-c1.mk"

copy_payload() {
  local dev="$1" src
  case "$dev" in
    /system_ext/*) src="$stock_ext/${dev#/system_ext/}" ;;
    /system/*) src="$stock_sys/${dev#/system/}" ;;
    *) fail "unsupported_payload_path=$dev" ;;
  esac
  [[ -f "$src" ]] || fail "stock_payload_missing=$dev source=$src"
  install -D -m 0644 "$src" "$PREBUILT/${dev#/}"
}

copy_payload /system_ext/priv-app/ImsService/ImsService.apk
copy_payload /system_ext/framework/mediatek-common.jar
copy_payload /system_ext/framework/mediatek-ims-base.jar

[[ "$(sha256sum "$PREBUILT/system_ext/priv-app/ImsService/ImsService.apk" | awk '{print $1}')" == "$IMS_SHA" ]] ||
  fail ims_apk_sha
[[ "$(sha256sum "$PREBUILT/system_ext/framework/mediatek-common.jar" | awk '{print $1}')" == "$MTK_COMMON_SHA" ]] ||
  fail mediatek_common_sha
[[ "$(sha256sum "$PREBUILT/system_ext/framework/mediatek-ims-base.jar" | awk '{print $1}')" == "$MTK_IMS_BASE_SHA" ]] ||
  fail mediatek_ims_base_sha

for p in "${NATIVE_PATHS[@]}"; do copy_payload "$p"; done
copy_payload /system_ext/etc/permissions/system-ext-permissions-mediatek.xml
copy_payload /system_ext/etc/sysconfig/com.mediatek.ims.config.xml
copy_payload /system/etc/permissions/privapp-permissions-mediatek.xml

echo "N1I_C1_NATIVE_PAYLOAD=PASS count=${#NATIVE_PATHS[@]}"
echo "N1I_C1_CONFIG_PAYLOAD=PASS count=3"

echo
echo "===== DERIVE NARROW ANDROID-16 SYSTEM_EXT SEPOLICY DELTA ====="
POL="$CELL_ROOT/sepolicy/system_ext/private"
mkdir -p "$POL"

python3 - "$stock_sys" "$stock_ext" "$c3a_sys" "$POL" <<'PY'
import re
import sys
from pathlib import Path

stock_sys = Path(sys.argv[1])
stock_ext = Path(sys.argv[2])
c3a_sys = Path(sys.argv[3])
out = Path(sys.argv[4])

property_names = [
    "persist.vendor.entitlement_enabled",
    "persist.vendor.entitlement.dbg.",
    "persist.vendor.entitlement.sesurl",
    "persist.vendor.net.wo.epdg_fqdn",
    "persist.vendor.mtk_wfc_opt_in",
    "persist.vendor.radio.cfu_over_ims",
    "vendor.gsm.radio.ss.imsdereg",
    "vendor.ril.imsconfig.force.notify",
    "persist.vendor.dbg.vonr_ui_ovr",
    "persist.vendor.dbg.vodata_avail_ovr",
    "persist.vendor.mtk_clientapi_support",
    "persist.vendor.radio.simswitchstate",
    "persist.vendor.radio.waitimsi.roaming",
    "persist.vendor.radio.wait.imsi",
    "vendor.ril.imsi.status.",
    "ro.mtk.ims.data.feature_support",
]
service_prefixes = (
    "imsa", "mtkIms", "epdg_service",
    "vendor.mediatek.hardware.mtkradioex.",
)

def existing(paths):
    lines = []
    for p in paths:
        if p.is_file():
            lines += [x.strip() for x in p.read_text(errors="replace").splitlines()
                      if x.strip() and not x.lstrip().startswith("#")]
    return lines

stock_pc = stock_ext / "etc/selinux/system_ext_property_contexts"
stock_sc = stock_ext / "etc/selinux/system_ext_service_contexts"
stock_cil = stock_ext / "etc/selinux/system_ext_sepolicy.cil"
if not all(p.is_file() for p in (stock_pc, stock_sc, stock_cil)):
    raise SystemExit("N1I_C1_SEPOLICY=FAIL_STOCK_SYSTEM_EXT_POLICY_MISSING")

c3a_pc_lines = set(existing([
    c3a_sys / "etc/selinux/plat_property_contexts",
    c3a_sys / "system_ext/etc/selinux/system_ext_property_contexts",
]))
c3a_sc_lines = set(existing([
    c3a_sys / "etc/selinux/plat_service_contexts",
    c3a_sys / "system_ext/etc/selinux/system_ext_service_contexts",
]))
c3a_cil_paths = [
    c3a_sys / "etc/selinux/plat_sepolicy.cil",
    c3a_sys / "system_ext/etc/selinux/system_ext_sepolicy.cil",
]
c3a_cil_text = "\n".join(
    p.read_text(errors="replace") for p in c3a_cil_paths if p.is_file()
)
c3a_types = set(re.findall(r"\(type ([A-Za-z0-9_]+)\)", c3a_cil_text))

pc_selected = []
property_types = set()
for raw in stock_pc.read_text(errors="replace").splitlines():
    s = raw.strip()
    if not s or s.startswith("#"):
        continue
    key = s.split()[0]
    if key in property_names:
        if s not in c3a_pc_lines:
            pc_selected.append(s)
        parts = s.split()
        m = re.search(r":([A-Za-z0-9_]+):s0$", parts[-1])
        if not m:
            raise SystemExit(f"N1I_C1_SEPOLICY=FAIL_PROPERTY_TYPE_PARSE line={s}")
        property_types.add(m.group(1))

sc_selected = []
service_types = set()
for raw in stock_sc.read_text(errors="replace").splitlines():
    s = raw.strip()
    if not s or s.startswith("#"):
        continue
    name = s.split()[0]
    if name in ("imsa", "mtkIms", "epdg_service") or name.startswith(service_prefixes[3]):
        if s not in c3a_sc_lines:
            sc_selected.append(s)
        m = re.search(r":([A-Za-z0-9_]+):s0$", s.split()[-1])
        if m and m.group(1) not in c3a_types:
            service_types.add(m.group(1))

stock_lines = stock_cil.read_text(errors="replace").splitlines()

def has_attr(attr, typ):
    needle = f"(typeattributeset {attr} "
    return any(line.startswith(needle) and re.search(rf"\b{re.escape(typ)}\b", line)
               for line in stock_lines)

macro_for = {}
for typ in sorted(property_types):
    if typ in c3a_types:
        continue
    if has_attr("system_internal_property_type", typ):
        macro_for[typ] = "system_internal_prop"
    elif has_attr("system_restricted_property_type", typ):
        macro_for[typ] = "system_restricted_prop"
    elif has_attr("system_public_property_type", typ):
        macro_for[typ] = "system_public_prop"
    else:
        raise SystemExit(f"N1I_C1_SEPOLICY=FAIL_PROPERTY_SCOPE_UNPROVEN type={typ}")

rules = []
set_pairs = set()
get_pairs = set()
svc_rules = set()
allow_re = re.compile(
    r"^\(allow ([A-Za-z0-9_]+) ([A-Za-z0-9_]+) "
    r"\(([A-Za-z0-9_]+) \(([^)]*)\)\)\)$"
)
new_types = set(macro_for) | service_types
known_types = c3a_types | new_types
for line in stock_lines:
    m = allow_re.match(line.strip())
    if not m:
        continue
    src, tgt, cls, perms_s = m.groups()
    if src not in known_types or tgt not in new_types:
        continue
    perms = set(perms_s.split())
    if tgt in property_types:
        if cls == "property_service" and "set" in perms:
            set_pairs.add((src, tgt))
        elif cls == "file" and {"read", "open"} & perms:
            get_pairs.add((src, tgt))
    elif tgt in service_types and cls == "service_manager":
        svc_rules.add((src, tgt, tuple(sorted(perms))))

te = [
    "# Generated from pinned V01.00.14 system_ext policy for N1I-C1.",
    "# Only types/rules absent from the Android 16 C3A policy are emitted.",
]
for typ, macro in sorted(macro_for.items()):
    te.append(f"{macro}({typ})")
for typ in sorted(service_types):
    te.append(f"type {typ}, service_manager_type;")
for src, typ in sorted(set_pairs):
    te.append(f"set_prop({src}, {typ})")
for src, typ in sorted(get_pairs - set_pairs):
    te.append(f"get_prop({src}, {typ})")
for src, tgt, perms in sorted(svc_rules):
    te.append(f"allow {src} {tgt}:service_manager {{ {' '.join(perms)} }};")

(out / "mtk_ims_generated.te").write_text("\n".join(te) + "\n")
(out / "property_contexts").write_text("\n".join(pc_selected) + ("\n" if pc_selected else ""))
(out / "service_contexts").write_text("\n".join(sc_selected) + ("\n" if sc_selected else ""))

if not pc_selected:
    raise SystemExit("N1I_C1_SEPOLICY=FAIL_NO_NEW_PROPERTY_CONTEXTS")
if not te or len(te) < 4:
    raise SystemExit("N1I_C1_SEPOLICY=FAIL_NO_POLICY_RULES")

print(f"N1I_C1_SEPOLICY_PROPERTY_CONTEXT_COUNT={len(pc_selected)}")
print(f"N1I_C1_SEPOLICY_SERVICE_CONTEXT_COUNT={len(sc_selected)}")
print(f"N1I_C1_SEPOLICY_PROPERTY_TYPE_COUNT={len(macro_for)}")
print(f"N1I_C1_SEPOLICY_SERVICE_TYPE_COUNT={len(service_types)}")
print(f"N1I_C1_SEPOLICY_SET_RULE_COUNT={len(set_pairs)}")
print(f"N1I_C1_SEPOLICY_GET_RULE_COUNT={len(get_pairs - set_pairs)}")
print(f"N1I_C1_SEPOLICY_SERVICE_RULE_COUNT={len(svc_rules)}")
print("N1I_C1_SEPOLICY=PASS_DERIVED_NARROW_ANDROID16")
PY

echo
echo "===== RECORD PAYLOAD HASHES ====="
{
  printf 'path\tsha256\n'
  find "$PREBUILT" -type f -print0 | LC_ALL=C sort -z |
    while IFS= read -r -d '' f; do
      printf '%s\t%s\n' "${f#"$PREBUILT"}" "$(sha256sum "$f" | awk '{print $1}')"
    done
} > "$EVIDENCE/payload-sha256.tsv"

ROM_BACKUP="$EVIDENCE/rom.mk.c3a"
cp "$ROM_MK" "$ROM_BACKUP"
ROM_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"

cat >> "$ROM_MK" <<'EOF'

# SABLE_N1I_C1_CELLULAR_ISOLATION
$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)
$(call inherit-product, vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk)
EOF

echo "N1I_C1_SOURCE_STAGE=PASS"
echo "N1I_C1_REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A"

echo
echo "===== BUILD ANDROID 16 SYSTEMIMAGE ====="
mkdir -p "$OUT_DIR_N1I"
(
  cd "$ANDROID_ROOT"
  export OUT_DIR="$OUT_DIR_N1I"
  set +u
  source build/envsetup.sh
  lunch treble_arm64_bvN-bp4a-user
  set -u

  [[ "$(get_build_var TARGET_PRODUCT)" == treble_arm64_bvN ]] || fail target_product
  [[ "$(get_build_var TARGET_BUILD_VARIANT)" == user ]] || fail target_variant
  [[ "$(get_build_var BUILD_ID)" == BP4A.251205.006 ]] || fail "build_id=$(get_build_var BUILD_ID)"
  [[ "$(get_build_var PLATFORM_VERSION)" == 16 ]] || fail "platform_version=$(get_build_var PLATFORM_VERSION)"

  pp="$(get_build_var PRODUCT_PACKAGES)"
  for module in "${MODULES[@]}" ImsService mediatek-common mediatek-ims-base; do
    grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" <<<"$pp" ||
      fail "product_package_missing=$module"
  done

  boot_jars="$(get_build_var PRODUCT_BOOT_JARS)"
  grep -Fq 'system_ext:mediatek-common' <<<"$boot_jars" || fail bootjar_mediatek_common
  grep -Fq 'system_ext:mediatek-ims-base' <<<"$boot_jars" || fail bootjar_mediatek_ims_base
  echo "N1I_C1_BOOTCLASSPATH_CONFIG=PASS"

  make systemimage -j"${SABLE_BUILD_JOBS:-$(nproc --all)}" 2>&1 |
    tee "$EVIDENCE/systemimage.log"
)
[[ -f "$PRODUCT_OUT/system.img" ]] || fail system_img_missing

NEW_SHA="$(sha256sum "$PRODUCT_OUT/system.img" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$PRODUCT_OUT/system.img")"
echo "N1I_C1_SYSTEM_SHA256=$NEW_SHA"
echo "N1I_C1_SYSTEM_BYTES=$NEW_BYTES"

echo
echo "===== POSTBUILD IMAGE VERIFICATION ====="
extract_fs "$PRODUCT_OUT/system.img" "$WORK/result"
result="$WORK/result"
[[ -f "$result/system/build.prop" ]] && result="$result/system"

IMS_OUT="$result/system_ext/priv-app/ImsService/ImsService.apk"
[[ -f "$IMS_OUT" ]] || fail result_ims_missing
"$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump badging "$IMS_OUT" |
  grep -Fq "package: name='com.mediatek.ims'" || fail result_ims_package

cert_ims="$("$SABLE_ANDROID_BUILD_TOOLS/apksigner" verify --print-certs "$IMS_OUT" |
  sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -n1)"
framework_res="$result/framework/framework-res.apk"
cert_platform="$("$SABLE_ANDROID_BUILD_TOOLS/apksigner" verify --print-certs "$framework_res" |
  sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -n1)"
[[ -n "$cert_ims" && "$cert_ims" == "$cert_platform" ]] ||
  fail "ims_platform_signature ims=$cert_ims platform=$cert_platform"
echo "N1I_C1_IMS_PLATFORM_RESIGN=PASS"

for p in \
  system_ext/framework/mediatek-common.jar \
  system_ext/framework/mediatek-ims-base.jar
do
  [[ -f "$result/$p" ]] || fail "result_missing=$p"
done
[[ "$(sha256sum "$result/system_ext/framework/mediatek-common.jar" | awk '{print $1}')" == "$MTK_COMMON_SHA" ]] ||
  fail result_mediatek_common_sha
[[ "$(sha256sum "$result/system_ext/framework/mediatek-ims-base.jar" | awk '{print $1}')" == "$MTK_IMS_BASE_SHA" ]] ||
  fail result_mediatek_ims_base_sha

BOOTPB="$result/etc/classpaths/bootclasspath.pb"
[[ -f "$BOOTPB" ]] || fail bootclasspath_pb_missing
grep -aFq '