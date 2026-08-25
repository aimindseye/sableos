# SableOS

SableOS is an experimental privacy-focused mobile OS project targeting Google Pixel hardware with a minimal Android/AOSP base and a Rust-first userspace architecture.

## Current reference target

- Device: Google Pixel 4a 5G G025E
- AOSP device codename: `bramble`
- SoC: Qualcomm Snapdragon 765G
- Base: Android 12.1 / `android-12.1.0_r11`
- Build ID: `SQ3A.220705.003.A1`
- Build variant: `userdebug`

## Current milestone: B1 — frozen

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

The local B1 gold master is frozen and checksum-verified at:

```text
/srv/data/aosp_gold_master_bramble/B1-oxynoded-SQ3A.220705.003.A1
```

Both payload and metadata checksum manifests were verified after the final read-only freeze, and the target-files ZIP passed `unzip -t`.

## Repository layout

```text
device/sable/bramble/        SableOS bramble product and oxynoded source
patches/                     Minimal AOSP patches required by the pinned base
docs/                        Build, validation, and hardware acceptance notes
```

Generated Android images, proprietary vendor archives, and target-files ZIPs are intentionally not committed to this repository.

## Documentation

- `docs/BUILDING_B1.md` — reproduce the B1 build
- `docs/B1_VALIDATION.md` — B1 build and image validation record
- `docs/B1_GOLD_MASTER.md` — immutable B1 archive/freeze record
- `docs/G025E_HARDWARE_ACCEPTANCE.md` — factory-state, unlock, safe-flash, B0/B1 hardware acceptance runbook

## Next hardware gate

Validate B0 and B1 on the physical Pixel 4a 5G G025E before B1.1 adds an init service and dedicated SELinux domain.
