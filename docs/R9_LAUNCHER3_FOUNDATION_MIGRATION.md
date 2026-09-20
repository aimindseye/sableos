# R9 Launcher3 / Quickstep Foundation Migration v2

Status: **phase 2 HOME ownership cutover implemented in source / focused cutover compile pending**

Date: 2026-09-20

## Product decision

SableOS will use the pinned Android 17 GrapheneOS Launcher3/Quickstep implementation as the single launcher/HOME foundation.

Pinned source:

```text
Repository: GrapheneOS/platform_packages_apps_Launcher3
Commit: e5fde8f4368539554b07ee136abd27bc7b4284c1
Product module: Launcher3QuickStep
Package: com.android.launcher3
Sable host: com.android.launcher3.sable.SableQuickstepLauncher
```

SableStart becomes the presentation layer hosted by Quickstep. Launcher3 remains responsible for lifecycle, app model, package/profile updates, launching, shortcuts/widgets, Recents/Overview and Android launcher integration.

## Why v2 is phased

The earlier R9 foundation branch attempted source retirement and product cutover before the focused Launcher3 compile had been proven. That branch also diverged from the pre-INFRA5 main line.

v2 starts from the locally qualified post-INFRA5 main and separates proof from retirement:

```text
Phase 1: host-compile proof
    -> expose Sable presentation as a Soong filegroup
    -> patch pinned Launcher3QuickStep in the workspace
    -> compile Launcher3QuickStep only
    -> retain standalone SableStart source/product temporarily

Phase 2: ownership cutover
    -> remove standalone SableStart app/JNI/activity/app-loading implementation
    -> remove SableStart from product packages
    -> move active build/target-files gates to Launcher3QuickStep
    -> require SableStart.apk absent

Phase 3: visual + physical acceptance
    -> final Sable presentation review
    -> full Panther image only after visual approval
    -> verify HOME/Recents/package refresh/theme behavior on device
```

A full Panther image remains unauthorized until the Phase 2 focused cutover compile passes and the Sable launcher visual review is accepted.

## Phase 1 ownership

Launcher3/Quickstep supplies:

- `QuickstepLauncher` HOME lifecycle and state machine;
- `AllAppsStore` inventory and package/profile refresh;
- `AppInfo` launch metadata;
- `startActivitySafely(...)` app-launch semantics;
- app-details integration;
- Recents/Overview and transition machinery;
- predictive-back authority.

Sable supplies:

- Start presentation;
- Favorites;
- session-only recent presentation;
- All Apps label-first list and alphabet rail;
- local Search/Command;
- Sable Peek;
- local calendar/media context;
- appearance state and Sable accent selection.

## Host bridge

`SableQuickstepLauncher` subclasses `QuickstepLauncher` and attaches one Compose surface to the Launcher drag layer.

The surface is visible only in `LauncherState.NORMAL`. Native Quickstep surfaces remain visible for non-normal states such as Overview and All Apps transitions.

The app inventory is projected from Launcher3's `AllAppsStore`; Sable does not register a second `LauncherApps.Callback` in the hosted path.

Launch requests resolve back to Launcher3 `AppInfo` and call `startActivitySafely(...)`. App information uses `PackageManagerHelper.startDetailsActivityForInfo(...)`.

## Back and Home ownership

The Compose presentation no longer installs its own Android `BackHandler`.

The host sends two monotonic generations:

```text
homeGeneration -> reset Sable presentation to Start
backGeneration -> perform one Sable nested-navigation back step
```

The presentation reports whether it can navigate back. Quickstep keeps predictive-back ownership and delegates to Sable only while the Sable surface is visible and nested navigation can consume the event.

## Niagara-inspired interaction rules

Sable adopts interaction lessons, not Niagara code or branding.

Useful Niagara principles confirmed from its public documentation:

- the app list is a primary navigation surface rather than a secondary grid;
- alphabet navigation is a first-class fast-access mechanism;
- one-hand reach is a core interaction constraint;
- feature/settings growth should be restrained so optional features do not make the default experience complex.

References:

- https://help.niagaralauncher.app/article/8-niagaras-design-principles
- https://help.niagaralauncher.app/article/171-alphabet-settings
- https://help.niagaralauncher.app/article/39-left-hand-mode
- https://help.niagaralauncher.app/article/77-missing-customization-features

Sable deliberately differs in several areas:

- no usage-ranked All Apps ordering by default;
- no persistent usage-learning requirement;
- session recents remain memory-only;
- no ambient network search;
- privacy/security context remains part of Sable Peek;
- Metro/Modern typography and Sable identity remain the visual language.

## Audited fallback Quickstep residue

Before the first v2 foundation apply, the canonical Panther workspace contained exactly two pre-existing Launcher3 modifications while the repository HEAD remained pinned at `e5fde8f4368539554b07ee136abd27bc7b4284c1`:

```text
quickstep/src/com/android/quickstep/FallbackActivityInterface.java
HEAD blob:     d9f14ac530bc9f81910e305536f1e39a0ef6e564
worktree blob: 8387af17a577a6720cccbc5ca952aefffafa6157
change:        interactor == null -> interactor == null || callbacks == null

quickstep/tests/multivalentTests/src/com/android/quickstep/FallbackSwipeHandlerTestCase.java
HEAD blob:     e68f0d2d9d242104b9ce05685e83708704b6dd5f
worktree blob: 23239ce5180bee05da6ea52afe889e00523619c4
change:        local null-callback regression test
```

Review found that current GrapheneOS Launcher3 already applies the same null-callback guard in the normal `LauncherActivityInterface`, while the pinned/current fallback implementation lacks it. The production fallback guard is therefore retained as an explicit Sable compatibility delta.

The local regression-test residue is not retained because it constructs the Dagger singleton incorrectly for the pinned API. The applicator recognizes that exact audited test blob only, restores that file to pinned `HEAD`, and then requires it to remain clean. The production fallback file is accepted before apply only at the exact audited `8387af...` blob; any other pre-existing fallback edit fails closed.

After apply, the complete allowed Launcher3 dirty set is exactly five files: the Quickstep library build file, Quickstep launcher manifest, Quickstep label resources, Sable host source, and `FallbackActivityInterface.java`.

## Warning-quality policy

The Launcher3 foundation compile is not considered quality-closed merely because it compiles. The focused build log is parsed by `build/gates/r9-launcher-warning-gate.py`.

The first successful hosted-Launcher build exposed 126 source warnings plus one R8 toolchain warning. The warning cleanup is intentionally split into two classes:

```text
SAFE MIGRATIONS
- Kotlin KT-73255 annotation default-target warnings
- typed Parcelable APIs
- explicit Handler Looper binding
- nullable File.listFiles handling
- deprecated framework overrides marked explicitly
- legacy preview message IDs retained without deprecated symbols
- override parameter-name mismatches
- Sable system-bar deprecated color setters

STRUCTURAL / UPSTREAM DEBT
- deprecated Launcher3 Executors bridge and call sites
- deprecated LauncherAppState access paths
- deprecated ModelDbController.db uses that still require raw SQLiteDatabase
- DesktopModeStatus APIs marked for removal
- remaining generic Bundle/value and unchecked-cast warnings
- R8 prebuilt lacking API-level 37 support
```

No blanket deprecation suppression is accepted as closure. The migration gate may pass when all Sable-owned and already-migrated warning classes are clean, but it reports `R9_LAUNCHER3_WARNING_DEBT_STATUS=OPEN` while inherited or toolchain debt remains. Final launcher quality closure requires that debt to be either migrated with evidence or resolved at the appropriate upstream/toolchain boundary.

The R8 API-37 warning is tracked separately as `R9_LAUNCHER3_R8_API37_DEBT`; lowering the platform/target API is not an acceptable fix.

## Easy Dagger executor migration before HOME cutover

Before retiring standalone SableStart, R9 migrates the low-risk constructor-injected users of the deprecated static `Executors` bridge. The mapping is limited to bindings that already have an explicit Dagger equivalent in `LauncherExecutorsModule`:

```text
Executors.MAIN_EXECUTOR
  -> @Ui Executor / LooperExecutor

Executors.UI_HELPER_EXECUTOR
  -> @LightweightBackground(priority = UI) LooperExecutor

Executors.ORDERED_BG_EXECUTOR
  -> @Background Executor / LooperExecutor
```

The first Dagger tranche covers:

```text
WidgetAppIconsRepositoryImpl
WallpaperColorHints
FirstScreenBroadcastHelper
ModelTaskController
RefreshRateTracker.RefreshRateTrackerImpl
RemoveAnimationSettingsTracker (obsolete deprecated import)
```

`FirstScreenBroadcastHelper` retains its one-argument unit-test constructor via a `@VisibleForTesting` main-looper executor while production construction uses injected `@Ui LooperExecutor`. Its nullable-installer-map unchecked cast is also removed.

This tranche intentionally does **not** replace `MODEL_EXECUTOR` with a generic background executor. The pinned Launcher3 tree does not expose a dedicated Dagger model-thread qualifier, and model ordering semantics must not be changed merely to silence deprecation warnings.

The 2026-09-20 focused baseline attributes 17 warnings to this tranche: 16 deprecated static-executor warnings and one unchecked cast. Qualification requires those exact warning signatures to stay absent through the path-specific warning regression gate.

## Focused qualification

Run only after synchronizing this repository branch locally:

```bash
SOURCE_MUTATION_AUTHORIZED=YES \
BUILD_AUTHORIZED=YES \
bash build/panther/qualify-r9-launcher3-foundation.sh
```

The qualifier resolves the current build workspace from `build/config/r8-release.env` and then layers Panther device/lunch constants from `build/config/panther-grapheneos-2026081300.env`. This avoids the retired `/srv/data/sableos/upstream/...` layout.

The focused compile also reuses the canonical warmed Panther output (`SABLE_R8_OUT_DIR`, currently `out_sable_r8_final`) by default. It refuses a cold output unless `ALLOW_COLD_OUT=YES` is explicitly supplied. A warm output must already contain a Ninja graph and `target/product/panther`; this prevents a nominally module-only `m Launcher3QuickStep` request from triggering a many-thousand-action cold dependency rebuild.

The qualifier performs:

1. repository Phase 2 foundation contract;
2. shared Sable design sync;
3. presentation-only Sable Start sync, which deletes retired standalone runtime files from the workspace;
4. pinned Launcher3 applicator self-test;
5. pinned Launcher3 HOME ownership apply + verify;
6. Panther lunch;
7. `m Launcher3QuickStep` only;
8. post-build foundation verification;
9. path-specific warning/deprecation regression gate.

It does not clean, clobber, fetch network content, contact a device, flash, or build a full Panther image.

Before mutation, the applicator inspects the Launcher3 Git worktree and refuses any dirty path outside the reviewed `FOUNDATION_DIRTY_PATHS` set. After apply, it requires exactly that bounded set. The set now includes the Sable host integration plus the explicitly reviewed warning/Dagger migration files; unknown Launcher3 dirt still fails closed.

Required Phase 2 success markers:

```text
R9_SABLESTART_STANDALONE_RUNTIME=PASS_ABSENT
R9_LAUNCHER3_HOME_OWNERSHIP=PASS
R9_L7_LAUNCHER3_FOUNDATION_COMPILE=PASS
R9_L8_HOME_CUTOVER_COMPILE=PASS
```

A full Panther image remains blocked after these markers until the launcher visual review is accepted.

## Phase 2 acceptance target

After retirement, repository/product gates must prove:

```text
Launcher3QuickStep.apk = exactly one
package = com.android.launcher3
HOME activity = com.android.launcher3.sable.SableQuickstepLauncher
SableStart.apk = absent
org.sableos.start standalone HOME package = absent
```

The existing appearance provider authority remains `org.sableos.start.appearance` for first-party compatibility, even though its implementation executes inside the Launcher3 process.

## Panther physical acceptance

After visual approval and a full Panther image, run:

```bash
bash tests/launcher3/device/r9_home_acceptance.sh
```

The gate is non-destructive: it does not flash, reboot, wipe, change slots, install, or uninstall packages. It performs resolver/role/package/process/crash checks plus HOME/Recents navigation, then records bounded manual confirmations for the presentation interactions that cannot be proven from shell state alone.

The eventual full-image/device gate must prove:

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

Titan 2 inherits the same launcher foundation. Its later acceptance can focus on keyboard and square-display behavior rather than duplicating launcher model/lifecycle work:

- first-character-preserving type-to-search;
- hardware focus traversal;
- Enter/Back/navigation keys;
- square geometry;
- pointer/trackpad behavior when exposed.
