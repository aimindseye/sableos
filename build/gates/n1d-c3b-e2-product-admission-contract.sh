#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-admission.env"
ADAPTER="$ROOT/build/titan2/stage-c3b-product-review.sh"
STAGING_GATE="$ROOT/build/gates/n1d-c3b-product-review-staging-contract.sh"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"

fail() {
    echo "N1D_C3B_E2_PRODUCT_ADMISSION_CONTRACT=FAIL $*" >&2
    exit 1
}

for file in "$PROFILE" "$ADAPTER" "$STAGING_GATE" "$TRANSITION"; do
    [[ -f "$file" ]] || fail "missing_file=$file"
done

bash -n "$PROFILE" || fail "syntax=$PROFILE"
bash -n "$ADAPTER" || fail "syntax=$ADAPTER"
bash "$STAGING_GATE"

# shellcheck source=/dev/null
source "$PROFILE"

[[ "$N1D_C3B_E2_ADMISSION_VERSION" == 1 ]] || fail admission_version
[[ "$N1D_C3B_E2_ADMISSION_DATE" == 2026-10-02 ]] || fail admission_date
[[ "$N1D_C3B_E2_PHASE" == C3B_E2_PRODUCT_SOURCE_ADMISSION ]] || fail phase
[[ "$N1D_C3B_E2_E1_PR" == 234 ]] || fail e1_pr
[[ "$N1D_C3B_E2_E1_MERGE_COMMIT" == 39b0733817fa8482fe168277fb0cd119cdc7ae1a ]] || fail e1_merge
[[ "$N1D_C3B_E2_E1_SYSTEM_SHA256" == 9ce0144220b3a5bf531a1b0da7ec97543a89c9181ab9d69b6390ea5a86ad45dd ]] || fail e1_system_sha
[[ "$N1D_C3B_E2_E1_SYSTEM_BYTES" == 2940891136 ]] || fail e1_system_bytes
[[ "$N1D_C3B_E2_E1_PREREQUISITE" == PASS_SYSTEMIMAGE ]] || fail e1_prerequisite

[[ "$N1D_C3B_E2_PRODUCT_SOURCE_REPO" == aimindseye/titan2-temp ]] || fail product_source_repo
[[ "$N1D_C3B_E2_PRODUCT_SOURCE_PR" == 18 ]] || fail product_source_pr
[[ "$N1D_C3B_E2_PRODUCT_QUALIFIED_HEAD" == 769feb9b9f662deda2a9110e85d95bb6114ceace ]] || fail qualified_head
[[ "$N1D_C3B_E2_PRODUCT_QUALIFIED_TREE" == cf5c232be3bc79eec4bd30ee0a90ab9247852053 ]] || fail qualified_tree
[[ "$N1D_C3B_E2_PRODUCT_MERGED_MAIN" == dbbb96cc01a0e366ea56817b54028b5686cb4035 ]] || fail merged_main
[[ "$N1D_C3B_E2_PRODUCT_MERGED_MAIN_TREE" == "$N1D_C3B_E2_PRODUCT_QUALIFIED_TREE" ]] || fail product_tree_equivalence
[[ "$N1D_C3B_E2_PRODUCT_TREE_EQUIVALENCE" == PASS ]] || fail product_tree_equivalence_status

[[ "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" == aafb543565c9d59ed5e0d9cda876aabb4967f8aa ]] || fail source_import_commit
[[ "$N1D_C3B_E2_SOURCE_IMPORT_PARENT" == 8a7d933d1aabfc16ea207c2094aaf2a59960f7fc ]] || fail source_import_parent_profile
[[ "$N1D_C3B_E2_SOURCE_IMPORT_FILE_COUNT" == 178 ]] || fail source_import_count_profile
[[ "$N1D_C3B_E2_SOURCE_IMPORT_UNSTAGED_FILE_COUNT" == 0 ]] || fail source_import_unstaged_profile
[[ "$N1D_C3B_E2_SOURCE_ADMISSION_STATUS" == PASS_CANONICAL_SOURCE_STAGED ]] || fail source_admission_status
[[ "$N1D_C3B_E2_PRODUCT_IDENTITY_STATUS" == DEFINED_THIN_WRAPPER_PENDING_PARSE ]] || fail product_identity_status

source_import_parent="$(git -C "$ROOT" rev-parse "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT^")"
[[ "$source_import_parent" == "$N1D_C3B_E2_SOURCE_IMPORT_PARENT" ]] ||
    fail "source_import_parent expected=$N1D_C3B_E2_SOURCE_IMPORT_PARENT actual=$source_import_parent"
source_import_count="$(git -C "$ROOT" diff-tree --no-commit-id --name-only -r "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" | grep -cve '^$' || true)"
[[ "$source_import_count" == "$N1D_C3B_E2_SOURCE_IMPORT_FILE_COUNT" ]] ||
    fail "source_import_file_count expected=$N1D_C3B_E2_SOURCE_IMPORT_FILE_COUNT actual=$source_import_count"
git -C "$ROOT" merge-base --is-ancestor "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD ||
    fail "source_import_not_ancestor=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"

[[ "$N1D_C3B_E2_RECONCILED_CANONICAL_COLLISION_COUNT" == 1 ]] || fail collision_count
[[ "$N1D_C3B_E2_PHOSPHOR_PROVENANCE_PATH" == third_party/phosphor-icons/PROVENANCE.md ]] || fail phosphor_path
[[ "$N1D_C3B_E2_PHOSPHOR_PROVENANCE_QUALIFIED_PRODUCT_BLOB" == b0ee56440b8db5c130321ae83e259f097832ad8c ]] || fail phosphor_product_blob
[[ "$N1D_C3B_E2_PHOSPHOR_PROVENANCE_CANONICAL_BLOB" == "$N1D_C3B_E2_PHOSPHOR_PROVENANCE_QUALIFIED_PRODUCT_BLOB" ]] || fail phosphor_blob_equivalence
[[ "$N1D_C3B_E2_PHOSPHOR_PROVENANCE_RECONCILIATION" == PASS_BYTE_IDENTICAL_QUALIFIED_PRODUCT_SOURCE ]] || fail phosphor_reconciliation

PHOSPHOR_PROVENANCE="$ROOT/$N1D_C3B_E2_PHOSPHOR_PROVENANCE_PATH"
[[ -f "$PHOSPHOR_PROVENANCE" ]] || fail "missing_phosphor_provenance=$PHOSPHOR_PROVENANCE"
phosphor_blob="$(git -C "$ROOT" hash-object "$PHOSPHOR_PROVENANCE")"
[[ "$phosphor_blob" == "$N1D_C3B_E2_PHOSPHOR_PROVENANCE_CANONICAL_BLOB" ]] ||
    fail "phosphor_provenance_blob expected=$N1D_C3B_E2_PHOSPHOR_PROVENANCE_CANONICAL_BLOB actual=$phosphor_blob"

[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_COUNT" == 2 ]] || fail ignored_exception_count
[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_1" == third_party/pinyin_zh/inputs/Unihan.zip ]] || fail ignored_exception_1
[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_1_GIT_BLOB" == 03e93bfb1f674a2cdd811e5f88c17c5a5402f3c5 ]] || fail ignored_exception_1_blob
[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_1_SHA256" == 4c93ea9c1f636451729a840978f1667a53886af37ba854fdcce109721c63d43e ]] || fail ignored_exception_1_sha
[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_2" == third_party/pinyin_zh/inputs/cedict_1_0_ts_utf-8_mdbg.zip ]] || fail ignored_exception_2
[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_2_GIT_BLOB" == b5530bc5f1b343a98c7d839cad67284f5881736b ]] || fail ignored_exception_2_blob
[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_2_SHA256" == 5a5ea3da98372bfba8f751b82f4fab62911dfb4c43d65b01ea95146e69b35d87 ]] || fail ignored_exception_2_sha
[[ "$N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_POLICY" == QUALIFIED_TRACKED_PROVENANCE_INPUTS_ONLY ]] || fail ignored_exception_policy

[[ "$N1D_C3B_E2_CRLF_BATCH_FILE_COUNT" == 1 ]] || fail crlf_count
[[ "$N1D_C3B_E2_CRLF_BATCH_FILE_1" == apps/titan2/platform/gradlew.bat ]] || fail crlf_path
[[ "$N1D_C3B_E2_CRLF_BATCH_FILE_1_GIT_BLOB" == 5eed7ee8452842305a18a4eb967442683808226a ]] || fail crlf_blob
[[ "$N1D_C3B_E2_CRLF_BATCH_POLICY" == PRESERVE_QUALIFIED_WINDOWS_WRAPPER_BYTES_ONLY ]] || fail crlf_policy
[[ "$N1D_C3B_E2_BINARY_LINE_ENDING_POLICY" == SKIP_GIT_CLASSIFIED_BINARY_STAGED_PATHS ]] || fail binary_line_ending_policy

[[ "$N1D_C3B_E2_PRODUCT_MODULE_COUNT" == 5 ]] || fail module_count
[[ "$N1D_C3B_E2_PRODUCT_MODULES" == SableTitan2Keyboard,SableTitan2Camera,SableTitan2DisplayCompat,SableTitan2Setup,SableTitan2RadioDiag ]] || fail module_set
[[ "$N1D_C3B_E2_PROTOTYPE_ADMISSION_ALLOWED" == NO ]] || fail prototype_policy
[[ "$N1D_C3B_E2_STANDALONE_HOME_ADMISSION_ALLOWED" == NO ]] || fail home_policy
[[ "$N1D_C3B_E2_REFERENCE_SOURCE_RUNTIME_ADMISSION_ALLOWED" == NO ]] || fail reference_policy
[[ "$N1D_C3B_E2_PRESIGNED_PRODUCT_APK_ADMISSION_ALLOWED" == NO ]] || fail presigned_policy

grep -Fxq 'N1D_C3B_PRODUCT_IDENTITY_STATUS=ENGINEERING_GENERATED_TREBLEDROID_PENDING_E2' "$TRANSITION" ||
    fail e1_transition_identity_handoff_missing
grep -Fxq 'N1D_C3B_SABLE_PRODUCT_ADMISSION_OWNER=E2_CANONICAL_ENGINEERING_LANE' "$TRANSITION" ||
    fail e2_admission_owner_missing

for token in     'n1d-c3b-e2-product-admission.env'     'N1D_C3B_E2_PRODUCT_QUALIFIED_HEAD'     'N1D_C3B_E2_PRODUCT_QUALIFIED_TREE'     'C3B_PRODUCT_STAGE_TREE=PASS'
do
    grep -Fq "$token" "$ADAPTER" || fail "adapter_binding_missing=$token"
done

[[ "$N1D_C3B_E2_TARGET_FILES_AUTHORIZED" == NO ]] || fail target_files_authorized
[[ "$N1D_C3B_E2_OTA_AUTHORIZED" == NO ]] || fail ota_authorized
[[ "$N1D_C3B_E2_DEVICE_CONTACT_AUTHORIZED" == NO ]] || fail device_contact_authorized
[[ "$N1D_C3B_E2_FLASH_AUTHORIZED" == NO ]] || fail flash_authorized
[[ "$N1D_C3B_E2_SIGNING_AUTHORIZED" == NO ]] || fail signing_authorized
[[ "$N1D_C3B_E2_PHYSICAL_RUNTIME_AUTHORIZED" == NO ]] || fail physical_runtime_authorized
[[ "$N1D_C3B_E2_RELEASE_ELIGIBLE" == NO ]] || fail release_eligible

echo "N1D_C3B_E2_E1_PREREQUISITE=PASS_SYSTEMIMAGE"
echo "N1D_C3B_E2_PRODUCT_SOURCE_BINDING=PASS_EXACT_QUALIFIED_HEAD_AND_TREE"
echo "N1D_C3B_E2_CANONICAL_SOURCE_IMPORT=PASS commit=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT files=$N1D_C3B_E2_SOURCE_IMPORT_FILE_COUNT"
echo "N1D_C3B_E2_PRODUCT_TREE_EQUIVALENCE=PASS"
echo "N1D_C3B_E2_CANONICAL_COLLISION_RECONCILIATION=PASS_PHOSPHOR_PROVENANCE_BYTE_IDENTICAL"
echo "N1D_C3B_E2_CANONICAL_IGNORE_EXCEPTION_POLICY=PASS_2_QUALIFIED_PINYIN_PROVENANCE_ARCHIVES"
echo "N1D_C3B_E2_LINE_ENDING_POLICY=PASS_1_QUALIFIED_CRLF_BATCH_WRAPPER"
echo "N1D_C3B_E2_BINARY_LINE_ENDING_POLICY=PASS_GIT_CLASSIFIED_BINARIES_EXCLUDED"
echo "N1D_C3B_E2_PRODUCT_MODULE_SCOPE=PASS_5_SOURCE_CANDIDATES"
echo "N1D_C3B_E2_PROTOTYPE_POLICY=PASS_EXCLUDED"
echo "N1D_C3B_E2_RUNTIME_AUTHORITY=PASS_BLOCKED"
echo "N1D_C3B_E2_RELEASE_AUTHORITY=PASS_BLOCKED"
echo "N1D_C3B_E2_PRODUCT_ADMISSION_CONTRACT=PASS"
