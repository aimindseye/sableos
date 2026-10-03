# Keyboard-first design implementation queue

Status: **design complete / implementation ready**
Date: **2026-10-03**

The four bounded keyboard-first design closures are accepted in
`sableos-project/platform_sable@126d91bfaedc98edc83fd38bb9c6eee8e5c1a008`.

They are intentionally not assigned for implementation until the current P1-P4
and P5 developer trains finish.

## Accepted contracts

```text
DESIGN-KF-A
  docs/design/NOTIFICATION_POLICY_ATTENTION_HUB_OWNERSHIP.md

DESIGN-KF-B
  docs/design/SYSTEMUI_VISUAL_CONVERGENCE_CONTRACT.md

DESIGN-KF-C
  docs/design/SABLE_TOOLS_PRODUCT_CONSOLIDATION.md

DESIGN-KF-D
  docs/design/ALL_APPS_PRIVACY_RESPONSIVE_POLISH.md
```

Public design authority:

```text
repository=sableos-project/platform_sable
head=126d91bfaedc98edc83fd38bb9c6eee8e5c1a008
```

## Design-closure state

```text
DESIGN_KF_A_NOTIFICATION_ATTENTION_HUB=ACCEPTED
DESIGN_KF_B_SYSTEMUI_CONVERGENCE=ACCEPTED
DESIGN_KF_C_SABLE_TOOLS_CONSOLIDATION=ACCEPTED
DESIGN_KF_D_ALL_APPS_RESPONSIVE_POLISH=ACCEPTED
KEYBOARD_FIRST_V1_FOUNDATIONAL_DESIGN=COMPLETE
TITAN2_V1_PRODUCT_DESIGN=COMPLETE
```

Remaining work is implementation, canonical integration, Android build
qualification, device/runtime evidence and physical UX polish.

## Future implementation assignment

No implementation branch should be started from this document yet.

### Developer A — after P1-P4

Recommended next train:

```text
KF-A-I  Notification Policy / Attention / Hub integration
KF-B-I  SystemUI visual convergence
KF-D-I  All Apps privacy row + responsive common-app polish
```

Rationale:

- P1 already touches Launcher3-hosted Sable Start and All Apps behavior;
- P3 already touches SetupWizard2 and platform-facing keyboard-first behavior;
- KF-A/KF-B/KF-D share SystemUI/Settings/Launcher integration boundaries;
- assigning these after P1-P4 avoids changing the current stacked product-source
  train underneath qualification.

Recommended ordering:

```text
P1-P4 frozen + operator qualification
 -> KF-D-I All Apps/responsive polish
 -> KF-A-I Notification/Attention/Hub
 -> KF-B-I SystemUI convergence
```

KF-B should consume the effective notification/attention ownership decided by
KF-A rather than restyling a policy surface whose ownership is still changing.

### Developer B — after P5

Recommended next train:

```text
KF-C-I1  Sable Tools common shell / capability model
KF-C-I2  read-only device/keyboard/display/radio diagnostics
KF-C-I3  hardware utilities + local IR remote
KF-C-I4  report/export + Settings/App-Security handoff
KF-C-I5  operator/device physical qualification
```

Rationale:

- P5 is common-app architecture work;
- Sable Tools is also a common application, not a Titan-only fork;
- it can be implemented largely independently from SystemUI/Launcher work;
- hardware-specific enablement remains profile/evidence gated.

## Cross-lane dependencies

```text
KF-D-I depends on:
  P1 Sable Start / All Apps handoff
  SableScreens baseline

KF-A-I depends on:
  current Hub portability contract
  Android NotificationManager/NotificationChannel ownership
  device attention capability profiles

KF-B-I depends on:
  KF-A ownership decisions
  existing Quick Settings / Lockscreen / Settings / Setup visual contracts
  global Sable appearance tokens

KF-C-I depends on:
  device capability/profile APIs
  Settings ownership boundaries
  App Security & Privacy ownership boundaries
```

None of the design contracts authorize:

```text
device contact
flash
production signing
public release
platform privilege expansion without review
device-model branching in common product UI
```

## Implementation branch policy

When implementation is assigned later:

- each design gets its own branch train;
- base/head must be explicitly frozen;
- no branch may be stacked onto an unrelated unqualified P1-P5 train;
- source/static gates precede ai-g732 Android qualification;
- runtime/device PASS remains operator-owned;
- implementation must preserve the acceptance markers in the public design
  contract.

## DESIGN-KF-A implementation boundary

Must preserve:

```text
Android owns notification delivery policy
SystemUI/Settings edit Android policy
Sable Attention maps effective policy to validated hardware outputs
Hub aggregates and stores only Hub-specific preferences/bounded derived state
Hub does not bypass DND
Hub does not invent provider actions
work-profile/user separation
```

No second generic notification center.

## DESIGN-KF-B implementation boundary

Must preserve Android behavior/security while applying common Sable:

```text
theme roles
focus
typography
spacing
control states
privacy/redaction
responsive square/compact layout
branding
visual-regression coverage
```

No security/authentication policy change is authorized by visual convergence.

## DESIGN-KF-C implementation boundary

One launcher-visible product:

```text
Sable Tools
  Utilities
  Diagnostics
  Reports
```

No separate Sable Toolbox launcher app. Settings continues to own configuration.
Tools remains read-only by default and does not become a root/shell/mutation
console.

## DESIGN-KF-D implementation boundary

All Apps privacy summaries show current effective access for the current Android
user/profile, not manifest-requested permissions.

Responsive closure also covers:

```text
no clipped top-level navigation
meaningful Media mini-player
bounded trailing row actions
one functional alphabet-index concept
focus restoration
large-font compact-layout behavior
```

## Issue relationship

Implementation remains tracked by existing open product/runtime issues where
applicable, including:

```text
#79  SystemUI/notifications/branding convergence
#86  All Apps granted privacy permissions
#48  keyboard-device Sable Tools
```

Those issues should not be closed merely because design is complete. They close
only after implementation and required physical/runtime evidence.

## Assignment trigger

The next developer handoff is authorized only when:

```text
Developer A:
  P1-P4 frozen
  P1-P4 exact-head operator qualification complete

Developer B:
  P5A-P5E frozen
  P5F exact-head operator qualification complete
```

At that point no additional design phase is required. The accepted contracts can
be converted directly into implementation work packages.
