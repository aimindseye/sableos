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
4. builds `SableStart`, `SystemUI`, vendor boot inputs, the Panther target-files package, and otatools;
5. proves both SystemUI and SableStart are present in target-files;
6. generates a coherent fastboot image ZIP with `img_from_target_files`;
7. verifies the image ZIP contains the boot-critical, vbmeta, super metadata, and dynamic-partition images required by the packaged `fastboot-info.txt`;
8. proves the image ZIP's `fastboot-info.txt` is byte-identical to the target-files copy;
9. writes a SHA-256 ledger for the fastboot image ZIP;
10. records build-warning candidates for review.

Default preview lunch target is `panther-cur-userdebug`. Override with `SABLEOS_UI_PREVIEW_LUNCH_TARGET` only when intentionally testing another variant.

## Flash the inactive slot

The preview flash uses the coherent image ZIP produced by
`img_from_target_files`. It does not manually select a subset of AVB-protected
partitions.

This matters because the Panther target's `vbmeta.img` authenticates the boot
chain and the dynamic partition set. A partial flash can therefore create a
slot where the new vbmeta descriptors do not match old boot/vendor images.

The packaged `fastboot-info.txt` is authoritative for the preview image. For
the current Panther target it includes the boot-critical images, applies
vbmeta, reboots to fastbootd, updates the super metadata, and flashes the six
dynamic partitions.

The flash helper:

- requires fastboot 35.0.1 or newer;
- verifies the image ZIP SHA-256 ledger;
- verifies the required image members and fastboot-info contract;
- refuses non-Panther devices, locked bootloaders, active snapshot updates, or
  multiple fastboot devices;
- discovers the inactive slot at runtime;
- invokes `fastboot update` with `--slot=<inactive>`,
  `--skip-secondary`, and `--skip-reboot`;
- never passes `-w`, so the packaged conditional userdata/metadata erase
  operations do not run;
- returns to bootloader fastboot for a post-flash active-slot check before
  booting Android.

Example:

```bash
export FASTBOOT=/path/to/platform-tools/fastboot
export ADB=/path/to/platform-tools/adb

export DEVICE_CONTACT_AUTHORIZED=YES
export DEVICE_REBOOT_AUTHORIZED=YES
export FLASH_AUTHORIZED=YES
export SLOT_CHANGE_AUTHORIZED=YES

bash build/panther/flash-ui-preview-inactive-slot.sh \
  /path/to/out/target/product/panther/sable_panther-ui-preview-images.zip
```

Do not use a distribution-provided legacy fastboot when it fails the version
gate. Use a current Android Platform Tools fastboot or an equivalently current
qualified build.

The previous four-image preview set
(`system/product/system_ext/vbmeta`) is retired. It was insufficient for the
generated AVB contract because the same vbmeta also authenticates
`boot`, `dtbo`, `init_boot`, `pvmfw`, `vendor_boot`,
`vendor_kernel_boot`, `system_dlkm`, `vendor`, and `vendor_dlkm`.

The known-good current slot is preserved as the rollback side through
`--skip-secondary`.

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


## Known pre-existing Panther security delta

The current R8 Panther workspace carries one intentional pre-existing
`frameworks/base` security/product delta in addition to the Sable boot mask:

```text
core/res/res/values/config_ext.xml
git blob: 8264085d12533d294eab24aae55ca40830bfb62b
sha256: 771a39703f97d0be7138f1f9b2ba510431dd98163309fb2a92728916d77175de
```

This delta removes the bundled GrapheneOS Auditor certificate digest from
`read_additional_security_state_known_signers`. The current Sable product
does not select Auditor, the Auditor project is not present in the repo
manifest, and no Auditor artifact was found in the existing Panther product
output.

The UI4 applicator therefore accepts this pre-existing state only when the
file matches the exact blob above. It also binds the existing Sable boot-mask
blob exactly:

```text
core/res/assets/images/android-logo-mask.png
git blob: bec81216db3ed6976f305fd496ed757f0788f702
sha256: dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e
```

Any other content at either path remains a hard failure. This is not a general
permission for extra `frameworks/base` dirt.
