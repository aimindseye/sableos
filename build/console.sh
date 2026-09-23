#!/usr/bin/env bash
# Human-readable console checkpoints for SableOS build/CI drivers.
#
# Canonical machine-readable markers must remain plain stdout. These helpers
# add separate colored checkpoint lines only when stdout is an interactive TTY.
# Set NO_COLOR to disable ANSI output explicitly.

sable_console_color_enabled() {
    [[ -t 1 ]] &&
    [[ -z "${NO_COLOR:-}" ]] &&
    [[ "${TERM:-}" != dumb ]]
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
