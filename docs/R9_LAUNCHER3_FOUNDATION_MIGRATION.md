# R9 Launcher3 / Quickstep foundation migration

> **Historical HOME-ownership note (2026-10-01):** this record predates the final R9L8 cutover. Current HOME runtime is Launcher3/Launcher3QuickStep hosting Sable Start presentation/state source. Do not use standalone-SableLauncher statements here as current Titan 2/C3B architecture. See `CURRENT_HOME_AND_C3B_INTEGRATION_AUTHORITY.md` and `../src/android/packages/apps/SableStart/PORTABILITY_STATUS.md`.

Status: **standalone Sable HOME + Quickstep Recents-only architecture**

## Current architecture

R9 no longer uses Launcher3 as the user-facing HOME implementation.

The product boundary is:

- `SableLauncher` is the standalone HOME application.
- package: `org.sableos.launcher`
- activity: `org.sableos.start.SableStartActivity`
- `Launcher3QuickStep` remains installed only as Android's
  Quickstep/Recents integration substrate.
- Launcher3 must not advertise HOME or ALL_APPS eligibility.
- the legacy `org.sableos.start` standalone package is retired.
- Sable presentation sources remain shared through
  `sable_start_presentation_srcs`.

Expected device state:

```text
HOME_RESOLVER=org.sableos.launcher/org.sableos.start.SableStartActivity
HOME_ROLE_HOLDER=org.sableos.launcher
LAUNCHER3_HOME_ROLE_ABSENT=PASS
LAUNCHER3_HOME_ELIGIBILITY_ABSENT=PASS
QUICKSTEP_SERVICE_PRESENT=PASS
QUICKSTEP_FALLBACK_RECENTS_PRESERVED=PASS
LEGACY_SABLESTART_PACKAGE_ABSENT=PASS
```

## Why the Launcher3 foundation still exists

The pinned Android 17 Launcher3 tree still needs a bounded set of compatibility
changes before it compiles cleanly in the SableOS product environment. Those
changes remain in
`patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py`.

That applicator is now an **intermediate compatibility layer only**. It is not
the final launcher architecture and must never be interpreted as proof that
Launcher3 owns HOME.

The final preparation sequence is:

```text
sync standalone SableLauncher
        ↓
apply/verify Launcher3 compatibility foundation
        ↓
apply/verify Quickstep Recents-only cutover
        ↓
compile SableLauncher + Launcher3QuickStep
```

`build/panther/prepare-r8-final-ui.sh` enforces that order. The foundation
contract also verifies that the Recents-only cutover follows the foundation
intermediate before product qualification.

## Standalone SableLauncher boundary

The canonical Sable HOME source lives under:

```text
src/android/packages/apps/SableStart/
```

The Soong definition must contain the standalone `SableLauncher`
`android_app`, including the presentation and shared-design filegroups.

Required runtime source includes:

```text
AndroidManifest.xml
res/values/strings.xml
src/com/sable/start/SableStartActivity.kt
src/com/sable/start/platform/LauncherAppsRepository.kt
```

Retired runtime source remains forbidden:

```text
rust/src/lib.rs
src/com/sable/start/bridge/SableStartNative.kt
src/com/sable/start/platform/SableAppearanceProvider.kt
```

Settings owns the global appearance authority. SableLauncher is an authorized
client/editor, not a second appearance authority.

## Quickstep Recents-only boundary

The final Launcher3 state is produced by:

```text
patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py
```

That cutover must establish:

- Sable Launcher3 host source absent;
- Launcher3 HOME eligibility absent;
- QuickstepLauncher private/internal only;
- TouchInteractionService retained;
- RecentsActivity retained;
- fallback Recents preserved.

Required source markers include:

```text
R9_SABLE_LAUNCHER3_HOST=PASS_ABSENT
R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT
R9_LAUNCHER3_PRIVATE_ACTIVITY=PASS_INTERNAL_ONLY
R9_QUICKSTEP_SERVICE=PASS_RETAINED
R9_FALLBACK_RECENTS=PASS_RETAINED
R9_QUICKSTEP_RECENTS_ONLY=PASS
```

## Focused foundation qualification

The focused qualifier remains:

```bash
bash build/panther/qualify-r9-launcher3-foundation.sh
```

It is source/build qualification only. It does not authorize a full image,
flash, or device mutation.

The qualifier now:

1. verifies the repository foundation contract;
2. syncs shared Sable design;
3. syncs standalone SableLauncher and requires
   `SABLESTART_STANDALONE_RUNTIME=PASS_PRESENT`;
4. applies/verifies the Launcher3 foundation intermediate;
5. applies/verifies the Quickstep Recents-only cutover;
6. compiles `SableLauncher Launcher3QuickStep`;
7. verifies the post-build Recents-only state;
8. runs the Launcher3 warning gate.

Expected result markers include:

```text
R9_SABLELAUNCHER_WORKSPACE=PASS_PRESENT
R9_SABLELAUNCHER_PRODUCT=PASS_PRESENT
R9_LAUNCHER3_HOME_OWNERSHIP=PASS_ABSENT
R9_QUICKSTEP_RECENTS_ONLY=PASS
R9_SABLE_HOME_QUICKSTEP_FOUNDATION_COMPILE=PASS
FULL_PANTHER_BUILD_PERFORMED=NO
DEVICE_CONTACTED=NO
```

## Product qualification

The canonical pre-image sequence is still:

```bash
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 qualify physical-ux
```

The second command is module-only and must retain:

```text
BUILD_AUTHORIZED=YES_MODULES_ONLY
FULL_TARGET_FILES_BUILD_AUTHORIZED=NO
```

Only after both source-bound gates pass for the same commit may a fresh
target-files/image build be authorized.

## Device acceptance

Physical HOME/Recents acceptance uses:

```bash
bash tests/launcher3/device/r9_home_acceptance.sh
```

The gate is non-destructive. It does not flash, reboot, wipe, change slots,
install, or uninstall packages.

It validates the standalone SableLauncher resolver/role/process state, absence
of Launcher3 HOME eligibility, presence of the Quickstep service, fallback
Recents behavior, HOME return behavior, launcher interaction regressions and
the bounded manual UX checks.

The authoritative final marker is:

```text
R9_SABLE_HOME_DEVICE_ACCEPTANCE=PASS
```

## Cross-device rule

Future device ports such as Titan 2 may reuse the same product boundary:
standalone SableLauncher for HOME and the platform's qualified
Quickstep/Recents substrate where applicable. Device-specific work should focus
on hardware, display, keyboard and input differences rather than recreating a
second launcher ownership model.
