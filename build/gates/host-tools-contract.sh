#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/config/host-tools.env"
LEGACY_R8="$ROOT/build/config/r8-host-tools.env"
VERIFY="$ROOT/build/host/verify-host-tools.sh"
MIGRATE="$ROOT/build/host/migrate-canonical-host-tools.sh"
ENTRY="$ROOT/build/sable.sh"
N1D_C0="$ROOT/build/titan2/qualify-n1d-c0-offline.sh"
N1D_C0_SELF_TEST="$ROOT/build/titan2/tests/test-n1d-c0-offline.sh"
N1I_C1_AUDIT="$ROOT/build/titan2/audit-n1i-c1-sealed-runtime-layout.sh"
N1I_C1_AUDIT_TEST="$ROOT/tests/titan2/n1i-c1/test-sealed-runtime-audit.sh"

for f in "$PROFILE" "$LEGACY_R8" "$VERIFY" "$MIGRATE" "$ENTRY" "$N1D_C0" "$N1D_C0_SELF_TEST" "$N1I_C1_AUDIT" "$N1I_C1_AUDIT_TEST"; do
    [[ -f "$f" ]] || {
        echo "SABLE_HOST_TOOLS_CONTRACT=FAIL_MISSING path=$f"
        exit 1
    }
done

for f in "$PROFILE" "$LEGACY_R8" "$VERIFY" "$MIGRATE" "$ENTRY" "$N1D_C0" "$N1D_C0_SELF_TEST" "$N1I_C1_AUDIT" "$N1I_C1_AUDIT_TEST"; do
    bash -n "$f"
done

for token in     'SABLE_HOST_TOOLS_ROOT'     'SABLE_ANDROID_SDK'     'SABLE_AOSP_HOST_TOOLS_ROOT'     'SABLE_LPDUMP'     'SABLE_LPUNPACK'     'SABLE_LPMAKE'     'SABLE_SIMG2IMG'     'SABLE_AVBTOOL'     'SABLE_CHECKVINTF'     'SABLE_SECILC'     'SABLE_UNPACK_BOOTIMG'     'SABLE_REPO_TOOL'     'SABLE_JDK17'     'SABLE_JDK21'
do
    grep -Fq "$token" "$PROFILE" || {
        echo "SABLE_HOST_TOOLS_CONTRACT=FAIL_MISSING_VARIABLE token=$token"
        exit 1
    }
done

grep -Fq '/srv/data/sable-host-tools' "$PROFILE"
grep -Fq 'source "$HOST_TOOLS_PROFILE"' "$ENTRY"
grep -Fq 'source "$_R8_HOST_TOOLS_CONFIG_DIR/host-tools.env"' "$LEGACY_R8"
grep -Fq 'cp -a --reflink=auto "$src/." "$stage/"' "$MIGRATE"
! grep -Fq 'cp -aL' "$MIGRATE"
grep -Fq '.sable-canonical-jdk.env' "$MIGRATE"
grep -Fq 'QUARANTINED_INCOMPLETE' "$MIGRATE"
grep -Fq 'build/config/host-tools.env' "$N1D_C0"
grep -Fq 'HOST_TOOL_RESOLUTION_MODE CANONICAL_PROFILE_ONLY' "$N1D_C0"
grep -Fq 'HOST_TOOLS_PROFILE="$ROOT/build/config/host-tools.env"' "$N1I_C1_AUDIT"
grep -Fq 'source "$HOST_TOOLS_PROFILE"' "$N1I_C1_AUDIT"
grep -Fq 'SIMG2IMG="$SABLE_SIMG2IMG"' "$N1I_C1_AUDIT"
grep -Fq 'HOST_TOOL_RESOLUTION_MODE="CANONICAL_PROFILE_ONLY"' "$N1I_C1_AUDIT"

for forbidden in     '/android/r8/'     '/android/r9/'     'titan2-n1c'     'panther-r9'     '/n1d/'
do
    if grep -Fq "$forbidden" "$PROFILE"; then
        echo "SABLE_HOST_TOOLS_CONTRACT=FAIL_BUILD_SPECIFIC_PATH token=$forbidden"
        exit 1
    fi
done

# Migration may reference the one legacy R8 SDK source path, but canonical
# profile/verification and operator entry points may not rediscover tools in
# Android build outputs.
for f in "$PROFILE" "$VERIFY" "$ENTRY" "$N1D_C0" "$N1I_C1_AUDIT"; do
    if grep -Eq '/out[^[:space:]]*/host/linux-x86|find .*host/linux-x86' "$f"; then
        echo "SABLE_HOST_TOOLS_CONTRACT=FAIL_OUT_DISCOVERY path=$f"
        exit 1
    fi
done

if grep -Fq 'resolve_otatools_zip' "$N1D_C0" || grep -Fq 'resolve_tool()' "$N1D_C0"; then
    echo "SABLE_HOST_TOOLS_CONTRACT=FAIL_N1D_TOOL_DISCOVERY"
    exit 1
fi

if grep -Fq 'command -v simg2img' "$N1I_C1_AUDIT" ||
   grep -Eq '(^|[[:space:]])simg2img[[:space:]]' "$N1I_C1_AUDIT"; then
    echo "SABLE_HOST_TOOLS_CONTRACT=FAIL_N1I_C1_SIMG2IMG_DISCOVERY"
    exit 1
fi

bash "$N1D_C0_SELF_TEST"
bash "$N1I_C1_AUDIT_TEST"
echo "SABLE_HOST_TOOLS_N1I_C1_AUDIT_SELF_TEST=PASS"
echo "SABLE_HOST_TOOLS_N1D_C0_SELF_TEST=PASS"

echo "SABLE_HOST_TOOLS_GLOBAL_LAYOUT=PASS"
echo "SABLE_HOST_TOOLS_EXPLICIT_VARIABLES=PASS"
echo "SABLE_HOST_TOOLS_NO_BUILD_SPECIFIC_PATHS=PASS"
echo "SABLE_HOST_TOOLS_NO_OUT_DISCOVERY=PASS"
echo "SABLE_HOST_TOOLS_CONTRACT=PASS"
