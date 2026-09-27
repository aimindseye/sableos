# Titan 2 / MediaTek GSI Build Stage Ledger

This ledger separates SableOS GSI work into stages so that AOSP control issues, TrebleDroid / RestlessOS integration issues, SableOS product overlay issues, and physical Titan 2 runtime issues do not get mixed together.

## Canonical stage sequence

The canonical sequence keeps both baseline build-proving stages under N0:

| Stage | Name | Purpose | Target class | Device contact |
| --- | --- | --- | --- | --- |
| `N0-AOSP` | AOSP BP4A control | Prove source/toolchain/Soong/Kati can build a baseline `system.img` | `generic_system_arm64-bp4a-userdebug` | `NO` |
| `N0-B-TREBLE` | TrebleDroid / RestlessOS baseline | Build a hardware-capable Treble GSI with MediaTek/phh compatibility layer | TrebleDroid / RestlessOS product | `NO` initially |
| `N1-SABLE` | SableOS GSI product | Add SableOS identity, packages, policies, keyboard/display overlays | Sable product inheriting from Treble product | `NO` until image is qualified |
| `N2-TITAN2` | Physical Titan validation | Validate Titan 2 / Titan 2 Elite boot/runtime behavior | Qualified Sable GSI artifact | Controlled, explicit |

`N1-TREBLE` is not canonical naming. The TrebleDroid / RestlessOS baseline is `N0-B-TREBLE`; `N1` is reserved for the first SableOS overlay stage.

## Why N0-AOSP and N0-B-TREBLE are separate

`N0-AOSP` is a control. It should answer whether the Android 16 / BP4A AOSP source tree and local host build setup can produce a valid `system.img`.

`N0-B-TREBLE` is the first hardware-relevant baseline build stage. It should use the TrebleDroid / RestlessOS product hierarchy rather than trying to make Google's pure `generic_system_arm64` product boot on Titan 2.

The separation gives a clean failure matrix:

```text
N0-AOSP fails -> AOSP/source/toolchain/patch issue
N0-AOSP passes and N0-B-TREBLE fails -> TrebleDroid/RestlessOS integration issue
N0-B-TREBLE passes and N1-SABLE fails -> Sable product overlay issue
N1-SABLE passes and N2-TITAN2 fails -> physical device/vendor/runtime compatibility issue
```

## Output directory policy

Use one output directory per stage/product graph.

```text
N0_AOSP_OUT=out_sable_t2_n0_aosp_gsi_bp4a
N0_B_TREBLE_OUT=out_sable_t2_n0b_treble_gsi
N1_SABLE_OUT=out_sable_t2_n1_sable_gsi
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
| ABI checks skipped for rerun | environment: `SKIP_ABI_CHECKS=true` | build-control workaround | Avoids late `header-abi-dumper` failure after `system.img` generation; no source mutation |

## N0-B-TREBLE planning record

`N0-B-TREBLE` should start only after the N0-AOSP result is captured. The expected direction is:

```text
Use RestlessOS / TrebleDroid product hierarchy
Do not manually layer Treble patches onto generic_system_arm64
Use separate OUT_DIR
Keep SableOS identity out of build/make base products
```

Items to identify before launching N0-B:

```text
RESTLESS_TREBLE_PRODUCT_NAME=<pending discovery>
TREBLE_PRODUCT_MAKEFILE=<pending discovery>
N0_B_OUT_DIR=out_sable_t2_n0b_treble_gsi
PATCH_SOURCE=RestlessOS/TrebleDroid patch series only
DEVICE_CONTACT=NO
FLASH_AUTHORIZED=NO
```

## N1-SABLE planning record

`N1-SABLE` should create a Sable product overlay that inherits from the TrebleDroid / RestlessOS product target.

N1 also owns the Sable multilingual readiness contract. Keyboard language support and UI localization readiness must be treated as one product requirement, not separate features. The detailed contract lives in `docs/titan2/N1_SABLE_MULTILINGUAL_READINESS.md`.

```text
N1_MULTILINGUAL_READINESS_REQUIRED=YES
FULL_LANGUAGE_PACKS_REQUIRED_IN_N1=NO
KEYBOARD_ONLY_MULTILINGUAL=NOT_ACCEPTABLE
UI_AND_KEYBOARD_LANGUAGE_ALIGNMENT=REQUIRED
```

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
Sable locale and multilingual-readiness policy
```

The N1 overlay must include or stage a gate named:

```text
N1_SABLE_LOCALE_KEYBOARD_CONTRACT
```

The gate should cover resource-backed UI strings, physical keyboard layout ownership, font fallback, IME policy for complex scripts, and RTL safety review. Full language packs can come later; the N1 architecture must be locale-safe from the start.

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
