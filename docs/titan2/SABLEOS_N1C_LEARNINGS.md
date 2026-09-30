# Titan 2 N1C Bring-up Learnings

Status: **checkpoint learning ledger**

This document mirrors N1C learnings into the SableOS execution repository. It is not a flash plan and does not authorize device contact.

## 1. Hybrid-super is the correct Titan 2 N1C architecture

The successful N1C path is not system-only flashing in isolation. It is a hybrid-super artifact:

```text
replace: system_a
preserve: product_a system_ext_a vendor_a system_dlkm_a vendor_dlkm_a odm_dlkm_a
preserve outside super: boot init_boot vendor_boot dtbo vbmeta* modem/firmware
```

This aligns with Titan 2's Treble/dynamic-partition model and with the external Titan 2 Lineage/GSI precedent.

## 2. Stock V01.00.14 / TEE14 dynamic partitions are the correct preserved base

Use the V01.00.14 target/reference dynamic partition images from:

```text
/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference
```

Do not mix `TEE13-large-source` with `TEE14-large-reference`. The `system_dlkm` ambiguity proved this matters.

## 3. GitHub stores metadata; firmware images stay on ai-g732

The Titan 2 research repository documents methods, hashes, and conclusions. It does not contain extracted firmware images or payloads. Local ai-g732 artifact roots remain the source of truth for extracted image material.

## 4. Generic system artifact-path enforcement is strict

A device/profile layer must not inject files/properties into `generic_system.mk` protected system paths.

Lessons:

```text
DO_NOT_INJECT_N1C_RUNTIME_RADIO_PROPS_INTO_GENERIC_SYSTEM=YES
DO_NOT_COPY_RADIO_METADATA_INTO_SYSTEM_ETC=YES
KEEP_RADIO_CONTRACT_AS_SOURCE_AND_EVIDENCE_METADATA=YES
```

The N1C radio props are intentionally absent from the final generic `system.img`.

## 5. APNS duplicate owner fix should be source-owner cleanup

The APNS failure was caused by duplicate ownership of:

```text
system/product/etc/apns-conf.xml
```

Correct direction:

```text
keep: vendor/apn Soong-generated apns-conf.xml
remove/filter: generic sample PRODUCT_COPY_FILES owner
verify: /system/product/etc/apns-conf.xml exists in final system.img
```

## 6. `llkd` belongs at the generic system owner layer

Adding `llkd` from the N1C product/profile layer violated generic system artifact-path rules. Ownership must remain at the generic system layer.

## 7. LG vibrator quarantine is low-impact and should remain isolated

The `vendor.lge.hardware.vibrator@1.0` / `vibrator-lge` path is an LG/PHH compatibility artifact, not a Titan 2 requirement. Quarantine should remain narrow and documented, not broad module removal.

## 8. Runtime hacks are reference material only

Titan 2 GSI runtime scripts contain useful clues for keyboard, back-screen touch, media codec, Wi-Fi seeding, and HAL restarts.

Do not copy them into N1C now because the same scripts include IMS/ePDG-disabling behavior that conflicts with the N1C cellular objective.

## 9. Host tools must run with matching Android host libraries

Copied `lpmake` / `lpunpack` without Android host shared libraries can fail with missing `libbase.so`.

Correct pattern:

```text
prefer: $OUT_DIR/host/linux-x86/bin/*
export LD_LIBRARY_PATH=$OUT_DIR/host/linux-x86/lib64:$OUT_DIR/host/linux-x86/lib
fallback copied tools only when linkage is proven by ldd
```

## 10. ABI dump/check issue is still unresolved

The no-flash checkpoint used:

```text
DISABLE_ABI_CHECKS=true
SKIP_ABI_CHECKS=true
```

This unblocked systemimage creation but is not a production-ready state. Future work must either fix header ABI dumper include paths or record a reviewed waiver.

## 11. Flash remains blocked

The artifact is ready for review, not flashing.

Required before any write-capable command:

```text
RESTORE_REPORT=REQUIRED
BOOTLOADER_PREFLIGHT=REQUIRED
FASTBOOTD_PREFLIGHT=REQUIRED
SNAPSHOT_UPDATE_STATUS=none
ARTIFACT_SHA256_RECONFIRM=REQUIRED
ARTIFACT_BYTES_RECONFIRM=REQUIRED
ACTIVE_SLOT=REQUIRED
EXPLICIT_TITAN_SERIAL=REQUIRED
AVB_ACTION=REQUIRED
USERDATA_POLICY=preserve|explicit-wipe-approved
RESTORE_PATH_VERIFIED=REQUIRED
FLASH_COMMAND_REVIEW=REQUIRED
```
