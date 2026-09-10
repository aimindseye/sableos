# SableOS non-Pixel release validation

Status: **normative extension to `RELEASE_VALIDATION.md` for non-Pixel candidates**.

This document adds the device/BSP/firmware/recovery evidence required when SableOS runs on non-Pixel hardware, especially MediaTek devices with proprietary vendor stacks or prebuilt kernels.

It does not weaken or replace any existing SableOS release gate.

## Assurance class

Every non-Pixel build must declare:

```text
SABLEOS_NON_PIXEL_CLASS=N0_GSI_USERSPACE_LAB|N1_INTEGRATED_VENDOR_BSP_PORT|N2_PRODUCTION_QUALIFIED
```

Only `N2_PRODUCTION_QUALIFIED` may carry a production SableOS device-support claim.

## Additional gate sequence

In addition to the common `RELEASE_VALIDATION.md` sequence, qualify:

```text
1. exact stock-device / recovery baseline
2. partition and dynamic-super inventory
3. bootloader / unlock / relock classification
4. AVB chain and rollback-index inventory
5. kernel / DTB / DTBO / module provenance
6. vendor / ODM / VINTF inventory
7. vendor ABI-shim inventory
8. modem / IMS / carrier integration inventory
9. firmware / TEE / bootloader provenance
10. physical capability baseline
11. A/B / OTA / rollback / recovery behavior
12. Sable mutation/build gates
13. post-build image/package proof
14. physical regression matrix
15. security-lifecycle / unresolved-risk record
```

## N0 GSI gate

A development GSI may reuse the stock kernel/vendor/firmware stack.

Required fields include:

```text
SABLEOS_NON_PIXEL_CLASS=N0_GSI_USERSPACE_LAB
STOCK_BUILD_FINGERPRINT=
STOCK_PLATFORM_SPL=
STOCK_VENDOR_SPL=
KERNEL_RELEASE=
KERNEL_IMAGE_SHA256=
DTB_SHA256=
DTBO_SHA256=
VENDOR_IMAGE_SHA256=
ODM_IMAGE_SHA256=
VENDOR_BOOT_SHA256=
VBMETA_CHAIN_RECORD=
BOOTLOADER_STATE=
RESTORE_PATH=PASS|FAIL|NOT_RUN
```

Not every image exists on every device; explicit `NOT_APPLICABLE` is valid when justified.

N0 release notes must state that SableOS does not own the stock kernel/vendor/firmware security-update lifecycle.

## N1 integrated vendor/BSP gate

An N1 device port must additionally bind:

```text
DEVICE_TREE_REVISION=
DEVICE_TREE_MANIFEST_SHA256=
VENDOR_BLOB_MANIFEST_SHA256=
VINTF_MANIFEST_MATRIX_RECORD=
SELINUX_DEVICE_POLICY_RECORD=
KERNEL_MODULE_MANIFEST_SHA256=
FIRMWARE_MANIFEST_SHA256=
ABI_SHIM_MANIFEST_SHA256=
AB_OTA_PARTITION_SET=
RECOVERY_ARTIFACT_MANIFEST_SHA256=
```

If the kernel is prebuilt, record the exact vendor release/provenance and compatibility with every shipped module partition.

If the kernel is source-built, normal `KERNEL_SECURITY_UPDATE_POLICY.md` gates apply.

## Vendor ABI-shim gate

Every framework/vendor compatibility shim must have a record containing:

```text
component=
source_vendor_bsp_version=
target_android_version=
change_type=DT_NEEDED_ADD|DT_NEEDED_REPLACE|SONAME_FIX|SYMBOL_SHIM|BINARY_PROPERTY_PATCH|OTHER
reason=
security_relevance=
input_sha256=
output_sha256=
runtime_test=
removal_condition=
```

Unknown or undocumented binary patching blocks N2 production qualification.

## Telephony / IMS / 5G gate

Record separate results for:

```text
SIM
MULTI_SIM
LTE_REGISTRATION
5G_REGISTRATION
PACKET_DATA
VOICE_OUTBOUND
VOICE_INBOUND
SMS_OUTBOUND
SMS_INBOUND
MMS
IMS_REGISTRATION
VOLTE
VOWIFI
CARRIER_CONFIG
HANDOVER_STABILITY
```

`NOT_APPLICABLE` is valid where the hardware/carrier does not provide a capability.

Do not infer voice/IMS success from packet-data success.

Routine validation must not place live emergency-services calls.

## Firmware provenance gate

Track at minimum when applicable:

```text
BOOTLOADER_VERSION=
MODEM_FIRMWARE_VERSION=
TEE_FIRMWARE_VERSION=
CONNECTIVITY_FIRMWARE_VERSION=
POWER_DSP_FIRMWARE_VERSION=
FIRMWARE_SOURCE_OR_VENDOR_RELEASE=
FIRMWARE_MANIFEST_SHA256=
FIRMWARE_UPDATE_PATH=
```

A current Android platform patch level does not compensate for stale modem, TEE, bootloader or vendor firmware.

## AVB / signing gate

Development builds may use test keys only when explicitly classified as development.

For N2:

```text
RELEASE_AVB_KEYS=PASS
PUBLIC_TEST_KEY_PRESENT=NO
VERIFICATION_DISABLED_FLAG=NO
HASHTREE_DISABLED_FLAG=NO
ROLLBACK_INDEX_POLICY=PASS
BOOTLOADER_LOCKED_OR_APPROVED_CUSTOM_KEY_STATE=PASS
OTA_SIGNATURE=PASS
```

Missing release signing material must fail closed.

## Recovery / flash-safety gate

Before device mutation, verify immediately before write:

```text
PRODUCT_IDENTITY=PASS
BOOTLOADER_STATE=PASS
PARTITION_LAYOUT=PASS
TARGET_SLOT=PASS|NOT_APPLICABLE
IMAGE_HASHES=PASS
WRITE_SET=EXPECTED_ONLY
WIPE_POLICY=EXPLICIT
RESTORE_PATH=PASS
```

Low-level MediaTek scatter/SP Flash tooling receives the same authorization discipline as fastboot.

A generic multi-partition flash script without product/partition/hash guards is not release tooling.

## Hardware-variation gate

If production units can differ in physical storage or partition layout, qualify every supported variant before generating a common image/flash bundle.

Required record:

```text
SUPPORTED_HARDWARE_VARIANTS=
MINIMUM_PHYSICAL_PARTITION_CAPACITIES=
SUPER_LAYOUT_COMPATIBILITY=PASS
USERDATA_LAYOUT_COMPATIBILITY=PASS
FLASH_BUNDLE_VARIANT_GUARD=PASS
```

Never assume one engineering sample describes the whole fleet.

## Physical acceptance gate

At N1/N2, test at minimum:

- boot/reboot stability;
- display/touch;
- physical keyboard/trackpad/pointer where present;
- Wi-Fi;
- Bluetooth;
- NFC;
- GNSS/location;
- audio playback/record/call routing;
- cameras;
- sensors;
- fingerprint/biometrics;
- USB/charging;
- suspend/resume;
- thermal behavior;
- storage/encryption;
- telephony/IMS/5G as applicable;
- A/B/OTA/rollback/recovery;
- AVB/bootloader state;
- declared hardware-security capabilities.

`BOOT=PASS` and `HOME=PASS` are insufficient.

## Reproducibility gate

N2 must bind exact revisions and tool inputs:

```text
SOURCE_REVISION_MANIFEST=
SOURCE_REVISION_MANIFEST_SHA256=
BUILD_CONTAINER_DIGEST=
HOST_TOOLCHAIN_RECORD=
KERNEL_PROVENANCE=
VENDOR_BSP_MANIFEST_SHA256=
FIRMWARE_MANIFEST_SHA256=
RELEASE_SIGNING_IDENTITY=
BUILD_DATE=
BUILD_NUMBER=
TARGET_FILES_SHA256=
FINAL_IMAGE_MANIFEST_SHA256=
```

Moving branch names, unpinned package repositories, or `latest` tool downloads may be used during development but do not satisfy the production reproducibility gate.

## Security claim rule

The release record must describe exactly which layers SableOS maintains.

For example:

```text
platform_userspace_maintained_by_sable=YES
kernel_maintained_by_sable=NO
vendor_bsp_maintained_by_sable=NO
firmware_maintained_by_sable=NO
```

Do not describe an N0/N1 build as equivalent to the Panther/GrapheneOS-derived production-security model when the lower layers remain opaque or vendor-controlled.

## References

- `RELEASE_VALIDATION.md`
- `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`
- `BRAX3_IODEOS_REFERENCE.md`
- `TITAN2_GSI_PLAN.md`
- `KERNEL_SECURITY_UPDATE_POLICY.md`
- `SECURITY_PRIVACY_ASSURANCE_STANDARD.md`
