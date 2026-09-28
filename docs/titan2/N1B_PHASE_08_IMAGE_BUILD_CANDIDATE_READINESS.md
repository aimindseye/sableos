# N1B Phase 08 image-build-candidate readiness

Status: **Phase 08 readiness gate / no build script yet**

This document is the evidence handoff from Phase 07 full local CI into the
future N1B image-build-candidate script. It does not build an image, does not
contact Titan 2 hardware, does not run ADB or fastboot, does not flash, and does
not create a public release or production-signing claim.

```text
N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS=YES
N1B_PHASE=08
N1B_PHASE_NAME=N1B_IMAGE_BUILD_CANDIDATE
SOURCE_MUTATION_AUTHORIZED=NO for gate execution
BUILD_AUTHORIZED=NO for this readiness qualifier
IMAGE_BUILD_AUTHORIZED=NO for this readiness qualifier
IMAGE_BUILD_SCRIPT_AUTHORIZED_BY_THIS_DOC=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Source review basis

Phase 08 is derived from four evidence surfaces:

```text
PREVIOUS_SABLEOS_CHAT_HISTORY_REVIEWED=YES
UNIHERTZ_TITAN2_RESEARCH_REVIEWED=YES
SABLEOS_PROJECT_REPOS_REVIEWED=YES
AIMINDSEYE_SABLEOS_REVIEWED=YES
```

Important source conclusions:

```text
TITAN2_RESEARCH_STATUS=COMPLETE_FOR_FIRST_SABLE_ARTIFACT
TITAN2_NO_BROAD_RESEARCH_REOPEN=YES
TITAN2_TREBLE_PORTABILITY_LANE=YES
PANTHER_PIXEL_FLASH_ASSUMPTIONS_ALLOWED=NO
PANTHER_ARTIFACT_FLASH_TO_TITAN2_ALLOWED=NO
FIRST_SABLE_BOOT=NOT_RUN
```

## Phase 07 full local CI binding

Phase 08 planning starts only because the Panther-grade full local CI profile
passed in Titan2/N1B context.

```text
N1B_FULL_LOCAL_CI=PASS
N1B_FULL_LOCAL_CI_PROFILE=full
N1B_FULL_LOCAL_CI_SOURCE_COMMIT=1bedaaf49cb82b215b95c5bf9e3b47a41710b659
N1B_FULL_LOCAL_CI_EVIDENCE_DIR=/srv/data/sable-build/sableos/local-ci-evidence/20260928T143234Z-1bedaaf49cb8-full
```

Any future image-build script or build-driver mutation must either:

```text
N1B_PHASE_08_BUILD_SCRIPT_REQUIRES_CURRENT_HEAD_FULL_CI=YES
```

or record a reviewed exception that the delta is documentation/contract-only and
not in the build path. The first image-build script should require a current
full-CI pass for the source commit it actually builds.

## Build-stage lesson carried forward

Phase 08 belongs to the `N1-SABLE` stage from the Titan 2 / MediaTek GSI stage
ledger.

```text
N1B_PHASE_08_STAGE=N1_SABLE
N0_AOSP_CONTROL_IS_NOT_THE_IMAGE_TARGET=YES
N0B_TREBLE_RESTLESS_BASELINE_REQUIRED=YES
N1_SABLE_OVERLAY_STAGE_REQUIRED=YES
N2_TITAN2_PHYSICAL_VALIDATION_LATER=YES
```

Use a dedicated output directory for the N1B Sable product graph. Do not reuse
N0-AOSP or N0B-Restless output directories for the Sable overlay image.

```text
N1B_PHASE_08_OUT_DIR_DEDICATED=YES
N1B_PHASE_08_OUT_DIR_SUGGESTED=out_sable_t2_n1b_sable_gsi
```

Each Phase 08 build run must end with:

```text
MANIFEST_SNAPSHOT_REQUIRED=YES
PATCH_QUEUE_SNAPSHOT_REQUIRED=YES
ARTIFACT_PATH_REQUIRED=YES
ARTIFACT_SIZE_REQUIRED=YES
ARTIFACT_SHA256_REQUIRED=YES
BUILD_RESULT_REQUIRED=YES
KNOWN_LIMITATIONS_REQUIRED=YES
NEXT_STAGE_HANDOFF_REQUIRED=YES
```

## Active product graph requirement

The N1A lesson is binding for Phase 08. Product discovery is not payload
injection.

```text
ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk
PRODUCT_NAME=treble_arm64_bvN
PRODUCT_DEVICE=tdgsi_arm64_ab
ANDROID_PRODUCTS_MK_IS_NOT_PAYLOAD_OWNER=YES
ACTIVE_PRODUCT_GRAPH_REQUIRED=YES
```

The future build script must verify that Sable overlay/product payload injection
is inherited by the active product makefile before it builds target-files or
system.img. A marker that only appears in `AndroidProducts.mk` is insufficient.

## Substrate and RestlessOS constraints

Phase 08 remains Android 16 / R7E-based. Android 17 N0C remains a parallel
research lane and is not a baseline pivot.

```text
ANDROID_RELEASE=16
ANDROID_VERSION_TAG=bp4a
BUILD_ID=BP4A.251205.006
AOSP_REVISION=android-16.0.0_r4
BASELINE=N0B_R7E_RESTLESS_INTERNAL_CANDIDATE
R7E_STATUS=PASS
ANDROID17_BASELINE_PIVOT=NO
N0C_ANDROID17_PARALLEL_RESEARCH=YES
```

R7E deviations must stay visible in every Phase 08 evidence package:

```text
GOODIX_PATCH_SKIPPED=YES
PLATFORM_TESTING_GATE=Android.bp_placeholder_from_R7D
TREBLEAPP_DEXPREOPT_DISABLED=YES
```

Phase 08 must not claim GrapheneOS-equivalent security, RestlessOS-equivalent
security, or production reproducibility.

```text
GRAPHENEOS_EQUIVALENT_SECURITY_CLAIM=NO
RESTLESSOS_EQUIVALENT_SECURITY_CLAIM=NO
PRODUCTION_REPRODUCIBILITY_CLAIM=NO
PRIVATE_SOURCE_ALLOWED=NO
PRIVATE_SIGNING_KEYS_ALLOWED=NO
PUBLIC_RELEASE=NO
```

## Titan 2 image boundary

The Phase 08 candidate is a Sable-owned GSI/system image candidate only. It must
preserve the stock MediaTek kernel/vendor/firmware stack until physical evidence
requires a reviewed exception.

```text
ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
PRESERVE_BOOT=YES
PRESERVE_INIT_BOOT=YES
PRESERVE_VENDOR_BOOT=YES
PRESERVE_DTBO=YES
PRESERVE_VENDOR=YES
PRESERVE_VENDOR_DLKM=YES
PRESERVE_ODM_DLKM=YES
PRESERVE_VBMETA_VENDOR=YES
PRESERVE_MODEM_AND_MTK_FIRMWARE=YES
BOOT_IMAGE_PATCHING_ALLOWED=NO
KERNEL_PATCHING_ALLOWED=NO
BLIND_SEPOLICY_ALLOW_RULES_ALLOWED=NO
PERMISSIVE_SELINUX_ALLOWED=NO
```

Do not include Titan-specific daemons or runtime hacks in the first N1B image
candidate.

```text
TITAN_TOUCHPAD_DAEMON_ENABLED=NO
CUSTOM_UINPUT_DAEMON_SEPOLICY=NO
UNVALIDATED_KEYLAYOUT_MUTATION=NO
KEYBOARD_BACKLIGHT_RUNTIME_CONTROL_UNLESS_VALIDATED=NO
SUBSCREEN_ACTIVE_RUNTIME_UNLESS_VALIDATED=NO
GPLV3_PREBUILT_WITHOUT_LICENSE_REVIEW=NO
```

## N1B user-facing scope binding

The image candidate must remain a keyboard-first SableOS system experience
candidate, not only an app bundle.

Required user-facing scope inherited from the N1B beta image scope:

```text
SETUP_WIZARD_FIRST_BOOT_REQUIRED=YES
LOCKSCREEN_SECURE_ENTRY_REQUIRED=YES
QUICK_SETTINGS_SHADE_REQUIRED=YES
SABLE_START_HOME_REQUIRED=YES
ALL_APPS_PRIVACY_SUMMARY_REQUIRED=YES
SABLE_COMMAND_SEARCH_REQUIRED=YES
SABLE_HUB_MESSAGES_MAIL_PEOPLE_REQUIRED=YES
PHONE_CONTACTS_MESSAGES_REQUIRED=YES
MAIL_CALENDAR_REQUIRED=YES
BROWSER_WEBVIEW_IDENTITY_REQUIRED=YES
READER_TEXT_READER_REQUIRED=YES
MEDIA_GALLERY_REQUIRED=YES
SETTINGS_PROFILE_POLICY_SURFACES_REQUIRED=YES
```

Required first-run and keyboard-first behavior:

```text
KEYBOARD_FIRST_ONBOARDING_REQUIRED=YES
PHYSICAL_KEYBOARD_VERIFICATION_REQUIRED=YES
CRITICAL_TEXT_ENTRY_GATE_REQUIRED=YES
SOFTWARE_KEYBOARD_FALLBACK_REQUIRED=YES
ALT_SYM_FN_TEXT_ENTRY_REQUIRED=YES
WIFI_PASSWORD_ENTRY_REQUIRED=YES
LOCK_METHOD_SETUP_REQUIRED=YES
NO_SETUP_DEAD_ENDS_REQUIRED=YES
```

## Artifact qualification requirements

The future build script must create an evidence package before registration.
Minimum required fields:

```text
SYSTEM_IMG_PATH=REQUIRED
SYSTEM_IMG_SHA256=REQUIRED
SYSTEM_IMG_BYTES=REQUIRED
SYSTEM_IMG_LOGICAL_BYTES=REQUIRED
SYSTEM_IMG_FORMAT=sparse|raw REQUIRED
TARGET_FILES_ZIP=REQUIRED
TARGET_FILES_SHA256=REQUIRED
ANDROID_INFO_TXT=REQUIRED_IF_TARGET_FILES
BUILD_PROP_IDENTITY_CAPTURE=REQUIRED
TARGET_FILES_SABLE_MARKER=REQUIRED
ACTIVE_PRODUCT_GRAPH_EVIDENCE=REQUIRED
```

The artifact must then be registered only through the central entrypoint:

```text
REGISTER_ENTRYPOINT=build/sable.sh titan2 N1B register-artifact
ARTIFACT_KIND_REQUIRED=gsi-system-image
PRIMARY_ARTIFACT_REQUIRED=system
BUILD_EVIDENCE_DIR_REQUIRED=YES
```

The Titan2 adapter may accept artifact registration and ledger-only flash-plan
preparation, but flash execution remains blocked.

```text
TITAN2_ARTIFACT_REGISTRATION_ALLOWED=YES
TITAN2_FLASH_PLAN_LEDGER_ALLOWED=YES
TITAN2_FLASH_EXECUTION_SUPPORTED=NO
TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO
```

## Flash and device boundary

Phase 08 image build does not authorize device contact or flashing.

```text
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
FASTBOOT_BOOT=UNSUPPORTED
DSU=UNAVAILABLE_ON_TESTED_STOCK_BUILD
FASTBOOTD=SUPPORTED_BUT_NOT_USED_BY_PHASE_08
```

No write-capable command sequence may be created until the N0/N1 ledger fields
are filled from current evidence and reviewed:

```text
RESTORE_REPORT=REQUIRED_BEFORE_FLASH
BOOTLOADER_PREFLIGHT=REQUIRED_BEFORE_FLASH
FASTBOOTD_PREFLIGHT=REQUIRED_BEFORE_FLASH
SNAPSHOT_UPDATE_STATUS=none REQUIRED_BEFORE_FLASH
ARTIFACT_SHA256=REQUIRED_BEFORE_FLASH
ARTIFACT_LOGICAL_BYTES=REQUIRED_BEFORE_FLASH
SYSTEM_CURRENT_BYTES=REQUIRED_BEFORE_FLASH
LP_ACTION=direct-flash|reviewed-resize REQUIRED_BEFORE_FLASH
AVB_ACTION=REQUIRED_BEFORE_FLASH
USERDATA_POLICY=preserve|explicit-wipe-approved REQUIRED_BEFORE_FLASH
EXPLICIT_TITAN_SERIAL=REQUIRED_BEFORE_FLASH
ACTIVE_SLOT=REQUIRED_BEFORE_FLASH
STOCK_BASELINE=REQUIRED_BEFORE_FLASH
RESTORE_PATH_VERIFIED=REQUIRED_BEFORE_FLASH
```

A userdata wipe must never be implicit.

```text
USERDATA_WIPE_IMPLICIT_ALLOWED=NO
USERDATA_WIPE_REQUIRES_EXPLICIT_APPROVAL=YES
```

## Phase 08 promotion rule

Phase 08 may produce and register a local internal N1B image candidate only after
the Phase 08 readiness gate passes and the operator explicitly runs the future
image-build script. It may not promote to physical flash, public release, or
production signing.

```text
N1B_PHASE_08_PROMOTES_TO_IMAGE_CANDIDATE_ONLY=YES
N1B_PHASE_08_DOES_NOT_AUTHORIZE_FLASH=YES
N1B_PHASE_08_DOES_NOT_CONTACT_DEVICE=YES
N1B_PHASE_08_DOES_NOT_CLAIM_PHYSICAL_UX_PASS=YES
N1B_PHASE_08_DOES_NOT_CLAIM_PUBLIC_RELEASE=YES
N1B_PHASE_08_DOES_NOT_CLAIM_PRODUCTION_SIGNING=YES
```

## Acceptance

```text
N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS=PASS
N1B_PHASE_08_SOURCE_REVIEW=PASS
N1B_PHASE_08_FULL_CI_BINDING=PASS
N1B_PHASE_08_ACTIVE_PRODUCT_GRAPH_BOUND=PASS
N1B_PHASE_08_RESTLESS_R7E_BOUND=PASS
N1B_PHASE_08_TITAN_IMAGE_BOUNDARY=PASS
N1B_PHASE_08_ARTIFACT_QUALIFICATION_BOUND=PASS
N1B_PHASE_08_FLASH_BOUNDARY=PASS
```
