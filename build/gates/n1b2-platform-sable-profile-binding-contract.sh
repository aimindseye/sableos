#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLATFORM_SABLE_ROOT="${PLATFORM_SABLE_ROOT:-/srv/data/sable-build/platform_sable}"
MANIFEST="$ROOT/docs/titan2/N1B2_APP_PROFILE_BINDING.tsv"
DOC="$ROOT/docs/titan2/N1B2_APP_PROFILE_BINDING.md"

passes=0
failures=0

emit() {
  local status="$1"
  local key="$2"
  local detail="${3:-}"

  printf '%s=%s' "$key" "$status"
  [[ -z "$detail" ]] || printf ' %s' "$detail"
  printf '\n'

  case "$status" in
    PASS) passes=$((passes + 1)) ;;
    FAIL) failures=$((failures + 1)) ;;
  esac
}

require_file() {
  local key="$1"
  local path="$2"

  [[ -f "$path" ]] \
    && emit PASS "$key" "path=$path" \
    || emit FAIL "$key" "missing=$path"
}

require_manifest_reference() {
  local key="$1"
  local pattern="$2"

  grep -Fq -- "$pattern" "$MANIFEST" \
    && emit PASS "$key" "pattern=$pattern path=$MANIFEST" \
    || emit FAIL "$key" "missing_pattern=$pattern path=$MANIFEST"
}

cat <<EOF_HEADER
===== N1B2 PLATFORM_SABLE PROFILE BINDING CONTRACT =====
ROOT=$ROOT
PLATFORM_SABLE_ROOT=$PLATFORM_SABLE_ROOT
MANIFEST=$MANIFEST
DOC=$DOC
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
BUILD_AUTHORIZED=NO
IMAGE_BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF_HEADER

require_file N1B2_PROFILE_BINDING_DOC_PRESENT "$DOC"
require_file N1B2_PROFILE_BINDING_MANIFEST_PRESENT "$MANIFEST"

require_file PLATFORM_SABLE_ARCHITECTURE_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/ARCHITECTURE.md"
require_file PLATFORM_SABLE_PORTABILITY_RULES_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/PORTABILITY_RULES.md"
require_file PLATFORM_SABLE_KEYBOARD_FIRST_PROFILE_MODEL_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/KEYBOARD_FIRST_DEVICE_PROFILE_MODEL.md"
require_file PLATFORM_SABLE_KEYBOARD_POINTER_PROFILE_MODEL_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/KEYBOARD_AND_POINTER_PROFILE_MODEL.md"
require_file PLATFORM_SABLE_CRITICAL_TEXT_ENTRY_GATES_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/CRITICAL_TEXT_ENTRY_GATES.md"
require_file PLATFORM_SABLE_DEVICE_CAPABILITY_MATRIX_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/device-capabilities/DEVICE_CAPABILITY_MATRIX.md"
require_file PLATFORM_SABLE_TITAN2_CAPABILITY_PROFILE_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/device-capabilities/TITAN2.md"

require_manifest_reference N1B2_PROFILE_BINDING_REFERENCES_TITAN2_CAPABILITY \
  "docs/device-capabilities/TITAN2.md"

expected_surfaces=(
  sable_start
  all_apps
  sable_hub
  messages_conversation
  mail_calendar
  contacts_people
  media_gallery
  browser_webview
  camera_capture
  command_search
  settings
  phone_dialer
  lockscreen
  setup_wizard
  quick_settings
  files_documents
  mobile_manager_app_controls
  connectivity_otg_nfc_cast
  private_space_work_profile
  subscreen_shortcut_keyboard
  toolbox_hardware
  utilities_notes_recorder
)

for surface in "${expected_surfaces[@]}"; do
  require_manifest_reference \
    "N1B2_PROFILE_SURFACE_${surface^^}_BOUND" \
    "${surface}"$'\t'
done

if [[ -f "$MANIFEST" ]]; then
  while IFS=$'\t' read -r surface capability_doc design_doc visual_doc artifact; do
    [[ "$surface" != surface ]] || continue
    [[ -n "$surface" ]] || continue

    key_surface="${surface^^}"

    require_file \
      "N1B2_${key_surface}_CAPABILITY_DOC_PRESENT" \
      "$PLATFORM_SABLE_ROOT/$capability_doc"

    require_file \
      "N1B2_${key_surface}_DESIGN_DOC_PRESENT" \
      "$PLATFORM_SABLE_ROOT/$design_doc"

    require_file \
      "N1B2_${key_surface}_VISUAL_CONFIRMATION_DOC_PRESENT" \
      "$PLATFORM_SABLE_ROOT/$visual_doc"

    require_file \
      "N1B2_${key_surface}_APPROVED_ARTIFACT_PRESENT" \
      "$PLATFORM_SABLE_ROOT/$artifact"

    case "$artifact" in
      docs/design/artifacts/*titan2*.svg)
        emit PASS "N1B2_${key_surface}_ARTIFACT_IS_TITAN2_SVG" "artifact=$artifact"
        ;;
      *)
        emit FAIL "N1B2_${key_surface}_ARTIFACT_IS_TITAN2_SVG" "bad_artifact=$artifact"
        ;;
    esac
  done < "$MANIFEST"
fi

echo "N1B2_PLATFORM_SABLE_PROFILE_BINDING_PASSES=$passes"
echo "N1B2_PLATFORM_SABLE_PROFILE_BINDING_FAILURES=$failures"

if (( failures == 0 )); then
  echo "N1B2_PLATFORM_SABLE_PROFILE_BINDING=PASS"
  exit 0
fi

echo "N1B2_PLATFORM_SABLE_PROFILE_BINDING=FAIL failures=$failures"
exit 1
