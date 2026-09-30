#!/usr/bin/env bash
# SableOS Titan 2 N1D C0 — host-only offline qualification.
set -euo pipefail

VERSION=1.1.0
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$D/n1d-c0-inspect.py"
CONFIG="" OUT="" KEEP=0
usage(){ echo "usage: $0 --config FILE [--out DIR] [--keep-work]"; }
while (($#)); do case "$1" in --config) CONFIG="${2:-}"; shift 2;; --out) OUT="${2:-}"; shift 2;; --keep-work) KEEP=1; shift;; -h|--help) usage; exit 0;; *) usage >&2; exit 2;; esac; done
[[ -f "$CONFIG" && -f "$HELPER" ]] || { echo "ERROR: config/helper missing" >&2; exit 2; }
# shellcheck disable=SC1090
source "$CONFIG"
: "${DEVICE_CONTACT_AUTHORIZED:=NO}"; : "${BUILD_AUTHORIZED:=NO}"; : "${FLASH_AUTHORIZED:=NO}"; : "${NETWORK_FETCH_AUTHORIZED:=NO}"
for x in DEVICE_CONTACT_AUTHORIZED BUILD_AUTHORIZED FLASH_AUTHORIZED NETWORK_FETCH_AUTHORIZED; do [[ "${!x}" == NO ]] || { echo "ERROR: $x must be NO" >&2; exit 2; }; done
: "${SABLE_REPO:=/srv/data/sable-build/sableos/repo}"; : "${EVIDENCE_ROOT:=/srv/data/sable-build/evidence/titan2}"
: "${N1C_WORKSPACE:=/srv/data/sable-build/workspaces/titan2-n1c-android16-hybrid-super-20260930_140947}"
: "${N1C_OUT_DIR:=$N1C_WORKSPACE/out_n1c_aosp_arm64_systemimage_apns_source_filter}"
: "${N1C_SYSTEM_IMG:=$N1C_OUT_DIR/target/product/generic_arm64/system.img}"
: "${N1C_SUPER_IMG:=/srv/data/sable-build/evidence/titan2/n1c-no-flash-hybrid-super-composition-r1f-20260930_185012/titan2-n1c-hybrid-super-r1f.sparse.img}"
: "${STOCK_REF_DIR:=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference}"
: "${STOCK_SUPER_IMG:=$STOCK_REF_DIR/super.img}"; : "${STOCK_FIRST_STAGE_TREE:=}"; : "${RESTLESS_SYSTEM_IMG:=}"; : "${N1D_PRODUCT_FILE:=}"
: "${N1B_CONTROL_SYSTEM_IMG:=}"; : "${N1B_CONTROL_EXPECTED_SHA256:=}"; : "${N1B_BOOT_PROOF:=}"; : "${N1B1_INPUT:=}"; : "${N1B2_INPUT:=}"
: "${SEPOLICY_VERSION:=30}"; : "${VINTF_FIRST_API_LEVEL:=}"; : "${VINTF_HARDWARE_SKU:=}"
: "${CELLULAR_AUDIT_TOOL:=$SABLE_REPO/build/titan2/audit-n1b2-cellular-stack.sh}"; : "${CAPTURE_TOOL:=$SABLE_REPO/build/titan2/capture-n1b2-cellular-runtime.sh}"; : "${CLASSIFIER_TOOL:=$SABLE_REPO/build/titan2/classify-n1b2-nr-state.py}"

TS="$(date +%Y%m%d_%H%M%S)"; OUT="${OUT:-$EVIDENCE_ROOT/n1d-c0-offline-$TS}"; mkdir -p "$OUT"/{logs,reports,inventory,work}; OUT="$(cd "$OUT" && pwd)"; WORK="$OUT/work"
SUM="$OUT/N1D_C0_OFFLINE_SUMMARY.env"; GATES="$OUT/N1D_C0_GATES.tsv"; : >"$SUM"; printf 'gate\tstatus\tdetail\n' >"$GATES"
declare -A S; BLOCK=(C0_00 C0_02_MOUNT_MODEL C0_03_FRAMEWORK_VIEW C0_04_GSI_CONTRACT C0_05_VINTF C0_06_SEPOLICY C0_07_AVB_CHAIN C0_08_AVB_BOUNDARY C0_09_LP_METADATA C0_10_CONTROL_DIFF C0_12_TOOLCHAIN_SEAL)
gate(){ S[$1]="$2"; printf '%s\t%s\t%s\n' "$1" "$2" "${3//$'\t'/ }" >>"$GATES"; printf '%s=%s\n' "$1" "$2" >>"$SUM"; }
rec(){ printf '%s=%s\n' "$1" "$2" >>"$SUM"; }
sha(){ sha256sum "$1" | awk '{print $1}'; }
cleanup(){ rc=$?; trap - EXIT; ((KEEP)) || rm -rf "$WORK"; exit "$rc"; }; trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
cat >"$OUT/00_POLICY.txt" <<EOF2
TRACK=N1D_C0_OFFLINE
SCRIPT_VERSION=$VERSION
DEVICE_CONTACT_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
INPUT_MUTATION_AUTHORIZED=NO
OUTPUT_MUTATION_AUTHORIZED=YES_EVIDENCE_DIR_ONLY
EOF2
rec N1D_C0_SCRIPT_VERSION "$VERSION"; rec DEVICE_CONTACT_AUTHORIZED NO; rec BUILD_AUTHORIZED NO; rec FLASH_AUTHORIZED NO; rec NETWORK_FETCH_AUTHORIZED NO

HOST="$N1C_OUT_DIR/host/linux-x86"; export LD_LIBRARY_PATH="$HOST/lib64:$HOST/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
tool(){ local n=$1 v=${2:-} p; [[ -n "$v" && -x "$v" ]] && { echo "$v"; return; }; [[ -x "$HOST/bin/$n" ]] && { echo "$HOST/bin/$n"; return; }; p="$(command -v "$n" 2>/dev/null || true)"; [[ -n "$p" ]] && echo "$p"; }
SIMG2IMG="$(tool simg2img "${SIMG2IMG_TOOL:-}")"; LPUNPACK="$(tool lpunpack "${LPUNPACK_TOOL:-}")"; LPDUMP="$(tool lpdump "${LPDUMP_TOOL:-}")"; AVBTOOL="$(tool avbtool "${AVBTOOL_TOOL:-}")"; CHECKVINTF="$(tool checkvintf "${CHECKVINTF_TOOL:-}")"; SECILC="$(tool secilc "${SECILC_TOOL:-}")"
hex(){ od -An -tx1 -j "$2" -N "$3" "$1" 2>/dev/null|tr -d ' \n'; }
typeof(){ [[ -f "$1" ]]||{ echo none; return; }; [[ "$(hex "$1" 0 4)" == 3aff26ed ]]&&{ echo sparse; return; }; [[ "$(hex "$1" 4096 4)" == 67446c61 ]]&&{ echo super; return; }; [[ "$(hex "$1" 1080 2)" == 53ef ]]&&{ echo ext4; return; }; [[ "$(hex "$1" 1024 4)" == e2e1f5e0 ]]&&{ echo erofs; return; }; echo unknown; }
raw(){ local s=$1 d=$2; if [[ "$(typeof "$s")" == sparse ]]; then [[ -n "$SIMG2IMG" ]]||return 3; "$SIMG2IMG" "$s" "$d" >/dev/null; echo "$d"; else echo "$s"; fi; }
extract(){ local i=$1 o=$2 t r="$i"; mkdir -p "$o"; t="$(typeof "$i")"; if [[ "$t" == sparse ]]; then r="$o.raw"; "$SIMG2IMG" "$i" "$r" >/dev/null; t="$(typeof "$r")"; fi; case "$t" in ext4) command -v debugfs >/dev/null||return 3; debugfs -R "rdump / $o" "$r" >"$o.debugfs.out" 2>"$o.debugfs.err"||return 4; grep -qiE 'bad magic|filesystem not open|while trying to open|corrupt|short read|i/o error' "$o.debugfs.err"&&return 4;; erofs) command -v fsck.erofs >/dev/null||return 3; fsck.erofs --extract="$o" "$r" >"$o.erofs.out" 2>"$o.erofs.err"||return 4;; *) return 4;; esac; [[ -n "$(find "$o" -mindepth 1 -print -quit)" ]]||return 4; [[ "$r" == "$i" ]]||rm -f "$r"; }
sysroot(){ [[ -f "$1/build.prop" ]]&&echo "$1"||{ [[ -f "$1/system/build.prop" ]]&&echo "$1/system"||echo "$1"; }; }

if [[ -f "$N1C_SYSTEM_IMG" && -f "$N1C_SUPER_IMG" && -d "$STOCK_REF_DIR" ]] && [[ "$(sha "$N1C_SYSTEM_IMG")" == ed9edad3c65e4908028bb6087bbb712efff81bd4fe6601cc6cc6f0273b545c5d ]] && [[ "$(sha "$N1C_SUPER_IMG")" == d97e53f5e4b3f23245b600b311c6071eb9ab7897be093ea21dea83bbde3f3711 ]]; then gate C0_00 PASS "N1C system/super hashes match checkpoint"; else gate C0_00 FAIL "required N1C/stock input missing or hash mismatch"; fi

if [[ -n "$N1B_CONTROL_SYSTEM_IMG" && -f "$N1B_CONTROL_SYSTEM_IMG" && -n "$N1B_CONTROL_EXPECTED_SHA256" && -f "$N1B_BOOT_PROOF" && "$(sha "$N1B_CONTROL_SYSTEM_IMG")" == "$N1B_CONTROL_EXPECTED_SHA256" ]]; then gate C0_01_N1B_CONTROL QUALIFIED_HISTORICAL "artifact hash and boot-proof path supplied"; else gate C0_01_N1B_CONTROL UNQUALIFIED_HISTORICAL "fresh control required later; no historical certainty manufactured"; fi

N1CX="$WORK/n1c"; if extract "$N1C_SYSTEM_IMG" "$N1CX"; then N1CR="$(sysroot "$N1CX")"; python3 "$HELPER" system-report --root "$N1CX" --label n1c --out "$OUT/inventory/n1c-system.env"; else N1CR=""; fi
for p in product system_ext vendor odm; do f="$STOCK_REF_DIR/$p.img"; [[ -f "$f" ]] && extract "$f" "$WORK/stock-$p" || true; done

FSTAB="$OUT/reports/C0_02_fstab_inventory.txt"; : >"$FSTAB"; [[ -n "$STOCK_FIRST_STAGE_TREE" && -d "$STOCK_FIRST_STAGE_TREE" ]] && grep -RhsE '^[^#].*[[:space:]]/(product|system_ext)[[:space:]]' "$STOCK_FIRST_STAGE_TREE" >>"$FSTAB" || true; grep -RhsE '^[^#].*[[:space:]]/(product|system_ext)[[:space:]]' "$STOCK_REF_DIR" >>"$FSTAB" 2>/dev/null || true
if [[ -n "$N1CR" ]] && grep -q '^SKIP_PRODUCT=YES$' "$OUT/inventory/n1c-system.env" && grep -q '^SKIP_SYSTEM_EXT=YES$' "$OUT/inventory/n1c-system.env"; then gate C0_02_MOUNT_MODEL PASS "N1C GSI explicitly skips stock product/system_ext; fstab inventory captured"; else gate C0_02_MOUNT_MODEL FAIL "N1C product/system_ext skip decision not proven"; fi

OK=1; for p in product system_ext; do if [[ -d "$N1CR/$p" && -d "$WORK/stock-$p" ]]; then python3 "$HELPER" framework-diff --gsi-root "$N1CR/$p" --stock-root "$WORK/stock-$p" --label "$p" --out-tsv "$OUT/reports/C0_03_${p}.tsv" --out-md "$OUT/reports/C0_03_${p}.md"||OK=0; else OK=0; fi; done
((OK))&&gate C0_03_FRAMEWORK_VIEW PASS "product/system_ext hidden-exposed inventories generated"||gate C0_03_FRAMEWORK_VIEW FAIL "framework-side extraction/diff incomplete"

AOSP_GSI="$N1C_WORKSPACE/build/make/target/product/gsi_release.mk"; [[ -f "$AOSP_GSI" ]]||AOSP_GSI="$N1C_WORKSPACE/build/target/product/gsi_release.mk"
if [[ -f "$AOSP_GSI" && -f "$N1D_PRODUCT_FILE" ]]; then python3 "$HELPER" gsi-contract --aosp "$AOSP_GSI" --sable "$N1D_PRODUCT_FILE" --out-json "$OUT/reports/C0_04_gsi_contract.json" --out-md "$OUT/reports/C0_04_gsi_contract.md"; if grep -q 'gsi_release.mk' "$N1D_PRODUCT_FILE"; then gate C0_04_GSI_CONTRACT PASS "N1D product inherits explicit GSI release contract"; else gate C0_04_GSI_CONTRACT FAIL "N1D product does not explicitly inherit gsi_release.mk"; fi; else gate C0_04_GSI_CONTRACT FAIL "AOSP gsi_release.mk or N1D_PRODUCT_FILE missing"; fi

if [[ -n "$CHECKVINTF" && -n "$N1CR" && -d "$WORK/stock-vendor" ]]; then A=(--check-compat --dirmap "/system:$N1CR" --dirmap "/vendor:$WORK/stock-vendor"); [[ -d "$N1CR/product" ]]&&A+=(--dirmap "/product:$N1CR/product"); [[ -d "$N1CR/system_ext" ]]&&A+=(--dirmap "/system_ext:$N1CR/system_ext"); [[ -d "$WORK/stock-odm" ]]&&A+=(--dirmap "/odm:$WORK/stock-odm"); [[ -n "$VINTF_FIRST_API_LEVEL" ]]&&A+=(--property "ro.product.first_api_level=$VINTF_FIRST_API_LEVEL"); [[ -n "$VINTF_HARDWARE_SKU" ]]&&A+=(--property "ro.boot.product.hardware.sku=$VINTF_HARDWARE_SKU"); if "$CHECKVINTF" "${A[@]}" >"$OUT/logs/C0_05_checkvintf.log" 2>&1; then gate C0_05_VINTF PASS "checkvintf --check-compat passed"; else gate C0_05_VINTF FAIL "checkvintf failed; inspect log"; fi; else gate C0_05_VINTF FAIL "checkvintf/runtime trees unavailable"; fi

SEL="$OUT/logs/C0_06_secilc.log"; CILS=(); if [[ -n "$SECILC" && -n "$N1CR" && -d "$WORK/stock-vendor" ]]; then VERS="$(cat "$WORK/stock-vendor/etc/selinux/plat_sepolicy_vers.txt" 2>/dev/null||true)"; for f in "$N1CR/etc/selinux/plat_sepolicy.cil" "$N1CR/etc/selinux/mapping/$VERS.cil" "$N1CR/system_ext/etc/selinux/system_ext_sepolicy.cil" "$N1CR/product/etc/selinux/product_sepolicy.cil" "$WORK/stock-vendor/etc/selinux/plat_pub_versioned.cil" "$WORK/stock-vendor/etc/selinux/vendor_sepolicy.cil" "$WORK/stock-odm/etc/selinux/odm_sepolicy.cil"; do [[ -f "$f" ]]&&CILS+=("$f"); done; if [[ -n "$VERS" && ${#CILS[@]} -ge 4 ]] && "$SECILC" -m -M true -G -N -c "$SEPOLICY_VERSION" "${CILS[@]}" -o /dev/null -f /dev/null >"$SEL" 2>&1; then gate C0_06_SEPOLICY PASS "split policy compiled for vendor mapping $VERS"; else gate C0_06_SEPOLICY FAIL "secilc failed or required policy inputs absent"; fi; else gate C0_06_SEPOLICY FAIL "secilc/runtime trees unavailable"; fi

OK=1; for n in vbmeta vbmeta_system vbmeta_vendor; do f="$STOCK_REF_DIR/$n.img"; if [[ -n "$AVBTOOL" && -f "$f" ]]; then "$AVBTOOL" info_image --image "$f" >"$OUT/reports/C0_07_${n}_avb.txt" 2>&1||OK=0; else OK=0; fi; done; ((OK))&&gate C0_07_AVB_CHAIN PASS "stock vbmeta chain parsed"||gate C0_07_AVB_CHAIN FAIL "stock vbmeta chain parse incomplete"

if [[ -n "$SIMG2IMG" && -n "$LPUNPACK" && -n "$AVBTOOL" ]]; then NS="$WORK/n1c-system.raw"; NP="$WORK/n1c-super.raw"; NSR="$(raw "$N1C_SYSTEM_IMG" "$NS")"; NPR="$(raw "$N1C_SUPER_IMG" "$NP")"; mkdir -p "$WORK/n1c-lp"; "$LPUNPACK" "$NPR" "$WORK/n1c-lp" >"$OUT/logs/C0_08_lpunpack.log" 2>&1||true; EX="$(find "$WORK/n1c-lp" -maxdepth 1 -type f \( -name 'system_a.img' -o -name 'system_a' -o -name 'system.img' -o -name 'system' \) -print -quit)"; SRC=NO EXT=NO; "$AVBTOOL" info_image --image "$NSR" >"$OUT/reports/C0_08_source_avb.txt" 2>&1&&SRC=YES||true; [[ -n "$EX" ]]&&"$AVBTOOL" info_image --image "$EX" >"$OUT/reports/C0_08_extracted_avb.txt" 2>&1&&EXT=YES||true; if [[ "$SRC" == YES && "$EXT" == NO ]]; then C=SUPPORTS_HYPOTHESIS; elif [[ "$SRC" == YES && "$EXT" == YES ]]; then C=DOES_NOT_SUPPORT_HYPOTHESIS; elif [[ "$SRC" == NO ]]; then C=NO_SOURCE_FOOTER; else C=UNRESOLVED; fi; printf 'SOURCE_AVB=%s\nEXTRACTED_AVB=%s\nCLASSIFICATION=%s\n' "$SRC" "$EXT" "$C" >"$OUT/reports/C0_08_avb_boundary.env"; [[ "$C" != UNRESOLVED ]]&&gate C0_08_AVB_BOUNDARY PASS "$C"||gate C0_08_AVB_BOUNDARY FAIL "could not classify footer/boundary hypothesis"; else gate C0_08_AVB_BOUNDARY FAIL "required LP/AVB tools unavailable"; fi

if [[ -n "$LPDUMP" && -n "$SIMG2IMG" && -f "$STOCK_SUPER_IMG" ]]; then SR="$WORK/stock-super.raw"; NR="$WORK/n1c-super2.raw"; SRR="$(raw "$STOCK_SUPER_IMG" "$SR")"; NRR="$(raw "$N1C_SUPER_IMG" "$NR")"; "$LPDUMP" -j "$SRR" >"$OUT/reports/C0_09_stock_lpdump.json" 2>"$OUT/logs/C0_09_stock.err"||true; "$LPDUMP" -j "$NRR" >"$OUT/reports/C0_09_n1c_lpdump.json" 2>"$OUT/logs/C0_09_n1c.err"||true; if python3 -m json.tool "$OUT/reports/C0_09_stock_lpdump.json" >/dev/null 2>&1 && python3 -m json.tool "$OUT/reports/C0_09_n1c_lpdump.json" >/dev/null 2>&1; then python3 "$HELPER" lp-diff --stock-json "$OUT/reports/C0_09_stock_lpdump.json" --n1c-json "$OUT/reports/C0_09_n1c_lpdump.json" --out-json "$OUT/reports/C0_09_lp_diff.json" --out-md "$OUT/reports/C0_09_lp_diff.md"; N="$(python3 - "$OUT/reports/C0_09_lp_diff.json" <<'PY'
import json,sys,re
j=json.load(open(sys.argv[1])); n=0
for p,d in j.get('diff',{}).items():
    if re.fullmatch(r'system(_a)?',p): continue
    n += len(d)
print(n)
PY
)"; rec C0_09_PRESERVED_DIFF_FIELDS "$N"; [[ "$N" == 0 ]]&&gate C0_09_LP_METADATA PASS "preserved partition metadata matches stock"||gate C0_09_LP_METADATA FAIL "$N preserved-partition metadata field differences"; else gate C0_09_LP_METADATA FAIL "lpdump JSON invalid"; fi; else gate C0_09_LP_METADATA FAIL "stock super or LP tools unavailable"; fi

if [[ -f "$RESTLESS_SYSTEM_IMG" && -n "$N1CR" ]]; then RX="$WORK/restless"; if extract "$RESTLESS_SYSTEM_IMG" "$RX"; then python3 "$HELPER" system-report --root "$RX" --label restless --out "$OUT/inventory/restless-system.env"; python3 "$HELPER" compare-system-reports --report "$OUT/inventory/n1c-system.env" --label n1c --report "$OUT/inventory/restless-system.env" --label restless --out-md "$OUT/reports/C0_10_system_control_comparison.md"; rec RESTLESS_SYSTEM_SHA256 "$(sha "$RESTLESS_SYSTEM_IMG")"; gate C0_10_CONTROL_DIFF PASS "known-booting Restless control extracted and compared"; else gate C0_10_CONTROL_DIFF FAIL "Restless image extraction failed"; fi; else find /srv/data/sable-build -maxdepth 7 -type f -iname '*restless*.img' -size +500M -print 2>/dev/null|head -50 >"$OUT/reports/C0_10_restless_candidates.txt"||true; gate C0_10_CONTROL_DIFF FAIL "RESTLESS_SYSTEM_IMG not supplied; candidate list written"; fi

if [[ -x "$CELLULAR_AUDIT_TOOL" && -n "$N1B1_INPUT" && -e "$N1B1_INPUT" && -n "$N1B2_INPUT" && -e "$N1B2_INPUT" ]]; then "$CELLULAR_AUDIT_TOOL" --stock "$STOCK_REF_DIR" --n1b1 "$N1B1_INPUT" --n1b2 "$N1B2_INPUT" --out "$OUT/cellular-static" >"$OUT/logs/C0_11.log" 2>&1 && gate C0_11_CELLULAR_STATIC PASS "historical audit complete" || gate C0_11_CELLULAR_STATIC INFO "historical audit incomplete; non-blocking for boot architecture"; else gate C0_11_CELLULAR_STATIC INFO "N1B1/N1B2 historical inputs not supplied"; fi

OK=1; for spec in "$CELLULAR_AUDIT_TOOL:b02d0da22de0f0cecca8a0793acd216ddecebafd9a51fae9c708936832c17c28" "$CAPTURE_TOOL:50344ffe5de82986299175587e152b493add8e930a90aa9dd55aba89351b721a" "$CLASSIFIER_TOOL:7833e2235a151f4ae2f628c597624c02d93cd81ed558da5af5eaa73a47f5a6e9"; do p=${spec%:*}; h=${spec##*:}; [[ -f "$p" && "$(sha "$p")" == "$h" ]]||OK=0; done; ((OK))&&gate C0_12_TOOLCHAIN_SEAL PASS "reviewed audit/capture/classifier hashes match"||gate C0_12_TOOLCHAIN_SEAL FAIL "reviewed tooling missing or hash mismatch"

BLOCKED=0; for g in "${BLOCK[@]}"; do [[ "${S[$g]:-FAIL}" == PASS ]]||BLOCKED=1; done
if ((BLOCKED)); then rec N1D_C0_COMPLETE NO; rec N1D_BUILD_READINESS BLOCKED; else rec N1D_C0_COMPLETE YES; rec N1D_BUILD_READINESS PASS; fi
rec N1D_BUILD_AUTHORIZED_BY_THIS_SCRIPT NO; rec N1D_FLASH_AUTHORIZED NO; rec N1D_DEVICE_CONTACT_AUTHORIZED NO
python3 - "$GATES" "$SUM" "$OUT/reports/N1D_C0_OFFLINE_REPORT.md" <<'PY'
import sys
from pathlib import Path
g,s,o=map(Path,sys.argv[1:]); env={}
for l in s.read_text().splitlines():
    if '=' in l: k,v=l.split('=',1); env[k]=v
rows=[x.split('\t',2)+[''] for x in g.read_text().splitlines()[1:] if x.strip()]
md=['# Titan 2 N1D C0 offline qualification','',f"- N1D_C0_COMPLETE={env.get('N1D_C0_COMPLETE','NO')}",f"- N1D_BUILD_READINESS={env.get('N1D_BUILD_READINESS','BLOCKED')}",'- N1D_FLASH_AUTHORIZED=NO','', '| gate | status | detail |','|---|---|---|']
for r in rows: md.append(f'| `{r[0]}` | **{r[1]}** | {r[2].replace("|","/")} |')
md += ['','A PASS is offline evidence only. This script never authorizes a build, device contact, or flash.']
o.write_text('\n'.join(md)+'\n')
PY
echo "SUMMARY=$SUM"; echo "REPORT=$OUT/reports/N1D_C0_OFFLINE_REPORT.md"; ((BLOCKED))&&exit 4||exit 0

