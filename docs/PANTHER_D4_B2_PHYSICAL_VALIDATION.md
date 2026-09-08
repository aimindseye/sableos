# Panther D4 B2 packaged flash and boot validation

Date: 2026-09-08
Device: Pixel 7 (`panther`)
Android: 17 / SDK 37
Build ID: `CP2A.260705.006`
Development build: `2026090500`, `userdebug/test-keys`

## Result

The exact packaged SableOS B2 population was flashed successfully to the already-active slot B and booted into Android userspace without an intentional userdata/metadata wipe. The post-boot identity and core smoke checks were then rerun through `sablectl` and passed cleanly.

```text
PACKAGED_TARGET_FILES_BINDING=PASS
TARGET_FILES_SOLE_IMAGE_SOURCE=PASS
FASTBOOT_POLICY=PASS
FLASH_EXECUTION=PASS
POST_FLASH_SLOT_B=PASS
ANDROID_SYS_BOOT_COMPLETED=PASS
POST_BUILDMANIFEST_EXACT_B2_MATCH=PASS
POST_ART_EXACT_B2_MATCH=PASS_5_OF_5
SELINUX_ENFORCING=PASS
CORE_ANDROID_SERVICES=PASS
PACKAGE_MANAGER_HEALTH=PASS
PHONE_BOOTED_INTO_SABLEOS=PASS
SABLECTL_VERIFY_BOOT=PASS_11_OF_11
SABLECTL_SMOKE=PASS_16_OF_16
```

The historical R10R3 harness's final status remains `BOUNDED_FAIL` because its shell `while read ... < expected_b2_art_sha256.tsv` loop allowed the `adb` child to consume the remaining TSV stdin after validating the first ART row. That host-only harness defect is now superseded by the successful `sablectl` post-boot run, which explicitly verified all five ART files.

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

## Post-boot exact identity closure with sablectl

The first live `sablectl verify boot` run against the same packaged B2 target-files completed with:

```text
PASS=11
FAIL=0
SKIP=0
MANUAL=0
ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/verify-boot/20260908T181140Z
```

The verified live-device properties were:

```text
boot.device=panther
boot.completed=1
boot.slot=_b
boot.crypto=encrypted
```

The installed BuildManifest matched exactly:

```text
/system/etc/security/fsverity/BuildManifest.apk
sha256=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

All five residual ART images matched the exact packaged B2 bytes:

```text
system/framework/oat/arm64/apex@com.android.appsearch@javalib@service-appsearch.jar@classes.art
sha256=3ff15d16850b8501a905b9d4a0a0259a8e5563a520f0de800f0673b3c09c9166

system/framework/oat/arm64/apex@com.android.art@javalib@service-art.jar@classes.art
sha256=afea44284e5007ff478a3999b009e011952d671fbba6d5ed4db5dc5796bf1efa

system/framework/oat/arm64/apex@com.android.telephonycore@javalib@service-telecom.jar@classes.art
sha256=d2323a48d0b3600023a9cd1037cd9e2e98f24a672525719465e7994801df9e63

system/framework/oat/arm64/apex@com.android.tethering@javalib@service-connectivity.jar@classes.art
sha256=b93b89253e2e76f1c8e8c8b0f1c2b560ecf211015c854ada3fe4b2348571d42e

system/framework/oat/arm64/services.art
sha256=dbf14adfde4b4182ba204915742bb8c13028a26c418c572e1978fdc69379a156
```

Aggregate result:

```text
artifact.art.count expected=5 actual=5 PASS
POST_ART_EXACT_B2_MATCH=PASS_5_OF_5
```

## Post-boot smoke closure with sablectl

The subsequent live `sablectl smoke` run completed with:

```text
PASS=16
FAIL=0
SKIP=0
MANUAL=0
ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/smoke/20260908T181212Z
```

Additional runtime checks passed:

```text
security.selinux=Enforcing
service.servicemanager=running
service.surfaceflinger=running
service.zygote=running
service.package_manager=PASS installed_packages=229
```

This closes the post-boot artifact-identity question that the historical R10R3 shell harness could not complete.

## Harness defect and final disposition

The R10R3 shell loop had the shape:

```text
while read expected_row; do
    adb ...
done < expected_rows.tsv
```

Because the child inherited stdin, `adb` could consume the remaining TSV input. Only one row reached that historical loop body.

`sablectl` removes that failure mode by executing child processes with stdin isolated from the caller and by unit-testing full expected-artifact cardinality.

Final disposition:

```text
R10R3_FLASH_RESULT=PASS
R10R3_BOOT_RESULT=PASS
R10R3_BUILDMANIFEST_IDENTITY=PASS
R10R3_POSTBOOT_ART_AGGREGATE=SUPERSEDED_HOST_HARNESS_DEFECT
SABLECTL_POSTBOOT_ART_AGGREGATE=PASS_5_OF_5
SABLECTL_VERIFY_BOOT=PASS_11_OF_11
SABLECTL_SMOKE=PASS_16_OF_16
R10R3_DEVICE_COMPATIBILITY_CONTRADICTION=NONE
B2_EXACT_PACKAGED_POSTBOOT_IDENTITY=CLOSED
```
