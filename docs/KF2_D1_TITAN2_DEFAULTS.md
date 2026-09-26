# KF2-D1 Titan 2 default keyboard policy

Status: **proposed V1 product defaults — validate before merge**

Date: 2026-09-25

This document resolves the Titan 2 policy choices intentionally left open by
the validated KF2 routing/security mechanism.

These are SableOS product defaults. They are not claims that stock AGUI uses the
same behavior and they are not hardware requirements.

## Decision summary

### Ordinary keyboard wake

```text
ordinary physical QWERTY/modifier keys -> do not wake primary display
```

Reasoning:

- matches the physically observed stock no-wake path without depending on stock
  framework policy;
- avoids accidental wake from pocket/bag keyboard presses;
- avoids ambiguity over whether the wake-triggering printable key should also be
  delivered into the lockscreen/IME/application;
- preserves a clean security boundary because wake remains an explicit action;
- battery impact is lower than general key-matrix wake.

This is a default, not a permanent platform limitation. A future accessibility
option may expose broader wake behavior if there is a justified use case.

### Func1

```text
default action   OPEN_SEARCH_COMMAND
lock policy      UNLOCKED_ONLY
wake policy      REQUEST_PRIMARY
configurable     YES
```

Interpretation:

- Func1 is the default Sable command key;
- with the primary display off, it may request wake;
- if the device is locked, the display may wake but the command/search action is
  suppressed until the lockscreen permits it;
- after unlock, Func1 gives keyboard-first access to SableStart Search/Command;
- users may remap it later through a Sable-owned settings surface.

This intentionally does not preserve stock AGUI rear-display behavior as the
default Sable meaning.

### Func2

```text
default action   OPEN_NOTIFICATIONS
lock policy      ALLOW_LOCKED_REDACTED
wake policy      REQUEST_PRIMARY
configurable     YES
```

Interpretation:

- Func2 is the default Sable attention key;
- it may wake the primary display;
- notification content while locked remains subject to normal lockscreen
  privacy/redaction;
- users may remap it later.

This separates the two side keys into a simple keyboard-first mental model:

```text
Func1 -> command / action discovery
Func2 -> attention / notifications
```

### Keyboard touch surface

```text
default          POINTER
user selectable  YES

available modes:
  POINTER
  GESTURE
  HYBRID
  RAW_APP
```

Reasoning:

- pointer is the safest first default for broad Android application
  compatibility;
- the hardware remains modeled as raw ABS_MT in KF1;
- gesture/hybrid behavior is layered above that fact and can evolve without
  changing the hardware profile;
- RAW_APP provides an explicit compatibility escape hatch for software that
  needs uninterpreted surface behavior.

The default does not imply Android Mouse Keys is the final implementation.

### Keyboard backlight

```text
default brightness       50%
activity timeout         20 seconds
wake on keyboard input   enabled
notification attention   disabled
user configurable        yes
UI owns sysfs            no
```

Reasoning:

- 50% avoids driving the hardware at its clamped extremes and is a neutral
  first-run level;
- a 20-second inactivity timeout provides useful keyboard visibility without
  leaving the backlight on indefinitely;
- keyboard/touch-surface activity may re-light it;
- notification blinking is disabled by default because the rear SubScreen,
  haptics, sound and normal notification UI already provide attention channels,
  and keyboard-light notification semantics are not yet a proven product need;
- Settings may expose brightness and timeout, but the UI must go through a
  bounded controller/service rather than writing sysfs directly.

### Navigation mode

```text
default state      OFF
activation state   DISABLED for V1
```

Reasoning:

- the product already has physical keyboard focus navigation, command/search and
  a real touch/pointer surface;
- enabling an ESDF/IJKL-style latched navigation mode before KF3/KF4 interaction
  design would introduce a shortcut/modifier conflict surface prematurely;
- no global activation chord is reserved in V1.

If later first-party/third-party testing shows a strong need, navigation mode can
be reintroduced as a contextual/user-configurable feature behind KF2.

## Security and privacy effects

These defaults preserve the validated KF2 ordering:

```text
SECURITY_LOCKSCREEN
RESERVED_SABLE_CHORD
IME_TEXT_COMPOSITION
APPLICATION_SHORTCUT
HOME_TYPE_TO_COMMAND
SABLE_NAVIGATION_MODE
NORMAL_APPLICATION_EVENT
```

Consequences:

- Func1 wake never implies command access while locked;
- Func2 notification access while locked remains redacted;
- ordinary typing keys do not bypass explicit wake/security handling;
- Alt/SYM remain text-composition-first;
- no new global chord is introduced;
- keyboard backlight state does not reveal notification state by default.

## Accessibility / configurability

V1 defaults aim to be useful without trapping the user:

- Func1 and Func2 are user-remappable;
- touch surface mode is user-selectable;
- keyboard backlight brightness/timeout are user-configurable;
- ordinary-key wake remains disabled by default, with future accessibility
  override possible if needed;
- no navigation-mode chord is imposed.

## App-compatibility effects

Expected positive compatibility behavior:

- pointer default works with ordinary Android applications without requiring
  Sable-specific keyboard navigation support;
- conventional app shortcuts remain untouched;
- no globally reserved Alt/SYM chord competes with text entry;
- RAW_APP remains available for explicit compatibility cases.

## Validation

Run from the KF2-D1 worktree:

```bash
bash build/kf2-d1-validate.sh
```

The script runs:

1. the cross-profile KF2 validator;
2. the validated KF2 mechanism tests;
3. the Titan 2 default-policy tests.

Full output is saved under:

```text
out/kf2-d1/<timestamp>/
  REPORT-<timestamp>-kf2-d1-titan2-defaults-validation.txt
  SHA256SUMS
```

## Acceptance markers

```text
ORDINARY_KEY_WAKE_DEFAULT=DISABLED
FUNC1_DEFAULT=OPEN_SEARCH_COMMAND
FUNC1_LOCK_POLICY=UNLOCKED_ONLY
FUNC2_DEFAULT=OPEN_NOTIFICATIONS
FUNC2_LOCK_POLICY=ALLOW_LOCKED_REDACTED
KEYBOARD_TOUCH_DEFAULT=POINTER
KEYBOARD_TOUCH_USER_SELECTABLE=YES
KEYBOARD_BACKLIGHT_DEFAULT_PERCENT=50
KEYBOARD_BACKLIGHT_TIMEOUT_SECONDS=20
KEYBOARD_BACKLIGHT_WAKE_ON_KEY=YES
KEYBOARD_BACKLIGHT_NOTIFICATION_ATTENTION=NO
NAVIGATION_MODE_V1=DISABLED
RESERVED_GLOBAL_CHORDS_V1=EMPTY
```

A PASS here means these are internally coherent Sable defaults against the
current KF1/KF2 contracts. Physical runtime acceptance waits for a Titan 2 Sable
image.
