# Pastiera 0.86 reference intake for Sable Keyboard

Status: **accepted behavior/product reference; no source import authorized**

Date: 2026-10-02

## Exact reviewed release

~~~text
repository=https://github.com/palsoftware/pastiera
release=v0.86
release_date=2026-09-26
annotated_tag=944dfd60008c349ed1303294605a1f3027b399c3
commit=e7d8f27ecc7253e61690b5d34f110b25dc68bb16
license=GPL-3.0
active_successor=https://github.com/pkb-rocks/plektra
~~~

Pastiera 0.86 describes itself as the final planned Pastiera feature release.
Security-relevant maintenance continues there while active feature development
moves to Plektra.

SableOS therefore uses 0.86 as a stable reference checkpoint rather than
chasing Pastiera nightly builds.

## Licensing boundary

Sable Keyboard remains Sable-owned.

~~~text
PASTIERA_SOURCE_IMPORTED=NO
PLEKTRA_SOURCE_IMPORTED=NO
GPL_CODE_COPIED_INTO_SABLE_KEYBOARD=NO
REFERENCE_USE=BEHAVIOR_AND_PRODUCT_IDEAS_ONLY
~~~

Direct GPL source reuse would require a separate explicit licensing/product
decision.

## Already covered by Sable

The Sable keyboard work already covers many Pastiera-class fundamentals:

- physical-keyboard-first IME;
- explicit Shift / Alt / Sym state;
- one-shot / lock / hold behavior;
- navigation mode;
- device KCM-aware Alt handling;
- numeric/PIN fallback;
- direct-boot storage;
- software-keyboard fallback;
- language subtypes;
- non-Latin layouts;
- Hangul, kana and pinyin composition;
- candidate UI;
- keyboard-first product integration.

These are not new roadmap items merely because Pastiera also contains them.

## Adopt as Sable concepts

### D6A — Compact Input Strip

High priority after D3 critical-input hardening.

When the full software keyboard is hidden, Sable Keyboard should be able to show
a compact keyboard-first strip containing only relevant state, for example:

- active language/layout;
- Shift / Alt / Sym / Nav state;
- composition candidates;
- short-lived variation choices;
- emoji/symbol entry affordance.

The strip should consume substantially less vertical space than the full
software keyboard.

This is inspired by the useful interaction pattern, not by Pastiera source or
visual identity.

### D6B — configurable SYM / emoji / snippets

Useful later keyboard capability:

- user-configurable symbol pages;
- emoji search from bundled/provenanced Unicode/CLDR data;
- local snippets/text shortcuts;
- symbol/emoji shortcodes;
- deterministic import/export schema.

Requirements:

~~~text
LOCAL_FIRST=YES
EXECUTABLE_PLUGIN_FORMAT=NO
SCHEMA_VALIDATION=REQUIRED
PROVENANCE_FOR_BUNDLED_DATA=REQUIRED
CLOUD_ACCOUNT_REQUIRED=NO
~~~

### D6C — local dictionary improvements

Candidate future work:

- multiple local dictionaries;
- explicit user dictionary;
- optional locally learned next-word sequences;
- user-visible clear/reset;
- no cloud training dependency.

Locally learned prediction must be separately privacy-reviewed and should be
opt-in until its retention/backup behavior is clearly specified.

### System-wide settings search/deep links

Pastiera 0.86's redesigned searchable settings and stable direct links are a
useful product lesson beyond the IME.

This belongs in Sable Settings architecture rather than as a keyboard-only
invention.

### Titan 2 Elite fit

Pastiera 0.86 reports improved Titan 2 Elite rounded-display fit.

Sable should use that as a test hypothesis:

- candidate/status strip stays inside rounded safe area;
- software modifier controls do not collide with corners;
- no Titan 2 geometry is inherited by Elite without separate evidence.

## Adopt elsewhere, not in the IME

### QuickLauncher

Pastiera's keyboard-driven app launching reinforces Sable's existing
type-to-find direction.

Ownership remains:

~~~text
Launcher3-hosted Sable Start / HOME
~~~

The IME must not become a second launcher or global command owner.

### Global/power shortcuts

Global shortcuts belong in platform input policy / Sable Start semantic actions,
not in privileged IME behavior.

The IME should avoid stealing printable input from applications.

## Defer or reject

### Shizuku-dependent suggestion swipe

Do not make Shizuku a SableOS input dependency.

~~~text
SHIZUKU_REQUIRED_BY_SABLE_KEYBOARD=NO
~~~

### Persistent clipboard history by default

Keyboard-owned clipboard history materially increases the sensitivity and
retention surface.

Policy:

~~~text
PERSISTENT_CLIPBOARD_HISTORY_DEFAULT=NO
~~~

A future opt-in design would require explicit retention, clear-all, private-field
and backup rules.

### Automatic online layout/dictionary repository

Do not introduce an automatic unverified remote content channel into the system
IME.

If downloadable resources are ever supported, require:

- signed/provenanced catalog;
- exact content hashes;
- schema validation;
- explicit user action;
- rollback/removal;
- offline bundled baseline.

### Fully arbitrary key remapping in first release

Do not turn Sable Keyboard into a large per-key configuration utility before the
core physical-keyboard experience is stable.

Prefer strong Sable defaults plus small bounded choices.

## Third-party IME policy input

Pastiera itself is a useful example of why SableOS should preserve Android's
normal alternative-IME model.

Product policy should be:

~~~text
SABLE_FACTORY_DEFAULT_IME=SABLE_KEYBOARD_PENDING_CANONICAL_IR005
THIRD_PARTY_IME_INSTALL_ALLOWED=YES
THIRD_PARTY_IME_ENABLE_ALLOWED=YES
THIRD_PARTY_IME_SELECT_ALLOWED=YES
FORCE_SABLE_IME_AFTER_USER_SELECTION=NO
SABLE_KEYBOARD_REMAINS_INSTALLED=YES
~~~

Sable Settings should make the trust implications of enabling a third-party IME
clear, but user choice should not be blocked by Sable product policy.

Critical pre-unlock/direct-boot support remains guaranteed only for the
first-party Sable configuration unless a third-party IME independently supports
and proves it.

## Related roadmap

Current sequence:

~~~text
D2   quality/dependency enforcement
D3   critical text-entry hardening
D5   first-party icon integration
D6A  compact input strip
D6B  configurable SYM / emoji / snippets
D6C  local dictionary/prediction improvements
~~~

D6 work must not delay D2/D3/D5 or canonical C3B image bring-up.
