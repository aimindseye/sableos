# SableOS interaction profiles

SableOS supports multiple interaction profiles on one common application and service architecture.

The goal is not to force every device into the same screen layout. The goal is for the same Sable application semantics to remain available through interaction models suited to each form factor.

## Design rule

> Form factor changes presentation and navigation, not application meaning.

A message is still a message, a notification is still a notification, and a call action is still a call action whether it is invoked from a large touch target or a hardware-key shortcut.

## Common semantic primitives

Applications should be built from semantic concepts that shells can present differently:

- navigation
- command
- list
- conversation
- contact
- notification
- search
- quick action
- status
- media
- form/input
- context action
- focus target

Device-specific UI code should be limited to places where hardware really requires it.

## Interaction security boundary

Both interaction profiles follow the same trust-boundary rule:

> The shell may observe and request; privileged services decide and execute.

A touch control, keyboard shortcut, command-palette entry, or Settings page does not gain direct hardware/security privilege merely because it can request an operation.

The shell should consume typed Sable semantic APIs for actions such as:

- placing or ending a call
- sending a message
- changing brightness or power policy
- connecting to a network
- changing notification policy
- querying storage or battery state
- requesting a security/encryption operation
- invoking automotive/accessory compatibility features

Raw device nodes, modem sockets, filesystem-encryption primitives, broad Binder/HIDL/AIDL surfaces, and privileged native libraries remain behind dedicated services/brokers and SELinux policy.

This rule is renderer-independent and applies equally to Slint, Vexo/`wgpu`, a future Sable-owned renderer, touch-first, keyboard-first, and any future interaction profile.

See `AOSP_CAPABILITY_POLICY.md`, `ARCHITECTURE.md`, and `adr/0002-rust-ui-framework-and-android-app-compatibility.md`.

## Touch-first profile

Internal/source naming should remain generic, for example `shell_touch` or `interaction_touch`.

The Pixel and conventional-phone reference experience is touch-first and Metro-inspired in its design direction:

- strong typography
- simple geometry
- edge-to-edge content
- low visual chrome
- glanceable information surfaces
- fast gesture navigation
- large, deliberate touch targets
- fast peek/return workflows
- low-latency transitions
- motion used to clarify hierarchy rather than decorate it

This is inspiration, not an attempt to clone Windows Phone or another Microsoft product.

The touch-first profile is the initial Pixel 4a 5G experience and should remain applicable to later Pixel-class and other conventional touch-first phones.

## Keyboard-first profile

Internal/source naming should remain generic, for example `shell_keyboard` or `interaction_keyboard`.

The keyboard-first profile is BlackBerry/BB10-inspired in interaction philosophy and treats a physical QWERTY keyboard as a primary OS input device rather than an accessory attached to a touchscreen UI.

Core behaviors should include:

- predictable directional focus
- visible focus state
- instant type-to-search from appropriate top-level contexts
- global and application-level shortcuts
- modifier-key chords where hardware supports them
- key hold/repeat semantics
- contextual actions without requiring touch
- command palette / quick launcher
- notification and communication triage from the keyboard
- deterministic back/navigation behavior
- fast peek/return workflows
- focus restoration after dialogs or app switching
- touch and keyboard coexistence
- pointer/touch-surface integration where available

Dense layouts are acceptable when they remain readable and navigable from the keyboard.

This is inspiration, not an attempt to clone BlackBerry OS/BB10.

## Titan 2 keyboard-first profile

Titan 2 is the first near-term hardware target where the keyboard-first profile is mandatory rather than optional.

```text
TITAN2_INTERACTION_PROFILE=KEYBOARD_FIRST
navigation.primary=keyboard
navigation.secondary=touch
touch_required_for_core_navigation=false
```

Required first-class behaviors:

- printable-key type-to-search from HOME with the first key preserved;
- deterministic directional focus and visible focus state;
- Enter activation, Back/Escape navigation and predictable Home/Recents behavior;
- Tab/Shift+Tab traversal where appropriate;
- key hold/repeat handling;
- explicit held vs one-shot vs latched modifier state;
- keyboard navigation across SableStart, SystemUI, Settings and first-party apps;
- physical-keyboard text entry without summoning the soft keyboard by default;
- touch/keyboard coexistence rather than touch fallback as the normal path.

The normative architecture is `adr/0010-keyboard-first-sableos-design-v1.md`; the Titan-specific external reference review and licensing/provenance boundary is `TITAN2_KEYBOARD_FIRST_REFERENCE.md`.

## Keyboard-first Hub

Sable Hub uses the same Priority / Messages / Email / People semantic model on
touch-first and keyboard-first devices.

The keyboard-first profile should make communication triage deterministic:

```text
1 / P  Priority
2 / M  Messages
3 / E  Email
4 / C  People
Up/Down  move selection
Enter    open
R        reply only when the active source exposes reply capability
Esc      back
```

Exact reserved global chords remain owned by the Sable Keyboard Policy Service;
single-key commands apply only when Hub itself owns the focused context and must
not steal text input.

## Keyboard-first tools surface

Physical-keyboard devices should also have a compact Sable-native power-user/device toolbox.

The common direction is documented in KEYBOARD_FIRST_SABLE_TOOLS_REFERENCE.md and is inspired in part by bb10root/bb10tools, while preserving Android/SableOS security ownership.

Required interaction properties:

- type-to-filter/search tools;
- keyboard-only navigation of core diagnostics;
- visible deterministic focus;
- copy/export shortcuts;
- read-only diagnostics by default;
- touch as a secondary path;
- no root/accessibility/bind-mount hacks for functionality SableOS owns at platform level.

Titan 2 and Q27 should consume the same Sable Tools semantics and source where compatible.

## Do not branch on model name

Applications should not contain logic such as:

```text
if device == Q25:
    use_keyboard_ui()
```

Prefer capability-driven behavior such as:

```text
input.has_physical_keyboard = true
navigation.primary = keyboard
navigation.secondary = touch
display.aspect_class = compact_portrait
```

This allows future portrait QWERTY, landscape QWERTY, slider, folding or other keyboard devices to share the same interaction profile.

## Input, display and attention capability examples

The capability model must describe behavior rather than branding and must not
collapse the physical key matrix and pointer/touch surface into one boolean.
It should be able to express at least:

```text
input.has_touch
input.has_physical_keyboard
input.has_dpad
input.modifier_keys
input.programmable_keys
input.repeat_capable
input.keyboard_wake
input.keyboard_backlight

input.surface.relative_pointer
input.surface.absolute_pointer
input.surface.scroll_x
input.surface.scroll_y
input.surface.tap
input.surface.click
input.surface.long_press
input.surface.swipe
input.surface.multi_zone
input.surface.gesture_select
input.surface.location = keyboard_matrix | toolbelt | separate_trackpad | other

navigation.primary
navigation.secondary

display.aspect_class
display.compactness
display.orientation_preference
display.app_profile_support

notification.output.status_led
notification.output.keyboard_backlight
notification.output.secondary_display
notification.output.haptic
notification.output.audio
notification.output.always_on_display
```

A device capability says what can be done. The owning Sable policy surface says
whether and how the capability is used.

## Sable App Display Profiles

Keyboard-first and unusual-aspect devices require application compatibility to
be user-controllable rather than hard-coded per model.

A per-app profile may choose:

```text
Automatic
App Default
Native / Full Screen
1:1
4:3
3:2
16:9 Portrait
device-tested preset
Custom logical width x height
optional density / UI scale
```

The physical/global display remains unchanged. Profiles are applied through
Android Activity/Task size-compat and window configuration and are scoped by
Android user/profile + package + display class. Global foreground-driven
`wm size` switching is not the Sable architecture.

## Keyboard-first notification interaction

Keyboard-first devices must expose notification triage and configuration without
requiring touch. Notification delivery policy remains distinct from Sable Hub
conversation aggregation.

While the Sable notification surface has focus, contextual keys may provide
open, reply, dismiss, snooze, mute/configure and expand/collapse actions. These
single-key commands are not global shortcuts.

Per-app/channel/conversation controls may include alerting/quiet/off, sound,
vibration, presentation, badge, lockscreen privacy, priority, snooze and Hub
inclusion where technically valid. Hardware attention outputs appear only when
the device profile proves that capability.

## Q25 profile

The Zinwa Q25 remains a useful keyboard-first engineering reference, but Titan 2 is now the first near-term physical keyboard-first SableOS evaluation target.

Its purpose is broader than supporting one handset. It is the validation target for:

- MediaTek hardware adaptation
- square/compact display handling
- keyboard-first shell behavior
- common Sable application semantics across touch-first and keyboard-first devices

The Q25 shell should use the same contacts, messages, notifications, settings, search and telephony service models as the Pixel shell.

## Q27 and future QWERTY hardware

The Zinwa Q27 is an exploratory target pending public developer sources and hardware validation.

If its platform is suitable, it should consume the same keyboard-first interaction framework rather than introduce a new Q27-specific shell.

The same rule applies to other future QWERTY devices: add hardware capabilities and adapters where needed, but keep common interaction behavior reusable.

## Efficiency target

The base SableOS shell and service architecture should be lightweight enough that memory is available for applications, cached state, search indexes and future local intelligence rather than being consumed by the base UI stack.

High device RAM should improve multitasking and caching; it should not be a prerequisite for a responsive home screen, messaging UI or core phone functionality.

## Rendering independence

Historic planning identified Slint for an initial Rust UI and Vexo/`wgpu` for a later renderer. These are now qualification candidates rather than immutable release requirements.

S1.8-F0 compares Slint and Vexo against the actual Android/AOSP baseline, including toolchain fit, reproducible build integration, touch/multi-touch, keyboard/focus behavior, IME, accessibility, lifecycle, performance and security boundaries. The outcome may select either framework, select one with bounded gaps, justify a focused Sable fork, or justify a Sable-owned Rust UI framework if neither candidate can meet requirements without disproportionate compromise.

Interaction-profile semantics must not depend on one renderer. Focus traversal, command routing, search, navigation, application state and capability decisions belong above the rendering backend so the UI implementation can evolve without rewriting application logic.

See `adr/0002-rust-ui-framework-and-android-app-compatibility.md` for the accepted framework-qualification and Android-APK coexistence decision.
