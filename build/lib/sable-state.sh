#!/usr/bin/env bash
#
# Shared Sable build/CI state output helper.
#
# Contract:
# - Important state is always emitted as machine-readable KEY=VALUE.
# - Human terminal output is color-coded by state class.
# - NO_COLOR=1 and SABLE_COLOR=never disable ANSI color.
# - SABLE_COLOR=always forces ANSI color even when stdout is not a TTY.
# - This file must be safe to source from build, CI, preflight, qualification,
#   repair, and release scripts for all SableOS device families.

if [ -z "${SABLE_STATE_HELPER_LOADED:-}" ]; then
  SABLE_STATE_HELPER_LOADED=1

  sable_color_enabled() {
    if [ "${NO_COLOR:-0}" = "1" ]; then
      return 1
    fi

    case "${SABLE_COLOR:-auto}" in
      never)
        return 1
        ;;
      always)
        return 0
        ;;
      auto|"")
        [ -t 1 ]
        return $?
        ;;
      *)
        [ -t 1 ]
        return $?
        ;;
    esac
  }

  if sable_color_enabled; then
    SABLE_C_RESET="$(printf '\033[0m')"
    SABLE_C_PASS="$(printf '\033[32m')"
    SABLE_C_FAIL="$(printf '\033[31m')"
    SABLE_C_WARN="$(printf '\033[33m')"
    SABLE_C_INFO="$(printf '\033[36m')"
    SABLE_C_GATE="$(printf '\033[35m')"
    SABLE_C_SKIP="$(printf '\033[2m')"
    SABLE_C_BOLD="$(printf '\033[1m')"
  else
    SABLE_C_RESET=""
    SABLE_C_PASS=""
    SABLE_C_FAIL=""
    SABLE_C_WARN=""
    SABLE_C_INFO=""
    SABLE_C_GATE=""
    SABLE_C_SKIP=""
    SABLE_C_BOLD=""
  fi

  sable_say() {
    # Usage: sable_say LABEL COLOR_VAR MESSAGE...
    sable_label="$1"
    sable_color="$2"
    shift 2
    printf '%s%-5s%s %s\n' "$sable_color" "$sable_label" "$SABLE_C_RESET" "$*"
  }

  sable_info() {
    sable_say "INFO" "$SABLE_C_INFO" "$*"
  }

  sable_gate() {
    sable_say "GATE" "$SABLE_C_GATE" "$*"
  }

  sable_pass() {
    sable_say "PASS" "$SABLE_C_PASS" "$*"
  }

  sable_fail() {
    sable_say "FAIL" "$SABLE_C_FAIL" "$*"
  }

  sable_warn() {
    sable_say "WARN" "$SABLE_C_WARN" "$*"
  }

  sable_skip() {
    sable_say "SKIP" "$SABLE_C_SKIP" "$*"
  }

  sable_next() {
    sable_say "NEXT" "$SABLE_C_BOLD" "$*"
  }

  sable_section() {
    printf '\n%s===== %s =====%s\n' "$SABLE_C_BOLD" "$*" "$SABLE_C_RESET"
  }

  sable_kv() {
    # Usage: sable_kv KEY VALUE
    # This is the canonical machine-readable state line.
    printf '%s=%s\n' "$1" "$2"
  }

  sable_state() {
    # Usage: sable_state CLASS KEY VALUE
    # CLASS: PASS, FAIL, WARN, INFO, GATE, SKIP, NEXT
    sable_class="$1"
    sable_key="$2"
    sable_value="$3"

    case "$sable_class" in
      PASS)
        sable_pass "$sable_key=$sable_value"
        ;;
      FAIL)
        sable_fail "$sable_key=$sable_value"
        ;;
      WARN)
        sable_warn "$sable_key=$sable_value"
        ;;
      GATE)
        sable_gate "$sable_key=$sable_value"
        ;;
      SKIP)
        sable_skip "$sable_key=$sable_value"
        ;;
      NEXT)
        sable_next "$sable_key=$sable_value"
        ;;
      INFO|*)
        sable_info "$sable_key=$sable_value"
        ;;
    esac

    sable_kv "$sable_key" "$sable_value"
  }

  sable_state_pass() {
    sable_state PASS "$1" PASS
  }

  sable_state_fail() {
    sable_state FAIL "$1" FAIL
  }

  sable_state_warn() {
    sable_state WARN "$1" "$2"
  }

  sable_state_info() {
    sable_state INFO "$1" "$2"
  }

  sable_state_gate() {
    sable_state GATE "$1" "$2"
  }

  sable_state_skip() {
    sable_state SKIP "$1" "$2"
  }

  sable_state_next() {
    sable_state NEXT "$1" "$2"
  }

  sable_record_state() {
    # Usage: sable_record_state FILE KEY VALUE
    # Writes plain, parser-safe KEY=VALUE to a result file.
    sable_file="$1"
    sable_key="$2"
    sable_value="$3"
    printf '%s=%s\n' "$sable_key" "$sable_value" >> "$sable_file"
  }

  sable_record_and_emit() {
    # Usage: sable_record_and_emit FILE CLASS KEY VALUE
    sable_file="$1"
    sable_class="$2"
    sable_key="$3"
    sable_value="$4"
    sable_state "$sable_class" "$sable_key" "$sable_value"
    sable_record_state "$sable_file" "$sable_key" "$sable_value"
  }
fi
