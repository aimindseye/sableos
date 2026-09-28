# N1B Phase 18: Titan2 Cross-Repo Flash Readiness Review

## Purpose

Phase 18 answers the owner question:

```text
Does the Phase 17 guarded execution script draft satisfy the relevant gates and requirements across:
- sableos-project/build
- aimindseye/sableos
- aimindseye/unihertz-titan2
?
```

Result:

```text
N1B_PHASE_18_CROSS_REPO_FLASH_READINESS=BLOCKED_WRITE_CAPABLE_PLAN_REQUIRED
```

Phase 17 satisfies the current review-draft/no-execution boundary, but it does not yet satisfy the cross-repo requirement for a reviewed write-capable flash plan.

## Scope

Phase 18 is a review gate. It does not contact the device, run ADB, run fastboot, reboot, flash, erase, unlock, resize logical partitions, mutate AVB, change slots, publish, production-sign, or emit runnable commands.

```text
DEVICE=titan2
RELEASE=N1B
DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
REBOOT_COMMANDS_RUN=NO
FLASH_AUTHORIZED=NO
FLASH_COMMANDS_RUN=NO
ERASE_COMMANDS_RUN=NO
UNLOCK_COMMANDS_RUN=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
SLOT_MUTATION_AUTHORIZED=NO
COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Cross-repo finding

### aimindseye/sableos

The Phase 17 artifacts prove only:

```text
N1B_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT=PASS_REVIEW_DRAFT_READY
AUTHORIZE_EXECUTION=NO
FLASH_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO
```

The generated `.sh.draft` is intentionally non-runnable and exits immediately. That is correct for Phase 17, but it is not a flash executor.

### sableos-project/build

The public build repository preserves fail-closed policy:

```text
Titan-family build and flash paths fail closed.
Treble portability artifacts are GSI system-image-first.
Flash paths remain explicitly gated.
Successful source bootstrap or image build does not authorize package, sign, or flash.
```

Phase 17 does not contradict this policy because it does not authorize flash. It also does not satisfy it for execution because no explicit write-capable flash gate has passed.

### aimindseye/unihertz-titan2

The Titan2 research/runbook requires a stricter first-write handoff. Before the first non-stock write, the plan must include, at minimum:

```text
ARTIFACT_SHA256
ARTIFACT_LOGICAL_BYTES
ACTIVE_SLOT
SNAPSHOT_UPDATE_STATUS=none
SYSTEM_CURRENT_BYTES
LP_ACTION=direct-flash | reviewed-resize
AVB_ACTION
USERDATA_POLICY=preserve | explicit-wipe-approved
RESTORE_REPORT
BOOTLOADER_PREFLIGHT
FASTBOOTD_PREFLIGHT
```

The runbook also says the exact command sequence must be reviewed before creating/running a write-capable script.

Phase 17 intentionally does not contain an exact command sequence. Therefore Phase 17 is not enough to move directly to flashing.

## Decision

```text
PHASE17_REVIEW_DRAFT_VALID=YES
CROSS_REPO_FLASH_EXECUTION_READY=NO
WRITE_CAPABLE_FLASH_PLAN_EXISTS=NO
EXACT_COMMAND_SEQUENCE_REVIEWED=NO
FLASH_AUTHORIZED=NO
N1B_PHASE_18_CROSS_REPO_FLASH_READINESS=BLOCKED_WRITE_CAPABLE_PLAN_REQUIRED
```

## Next allowed phase

The next allowed deliverable is a Phase 19 write-capable flash-plan PR, still not run by default.

Phase 19 must include a concrete, reviewed write plan and still remain guarded until the owner separately authorizes execution.

Required Phase 19 characteristics:

```text
OWNER_AUTHORIZATION_REQUIRED=YES
DEVICE_SERIAL_EXPLICIT=YES
RESTORE_PATH_RECHECK_REQUIRED=YES
BOOTLOADER_PREFLIGHT_RECHECK_REQUIRED=YES
FASTBOOTD_PREFLIGHT_RECHECK_REQUIRED=YES
SNAPSHOT_UPDATE_STATUS_NONE_REQUIRED=YES
LP_ACTION_EXPLICIT=YES
AVB_ACTION_EXPLICIT=YES
USERDATA_POLICY_EXPLICIT=YES
STOP_GATES_BEFORE_EVERY_MUTATION=YES
POST_CHANGE_ACCEPTANCE_REQUIRED=YES
```

Phase 19 may draft executable commands for review, but those commands must not be run until a later explicit execution authorization is given.

## Owner decision options

```text
APPROVE_PHASE_19_WRITE_CAPABLE_FLASH_PLAN_PR_ONLY
REQUEST_MORE_CROSS_REPO_REVIEW
BLOCK_FLASH_PATH
```

Recommended owner decision:

```text
APPROVE_PHASE_19_WRITE_CAPABLE_FLASH_PLAN_PR_ONLY=YES
AUTHORIZE_EXECUTION=NO
```
