# Keyboard-first design implementation queue

Status: **design complete / implementation ready**
Date: **2026-10-04**

The four bounded keyboard-first design closures are accepted in
`sableos-project/platform_sable@126d91bfaedc98edc83fd38bb9c6eee8e5c1a008`.

They are now assigned to replacement developer slots because the original Dev A
and Dev B are treated as unavailable. If either returns later, assign remaining
or new work rather than displacing active replacement ownership.

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

## Active implementation assignment

Original Dev A/B ownership is retired for scheduling purposes.

```text
REPLACEMENT_DEV_A:
  KF-D-I  All Apps privacy row + responsive common-app polish   #305
  KF-A-I  Notification Policy / Attention / Hub integration    #304
  KF-B-I  SystemUI visual convergence                           #79

REPLACEMENT_DEV_B:
  KF-C-I1  Sable Tools common shell / capability model          #48
  KF-C-I2  read-only device/keyboard/display/radio diagnostics
  KF-C-I3  hardware utilities + local IR remote
  KF-C-I4  report/export + Settings/App-Security handoff
  KF-C-I5  operator/device physical qualification
```

Required ordering for replacement Dev A:

```text
KF-D-I -> KF-A-I -> KF-B-I
```

KF-B must consume the effective notification/attention ownership established by
KF-A. KF-D goes first because it is bounded common Launcher/app UX work and
directly exercises existing Panther issues #86/#120/#121/#122.

Replacement Dev B may begin KF-C source work independently once a source branch
and base are frozen. Device-specific diagnostics remain capability/evidence
gated; the read-only common shell must not grow into a root or mutation console.

If an original developer returns:

```text
DO_NOT_DISPLACE_ACTIVE_REPLACEMENT_OWNER=YES
ASSIGN_RETURNING_DEVELOPER=REMAINING_OR_NEW_WORK
```

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


## Pending DESIGN-KF-E — Battery usage, health and charging

Battery usage/health is added as the next Settings-focused keyboard-first design
workstream.

```text
DESIGN_KF_E_BATTERY_USAGE_HEALTH=DESIGN_MERGED_IMPLEMENTATION_PENDING
USER_SURFACE=Settings -> Battery
IMPLEMENTATION_ISSUE=#302
IMPLEMENTATION_STARTED=NO
```

Public design paths:

```text
docs/design/BATTERY_HEALTH_USAGE_UX.md
docs/design/BATTERY_HEALTH_USAGE_VISUAL_CONFIRMATION.md
docs/design/artifacts/sable-battery-health-usage-titan2.svg
```

Recommended implementation train after the already queued KF work:

```text
KF-E-I1  Settings Battery overview + focus/type-ahead
KF-E-I2  Android usage/accounting + consumers
KF-E-I3  health availability/source/confidence model
KF-E-I4  bounded local history + chart inspection
KF-E-I5  charging-capability discovery
KF-E-I6  mutable controls only where a backend is qualified
KF-E-I7  Panther/Titan physical UX/runtime qualification
```

KF-E must remain separate from the Titan 2 N1I cellular lane. Read-only BH1-BH4
can complete without BH6.

Cross-lane dependencies:

```text
KF-E-I depends on:
  Android Settings Battery ownership
  normalized key input contract
  keyboard-first Settings UX
  device battery capability/profile facts
  Android BatteryStats/Health/framework evidence
  explicit Settings source-owner selection before BH1 implementation
```

Hard boundary:

```text
NO_SEPARATE_BATTERY_APP
NO_FABRICATED_HEALTH_PERCENTAGE
NO_FABRICATED_CYCLE_COUNT
NO_COMMON_UI_RAW_SYSFS_WRITE
NO_UNQUALIFIED_CHARGING_MUTATION
NO_CLOUD_BATTERY_ANALYTICS
NO_DEVICE_CAPABILITY_INHERITANCE
```

## Issue relationship

Implementation remains tracked by existing open product/runtime issues where
applicable, including:

```text
#79  SystemUI/notifications/branding convergence
#86  All Apps granted privacy permissions
#48  keyboard-device Sable Tools
#302 Battery usage, health and charging Settings workstream
```

Those issues should not be closed merely because design is complete. They close
only after implementation and required physical/runtime evidence.

## Assignment state

```text
REPLACEMENT_OWNERSHIP=ACTIVE
P1_P4_SOURCE_HANDOFFS=MERGED_IN_TITAN2_TEMP
P5A_P5E=MERGED_IN_TITAN2_TEMP
P5F_OPERATOR_QUALIFICATION=PENDING
KF_D_I=#305
KF_A_I=#304
KF_B_I=#79
KF_C_I=#48
BATTERY_DESIGN=MERGED
```

Source/static gates still precede ai-g732 Android qualification, and all
device/runtime PASS remains operator-owned.

