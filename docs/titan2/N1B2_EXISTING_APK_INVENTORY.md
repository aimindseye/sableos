# N1B2 existing APK inventory and build gate

This is the first APK/code-closure gate after the `platform_sable` binding and Panther no-regression guards.

This contract intentionally does not restore missing app modules, does not relax Android product composition, does not build a system image, does not contact a device, and does not authorize adb, fastboot, flash, public release, or production signing.

## Purpose

Before adding or restoring missing apps for Titan2/N1B2, the current Gradle app surface must remain buildable and explicitly inventoried.

The machine-readable inventory is:

```text
docs/titan2/N1B2_EXISTING_APK_INVENTORY.tsv
```

The inventory is the source of truth for each module's role, build task, and expected debug artifact glob.

## Canonical host tools

Build mode must use the existing SableOS host-tool profile:

```text
build/config/r8-host-tools.env
```

The gate sources that file and derives Android SDK, Rust, Cargo, Rustup, Gradle, and Java paths from it. It must not rediscover SDK, NDK, Rust, Java, or Gradle paths from `$HOME`, `/opt`, or unrelated host defaults.

This preserves the same host-tool model used by earlier R8/R9/N1A/N1B validation instead of creating a parallel APK-build environment.

## Current product APK candidates

Current product APK modules are:

```text
calculator
games
media
hub
weather
calendar
```

`games` is a flavored Android application. Its debug APK outputs are flavor-scoped under:

```text
games/build/outputs/apk/*/debug/*.apk
```

`convert` exists in the current Gradle graph as a legacy shared library module, not as an APK-producing product module. Its functionality should be consolidated into Calculator in a later cleanup PR.

`design` is a shared library, not a product APK.

`sablestart-presentation-check` is a validation/support module and does not produce a product APK.

`sablestart-visual-review` is a validation APK, not an N1B2 product APK candidate.

## Inventory artifact sentinel

The TSV uses `NONE` in `expected_debug_artifact_glob` for rows that intentionally do not produce a debug APK or checked artifact.

Do not leave that field blank. Bash treats tab as IFS whitespace and can collapse empty TSV fields, shifting notes into the artifact-glob column. The gate treats `NONE` as `NOT_APPLICABLE`.

## Gate

The gate is:

```text
build/gates/n1b2-existing-apk-inventory-contract.sh
```

Inventory-only mode verifies the Gradle settings and module layout without compiling:

```text
bash build/gates/n1b2-existing-apk-inventory-contract.sh
```

APK build mode compiles current modules and validates only the debug artifacts declared by the inventory:

```text
bash build/gates/n1b2-existing-apk-inventory-contract.sh --build YES
```

## Expected markers

Inventory-only mode:

```text
N1B2_EXISTING_APK_INVENTORY=PASS
```

Build mode:

```text
N1B2_EXISTING_APK_INVENTORY=PASS
N1B2_CANONICAL_HOST_TOOLS_ENV_SOURCED=PASS
N1B2_CANONICAL_BUILD_ENV_READY=PASS
N1B2_EXISTING_APK_BUILD=PASS
```

## Safety posture

The gate permits only local Gradle APK/module work when `--build YES` is explicitly supplied. It does not run Android image builds, Soong builds, adb, fastboot, flashing, device contact, factory reset, release publication, or production signing.
