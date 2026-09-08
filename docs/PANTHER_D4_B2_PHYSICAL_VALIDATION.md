# Panther D4 B2 packaged flash and boot validation

Date: 2026-09-08
Device: Pixel 7 (`panther`)
Android: 17 / SDK 37
Build ID: `CP2A.260705.006`
Development build: `2026090500`, `userdebug/test-keys`

## Result

The exact packaged SableOS B2 population was flashed successfully to the already-active slot B and booted into Android userspace without an intentional userdata/metadata wipe.

```text
PACKAGED_TARGET_FILES_BINDING=PASS
TARGET_FILES_SOLE_IMAGE_SOURCE=PASS
FASTBOOT_POLICY=PASS
FLASH_EXECUTION=PASS
POST_FLASH_SLOT_B=PASS
ANDROID_SYS_BOOT_COMPLETED=PASS
POST_BUILDMANIFEST_EXACT_B2_MATCH=PASS
PHONE_BOOTED_INTO_SABLEOS=PASS
```

The historical R10R3 harness's final status is `BOUNDED_FAIL` because its post-boot shell loop validated one ART file and then let the `adb` child consume the remaining TSV stdin. The failure occurred after successful flash, reboot, userspace boot and exact BuildManifest identity proof.

## Exact packaged source

```text
B2_TARGET_FILES=panther-target_files.zip
B2_TARGET_FILES_SHA256=b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78
B2_MANIFEST_PB_SHA256=c006f36d2181e9a302c275d3d8dfeb8c3ef88ac126738fe05f33736dc9b2f429
B2_BUILDMANIFEST_APK_SHA256=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
FASTBOOT_INFO_SHA256=42a270c4d51ca3e1e62b073bf4d2aa88617580a4a6517bb7607b2d2b4ac9ebac
```

Fourteen image sources were staged exclusively from `target_files.zip!IMAGES/`:

```text
boot.img
init_boot.img
dtbo.img
product.img
pvmfw.img
super_empty.img
system.img
system_dlkm.img
system_ext.img
vbmeta.img
vendor.img
vendor_boot.img
vendor_dlkm.img
vendor_kernel_boot.img
```

## Mutation policy

```text
DEVICE_CONTACT_AUTHORIZED=YES
DEVICE_REBOOT_AUTHORIZED=YES
FLASH_AUTHORIZED=YES
SLOT_REASSERTION_AUTHORIZED=YES
SLOT_CHANGE_AUTHORIZED=NO
BOOTLOADER_UNLOCK_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
INACTIVE_SLOT_FLASH_AUTHORIZED=NO
FASTBOOT_WIPE_FLAG=ABSENT
```

`fastboot-info.txt` contained two conditional `if-wipe` directives, but the host invocation never supplied `-w`. No unconditional userdata/metadata operation or inactive-slot directive was permitted by the harness.

## Flash outcome

Fastboot completed with return code zero. Slot B remained current before reboot.

```text
FASTBOOT_FLASHALL_RC=0
POST_FLASH_PRE_REBOOT_SLOT=b
FASTBOOT_FLASH_PAYLOAD_EXECUTION=PASS
POST_FLASH_PRE_REBOOT_SLOT_PRESERVED=PASS
FINAL_FASTBOOT_REBOOT_RC=0
CONTROLLED_B2_FLASH_EXECUTION=PASS
```

The dynamic super update populated the B-side logical partitions for product, system, system_dlkm, system_ext, vendor and vendor_dlkm.

## Post-boot outcome

```text
POST_SYS_BOOT_COMPLETED=1
POST_DEVICE_PRODUCT=panther
POST_SLOT_SUFFIX=_b
POST_FLASH_LOCKED=0
POST_VERIFIED_BOOT_STATE=orange
POST_CRYPTO_STATE=encrypted
POST_CRYPTO_TYPE=file
POST_BUILDMANIFEST_EXACT_B2_MATCH=PASS
```

The first ART image also matched its expected packaged B2 SHA exactly before the host loop defect terminated aggregate verification.

## Harness defect and disposition

The shell loop had the shape:

```text
while read expected_row; do
    adb ...
done < expected_rows.tsv
```

Because the child inherited stdin, `adb` could consume the remaining TSV input. Only one row reached the loop body.

Disposition:

```text
R10R3_FLASH_RESULT=PASS
R10R3_BOOT_RESULT=PASS
R10R3_BUILDMANIFEST_IDENTITY=PASS
R10R3_POSTBOOT_ART_AGGREGATE=HARNESS_DEFECT
R10R3_DEVICE_COMPATIBILITY_CONTRADICTION=NONE
```

Post-boot validation moves to `sablectl`, whose subprocess layer always uses `stdin=DEVNULL` and whose unit tests explicitly require all five ART checks to execute.
