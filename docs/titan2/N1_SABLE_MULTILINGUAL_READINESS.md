# N1-SABLE Multilingual Readiness Contract

This contract makes multilingual readiness a required N1 design rule for the SableOS GSI product overlay. Full translated language packs can arrive later; the N1 architecture must not block them.

## Decision

```text
N1_MULTILINGUAL_READINESS_REQUIRED=YES
FULL_LANGUAGE_PACKS_REQUIRED_IN_N1=NO
KEYBOARD_ONLY_MULTILINGUAL=NOT_ACCEPTABLE
UI_AND_KEYBOARD_LANGUAGE_ALIGNMENT=REQUIRED
PHYSICAL_KEYBOARD_LAYOUT_IS_NOT_FULL_LANGUAGE_INPUT=YES
```

N1-SABLE must be built so that Sable UI, physical keyboard behavior, fonts, and input-method policy can evolve together. Supporting multiple physical keyboard layouts without matching UI/resource readiness would create a broken product contract.

## Stage ownership

```text
N0-B-TREBLE=inherit RestlessOS/TrebleDroid baseline behavior only
N1-SABLE=define SableOS locale and keyboard architecture
N2-TITAN2=validate physical keyboard layouts and locale behavior on real devices
```

N0-B-TREBLE should not carry Sable-specific language policy. N1-SABLE owns the product-level multilingual architecture.

## Required N1 layers

| Layer | Requirement | N1 expectation |
| --- | --- | --- |
| Android locale support | Sable products must not disable Android language selection or font fallback behavior | Locale-safe |
| Sable UI resources | First-party Sable UI text must be resource-backed, not hardcoded | Required |
| Physical keyboard | Titan keyboard `.kl` / `.kcm` ownership and layout registry must be explicit | Required |
| IME policy | Complex-script languages must be treated as IME requirements, not keymap-only requirements | Required architecture; full coverage later |
| Font fallback | Product must not assume English-only glyph coverage | Required architecture |
| RTL readiness | Layouts must not hardcode left-to-right assumptions where Android resource/layout mechanisms can avoid them | Required architecture; full RTL validation later |

## P0/P1/P2/P3/P4/P5 rollout

```text
P0=English UI + Titan physical keyboard correctness
P1=multiple Android locales selectable; Sable UI must not break under non-English locales
P2=first Sable UI localization set
P3=validated physical keyboard layout registry for selected Latin-script languages
P4=complex-script IME support and validation path
P5=RTL UI validation path
```

N1 is not required to ship every translation. N1 is required to make the architecture translation-safe.

## Sable first-party app rules

All Sable first-party apps introduced or refreshed in N1 must follow these rules:

```text
NO_HARDCODED_USER_VISIBLE_TEXT=YES
RESOURCE_STRINGS_REQUIRED=YES
STRING_LENGTH_EXPANSION_SAFE=YES
FONT_FALLBACK_SAFE=YES
LOCALE_SAFE_SORTING_AND_FORMATTING=YES
DATE_TIME_NUMBER_FORMAT_USE_LOCALE=YES
LTR_ONLY_LAYOUT_ASSUMPTIONS_AVOIDED=YES
```

This applies to Launcher/Start, Settings-facing Sable panels, Messages, Media, Mail, Calculator, first-run/setup surfaces, and any Titan-specific UI.

## Physical keyboard policy

Titan hardware keyboard support must distinguish three separate concepts:

```text
KEY_LAYOUT=.kl hardware scan-code mapping
KEY_CHARACTER_MAP=.kcm character/dead-key behavior
IME=input method for composition, prediction, transliteration, and complex scripts
```

For Latin-script layouts, `.kcm` plus Android locale selection may be enough for early support. For languages requiring composition or complex input, N1 must define the IME integration path rather than pretending a hardware keymap is sufficient.

## N1 locale and keyboard gate

Create or wire a gate named:

```text
N1_SABLE_LOCALE_KEYBOARD_CONTRACT
```

The gate should eventually check:

```text
HARDCODED_STRING_SCAN=PASS
RESOURCE_LOCALE_STRUCTURE=PASS
PHYSICAL_KEYBOARD_LAYOUT_REGISTRY=PASS
FONT_FALLBACK_POLICY=PASS
RTL_SAFETY_REVIEW=PASS
IME_POLICY_DOCUMENTED=PASS
DEVICE_CONTACT=NO_UNLESS_N2_VALIDATION_APPROVED
```

Initial N1 implementation may mark some checks as `PASS_POLICY_ONLY` until code exists, but the contract must be present before Sable overlay work expands.

## Non-goals for initial N1

```text
FULL_TRANSLATED_UI_FOR_MANY_LANGUAGES=NO
FULL_COMPLEX_SCRIPT_INPUT_VALIDATION=NO
FULL_RTL_DEVICE_VALIDATION=NO
SHIPPING_ALL_LANGUAGE_PACKS=NO
```

These are later milestones. The N1 requirement is architectural readiness.

## Handoff to N2-TITAN2

Physical validation begins after a qualified N1-SABLE artifact exists. N2 should test at minimum:

```text
Titan hardware key behavior
layout switching path
Android locale switching path
Sable UI truncation/overflow behavior
font fallback on selected non-English samples
IME behavior for at least one complex-script scenario if included
```

No flash or device contact is authorized by this document.
