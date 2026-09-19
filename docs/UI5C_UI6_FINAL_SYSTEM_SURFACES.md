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
