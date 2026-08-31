# PANTHER-P0R1 Android 17 source/provenance qualification

Status: **PASS / P1A AOSP-DECOUPLING AUDIT NEXT**.

## Purpose

P0R1 qualified whether Pixel 7 (`panther`) can remain on an Android 17 Sable path despite Google's legacy `device/google/pantah` / downloadable-driver publication model stopping after Android 15.

No Android workspace was created, no Sable source was mutated, no image was built or flashed, ADB root was not used, and the device was not rebooted.

## Physical baseline

Observed device state:

```text
device=panther
build=CP2A.260705.006
release=17
sdk=37
spl=2026-07-05
vendor_spl=2026-07-05
selinux=Enforcing
```

The device remained unchanged through the gate and stayed on slot `_b`.

## AOSP Android 17 baseline

Validated:

```text
AOSP tag: android-17.0.0_r1
manifest tag SHA: 7a9e46ba6ed424f922a3457f4964e67e0b966201
android17-release manifest SHA: 29ace668ae756c7b8917c57abb440f6518844b0c
```

The Android 17 release branch reports Rust 1.93.1. The `android-17.0.0_r1` Rust-toolchain repository contains 1.91.1, 1.92.0 and 1.93.1 prebuilts, so the Android 17 platform is no longer constrained by the bramble-era Rust 1.68 generation. The exact default compiler used by the selected pinned workspace must still be verified after sync rather than inferred from directory presence.

## Signed external reconstruction reference

The GrapheneOS stable tag `2026081300` was used as a **reference/provenance source**, not selected as the Sable OS substrate.

Tag verification passed with the published GrapheneOS ED25519 signer.

The reference manifest defaults to:

```text
refs/tags/android-17.0.0_r1
```

Pinned small external inputs discovered from that signed manifest:

```text
vendor/adevtool
5019450d9235c48a987250c890e346b416f8dfd4

vendor/state
d69d029d7fe3745049e80ad64ad1967a9cac8e5f

device/google/pantah-kernels/6.1
b3fd241e7f8b3283c864b3e6e464f853defb5997
```

All three exact checkouts were verified.

## Pixel 7 generation configuration

Pinned `adevtool` configuration resolves:

```text
device: panther
platform: gs201
build_id: CP2A.260705.006
```

This exactly matches the physical device build captured by P0R1.

The generated panther product configuration is capable of defining `PRODUCT_NAME := panther` without the legacy public `device/google/pantah` tree. It inherits an AOSP generic/handheld product base and adds Pixel-specific generated vendor/VINTF/sysconfig/proprietary material.

## Important GrapheneOS-coupling correction

The initial P0R1 harness reported:

```text
grapheneos_forked_aosp_projects=0
```

That marker is **not evidence that the full GrapheneOS manifest is vanilla AOSP**. The parser counted only projects carrying a specific `aosp-name` attribute and therefore missed GrapheneOS-remote replacements/custom projects.

The signed manifest contains numerous `remote="grapheneos"` projects, including platform/device replacements and security components. Sable therefore continues to reject wholesale GrapheneOS as an implicit substrate.

The pinned `adevtool` Pixel product configuration also contains GrapheneOS-specific hooks. Examples found during follow-up validation include:

```text
GosOverlay
init.gs201.grapheneos.rc
init.pixel.grapheneos.rc
CarrierConfig2
GosTelephonyProviderOverlay
GosTelephonyOverlay
gos-dhdutil
restrict-pixel-health-association
```

These must be audited and removed, replaced or explicitly adopted on their own merits before using `adevtool` output in a pure-AOSP Sable workspace.

## `vendor/state` trust classification

`vendor/state/panther.json` was present and pinned, but its contents include GrapheneOS product state such as `Auditor.apk`.

Therefore:

```text
vendor_state = reference/output-verification evidence
vendor_state != stock Pixel vendor payload
vendor_state != automatic Sable product input
```

No GrapheneOS application or platform policy is inherited merely because the reference state is useful to understand generation behavior.

## Factory/recovery baseline correction

The host HTML grep used in P0R1 did not expose Google's dynamic factory/OTA table and therefore returned zero references. That result was a harness limitation.

Authoritative Google factory-image listings show Pixel 7 (`panther`) Android 17 factory images through:

```text
CP2A.260605.012  Jun 2026
CP2A.260705.006  Jul 2026
```

and no August 2026 Pixel 7 factory image in the panther section as of the current check.

This means `CP2A.260705.006` is not merely an old convenient input: it is the latest official Pixel 7 factory/recovery baseline currently published by Google and it exactly matches the physical device plus the pinned `adevtool` panther configuration.

GrapheneOS's August 2026 release separately reports a full 2026-08-05 Pixel SPL and August Pixel driver/firmware code. Those backports/updates are useful security reference material but are **not** silently substituted for the official July stock recovery baseline in the first Sable vanilla bring-up.

## Kernel reference

The pinned `pantah-kernels/6.1` reference contained 341 non-git files including the kernel image/support modules and `dtbo` material expected for the current Pixel 7 6.1 path.

The kernel reference remains external input whose source/provenance and any GrapheneOS-specific kernel changes must be classified separately before production adoption.

## Reconstruction policy

Accepted direction after P0R1:

```text
base platform:
    AOSP android-17.0.0_r1

stock/recovery/vendor extraction baseline:
    Pixel 7 CP2A.260705.006

external references/tools:
    pinned adevtool
    pinned vendor-state evidence
    pinned pantah 6.1 kernel reference

not accepted implicitly:
    full GrapheneOS platform manifest
    GrapheneOS-only product modules
    GrapheneOS applications
    GrapheneOS security policy/patches without separate review
```

Sable may fork or minimally patch `adevtool` configuration if that is the cleanest auditable way to generate Pixel support from stock images. Generated outputs must be diffed and classified rather than trusted as opaque blobs.

## Gate result

```text
PANTHER_P0R1_CAPTURE=PASS
PANTHER_P0R1_AOSP17_PREFERRED=YES
PANTHER_P0R1_STOCK_BASELINE=CP2A.260705.006
PANTHER_P0R1_GRAPHENEOS_OS_SUBSTRATE=NO
PANTHER_P0R1_ADEVTOOL=QUALIFIED_REFERENCE_REQUIRES_DECOUPLING
PANTHER_P0R1_VENDOR_STATE=REFERENCE_ONLY
PANTHER_P0R1_DEVICE_UNCHANGED=PASS
PANTHER_P0R1_WORKSPACE_CREATED=NO
PANTHER_P0R1_SABLE_SOURCE_MUTATED=NO
PANTHER_P0R1_BUILD_PERFORMED=NO
PANTHER_P0R1_FLASH_PERFORMED=NO
```

## Next gate

`PANTHER-P1A` is a host-only **AOSP-decoupling audit** of the pinned Pixel support configuration. It must enumerate the complete panther include chain and every GrapheneOS-only package/init/policy/build dependency before the large Android 17 workspace is created.

If the coupling is bounded, `PANTHER-P1B/V0-HOST` will create a separate Android 17 workspace, sync the pinned AOSP tag, introduce only reviewed Pixel support inputs, generate the vendor module from the official July Pixel 7 image, prove the panther product graph and Rust toolchain, and attempt the first vanilla host build. No flash occurs until that host gate closes.
