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

This rule is renderer-independent and applies equally to Slint, Vexo/`wgpu`, touch-first, keyboard-first, and any future interaction profile.

See `AOSP_CAPABILITY_POLICY.md` and `ARCHITECTURE.md`.

## Touch-first profile

Internal/source naming should remain generic, for example `shell_touch` or `interaction_touch`.

The Pixel reference experience is touch-first and Metro-inspired in its design direction:

- strong typography
- simple geometry
- edge-to-edge content
- low visual chrome
- glanceable information surfaces
- fast gesture navigation
- large, deliberate touch targets
- motion used to clarify hierarchy rather than decorate it

This is an inspiration, not an attempt to clone another product.

The touch-first profile is the initial Pixel 4a 5G experience.

## Keyboard-first profile

Internal/source naming should remain generic, for example `shell_keyboard` or `interaction_keyboard`.

The keyboard-first profile treats a physical QWERTY keyboard as a primary OS input device rather than an accessory attached to a touchscreen UI.

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
- focus restoration after dialogs or app switching
- touch and keyboard coexistence
- pointer/touch-surface integration where available

Dense layouts are acceptable when they remain readable and navigable from the keyboard.

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

## Input capability examples

The eventual capability model should be able to express at least:

```text
input.has_touch
input.has_physical_keyboard
input.has_pointer
input.keyboard_touch_surface
input.has_dpad
input.modifier_keys
input.repeat_capable

navigation.primary
navigation.secondary

display.aspect_class
display.compactness
display.orientation_preference
```

Capabilities should describe behavior, not branding.

## Q25 profile

The Zinwa Q25 is the first planned keyboard-first SableOS port.

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

R1 uses Slint and R2 is expected to move toward Vexo / `wgpu`.

Interaction-profile semantics must not depend on one renderer. Focus traversal, command routing, search, navigation and capability decisions belong above the rendering backend so the UI implementation can evolve without rewriting application logic.
