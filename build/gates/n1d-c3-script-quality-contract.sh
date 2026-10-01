#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREP="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"
PARSE="$ROOT/build/titan2/qualify-n1d-c3-product-parse.sh"
BUILD="$ROOT/build/titan2/build-n1d-c3-trebledroid-systemimage.sh"
PIPELINE="$ROOT/build/gates/sable-pipeline-contract.sh"

fail() {
    echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=FAIL $*" >&2
    exit 1
}

syntax_files=(
    "$ROOT/build/titan2/n1d-source-lock.env"
    "$ROOT/build/titan2/n1d-product-contract.env"
    "$ROOT/build/titan2/n1d-restless-security-boundary.env"
    "$ROOT/build/titan2/n1d-c3-composition.env"
    "$ROOT/build/titan2/n1d-c3-phase-split.env"
    "$ROOT/build/titan2/n1d-c3-trebledroid.env"
    "$PREP"
    "$PARSE"
    "$BUILD"
    "$ROOT/build/titan2/stage-n1d-c3-product.sh"
    "$ROOT/build/titan2/tests/test-n1d-c0-offline.sh"
    "$ROOT/build/gates/n1d-c3-phase-split-contract.sh"
    "$ROOT/build/gates/n1d-c3-trebledroid-contract.sh"
    "$ROOT/build/gates/n1d-c3-product-composition-contract.sh"
    "$ROOT/build/gates/n1d-c3-product-parse-contract.sh"
    "$ROOT/build/gates/n1d-c3-trebledroid-build-contract.sh"
    "$ROOT/build/gates/n1d-restless-security-boundary-contract.sh"
    "$ROOT/build/gates/n1d-source-lock-contract.sh"
    "$PIPELINE"
)

for file in "${syntax_files[@]}"; do
    [[ -f "$file" ]] || fail "missing_file=$file"
    bash -n "$file" || fail "bash_n=$file"
done

for file in "${syntax_files[@]}"; do
    if grep -Eq 'bash[[:space:]]+-n[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"' "$file"; then
        fail "multi_file_bash_n=$file"
    fi
done

repo_sync_count="$(grep -Ec '^[[:space:]]*"?\$SABLE_REPO_TOOL"?[[:space:]]+sync|^[[:space:]]*repo[[:space:]]+sync' "$PREP" || true)"
repo_forall_count="$(grep -c 'forall -c' "$PREP" || true)"
systemimage_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$BUILD" || true)"
treble_app_count="$(grep -Ec '^[[:space:]]*bash[[:space:]]+build\.sh[[:space:]]+release[[:space:]]*$' "$BUILD" || true)"
prep_action_dispatch_count="$(grep -c '^case "\$ACTION" in$' "$PREP" || true)"
prep_host_layout_verify_count="$(grep -c '^verify_host_layout_fix() {$' "$PREP" || true)"
prep_latest_stage_count="$(grep -c '^latest_stage_evidence() {$' "$PREP" || true)"
prep_preflight_count="$(grep -c '^preflight() {$' "$PREP" || true)"
prep_stage_count="$(grep -c '^stage() {$' "$PREP" || true)"
prep_verify_count="$(grep -c '^verify() {$' "$PREP" || true)"
prep_last_nonempty="$(awk 'NF {line=$0} END {print line}' "$PREP")"

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"
[[ "$prep_action_dispatch_count" == 1 ]] || fail "prep_action_dispatch_count=$prep_action_dispatch_count"
[[ "$prep_host_layout_verify_count" == 1 ]] || fail "prep_host_layout_verify_count=$prep_host_layout_verify_count"
[[ "$prep_latest_stage_count" == 1 ]] || fail "prep_latest_stage_count=$prep_latest_stage_count"
[[ "$prep_preflight_count" == 1 ]] || fail "prep_preflight_count=$prep_preflight_count"
[[ "$prep_stage_count" == 1 ]] || fail "prep_stage_count=$prep_stage_count"
[[ "$prep_verify_count" == 1 ]] || fail "prep_verify_count=$prep_verify_count"
[[ "$prep_last_nonempty" == esac ]] || fail "prep_terminal_dispatch_not_eof last=$prep_last_nonempty"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_PREP_STRUCTURE=PASS dispatcher=1 host_layout_verify=1 latest_stage=1 preflight=1 stage=1 verify=1 terminal_esac=YES"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
 "$BUILD" || true)"
prep_action_dispatch_count="$(grep -c '^case "\$ACTION" in

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
 "$PREP" || true)"
prep_host_layout_verify_count="$(grep -c '^verify_host_layout_fix() {

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
 "$PREP" || true)"
prep_latest_stage_count="$(grep -c '^latest_stage_evidence() {

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
 "$PREP" || true)"
prep_preflight_count="$(grep -c '^preflight() {

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
 "$PREP" || true)"
prep_stage_count="$(grep -c '^stage() {

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
 "$PREP" || true)"
prep_verify_count="$(grep -c '^verify() {

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
 "$PREP" || true)"
prep_last_nonempty="$(awk 'NF {line=$0} END {print line}' "$PREP")"

[[ "$repo_sync_count" == 1 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_count=$treble_app_count"

grep -Fq -- '--jobs=4' "$PREP" || fail prep_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE"     || fail standard_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3_PREP_SYNC_PARALLELISM=PASS jobs=4"
echo "N1D_C3_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3_BUILD_TREBLE_APP_COUNT=PASS value=$treble_app_count"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
