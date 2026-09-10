# Panther D4 closure — 2026-09-08

Status: **CLOSED**

D4 reached full release-candidate closure for the current SableOS B2 development population on physical Pixel 7 (`panther`).

## Closure markers

```text
D4_GRAPHENE_USER_FACING_DEFAULTS=REMOVED_OR_EXPLICITLY_JUSTIFIED
D4_DEFAULT_APP_SET=DOCUMENTED
D4_FUNCTIONAL_ACCEPTANCE=PASS
D4_SLOT_B_BOOT=PASS
D4_SLOT_B_SUCCESSFUL=PASS
D4_SLOT_B_BOOTABLE=PASS
D4_SHARED_DATA_PRESERVED=PASS
D4_AUTOMATED_REGRESSION=PASS
D4_RELEASE_GATE=PASS
D4_BLOCKING_FUNCTIONAL_DEFECTS=0
PANTHER_D4_R2=PASS
PANTHER_D4=CLOSED
```

The only deferred physical coverage is NFC RF/tag interaction because no external NFC tag was available during D4:

```text
NFC_FRAMEWORK_STACK=PASS
NFC_HAL_BRINGUP=PASS
NFC_ENABLE_DISABLE_PATH=PASS
NFC_ROUTING_INITIALIZATION=PASS
NFC_RF_TAG_READ=DEFERRED_NON_BLOCKING_EXTERNAL_HARDWARE_VALIDATION
```

## Final slot-success proof

Corrected read-only bootloader proof:

```text
FASTBOOT_PRODUCT=panther
FASTBOOT_CURRENT_SLOT=b
FASTBOOT_SLOT_COUNT=2
FASTBOOT_SLOT_SUCCESSFUL_b=yes
FASTBOOT_SLOT_UNBOOTABLE_b=no
FASTBOOT_SLOT_RETRY_COUNT_b=2
D4_SLOT_B_SUCCESSFUL=PASS
D4_SLOT_B_BOOTABLE=PASS
D4_SLOT_B_CURRENT=PASS
POST_DEVICE_PRODUCT=panther
POST_SLOT_SUFFIX=_b
POST_BOOT_COMPLETED=1
POST_SLOT_PRESERVED=PASS
PANTHER_D4_R2_SLOT_SUCCESS_RESULT=PASS
R2_RC=0
```

Evidence:

```text
EVIDENCE_DIR=/tmp/PANTHER_D4_R2_SLOT_SUCCESS_PROOF_20260908T215953Z_JS7omS
script_sha256=d3cdb1dc4cdca4289ff7d835a96d9c96aebfee05a4feaa4c967bbf033115ca71
log_sha256=8aaf2bbaf195cd5f48acc0eafad64022c3dd6ca339a4b400a933752a49738dbc
```

The immediately preceding bounded failure is superseded as a host-harness fastboot-readiness race. It produced no slot contradiction and the device was recovered to Android on `_b`. The corrected harness required a successful read-only `getvar product` before declaring fastboot ready and subsequently closed the slot-success boundary.

## Transition

The active engineering milestone after D4 is **R1 — Sable-owned release engineering**.

The first R1 deliverable is `docs/SABLE_R1_R0_RELEASE_ENGINEERING_PREFLIGHT.md` plus the read-only `tools/validation/release-r1/SABLE_R1_R0_RELEASE_PREFLIGHT.py` gate.
