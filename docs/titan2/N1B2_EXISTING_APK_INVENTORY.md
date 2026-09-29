# N1B2 existing APK inventory and build gate

This is the first APK/code-closure gate after the `platform_sable` binding and Panther no-regression guards.

This contract intentionally does not restore missing app modules, does not relax Android product composition, does not build a system image, does not contact a device, and does not authorize adb, fastboot, flash, public release, or production signing.

## Purpose

Before adding or restoring missing apps for Titan2/N1B2, the current Gradle app surface must remain buildable and explicitly inventoried.

The machine-readable inventory is:

```text
 docs/titan2/N1B2_EXISTING_APK_INVENTORY.tsv
```

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

`convert` is tracked as a legacy APK because it exists in the current Gradle graph, but it is not an N1B2 product candidate. Its functionality should be consolidated into Calculator in a later cleanup PR.

`design` is a shared library, not a product APK.

`sablestart-presentation-check` and `sablestart-visual-review` are validation/support modules, not N1B2 product APK candidates.

## Gate

The gate is:

```text
build/gates/n1b2-existing-apk-inventory-contract.sh
```

Inventory-only mode verifies the Gradle settings and module layout without compiling:

```text
bash build/gates/n1b2-existing-apk-inventory-contract.sh
```

APK build mode compiles current APK modules only:

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
N1B2_EXISTING_APK_BUILD=PASS
```

## Safety posture

The gate permits only local Gradle APK/module work when `--build YES` is explicitly supplied. It does not run Android image builds, Soong builds, adb, fastboot, flashing, device contact, factory reset, release publication, or production signing.
