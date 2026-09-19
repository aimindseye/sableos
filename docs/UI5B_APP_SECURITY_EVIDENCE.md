# UI5B production: Application Security & Privacy evidence

Status: **production applicator ready for source qualification**

Base Settings repository:

```text
GrapheneOS/platform_packages_apps_Settings
71bd21cda07f4dfdcec2aabb16bc570be5bd8d35
```

UI5B layers on top of the validated UI5A Settings delta. It does not introduce a
root/ADB package-management service and it does not mutate package state.

## Entry point

The standard Android App info screen gains:

```text
Application Security & Privacy
Identity, authority, components and local evidence
```

The destination is a read-only Sable evidence surface. Existing Android App
info controls remain the policy-changing path for permissions, notifications,
data, battery, special access and uninstall/disable operations.

## Evidence implemented in UI5B

### Identity and provenance

PackageManager-backed:

- package name;
- version name and long version code;
- minimum and target SDK;
- installer / initiating / originating package when available;
- current signing-certificate SHA-256;
- signing-lineage presence and certificate count;
- system / updated-system / user-installed classification;
- debuggable and test-only flags.

### Effective authority

For monitored sensitive permission groups, UI5B separates:

- declaration from `PackageInfo.requestedPermissions`;
- current grant from PackageManager;
- mapped AppOp state when Android exposes a permission-to-AppOp mapping.

The screen never treats a manifest declaration as runtime use.

Initial monitored groups include camera, microphone, location, contacts,
calendar, phone/call log, SMS, nearby devices, media, sensors and notifications.

### Components and attack surface

PackageManager metadata provides counts for:

- activities;
- services;
- broadcast receivers;
- providers;
- instrumentation.

For the first four component types the surface shows:

- total count;
- enabled count;
- exported count;
- exported-without-component-permission count;
- up to four exported component names for orientation.

This is `DECLARED` package metadata. It is not presented as a risk score.

The surface also reports declarations of elevated component classes detectable
from binding permissions, including accessibility services, notification
listeners, VPN services, input methods, autofill services and device-admin
receivers.

### Code and libraries

UI5B locally scans the installed base/split APK ZIPs for packaged `.so` files.

That result is labeled `INFERRED`, because it is bounded static package
inspection rather than runtime load evidence.

Shared-library paths exposed by ApplicationInfo are labeled `DECLARED`.

Tracker/library signatures remain:

```text
UNKNOWN
```

until a versioned local signature dataset/analyzer is implemented. No absence or
execution claim is fabricated.

### Network and background

Implemented:

- INTERNET manifest declaration;
- current INTERNET permission grant;
- battery-optimization exemption state;
- package stopped state.

Not yet collected:

- per-app Wi-Fi/mobile transport counters;
- destination/domain history.

Those fields explicitly render `UNKNOWN`.

### Local history

PackageManager first-install and last-update timestamps are shown as local
`OBSERVED` state.

A persistent permission/AppOps event journal is not yet implemented and is
shown as `UNKNOWN`, rather than reconstructing a false history.

## Evidence classes

UI5B follows the project-wide contract:

```text
DECLARED
ENFORCED
OBSERVED
INFERRED
UNKNOWN
```

The screen has no opaque score and no overall app verdict.

## Source delta

Modified on top of UI5A:

```text
res/xml/app_info_settings.xml
src/com/android/settings/applications/appinfo/AppInfoDashboardFragment.java
```

Added:

```text
res/xml/sable_app_security_privacy.xml
res/values/strings_sable_ui5b.xml
src/com/android/settings/applications/appinfo/SableAppSecurityPrivacyFragment.java
src/com/android/settings/applications/appinfo/SableAppSecurityPrivacyPreferenceController.java
```

## Validation

Repository-only self-test:

```bash
python3 patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py \
  --self-test
```

Apply / verify on the UI5A-qualified Panther workspace:

```bash
python3 patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py \
  --source /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300 \
  apply

python3 patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py \
  --source /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300 \
  verify
```

Incremental compile gate:

```bash
cd /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300
source build/envsetup.sh

export OUT_DIR=out_sable_ui_preview
export SOONG_NINJA=ninja
export SOONG_INCREMENTAL_ANALYSIS=false

lunch panther-cur-userdebug
m -j8 Settings
```

No clean/clobber is required or authorized for this gate.

## Deferred evidence

The following remain explicit future work rather than being simulated by UI5B:

- versioned tracker/SDK signature dataset;
- persistent permission/AppOps change journal;
- per-app network destination attribution;
- reliable split Wi-Fi/mobile usage if a qualified Android accounting source is
  selected;
- observed native-library load state;
- scoped enforcement controls beyond existing Android Settings flows.
