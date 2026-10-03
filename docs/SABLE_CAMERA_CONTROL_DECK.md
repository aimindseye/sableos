# Sable Camera Control Deck

Status: **accepted product/UX direction; source implementation and device evidence pending**

Date: 2026-10-02

## Product decision

Sable Camera on keyboard-first devices is no longer defined as a conventional
touch-first Android camera with a few keyboard shortcuts.

The product direction is:

> **The screen is the viewfinder. The physical keyboard is the camera control
> surface.**

This is an interaction-layer decision, not a new camera mode and not a vendor
HAL change.

The existing Sable Camera source remains capability-driven Camera2 code over the
stock vendor camera HAL/ISP. The Control Deck changes how the application
presents and controls already-supported capture capability.

## Goals

- maximize useful viewfinder area on Titan-class displays;
- make physical controls first-class rather than incidental shortcuts;
- preserve touch as a complete fallback;
- preserve Photo / Video / Pro as the shooting modes;
- expose manual parameters transiently rather than covering the viewfinder with
  permanent controls;
- remain usable in portrait orientation;
- make landscape orientation especially effective when the physical keyboard is
  on the user's right-hand side;
- keep device capability truth above UI ambition: unsupported Camera2 controls
  remain unavailable.

## Interaction model

### Portrait

Portrait remains supported.

The default portrait UI is a minimal conventional camera surface:

- large viewfinder;
- focus rectangle;
- compact mode/zoom/capture state;
- touch shutter and mode access;
- the same physical keyboard controls remain active.

Sable Camera must not globally force landscape merely because the device has a
physical keyboard.

### Landscape — Camera Control Deck

In landscape, Sable Camera should minimize persistent touch chrome and use the
physical keyboard as the primary camera control surface.

The keyboard is treated conceptually like the button/dial side of a dedicated
camera body.

The UI should favor:

- maximum viewfinder;
- small exposure/capture status;
- focus point;
- transient parameter strips;
- no fake on-screen DSLR dials;
- no requirement to touch the screen for ordinary capture.

## Standard control map

The initial Sable layout is intentionally opinionated rather than exposing a
large per-key customization matrix.

~~~text
Space / Enter / Camera key / Volume    shutter / video start-stop
F                                      autofocus
hold F                                 autofocus lock candidate
E                                      exposure selection / adjustment
hold E                                 auto-exposure lock candidate
I                                      ISO selector
W                                      white-balance selector
S                                      shutter-speed selector
+ / -                                  zoom
Left / Right                           previous / next shooting mode
Up / Down                              adjust active parameter
C                                      switch camera
R                                      RAW / RAW+JPEG candidate
B                                      same-scene compare bracket
G                                      last capture
A                                      return selected Pro parameter to Auto
~~~

The exact long-hold semantics require device/runtime testing before becoming
release behavior.

Func1/Func2 remain unbound until the Android input path proves that applications
can actually receive them; current Titan evidence says the vendor framework
intercepts them.

## Focus-point interaction

The Control Deck should support keyboard-driven focus-point movement without
requiring a tap on the viewfinder.

Candidate semantic model:

~~~text
F tap        autofocus at current focus point
F hold       lock focus
F + arrows   move focus point
E hold       lock exposure
Space        capture
~~~

The final chord may change after physical testing. The invariant is more
important than the exact keys:

~~~text
FOCUS_POINT_MOVE_WITHOUT_TOUCH=REQUIRED
AF_LOCK_DISCOVERABLE=REQUIRED
AE_LOCK_DISCOVERABLE=REQUIRED
~~~

Tap-to-focus remains supported as the touch fallback.

## Transient parameter strips

Manual controls should appear only while being adjusted.

Example:

~~~text
ISO
AUTO   100   200   400   800   1600
              ^
~~~

Similar strips may be used for:

- white balance;
- shutter speed;
- exposure compensation;
- manual focus;
- zoom;
- RAW/JPEG capture policy.

They should disappear automatically after interaction and must not permanently
consume square-screen viewfinder space.

## Control legend

Sable Camera needs a discoverability surface for the physical controls.

A hold-to-show or dedicated help action should display a translucent control
legend over the preview.

The legend must be keyboard dismissible and touch dismissible.

The legend is documentation of the fixed Sable layout, not an invitation to
turn the first release into a fully programmable key-mapping application.

## Orientation policy

Default:

~~~text
CAMERA_ORIENTATION_POLICY=AUTO
PORTRAIT_SUPPORTED=YES
LANDSCAPE_CONTROL_DECK=YES
GLOBAL_LANDSCAPE_LOCK=NO
~~~

Future settings may expose:

~~~text
Auto
Portrait
Landscape
~~~

but Auto remains the intended default.

All preview transforms, tap-to-focus coordinates, saved media orientation and
keyboard focus behavior must be validated independently in portrait and
landscape.

## Touch fallback

Every essential camera operation must remain reachable by touch.

Physical-keyboard-first means:

~~~text
TOUCH_NOT_REQUIRED_FOR_CORE_CAMERA_USE=YES
TOUCH_SUPPORTED=YES
~~~

It does not mean hiding essential functions behind physical-only chords.

## Relationship to existing camera scope

This design does not add new capture modes.

Current scope remains:

- Photo;
- Video;
- Pro;
- Auto / normal JPEG;
- high-resolution JPEG where reported;
- RAW/DNG where reported;
- compare bracket;
- capability-driven zoom/camera selection;
- Camera2 manual controls only when supported.

Not introduced by this decision:

- new HAL;
- proprietary GCam code;
- timelapse;
- burst;
- computational HDR pipeline;
- privileged telephoto access;
- SYSTEM_CAMERA permission;
- Func1/Func2 application bindings.

Those remain separate capability/evidence decisions.

## Product identity

The objective is not to imitate the visual appearance of Canon, Nikon or another
dedicated camera.

The useful reference idea is the interaction model:

~~~text
dedicated hardware controls
    + mostly unobstructed viewfinder
    + transient parameter feedback
    + visible focus state
~~~

Sable Camera should express that model in Sable's own visual language.

## Delivery roadmap

### CAMERA-D6A — Control Deck source architecture

- separate camera actions from key codes;
- define one Sable camera-action map;
- preserve touch actions against the same semantic commands;
- implement transient parameter-strip state;
- add help/control-legend model;
- no device-contact claim.

### CAMERA-D6B — focus and lock controls

- movable AF point;
- keyboard AF;
- AF lock;
- AE lock;
- tap-to-focus compatibility;
- Camera2 capability gating;
- JVM/source tests where possible.

### CAMERA-D6C — orientation/inset polish

- portrait minimal surface;
- landscape Control Deck surface;
- square/near-square inset handling;
- Titan 2 Elite rounded-corner safe areas;
- orientation policy setting if still justified.

### CAMERA-PHYSICAL — device evidence

On real hardware prove:

- key delivery while camera owns focus;
- every standard control;
- AF/AE lock behavior;
- focus-point geometry;
- portrait and landscape preview transforms;
- still orientation;
- video orientation;
- no accidental app/system shortcuts;
- one-handed/right-hand control ergonomics;
- touch fallback.

## Acceptance markers

Source-level:

~~~text
SABLE_CAMERA_CONTROL_DECK_MODEL=PASS
SABLE_CAMERA_FIXED_CONTROL_MAP=PASS
SABLE_CAMERA_TOUCH_FALLBACK=PASS
SABLE_CAMERA_TRANSIENT_PARAMETER_UI=PASS
SABLE_CAMERA_CONTROL_LEGEND=PASS
SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK=PASS_ABSENT
~~~

Runtime-level, later:

~~~text
SABLE_CAMERA_CONTROL_DECK_TITAN2=PASS
SABLE_CAMERA_FOCUS_POINT_TITAN2=PASS
SABLE_CAMERA_AF_LOCK_TITAN2=PASS
SABLE_CAMERA_AE_LOCK_TITAN2=PASS
SABLE_CAMERA_ORIENTATION_TITAN2=PASS
SABLE_CAMERA_CONTROL_DECK_ELITE=PASS_OR_SEPARATE_EVIDENCE_PENDING
~~~

No source-only result may claim the runtime markers.
