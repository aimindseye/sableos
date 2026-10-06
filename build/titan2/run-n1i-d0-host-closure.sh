#!/usr/bin/env bash
# Titan 2 N1I-D0-0H host-only boot-compatibility closure.
# Read-only inputs; evidence output only. No build, network, device, reboot or flash.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/build/titan2/n1i-d0-host.py"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
B2_PIN="1697f21989b8ed6f1db90f8886952894592c7d0f"
API_LEVEL=36
SEPOLICY_VERSION="${SEPOLICY_VERSION:-30}"

CONFIG=""
OUT=""
KEEP_WORK=0

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/run-n1i-d0-host-closure.sh --config FILE [--out DIR] [--keep-work]

Required authorization:
  DEVICE_CONTACT_AUTHORIZED=NO
  BUILD_AUTHORIZED=NO
  NETWORK_FETCH_AUTHORIZED=NO
  REBOOT_AUTHORIZED=NO
  FLASH_AUTHORIZED=NO

This driver reads retained local artifacts and writes evidence only beneath --out.
Missing evidence becomes UNKNOWN. It never performs device transport, source synchronization,
a build, a reboot, or a flash.
EOF
}

fail() {
  echo "N1I_D0_0H=FAIL_TOOLING reason=$1" >&2
  exit "${2:-2}"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --config)
      [[ "$#" -ge 2 ]] || fail missing_config_value
      CONFIG="$2"; shift 2 ;;
    --out)
      [[ "$#" -ge 2 ]] || fail missing_out_value
      OUT="$2"; shift 2 ;;
    --keep-work)
      KEEP_WORK=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "unknown_argument=$1" ;;
  esac
done

[[ -n "$CONFIG" && -f "$CONFIG" ]] || fail config_required
[[ -f "$HELPER" ]] || fail helper_missing
[[ -f "$HOST_PROFILE" ]] || fail host_profile_missing

# shellcheck disable=SC1090
source "$CONFIG" || fail config_source
# shellcheck disable=SC1090
source "$HOST_PROFILE" || fail host_profile_source

: "${DEVICE_CONTACT_AUTHORIZED:=NO}"
: "${BUILD_AUTHORIZED:=NO}"
: "${NETWORK_FETCH_AUTHORIZED:=NO}"
: "${REBOOT_AUTHORIZED:=NO}"
: "${FLASH_AUTHORIZED:=NO}"
: "${EVIDENCE_ROOT:=/srv/sable-build/evidence/titan2}"

[[ "$DEVICE_CONTACT_AUTHORIZED" == NO ]] || fail device_contact_must_be_no
[[ "$BUILD_AUTHORIZED" == NO ]] || fail build_must_be_no
[[ "$NETWORK_FETCH_AUTHORIZED" == NO ]] || fail network_must_be_no
[[ "$REBOOT_AUTHORIZED" == NO ]] || fail reboot_must_be_no
[[ "$FLASH_AUTHORIZED" == NO ]] || fail flash_must_be_no

CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)" ||
  fail git_head_unavailable
GIT_STATUS="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all 2>/dev/null)" ||
  fail git_status_unavailable
[[ -z "$GIT_STATUS" ]] || fail source_worktree_dirty
git -C "$ROOT" merge-base --is-ancestor "$B2_PIN" "$CURRENT_HEAD" >/dev/null 2>&1 ||
  fail pinned_b2_not_ancestor

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${OUT:-$EVIDENCE_ROOT/n1i-d0-host-closure/$STAMP}"
[[ ! -e "$OUT" ]] || fail "output_exists=$OUT"
mkdir -p "$OUT"/{logs,reports,inventory,inputs,tools,work} ||
  fail output_create
OUT="$(cd "$OUT" && pwd -P)" || fail output_resolve
WORK="$OUT/work"
SUMMARY="$OUT/N1I_D0_SUMMARY.env"
GATES="$OUT/N1I_D0_GATES.tsv"
: > "$SUMMARY"
printf 'gate\tcontrol\tstatus\tdetail\n' > "$GATES"

cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  if [[ "$KEEP_WORK" -ne 1 && -d "$WORK" ]]; then
    rm -rf "$WORK"
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

record() {
  printf '%s=%s\n' "$1" "$2" >> "$SUMMARY"
}

gate() {
  local gate_name="$1" control="$2" status="$3" detail="${4:-}"
  printf '%s\t%s\t%s\t%s\n'     "$gate_name" "$control" "$status" "${detail//$'\t'/ }" >> "$GATES"
  printf 'N1I_D0_%s_%s=%s\n'     "$gate_name" "$control" "$status" >> "$SUMMARY"
}

sha_file() {
  sha256sum "$1" | awk '{print $1}'
}

tool_record() {
  local key="$1" path="$2" version="${3:-}"
  if [[ ! -x "$path" ]]; then
    record "TOOL_${key}_STATUS" "UNKNOWN_MISSING"
    return 1
  fi
  record "TOOL_${key}_PATH" "$path"
  record "TOOL_${key}_SHA256" "$(sha_file "$path")"
  [[ -n "$version" ]] && record "TOOL_${key}_VERSION" "$version"
  return 0
}

run_host_tool() {
  local exe="$1"
  shift
  local tool_root
  tool_root="${exe%/bin/*}"
  if [[ -d "$tool_root/lib64" ]]; then
    LD_LIBRARY_PATH="$tool_root/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"       "$exe" "$@"
  else
    "$exe" "$@"
  fi
}

detect_image_fs() {
  python3 - "$1" <<'PY'
import pathlib,struct,sys
p=pathlib.Path(sys.argv[1])
b=p.read_bytes()[:1084]
if len(b)>=4 and struct.unpack_from("<I",b,0)[0]==0xed26ff3a:
    print("sparse")
elif len(b)>=1082 and b[1080:1082]==b"\x53\xef":
    print("ext4")
elif len(b)>=1028 and b[1024:1028]==b"\xe2\xe1\xf5\xe0":
    print("erofs")
else:
    print("unknown")
PY
}

normalize_image() {
  local src="$1" dest="$2" fs
  fs="$(detect_image_fs "$src")"
  if [[ "$fs" == sparse ]]; then
    [[ -x "$SABLE_SIMG2IMG" ]] || return 10
    run_host_tool "$SABLE_SIMG2IMG" "$src" "$dest" >/dev/null 2>&1 || return 11
    printf '%s\n' "$dest"
    return 0
  fi
  printf '%s\n' "$src"
}

extract_image() {
  local src="$1" dest="$2" label="$3" raw fs rc
  mkdir -p "$dest" || return 10
  raw="$WORK/${label}.raw.img"
  raw="$(normalize_image "$src" "$raw")" || return $?
  fs="$(detect_image_fs "$raw")"
  case "$fs" in
    ext4)
      "$DEBUGFS" -R "rdump / $dest" "$raw"         >"$OUT/logs/${label}.debugfs.log" 2>&1
      rc=$?
      ;;
    erofs)
      "$FSCK_EROFS" "--extract=$dest" "$raw"         >"$OUT/logs/${label}.erofs.log" 2>&1
      rc=$?
      ;;
    *)
      echo "unsupported_fs=$fs" >"$OUT/logs/${label}.extract.log"
      return 12
      ;;
  esac
  [[ "$rc" -eq 0 && -n "$(find "$dest" -mindepth 1 -print -quit 2>/dev/null)" ]] ||
    return 13
  return 0
}

runtime_system_root() {
  local root="$1"
  if [[ -f "$root/system/build.prop" ]]; then
    printf '%s\n' "$root/system"
  else
    printf '%s\n' "$root"
  fi
}

verify_image() {
  local label="$1" image="$2" want_sha="$3" want_bytes="$4"
  if [[ ! -f "$image" ]]; then
    record "${label}_IMAGE_STATUS" "UNKNOWN_MISSING"
    return 1
  fi
  local bytes actual
  bytes="$(stat -c '%s' "$image")" || return 2
  actual="$(sha_file "$image")" || return 2
  record "${label}_SYSTEM_IMG" "$(readlink -f "$image")"
  record "${label}_SYSTEM_BYTES" "$bytes"
  record "${label}_SYSTEM_SHA256" "$actual"
  if [[ "$bytes" != "$want_bytes" || "$actual" != "$want_sha" ]]; then
    record "${label}_IMAGE_STATUS" "UNKNOWN_IDENTITY_MISMATCH"
    return 3
  fi
  record "${label}_IMAGE_STATUS" "PASS_EXACT"
  return 0
}

prepare_control_root() {
  local label="$1" image="$2" expected_sha="$3" expected_bytes="$4"
  local product_out="$5" override="$6" dest="$WORK/${label,,}-system"
  if ! verify_image "$label" "$image" "$expected_sha" "$expected_bytes"; then
    return 1
  fi
  if [[ -n "$override" && -d "$override" ]]; then
    printf '%s\n' "$(runtime_system_root "$(readlink -f "$override")")"
    return 0
  fi
  if [[ -n "$product_out" && -d "$product_out/system" ]]; then
    printf '%s\n' "$(readlink -f "$product_out/system")"
    return 0
  fi
  extract_image "$image" "$dest" "${label,,}-system" || return 2
  printf '%s\n' "$(runtime_system_root "$dest")"
}

prepare_stock_partition() {
  local part="$1" override_root="$2" image="$STOCK_REF_DIR/${part}.img"
  local upper expected_var expected="" actual bytes
  upper="$(printf '%s' "$part" | tr '[:lower:]' '[:upper:]')"
  expected_var="STOCK_${upper}_SHA256"
  expected="${!expected_var:-}"

  if [[ -f "$image" ]]; then
    [[ -n "$expected" ]] || {
      record "STOCK_${upper}_STATUS" UNKNOWN_UNPINNED
      return 1
    }
    actual="$(sha_file "$image")" || return 2
    bytes="$(stat -c '%s' "$image")" || return 2
    record "STOCK_${upper}_IMG" "$(readlink -f "$image")"
    record "STOCK_${upper}_SHA256" "$actual"
    record "STOCK_${upper}_BYTES" "$bytes"
    if [[ "$actual" != "$expected" ]]; then
      record "STOCK_${upper}_STATUS" UNKNOWN_IDENTITY_MISMATCH
      return 3
    fi
    record "STOCK_${upper}_STATUS" PASS_EXACT
  elif [[ -z "$override_root" || ! -d "$override_root/$part" ]]; then
    record "STOCK_${upper}_STATUS" UNKNOWN_MISSING
    return 1
  fi

  if [[ -n "$override_root" && -d "$override_root/$part" ]]; then
    [[ -f "$image" ]] || {
      record "STOCK_${upper}_STATUS" UNKNOWN_EXTRACTED_ROOT_WITHOUT_PINNED_IMAGE
      return 1
    }
    printf '%s\n' "$(readlink -f "$override_root/$part")"
    return 0
  fi

  local dest="$WORK/stock-$part"
  extract_image "$image" "$dest" "stock-$part" || return 4
  printf '%s\n' "$(runtime_system_root "$dest")"
}

extract_prop_unique() {
  local key="$1"
  shift
  local values
  values="$(
    for root in "$@"; do
      [[ -d "$root" ]] || continue
      find "$root" -maxdepth 3 -type f         \( -name 'build.prop' -o -name '*.prop' \) -print0 2>/dev/null |
        while IFS= read -r -d '' f; do
          grep -h "^${key}=" "$f" 2>/dev/null || true
        done
    done | sed "s/^${key}=//" | sort -u
  )"
  if [[ "$(printf '%s\n' "$values" | sed '/^$/d' | wc -l | tr -d ' ')" == 1 ]]; then
    printf '%s\n' "$values"
  else
    printf '%s\n' "UNKNOWN"
  fi
}

cat > "$OUT/00_POLICY.txt" <<EOF_POLICY
===== TITAN 2 N1I-D0-0H HOST BOOT-COMPATIBILITY CLOSURE =====
TOOL_SOURCE_COMMIT=$CURRENT_HEAD
B2_PIN=$B2_PIN
SOURCE_MUTATION_AUTHORIZED=NO_DURING_QUALIFICATION
BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
MODE_TRANSITION_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
INPUT_MUTATION_AUTHORIZED=NO
OUTPUT_MUTATION_AUTHORIZED=YES_EVIDENCE_DIR_ONLY
EOF_POLICY

record N1I_D0_TOOL_SOURCE_COMMIT "$CURRENT_HEAD"
record N1I_D0_B2_PIN "$B2_PIN"
record BUILD_AUTHORIZED NO
record NETWORK_FETCH_AUTHORIZED NO
record DEVICE_CONTACT_AUTHORIZED NO
record REBOOT_AUTHORIZED NO
record FLASH_AUTHORIZED NO
record N1I_D0_A4_IMPORT_AUTHORITY RETIRED_REFERENCE_ONLY
record N1I_D0_TELEPHONYMETRICS_SCOPE C2_ONLY

# ----------------------------- host tools
SABLE_PYTHON="${SABLE_PYTHON:-$(command -v python3)}"
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
DEBUGFS="$(command -v debugfs || true)"
FSCK_EROFS="$(command -v fsck.erofs || true)"
READELF="$(command -v readelf || true)"
C2_OUT_TOP=""
if [[ -n "${C2_PRODUCT_OUT:-}" && "$C2_PRODUCT_OUT" == */target/product/* ]]; then
  C2_OUT_TOP="${C2_PRODUCT_OUT%%/target/product/*}"
fi
PROPERTY_INFO_CHECKER=""
CHECKFC=""
if [[ -n "$C2_OUT_TOP" ]]; then
  [[ -x "$C2_OUT_TOP/host/linux-x86/bin/property_info_checker" ]] &&
    PROPERTY_INFO_CHECKER="$C2_OUT_TOP/host/linux-x86/bin/property_info_checker"
  [[ -x "$C2_OUT_TOP/host/linux-x86/bin/checkfc" ]] &&
    CHECKFC="$C2_OUT_TOP/host/linux-x86/bin/checkfc"
fi
[[ -n "$PROPERTY_INFO_CHECKER" ]] ||
  PROPERTY_INFO_CHECKER="$(command -v property_info_checker || true)"
[[ -n "$CHECKFC" ]] || CHECKFC="$(command -v checkfc || true)"

[[ -x "$SABLE_PYTHON" ]] || fail python_missing
[[ -x "$AAPT2" ]] || fail aapt2_missing
[[ -x "$SABLE_SECILC" ]] || fail secilc_missing
[[ -x "$SABLE_SIMG2IMG" ]] || fail simg2img_missing
[[ -x "$DEBUGFS" ]] || fail debugfs_missing
[[ -x "$FSCK_EROFS" ]] || fail fsck_erofs_missing

tool_record PYTHON "$SABLE_PYTHON" "$("$SABLE_PYTHON" --version 2>&1 | head -1)" || true
tool_record AAPT2 "$AAPT2" "$("$AAPT2" version 2>&1 | head -1)" || true
tool_record SECILC "$SABLE_SECILC" "$("$SABLE_SECILC" --help 2>&1 | head -1)" || true
tool_record SIMG2IMG "$SABLE_SIMG2IMG" "" || true
tool_record DEBUGFS "$DEBUGFS" "$("$DEBUGFS" -V 2>&1 | head -1)" || true
tool_record FSCK_EROFS "$FSCK_EROFS" "$("$FSCK_EROFS" -V 2>&1 | head -1)" || true
[[ -n "$READELF" ]] && tool_record READELF "$READELF" "$("$READELF" --version 2>&1 | head -1)" || true
if [[ -n "$PROPERTY_INFO_CHECKER" ]]; then
  tool_record PROPERTY_INFO_CHECKER "$PROPERTY_INFO_CHECKER" "" || true
else
  record TOOL_PROPERTY_INFO_CHECKER_STATUS UNKNOWN_MISSING
fi
if [[ -n "$CHECKFC" ]]; then
  tool_record CHECKFC "$CHECKFC" "" || true
else
  record TOOL_CHECKFC_STATUS UNKNOWN_MISSING
fi

"$SABLE_PYTHON" -m py_compile "$HELPER" || fail helper_python_syntax
"$SABLE_PYTHON" "$HELPER" selftest >"$OUT/logs/helper-selftest.log" 2>&1 ||
  fail helper_selftest
record N1I_D0_HOST_HELPER_SELFTEST PASS

# ----------------------------- exact pinned B2 source
PIN_ROOT="$WORK/b2-pin"
mkdir -p "$PIN_ROOT" || fail b2_pin_dir
B2_TAR="$WORK/b2-pin.tar"
git -C "$ROOT" archive -o "$B2_TAR" "$B2_PIN" \
  build/titan2/n1i_static.py \
  build/titan2/n1i-b2-members.py \
  build/titan2/n1i-b2-native.py \
  tests/titan2/n1i-b
B2_GIT_ARCHIVE_RC=$?
[[ "$B2_GIT_ARCHIVE_RC" -eq 0 ]] || fail b2_pin_git_archive
tar -xf "$B2_TAR" -C "$PIN_ROOT"
B2_TAR_RC=$?
[[ "$B2_TAR_RC" -eq 0 ]] || fail b2_pin_tar_extract
rm -f "$B2_TAR"
git -C "$PIN_ROOT" init -q || fail b2_pin_git_init
record N1I_D0_B2_PIN_MATERIALIZATION PASS_LOCAL_GIT_OBJECT_ONLY
for rel in   build/titan2/n1i_static.py   build/titan2/n1i-b2-members.py   build/titan2/n1i-b2-native.py
do
  record "B2_PIN_SHA256_$(basename "$rel" | tr '.-' '__')"     "$(sha_file "$PIN_ROOT/$rel")"
done

# Self-tests can fail because their oracle compilers are unavailable. That is
# UNKNOWN, not a false PASS and not a reason to substitute newer analyzer code.
B2_MEMBERS_SELFTEST=UNKNOWN
B2_NATIVE_SELFTEST=UNKNOWN
(
  cd "$PIN_ROOT" || exit 2
  "$SABLE_PYTHON" tests/titan2/n1i-b/test-members.py
) >"$OUT/logs/b2-members-selftest.log" 2>&1
[[ "$?" -eq 0 ]] && B2_MEMBERS_SELFTEST=PASS
(
  cd "$PIN_ROOT" || exit 2
  "$SABLE_PYTHON" tests/titan2/n1i-b/test-native.py
) >"$OUT/logs/b2-native-selftest.log" 2>&1
[[ "$?" -eq 0 ]] && B2_NATIVE_SELFTEST=PASS
record N1I_D0_B2_MEMBERS_SELFTEST "$B2_MEMBERS_SELFTEST"
record N1I_D0_B2_NATIVE_SELFTEST "$B2_NATIVE_SELFTEST"

# ----------------------------- input roots
N1F_ROOT=""
C1_ROOT=""
C2_ROOT=""
STOCK_SYSTEM_ROOT=""
STOCK_SYSTEM_EXT_ROOT=""
STOCK_PRODUCT_ROOT=""
STOCK_VENDOR_ROOT=""
STOCK_ODM_ROOT=""

N1F_ROOT="$(prepare_control_root N1F "$N1F_SYSTEM_IMG" "$N1F_SYSTEM_SHA256"   "$N1F_SYSTEM_BYTES" "${N1F_PRODUCT_OUT:-}" "${N1F_EXTRACTED_ROOT:-}" || true)"
C2_ROOT="$(prepare_control_root C2 "$C2_SYSTEM_IMG" "$C2_SYSTEM_SHA256"   "$C2_SYSTEM_BYTES" "${C2_PRODUCT_OUT:-}" "${C2_EXTRACTED_ROOT:-}" || true)"
if [[ -n "${C1_SYSTEM_IMG:-}" && -n "${C1_SYSTEM_SHA256:-}" && -n "${C1_SYSTEM_BYTES:-}" ]]; then
  C1_ROOT="$(prepare_control_root C1 "$C1_SYSTEM_IMG" "$C1_SYSTEM_SHA256"     "$C1_SYSTEM_BYTES" "${C1_PRODUCT_OUT:-}" "${C1_EXTRACTED_ROOT:-}" || true)"
fi

for part in system system_ext product vendor odm; do
  value="$(prepare_stock_partition "$part" "${STOCK_EXTRACTED_ROOT:-}" || true)"
  case "$part" in
    system) STOCK_SYSTEM_ROOT="$value" ;;
    system_ext) STOCK_SYSTEM_EXT_ROOT="$value" ;;
    product) STOCK_PRODUCT_ROOT="$value" ;;
    vendor) STOCK_VENDOR_ROOT="$value" ;;
    odm) STOCK_ODM_ROOT="$value" ;;
  esac
done

record N1F_RUNTIME_SYSTEM_ROOT "${N1F_ROOT:--}"
record C1_RUNTIME_SYSTEM_ROOT "${C1_ROOT:--}"
record C2_RUNTIME_SYSTEM_ROOT "${C2_ROOT:--}"
record STOCK_SYSTEM_ROOT "${STOCK_SYSTEM_ROOT:--}"
record STOCK_SYSTEM_EXT_ROOT "${STOCK_SYSTEM_EXT_ROOT:--}"
record STOCK_PRODUCT_ROOT "${STOCK_PRODUCT_ROOT:--}"
record STOCK_VENDOR_ROOT "${STOCK_VENDOR_ROOT:--}"
record STOCK_ODM_ROOT "${STOCK_ODM_ROOT:--}"

[[ -n "$N1F_ROOT" && -d "$N1F_ROOT" ]] || gate INPUT N1F UNKNOWN system_root_unavailable
[[ -n "$C2_ROOT" && -d "$C2_ROOT" ]] || gate INPUT C2 UNKNOWN system_root_unavailable
[[ -n "$STOCK_VENDOR_ROOT" && -d "$STOCK_VENDOR_ROOT" ]] ||
  gate INPUT STOCK UNKNOWN vendor_root_unavailable

# ----------------------------- D0-B0 inventories/deltas
for spec in "N1F:$N1F_ROOT" "C1:$C1_ROOT" "C2:$C2_ROOT"; do
  label="${spec%%:*}"
  root="${spec#*:}"
  if [[ -n "$root" && -d "$root" ]]; then
    "$SABLE_PYTHON" "$HELPER" inventory       --root "$root" --out "$OUT/inventory/${label}.tsv"       >"$OUT/logs/inventory-${label}.log" 2>&1
    rc=$?
    [[ "$rc" -eq 0 ]] && gate B0 "$label" PASS inventory_complete ||
      gate B0 "$label" UNKNOWN "inventory_rc=$rc"
  else
    gate B0 "$label" UNKNOWN root_unavailable
  fi
done

compare_pair() {
  local left="$1" right="$2" name="$3"
  if [[ -f "$OUT/inventory/${left}.tsv" && -f "$OUT/inventory/${right}.tsv" ]]; then
    "$SABLE_PYTHON" "$HELPER" compare-inventory       --left "$OUT/inventory/${left}.tsv"       --right "$OUT/inventory/${right}.tsv"       --out "$OUT/reports/${name}.tsv"       >"$OUT/logs/${name}.log" 2>&1
    [[ "$?" -eq 0 ]] && record "${name}_STATUS" PASS ||
      record "${name}_STATUS" UNKNOWN
  else
    record "${name}_STATUS" UNKNOWN
  fi
}
compare_pair N1F C1 N1F_TO_C1
compare_pair N1F C2 N1F_TO_C2
compare_pair C1 C2 C1_TO_C2

cat > "$OUT/reports/D0_B0_TELEPHONYMETRICS.env" <<'EOF_TM'
N1I_D0_TELEPHONYMETRICS_SCOPE=C2_ONLY
C1_DRIVER_PATCH_INVOCATION=ABSENT
C2_DRIVER_PATCH_INVOCATION=PRESENT
C3A_C1_SIGNATURE=(IIII)V
C2_ADMITTED_COMPAT_SIGNATURE=(II)V
EOF_TM

# ----------------------------- Gate A0/A1/A2
policy_args() {
  local root="$1"
  printf '%s\n'     --system-root "$root"     --system-ext-root "$root/system_ext"     --product-root "$root/product"     --vendor-root "$STOCK_VENDOR_ROOT"
  if [[ -n "$STOCK_ODM_ROOT" && -d "$STOCK_ODM_ROOT" ]]; then
    printf '%s\n' --odm-root "$STOCK_ODM_ROOT"
  fi
}

run_a0() {
  local label="$1" root="$2"
  if [[ -z "$root" || ! -d "$root" || -z "$STOCK_VENDOR_ROOT" || ! -d "$STOCK_VENDOR_ROOT" ]]; then
    gate A0 "$label" UNKNOWN required_root_missing
    record "N1I_D0_A0_${label}" UNKNOWN
    return
  fi
  local -a args=(
    "$SABLE_PYTHON" "$HELPER" policy-path
    --system-root "$root"
    --system-ext-root "$root/system_ext"
    --product-root "$root/product"
    --vendor-root "$STOCK_VENDOR_ROOT"
    --out "$OUT/reports/A0_${label}.tsv"
  )
  [[ -n "$STOCK_ODM_ROOT" && -d "$STOCK_ODM_ROOT" ]] &&
    args+=(--odm-root "$STOCK_ODM_ROOT")
  "${args[@]}" >"$OUT/logs/A0_${label}.log" 2>&1
  local rc=$? verdict
  if [[ "$rc" -ne 0 ]]; then
    verdict=UNKNOWN
  else
    verdict="$(sed -n 's/^N1I_D0_A0_POLICY_PATH=//p' "$OUT/logs/A0_${label}.log" | tail -1)"
    [[ "$verdict" == SPLIT_COMPILE || "$verdict" == PRECOMPILED_USED ]] ||
      verdict=UNKNOWN
  fi
  record "N1I_D0_A0_${label}" "$verdict"
  [[ "$verdict" == UNKNOWN ]] && gate A0 "$label" UNKNOWN policy_path_unresolved ||
    gate A0 "$label" PASS "$verdict"
}
run_a0 N1F "$N1F_ROOT"
run_a0 C2 "$C2_ROOT"
[[ -n "$C1_ROOT" ]] && run_a0 C1 "$C1_ROOT" || {
  gate A0 C1 UNKNOWN c1_binary_control_unavailable
  record N1I_D0_A0_C1 UNKNOWN
}

ANDROID16_INIT_SELINUX_CPP="${ANDROID16_INIT_SELINUX_CPP:-}"
if [[ -z "$ANDROID16_INIT_SELINUX_CPP" && -n "${ANDROID16_SOURCE_ROOT:-}" ]]; then
  candidate="$ANDROID16_SOURCE_ROOT/system/core/init/selinux.cpp"
  [[ -f "$candidate" ]] && ANDROID16_INIT_SELINUX_CPP="$candidate"
fi
INIT_SOURCE_OK=NO
if [[ -n "$ANDROID16_INIT_SELINUX_CPP" && -f "$ANDROID16_INIT_SELINUX_CPP" ]]; then
  if grep -Fq 'plat_sepolicy_and_mapping.sha256' "$ANDROID16_INIT_SELINUX_CPP" &&
     grep -Fq 'precompiled_sepolicy' "$ANDROID16_INIT_SELINUX_CPP" &&
     grep -Fq 'secilc' "$ANDROID16_INIT_SELINUX_CPP"; then
    INIT_SOURCE_OK=YES
    record ANDROID16_INIT_SELINUX_CPP "$(readlink -f "$ANDROID16_INIT_SELINUX_CPP")"
    record ANDROID16_INIT_SELINUX_CPP_SHA256 "$(sha_file "$ANDROID16_INIT_SELINUX_CPP")"
  fi
fi
record N1I_D0_A1_INIT_SOURCE_AUTHORITY "$INIT_SOURCE_OK"

run_a1() {
  local label="$1" root="$2" mode="$3" outbin="$WORK/${label,,}-sepolicy-${mode}.bin"
  local a0
  a0="$(sed -n "s/^N1I_D0_A0_${label}=//p" "$SUMMARY" | tail -1)"
  if [[ "$a0" == PRECOMPILED_USED ]]; then
    gate "A${mode}" "$label" PASS PRECOMPILED_USED_NO_SPLIT_COMPILE
    return
  fi
  if [[ "$a0" != SPLIT_COMPILE || "$INIT_SOURCE_OK" != YES ]]; then
    gate "A${mode}" "$label" UNKNOWN split_compile_authority_unavailable
    return
  fi
  local versfile="$STOCK_VENDOR_ROOT/etc/selinux/plat_sepolicy_vers.txt"
  [[ -f "$versfile" ]] || {
    gate "A${mode}" "$label" UNKNOWN vendor_mapping_version_missing
    return
  }
  local vers plat map
  vers="$(head -1 "$versfile" | tr -d '\r\n')"
  plat="$root/etc/selinux/plat_sepolicy.cil"
  map="$root/etc/selinux/mapping/$vers.cil"
  local vendor_pub="$STOCK_VENDOR_ROOT/etc/selinux/plat_pub_versioned.cil"
  local vendor_cil="$STOCK_VENDOR_ROOT/etc/selinux/vendor_sepolicy.cil"
  for req in "$plat" "$map" "$vendor_pub" "$vendor_cil"; do
    [[ -f "$req" ]] || {
      gate "A${mode}" "$label" UNKNOWN "required_policy_input_missing=$req"
      return
    }
  done

  local -a args=(
    "$plat" -m -M true -G
  )
  [[ "$mode" == 1 ]] && args+=(-N)
  args+=(-c "$SEPOLICY_VERSION" "$map" -o "$outbin" -f /dev/null)

  for p in     "$root/etc/selinux/mapping/$vers.compat.cil"     "$root/system_ext/etc/selinux/system_ext_sepolicy.cil"     "$root/system_ext/etc/selinux/mapping/$vers.cil"     "$root/system_ext/etc/selinux/mapping/$vers.compat.cil"     "$root/product/etc/selinux/product_sepolicy.cil"     "$root/product/etc/selinux/mapping/$vers.cil"     "$vendor_pub"     "$vendor_cil"     "${STOCK_ODM_ROOT:+$STOCK_ODM_ROOT/etc/selinux/odm_sepolicy.cil}"
  do
    [[ -n "$p" && -f "$p" ]] && args+=("$p")
  done

  local genfs_version_file="$STOCK_VENDOR_ROOT/etc/selinux/genfs_labels_version.txt"
  local genfs_version=""
  [[ -f "$genfs_version_file" ]] &&
    genfs_version="$(head -1 "$genfs_version_file" | tr -d '\r\n')"
  if [[ -n "$genfs_version" ]]; then
    genfs="$root/etc/selinux/mapping/genfs_labels_${genfs_version}.cil"
    [[ -f "$genfs" ]] && args+=("$genfs")
  fi

  {
    printf 'SECILC=%q\n' "$SABLE_SECILC"
    printf 'ARGS='
    printf '%q ' "${args[@]}"
    printf '\n'
  } > "$OUT/reports/A${mode}_${label}_command.txt"

  run_host_tool "$SABLE_SECILC" "${args[@]}"     >"$OUT/logs/A${mode}_${label}.log" 2>&1
  local rc=$?
  if [[ "$rc" -eq 0 ]]; then
    [[ "$mode" == 1 ]] &&
      gate A1 "$label" PASS INIT_EQUIVALENT_SPLIT_COMPILE ||
      gate A2 "$label" PASS FULL_COMPLIANCE_COMPILE
  else
    [[ "$mode" == 1 ]] &&
      gate A1 "$label" BOOT_FATAL "secilc_rc=$rc" ||
      gate A2 "$label" COMPLIANCE_ONLY "secilc_rc=$rc"
  fi
}
for spec in "N1F:$N1F_ROOT" "C2:$C2_ROOT" "C1:$C1_ROOT"; do
  label="${spec%%:*}"; root="${spec#*:}"
  if [[ -n "$root" && -d "$root" ]]; then
    run_a1 "$label" "$root" 1
    run_a1 "$label" "$root" 2
  else
    gate A1 "$label" UNKNOWN control_root_unavailable
    gate A2 "$label" UNKNOWN control_root_unavailable
  fi
done

# ----------------------------- Gate B/C context unions
context_roots() {
  local root="$1"
  printf '%s\n'     "system=$root"     "system_ext=$root/system_ext"     "product=$root/product"     "vendor=$STOCK_VENDOR_ROOT"
  [[ -n "$STOCK_ODM_ROOT" && -d "$STOCK_ODM_ROOT" ]] &&
    printf '%s\n' "odm=$STOCK_ODM_ROOT"
}

policy_binary_for() {
  local label="$1" root="$2" a0
  a0="$(sed -n "s/^N1I_D0_A0_${label}=//p" "$SUMMARY" | tail -1)"
  if [[ "$a0" == PRECOMPILED_USED ]]; then
    for p in       "${STOCK_ODM_ROOT:+$STOCK_ODM_ROOT/etc/selinux/precompiled_sepolicy}"       "$STOCK_VENDOR_ROOT/etc/selinux/precompiled_sepolicy"
    do
      [[ -n "$p" && -f "$p" ]] && {
        printf '%s\n' "$p"
        return 0
      }
    done
    return 1
  fi
  if awk -F '\t' -v c="$label"       '$1=="A1" && $2==c && $3=="PASS" {ok=1} END {exit !ok}' "$GATES"; then
    p="$WORK/${label,,}-sepolicy-1.bin"
    [[ -f "$p" ]] || return 1
    printf '%s\n' "$p"
    return 0
  fi
  return 1
}

context_files() {
  local root="$1" kind="$2" pattern
  [[ "$kind" == property ]] && pattern='*property_contexts' ||
    pattern='*service_contexts'
  for dir in     "$root/etc/selinux"     "$root/system_ext/etc/selinux"     "$root/product/etc/selinux"     "$STOCK_VENDOR_ROOT/etc/selinux"     "${STOCK_ODM_ROOT:+$STOCK_ODM_ROOT/etc/selinux}"
  do
    [[ -n "$dir" && -d "$dir" ]] || continue
    find "$dir" -maxdepth 1 -type f -name "$pattern" -print |
      LC_ALL=C sort
  done
}

run_context_gate() {
  local label="$1" root="$2" kind="$3" gate_name="$4"
  if [[ -z "$root" || ! -d "$root" ||
        -z "$STOCK_VENDOR_ROOT" || ! -d "$STOCK_VENDOR_ROOT" ]]; then
    gate "$gate_name" "$label" UNKNOWN required_root_missing
    return
  fi
  local -a args=("$SABLE_PYTHON" "$HELPER" contexts --kind "$kind")
  while IFS= read -r spec; do args+=(--root "$spec"); done < <(context_roots "$root")
  args+=(--out "$OUT/reports/${gate_name}_${label}.tsv")
  "${args[@]}" >"$OUT/logs/${gate_name}_${label}.static.log" 2>&1
  local rc=$? count policy
  [[ "$rc" -eq 0 ]] || {
    gate "$gate_name" "$label" UNKNOWN "helper_rc=$rc"
    return
  }
  count="$(
    sed -n 's/^N1I_D0_CONTEXT_CONFLICT_COUNT=//p'       "$OUT/logs/${gate_name}_${label}.static.log" | tail -1
  )"

  policy="$(policy_binary_for "$label" "$root" || true)"
  if [[ -z "$policy" || ! -f "$policy" ]]; then
    gate "$gate_name" "$label" UNKNOWN "compiled_policy_unavailable;static_conflicts=$count"
    return
  fi

  local -a files=()
  while IFS= read -r p; do
    [[ -f "$p" ]] && files+=("$p")
  done < <(context_files "$root" "$kind")
  [[ "${#files[@]}" -gt 0 ]] || {
    gate "$gate_name" "$label" UNKNOWN context_files_absent
    return
  }

  if [[ "$kind" == property ]]; then
    [[ -n "$PROPERTY_INFO_CHECKER" && -x "$PROPERTY_INFO_CHECKER" ]] || {
      gate "$gate_name" "$label" UNKNOWN "property_info_checker_missing;static_conflicts=$count"
      return
    }
    "$PROPERTY_INFO_CHECKER" "$policy" "${files[@]}"       >"$OUT/logs/${gate_name}_${label}.checker.log" 2>&1
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      gate "$gate_name" "$label" PASS "property_info_checker=PASS static_conflicts=$count"
    else
      gate "$gate_name" "$label" BOOT_FATAL "property_info_checker_rc=$rc static_conflicts=$count"
    fi
  else
    [[ -n "$CHECKFC" && -x "$CHECKFC" ]] || {
      gate "$gate_name" "$label" UNKNOWN "checkfc_missing;static_conflicts=$count"
      return
    }
    "$CHECKFC" -s "$policy" "${files[@]}"       >"$OUT/logs/${gate_name}_${label}.checker.log" 2>&1
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      gate "$gate_name" "$label" PASS "checkfc_service=PASS static_conflicts=$count"
    else
      gate "$gate_name" "$label" FUNCTIONAL_RISK "checkfc_service_rc=$rc static_conflicts=$count"
    fi
  fi
}
for spec in "N1F:$N1F_ROOT" "C2:$C2_ROOT"; do
  label="${spec%%:*}"; root="${spec#*:}"
  run_context_gate "$label" "$root" property B
  run_context_gate "$label" "$root" service C
done
[[ -n "$C1_ROOT" ]] && {
  run_context_gate C1 "$C1_ROOT" property B
  run_context_gate C1 "$C1_ROOT" service C
} || {
  gate B C1 UNKNOWN c1_binary_control_unavailable
  gate C C1 UNKNOWN c1_binary_control_unavailable
}

# Vendor VINTF provider evidence for the C1-added service contexts.
C1_SERVICE_SOURCE="$ROOT/product/titan2/n1i-c1/sepolicy/system_ext/private/service_contexts"
if [[ -f "$C1_SERVICE_SOURCE" && -n "$STOCK_VENDOR_ROOT" ]]; then
  {
    printf 'service\tprovider_text_match\n'
    while read -r service _context _rest; do
      [[ -n "$service" && "$service" != \#* ]] || continue
      found=NO
      for vr in "$STOCK_VENDOR_ROOT" "$STOCK_ODM_ROOT"; do
        [[ -d "$vr/etc/vintf" ]] || continue
        grep -RFl -- "$service" "$vr/etc/vintf" >/dev/null 2>&1 && found=YES
      done
      printf '%s\t%s\n' "$service" "$found"
    done < "$C1_SERVICE_SOURCE"
  } > "$OUT/reports/C_service_vintf.tsv"
fi

# ----------------------------- Gate D
AAPT2_OK=YES
for spec in "N1F:$N1F_ROOT" "C2:$C2_ROOT"; do
  label="${spec%%:*}"; root="${spec#*:}"
  if [[ -z "$root" || ! -d "$root" ]]; then
    gate D "$label" UNKNOWN root_unavailable
    continue
  fi
  framework="$root/framework/framework-res.apk"
  [[ -f "$framework" ]] || {
    gate D "$label" UNKNOWN framework_res_missing
    continue
  }
  "$AAPT2" dump xmltree --file AndroidManifest.xml "$framework"     >"$OUT/reports/D_${label}_framework_manifest.txt" 2>"$OUT/logs/D_${label}_framework_manifest.err"
  rc=$?
  [[ "$rc" -eq 0 ]] || {
    gate D "$label" UNKNOWN framework_manifest_parse_failed
    continue
  }

  mode="$(extract_prop_unique ro.control_privapp_permissions     "$root" "$root/system_ext" "$root/product")"
  record "N1I_D0_D_${label}_PRIVAPP_MODE" "$mode"

  if [[ "$label" == N1F ]]; then
    "$SABLE_PYTHON" "$HELPER" privapp-tree       --aapt2 "$AAPT2"       --framework-manifest "$OUT/reports/D_${label}_framework_manifest.txt"       --root "system=$root"       --root "system_ext=$root/system_ext"       --root "product=$root/product"       --out "$OUT/reports/D_N1F_privapp_tree.tsv"       >"$OUT/logs/D_N1F_privapp_tree.log" 2>&1
    rc=$?
    tree_result="$(sed -n 's/^N1I_D0_PRIVAPP_TREE=//p' "$OUT/logs/D_N1F_privapp_tree.log" | tail -1)"
    if [[ "$rc" -ne 0 || -z "$tree_result" || "$mode" == UNKNOWN ]]; then
      gate D N1F UNKNOWN "control_parse_or_mode_unknown"
    elif [[ "$mode" == enforce && "$tree_result" != PASS ]]; then
      gate D N1F BOOT_FATAL control_privapp_coverage_failure
    else
      gate D N1F PASS "mode=$mode result=$tree_result"
    fi
  else
    ims="$root/system_ext/priv-app/ImsService/ImsService.apk"
    [[ -f "$ims" ]] || {
      gate D C2 UNKNOWN ims_apk_missing
      continue
    }
    "$AAPT2" dump permissions "$ims"       >"$OUT/reports/D_C2_ims_permissions.txt" 2>"$OUT/logs/D_C2_ims_permissions.err"
    rc=$?
    [[ "$rc" -eq 0 ]] || {
      gate D C2 UNKNOWN ims_permission_parse_failed
      continue
    }
    local_args=(
      "$SABLE_PYTHON" "$HELPER" privapp
      --package com.mediatek.ims
      --candidate-partition system_ext
      --apk-permissions "$OUT/reports/D_C2_ims_permissions.txt"
      --framework-manifest "$OUT/reports/D_C2_framework_manifest.txt"
    )
    for sr in       "system=$STOCK_SYSTEM_ROOT"       "system_ext=$STOCK_SYSTEM_EXT_ROOT"       "product=$STOCK_PRODUCT_ROOT"
    do
      [[ -d "${sr#*=}" ]] && local_args+=(--stock-root "$sr")
    done
    local_args+=(
      --candidate-root "system=$root"
      --candidate-root "system_ext=$root/system_ext"
      --candidate-root "product=$root/product"
      --out "$OUT/reports/D_C2_privapp.json"
    )
    "${local_args[@]}" >"$OUT/logs/D_C2_privapp.log" 2>&1
    rc=$?
    missing="$(sed -n 's/^N1I_D0_PRIVAPP_MISSING_REQUIRED_COUNT=//p' "$OUT/logs/D_C2_privapp.log" | tail -1)"
    blocks="$(sed -n 's/^N1I_D0_PRIVAPP_SYSTEM_EXT_BLOCK_COUNT=//p' "$OUT/logs/D_C2_privapp.log" | tail -1)"
    if [[ "$rc" -ne 0 || ! "$missing" =~ ^[0-9]+$ || "$mode" == UNKNOWN ]]; then
      gate D C2 UNKNOWN coverage_or_mode_unresolved
    elif [[ "$mode" == enforce && ( "$missing" -gt 0 || "$blocks" -eq 0 ) ]]; then
      gate D C2 BOOT_FATAL "mode=enforce missing=$missing system_ext_blocks=$blocks"
    else
      gate D C2 PASS "mode=$mode missing=$missing system_ext_blocks=$blocks"
    fi
  fi
done

# seapp context evidence is factual and separate from Gate-D allowlist fatality.
for spec in "STOCK:$STOCK_SYSTEM_ROOT" "C2:$C2_ROOT"; do
  label="${spec%%:*}"; root="${spec#*:}"
  [[ -n "$root" && -d "$root" ]] || continue
  seapp_args=("$SABLE_PYTHON" "$HELPER" seapp --user radio --seinfo platform)
  if [[ "$label" == STOCK ]]; then
    for sr in       "system=$STOCK_SYSTEM_ROOT"       "system_ext=$STOCK_SYSTEM_EXT_ROOT"       "product=$STOCK_PRODUCT_ROOT"       "vendor=$STOCK_VENDOR_ROOT"       "odm=$STOCK_ODM_ROOT"
    do
      [[ -d "${sr#*=}" ]] && seapp_args+=(--root "$sr")
    done
  else
    seapp_args+=(--root "system=$root" --root "system_ext=$root/system_ext" --root "product=$root/product")
  fi
  seapp_args+=(--out "$OUT/reports/D4_${label}_seapp.tsv")
  "${seapp_args[@]}" >"$OUT/logs/D4_${label}_seapp.log" 2>&1 || true
done

# ----------------------------- Gate E APEX/classpath
prepare_apex_root() {
  local label="$1" root="$2" override="$3" dest="$WORK/${label,,}-apex"
  if [[ -n "$override" && -d "$override" ]]; then
    printf '%s\n' "$(readlink -f "$override")"
    return 0
  fi
  "$SABLE_PYTHON" "$HELPER" apex-extract     --system-root "$root"     --debugfs "$DEBUGFS"     --fsck-erofs "$FSCK_EROFS"     --out "$dest"     >"$OUT/logs/E_${label}_apex_extract.log" 2>&1
  [[ "$?" -eq 0 ]] || return 1
  printf '%s\n' "$dest"
}

N1F_APEX=""
C2_APEX=""
[[ -n "$N1F_ROOT" ]] &&
  N1F_APEX="$(prepare_apex_root N1F "$N1F_ROOT" "${N1F_APEX_ROOT:-}" || true)"
[[ -n "$C2_ROOT" ]] &&
  C2_APEX="$(prepare_apex_root C2 "$C2_ROOT" "${C2_APEX_ROOT:-}" || true)"
record N1I_D0_N1F_APEX_ROOT "${N1F_APEX:--}"
record N1I_D0_C2_APEX_ROOT "${C2_APEX:--}"

run_classpath() {
  local label="$1" system="$2" system_ext="$3" product="$4" apex="$5" api="$6"
  if [[ -z "$system" || -z "$system_ext" || -z "$product" ||
        -z "$apex" || ! -d "$apex" ]]; then
    gate E "$label" UNKNOWN apex_or_partition_root_unavailable
    return
  fi
  "$SABLE_PYTHON" "$HELPER" classpath     --repo "$ROOT"     --system-root "$system"     --system-ext-root "$system_ext"     --product-root "$product"     --apex-root "$apex"     --static-tool "$PIN_ROOT/build/titan2/n1i_static.py"     --api-level "$api"     --out "$OUT/reports/E_${label}"     >"$OUT/logs/E_${label}.log" 2>&1
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then
    gate E "$label" UNKNOWN "classpath_helper_rc=$rc"
    return
  fi
  local missing
  missing="$(
    sed -n 's/^N1I_D0_CLASSPATH_MISSING_COUNT=//p'       "$OUT/logs/E_${label}.log" | tail -1
  )"
  if [[ "$missing" =~ ^[0-9]+$ && "$missing" -gt 0 ]]; then
    gate E "$label" BOOT_FATAL "runtime_classpath_missing=$missing"
  else
    gate E "$label" PASS PATHS_RESOLVE_DUPLICATES_REPORT_ONLY_PENDING_BOOT_PATH
  fi
}

run_classpath N1F   "$N1F_ROOT" "$N1F_ROOT/system_ext" "$N1F_ROOT/product"   "$N1F_APEX" "$API_LEVEL"
run_classpath C2   "$C2_ROOT" "$C2_ROOT/system_ext" "$C2_ROOT/product"   "$C2_APEX" "$API_LEVEL"
[[ -n "$C1_ROOT" ]] &&
  gate E C1 UNKNOWN C1_APEX_CONTROL_NOT_MATERIALIZED ||
  gate E C1 UNKNOWN c1_binary_control_unavailable

# Stock E2 authority uses its own split system/system_ext/product partitions and
# Android 14 API level. This decides BCP vs named-library architecture; it does
# not by itself make a boot-fatal claim about C2.
STOCK_APEX=""
if [[ -n "$STOCK_SYSTEM_ROOT" && -d "$STOCK_SYSTEM_ROOT" ]]; then
  STOCK_APEX="$(
    prepare_apex_root STOCK "$STOCK_SYSTEM_ROOT" "${STOCK_APEX_ROOT:-}" || true
  )"
fi
record N1I_D0_STOCK_APEX_ROOT "${STOCK_APEX:--}"
if [[ -n "$STOCK_APEX" ]]; then
  run_classpath STOCK     "$STOCK_SYSTEM_ROOT" "$STOCK_SYSTEM_EXT_ROOT" "$STOCK_PRODUCT_ROOT"     "$STOCK_APEX" 34
else
  gate E STOCK UNKNOWN stock_apex_unavailable
fi

E2_MODEL=UNKNOWN
if [[ -f "$OUT/reports/E_STOCK/CLASSPATH.tsv" ]]; then
  common_stock="$(
    awk -F '\t' '$1=="BOOT" && $3=="/system_ext/framework/mediatek-common.jar" {print $2}'       "$OUT/reports/E_STOCK/CLASSPATH.tsv" | tail -1
  )"
  imsbase_stock="$(
    awk -F '\t' '$1=="BOOT" && $3=="/system_ext/framework/mediatek-ims-base.jar" {print $2}'       "$OUT/reports/E_STOCK/CLASSPATH.tsv" | tail -1
  )"
  common_declared=NO
  imsbase_declared=NO
  for r in "$STOCK_SYSTEM_ROOT" "$STOCK_SYSTEM_EXT_ROOT" "$STOCK_PRODUCT_ROOT"; do
    [[ -d "$r/etc/permissions" ]] || continue
    grep -RFl 'name="com.mediatek.common"' "$r/etc/permissions" >/dev/null 2>&1 &&
      common_declared=YES
    grep -RFl 'name="com.mediatek.ims.base"' "$r/etc/permissions" >/dev/null 2>&1 &&
      imsbase_declared=YES
  done
  if [[ -n "$common_stock" && -n "$imsbase_stock" ]]; then
    E2_MODEL=STOCK_BOOTCLASSPATH
  elif [[ "$common_declared" == YES && "$imsbase_declared" == YES ]]; then
    E2_MODEL=STOCK_NAMED_SHARED_LIBRARIES
  elif [[ -n "$common_stock$imsbase_stock" ||
          "$common_declared" == YES || "$imsbase_declared" == YES ]]; then
    E2_MODEL=STOCK_MIXED_MODEL_REVIEW_REQUIRED
  fi
fi
record N1I_D0_E2_JAR_MODEL "$E2_MODEL"

# Gate E stays UNKNOWN when the stock classloader model itself is unresolved.
# Append a final C2 row so verdict selection uses this stricter status.
if [[ "$E2_MODEL" == UNKNOWN ]]; then
  gate E C2 UNKNOWN stock_jar_classloader_model_unresolved
fi

# ----------------------------- Gate F IMS runtime role
if [[ -n "$C2_ROOT" && -f "$C2_ROOT/system_ext/priv-app/ImsService/ImsService.apk" ]]; then
  IMS_APK="$C2_ROOT/system_ext/priv-app/ImsService/ImsService.apk"
  "$AAPT2" dump badging "$IMS_APK" >"$OUT/reports/F_ims_badging.txt" 2>"$OUT/logs/F_badging.err"
  BADGING_RC=$?
  "$AAPT2" dump xmltree --file AndroidManifest.xml "$IMS_APK"     >"$OUT/reports/F_ims_manifest.txt" 2>"$OUT/logs/F_manifest.err"
  MANIFEST_RC=$?
  if [[ "$BADGING_RC" -eq 0 && "$MANIFEST_RC" -eq 0 ]]; then
    if grep -Eq 'persistent[^=]*=(0xffffffff|true)|process[^=]*="com\.android\.phone"|directBootAware[^=]*=(0xffffffff|true)'       "$OUT/reports/F_ims_manifest.txt"; then
      BOOT_PATH=YES
    else
      BOOT_PATH=NO
    fi
    {
      echo "BOOT_PATH_COMPONENT=$BOOT_PATH"
      echo "REQUIRED_LIBRARY_MISSING=UNKNOWN_PENDING_GATE_E2_MODEL"
      echo "REQUIRED_NATIVE_LIBRARY_MISSING=UNKNOWN_PENDING_GATE_G"
      echo "FOREIGN_RESOURCE_PACKAGE_DEPENDENCY=UNKNOWN_NOT_IMPLEMENTED"
    } > "$OUT/reports/F_summary.env"
    gate F C2 PASS "BOOT_PATH_COMPONENT=$BOOT_PATH"
  else
    gate F C2 UNKNOWN manifest_parse_failed
  fi
else
  gate F C2 UNKNOWN ims_apk_missing
fi
gate F N1F NOT_APPLICABLE_CONTROL no_ims_app_in_control

# ----------------------------- Gate G pinned B2 native rederivation
G_READY=NO
G_COMPLETE_COUNT=0
G_TARGET_COUNT=3
APEX_LIB_FLAT=""
if [[ -n "$C2_APEX" && -d "$C2_APEX" ]]; then
  APEX_LIB_FLAT="$WORK/c2-apex-lib64-flat"
  mkdir -p "$APEX_LIB_FLAT"
  while IFS= read -r lib; do
    base="$(basename "$lib")"
    if [[ ! -e "$APEX_LIB_FLAT/$base" ]]; then
      ln -s "$lib" "$APEX_LIB_FLAT/$base"
    fi
  done < <(
    find "$C2_APEX" -type f -path '*/lib64/*.so' -print 2>/dev/null |
      LC_ALL=C sort
  )
fi

run_b2_native_target() {
  local label="$1" target="$2" badging="$3"
  [[ -f "$target" ]] || return 10
  local -a args=(
    "$SABLE_PYTHON" "$PIN_ROOT/build/titan2/n1i-b2-native.py"
    --side c3a
    --apk "$target"
    --abi arm64-v8a
    --lib-dir "system=$C2_ROOT/lib64"
    --lib-dir "system_ext=$C2_ROOT/system_ext/lib64"
    --lib-dir "product=$C2_ROOT/product/lib64"
    --search-superset "$ROOT/product/titan2/n1i-c1/a4-native-superset.txt"
    --out "$OUT/reports/G_native_$label"
  )
  [[ -n "$badging" && -f "$badging" ]] && args+=(--badging "$badging")
  [[ -n "$APEX_LIB_FLAT" ]] && args+=(--lib-dir "apex=$APEX_LIB_FLAT")
  [[ -n "$STOCK_VENDOR_ROOT" && -d "$STOCK_VENDOR_ROOT/lib64" ]] &&
    args+=(--lib-dir "vendor=$STOCK_VENDOR_ROOT/lib64")
  [[ -n "$STOCK_ODM_ROOT" && -d "$STOCK_ODM_ROOT/lib64" ]] &&
    args+=(--lib-dir "odm=$STOCK_ODM_ROOT/lib64")
  "${args[@]}" >"$OUT/logs/G_native_$label.log" 2>&1
  return $?
}

if [[ "$B2_NATIVE_SELFTEST" == PASS && -n "$C2_ROOT" ]]; then
  IMS_APK="$C2_ROOT/system_ext/priv-app/ImsService/ImsService.apk"
  COMMON_JAR="$C2_ROOT/system_ext/framework/mediatek-common.jar"
  IMS_BASE_JAR="$C2_ROOT/system_ext/framework/mediatek-ims-base.jar"
  IMS_BADGING="$OUT/reports/G_ims_badging.txt"
  if [[ -f "$IMS_APK" ]]; then
    "$AAPT2" dump badging "$IMS_APK"       >"$IMS_BADGING" 2>"$OUT/logs/G_badging.err"
    [[ "$?" -eq 0 ]] || IMS_BADGING=""
  else
    IMS_BADGING=""
  fi

  run_b2_native_target ims "$IMS_APK" "$IMS_BADGING"
  [[ "$?" -eq 0 ]] && G_COMPLETE_COUNT=$((G_COMPLETE_COUNT + 1))
  run_b2_native_target common "$COMMON_JAR" ""
  [[ "$?" -eq 0 ]] && G_COMPLETE_COUNT=$((G_COMPLETE_COUNT + 1))
  run_b2_native_target imsbase "$IMS_BASE_JAR" ""
  [[ "$?" -eq 0 ]] && G_COMPLETE_COUNT=$((G_COMPLETE_COUNT + 1))

  if [[ "$G_COMPLETE_COUNT" -eq "$G_TARGET_COUNT" ]]; then
    G_READY=YES
    gate G C2 PASS PINNED_B2_APK_AND_TWO_JARS_COMPLETE
  else
    gate G C2 UNKNOWN "completed=$G_COMPLETE_COUNT expected=$G_TARGET_COUNT"
  fi
else
  gate G C2 UNKNOWN pinned_selftest_or_input_unavailable
fi
gate G N1F NOT_APPLICABLE_CONTROL pinned_B2_selftest_is_control
record N1I_D0_G2_SYMBOL_VERSION_CHECK UNKNOWN_NOT_IMPLEMENTED
record N1I_D0_G2_LINKER_NAMESPACE_CHECK UNKNOWN_NOT_IMPLEMENTED

# A4 retirement classification is evidence only. Union all three B2 reports.
printf 'library\tclassification\n' > "$OUT/reports/A4_RETIREMENT.tsv"
if [[ "$G_READY" == YES ]]; then
  "$SABLE_PYTHON" - "$OUT" <<'PY'
import csv
import pathlib
import sys
out=pathlib.Path(sys.argv[1])
seen={}
for p in sorted(out.glob("reports/G_native_*/SEARCH_SUPERSET.tsv")):
    with p.open(encoding="utf-8") as fp:
        for row in csv.DictReader(fp, delimiter="\t"):
            lib=row["library"]
            yes=row["admitted_by_evidence"]=="YES"
            seen[lib]=seen.get(lib,False) or yes
with (out/"reports/A4_RETIREMENT.tsv").open(
    "w",encoding="utf-8",newline=""
) as fp:
    w=csv.writer(fp,delimiter="\t")
    w.writerow(("library","classification"))
    for lib in sorted(seen):
        w.writerow((
            lib,
            "B2_REQUIRED_OR_TRANSITIVE" if seen[lib]
            else "SEARCH_SUPERSET_ONLY",
        ))
PY
fi

# ----------------------------- verdict semantics
closure_unknown=0
fatal_count=0
for g in A1 B D E; do
  n1f_status="$(
    awk -F '\t' -v g="$g"       '$1==g && $2=="N1F" {v=$3} END {print v}' "$GATES"
  )"
  c2_status="$(
    awk -F '\t' -v g="$g"       '$1==g && $2=="C2" {v=$3} END {print v}' "$GATES"
  )"
  [[ "$n1f_status" != PASS ]] &&
    closure_unknown=$((closure_unknown + 1))
  [[ "$c2_status" == UNKNOWN || -z "$c2_status" ]] &&
    closure_unknown=$((closure_unknown + 1))
  [[ "$c2_status" == BOOT_FATAL && "$n1f_status" == PASS ]] &&
    fatal_count=$((fatal_count + 1))
done

if [[ "$closure_unknown" -gt 0 ]]; then
  D0_VERDICT=NOT_CLOSED
elif [[ "$fatal_count" -gt 0 ]]; then
  D0_VERDICT=DEFECT_FOUND
else
  D0_VERDICT=NO_FATAL_DEFECT_FOUND
fi

E2_DECIDED=NO
F_COMPLETE=NO
G_COMPLETE=NO
[[ "$E2_MODEL" == STOCK_BOOTCLASSPATH ||
   "$E2_MODEL" == STOCK_NAMED_SHARED_LIBRARIES ]] &&
  E2_DECIDED=YES
[[ -f "$OUT/reports/F_summary.env" ]] &&
  ! grep -Fq '=UNKNOWN' "$OUT/reports/F_summary.env" &&
  F_COMPLETE=YES
[[ "$G_READY" == YES ]] && G_COMPLETE=YES

if [[ "$E2_DECIDED" == YES && "$F_COMPLETE" == YES && "$G_COMPLETE" == YES ]]; then
  C1J_READY=YES
else
  C1J_READY=NO
fi

record N1I_D0_VALIDATED_BOOT_FATAL_COUNT "$fatal_count"
record N1I_D0_CLOSURE_UNKNOWN_COUNT "$closure_unknown"
record N1I_D0_0H "$D0_VERDICT"
record N1I_D0_C1J_COMPOSITION_READY "$C1J_READY"
record N1I_D0_NEXT_PHYSICAL_IMAGE N1F_OBS_ONLY_AFTER_D0_REVIEW
record N1I_D0_NEXT_BUILD_AUTHORIZED NO
record N1I_D0_DEVICE_CONTACT NONE
record N1I_D0_REBOOT NONE
record N1I_D0_FLASH NONE

# Seal all evidence except ephemeral work and the seal itself.
(
  cd "$OUT" || exit 1
  find . -type f ! -path './work/*' ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)
SEAL_RC=$?
[[ "$SEAL_RC" -eq 0 ]] || fail evidence_seal

echo "===== N1I-D0-0H HOST CLOSURE RESULT ====="
cat "$SUMMARY"
echo "N1I_D0_EVIDENCE_SEAL=PASS"
echo "N1I_D0_EVIDENCE_DIR=$OUT"
echo "N1I_D0_PHYSICAL_ACTIONS=NONE"
