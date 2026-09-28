# N1B Phase 17: Titan2 Guarded Execution Script Draft

## Purpose

Phase 17 produces a guarded execution-script **draft** for owner review only.

It implements the owner-approved boundary:

```text
APPROVE_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT_ONLY=YES
AUTHORIZE_EXECUTION=NO
```

Phase 17 may assemble a JSON plan, Markdown review summary, and a non-runnable `.sh.draft` skeleton. It must not contact the device, run transport tools, reboot, flash, erase, unlock, resize logical partitions, mutate AVB, change slots, publish, production-sign, or emit runnable commands.

## Inputs

Phase 17 consumes:

```text
phase16-executable-plan-draft.json
phase15-manual-authorization-package.json
phase14-final-preflight-approval.json
N1B artifact registry manifest
restore report directory
canonical system.img
```

## Required upstream state

```text
PHASE_14_FINAL_PREFLIGHT_APPROVAL=APPROVAL_READY_FOR_MANUAL_AUTHORIZATION
PHASE_15_MANUAL_AUTHORIZATION_PACKAGE=PASS_REVIEW_READY
PHASE_16_EXECUTABLE_PLAN_DRAFT=PASS_REVIEW_DRAFT_READY
OWNER_AUTHORIZATION=APPROVE_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT_ONLY
AUTHORIZE_EXECUTION=NO
```

## Authorization boundary

```text
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

## Draft output rules

The generated `.sh.draft` must remain non-runnable and review-only.

Required markers:

```text
DRAFT_ONLY=YES
AUTHORIZE_EXECUTION=NO
RUNNABLE_SHELL=NO
DEVICE_CONTACT=NO
COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO
```

The draft may describe action intents such as:

```text
VERIFY_OPERATOR_INTENT_AND_STOP_CONDITIONS
VERIFY_RESTORE_PATH_AND_USERDATA_POLICY
VERIFY_DEVICE_IDENTITY_FASTBOOTD_AND_ACTIVE_SLOT
INTENT_ACTIVE_SYSTEM_LOGICAL_PARTITION_GROWTH
INTENT_SYSTEM_IMAGE_DEPLOYMENT
INTENT_AVB_CHAIN_DECISION
INTENT_POST_CHANGE_ACCEPTANCE
INTENT_ROLLBACK_OR_STOP
```

Every action intent must carry:

```text
executable_command=NO
runnable_shell=NO
manual_execution_authorization_required=YES
operator_review_required=YES
stop_if_unmet=YES
```

## Non-goals

Phase 17 does not:

```text
CONTACT_DEVICE=NO
RUN_ADB=NO
RUN_FASTBOOT=NO
REBOOT_DEVICE=NO
FLASH_SYSTEM=NO
RESIZE_LOGICAL_PARTITION=NO
ERASE_USERDATA=NO
PATCH_AVB=NO
CHANGE_SLOT=NO
UNLOCK_BOOTLOADER=NO
GENERATE_EXECUTABLE_COMMANDS=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGN=NO
```

## Expected output state

```text
N1B_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT=PASS_REVIEW_DRAFT_READY
N1B_PHASE_17_OWNER_AUTHORIZATION=APPROVE_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT_ONLY
N1B_PHASE_17_AUTHORIZE_EXECUTION=NO
N1B_PHASE_17_FLASH_AUTHORIZED=NO
N1B_PHASE_17_LP_MUTATION_ALLOWED=NO
COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO
```

## Canonical post-merge flow

After this PR is merged, run from merged `main`:

```bash
cd /srv/data/sable-build/sableos/repo

git fetch origin main
git switch main
git merge --ff-only origin/main

bash build/gates/n1b-phase-17-guarded-execution-script-draft-contract.sh

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

Then assemble the Phase 17 review draft:

```bash
bash build/titan2/assemble-n1b-phase-17-guarded-execution-script-draft.sh \
  --phase16-json /srv/data/sable-build/evidence/titan2/n1b-phase-16-executable-plan-draft/20260928_210016/offline-draft/phase16-executable-plan-draft.json \
  --phase15-json /srv/data/sable-build/evidence/titan2/n1b-phase-15-manual-authorization-package/20260928_205352/offline-authorization-package/phase15-manual-authorization-package.json \
  --phase14-json /srv/data/sable-build/evidence/titan2/n1b-phase-14-final-preflight-approval/20260928_204633/offline-approval/phase14-final-preflight-approval.json \
  --artifact-manifest /srv/data/sable-build/release-registry/titan2/N1B/462839cfcc362e4f4ed93d8a8dabf059885452b1.json \
  --restore-report /srv/data/sable-build/artifacts/titan2/stock-firmware/unihertz-device-fota-20260922 \
  --system-image /srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi/target/product/tdgsi_arm64_ab/system.img
```

No execution is authorized by Phase 17.
