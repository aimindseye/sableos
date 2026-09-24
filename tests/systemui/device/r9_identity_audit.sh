#!/usr/bin/env bash
set -euo pipefail

SERIAL="${SERIAL:-}"
EVIDENCE_DIR="${EVIDENCE_DIR:-}"
ADB="${ADB:-adb}"

[[ -n "$SERIAL" ]] || {
  echo "R9_SYSTEM_IDENTITY_AUDIT=FAIL_SERIAL_REQUIRED"
  exit 64
}
if [[ -z "$EVIDENCE_DIR" ]]; then
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_DIR="/srv/data/sable-build/evidence/panther/r9-physical/${STAMP}_system-identity"
fi
mkdir -p "$EVIDENCE_DIR"

echo "===== R9 SYSTEM IDENTITY READ-ONLY AUDIT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "WIPE_AUTHORIZED=NO"
echo "PACKAGE_INSTALL_REMOVE_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "SERIAL=${SERIAL:0:4}********${SERIAL: -4}"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"

"$ADB" -s "$SERIAL" get-state | tee "$EVIDENCE_DIR/adb-state.txt"
[[ "$("$ADB" -s "$SERIAL" get-state)" == device ]] || {
  echo "R9_SYSTEM_IDENTITY_AUDIT=FAIL_DEVICE_NOT_READY"
  exit 1
}

PRODUCT="$("$ADB" -s "$SERIAL" shell getprop ro.product.device | tr -d '\r')"
MODEL="$("$ADB" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
FINGERPRINT="$("$ADB" -s "$SERIAL" shell getprop ro.build.fingerprint | tr -d '\r')"
[[ "$PRODUCT" == panther ]] || {
  echo "R9_SYSTEM_IDENTITY_AUDIT=FAIL_PRODUCT actual=$PRODUCT"
  exit 2
}

{
  echo "product=$PRODUCT"
  echo "model=$MODEL"
  echo "fingerprint=$FINGERPRINT"
  for prop in \
    ro.product.brand \
    ro.product.system.brand \
    ro.product.product.brand \
    ro.product.vendor.brand \
    ro.build.display.id \
    ro.build.version.incremental
  do
    printf '%s=' "$prop"
    "$ADB" -s "$SERIAL" shell getprop "$prop" | tr -d '\r'
  done
} | tee "$EVIDENCE_DIR/device-identity.txt"

# Resolve exact runtime framework resources that can name system notifications.
# cmd overlay lookup is read-only and exposes whether an overlay rather than
# the base framework supplied the effective value.
set +e
"$ADB" -s "$SERIAL" shell \
  cmd overlay lookup --verbose android android:string/android_system_label \
  > "$EVIDENCE_DIR/android-system-label.lookup.txt" 2>&1
SYSTEM_LABEL_RC=$?

"$ADB" -s "$SERIAL" shell \
  cmd overlay lookup --verbose android android:string/adb_active_notification_title \
  > "$EVIDENCE_DIR/adb-active-title.lookup.txt" 2>&1
ADB_TITLE_RC=$?
set -e

echo "ANDROID_SYSTEM_LABEL_LOOKUP_RC=$SYSTEM_LABEL_RC"
echo "ADB_ACTIVE_TITLE_LOOKUP_RC=$ADB_TITLE_RC"
echo "----- android_system_label -----"
cat "$EVIDENCE_DIR/android-system-label.lookup.txt"
echo "----- adb_active_notification_title -----"
cat "$EVIDENCE_DIR/adb-active-title.lookup.txt"

"$ADB" -s "$SERIAL" shell cmd overlay list android \
  > "$EVIDENCE_DIR/android-overlays.txt" 2>&1 || true

# Capture only the ADB notification neighborhood rather than persisting the
# complete notification dump, which can contain unrelated private content.
TMP_NOTIFICATION="$(mktemp)"
trap 'rm -f "$TMP_NOTIFICATION"' EXIT
"$ADB" -s "$SERIAL" shell dumpsys notification --noredact \
  > "$TMP_NOTIFICATION" 2>&1 || true

if grep -Fqi 'Permission allowlist violation' "$TMP_NOTIFICATION"; then
  grep -Fin -B25 -A60 'Permission allowlist violation' "$TMP_NOTIFICATION" \
    > "$EVIDENCE_DIR/permission-allowlist-violation.txt" 2>&1 || true
  echo "R9_PERMISSION_ALLOWLIST_RUNTIME=FAIL_NOTIFICATION_PRESENT"
  cat "$EVIDENCE_DIR/permission-allowlist-violation.txt"
  exit 12
fi
echo "R9_PERMISSION_ALLOWLIST_RUNTIME=PASS_NO_NOTIFICATION"

python3 - "$TMP_NOTIFICATION" "$EVIDENCE_DIR/adb-notification-snippet.txt" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines()
dest = Path(sys.argv[2])
needles = (
    "USB debugging connected",
    "adb_active_notification",
    "usbdevicemanager.adb",
)
hits = [
    i for i, line in enumerate(source)
    if any(needle.lower() in line.lower() for needle in needles)
]
selected: set[int] = set()
for hit in hits:
    lo = max(0, hit - 35)
    hi = min(len(source), hit + 55)
    selected.update(range(lo, hi))

if not selected:
    dest.write_text(
        "ADB_NOTIFICATION_MATCH=NOT_FOUND\n",
        encoding="utf-8",
    )
else:
    blocks = []
    last = None
    for idx in sorted(selected):
        if last is not None and idx != last + 1:
            blocks.append("-----")
        blocks.append(f"{idx + 1}: {source[idx]}")
        last = idx
    dest.write_text("\n".join(blocks) + "\n", encoding="utf-8")
PY

echo "----- ADB notification snippet -----"
cat "$EVIDENCE_DIR/adb-notification-snippet.txt"

for pkg in android com.android.systemui; do
  safe="${pkg//./_}"
  "$ADB" -s "$SERIAL" shell dumpsys package "$pkg" \
    | grep -E \
      'Package \[|application-label|labelRes=|nonLocalizedLabel=|sharedUserId=|codePath=|versionName=' \
    > "$EVIDENCE_DIR/package-${safe}.txt" 2>&1 || true
done

python3 - "$EVIDENCE_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
label = (root / "android-system-label.lookup.txt").read_text(
    encoding="utf-8", errors="replace"
)
title = (root / "adb-active-title.lookup.txt").read_text(
    encoding="utf-8", errors="replace"
)
snippet = (root / "adb-notification-snippet.txt").read_text(
    encoding="utf-8", errors="replace"
)

print("R9_ADB_NOTIFICATION_TITLE_RUNTIME=" + (
    "PASS" if "USB debugging connected" in title or "USB debugging connected" in snippet
    else "UNRESOLVED"
))

if re.search(r"GrapheneOS", label, re.IGNORECASE):
    print("R9_RUNTIME_ANDROID_SYSTEM_LABEL=GRAPHENEOS")
elif re.search(r"SableOS", label, re.IGNORECASE):
    print("R9_RUNTIME_ANDROID_SYSTEM_LABEL=SABLEOS")
elif re.search(r"Android System", label, re.IGNORECASE):
    print("R9_RUNTIME_ANDROID_SYSTEM_LABEL=ANDROID_SYSTEM")
else:
    print("R9_RUNTIME_ANDROID_SYSTEM_LABEL=UNRESOLVED")

if re.search(r"GrapheneOS", snippet, re.IGNORECASE):
    print("R9_ADB_NOTIFICATION_GRAPHENE_IDENTITY=OBSERVED")
elif re.search(r"SableOS", snippet, re.IGNORECASE):
    print("R9_ADB_NOTIFICATION_SABLE_IDENTITY=OBSERVED")
else:
    print("R9_ADB_NOTIFICATION_BRAND_IDENTITY=NOT_PRESENT_IN_SNIPPET")
PY

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum > SHA256SUMS.txt
)

echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY"
