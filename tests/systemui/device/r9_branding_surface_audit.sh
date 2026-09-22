#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-adb}"
SERIAL="${SERIAL:-}"
SCENE="${SCENE:-${1:-}}"
DEVICE_CONTACT_AUTHORIZED="${DEVICE_CONTACT_AUTHORIZED:-NO}"
EVIDENCE_DIR="${EVIDENCE_DIR:-}"

[[ "$DEVICE_CONTACT_AUTHORIZED" == YES_READ_ONLY ]] || {
  echo "R9_BRANDING_SURFACE_AUDIT=FAIL_DEVICE_CONTACT_NOT_AUTHORIZED"
  exit 2
}

[[ -n "$SERIAL" ]] || {
  echo "R9_BRANDING_SURFACE_AUDIT=FAIL_SERIAL_REQUIRED"
  exit 64
}

case "$SCENE" in
  setup|settings-home|appearance|applications|app-security|about|shade|keyguard|phone|contacts|files|clock|photos|vanadium|other)
    ;;
  *)
    echo "usage: SCENE=<setup|settings-home|appearance|applications|app-security|about|shade|keyguard|phone|contacts|files|clock|photos|vanadium|other> SERIAL=<serial> DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY bash tests/systemui/device/r9_branding_surface_audit.sh" >&2
    exit 64
    ;;
esac

case "$SCENE" in
  setup|settings-home|appearance|applications|app-security|about)
    CLASSIFICATION=SABLE_OWNED
    ;;
  shade|keyguard|phone|contacts|files|clock|photos|vanadium)
    CLASSIFICATION=SABLE_PRESENTED_ANDROID
    ;;
  other)
    CLASSIFICATION=INTENTIONALLY_UPSTREAM_REVIEW_REQUIRED
    ;;
esac

if [[ -z "$EVIDENCE_DIR" ]]; then
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_DIR="/srv/data/sable-build/evidence/panther/r9-physical/${STAMP}_branding_${SCENE}"
fi
mkdir -p "$EVIDENCE_DIR"

echo "===== R9 USER-VISIBLE BRANDING SURFACE AUDIT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "WIPE_AUTHORIZED=NO"
echo "INPUT_EVENT_AUTHORIZED=NO"
echo "PACKAGE_INSTALL_REMOVE_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "SCENE=$SCENE"
echo "CLASSIFICATION=$CLASSIFICATION"
echo "SERIAL=${SERIAL:0:4}********${SERIAL: -4}"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"

"$ADB" -s "$SERIAL" get-state > "$EVIDENCE_DIR/adb-state.txt"
[[ "$(tr -d '\r\n' < "$EVIDENCE_DIR/adb-state.txt")" == device ]] || {
  echo "R9_BRANDING_SURFACE_AUDIT=FAIL_DEVICE_NOT_READY"
  exit 3
}

"$ADB" -s "$SERIAL" shell dumpsys window windows   > "$EVIDENCE_DIR/window.txt" 2>&1 || true

set +e
"$ADB" -s "$SERIAL" exec-out uiautomator dump /dev/tty   > "$EVIDENCE_DIR/hierarchy.xml" 2> "$EVIDENCE_DIR/uiautomator.stderr.txt"
UI_RC=$?
set -e

echo "UIAUTOMATOR_RC=$UI_RC"
[[ "$UI_RC" -eq 0 ]] || {
  echo "R9_BRANDING_SURFACE_AUDIT=FAIL_UI_HIERARCHY"
  exit 4
}

"$ADB" -s "$SERIAL" exec-out screencap -p   > "$EVIDENCE_DIR/screenshot.png"

python3 - "$EVIDENCE_DIR/hierarchy.xml" "$CLASSIFICATION" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
classification = sys.argv[2]
text = path.read_text(encoding="utf-8", errors="replace")

graphene = bool(re.search(r"GrapheneOS", text, re.IGNORECASE))
sable = bool(re.search(r"SableOS|Sable Start|Sable ", text, re.IGNORECASE))

print(f"R9_VISIBLE_GRAPHENEOS_PRODUCT_COPY={'OBSERVED' if graphene else 'ABSENT'}")
print(f"R9_VISIBLE_SABLE_PRODUCT_COPY={'OBSERVED' if sable else 'NOT_OBSERVED'}")

if classification == "SABLE_OWNED" and graphene:
    print("R9_SABLE_OWNED_BRANDING_SCENE=FAIL_GRAPHENEOS_PRODUCT_COPY")
    raise SystemExit(10)

if classification == "SABLE_OWNED":
    print("R9_SABLE_OWNED_BRANDING_SCENE=PASS_NO_GRAPHENEOS_PRODUCT_COPY")
elif classification == "SABLE_PRESENTED_ANDROID":
    print("R9_SABLE_PRESENTED_ANDROID_BRANDING_SCENE=PASS_CAPTURED")
else:
    print("R9_INTENTIONALLY_UPSTREAM_BRANDING_SCENE=PASS_CAPTURED_REVIEW_REQUIRED")
PY

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0     | LC_ALL=C sort -z     | xargs -0 sha256sum > SHA256SUMS.txt
)

echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "R9_BRANDING_SURFACE_AUDIT=PASS_CAPTURED"
echo "R9_SABLE_USER_VISIBLE_BRANDING_AUDIT=SCENE_CAPTURED_PENDING_FULL_SET"
