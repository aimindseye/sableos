# N1B Phase 13: Titan2 Flash-Plan Proposal Gate

## Purpose

Phase 13 converts the Phase 12 LP resize plan JSON into a human-reviewable flash-plan proposal for Titan2/N1B.

Phase 13 is **not** flash execution and is **not** an executable command generator.

It produces a proposal record that binds the prior evidence, the canonical N1B `system.img`, the required logical partition growth, and the remaining safety blockers before any executable flash or resize script can exist.

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
CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_12_OUTPUT
```

External Titan2/SableOS organization repositories are referenced through the canonical Titan2 deliverable source map. Phase 13 does not claim a fresh deep review of every external repository unless a future PR adds that evidence explicitly.

## Inputs

Phase 13 consumes:

```text
Phase 12 JSON = offline LP resize plan design artifact
N1B system image = canonical N1B GSI system image
Titan2 source map = docs/titan2/TITAN2_DELIVERABLE_SOURCE_MAP.md
```

Expected current Phase 12 values:

```text
N1B_PHASE_12_REQUIRED_SYSTEM_BYTES=3180666880
N1B_PHASE_12_SYSTEM_CURRENT_BYTES=756441088
N1B_PHASE_12_SYSTEM_MISSING_DIRECT_BYTES=2424225792
N1B_PHASE_12_SYSTEM_TARGET_BYTES=3449815040
N1B_PHASE_12_SYSTEM_GROWTH_BYTES=2693373952
N1B_PHASE_12_SUPER_HEADROOM_ESTIMATE_BYTES=5510365184
N1B_PHASE_12_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES=2816991232
N1B_PHASE_12_LP_RESIZE_PLAN=PASS_REVIEW_REQUIRED
```

## Titan2-specific constraints

Phase 13 inherits the Titan2 constraints captured in the source map and Phase 11:

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

Implications:

```text
DO_NOT_USE_DSU_FOR_N1B_GSI=YES
DO_NOT_USE_FASTBOOT_BOOT_FOR_N1B_GSI=YES
DO_NOT_ASSUME_STANDALONE_RECOVERY_FLASH_PATH=YES
DO_NOT_TREAT_BOOTLOADER_FASTBOOT_AS_SUFFICIENT_FOR_LP_SIZING=YES
DO_NOT_TREAT_PHASE_13_AS_EXECUTABLE_FLASH_SCRIPT=YES
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

## Output

The Phase 13 designer emits JSON only.

It may include a non-executable ordered proposal with descriptions such as:

```text
1. Confirm restore path, stock baseline, and userdata policy.
2. Confirm Titan2 device identity, active slot, and fastbootd state.
3. Review LP resize need for the active system logical partition.
4. Review N1B system image deployment decision.
5. Review AVB/chained-vbmeta decision as a separate axis.
6. Define post-change acceptance checks.
```

It must not emit executable shell commands, fastboot commands, adb commands, destructive commands, or mutation commands.

## Required remaining review decisions

A Phase 13 `PASS_REVIEW_REQUIRED` result still requires separate review and authorization for at least:

```text
RESTORE_PATH_FINAL_REVIEW_REQUIRED=YES
USERDATA_POLICY_FINAL_REVIEW_REQUIRED=YES
ACTIVE_SLOT_FINAL_REVIEW_REQUIRED=YES
LP_RESIZE_COMMAND_REVIEW_REQUIRED=YES
GSI_FLASH_COMMAND_REVIEW_REQUIRED=YES
AVB_CHAIN_DECISION_REQUIRED=YES
POST_FLASH_ACCEPTANCE_REQUIRED=YES
ROLLBACK_PLAN_REQUIRED=YES
```

## Expected result

For the current N1B evidence, expected classification is:

```text
N1B_PHASE_13_FLASH_PLAN_PROPOSAL=PASS_REVIEW_REQUIRED
N1B_PHASE_13_FLASH_PLAN_ALLOWED=NO
N1B_PHASE_13_FLASH_ALLOWED=NO
N1B_PHASE_13_LP_MUTATION_ALLOWED=NO
N1B_PHASE_13_AVB_MUTATION_ALLOWED=NO
COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO
```

## Canonical post-merge flow

After this PR is merged, run from merged `main` only:

```bash
cd /srv/data/sable-build/sableos/repo

git fetch origin main
git switch main
git merge --ff-only origin/main

bash build/gates/n1b-phase-13-flash-plan-proposal-contract.sh

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

Then run Phase 13 offline against the Phase 12 JSON:

```bash
bash build/titan2/design-n1b-phase-13-flash-plan-proposal.sh \
  --phase12-json /srv/data/sable-build/evidence/titan2/n1b-phase-12-lp-resize-plan/20260928_201621/offline-plan/phase12-lp-resize-plan.json \
  --system-image /srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi/target/product/tdgsi_arm64_ab/system.img
```

No flash, LP resize, AVB mutation, erase, reboot, slot mutation, or executable command generation is authorized by Phase 13.
