# N1B Phase 15: Titan2 Manual Authorization Package

## Purpose

Phase 15 assembles a human-reviewable authorization package from the Phase 10 through Phase 14 evidence chain.

It is the first package intended for owner review before any later executable-plan draft work.

Phase 15 does **not** execute, generate, or authorize flash, LP resize, erase, reboot, slot mutation, AVB mutation, unlock, public release, or production signing.

## Authorization boundary

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

## Inputs

Phase 15 consumes:

```text
phase14-final-preflight-approval.json
phase13-flash-plan-proposal.json
N1B artifact manifest
restore report directory
canonical N1B system.img
```

The required upstream state is:

```text
PHASE_08_IMAGE_BUILD=PASS
PHASE_10A_ADB_PREFLIGHT=PASS_READ_ONLY
PHASE_10B_FASTBOOTD_PREFLIGHT=PASS_READ_ONLY
PHASE_11_LP_SUPER_SIZING=PASS_PLAN_REQUIRED
PHASE_12_LP_RESIZE_PLAN_DESIGN=PASS_REVIEW_REQUIRED
PHASE_13_FLASH_PLAN_PROPOSAL=PASS_REVIEW_REQUIRED
PHASE_14_FINAL_PREFLIGHT_APPROVAL=APPROVAL_READY_FOR_MANUAL_AUTHORIZATION
```

## Review summary produced by Phase 15

Phase 15 emits both JSON and Markdown containing:

```text
1. Evidence status summary
2. Sizing summary
3. Proposed non-executable operation sequence
4. Risk and stop-condition summary
5. Restore/rollback evidence binding
6. Post-change acceptance checklist
7. Manual approval options
```

## Titan2-specific risk context

The package must preserve the Titan2-specific context established in prior phases:

```text
1. Titan2 uses dynamic partitions and virtual A/B.
2. Userspace fastbootd evidence is required for LP/super sizing.
3. `fastboot boot` is not available as a temporary boot path.
4. DSU is not available on the tested stock build as a low-risk GSI path.
5. No standalone recovery partition should be assumed.
6. Restore planning must account for vendor_boot-hosted recovery behavior.
7. Chained AVB remains a separate decision axis.
8. AtlasOS is reference evidence only, not the SableOS product path.
9. jinn_lineageos22 issue review contributes post-change acceptance risks.
10. No Sable image has been flashed yet.
```

## Non-executable operation sequence

Phase 15 may describe the later proposed sequence as review-only operation IDs:

```text
REVIEW_RESTORE_AND_USERDATA_POLICY
REVIEW_DEVICE_IDENTITY_AND_ACTIVE_SLOT
REVIEW_LP_RESIZE_ACTIVE_SYSTEM
REVIEW_SYSTEM_IMAGE_DEPLOYMENT
REVIEW_AVB_CHAIN_DECISION
REVIEW_POST_CHANGE_ACCEPTANCE
```

Phase 15 must not emit runnable shell commands for these operations.

## Manual approval options

Phase 15 can recommend one of the following owner decisions:

```text
APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY
REQUEST_MORE_EVIDENCE
BLOCK_DEPLOYMENT
```

`APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY` means only that a later PR may draft an executable plan for review. It does **not** authorize running that plan.

## Non-goals

Phase 15 does not:

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

## Canonical post-merge flow

After this PR is merged, run from merged `main`:

```bash
cd /srv/data/sable-build/sableos/repo

git fetch origin main
git switch main
git merge --ff-only origin/main

bash build/gates/n1b-phase-15-manual-authorization-package-contract.sh

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

Then assemble the Phase 15 package:

```bash
bash build/titan2/assemble-n1b-phase-15-manual-authorization-package.sh \
  --phase14-json /srv/data/sable-build/evidence/titan2/n1b-phase-14-final-preflight-approval/20260928_204633/offline-approval/phase14-final-preflight-approval.json \
  --phase13-json /srv/data/sable-build/evidence/titan2/n1b-phase-13-flash-plan-proposal/20260928_202350/offline-proposal/phase13-flash-plan-proposal.json \
  --artifact-manifest /srv/data/sable-build/release-registry/titan2/N1B/462839cfcc362e4f4ed93d8a8dabf059885452b1.json \
  --restore-report /srv/data/sable-build/artifacts/titan2/stock-firmware/unihertz-device-fota-20260922 \
  --system-image /srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi/target/product/tdgsi_arm64_ab/system.img
```

The result is still review-only. It does not authorize execution.
