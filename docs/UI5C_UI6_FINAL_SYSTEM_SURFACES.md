# UI5C + UI6 final system-surfaces production tranche

Status: **combined production integration**

Tracking: GitHub issue #undefined

The remaining SableOS UI5C and UI6 work is intentionally combined into one
final system-surfaces tranche before the full Panther qualification build.

## Scope

### UI5C — SetupWizard + About / branding

Production work includes:

- SetupWizard welcome visual integration using the canonical SableOS mark;
- SetupWizard finish visual integration;
- SableOS copy where product ownership is genuinely Sable-owned;
- preservation of upstream bootloader/OEM-lock warnings and setup security
  behavior;
- About SableOS presentation backed by actual build/device properties rather
  than preview constants;
- continued reuse of the already-qualified branding assets and pinned
  SetupWizard2 / Settings / frameworks-base revisions.

Internal GrapheneOS package identifiers, service/provider ownership text and
GrapheneOS URLs are not globally replaced merely for cosmetic consistency.

### UI6A — Lockscreen / Keyguard visual refresh

UI6A is visual only.

Allowed changes:

- typography and spacing;
- restrained Sable surface geometry;
- live clock/date presentation;
- swipe-up affordance;
- approved Sable accent/visual treatment.

Preserved upstream behavior:

- credential verification;
- biometric authentication;
- trust state;
- emergency call;
- notification redaction;
- lockscreen notification behavior;
- falsing / gesture routing;
- doze/AOD state;
- device-policy restrictions;
- accessibility semantics.

No custom authentication path is introduced.

### UI6B — final SystemUI acceptance

The combined tranche also closes the remaining visual/accessibility acceptance
for UI4 + UI6:

- Quick Settings;
- notification shade;
- SystemUI media;
- lockscreen / Keyguard;
- touch targets;
- state descriptions;
- motion/gesture continuity;
- privacy indicators.

UI6B is an acceptance gate, not a license to modify unrelated SystemUI
behavior.

## Build strategy

The combined tranche uses one production branch:

```text
ui/ui5c-setupwizard-about-branding-production-20260919
```

The branch name is retained to avoid unnecessary checkout churn even though its
scope now includes UI6.

Qualification sequence:

```text
1. repository self-tests / source pins
2. fail-closed apply + verify
3. incremental SetupWizard build
4. incremental Settings build if About resources/controllers change
5. incremental SystemUI/framework build for UI6
6. integrated source verification
7. full Panther build
8. runtime visual/accessibility/security acceptance
```

The full Panther build should be started only after steps 1-6 pass. At that
point it becomes the first build worth leaving running overnight.

## Source-boundary rule

Any new SetupWizard2, Settings or frameworks/base file must be sealed before
mutation. Existing UI4 and D2+D3 deltas remain cumulative preconditions rather
than being reapplied destructively.

Do not clean, reset or clobber the existing qualified Android output tree.

## Product completion

This combined tranche closes:

```text
UI5C  SetupWizard + About/branding
UI6A  Lockscreen / Keyguard visual refresh
UI6B  remaining SystemUI/accessibility/motion acceptance
```

After the incremental gates pass, there is no additional UI system-surface
tranche before the final Panther build.


## Production implementation

The combined fail-closed applicator is:

```text
patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py
```

It layers only on the already-qualified cumulative state:

```text
D2+D3 branding
UI5A Settings + Applications
UI5B Application Security & Privacy
UI4 Quick Settings + notifications + SystemUI media
```

### SetupWizard production delta

The production welcome and finish layouts retain the existing SetupWizard2
activity/action implementation and OEM-unlock safety flow.

Visual changes are bounded to:

- canonical SableOS icon already qualified by D2+D3;
- dark Sable background and light text hierarchy;
- 72dp welcome mark and large light-weight welcome title;
- updated privacy/security-oriented copy without changing setup decisions;
- compact 96dp completion mark and completion note;
- existing language, accessibility, emergency-call, primary-next/start and
  OEM-unlock controls remain wired to the upstream actions.

### About SableOS production delta

The About screen becomes **About SableOS** and gains one read-only identity row.

Its summary is populated at runtime from:

```text
Build.MODEL
Build.DEVICE
Build.VERSION.RELEASE
Build.DISPLAY
```

No preview/version literal is embedded into Settings.

### Keyguard production delta

UI6 keeps the upstream Keyguard clock controller, binder, clock face selection,
AOD burn-in state and unlock gesture path.

The bounded visual delta is:

- large lockscreen clock biased to the start edge with a 28dp Sable margin;
- lockscreen clock top margin 18dp -> 28dp;
- keyguard indication bottom margin 32dp -> 36dp;
- upstream unlock indication copy becomes "Swipe up to unlock".

No authentication or device-entry code path is replaced.

### Incremental gate

After apply/verify, compile only:

```bash
m -j8 SetupWizard2 Settings SystemUI
```

using the existing `out_sable_ui_preview` tree.

A successful combined incremental build is the authorization point for the
final full Panther build. Do not clean or clobber before that build.
