# Titan 2 N1B on V01.00.14 control

Status: **offline qualification package / no device contact / no mutation**

This is the next canonical Titan 2 engineering control after the N1D physical
reboot-loop result.

```text
N1B_V010014_CONTROL=NEXT_PHYSICAL_CONTROL_AFTER_REVIEW
COUNT_ZERO_STATUS=PRIMARY_SUSPECT_NOT_PROVEN_ROOT_CAUSE
N1E_BUILD_AUTHORIZED=NO_PENDING_N1B_CONTROL
N1E_FLASH_AUTHORIZED=NO
```

## Purpose

The control repeats the exact known-booting N1B system artifact against the
current V01.00.14 device/vendor state. It separates the broad N1D system-side
delta from current device/firmware state before N1E is built.

A successful N1B boot on V01.00.14 means the current device/vendor state remains
compatible with N1B. It does **not** prove that `COUNT=0`, AVB/dm-verity, VNDK,
SELinux, VINTF, SurfaceFlinger, or any other single patch family is the root
cause. N1E is the next controlled isolation.

A failed N1B control means the historical N1B control is not reproduced on the
current device state. It does **not** prove V01.00.14 alone caused the failure.

## Exact N1B authority

```text
N1B_SOURCE_COMMIT=8dd06e77410fea131e4716447f7f05067e427654
N1B_SYSTEM_SHA256=bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e
N1B_SYSTEM_BYTES=3180666880
N1B_HISTORICAL_TARGET=system_a
N1B_HISTORICAL_FIRST_BOOT=PASS
N1B_HISTORICAL_FACTORY_RESET_REQUIRED=YES_CONFIRMED
```

The first-boot ledger remains the authority for those values:
`docs/titan2/N1B_FIRST_BOOT_LEDGER_AND_N1B2_HANDOFF.md`.

## Current-firmware evidence

The preparation package consumes the sealed E5A read-only JSON and the sealed
E5B decision JSON. It requires:

```text
E5A_FINAL_STATE=PASS_REVIEW_READY
E5A_DEVICE_BINDING_VERIFIED=true
CURRENT_STOCK_INCREMENTAL=V01.00.14
CURRENT_SLOT=a
FASTBOOTD_IS_USERSPACE=yes
FASTBOOTD_UNLOCKED=yes
SNAPSHOT_UPDATE_STATUS=none
SUPER_BYTES=9663676416
ALLOCATION_COMPLETE=true
CAPACITY_SAFE=true
E5B_DECISION_SHA256=74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926
E5B_BINDS_THE_SUPPLIED_E5A_JSON=YES
```

This is historical/sealed evidence. The later physical execution must still
perform a fresh live fastbootd preflight because the current `system_a` contents
and size changed during the N1D/E6 experiments.

## Offline preparation

Run from current canonical main after the control-preparation PR is merged:

```bash
cd /srv/sable-build/sableos/repo

git fetch origin main
git switch main
git pull --ff-only origin main

bash build/gates/n1b-v010014-control-contract.sh

E5A_DIR=/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z

bash build/titan2/prepare-n1b-v010014-control.sh \
  --e5a-json "$E5A_DIR/e5a-readonly-device-state.json" \
  --e5b-json "$E5A_DIR/e5b-authorization-package.json"
```

`n1d-c2-prebuilt-control` is **not** the N1B control. C2 is the published RestlessOS 16.0.0-202606230923 asset with SHA-256 `52ea47d7...`; it must not be substituted for the historical N1B system image whose SHA-256 is `bc550bfa...`.

The original N1B workspace was retired during later N1D cleanup. `--system-img` is therefore optional. If the supplied path is absent, the preparation script reuses the C0 recovery model: release registry -> surviving exact-size local images -> retained N1B target-files archives. Target-files recovery accepts only `IMAGES/system.img` with the historical byte size and SHA-256, then stores a read-only recovered copy under `/srv/data/sable-build/artifacts/titan2/n1b-control-recovered/`. No network access or rebuild is used.

## Expected result

```text
N1B_V010014_CONTROL_ARTIFACT=PASS_EXACT_HISTORICAL_N1B
N1B_V010014_CONTROL_CURRENT_FIRMWARE_EVIDENCE=PASS_SEALED_V010014
N1B_V010014_CONTROL_PLAN=PASS_PREPARED_NO_WRITE
N1B_V010014_CONTROL_FLASH_AUTHORIZED=NO
N1B_V010014_CONTROL_FACTORY_RESET_AUTHORIZED=NO
N1B_V010014_CONTROL_PREP=PASS
```

Return the complete console output plus the emitted `EVIDENCE_DIR` and
`EVIDENCE_SEAL_SHA256` before physical mutation is enabled.

## Later physical scope — not authorized by this deliverable

The sealed plan records the future scope but does not execute it:

```text
ENTRY_MODE=userspace fastbootd
TARGET=system_a
ACTIVE_SLOT=a
DEVICE_BINDING=fresh live match required
SNAPSHOT_UPDATE_STATUS=none required
ACTIVE_COW_COUNT=0 required
LOGICAL_ALLOCATION=complete required
CAPACITY_CHECK=fresh required
FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=3180666880
MANUAL_PRE_RESIZE=NO
COW_DELETION=NO
SLOT_CHANGE=NO
AVB_MUTATION=NO
BOOT_CHAIN_FLASH=NO
WHOLE_SUPER_FLASH=NO
AUTO_RETRY=NO
```

After the future system write, the driver must stop at the first terminal state:
Android boot complete, stock recovery, or fastboot return. If recovery is the
result, factory reset remains a separate destructive authorization. The
historical N1B path required that reset; it must not be folded silently into the
system flash.

## Decision after the physical control

```text
if N1B boots on V01.00.14:
    N1B_V010014_CONTROL=PASS
    N1E_BUILD_AUTHORIZED=YES_AFTER_REAL_HOST_GATES
    next=N1B provenance capture -> minimal N1E -> G0/G1/G2

if N1B fails on V01.00.14:
    N1B_V010014_CONTROL=FAIL
    N1E_BUILD_AUTHORIZED=NO
    next=V01.00.13_TO_V01.00.14_AND_BOOT_CHAIN_CURRENT_STATE_INVESTIGATION
```
