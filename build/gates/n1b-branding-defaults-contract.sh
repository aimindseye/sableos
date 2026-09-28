#!/usr/bin/env bash

ROOT="${1:-.}"
FAILURES=0

say() {
  printf '%s\n' "$1"
}

pass() {
  say "$1=PASS"
}

fail() {
  say "$1=FAIL"
  FAILURES=$((FAILURES + 1))
}

require_file() {
  NAME="$1"
  PATH_VALUE="$2"
  if [ -f "$ROOT/$PATH_VALUE" ]; then
    pass "$NAME"
  else
    fail "$NAME"
    say "MISSING_PATH=$PATH_VALUE"
  fi
}

require_marker() {
  NAME="$1"
  PATH_VALUE="$2"
  MARKER="$3"
  if grep -Fq "$MARKER" "$ROOT/$PATH_VALUE" 2>/dev/null; then
    pass "$NAME"
  else
    fail "$NAME"
    say "MISSING_MARKER=$MARKER"
    say "IN_FILE=$PATH_VALUE"
  fi
}

say "===== N1B BRANDING DEFAULTS CONTRACT ====="
say "ROOT=$ROOT"
say "SOURCE_MUTATION_AUTHORIZED=NO"
say "BUILD_AUTHORIZED=NO"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"
say "PUBLIC_RELEASE=NO"

DOC="docs/titan2/N1B_BRANDING_DEFAULTS_READINESS.md"
QUALIFIER="build/titan2/qualify-n1b-branding-defaults.sh"
SELF="build/gates/n1b-branding-defaults-contract.sh"

require_file "N1B_BRANDING_DEFAULTS_DOC" "$DOC"
require_file "N1B_BRANDING_DEFAULTS_QUALIFIER" "$QUALIFIER"
require_file "N1B_BRANDING_DEFAULTS_CONTRACT" "$SELF"

require_marker "DOC_READINESS_MARKER" "$DOC" \
  "N1B_BRANDING_DEFAULTS_READINESS=YES"
require_marker "DOC_PANTHER_MARKER" "$DOC" \
  "PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES"
require_marker "DOC_KEYBOARD_PROFILE_MARKER" "$DOC" \
  "TITAN2_KEYBOARD_FIRST_PROFILE_GATED=YES"
require_marker "DOC_NO_IMAGE_MARKER" "$DOC" \
  "N1B_PHASE_04_DOES_NOT_AUTHORIZE_IMAGE_BUILD=YES"
require_marker "DOC_NO_FLASH_MARKER" "$DOC" \
  "N1B_PHASE_04_DOES_NOT_AUTHORIZE_FLASH=YES"
require_marker "QUALIFIER_NO_BUILD" "$QUALIFIER" \
  "BUILD_AUTHORIZED=NO"
require_marker "QUALIFIER_NO_DEVICE" "$QUALIFIER" \
  "DEVICE_CONTACT_AUTHORIZED=NO"
require_marker "QUALIFIER_PASS_MARKER" "$QUALIFIER" \
  "N1B_BRANDING_DEFAULTS=PASS"

if [ "$FAILURES" -eq 0 ]; then
  say "N1B_BRANDING_DEFAULTS_CONTRACT=PASS"
  exit 0
fi

say "N1B_BRANDING_DEFAULTS_CONTRACT=FAIL"
say "FAILURES=$FAILURES"
exit 1
