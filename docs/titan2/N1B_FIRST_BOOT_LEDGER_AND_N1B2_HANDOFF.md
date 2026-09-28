# Titan2 N1B first-boot ledger and N1B2 handoff

## Purpose

This document records the actual Titan2 N1B first-boot path before starting
N1B2. It is a developer reference for future production-build work and a guard
against repeating the mistakes found during the first write.

This record is intentionally written after the real first boot, not as a theory.
It captures what worked, what did not work, and what must be followed before
building or flashing a future Titan2 image.

```text
DEVICE=titan2
RELEASE=N1B
NEXT_RELEASE=N1B2
RECORD_KIND=POST_BOOT_LEDGER_AND_HANDOFF
SOURCE_COMMIT=8dd06e77410fea131e4716447f7f05067e427654
FIRST_BOOT_EVIDENCE_DIR=/srv/data/sable-build/evidence/titan2/n1b-first-boot-smoke/20260928_215855
POST_BOOT_CLOSURE_DIR=/srv/data/sable-build/evidence/titan2/n1b-post-boot-closure/20260928_220049
MUTATION_LEVEL=STATE_CHANGING_FLASH_PLUS_FACTORY_RESET
```

## Source material that must remain binding

Future Titan2 release work must start from these source classes before creating
build, flash, or packaging deliverables:

```text
1. Historical SableOS project chat context and pasted validation logs.
2. aimindseye/sableos current release scripts, gates, docs, and registry state.
3. aimindseye/unihertz-titan2 research, especially:
   - docs/SABLEOS_TREBLE_PORTABILITY_HANDOFF.md
   - docs/SABLEOS_BRINGUP_CONTRACT.md
   - docs/TITAN2_TIER2_RUNBOOK.md
   - docs/TITAN_FAMILY_SABLEOS_RESEARCH_CHECKLIST.md
   - docs/TITAN2_N0_ACCEPTANCE_MATRIX.md
4. sableos-project repositories, especially:
   - sableos-project/build
   - sableos-project/device_sable_titan2
   - sableos-project/platform_sable
   - sableos-project/treble_restlessos
   - sableos-project/platform_manifest
5. Abyss-c0re/atlasos for comparative Titan2 GSI/hybrid-super practice.
6. Current ai-g732 private stock restore images and stock firmware inventory.
```

The AtlasOS repo is reference material, not a product path for SableOS. Its
useful lessons are:

```text
ATLASOS_USAGE=REFERENCE_ONLY_NOT_PRODUCT_PATH
GSI_PLUS_STOCK_VENDOR_BOOT_MODEL=RELEVANT
REGION_MATCHED_STOCK_ZIP_REQUIRED_FOR_HYBRID_SUPER=RELEVANT
WIPE_BASED_CERTIFICATION_MODEL=RELEVANT
DO_NOT_IMPORT_ATLAS_BINARIES_OR_BRANDING=YES
```

## What actually happened

### Artifact written

```text
SYSTEM_IMG=/srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi/target/product/tdgsi_arm64_ab/system.img
SYSTEM_SHA256=bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e
SYSTEM_BYTES=3180666880
TARGET_PARTITION=system_a
ACTIVE_SLOT_BEFORE_FLASH=a
```

### First generic resize failed

The first write-capable attempt resized `system_a` directly using a target size
of `3449815040` bytes and failed:

```text
FAILED_REMOTE=Not enough space to resize partition
ROOT_CAUSE=visible Virtual A/B COW logical partitions consumed allocatable super space
```

Lesson:

```text
DO_NOT_TREAT_SUPER_HEADROOM_AS_IMMEDIATELY_ALLOCATABLE=YES
DO_NOT_TREAT_COW_PARTITIONS_AS_DISPOSABLE_WITHOUT_SNAPSHOT_REVIEW=YES
REQUIRE_CURRENT_FASTBOOTD_LP_STATE=YES
```

### Corrected COW-aware path

The corrected path was possible only after current fastbootd evidence showed:

```text
PRODUCT=Titan_2
IS_USERSPACE=yes
CURRENT_SLOT=a
UNLOCKED=yes
SNAPSHOT_UPDATE_STATUS=none
COW_PARTITIONS_PRESENT=YES
```

The following active-slot COW logical partitions were deleted:

```text
odm_dlkm_a-cow
product_a-cow
system_a-cow
system_dlkm_a-cow
system_ext_a-cow
vendor_a-cow
vendor_dlkm_a-cow
```

Then `system_a` was resized and flashed:

```text
SYSTEM_A_BEFORE_RESIZE_BYTES=756441088
SYSTEM_A_AFTER_RESIZE_BYTES=3449815040
SYSTEM_A_POST_FLASH_BYTES=3180666880
FLASH_RESULT=PASS_SYSTEM_A_WRITTEN
USERDATA_ERASE=NO
AVB_MUTATION=NO
BOOT_VENDOR_VBMETA_FLASH=NO
SLOT_CHANGE=NO
```

### First reboot entered recovery

After flashing `system_a` and rebooting, stock recovery reported that Android
could not be loaded. This was not treated as permission to flash more images or
patch AVB.

The correct next step was to apply the explicit userdata policy that the Titan2
research required to be separate and destructive:

```text
AUTHORIZE_FACTORY_DATA_RESET_ON_TITAN2=YES
DATA_LOSS_ACCEPTED=YES
PURPOSE=first Sable N1B boot after system_a flash
```

### Factory reset booted the image

Factory reset wiped `/data`; it did not restore stock `system_a`. After the
wipe, the flashed N1B image booted.

```text
FACTORY_DATA_RESET_RESULT=PASS
BOOT_COMPLETED=PASS
ADB_AVAILABLE=PASS
VERIFIED_BOOT_STATE=orange
FLASH_LOCKED=0
ACTIVE_SLOT=_a
FIRST_N1B_BOOT=PASS
```

## First-boot evidence summary

The smoke capture recorded:

```text
sys.boot_completed=1
dev.bootcomplete=1
ro.boot.verifiedbootstate=orange
ro.boot.flash.locked=0
ro.boot.slot_suffix=_a
ro.system.build.fingerprint=google/treble_arm64_bvN/tdgsi_arm64_ab:16/BP4A.251205.006/2026092800:userdebug/test-keys
ro.vendor.build.fingerprint=Unihertz/Titan_2/Titan_2:14/UP1A.231005.007/V01.00.13:user/release-keys
```

This proves the first Titan2 alternate-system boot, but it also proves that N1B
is still a generic TrebleDroid/RestlessOS-derived substrate rather than a
SableOS product image.

## Post-boot closure summary

Post-boot closure recorded:

```text
BOOT_COMPLETED=PASS
VERIFIED_BOOT_STATE=orange
ACTIVE_SLOT=_a
HOME=com.android.launcher3/.uioverrides.QuickstepLauncher
DEVICE_NAME=TrebleDroid vanilla
PRODUCT_IDENTITY=GENERIC_TREBLEDROID
STOCK_VENDOR_BASELINE=PRESENT
```

Input enumeration was strong enough for first bring-up:

```text
TITANKEY_ENUMERATED=PASS
TOUCHPAD_ENUMERATED=PASS
SYNAPTICS_DSX_I2C_ENUMERATED=PASS
GPIO_KEYS_ENUMERATED=PASS
```

Display enumeration was strong enough for first bring-up:

```text
PRIMARY_DISPLAY=1440x1440
REAR_DISPLAY=410x502
MULTI_DISPLAY_PRESENT=PASS
```

Connectivity was not product-pass:

```text
WIFI_PRESENT_BUT_DISABLED=YES
BLUETOOTH_PRESENT_BUT_DISABLED=YES
TELEPHONY_LTE_SERVICE_TRANSITIONS_OBSERVED=YES
TELEPHONY_STABILITY=PARTIAL
```

## Correct classification

```text
FIRST_N1B_BOOT=PASS
FIRST_N1B_MINIMUM_HARDWARE_ENUMERATION=PASS
FACTORY_RESET_REQUIRED=YES_CONFIRMED
N1B_PRODUCT_CLOSURE=FAIL
N1B_DAILY_DRIVER=NO
RESTORE_STOCK_NOW=NO
NEXT_WORK=N1B2_PRODUCT_IDENTITY_AND_TITAN_PROFILE_CLOSURE
```

N1B is a successful Titan2 Treble bring-up substrate. It is not a production
SableOS build.

## Required N1B2 scope

N1B2 must start by closing product identity and Titan2 profile gaps, not by
changing more partitions.

```text
N1B2_REQUIRED_WORK:
  - Sable product identity and device name.
  - Visible Sable branding and removal of user-visible RestlessOS/TrebleDroid placeholders.
  - HOME resolution to the intended Sable launcher or SableStart path.
  - Titan2 keyboard profile instead of Generic.kl / Generic.kcm defaults where appropriate.
  - Titan2 touchPad profile and pointer/touch behavior policy.
  - Preservation of stock vendor/kernel/firmware strategy.
  - Explicit first-boot userdata wipe policy for Titan2 GSI deployment.
  - First-boot acceptance script using the proven evidence shape.
```

N1B2 must not claim daily-driver status until at least these areas are captured:

```text
N1B2_DAILY_DRIVER_BLOCKERS:
  - telephony stability and IMS behavior;
  - Wi-Fi enable/connect behavior;
  - Bluetooth enable/pair behavior;
  - keyboard key event capture and text-entry behavior;
  - touchPad behavior;
  - primary display/touch usability across Sable apps;
  - rear display ownership and behavior;
  - camera, fingerprint, NFC, sensors, audio, suspend/power smoke evidence;
  - restore path validation after N1B2.
```

## Mandatory workflows for future Titan2 production builds

### Before building

```text
SOURCE_MAP_REVIEWED=YES
HISTORICAL_CHAT_CONTEXT_REVIEWED=YES_OR_SCOPE_LIMITED_AND_DECLARED
UNIHERTZ_TITAN2_REPO_REVIEWED=YES
DEVICE_SABLE_TITAN2_REPO_REVIEWED=YES
SABLEOS_PROJECT_BUILD_REPO_REVIEWED=YES
ATLASOS_REVIEWED_AS_REFERENCE_ONLY=YES
CURRENT_BOOT_EVIDENCE_REVIEWED=YES
STOCK_RESTORE_IMAGES_ON_AI_G732_CONFIRMED=YES
```

### Before flashing

```text
RESTORE_PATH_VERIFIED=YES
ARTIFACT_SHA256=RECORDED
ARTIFACT_LOGICAL_BYTES=RECORDED
DEVICE_SERIAL_BOUND=YES
ACTIVE_SLOT_RECORDED=YES
FASTBOOTD_VERIFIED_BY_GETVAR_IS_USERSPACE_YES=YES
SNAPSHOT_UPDATE_STATUS=none
LOGICAL_PARTITION_FIT_VALIDATED=YES
LP_ACTION=direct-flash|reviewed-resize|reviewed-cow-cleanup-plus-resize
AVB_ACTION=explicit-none|explicit-reviewed-change
USERDATA_POLICY=preserve|explicit-wipe-approved
FLASH_COMMANDS_REVIEWED=YES
```

### Write boundaries

```text
NO_PIXEL_OR_PANTHER_FLASH_ASSUMPTIONS=YES
NO_IMPLICIT_USERDATA_WIPE=YES
NO_UNREVIEWED_COW_DELETE=YES
NO_UNREVIEWED_LP_RESIZE=YES
NO_RANDOM_VBMETA_OR_AVB_PATCHING=YES
NO_SLOT_CHANGE_UNLESS_REVIEWED=YES
NO_BOOT_VENDOR_BOOT_OR_VBMETA_FLASH_UNLESS_REVIEWED=YES
NO_BOOTLOADER_RELOCK=YES
NO_PUBLIC_RELEASE_OR_PRODUCTION_SIGNING_FROM_BRINGUP=YES
```

### After first boot

```text
CAPTURE_BOOT_COMPLETED=YES
CAPTURE_ADB_AVAILABILITY=YES
CAPTURE_VERIFIED_BOOT_STATE=YES
CAPTURE_ACTIVE_SLOT=YES
CAPTURE_PRODUCT_IDENTITY=YES
CAPTURE_HOME_RESOLUTION=YES
CAPTURE_INPUT_ENUMERATION=YES
CAPTURE_DISPLAY_ENUMERATION=YES
CAPTURE_SERVICE_INVENTORY=YES
CAPTURE_TELEPHONY_SUMMARY_WITH_PRIVATE_IDENTIFIERS_REDACTED=YES
```

## Stock images and proprietary material policy

The stock firmware and restore images on ai-g732 are valid private restore and
packaging inputs, but they must remain governed by provenance and licensing
rules.

```text
STOCK_IMAGES_ON_AI_G732=AVAILABLE_FOR_PRIVATE_RESTORE_AND_LOCAL_PACKAGING_IF_NEEDED
COMMIT_STOCK_IMAGES_TO_GIT=NO
COMMIT_EXTRACTED_PROPRIETARY_BINARIES=NO
PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW
RESTORE_USE=YES
LOCAL_HYBRID_PACKAGING_USE=YES_IF_GATED_AND_NOT_PUBLISHED
```

For N1B2, stock images may be used locally to inspect/compare or to package a
private hybrid artifact if a separate gate authorizes that approach. They must
not be silently added to public or project repositories.

## What not to do again

```text
DO_NOT_CREATE_PR_TO_REVIEW_ONLY_THE_PREVIOUS_PR=YES
DO_NOT_SKIP_REPO_REVIEW_BECAUSE_LOCAL_EVIDENCE_LOOKS_SUFFICIENT=YES
DO_NOT_TREAT_PHASE_DRAFTS_AS_EXECUTION_READY=YES
DO_NOT_TREAT_FIRST_BOOT_AS_PRODUCT_COMPLETION=YES
DO_NOT_IGNORE_ATLASOS_OR_TITAN2_HANDOFF_WHEN FLASHING=YES
DO_NOT_REUSE_PANTHER_PRESERVED_DATA_ASSUMPTIONS_ON_TITAN2=YES
```

## N1B2 go/no-go

N1B2 build work may start only after this ledger is merged and the gate below
passes:

```text
N1B_FIRST_BOOT_LEDGER=PASS
N1B2_HANDOFF_RECORDED=PASS
N1B2_BUILD_ALLOWED=YES_AFTER_LEDGER_MERGE
N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED
```