# Non-cellular SableOS validation and replacement-developer execution plan

Status: **active while Titan cellular lane is held**  
Date: **2026-10-04**

## Hard boundary

BE2's N1I / MTK telephony investigation remains isolated.

```text
N1I_MUTATION=HOLD
IMS_MUTATION=HOLD
APN_MUTATION=HOLD
QNS_IWLAN_MUTATION=HOLD
VENDOR_TELEPHONY_IMPORT=HOLD
TITAN2_FLASH=HOLD
```

Allowed work is common-product source/build/UX validation and already-frozen
product-source qualification.

## Ownership

The project now assumes the original Dev A and Dev B are unavailable and does
not reserve future work for them.

```text
REPLACEMENT_DEV_A:
  KF-D-I -> KF-A-I -> KF-B-I

REPLACEMENT_DEV_B:
  KF-C-I1 -> KF-C-I2 -> KF-C-I3 -> KF-C-I4 -> KF-C-I5

ORIGINAL_DEV_A_B_RETURN_POLICY:
  assign remaining or new work; do not displace active replacement ownership
```

Tracking:

```text
KF-A-I=#304
KF-B-I=#79
KF-C-I=#48
KF-D-I=#305
BATTERY_BH1_BH7=#302
```

## Immediate operator work

### O1 — PR #28 P5F Reader

Exact head:

```text
e8a5ddd374a0d78ca175b2137cf73707150ca28a
```

Run exact-head static/JVM/Android-offline qualification. Do not contact a device.

### O2 — PR #29 C3B non-Reader readiness

Exact head:

```text
5468758dc42c372854fc6936e3800afc1ee33def
```

Run self-test, readiness/static and Android-offline merged-manifest qualification.
Do not contact a device.

### O3 — current SableOS main

Current design/planning main after Battery merge:

```text
0e42f2abf37182a8bc0f31bef26c337bb0e02211
```

Run:

```text
panther R9 ci full
panther R9 qualify physical-ux
```

These prove common source/build/security and module/product composition. They do
not authorize a device flash.

## Panther validation release candidate

Only after O3 PASS for the same source commit:

```text
panther R9 build --tmux
```

The build path requires the source-bound `PROFILE=full` local-CI attestation.
The release-candidate driver uses a fresh source-bound OUT and no Titan telephony
work.

After successful target-files registration, use the canonical artifact registry
and flash-plan path. Physical Panther flashing is a separate operator action and
requires explicit user authorization at that time.

## Panther issue exercise set

The next Panther RC must deliberately exercise:

```text
#120 Search -> Peek -> app security info -> Back
#121 Contacts and Phone->Contacts alphabet rail
#122 Media portrait tabs / mini-player / podcast-radio density
#82  single intended Messages launcher exposure
#84  pre-clear first-run crash history
#83  first-party icons and startup latency
#86  All Apps granted privacy permission summary
```

For each issue collect:

- exact source commit;
- target-files SHA-256 / flashed artifact identity;
- screenshots/video where visual;
- crash/exit evidence where stability-related;
- PASS/FAIL per acceptance item;
- negative-regression notes.

Do not close an issue from source/static evidence alone when it requires physical
Panther acceptance.

## Battery

Battery design/roadmap is merged:

```text
platform_sable#50=MERGED
sableos-project/.github#38=MERGED
aimindseye/sableos#303=MERGED
```

BH1-BH4 may be assigned after the Android Settings source-owner decision.
BH5 is capability discovery.
BH6 mutable charging control remains unauthorized until a validated device
backend exists.

## P1-P5

See `docs/titan2/P1_P5_CANONICAL_INTEGRATION_PACKAGES.md`.

## Success state for the waiting period

```text
PR28_OPERATOR_ANDROID=PASS
PR29_OPERATOR_ANDROID=PASS
SABLEOS_MAIN_CI_FULL=PASS
PANTHER_PHYSICAL_UX_PREBUILD=PASS
PANTHER_VALIDATION_RC=BUILT
PANTHER_COMMON_ISSUE_MATRIX=EXECUTED
P1_P5_CANONICAL_HANDOFF=READY
KF_REPLACEMENT_OWNERSHIP=ACTIVE
TITAN_CELLULAR_EVIDENCE_CHAIN=UNCHANGED
```
