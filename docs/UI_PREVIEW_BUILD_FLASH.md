# Panther UI preview build and inactive-slot flash

This is the accelerated development path for reviewing the merged Sable UI refresh on Pixel 7 (`panther`).

It intentionally combines the former UI4R4 build/runtime gate with a state-aware preview flash handoff. It does **not** wait for UI5 or UI6, and it does not claim production/release qualification.

## What the first preview contains

The preview image is intended to contain:

- UI1 SableStart and the shared Sable Design source;
- UI4R1 Quick Settings geometry/theme alignment;
- UI4R2 notification shade geometry;
- UI4R3 SystemUI media geometry;
- the already-existing Sable/GrapheneOS bounded product delta present in the canonical workspace.

UI2/UI2G/UI3 application redesigns are still standalone-qualified application workstreams. They do not block this first SystemUI/SableStart image. Their final `PRODUCT_PACKAGES`/prebuilt integration can be combined into a later image tranche rather than delaying UI review now.

## Why this can be flashed now

UI4R1-R3 are merged and the cumulative applicator is pinned to exact GrapheneOS 2026081300 source blobs. The remaining UI4 work is product execution: apply the delta in the canonical Panther workspace, compile, verify packaging, flash a coherent partition set, and visually review the result.

The preview builder fails before flash if either `SystemUI.apk` or `SableStart.apk` is absent from target-files.

## Build in one command

Set `SABLEOS_UPSTREAM` to the canonical GrapheneOS 2026081300 workspace. If the build tree was moved to the new large drive, use that path rather than the historical example.

Example using the historical workspace location:

```bash
cd /path/to/aimindseye-sableos

export SABLEOS_UPSTREAM=/srv/data/sableos_panther_graphene_2026081300_workspace
export SABLEOS_UI_PREVIEW_OUT=/srv/data/sableos-ui-preview-out
export SOURCE_MUTATION_AUTHORIZED=YES
export BUILD_AUTHORIZED=YES

bash build/panther/build-ui-preview.sh
```

The script:

1. self-tests and applies/verifies the cumulative UI4R1-R3 SystemUI delta;
2. syncs the shared `SableDesign` Soong filegroup;
3. syncs current SableStart;
4. builds `SableStart`, `SystemUI`, vendor boot inputs, and the Panther target-files package;
5. proves both SystemUI and SableStart are present in target-files;
6. requires `system.img`, `product.img`, `system_ext.img`, and `vbmeta.img`;
7. writes `UI_PREVIEW_IMAGES.sha256`;
8. records build-warning candidates for review.

Default preview lunch target is `panther-cur-userdebug`. Override with `SABLEOS_UI_PREVIEW_LUNCH_TARGET` only when intentionally testing another variant.

## Flash the inactive slot

The flash gate preserves userdata and chooses the opposite slot at runtime. It refuses non-Panther devices, locked bootloaders, active snapshot updates, missing hashes, multiple fastboot devices, or missing authorization flags.

```bash
export DEVICE_CONTACT_AUTHORIZED=YES
export DEVICE_REBOOT_AUTHORIZED=YES
export FLASH_AUTHORIZED=YES
export SLOT_CHANGE_AUTHORIZED=YES

bash build/panther/flash-ui-preview-inactive-slot.sh \
  /srv/data/sableos-ui-preview-out/target/product/panther
```

The coherent preview set is:

```text
system_<inactive>
product_<inactive>
system_ext_<inactive>
vbmeta_<inactive>
```

`vbmeta` is written last. There is no userdata or metadata wipe. The current slot remains the rollback side until the inactive-slot preview is explicitly made active.

This extends the previously validated D3 deployment set because UI4 modifies SystemUI in `system_ext`.

## Runtime gate and screenshots

After Android boots:

```bash
export DEVICE_CONTACT_AUTHORIZED=YES
export CAPTURE_UI=YES

bash build/panther/validate-ui-preview.sh
```

The runtime gate verifies boot completion, records slot/build/encryption identity, verifies both SystemUI and SableStart are installed, and optionally captures:

- Quick Settings;
- SableStart.

Human visual review should then cover Quick Settings active/inactive states, brightness/footer geometry, notifications, media controls when a session is active, Start layout, dark/light/accent behavior, clipping, text truncation, touch targets, and accessibility.

## Decision

Do not wait for UI5/UI6 before this preview flash. Use the first device pass to find cross-surface visual problems early, then continue UI5/UI6 against real Pixel feedback.

This is a development preview path. Production signing, OTA generation, release keys, userdata wiping, bootloader locking, and release-candidate claims remain out of scope.
