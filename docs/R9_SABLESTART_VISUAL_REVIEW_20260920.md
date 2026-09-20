# R9 SableStart combined L1-L6 visual review

Status: **R9L9 source + Pixel 7 review harness implemented / visual acceptance pending**

Date: 2026-09-20

PR: #71

This review sheet is derived from the production SableStart source in:

~~~text
src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt
~~~

It is not a retired preview APK and does not authorize a full Panther build.

## Frame 01 — Start / dark

Production composition:

~~~text
TIME                            Sable Blue
DATE

[ truthful local context, only when available ]
  calendar
  9:30 AM · Design review

start
┌──────────────────┐ ┌──────────────────┐
│ [real icon]      │ │ [real icon]      │
│ Sable Mail       │ │ Phone            │
└──────────────────┘ └──────────────────┘
┌──────────────────┐ ┌──────────────────┐
│ [real icon]      │ │ ⚙                │
│ Calendar         │ │ Settings         │
└──────────────────┘ └──────────────────┘

favorites
[icon] Calculator                            ⋯
[icon] Reader                                ⋯
[icon] Media                                 ⋯

⌕  Search / Command
   apps · settings · Sable actions

all apps  →
local context  →
~~~

Review intent:

- Metro-derived typography and tiles remain;
- the oversized R8 hero is gone;
- useful controls are lower on the display;
- Favorites are user-owned rather than usage-ranked;
- context disappears when there is no truthful local datum.

## Frame 02 — Start / light

Same production hierarchy as Frame 01 using the shared Sable light semantic colors.

Required review points:

- accent remains orientation/state rather than decorative fill everywhere;
- text contrast remains readable;
- context and Favorites remain visually subordinate to the primary Start tiles;
- no dark-only hard-coded launcher palette.

## Frame 03 — All Apps + Sable Rail

Production composition:

~~~text
‹  all apps

⌕  Search / Command

A                                  A
Apps                               B
                                   C
C                                  D
Calculator                         E
Calendar                           F
Camera                             G
                                   H
F                                  ...
Files                              Z
~~~

The right-edge rail:

- is built from actual locale-aware app sections;
- supports direct letter taps;
- supports continuous drag scrubbing;
- scrolls the production LazyColumn directly;
- does not reorder apps by persistent usage.

The main list remains label-first and left aligned.

## Frame 04 — Search / Command

Production composition:

~~~text
‹  search

[ Search apps and Sable actions                ]

quick actions / commands

[A] All apps
    Alphabetical launcher list

[◐] Appearance
    Theme and Sable accent

[◫] Local context
    Calendar, photos and local media state

[⚙] System Settings
    Open Android settings

apps
[M] Sable Mail                               ›
[M] Sable Media                              ›
...
~~~

The first R9 implementation is intentionally local.

No network search provider is present in SableStart.

## Frame 05 — Sable Peek

Production composition:

~~~text
Close


┌────────────────────────────────────────────┐
│ [M]  Sable Mail                            │
│      Sable Peek                            │
│                                            │
│              [ Open ]                      │
│                                            │
│ +   Pin to Favorites                       │
│ ⓘ   Permissions & app info                 │
│                                            │
│ Published shortcuts / notification content │
│ remain hidden until their Android and      │
│ privacy gates are wired.                   │
└────────────────────────────────────────────┘
~~~

This is a single contextual level, not a folder tree.

## Frame 06 — Local media context

The current production data provider does not have authority for active Android media-session controls.

Therefore R9 does **not** manufacture a fake now-playing card.

When authorized local audio exists and no live calendar event takes precedence, Start may truthfully show:

~~~text
music
247 tracks
~~~

Active playback/artwork remains a later capability requiring a separately reviewed Android media-session boundary.

## Frame 07 — Calendar context

With READ_CALENDAR granted, the production repository queries remaining events today and exposes the first event's actual title/time:

~~~text
calendar
9:30 AM · Design review
~~~

If no event remains:

~~~text
nothing else today
~~~

No synthetic event title is shown.

## Frame 08 — accessibility / focus

Source requirements carried into the production layout:

- primary touch rows >=48dp;
- Favorites rows >=54dp;
- app rows >=58dp;
- headings use semantics;
- text uses Material typography rather than fixed raster assets;
- accent is not the only selected-state cue;
- keyboard-visible-focus work remains required for the Titan interaction profile.

## External design checks retained

The combined source continues the reviewed reference decisions:

- Niagara: fast alphabet access, left/right edge reach philosophy, simple contextual pop-ups and bounded gestures;
- Kvaesitso: search as a primary launcher surface;
- Olauncher: restraint and no ambient launcher network behavior;
- OpenMiniLaunch/MinkLauncher: keyboard-first search semantics for Titan;
- Lawnchair/Launcher3: keep mature Quickstep/Overview plumbing rather than expanding R9 into a Recents rewrite.

These are behavioral references only. No external launcher code is copied.

## L6 acceptance

The textual/source review is not sufficient to reopen the build.

Required before changing the build authorization:

~~~text
R9_SABLESTART_PRODUCTION_COMPILE=PASS
R9_SABLESTART_VISUAL_REVIEW_SET=PASS
R9_SABLESTART_PRODUCT_IDENTITY=APPROVED
R9_SABLESTART_ONE_HAND_REACH=PASS
R9_SABLESTART_ALL_APPS_RAIL=PASS
R9_SABLESTART_SEARCH_COMMAND=PASS
R9_SABLESTART_PEEK=PASS
R9_SABLESTART_LIGHT_DARK=PASS
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES
~~~

Current state remains:

~~~text
R9_L6_VISUAL_REVIEW_STATUS=PENDING
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
~~~


## R9L9 emulator execution gate

The production visual set is now executed through the established Mac mini +
Pixel 7 AVD workflow documented in:

~~~text
docs/R9_LAUNCHER_VISUAL_VALIDATION_MAC_MINI.md
~~~

The non-product `sablestart-visual-review` APK depends on the production
presentation compilation unit. It has no HOME intent and is absent from Panther
product composition.

Production app rows and Start tiles now attempt to render each launcher's real
Android activity icon through `LauncherApps`, with the existing Sable initial
mark as a failure-safe fallback. Launcher3 remains authoritative for the
product app inventory, update stream, launch path, details path and Quickstep
lifecycle.

Current gate:

~~~text
R9_L9_VISUAL_REVIEW_HARNESS=RUNTIME_READY
R9_SABLESTART_VISUAL_REVIEW_SET=PENDING_USER_REVIEW
R9_L6_VISUAL_REVIEW_STATUS=PENDING
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO

Runtime evidence at 2bcdc6699a705a965dc0a4a89c98314cdaaa1162:

```text
R9_VISUAL_REVIEW_APK_BUILD=PASS
R9_VISUAL_REVIEW_PIXEL7_AVD=PASS
R9_VISUAL_REVIEW_INSTALL=PASS
R9_VISUAL_REVIEW_INITIAL_CAPTURE=PASS
```

~~~

## R9L10 initial-frame review

The first Pixel 7 runtime frame at commit
`2bcdc6699a705a965dc0a4a89c98314cdaaa1162` proved the review path, but the
Start presentation is not accepted as final product identity.

Observed issues from `00-start-initial.png`:

- the 2x2 Start tile block is visually too tall for the amount of information;
- Favorites repeats apps already promoted into Start tiles;
- the standalone accent-name button reads as floating chrome rather than part
  of the Metro hierarchy;
- Search / Command reads like a generic Material card instead of a Sable
  command surface;
- the two navigation links consume too much vertical space;
- the review host app appears in the fixture inventory and pollutes the product
  review.

R9L10 responds by:

- shrinking Start tiles from 118dp to 96dp and app marks from 44dp to 34dp;
- removing primary-tile apps from the Start Favorites subset;
- replacing the floating accent-name button with a compact accent-swatch
  appearance affordance;
- changing Search / Command to a flat Metro-style accent rule and typographic
  command row;
- putting All Apps and Local Context into one compact navigation row;
- limiting Start Favorites to four entries;
- filtering the non-product visual-review host from the emulator inventory.

The review must now be re-captured from the R9L10 source before visual
acceptance.

```text
R9_L10_START_REFINEMENT=SOURCE_READY
R9_SABLESTART_VISUAL_REVIEW_SET=RECAPTURE_REQUIRED
R9_SABLESTART_PRODUCT_IDENTITY=PENDING_USER_REVIEW
R9_L6_VISUAL_REVIEW_STATUS=PENDING
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L10 second-frame review

The second Pixel 7 Start frame confirms the R9L10 hierarchy improvements:
real icons, compact Metro tiles, flatter Search / Command treatment, and the
combined lower navigation row all render as intended.

Two remaining Start-specific defects were visible:

- Settings was still repeated in Favorites because it is a dedicated system
  tile rather than part of the primary-app key set.
- an odd three-tile inventory left an empty lower-right quadrant.

The follow-up source now:

- excludes Settings from the Start Favorites/recent subset;
- omits the Favorites section entirely when no non-primary quick apps remain;
- lets a final odd tile span the full row, matching the wide-tile Metro
  vocabulary instead of leaving a visual hole.

```text
R9_L10_SECOND_FRAME_REVIEW=PASS_WITH_SOURCE_POLISH
R9_L10_START_REFINEMENT=SOURCE_READY
R9_SABLESTART_VISUAL_REVIEW_SET=START_RECAPTURE_REQUIRED
R9_SABLESTART_PRODUCT_IDENTITY=PENDING_USER_REVIEW
R9_L6_VISUAL_REVIEW_STATUS=PENDING
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L10 third-frame Start acceptance

The third Pixel 7 Start frame is accepted as the R9 Start presentation baseline.

Accepted characteristics:

- clock/date hierarchy is clear and intentionally dominant;
- appearance is a compact secondary affordance rather than competing chrome;
- real launcher icons render correctly;
- two compact square tiles plus one full-width Settings tile form a deliberate
  Metro composition when launcher inventory is sparse;
- no Start/Favorites duplication remains;
- empty Favorites is omitted instead of showing placeholder copy;
- Search + Command is visually distinct without reverting to a generic
  Material card;
- All Apps and Local Context share one compact lower navigation row;
- the non-product visual-review host is absent from launcher fixture inventory.

```text
R9_L10_START_VISUAL_REVIEW=PASS
R9_L10_START_PRODUCT_IDENTITY=APPROVED
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_REMAINING_SURFACES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```

Remaining required surfaces are All Apps / Sable Rail, Search / Command,
Sable Peek, Local Context, Appearance, and light/dark theme behavior.


## R9L10 All Apps / Sable Rail acceptance

Pixel 7 captures `03-all-apps-top.png` and `04-all-apps-rail.png` are
accepted for the current R9 visual gate.

Accepted characteristics:

- All Apps preserves the same typography and accent vocabulary as Start;
- Search + Command remains immediately reachable at the top;
- real launcher icons remain legible without crowding labels;
- alphabetical section headers are visually distinct from app rows;
- the right-side Sable Rail is visible without dominating the list;
- rail interaction provides active-letter feedback: the captured state changes
  from P to T.

Fixture limitation:

The Pixel 7 review AVD currently exposes only three launcher-visible apps
(Play Store, Settings, and TMobile) after filtering the review host. All three
fit on one screen, so these captures cannot prove long-list scroll anchoring or
long-label collision behavior. That remains a later full-inventory/runtime
check; this does not block the current visual-design gate.

```text
R9_L10_ALL_APPS_VISUAL_REVIEW=PASS
R9_L10_SABLE_RAIL_ACTIVE_STATE=PASS
R9_L10_SABLE_RAIL_LONG_LIST_PROOF=PENDING_FULL_INVENTORY
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_ALL_APPS_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_REMAINING_SURFACES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L11 Search review

The first Search captures prove the behavior model:

- empty query shows quick actions plus local app results;
- query `set` correctly separates the Sable/System command
  `System Settings` from the actual launcher app result `Settings`;
- no web/cloud search affordance is present;
- real app icons remain consistent with Start and All Apps.

Visual refinement is still required before Search acceptance. The captured
outlined Material text field and rounded gray quick-action icon tiles do not
match the flatter Sable/Metro language already approved on Start and All Apps.

R9L11 source changes:

- replaces the Material outlined field with a flat `BasicTextField`;
- uses the Sable accent rule plus a single bottom hairline for search identity;
- uses the placeholder `search apps + Sable actions`;
- removes rounded gray command-icon surfaces;
- renders command glyphs directly in the Sable accent while preserving
  separate `commands` and `apps` sections.

```text
R9_L11_SEARCH_BEHAVIOR=PASS
R9_L11_SEARCH_VISUAL_REVIEW=RECAPTURE_REQUIRED
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_ALL_APPS_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_REMAINING_SURFACES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L11 Search acceptance

The recaptured Pixel 7 Search frames are accepted.

Accepted characteristics:

- the flat accent-rule field matches the Start Search + Command language;
- empty-query placeholder is clear without Material outlined-field chrome;
- quick actions use direct accent glyphs rather than rounded gray icon tiles;
- command titles/subtitles retain a clear hierarchy;
- query `set` keeps `System Settings` under commands and the actual
  `Settings` launcher activity under apps;
- real app icons remain consistent with Start and All Apps;
- no web/cloud search affordance is implied.

```text
R9_L11_SEARCH_BEHAVIOR=PASS
R9_L11_SEARCH_VISUAL_REVIEW=PASS
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_ALL_APPS_SEARCH_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_REMAINING_SURFACES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L12 Sable Peek review

The first Pixel 7 Peek capture proves the contextual behavior and action set,
but the visual treatment is not accepted.

Behavior confirmed:

- app identity is clear;
- Open is primary;
- pin/unpin state is exposed;
- Permissions & app info is directly reachable;
- no nested menu is introduced.

Visual issues in the first capture:

- the rounded gray bottom sheet reads as generic Material UI;
- the oversized blue button is visually heavier than the accepted Start/Search
  language;
- the large blank upper area makes the layer feel detached from the product;
- the long capability note competes too much with the actions.

R9L12 source changes:

- removes the rounded Material-style sheet surface;
- uses a flat bottom contextual layer with a Sable accent rule;
- replaces the Button with a flat Metro-style primary action strip;
- simplifies the close affordance;
- reduces the capability/privacy note to subordinate body-small text;
- keeps the same Open, pin/unpin, and permissions actions.

```text
R9_L12_PEEK_BEHAVIOR=PASS
R9_L12_PEEK_VISUAL_REVIEW=RECAPTURE_REQUIRED
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_ALL_APPS_SEARCH_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_REMAINING_SURFACES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L12 Sable Peek acceptance

The recaptured Pixel 7 Peek frame is accepted.

Accepted characteristics:

- the contextual layer is flat and visually consistent with Start/Search;
- the Sable accent rule establishes identity without a rounded sheet container;
- app icon and app name dominate the identity hierarchy;
- `open` is clearly the primary action;
- pin/unpin and permissions remain secondary but directly reachable;
- the privacy/capability note is subordinate and no longer competes with actions;
- the single contextual level is preserved with no nested menu.

```text
R9_L12_PEEK_BEHAVIOR=PASS
R9_L12_PEEK_VISUAL_REVIEW=PASS
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_ALL_APPS_SEARCH_PEEK_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_REMAINING_SURFACES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L13 Local Context review

The first Pixel 7 Local Context capture proves the permission/state model, but
the visual treatment is not accepted.

Behavior confirmed:

- Calendar, Music, and Photos clearly report `permission required`;
- the permission CTA is explicit and local-data scoped;
- Weather and Tasks remain unavailable without configured providers;
- no ambient network search or fabricated remote context is implied.

Visual issues in the first capture:

- rounded gray cards repeat a generic Material card vocabulary;
- the large blue permission button is heavier than the accepted Sable action
  treatment;
- the two explanatory paragraphs are too verbose for a launcher surface.

R9L13 source changes:

- replaces rounded live-data cards with flat typographic rows and hairlines;
- uses direct Sable-accent marks for Calendar, Music, and Photos;
- replaces the Material Button with a flat `enable local data` action strip;
- condenses provider/network truth into:
  `weather + tasks · provider not configured` and
  `local only · no ambient network search`.

```text
R9_L13_LOCAL_CONTEXT_BEHAVIOR=PASS
R9_L13_LOCAL_CONTEXT_VISUAL_REVIEW=RECAPTURE_REQUIRED
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_ALL_APPS_SEARCH_PEEK_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_REMAINING_SURFACES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```


## R9L13 Local Context acceptance

The recaptured Pixel 7 Local Context permission-required frame is accepted.

Accepted characteristics:

- Calendar, Music, and Photos use flat rows with direct Sable accent marks;
- permission-required state is prominent without resembling a permission/settings screen;
- the `enable local data` strip is clearly the primary action;
- provider absence is stated explicitly;
- `local only · no ambient network search` keeps the privacy boundary concise;
- no remote/fabricated context is implied.

```text
R9_L13_LOCAL_CONTEXT_BEHAVIOR=PASS
R9_L13_LOCAL_CONTEXT_VISUAL_REVIEW=PASS
R9_SABLESTART_VISUAL_REVIEW_SET=PARTIAL_START_ALL_APPS_SEARCH_PEEK_CONTEXT_PASS
R9_L6_VISUAL_REVIEW_STATUS=PENDING_APPEARANCE_THEME
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```

