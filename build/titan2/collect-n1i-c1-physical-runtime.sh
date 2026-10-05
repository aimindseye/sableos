#!/usr/bin/env bash
# Titan 2 N1I-C1 physical runtime evidence collector.
# Read-only after a separately-authorized flash/install.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD_LIB="$ROOT/build/titan2/n1i-c1-readonly-guard.sh"
HOST_LIB="$ROOT/build/titan2/n1i-c1-physical-host-binding.sh"
SNAPSHOT_LIB="$ROOT/build/titan2/n1i-c1-physical-snapshot.sh"
CAPTURE_ENGINE="$ROOT/build/titan2/capture-n1b2-cellular-runtime.sh"
LEGACY_GUARD_TEST="$ROOT/tests/titan2/n1i-b/test-guard.sh"
C1_GUARD_TEST="$ROOT/tests/titan2/n1i-c1/test-physical-runtime-guard.sh"
QUALIFIER="$ROOT/build/titan2/qualify-n1i-c1-physical-runtime.py"
IMAGE_SOURCE_COMMIT="a745c7daa08267d851f45785a5bb7ff762ed4604"
EXPECTED_ROLE="N1I_C1_ANDROID16_CELLULAR_ISOLATION"
EXPECTED_PLATFORM="16"

fail() { echo "N1I_C1_PHYSICAL_COLLECTOR=FAIL reason=$1" >&2; exit "${2:-1}"; }
usage() {
  cat <<'USAGE'
Usage:
  bash build/titan2/collect-n1i-c1-physical-runtime.sh \
    --authorize-device-contact YES_READ_ONLY --serial SERIAL \
    --artifact-dir QUALIFIED_C1_ARTIFACT_DIR --system-image-sha256 SHA256 \
    --flash-receipt SEALED_FLASH_RECEIPT_DIR --scenario tray1|tray2|dsds \
    [--duration-min 20] [--interval-sec 10] [--out DIR]

Device must already be fully booted in Android/adbd mode. No reboot, mode
transition, radio/APN/property write, service restart or healing is performed.
USAGE
}

AUTH=""; SERIAL=""; ARTIFACT_DIR=""; SYSTEM_SHA=""; FLASH_RECEIPT_DIR=""; SCENARIO=""
DURATION_MIN=20; INTERVAL_SEC=10; OUT=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --authorize-device-contact) [[ "$#" -ge 2 ]] || fail missing_authorization_value 64; AUTH="$2"; shift 2 ;;
    --serial) [[ "$#" -ge 2 ]] || fail missing_serial_value 64; SERIAL="$2"; shift 2 ;;
    --artifact-dir) [[ "$#" -ge 2 ]] || fail missing_artifact_dir_value 64; ARTIFACT_DIR="$2"; shift 2 ;;
    --system-image-sha256) [[ "$#" -ge 2 ]] || fail missing_system_sha_value 64; SYSTEM_SHA="$2"; shift 2 ;;
    --flash-receipt) [[ "$#" -ge 2 ]] || fail missing_flash_receipt_value 64; FLASH_RECEIPT_DIR="$2"; shift 2 ;;
    --scenario) [[ "$#" -ge 2 ]] || fail missing_scenario_value 64; SCENARIO="$2"; shift 2 ;;
    --duration-min) [[ "$#" -ge 2 ]] || fail missing_duration_value 64; DURATION_MIN="$2"; shift 2 ;;
    --interval-sec) [[ "$#" -ge 2 ]] || fail missing_interval_value 64; INTERVAL_SEC="$2"; shift 2 ;;
    --out) [[ "$#" -ge 2 ]] || fail missing_out_value 64; OUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "unknown_argument=$1" 64 ;;
  esac
done

# Fail closed before adb lookup/contact.
[[ "$AUTH" == YES_READ_ONLY ]] || fail device_contact_authorization_required 64
[[ "$SERIAL" =~ ^[A-Za-z0-9._:-]{1,128}$ ]] || fail invalid_serial 64
[[ "$SYSTEM_SHA" =~ ^[0-9a-f]{64}$ ]] || fail invalid_system_sha256 64
case "$SCENARIO" in tray1|tray2|dsds) ;; *) fail invalid_scenario 64 ;; esac
[[ "$DURATION_MIN" =~ ^[1-9][0-9]*$ ]] || fail invalid_duration_min 64
[[ "$INTERVAL_SEC" =~ ^[0-9]+$ && "$INTERVAL_SEC" -ge 2 ]] || fail invalid_interval_sec 64
[[ -d "$ARTIFACT_DIR" ]] || fail artifact_dir_missing 64
[[ -d "$FLASH_RECEIPT_DIR" ]] || fail flash_receipt_dir_missing 64
command -v python3 >/dev/null 2>&1 || fail python3_missing 69

for required in "$GUARD_LIB" "$HOST_LIB" "$SNAPSHOT_LIB" "$CAPTURE_ENGINE" "$C1_GUARD_TEST" "$QUALIFIER" "$LEGACY_GUARD_TEST"; do
  [[ -f "$required" ]] || fail "required_tool_missing=$required" 69
done
# shellcheck source=/dev/null
source "$HOST_LIB"
BIND_REASON="$(n1i_c1_verify_host_binding "$ARTIFACT_DIR" "$FLASH_RECEIPT_DIR" "$SERIAL" "$SYSTEM_SHA" "$IMAGE_SOURCE_COMMIT" "$EXPECTED_ROLE" "$EXPECTED_PLATFORM")"
BIND_RC=$?
[[ "$BIND_RC" -eq 0 ]] || fail "host_binding=$BIND_REASON"

# Built-in regressions before device contact.
for syntax_file in "$0" "$GUARD_LIB" "$HOST_LIB" "$SNAPSHOT_LIB" "$CAPTURE_ENGINE"; do
  bash -n "$syntax_file" || fail "shell_syntax_selftest=$syntax_file"
done
bash "$C1_GUARD_TEST" --guard-only >/dev/null 2>&1 || fail c1_guard_selftest
python3 "$QUALIFIER" --self-test >/dev/null 2>&1 || fail qualifier_selftest
N1I_B_BASE_COMMIT="8adfac494380d36dcf1951bcef4adb9dca106b5e" \
  bash "$LEGACY_GUARD_TEST" >/dev/null 2>&1 || fail be2_legacy_guard_selftest

ADB="${SABLE_ADB:-adb}"
command -v "$ADB" >/dev/null 2>&1 || fail adb_missing 69
# shellcheck source=/dev/null
source "$GUARD_LIB"
# shellcheck source=/dev/null
source "$SNAPSHOT_LIB"
STATE="$($ADB -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')"
[[ "$STATE" == device ]] || fail "device_mode=FAIL_NOT_ANDROID_ADB state=${STATE:-absent}" 3
n1i_c1_verify_runtime_identity

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${OUT:-./out/n1i-c1-physical-${SCENARIO}-${STAMP}}"
mkdir -p "$OUT/raw/start" "$OUT/raw/end" "$OUT/private" || fail output_dir_create
OUT="$(cd "$OUT" && pwd)"
chmod 700 "$OUT" "$OUT/raw" "$OUT/raw/start" "$OUT/raw/end" "$OUT/private" 2>/dev/null || true
TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
SERIAL_SHA="$(printf '%s' "$SERIAL" | sha256sum | awk '{print $1}')"
CAPTURE_SHA="$(sha256sum "$CAPTURE_ENGINE" | awk '{print $1}')"

cat > "$OUT/private/device-binding.env" <<EOF_PRIVATE
DEVICE_SERIAL=$SERIAL
DEVICE_SERIAL_SHA256=$SERIAL_SHA
FLASH_RECEIPT_DIR=$FLASH_RECEIPT_DIR
ARTIFACT_DIR=$ARTIFACT_DIR
EOF_PRIVATE
cat > "$OUT/N1I_C1_BINDING.env" <<EOF_BINDING
SCENARIO=$SCENARIO
N1I_C1_TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
N1I_C1_IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT
N1I_C1_SYSTEM_IMAGE_SHA256=$SYSTEM_SHA
N1I_C1_DEVICE_SERIAL_SHA256=$SERIAL_SHA
N1I_C1_CAPTURE_ENGINE_SHA256=$CAPTURE_SHA
N1I_C1_DEVICE_SERIAL_BINDING=PASS
N1I_C1_SYSTEM_IMAGE_SHA_BINDING=PASS
N1I_C1_RUNTIME_DEVICE_IDENTITY=PASS
EOF_BINDING
cat > "$OUT/raw/runtime-identity.env" <<EOF_ID
ro.product.device=$DEVICE
ro.product.model=$MODEL
ro.product.manufacturer=$MANUFACTURER
ro.build.version.release=$ANDROID_RELEASE
ro.build.version.sdk=$ANDROID_SDK
ro.vendor.build.fingerprint=$VENDOR_FP
sys.boot_completed=$BOOT_COMPLETED
EOF_ID
cat > "$OUT/COLLECTOR_POLICY.env" <<'EOF_POLICY'
N1I_C1_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY
N1I_C1_DEVICE_MUTATION_AUTHORIZED=NO
N1I_C1_FLASH_AUTHORIZED=NO
N1I_C1_REBOOT_AUTHORIZED=NO
N1I_C1_RADIO_RESTART_AUTHORIZED=NO
N1I_C1_AIRPLANE_MODE_MUTATION_AUTHORIZED=NO
N1I_C1_APN_MUTATION_AUTHORIZED=NO
N1I_C1_SIM_SWITCH_PROPERTY_MUTATION_AUTHORIZED=NO
N1I_C1_HEALING_AUTHORIZED=NO
EOF_POLICY

echo "===== N1I-C1 PHYSICAL RUNTIME COLLECTOR ====="
echo "SCENARIO=$SCENARIO"
echo "N1I_C1_IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT"
echo "N1I_C1_SYSTEM_IMAGE_SHA256=$SYSTEM_SHA"
echo "N1I_C1_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "N1I_C1_DEVICE_MUTATION_AUTHORIZED=NO"
echo "N1I_C1_FLASH_AUTHORIZED=NO"
echo "N1I_C1_REBOOT_AUTHORIZED=NO"
echo "N1I_C1_HEALING_AUTHORIZED=NO"

echo "===== C1 START SNAPSHOT ====="
n1i_c1_snapshot "$OUT/raw/start"
echo "===== BE2/N1B READ-ONLY WINDOW ====="
mkdir -p "$OUT/be2"
PATH_DIR="$(dirname "$(command -v "$ADB")")"
PATH="$PATH_DIR:$PATH" bash "$CAPTURE_ENGINE" \
  --serial "$SERIAL" --label "n1i-c1-$SCENARIO" \
  --duration-min "$DURATION_MIN" --interval-sec "$INTERVAL_SEC" --out "$OUT/be2"
CAPTURE_RC=$?
[[ "$CAPTURE_RC" -eq 0 ]] || fail "be2_capture_rc=$CAPTURE_RC" 7
BE2_SUMMARY="$OUT/be2/CELLULAR_RUNTIME_SUMMARY.env"
[[ -f "$BE2_SUMMARY" ]] || fail be2_summary_missing 7
grep -Fxq 'READ_ONLY=YES' "$BE2_SUMMARY" || fail be2_readonly_marker_missing 7
grep -Fxq 'DEVICE_SETTINGS_CHANGED_BY_SCRIPT=NO' "$BE2_SUMMARY" || fail be2_settings_marker_missing 7

echo "===== C1 END SNAPSHOT ====="
n1i_c1_snapshot "$OUT/raw/end"
cat > "$OUT/N1I_C1_COLLECTOR_SUMMARY.env" <<EOF_SUMMARY
N1I_C1_PHYSICAL_COLLECTOR=PASS
SCENARIO=$SCENARIO
N1I_C1_TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
N1I_C1_IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT
N1I_C1_SYSTEM_IMAGE_SHA256=$SYSTEM_SHA
N1I_C1_DEVICE_SERIAL_SHA256=$SERIAL_SHA
N1I_C1_DEVICE_SERIAL_BINDING=PASS
N1I_C1_SYSTEM_IMAGE_SHA_BINDING=PASS
N1I_C1_RUNTIME_DEVICE_IDENTITY=PASS
N1I_C1_READ_ONLY_CONTRACT=PASS
N1I_C1_DUMPSYS_IMS_STANDALONE_GATE=DISABLED
N1I_C1_PROPERTY_WRITE_COUNT=0
N1I_C1_RADIO_RESTART_COUNT_BY_COLLECTOR=0
N1I_C1_AIRPLANE_TOGGLE_COUNT_BY_COLLECTOR=0
N1I_C1_APN_EDIT_COUNT=0
N1I_C1_HEALING_ACTION_COUNT=0
N1I_C1_RAW_PRIVACY=KEEP_LOCAL_DO_NOT_COMMIT
N1I_C1_QUALIFICATION_READY=YES_OPERATOR_RESULTS_REQUIRED
EOF_SUMMARY
cat > "$OUT/README-PRIVACY.txt" <<'EOF_PRIVACY'
raw/ and private/ are local evidence only. They may contain device/subscriber
identifiers, APN/subscription metadata or location-correlated radio data. Do not
commit or share them. BE2 redaction remains best-effort and requires manual
privacy review before sharing.
EOF_PRIVACY

echo "N1I_C1_PHYSICAL_COLLECTOR=PASS"
echo "N1I_C1_READ_ONLY_CONTRACT=PASS"
echo "N1I_C1_DEVICE_SERIAL_BINDING=PASS"
echo "N1I_C1_SYSTEM_IMAGE_SHA_BINDING=PASS"
echo "N1I_C1_RUNTIME_DEVICE_IDENTITY=PASS"
echo "N1I_C1_PROPERTY_WRITE_COUNT=0"
echo "N1I_C1_RADIO_RESTART_COUNT_BY_COLLECTOR=0"
echo "N1I_C1_AIRPLANE_TOGGLE_COUNT_BY_COLLECTOR=0"
echo "N1I_C1_APN_EDIT_COUNT=0"
echo "N1I_C1_HEALING_ACTION_COUNT=0"
echo "EVIDENCE_DIR=$OUT"
