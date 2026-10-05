#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
PATCH="$ROOT/patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch"

[[ -f "$STORAGE_PROFILE" ]] || {
    echo "N1I_C1_TELEPHONY_METRICS_COMPAT=FAIL reason=storage_profile_missing" >&2
    exit 2
}
# shellcheck source=/dev/null
source "$STORAGE_PROFILE"

TARGET_REL="src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java"
BASE_BLOB="27638e5be9c008101c2f9b8f1e7a9af49d94f838"
POST_BLOB="9d5108e0ddb8d4960d21cda021813b53dbbf4da8"
PATCH_BLOB="ee353caded6dd07318991eb52d66687e06034c30"
DEFAULT_OPT_TEL="$SABLE_WORKSPACES_ROOT/titan2-n1d/frameworks/opt/telephony"

OPT_TEL="$DEFAULT_OPT_TEL"
ACTION="verify"
ACTION_SET="NO"
SOURCE_MUTATION_AUTHORIZED="NO"

fail() {
    echo "N1I_C1_TELEPHONY_METRICS_COMPAT=FAIL reason=$*" >&2
    exit 2
}

usage() {
    cat <<'EOF'
Usage:
  qualify-n1i-c1-telephonymetrics-compat.sh [options]

Options:
  --opt-telephony DIR          frameworks/opt/telephony checkout
  --verify                     verify exact base/post state (default)
  --apply                      apply the reviewed overload patch
  --revert                     revert the reviewed overload patch
  --authorize-source-mutation  required for --apply / --revert
  -h, --help                   show this help

This tool never builds, fetches from the network, contacts a device, reboots,
or flashes. Source mutation is limited to the single pinned TelephonyMetrics
target and requires explicit authorization.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --opt-telephony)
            [[ $# -ge 2 ]] || fail "missing_value=--opt-telephony"
            OPT_TEL="$2"
            shift 2
            ;;
        --verify)
            [[ "$ACTION_SET" == "NO" ]] || fail "multiple_actions"
            ACTION="verify"
            ACTION_SET="YES"
            shift
            ;;
        --apply)
            [[ "$ACTION_SET" == "NO" ]] || fail "multiple_actions"
            ACTION="apply"
            ACTION_SET="YES"
            shift
            ;;
        --revert)
            [[ "$ACTION_SET" == "NO" ]] || fail "multiple_actions"
            ACTION="revert"
            ACTION_SET="YES"
            shift
            ;;
        --authorize-source-mutation)
            SOURCE_MUTATION_AUTHORIZED="YES"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown_argument=$1"
            ;;
    esac
done

[[ -f "$PATCH" ]] || fail "patch_missing=$PATCH"
[[ -d "$OPT_TEL" ]] || fail "opt_telephony_missing=$OPT_TEL"
TARGET="$OPT_TEL/$TARGET_REL"
[[ -f "$TARGET" ]] || fail "target_missing=$TARGET"

PATCH_ACTUAL="$(git hash-object "$PATCH")"
[[ "$PATCH_ACTUAL" == "$PATCH_BLOB" ]] ||
    fail "patch_blob expected=$PATCH_BLOB actual=$PATCH_ACTUAL"

DIFF_COUNT="$(grep -Ec '^diff --git ' "$PATCH" || true)"
[[ "$DIFF_COUNT" == 1 ]] || fail "patch_diff_count=$DIFF_COUNT"

NUMSTAT="$(git -C "$OPT_TEL" apply --numstat "$PATCH" 2>/dev/null || true)"
[[ "$NUMSTAT" == $'8\t0\t'"$TARGET_REL" ]] ||
    fail "patch_numstat_unexpected=$(printf '%q' "$NUMSTAT")"

TWO_ARG='    public void writeRilAnswer(int phoneId, int rilSerial) {'
FOUR_ARG='    public void writeRilAnswer(int phoneId, int rilSerial, int rilError, int rilRequest) {'

grep -Fq -- "+$TWO_ARG" "$PATCH" ||
    fail "patch_missing_two_arg_overload"
grep -Fq -- " $FOUR_ARG" "$PATCH" ||
    fail "patch_missing_four_arg_context"

target_blob() {
    git -C "$OPT_TEL" hash-object "$TARGET_REL"
}

verify_base() {
    local blob
    blob="$(target_blob)"
    [[ "$blob" == "$BASE_BLOB" ]] ||
        fail "base_blob expected=$BASE_BLOB actual=$blob"
    [[ "$(grep -Fxc -- "$TWO_ARG" "$TARGET" || true)" == 0 ]] ||
        fail "base_two_arg_overload_present"
    [[ "$(grep -Fxc -- "$FOUR_ARG" "$TARGET" || true)" == 1 ]] ||
        fail "base_four_arg_overload_count"
    git -C "$OPT_TEL" apply --check "$PATCH" ||
        fail "base_patch_apply_check"
}

verify_post() {
    local blob
    blob="$(target_blob)"
    [[ "$blob" == "$POST_BLOB" ]] ||
        fail "post_blob expected=$POST_BLOB actual=$blob"
    [[ "$(grep -Fxc -- "$TWO_ARG" "$TARGET" || true)" == 1 ]] ||
        fail "post_two_arg_overload_count"
    [[ "$(grep -Fxc -- "$FOUR_ARG" "$TARGET" || true)" == 1 ]] ||
        fail "post_four_arg_overload_count"
    git -C "$OPT_TEL" apply --reverse --check "$PATCH" ||
        fail "post_reverse_apply_check"
}

CURRENT_BLOB="$(target_blob)"

echo "===== N1I-C1 TELEPHONYMETRICS LEGACY ABI COMPAT ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "ADB_COMMANDS_AUTHORIZED=NO"
echo "FASTBOOT_COMMANDS_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=$SOURCE_MUTATION_AUTHORIZED"
echo "ACTION=$ACTION"
echo "OPT_TELEPHONY=$OPT_TEL"
echo "TARGET=$TARGET_REL"
echo "EXPECTED_BASE_BLOB=$BASE_BLOB"
echo "EXPECTED_POST_BLOB=$POST_BLOB"
echo "EXPECTED_PATCH_BLOB=$PATCH_BLOB"
echo "CURRENT_TARGET_BLOB=$CURRENT_BLOB"
echo "N1I_C1_TELEPHONY_METRICS_STOCK_REQUIRED_ABI=(II)V"
echo "N1I_C1_TELEPHONY_METRICS_EXISTING_STUB_ABI=(IIII)V"
echo "N1I_C1_TELEPHONY_METRICS_COMPAT_SEMANTICS=NOOP_OVERLOAD_ONLY"

case "$CURRENT_BLOB" in
    "$BASE_BLOB")
        verify_base
        echo "N1I_C1_TELEPHONY_METRICS_STATE=PASS_EXACT_BASE"
        ;;
    "$POST_BLOB")
        verify_post
        echo "N1I_C1_TELEPHONY_METRICS_STATE=PASS_EXACT_PATCHED"
        ;;
    *)
        fail "unexpected_target_blob=$CURRENT_BLOB"
        ;;
esac

case "$ACTION" in
    verify)
        echo "N1I_C1_TELEPHONY_METRICS_MUTATION=NOT_RUN"
        ;;
    apply)
        if [[ "$CURRENT_BLOB" == "$POST_BLOB" ]]; then
            echo "N1I_C1_TELEPHONY_METRICS_MUTATION=PASS_ALREADY_APPLIED"
        else
            [[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] ||
                fail "apply_requires_--authorize-source-mutation"
            git -C "$OPT_TEL" apply --check "$PATCH" ||
                fail "preapply_check"
            git -C "$OPT_TEL" apply "$PATCH" ||
                fail "apply_failed"
            verify_post
            git -C "$OPT_TEL" diff --check -- "$TARGET_REL" ||
                fail "postapply_diff_check"
            echo "N1I_C1_TELEPHONY_METRICS_MUTATION=PASS_APPLIED"
        fi
        ;;
    revert)
        if [[ "$CURRENT_BLOB" == "$BASE_BLOB" ]]; then
            echo "N1I_C1_TELEPHONY_METRICS_MUTATION=PASS_ALREADY_BASE"
        else
            [[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] ||
                fail "revert_requires_--authorize-source-mutation"
            git -C "$OPT_TEL" apply --reverse --check "$PATCH" ||
                fail "prerevert_check"
            git -C "$OPT_TEL" apply --reverse "$PATCH" ||
                fail "revert_failed"
            verify_base
            git -C "$OPT_TEL" diff --check -- "$TARGET_REL" ||
                fail "postrevert_diff_check"
            echo "N1I_C1_TELEPHONY_METRICS_MUTATION=PASS_REVERTED"
        fi
        ;;
    *)
        fail "internal_action=$ACTION"
        ;;
esac

FINAL_BLOB="$(target_blob)"
echo "FINAL_TARGET_BLOB=$FINAL_BLOB"
echo "N1I_C1_TELEPHONY_METRICS_COMPAT=PASS"
