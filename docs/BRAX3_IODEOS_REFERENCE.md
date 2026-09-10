# Brax3 / iodéOS external reference review

Status: **external implementation reference; not a SableOS trust or support baseline**.

Review date: **2026-09-10**.

This document records lessons from the Brax3 iodéOS repositories reviewed as source artifacts. The purpose is to improve SableOS non-Pixel architecture, especially MediaTek bring-up, without importing iodéOS, LineageOS, Brax3 or MediaTek trust assumptions wholesale.

## Reviewed repositories and exact source state

The review used local ZIP snapshots containing Git history from the following repositories:

```text
Brax3_IodeOs/manifests_android
  branch: v7.7
  HEAD:   bc76dc243fd0dc58264ba06c0e9f2a5e38ed86b1

Brax3_IodeOs/device_brax_brax3
  branch: v7.7
  HEAD:   7616294e7c23f34cec744f7fb9c08cb75ee4569b

Brax3_IodeOs/device_brax_brax3-kernel
  branch: v7.7
  HEAD:   cdb0c4de0f6bee76e28144bc6d5e6441620237d3

Brax3_IodeOs/vendor_brax_brax3
  branch: v7.7
  HEAD:   677459b41158a5d5dd7753685e4a9568e21dd11e

Brax3_IodeOs/brax3_spflash_vendor
  branch: v7.7
  HEAD:   559dd41018297049d96f3e87ffebd0047f9eb55e

Brax3_IodeOs/build
  branch: main
  HEAD:   14dcfc994efc580b825cb784f0dff17ddc02ecda
```

Upstream repository group:

- https://git.os-source.co/Brax3_IodeOs

## High-level architecture

The Brax3 stack is layered rather than implemented as a GSI-only adaptation:

```text
AOSP Android 16
    -> LineageOS 23.2
    -> iodéOS platform forks
    -> Brax3 manifest overlay
    -> Brax3 device tree
    -> prebuilt kernel / DTB / DTBO / kernel modules
    -> proprietary MediaTek vendor userspace and firmware
    -> device-specific release / flash packaging
```

The Brax-specific manifest layer introduces a small set of projects:

```text
hardware/mediatek
device/brax/brax3
device/brax/brax3-kernel
vendor/brax/brax3
```

This clear ownership boundary is a useful reference for future SableOS non-Pixel manifests.

## Kernel finding: prebuilt support package, not source tree

`device_brax_brax3-kernel` is not a conventional Linux kernel source repository.

The device tree selects:

```make
TARGET_KERNEL_PATH := device/brax/brax3-kernel
TARGET_PREBUILT_KERNEL := $(TARGET_KERNEL_PATH)/kernel
```

The repository carries:

- a prebuilt kernel image;
- `mtk.dtb`;
- `dtbo.img`;
- kernel UAPI headers;
- prebuilt `vendor_boot` kernel modules;
- prebuilt `vendor_dlkm` kernel modules.

The supplied snapshot contained 196 `vendor_boot` modules and 181 `vendor_dlkm` modules.

This is an important precedent: modern Android userspace can be maintained above an opaque/vendor-controlled kernel and module set, but this does **not** provide the same kernel-security ownership as a source-built supported kernel.

## Device partition and update model

The Brax3 tree uses a modern Android partition model including:

- A/B OTA;
- Virtual A/B;
- dynamic partitions;
- `super`;
- `boot`;
- `init_boot`;
- `vendor_boot`;
- `dtbo`;
- `system`;
- `system_ext`;
- `product`;
- `vendor`;
- `vendor_dlkm`;
- `system_dlkm`;
- `odm_dlkm`;
- metadata and file-based encryption;
- EROFS for read-only product/system/vendor-family filesystems;
- F2FS userdata.

The device tree defines a roughly 9 GiB `super` partition and a MediaTek dynamic-partition group containing the Android logical partitions.

The design is substantially closer to a real device port than a system-only GSI experiment.

## Vendor / BSP dependency

The proprietary-file inventory is large and includes security-critical and hardware-critical components, not only camera and graphics blobs.

Observed classes include:

- MediaTek radio / `mtkradioex` interfaces;
- IMS / VoLTE / RCS components;
- camera services and libraries;
- graphics and media libraries;
- audio stack components;
- GNSS;
- Bluetooth;
- fingerprint;
- NVRAM;
- thermal / power services;
- Trustonic KeyMint;
- Trustonic Gatekeeper;
- TEE services;
- Widevine and DRM components.

The reviewed `proprietary-files.txt` contained 1478 lines including comments/sections and a large install inventory. The generated vendor repository contains hundreds of prebuilt shared libraries and binaries.

This means a functional Brax3 Android 16 port still relies on a substantial proprietary MediaTek BSP trust boundary.

## Framework/vendor compatibility shims

`extract-files.py` demonstrates active ABI adaptation between newer Android userspace and the older vendor BSP. Examples include:

- `add_needed()` compatibility dependencies;
- `replace_needed()` substitutions for older library/HAL names;
- binary property/string substitutions;
- SONAME corrections;
- KeyMint interface dependency adaptation;
- graphics/audio/sensor compatibility replacements.

This is important for SableOS planning. A newer Android framework plus an older MediaTek vendor stack should be expected to require explicit compatibility work rather than being treated as a passive binary copy operation.

Compatibility shims must be individually documented, testable and version-bound. They are maintenance debt and potential security boundaries, not invisible plumbing.

## Radio and IMS lesson

Brax3 preserves MediaTek telephony and IMS infrastructure rather than replacing the modem protocol.

The vendor/device integration includes MediaTek framework libraries, IMS service APKs and `mtkradioex` AIDL libraries. This reinforces the SableOS telephony rule:

```text
Sable telephony semantics
    -> narrow Android-facing broker where needed
    -> supported Android Radio / IMS interfaces
    -> vendor MediaTek RIL / IMS stack
    -> modem firmware
```

A device reaching the launcher and obtaining packet data is not enough to qualify telephony. Non-Pixel acceptance must separately validate:

- SIM and multi-SIM behavior;
- LTE / 5G;
- packet data;
- voice;
- SMS/MMS;
- IMS;
- VoLTE;
- VoWiFi where applicable;
- carrier configuration;
- emergency-calling path without placing routine live emergency-service test calls.

## Firmware ownership lesson

The Brax3 OTA model updates more than Android userspace. Its partition set includes low-level firmware such as modem, TEE and SoC-side components.

The reviewed artifacts include families such as:

```text
connsys_bt
dpm
gz
lk
mcf_ota
mcupm
md1img
pi_img
scp
spmfw
sspm
tee
vcp
```

This is a materially stronger lifecycle model than a pure GSI over permanently frozen stock firmware.

For future SableOS non-Pixel support, OEM delivery of current signed firmware/BSP artifacts may be useful even when full source is unavailable, but opaque firmware remains a separate trust and maintenance dependency.

## AVB lesson

The Brax3 device tree has a useful multi-key structure for OEM/root vbmeta, boot, system and vendor chains with separate rollback-index locations.

However, when the private Brax OEM key is unavailable, the reviewed configuration falls back to the public AOSP AVB test key and sets:

```make
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
```

This is acceptable only as an explicitly classified development behavior.

SableOS production policy is stricter:

```text
production/release-candidate key missing
    -> hard build/release failure
```

A production SableOS build must never silently degrade to public test keys or verification-disabled vbmeta.

## Security-patch provenance lesson

The reviewed Brax3 tree declares:

```make
VENDOR_SECURITY_PATCH := 2026-01-05
```

while later kernel/vendor repository changes exist. This field alone does not prove the complete effective vendor patch status, but it demonstrates why SableOS must track platform, vendor, kernel/boot, modem, TEE and bootloader provenance independently.

A single Android security-patch string is not sufficient evidence for a non-Pixel release claim.

## SELinux lesson

The Brax3 tree shows useful targeted policy maintenance rather than a broad permissive-device strategy. For example, an NFC regression was corrected with a narrow device permission rather than disabling enforcement.

SableOS should continue to treat SELinux AVCs and `neverallow` failures as architecture evidence, not invitations to broadly relax policy.

## Flashing and recovery lesson

`brax3_spflash_vendor` separates vendor-supplied MediaTek flashing assets from the Android source tree. It contains preloader variants, a MediaTek scatter map, a Download Agent and modem/carrier artifacts.

That repository boundary is useful. Low-level vendor recovery/flashing inputs should be versioned separately from common Android source and bound to explicit device/BSP releases.

The supplied `flash.sh`, however, is not a model for SableOS release tooling. It directly issues fastboot flash commands and does not itself demonstrate the safeguards SableOS requires, such as:

- exact product identity;
- expected partition layout and size;
- slot-state verification;
- artifact SHA-256 verification immediately before write;
- bootloader/verified-boot state classification;
- bounded mutation authorization;
- fail-closed handling of missing or unexpected files.

A later Brax userdata-size validator is a much better pattern: qualify real hardware variation before allowing an image layout to be considered safe.

## Build reproducibility lesson

The Brax build wrapper is useful as a reproducible-build direction but is not itself a sufficient immutable release definition.

Useful ideas:

- keep host/build-container mechanics outside the Android source tree;
- use a small wrapper around manifest sync and target build;
- keep release tooling visibly separate from device implementation.

Issues observed in the reviewed build repo:

- the public wrapper still initializes manifest branch `v7.5` while the reviewed device/manifest stack is `v7.7`;
- Docker starts from `ubuntu:22.04` by tag rather than an immutable digest;
- Android platform tools are downloaded from `platform-tools-latest-linux.zip`;
- host apt packages are not content-pinned;
- the Dockerfile comments about a non-root build user but ends with `USER root`;
- `${BUILD_USER}` is referenced in a `chown` without an obvious definition in the reviewed wrapper;
- the Android manifest uses many moving release branches rather than a generated revision-pinned release manifest.

SableOS release reproducibility should instead bind:

```text
base-container digest
host/build-tool versions
repo manifest -r / exact project revisions
vendor/BSP artifact hashes
kernel/module/DTB/DTBO hashes or source provenance
Sable source hashes
signing identity
build date/build number
resulting target-files / image hashes
```

## Cross-repository issue to verify upstream

The Brax3 `BoardConfig.mk` defines:

```make
TARGET_KERNEL_PATH := device/brax/brax3-kernel
```

but later references:

```make
TARGET_PREBUILT_KERNEL_HEADERS := $(KERNEL_PATH)/kernel-uapi-headers.tar.gz
```

No `KERNEL_PATH` definition was found in the six reviewed repositories. This may be supplied by another upstream project; therefore this review records it as an unresolved cross-repository dependency rather than a proven defect.

## Resulting SableOS decisions

Adopt or reinforce:

1. Keep non-Pixel device ownership explicit through small manifest/device/vendor/kernel-prebuilt/firmware layers.
2. Treat prebuilt kernel support as functionally viable but security-lifecycle-limited.
3. Keep proprietary MediaTek radio/IMS/camera/audio/security stacks behind Android/vendor interfaces during initial bring-up.
4. Inventory and version every ABI shim between Android framework and vendor BSP.
5. Track platform, kernel, vendor, modem, TEE and bootloader security provenance separately.
6. Treat A/B update, firmware delivery and recovery as product architecture, not post-port packaging details.
7. Use exact release keys and fail closed in release/production builds.
8. Qualify physical partition/layout variation before flashing or release packaging.
9. Preserve SELinux enforcing and prefer targeted policy corrections.
10. Use immutable revision manifests and content-pinned build environments for Sable releases.

Reject as Sable production patterns:

- public AVB test-key fallback;
- verification-disabled vbmeta fallback;
- unguarded multi-partition flash scripts;
- moving `latest` build-tool downloads in the release environment;
- moving branch heads as the only release source record;
- treating a booting GSI as evidence of complete hardware or security support.

## Applicability

### Titan 2

Brax3 is highly relevant because it proves that useful modern Android device integration can be maintained above a prebuilt MediaTek kernel/BSP. Titan 2 should nevertheless begin as a development GSI/userspace lab until its exact stock partition, VINTF, firmware, bootloader, AVB, radio/IMS and recovery behavior are qualified.

### Zinwa Q25

Q25 remains a stronger low-level MediaTek research platform when maintainable kernel/community source is available. Its value is kernel/device experimentation rather than being mandatory for the SableOS product roadmap.

### Zinwa Q27

Q27 remains the preferred future physical-QWERTY full-device candidate only after real hardware and source/BSP/security-lifecycle evidence are available. The Brax3 model demonstrates that OEM cooperation on current BSP/firmware artifacts can materially improve support even if some components remain proprietary, but it does not remove SableOS security-support requirements.

## References

- https://git.os-source.co/Brax3_IodeOs
- https://source.android.com/docs/core/architecture/vintf
- https://source.android.com/docs/core/ota/dynamic_partitions/implement
- https://source.android.com/docs/core/architecture/kernel/gki
- https://grapheneos.org/build
- `ARCHITECTURE.md`
- `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`
- `TITAN2_GSI_PLAN.md`
- `Q25_PORT_PLAN.md`
- `RELEASE_VALIDATION.md`
