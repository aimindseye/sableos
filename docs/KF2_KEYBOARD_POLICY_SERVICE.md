# KF2 Keyboard Policy Service V1

Status: **design/policy contract — first policy: Titan 2**

Date: 2026-09-25

ADR-0010 defines KF2 as the small platform policy layer that decides input
context, security class and routing after KF1 has normalized hardware facts.

KF2 is deliberately not a second keylayout, not an IME, and not a replacement
for Android application shortcut handling.

## Deliverables

```text
product/keyboard-first/kf2-keyboard-policy-v1.schema.json
product/keyboard-first/titan2.keyboard-policy.json
build/validate_kf2_keyboard_policy.py
build/kf2-validate.sh
tests/kf2/test_keyboard_policy.py
```

Validate with:

```bash
bash build/kf2-validate.sh
```

The full output is saved under `out/kf2/<timestamp>/`; terminal output is
limited to report path and PASS/FAIL.

## 1. Ownership boundary

The pipeline is:

```text
physical hardware
  -> kernel/vendor input
  -> EventHub/InputReader
  -> KF1 normalized device/input surface
  -> KF2 context + security + routing
  -> semantic action OR pass-through destination
  -> SableStart / SystemUI / Settings / IME / application
```

KF2 may reference stable KF1 surface IDs such as:

```text
func1
func2
keyboard-touch-surface
```

KF2 must not reference:

```text
scan 249 / 250
event numbers
Linux driver names
Android vendor key 404
raw AGUI policy classes
```

Those are substrate or compatibility facts below the policy layer.

## 2. Normative routing precedence

V1 binds the ADR-0010 order exactly:

```text
1 SECURITY_LOCKSCREEN
2 RESERVED_SABLE_CHORD
3 IME_TEXT_COMPOSITION
4 APPLICATION_SHORTCUT
5 HOME_TYPE_TO_COMMAND
6 SABLE_NAVIGATION_MODE
7 NORMAL_APPLICATION_EVENT
```

The validator rejects reordering.

This ordering is intentionally conservative:

- lockscreen/security gets first refusal;
- the global Sable shortcut namespace remains small;
- editable text reaches the IME before HOME/search behavior;
- conventional application shortcuts are preserved before launcher navigation;
- HOME type-to-command only wins in the correct HOME context;
- navigation mode is lower priority than ordinary app shortcuts;
- unmatched input reaches the application normally.

## 3. Lock-state policy

Every semantic action has one explicit lock policy:

```text
ALLOW_LOCKED
ALLOW_LOCKED_REDACTED
AUTH_REQUIRED
UNLOCKED_ONLY
DISABLED
```

Examples in the Titan 2 draft:

```text
OPEN_HOME             UNLOCKED_ONLY
OPEN_SEARCH_COMMAND   UNLOCKED_ONLY
OPEN_RECENTS          UNLOCKED_ONLY
OPEN_NOTIFICATIONS    ALLOW_LOCKED_REDACTED
OPEN_QUICK_SETTINGS   ALLOW_LOCKED_REDACTED
BACK                  ALLOW_LOCKED
WAKE_PRIMARY          ALLOW_LOCKED
WAKE_SECONDARY        ALLOW_LOCKED
```

`ALLOW_LOCKED` for a wake/navigation primitive never means "unlock." The
lockscreen/security stage still runs first and controls visible content and
credential state.

## 4. Text-entry and application-shortcut rules

The initial keyboard-first policy fixes these common rules:

```text
editable text owner          IME_TEXT_COMPOSITION
full soft IME default        HIDDEN with physical keyboard
HOME printable key           START_COMMAND
HOME first key preserved     YES
conventional app shortcuts   PRESERVE
Alt text role                TEXT_COMPOSITION_FIRST
SYM text role                TEXT_COMPOSITION_FIRST
```

The Alt/SYM rule is especially important on Titan 2 because those keys are part
of real text/symbol entry. KF2 must not casually reserve Alt+letter or
SYM+letter global chords and break composition.

The initial Titan 2 `reserved_global_chords` list is empty on purpose. The
service mechanism exists before Sable claims any globally reserved chord.

## 5. Programmable keys

KF2 consumes the KF1 surface IDs:

```text
func1
func2
```

The first draft records both as:

```text
assignment_state = UNDECIDED
semantic_action  = null
lock_policy      = DISABLED
wake_policy      = UNDECIDED
```

That does not mean the keys are unavailable. It means physical capability is
proven but Sable has not yet chosen the product default.

When an assignment becomes normative, KF2 uses a semantic action such as
`OPEN_SEARCH_COMMAND` or `OPEN_NOTIFICATIONS`. It does not expose scan codes
to SableStart/SystemUI.

## 6. Wake policy

KF1 proved stock wake behavior and hardware wake facts. KF2 owns the desired
Sable behavior.

The first draft intentionally leaves:

```text
ordinary_keyboard_primary_wake = UNDECIDED
func1 wake policy              = UNDECIDED
func2 wake policy              = UNDECIDED
```

while permanently binding:

```text
lockscreen_security_first = true
```

Wake is therefore a product decision, but it can never become an authentication
bypass.

## 7. Navigation mode

The common mechanism supports a contextual Sable navigation mode, but V1 does
not invent an activation chord before product review.

Initial state:

```text
default_state     OFF
activation_state  UNDECIDED
activation        null
scope             CONTEXTUAL
```

This keeps conventional application shortcuts and text input stable while the
keyboard-first navigation UX is designed.

## 8. Keyboard touch surface

KF1 proved `keyboard-touch-surface` is raw ABS_MT rather than an intrinsic
mouse.

KF2 therefore allows:

```text
POINTER
GESTURE
HYBRID
RAW_APP
```

but leaves the default `UNDECIDED`.

This is intentional. The common policy model supports all four without baking
stock Android Mouse Keys into the hardware profile.

A later decision may make the mode user-selectable and provide an app/raw-input
escape hatch.

## 9. Keyboard backlight

KF1 owns the hardware backend facts. KF2/Settings own behavior.

Permanent V1 boundary:

```text
ui_owns_sysfs = false
```

Still undecided:

```text
timeout policy
wake-on-key behavior
notification-attention use
```

The implementation should expose a narrow controller/service; presentation code
must never directly write the keypad LED sysfs node.

## 10. Rear SubScreen boundary

KF1 handed off `REAR_SUBSCREEN_PRODUCT_ROLE`, but that decision is broader
than keyboard routing.

KF2 explicitly delegates it to:

```text
SECONDARY_DISPLAY_PRODUCT_POLICY
```

KF2 may eventually route a semantic action such as a request to wake/open a
rear-display surface. It does not decide:

- whether arbitrary app tasks can live there;
- notification privacy/presentation policy;
- task-hosting/security model;
- the overall rear-display product role.

KF7 may consume the rear display as a proven notification output, but the
display's complete product role is not owned by KF7 notification policy alone.

## 11. Validator invariants

The validator cross-checks the KF2 policy against the KF1 profile and enforces:

- device/profile identity matches;
- exact seven-stage routing precedence;
- physical-keyboard soft IME is hidden by default;
- HOME type-to-command preserves the first key;
- normal application shortcuts are preserved;
- Alt and SYM remain text-composition-first;
- semantic action IDs and lock policies are explicit;
- programmable keys reference real KF1 `PROGRAMMABLE_KEY` surfaces;
- undecided programmable keys cannot secretly carry an action;
- touch policy references the KF1 `ABSOLUTE_TOUCH_SURFACE`;
- keyboard-light policy references the KF1 keyboard-light indicator;
- UI never owns keyboard-light sysfs;
- lockscreen security remains first;
- rear-display product role is explicitly delegated;
- raw hardware fields such as `scan_code`, `driver`, `module`,
  `linux_name` and Android `KEYCODE_*` are forbidden in KF2 policy.

Titan-specific tests additionally seal:

- no reserved global chords in the first draft;
- Func1/Func2 remain explicit product decisions;
- no vendor key-404 semantic leaks into policy;
- HOME/search cannot run unlocked policy while locked;
- locked notifications are redacted-policy actions;
- the keyboard touch surface remains undecided rather than silently becoming a
  mouse;
- raw scan-code injection is rejected.

## 12. KF2 decision queue

The service architecture can be validated before these product choices are
settled:

```text
FUNC1_DEFAULT_ACTION
FUNC2_DEFAULT_ACTION
PRIMARY_DISPLAY_WAKE_KEYS
KEYBOARD_TOUCH_DEFAULT_MODE
KEYBOARD_BACKLIGHT_TIMEOUT
KEYBOARD_BACKLIGHT_WAKE_ON_KEY
KEYBOARD_BACKLIGHT_NOTIFICATION_ATTENTION
NAVIGATION_MODE_ACTIVATION
```

Those decisions should be made deliberately during keyboard-first UX design,
then encoded as policy data and regression-tested.

## 13. KF2 V1 completion boundary

The policy-mechanism phase is ready to advance when:

```text
KF1_HANDOFF=PASS
ROUTING_PRECEDENCE=PASS
LOCK_POLICY_MODEL=PASS
IME_FIRST_EDITABLE_TEXT=PASS
APP_SHORTCUT_PRESERVATION=PASS
HOME_FIRST_KEY_PRESERVATION=PASS
PROGRAMMABLE_KEY_PROFILE_BINDING=PASS
RAW_HARDWARE_FIELDS_ABSENT=PASS
TOUCH_SURFACE_POLICY_MODEL=PASS
KEYBOARD_LIGHT_OWNERSHIP_BOUNDARY=PASS
POLICY_VALIDATOR=PASS
TITAN2_POLICY_TESTS=PASS
```

This does not require the undecided product mappings to be finalized. Those are
the next design inputs to KF3/KF4/SystemUI and the later runtime service
implementation.
