# R9 final UI runtime acceptance

Status: **required before Panther UI closure**

This acceptance exists because the Pixel 7 AVD used for Mac visual design
contains Google applications and emulator-specific package state that is not
the SableOS/GrapheneOS Panther product.

## Appearance

Sable appearance has two layers:

1. Sable-owned applications consume the Sable appearance provider directly.
2. Sable Start bridges Light/Dark to Android system night mode through
   `UiModeManager`.

The Panther acceptance must verify both layers.

### Mac visual-review fidelity boundary

The Mac mini Pixel 7 AVD is a design/interaction host, not a SableOS product
image. The visual-review APK therefore emulates only the cross-application
Sable appearance provider contract that an unprivileged review APK can
faithfully exercise:

- it registers the same `org.sableos.start.appearance` provider authority;
- it persists appearance through the production `StartStateRepository`;
- installed Sable-owned review apps can observe Light/Dark/accent updates through
  the same `SableGlobalTheme` content-observer path used by production.

The Mac review APK does **not** claim to prove the privileged Android
`UiModeManager.setNightMode()` bridge. Platform-app night-mode propagation is
Panther physical acceptance only.

The stock Pixel AVD may contain Google Chrome `com.android.chrome`. Chrome is
filtered from the Sable launcher visual-review inventory so it cannot be
mistaken for SableOS product composition. The harness does not rename Chrome or
inject a fake Vanadium entry. Vanadium package/default-browser identity remains
Panther physical acceptance only.

The stock Pixel AVD may also contain Google Messages
`com.google.android.apps.messaging`. It is filtered from the visual-review
launcher inventory alongside the retained GrapheneOS transport package
`com.android.messaging`, so the Mac Start surface presents only Sable Messages.
This is review-host filtering only; the clean Panther product must still prove
Google Messages absent and GrapheneOS Messaging retained as the hidden transport
substrate.

The scripted Mac fidelity audit is:

```
bash build/macos/audit-r9-launcher-review-fidelity.sh [follow-system|light|dark]
```

A successful audit proves the cross-process appearance provider state and
explicitly reports browser/system-night claims as deferred to Panther.

The Mac prepare flow also builds and installs Sable Messages as a second-process
theme probe. After selecting Light or Dark in the Start review UI, capture the
cross-app proof with:

```
bash build/macos/capture-r9-theme-fidelity-review.sh dark
# or:
bash build/macos/capture-r9-theme-fidelity-review.sh light
```

The capture command refuses to proceed if the appearance provider does not
report the expected mode, then captures both Sable Start and Sable Messages.
Human review of those two frames is the Mac proof that Sable-owned applications
observe the same selected appearance across app processes. It does not promote
platform night mode or browser identity to Mac-proven status.

Sable-owned applications that must follow the selected Sable appearance:

- Sable Start / Launcher presentation;
- Sable Messages / Hub;
- Sable Mail;
- Sable Media;
- Sable Reader;
- Sable Calculator;
- all three Sable Games;
- Sable Weather.

Platform surfaces that must follow Android system night mode after the bridge:

- Settings / SystemUI;
- Phone / Dialer;
- Contacts;
- Vanadium;
- other platform applications that honor Android DayNight/system dark mode.

Third-party applications installed later from Play, F-Droid or elsewhere are
not forcibly re-themed. They follow Sable dark/light only when they honor
Android system night mode or compatible dynamic-color APIs.

## Messaging identity

The clean Panther product retains GrapheneOS Messaging package
`com.android.messaging` as the SMS/MMS transport substrate.

Sable Messages / Hub is the Sable-visible communication surface.

The clean product must not accidentally substitute Google Messages
`com.google.android.apps.messaging`.

Sable Messages does not request the default SMS role during this tranche.
GrapheneOS Messaging remains the default Android messaging transport while
Sable Messages organizes SMS/people/providers above it.

## Sable Messages provider surface

Sable Messages currently carries four isolated WEB provider capsules:

- WhatsApp -> `https://web.whatsapp.com/`
- Instagram -> `https://www.instagram.com/direct/inbox/`
- Facebook / Messenger -> `https://www.messenger.com/`
- LinkedIn -> `https://www.linkedin.com/messaging/`

Each provider uses an isolated WebView data-directory suffix and a separate
Android process. Provider navigation is HTTPS-only inside the allowed provider
host set, mixed content is disabled and third-party cookies are disabled.

These are provider capsules, not native unified-inbox APIs. A user can open and
authenticate to the provider messaging surface from Sable Messages when the
provider supports its web experience. Sable does not scrape private app
databases or claim direct native send/read capability that the provider has not
authorized.

Future installed-app or Android-notification integration may complement these
capsules, but must preserve the same explicit authorization boundary.

## Browser identity

The GrapheneOS standard browser is Vanadium.

Expected package:

`app.vanadium.browser`

The clean Panther product must resolve normal HTTPS browsing to Vanadium and
must not preload Google Chrome `com.android.chrome`.

Sable Launcher displays the package-manager supplied application label/icon for
ordinary third-party/platform apps. It must therefore show Vanadium on the real
Panther image rather than carrying over the Pixel AVD's Chrome inventory.

## Physical acceptance

The final Panther validation must prove:

```
R9_FINAL_UI_VANADIUM_PACKAGE=PASS
R9_FINAL_UI_DEFAULT_BROWSER=PASS_VANADIUM
R9_FINAL_UI_GOOGLE_CHROME_PRELOAD=PASS_ABSENT
R9_FINAL_UI_GRAPHENE_MESSAGING_PACKAGE=PASS
R9_FINAL_UI_GOOGLE_MESSAGES_PRELOAD=PASS_ABSENT
R9_FINAL_UI_SMS_ROLE=PASS_GRAPHENE_MESSAGING
R9_FINAL_UI_SABLE_MESSAGES_PACKAGE=PASS
R9_FINAL_UI_PROVIDER_CAPSULES=PASS_4
```

Appearance remains a screenshot/device-interaction acceptance in addition to
static source contracts:

```
R9_FINAL_UI_APPEARANCE_SABLE_APPS=PASS
R9_FINAL_UI_APPEARANCE_PLATFORM_APPS=PASS
```

Do not infer either Panther appearance marker solely from the Mac AVD.

Mac review acceptance may prove:

```
R9_VISUAL_FIDELITY_APPEARANCE_PROVIDER=PASS
R9_VISUAL_FIDELITY_EXPECTED_MODE=PASS
R9_VISUAL_FIDELITY_AUDIT=PASS
R9_THEME_FIDELITY_PROVIDER_MODE=PASS
R9_THEME_FIDELITY_START_CAPTURE=PASS
R9_THEME_FIDELITY_SABLE_MESSAGES_CAPTURE=PASS
R9_THEME_FIDELITY_CROSS_APP_VISUAL_REVIEW=PENDING_USER_REVIEW
```

It must continue to report:

```
R9_VISUAL_FIDELITY_PLATFORM_NIGHT_MODE_PROOF=DEFERRED_PHYSICAL_PANTHER
R9_VISUAL_FIDELITY_VANADIUM_PROOF=DEFERRED_PHYSICAL_PANTHER
```

