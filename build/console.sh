#!/usr/bin/env bash
# Human-readable console checkpoints for SableOS build/CI drivers.
#
# Canonical machine-readable markers must remain plain stdout. These helpers
# add separate colored checkpoint lines only when stdout is an interactive TTY.
# Set NO_COLOR to disable ANSI output explicitly.

sable_console_color_enabled() {
    [[ -z "${NO_COLOR:-}" ]] || return 1

    case "${SABLE_CONSOLE_COLOR:-AUTO}" in
        YES) return 0 ;;
        NO) return 1 ;;
        AUTO) ;;
        *) return 1 ;;
    esac

    [[ -t 1 ]] && [[ "${TERM:-}" != dumb ]]
}

# Capture interactive color capability before a driver redirects stdout through
# tee. Nested scripts inherit the decision, while NO_COLOR always wins.
sable_console_capture_color() {
    if [[ -n "${NO_COLOR:-}" ]]; then
        export SABLE_CONSOLE_COLOR=NO
    elif [[ "${SABLE_CONSOLE_COLOR:-AUTO}" == YES || "${SABLE_CONSOLE_COLOR:-AUTO}" == NO ]]; then
        export SABLE_CONSOLE_COLOR
    elif [[ -t 1 && "${TERM:-}" != dumb ]]; then
        export SABLE_CONSOLE_COLOR=YES
    else
        export SABLE_CONSOLE_COLOR=NO
    fi
}

_sable_console_emit() {
    local color="$1"
    local label="$2"
    shift 2

    if sable_console_color_enabled; then
        printf '\033[%sm>>> %s: %s\033[0m\n' "$color" "$label" "$*"
    else
        printf '>>> %s: %s\n' "$label" "$*"
    fi
}

sable_checkpoint_pass() {
    _sable_console_emit '1;32' PASS "$@"
}

sable_checkpoint_fail() {
    _sable_console_emit '1;31' FAIL "$@"
}

sable_checkpoint_warn() {
    _sable_console_emit '1;33' WARN "$@"
}

sable_checkpoint_info() {
    _sable_console_emit '1;36' INFO "$@"
}
