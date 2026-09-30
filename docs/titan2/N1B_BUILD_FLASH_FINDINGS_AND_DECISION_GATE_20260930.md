# Titan 2 N1B build, flash and cellular findings

Status: **SableOS Titan 2 N1B paused for benchmark-first decision gate**
Date: 2026-09-30

```text
DEVICE=titan2
LANE=TREBLE_PORTABILITY
CURRENT_TRACK=N1B
NEW_BUILD_AUTHORIZED=NO
NEW_FLASH_AUTHORIZED=NO
PUBLIC_RELEASE_CLAIM=NO
MERGE_AS_CELLULAR_FIX=NO
BENCHMARK_FIRST_DECISION_GATE=REQUIRED
```

## Purpose

This document records the N1B image building and flashing findings for Titan 2,
why the current N1B cellular work is paused, and what must happen before another
SableOS Titan 2 image is built or flashed.

## What worked

### Build path

SableOS was able to drive a Restless/Treble-derived Titan 2 GSI build and produce
verified artifacts.

```text
REPO_LOCAL_CI=PASS_FOR_SOURCE_GATES
ANDROID_IMAGE_BUILD=PASS
SYSTEM_IMG_BUILT=YES
TARGET_FILES_BUILT=YES
ARTIFACT_SHA256_SEALED=YES
TARGET_FILES_VERIFIER_USED=YES
```

This means the current blocker is not basic image generation.

### Flash path

Titan 2 flashing through fastbootd has been proven for `system_a` only.

```text
FASTBOOTD_IS_USERSPACE=yes
ACTIVE_SLOT=a
SYSTEM_A_RESIZE=PASS
SYSTEM_A_FLASH=PASS
USERDATA_POLICY=PRESERVE
BOOT_FLASHED=NO
VENDOR_FLASHED=NO
VBMETA_FLASHED=NO
SUPER_FLASHED=NO
```

The current Sable path is therefore a **system partition replacement** over stock
Titan 2 vendor/firmware/kernel, not a complete device image or full-super port.

## N1B image history

### N1B2

N1B2 established the initial Sable/Restless Titan 2 image candidate and flash
pipeline. It proved bootability and system-image handling but did not establish
stable cellular.

### N1B3

N1B3 added radio-compatibility product markers and held the product boundary:

```text
NO_STOCK_MTK_APK_JAR_SO_IMPORT=YES
PERSIST_SYS_PHH_IMS_MTK=false
RADIO_COMPAT_PROFILE=n1b3_r1
```

N1B3 did not fix cellular stability.

### N1B4

N1B4 removed the MTK IMS telephony overlay that pointed AOSP IMS resolution to
`com.mediatek.ims`, a package intentionally absent from SableOS.

```text
TREBLE_MTK_IMS_OVERLAY_REMOVED=YES
COM_MEDIATEK_IMS_BINDING_REMOVED=YES
TARGET_FILES_FORBIDDEN_OVERLAY_SCAN=PASS
STOCK_MTK_PAYLOAD_IMPORT=NO
```

N1B4 is a valid prerequisite but **not a cellular fix**.

## Runtime findings after N1B4

The repeated runtime pattern is:

```text
LTE_REGISTRATION_RETURNS=YES_BRIEFLY
NR_NSA_DISPLAY_OR_ANCHOR_SIGNAL_APPEARS=YES_BRIEFLY
DATA_CALL_OR_SETUP_ATTEMPT=YES
WWAN_DATA_DROPS=YES
FAIL_CAUSE=ERROR_UNSPECIFIED_0xffff
POST_DROP=OUT_OF_SERVICE_OR_EMERGENCY_OR_UNKNOWN
REJECT_CAUSES_SEEN=11,13,15,114
```

Current evidence does not support a release claim for cellular.

### IWLAN/QNS experiment

A temporary runtime disable of `com.google.android.iwlan` did not stabilize
cellular.

```text
IWLAN_DISABLE_EXPERIMENT=NEGATIVE
QNS_ONLY_ROOT_CAUSE=UNPROVEN
LEGACY_IWLAN_OR_QNS_GATING=STILL_REVIEW_ITEM_NOT_RELEASE_FIX
```

### APN experiment

The attempt to force a different US Mobile `pwg` APN row did not actually switch
the preferred APN. Current evidence does not support an N1B5 APN overlay.

```text
APN_3251_FORCED_SELECTION=NOT_APPLIED
APN_OVERLAY_FIX_READY=NO
```

### LTE-only experiment

ADB network-mask mutation via `cmd phone set-allowed-network-types-for-users`
failed with `No valid NETWORK_TYPES_BITMASK`. A manual UI LTE-only direction still
disconnected and still showed a short LTE/NR-NSA window. Therefore the LTE-only
hypothesis is not proven.

```text
ADB_LTE_ONLY_MASK_APPLIED=NO
UI_LTE_ONLY_STABILITY=FAIL_OR_INCONCLUSIVE
NR_DISABLE_FIX_PROVEN=NO
```

## Why this work is paused

The trial loop reached diminishing returns. The issue appears to be deeper than a
single overlay or APN row and may involve some combination of:

```text
MEDIATEK_VENDOR_MODEM_PROFILE=UNKNOWN
AOSP_GSI_TELEPHONY_INTEGRATION=UNKNOWN
DSDS_SLOT_BEHAVIOR=UNDER_REVIEW
IMS_EPDG_IWLAN_QNS=UNDER_REVIEW
CARRIER_CONFIG_IDENTIFICATION=UNDER_REVIEW
FULL_SUPER_VS_SYSTEM_ONLY_ARCHITECTURE=OPEN
```

The next step is not another patch. It is benchmarking Titan 2 against known
external baselines.

## External baselines to inspect

- Local downloaded file on Mac mini:
  `Titan2-LineageOS-23.0-20251027-GAPPS-EXT4-GSI-v0.0.2.img.gz`
- GitHub: `agreenbhm/Unihertz-Titan-2-LineageOS`
- Gitea: `PeterGSI/android_device_peter_gsi`
- Stock Titan 2 firmware/runtime

The `agreenbhm` approach appears to be a Titan-specific GSI customization path,
including runtime hooks and a super-image build tool. This may imply that Titan 2
needs a stock-super/full-super architecture rather than a `system_a`-only Sable
image.

## Options under review

### Option A — Pause Titan 2 as immediate SableOS release target

Return main effort to Pixel/R9 while keeping Titan 2 as a research target.

### Option B — Use LineageOS 23 Titan 2 as reference baseline

Study the downloaded image and customization repo. If it works, port only the
understood and auditable parts into SableOS.

### Option C — Stock-super plus Sable-system architecture

If Lineage/PeterGSI stability depends on rebuilding `super` with preserved stock
partitions and Titan hooks, move Sable Titan 2 toward that architecture.

### Option D — Stock firmware plus privacy hardening/debloat

If GSI paths remain unstable and daily-driver use is the priority, pursue a
stock-based hardening path instead of a full SableOS replacement.

## Benchmark-first decision gate

No new Sable Titan 2 image should be built or flashed until this gate is complete.

```text
TITAN2_DECISION_GATE_R1=REQUIRED
NO_NEW_BUILD_UNTIL_GATE=YES
NO_FLASH_UNTIL_GATE=YES
NO_RELEASE_CLAIM_UNTIL_GATE=YES
```

Required outputs:

1. Identify whether the downloaded LineageOS 23 artifact is `system.img`,
   `super.img`, sparse image, raw image or another layout.
2. Extract and compare Lineage/PeterGSI runtime hooks, especially
   `phh-on-boot.sh`, telephony properties, overlays and CarrierConfig changes.
3. Compare Lineage/PeterGSI handling of MTK IMS, EPDG, IWLAN and QNS.
4. Compare current Sable N1B target-files with the Lineage/PeterGSI image.
5. Capture or document stock Titan 2 cellular behavior on the same SIM/location
   if available.
6. Decide A/B/C/D before the next build or flash.

## Current decision

```text
N1B4_AS_CELLULAR_FIX=NO
N1B5_AS_PATCH_LOOP=STOPPED
NEXT_DELIVERABLE=TITAN2_DECISION_GATE_R1_REPORT
```
