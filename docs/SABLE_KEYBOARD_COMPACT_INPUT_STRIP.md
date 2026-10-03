# Sable Keyboard compact input strip (D7B)

Status: **source delivered; no device evidence**

Implements only the high-priority compact-input-strip concept accepted in
`docs/PASTIERA_086_REFERENCE_INTAKE.md` (its D6A). Pastiera and Plektra are behaviour references
only. No source was imported and no GPL code was copied.

## Source markers

Derived from the source by `build/titan2/qualify-c3b-product-source.sh`; source-level only.

~~~text
SABLE_KEYBOARD_COMPACT_STRIP_MODEL=PASS
SABLE_KEYBOARD_COMPACT_STRIP_STATE=PASS
SABLE_KEYBOARD_COMPACT_STRIP_SAFE_AREA=PASS
SABLE_KEYBOARD_COMPACT_STRIP_HEIGHT=PASS
SABLE_KEYBOARD_COMPACT_STRIP_PRIVACY=PASS
SABLE_KEYBOARD_COMPACT_STRIP_SCOPE=PASS_EXCLUSIONS_ABSENT
~~~

## Contract statements

~~~text
D7B_DEVICE_RUNTIME_VALIDATED=NO
D7B_CRITICAL_TEXT_ENTRY_DEVICE_RUNTIME_VALIDATED=NO
D7B_DEPENDENCY_DELTA=NONE
D7B_PASTIERA_SOURCE_IMPORTED=NO
D7B_PLEKTRA_SOURCE_IMPORTED=NO
D7B_GPL_CODE_COPIED=NO
D7B_EMOJI_DATA=NONE
D7B_SNIPPETS=NO
D7B_LEARNED_PREDICTION=NO
D7B_KEY_REMAPPING=NO
D7B_NEW_LANGUAGES=NO
D7B_SHIZUKU=NO
D7B_CLIPBOARD_HISTORY=NO
D7B_NETWORK_ACCESS=NO
D7B_ONLINE_REPOSITORIES=NO
IR_004_STATUS=OPEN_CANONICAL
IR_005_STATUS=OPEN_CANONICAL
~~~

IR-004 (platform Alt/Sym input policy) and IR-005 (factory default IME) stay open and
canonical-owned. Nothing here sets or implies a default IME. Device-runtime critical-text-entry
evidence (KL-029) is still pending.

## What the strip is

A pure-Kotlin model (`core/CompactStrip.kt`) rendered by `android/CompactStripView.kt`, which is
the IME candidates view. It shows only state the IME already holds:

- **Language/layout:** a short chip from the active language tag (and layout), with the full
  label as the accessibility description.
- **Shift / Alt / Sym / Nav state:** read from the existing `ModifierMachine` and `Resolver`. Off,
  one-shot, locked and held are distinct. Nav is shown *Active* only when it is effective in the
  field, and *Suspended* when it is on but the field class suspends it (passwords, numbers).
- **Existing composition candidates:** the composer's candidates, bounded to eight. Tapping one
  uses the same pick path as before.
- **Short-lived variation state:** the existing Sym+letter accent cycle, read through
  `Resolver.variation()`. It is shown for `StripPolicy.VARIATION_TTL_MS` after the last press and
  only when the cycle has at least two options.
- **Bounded symbol affordance:** while Alt or Sym is armed, up to twelve symbols taken from the
  existing layout tables (`KeyLayout.alt` / `KeyLayout.sym`). An unconfirmed layer is never
  guessed: Titan 2 has no confirmed Sym legends, so Sym alone offers nothing there.

One content area is shown at a time: candidates, then variation, then symbols.

## Modes

| Mode | When | Shows |
| --- | --- | --- |
| Hidden | no editable field, or nothing to show | nothing |
| CandidatesOnly | the full on-screen keyboard is up, or the strip is turned off in settings | candidates (the previous behaviour) |
| Compact | the full on-screen keyboard is hidden | language, Shift/Alt/Sym/Nav, one content area |

The strip is on by default and can be turned off in Sable Keyboard settings, which restores the
previous candidates-only behaviour.

## Space and safe areas

- Height: `StripGeometry.HEIGHT_DP` (one row, 48 dp). The full on-screen keyboard is at least
  `SoftKeyboardGeometry.minHeightDp()` (220 dp), and `SoftKeyboardView` reads its row height from
  that same constant. The gate requires the strip to be at most a quarter of that.
- Safe areas come only from the live window insets: display cutout, bottom rounded corners and
  the navigation bar. `StripGeometry.cornerInset` derives the corner offset from the circle, so
  no device geometry is hard-coded and Titan 2 geometry is not inherited by Elite.
- Not validated on a device or on an Elite display.

## Privacy

- Candidates, variation and symbols appear only in ordinary text fields. Password, numeric
  password, number and phone fields show language and modifier state only.
- The strip stores nothing, logs nothing, and has no network or clipboard access. The keyboard
  manifest still requests no permission.
- A failed strip refresh never reaches the key path.

## Explicitly not in this deliverable

- No configurable snippets, import/export, learned prediction, arbitrary key remapping, new
  languages, Shizuku, persistent clipboard history, cloud dependency or online layout/dictionary
  repository.
- No emoji affordance: the repository has no provenanced emoji data, so none is offered
  (`D7B_EMOJI_DATA=NONE`). One needs a provenanced Unicode/CLDR source first.
- No second launcher or global command surface in the IME; no change to which IME is default.

## Verification limits

The JVM tests cover the model, modifier/nav/variation reporting, symbol sourcing, privacy
suppression and the geometry math. `CompactStripView`, the service wiring and the settings switch
are not compiled or run here and are verified by the static gate and operator Android
compile/lint/Detekt/Ktlint only. Whether the system shows the candidates window for a hardware
keyboard with no soft keyboard, and how it lays out on Titan 2 and Elite, is unverified (KL-032).
