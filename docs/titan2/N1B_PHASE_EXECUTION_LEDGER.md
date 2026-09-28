# Titan 2 N1B phase execution ledger

Status: **stacked N1B execution plan / no image work**

This ledger defines the merge/test sequence for N1B after N1A substrate
registration. Each phase is intended to land as a separate PR so the operator can
merge, run the named checks, and stop before physical or image work if any phase
fails.

```text
N1B_PHASE_EXECUTION_LEDGER=YES
N1A_REGISTERED_SUBSTRATE_REQUIRED=YES
N1B_STACKED_PRS_REQUIRED=YES
N1B_IMAGE_BUILD_LAST=YES
N1B_FLASH_PLAN_METADATA_REQUIRED_BEFORE_FLASH=YES
```

## Current substrate

N1B starts from the registered N1A substrate:

```text
N1A_ARTIFACT_REGISTRATION=PASS
N1A_ARTIFACT_KIND=gsi-system-image
N1A_PRIMARY_ARTIFACT=system
N1A_ANDROID_VERSION=16.0.0
N1A_AOSP_REVISION=android-16.0.0_r4
N1A_BUILD_ID=BP4A.251205.006
N1A_PUBLIC_RELEASE=NO
N1A_FLASH_AUTHORIZED=NO
```

N1A is valid as a substrate stamp. It is not the preferred first user-facing
Titan 2 flash candidate.

## Phase order

```text
N1B_PHASE_01=FAST_LANE_SDK_PREFLIGHT
N1B_PHASE_02=PHASE_LEDGER_AND_GATES
N1B_PHASE_03=SABLE_IDENTITY_AND_APP_COMPOSITION_STATIC_GATES
N1B_PHASE_04=BRANDING_AND_DEFAULT_SURFACE_INTEGRATION
N1B_PHASE_05=KEYBOARD_FIRST_SETUP_AND_LAUNCHER_BINDING
N1B_PHASE_06=PHYSICAL_UX_ACCEPTANCE_READINESS
N1B_PHASE_07=FULL_CI_READINESS
N1B_PHASE_08=N1B_IMAGE_BUILD_CANDIDATE
```

## Phase 01: fast-lane SDK preflight

Purpose: prevent duplicate Gradle failures when the Android SDK is not bound.

```text
N1B_PHASE_01_RESULT_REQUIRED=PASS
N1B_STAGE_A_ANDROID_SDK_PREFLIGHT=REQUIRED
N1B_STAGE_A_GRADLE_BUILDS_SKIP_ON_SDK_PRECONDITION=YES
```

Required checks after merge:

```text
bash build/gates/n1b-stage-a-fast-lane-contract.sh .
EVIDENCE_DIR=/srv/data/sable-build/evidence/titan2/n1b-stage-a-fast-lane/<stamp> \
  bash build/titan2/qualify-n1b-stage-a-fast-lane.sh
```

If no Android SDK is bound, the expected first failure is:

```text
FIRST_FAILURE=N1B_STAGE_A_ANDROID_SDK
N1B_STAGE_A_GRADLE_BUILDS=SKIPPED_ANDROID_SDK_PRECONDITION
```

That is a clean environment failure, not an app-code failure.

## Phase 02: phase ledger and gates

Purpose: make the rest of the work auditable and fail-closed.

```text
N1B_PHASE_02_RESULT_REQUIRED=PASS
N1B_PHASE_LEDGER_CONTRACT=REQUIRED
N1B_PHASE_DRIVER=REQUIRED
```

Required checks:

```text
bash build/gates/n1b-phase-execution-contract.sh .
bash build/titan2/qualify-n1b-phase-execution.sh
```

## Phase 03: Sable identity and app composition static gates

Purpose: catch stale or missing product identity before app build/image work.

```text
N1B_PHASE_03_RESULT_REQUIRED=PASS
SABLE_IDENTITY_STATIC_GATE=REQUIRED
NO_USER_FACING_GRAPHENE_BRANDING_ON_SABLE_SURFACES=REQUIRED
BROWSER_LABEL_POLICY_BOUND=REQUIRED
HUB_MAIL_MESSAGES_PEOPLE_COMPOSITION_BOUND=REQUIRED
```

This phase is static-only. It must not claim runtime behavior.

## Phase 04: branding and default surface integration

Purpose: wire Sable branding/default-surface configuration for the N1B candidate.

```text
N1B_PHASE_04_RESULT_REQUIRED=PASS
SABLE_BRANDING_INTEGRATION=REQUIRED
SABLE_DEFAULT_SURFACE_INTEGRATION=REQUIRED
PANTHER_TOUCH_FIRST_NON_REGRESSION=REQUIRED
```

## Phase 05: keyboard-first setup and launcher binding

Purpose: bind the GrapheneOS SetupWizard2 base and Sable keyboard-first extension
points without breaking Pixel/Panther setup behavior.

```text
N1B_PHASE_05_RESULT_REQUIRED=PASS
GRAPHENEOS_SETUPWIZARD2_BASE_BOUND=REQUIRED
TITAN_KEYBOARD_FIRST_SETUP_EXTENSION_POINT=REQUIRED
SABLE_START_KEYBOARD_FIRST_BINDING=REQUIRED
```

## Phase 06: physical UX acceptance readiness

Purpose: prepare operator checks for Titan 2 hardware validation.

```text
N1B_PHASE_06_RESULT_REQUIRED=PASS
PHYSICAL_UX_ACCEPTANCE_READY=YES
DEVICE_CONTACT_AUTHORIZED=NO_BY_PHASE_LEDGER
```

This phase may prepare scripts/docs but must not contact the device unless the
operator explicitly authorizes physical acceptance.

## Phase 07: full CI readiness

Purpose: run the full code/static CI gates after app and physical UX readiness.

```text
N1B_PHASE_07_RESULT_REQUIRED=PASS
FULL_CI_READY=YES
IMAGE_BUILD_AUTHORIZED=NO
```

## Phase 08: N1B image build candidate

Purpose: build the N1B image only after Phase 01-07 pass.

```text
N1B_PHASE_08_RESULT_REQUIRED=PASS
N1B_IMAGE_BUILD_ALLOWED_ONLY_AFTER_PHASES_01_TO_07_PASS=YES
N1B_FLASH_STILL_REQUIRES_N0_N1_PHYSICAL_METADATA=YES
```

## Flash boundary

N1B image build does not imply flash authorization.

```text
FLASH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
N1B_FLASH_REQUIRES_RESTORE_REPORT=YES
N1B_FLASH_REQUIRES_BOOTLOADER_PREFLIGHT=YES
N1B_FLASH_REQUIRES_FASTBOOTD_PREFLIGHT=YES
N1B_FLASH_REQUIRES_AVB_LP_USERDATA_POLICY=YES
```

The N0/N1 flash-plan metadata remains mandatory before any Titan 2 write.
