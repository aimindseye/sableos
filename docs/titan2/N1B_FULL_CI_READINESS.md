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

## Recovered Panther / Pixel CI baseline

N1B must use the same strict local-CI class used for Pixel/Panther work before
SableOS stopped building Panther images. The historical CI source is the local
runner and policy set under:

```text
PANTHER_LOCAL_CI_RUNNER=build/local-ci/run.sh
PANTHER_CI_POLICY=build/check-ci-policy.py
PANTHER_PRE_PUSH_GUARD=.githooks/pre-push
PANTHER_HOST_TOOLS_ENV=build/config/r8-host-tools.env
PANTHER_GRADLE_SUPPLY_CHAIN_GATE=build/check-gradle-supply-chain.py
```

Recovered CI behavior that N1B inherits:

```text
N1B_FULL_CI_REUSES_PANTHER_LOCAL_CI_PROFILE=YES
N1B_FULL_CI_LOCAL_DIRECT_EXECUTION_REQUIRED=YES
N1B_FULL_CI_GITHUB_ACTIONS_DISABLED_REQUIRED=YES
N1B_FULL_CI_SELF_HOSTED_ACTIONS_DISABLED_REQUIRED=YES
N1B_FULL_CI_FULL_OR_RELEASE_ATTESTATION_REQUIRED=YES
N1B_FULL_CI_DIRTY_SOURCE_BLOCKS=YES
N1B_FULL_CI_NETWORK_FETCH_DEFAULT_NO=YES
N1B_FULL_CI_PINNED_HOST_TOOLS_REQUIRED=YES
N1B_FULL_CI_SHARED_SECURITY_TOOLS_REQUIRED=YES
```

The required local-CI stage set is:

```text
N1B_LOCAL_CI_STAGE_POLICY_REQUIRED=YES
N1B_LOCAL_CI_STAGE_STATIC_REQUIRED=YES
N1B_LOCAL_CI_STAGE_RUST_REQUIRED=YES
N1B_LOCAL_CI_STAGE_ANDROID_REQUIRED=YES
N1B_LOCAL_CI_STAGE_APK_SEAL_REQUIRED=YES
N1B_LOCAL_CI_STAGE_QUALITY_REQUIRED=YES
N1B_LOCAL_CI_STAGE_SUPPLY_CHAIN_REQUIRED=YES
N1B_LOCAL_CI_STAGE_SECURITY_REQUIRED=YES
N1B_LOCAL_CI_STAGE_TEXTREADER_REQUIRED=YES
N1B_LOCAL_CI_STAGE_READER_REQUIRED=YES
N1B_LOCAL_CI_STAGE_MAIL_REQUIRED=YES
```

Phase 07 may not promote to Phase 08 until the strict local CI profile succeeds
for the N1B source commit with Titan 2/N1B context:

```bash
SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

The `release` profile remains Panther-only until a Titan 2 image candidate exists
and a separate Titan release-candidate runner is created. Do not use Panther
release-candidate success as a Titan 2 release claim.

```text
N1B_LOCAL_CI_RELEASE_PROFILE_BLOCKED_UNTIL_TITAN_RUNNER_EXISTS=YES
N1B_PANTHER_RELEASE_CANDIDATE_NOT_TITAN_RELEASE_CANDIDATE=YES
```

## Panther-grade strict CI security baseline

N1B must not weaken the Pixel/Panther code-quality, security, privacy, or
performance standard. Phase 07 readiness therefore requires the full CI plan to
include the same class of gates used for Panther validation before any Phase 08
image-build candidate can be considered.

```text
N1B_FULL_CI_PANTHER_GRADE_STRICT_CI_REQUIRED=YES
N1B_FULL_CI_NO_SECURITY_REGRESSION_FROM_PANTHER=YES
N1B_FULL_CI_NO_PRIVACY_REGRESSION_FROM_PANTHER=YES
N1B_FULL_CI_NO_PERFORMANCE_REGRESSION_FROM_PANTHER=YES
N1B_FULL_CI_FAIL_CLOSED_ON_MISSING_SECURITY_TOOLS=YES
N1B_FULL_CI_FAIL_CLOSED_ON_LINT_FAILURES=YES
N1B_FULL_CI_FAIL_CLOSED_ON_STATIC_ANALYSIS_FAILURES=YES
```

Required strict CI categories:

```text
N1B_STRICT_CI_ANDROID_LINT_REQUIRED=YES
N1B_STRICT_CI_KOTLIN_LINT_REQUIRED=YES
N1B_STRICT_CI_DETEKT_REQUIRED=YES
N1B_STRICT_CI_KTLINT_OR_EQUIVALENT_REQUIRED=YES
N1B_STRICT_CI_SHELLCHECK_OR_BASH_SYNTAX_REQUIRED=YES
N1B_STRICT_CI_PYTHON_COMPILE_REQUIRED=YES
N1B_STRICT_CI_STATIC_CONTRACTS_REQUIRED=YES
N1B_STRICT_CI_RUST_FMT_REQUIRED=YES
N1B_STRICT_CI_RUST_CLIPPY_DENY_WARNINGS_REQUIRED=YES
N1B_STRICT_CI_RUST_TESTS_REQUIRED=YES
N1B_STRICT_CI_GRADLE_UNIT_TESTS_REQUIRED=YES
N1B_STRICT_CI_GRADLE_ASSEMBLE_REQUIRED=YES
N1B_STRICT_CI_APK_SEAL_REQUIRED=YES
N1B_STRICT_CI_APK_STATIC_SECURITY_SCAN_REQUIRED=YES
N1B_STRICT_CI_MOBSFSCAN_REQUIRED=YES
N1B_STRICT_CI_MOBSF_OR_MOBSFSCAN_EQUIVALENT_REQUIRED=YES
N1B_STRICT_CI_GITLEAKS_REQUIRED=YES
N1B_STRICT_CI_CARGO_AUDIT_REQUIRED=YES
N1B_STRICT_CI_CARGO_DENY_REQUIRED=YES
N1B_STRICT_CI_COVERAGE_EVIDENCE_REQUIRED=YES
N1B_STRICT_CI_MANIFEST_PERMISSION_AUDIT_REQUIRED=YES
N1B_STRICT_CI_EXPORTED_COMPONENT_AUDIT_REQUIRED=YES
N1B_STRICT_CI_DEPENDENCY_PROVENANCE_AUDIT_REQUIRED=YES
N1B_STRICT_CI_GRADLE_VERIFICATION_METADATA_REQUIRED=YES
N1B_STRICT_CI_SUPPLY_CHAIN_EVIDENCE_REQUIRED=YES
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
N1B_STATIC_ANALYSIS_FAILURE_BLOCKS_PHASE_08=YES
N1B_SECURITY_SCAN_FAILURE_BLOCKS_PHASE_08=YES
N1B_SUPPLY_CHAIN_FAILURE_BLOCKS_PHASE_08=YES
N1B_PERFORMANCE_REGRESSION_BLOCKS_PHASE_08=YES
```

## RestlessOS substrate security and privacy review

Titan 2 N1B currently depends on an Android 16 Restless/Treble substrate, not the
same Panther GrapheneOS Pixel product path. N1B must not claim GrapheneOS
security properties unless they are proven by source and artifact evidence.

```text
N1B_RESTLESS_SUBSTRATE_SECURITY_REVIEW_REQUIRED=YES
N1B_RESTLESS_NO_GRAPHENEOS_EQUIVALENT_SECURITY_CLAIM=YES
N1B_RESTLESS_PUBLIC_ONLY_SOURCE_REQUIRED=YES
N1B_RESTLESS_PRIVATE_SOURCE_ALLOWED=NO
N1B_RESTLESS_PRIVATE_SIGNING_KEYS_ALLOWED=NO
N1B_RESTLESS_PRIVATE_MAINTAINER_DEPENDENCY_REMOVED=YES
N1B_RESTLESS_PINNED_TAGS_REQUIRED=YES
N1B_RESTLESS_PINNED_MANIFEST_REQUIRED=YES
N1B_RESTLESS_REPO_MANIFEST_R_REQUIRED=YES
N1B_RESTLESS_PATCH_TIERS_FROM_PINNED_TAG_REQUIRED=YES
N1B_RESTLESS_PATCH_DEVIATIONS_RECORDED=YES
N1B_RESTLESS_BUILD_IDENTITY_CAPTURE_REQUIRED=YES
N1B_RESTLESS_TARGET_FILES_AND_SYSTEM_IMAGE_SHA256_REQUIRED=YES
```

Before Phase 08 image-candidate promotion, Restless substrate review must include
artifact and tree-comparison gates. These are intended to reduce backdoor and
unknown-delta risk when using a less independently reviewed upstream base.

```text
N1B_RESTLESS_IMAGE_TREE_COMPARISON_REQUIRED=YES
N1B_RESTLESS_NATIVE_BINARY_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_INIT_RC_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_SELINUX_POLICY_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_VINTF_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_LINKER_CONFIG_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_PERMISSION_XML_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_SYSCONFIG_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_PRIVAPP_PERMISSION_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_OVERLAY_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_BUILD_PROP_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_ODex_VDEX_ART_DIFF_BLOCKS_PHASE_08=YES
N1B_RESTLESS_APN_PIN_OR_DIFF_REVIEW_REQUIRED=YES
N1B_RESTLESS_UNEXPLAINED_FILE_ADDITION_REMOVAL_BLOCKS_PHASE_08=YES
```

Allowed differences must remain narrow and documented, for example signing
metadata, certificate hex where expected, and filesystem metadata. Any runtime
file, native library, SELinux, VINTF, permissions, linker, init, overlay, or
priv-app difference requires explicit review.

## MediaTek / Titan 2 specific security checks

MediaTek/Titan bring-up needs extra fail-closed checks because the vendor/kernel,
radio, BPF/network policy, input, and secondary-display paths differ from Panther.
These are not a substitute for strict app CI; they are additional device-platform
checks.

```text
N1B_MTK_SECURITY_REVIEW_REQUIRED=YES
N1B_MTK_VENDOR_BLOB_PROVENANCE_CAPTURE_REQUIRED=YES
N1B_MTK_VENDOR_API_VNDK_COMPATIBILITY_RECHECK_REQUIRED=YES
N1B_MTK_BOOT_VENDOR_BOOT_RECOVERY_TOPOLOGY_BOUNDARY_REQUIRED=YES
N1B_MTK_AVB_CHAIN_TOPOLOGY_RECHECK_REQUIRED=YES
N1B_MTK_NO_BOOT_KERNEL_PATCH_WITHOUT_PHYSICAL_EVIDENCE=YES
N1B_MTK_BPF_NETD_FIREWALL_EVIDENCE_REQUIRED_BEFORE_DEVICE_PROMOTION=YES
N1B_MTK_SELINUX_ENFORCING_REQUIRED_FOR_PHYSICAL_PROMOTION=YES
N1B_MTK_NO_PERMISSIVE_POLICY=YES
N1B_MTK_NO_BLIND_SEPOLICY_ALLOW_RULES=YES
N1B_MTK_NO_UINPUT_SEPOLICY_WITHOUT_REAL_DENIALS=YES
N1B_MTK_TITAN_INPUT_DAEMONS_EXCLUDED_FROM_N1B_BASELINE=YES
N1B_MTK_TOUCHPAD_BACKLIGHT_REARSCREEN_POST_BASELINE_ONLY=YES
N1B_MTK_GPLV3_PREBUILT_BLOCKED_WITHOUT_LICENSE_REVIEW=YES
N1B_MTK_RADIO_IMS_TELEPHONY_PHYSICAL_VALIDATION_REQUIRED=YES
N1B_MTK_CAMERA_SENSOR_HAL_PHYSICAL_VALIDATION_REQUIRED=YES
N1B_MTK_FINGERPRINT_SENSOR_HAL_PHYSICAL_VALIDATION_REQUIRED=YES
```

These checks do not authorize device contact in Phase 07. They define the
required evidence before physical promotion or Phase 08 image-candidate promotion.

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

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
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

Phase 08 is blocked until all of the following are true:

```text
N1B_PHASE_08_BLOCKED_UNTIL_LOCAL_CI_FULL_PASS=YES
N1B_PHASE_08_BLOCKED_UNTIL_RESTLESS_SECURITY_REVIEW_PASS=YES
N1B_PHASE_08_BLOCKED_UNTIL_MTK_SECURITY_REVIEW_PASS=YES
N1B_PHASE_08_BLOCKED_UNTIL_NO_UNEXPLAINED_SUBSTRATE_DELTAS=YES
```

## Expected pass marker

```text
N1B_FULL_CI_READINESS=PASS
```