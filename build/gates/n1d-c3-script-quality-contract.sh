#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREP="$ROOT/build/titan2/prepare-n1d-c3b-engineering.sh"
PARSE="$ROOT/build/titan2/qualify-n1d-c3b-product-parse.sh"
BUILD="$ROOT/build/titan2/build-n1d-c3b-systemimage.sh"
LPTOOLS_QUALIFIER="$ROOT/build/titan2/qualify-n1d-c3b-lptools.sh"
HARDENER="$ROOT/build/titan2/apply-n1d-c3b-phh-base-hardening.py"
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
    "$ROOT/build/titan2/n1d-c3a-control-evidence.env"
    "$ROOT/build/titan2/n1d-c3b-transition.env"
    "$PREP"
    "$PARSE"
    "$BUILD"
    "$LPTOOLS_QUALIFIER"
    "$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"
    "$ROOT/build/titan2/qualify-n1d-c3-product-parse.sh"
    "$ROOT/build/titan2/build-n1d-c3-trebledroid-systemimage.sh"
    "$ROOT/build/titan2/stage-n1d-c3-product.sh"
    "$ROOT/build/titan2/tests/test-n1d-c0-offline.sh"
    "$ROOT/build/gates/n1d-c3-phase-split-contract.sh"
    "$ROOT/build/gates/n1d-c3a-control-evidence-contract.sh"
    "$ROOT/build/gates/n1d-c3b-transition-contract.sh"
    "$ROOT/build/gates/n1d-c3b-engineering-contract.sh"
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

PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache" \
    python3 -m py_compile "$HARDENER" || fail "python_syntax=$HARDENER"

for file in "${syntax_files[@]}"; do
    if grep -Eq 'bash[[:space:]]+-n[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"' "$file"; then
        fail "multi_file_bash_n=$file"
    fi
done

repo_sync_count="$(grep -c '"$SABLE_REPO_TOOL" sync' "$PREP" || true)"
repo_forall_count="$(grep -c 'forall -c' "$PREP" || true)"
systemimage_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$BUILD" || true)"
lptools_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+lptools[[:space:]]' "$LPTOOLS_QUALIFIER" || true)"
prep_action_dispatch_count="$(grep -c '^case "$ACTION" in$' "$PREP" || true)"
prep_preflight_count="$(grep -c '^preflight() {$' "$PREP" || true)"
prep_init_count="$(grep -c '^init_base() {$' "$PREP" || true)"
prep_sync_count="$(grep -c '^sync_base() {$' "$PREP" || true)"
prep_stage_count="$(grep -c '^stage() {$' "$PREP" || true)"
prep_verify_count="$(grep -c '^verify() {$' "$PREP" || true)"
prep_last_nonempty="$(awk 'NF {line=$0} END {print line}' "$PREP")"
hardening_transform_count="$(grep -c '^        "drop_' "$HARDENER" || true)"

[[ "$repo_sync_count" == 2 ]] || fail "prep_repo_sync_count=$repo_sync_count"
[[ "$repo_forall_count" == 1 ]] || fail "prep_repo_forall_definition_count=$repo_forall_count"
grep -Fq 'capture_project_state()' "$PREP" ||
    fail prep_combined_project_state_capture_missing
[[ "$systemimage_count" == 1 ]] || fail "build_systemimage_count=$systemimage_count"
[[ "$lptools_count" == 1 ]] || fail "lptools_module_build_count=$lptools_count"
[[ "$prep_action_dispatch_count" == 1 ]] || fail "prep_action_dispatch_count=$prep_action_dispatch_count"
[[ "$prep_preflight_count" == 1 ]] || fail "prep_preflight_count=$prep_preflight_count"
[[ "$prep_init_count" == 1 ]] || fail "prep_init_count=$prep_init_count"
[[ "$prep_sync_count" == 1 ]] || fail "prep_sync_function_count=$prep_sync_count"
[[ "$prep_stage_count" == 1 ]] || fail "prep_stage_count=$prep_stage_count"
[[ "$prep_verify_count" == 1 ]] || fail "prep_verify_count=$prep_verify_count"
[[ "$prep_last_nonempty" == esac ]] || fail "prep_terminal_dispatch_not_eof last=$prep_last_nonempty"
[[ "$hardening_transform_count" == 14 ]] || fail "hardening_transform_count=$hardening_transform_count"

grep -Fq -- '--jobs=8' "$PREP" || fail base_sync_parallelism_missing
grep -Fq -- '--jobs=4' "$PREP" || fail scaffold_sync_parallelism_missing

if grep -Eq '^[[:space:]]*sleep([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD" "$LPTOOLS_QUALIFIER"; then
    fail avoidable_sleep_present
fi

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD" "$LPTOOLS_QUALIFIER"; then
    fail clean_or_clobber_present
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD" "$LPTOOLS_QUALIFIER"; then
    fail device_command_present
fi

if grep -Eq '^[[:space:]]*(m|make|ninja)([[:space:]]|$)' "$PREP" "$PARSE"; then
    fail target_compile_outside_build_driver
fi

if grep -Eq 'bash[[:space:]]+build.sh[[:space:]]+release|TrebleApp.apk' "$BUILD"; then
    fail c3a_treble_app_build_in_active_driver
fi

grep -Fq 'bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"' "$PIPELINE" ||
    fail standard_pipeline_binding_missing
grep -Fq 'bash "$ROOT/build/gates/n1d-c3b-transition-contract.sh"' "$PIPELINE" ||
    fail c3b_transition_pipeline_binding_missing
grep -Fq 'bash "$ROOT/build/gates/n1d-c3b-engineering-contract.sh"' "$PIPELINE" ||
    fail c3b_engineering_pipeline_binding_missing

echo "N1D_C3_SCRIPT_SYNTAX=PASS files=${#syntax_files[@]}"
echo "N1D_C3_PYTHON_SYNTAX=PASS files=1"
echo "N1D_C3_SCRIPT_SYNTAX_SINGLE_FILE_INVOCATION=PASS"
echo "N1D_C3B_PREP_REPO_SYNC_COUNT=PASS value=$repo_sync_count"
echo "N1D_C3B_PREP_REPO_FORALL_HELPERS=PASS value=$repo_forall_count optimized_combined_state_capture=YES"
echo "N1D_C3B_PREP_SYNC_PARALLELISM=PASS base_jobs=8 scaffold_jobs=4"
echo "N1D_C3B_BUILD_SYSTEMIMAGE_COUNT=PASS value=$systemimage_count"
echo "N1D_C3B_LPTOOLS_MODULE_BUILD_COUNT=PASS value=$lptools_count"
echo "N1D_C3B_PHH_HARDENING_TRANSFORM_COUNT=PASS value=$hardening_transform_count"
echo "N1D_C3B_PREP_STRUCTURE=PASS dispatcher=1 preflight=1 init=1 sync=1 stage=1 verify=1 terminal_esac=YES"
echo "N1D_C3_NO_AVOIDABLE_SLEEP=PASS"
echo "N1D_C3_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_COMPILE_SCOPE=PASS_BUILD_DRIVER_ONLY"
echo "N1D_C3_SCRIPT_QUALITY_CONTRACT=PASS"
