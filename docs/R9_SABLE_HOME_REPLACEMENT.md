# R9 Sable HOME Replacement

> **Historical HOME-ownership note (2026-10-01):** this record predates the final R9L8 cutover. Current HOME runtime is Launcher3/Launcher3QuickStep hosting Sable Start presentation/state source. Do not use standalone-SableLauncher statements here as current Titan 2/C3B architecture. See `CURRENT_HOME_AND_C3B_INTEGRATION_AUTHORITY.md` and `../src/android/packages/apps/SableStart/PORTABILITY_STATUS.md`.

Status: implementation tranche after physical rejection of the Sable-over-Launcher3 architecture.

## Physical evidence that triggered this change

The source-bound Panther candidate `48956a2f6f12ecfd59fd7fc6134c10db4efccea9`
passed build, flash, runtime identity, All Apps, local Search, Sable Peek and
permission-summary checks. The strengthened physical gesture gate then failed
all four launcher-boundary cases:

```text
SABLE_SUBSURFACE_BACK_GESTURES=FAIL
SABLE_ABORTED_SWIPE_NO_NATIVE_ESCAPE=FAIL
SABLE_COMMITTED_RECENTS_GESTURE=FAIL
SABLE_STATUS_SHADE_GESTURE_STABILITY=FAIL
R9_LAUNCHER3_HOME_DEVICE_ACCEPTANCE=FAIL
```

The failure is treated as an architecture failure, not as another request for
Launcher3 visibility/touch-controller guards.

## R9 launcher architecture

### User-facing HOME

SableOS owns a standalone HOME application:

```text
module: SableLauncher
package: org.sableos.launcher
HOME activity: org.sableos.start.SableStartActivity
presentation namespace: org.sableos.start.*
```

The package is intentionally new. `org.sableos.start` was the retired R8
standalone package and must not be silently resurrected as an upgrade artifact.

SableLauncher owns:

- Start
- All Apps
- local Search
- Sable Peek
- Live
- Appearance entry/editing
- app launch and app-details routing
- touch navigation inside Sable HOME
- keyboard navigation and type-to-search
- launcher-only favorites/start-tile state
- privacy/security permission summaries shown in All Apps

The host-side Gradle `sablestart-presentation-check` compiles and lints only
the six canonical files in the Soong `sable_start_presentation_srcs`
filegroup. A Gradle `Sync` task mirrors those six files into the module build
directory before Kotlin compile and every lint task, so Android Lint cannot
walk the broader canonical source root. It must not compile or lint
`SableStartActivity.kt` or `LauncherAppsRepository.kt`; those are standalone
runtime sources and are qualified by the Soong/module path.

SableLauncher uses `sdk_version: "system_current"`, not unrestricted
`platform_apis`. The system SDK is required for Android's
`Context.createContextAsUser(...)` API used to read per-profile permission
state. The package query uses the public legacy
`getPackageInfo(String, int)` overload with `GET_PERMISSIONS` instead of the
API-33-only `PackageInfoFlags.of(...)` wrapper. If a profile context cannot be
obtained, the launcher reports the permission summary as unavailable rather
than falling back to another user's package state.

Settings remains the only persisted global appearance authority at
`content://org.sableos.appearance/appearance`.

### Recents / gesture navigation substrate

Launcher3QuickStep remains installed for R9 only as the Android
Quickstep/Recents integration substrate. The existing Launcher3 foundation
applicator is a compile-compatibility intermediate only: preparation may apply
it to the pinned Launcher3 tree, but must immediately apply and verify the
Recents-only cutover before qualification. It must no longer host Sable UI or be
the default HOME.

When another package owns HOME, Launcher3's existing Quickstep implementation
uses its fallback RecentsActivity path. R9 deliberately uses that supported
boundary instead of placing a full-screen Compose launcher inside
QuickstepLauncher.

R9 does **not** attempt to replace TouchInteractionService / the Quickstep
protocol in this tranche. A Sable-owned Recents provider can be considered in a
later release after HOME behavior is stable.

### No hidden native launcher contract

The following are release requirements:

```text
R9_SABLE_HOME_ROLE=PASS_ORG_SABLEOS_LAUNCHER
R9_LAUNCHER3_HOME_ROLE=PASS_ABSENT
R9_LAUNCHER3_SABLE_HOST=PASS_ABSENT
R9_LAUNCHER3_USER_VISIBLE_WORKSPACE=PASS_UNREACHABLE_FROM_HOME
R9_QUICKSTEP_SERVICE=PASS_RETAINED
R9_FALLBACK_RECENTS=PASS
```

There must be no Sable ComposeView layered over Launcher3 workspace and no
Sable-specific touch-controller interception patch.

## Preserved-data migration

A preserved-data upgrade can retain the old HOME role holder. Merely adding a
new HOME activity is insufficient.

Qualification therefore has two distinct requirements:

1. product source contains SableLauncher as the intended HOME candidate;
2. the controlled physical migration explicitly changes the Android HOME role
   from `com.android.launcher3` to `org.sableos.launcher` without clearing
   userdata.

The permanent product mechanism must use Android's HOME role/default-home
authority rather than package-disable tricks. Launcher3QuickStep stays enabled
because SystemUI still binds its Quickstep service.

No wipe, clean, clobber or bootloader-state change is part of this migration.

## Live-snapshot privacy boundary

Weather, Calendar, Messages, Mail and Media snapshot providers admit
`org.sableos.launcher` as the product launcher caller and reject unrelated
callers. Launcher3 access is not part of the standalone HOME architecture.

The appearance provider writer policy likewise admits SableLauncher while
retaining Settings as the persisted authority owner.

## Keyboard-first contract

The standalone launcher is designed for both touch-first Pixel and
keyboard-first Titan-class devices. Navigation state must not depend on touch
gestures.

Required keyboard behavior:

- printable key from Start/All Apps enters local search;
- Up/Down/Left/Right move deterministic focus;
- Enter launches or activates the focused control;
- Back/Escape returns one Sable destination;
- Home returns to Start;
- alphabet rail has keyboard equivalents (letter typing and section focus);
- every action reachable by touch is reachable without touch unless it is an
  intrinsically touch-only system gesture.

This contract is added now even though Panther remains the R9 physical release
device.

## Contacts alphabet rail

GrapheneOS Contacts already has `ContactsSectionIndexer` and indexed cursor
metadata. Sable does not build a second contact index.

The default contacts browse screen gets a right-edge alphabet rail which maps a
letter to the existing section index and scrolls the existing list. This is a
bounded Contacts UI-behavior change; the old presentation-only claim for the
Contacts applicator is retired. ContactsProvider, account, sync, permission and
contact-data behavior remain untouched.

## Media library navigation

Songs, Artists, Albums and Favorites use the same right-edge alphabet-rail
interaction pattern as All Apps. Playlists keep their existing product-specific
ordering.

Track rows become flat list rows:

- no card border / boxed row chrome;
- title remains primary;
- artist and album remain secondary metadata;
- favorite and play remain visible primary row actions;
- destructive remove is no longer an inline `×` action;
- remove moves to an explicit manage/context flow so accidental deletion is
  harder.

Artists and Albums use equivalent flat rows and alphabet section navigation.

Large-library behavior is part of the launcher-adjacent acceptance contract:
Media collection sorting/grouping/section-index construction runs off the UI
thread; Songs/Artists/Albums/Favorites render lazily; Up Next and playlist
editing render lazily; playback-position ticks are active only on Now Playing;
and queue launch uses a bounded process-local token rather than serializing the
full library through Binder.

## Qualification sequence

No full Panther image is authorized until this tranche passes:

1. standalone SableLauncher static contract;
2. SableLauncher Soong module compile;
3. Launcher3 Quickstep recents-only source contract;
4. Contacts alphabet-rail module compile;
5. Sable Media alphabet-rail/flat-row compile and quality gates;
6. combined R9 module qualification.

Only then freeze one source commit for a fresh Panther target-files build.

Physical acceptance must prove:

- HOME role holder is `org.sableos.launcher`;
- Sable HOME survives repeated HOME presses and process restart;
- Back works on all Sable sub-surfaces;
- Android Recents works through fallback Quickstep;
- aborted/committed swipe-up never reveals Launcher3 workspace;
- notification-shade swipe-down is stable;
- All Apps/search/Peek/permission summaries remain intact;
- keyboard navigation contract is exercisable through ADB key events;
- Contacts and Media alphabet rails jump to the requested section.
