# Titan 2 N1D C3 product composition R1

Status: **C3A active control; C3B Sable baseline held**

Date: 2026-10-01

## Architecture correction

The earlier handcrafted product `sable_titan2_n1d_arm64` is retired.

Live compilation proved that the handcrafted
`generic_system_arm64 + gsi_release` path enabled an AOSP
`aosp_system_image` dependency graph incompatible with the pinned GrapheneOS
source set.

C3A follows the known-successful Restless/TrebleDroid topology:

```text
GrapheneOS 2026061600
  + pinned public TrebleDroid/PHH scaffold
  + exact pinned Restless release patch stack
  + device/phh/treble/rom.mk
  + device/phh/treble/generate.sh rom
  -> treble_arm64_bvN
  -> lunch treble_arm64_bvN-bp4a-user
  -> systemimage
```

## Source pins

The clean Graphene base remains the previously sealed 1,033-project checkout.

Twelve additional public projects are admitted by
`build/titan2/n1d-c3-trebledroid-manifest.xml`, each by exact commit.
The Restless build recipe is pinned to:

```text
tag:    16.0.0-202606230923
commit: 4adc5766f457849ca37e0b318bced65aef5a2233
```

The private Restless vendor repository is not admitted.

## Patch layers

Two patch concepts are deliberately separate.

The **C3A control patch stack** reproduces the successful Restless release build:
five ordered tiers and 369 patches. It is allowed only for the non-release
compatibility control.

The **C3B Sable runtime patch allowlist** starts empty. Nothing in the
control stack becomes accepted Sable runtime policy simply because the control
image builds.

Nine build/make patches are also vendored in SableOS as a focused C3A audit set.
They include the Graphene-GSI dependency corrections and the ADB-authentication
correction that are directly relevant to product composition.

## Generator config

The repository-owned
`build/titan2/n1d-c3a-control-rom.mk` mirrors the successful Restless
`configs/rom/rom.mk` control configuration and is copied to
`device/phh/treble/rom.mk` before generation.

The expected generated product is:

```text
PRODUCT_NAME   = treble_arm64_bvN
PRODUCT_DEVICE = tdgsi_arm64_ab
PRODUCT_BRAND  = google
PRODUCT_MODEL  = TrebleDroid vanilla
```

Branding is intentionally not changed during this control phase. Sable product
identity is a later release-runtime concern.

## Preparation

Offline preflight:

```bash
bash build/titan2/prepare-n1d-c3-trebledroid.sh preflight
```

Pinned scaffold/recipe staging requires both explicit permissions:

```bash
bash build/titan2/prepare-n1d-c3-trebledroid.sh \
  stage \
  --authorize-source-mutation \
  --authorize-network
```

The stage archives the obsolete Android-tree `vendor/sable/n1d` product,
installs the pinned local manifest, syncs only the 12 admitted projects, fetches
the exact pinned Restless recipe, applies the exact 369-patch stack, and runs
`generate.sh rom`.

No Android target build occurs during this stage.

## Parse and first build

Product parse:

```bash
bash build/titan2/qualify-n1d-c3-product-parse.sh \
  --authorize-product-parse
```

First compile:

```bash
bash build/titan2/build-n1d-c3-trebledroid-systemimage.sh \
  --authorize-c3-compile \
  --authorize-network \
  --jobs 16
```

The network authorization is limited by contract to the pinned TrebleApp Gradle release prebuild. The driver runs `bash build.sh release` in `treble_app` before Restless's exact `make systemimage` invocation.

The first compile uses a fresh output directory:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3a-td
```

and authorizes only the TrebleApp release prebuild plus `systemimage`. Restless's subsequent `target-files-package`, `otatools`, signing and release packaging are intentionally deferred until this control compile succeeds.

## Release status

C3A proves reproducible build topology and compatibility, not release
security.

```text
N1D_C3_RELEASE_ELIGIBLE=NO
N1D_C3_RUNTIME_SECURITY_AUDIT_REQUIRED=YES
```

No device contact or flash is authorized.


## C3B peeling boundary

C3B does not inherit the C3A 369-patch stack. It starts from the pinned
Graphene/Treble scaffold with an empty runtime allowlist. A C3A patch or patch
pair may enter C3B only after a reproduced C3B failure identifies the need and
the security/runtime impact is reviewed.

```text
N1D_C3B_RESTLESS_FULL_PATCH_STACK_ALLOWED=NO
N1D_C3B_RUNTIME_PATCH_ALLOWLIST_INITIAL_COUNT=0
N1D_C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE
```
