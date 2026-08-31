# PANTHER-P0 — Pixel 7 device/source/toolchain baseline

Status: **PASS / Android 17 preferred candidate / source reconstruction qualification next**.

## Purpose

PANTHER-P0 is the first read-only gate after moving active SableOS development from Pixel 4a 5G (`bramble`) to Pixel 7 (`panther`). It does not select a renderer and does not mutate Sable source, create a new Android workspace, build images, flash, reboot, or use `adb root`.

Normative transition: `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.

## Physical device baseline

Observed device state:

```text
device=panther
model=Pixel 7
product=panther
android_release=17
sdk=37
build_id=CP2A.260705.006
fingerprint=google/panther/panther:17/CP2A.260705.006/15641320:user/release-keys
security_patch=2026-07-05
vendor_security_patch=2026-07-05
slot=_b
flash_locked=0
vbmeta_device_state=unlocked
verified_boot_state=orange
bootloader=cloudripper-17.0-15199429
hardware=panther
board_platform=gs201
selinux=Enforcing
```

Kernel:

```text
Linux 6.1.157-android14-11-gbd23337e42e7-ab14791245
Clang/LLD 17.0.2
```

Interpretation:

- physical Pixel 7 identity is confirmed;
- stock/current device runtime is Android 17;
- platform and vendor SPL are both 2026-07-05 in the captured build;
- SELinux is enforcing;
- bootloader is already unlocked and verified boot therefore reports orange/unlocked state;
- no flashing occurred in P0.

## Ordinary-shell visibility limitations

The initial P0 shell produced empty `bootctl` values, no `/dev/block/by-name/*` hits and no `lshal` Health/Power rows.

These results are **not** classified as missing A/B partitions, missing boot/vendor partitions, or missing Health/Power HALs. They only show that the Android 17 ordinary-shell commands/paths used by the original bramble-oriented script did not expose those objects.

Do not repair platform code or infer partition/HAL absence from these empty observations. A later bounded inspection gate may use Android-17-appropriate service/partition discovery and, only if required on a userdebug Sable build, privileged diagnostic access.

## Public platform branches and Rust toolchains

Observed AOSP manifest branches:

```text
android15-release = present
android16-release = present
android17-release = present
```

Observed AOSP Rust defaults:

```text
Android 15 -> Rust 1.78.0
Android 16 -> Rust 1.83.0
Android 17 -> Rust 1.93.1
```

This confirms the bramble Rust/Cargo 1.68 constraint was tied to the historical Android 14 platform branch, not to arm64 or Pixel 4a 5G hardware.

## Google Pixel 7 public device-source publication shape

The legacy Google `device/google/pantah` repository exposes Android 15 release branches/tags but no `android16-release` or `android17-release` branch in the P0 probe.

The old Google driver-binary page similarly produced Pixel 7 Android 15 entries but no Android 16/17 entries.

This does **not** mean Pixel 7 cannot run or be built on later Android releases. It means Google's older turnkey public-AOSP Pixel publication model is no longer sufficient by itself for an Android 16/17 panther build.

Android 15 therefore remains the clean official-Google-publication fallback, not the preferred Sable baseline.

## Kernel path

The public factory-supported Pixel kernel documentation continues to list Pixel 7/7 Pro under:

```text
android-gs-pantah-6.1-android16
```

Pixel 7 and later use split `vendor_boot` / `vendor_kernel_boot` handling for kernel artifacts.

The P0 probe found the `android-gs-pantah-6.1-android16` kernel-manifest branch.

## Evidence that Android 17 panther hardware integration is reproducible

GrapheneOS is a scoped external reference, not SableOS's platform trust model. Its current public Android 17 build infrastructure is nevertheless useful evidence for hardware/source feasibility:

- its Android 17 branch is based on Android 17 AOSP;
- `panther` is a current supported production build target;
- Pixel vendor files are generated/extracted with `adevtool generate-all -d panther`;
- Pixel 7 uses the `pantah` 6.1 kernel path;
- Android 17 releases for Pixel 7 are publicly shipped.

This proves that the absence of a Google `device/google/pantah` Android-17 branch does not impose an Android-15 ceiling on the hardware.

It does **not** authorize adopting GrapheneOS wholesale. Sable must separately determine the minimum auditable device/vendor/kernel inputs needed to construct its own Android-17 panther substrate while preserving Sable's architecture and provenance rules.

## Baseline decision

P0 selects:

```text
preferred platform candidate = Android 17 / panther
fallback                    = Android 15 official Google AOSP publication path
Android 16                  = comparison/fallback candidate if useful
```

Android 17 is not yet declared the accepted Sable build baseline. Acceptance requires a source-reconstruction gate proving that the required panther device/vendor/kernel inputs can be assembled reproducibly without silently importing an unrelated OS architecture.

## Rust/UI consequence

The platform/toolchain rule from ADR-0003 remains:

- prefer the AOSP platform Rust compiler when a selected UI framework fits cleanly;
- do not select the renderer merely to match an older platform MSRV;
- allow a separately pinned modern UI Rust compiler when required;
- never link independently compiled Rust components across compiler-private Rust ABI;
- cross toolchain universes through a stable C/NDK/AIDL boundary.

Android 17's AOSP Rust 1.93.1 substantially widens direct-framework compatibility compared with bramble Android 14 Rust 1.68, but framework qualification still considers architecture, input, accessibility, performance, security, supply chain and Pixel/QWERTY portability rather than compiler version alone.

## P0 closure

```text
PANTHER_P0_DEVICE_ID=PASS
PANTHER_P0_STOCK_SELINUX=PASS
PANTHER_P0_KERNEL_BRANCH=PASS
PANTHER_P0_DRIVER_PAGE=PASS_CAPTURE
PANTHER_P0_BRAMBLE_REFERENCE_PRESERVED=PASS
PANTHER_P0_CAPTURE=PASS
PANTHER_P0_SOURCE_MUTATED=NO
PANTHER_P0_WORKSPACE_CREATED=NO
PANTHER_P0_BUILD_PERFORMED=NO
PANTHER_P0_FLASH_PERFORMED=NO
PANTHER_P0_ADB_ROOT_USED=NO
PANTHER_P0_REBOOT_PERFORMED=NO
PANTHER_P0_TMUX_SAFE=YES
```

## Next gate

`PANTHER-P0R1` performs host-only source/provenance reconstruction qualification for Android 17 panther. It should determine:

1. exact Android 17 AOSP tag/branch to pin;
2. exact Pixel 7 stock build/factory image and vendor state corresponding to the baseline;
3. which panther/gs201 device configuration must be retained or regenerated;
4. which proprietary files are required and how they are reproducibly extracted;
5. kernel and kernel-prebuilt provenance;
6. whether GrapheneOS `adevtool` can be used strictly as a vendor/device extraction/build-input tool without importing GrapheneOS platform policy/features;
7. exact Rust/Cargo/Clang/Soong versions after sync;
8. expected lunch/product target;
9. source and license/provenance boundaries;
10. a go/no-go decision for creating the Android 17 Sable panther workspace.

No device flash belongs to P0R1.