# Titan 2 N0 build target contract

Status: **substrate qualification required before first build**

Canonical operator shape:

```bash
bash build/sable.sh titan2 R10 build --direct
```

The adapter remains fail-closed until this contract has a qualified Android
source substrate and an implemented build driver.

## Target contract

```text
DEVICE=titan2
RELEASE=R10
ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
TARGET_ARCH=arm64
TARGET_ANDROID_RELEASE=16
TARGET_PLATFORM_SDK=36
STOCK_VENDOR_API=34
STOCK_VNDK=34
BUILD_VARIANT=userdebug
ADB_FOR_N0=REQUIRED
STOCK_KERNEL_VENDOR_PRESERVED=YES
PANTHER_BOOT_VENDOR_CONTENT_ALLOWED=NO
```

The first artifact should be a generic/system-only userspace candidate. Titan
device policy and Sable keyboard/display integration can be added incrementally
after the first boot proves the stock vendor stack accepts the system image.

## Phase A — qualify build substrate

Run:

```bash
bash build/titan2/probe-build-substrate.sh
```

The probe is read-only. It searches known local Android workspaces, reports the
platform SDK it can observe and lists candidate generic ARM64/GSI product
definitions. It does not fetch source, build an image or touch a device.

Required result before enabling `sable_device_build`:

```text
TITAN2_SUBSTRATE_FOUND=YES
TITAN2_SUBSTRATE_PLATFORM_SDK=36
TITAN2_GSI_ARM64_PRODUCT_CANDIDATE=<qualified target>
TITAN2_SUBSTRATE_QUALIFIED=YES
```

An Android 17 / SDK 37 Panther workspace is useful as a Sable reference but is
not automatically accepted as the first Titan 2 N0 substrate. The first target
is intentionally aligned to the stock Android 16 / SDK 36 userspace boundary to
reduce bring-up variables.

## Phase B — implement build driver

After the substrate/product is known:

- add a Titan 2 build driver under `build/titan2/`;
- set an isolated OUT_DIR;
- build the selected ARM64 GSI/system target;
- record source commit, upstream manifest identity, lunch/product, output path,
  file size and SHA-256;
- leave flash support disabled;
- enable generic artifact registration for `gsi-system-image` only after the
  build evidence contract is satisfied.

## Phase C — E3

The generated `system.img` then goes through the Titan repository's E3
artifact preflight for sparse/logical size, current logical-partition fit and
AVB metadata inspection. No write-capable command is authorized by a successful
build alone.


## Observed substrate probe — 2026-09-26

The first host probe found one existing generic ARM64/GSI-capable Android tree:

```text
SUBSTRATE_PATH=/srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300
PLATFORM_SDK=UNOBSERVED
PLATFORM_SDK_MATCH=NO
GSI_REFERENCE_SUBSTRATE_COUNT=1
SDK36_SUBSTRATE_COUNT=0
TITAN2_SUBSTRATE_QUALIFIED=NO
```

That workspace is the existing Panther GrapheneOS 2026081300 substrate; Sable's
Panther config declares it as Android 17. It is therefore not accepted as the
first Titan 2 Android 16 / SDK 36 build substrate merely because it contains
`gsi_arm64.mk`.

Next qualification step: inspect the exact generic product/release definitions
in that tree and search for any other local Android 16 / SDK 36 source tree.
Do not enable `SABLE_DEVICE_BUILD_SUPPORTED` until an SDK 36 substrate is
positively identified, or until the Android-major compatibility decision is
explicitly revisited and documented.
