# Titan 2 / MediaTek GSI Build Stage Ledger

This ledger separates SableOS GSI work into stages so that AOSP control issues, TrebleDroid / RestlessOS integration issues, SableOS product overlay issues, and physical Titan 2 runtime issues do not get mixed together.

## Canonical stage sequence

| Stage | Name | Purpose | Target class | Device contact |
| --- | --- | --- | --- | --- |
| `N0-AOSP` | AOSP BP4A control | Prove source/toolchain/Soong/Kati can build a baseline `system.img` | `generic_system_arm64-bp4a-userdebug` | `NO` |
| `N1-TREBLE` | TrebleDroid / RestlessOS baseline | Build a hardware-capable Treble GSI with MediaTek/phh compatibility layer | TrebleDroid / RestlessOS product | `NO` initially |
| `N2-SABLE` | SableOS GSI product | Add SableOS identity, packages, policies, keyboard/display overlays | Sable product inheriting from Treble product | `NO` until image is qualified |
| `N3-TITAN2` | Physical Titan validation | Validate Titan 2 / Titan 2 Elite boot/runtime behavior | Qualified Sable GSI artifact | Controlled, explicit |

## Why N0-AOSP and N1-TREBLE are separate

`N0-AOSP` is a control. It should answer whether the Android 16 / BP4A AOSP source tree and local host build setup can produce a valid `system.img`.

`N1-TREBLE` is the first hardware-relevant build stage. It should use the TrebleDroid / RestlessOS product hierarchy rather than trying to make Google's pure `generic_system_arm64` product boot on Titan 2.

The separation gives a clean failure matrix:

```text
N0-AOSP fails -> AOSP/source/toolchain/patch issue
N0-AOSP passes and N1-TREBLE fails -> TrebleDroid/RestlessOS integration issue
N1-TREBLE passes and N2-SABLE fails -> Sable product overlay issue
N2-SABLE passes and N3-TITAN2 fails -> physical device/vendor/runtime compatibility issue
```

## Output directory policy

Use one output directory per stage/product graph.

```text
N0_AOSP_OUT=out_sable_t2_n0_aosp_gsi_bp4a
N1_TREBLE_OUT=out_sable_t2_n1_treble_gsi
N2_SABLE_OUT=out_sable_t2_n2_sable_gsi
```

Do not share output directories across product graphs. Reusing an output directory within the same stage is allowed and expected for incremental builds.

## N0-AOSP build record

| Field | Value |
| --- | --- |
| Status | `IN_PROGRESS` |
| Target | `generic_system_arm64-bp4a-userdebug` |
| Build goal | `systemimage` |
| AOSP tag | `android-16.0.0_r4` |
| Build ID | `BP4A.251205.006` |
| Output directory | `out_sable_t2_n0_aosp_gsi_bp4a` |
| Device contact | `NO` |
| Flash authorization | `NO` |
| Latest local evidence | `/srv/data/sable-build/evidence/titan2/n0-bp4a-rerun/20260927_092433` |

## N0-AOSP current patch queue

| Patch | Repository path | Status | Notes |
| --- | --- | --- | --- |
| Targeted `platform_testing` `test_package` unblocker | `platform_testing/Android.bp` | scratch unblocker | Avoids host-side Tradefed test bundle path errors during `systemimage` graph generation |
| Ranging existence-check allowlist | `build/make/target/product/generic_system_arm64.mk` | BP4A control patch candidate | Preserves `base_system.mk` and `RELEASE_RANGING_STACK`; allowlists only `com.android.ranging` for existence check |

## N1-TREBLE planning record

`N1-TREBLE` should start only after the N0-AOSP result is captured. The expected direction is:

```text
Use RestlessOS / TrebleDroid product hierarchy
Do not manually layer Treble patches onto generic_system_arm64
Use separate OUT_DIR
Keep SableOS identity out of build/make base products
```

Items to identify before launching N1:

```text
RESTLESS_TREBLE_PRODUCT_NAME=<pending discovery>
TREBLE_PRODUCT_MAKEFILE=<pending discovery>
N1_OUT_DIR=out_sable_t2_n1_treble_gsi
PATCH_SOURCE=RestlessOS/TrebleDroid patch series only
DEVICE_CONTACT=NO
FLASH_AUTHORIZED=NO
```

## N2-SABLE planning record

`N2-SABLE` should create a Sable product overlay that inherits from the TrebleDroid / RestlessOS product target.

Candidate layout:

```text
device/sable/gsi/AndroidProducts.mk
device/sable/gsi/sable_gsi_arm64.mk
vendor/sable/
```

Sable-specific contents belong here, not in AOSP `build/make` base product files:

```text
Sable packages
Titan keyboard .kl/.kcm overlays
Square-display overlays/RROs
Sable artifact allowlists
Sable branding and default app policy
```

## Historical rule

Each stage should end with:

```text
manifest snapshot
patch queue snapshot
artifact path
artifact size
artifact SHA-256
build result
known limitations
next-stage handoff
```
