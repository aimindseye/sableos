#!/usr/bin/env bash
# Probe the sealed N1I-C1 system image for the exact 33 frozen C2 native paths.
#
# Host-only/read-only. No Android source mutation, build, network, device,
# reboot, or flash authority is exercised.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"

EXPECTED_C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
EXPECTED_NATIVE_COUNT=33

C1_SYSTEM=""
MATERIALIZED=""
OUT=""

fail() {
    echo "N1I_C2_C1_NATIVE_BASELINE_PROBE=FAIL reason=$1" >&2
    return "${2:-1}"
}

usage() {
    cat <<'EOF'
Usage:
  probe-n1i-c2-c1-native-baseline.sh \
    --c1-system FILE \
    --materialized DIR \
    --out DIR

Reads the exact sealed C1 image and frozen C2 materialization only.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --c1-system)
            [[ $# -ge 2 ]] || { fail missing_c1_system_value 64; exit $?; }
            C1_SYSTEM="$2"
            shift 2
            ;;
        --materialized)
            [[ $# -ge 2 ]] || { fail missing_materialized_value 64; exit $?; }
            MATERIALIZED="$2"
            shift 2
            ;;
        --out)
            [[ $# -ge 2 ]] || { fail missing_out_value 64; exit $?; }
            OUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown_argument=$1" 64
            exit $?
            ;;
    esac
done

echo "===== N1I-C2 SEALED C1 NATIVE BASELINE PROBE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

[[ -n "$C1_SYSTEM" && -f "$C1_SYSTEM" ]] ||
    { fail c1_system_missing 64; exit $?; }
[[ -n "$MATERIALIZED" && -d "$MATERIALIZED" ]] ||
    { fail materialized_missing 64; exit $?; }
[[ -n "$OUT" ]] || { fail out_missing 64; exit $?; }

C1_SYSTEM="$(realpath "$C1_SYSTEM")"
MATERIALIZED="$(realpath "$MATERIALIZED")"
OUT="$(realpath -m "$OUT")"

[[ ! -e "$OUT" ]] || { fail "out_exists=$OUT" 64; exit $?; }
mkdir -p "$OUT" || { fail out_create 65; exit $?; }

C1_SHA="$(sha256sum "$C1_SYSTEM" | awk '{print $1}')"
[[ "$C1_SHA" == "$EXPECTED_C1_SHA" ]] ||
    { fail "c1_sha=$C1_SHA" 65; exit $?; }

[[ -f "$MATERIALIZED/SHA256SUMS.txt" ]] ||
    { fail materialization_seal_missing 65; exit $?; }
(
    cd "$MATERIALIZED" || exit 1
    sha256sum -c SHA256SUMS.txt >/dev/null
)
MAT_SEAL_RC=$?
[[ "$MAT_SEAL_RC" -eq 0 ]] ||
    { fail materialization_seal 65; exit $?; }

MAP="$MATERIALIZED/CELLULAR_MVP_STOCK_MATERIALIZATION.tsv"
SUMMARY="$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env"
[[ -f "$MAP" && -f "$SUMMARY" ]] ||
    { fail materialization_inputs_missing 65; exit $?; }
grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT=33' "$SUMMARY" ||
    { fail materialization_native_count 65; exit $?; }
grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_HASH_COUNT=33' "$SUMMARY" ||
    { fail materialization_native_hash_count 65; exit $?; }

image_type() {
    local img="$1"
    if [[ "$(od -An -tx1 -j 0 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == 3aff26ed ]]; then
        echo sparse
    elif [[ "$(od -An -tx1 -j 1080 -N 2 "$img" 2>/dev/null | tr -d ' \n')" == 53ef ]]; then
        echo ext4
    elif [[ "$(od -An -tx1 -j 1024 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == e2e1f5e0 ]]; then
        echo erofs
    else
        echo unknown
    fi
}

TARGET_IMAGE="$C1_SYSTEM"
TEMP_RAW=""
TEMP_ROOT=""

C1_KIND="$(image_type "$C1_SYSTEM")"
if [[ "$C1_KIND" == sparse ]]; then
    TEMP_RAW="$OUT/.c1.raw.img"
    "$SABLE_SIMG2IMG" "$C1_SYSTEM" "$TEMP_RAW" >/dev/null
    CONVERT_RC=$?
    [[ "$CONVERT_RC" -eq 0 ]] ||
        { rm -f "$TEMP_RAW"; fail "simg2img_rc=$CONVERT_RC" 66; exit $?; }
    TARGET_IMAGE="$TEMP_RAW"
    C1_KIND="$(image_type "$TARGET_IMAGE")"
fi

echo "N1I_C2_C1_BASELINE_IMAGE_TYPE=$C1_KIND"

debugfs_stat() {
    local path="$1" output
    output="$(debugfs -R "stat $path" "$TARGET_IMAGE" 2>&1)"
    grep -Fq 'Inode:' <<<"$output"
}

debugfs_dump() {
    local image_path="$1" dest="$2"
    rm -f "$dest"
    debugfs -R "dump -p $image_path $dest" "$TARGET_IMAGE" >/dev/null 2>&1
    [[ -f "$dest" ]]
}

ROOT_PREFIX=""
case "$C1_KIND" in
    ext4)
        if debugfs_stat /build.prop; then
            ROOT_PREFIX=""
        elif debugfs_stat /system/build.prop; then
            ROOT_PREFIX="/system"
        else
            rm -f "$TEMP_RAW"
            fail c1_ext4_layout_unknown 66
            exit $?
        fi
        ;;
    erofs)
        TEMP_ROOT="$OUT/.c1-root"
        mkdir -p "$TEMP_ROOT" || { rm -f "$TEMP_RAW"; fail erofs_temp_root 66; exit $?; }
        fsck.erofs --extract="$TEMP_ROOT" "$TARGET_IMAGE" >/dev/null 2>"$OUT/erofs-extract.log"
        EROFS_RC=$?
        [[ "$EROFS_RC" -eq 0 ]] ||
            { rm -rf "$TEMP_ROOT" "$TEMP_RAW"; fail "erofs_extract_rc=$EROFS_RC" 66; exit $?; }
        if [[ -f "$TEMP_ROOT/build.prop" ]]; then
            ROOT_PREFIX=""
        elif [[ -f "$TEMP_ROOT/system/build.prop" ]]; then
            ROOT_PREFIX="/system"
        else
            rm -rf "$TEMP_ROOT" "$TEMP_RAW"
            fail c1_erofs_layout_unknown 66
            exit $?
        fi
        ;;
    *)
        rm -f "$TEMP_RAW"
        fail "unsupported_c1_image_type=$C1_KIND" 66
        exit $?
        ;;
esac

map_image_path() {
    local target="$1" rel
    case "$target" in
        /system/*)
            rel="${target#/system/}"
            if [[ -n "$ROOT_PREFIX" ]]; then
                printf '%s/%s\n' "$ROOT_PREFIX" "$rel"
            else
                printf '/%s\n' "$rel"
            fi
            ;;
        /system_ext/*)
            rel="${target#/system_ext/}"
            if [[ -n "$ROOT_PREFIX" ]]; then
                printf '%s/system_ext/%s\n' "$ROOT_PREFIX" "$rel"
            else
                printf '/system_ext/%s\n' "$rel"
            fi
            ;;
        /product/*)
            rel="${target#/product/}"
            if [[ -n "$ROOT_PREFIX" ]]; then
                printf '%s/product/%s\n' "$ROOT_PREFIX" "$rel"
            else
                printf '/product/%s\n' "$rel"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

extract_one() {
    local image_path="$1" dest="$2" host_path
    case "$C1_KIND" in
        ext4)
            debugfs_dump "$image_path" "$dest"
            ;;
        erofs)
            if [[ -n "$ROOT_PREFIX" ]]; then
                host_path="$TEMP_ROOT${image_path}"
            else
                host_path="$TEMP_ROOT${image_path}"
            fi
            [[ -f "$host_path" ]] || return 1
            install -m 0600 "$host_path" "$dest"
            ;;
        *)
            return 1
            ;;
    esac
}

PROBE="$OUT/NATIVE_BASELINE_PROBE.tsv"
printf 'id\ttarget\tmodule\tstock_sha256\tc1_status\tc1_sha256\tc1_image_path\n' > "$PROBE"

PRESENT=0
ABSENT=0
IDENTICAL=0
DIFFERENT=0
ROWS=0
TMP_FILE="$OUT/.probe-file"

{
    IFS= read -r _header
    while IFS=$'\t' read -r mutation_id kind partition target source bundle_path stock_sha bytes elf_class elf_machine authority; do
        [[ -n "$mutation_id" ]] || continue
        [[ "$kind" == NATIVE ]] || continue

        case "$mutation_id" in
            M0[0-3][0-9]) ;;
            *) rm -rf "$TEMP_ROOT" "$TEMP_RAW" "$TMP_FILE"; fail "unexpected_native_id=$mutation_id" 67; exit $? ;;
        esac

        NUM="${mutation_id#M}"
        NUM_VALUE=$((10#$NUM))
        [[ "$NUM_VALUE" -ge 7 && "$NUM_VALUE" -le 39 ]] ||
            { rm -rf "$TEMP_ROOT" "$TEMP_RAW" "$TMP_FILE"; fail "native_id_range=$mutation_id" 67; exit $?; }

        MODULE="SableN1IC2Native$mutation_id"
        IMAGE_PATH="$(map_image_path "$target")" ||
            { rm -rf "$TEMP_ROOT" "$TEMP_RAW" "$TMP_FILE"; fail "target_map=$target" 67; exit $?; }

        rm -f "$TMP_FILE"
        if extract_one "$IMAGE_PATH" "$TMP_FILE"; then
            C1_STATUS=PRESENT
            C1_SHA="$(sha256sum "$TMP_FILE" | awk '{print $1}')"
            PRESENT=$((PRESENT + 1))
            if [[ "$C1_SHA" == "$stock_sha" ]]; then
                IDENTICAL=$((IDENTICAL + 1))
            else
                DIFFERENT=$((DIFFERENT + 1))
            fi
        else
            C1_STATUS=ABSENT
            C1_SHA=-
            ABSENT=$((ABSENT + 1))
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$mutation_id" "$target" "$MODULE" "$stock_sha" \
            "$C1_STATUS" "$C1_SHA" "$IMAGE_PATH" >> "$PROBE"
        ROWS=$((ROWS + 1))
    done
} < "$MAP"

rm -f "$TMP_FILE" "$TEMP_RAW"
rm -rf "$TEMP_ROOT"

[[ "$ROWS" -eq "$EXPECTED_NATIVE_COUNT" ]] ||
    { fail "probe_row_count=$ROWS" 67; exit $?; }
[[ $((PRESENT + ABSENT)) -eq "$EXPECTED_NATIVE_COUNT" ]] ||
    { fail "probe_status_total=present:$PRESENT,absent:$ABSENT" 67; exit $?; }
[[ $((IDENTICAL + DIFFERENT)) -eq "$PRESENT" ]] ||
    { fail "probe_hash_total=identical:$IDENTICAL,different:$DIFFERENT,present:$PRESENT" 67; exit $?; }

cat > "$OUT/NATIVE_BASELINE_SUMMARY.env" <<EOF
N1I_C2_C1_NATIVE_BASELINE_VERSION=1
N1I_C2_C1_SYSTEM_SHA256=$EXPECTED_C1_SHA
N1I_C2_C1_IMAGE_TYPE=$C1_KIND
N1I_C2_C1_ROOT_PREFIX=${ROOT_PREFIX:-ROOT}
N1I_C2_C1_NATIVE_TARGET_COUNT=$ROWS
N1I_C2_C1_NATIVE_PRESENT_COUNT=$PRESENT
N1I_C2_C1_NATIVE_ABSENT_COUNT=$ABSENT
N1I_C2_C1_NATIVE_IDENTICAL_TO_STOCK_COUNT=$IDENTICAL
N1I_C2_C1_NATIVE_DIFFERENT_FROM_STOCK_COUNT=$DIFFERENT
N1I_C2_C1_NATIVE_BASELINE_PROBE=PASS
EOF

(
    cd "$OUT" || exit 1
    find . -maxdepth 1 -type f ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)
SEAL_RC=$?
[[ "$SEAL_RC" -eq 0 ]] || { fail output_seal 68; exit $?; }

cat "$OUT/NATIVE_BASELINE_SUMMARY.env"
echo "N1I_C2_C1_NATIVE_BASELINE_PROBE_OUT=$OUT"
echo "N1I_C2_C1_NATIVE_BASELINE_PROBE=PASS"
