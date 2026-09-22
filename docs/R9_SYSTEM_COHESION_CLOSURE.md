# R9 System Cohesion Closure

Status: **active / physical R9 candidate rejected**

Integration branch:

```text
r9/system-cohesion-closure-20260921
```

Baseline branch commit:

```text
c04f62aa894788091cd3dc15c01603902a3cd455
```

Failed physical image source:

```text
d35a1c9f79da1d7a0d114602f8b41fd4f799df35
```

This tranche converts the current Sable presentation overlays into a coherent
SableOS product shell while retaining Android/GrapheneOS security and service
implementation underneath.

## Source progress — 2026-09-22

```text
WS0=PASS_SOURCE
WS1=PASS_SOURCE_SETTINGS_HOSTED_APPEARANCE
WS2=PASS_SOURCE_SABLE_HOME_QUICKSTEP_RECENTS
WS3=PASS_SOURCE_SETTINGS_APPEARANCE_AND_NETWORK_MANAGER
WS4=PASS_SOURCE_SYSTEMUI_SHARED_AUTHORITY
WS5=PASS_SOURCE_READER_READIUM_BRIDGE
WS6=PASS_SOURCE_PLATFORM_CLASSIFICATION
WS7=IN_PROGRESS_AI_G732_MODULE_QUALIFICATION
WS8=BLOCKED_UNTIL_WS7_PASS
```

Implemented source boundaries:

- Settings owns global appearance persistence, write authorization and
  locked-boot/boot/package-replace restoration.
- Sable Settings adds Network Manager backed directly by GrapheneOS'
  user-revocable `android.permission.INTERNET`; R9 intentionally does not
  fabricate separate Mobile/WLAN toggles because the base does not provide
  transport-scoped per-app enforcement.
- Launcher3 no longer requests `MODIFY_DAY_NIGHT_MODE` and no longer hosts the
  appearance provider.
- Sable Start writes the Settings authority and prevents native Launcher3
  All Apps/workspace presentation from becoming a second HOME surface.
- Quickstep nav-edge Recents/Overview remains preserved.
- SystemUI observes the same Sable accent authority; the exact old Launcher
  authority bridge is a recognized one-time migration and arbitrary bridge
  drift remains fail-closed.
- Reader maps ordinary Readium page Light/Dark to Sable system appearance while
  retaining explicit Sepia/E-ink reading overrides.
- residual platform surfaces are classified in
  `docs/R9_PLATFORM_SURFACE_CLASSIFICATION.md`.
- `build/gates/r9-system-cohesion-contract.py` is mandatory in local CI and
  Panther pre-full qualification.

No new full Panther image has been authorized or built by this source work.


## Serial workstreams

### WS0 — Baseline and acceptance contract

Freeze the current failed physical evidence and introduce source/runtime gates
for the defects exposed on Panther. No feature mutation is accepted without a
corresponding fail-closed contract.

Exit gate:
- physical failure evidence referenced;
- no-native-launcher-escape contract exists;
- appearance ownership contract exists;
- final physical acceptance markers documented.

### WS1 — System-owned appearance authority

Replace Launcher3 ownership of global appearance with a privileged Sable system
authority. Launcher and Settings become editors/clients. Existing first-party
apps and SystemUI consume the same authority.

Required behavior:
- follow-system/light/dark;
- Sable accent preset;
- persisted state available after reboot;
- persisted explicit light/dark re-applies Android `UiModeManager`;
- observers update without app-specific duplicated preference stores.

Exit gate:
- one authority;
- no Launcher3-only global preference ownership;
- Settings and Launcher read/write through the same contract;
- boot/user-unlock restoration path covered by tests.

### WS2 — Launcher and Quickstep ownership

Keep Launcher3/Quickstep as HOME/Recents infrastructure but prevent its native
workspace/app drawer from becoming a second user-facing launcher.

Sable owns:
- Start;
- All Apps;
- Search;
- Sable Peek;
- launcher appearance navigation.

Quickstep owns:
- Recents/Overview;
- task/gesture integration needed by Android.

Fix:
- vertical touch/scroll interception;
- native All Apps escape;
- HOME reset semantics;
- Start gear -> Sable control/Appearance;
- Android Settings remains an explicit secondary route.

Exit gate:
- Start scrolls normally;
- swipe/navigation cannot expose native Launcher3 drawer/workspace;
- Recents remains native Quickstep;
- Sable All Apps/Search/Peek all work;
- permission subtitles remain.

### WS3 — Sable Settings control center

Compose UI5A, UI5B and UI5C into one coherent Settings product surface rather
than disconnected deltas.

Top-level Sable responsibilities:
- Appearance;
- Privacy & Security;
- Applications;
- Connectivity;
- Device;
- People & Accounts;
- System;
- About SableOS.

Underlying Android/GrapheneOS fragments continue to perform enforcement and
policy mutation.

Exit gate:
- Appearance is first-class and backed by WS1;
- Applications permission summaries work;
- Application Security & Privacy evidence remains accessible;
- About uses real device/build properties;
- no security control is reimplemented unnecessarily.

### WS4 — SystemUI and key system surfaces

Finish Sable coherence for:
- status/notification shade;
- Quick Settings;
- media controls;
- privacy indicators;
- lockscreen/keyguard;
- bounded system presentation reached in normal daily use.

Preserve upstream:
- notification behavior/ranking;
- privacy logic;
- tile state;
- media routing;
- authentication;
- accessibility;
- gesture/falsing/security state machines.

Exit gate:
- system night-mode follows WS1;
- active Sable accent is observed;
- physical visual states have dedicated acceptance markers.

### WS5 — Core apps and Reader

Audit base-product apps in both light and dark:
- Phone;
- Contacts;
- Files/DocumentsUI;
- Clock;
- Photos/Gallery;
- Vanadium;
- Camera where supported by its upstream pipeline;
- all first-party Sable apps.

Reader additionally bridges global Sable light/dark to default Readium page
theme while retaining explicit reading-only overrides such as Sepia/E-ink.

Exit gate:
- light -> dark -> light state works;
- no Sable app has conflicting chrome/content colors;
- Reader chrome and default reading canvas agree;
- no unsafe binary patching of security-sensitive apps.

### WS6 — Residual platform and branding audit

Traverse remaining visible platform flows and classify every surface:

```text
SABLE_OWNED
SABLE_PRESENTED_ANDROID
INTENTIONALLY_UPSTREAM
```

Scope includes SetupWizard, About, PermissionController, install/package flows,
chooser/share, accounts/accessibility entry surfaces and other base-system UI
encountered during daily-driver traversal.

User-facing ownership should be SableOS where truthful. Internal GrapheneOS
package names, APIs, services and provider identifiers are not cosmetically
renamed.

Exit gate:
- no accidental GrapheneOS/Android product-shell leakage in intended Sable
  surfaces;
- intentional upstream identifiers are documented rather than hidden.

### WS7 — Integrated pre-image qualification

Current 2026-09-22 checkpoint:

- first-party Android build: PASS;
- Sable Reader build: PASS, tracked Kotlin/native-strip warnings both 0;
- Sable Mail build and policy verification: PASS;
- source-bound ten-APK bundle: PASS;
- UI5C/UI6 cumulative-state recognition: PASS;
- SystemUI coherence upgraded from the exact legacy Launcher appearance
  authority to the Settings-owned authority: PASS;
- Settings appearance + Network Manager cohesion: PASS;
- shared Sable Design synchronization: PASS;
- SableStart sync contract: corrected after detecting the retired
  `SableAppearanceProvider.kt` was still listed as required by the sync
  script.
- Launcher foundation resume: the driver now verifies an existing foundation
  before replaying it; a valid foundation is reused and only the cohesion
  layer is applied. This avoids re-running the large Launcher warning-cleanup
  patch set on an already-patched workspace.

Full target-files build remains blocked until the remainder of WS7 module
qualification passes on one immutable source commit.

The 2026-09-22 warning-cleanup experiment after the Start-sync fix intentionally
tried to eliminate five Thunderbird/Gradle build-tool deprecation warnings.
Changing `build-plugin/` invalidated Thunderbird's previously proven offline
build-logic cache and caused Gradle 9.6.1 to request uncached
`org.jetbrains.kotlin:kotlin-stdlib-common:2.3.21`. The experiment was
reverted without changing any Sable Mail runtime/product patch. The Mail flavor
is byte-identical to the prior successful variant, and the verifier now rejects
any future mutation of Thunderbird's root `build.gradle.kts` or
`build-plugin/` tree. The upstream deprecation lines remain diagnostic and
nonblocking.

The subsequent WS7 run reached final product composition with the ten-APK
freeze, cumulative SystemUI/Settings/Launcher preparation, final source
verification, and the no-stale-product gate all passing. It stopped only at
`R9_RETIRED_LAUNCHER_APPEARANCE_AUTHORITY`. That was a qualification
false-positive: the composition gate recursively scanned Android unit tests and
matched the deliberate negative regression assertion proving that
`org.sableos.start.appearance` is not the active authority. The gate now keeps
the broad production/runtime scan while excluding `test`, `androidTest`, and
Markdown inputs. The stale SableStart portability document was also reconciled
to the Settings-owned `content://org.sableos.appearance/appearance` contract
with the Launcher-owned appearance provider explicitly retired.

A follow-up WS7 run proved the first scope correction was still too broad:
although source `src/test` was excluded, the composition gate executes after
Gradle tests/builds and recursively traversed generated `build/` output, where
the compiled negative regression assertion still contains the retired authority
literal. Generated build/cache/output directories are now excluded from this
source-composition check as well.


No full image yet.

Run:
- self-tests;
- exact-source applicator verification;
- Launcher3 module build;
- Settings module build;
- SystemUI/framework module qualification;
- Reader and Sable app builds;
- product-composition/stale-code gates;
- new system-cohesion source contracts.

Exit gate:
all pre-image gates green on one immutable source commit.

### WS8 — Fresh Panther candidate and physical acceptance

Build exactly one new candidate after WS0-WS7.

Then:
- target-files identity/freshness;
- inactive-slot preserved-data flash;
- package/runtime identity;
- HOME/Quickstep;
- Settings/Appearance;
- SystemUI;
- core apps;
- Reader;
- light -> dark -> light;
- branding;
- daily-driver regression.

R9 closes only when the physical device can no longer fall through into an
unintended alternate product presentation.

## Execution policy

Workstreams are serial. Later streams may add tests while earlier work is in
progress, but implementation dependencies do not leapfrog the sequence.

There will be one integration branch and one final integration PR/candidate,
not one PR per workstream.
