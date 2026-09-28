#!/usr/bin/env bash

ROOT="${1:-.}"
FAILURES=0

check_file() {
  if [ -f "$ROOT/$1" ]; then
    echo "$2=PASS"
  else
    echo "$2=FAIL_MISSING path=$1"
    FAILURES=$((FAILURES + 1))
  fi
}

check_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -qF "$pattern" "$ROOT/$path" 2>/dev/null; then
    echo "$label=PASS"
  else
    echo "$label=FAIL pattern=$pattern path=$path"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "===== N1A ACTIVE PRODUCT GRAPH CONTRACT ====="
echo "ROOT=$ROOT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"

check_file "build/titan2/qualify-n1a-active-product-graph.sh" "N1A_ACTIVE_PRODUCT_GRAPH_GUARD_SCRIPT"
check_file "docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md" "N1A_ACTIVE_PRODUCT_GRAPH_LESSON_DOC"

check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "ACTIVE_PRODUCT_MK" "GUARD_REPORTS_ACTIVE_PRODUCT_MK"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "treble_arm64_bvN.mk" "GUARD_BINDS_TREBLE_ARM64_BVN"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "N1A_ACTIVE_PRODUCT_OVERLAY_INHERIT=FAIL" "GUARD_BLOCKS_MISSING_ACTIVE_PRODUCT_WIRING"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "WARN_MISPLACED_CLEANUP_REQUIRED" "GUARD_REPORTS_ANDROIDPRODUCTS_CLEANUP_WARNING"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "SABLEOS_MILESTONE=N1A" "GUARD_USES_SEMANTIC_STAMP_MILESTONE"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "SABLEOS_STAGE=ANDROID16_RESTLESS_R7E_OVERLAY_STAMP" "GUARD_USES_SEMANTIC_STAMP_STAGE"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "N1A_MARKER_FOUND_COUNT" "GUARD_REPORTS_MARKER_COUNT"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "DEVICE_CONTACT_AUTHORIZED=NO" "GUARD_NO_DEVICE_CONTACT"
check_contains "build/titan2/qualify-n1a-active-product-graph.sh" "FLASH_AUTHORIZED=NO" "GUARD_NO_FLASH"

check_contains "docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md" "ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk" "DOC_ACTIVE_PRODUCT_OWNER"
check_contains "docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md" "AndroidProducts.mk is product discovery" "DOC_ANDROIDPRODUCTS_LESSON"
check_contains "docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md" "SABLEOS_MILESTONE=N1A" "DOC_SEMANTIC_STAMP_MILESTONE"
check_contains "docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md" "N1A can be flashed only after the N0/N1 physical flash-plan metadata is bound" "DOC_N1A_FLASH_BOUNDARY"
check_contains "docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md" "N1B is the preferred first user-facing flash candidate" "DOC_N1B_FLASH_RECOMMENDATION"

if [ "$FAILURES" -eq 0 ]; then
  echo "N1A_ACTIVE_PRODUCT_GRAPH_CONTRACT=PASS"
else
  echo "N1A_ACTIVE_PRODUCT_GRAPH_CONTRACT=FAIL failures=$FAILURES"
fi

exit "$FAILURES"
