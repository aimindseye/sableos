#!/usr/bin/env bash

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=build/titan2/n1b-sable-host-toolchain-env.sh
. "$SCRIPT_DIR/n1b-sable-host-toolchain-env.sh"

exec "$SCRIPT_DIR/qualify-n1b-stage-a-fast-lane.sh" "$@"
