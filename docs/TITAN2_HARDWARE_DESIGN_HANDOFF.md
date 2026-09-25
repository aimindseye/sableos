# Titan 2 hardware evidence handoff for keyboard-first design

Status: **design input complete enough to proceed; device build/deployment is a separate later gate**

Date: 2026-09-25

This document binds the completed Titan 2 hardware/input/display research into
Keyboard-First Design V1. It is a design handoff, not a claim that a Titan 2
SableOS image already exists.

The purpose is to answer:

> Which physical facts should constrain SableOS product/platform design now,
> before a Titan 2 build target or first N0 image exists?

## Current boundary

The Titan 2 research repository has closed the implementation-facing questions
for:

- physical keyboard matrix and Android key mapping;
- keyboard-associated touch surface;
- programmable side keys;
- keyboard illumination hardware;
- screen-off/wake behavior relevant to input policy;
- rear SubScreen topology/lifecycle/input;
- hidden-vs-public camera topology and normal-app camera capability;
- stock restore, bootloader, fastbootd and dynamic-partition preflight.

For design purposes, broad stock keyboard/SubScreen archaeology should stop.
Remaining exact AGUI preference behavior and stock synthetic-key compatibility
details are optional parity work, not prerequisites for Keyboard-First Design
V1.

## Proven Titan 2 physical facts

### Primary keyboard

```text
input device      TitanKey
transport         I2C 6-0058
driver            aw9523_key
matrix mode       enabled
stock Space wake  configured scan 57, but disabled by wake_up_enable=0
```

Observed Android behavior includes ordinary Space, Enter, Shift, Alt and SYM
events with repeat where expected.

Design consequence:

- treat the keyboard as a primary platform input surface;
- wake policy is a Sable policy choice constrained by battery/security behavior,
  not something that must copy stock;
- do not put scan-code quirks into SableStart or the common IME.

### Keyboard touch surface

```text
input device      touchPad
transport         I2C 2-0020
driver            synaptics_dsx_pad / synaptics_1403_touch
raw behavior      ABS_MT touch surface
stock Mouse Mode  Android Mouse Keys virtual mouse layered above the raw device
```

Design consequence:

- physical keyboard and keyboard touch surface are independent capabilities;
- do not assume the surface is intrinsically a relative mouse;
- Sable may choose pointer, gesture or mixed semantics above the same raw
  surface;
- the common capability schema should distinguish a raw absolute touch surface
  from an already-normalized pointer where that distinction matters.

### Programmable / side keys

```text
Func1  PMIC-backed runtime path, scan 249
       stock policy consumes it and can wake/activate the rear display

Func2  gpio_key.ko / gpio_key-func, scan 250
       stock policy consumes it; no visible display wake in the measured path
```

Design consequence:

- expose both as device-profile programmable-key capabilities;
- Sable owns the semantic action and lockscreen/wake policy;
- stock PhoneWindowManager/AGUI assignments are reference behavior, not the
  hardware contract.

### Vendor synthetic key 404

The stock native input stack contains a vendor compatibility path in
`KeyboardInputMapper::aguiSetProgrammableKey(int)` that synthesizes Android key
code 404. Downstream InputDispatcher, PhoneWindowManager and AGUI shortcut
policy consume it.

Design consequence:

- key 404 is a vendor translation artifact, not a Sable semantic action;
- normalize the underlying physical/gesture capability into the Sable Input
  Surface API instead of making 404 part of the common product contract;
- reproduce 404 only if stock-compatibility testing later proves a concrete
  need.

### Fingerprint gesture helper

`ff_key` is attributable to the FocalTech fingerprint stack rather than the
physical keyboard.

Design consequence:

- do not treat `ff_key` as part of the Titan keyboard adapter;
- expose fingerprint gesture keys only if Sable intentionally supports that
  fingerprint capability.

### Keyboard illumination

```text
backend          keypad_led.ko / MediaTek PWM
sysfs            /sys/devices/platform/keypad_led/keyled_brightness
public range     0..100
0                off / PWM disabled
1..7             effective minimum PWM level 8
8..99            direct effective level
100              effective PWM level 99
stock policy     AGUI KeyboardLightController in system_server
SELinux type     sysfs_agold
```

AW9523 LED mode is disabled in board DT; the dedicated keypad PWM driver is the
actual hardware owner.

Design consequence:

- Sable can replace the AGUI light policy/controller while preserving the kernel
  backend;
- expose brightness through a bounded keyboard-light service rather than letting
  UI code write sysfs directly;
- automatic timeout, wake-on-key and notification use are Sable product policy;
- hardware scaling/clamping belongs below the user-facing percentage model.

### Main and rear displays

Primary display:

```text
native           1440 x 1440 @ 60 Hz
base density     400
cutout           none
rounded corners  present
```

Rear SubScreen:

```text
native           410 x 502 @ 60 Hz
independent      brightness and touch association
display group    separate
stock flags      private/trusted/secure/own-content/own-focus class
task hosting     stock reports canHostTasks=false
runtime ID       not stable; must be discovered
```

The rear touch device is dynamically associated with the rear display and is
inactive when the corresponding display viewport is inactive.

Design consequence:

- never encode a fixed Android display ID;
- model the rear panel as a device capability with a discovered display/touch
  association;
- stock's no-task-hosting behavior is not automatically the Sable product
  decision, but changing it must be deliberate and security-reviewed;
- rear-display notification/presentation is a separate output capability from
  normal app task placement.

### Camera

Stock exposes four camera devices:

```text
0  public rear main
1  public front
2  hidden SYSTEM_CAMERA rear tele
3  hidden SYSTEM_CAMERA logical main+tele
```

The ordinary-app path already proves:

- rear main capture;
- front capture;
- high-resolution JPEG on both public cameras;
- rear RAW/DNG.

Design consequence:

- Sable Camera can be designed now around the ordinary Camera2 path;
- hidden tele/logical access stays a separate per-device privileged integration
  decision;
- keyboard-first camera UX can proceed without waiting for SYSTEM_CAMERA work.

## Mapping to ADR-0010 workstreams

### KF1 — Device Profile + Input Surface API

Unblocked now.

Titan 2 profile can represent:

```text
PHYSICAL_KEY_MATRIX
MODIFIER_KEYS
PROGRAMMABLE_KEYS
KEY_REPEAT
KEYBOARD_BACKLIGHT
ABSOLUTE_KEYBOARD_TOUCH_SURFACE
PRIMARY_SQUARE_DISPLAY
SECONDARY_REAR_DISPLAY
SECONDARY_DISPLAY_TOUCH
```

Potential ADR/schema refinement:

- distinguish a raw absolute touch surface from an already-normalized absolute
  pointer if the current `ABSOLUTE_POINTER` capability is too ambiguous.

### KF2 — Keyboard Policy Service

Unblocked now.

Open product decisions, not missing hardware facts:

- Func1 default semantic action;
- Func2 default semantic action;
- whether Space or another key may wake the primary display;
- lockscreen routing of programmable keys;
- small globally reserved shortcut namespace;
- keyboard-light wake/timeout behavior.

### KF3 — SableStart command/focus surface

Unblocked now.

The 1440x1440 primary display and real physical-keyboard behavior are sufficient
to design:

- printable-key entry from HOME;
- deterministic focus;
- first-key preservation;
- square-screen Start/Search/All Apps layout;
- keyboard-only navigation with touch retained as secondary input.

### KF4 — Physical IME

Unblocked for architecture and baseline implementation.

Known hardware boundaries are sufficient to build:

- data-driven Alt/SYM maps;
- explicit held/one-shot/latched modifier state;
- physical-keyboard-first InputConnection behavior;
- no full touch keyboard popup by default;
- device map kept below common IME semantics.

Exact stock Kika behavior is not required.

### KF5 — SystemUI / Settings traversal

Unblocked for design.

Qualification still requires a Sable image later, but focus order, shortcut
semantics and square-screen layout work can proceed now.

### KF6 — App Display Profiles

Unblocked for design.

The square 1440x1440 primary display is enough to define and test the common
profile UX in emulator/unit/instrumentation contexts before Titan runtime
qualification.

### KF7 — Notification Policy

Partially unblocked and useful now.

Physically proven Titan output capabilities include:

- rear secondary display;
- keyboard backlight;
- haptic/audio through normal Android device capability.

Sable should keep:

```text
notification delivery policy
Hub aggregation
hardware attention outputs
```

as separate layers.

Whether keyboard backlight should ever represent notification state is a product
decision, not a stock behavior requirement.

### KF8 — Hub integration

No new Titan hardware research is required before common Hub/notification design
continues.

### KF9 — Titan 2 adapter/evidence binding

Hardware contract is ready for adapter design, but runtime qualification waits
for a Titan 2 Sable build.

## Design questions now worth answering

The physical research has reduced the remaining work to product decisions:

1. What should Func1 and Func2 mean by default?
2. Which physical keys, if any, may wake the primary display?
3. Should the keyboard touch surface default to pointer, gesture, or a
   user-selectable hybrid mode?
4. What is the Sable keyboard-light policy: manual, automatic timeout,
   brightness curve, wake-on-key, notification use?
5. What is the rear SubScreen product role: glance/notification surface,
   bounded Sable mini-surfaces, selected apps, or a general secondary task
   display?
6. How should Search/Command, Recents, notification center and Quick Settings be
   exposed as keyboard-first semantic actions?
7. Which square-screen compatibility profiles should ship as defaults?
8. How much modifier state should be visible to the user, and where?
9. Which hardware behaviors must remain available while locked?

Those decisions should be made in common Sable architecture and then bound to
Titan 2 through the device profile.

## Remaining Titan 2 research that does not block keyboard-first design

Still useful for later N0 parity/support, but independent from the core
keyboard-first design:

- telephony / IMS functional baseline;
- audio/routing functional baseline;
- fingerprint authentication, sensors, NFC, GNSS, IR and USB OTG baseline;
- charging, Health HAL, broad suspend/deep-idle and thermal baseline;
- first-Sable VINTF/HAL comparison;
- privileged hidden-camera integration if adopted;
- exact stock preference persistence for keyboard-light UI;
- exact vendor string predicate selecting the synthetic-404 path.

Do not delay KF1-KF8 waiting for those items.

## Titan 2 Elite

When the Elite arrives, repeat the physical evidence independently and map it
into the same capability schema.

The goal is not to copy Titan 2 behavior. The goal is to test whether the
common keyboard-first capability model is broad enough to describe both devices
without application forks.
