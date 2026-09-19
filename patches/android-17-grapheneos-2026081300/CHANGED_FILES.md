# D2+D3 changed-file ledger

Canonical base: GrapheneOS `2026081300`

## SetupWizard2

Base HEAD:

```text
3982cfc3536620c17b2ec5c3494af0fb2a58a633
```

Changed:

```text
res/values/strings.xml
res/layout/activity_welcome.xml
res/layout/activity_finish.xml
res/drawable-nodpi/sableos_icon.png (new)
```

Exact visible mutations:

```text
Welcome to GrapheneOS -> Welcome to SableOS
GrapheneOS icon -> SableOS icon
@drawable/grapheneos_icon -> @drawable/sableos_icon (welcome + finish)
If you have a backup from your previous GrapheneOS device, you can restore it here.
  -> If you have a compatible backup from a previous device, you can restore it here.
```

## Settings

Base HEAD:

```text
71bd21cda07f4dfdcec2aabb16bc570be5bd8d35
```

Changed:

```text
res/values/strings_app_exploit_protection.xml
res/values/strings_ext.xml
```

Exact visible mutations:

```text
GrapheneOS exploit protections -> SableOS exploit protections
GrapheneOS will remain installed. -> SableOS will remain installed.
```

## frameworks/base

Base HEAD:

```text
aab06a8bd44c4c2b58eeec780fde83baa9d43a40
```

Changed:

```text
core/res/assets/images/android-logo-mask.png
```

Exact asset transition:

```text
old Graphene mask SHA-256
75efac98abbc429c9aaa4c1aea918014aaead364b802ecec493c70c2d000df41

new Sable mask SHA-256
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e
```

Unchanged shine asset:

```text
73c2cb640b053c29ec8be308892759a33cd6ed5aa85283cca2a456d208ccd4fb
```

## Binary assets stored in this repository

```text
assets/sableos_setupwizard_icon.png
eed1b1277a77fa1f94b514585622c403c85c95191cfa3ba90edf526d02e5aea7

assets/sableos_boot_fallback_mask_448x605.png
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e
```

Use `apply_sable_branding.py`, rather than broad search-and-replace, to reconstruct the exact changed source scope from the pinned base.


## UI5A Settings + Applications

Base HEAD remains:

```text
71bd21cda07f4dfdcec2aabb16bc570be5bd8d35
```

Layered after D2+D3 branding, UI5A additionally changes:

```text
res/layout/settings_homepage_container.xml
res/xml/top_level_settings.xml
res/xml/top_level_settings_expressive.xml
res/xml/top_level_settings_expressive_desktop.xml
src/com/android/settings/applications/manageapplications/ManageApplications.java
```

and adds:

```text
res/layout/sable_settings_home_header.xml
res/values/colors_sable_ui5a.xml
res/values/strings_sable_ui5a.xml
src/com/android/settings/applications/TopLevelApplicationsPreferenceController.java
src/com/android/settings/applications/manageapplications/SableSensitiveAccessSummary.java
```

Semantics:

- Sable Settings home header is a production Android resource;
- Applications moves into the privacy/security group;
- Applications opens `ManageApplications` directly;
- homepage app count is derived from PackageManager for the current user;
- normal main-list subtitles report only effective sensitive permission grants;
- AppOps, observed behavior, provenance, components, tracker/library analysis,
  network destinations and security history remain deferred to UI5B.


## UI5B Application Security & Privacy evidence

Layered after UI5A, UI5B additionally changes:

```text
res/xml/app_info_settings.xml
src/com/android/settings/applications/appinfo/AppInfoDashboardFragment.java
```

and adds:

```text
res/xml/sable_app_security_privacy.xml
res/values/strings_sable_ui5b.xml
src/com/android/settings/applications/appinfo/SableAppSecurityPrivacyFragment.java
src/com/android/settings/applications/appinfo/SableAppSecurityPrivacyPreferenceController.java
```

Semantics:

- identity/provenance comes from PackageManager and signing metadata;
- sensitive authority separates manifest declaration, permission grant and
  mapped AppOps state;
- component counts/export state come from parsed package metadata;
- packaged native-code presence is bounded local APK static inference;
- install/update timestamps are local PackageManager-observed state;
- tracker execution, network destinations and permission/AppOps event history
  remain explicit `UNKNOWN` until qualified evidence sources exist;
- the UI5B surface is read-only and retains existing Android Settings flows for
  all mutations.


## UI5C + UI6 final system surfaces

Layered after D2+D3 + UI5A + UI5B + UI4, the combined tranche additionally
modifies:

```text
packages/apps/SetupWizard2/res/layout/activity_welcome.xml
packages/apps/SetupWizard2/res/layout/activity_finish.xml
packages/apps/SetupWizard2/res/values/strings.xml

packages/apps/Settings/res/xml/my_device_info.xml
packages/apps/Settings/res/xml/top_level_settings.xml
packages/apps/Settings/res/xml/top_level_settings_expressive.xml
packages/apps/Settings/res/xml/top_level_settings_expressive_desktop.xml

frameworks/base/packages/SystemUI/src/com/android/systemui/keyguard/ui/view/layout/sections/ClockSection.kt
frameworks/base/packages/SystemUI/res/values/dimens.xml
frameworks/base/packages/SystemUI/res/values/strings.xml
```

and adds:

```text
packages/apps/SetupWizard2/res/values/colors_sable_ui5c.xml
packages/apps/SetupWizard2/res/values/strings_sable_ui5c.xml
packages/apps/Settings/res/values/strings_sable_ui5c.xml
packages/apps/Settings/src/com/android/settings/deviceinfo/aboutphone/SableAboutPreferenceController.java
```

The Keyguard changes are presentation-only and do not alter authentication,
device-entry, biometric, notification-redaction or privacy-indicator state
machines.
