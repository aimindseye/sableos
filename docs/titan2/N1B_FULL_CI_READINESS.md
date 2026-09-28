# N1B full CI readiness

Status: **N1B Phase 07 static readiness gate / no image work**

This document defines the final static aggregation gate before N1B may be
considered for an image-build candidate. Phase 07 does not build an image, does
not contact Titan 2 hardware, does not run ADB or fastboot, does not flash, and
does not make a public-release or production-signing claim.

```text
N1B_FULL_CI_READINESS=YES
N1B_PHASE=07
N1B_PHASE_NAME=FULL_CI_READINESS
SOURCE_MUTATION_AUTHORIZED=NO for gate execution
BUILD_AUTHORIZED=NO for this readiness qualifier
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Required predecessor phases

Phase 07 may pass only when all previous N1B phase gates are present and intended
to be green before any Phase 08 image-build candidate work.

```text
N1B_PHASE_01_STAGE_A_FAST_LANE_REQUIRED=YES
N1B_PHASE_02_PHASE_EXECUTION_REQUIRED=YES
N1B_PHASE_03_IDENTITY_STATIC_REQUIRED=YES
N1B_PHASE_04_BRANDING_DEFAULTS_REQUIRED=YES
N1B_PHASE_05_SETUP_LAUNCHER_BINDING_REQUIRED=YES
N1B_PHASE_06_PHYSICAL_UX_READINESS_REQUIRED=YES
```

The Phase 07 qualifier checks that the required documents, qualifiers, contracts,
and host-toolchain wrapper are present. It intentionally does not rerun Gradle or
claim that physical UX has passed on hardware.

## Required gate inventory

```text
N1B_REQUIRED_DOC_PHASE_EXECUTION=docs/titan2/N1B_PHASE_EXECUTION_LEDGER.md
N1B_REQUIRED_DOC_IDENTITY=docs/titan2/N1B_SABLE_IDENTITY_STATIC_GATE.md
N1B_REQUIRED_DOC_BRANDING_DEFAULTS=docs/titan2/N1B_BRANDING_DEFAULTS_READINESS.md
N1B_REQUIRED_DOC_SETUP_LAUNCHER=docs/titan2/N1B_SETUP_LAUNCHER_BINDING_READINESS.md
N1B_REQUIRED_DOC_PHYSICAL_UX=docs/titan2/N1B_PHYSICAL_UX_ACCEPTANCE_READINESS.md
N1B_REQUIRED_DOC_FULL_CI=docs/titan2/N1B_FULL_CI_READINESS.md
```

```text
N1B_REQUIRED_GATE_STAGE_A_FAST_LANE=build/gates/n1b-stage-a-fast-lane-contract.sh
N1B_REQUIRED_GATE_SABLE_HOST_TOOLCHAIN=build/gates/n1b-sable-host-toolchain-contract.sh
N1B_REQUIRED_GATE_PHASE_EXECUTION=build/gates/n1b-phase-execution-contract.sh
N1B_REQUIRED_GATE_IDENTITY_STATIC=build/gates/n1b-sable-identity-static-contract.sh
N1B_REQUIRED_GATE_BRANDING_DEFAULTS=build/gates/n1b-branding-defaults-contract.sh
N1B_REQUIRED_GATE_SETUP_LAUNCHER=build/gates/n1b-setup-launcher-binding-contract.sh
N1B_REQUIRED_GATE_PHYSICAL_UX=build/gates/n1b-physical-ux-readiness-contract.sh
N1B_REQUIRED_GATE_FULL_CI=build/gates/n1b-full-ci-readiness-contract.sh
```

```text
N1B_REQUIRED_QUALIFIER_STAGE_A_FAST_LANE=build/titan2/qualify-n1b-stage-a-fast-lane-sable-host.sh
N1B_REQUIRED_QUALIFIER_PHASE_EXECUTION=build/titan2/qualify-n1b-phase-execution.sh
N1B_REQUIRED_QUALIFIER_IDENTITY_STATIC=build/titan2/qualify-n1b-sable-identity-static.sh
N1B_REQUIRED_QUALIFIER_BRANDING_DEFAULTS=build/titan2/qualify-n1b-branding-defaults.sh
N1B_REQUIRED_QUALIFIER_SETUP_LAUNCHER=build/titan2/qualify-n1b-setup-launcher-binding.sh
N1B_REQUIRED_QUALIFIER_PHYSICAL_UX=build/titan2/qualify-n1b-physical-ux-readiness.sh
N1B_REQUIRED_QUALIFIER_FULL_CI=build/titan2/qualify-n1b-full-ci-readiness.sh
```

## Panther-grade strict CI security baseline

N1B must not weaken the Pixel/Panther code-quality, security, or performance
standard. Phase 07 readiness therefore requires the full CI plan to include the
same class of gates used for Panther validation before any Phase 08 image-build
candidate can be considered.

```text
N1B_FULL_CI_PANTHER_GRADE_STRICT_CI_REQUIRED=YES
N1B_FULL_CI_NO_SECURITY_REGRESSION_FROM_PANTHER=YES
N1B_FULL_CI_NO_PERFORMANCE_REGRESSION_FROM_PANTHER=YES
N1B_FULL_CI_FAIL_CLOSED_ON_MISSING_SECURITY_TOOLS=YES
N1B_FULL_CI_FAIL_CLOSED_ON_LINT_FAILURES=YES
N1B_FULL_CI_FAIL_CLOSED_ON_STATIC_ANALYSIS_FAILURES=YES
```

Required strict CI categories:

```text
N1B_STRICT_CI_ANDROID_LINT_REQUIRED=YES
N1B_STRICT_CI_KOTLIN_LINT_REQUIRED=YES
N1B_STRICT_CI_KTLINT_OR_EQUIVALENT_REQUIRED=YES
N1B_STRICT_CI_SHELLCHECK_OR_BASH_SYNTAX_REQUIRED=YES
N1B_STRICT_CI_PYTHON_COMPILE_REQUIRED=YES
N1B_STRICT_CI_GRADLE_UNIT_TESTS_REQUIRED=YES
N1B_STRICT_CI_GRADLE_ASSEMBLE_REQUIRED=YES
N1B_STRICT_CI_APK_STATIC_SECURITY_SCAN_REQUIRED=YES
N1B_STRICT_CI_MOBSFSCAN_REQUIRED=YES
N1B_STRICT_CI_MOBSF_OR_MOBSFSCAN_EQUIVALENT_REQUIRED=YES
N1B_STRICT_CI_MANIFEST_PERMISSION_AUDIT_REQUIRED=YES
N1B_STRICT_CI_EXPORTED_COMPONENT_AUDIT_REQUIRED=YES
N1B_STRICT_CI_DEPENDENCY_PROVENANCE_AUDIT_REQUIRED=YES
N1B_STRICT_CI_NO_DEBUG_RELEASE_ARTIFACT_REQUIRED=YES
N1B_STRICT_CI_NO_NETWORK_FETCH_WITHOUT_AUTHORIZATION=YES
N1B_STRICT_CI_NO_SECRET_OR_SIGNING_KEY_MATERIAL=YES
N1B_STRICT_CI_PERFORMANCE_REGRESSION_REVIEW_REQUIRED=YES
```

The Phase 07 static qualifier only proves that the strict CI plan is bound. The
actual strict CI execution remains a separate run and must fail closed if a
required security scanner such as `mobsfscan`/MobSF-equivalent is unavailable.
Do not treat a missing scanner as a warning for N1B image-candidate promotion.

```text
N1B_MOBSFSCAN_MISSING_IS_FAILURE_FOR_FULL_CI=YES
N1B_LINT_FAILURE_BLOCKS_PHASE_08=YES
N1B_SECURITY_SCAN_FAILURE_BLOCKS_PHASE_08=YES
N1B_PERFORMANCE_REGRESSION_BLOCKS_PHASE_08=YES
```

## N1A and substrate binding

Phase 07 keeps N1B bound to the already qualified N1A/R7E substrate history. It
does not create or modify artifacts.

```text
N1B_FULL_CI_REQUIRES_N1A_SUBSTRATE_EVIDENCE=YES
N1B_FULL_CI_REQUIRES_R7E_ANDROID16_RESTLESS_SUBSTRATE=YES
N1B_FULL_CI_REQUIRES_N0B_DEVIATIONS_RECORDED=YES
N1B_FULL_CI_REQUIRES_N0_N1_FLASH_PLAN_BOUNDARY=YES
```

## Full CI command sequence

When the operator runs the full CI readiness sequence, the intended order is:

```bash
bash build/gates/n1b-sable-host-toolchain-contract.sh .
bash build/gates/n1b-stage-a-fast-lane-contract.sh .
bash build/gates/n1b-phase-execution-contract.sh .
bash build/gates/n1b-sable-identity-static-contract.sh .
bash build/gates/n1b-branding-defaults-contract.sh .
bash build/gates/n1b-setup-launcher-binding-contract.sh .
bash build/gates/n1b-physical-ux-readiness-contract.sh .
bash build/gates/n1b-full-ci-readiness-contract.sh .

bash build/titan2/qualify-n1b-phase-execution.sh
bash build/titan2/qualify-n1b-sable-identity-static.sh
bash build/titan2/qualify-n1b-branding-defaults.sh
bash build/titan2/qualify-n1b-setup-launcher-binding.sh
bash build/titan2/qualify-n1b-physical-ux-readiness.sh
bash build/titan2/qualify-n1b-full-ci-readiness.sh

N1A_EVIDENCE_DIR=/srv/data/sable-build/evidence/titan2/n1a-sable-overlay-stamp-android16-r7e/20260928_000848 \
EVIDENCE_DIR=/srv/data/sable-build/evidence/titan2/n1b-stage-a-fast-lane/<stamp> \
bash build/titan2/qualify-n1b-stage-a-fast-lane-sable-host.sh
```

The app fast-lane build remains apps/static-gates only. It must not be confused
with a system image build.

```text
N1B_STAGE_A_FAST_LANE_BUILD_SCOPE=YES_APPS_AND_STATIC_GATES_ONLY
N1B_FULL_CI_IMAGE_BUILD_SCOPE=NO
N1B_FULL_CI_DEVICE_SCOPE=NO
N1B_FULL_CI_FLASH_SCOPE=NO
```

## Promotion rule

Phase 07 may promote to Phase 08 only as an image-build-candidate readiness
handoff. It does not authorize image construction by itself.

```text
N1B_PHASE_07_PROMOTES_TO_PHASE_08_ONLY=YES
N1B_PHASE_07_DOES_NOT_AUTHORIZE_IMAGE_BUILD=YES
N1B_PHASE_07_DOES_NOT_AUTHORIZE_FLASH=YES
N1B_PHASE_07_DOES_NOT_CONTACT_DEVICE=YES
N1B_PHASE_07_DOES_NOT_CLAIM_PHYSICAL_UX_PASS=YES
N1B_PHASE_07_DOES_NOT_CLAIM_PUBLIC_RELEASE=YES
```

## Expected pass marker

```text
N1B_FULL_CI_READINESS=PASS
```