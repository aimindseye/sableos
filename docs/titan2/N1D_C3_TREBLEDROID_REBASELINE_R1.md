# Titan 2 N1D C3 TrebleDroid rebaseline R1

Date: 2026-10-01

## Purpose

Reproduce the exact public build topology that successfully produced the
RestlessOS Android 16 ARM64 A/B GSI, while separating build reproducibility from
SableOS release-runtime acceptance.

## Known-good recipe

The pinned Restless release performs this sequence:

```text
Graphene source sync
local Treble manifests
patch tiers:
  trebledroid
  trebledroid-staging
  rom
  personal
  release-builds
copy configs/rom/rom.mk -> device/phh/treble/rom.mk
device/phh/treble/generate.sh rom
treble_app/build.sh release
lunch treble_arm64_bvN-bp4a-user
make systemimage
```

N1D follows the same topology with exact immutable pins and a Sable-owned
driver.

## Immutable inputs

```text
GrapheneOS tag:
  2026061600

RestlessOS tag:
  16.0.0-202606230923

RestlessOS commit:
  4adc5766f457849ca37e0b318bced65aef5a2233

device/phh/treble:
  39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed
```

The remaining companion projects and exact commits are declared in
`n1d-c3-trebledroid-manifest.xml`.

## Control vs release

The full 369-patch Restless stack is admitted only to reproduce the known-good
**control** build.

It is not the Sable release patch allowlist.

```text
control patch count:          369
release runtime allowlist:      0
control release eligible:      NO
```

This lets C3 establish a compiling/bootable compatibility baseline first. Later
work removes or replaces control-only runtime mechanisms and promotes only
reviewed Titan-specific deltas.

## Why this supersedes the handcrafted product

The retired handcrafted C3 product repeatedly reached Soong graph generation
and failed because `aosp_system_image` required Graphene-absent AOSP modules:
`webview`, `Browser2`, `Camera2`, `messaging`, and
`QuickSearchBox`.

The known-good Restless build explicitly patches those GSI dependency lists and
uses the TrebleDroid-generated product. Reproducing that established topology is
lower risk than continuing to reverse-engineer its effects into a separate
handmade GSI product.

## First success criterion

The immediate target is a successful, non-release
`treble_arm64_bvN-bp4a-user` `system.img`, built after the same TrebleApp release prebuild used by Restless. Target-files, otatools and signing remain a later gate.

That success does not authorize flash. The next phase is a runtime/security
delta audit against the control image before any Sable identity or release
claim is made.
