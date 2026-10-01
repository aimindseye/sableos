#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/config/storage.env"
VERIFY="$ROOT/build/host/verify-storage-root.sh"
MIGRATE="$ROOT/build/host/migrate-storage-root.sh"
ENTRY="$ROOT/build/sable.sh"
README="$ROOT/build/README.md"

fail() {
    echo "SABLE_STORAGE_ROOT_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$PROFILE" "$VERIFY" "$MIGRATE" "$ENTRY" "$README"; do
    [[ -f "$f" ]] || fail "missing=$f"
done

bash -n "$PROFILE"
bash -n "$VERIFY"
bash -n "$MIGRATE"
bash -n "$ENTRY"

for required in \
    'export SABLE_BUILD_ROOT="${SABLE_BUILD_ROOT:-/srv/sable-build}"' \
    'export SABLE_BUILD_LEGACY_ROOT="${SABLE_BUILD_LEGACY_ROOT:-/srv/data/sable-build}"' \
    'export SABLE_BUILD_FS_LABEL_EXPECTED="${SABLE_BUILD_FS_LABEL_EXPECTED:-sable-build}"' \
    'export SABLE_BUILD_FS_TYPE_EXPECTED="${SABLE_BUILD_FS_TYPE_EXPECTED:-ext4}"' \
    'export SABLE_BUILD_MIN_FREE_GIB="${SABLE_BUILD_MIN_FREE_GIB:-250}"' \
    'export SABLE_WORKSPACES_ROOT="${SABLE_WORKSPACES_ROOT:-$SABLE_BUILD_ROOT/workspaces}"' \
    'export SABLE_EVIDENCE_ROOT="${SABLE_EVIDENCE_ROOT:-$SABLE_BUILD_ROOT/evidence}"' \
    'export SABLE_RELEASE_REGISTRY_ROOT="${SABLE_RELEASE_REGISTRY_ROOT:-$SABLE_BUILD_ROOT/release-registry}"'
do
    grep -Fxq "$required" "$PROFILE" ||
        fail "profile_missing_line=$required"
done

grep -Fq 'build/config/storage.env' "$ENTRY" ||
    fail "entrypoint_storage_profile_not_bound"
grep -Fq 'REGISTRY_ROOT="${SABLE_RELEASE_REGISTRY_ROOT}"' "$ENTRY" ||
    fail "entrypoint_registry_not_profile_owned"
grep -Fq 'EVIDENCE_ROOT="${SABLE_DEVICE_EVIDENCE_ROOT}"' "$ENTRY" ||
    fail "entrypoint_evidence_not_profile_owned"

if grep -Fq '/srv/data/sable-build/release-registry' "$ENTRY" ||
   grep -Fq '/srv/data/sable-build/evidence' "$ENTRY"; then
    fail "entrypoint_legacy_build_root_default_present"
fi

grep -Fq 'mount --bind "$SABLE_BUILD_LEGACY_ROOT" "$SABLE_BUILD_ROOT"' "$MIGRATE" ||
    fail "live_bind_missing"
grep -Fq 'FSTAB_MUTATION_PERFORMED=NO' "$MIGRATE" ||
    fail "fstab_plan_not_nonmutating"
grep -Fq 'active_options="$(findmnt -n -o OPTIONS -M "$SABLE_BUILD_LEGACY_ROOT")"' "$MIGRATE" ||
    fail "fstab_plan_does_not_capture_active_options"
grep -Fq 'PROPOSED_FS_OPTIONS=$fstab_options' "$MIGRATE" ||
    fail "fstab_plan_does_not_report_proposed_options"

if grep -Eq 'sed .*\/etc\/fstab|>>[[:space:]]*\/etc\/fstab|tee .*\/etc\/fstab' "$MIGRATE"; then
    fail "automatic_fstab_mutation_present"
fi

grep -Fq '/srv/sable-build' "$README" ||
    fail "readme_missing_canonical_root"
grep -Fq '/srv/data/sable-build' "$README" ||
    fail "readme_missing_legacy_alias"

echo "SABLE_STORAGE_CANONICAL_ROOT=PASS"
echo "SABLE_STORAGE_LEGACY_ALIAS_POLICY=PASS"
echo "SABLE_STORAGE_ENTRYPOINT_BINDING=PASS"
echo "SABLE_STORAGE_MIGRATION_FAIL_CLOSED=PASS"
echo "SABLE_STORAGE_FSTAB_REVIEW_REQUIRED=PASS"
echo "SABLE_STORAGE_ROOT_CONTRACT=PASS"
