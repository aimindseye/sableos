#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SABLE="$ROOT/build/sable.sh"
TITAN="$ROOT/build/devices/titan2.sh"

echo "===== N1B2 CANONICAL PRODUCT COMPOSITION CONTRACT ====="
echo "ROOT=$ROOT"

[[ -f "$SABLE" ]] || {
  echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_CONTRACT=FAIL_MISSING_SABLE_ENTRYPOINT path=$SABLE"
  exit 1
}
[[ -f "$TITAN" ]] || {
  echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_CONTRACT=FAIL_MISSING_TITAN_ADAPTER path=$TITAN"
  exit 1
}

bash -n "$SABLE"
bash -n "$TITAN"
echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_SYNTAX=PASS"

required_sable_markers=(
  "product-composition"
  "sable_device_product_composition"
  "SABLE_DEVICE_PRODUCT_COMPOSITION_SUPPORTED"
  "SABLE_PRODUCT_COMPOSITION=BLOCKED_UNQUALIFIED"
  "SABLE_PRODUCT_COMPOSITION=FAIL_ADAPTER_FUNCTION_MISSING"
)

for marker in "${required_sable_markers[@]}"; do
  if ! grep -Fq -- "$marker" "$SABLE"; then
    echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_CONTRACT=FAIL_SABLE_MARKER marker=$marker"
    exit 1
  fi
done

required_titan_markers=(
  "SABLE_DEVICE_PRODUCT_COMPOSITION_SUPPORTED=YES"
  "sable_device_product_composition()"
  "TITAN2_N1B2_RELEASE_GATE=AUDIT_ONLY_FAIL_CLOSED"
  "TITAN2_N1B2_BUILD_SUPPORTED=NO"
  "TITAN2_N1B2_QUALIFY_SUPPORTED=NO"
  "TITAN2_N1B2_FLASH_EXECUTION_SUPPORTED=NO"
  "TITAN2_N1B2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO"
  "DEVICE_CONTACT_AUTHORIZED=NO"
  "ADB_COMMANDS_RUN=NO"
  "FASTBOOT_COMMANDS_RUN=NO"
  "BUILD_AUTHORIZED=NO"
  "FLASH_AUTHORIZED=NO"
  "FACTORY_RESET_AUTHORIZED=NO"
  "PUBLIC_RELEASE=NO"
  "PRODUCTION_SIGNING=NO"
  "TITAN2_N1B2_ALLOWED_MODULE_SABLELAUNCHER_SELECTED"
  'TITAN2_N1B2_BLOCKED_MODULE_${key_module}_NOT_SELECTED'
  "blocked_modules=("
  "SableMail"
  "SableMessages"
  "SableSettings"
  "SablePhone"
  "SableContacts"
)

for marker in "${required_titan_markers[@]}"; do
  if ! grep -Fq -- "$marker" "$TITAN"; then
    echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_CONTRACT=FAIL_TITAN_MARKER marker=$marker"
    exit 1
  fi
done

if awk '
  /sable_device_product_composition\(\)/ { in_fn=1 }
  in_fn && /^}/ { in_fn=0 }
  in_fn { print }
' "$TITAN" | grep -Eq '(^|[;&|[:space:]])(adb|fastboot|lunch|mka|make|ninja|soong_ui)([[:space:]]|$)'; then
  echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_CONTRACT=FAIL_FORBIDDEN_COMMAND_IN_PRODUCT_COMPOSITION"
  exit 1
fi

echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_NO_DEVICE_OR_BUILD_CONTACT=PASS"
echo "N1B2_CANONICAL_PRODUCT_COMPOSITION_CONTRACT=PASS"
