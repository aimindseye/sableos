# R9L9 — Mac mini / Pixel 7 launcher visual validation

Status: **source ready / emulator execution pending**

Date: 2026-09-20

Branch:

```text
r9/launcher-visual-review-r9l9-20260920
```

Base:

```text
r9/launcher3-quickstep-foundation-v2-20260920
bccb38f4b9344960e4f81c9940c398057ac1c2b8
```

## Purpose

Re-establish the previously used Mac mini + Android emulator review loop for
R9 without reviving the retired standalone SableStart launcher architecture.

The review APK renders the production `SableStartScreen` compiled by
`:sablestart-presentation-check`. It does not contain a HOME intent filter,
is not selected by the Panther product, and does not replace
`Launcher3QuickStep`.

The emulator answers a visual/product question:

> Does the current production Sable launcher presentation look and interact as
> intended on the Pixel 7 phone profile?

It does not replace the later physical Panther proof for HOME, Quickstep,
Overview/Recents, task animation, role ownership, or boot behavior.

## Prior evidence reused

The repository already established this style of review before the R9
Launcher3 cutover:

```text
6e0e752  UI: add production-mode SableStart emulator adapter
67e5a7c  UI: launch production-mode SableStart in emulator
e43f909  UI-A: wire emulator adapter to production actions
909f985  UI-A: persist emulator preview pinned apps
924f1f7  UI-A: rename emulator review activity
```

The organization repository also retains the earlier screenshot-bound runtime
visual-closure record in:

```text
sableos-project/packages_apps_SableStart
docs/R3C_R3_VISUAL_CLOSURE_20260911.md
```

R9L9 keeps the useful evidence discipline while removing the old independent
HOME/model boundary.

## R9L9 production delta

Production SableStart now renders the real launcher activity icon when Android
can resolve it through the supported `LauncherApps` API.

Important boundary:

```text
Launcher3 AllAppsStore = authoritative inventory and update stream
Launcher3 AppInfo      = authoritative product launch/details bridge
LauncherApps           = presentation icon resolution only
SableStartScreen       = presentation
```

If an icon cannot be resolved, the existing deterministic Sable initial tile is
retained as the fallback. Missing icon data must not make an app disappear.

## Review APK contract

Module:

```text
apps/r8/android/sablestart-visual-review
applicationId = org.sableos.start.visualreview
```

Required properties:

```text
HOME intent                         ABSENT
HOME role request                   ABSENT
Panther product inclusion           ABSENT
Sable app bundle export             ABSENT
production SableStartScreen reuse   REQUIRED
production design module reuse      REQUIRED
full Panther image build            NOT REQUIRED
flash                               NOT REQUIRED
```

The review activity uses Android `LauncherApps` only to provide the emulator's
launcher-visible fixture inventory and to exercise taps. That code lives only
inside the non-product review module.

## Mac mini preparation

Use the existing Pixel 7 AVD from the earlier UI review work.

From the repository checkout:

```bash
git fetch origin \
  r9/launcher3-quickstep-foundation-v2-20260920 \
  r9/launcher-visual-review-r9l9-20260920

git switch --detach origin/r9/launcher-visual-review-r9l9-20260920

git diff --check \
  origin/r9/launcher3-quickstep-foundation-v2-20260920...HEAD

export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"

# Only needed when the Pixel 7 AVD is not already running.
export AVD_NAME="<existing Pixel 7 AVD name>"

bash build/macos/prepare-r9-launcher-visual-review.sh
```

The runner defaults to Gradle offline mode. On a Mac that has not yet cached
the pinned AndroidX graph, it reports `R9_VISUAL_REVIEW_DEPENDENCY_CACHE=MISS`
instead of silently using the network. Authorize the one-time dependency
bootstrap explicitly:

```bash
NETWORK_FETCH_AUTHORIZED=YES \
  bash build/macos/prepare-r9-launcher-visual-review.sh
```

After that successful fetch, normal review reruns return to offline mode.

It refuses a non-Pixel-7 AVD unless an explicit reviewed exception sets:

```bash
ALLOW_NON_PIXEL7_AVD=YES
```

Do not set that for the normal R9 review.

The preparation step:

1. verifies macOS;
2. finds or starts the established Pixel 7 AVD;
3. compiles the production presentation source;
4. assembles and lints the review APK;
5. installs and launches the review activity;
6. records AVD/device/display identity;
7. captures the initial Start frame;
8. leaves the full Panther build unauthorized.

## Required visual set

Capture after manually navigating the production UI:

```text
00-start-initial
01-start-dark
02-start-light
03-all-apps-top
04-all-apps-rail
05-search-command
06-search-results
07-sable-peek
08-local-context-denied
09-appearance
10-start-accent-alternate
```

For each frame:

```bash
bash build/macos/capture-r9-launcher-visual-review.sh 01-start-dark
```

The helper stores a PNG, SHA-256 and focused-activity state beside the initial
evidence.

## Review criteria

### Start

- real application icons are visible for resolvable launcher activities;
- no package names are shown in the ordinary Start UI;
- four Start tiles remain visually coherent with the Metro-derived hierarchy;
- the Favorites section stays within comfortable lower-screen reach;
- Search / Command and All Apps are discoverable without excess chrome;
- truthful context does not fabricate remote/live state.

### All Apps / Sable Rail

- label-first list remains the dominant surface;
- real icons do not crowd the label;
- right-edge alphabet rail remains reachable;
- tap and drag rail behavior remain visually stable;
- long labels do not collide with the rail or context affordance.

### Search / Command

- search field is immediately legible;
- local commands remain visually distinct from app results;
- app results use the same real-icon treatment as All Apps;
- no web/cloud search affordance is implied.

### Sable Peek

- app identity is obvious;
- Open, Pin/Unpin and Permissions & app info have clear hierarchy;
- the panel remains a single contextual level rather than a nested menu system.

### Appearance

- Follow system, Light and Dark remain the only theme modes;
- the bounded accent set remains visually coherent;
- changing theme/accent updates the production screen rather than a mock surface.

## Explicit non-claims

Passing this emulator visual gate does not prove:

- Launcher3 HOME ownership;
- Quickstep Recents/Overview correctness;
- gesture/task-animation integration;
- system-server role persistence;
- boot-to-HOME behavior;
- physical Pixel 7 performance or power;
- Titan 2 keyboard/focus acceptance.

Those remain later device/runtime gates.

## Acceptance state

Before screenshots are reviewed:

```text
R9_L9_VISUAL_REVIEW_HARNESS=SOURCE_READY
R9_SABLESTART_VISUAL_REVIEW_SET=PENDING
R9_SABLESTART_PRODUCT_IDENTITY=PENDING_USER_REVIEW
R9_L6_VISUAL_REVIEW_STATUS=PENDING
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```

Only after the captured set is reviewed and accepted should this become:

```text
R9_SABLESTART_VISUAL_REVIEW_SET=PASS
R9_SABLESTART_PRODUCT_IDENTITY=APPROVED
R9_L6_VISUAL_REVIEW_STATUS=PASS
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES
```
