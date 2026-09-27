# SableOS Build Methodology

STATUS=STANDARD_BUILD_METHODOLOGY
APPLIES_TO=all_devices
DEVICE_FAMILIES=Pixel/Panther,Titan2,Titan2Elite,Q27,future_keyboard_first_devices
BUILD_PRODUCT_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
FLASH_ENABLEMENT=NO

## Purpose

This document defines the standard SableOS build, CI, preflight, qualification,
repair and release methodology. It is intentionally device-agnostic. Device
scripts may add device-specific gates, but they must not weaken the common
methodology.

The immediate reason for this standard is that SableOS build and preflight output
contains many states. Important states must be easy for a human to scan and also
safe for scripts to parse.

```text
COLOR_CODED_STATE_OUTPUT=REQUIRED
MACHINE_READABLE_KEY_VALUE_OUTPUT=REQUIRED
EVIDENCE_DIR_REQUIRED=YES
NO_COLOR_ESCAPE_HATCH=REQUIRED
ALL_DEVICES_FOLLOW_SAME_METHOD=YES
```

## Core principles

```text
ONE_METHOD_ALL_DEVICES=YES
DEVICE_SPECIFIC_GATES_ALLOWED=YES
DEVICE_SPECIFIC_SHORTCUTS_TO_SKIP_COMMON_GATES=NO
EVIDENCE_FIRST=YES
AUTHORIZATION_FIRST=YES
REPRODUCIBLE_COMMANDS=YES
NO_IMPLICIT_FLASH=YES
NO_IMPLICIT_DEVICE_CONTACT=YES
NO_IMPLICIT_CLEAN_OR_CLOBBER=YES
NO_SILENT_NETWORK_FETCH=YES
```

Every script must make its authority boundary visible before doing work.

Required authorization lines:

```text
SOURCE_MUTATION_AUTHORIZED=<YES|NO|scope>
BUILD_AUTHORIZED=<YES|NO|scope>
DEVICE_CONTACT_AUTHORIZED=<YES|NO>
FLASH_AUTHORIZED=<YES|NO>
NETWORK_FETCH_AUTHORIZED=<YES|NO|scope>
CLEAN_AUTHORIZED=<YES|NO>
CLOBBER_AUTHORIZED=<YES|NO>
WORKSPACE_DELETE_AUTHORIZED=<YES|NO>
```

## Colored output and parseable state

All build, CI, preflight, qualification, repair and release scripts must source
`build/lib/sable-state.sh` when that helper is available.

```bash
# shellcheck source=/dev/null
. "${SABLE_ROOT:-$(pwd)}/build/lib/sable-state.sh"
```

Important state must be emitted in two forms:

1. a color-coded human line;
2. a plain `KEY=VALUE` state line suitable for grep, CI and final result files.

Canonical color classes:

```text
PASS=green
FAIL=red
WARN=yellow
INFO=cyan
GATE=magenta
SKIP=dim
NEXT=bold
```

The helper supports:

```text
NO_COLOR=1
SABLE_COLOR=never
SABLE_COLOR=always
SABLE_COLOR=auto
```

A final result file must remain plain text and parser-safe. ANSI color sequences
may appear in terminal logs, but final result files must be usable with simple
`grep` and `awk`.

```text
TERMINAL_COLOR=YES
RESULT_FILE_COLOR=NO
KEY_VALUE_OUTPUT=REQUIRED
```

## Standard script shape

Each script should follow this shape.

```text
1. Declare authorization state.
2. Create evidence directory.
3. Record host/workspace/source identity.
4. Validate preconditions.
5. Execute only the authorized stage.
6. Capture return codes explicitly.
7. Write plain final result file.
8. Print NEXT_ACTION.
```

Long-running tmux driver scripts should not rely on `set -euo pipefail` to manage
control flow. They must capture return codes explicitly so tmux/SSH sessions do
not disappear without a readable failure summary.

```text
TMUX_DRIVER_SET_E_STRICT_MODE=NO
EXPLICIT_RC_CAPTURE=YES
PIPESTATUS_CAPTURE=YES_WHEN_BASH_PIPE_USED
READABLE_FAILURE_SUMMARY=REQUIRED
```

Short non-interactive gates may use stricter shell settings only when a readable
failure summary is still emitted.

## Standard phases

### 0. Source acquisition

```text
SOURCE_SYNC=allowed_only_when_network_fetch_authorized
FULL_WORKSPACE_DELETE=NO_UNLESS_EXPLICIT
TARGETED_REPAIR_BEFORE_FULL_RESET=YES
SOURCE_SYNC_SEAL_REQUIRED=YES
```

### 1. Read-only preflight

```text
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
EXPECTED_OUTPUT=PREFLIGHT_PASS_OR_ACTIONABLE_FAIL
```

### 2. Integration mapping

```text
SOURCE_MUTATION_AUTHORIZED=NO_BY_DEFAULT
BUILD_AUTHORIZED=NO_BY_DEFAULT
PRODUCT_DISCOVERY=YES
MODULE_MAPPING=YES
SYSTEM_IMG_FEATURE_MATRIX_CHECK=YES
DEVICE_GATE_MATRIX_CHECK=YES
```

### 3. Controlled source mutation

```text
SOURCE_MUTATION_AUTHORIZED=YES_BY_DELIVERABLE_ONLY
SMALL_REVIEWABLE_DIFFS=YES
PR_OR_PATCH_BOUNDARY_REQUIRED=YES
NO_UNRELATED_REFORMATTING=YES
```

### 4. Module or narrow build

```text
BUILD_AUTHORIZED=YES_MODULES_ONLY
FULL_IMAGE_BUILD_AUTHORIZED=NO_UNLESS_EXPLICIT
CLEAN_AUTHORIZED=NO_UNLESS_EXPLICIT
CLOBBER_AUTHORIZED=NO_UNLESS_EXPLICIT
```

### 5. Full image build

```text
FULL_IMAGE_BUILD_AUTHORIZED=YES_ONLY_WHEN_EXPLICIT
SOURCE_BOUND_IMAGE_REQUIRED=YES
TARGET_PRODUCT_RECORDED=YES
TARGET_RELEASE_RECORDED=YES
OUT_DIR_RECORDED=YES
```

### 6. Device acceptance

```text
DEVICE_CONTACT_AUTHORIZED=YES_ONLY_WHEN_EXPLICIT
ADB_COMMANDS_RECORDED=YES
FASTBOOT_COMMANDS_RECORDED=YES
FLASH_AUTHORIZED=NO_UNLESS_EXPLICIT
```

### 7. Flash/release

```text
FLASH_AUTHORIZED=YES_ONLY_WHEN_EXPLICIT
ROLLBACK_PLAN_REQUIRED=YES
IMAGE_HASHES_REQUIRED=YES
SLOT_STATE_RECORDED=YES
POST_FLASH_ACCEPTANCE_REQUIRED=YES
```

## Common final result keys

Every script should write a plain final result file such as
`99-<stage>-result.txt` containing the stage result and evidence path.

Recommended keys:

```text
<STAGE_NAME>=PASS|FAIL|WARN|SKIP
FAIL_COUNT=<integer>
WARN_COUNT=<integer>
EVIDENCE=<absolute path>
NEXT_ACTION=<text>
BUILD_STARTED=YES|NO
DEVICE_CONTACT=YES|NO
FLASH_AUTHORIZED=YES|NO
```

## Standardized build safety for all devices

The same methodology applies to Panther, Titan 2, Titan 2 Elite, Q27 and future
SableOS devices.

```text
PANTHER_METHOD_DIFFERENCE=device_specific_gates_only
TITAN2_METHOD_DIFFERENCE=device_specific_gates_only
TITAN2_ELITE_METHOD_DIFFERENCE=device_specific_gates_only
Q27_METHOD_DIFFERENCE=device_specific_gates_only
COMMON_AUTHORIZATION_MODEL=YES
COMMON_EVIDENCE_MODEL=YES
COMMON_COLOR_OUTPUT_MODEL=YES
COMMON_RESULT_FILE_MODEL=YES
```

## Must-not regress rules

```text
MAJOR_STATE_WITHOUT_COLOR=NO
MAJOR_STATE_WITHOUT_KEY_VALUE=NO
FINAL_RESULT_WITHOUT_EVIDENCE_PATH=NO
BUILD_WITHOUT_AUTHORIZATION_LINES=NO
FLASH_WITHOUT_EXPLICIT_AUTHORIZATION=NO
DEVICE_CONTACT_WITHOUT_EXPLICIT_AUTHORIZATION=NO
FULL_WORKSPACE_DELETE_AS_FIRST_REPAIR=NO
SOURCE_SYNC_WITHOUT_SEAL=NO
SCRIPT_FAILURE_WITHOUT_READABLE_RESULT=NO
```

## Acceptance criteria

```text
SABLE_BUILD_METHODOLOGY=PASS
STATE_OUTPUT_HELPER=PASS
COLOR_CODED_IMPORTANT_STATE=PASS
PLAIN_KEY_VALUE_RESULTS=PASS
NO_COLOR_SUPPORTED=PASS
ALL_DEVICES_COMMON_METHOD=PASS
DEVICE_SPECIFIC_GATES_ALLOWED=PASS
DEVICE_SPECIFIC_METHOD_FORKS=NO
BUILD_PRODUCT_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
FLASH_ENABLEMENT=NO
```
