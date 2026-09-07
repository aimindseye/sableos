# Panther D3-R3 read-only slot-success evidence

Date: 2026-09-07

Purpose: close the bootloader-authoritative success state for the already booted D3 slot B and return to Android without mutation.

Evidence directory from the validated run:

```text
/tmp/PANTHER_P1B_C2R33_D3_R3_SLOT_SUCCESS_20260907_084012
```

Authorization / mutation boundary:

```text
DEVICE_CONTACT_AUTHORIZED=YES_D3_R3_READ_ONLY_SLOT_SUCCESS_CLOSURE
FLASH_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_REBOOT_TO_BOOTLOADER_AUTHORIZED=YES_ONE
DEVICE_REBOOT_TO_ANDROID_AUTHORIZED=YES_ONE
SLOT_CHANGE_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
UPDATE_SUPER_AUTHORIZED=NO
SNAPSHOT_CANCEL_AUTHORIZED=NO
```

## R2B deployment binding

```text
flash_results.tsv
3337f0d906ba30f2380a92b8040856b050fac090ee6a3910e6d5629a3784a1f8

vendor_boot_a_post.img
84fb46744cbe67e9a2dd67e67551fa2ebaa27d046ee587e58dd063a9bb9758a6

r2b_successful_flash_count=3
r2b_successful_flash_order=system_b,product_b,vbmeta_b
D3_R2B_SUCCESS_BINDING=PASS
```

## Pre-reboot Android identity

```text
sys.boot_completed=1
ro.boot.slot_suffix=_b
ro.build.id=CP2A.260705.006
ro.build.version.incremental=2026090500
ro.build.fingerprint=google/panther/panther:17/CP2A.260705.006/2026090500:userdebug/test-keys
ro.crypto.state=encrypted
ro.boot.verifiedbootstate=orange

SetupWizard2.apk
341850ebc00aa605a4b22e17659d6438401d70d061a8bae843be8d64da943548

Settings.apk
04ea22f0b10bf02446463a8bb0a8ec4f7c4c12537f3794f45ed65445be648ef4

PRODUCT generated RRO
ffe8678bb5c8a009ee5d029138102ea0d39fa5ea781e0404e310f25b5f256306

framework fallback mask
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e

PRE_ANDROID_D3_IDENTITY=PASS
```

`verifiedbootstate=orange` is expected for this unlocked development/test device and is not classified as a D3 failure.

## Bootloader-authoritative state

Exactly one authorized Android-to-bootloader reboot was performed. The bootloader reported:

```text
product=panther
is_userspace=no
current_slot=b
snapshot_update_status=none
unlocked=yes

slot_a_successful=yes
slot_a_unbootable=no
slot_a_retry=2

slot_b_successful=yes
slot_b_unbootable=no
slot_b_retry=2
```

Read-only slot-A rollback-anchor fetch:

```text
vendor_boot_a_r3_sha256=
84fb46744cbe67e9a2dd67e67551fa2ebaa27d046ee587e58dd063a9bb9758a6
```

Closure markers:

```text
PANTHER_D3_SLOT_B_BOOTLOADER_SUCCESS=PASS
GRAPHENE_CONTROL_SLOT_A_ROLLBACK_ANCHOR=PASS
DUAL_KNOWN_GOOD_SLOTS=PASS
```

## Return to Android

Exactly one authorized bootloader-to-Android reboot was performed. The returned system again proved the same D3 runtime identity, encrypted shared data, SetupWizard2/Settings identities, generated PRODUCT RRO and framework Sable mask.

```text
D3_R3_RETURN_TO_ANDROID=PASS
D3_SLOT_B_BOOTLOADER_SUCCESS=PASS
DUAL_KNOWN_GOOD_SLOTS=PASS
D3_RUNTIME_IDENTITY_AFTER_RETURN=PASS
C2R33_D3_R3_gate_rc=0
```

Final result:

```text
PANTHER_P1B_C2R33_D3_R3_RESULT=
PASS_D3_SLOT_B_BOOTLOADER_SUCCESS_AND_ANDROID_RETURN

FLASH=NONE
SLOT_CHANGE=NONE
SOURCE_MUTATION=NONE
BUILD=NONE
POST_FINALIZATION_SEAL=PASS
SSH_TMUX_SHELL_STILL_ALIVE=PASS
```

## Evidence hashes visible in the finalized run output

```text
pre_framework-res.apk
c39bdb2d9d7b90d2d4ae9212f5ac78fc24032ef3fc5f0c6aa09227de7ad12bad

pre_android-logo-mask.png
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e

post_framework-res.apk
c39bdb2d9d7b90d2d4ae9212f5ac78fc24032ef3fc5f0c6aa09227de7ad12bad

post_android-logo-mask.png
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e

summary.txt
77179850c91811cccd23867699a27a3a7ce4080298a3daee1d72a5286583c75d

R2B flash_results.tsv
3337f0d906ba30f2380a92b8040856b050fac090ee6a3910e6d5629a3784a1f8

R2B vendor_boot_a_post.img
84fb46744cbe67e9a2dd67e67551fa2ebaa27d046ee587e58dd063a9bb9758a6
```

This document records only hashes and lines present in the supplied finalized R3 output; it does not infer omitted evidence-seal lines.
