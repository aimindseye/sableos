# S0.4 Android 14 firmware compatibility audit

Status: **PASS — firmware mismatch identified; no flash performed**

## Purpose

S0.4 compared the reference Pixel 4a (5G) (`bramble`) device's currently installed bootloader/baseband against the firmware paired with the final official Android 14 baseline used by S0:

- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Product: `aosp_bramble-userdebug`

No partition was written during this gate.

## S0.3 artifact revalidation

The frozen S0.3 vanilla-build artifacts were revalidated before device inspection.

Target-files SHA256:

```text
86d69608d548cdcf20b713424b156b53a87c7d667099f251eb0589403eb80549
```

Core image hashes remained identical to the S0.3 pre-flash record, including boot, dtbo, product, system, system_ext, vbmeta, vendor and vendor_boot.

Result:

```text
S0_4_TARGET_FILES_INTEGRITY=PASS
S0_4_PREFLIGHT_GATE=PASS
```

## Current device firmware

Read-only ADB capture showed:

```text
CURRENT_BOOTLOADER=b5-0.4-8351080
CURRENT_BASEBAND=g7250-00202-220422-B-8489468
CURRENT_BUILD_ID=SQ3A.220705.003.A1
CURRENT_ANDROID_RELEASE=12
CURRENT_SECURITY_PATCH=2022-07-05
CURRENT_SLOT_SUFFIX=_a
```

Result:

```text
S0_4_ADB_SINGLE_DEVICE=PASS
S0_4_CURRENT_FIRMWARE_CAPTURE=PASS
```

## Matching Android 14 factory package

The exact Google bramble factory package used for the comparison was:

```text
bramble-up1a.231105.001.b2-factory-46a218d9.zip
SHA256=46a218d9dc2bf1802a584fa4e7e1b4d609a62189bd87a474201fb6d84e1c3e1c
```

Package integrity and expected component discovery passed.

The official package pairs `UP1A.231105.001.B2` with:

```text
EXPECTED_BOOTLOADER=b5-0.6-10489838
EXPECTED_BASEBAND=g7250-00264-230619-B-10346159
```

Factory-component SHA256 values recorded during the audit:

```text
63df7c9a2957ffb6f648ea0973f1b2f3ada427a10bd1ac29ac8741a3c8ff3272  bootloader-bramble-b5-0.6-10489838.img
b65fb8b2750228bc409c48136e2e3563338a1f9782bfbcc77dd5e20a0129c356  radio-bramble-g7250-00264-230619-b-10346159.img
cd087c3d2778ff5fa5f59adefbe783e6fffa434c3dcc2f48b685cf6f1ed59288  image-bramble-up1a.231105.001.b2.zip
```

The official `android-info.txt` requires:

```text
require board=bramble
require version-bootloader=b5-0.6-10489838
require version-baseband=g7250-00264-230619-B-10346159
```

## Comparison result

```text
S0_4_COMPARE_INPUTS=PASS
S0_4_BOOTLOADER_MATCH=DIFF
S0_4_BASEBAND_MATCH=DIFF
S0_4_FIRMWARE_COMPARISON=COMPLETE
S0_4_NO_FLASH_PERFORMED=PASS
```

Conclusion: the Android-12-era firmware-preservation rule does **not** carry forward unchanged to the Android 14 baseline. The reference device must first be paired with the bootloader/radio required by the matching official Android 14 factory release before the S0 vanilla AOSP system is flashed.

This is an explicit S0 transition decision; it does not invalidate the historical B1/B1.1 firmware-preservation evidence on Android 12.

## Next gate

S0.5 performs a read-only Fastboot preflight before any write. It must verify the expected `bramble` product, unlocked flashing state, current slot, fastboot tool, exact factory firmware component hashes and exact S0.3 AOSP artifacts. Only after that preflight passes may the project define and execute the controlled firmware-update + vanilla AOSP flash sequence.
