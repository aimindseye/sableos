# N1B2 Panther no-regression contract

Titan2/N1B2 keyboard-first app work must not alter Panther touch-first behavior or common app semantics through device-name branches.

This contract is a pre-APK and pre-image guard. It does not authorize image builds, device contact, adb, fastboot, flashing, public release, or production signing.

## Rule

SableOS keeps one common application source model with profile-driven presentation:

```text
COMMON_SABLE_APPS=YES
PANTHER_TOUCH_FIRST_DEFAULT=YES
TITAN2_KEYBOARD_FIRST_PROFILE_DRIVEN=YES
COMMON_APP_DEVICE_NAME_FORKS=NO
```

## Panther protection

Common application paths must not contain Titan2/N1B2 device tokens or product-specific composition paths.

Panther paths must not contain Titan2/N1B2 tokens.

Titan2-specific terms belong only in bounded locations such as:

```text
docs/titan2/
build/titan2/
build/devices/titan2.sh
```

## Device branching rule

Common app code must not branch on Android device identity, model, product, brand, manufacturer, or raw system property checks.

Bad examples:

```kotlin
if (Build.MODEL.contains("Titan")) { ... }
if (Build.DEVICE == "titan2") { ... }
SystemProperties.get("ro.product.device")
```

Expected approach:

```kotlin
val keyboardProfile = SableProfiles.keyboard(context)
val appLayoutProfile = SableProfiles.appLayout(context)
```

Apps may adapt focus order, shortcuts, layout density, command behavior, and input handling only through profile facts/capability flags, not retail names or Build fields.

## Gate

The static gate is:

```text
build/gates/n1b2-panther-no-regression-contract.sh
```

Expected marker:

```text
N1B2_PANTHER_NO_REGRESSION=PASS
```

This gate should pass before any PR restores or adds Titan2-targeted app/APK modules.
