# R9 SableStart launcher design expansion

Status: **approved design scope / Mac gate waived for R9 / physical Panther is final visual authority**

Date: 2026-09-20

## Release rule

R9 exists to make SableStart feel like the primary SableOS shell rather than a launcher prototype.

The approved Daily Driver design remains the R9 visual target. For this build,
Mac-mini visual validation is closed and the final visual decision is deferred
to the physical Panther after Linux CI, module qualification and a fresh image
build.

~~~
R9_LAUNCHER_DESIGN_REVIEW_REQUIRED=YES
R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9
R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_LINUX_QUALIFICATION
~~~

The build may proceed after ai-g732 qualification; visual/runtime acceptance is
then completed on the flashed Panther.

This does not block source review, tests, documentation, CI, standalone design work, or other non-image product work.

## Product intent

SableStart remains a Sable/Metro-derived launcher, not a Niagara, Pixel, Lawnchair or Windows Phone clone.

The target combines:

- Sable/Metro information hierarchy, large typography, restrained flat geometry and live information;
- Niagara-style one-handed reachability, alphabet navigation, favorites discipline and contextual expansion;
- Kvaesitso-style search/command centrality;
- Olauncher-style restraint and privacy;
- OpenMiniLaunch/MinkLauncher keyboard-first search behavior for Titan-class devices;
- retained Launcher3/Quickstep integration where Android overview/gesture plumbing is mature and Sable does not yet own a replacement.

The result should feel faster, calmer and more intentional than the current R8 SableStart while preserving SableOS identity.

## Current R8 gaps

The current production SableStart establishes the basic shell, app inventory, pinning, appearance state and local live-data plumbing, but its home experience is still too close to a development/reference surface:

- the primary home surface exposes too little information density for a true Sable shell;
- the app list lacks an edge alphabet rail and rapid one-handed jump navigation;
- app context is a separate full screen rather than a fast contextual layer;
- search is app-only rather than a unified local Sable command/search surface;
- the Start/live relationship is separated rather than integrated into one calm home hierarchy;
- the launcher has no explicit thumb-reach model for tall slab phones;
- launcher ownership, cold-start survival and visual review were not treated as independent physical release gates in R8.

R9 addresses these as product-design scope, not as isolated styling changes.

## External reference review

Reference use is behavioral and architectural unless a separate licensing/provenance review authorizes code reuse.

### Niagara Launcher

Public references reviewed:

~~~
organization: NiagaraLauncher
public repository: NiagaraLauncher/Niagara-Issues
revision observed: da4e0162861dce409281170b1ebd676abaa761c3
official help/docs: help.niagaralauncher.app
review date: 2026-09-20
~~~

Niagara's product source is not published in the public organization; the public GitHub repository is an issue/release surface. Therefore Sable uses official behavior documentation and visible interaction patterns as design reference only.

Useful lessons:

- one-handed app access is a primary design constraint rather than an accessibility afterthought;
- an edge alphabet rail is faster than a conventional drawer for long app lists;
- favorites stay compact and prominent;
- horizontal app gestures can open contextual notifications/shortcuts without forcing a full-screen detour;
- top-of-home information such as time, date, calendar and media can appear contextually instead of living on a separate widget page;
- nested folder depth is intentionally avoided;
- gesture customization is deliberately bounded to preserve learnability;
- immediate app launch should not be delayed by gesture ambiguity.

Not adopted:

- persistent usage-driven app ranking by default;
- analytics-dependent suggestion behavior;
- network-backed app categorization;
- a visual copy of Niagara's typography, iconography or layout.

Official Niagara behavior references reviewed:

- https://help.niagaralauncher.app/article/171-alphabet-settings
- https://help.niagaralauncher.app/article/34-tips-and-tricks
- https://help.niagaralauncher.app/article/115-pop-ups
- https://help.niagaralauncher.app/article/41-adding-multiple-widgets
- https://help.niagaralauncher.app/article/77-missing-customization-features
- https://help.niagaralauncher.app/article/39-left-hand-mode

### Kvaesitso

~~~
repository: MM2-0/Kvaesitso
revision: 9835dcd48fcc00da56308603677a3f8aa29f0fb3
license: GPL-3.0 for the main launcher; selected SDK modules Apache-2.0
role: search-first launcher reference
~~~

Useful lessons:

- search is a primary launcher surface, not a secondary drawer feature;
- app launch, settings navigation and local information lookup benefit from one command/search entry point;
- a launcher can stay useful without forcing a conventional icon-grid mental model.

Sable boundary:

- no GPL implementation is copied into Apache/platform-owned Sable code;
- Sable search providers remain typed, local-first and permission-bounded.

### Lawnchair

~~~
repository: LawnchairLauncher/lawnchair
revision: 1c79ee5e7a4cc559b0c81dc7daf0ccf92b60d11c
default branch observed: 16-dev
role: Launcher3/Quickstep, recents and global-search architecture reference
~~~

Useful lessons:

- Launcher3/Quickstep is mature Android infrastructure for overview/recents and gesture integration;
- global search can coexist with Launcher3-derived system integration;
- launcher replacement should not casually discard Quickstep plumbing.

Sable decision:

- retain Quickstep for overview/gesture behavior during R9;
- do not expand R9 into a Recents rewrite;
- SableStart owns HOME presentation while Android/Quickstep continues to own the mature overview path until separately replaced and qualified.

### Olauncher CF

~~~
repository: OlauncherCF/OlauncherCF
revision: 5d2b007e86b55fada0e6d806ca147024de714970
license: GPL-3.0
role: minimal/privacy launcher reference
~~~

Useful lessons:

- a launcher benefits from a deliberately small gesture vocabulary;
- no-network launcher behavior is a strong privacy default;
- clock/date can be actionable without becoming a dashboard full of controls;
- customization should not overwhelm primary navigation.

Sable decision:

- SableStart itself should have no ambient network client;
- remote data enters only through explicit Sable/Android providers with visible privacy boundaries.

### OpenMiniLaunch / MinkLauncher

~~~
repository: katoaapps/openminilaunch
revision: 29c6b47f1990a1e2fe722d698b4742040ac4515d
license: Apache-2.0
role: keyboard-first launcher and command/search reference
~~~

This reference was already accepted in the Titan 2 keyboard-first work.

R9 carries the same semantic search model on Panther while preserving the stronger Titan requirement:

- printable key from HOME opens search immediately;
- first character is preserved;
- physical keyboard focus does not summon the software keyboard by default;
- keyboard navigation remains a first-class presentation profile rather than a patched touch UI.

## R9 Panther information architecture

### 1. Start root

The root surface should be readable in one glance and reachable with one thumb.

Conceptual order:

~~~
TIME / DATE
context line: next calendar item OR active media OR quiet local status

START
primary live/pinned tiles

FAVORITES
compact label-first launch rows or small tiles

search affordance
~~~

The top context line is conditional. Empty data does not create a blank card.

The root is not an infinite widget canvas.

### 2. Start tiles

Start is a vertically scrolling Sable tile surface rather than a four-tile
shortcut strip or an unrestricted widget canvas.

Default capability order:

~~~
Phone       Messages
Mail        Calendar
Weather     Photos
Media       Camera
Calculator  Files
~~~

The default resolver chooses the first installed app matching each capability
alias. Weather recognizes `Sable Weather` / `Weather` and becomes a normal
preferred Start tile once the production Weather app exists.

The default target is ten tiles. It is not a hard user limit.

Once the user customizes Start, the explicit Start-tile set is persisted
separately from Favorites. An explicit empty set means the user intentionally
wants no Start tiles. User-added Start tiles are not capped by the old
four-tile limit; the existing Start `LazyColumn` provides vertical scrolling.

Tile interaction:

- tap -> launch immediately;
- long press -> Sable Peek;
- Peek -> Pin to Start / Remove from Start;
- Start membership is independent of Favorites membership;
- later drag/reorder may refine ordering but is not required for R9.

Tile rules:

- useful live state only;
- no animation for animation's sake;
- redaction follows lock/privacy policy;
- no fake weather/feed data;
- no provider state without an explicit provider;
- color supplements state but does not replace text/state cues;
- no arbitrary Android widget canvas is introduced.

### 3. Favorites

Favorites are the fastest user-curated launch surface.

R9 target:

- Favorites are persisted independently from Start tiles;
- Pin to Favorites never implicitly pins to Start and vice versa;
- 4-8 user-selected favorites;
- label-first presentation;
- enough icon/mark identity for scanning without turning Start into a generic icon grid;
- no automatic persistent usage-based replacement;
- optional session-only recent suggestions may appear separately and must be visibly distinct from pinned favorites.

### 4. All Apps + Sable Rail

All Apps becomes a fast one-handed vertical list.

Required behavior:

- app label is primary;
- alphabetical grouping respects locale;
- right-edge alphabet rail;
- left-edge activation region for left-hand use without mirroring the entire list;
- dragging the rail gives immediate letter feedback;
- releasing lands at the group;
- exact alphabetical ordering is the privacy-preserving default;
- no usage-history sorting unless a future explicit opt-in design is separately reviewed.

Concept:

~~~
all apps                            A
                                    B
Calculator                          C
Calendar                            D
Camera                              E
                                    F
Files                               G
...
                                    Z
~~~

### 5. Sable Search / Command

Search is promoted from app-only filtering into a local Sable command surface.

R9 initial providers:

~~~
apps
Settings destinations
Sable first-party actions/routes
contacts/people when permission is granted
local media/documents only when user-authorized
~~~

Future providers may include conversations and Hub capabilities, but remote provider search is out of scope unless explicitly authorized.

Search rules:

- local-first;
- no network query from SableStart itself;
- permission-scoped results;
- provider identity visible when ambiguity matters;
- app search remains instant;
- keyboard and touch use the same semantic result model.

### 6. Sable Peek

A short horizontal swipe or deliberate secondary action on an app opens **Sable Peek**, a contextual layer rather than a full-screen app-details replacement.

Initial contents:

~~~
app name / icon
Open
Pin or Unpin
published app shortcuts
App Security & Privacy
Android App info
~~~

Optional later contents:

~~~
notification/conversation preview when explicitly authorized
small widget/live card
provider-specific quick action
~~~

Rules:

- one level only; no nested popup hierarchy;
- swipe/tap behavior must not delay ordinary app launch;
- sensitive notification content follows lock/redaction policy;
- privacy/security data routes to the authoritative Sable Settings surface rather than being duplicated in the launcher.

### 7. Contextual top card

Instead of a dedicated widget page, Start may show at most one primary contextual block above tiles.

Priority proposal:

~~~
active media
next calendar event
bounded local device status
nothing
~~~

The user may disable this block.

Weather remains visually identified as provider data. Production Live uses bounded app-owned
snapshot providers for Weather, Calendar, Messages, Mail and Media. SableLauncher reads
only those bounded snapshots and does not read the applications' sensitive databases directly. Photos remain local MediaStore data
behind explicit photo permission. Refresh is driven by provider changes and HOME lifecycle;
there is no ambient one-minute launcher polling loop. Message bodies and mail subjects are
not rendered on Home.

## Gesture contract

Panther baseline:

~~~
tap app/tile              -> launch immediately
long press                -> Sable Peek / edit affordance
swipe app right           -> Sable Peek when gesture threshold is crossed
swipe down on empty Start -> notification shade
swipe up on Start         -> All Apps
tap Search                -> Sable Search / Command
drag alphabet edge        -> fast alphabetical navigation
Home                      -> Start root
Back                      -> one semantic level
~~~

Avoid:

- two-finger launcher gestures;
- arbitrary user-remappable gesture matrices in the baseline;
- double-tap-on-app actions that delay normal app launch;
- nested popup/folder navigation.

## Privacy contract

~~~
SABLESTART_AMBIENT_NETWORK_CLIENT=NO
PERSISTENT_USAGE_RANKING_DEFAULT=NO
SESSION_RECENTS_ALLOWED=YES_MEMORY_ONLY
REMOTE_CONTEXT_PROVIDER=EXPLICIT_ONLY
NOTIFICATION_CONTENT=EXPLICIT_ACCESS_AND_REDACTION
PACKAGE_NAMES_IN_NORMAL_UI=NO
~~~

The existing StartStateRepository rule remains: launcher presentation state may persist; recent activity does not become a persistent usage-history database.

## Quickstep boundary

Quickstep remains installed in R9, but Launcher3 is no longer the user-facing
HOME implementation.

SableLauncher owns:

- the Android HOME activity and HOME role;
- Start;
- All Apps;
- Search/Command;
- Sable Peek;
- launcher appearance editing and local live context;
- touch and keyboard navigation inside HOME.

Launcher3QuickStep owns only the Android Recents/Overview integration,
TouchInteractionService and task-animation plumbing that Sable has not
separately replaced. Its `QuickstepLauncher` activity remains private for
upstream Quickstep bookkeeping and does not advertise HOME, ALL_APPS or other
launcher entry intents.

When another package is HOME, upstream Quickstep already provides the fallback
`RecentsActivity` path. R9 uses that supported separation rather than
rendering Sable as a full-screen layer over native Launcher3 workspace.

R9 must therefore prove:

```
HOME_RESOLVER=org.sableos.launcher/org.sableos.start.SableStartActivity
HOME_ROLE_HOLDER=org.sableos.launcher
LAUNCHER3_HOME_ROLE_ABSENT=PASS
LAUNCHER3_HOME_ELIGIBILITY_ABSENT=PASS
QUICKSTEP_SERVICE_PRESENT=PASS
QUICKSTEP_FALLBACK_RECENTS_PRESERVED=PASS
```

## Visual direction

SableStart should look recognizably Sable:

- larger Metro-derived typography than conventional Android launchers;
- flat or lightly rounded <=6dp geometry;
- Sable accent used for focus, selection and live state rather than decorative gradients everywhere;
- dark mode may use near-black/charcoal surfaces rather than pure black where hierarchy benefits;
- light mode uses restrained warm/cool neutral surfaces;
- app icons remain recognizable, but Start does not become an icon-grid clone;
- tiles may use app/provider artwork only where the content itself is visual, such as media/photos;
- motion remains in the 120/180/240ms Sable timing classes.

## Production visual acceptance for this R9 build

The earlier Mac production-source review gate is superseded for this build.
The approved Daily Driver frames remain the design reference, but the Mac AVD
is not required to authorize the image.

Required policy markers:

~~~
R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9
R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED
R9_FINAL_VISUAL_AUTHORITY=PHYSICAL_PANTHER
~~~

Production SableStart must still compile and lint through the Linux
source/design checks, build as the standalone `SableLauncher` module alongside
the recents-only `Launcher3QuickStep` substrate during module qualification,
and pass final physical Panther acceptance after flash.

A review harness may remain in the repository as non-product tooling, but it is
not executed by the R9 release-blocking Linux CI path.

## Runtime acceptance

A visual approval does not replace runtime qualification.

R9 physical acceptance must additionally prove:

~~~
HOME_RESOLVER=org.sableos.launcher/org.sableos.start.SableStartActivity
HOME_ROLE_HOLDER=org.sableos.launcher
LAUNCHER3_HOME_ROLE_ABSENT=PASS
LAUNCHER3_HOME_ELIGIBILITY_ABSENT=PASS
QUICKSTEP_SERVICE_PRESENT=PASS
LEGACY_SABLESTART_PACKAGE_ABSENT=PASS
COLD_HOME_LAUNCH_CRASHES=0
HOME_KEY_RETURNS_TO_START=PASS
QUICKSTEP_FALLBACK_RECENTS_PRESERVED=PASS
ALL_APPS_TOUCH_NAVIGATION=PASS
SEARCH_LOCAL_RESULTS=PASS
SABLE_PEEK=PASS
SABLE_SUBSURFACE_BACK_GESTURES=PASS
SABLE_ABORTED_SWIPE_NO_NATIVE_ESCAPE=PASS
SABLE_FALLBACK_RECENTS_GESTURE=PASS
SABLE_STATUS_SHADE_GESTURE_STABILITY=PASS
THEME_PROPAGATION=PASS
~~~

The R8 v4-signature incident and R8 HOME/startup incident remain prerequisite regression gates.

## Release slices

~~~
R9-L0  design/reference contract + visual-review build hold
R9-L1  Start root + one-hand geometry + favorites
R9-L2  All Apps + Sable Rail
R9-L3  Sable Search / Command
R9-L4  Sable Peek
R9-L5  provider-owned weather/calendar/messages/mail/media live block
R9-L6  Linux production-source compile/design qualification
R9-L7  Panther image integration + physical visual/HOME/Recents/runtime qualification
~~~

The slices may be implemented in parallel where source boundaries allow. For this build, successful R9-L6 Linux qualification authorizes the R9-L7 fresh Panther build; final visual acceptance occurs on the physical device.
