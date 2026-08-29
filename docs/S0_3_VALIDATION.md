# S0.3 Android 14 vanilla build validation

Status: **PRE-FLASH PASS**

Physical-device flashing/boot validation has not yet been performed.

## Baseline

- Device: Google Pixel 4a (5G), codename `bramble`
- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Product: `aosp_bramble-userdebug`
- Output directory: `out_s0`
- Sable source intentionally absent from the Android-14 worktree
- Matching official Google/Qualcomm proprietary binaries installed for this build

## S0.3A required AOSP compatibility backport

The first vanilla full build stopped in `external/iproute2/tc` because the pinned source snapshot's sandboxed Bison genrules did not explicitly provide the AOSP-prebuilt `m4` helper.

The minimal upstream AOSP fix was backported from external/iproute2 commit:

`f802dbfadf575f00d02d0a6d420f2c303a402010` — `Specify which M4 to use with bison`

The backport changes only `external/iproute2/tc/Android.bp` by declaring `m4` as a genrule tool and setting `M4=$(location m4)` for the two Bison invocations.

Repository copy:

`patches/android-14.0.0_r28/0001-iproute2-specify-m4-for-bison.patch`

This is classified as an AOSP build-compatibility backport, not a Sable runtime/security modification.

## Full build gate

Observed:

- `S0_3_FULL_BUILD_RC=0`
- `S0_3_FULL_BUILD_GATE=PASS`
- build completed successfully

## Target-files gate

Observed:

- `S0_3_TARGET_FILES_RC=0`
- `S0_3_TARGET_FILES_GATE=PASS`
- exactly one target-files ZIP
- target-files integrity: PASS
- target-files contains no Sable payload
- target-files build ID: `UP1A.231105.001.B2`

Target-files:

`aosp_bramble-target_files-eng.mindseye73.zip`

SHA256:

`86d69608d548cdcf20b713424b156b53a87c7d667099f251eb0589403eb80549`

## Core image hashes

- `boot.img` — `d2bc4c539bb1814ecafaaad9a1f757a530c1bc1ce57c36eb974085d252debdd9`
- `dtbo.img` — `fa5dc7bc79bba12b106e0ac68a6c9e02dfb07d7dfb314aa12f1701bed2564628`
- `product.img` — `1b3252f2bd5e7b83c22d13fc70296b6abd64688a20232d3ddc34d5d22f78d258`
- `system.img` — `432a31af75a3d6258ab41f8499e61ba63a96b0dd40ecd64c7255715811d473d8`
- `system_ext.img` — `e0eba9ac6af0f6f01ad48056babf4a259e7dc0b88809c6fe762caa6d13577ee3`
- `vbmeta.img` — `1484cd852016b79b6352cd99043e2fcc023aa1adbb24e9d6201a19e0fb54b2e2`
- `vendor.img` — `49d776911f955fd7b0a677980710be24aa567a900671b7fee0a0fd87ecb2e2fd`
- `vendor_boot.img` — `7d293102a9d1607f5baaa9d471a517a5a05095c91aee01d1c1dee8fe012a8320`

## Vanilla boundary audit

Observed:

- `S0_3_VANILLA_SABLE_ABSENT=PASS`
- `S0_3_IMAGE_BUILD_ID=UP1A.231105.001.B2`
- `S0_3_IMAGE_BUILD_ID_GATE=PASS`
- `S0_3_NO_SABLE_INSTALLED_PAYLOAD=PASS`
- `S0_3_TARGET_FILES_UNIQUE=PASS`
- `S0_3_TARGET_FILES_INTEGRITY=PASS`
- `S0_3_TARGET_FILES_NO_SABLE=PASS`
- `S0_3_TARGET_FILES_BUILD_ID=PASS`
- `S0_3_VANILLA_BUILD_PRE_FLASH_GATE=PASS`

## Storage after build

- `out_s0`: approximately 116 GiB
- `/srv/data` available: approximately 424 GiB

## Security/firmware note

S0.3 proves the userspace/kernel/vendor-image build baseline only. It does not prove that the Android-12-era bootloader/baseband currently installed on the reference device are the correct firmware pairing for the final Android-14 bramble build.

The next gate must compare the reference device's current bootloader/baseband with the matching official `UP1A.231105.001.B2` factory package before constructing or executing any flash plan. The earlier Android-12 rule of preserving bootloader/baseband unchanged must not be carried across the Android-major-version uplift without evidence.

## Next gate

S0.4 performs a non-destructive firmware compatibility and flash-package audit. No device partition is flashed until that gate establishes the intended bootloader/radio policy and audits the exact AOSP payload.
