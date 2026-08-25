# Building SableOS B1 on bramble

B1 is based on AOSP Android 12.1 tag `android-12.1.0_r11`, build ID `SQ3A.220705.003.A1`, targeting Google Pixel 4a 5G (`bramble`).

## Prerequisites

A working `bramble` AOSP tree with the matching Google/Qualcomm proprietary binaries is required. SableOS does not redistribute those proprietary archives.

## Install the SableOS device tree

Place this repository's `device/sable` tree at:

```text
<AOSP>/device/sable
```

## Apply the Android 12.1 Rust allow-list patch

Android 12.1 restricts Rust module locations. Apply:

```bash
git -C build/soong apply \
  /path/to/sableos/patches/android-12.1/0001-allow-device-sable-rust.patch
```

The patch adds only:

```text
"device/sable",
```

to `build/soong/rust/config/allowed_list.go`.

## Select B1

From the AOSP root:

```bash
export OUT_DIR=out_b1
source build/envsetup.sh
lunch sable_bramble_b1-userdebug
```

Expected key values:

```text
TARGET_PRODUCT=sable_bramble_b1
TARGET_DEVICE=bramble
TARGET_BUILD_VARIANT=userdebug
BUILD_ID=SQ3A.220705.003.A1
OUT_DIR=out_b1
```

## Build only oxynoded first

```bash
m oxynoded -j8
```

Expected installed path:

```text
out_b1/target/product/bramble/system_ext/bin/oxynoded
```

Inspect it with:

```bash
file out_b1/target/product/bramble/system_ext/bin/oxynoded
readelf -h out_b1/target/product/bramble/system_ext/bin/oxynoded \
  | grep -E 'Class:|Type:|Machine:'
readelf -d out_b1/target/product/bramble/system_ext/bin/oxynoded \
  | grep NEEDED
```

The verified B1 binary is ELF64, AArch64, PIE, uses `/system/bin/linker64`, and has only `libc.so` and `libdl.so` as shared-library dependencies.

## Full B1 build

```bash
m -j8
```

## Target-files package

```bash
m target-files-package -j8
```

The validated build produced:

```text
out_b1/target/product/bramble/obj/PACKAGING/target_files_intermediates/
  sable_bramble_b1-target_files-eng.mindseye73.zip
```

`unzip -t` completed with no compressed-data errors.

## Intentional B1 scope

B1 does **not** auto-start `oxynoded` and does not add SELinux policy, hardware privileges, radio access, IPC, or networking privileges. Those changes are intentionally deferred until B0/B1 hardware validation on a physical Pixel 4a 5G.
