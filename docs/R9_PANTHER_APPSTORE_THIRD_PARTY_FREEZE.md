# R9 Panther App Store / third-party compatibility freeze

Status: **bounded final Panther compatibility closure; physical acceptance pending**

Date: 2026-09-24

## Purpose

Panther R9 had already been frozen as the SableOS touch-first reference. It is
temporarily reopened for one bounded compatibility tranche before keyboard-first
Titan 2 / Titan 2 Elite implementation becomes the active device focus.

The tranche exists to prove a complete daily-driver boundary:

```text
SableOS image
    -> pinned GrapheneOS AppStore present
    -> sandboxed Google Play remains optional/user-installed
    -> user installs ordinary third-party applications
    -> Sable shell / Settings / SystemUI remain coherent
    -> Sable Messages consumes only Android-authorized conversation surfaces
    -> Panther is frozen again
```

This is not authorization for unrelated Panther feature work.

## Product composition decision

The canonical GrapheneOS 2026081300 source manifest already contains
`external/AppStore`. Its `AppStore` Soong module is a product-specific,
privileged, preprocessed GrapheneOS-signed package with the corresponding
`app.grapheneos.apps` permission allowlist.

SableOS therefore adds only:

```text
PRODUCT_PACKAGES += AppStore
```

SableOS does **not** preinstall:

```text
com.android.vending
com.google.android.gms
com.google.android.gsf
WhatsApp
Signal
Telegram
LinkedIn
```

The user decides whether to install sandboxed Google Play and which applications
to install through it.

## Appearance contract

SableOS owns appearance for Sable first-party applications and Sable-owned
system surfaces.

For ordinary third-party Android applications:

- the Android system Light/Dark state is the interoperability contract;
- an app that follows system `uiMode` should follow the selected Sable
  Light/Dark mode;
- an app with its own explicit theme remains authoritative for its own content;
- Sable accent colors are not injected into arbitrary third-party application
  internals;
- Sable still owns surrounding system bars, permission dialogs, notification
  presentation, Recents integration, launcher presentation and OS settings.

A branded third-party app remaining branded is therefore not a UI defect.
Unreadable system bars, broken insets, incorrect Light/Dark handoff, invisible
focus, broken permission dialogs, launcher/Recents defects or Sable surface
regressions are defects.

## Build gates

Before a new Panther image is accepted:

```text
R9_APPSTORE_UPSTREAM=PASS_PINNED_GRAPHENE_MODULE
R9_APPSTORE_PRODUCT_MODULE=PASS
R9_APPSTORE_MODULE_BUILD=PASS
R9_APPSTORE_TARGET_FILES=PASS_PRESENT
R9_APPSTORE_PACKAGE_IDENTITY=PASS_APP_GRAPHENEOS_APPS
R9_GOOGLE_PLAY_PREINSTALLED_TARGET_FILES=PASS_ABSENT
R8_FINAL_TARGET_FILES=PASS
R9_FRESH_FULL_BUILD=PASS
```

The source/product gates must also prove that the Sable product does not add
GmsCore/Phonesky/GoogleServicesFramework as default packages.

## Physical acceptance sequence

### P0 — clean post-flash baseline

Immediately after the new SableOS image boots, before installing Google Play:

```bash
SERIAL=<pixel-7-serial> \
PHASE=baseline \
  bash tests/systemui/device/r9_appstore_third_party_compat_audit.sh
```

Required observations:

- Apps / App Store is visible in SableLauncher;
- App Store launches without crash;
- App Store renders correctly in Sable Light and Dark;
- GmsCompat framework packages remain present;
- Play Store, Play services and GSF remain absent.

### P1 — user installs sandboxed Google Play

Use Apps / App Store on the device to install the supported core Google Play
components. Do not use ADB sideloading for this acceptance path.

Then run:

```bash
SERIAL=<pixel-7-serial> \
PHASE=play \
  bash tests/systemui/device/r9_appstore_third_party_compat_audit.sh
```

Physically verify:

- Play Store launches and account sign-in works;
- package installation/update UI is coherent;
- permission and install confirmation dialogs remain Sable/Android-correct;
- system Light/Dark changes do not break Play Store or system bars.

### P2 — install provider test set

Install through Play Store:

```text
WhatsApp   com.whatsapp
Signal     org.thoughtcrime.securesms
Telegram   org.telegram.messenger
LinkedIn   com.linkedin.android
```

Then run:

```bash
SERIAL=<pixel-7-serial> \
PHASE=providers \
  bash tests/systemui/device/r9_appstore_third_party_compat_audit.sh
```

For each provider test:

- launch from SableStart All Apps and Search;
- verify icon/name/focus and normal return-to-Home behavior;
- verify Recents/Quickstep presentation;
- test Sable Light and Dark;
- inspect status/navigation bar contrast and edge-to-edge/insets;
- open Android permission/settings pages from the app;
- receive at least one real notification;
- verify notification shade rendering and lockscreen privacy;
- verify Sable Messages Connected Apps opt-in;
- verify notification-derived conversation only when the provider exposes it;
- verify quick reply only when the source exposes a valid free-form RemoteInput;
- verify Open in app fallback otherwise;
- verify optional SableLauncher hiding and unhiding without uninstalling;
- reboot and unlock, then confirm CE policy/history restoration.

Do not classify missing non-notifying provider history as a Sable defect. The
accepted Messages architecture intentionally sees only content exposed through
Android-authorized notification/conversation surfaces.

## Provider evidence table

Record the installed version and observed capability instead of hard-coding
provider behavior.

| Provider | Version | Light/Dark | Notification | Sable conversation | RemoteInput reply | Open in app | Launcher hide |
| --- | --- | --- | --- | --- | --- | --- | --- |
| WhatsApp | | | | | | | |
| Signal | | | | | | | |
| Telegram | | | | | | | |
| LinkedIn | | | | | | | |

Allowed capability outcomes are:

```text
CONVERSATION_REPLY
NOTIFICATION_ONLY
LAUNCH_ONLY
```

A provider-specific limitation is not silently upgraded into a Sable
capability.

## Final freeze gate

Panther can return to HOLD/reference state only after:

```text
R9_APPSTORE_BASELINE_PHYSICAL=PASS
R9_SANDBOXED_GOOGLE_PLAY_USER_INSTALL=PASS
R9_THIRD_PARTY_APP_UI_INTEROP=PASS
R9_MESSAGES_CONNECTED_APPS_PHYSICAL=PASS
R9_MESSAGES_REMOTEINPUT_TRUTHFUL_DEGRADE=PASS
R9_PANTHER_FINAL_COMPATIBILITY_FREEZE=PASS
```

At that point record the final source commit and target-files SHA-256 in
`CURRENT_STATUS.md`, preserve Panther as the touch-first regression reference,
and return active implementation focus to keyboard-first common SableOS plus
Titan 2 and Titan 2 Elite.
