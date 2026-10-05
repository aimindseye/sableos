#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"

MATERIALIZER="$ROOT/build/titan2/materialize-n1i-c2-cellular-mvp-stock.py"
N1I_A_AUDIT="$ROOT/build/titan2/audit-n1i-a-v010014-oem-ims.sh"

MANIFEST_EVIDENCE="/srv/sable-build/evidence/titan2/n1i-c2-cellular-mvp-manifest/20261005T215928Z-8ebeebdb"
PREFERRED_REPLAY="/srv/sable-build/evidence/titan2/n1i-c1-runtime-linkage-v6e/20261005T195904Z-3612ca20/n1i-a-replay"
C3A_HISTORY="/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z"

EXPECTED_MANIFEST_A4_SHA="6dad2e573b912d6a20fd5b16cb667dc15b9d43cb1f831fa2751830282e437fd4"
EXPECTED_C3A_SHA="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
EXPECTED_N1I_A_AUDIT_BLOB="02f7b7330b468a31be8cfc60551673cad127313e"

OUT=""
EVIDENCE=""
REPLAY=""
AUTHORIZED=NO

fail() {
    echo "N1I_C2_MATERIALIZATION_DRIVER=FAIL reason=$1" >&2
    exit "${2:-2}"
}

usage() {
    cat <<'EOF'
Usage:
  run-n1i-c2-cellular-mvp-materialization.sh \
    --authorize-materialization \
    [--manifest-evidence DIR] \
    [--replay-evidence DIR] \
    [--out DIR] \
    [--evidence DIR]

This driver is host-only. It may write a sealed artifact/evidence bundle but
does not mutate Android source, build, contact a device, use the network,
reboot, or flash.

If --replay-evidence is omitted, the already-qualified retained V6E N1I-A
replay is used when its extracted work tree is present. Otherwise a fresh
read-only N1I-A replay is generated from the pinned stock reference and sealed
C3A control.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --authorize-materialization)
            AUTHORIZED=YES
            shift
            ;;
        --manifest-evidence)
            [[ $# -ge 2 ]] || fail missing_manifest_evidence_value 64
            MANIFEST_EVIDENCE="$2"
            shift 2
            ;;
        --replay-evidence)
            [[ $# -ge 2 ]] || fail missing_replay_evidence_value 64
            REPLAY="$2"
            shift 2
            ;;
        --out)
            [[ $# -ge 2 ]] || fail missing_out_value 64
            OUT="$2"
            shift 2
            ;;
        --evidence)
            [[ $# -ge 2 ]] || fail missing_evidence_value 64
            EVIDENCE="$2"
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

echo "===== N1I-C2 CELLULAR MVP MATERIALIZATION DRIVER ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "MATERIALIZATION_AUTHORIZED=$AUTHORIZED"

[[ "$AUTHORIZED" == YES ]] || fail materialization_requires_--authorize-materialization 64

for path in     "$MATERIALIZER"     "$N1I_A_AUDIT"     "$MANIFEST_EVIDENCE/CELLULAR_MVP_SUMMARY.env"     "$MANIFEST_EVIDENCE/CELLULAR_MVP_MUTATION_MANIFEST.tsv"     "$MANIFEST_EVIDENCE/CELLULAR_MVP_NATIVE_CLOSURE.tsv"     "$MANIFEST_EVIDENCE/SHA256SUMS.txt"     "$C3A_HISTORY/system.img"     "$C3A_HISTORY/SHA256SUMS.txt"
do
    [[ -f "$path" ]] || fail "required_file_missing=$path" 64
done

[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] ||
    fail sable_repo_dirty 65

(
    cd "$MANIFEST_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail manifest_evidence_seal 65

grep -Fxq     "N1I_C2_MANIFEST_N1I_A_A4_SHA256=$EXPECTED_MANIFEST_A4_SHA"     "$MANIFEST_EVIDENCE/CELLULAR_MVP_SUMMARY.env" ||
    fail manifest_a4_authority 65

grep -Fxq 'N1I_C2_MANIFEST_NATIVE_IMPORT_COUNT=33'     "$MANIFEST_EVIDENCE/CELLULAR_MVP_SUMMARY.env" ||
    fail manifest_native_count 65

grep -Fxq 'N1I_C2_MANIFEST_MUTATION_COUNT=41'     "$MANIFEST_EVIDENCE/CELLULAR_MVP_SUMMARY.env" ||
    fail manifest_mutation_count 65

grep -Fxq 'N1I_C2_CELLULAR_MVP_MUTATION_MANIFEST=PASS'     "$MANIFEST_EVIDENCE/CELLULAR_MVP_SUMMARY.env" ||
    fail manifest_not_pass 65

(
    cd "$C3A_HISTORY"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail c3a_history_seal 65

[[ "$(sha256sum "$C3A_HISTORY/system.img" | awk '{print $1}')" == "$EXPECTED_C3A_SHA" ]] ||
    fail c3a_sha 65

AUDIT_BLOB="$(git -C "$ROOT" hash-object "$N1I_A_AUDIT")"
[[ "$AUDIT_BLOB" == "$EXPECTED_N1I_A_AUDIT_BLOB" ]] ||
    fail "n1i_a_audit_blob=$AUDIT_BLOB" 65

if [[ -z "$OUT" || -z "$EVIDENCE" ]]; then
    STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
    [[ -n "$OUT" ]] ||
        OUT="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c2-cellular-mvp-stock/$STAMP"
    [[ -n "$EVIDENCE" ]] ||
        EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-c2-cellular-mvp-materialization/$STAMP"
fi

[[ ! -e "$OUT" ]] || fail "out_exists=$OUT" 64
[[ ! -e "$EVIDENCE" ]] || fail "evidence_exists=$EVIDENCE" 64
mkdir -p "$EVIDENCE"

usable_replay() {
    local r="$1"
    [[ -f "$r/n1i-a-v010014-oem-ims.env" ]] &&
    [[ -f "$r/inputs.tsv" ]] &&
    [[ -d "$r/work/stock/system_img" ]] &&
    [[ -d "$r/work/stock/system_ext" ]] &&
    [[ -d "$r/work/stock/product" ]]
}

if [[ -n "$REPLAY" ]]; then
    usable_replay "$REPLAY" || fail "explicit_replay_not_usable=$REPLAY" 65
    REPLAY_SOURCE=EXPLICIT_RETAINED
elif usable_replay "$PREFERRED_REPLAY"; then
    REPLAY="$PREFERRED_REPLAY"
    REPLAY_SOURCE=QUALIFIED_V6E_RETAINED
else
    REPLAY="$EVIDENCE/n1i-a-replay"
    REPLAY_SOURCE=FRESH_PINNED_REPLAY
    echo
    echo "===== GENERATE FRESH READ-ONLY N1I-A REPLAY ====="
    if bash "$N1I_A_AUDIT" \
        --c3a-system "$C3A_HISTORY/system.img" \
        --out "$REPLAY" \
        --tools-dir "$SABLE_ANDROID_BUILD_TOOLS" \
        > >(tee "$EVIDENCE/n1i-a-replay.log") 2>&1
    then
        REPLAY_RC=0
    else
        REPLAY_RC=$?
    fi
    [[ "$REPLAY_RC" -eq 0 ]] || fail "fresh_replay_rc=$REPLAY_RC" 66
    usable_replay "$REPLAY" || fail fresh_replay_missing_work 66
fi

echo "N1I_C2_MATERIALIZATION_REPLAY_SOURCE=$REPLAY_SOURCE"
echo "N1I_C2_MATERIALIZATION_REPLAY=$REPLAY"

echo
echo "===== FREEZE STOCK PAYLOAD ====="

if "$SABLE_PYTHON" "$MATERIALIZER" \
    --manifest-evidence "$MANIFEST_EVIDENCE" \
    --replay-evidence "$REPLAY" \
    --out "$OUT" \
    > >(tee "$EVIDENCE/materialization.log") 2>&1
then
    MATERIALIZE_RC=0
else
    MATERIALIZE_RC=$?
fi

[[ "$MATERIALIZE_RC" -eq 0 ]] ||
    fail "materializer_rc=$MATERIALIZE_RC" 67

(
    cd "$OUT"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail output_seal 67

grep -Fxq 'N1I_C2_MATERIALIZATION_STOCK_FILE_COUNT=36'     "$OUT/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    fail output_stock_count 67
grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT=33'     "$OUT/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    fail output_native_count 67
grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_HASH_COUNT=33'     "$OUT/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    fail output_native_hash_count 67
grep -Fxq 'N1I_C2_MATERIALIZATION_MUTATION_COUNT=41'     "$OUT/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    fail output_mutation_count 67
grep -Fxq 'N1I_C2_CELLULAR_MVP_STOCK_MATERIALIZATION=PASS'     "$OUT/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    fail output_not_pass 67

[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] ||
    fail sable_repo_changed 68

cat > "$EVIDENCE/materialization-driver.env" <<EOF
N1I_C2_MATERIALIZATION_SOURCE_COMMIT=$(git -C "$ROOT" rev-parse HEAD)
N1I_C2_MATERIALIZATION_REPLAY_SOURCE=$REPLAY_SOURCE
N1I_C2_MATERIALIZATION_REPLAY=$REPLAY
N1I_C2_MATERIALIZATION_MANIFEST_EVIDENCE=$MANIFEST_EVIDENCE
N1I_C2_MATERIALIZATION_ARTIFACT=$OUT
N1I_C2_MATERIALIZATION_SOURCE_MUTATION_AUTHORIZED=NO
N1I_C2_MATERIALIZATION_BUILD_AUTHORIZED=NO
N1I_C2_MATERIALIZATION_DEVICE_CONTACT_AUTHORIZED=NO
N1I_C2_MATERIALIZATION_FLASH_AUTHORIZED=NO
N1I_C2_MATERIALIZATION_DRIVER=PASS
EOF

(
    cd "$EVIDENCE"
    find . -type f ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail evidence_seal 68

echo
echo "N1I_C2_MATERIALIZATION_DRIVER=PASS"
echo "N1I_C2_MATERIALIZATION_ARTIFACT=$OUT"
echo "N1I_C2_MATERIALIZATION_EVIDENCE=$EVIDENCE"
echo "N1I_C2_SOURCE_MUTATION_AUTHORIZED=NO"
echo "N1I_C2_BUILD_AUTHORIZED=NO"
