# N1B Phase 12: Titan2 LP Resize Plan Design Gate

## Purpose

Phase 12 converts the Phase 11 LP/super sizing evidence into an offline, review-only LP resize plan record.

Phase 12 does not flash, erase, resize, change slots, patch AVB, reboot, contact the device, or create executable fastboot commands.

It answers one narrow question:

```text
Given the Phase 11 fastbootd sizing evidence and the canonical N1B system image, what reviewed target system logical-partition size would be required before a later flash-plan can even be considered?
```

## Source review

```text
SOURCE_MAP_REVIEWED=YES
HISTORICAL_CHAT_CONTEXT_REVIEWED=SCOPE_LIMITED_TO_CURRENT_PROJECT_CONTEXT_AND_PASTED_VALIDATION_LOGS
UNIHERTZ_TITAN2_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
DEVICE_SABLE_TITAN2_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
PLATFORM_SABLE_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
TREBLE_RESTLESSOS_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
PLATFORM_MANIFEST_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
BUILD_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
CURRENT_SABLEOS_REPO_REVIEWED=YES
CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_11_OUTPUT
```

This is intentionally not a broad fresh audit of every external repository. It is a Phase 12 continuation from the canonical source map, current SableOS Phase 09-11 docs/gates, and the latest Phase 11 evidence.

## Titan2 constraints preserved

Phase 12 inherits the Titan2 constraints recorded in `docs/titan2/TITAN2_DELIVERABLE_SOURCE_MAP.md` and `docs/titan2/N1B_PHASE_11_LP_SUPER_SIZING.md`:

```text
TITAN2_DYNAMIC_PARTITIONS=YES
TITAN2_VIRTUAL_AB=YES
TITAN2_FASTBOOTD_SUPPORTED=YES
TITAN2_DSU_AVAILABLE=NO
TITAN2_FASTBOOT_BOOT_SUPPORTED=NO
TITAN2_STANDALONE_RECOVERY_PARTITION=NO_OBSERVED
TITAN2_RECOVERY_LOCATION=vendor_boot_recovery_vendor_ramdisk
TITAN2_AVB_CHAINED_BOOT_VBMETA_SYSTEM_VBMETA_VENDOR=YES
TITAN2_GSI_DEPLOYMENT_REQUIRES_FASTBOOTD_LP_CONTEXT=YES
NO_SABLE_IMAGE_FLASHED_YET=YES
```

Practical implications:

```text
DO_NOT_USE_DSU_FOR_N1B_GSI=YES
DO_NOT_USE_FASTBOOT_BOOT_FOR_N1B_GSI=YES
DO_NOT_ASSUME_STANDALONE_RECOVERY_FLASH_PATH=YES
DO_NOT_TREAT_SYSTEM_AS_FIXED_RAW_PARTITION=YES
DO_NOT_TREAT_BOOTLOADER_FASTBOOT_AS_SUFFICIENT_FOR_LP_SIZING=YES
DO_NOT_AUTHORIZE_LP_MUTATION_FROM_PHASE_12=YES
```

## Inputs

Phase 12 consumes:

```text
1. Phase 11 JSON produced by build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh
2. Canonical N1B system image path
3. Optional sizing knobs:
   - alignment bytes, default 1048576
   - system margin bytes, default 268435456
   - minimum remaining super headroom bytes, default 536870912
```

Known current Phase 11 values:

```text
N1B_PHASE_11_REQUIRED_SYSTEM_BYTES=3180666880
N1B_PHASE_11_SYSTEM_CURRENT_BYTES=756441088
N1B_PHASE_11_SYSTEM_MISSING_BYTES=2424225792
N1B_PHASE_11_SUPER_BYTES=9663676416
N1B_PHASE_11_TOTAL_SELECTED_DYNAMIC_CURRENT_BYTES=4153311232
N1B_PHASE_11_SUPER_HEADROOM_ESTIMATE_BYTES=5510365184
N1B_PHASE_11_DIRECT_SYSTEM_SIZE_COMPATIBILITY=BLOCKED_NEEDS_LP_RESIZE_PLAN
N1B_PHASE_11_SUPER_HEADROOM_ESTIMATE=PASS_CAPACITY_APPEARS_AVAILABLE_PLAN_REQUIRED
```

## Output

Phase 12 emits a JSON plan record containing:

```text
phase
source_review
authorization_boundary
inputs
observed_phase11_state
sizing_decision
non_authorized_actions
next_gate
```

The JSON may contain a conceptual target such as:

```text
target_logical_partition=system_a
target_system_bytes=<aligned required size plus margin>
system_growth_bytes=<target - current>
remaining_super_headroom_estimate_bytes=<headroom - growth>
```

It must not contain executable fastboot, adb, shell, flash, erase, AVB, slot, or LP mutation commands.

## Authorization boundary

```text
DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FLASH_COMMANDS_RUN=NO
ERASE_COMMANDS_RUN=NO
UNLOCK_COMMANDS_RUN=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Expected current classification

For the observed Titan2/N1B state, Phase 12 should produce a reviewed candidate plan record but still deny flash-plan generation and all mutation:

```text
N1B_PHASE_12_DIRECT_SYSTEM_SIZE_COMPATIBILITY=BLOCKED_NEEDS_LP_RESIZE_PLAN
N1B_PHASE_12_SUPER_HEADROOM_ESTIMATE=PASS_CAPACITY_APPEARS_AVAILABLE_REVIEW_REQUIRED
N1B_PHASE_12_PLAN_RECORD=PASS_REVIEW_REQUIRED
N1B_PHASE_12_FLASH_PLAN_ALLOWED=NO
N1B_PHASE_12_FLASH_ALLOWED=NO
N1B_PHASE_12_LP_MUTATION_ALLOWED=NO
```

## Canonical post-merge flow

After this PR is merged, run from merged `main` only:

```bash
cd /srv/data/sable-build/sableos/repo

git fetch origin main
git switch main
git merge --ff-only origin/main

bash build/gates/n1b-phase-12-lp-resize-plan-contract.sh

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

Then design the offline Phase 12 plan record using the Phase 11 JSON:

```bash
bash build/titan2/design-n1b-phase-12-lp-resize-plan.sh \
  --phase11-json /srv/data/sable-build/evidence/titan2/n1b-phase-11-lp-super-sizing/20260928_195308/fastbootd-lp-sizing/phase11-fastbootd-lp-sizing.json \
  --system-image /srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi/target/product/tdgsi_arm64_ab/system.img
```

## Non-goals

Phase 12 does not:

```text
CONTACT_DEVICE=NO
RUN_ADB=NO
RUN_FASTBOOT=NO
FLASH_SYSTEM=NO
RESIZE_LOGICAL_PARTITION=NO
DELETE_LOGICAL_PARTITION=NO
CREATE_LOGICAL_PARTITION=NO
ERASE_USERDATA=NO
PATCH_AVB=NO
CHANGE_SLOT=NO
GENERATE_EXECUTABLE_COMMANDS=NO
AUTHORIZE_FLASH_PLAN=NO
AUTHORIZE_FLASH_EXECUTION=NO
```
