# Titan 2 N1A active product graph lesson

Status: current guardrail after N1A overlay-stamp qualification
Device: Titan 2
Release lane: N1 / N1A
Android base: Android 16, `android-16.0.0_r4`, `BP4A.251205.006`

## Summary

The N1A overlay stamp was initially generated and the build completed, but the marker did not appear inside the target-files artifact. The failure was not caused by a missing marker source file or a missing copy rule. The failure was caused by wiring the overlay into the wrong makefile.

Correct owner:

```text
ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk
PRODUCT_NAME=treble_arm64_bvN
PRODUCT_DEVICE=tdgsi_arm64_ab
```

Incorrect owner for product payload injection:

```text
PRODUCT_MK=device/phh/treble/AndroidProducts.mk
```

`AndroidProducts.mk is product discovery`, not the active product inheritance graph for payload inclusion. N1A marker payload must be inherited by the active product makefile for the build target.

## Correct wiring

The active product makefile must contain the Sable N1A overlay inherit next to the rest of the product inheritance chain:

```make
$(call inherit-product, device/phh/treble/base.mk)
$(call inherit-product, device/phh/treble/rom.mk)
# SABLE_N1A_ANDROID16_R7E_OVERLAY_START
$(call inherit-product, vendor/sable/n1_overlay/sable_n1_overlay.mk)
# SABLE_N1A_ANDROID16_R7E_OVERLAY_END

PRODUCT_NAME := treble_arm64_bvN
PRODUCT_DEVICE := tdgsi_arm64_ab
```

The overlay file must own the copy rule:

```make
PRODUCT_COPY_FILES += \
    vendor/sable/n1_overlay/sableos_n1_substrate.env:$(TARGET_COPY_OUT_PRODUCT)/etc/sableos/n1-substrate.env
```

The packaged target-files artifact must contain:

```text
SYSTEM/product/etc/sableos/n1-substrate.env
```

The marker file is a semantic substrate stamp. It must contain at least:

```text
SABLEOS_MILESTONE=N1A
SABLEOS_STAGE=ANDROID16_RESTLESS_R7E_OVERLAY_STAMP
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
PUBLIC_RELEASE=NO
```

Do not require the file itself to contain the result-line string `N1A_SABLE_OVERLAY_STAMP=PASS`. That result belongs to the qualification result, while `sableos_n1_substrate.env` is the packaged substrate identity stamp.

## Required N1A reporting fields

N1A result reporting must distinguish product discovery from the active product graph:

```text
PRODUCT_MK=device/phh/treble/AndroidProducts.mk
ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk
N1A_ACTIVE_PRODUCT_GRAPH_FIX=PASS
N1A_MARKER_FOUND_COUNT=1
N1A_SABLE_OVERLAY_STAMP=PASS
```

Any future N1A script that reports only `PRODUCT_MK=AndroidProducts.mk` is incomplete because it hides the product graph owner that determines whether `PRODUCT_COPY_FILES` participates in target-files packaging.

If the active product makefile contains the overlay inherit and `AndroidProducts.mk` also contains a stale overlay inherit, report the latter as cleanup debt instead of failing the artifact:

```text
N1A_ACTIVE_PRODUCT_OVERLAY_INHERIT=PASS
N1A_ANDROID_PRODUCTS_OVERLAY_INHERIT=WARN_MISPLACED_CLEANUP_REQUIRED
```

Fail only when the active product makefile does not own the overlay inherit.

## Failure classification

Use these classifications for future N1A runs:

```text
N1A_BUILD=PASS
N1A_OVERLAY_SOURCE_EXISTS=PASS
N1A_COPY_RULE_EXISTS=PASS
N1A_PRODUCT_GRAPH_WIRING=FAIL
N1A_MARKER_PACKAGING=FAIL
N1A_STATUS=FAIL_MARKER_NOT_IN_TARGET_FILES
```

when the overlay appears only in `AndroidProducts.mk`.

Use this classification after the active product graph is fixed and the marker appears in target-files:

```text
N1A_BUILD=PASS
N1A_PRODUCT_GRAPH_WIRING=PASS
N1A_MARKER_PACKAGING=PASS
N1A_STATUS=PASS
```

## Flash boundary

N1A can be flashed only after the N0/N1 physical flash-plan metadata is bound and reviewed. N1A does not technically require N1B before flashing, but N1A is a minimal substrate/stamp artifact and is not the preferred first user-facing Titan 2 candidate.

N1B is the preferred first user-facing flash candidate because it should include the Sable branding, setup, keyboard-first UX, core app composition, and Titan 2 validation gates that make the device review meaningful.

Current N1A boundary:

```text
N1A_ARTIFACT_REGISTRATION=PASS
FLASH_EXECUTION_SUPPORTED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
PUBLIC_RELEASE=NO
```

Do not run `flash-plan` until the registered artifact also has:

```text
restore_report
bootloader_preflight
fastbootd_preflight
snapshot_update_status=none
system_current_bytes
lp_action
avb_action
userdata_policy
explicit_titan_serial
active_slot
stock_baseline
restore_path_verified
```
