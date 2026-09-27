# Titan 2 N0-AOSP BP4A Control Build

Status: `IN_PROGRESS`

This document records the first Android 16 / BP4A `generic_system_arm64` control build used to validate the SableOS host build environment, AOSP source graph, Soong/Kati behavior, and the minimum patch queue before moving to TrebleDroid / RestlessOS and then SableOS-specific product overlays.

This build is **not** the Titan 2 flashable image. It is the N0-AOSP control stage.

## Scope

| Field | Value |
| --- | --- |
| Stage | `N0-AOSP` |
| Purpose | AOSP BP4A `system.img` control build |
| AOSP manifest tag | `android-16.0.0_r4` |
| Build ID observed after lunch | `BP4A.251205.006` |
| Lunch target | `generic_system_arm64-bp4a-userdebug` |
| Build goal | `systemimage` |
| Output directory | `out_sable_t2_n0_aosp_gsi_bp4a` |
| Device contact | `NO` |
| Flash authorized | `NO` |
| Clean/clobber | `NO` |

## Stage boundaries

`N0-AOSP` answers only this question:

> Can the Android 16 / BP4A AOSP source tree, host toolchain, Soong/Kati graph, and documented patch queue produce a valid `system.img`?

It does not answer whether the image boots on Titan 2 or Titan 2 Elite. MediaTek / Titan hardware compatibility is handled by the later TrebleDroid / RestlessOS and SableOS product stages.

## Stage naming

| Stage | Meaning | Expected target family |
| --- | --- | --- |
| `N0-AOSP` | Pure AOSP BP4A control build | `generic_system_arm64-bp4a-userdebug` |
| `N1-TREBLE` | RestlessOS / TrebleDroid hardware-capable GSI baseline | TrebleDroid / RestlessOS product target |
| `N2-SABLE` | SableOS product overlay on the Treble baseline | `sable_gsi_arm64` or successor |
| `N3-TITAN2` | Physical Titan 2 / Titan 2 Elite validation | device-specific validation, no baseline source churn |

## Local evidence anchors

The local build/evidence directories used during the N0-AOSP work were:

```text
SOURCE_SYNC_EVIDENCE=/srv/data/sable-build/evidence/titan2/n0-a16-source-sync/20260926_221401
PREFLIGHT_EVIDENCE=/srv/data/sable-build/evidence/titan2/n0-build-preflight/20260927_071142
BP4A_RANGING_VERIFICATION=/srv/data/sable-build/evidence/titan2/n0-bp4a-ranging-verification/20260927_090614
BP4A_RERUN_EVIDENCE=/srv/data/sable-build/evidence/titan2/n0-bp4a-rerun/20260927_092433
OUT_DIR=/srv/data/sable-build/workspaces/titan2-n0-a16-20260926_221401/aosp-android16/out_sable_t2_n0_aosp_gsi_bp4a
```

These are local evidence paths, not repository paths.

## Key decisions captured

### Release config

The Android 16 lunch target must use the three-part release-aware form:

```text
generic_system_arm64-bp4a-userdebug
```

`trunk_staging` is not the N0-AOSP control baseline for this tagged checkout.

### Ranging stack handling

Local verification showed:

```text
TARGET_RELEASE=bp4a
RELEASE_RANGING_STACK=true
PRODUCT_APEX_BOOT_JARS includes com.android.uwb:framework-ranging
PRODUCT_APEX_SYSTEM_SERVER_JARS includes com.android.uwb:service-ranging
```

The local tree has `packages/modules/Uwb` at the `android-16.0.0_r4` manifest revision, and `framework-ranging` / `service-ranging` are carried by `com.android.uwb` when `RELEASE_RANGING_STACK=true`.

The N0-AOSP patch approach is therefore:

```make
$(call enforce-product-packages-exist,com.android.ranging)
```

in `build/make/target/product/generic_system_arm64.mk`, rather than deleting `com.android.ranging` from `base_system.mk` or disabling `RELEASE_RANGING_STACK`.

### Platform testing handling

`platform_testing` `test_package` blocks are not runtime `system.img` content, but Soong validates the global Blueprint graph before building `systemimage`. The N0-AOSP scratch unblocker disables only the known failing `platform_testing` test-package bundle declarations that pull invalid host artifact paths.

This patch is classified as:

```text
CLASSIFICATION=SCRATCH_UNBLOCKER_FOR_N0_AOSP_GRAPH
RUNTIME_SYSTEM_IMG_IMPACT=NO_EXPECTED
REVERT_FOR_ZERO_MUTATION_AOSP_CONTROL=YES
```

## Patch classification

| Patch / mutation | Classification | Reason |
| --- | --- | --- |
| `platform_testing` targeted `test_package` unblocker | Temporary scratch unblocker | Avoids host test bundle graph failures while building runtime `systemimage` |
| `generic_system_arm64.mk` `com.android.ranging` allowlist | Reusable Android 16 BP4A control patch candidate | Preserves `base_system.mk` and `RELEASE_RANGING_STACK` while allowing absent product package declaration |
| Adding `packages/modules/Ranging` from `main` | Not approved | Would mix `main` project state into a tagged BP4A source tree |
| Deleting `com.android.ranging` from `base_system.mk` | Not approved for N0-AOSP | Removes upstream package entry instead of documenting the generic-system existence-check gap |
| Disabling `RELEASE_RANGING_STACK` | Not approved | Would remove Android 16 ranging jars from the UWB APEX classpath fragments |

## Completion criteria

`N0-AOSP` is complete when:

```text
LUNCH_RC=0
BUILD_RC=0
SYSTEM_IMG_COUNT=1
N0_BP4A_SYSTEMIMAGE=PASS
DEVICE_CONTACT=NO
FLASH_AUTHORIZED=NO
```

After completion, record the final artifact path, size, SHA-256, and build-prop sample in this document or a follow-up PR.

## Next stage

After `N0-AOSP` passes, move to `N1-TREBLE` using the RestlessOS / TrebleDroid product hierarchy in a separate output directory. Do not reuse the N0-AOSP output directory for the Treble product graph.
