# KF1 Device Profile + Input Surface Model V1

Status: **implementation/design contract — first profile: Titan 2**

Date: 2026-09-25

ADR-0010 defines KF1 as:

> capability schema + device profile + normalized input-surface model

This document turns that architecture into a machine-readable contract without
creating a Titan 2 build target or enabling device mutation.

## Deliverables

```text
product/keyboard-first/kf1-device-profile-v1.schema.json
product/keyboard-first/titan2.device-profile.json
build/validate_kf1_device_profile.py
tests/kf1/test_device_profile.py
```

Validate locally:

```bash
python3 build/validate_kf1_device_profile.py \
  product/keyboard-first/titan2.device-profile.json

python3 tests/kf1/test_device_profile.py
```

The validator intentionally uses only Python's standard library. The JSON
Schema is the normative structural description; the validator adds Sable
cross-field invariants.

## 1. Separation of facts and policy

A device profile contains **physically evidenced substrate facts** and explicit
unresolved policy decisions.

It does not silently convert stock behavior into Sable product behavior.

For example:

```text
FACT:
  Func1 is a physical programmable key with observed scan 249 and a wake-capable
  stock path.

NOT A FACT:
  Func1 must open the rear display in SableOS.

FACT:
  touchPad is a raw ABS_MT surface associated with the keyboard.

NOT A FACT:
  touchPad must behave as a mouse.

FACT:
  the dedicated keypad LED backend accepts 0..100 with hardware clamping.

NOT A FACT:
  the keyboard light must use stock timeout/automatic policy.
```

Product choices live in `policy_decisions` until KF2 or another owning
workstream makes them normative.

## 2. Device profile identity

The profile identity is independent of a physical handset serial.

Required identity:

```text
profile_id
device_class
interaction_profile
support_level
evidence
```

Titan 2 currently declares:

```text
device_class        titan2
interaction_profile KEYBOARD_FIRST
support_level       N0_GSI_USERSPACE_LAB
evidence.state      PHYSICALLY_VERIFIED
baseline            V01.00.13 / Android 16
```

This does not mean a Titan 2 Sable image exists or that N0 runtime acceptance
has passed. It means the profile is valid input to N0 design.

## 3. Display model

Displays have stable **profile IDs**, not assumed stable Android display IDs.

Required fields include:

```text
id
role
native geometry
refresh
base density
identity strategy
android display-id policy
touch association
```

### Primary display

Titan 2:

```text
profile id   primary-square
role         PRIMARY
native       1440 x 1440 @ 60
density      400 dpi
identity     PRIMARY_DEFAULT_DISPLAY
```

### Rear SubScreen

Titan 2:

```text
profile id        rear-subscreen
role              SECONDARY_REAR
native            410 x 502 @ 60
display ID policy DISCOVER
touch association DYNAMIC_ASSOCIATION
stock task host   false
```

A profile with `android_display_id_policy=DISCOVER` must not contain a
hard-coded numeric `android_display_id`. The validator enforces this because
the Titan research proved that runtime IDs are not stable enough to be a product
contract.

## 4. Input Surface model

KF1 treats an input surface as a physical or vendor-exposed source that can be
normalized before high-level Sable policy.

Current surface types:

```text
PHYSICAL_KEYBOARD
ABSOLUTE_TOUCH_SURFACE
RELATIVE_POINTER
PROGRAMMABLE_KEY
FINGERPRINT_GESTURE_HELPER
OTHER
```

Current locations:

```text
KEYBOARD_MATRIX
DEVICE_SIDE
FINGERPRINT_SENSOR
PRIMARY_DISPLAY
SECONDARY_DISPLAY
TOOLBELT
SEPARATE_TRACKPAD
OTHER
```

This deliberately adds `ABSOLUTE_TOUCH_SURFACE` / `ABSOLUTE_TOUCH` to the
minimum ADR-0010 vocabulary.

Reason: Titan 2 proves a meaningful distinction between:

```text
raw ABS_MT keyboard touch surface
        vs
normalized Android pointer / Mouse Keys device
```

Calling both simply `ABSOLUTE_POINTER` would lose a substrate fact needed by
the Hardware Input Mapper.

## 5. Normalization boundary

The profile describes the intended normalization class, not the final user
action.

### Standard physical keyboard

```text
TitanKey
  -> Linux / vendor driver
  -> EventHub / InputReader
  -> STANDARD_ANDROID_KEY_EVENT
  -> KF2 policy / IME / application
```

### Raw keyboard touch surface

```text
touchPad ABS_MT
  -> RAW_ABS_MT
  -> Sable Hardware Input Mapper
  -> semantic surface events
  -> pointer / gesture / hybrid policy
```

### Programmable keys

```text
Func1 / Func2
  -> SABLE_PROGRAMMABLE_ACTION normalization
  -> KF2 context/security routing
  -> semantic action selected by policy
```

No application should need to know scan 249, scan 250, `gpio_key-func`, or
MediaTek PMIC details.

## 6. Capability vocabulary

Capabilities are uppercase semantic facts. They are additive.

Current Titan 2 examples:

```text
PHYSICAL_KEY_MATRIX
MODIFIER_KEYS
KEY_REPEAT
KEYBOARD_WAKE_POLICY

ABSOLUTE_TOUCH
TAP
SWIPE
POINTER_POLICY_ELIGIBLE

PROGRAMMABLE_KEYS
WAKE_SOURCE

FINGERPRINT_GESTURE_KEYS
```

The schema does not require every device to expose every capability.

Titan 2 Elite must receive a separate profile from its own evidence. It must not
inherit Titan 2 capabilities merely because both devices are keyboard-first.

## 7. Hardware indicators

Indicators are represented separately from input surfaces.

Titan 2 keyboard light:

```text
indicator_type       KEYBOARD_BACKLIGHT
backend              keypad_led.ko / MediaTek PWM
sysfs                 /sys/devices/platform/keypad_led/keyled_brightness
public API            0..100
effective nonzero min 8
effective max         99
ownership             KERNEL_BACKEND
```

KF1 records the backend contract. KF2/Settings/SystemUI can later own user
policy.

UI code should not directly write the backend node.

## 8. Vendor compatibility artifacts

Vendor compatibility behavior may be recorded without becoming a common Sable
semantic.

Titan 2 example:

```text
stock synthetic Android key = 404
producer = KeyboardInputMapper::aguiSetProgrammableKey(int)
Sable exposure = DO_NOT_EXPOSE_AS_COMMON_SEMANTIC
```

The validator rejects using a raw `KEYCODE_*` as a surface
`semantic_default` and specifically prevents synthetic key 404 from being
promoted into the common semantic layer.

A later compatibility implementation may reproduce the vendor behavior behind
a bounded adapter if a real application compatibility need is demonstrated.

## 9. Policy-decision queue

The Titan 2 profile currently leaves these unresolved:

```text
FUNC1_DEFAULT_ACTION
FUNC2_DEFAULT_ACTION
PRIMARY_DISPLAY_WAKE_KEYS
KEYBOARD_TOUCH_DEFAULT_MODE
KEYBOARD_BACKLIGHT_POLICY
REAR_SUBSCREEN_PRODUCT_ROLE
```

This is intentional.

The profile is useful precisely because it separates:

```text
what the hardware can do
from
what SableOS should do
```

KF2 should consume the programmable-key, wake and lock-state facts when defining
the Keyboard Policy Service.

KF3 should consume the physical keyboard + square-display facts.

KF4 should consume keyboard/modifier/keymap facts without importing device scan
codes into the common IME.

KF7 should consume only proven attention-output capabilities.

## 10. Validator invariants

The stdlib validator currently enforces:

- schema version;
- canonical profile/device ID syntax;
- valid interaction/support/evidence state;
- evidence source presence;
- one and only one primary display;
- unique display/surface/indicator/compatibility IDs;
- no hard-coded Android display ID when the policy says `DISCOVER`;
- positive geometry/density/refresh values;
- non-empty, unique capability sets;
- common semantic defaults cannot be raw Android keycodes;
- synthetic vendor key 404 cannot become a common Sable semantic;
- sane indicator ranges;
- explicit state for every policy decision.

The Titan-specific test additionally seals the facts that should not drift
without new physical evidence:

- 1440x1440 primary;
- 410x502 rear display;
- rear dynamic display identity;
- TitanKey / `aw9523_key`;
- touchPad / raw ABS_MT;
- Func1 scan 249;
- Func2 scan 250 from `gpio_key`;
- `ff_key` classified outside the keyboard contract;
- keyboard-light 0..100 / effective 8..99 behavior;
- vendor synthetic key 404 remains compatibility-only.

## 11. KF1 completion boundary

KF1 V1 is complete enough to hand to KF2 when:

```text
COMMON_SCHEMA=PASS
TITAN2_PROFILE=PASS
PROFILE_VALIDATOR=PASS
TITAN2_EVIDENCE_INVARIANTS=PASS
RAW_TOUCH_VS_POINTER_DISTINCTION=PASS
DYNAMIC_REAR_DISPLAY_ID_RULE=PASS
VENDOR_404_NOT_COMMON_SEMANTIC=PASS
POLICY_DECISIONS_EXPLICIT=PASS
```

Titan 2 Elite is not required for Titan 2 KF1 closure. When the hardware
arrives, its independent profile is a portability test of the schema. If Elite
cannot be represented without application-level device branching, KF1 should be
revisited before promoting the schema beyond V1.
