#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADAPTER="$ROOT/build/titan2/stage-c3b-product-review.sh"

fail() {
    echo "N1D_C3B_PRODUCT_REVIEW_STAGING_CONTRACT=FAIL $*" >&2
    exit 1
}

[[ -f "$ADAPTER" ]] || fail "missing_adapter=$ADAPTER"
bash -n "$ADAPTER" || fail "bash_n=$ADAPTER"

grep -Fq -- '--product-source <titan2-temp review worktree>' "$ADAPTER" || fail product_source_interface_missing
grep -Fq -- '--product-head <40-char sha>' "$ADAPTER" || fail product_head_interface_missing
grep -Fq -- '--stage' "$ADAPTER" || fail stage_interface_missing
grep -Fq -- '--authorize-source-mutation' "$ADAPTER" || fail mutation_authority_missing
grep -Fq 'ACTIVE_REPO="/srv/sable-build/sableos/repo"' "$ADAPTER" || fail active_repo_guard_missing
grep -Fq 'active_repo_forbidden=' "$ADAPTER" || fail active_repo_rejection_missing

grep -Fq 'docs/C3B_PRODUCT_HANDOFF.env' "$ADAPTER" || fail handoff_binding_missing
grep -Fq 'docs/C3B_PRODUCT_PATH_OWNERSHIP.tsv' "$ADAPTER" || fail ownership_binding_missing
grep -Fq 'C3B_PRODUCT_SOURCE_REPO=aimindseye/titan2-temp' "$ADAPTER" || fail source_repo_binding_missing
grep -Fq 'C3B_RELEASE_TRACK=N1D' "$ADAPTER" || fail release_track_binding_missing
grep -Fq 'C3B_BASELINE_PHASE=C3B' "$ADAPTER" || fail baseline_phase_binding_missing
grep -Fq 'RUNTIME_GIT_HEAD' "$ADAPTER" || fail runtime_head_binding_missing
grep -Fq 'n1d-c3b-e2-product-admission.env' "$ADAPTER" || fail e2_profile_binding_missing
grep -Fq 'N1D_C3B_E2_PRODUCT_QUALIFIED_HEAD' "$ADAPTER" || fail e2_qualified_head_binding_missing
grep -Fq 'N1D_C3B_E2_PRODUCT_QUALIFIED_TREE' "$ADAPTER" || fail e2_qualified_tree_binding_missing
grep -Fq "rev-parse 'HEAD^{tree}'" "$ADAPTER" || fail runtime_tree_identity_missing
grep -Fq 'C3B_PRODUCT_STAGE_TREE=PASS' "$ADAPTER" || fail tree_pass_marker_missing
grep -Fq 'undeclared_tracked_files' "$ADAPTER" || fail undeclared_file_rejection_missing
grep -Fq 'differing_existing_path=' "$ADAPTER" || fail collision_rejection_missing
grep -Fq 'HANDOFF_AS_SOURCE_MODULE' "$ADAPTER" || fail stage_action_source_missing
grep -Fq 'HANDOFF_AS_GATE' "$ADAPTER" || fail stage_action_gate_missing
grep -Fq 'HANDOFF_AS_PROVENANCE' "$ADAPTER" || fail stage_action_provenance_missing
grep -Fq 'DO_NOT_STAGE' "$ADAPTER" || fail do_not_stage_policy_missing
grep -Fq 'KEEP_AS_PROTOTYPE' "$ADAPTER" || fail prototype_exclusion_missing
grep -Fq 'KEEP_REFERENCE_ONLY' "$ADAPTER" || fail reference_exclusion_missing

grep -Fq 'git", "-C", str(source), "ls-files", "-s", "-z"' "$ADAPTER" || fail tracked_file_inventory_missing
grep -Fq 'git -C "$ROOT" diff --cached --check' "$ADAPTER" || fail diff_check_missing
grep -Fq 'xargs -0 -r git -C "$ROOT" add -f -- < "$COPIED_NUL"' "$ADAPTER" || fail approved_ignored_file_stage_missing
grep -Fq 'if staged != copied:' "$ADAPTER" || fail staged_equals_copied_guard_missing
grep -Fq 'C3B_PRODUCT_STAGE_INDEX=FAIL staged=' "$ADAPTER" || fail staged_equals_copied_failure_marker_missing
grep -Fq 'staged-file-inventory.tsv' "$ADAPTER" || fail deterministic_inventory_missing
grep -Fq 'C3B_PRODUCT_HEAD=$PRODUCT_HEAD' "$ADAPTER" || fail evidence_head_missing
grep -Fq 'C3B_CANONICAL_BASE_HEAD=$BASE_HEAD' "$ADAPTER" || fail evidence_base_missing
grep -Fq 'C3B_PRODUCT_STAGING=PASS' "$ADAPTER" || fail pass_marker_missing

if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(clone|fetch|pull)([[:space:]]|$)' "$ADAPTER"; then
    fail network_command_present
fi
if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$ADAPTER"; then
    fail device_command_present
fi
if grep -Eq '^[[:space:]]*(sudo|apt|apt-get|dnf|yum|pacman|brew)([[:space:]]|$)' "$ADAPTER"; then
    fail host_package_command_present
fi
if grep -Eq 'git[[:space:]]+-C[[:space:]]+"?\$ROOT"?[[:space:]]+(commit|push|merge|rebase)([[:space:]]|$)' "$ADAPTER"; then
    fail repository_history_mutation_present
fi
if grep -Eq '(signing|keystore|private[_-]?key)' "$ADAPTER"; then
    fail signing_surface_present
fi

echo "N1D_C3B_PRODUCT_REVIEW_STAGING_SYNTAX=PASS"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_AUTHORITY=PASS_EXPLICIT"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_SOURCE_BINDING=PASS_EXACT_HEAD"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_TREE_BINDING=PASS_EXACT_QUALIFIED_TREE"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_OWNERSHIP=PASS_FAIL_CLOSED"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_COLLISION_POLICY=PASS_REJECT_DIFFERING"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_IGNORED_INPUT_POLICY=PASS_FORCE_ADD_APPROVED_COPIED_PATHS_ONLY"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_PROTOTYPE_POLICY=PASS_EXCLUDED"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_NETWORK=PASS_FORBIDDEN"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_DEVICE_CONTACT=PASS_FORBIDDEN"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_REPOSITORY_HISTORY=PASS_UNCHANGED"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_EVIDENCE=PASS_DETERMINISTIC_INVENTORY"
echo "N1D_C3B_PRODUCT_REVIEW_STAGING_CONTRACT=PASS"
