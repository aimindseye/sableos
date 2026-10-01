#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
DRIVER="$ROOT/build/titan2/prepare-n1d-fresh-source.sh"
DERIVE="$ROOT/build/titan2/derive-n1d-c2-public-manifest.py"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
STORAGE="$ROOT/build/config/storage.env"

fail() {
    echo "N1D_FRESH_SOURCE_CONTRACT=FAIL $*" >&2
    exit 1
}

for file in "$PROFILE" "$DRIVER" "$DERIVE" "$SOURCE_LOCK" "$STORAGE"; do
    [[ -f "$file" ]] || fail "missing_file=$file"
done

bash -n "$PROFILE"
bash -n "$DRIVER"
python3 -m py_compile "$DERIVE"

for required in \
    'N1D_FRESH_SOURCE_VERSION=1' \
    'N1D_ANDROID_ROOT_REL=workspaces/titan2-n1d/android' \
    'N1D_OUT_C2_REL=workspaces/titan2-n1d/out-c2' \
    'N1D_OUT_C3_REL=workspaces/titan2-n1d/out-c3' \
    'N1D_GRAPHENE_MANIFEST_REF=refs/tags/2026061600' \
    'N1D_GRAPHENE_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb' \
    'N1D_AOSP_REVISION=android-16.0.0_r4' \
    'N1D_RELEASE_CONFIG=bp4a' \
    'N1D_C2_PIN_PACKAGE_LABEL=n0b-restless-r6' \
    'N1D_C2_PIN_SEAL_SHA256=6973822165e95de5874870fb2b19ea4e812842abf6e8044130970fd1b5467c5c' \
    'N1D_C2_PUBLIC_PROJECT_COUNT=13' \
    'N1D_C2_PRIVATE_VENDOR_ALLOWED=NO' \
    'N1D_C2_MUTABLE_REVISION_ALLOWED=NO' \
    'N1D_C2_UPSTREAM_SYNC_SCRIPT_ALLOWED=NO' \
    'N1D_PREEXISTING_ANDROID_OUT_ALLOWED=NO' \
    'N1D_FRESH_SOURCE_CONTRACT=PASS'
do
    grep -Fxq "$required" "$PROFILE" ||
        fail "profile_missing=$required"
done

grep -Fq 'source "$STORAGE_PROFILE"' "$DRIVER" ||
    fail "storage_profile_not_sourced"
grep -Fq 'source "$HOST_PROFILE"' "$DRIVER" ||
    fail "host_profile_not_sourced"
grep -Fq 'bash "$STORAGE_VERIFY" runtime' "$DRIVER" ||
    fail "runtime_storage_verification_missing"
grep -Fq 'require_network_authorization' "$DRIVER" ||
    fail "network_authorization_guard_missing"
grep -Fq 'network_action_requires_--authorize-network' "$DRIVER" ||
    fail "network_authorization_failure_missing"
grep -Fq '"$SABLE_REPO_TOOL" init' "$DRIVER" ||
    fail "canonical_repo_init_missing"
grep -Fq '"$SABLE_REPO_TOOL" sync' "$DRIVER" ||
    fail "canonical_repo_sync_missing"
grep -Fq '"$SABLE_REPO_TOOL" manifest -r' "$DRIVER" ||
    fail "pinned_manifest_seal_missing"
grep -Fq 'N1D_BASE_DIRTY_PROJECT_COUNT' "$DRIVER" ||
    fail "dirty_project_gate_missing"
grep -Fq 'c2_pin_contains_unresolved_project_head' "$DRIVER" ||
    fail "historical_pin_unresolved_guard_missing"
grep -Fq 'git lfs version' "$DRIVER" ||
    fail "git_lfs_preflight_missing"
grep -Fq 'if [ -n "$status" ]; then' "$DRIVER" ||
    fail "repo_forall_posix_status_probe_missing"

if grep -Fq '/srv/data/sable-build' "$PROFILE" "$DRIVER"; then
    fail "legacy_build_root_hardcoded"
fi

if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+clone' "$DRIVER"; then
    fail "non_repo_network_fetch_present"
fi

if grep -Fq 'scripts/sync-sources.sh' "$DRIVER"; then
    fail "upstream_restless_sync_script_present"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$TMP/input.xml" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

paths = [
    "device/phh/treble",
    "packages/apps/QcRilAm",
    "prebuilts/vndk/v28",
    "prebuilts/vndk/v29",
    "prebuilts/vndk/v30",
    "treble_app",
    "vendor/apn",
    "vendor/hardware_overlay",
    "vendor/interfaces",
    "vendor/lptools",
    "vendor/magisk",
    "vendor/pixel/gsans",
    "vendor/vndk-tests",
]

root = ET.Element("manifest")
ET.SubElement(root, "remote", {
    "name": "public",
    "fetch": "https://github.com/example/",
})
ET.SubElement(root, "remote", {
    "name": "private",
    "fetch": "ssh://git@github.com/cawilliamson/",
})

for index, path in enumerate(paths, start=1):
    ET.SubElement(root, "project", {
        "name": f"project-{index}",
        "path": path,
        "remote": "public",
        "revision": f"{index:040x}",
    })

ET.SubElement(root, "project", {
    "name": "vendor_cawilliamson-priv",
    "path": "vendor/cawilliamson-priv",
    "remote": "private",
    "revision": "f" * 40,
})

ET.indent(root, space="  ")
Path(sys.argv[1]).write_text(
    ET.tostring(root, encoding="unicode", xml_declaration=True) + "\n",
    encoding="utf-8",
)
PY

python3 "$DERIVE" \
    --input "$TMP/input.xml" \
    --output "$TMP/output.xml" \
    > "$TMP/derive.log"

grep -Fq 'N1D_C2_PUBLIC_PROJECT_COUNT=13' "$TMP/derive.log" ||
    fail "fixture_project_count"
grep -Fq 'N1D_C2_PRIVATE_VENDOR=ABSENT' "$TMP/derive.log" ||
    fail "fixture_private_vendor"
grep -Fq 'N1D_C2_MUTABLE_REVISIONS=ABSENT' "$TMP/derive.log" ||
    fail "fixture_mutable_revision"
grep -Fq 'N1D_C2_PUBLIC_MANIFEST=PASS' "$TMP/derive.log" ||
    fail "fixture_pass"

[[ "$(grep -c '<project ' "$TMP/output.xml")" == 13 ]] ||
    fail "fixture_output_project_count"

if grep -Eiq 'cawilliamson|ssh://|git@|revision="(main|master)"|upstream=|dest-branch=' "$TMP/output.xml"; then
    fail "fixture_output_forbidden_token"
fi

cp "$TMP/input.xml" "$TMP/mutable.xml"
python3 - "$TMP/mutable.xml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace('revision="0000000000000000000000000000000000000001"', 'revision="main"', 1)
path.write_text(text, encoding="utf-8")
PY

if python3 "$DERIVE" \
    --input "$TMP/mutable.xml" \
    --output "$TMP/should-not-exist.xml" \
    >"$TMP/mutable.log" 2>&1
then
    fail "mutable_revision_fixture_was_accepted"
fi

echo "N1D_FRESH_SOURCE_SHELL_SYNTAX=PASS"
echo "N1D_FRESH_SOURCE_PYTHON_SYNTAX=PASS"
echo "N1D_FRESH_SOURCE_CANONICAL_STORAGE=PASS"
echo "N1D_FRESH_SOURCE_EXPLICIT_NETWORK_AUTH=PASS"
echo "N1D_FRESH_SOURCE_NO_UPSTREAM_RESTLESS_SYNC=PASS"
echo "N1D_FRESH_SOURCE_C2_PUBLIC_PIN_DERIVATION=PASS"
echo "N1D_FRESH_SOURCE_MUTABLE_PIN_REJECTION=PASS"
echo "N1D_FRESH_SOURCE_CONTRACT=PASS"
