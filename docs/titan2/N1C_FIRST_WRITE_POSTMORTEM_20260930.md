# Titan 2 N1C first-write postmortem — 2026-09-30

Status: **device recovered / N1C retry blocked**

This SableOS execution record captures the first write-capable Titan 2 N1C test, recovery, and corrective actions required before any N1D or Option C continuation.

```text
TRACK=N1C_ANDROID16_HYBRID_SUPER
DEVICE=titan2
FIRST_WRITE_SCOPE=super_only
N1C_FIRST_WRITE_RESULT=FLASHED_BUT_BOOT_FAILED
STOCK_SUPER_RESTORE=PASS
TEE14_BOOT_AVB_RESTORE=PASS
FACTORY_RESET=REQUIRED_AND_PERFORMED_FROM_RECOVERY
DEVICE_RECOVERED=YES
N1C_RETRY_AUTHORIZED=NO
FLASH_AUTHORIZED_BY_THIS_DOC=NO
```

## Evidence paths on ai-g732

```text
N1C_WRITE_EVID=/srv/data/sable-build/evidence/titan2/n1c-first-write-super-test-r1-20260930_200458
STOCK_SUPER_ARTIFACT_EVID=/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124
STOCK_SUPER_LIVE_EVID=/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-live-20260930_202932
TEE14_BOOT_AVB_EVID=/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335
STOCK_RECOVERY_AFTER_FACTORY_RESET_EVID=/srv/data/sable-build/evidence/titan2/n1c-stock-recovery-after-factory-reset-20260930_205351
FAILURE_ANALYSIS_LEDGER_EVID=/srv/data/sable-build/evidence/titan2/n1c-first-write-failure-analysis-ledger-r1-20260930_205520
```

## Outcome

The N1C sparse super image was written successfully in fastbootd, but the device did not boot back to Android/ADB. Recovery required a verified stock super restore, matched TEE14 boot/AVB restore, and recovery factory reset. The device then returned to Unihertz stock setup on V01.00.14.

## Recovered stock state

```text
sys.boot_completed=1
ro.product.device=Titan_2
ro.product.model=Titan 2
ro.product.manufacturer=Unihertz
ro.build.fingerprint=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
ro.vendor.build.fingerprint=Unihertz/Titan_2/Titan_2:14/UP1A.231005.007/V01.00.14:user/release-keys
ro.boot.slot_suffix=_a
ro.boot.dynamic_partitions=true
ro.virtual_ab.enabled=true
ro.treble.enabled=true
ro.boot.verifiedbootstate=orange
ro.boot.flash.locked=0
ro.build.version.release=16
ro.build.version.incremental=V01.00.14
```

## Corrective action rules

```text
NO_RETRY_SAME_N1C_ARTIFACT=YES
NO_FLASH_NEW_N1C_ARTIFACT_UNTIL_OFFLINE_ROOT_CAUSE_ANALYSIS=YES
NO_SET_EUO_PIPEFAIL_IN_DEVICE_OR_RECOVERY_SCRIPTS=YES
NO_STDOUT_LOGGING_FROM_FUNCTIONS_USED_IN_COMMAND_SUBSTITUTION=YES
NO_HARDCODED_HOST_TOOL_WITHOUT_RESOLVER_FALLBACK=YES
NO_WRITE_CAPABLE_SCRIPT_WITHOUT_VERIFIED_RESTORE_PATH=YES
NO_WRITE_CAPABLE_SCRIPT_WITHOUT_DRY_RUN_TRANSCRIPT=YES
```

## Required offline root-cause work

```text
COMPARE_RESTLESSOS_BOOTABLE_GSI_TO_N1C_SYSTEM=REQUIRED
COMPARE_LINEAGE23_OR_OTHER_TITAN2_GSI_GUIDANCE=REQUIRED
CHECK_INIT_AND_FIRST_STAGE_MOUNT_PATHS=REQUIRED
CHECK_FSTAB_AND_METADATA_ENCRYPTION_FLAGS=REQUIRED
CHECK_DYNAMIC_PARTITION_LAYOUT_AND_LP_METADATA=REQUIRED
CHECK_SYSTEM_PROPERTIES_IDENTITY_AND_API_LEVELS=REQUIRED
CHECK_VINTF_COMPATIBILITY=REQUIRED
CHECK_SEPOLICY_AND_TREBLE_PHRASES=REQUIRED
CHECK_DATA_FORMAT_AND_ENCRYPTION_EXPECTATIONS=REQUIRED
CHECK_AVB_CHAIN_IMPLICATIONS=REQUIRED
```

## Option C status

Option C is not discarded. The structural idea remains valid: replace `system_a` while preserving stock `product`, `system_ext`, `vendor`, and DLKMs.

The failed N1C attempt does mean the previous Option C implementation is blocked. The next Option C candidate must be driven by a known-booting RestlessOS/GSI baseline and an offline diff that explains the boot/data failure before any further write-capable Titan 2 test.

```text
OPTION_C_STATUS=OPEN_BUT_BLOCKED_PENDING_OFFLINE_DIFF
RESTLESSOS_GSI_BASELINE=REQUIRED_CONTROL_CASE
NEXT_FLASH_AUTHORIZED=NO
```