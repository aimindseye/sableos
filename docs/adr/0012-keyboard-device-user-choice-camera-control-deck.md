# ADR-0012: Keyboard-device user choice and Camera Control Deck

Status: **accepted**

Date: 2026-10-02

## Context

Keyboard-first SableOS now has:

- Launcher3/Quickstep-hosted Sable Start as the canonical first-party HOME;
- a Sable-owned keyboard source candidate designed for Titan-class hardware;
- a Sable-owned Camera2 camera source candidate for keyboard devices;
- a reviewed Pastiera 0.86 physical-keyboard reference;
- a product requirement to preserve Android user choice rather than turn SableOS
  into a locked appliance.

The design review also considered a keyboard-device camera concept where the
display is primarily a viewfinder and the physical keyboard becomes the camera
control surface.

## Decision 1 — first-party ownership does not remove user choice

Sable distinguishes:

~~~text
first-party/canonical owner
!=
user-selected current default
~~~

### HOME

~~~text
SABLE_FIRST_PARTY_HOME_OWNER=Launcher3QuickStep
SABLE_FACTORY_DEFAULT_HOME=SableStart
THIRD_PARTY_HOME_INSTALL_ALLOWED=YES
THIRD_PARTY_HOME_SELECTION_ALLOWED=YES
FORCE_SABLE_HOME_AFTER_USER_SELECTION=NO
SABLE_START_REMAINS_INSTALLED=YES
~~~

Launcher3/Quickstep remains the Sable-supported implementation for:

- Sable Start;
- Quickstep/Recents integration;
- gesture/transition integration;
- Sable keyboard-first type-to-find;
- full Sable private-profile/Private Space behavior.

A third-party launcher may be selected through Android's normal HOME/default
role model. SableOS does not grant arbitrary third-party launchers privileged
Quickstep/SystemUI integration.

On Android versions with Private Space/hidden profiles, a third-party HOME may
provide reduced integration if it does not implement Android's launcher
requirements for those profiles. SableOS must not weaken Private Space to make
an incompatible launcher appear equivalent to Sable Start.

Reference:
https://developer.android.com/about/versions/15/behavior-changes-all

### IME

~~~text
SABLE_FIRST_PARTY_IME=SableKeyboard
SABLE_FACTORY_DEFAULT_IME=SableKeyboard
THIRD_PARTY_IME_INSTALL_ALLOWED=YES
THIRD_PARTY_IME_ENABLE_ALLOWED=YES
THIRD_PARTY_IME_SELECT_ALLOWED=YES
FORCE_SABLE_IME_AFTER_USER_SELECTION=NO
SABLE_KEYBOARD_REMAINS_INSTALLED=YES
~~~

Sable Keyboard remains the first-party path for:

- direct-boot/critical-entry qualification;
- Titan physical-keyboard semantics;
- Sable-tested Alt/Sym/Nav behavior;
- product fallback/recovery.

Android's extensible input-method framework remains available to user-installed
IMEs. Sable Settings may explain the trust implications of enabling an IME, but
Sable product policy does not block the user's selection.

Reference:
https://developer.android.com/develop/ui/views/touch-and-input/creating-input-method

A third-party IME is not automatically covered by Sable's lockscreen,
pre-unlock or physical-keyboard runtime acceptance.

## Decision 2 — Sable Camera Control Deck

For keyboard-first devices, Sable Camera is designed around this principle:

> **The screen is the viewfinder. The physical keyboard is the camera control
> surface.**

This is an interaction decision, not a new HAL or capture-mode architecture.

### Orientation

~~~text
PORTRAIT_SUPPORTED=YES
LANDSCAPE_CONTROL_DECK=YES
GLOBAL_LANDSCAPE_LOCK=NO
DEFAULT_ORIENTATION_POLICY=AUTO
~~~

Portrait remains a minimal conventional camera UI.

Landscape should optimize for the physical keyboard on the control side of the
device, with maximum viewfinder area and minimal permanent touch chrome.

### Control semantics

Initial semantic actions include:

~~~text
shutter
autofocus
autofocus lock
auto-exposure lock
focus-point movement
ISO
white balance
shutter speed
exposure compensation
zoom
camera switch
RAW / RAW+JPEG candidate
same-scene compare bracket
mode navigation
last capture
return parameter to Auto
~~~

The application should map physical keys to semantic camera actions rather than
spreading raw key codes through capture logic.

Touch must remain a complete fallback.

### UI behavior

Manual controls should use transient parameter strips rather than permanent
virtual DSLR dials.

A keyboard/touch-accessible control legend is required for discoverability.

The first production version should use a strong Sable default key map rather
than a large arbitrary per-key configuration system.

## Decision 3 — Pastiera 0.86 reference boundary

Reviewed checkpoint:

~~~text
repository=https://github.com/palsoftware/pastiera
release=v0.86
commit=e7d8f27ecc7253e61690b5d34f110b25dc68bb16
license=GPL-3.0
release_date=2026-09-26
successor=https://github.com/pkb-rocks/plektra
~~~

Pastiera 0.86 is used as a behavior/product reference only.

~~~text
PASTIERA_SOURCE_IMPORTED=NO
PLEKTRA_SOURCE_IMPORTED=NO
GPL_SOURCE_COPIED_INTO_SABLE_KEYBOARD=NO
~~~

Accepted future Sable concepts:

- compact candidate/modifier/language strip while the full soft keyboard is
  hidden;
- configurable SYM/emoji surfaces;
- local snippets and shortcodes;
- bundled/provenanced emoji search data;
- multiple local dictionaries;
- optional local learned next-word behavior after privacy review;
- searchable Settings and stable deep links;
- Titan 2 Elite rounded-display/inset test cases.

Ownership rules:

- keyboard-driven app launch remains Sable Start/HOME functionality;
- global/power shortcuts remain platform/Sable Start functionality;
- the IME does not become a second launcher or global command daemon.

Not adopted:

- Shizuku as an input dependency;
- persistent keyboard clipboard history enabled by default;
- automatic unverified remote dictionary/layout channels;
- arbitrary full key remapping as a first-release requirement.

## Roadmap placement

These decisions add non-blocking post-foundation work:

~~~text
D2        Kotlin quality + dependency verification
D3        critical text-entry hardening
D5        first-party icon integration

D6A       compact input strip
D6B       configurable SYM / emoji / snippets
D6C       local dictionary/prediction improvements

CAM-D6A   Camera Control Deck source architecture
CAM-D6B   focus-point / AF lock / AE lock
CAM-D6C   portrait/landscape/inset polish
CAM-PHY   physical camera-control qualification
~~~

D6 work must not delay C3B engineering image bring-up, D2/D3/D5 closure,
telephony/runtime work or production-security gates.

## Consequences

Positive:

- Sable retains deep first-party integration without denying Android user
  choice;
- Sable Keyboard can learn from mature physical-keyboard products without
  importing GPL implementation;
- Sable Camera becomes intentionally keyboard-device-native rather than a
  generic camera with shortcuts;
- touch remains available across first-party surfaces.

Trade-offs:

- third-party launchers may not match Sable Start's Quickstep/Private Space
  integration;
- third-party IMEs may not meet Sable's critical-entry guarantees;
- Camera Control Deck adds runtime/device validation work;
- compact input and advanced dictionary features become additional future
  product scope and therefore remain explicitly non-blocking.
