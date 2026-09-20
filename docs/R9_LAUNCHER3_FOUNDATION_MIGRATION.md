# R9 Launcher3 / Quickstep Foundation Migration

Status: **source deliverable implemented / CI and focused local Soong qualification pending**

Date: 2026-09-20

## Decision

SableOS no longer treats SableStart as a separate HOME application that recreates launcher behavior beside Quickstep.

The product launcher foundation is the pinned Android 17 GrapheneOS Launcher3/Quickstep tree:

```text
GrapheneOS tag: 2026081300
Launcher3 repository: GrapheneOS/platform_packages_apps_Launcher3
Launcher3 commit: e5fde8f4368539554b07ee136abd27bc7b4284c1
product module: Launcher3QuickStep
package: com.android.launcher3
Sable HOME activity: com.android.launcher3.sable.SableQuickstepLauncher
```

The SableStart Compose UI remains the user-facing launcher design. It is compiled into `Launcher3QuickStep` as a presentation layer over the mature Android launcher machinery.

## Why this migration happens before the next image

Panther physical testing exposed failure modes that were artifacts of maintaining a second HOME app:

- HOME resolver/default-role competition with Quickstep;
- independent activity lifecycle behavior;
- duplicate package-change/app-loading machinery;
- independent app-launch behavior;
- startup/signing/package-scan failure modes specific to a second launcher APK;
- extra device qualification work that would otherwise be repeated on Panther and Titan 2.

With Titan 2 entering bring-up, the common launcher foundation must be established first so device testing concentrates on interaction and hardware differences rather than basic launcher correctness twice.

## Ownership after migration

Launcher3/Quickstep owns:

- launcher process and HOME lifecycle;
- app model/loading;
- package, profile, suspension and availability updates;
- app launch semantics and per-user launch handling;
- configuration and state restoration;
- shortcuts and widget-host infrastructure;
- Recents/Overview;
- task/transition animation integration;
- gesture-navigation integration.

Sable presentation owns:

- Start root;
- Favorites;
- session-only recent presentation;
- All Apps label-first list and Sable Rail;
- local Search/Command;
- Sable Peek;
- local calendar/media context;
- Follow system / Light / Dark;
- bounded Sable accent state.

## Source composition

The canonical SableStart tree is now presentation-only:

```text
src/android/packages/apps/SableStart/
  Android.bp -> sable_start_presentation_srcs
  live/
  model/
  platform/
  ui/
```

Retired product implementation:

```text
AndroidManifest.xml
SableStartActivity.kt
LauncherAppsRepository.kt
SableStartNative.kt
rust/src/lib.rs
standalone SableStart android_app
standalone SableStart Rust/JNI module
```

The global appearance provider authority remains:

```text
org.sableos.start.appearance
```

This avoids an unnecessary API change for existing Sable first-party appearance consumers even though the provider implementation now executes inside `com.android.launcher3`.

## Launcher3 integration

The fail-closed applicator is:

```text
patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py
```

It refuses mutation unless Launcher3 is exactly the pinned commit.

It performs only the reviewed foundation delta:

- adds SableStart presentation sources to `Launcher3QuickStepLib`;
- adds the shared Sable design source filegroup;
- adds required Compose/foundation dependencies;
- adds explicit local-context permissions to the Quickstep launcher manifest;
- registers the Sable appearance provider;
- changes the HOME activity to `SableQuickstepLauncher`;
- keeps the `com.android.launcher3` package and privileged/system-ext product identity;
- applies the user-visible `Sable Start` launcher label.

## Runtime bridge

`SableQuickstepLauncher` subclasses `QuickstepLauncher`.

The bridge deliberately uses Launcher3 APIs rather than duplicating them:

```text
app inventory/update source -> ActivityContextComponent / AllAppsStore
launch target              -> Launcher3 AppInfo
launch operation           -> startActivitySafely(...)
app details                -> PackageManagerHelper.startDetailsActivityForInfo(...)
Recents/Overview            -> Quickstep unchanged
HOME lifecycle              -> QuickstepLauncher lifecycle
```

The Sable Compose layer is visible only in `LauncherState.NORMAL`. Non-NORMAL states reveal the native Quickstep state surface.

Sable nested navigation reports whether it can consume Back. Quickstep remains the Back/predictive-back authority and delegates to the Sable navigation layer only when appropriate.

## Product composition rule

After this migration:

```text
Launcher3QuickStep.apk     REQUIRED
package com.android.launcher3 REQUIRED
SableStart.apk             FORBIDDEN
package org.sableos.start  FORBIDDEN_AS_HOME_APK
```

Historical SableStart v4-signing and HOME-priority gates are retired from the active build path because the second launcher APK no longer exists. The incident documentation remains historical evidence.

## Focused qualification before any full Panther build

Run only the bounded launcher qualification:

```bash
SOURCE_MUTATION_AUTHORIZED=YES \
BUILD_AUTHORIZED=YES \
bash build/panther/qualify-r9-launcher3-foundation.sh
```

The qualifier:

1. validates the repository foundation contract;
2. syncs Sable design and presentation sources;
3. applies/verifies the pinned Launcher3 delta;
4. lunches `panther-cur-userdebug`;
5. builds only `Launcher3QuickStep`;
6. verifies the foundation again after compilation.

It does **not** clean/clobber, fetch from the network, contact a device, flash, or build a complete Panther image.

Required marker:

```text
R9_L7_LAUNCHER3_FOUNDATION_COMPILE=PASS
```

## Full-image gate

A full Panther image remains blocked until both are true:

```text
R9_L7_LAUNCHER3_FOUNDATION_COMPILE=PASS
R9_SABLESTART_VISUAL_REVIEW_SET=PASS
```

Final target-files must then prove:

```text
Launcher3QuickStep.apk = exactly one
package = com.android.launcher3
SableStart.apk = absent
```

## Physical acceptance

Panther physical acceptance after the eventual image build must prove:

```text
HOME_RESOLVER=com.android.launcher3/.sable.SableQuickstepLauncher
HOME_ROLE_HOLDER=com.android.launcher3
COLD_HOME_LAUNCH_CRASHES=0
HOME_KEY_RETURNS_TO_START=PASS
QUICKSTEP_RECENTS_PRESERVED=PASS
PACKAGE_INSTALL_REMOVE_REFRESH=PASS
MULTI_USER_PROFILE_LAUNCH=PASS_WHERE_AVAILABLE
ALL_APPS_TOUCH_NAVIGATION=PASS
SEARCH_LOCAL_RESULTS=PASS
SABLE_PEEK=PASS
THEME_PROPAGATION=PASS
```

## Titan 2 consequence

Titan 2 should inherit this same launcher foundation.

Shared across Panther and Titan 2:

- Launcher3 model/loading;
- package/profile changes;
- HOME lifecycle;
- app launch semantics;
- shortcuts/widgets foundation;
- Quickstep/Recents;
- Sable Start semantic UI;
- Sable Search/Peek;
- appearance state.

Device-specific Titan 2 acceptance can therefore focus on:

- physical keyboard type-to-search;
- first-character preservation;
- focus traversal;
- Enter/Back/navigation keys;
- square display geometry;
- pointer/trackpad behavior where exposed.

This is the intended reduction in duplicated device validation work.
