# Titan2 Deliverable Source Map

## Purpose

This document prevents Titan2 research, prior qualification work, and repository-specific constraints from being lost when new SableOS deliverables are created.

Any future Titan2 deliverable that affects build qualification, GSI deployment planning, fastboot/fastbootd handling, AVB boundaries, logical partition sizing, device preflight, or release readiness should explicitly review this source map before implementation.

## Required source categories

Titan2 deliverables must distinguish the following source categories:

```text
1. Historical SableOS project chat context and pasted validation logs
2. Local evidence directories produced during Titan2/N1B qualification
3. Current aimindseye/sableos repo docs, scripts, gates, and artifact registry state
4. Titan2 research/reference repositories listed below
5. Current runtime device evidence collected by read-only ADB/fastboot/fastbootd scripts
```

If a deliverable uses only a subset, it must say so explicitly in its PR body or documentation.

## Required repository references

The following repositories are the current Titan2/SableOS reference set:

```text
aimindseye/unihertz-titan2
sableos-project/device_sable_titan2
sableos-project/platform_sable
sableos-project/treble_restlessos
sableos-project/platform_manifest
sableos-project/build
aimindseye/sableos
```

### aimindseye/unihertz-titan2

Purpose:

```text
Titan2/Titan2 Elite device research, wiki-style findings, physical-device notes, observed stock behavior, and hardware/vendor-specific unknowns.
```

Use before creating deliverables involving:

```text
stock behavior
physical-device handling
boot modes
unknown Titan2/Titan2 Elite differences
restore-path assumptions
manual operator procedures
```

### sableos-project/device_sable_titan2

Purpose:

```text
SableOS organization-side Titan2 device documentation, pass seals, phase notes, and device-specific publication-quality evidence.
```

Use before creating deliverables involving:

```text
Titan2 phase status
public device docs
stock/restore evidence
GSI deployment boundary docs
release-readiness claims
```

### sableos-project/platform_sable

Purpose:

```text
Sable platform overlays and SableOS platform behavior that may be consumed by the Titan2 GSI substrate.
```

Use before creating deliverables involving:

```text
Sable overlay behavior
platform feature ownership
Sable system identity
cross-device platform assumptions
```

### sableos-project/treble_restlessos

Purpose:

```text
Restless/Treble source substrate used for the Titan2 native Android 16 / GSI build path.
```

Use before creating deliverables involving:

```text
Treble product graph
GSI target behavior
PHH/Treble product inheritance
Android 16 source substrate
build graph changes
```

### sableos-project/platform_manifest

Purpose:

```text
Manifest and repo composition for the SableOS platform source graph.
```

Use before creating deliverables involving:

```text
source checkout composition
repo sync assumptions
branch/revision provenance
multi-repo graph changes
```

### sableos-project/build

Purpose:

```text
SableOS organization-side build scripts and build-system customizations.
```

Use before creating deliverables involving:

```text
shared build tooling
release gates
build orchestration
organization-level build behavior
```

### aimindseye/sableos

Purpose:

```text
Main integration repository for current local CI, Titan2/N1B scripts, gates, artifact registry, and operator-facing phase flow.
```

Use before creating deliverables involving:

```text
local CI
deployment gates
artifact registration
Phase 08+
Phase 09+
Phase 10+
Phase 11+
operator commands
```

## Titan2-specific constraints that must not be lost

These constraints are currently established by project evidence and must be preserved unless later evidence explicitly supersedes them:

```text
DEVICE=titan2
BOARD_PRODUCT=g71v78c2k_dfl_tee
SOC=MediaTek_MT6878
ANDROID_MAJOR=16
SDK=36
KERNEL=6.1.145-android14-11
ARM64_ONLY=YES
TREBLE=true
SLOTS=2
DYNAMIC_PARTITIONS=true
VIRTUAL_AB=true
SUPER_SIZE=9663676416
BOOTLOADER_UNLOCK_SUPPORTED=YES
AVB_ORANGE_AFTER_UNLOCK=YES
FASTBOOTD_SUPPORTED=YES
FASTBOOT_BOOT_SUPPORTED=NO
DSU_AVAILABLE=NO_ON_TESTED_STOCK
STANDALONE_RECOVERY_PARTITION_OBSERVED=NO
RECOVERY_LOCATION=vendor_boot_recovery_vendor_ramdisk
AVB_CHAINED_BOOT_VBMETA_SYSTEM_VBMETA_VENDOR=YES
ROOT_VBMETA_KEY_ROTATION=13_TO_14_OBSERVED
NO_SABLE_IMAGE_FLASHED_YET=YES
```

## Titan2 GSI deployment implications

Titan2 GSI deployment planning is not the same as a generic Android phone flow.

Required implications:

```text
1. Bootloader fastboot alone is insufficient for logical partition sizing.
2. Userspace fastbootd is required for LP/super sizing decisions.
3. `fastboot boot` is not available as a low-risk temporary boot path.
4. DSU is not available on the tested stock build as a low-risk GSI path.
5. No standalone recovery partition should be assumed.
6. Restore planning must account for vendor_boot-hosted recovery behavior.
7. Chained AVB must be treated as a separate planning axis from LP sizing.
8. Flash execution remains blocked until a separate reviewed and authorized plan exists.
9. LP mutation commands are not authorized by sizing gates.
10. Public release and production signing are not implied by local candidate images.
```

## Current evidence checkpoints

Current known Titan2/N1B checkpoints:

```text
N1B_PHASE_08_IMAGE_BUILD_CANDIDATE=PASS
N1B_ARTIFACT_REGISTER=PASS
N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED_AS_DESIGNED_BEFORE_PHYSICAL_METADATA
N1B_PHASE_10A_ADB_PREFLIGHT=PASS_READ_ONLY
N1B_PHASE_10B_FASTBOOTD_PREFLIGHT=PASS_READ_ONLY
N1B_PHASE_11_FASTBOOTD_LP_SUPER_SIZING=PASS
N1B_PHASE_11_LP_SUPER_SIZING=PASS_PLAN_REQUIRED
FLASH_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

Important sizing result:

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

Interpretation:

```text
The current system logical partition is too small for the N1B system image.
Super capacity appears sufficient by the conservative selected-partition estimate.
A reviewed LP resize plan is required before flash-plan generation.
No flash, resize, AVB mutation, slot mutation, or erase command is authorized by this result.
```

## Future deliverable checklist

Before opening a Titan2 deliverable PR, record the applicable items:

```text
SOURCE_MAP_REVIEWED=YES
HISTORICAL_CHAT_CONTEXT_REVIEWED=YES_OR_SCOPE_LIMITED
UNIHERTZ_TITAN2_REPO_REVIEWED=YES_OR_NOT_APPLICABLE
DEVICE_SABLE_TITAN2_REPO_REVIEWED=YES_OR_NOT_APPLICABLE
PLATFORM_SABLE_REPO_REVIEWED=YES_OR_NOT_APPLICABLE
TREBLE_RESTLESSOS_REPO_REVIEWED=YES_OR_NOT_APPLICABLE
PLATFORM_MANIFEST_REPO_REVIEWED=YES_OR_NOT_APPLICABLE
BUILD_REPO_REVIEWED=YES_OR_NOT_APPLICABLE
CURRENT_SABLEOS_REPO_REVIEWED=YES
CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_OR_NOT_APPLICABLE
```

If any required source is not reviewed, the PR must say that explicitly and avoid broad safety/readiness claims.

## Required PR body language for Titan2 deployment deliverables

Titan2 deployment PRs should include a source section similar to:

```text
## Source review

- Historical SableOS project context: reviewed / scope-limited
- aimindseye/unihertz-titan2: reviewed / not applicable
- sableos-project/device_sable_titan2: reviewed / not applicable
- sableos-project/platform_sable: reviewed / not applicable
- sableos-project/treble_restlessos: reviewed / not applicable
- sableos-project/platform_manifest: reviewed / not applicable
- sableos-project/build: reviewed / not applicable
- aimindseye/sableos current docs/scripts/gates: reviewed
- Current device evidence: reviewed / not applicable
```

## Boundary reminder

Unless a future PR explicitly changes the authorization boundary and is separately approved:

```text
DEVICE_CONTACT_AUTHORIZED=NO_BY_DEFAULT
ADB_COMMANDS_RUN=NO_BY_DEFAULT
FASTBOOT_COMMANDS_RUN=NO_BY_DEFAULT
REBOOT_AUTHORIZED=NO_BY_DEFAULT
FLASH_AUTHORIZED=NO
ERASE_AUTHORIZED=NO
UNLOCK_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```
