#!/usr/bin/env bash

REPO="${REPO:-$(pwd)}"
APP_ROOT="${APP_ROOT:-$REPO/apps/r8/android}"
FAILURES=0
FIRST_FAILURE=""

say() {
  printf '%s\n' "$1"
}

record_failure() {
  NAME="$1"
  DETAIL="$2"
  FAILURES=$((FAILURES + 1))
  if [ -z "$FIRST_FAILURE" ]; then
    FIRST_FAILURE="$NAME"
  fi
  say "$NAME=FAIL"
  say "$DETAIL"
}

pass() {
  say "$1=PASS"
}

require_module() {
  MODULE="$1"
  LABEL="$2"
  if grep -Fq "include(\":$MODULE\")" "$APP_ROOT/settings.gradle.kts" 2>/dev/null; then
    pass "$LABEL"
  else
    record_failure "$LABEL" "MISSING_INCLUDE=include(\":$MODULE\")"
  fi
}

deny_source_term() {
  LABEL="$1"
  TERM="$2"
  if grep -R -n -I \
      --exclude-dir=build \
      --exclude-dir=.gradle \
      --exclude='*.png' \
      --exclude='*.webp' \
      --exclude='*.jpg' \
      --exclude='*.jpeg' \
      --exclude='*.gif' \
      -F "$TERM" "$APP_ROOT" >/tmp/n1b-identity-scan.$$ 2>/dev/null; then
    record_failure "$LABEL" "FORBIDDEN_TERM=$TERM"
    sed -n '1,20p' /tmp/n1b-identity-scan.$$
  else
    pass "$LABEL"
  fi
  rm -f /tmp/n1b-identity-scan.$$
}

say "===== N1B SABLE IDENTITY STATIC QUALIFIER ====="
say "REPO=$REPO"
say "APP_ROOT=$APP_ROOT"
say "SOURCE_MUTATION_AUTHORIZED=NO"
say "BUILD_AUTHORIZED=NO"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"
say "PUBLIC_RELEASE=NO"

if [ ! -f "$APP_ROOT/settings.gradle.kts" ]; then
  record_failure "N1B_IDENTITY_GRADLE_SETTINGS" \
    "MISSING_PATH=$APP_ROOT/settings.gradle.kts"
else
  pass "N1B_IDENTITY_GRADLE_SETTINGS"
fi

if [ "$FAILURES" -eq 0 ]; then
  require_module "design" "N1B_IDENTITY_MODULE_design"
  require_module "calculator" "N1B_IDENTITY_MODULE_calculator"
  require_module "convert" "N1B_IDENTITY_MODULE_convert"
  require_module "games" "N1B_IDENTITY_MODULE_games"
  require_module "media" "N1B_IDENTITY_MODULE_media"
  require_module "hub" "N1B_IDENTITY_MODULE_hub"
  require_module "sablestart-presentation-check" "N1B_IDENTITY_MODULE_sablestart_presentation_check"
  require_module "sablestart-visual-review" "N1B_IDENTITY_MODULE_sablestart_visual_review"
  require_module "weather" "N1B_IDENTITY_MODULE_weather"
  require_module "calendar" "N1B_IDENTITY_MODULE_calendar"
fi

if [ -d "$APP_ROOT" ]; then
  deny_source_term "N1B_IDENTITY_NO_GRAPHENEOS_BRANDING" "GrapheneOS"
  deny_source_term "N1B_IDENTITY_NO_GRAPHENE_OS_BRANDING" "Graphene OS"
  deny_source_term "N1B_IDENTITY_NO_CHROME_LABEL" "Chrome"
fi

say "===== N1B SABLE IDENTITY STATIC RESULT ====="
say "FAILURES=$FAILURES"
if [ -n "$FIRST_FAILURE" ]; then
  say "FIRST_FAILURE=$FIRST_FAILURE"
fi

if [ "$FAILURES" -eq 0 ]; then
  say "N1B_SABLE_IDENTITY_STATIC=PASS"
  exit 0
fi

say "N1B_SABLE_IDENTITY_STATIC=FAIL"
exit 1
