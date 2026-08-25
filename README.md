# SableOS

SableOS is an experimental privacy-focused mobile OS project targeting Google Pixel hardware with a minimal Android/AOSP base and a Rust-first userspace architecture.

## Current reference target

- Device: Google Pixel 4a 5G G025E
- AOSP device codename: `bramble`
- SoC: Qualcomm Snapdragon 765G
- Base: Android 12.1 / `android-12.1.0_r11`
- Build ID: `SQ3A.220705.003.A1`
- Build variant: `userdebug`

## Current milestone: B1

B1 is the first SableOS derivative build on `bramble`.

It keeps the known-good Google/Qualcomm hardware and radio stack intact and adds one native Rust executable:

```text
/system_ext/bin/oxynoded
```

`oxynoded` is currently a minimal probe/idle daemon used to validate Android Soong Rust integration before adding init startup, SELinux policy, IPC, or hardware privileges.

Verified B1 properties:

- ARM64 / AArch64 ELF
- PIE executable
- Android linker: `/system/bin/linker64`
- Dynamic dependencies: `libc.so`, `libdl.so`
- SHA-256: `753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45`
- `bootloader.img` unchanged from B0
- `radio.img` unchanged from B0
- `vendor.img` unchanged from B0
- `dtb.img` unchanged from B0
- underlying DTBO payload unchanged from B0; final `dtbo.img` differs only because of AVB/build metadata

## Repository layout

```text
device/sable/bramble/        SableOS bramble product and oxynoded source
patches/                     Minimal AOSP patches required by the pinned base
docs/                        Build and milestone validation notes
```

Generated Android images, proprietary vendor archives, and target-files ZIPs are intentionally not committed to this repository.

## Next hardware gate

B0 and B1 will be validated on a Pixel 4a 5G G025E before B1.1 adds an init service and dedicated SELinux domain.
