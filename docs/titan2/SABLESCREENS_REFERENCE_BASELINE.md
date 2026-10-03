# SableScreens reference baseline

Status: **accepted design/reference baseline; not a shipping runtime**
Date: **2026-10-02 ET / 2026-10-03 UTC**

The early aimindseye/titan2-temp/apps/titan2/screens work is substantial and
must remain an explicit input to current product work.

At the qualified product-source base, the catalog contains 23 traced Compose
surfaces, reference SVG/PNG artifacts, multiple documented states and shared
keyboard/focus/privacy/theme/device-profile primitives.

It is a design catalog, not an implementation of SystemUI, Settings, Telecom,
Keyguard or other privileged Android runtime owners.

## Baseline source

~~~
REPOSITORY=aimindseye/titan2-temp
P1_BASE_MAIN=dbbb96cc01a0e366ea56817b54028b5686cb4035
QUALIFIED_TREE=cf5c232be3bc79eec4bd30ee0a90ab9247852053
PATH=apps/titan2/screens
SCREEN_COUNT=23
~~~

D2 cleaned the maintained SableScreens Kotlin to Detekt/Ktlint zero findings,
and earlier D1b work fixed the known Compose compile issues. The catalog remains
prototype/reference source and is deliberately not one of the five E2 product
modules.

## 23-screen convergence map

| Screen | Current roadmap owner |
| --- | --- |
| Sable Start | P1 / E8A |
| All Apps | P1 / E8A |
| Sable Hub | E8A |
| Command Search | P1 / E8A |
| Phone / Dialer | E8B |
| Messages / Conversation | E8A/E8B |
| Contacts / People | E8B |
| Mail & Calendar | E8B |
| Browser / WebView | E8A |
| Camera / Capture | E2 base + E8C enhancement |
| Media & Gallery | E8B |
| Files & Documents | E8A |
| Utilities / Notes / Recorder | E8B |
| Toolbox | E8C |
| Settings | E8A |
| Quick Settings & Shade | E8A canonical SystemUI integration |
| Lockscreen / Secure Entry | E8A canonical Keyguard integration |
| Setup Wizard | P3 / E8A |
| Private Space / Dual Apps / Work | E8B |
| Mobile Manager / App Controls | E8B |
| Connectivity / OTG / NFC / Cast | E8C |
| App Display Compatibility | E2 base + E8C backend/enforcement |
| Sub-screen & Shortcut Keyboard | E8C |

## Shared behavior to preserve

The catalog established reusable behavior requirements:

~~~
deterministic visible keyboard focus
text fields own printable input
hover does not steal keyboard focus
privacy/redaction states
provider-safe actions
confirmation for destructive actions
latest/current content anchored where required
global theme propagation
capability-driven device profiles
no device-name branching
touch remains supported
~~~

P1-P5 and E8 implementations should reuse these semantics where applicable
rather than rediscovering them independently.

## Current assignment impact

P1 must use the existing Start, All Apps and Command Search catalog behavior as
a design/reference baseline while producing reusable source for
Launcher3-hosted Sable Start. The catalog itself remains non-shipping.

P2 has no dedicated SableScreens IME screen, but it must preserve the shared
input/focus rules and capability-driven device-profile model.

P3 must use the existing Setup Wizard visual/interaction states. Lockscreen and
Settings catalog states are supporting references for critical text-entry and
first-boot navigation.

Weather was not one of the 23 SableScreens surfaces. P4 is additive product
work and therefore needs its own keyboard-first Weather UX/visual contract.

The original catalog did not contain a dedicated Sable Reader product surface.
It contained Reader-like states inside Files/Documents and Browser/WebView only.

P5 therefore extends the design baseline with a dedicated Reader v2 visual
contract covering:

~~~
unified library
EPUB/PDF reader
comic paged mode
comic RTL/manga mode
continuous/webtoon mode
audiobook player
collections/search
bookmarks/highlights/progress
keyboard help/command surface
~~~

The existing Files/Browser Reader states remain reference input rather than the
complete P5 product design.

## Runtime boundary

Never promote a SableScreens mock to runtime completion merely because it looks
correct.

Examples:

~~~
SableScreens Lockscreen != Keyguard implementation
SableScreens Quick Settings != SystemUI implementation
SableScreens Settings != Settings runtime integration
SableScreens Phone != Telecom/Telephony integration
SableScreens Setup Wizard != GrapheneOS SetupWizard2 integration
SableScreens App Display Compatibility != enforcement backend
~~~

The catalog is a design/behavior oracle. Production code must live in the
canonical owner for each surface and pass its own build/runtime/security gates.
