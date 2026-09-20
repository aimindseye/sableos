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
R9_L9_VISUAL_REVIEW_HARNESS=SOURCE_READY
R9_SABLESTART_VISUAL_REVIEW_SET=PENDING_MAC_MINI_CAPTURE
R9_L6_VISUAL_REVIEW_STATUS=PENDING
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
~~~
