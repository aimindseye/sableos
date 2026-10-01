#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c2-source-admission.env"
DRIVER="$ROOT/build/titan2/admit-n1d-c2-source.sh"
DERIVE="$ROOT/build/titan2/derive-n1d-c2-public-manifest.py"
HEAD_VERIFY="$ROOT/build/titan2/verify-n1d-c2-heads.py"

fail() {
    echo "N1D_C2_SOURCE_ADMISSION_CONTRACT=FAIL $*" >&2
    exit 1
}

for file in "$PROFILE" "$DRIVER" "$DERIVE" "$HEAD_VERIFY"; do
    [[ -f "$file" ]] || fail "missing_file=$file"
done

bash -n "$PROFILE"
bash -n "$DRIVER"
python3 -m py_compile "$DERIVE" "$HEAD_VERIFY"

for required in \
    'N1D_C2_ADMISSION_VERSION=1' \
    'N1D_C2_BASE_SEAL_SHA256=365780be847eba999a72603c501a0f3afcac30dc61f71ce35165d8271dfbf830' \
    'N1D_C2_BASE_PROJECT_COUNT=1033' \
    'N1D_C2_REMOTE_PREFIX=n1d-c2-' \
    'N1D_C2_PROJECT_COUNT=13' \
    'N1D_C2_EXPECTED_TOTAL_PROJECT_COUNT=1046' \
    'N1D_C2_BUILD_AUTHORIZED=NO' \
    'N1D_C2_DEVICE_CONTACT_AUTHORIZED=NO' \
    'N1D_C2_FLASH_AUTHORIZED=NO' \
    'N1D_C2_PRIVATE_VENDOR_ALLOWED=NO' \
    'N1D_C2_MUTABLE_REVISION_ALLOWED=NO' \
    'N1D_C2_UPSTREAM_LOCATOR_PRESERVE=YES' \
    'N1D_C2_UPSTREAM_LOCATOR_IDENTITY_ROLE=TRANSPORT_ONLY' \
    'N1D_C2_RESUME_FAILED_ADMISSION_ALLOWED=NO' \
    'N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE' \
    'N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED=NO' \
    'N1D_C2_PRODUCT_ROLE=DIAGNOSTIC_CONTROL_ONLY' \
    'N1D_C2_ADMISSION_CONTRACT=PASS'
do
    grep -Fxq "$required" "$PROFILE" || fail "profile_missing=$required"
done

grep -Fq 'network_action_requires_--authorize-network' "$DRIVER" || fail network_guard_missing
grep -Fq 'SOURCE_MUTATION_AUTHORIZED=YES_C2_LOCAL_MANIFEST_AND_13_PROJECT_PATHS_ONLY' "$DRIVER" || fail bounded_mutation_marker_missing
grep -Fq '"$SABLE_REPO_TOOL" sync' "$DRIVER" || fail repo_sync_missing
grep -Fq '"${project_paths[@]}"' "$DRIVER" || fail bounded_project_sync_missing
grep -Fq 'current_base_heads_do_not_match_seal' "$DRIVER" || fail base_head_binding_missing
grep -Fq '"$HEAD_VERIFY"' "$DRIVER" || fail head_verifier_binding_missing
grep -Fq 'N1D_C2_DIRTY_PROJECT_COUNT=0' "$DRIVER" || fail dirty_count_gate_missing
grep -Fq -- '--remote-prefix "$N1D_C2_REMOTE_PREFIX"' "$DRIVER" || fail remote_prefix_binding_missing
grep -Fq -- '--project-tsv "$ledger"' "$DRIVER" || fail project_ledger_binding_missing
grep -Fq 'N1D_C2_BASE_C2_PATH_DISJOINT=PASS' "$DRIVER" || fail base_c2_disjoint_gate_missing
grep -Fq -- '--preserve-upstream' "$DRIVER" || fail upstream_preserve_binding_missing
grep -Fq 'N1D_C2_UPSTREAM_IDENTITY_ROLE=TRANSPORT_ONLY' "$DRIVER" || fail upstream_transport_role_missing
grep -Fq 'verify_base_subset_exact() {' "$DRIVER" || fail resume_base_verifier_missing
grep -Fq 'verify_partial_c2_safe() {' "$DRIVER" || fail resume_partial_c2_verifier_missing
grep -Fq 'resume_preflight() {' "$DRIVER" || fail resume_preflight_action_missing
grep -Fq 'N1D_C2_SOURCE_ADMISSION_RESUME_PREFLIGHT=PASS' "$DRIVER" || fail resume_preflight_pass_marker_missing
grep -Fq 'resume() {' "$DRIVER" || fail resume_action_missing
grep -Fq 'N1D_C2_SOURCE_ADMISSION_RESUME=PASS' "$DRIVER" || fail resume_pass_marker_missing
grep -Fq 'N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE' "$DRIVER" || fail source_reconstruction_block_missing
grep -Fq 'N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED=NO' "$DRIVER" || fail source_retry_block_missing
grep -Fq 'N1D_C2_SOURCE_ADMISSION=FAIL_CLOSED_USE_PINNED_PREBUILT_CONTROL' "$DRIVER" || fail prebuilt_pivot_missing

if grep -Fq '/srv/data/sable-build' "$PROFILE" "$DRIVER"; then
    fail legacy_build_root_hardcoded
fi
if grep -Eq '(^|[[:space:]])(adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail device_command_present
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$TMP/input.xml" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
paths = [
    "device/phh/treble", "packages/apps/QcRilAm", "prebuilts/vndk/v28",
    "prebuilts/vndk/v29", "prebuilts/vndk/v30", "treble_app", "vendor/apn",
    "vendor/hardware_overlay", "vendor/interfaces", "vendor/lptools",
    "vendor/magisk", "vendor/pixel/gsans", "vendor/vndk-tests",
]
root = ET.Element("manifest")
ET.SubElement(root, "remote", {"name": "public-a", "fetch": "https://github.com/example-a/"})
ET.SubElement(root, "remote", {"name": "public-b", "fetch": "https://github.com/example-b/"})
ET.SubElement(root, "default", {"remote": "public-a"})
for index, path in enumerate(paths, start=1):
    attrs = {"name": f"project-{index}", "path": path, "revision": f"{index:040x}"}
    if path == "vendor/interfaces":
        attrs["remote"] = "public-b"
    elif path != "prebuilts/vndk/v28":
        attrs["remote"] = "public-a"
    if path == "device/phh/treble":
        attrs["upstream"] = "refs/heads/android-16.0"
    elif path == "prebuilts/vndk/v29":
        attrs["upstream"] = "refs/heads/android16-qpr2-release"
    ET.SubElement(root, "project", attrs)
ET.indent(root, space="  ")
Path(sys.argv[1]).write_text(ET.tostring(root, encoding="unicode", xml_declaration=True) + "\n", encoding="utf-8")
PY

python3 "$DERIVE" \
    --input "$TMP/input.xml" \
    --output "$TMP/output.xml" \
    --remote-prefix n1d-c2- \
    --project-tsv "$TMP/c2.tsv" \
    > "$TMP/derive.log"

grep -Fq 'N1D_C2_PUBLIC_PROJECT_COUNT=13' "$TMP/derive.log" || fail fixture_project_count
[[ "$(grep -c '<project ' "$TMP/output.xml")" == 13 ]] || fail fixture_manifest_project_count
[[ "$(grep -cve '^$' "$TMP/c2.tsv")" == 13 ]] || fail fixture_ledger_count
if grep '<remote ' "$TMP/output.xml" | grep -v 'name="n1d-c2-' >/dev/null; then
    fail fixture_unprefixed_remote
fi
while IFS=$'\t' read -r path revision remote upstream; do
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || fail "fixture_unpinned_revision path=$path"
    [[ "$remote" == n1d-c2-* ]] || fail "fixture_unprefixed_remote path=$path"
    [[ -z "$upstream" ]] || fail "audit_fixture_upstream_leaked path=$path"
done < "$TMP/c2.tsv"
if grep -Fq 'upstream=' "$TMP/output.xml"; then
    fail audit_fixture_upstream_leaked_manifest
fi
grep -Fq 'N1D_C2_UPSTREAM_LOCATOR_COUNT=0' "$TMP/derive.log" ||
    fail audit_fixture_upstream_count

python3 "$DERIVE" \
    --input "$TMP/input.xml" \
    --output "$TMP/output-install.xml" \
    --remote-prefix n1d-c2- \
    --project-tsv "$TMP/c2-install.tsv" \
    --preserve-upstream \
    > "$TMP/derive-install.log"

grep -Fq 'N1D_C2_UPSTREAM_LOCATOR_COUNT=2' "$TMP/derive-install.log" ||
    fail install_fixture_upstream_count
grep -Fq 'N1D_C2_UPSTREAM_IDENTITY_ROLE=TRANSPORT_ONLY' "$TMP/derive-install.log" ||
    fail install_fixture_upstream_role
grep -Fq 'upstream="refs/heads/android-16.0"' "$TMP/output-install.xml" ||
    fail install_fixture_phh_upstream_missing
grep -Fq 'upstream="refs/heads/android16-qpr2-release"' "$TMP/output-install.xml" ||
    fail install_fixture_v29_upstream_missing
awk -F '\t' '$1 == "device/phh/treble" && $4 == "refs/heads/android-16.0" { found=1 } END { exit(found ? 0 : 1) }' "$TMP/c2-install.tsv" ||
    fail install_fixture_phh_ledger_upstream
awk -F '\t' '$1 == "prebuilts/vndk/v29" && $4 == "refs/heads/android16-qpr2-release" { found=1 } END { exit(found ? 0 : 1) }' "$TMP/c2-install.tsv" ||
    fail install_fixture_v29_ledger_upstream

printf 'base/a\t1111111111111111111111111111111111111111\nbase/b\t2222222222222222222222222222222222222222\n' > "$TMP/base.tsv"
printf 'c2/a\t3333333333333333333333333333333333333333\tn1d-c2-public-a\n' > "$TMP/c2-small.tsv"
printf 'base/a\t1111111111111111111111111111111111111111\nbase/b\t2222222222222222222222222222222222222222\nc2/a\t3333333333333333333333333333333333333333\n' > "$TMP/current.tsv"

python3 "$HEAD_VERIFY" \
    --base "$TMP/base.tsv" \
    --current "$TMP/current.tsv" \
    --c2 "$TMP/c2-small.tsv" \
    --expected-base-count 2 \
    --expected-c2-count 1 \
    --expected-total-count 3 \
    > "$TMP/head-pass.log"
grep -Fq 'N1D_C2_HEAD_VERIFY=PASS' "$TMP/head-pass.log" || fail head_fixture_pass_missing

sed 's/3333333333333333333333333333333333333333/4444444444444444444444444444444444444444/' "$TMP/current.tsv" > "$TMP/current-bad.tsv"
if python3 "$HEAD_VERIFY" \
    --base "$TMP/base.tsv" \
    --current "$TMP/current-bad.tsv" \
    --c2 "$TMP/c2-small.tsv" \
    --expected-base-count 2 \
    --expected-c2-count 1 \
    --expected-total-count 3 \
    > "$TMP/head-bad.log" 2>&1
then
    fail head_mismatch_fixture_accepted
fi

echo "N1D_C2_SOURCE_ADMISSION_SHELL_SYNTAX=PASS"
echo "N1D_C2_SOURCE_ADMISSION_PYTHON_SYNTAX=PASS"
echo "N1D_C2_SOURCE_ADMISSION_EXPLICIT_NETWORK_AUTH=PASS"
echo "N1D_C2_SOURCE_ADMISSION_BOUNDED_SYNC=PASS"
echo "N1D_C2_SOURCE_ADMISSION_COLLISION_SAFE_REMOTES=PASS"
echo "N1D_C2_SOURCE_ADMISSION_AUDIT_UPSTREAM_STRIPPING=PASS"
echo "N1D_C2_SOURCE_ADMISSION_INSTALL_UPSTREAM_PRESERVE=PASS"
echo "N1D_C2_SOURCE_ADMISSION_RESUME_POLICY=PASS"
echo "N1D_C2_SOURCE_ADMISSION_RESUME_PREFLIGHT_CONTRACT=PASS"
echo "N1D_C2_SOURCE_ADMISSION_EXACT_HEAD_VERIFY=PASS"
echo "N1D_C2_SOURCE_ADMISSION_MISMATCH_REJECTION=PASS"
echo "N1D_C2_SOURCE_ADMISSION_RETRY_POLICY=PASS_BLOCKED"
echo "N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE"
echo "N1D_C2_SOURCE_ADMISSION_CONTRACT=PASS"
