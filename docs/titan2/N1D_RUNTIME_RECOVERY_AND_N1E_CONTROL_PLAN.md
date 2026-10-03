# Titan 2 N1D runtime recovery and N1E control plan

Status: **current runtime-recovery authority**
Updated: **2026-10-03 ET**

This document supersedes the earlier assumption that the next canonical step is
another N1D/C3B boot attempt followed directly by E6. The N1D build remains a
valid sealed build artifact, but it is not a boot-qualified Titan 2 baseline.

## Current evidence

```text
RECOVERY_PLAN_BASE_MAIN=f08aac781e58b549e63d7104d495993917d43353
N1D_C3B_E3_BUILD=PASS_SEALED
N1D_PHYSICAL_RESULT=FAIL_REBOOT_LOOP
N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0
N1D_RUNTIME_PATCH_ALLOWLIST_COUNT_ZERO=PRIMARY_SUSPECT_NOT_PROVEN_ROOT_CAUSE
CURRENT_STOCK_FIRMWARE=V01.00.14
HISTORICAL_N1B_BOOT_FIRMWARE=V01.00.13
N1D_E6=FROZEN
N1D_REFLASH=HOLD
```

The current working hypothesis is that removing the TrebleDroid/RestlessOS
runtime-compatibility baseline from N1D exposed a system/vendor compatibility
failure. That hypothesis is not yet a proven root cause. The V01.00.13 ->
V01.00.14 vendor/firmware change and AVB/dm-verity behavior remain uncontrolled
until the N1B control is repeated on the current device state.

Do not describe `COUNT=0` as proven causal. A successful N1B control isolates
the failure to the broad N1D system-side delta; N1E performs the next controlled
isolation.

## Physical control: N1B on current firmware

The next physical experiment is the exact sealed N1B system artifact on the
current V01.00.14 device state.

Required deployment model:

```text
TARGET=active system_a through userspace fastbootd
SLOT_POLICY=keep current slot
WHOLE_SUPER_PRIMARY_PATH=NO
BOOT_VENDOR_BOOT_VBMETA_MUTATION=NO
FACTORY_RESET_AFTER_SYSTEM_FLASH=YES
TELEMETRY_CAPTURE=ARMED_FOR_TRANSIENT_ADB
```

No new N1D build or hybrid `super.img` experiment precedes this control.

Decision:

```text
if N1B boots on V01.00.14:
    current device/vendor state is compatible with N1B
    authorize N1E construction and qualification
else:
    do not build/flash N1E
    investigate V01.00.13 -> V01.00.14, boot-chain and current-device-state delta
```

A failed N1B control does not by itself prove that V01.00.14 is the sole cause.

## N1E definition

N1E is an isolation build, not the final Sable Titan 2 wrapper product.

```text
N1E =
  exact authoritative N1B workspace state
  + exact N1B generated treble_arm64_bvN product
  + exact N1B lunch combo
  + one rom.mk inherit of vendor/sable/titan2/sable-titan2-apps.mk
  + exactly five C3B application modules
```

N1E must not introduce the `sable_titan2` wrapper identity. In particular,
`TARGET_PRODUCT`, `PRODUCT_NAME`, brand, model and manufacturer remain the
N1B values.

The five admitted modules are:

```text
SableTitan2Keyboard
SableTitan2Camera
SableTitan2DisplayCompat
SableTitan2Setup
SableTitan2RadioDiag
```

The current C3B imports are product-specific, non-privileged Android app imports.
N1E does not add a privapp allowlist, product-identity properties, RROs, role
ownership, IME defaulting or other product behavior.

## N1E pre-flash qualification

The reviewed qualification design is G0 -> G1 -> G2 and is fail-closed.

```text
N1E_QUALIFICATION_DESIGN=PASS
UPSTREAM_SYNTHETIC_SELFTEST=PASS cases=47
REAL_HOST_SELFTEST=PENDING
REAL_N1B_CAPTURE=PENDING
N1E_DELTA_APK_HASH_BINDING=PENDING
N1E_BUILD_AUTHORIZED=NO_PENDING_N1B_CURRENT_FIRMWARE_CONTROL
N1E_FLASH_AUTHORIZED=NO
```

G0 proves source/provenance parity plus the exact staged `vendor/sable` payload.
G1 proves build-variable parity plus the declared five-module delta and measured
stock VNDK requirements. G2 compares AVB policy/layout, compatibility substrate,
SELinux mapping parity, extracted-image ownership/inventory and the exact image
delta.

The real qualification host must rerun the self-test with its own `aapt2`,
`avbtool`, framework manifest and Android SDK jar. A successful real N1B
`capture` is required because successful capture has not been demonstrated by
the synthetic self-test.

## Developer-source lane

`aimindseye/titan2-temp` remains a parallel product-source candidate lane. It
does not own the Android base, compatibility policy, image, flash, SELinux,
radio/IMS or production signing.

Current draft deliverables:

```text
PR_28=P5F_READER_RUNTIME_READINESS_DRAFT
PR_28_ANDROID_COMPILE=PENDING_OPERATOR
PR_28_LINT=PENDING_OPERATOR
PR_28_MERGED_MANIFEST=PENDING_OPERATOR
PR_28_DEVICE_RUNTIME=NOT_RUN

PR_29=C3B_NON_READER_RUNTIME_READINESS_DRAFT
PR_29_STATIC_AND_MUTATION=PASS_DEVELOPER
PR_29_ANDROID_OFFLINE=PENDING_OPERATOR
PR_29_DEVICE_RUNTIME=NOT_RUN
```

PR #28 contains Reader runtime-readiness tooling plus bounded source corrections.
It must remain draft until exact-head operator Android compile/lint/unit/merged-
manifest qualification is complete. Device qualification is separate and must
not be used to bypass the canonical Titan boot-baseline recovery.

PR #29 contains non-Reader runtime-readiness/evidence tooling only. Its static,
Python and mutation evidence is useful, but its `--android-offline` path still
requires operator execution with a base that precedes the Android source delta.
It makes no runtime admission claim.

Neither PR is a reason to change the N1B -> N1E physical-control sequence.

## Execution order

```text
1. finish N1E delta hash binding from the sealed E2 APK bundle (offline)
2. run qualification-host selftest
3. flash exact sealed N1B to current V01.00.14 using the proven system_a path
4. factory reset and capture boot telemetry

if N1B PASS:
    5. capture authoritative N1B source/product state
    6. construct minimal N1E
    7. capture N1E using N1B lunch identity
    8. run G0 -> G1
    9. build N1E systemimage
   10. extract N1B/N1E identically with ownership preserved
   11. run G2
   12. only a clean qualification authorizes N1E flash
   13. if N1E boots, reintroduce sable_titan2 wrapper/product identity as a later delta

if N1B FAIL:
    5. stop N1E
    6. investigate firmware/boot-chain/current-device-state delta
```

E6 runtime qualification resumes only after a boot-qualified baseline exists.

## Safety boundary

```text
N1D_REFLASH_AUTHORIZED=NO
N1E_FLASH_AUTHORIZED=NO
WHOLE_SUPER_EXPERIMENT_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
OTA_AUTHORIZED=NO
PUBLIC_TITAN_FLASH=NO
```
