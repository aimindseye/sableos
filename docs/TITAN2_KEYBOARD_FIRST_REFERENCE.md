# Titan 2 keyboard-first reference review

Status: **accepted design/reference input; no external implementation is automatically imported**

Date: 2026-09-19

Titan 2 is a keyboard-first SableOS target.

The physical QWERTY keyboard is a primary OS input device, not an accessory layered over a touch-first phone UI.

Canonical interaction capability target:

```text
input.has_physical_keyboard = true
navigation.primary = keyboard
navigation.secondary = touch
type_to_search = true
focus.visible = true
focus.directional = true
modifier_shortcuts = true
key_repeat = true
touch_required_for_core_navigation = false
```

The same Sable semantic application model remains shared with Panther. Titan 2 changes interaction/layout presentation, not application meaning or service authority.

## Reviewed external references

The following exact source revisions were reviewed on 2026-09-19.

### Pastiera

```text
repository: palsoftware/pastiera
release: v0.86
revision: e7d8f27ecc7253e61690b5d34f110b25dc68bb16
release date: 2026-09-26
license: GPL-3.0
successor: pkb-rocks/plektra
role: physical-keyboard IME / input-routing / compact-input product reference
```

Observed useful concepts:

- explicitly profiled for physical-keyboard Android devices including Titan 2;
- dedicated physical-keyboard `InputMethodService`;
- separated input routing from modifier state;
- configurable Ctrl/Alt/Shift/SYM behavior;
- held, one-shot and latch semantics;
- configurable navigation mode;
- launcher shortcuts and global/power-style shortcuts;
- JSON keyboard layouts and device-specific mapping data;
- compact status/variation UI which minimizes screen use;
- device-near modifier/input regression tests;
- launcher shortcut handling separated from ordinary text-entry behavior;
- compact candidate/modifier/language status surfaces;
- configurable SYM/emoji surfaces and snippets/shortcodes;
- multiple dictionaries and local learned next-word sequences;
- searchable settings with stable direct links;
- improved Titan 2 Elite rounded-display fitting.

Sable lessons:

- modifier state belongs in an explicit state machine rather than ad-hoc per-screen logic;
- text-entry routing, navigation routing and launcher shortcut routing should be distinct;
- key mappings should be data-driven and capability/device-profile bound;
- shortcut handling must not accidentally steal text from an editable field;
- held modifier behavior and latched navigation behavior are separate states and should stay separate;
- input behavior requires automated regression tests, especially for modifier/key-up/key-repeat sequences;
- compact input surfaces are useful, but app launching/global shortcuts remain Sable Start/platform responsibilities rather than IME ownership;
- persistent keyboard clipboard history should not be enabled by default;
- Shizuku must not become a Sable input dependency;
- remote layout/dictionary catalogs require provenance, signing/hash validation and explicit user action if ever introduced.

Pastiera is GPL-3.0. Treat implementation as a behavioral/architectural reference unless a separate licensing review authorizes reuse. No Pastiera/Plektra source import is authorized by this review.

### MinkLauncher / OpenMiniLaunch

```text
repository: katoaapps/openminilaunch
revision: 29c6b47f1990a1e2fe722d698b4742040ac4515d
license: Apache-2.0
role: keyboard-first launcher / type-to-search reference
```

Observed useful concepts:

- explicitly describes itself as a keyboard-first Android launcher;
- printable key from Home immediately enters the launcher search/command surface;
- the first typed character is preserved rather than lost during focus transition;
- Compose text input uses `showKeyboardOnFocus = false` for physical-keyboard flow;
- hardware key-up is observed through Compose key handling;
- dedicated correction logic handles the race between an initial Home key and physical-keyboard IME long-press replacement;
- separate QWERTY-aware Home layout behavior;
- installed-app search is integrated into a keyboard-first command/search surface;
- touch remains available without being required for primary launcher operation.

Sable lessons:

- Titan SableStart should be immediately typeable from HOME;
- no tap should be required before searching/launching;
- opening type-to-search must preserve the triggering character;
- focusing a hardware-keyboard search field should not summon the soft keyboard by default;
- HOME should have a dedicated keyboard layout/focus model rather than merely adding focus rings to the Panther touch layout;
- search/command entry should be a first-class launcher surface.

OpenMiniLaunch is Apache-2.0. It remains a reference by default; any direct reuse still requires provenance/attribution review.

### Commander

```text
repository: astroboii47/Commander
reviewed state: current September 2026 main/release line
role: keyboard-first command palette / notification Hub reference
```

Observed useful concepts:

- fast keyboard-first overlay/search across apps, settings, contacts and actions;
- recent-app filtering and keyboard navigation;
- notification grouping, filtering, dismiss/open and source-authorized inline reply;
- explicit acknowledgment that third-party messaging capability depends on
  Android intents, shortcuts, notifications and RemoteInput exposed by the
  source app;
- optional notification history rather than assuming unrestricted access.

Sable lessons:

- command/search and notification triage should be first-class keyboard
  surfaces;
- third-party reply must remain source-app-authorized;
- Sable should implement system-owned behavior through platform surfaces rather
  than reproducing Accessibility/overlay workarounds required by an ordinary
  app.

### TypeQ25

```text
repository: sriharshaKanukuntla/TypeQ25
revision: 5a9025a8885f816be41b64fb9eba2caca9b0f398
license: GPL-3.0
role: physical-keyboard IME / Q25+Titan mapping reference
```

Observed useful concepts:

- physical-keyboard `InputMethodService`;
- input-event router and dedicated modifier/nav-mode helpers;
- launcher shortcuts and global power shortcuts;
- double-Ctrl navigation mode;
- ESDF/IJKL directional navigation;
- D-pad/UI navigation;
- layout switching and customizable mapping data;
- explicit Titan 2 Alt map:
  - Q/W/E/R -> 0/1/2/3
  - S/D/F -> 4/5/6
  - X/C/V -> 7/8/9
  - additional punctuation/operators mapped through Alt;
- auto-focus patterns intended to make apps immediately typeable.

Sable lessons:

- Titan 2 needs a sealed physical-key mapping baseline before changing input behavior;
- Alt/SYM mappings should be represented as versioned data rather than scattered code constants;
- navigation-mode mappings should be customizable behind stable semantic actions;
- device mapping is an adapter beneath common keyboard-first semantics.

TypeQ25 is GPL-3.0. Treat it as behavioral/mapping reference unless separately reviewed for licensing.

### Q25 Toolbox

```text
repository: nozerorma/q25toolbox
revision: bdddabf8c93cc1c7b5537e2f4874cc479550bd4a
license: no repository license detected
role: Q25 hardware/keylayout/device-behavior forensic reference
```

Observed useful concepts:

- verifies the effective hardware keylayout rather than assuming `Generic.kl`;
- recognizes that keylayout may live under `/system/usr/keylayout` or `/vendor/usr/keylayout`;
- preserves the correct SELinux file label when replacing a keylayout;
- documents physical scancodes and keycode consequences;
- accessibility-based auto-focus on first printable key;
- lockscreen PIN keyboard support;
- per-app raw keyboard passthrough;
- chat Enter-to-send and calculator keyboard adaptations;
- IME suggestion shortcuts;
- in-call physical keyboard shortcuts;
- explicit recovery behavior for a stuck keyboard driver.

Important Sable boundary:

Q25 Toolbox is a rooted utility built around KernelSU, bind mounts, service.d scripts, Accessibility interception, driver unbind/rebind and other device-specific mechanisms. Those mechanisms are **not** the SableOS production architecture.

For SableOS:

- use platform keylayout/device configuration when integration ownership exists;
- use SystemUI/Phone/Launcher source integration for their keyboard behavior;
- use a normal Sable IME/input layer for text/modifier behavior;
- avoid root shell, accessibility injection or runtime bind-mount hacks for functionality SableOS owns at build/platform level;
- do not copy q25toolbox implementation because no repository license was detected;
- retain its empirical lessons about effective keylayout discovery, scancodes, SELinux labels, firmware quirks and failure modes.

### TrebleDroid / RestlessOS

```text
repository: cawilliamson/treble_restlessos
reviewed revision: 268490dc4150cd1686a9ec1afb5ea32be4acab83
role: non-Pixel / Treble / vendor-compatibility reference
```

Useful Titan-family evidence includes:

- Unihertz MediaTek keylayout replacement logic and dedicated PTT/capacitive
  navigation key maps;
- Unihertz/Agold camera compatibility work;
- fingerprint/vendor-policy examples;
- explicit documentation of GrapheneOS-derived hardening features that may fail
  on arbitrary vendor kernels/partitions.

Sable boundary:

- use RestlessOS/TrebleDroid to identify and reproduce compatibility failures;
- never import a blanket hardening relaxation merely because it broadens GSI
  boot compatibility;
- bind every accepted delta to a Titan device/firmware profile, security impact,
  runtime test and removal condition;
- GrapheneOS/AOSP security architecture remains the reference baseline.

### BB10 Tools / Sable Tools reference

A second keyboard-device reference is now pinned for power-user/device-tooling ideas:

~~~text
repository: bb10root/bb10tools
revision: 68d2e42a471b46b53ff5567edac4293ef0f3d5d6
license: GPL-3.0
role: BB10/QNX engineering and device-tooling reference
~~~

Use it as a capability/reference inventory for a future common Sable Tools app on Titan 2 and Q27. Useful inspiration includes structured device/radio inspection, keyboard/input diagnostics, file/report workflows, storage/device inspection and compact service tooling.

Do **not** port its BB10-specific kernel patching, memory writes, NVRAM mutation, trust/security bypass or unauthenticated service mechanisms into production SableOS.

The normative Sable interpretation is in KEYBOARD_FIRST_SABLE_TOOLS_REFERENCE.md.

## Titan 2 keyboard-first UX contract

### HOME / SableStart

HOME must be operable without touch.

Required behavior:

- printable key from Start enters type-to-search/command immediately;
- first typed character is preserved;
- soft keyboard does not appear merely because hardware-keyboard search gains focus;
- Up/Down/Left/Right move deterministic visible focus;
- Enter activates the focused item;
- Back/Escape returns one semantic level;
- Home returns to Start/root;
- Tab / Shift+Tab traverse focus where appropriate;
- hardware repeat behaves predictably for navigation and editing;
- selected/focused state is visible without relying on color alone;
- focus restores after dialogs, returning from apps and task switching;
- All Apps remains secondary to Start, but fully keyboard navigable;
- direct app/command shortcuts may be supported through a configurable semantic shortcut layer;
- touch remains available as secondary input.

The Titan Start layout may differ from Panther's touch layout. It must still consume the same tiles, app inventory, people/communication semantics, settings routes and privacy model.

### Search / command

The keyboard-first command surface should unify:

```text
apps
settings
people
conversations
authorized local content
typed Sable actions
```

The first implementation may expose only a subset, but app search and Settings navigation are mandatory.

Search must not require a prior tap.

### Modifier model

Treat these as explicit semantic states where the hardware supports them:

```text
Shift
Ctrl
Alt
SYM
one-shot modifier
held modifier
locked/latching modifier
navigation mode
```

A held Ctrl shortcut and a latched navigation mode are not the same state.

Mappings should resolve to semantic commands such as:

```text
NAV_UP
NAV_DOWN
NAV_LEFT
NAV_RIGHT
NEXT_FOCUS
PREVIOUS_FOCUS
ACTIVATE
BACK
HOME
RECENTS
OPEN_SEARCH
OPEN_NOTIFICATIONS
OPEN_QUICK_SETTINGS
APP_SHORTCUT
TEXT_COPY
TEXT_PASTE
TEXT_SELECT_ALL
```

Hardware-specific keycodes/scancodes map into those semantic actions through an adapter.

### Text input / IME

Titan 2 requires a physical-keyboard-aware Sable input strategy.

Requirements:

- normal Android `InputConnection`/IME contracts;
- no soft-keyboard popup by default when a physical keyboard is active;
- data-driven layout and Alt/SYM maps;
- correct Shift/Ctrl/Alt/SYM press/release/repeat state;
- language/layout switching;
- cursor/navigation shortcuts;
- text selection/editing shortcuts;
- optional compact suggestion/variation UI which does not consume large display area;
- application opt-out/raw-key path for apps such as games when required;
- no ambient AccessibilityService interception as the normal Sable input architecture.

Pastiera 0.86 is a primary behavior/reference model for this work, alongside Sable's independently owned implementation.

Sable first-party/default-IME ownership must not remove Android user choice:

~~~text
SABLE_FIRST_PARTY_IME=SableKeyboard
THIRD_PARTY_IME_SELECTION_ALLOWED=YES
FORCE_SABLE_IME_AFTER_USER_SELECTION=NO
~~~

Third-party IMEs are not automatically covered by Sable's direct-boot, lockscreen
or physical-keyboard acceptance evidence.

### App display compatibility

Titan-class displays require user-controllable per-app presentation rather than
one hard-coded letterbox rule.

Sable App Display Profiles should allow, per Android user/profile + package +
display class:

```text
Automatic
App Default
Native / Full Screen
1:1
4:3
3:2
16:9 Portrait
device-tested presets
Custom logical width x height
optional density / UI scale
```

The global physical display must remain unchanged. Sable should use Android
Activity/Task size-compat/window configuration, including coherent resource,
inset and input-coordinate transforms. Foreground-driven global `wm size`
switching is not the target architecture.

Titan research should record real applications that fail or waste substantial
space at native geometry and capture screenshots/metrics sufficient to build
reproducible compatibility tests. User choice remains authoritative over an
automatic profile.

### Notification configuration and hardware attention

Keyboard-first notification handling must include both triage and configuration.
Notification delivery policy is separate from Sable Hub aggregation.

Required Sable-owned behavior includes keyboard navigation of the notification
surface plus contextual open, reply when RemoteInput exists, dismiss, snooze,
mute/configure and expand/collapse actions.

Per app/channel/conversation, expose Android-supported delivery and privacy
controls such as alerting/quiet/off, sound, vibration, presentation, badge,
lockscreen visibility, priority and snooze.

Titan device research must separately establish which hardware attention outputs
actually exist and who owns them:

```text
status / notification LED
keyboard backlight or indicator behavior
rear SubScreen notification presentation
haptic patterns
audio
doze / always-on presentation if supported
```

Only physically proven outputs become Titan device-profile capabilities.

### System surfaces

Keyboard-first means more than the launcher.

Titan qualification must cover keyboard operation for:

- lockscreen/PIN/credential entry;
- Quick Settings;
- notification shade;
- Settings;
- app list and app security detail;
- Calculator;
- Reader;
- Media;
- Sudoku/Minesweeper/2048 where meaningful;
- Phone/in-call controls when Sable Phone work reaches Titan;
- Recents/task switching.

System-owned Sable behavior should be implemented in the owning platform surface rather than through accessibility automation.

### Game/raw-key behavior

Games may need direct/raw key events instead of IME text translation.

Define an explicit per-activity/input-mode contract rather than globally changing the IME.

Examples:

- 2048: arrows/WASD or profile-defined directional actions;
- Minesweeper: focus grid + reveal/flag shortcuts;
- Sudoku: focus grid + digit entry/navigation.

Touch remains available.

## T0 physical keyboard evidence on device arrival

Before changing any Titan input behavior, collect read-only evidence.

At minimum:

```text
getevent -lp
cat /proc/bus/input/devices
dumpsys input
settings/system IME state
effective KeyLayoutFile / KeyCharacterMap
/system/usr/keylayout inventory
/vendor/usr/keylayout inventory
/system/usr/keychars inventory
/vendor/usr/keychars inventory
physical keycodes/scancodes for:
  letters
  number/Alt symbols
  Shift
  Ctrl
  Alt
  SYM
  Enter
  Backspace/Delete
  Home
  Back
  Recents/App Switch
  any programmable/currency/special key
key down/up/repeat behavior
modifier metaState behavior
screen geometry/density/orientation
pointer/touch-surface devices if present
```

Do not infer Titan 2 mappings from Q25 mappings. Reference repositories guide what to measure; the physical Titan 2 provides the authoritative mapping.

## Architecture layers

Preferred Sable ownership:

```text
physical keyboard / pointer surface hardware
    -> kernel/input driver + stock vendor
    -> EventHub / InputReader + keylayout/key character map
    -> Sable hardware input mapper / device profile
    -> Sable Input Surface API
    -> Sable Keyboard Policy Service / semantic command layer
    -> SableStart / SystemUI / Settings / IME / first-party apps

editable text
    -> Android InputMethod/InputConnection
    -> Sable physical-keyboard-aware IME behavior
```

Do not route all keyboard behavior through one privileged daemon.

## Acceptance markers

```text
TITAN2_INTERACTION_PROFILE=KEYBOARD_FIRST
TITAN2_TOUCH_ROLE=SECONDARY
TITAN2_KEYBOARD_T0_BASELINE=PASS
TITAN2_KEYMAP_ADAPTER=PASS
TITAN2_MODIFIER_STATE_MACHINE=PASS
TITAN2_HOME_TYPE_TO_SEARCH=PASS
TITAN2_FOCUS_NAVIGATION=PASS
TITAN2_TEXT_INPUT=PASS
TITAN2_SYSTEM_SURFACE_KEYBOARD_ACCEPTANCE=PASS
TITAN2_TOUCH_KEYBOARD_COEXISTENCE=PASS
TITAN2_INPUT_SURFACE_PROFILE=PASS
TITAN2_APP_DISPLAY_PROFILE_BASELINE=PASS
TITAN2_NOTIFICATION_POLICY_KEYBOARD_ACCEPTANCE=PASS
TITAN2_NOTIFICATION_OUTPUT_CAPABILITY_BASELINE=PASS
```

These are N0 development acceptance markers. They do not imply N2 production support.
