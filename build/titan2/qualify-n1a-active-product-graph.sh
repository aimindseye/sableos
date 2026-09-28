#!/usr/bin/env bash

status=0

fail() {
  echo "$1"
  status=1
}

pass() {
  echo "$1"
}

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/qualify-n1a-active-product-graph.sh \
    --src-dir PATH \
    --out-dir PATH \
    --n1a-evidence-dir PATH

Optional:
  --active-product-mk PATH
  --target-files PATH
  --marker-path-in-zip SYSTEM/product/etc/sableos/n1-substrate.env
  --expected-marker N1A_SABLE_OVERLAY_STAMP=PASS

This is a read-only N1A reporting/packaging guard. It does not build,
contact a device, run adb/fastboot, or flash.
EOF
}

SRC_DIR=""
OUT_DIR=""
N1A_EVIDENCE_DIR=""
ACTIVE_PRODUCT_MK=""
TARGET_FILES=""
MARKER_PATH_IN_ZIP="SYSTEM/product/etc/sableos/n1-substrate.env"
EXPECTED_MARKER="N1A_SABLE_OVERLAY_STAMP=PASS"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --src-dir) SRC_DIR="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --n1a-evidence-dir) N1A_EVIDENCE_DIR="$2"; shift 2 ;;
    --active-product-mk) ACTIVE_PRODUCT_MK="$2"; shift 2 ;;
    --target-files) TARGET_FILES="$2"; shift 2 ;;
    --marker-path-in-zip) MARKER_PATH_IN_ZIP="$2"; shift 2 ;;
    --expected-marker) EXPECTED_MARKER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 64 ;;
  esac
done

if [ -z "$SRC_DIR" ] || [ -z "$OUT_DIR" ] || [ -z "$N1A_EVIDENCE_DIR" ]; then
  usage
  exit 64
fi

if [ -z "$ACTIVE_PRODUCT_MK" ]; then
  ACTIVE_PRODUCT_MK="$SRC_DIR/device/phh/treble/treble_arm64_bvN.mk"
fi

if [ -z "$TARGET_FILES" ] && [ -f "$N1A_EVIDENCE_DIR/target-files.tsv" ]; then
  TARGET_FILES="$(awk -F '\t' '{print $2}' "$N1A_EVIDENCE_DIR/target-files.tsv" | head -1)"
fi

ANDROID_PRODUCTS_MK="$SRC_DIR/device/phh/treble/AndroidProducts.mk"
OVERLAY_MK="$SRC_DIR/vendor/sable/n1_overlay/sable_n1_overlay.mk"
MARKER_FILE="$SRC_DIR/vendor/sable/n1_overlay/sableos_n1_substrate.env"

cat <<EOF
===== N1A ACTIVE PRODUCT GRAPH GUARD =====
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
SRC_DIR=$SRC_DIR
OUT_DIR=$OUT_DIR
N1A_EVIDENCE_DIR=$N1A_EVIDENCE_DIR
ACTIVE_PRODUCT_MK=$ACTIVE_PRODUCT_MK
ANDROID_PRODUCTS_MK=$ANDROID_PRODUCTS_MK
OVERLAY_MK=$OVERLAY_MK
MARKER_FILE=$MARKER_FILE
TARGET_FILES=$TARGET_FILES
MARKER_PATH_IN_ZIP=$MARKER_PATH_IN_ZIP
EOF

[ -d "$SRC_DIR" ] || fail "N1A_SRC_DIR=FAIL"
[ -d "$OUT_DIR" ] || fail "N1A_OUT_DIR=FAIL"
[ -d "$N1A_EVIDENCE_DIR" ] || fail "N1A_EVIDENCE_DIR=FAIL"
[ -f "$ACTIVE_PRODUCT_MK" ] || fail "N1A_ACTIVE_PRODUCT_MK=FAIL_MISSING"
[ -f "$ANDROID_PRODUCTS_MK" ] || fail "N1A_ANDROID_PRODUCTS_MK=FAIL_MISSING"
[ -f "$OVERLAY_MK" ] || fail "N1A_OVERLAY_MK=FAIL_MISSING"
[ -f "$MARKER_FILE" ] || fail "N1A_MARKER_FILE=FAIL_MISSING"
[ -n "$TARGET_FILES" ] && [ -f "$TARGET_FILES" ] || fail "N1A_TARGET_FILES=FAIL_MISSING"

if [ "$status" -ne 0 ]; then
  echo "N1A_ACTIVE_PRODUCT_GRAPH_GUARD=FAIL_PRECONDITION"
  exit 1
fi

if grep -q 'PRODUCT_NAME := treble_arm64_bvN' "$ACTIVE_PRODUCT_MK"; then
  pass "N1A_ACTIVE_PRODUCT_NAME=PASS"
else
  fail "N1A_ACTIVE_PRODUCT_NAME=FAIL"
fi

if grep -q 'PRODUCT_DEVICE := tdgsi_arm64_ab' "$ACTIVE_PRODUCT_MK"; then
  pass "N1A_ACTIVE_PRODUCT_DEVICE=PASS"
else
  fail "N1A_ACTIVE_PRODUCT_DEVICE=FAIL"
fi

if grep -q 'vendor/sable/n1_overlay/sable_n1_overlay.mk' "$ACTIVE_PRODUCT_MK"; then
  pass "N1A_ACTIVE_PRODUCT_OVERLAY_INHERIT=PASS"
else
  fail "N1A_ACTIVE_PRODUCT_OVERLAY_INHERIT=FAIL"
fi

if grep -q 'vendor/sable/n1_overlay/sable_n1_overlay.mk' "$ANDROID_PRODUCTS_MK"; then
  fail "N1A_ANDROID_PRODUCTS_OVERLAY_INHERIT=FAIL_MISPLACED"
else
  pass "N1A_ANDROID_PRODUCTS_OVERLAY_INHERIT=PASS_ABSENT"
fi

if grep -q 'PRODUCT_COPY_FILES' "$OVERLAY_MK" && grep -q 'sableos_n1_substrate.env' "$OVERLAY_MK"; then
  pass "N1A_OVERLAY_COPY_RULE=PASS"
else
  fail "N1A_OVERLAY_COPY_RULE=FAIL"
fi

if grep -qF "$EXPECTED_MARKER" "$MARKER_FILE"; then
  pass "N1A_MARKER_FILE_CONTENT=PASS"
else
  fail "N1A_MARKER_FILE_CONTENT=FAIL"
fi

ZIP_ENTRY_COUNT=0
MARKER_FOUND_COUNT=0
if unzip -Z1 "$TARGET_FILES" 2>/dev/null | grep -qxF "$MARKER_PATH_IN_ZIP"; then
  ZIP_ENTRY_COUNT=1
  pass "N1A_MARKER_ZIP_ENTRY=PASS"
else
  fail "N1A_MARKER_ZIP_ENTRY=FAIL"
fi

if [ "$ZIP_ENTRY_COUNT" -eq 1 ]; then
  if unzip -p "$TARGET_FILES" "$MARKER_PATH_IN_ZIP" 2>/dev/null | grep -qF "$EXPECTED_MARKER"; then
    MARKER_FOUND_COUNT=1
    pass "N1A_MARKER_ZIP_CONTENT=PASS"
  else
    fail "N1A_MARKER_ZIP_CONTENT=FAIL"
  fi
fi

cat <<EOF
N1A_MARKER_FOUND_COUNT=$MARKER_FOUND_COUNT
PRODUCT_MK=$ANDROID_PRODUCTS_MK
ACTIVE_PRODUCT_MK=$ACTIVE_PRODUCT_MK
EOF

if [ "$status" -eq 0 ]; then
  echo "N1A_ACTIVE_PRODUCT_GRAPH_GUARD=PASS"
else
  echo "N1A_ACTIVE_PRODUCT_GRAPH_GUARD=FAIL"
fi

exit "$status"
