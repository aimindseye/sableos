# Sable Titan 2 device skeleton

Status: **N0 build-target work active — deployment remains closed**

This directory is the private integration skeleton for Titan 2 SableOS N0. It is
not a public source release, not a build target, and not a flash contract.

```text
DEVICE=titan2
RELEASE=N0
DEVICE_ADAPTER_STATUS=BUILD_TARGET_IN_PROGRESS
BUILD_IMAGE_PUBLIC=NO
BUILD_IMAGE_PRIVATE=NO
FLASH_PUBLIC=NO
FLASH_PRIVATE=NO
FIRST_SABLE_ARTIFACT=ABSENT
FIRST_BUILD_ARTIFACT_KIND=gsi-system-image
FIRST_SABLE_BOOT=NOT_RUN
```

## Current goal

Create the minimum device-adapter workspace needed to decide the first bounded
Titan 2 artifact type and to bind any future artifact to the exact stock
firmware/vendor basis.

The first artifact must be chosen experimentally from:

```text
gsi-system-image
generated-super-image
bounded system/product/system_ext bundle
```

The first build candidate is now a system-only ARM64 GSI. Building remains
non-destructive and is allowed to proceed after the Android 16 / SDK 36 source
substrate and generic ARM64 product are qualified. AVB and userdata policy remain
deployment gates and do not authorize a flash merely because an image builds.

## Source/evidence boundary

Allowed in this directory:

- normalized facts;
- placeholders;
- adapter contracts;
- command shapes;
- hashes of approved inputs;
- evidence references.

Not allowed:

- stock firmware;
- OTA packages;
- partition images;
- extracted blobs;
- private keys;
- serials, IMEI/MEID/ICCID, FCM identifiers or signed OTA URLs;
- unredacted diagnostics.

## Required next state

```text
TITAN2_STOCK_BASIS_BOUND=YES
TITAN2_ARTIFACT_KIND_DECIDED=YES
TITAN2_RESTORE_PLAN_VERIFIED=YES
TITAN2_USERDATA_POLICY_DECIDED=YES
TITAN2_FIRST_ARTIFACT_CREATED=YES
```

Only after those are true should E3/N0 deployment be attempted.
