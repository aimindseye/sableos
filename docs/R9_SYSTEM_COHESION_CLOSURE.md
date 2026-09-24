# R9 System Cohesion Closure

Status: **active / standalone-HOME source and focused app qualification complete; fresh physical candidate pending**

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
- standalone `org.sableos.launcher` owns the intended HOME surface and writes
  the Settings appearance authority as a client/editor;
- Launcher3 no longer advertises HOME or hosts Sable UI;
- Quickstep Recents/Overview services remain preserved as a recents-only substrate.
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

### Long-lived Settings workspace convergence

Panther preparation may encounter either the exact pre-cohesion Settings dirty
scope or the exact already-applied final cohesion dirty scope. The Settings
cohesion applicator accepts only those two states.

When the final cohesion scope is already present, the applicator may refresh
only the bounded cohesion files/entries and then must pass the same final
verifier. Any additional unexpected dirty path remains a hard failure. This
makes repeated release-candidate/module qualification idempotent without
turning Settings preparation into a broad workspace reset or best-effort patch.

Expected self-test markers:

```text
R9_SETTINGS_COHESION_SELF_TEST_PRE_SCOPE=PASS
R9_SETTINGS_COHESION_SELF_TEST_FINAL_SCOPE=PASS
R9_SETTINGS_COHESION_SELF_TEST_DRIFT_REJECTION=PASS
```


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
- one authority, with the literal owned by `SableAppearanceContract` and
  provider code consuming `SableAppearanceContract.CONTENT_URI`;
- no Launcher3-only global preference ownership;
- Settings and Launcher read/write through the same contract;
- boot/user-unlock restoration path covered by tests.

### WS2 — Standalone HOME and Quickstep ownership

Standalone SableLauncher owns Android HOME. Launcher3QuickStep remains installed
only for Recents/Overview/task-gesture integration and must not advertise HOME,
ALL_APPS or expose a native workspace as a fallback.

Sable owns:
- Start;
- All Apps;
- Search;
- Sable Peek;
- launcher appearance navigation.

Quickstep owns:
- Recents/Overview;
- TouchInteractionService/task-animation integration needed by Android.

Launcher3 does **not** own HOME or host the Sable Compose presentation.

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

### R9 physical-regression correction

The rejected physical candidates exposed defects that are now source-gated:

- Clock/Photos use qualified Day/Night presentation so Light restores visible
  semantic text/background colors;
- Camera remains an intentionally upstream preprocessed APK boundary and is not
  falsely claimed to follow Sable Light/Dark;
- Reader ordinary Light/Dark follows global Sable appearance; local Light/Dark
  ownership is retired for the Sable flavor while Sepia/E-ink remain explicit;
- Reader library renders actual distinct books continuously rather than exposing
  only a six-item stack/page count;
- Reader no longer hosts the hidden plain-text/OCR runtime; standalone
  `org.sableos.textreader` owns text/plain, share/process-text, text TTS/audio
  export and camera/gallery OCR with no INTERNET permission or translation
  model-download path;
- Contacts uses the existing section indexer plus a right-edge alphabet rail;
- Media uses lazy large-library surfaces, background indexing and bounded queue
  handoff;
- Sable Messages is SMS/People-first; embedded provider WebViews are retired.

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
Sable Text Reader is reviewed separately as the plain-text/accessibility/OCR
surface and follows the same global Sable appearance authority.

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
literal. The retirement check now uses `git grep` over tracked production
source only, with test-source and Markdown exclusions. Untracked/generated
Gradle output therefore cannot participate in the source-composition decision.

The next WS7 run passed that composition blocker and reached the Android
Launcher3 module preflight, but the qualification driver had selected a new
source-specific empty OUT and forced `REQUIRE_FRESH_OUT=YES` even though the
run was module-only. That turned `m Launcher3QuickStep` into a cold framework
dependency build and exposed broad Metalava/API-stub diagnostics unrelated to
the intended focused launcher proof. This contradicted the existing Launcher3
qualification contract, which requires a warmed Panther graph for module-only
qualification. WS7 now reuses the canonical `SABLE_R8_OUT_DIR` and the inner
build rejects `modules + REQUIRE_FRESH_OUT=YES`. The fresh source-bound OUT
policy remains reserved for WS8 full target-files/release-candidate causality.

The warm-graph rerun then reached the focused `Launcher3QuickStepLib` Kotlin
compile and exposed the real launcher source defect: the two appearance-write
callbacks inside `ComposeView.apply { setContent { ... } }` passed unqualified
`this`. At those call sites Kotlin resolves `this` to the enclosing
`ComposeView`, while `writeGlobalSableAppearance(...)` requires an Android
`Context`. Both writes now pass `this@SableQuickstepLauncher`, matching the
explicit receiver style already used by the appearance observer in the same
class. The Launcher3 foundation contract requires both qualified calls.

A later long-lived-workspace rerun exposed historical Launcher cohesion residue
in `PortraitStatesTouchController.java` and
`NoButtonNavbarToOverviewTouchController.java`. Those mutations belonged to
the retired SableQuickstepLauncher-based HOME interception layer and are not
part of the current standalone-SableLauncher / Quickstep-Recents-only
architecture.

The Launcher3 foundation now recognizes only the exact two-file retired
cohesion transformation reconstructed from pinned Launcher3 HEAD. If both files
match that historical transformation byte-for-byte, they are normalized back
to pinned HEAD before foundation convergence continues. Partial residue,
unexpected extra dirt, or content mismatch remains fail-closed. The retired
`apply_r9_launcher_cohesion.py` applicator is removed and the no-stale gate
requires it to remain absent.

The following preparation pass proved that normalization, then exposed an
interface inconsistency in the Recents-only applicator: production callers pass
the Android workspace root as `--source`, while the script attempted
`git -C <source>` as though it had received the Launcher3 repository itself.
The applicator now resolves
`<workspace>/packages/apps/Launcher3` internally. A direct Launcher3 root is
accepted only for isolated self-tests/developer probes when canonical
`Android.bp` and `quickstep/` markers are present; unresolved roots fail
closed.

A subsequent focused Launcher3 rerun exposed one more long-lived-workspace
state: the tree was already at the Recents-only final dirty scope from the
prior run, but carried the older observer transform that had dropped the
`ResolveInfo` import. Re-entering the foundation intermediate is incorrect for
that state because `OverviewComponentObserver.java` is intentionally dirty
only in the final Recents-only layer.

The Recents-only applicator therefore has a narrow `upgrade-final` path. It is
eligible only when the Launcher3 dirty set exactly equals the expected final
Recents-only set derived from the foundation dirty-set contract, all final
Recents-only semantics pass except for the missing `ResolveInfo` import, and
the retained `ResolveInfo secondaryInfo` use is present. It then restores only
that missing import and re-runs the full final verifier. Production preparation
and the focused Launcher3 qualifier now use the order: final verify, exact
stale-final upgrade, then foundation intermediate + final cutover only when
neither final state applies.

The next preparation pass proved the Quickstep source-root fix and advanced to
Contacts. The long-lived Contacts tree was in a bounded partial presentation
state: the four color/layout/style files were already canonical Sable
presentation changes, while the two alphabet-rail Java files had returned to
pinned Contacts HEAD. The Phone/Contacts applicator now permits partial
convergence only when every approved file is either byte-for-byte pinned HEAD
or byte-for-byte canonical transformed content, and when no dirty path exists
outside the approved set. It applies only the missing transformations and then
requires the exact six-file Contacts final scope. Any mixed/manual content
inside an approved path still fails closed.


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
