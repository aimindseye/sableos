#!/usr/bin/env bash
# Fetch/verify the pinned RestlessOS N1D C2 diagnostic control artifact.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
CONTROL_PROFILE="$ROOT/build/titan2/n1d-c2-prebuilt-control.env"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

fail() { echo "N1D_C2_PREBUILT_CONTROL=FAIL $*" >&2; exit 1; }

for f in "$STORAGE_PROFILE" "$HOST_PROFILE" "$CONTROL_PROFILE" "$STORAGE_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$CONTROL_PROFILE"

ACTION="${1:-preflight}"
if (($#)); then shift; fi
NETWORK_AUTHORIZED=NO
while (($#)); do
    case "$1" in
        --authorize-network) NETWORK_AUTHORIZED=YES; shift ;;
        *) fail "unknown_arg=$1" ;;
    esac
done

ARTIFACT="$SABLE_BUILD_ROOT/$N1D_C2_CONTROL_ARTIFACT_REL"
ARTIFACT_DIR="$(dirname "$ARTIFACT")"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c2-prebuilt-control"

verify_artifact() {
    [[ -f "$ARTIFACT" ]] || fail "artifact_missing=$ARTIFACT"
    local size digest
    size="$(stat -c "%s" "$ARTIFACT")"
    [[ "$size" == "$N1D_C2_CONTROL_ASSET_SIZE" ]] || fail "size expected=$N1D_C2_CONTROL_ASSET_SIZE actual=$size"
    digest="$(sha256sum "$ARTIFACT" | awk '{print $1}')"
    [[ "$digest" == "$N1D_C2_CONTROL_ASSET_SHA256" ]] || fail "sha256 expected=$N1D_C2_CONTROL_ASSET_SHA256 actual=$digest"
    echo "N1D_C2_CONTROL_ASSET_SIZE=PASS value=$size"
    echo "N1D_C2_CONTROL_ASSET_SHA256=PASS value=$digest"
    echo "N1D_C2_CONTROL_ARTIFACT=PASS path=$ARTIFACT"
}

preflight() {
    echo "===== TITAN 2 N1D C2 PREBUILT CONTROL PREFLIGHT ====="
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    bash "$STORAGE_VERIFY" runtime
    command -v curl >/dev/null 2>&1 || fail curl_missing
    [[ "$N1D_C2_CONTROL_MODE" == PINNED_PREBUILT_RESTLESS_GSI ]] || fail control_mode
    [[ "$N1D_C2_EXACT_SOURCE_RECONSTRUCTION" == BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE ]] || fail source_reconstruction_status
    [[ "$N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED" == NO ]] || fail source_retry_policy
    echo "N1D_C2_PREBUILT_CONTROL_PREFLIGHT=PASS"
}

download() {
    echo "===== TITAN 2 N1D C2 PREBUILT CONTROL DOWNLOAD ====="
    [[ "$NETWORK_AUTHORIZED" == YES ]] || fail network_action_requires_--authorize-network
    echo "NETWORK_FETCH_AUTHORIZED=YES_EXPLICIT"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    bash "$STORAGE_VERIFY" runtime
    command -v curl >/dev/null 2>&1 || fail curl_missing
    mkdir -p "$ARTIFACT_DIR"
    curl --fail --location --retry 5 --retry-delay 2 --continue-at - \
        --output "$ARTIFACT" \
        "$N1D_C2_CONTROL_ASSET_URL"
    verify_artifact
    local stamp out
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-control-artifact"
    mkdir -p "$out"
    {
        echo "N1D_C2_CONTROL_MODE=$N1D_C2_CONTROL_MODE"
        echo "N1D_C2_RESTLESS_TAG=$N1D_C2_RESTLESS_TAG"
        echo "N1D_C2_RESTLESS_COMMIT=$N1D_C2_RESTLESS_COMMIT"
        echo "N1D_C2_GRAPHENE_BASE_TAG=$N1D_C2_GRAPHENE_BASE_TAG"
        echo "N1D_C2_CONTROL_ASSET_NAME=$N1D_C2_CONTROL_ASSET_NAME"
        echo "N1D_C2_CONTROL_ASSET_SIZE=$N1D_C2_CONTROL_ASSET_SIZE"
        echo "N1D_C2_CONTROL_ASSET_SHA256=$N1D_C2_CONTROL_ASSET_SHA256"
        echo "N1D_C2_CONTROL_ARTIFACT=$ARTIFACT"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/control.env"
    sha256sum "$out/control.env" > "$out/SHA256SUMS.txt"
    sha256sum -c "$out/SHA256SUMS.txt" >/dev/null
    echo "N1D_C2_PREBUILT_CONTROL_EVIDENCE=$out"
    echo "N1D_C2_PREBUILT_CONTROL_DOWNLOAD=PASS"
}

case "$ACTION" in
    preflight) preflight ;;
    verify) verify_artifact ;;
    download) download ;;
    *) fail "unknown_action=$ACTION" ;;
esac

