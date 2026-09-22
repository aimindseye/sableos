# R9 final UI runtime acceptance

## Physical candidate rejection — 2026-09-21

The Panther image built from source commit
`d35a1c9f79da1d7a0d114602f8b41fd4f799df35` passed package/runtime identity
checks but failed physical daily-driver acceptance.

Physical evidence:

```text
/srv/data/sable-build/evidence/panther/r9-physical/20260921_221930/home-20260921_224929
```

Observed release-blocking failures:

```text
ALL_APPS_TOUCH_NAVIGATION=FAIL
SEARCH_LOCAL_RESULTS=FAIL
SABLE_PEEK=FAIL
R9_LAUNCHER3_HOME_DEVICE_ACCEPTANCE=FAIL
```

The supplied physical video additionally demonstrated native Launcher3
presentation escaping beneath the Sable Compose surface, inconsistent system
appearance propagation, the Start Settings shortcut bypassing Sable appearance
controls, and Reader content/chrome theme divergence.

The rejected image remains useful as evidence but is not an R9 release
candidate. Remediation is tracked by `docs/R9_SYSTEM_COHESION_CLOSURE.md`.

Final closure now additionally requires:

```text
R9_SABLE_NATIVE_LAUNCHER_ESCAPE=PASS_ABSENT
R9_SABLE_HOME_NAVIGATION=PASS
R9_SABLE_SETTINGS_TOP_LEVEL=PASS
R9_SABLE_APPEARANCE_CONTROL=PASS
R9_SABLE_APPEARANCE_BOOT_RESTORE=PASS
R9_SABLE_SYSTEM_NIGHT_PROPAGATION=PASS
R9_SABLE_SYSTEMUI_APPEARANCE=PASS
R9_SABLE_CORE_APPS_APPEARANCE=PASS
R9_SABLE_READER_APPEARANCE=PASS
R9_SABLE_USER_VISIBLE_BRANDING_AUDIT=PASS
R9_PHYSICAL_DAILY_DRIVER_ACCEPTANCE=PASS
```


Status: **required before Panther UI closure**

## R9 validation authority update — 2026-09-21

For this R9 build, the user has closed Mac-mini visual validation after repeated
review-harness failures. Mac screenshots are therefore not a release gate.

```
R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9
R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED
R9_FINAL_VISUAL_AUTHORITY=PHYSICAL_PANTHER
```

The waiver does not waive production compilation, Linux CI, module
qualification, product-composition checks, or physical-device acceptance.
Start/Live/theme, Launcher3 HOME/Recents, SystemUI, Vanadium, Messaging,
Calendar and other runtime presentation claims must be checked on the flashed
Panther.

This acceptance exists because the Pixel 7 AVD used for Mac visual design
contains Google applications and emulator-specific package state that is not
the SableOS/GrapheneOS Panther product.

## Appearance

Sable appearance has one system authority:

`content://org.sableos.appearance/appearance`

The provider is hosted by the privileged Settings package and stores its state
in device-protected storage. It owns:

- Follow system / Light / Dark;
- the Sable accent preset;
- restoration of explicit Light/Dark through Android `UiModeManager` during
  locked boot, normal boot and Settings package replacement.

Launcher3 is no longer the operating-system appearance authority. Sable Start
may edit the same provider for fast access, while Settings exposes the
first-class Appearance page. Sable-owned applications observe the provider
through `SableGlobalTheme`; SystemUI observes its accent and Android system
night mode; platform/core applications follow Android DayNight/system mode when
their upstream implementation supports it.

The Panther acceptance must prove the complete chain:

```text
Settings appearance selection
        -> org.sableos.appearance
        -> persisted device-protected state
        -> UiModeManager
        -> SystemUI / platform apps
        -> Sable app observers
```

A reboot while explicit Dark or Light is selected must restore the same mode
without opening Launcher or Settings.

Sable-owned applications that must follow the selected appearance include
Start, Messages, Mail, Media, Reader, Calculator, Games, Weather and Calendar.
Reader additionally maps normal Readium page Light/Dark to the Sable system
mode. Sepia and E-ink remain explicit reading-only overrides.

Platform/core surfaces that must follow Android system night mode include
Settings, SystemUI, Phone, Contacts, Clock, Files, Photos/Gallery, Vanadium and
other bundled apps that honor Android DayNight/system appearance. Camera
remains within its upstream preprocessed/security boundary and is accepted
according to the appearance support of that upstream package.

Third-party applications installed later are not forcibly recolored. They
follow Sable Light/Dark only when they honor Android system night mode or a
compatible platform appearance API.

### Mac boundary

The Mac mini is not required for this closure and may remain asleep. The
standalone launcher review APK is a design-only host with local appearance
state; it does not emulate or own the production privileged appearance
provider. It cannot prove boot restoration, `UiModeManager`, SystemUI,
Vanadium, Quickstep or platform-app appearance. All final appearance authority
is physical Panther.

Required physical markers:

```text
R9_SABLE_APPEARANCE_CONTROL=PASS
R9_SABLE_APPEARANCE_BOOT_RESTORE=PASS
R9_SABLE_SYSTEM_NIGHT_PROPAGATION=PASS
R9_SABLE_SYSTEMUI_APPEARANCE=PASS
R9_SABLE_CORE_APPS_APPEARANCE=PASS
R9_SABLE_READER_APPEARANCE=PASS
```

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

## Calendar and launcher Live privacy boundary

Sable Calendar package `org.sableos.calendar` is the Sable-visible calendar
application. It uses Android `CalendarProvider` for event storage and replaces
the upstream `Calendar` product module rather than introducing a second
calendar database.

Launcher3 does not read Calendar, SMS, Mail or Media databases directly. Those
applications expose bounded read-only snapshot providers for Start/Live:

- Weather -> `org.sableos.weather.snapshot`
- Calendar -> `org.sableos.calendar.snapshot`
- Messages -> `org.sableos.hub.snapshot`
- Mail -> `org.sableos.mail.snapshot`
- Media -> `org.sableos.media.snapshot`

The sensitive app-owned providers accept the product Launcher3 caller and reject
unrelated callers. Sable Start requests local photo access only for the Photos
summary. Live refresh is provider/lifecycle driven rather than a permanent
one-minute polling loop. Home must not expose message bodies or mail subjects.

## Daily-driver core application presentation

Clock, Files and Photos are presentation-only source changes pinned to the
GrapheneOS 2026081300 revisions. Their application behavior remains upstream.
GrapheneOS Camera is delivered as a preprocessed APK in this baseline and
Vanadium has its own security-sensitive build pipeline, so R9 does not binary
patch either of them. They retain upstream behavior and identity while Sable
controls the surrounding launcher/system appearance.

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
R9_FINAL_UI_SABLE_CALENDAR_PACKAGE=PASS
R9_FINAL_UI_PLATFORM_CALENDAR_PRELOAD=PASS_ABSENT
R9_FINAL_UI_LIVE_PROVIDER_CALLER_BOUNDARY=PASS
```

Appearance remains a screenshot/device-interaction acceptance in addition to
static source contracts:

```
R9_FINAL_UI_APPEARANCE_SABLE_APPS=PASS
R9_FINAL_UI_APPEARANCE_PLATFORM_APPS=PASS
```

Do not infer either Panther appearance marker solely from the Mac AVD.

Mac review acceptance may prove the following production Sable-owned
surfaces from the shared production renderer and installed review APKs:

- Start in dark and light mode, including the approved Settings gear, greeting,
  dimensional tile hierarchy, approved Sable/Phosphor app identity and the
  `all apps · search · live` navigation;
- Live layout and provider/lifecycle presentation, using source-bound Mac
  fixtures only where the corresponding production package cannot be built on
  macOS;
- Sable Calendar landing layout from the real `org.sableos.calendar` APK;
- Sable Messages landing layout from the real `org.sableos.hub` APK;
- Sable-owned appearance-provider propagation between the review Start host and
  Sable Messages.

The minimal production capture set is:

```
20-production-start-dark.png
21-production-start-light.png
22-production-live-dark.png
23-production-calendar-dark.png
24-production-messages-dark.png
```

Mac review does **not** prove the real Launcher3 HOME/Quickstep integration,
SystemUI or privileged `UiModeManager` propagation, GrapheneOS Messaging role
ownership, Vanadium/default-browser identity, GrapheneOS Camera behavior, the
source-patched AOSP Clock/Files/Photos runtime, signing/verified boot, or any
physical-device behavior. Those are Panther-only checks.

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

