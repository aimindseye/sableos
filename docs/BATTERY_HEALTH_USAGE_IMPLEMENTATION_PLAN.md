# Battery usage, health and charging implementation plan

Status: **planned / design-first / implementation not started**  
Date: **2026-10-04**

Public product/design authority is being added in:

```text
sableos-project/platform_sable
  docs/design/BATTERY_HEALTH_USAGE_UX.md
  docs/design/BATTERY_HEALTH_USAGE_VISUAL_CONFIRMATION.md
  docs/design/artifacts/sable-battery-health-usage-titan2.svg
```

This private plan owns implementation sequencing, evidence and device
qualification. It does not supersede the active Titan 2 N1I cellular work.

## Product boundary

```text
USER_SURFACE=Settings -> Battery
SEPARATE_LAUNCHER_APP=NO
COMMON_UI_DEVICE_MODEL_BRANCHING=NO
KEYBOARD_FIRST_TITAN2=YES
TOUCH_FALLBACK=YES
LOCAL_ANALYTICS_ONLY=YES
RAW_SYSFS_COMMON_UI_ACCESS=NO
CHARGING_MUTATION=CAPABILITY_GATED
```

Battery V1 is read-only first. Charge-limit/adaptive-charging mutation is a later
phase and requires a validated per-device backend.

## Existing architecture preserved

The historical S1.7 service remains frozen:

```text
com.sableos.power.IPowerService/default
    getLatestState() -> PowerSnapshot
```

It remains responsible for the narrow semantic level/charging/source snapshot.
Do not expand S1.7 merely to satisfy the new Settings UI.

The Battery experience instead composes:

```text
S1.7 / Android battery current state
+ Android BatteryStats / Settings battery accounting
+ Health/framework/vendor facts
+ optional bounded device charging-control adapter
```

## Implementation train

```text
BH1  Settings Battery overview + keyboard/focus contract
BH2  Android usage/accounting + app/system consumer details
BH3  health source/availability/provenance model
BH4  bounded local temperature/health history + keyboard chart inspection
BH5  per-device charging-capability discovery
BH6  mutable charging/protection controls for validated backends only
BH7  physical keyboard/touch/accessibility/runtime qualification
```

### BH1 — overview

Requirements:

- remain under Android Settings Battery;
- list-first square layout;
- visible deterministic focus;
- Up/Down + Enter/Space + Back/Escape;
- Settings type-ahead/search integration;
- no separate Battery app/package.

### BH2 — usage

Use Android platform accounting where possible. Do not add a duplicate
always-running profiler.

Required evidence includes:

- accounting source;
- time-window semantics;
- system/app consumer mapping;
- background restriction handoff;
- keyboard chart inspection;
- no network dependency.

### BH3 — health

Each health fact records:

```text
availability
source
confidence
sample timestamp if meaningful
```

Initial source classes:

```text
ANDROID_FRAMEWORK
HEALTH_HAL
VENDOR_SUPPORTED_INTERFACE
DERIVED_LOCAL_ESTIMATE
UNAVAILABLE
```

Maximum capacity and cycle count fail closed to Unavailable unless independently
proven on each target.

### BH4 — history

Local bounded history only.

No cloud analytics and no high-frequency collector. Retention and sampling must
be justified against power cost.

### BH5 — capability discovery

Independently audit:

```text
Panther
Titan 2
Titan 2 Elite
Q27
```

for:

- health/cycle/capacity facts;
- charge counter;
- temperature;
- supported charge-limit semantics;
- adaptive/scheduled charging;
- thermal charging state;
- framework/HAL/vendor ownership;
- writable-control security boundary.

No target inherits another target's capability result.

### BH6 — mutation

Not authorized by design alone.

For each mutable control require:

- supported backend with provenance;
- fail-closed default;
- Settings ownership;
- SELinux/API review;
- negative tests;
- restore/default behavior;
- physical evidence;
- no direct common-UI raw sysfs write.

### BH7 — runtime qualification

Required classes:

```text
Panther touch reference
Titan 2 square physical-keyboard
Titan 2 Elite compact keyboard candidate
Q27 later when hardware qualifies
```

Titan 2 acceptance must include keyboard-only operation, touch fallback,
font-scale, screen reader and focus restoration.

## Keyboard acceptance

```text
BATTERY_VISIBLE_FOCUS=PASS
BATTERY_ARROW_NAVIGATION=PASS
BATTERY_ENTER_ACTIVATION=PASS
BATTERY_SPACE_TOGGLE_SUPPORTED_CONTROLS=PASS
BATTERY_BACK_ESCAPE=PASS
BATTERY_TYPE_AHEAD=PASS
BATTERY_SETTINGS_SEARCH=PASS
BATTERY_CHART_INSPECTION=PASS
BATTERY_NO_FOCUS_TRAPS=PASS
```

## Data-integrity acceptance

```text
FABRICATED_MAX_CAPACITY=PASS_ABSENT
FABRICATED_CYCLE_COUNT=PASS_ABSENT
FABRICATED_BATTERY_AGE=PASS_ABSENT
DERIVED_VALUES_LABEL_SOURCE_CONFIDENCE=PASS
UNAVAILABLE_STATE=PASS
DEVICE_CAPABILITY_INHERITANCE=PASS_ABSENT
```

## Security/privacy acceptance

```text
NETWORK_REQUIRED=NO
CLOUD_ANALYTICS=NO
RAW_SYSFS_COMMON_UI_WRITE=NO
UNQUALIFIED_CHARGING_MUTATION=NO
EXPORT_USER_INITIATED=YES
EXPORT_REDACTION_REQUIRED=YES
```

## Repository ownership

Current design authority:

```text
sableos-project/platform_sable
```

Current public organization roadmap/index:

```text
sableos-project/.github
```

Private integration, qualification and pending implementation:

```text
aimindseye/sableos
```

There is currently no dedicated public Sable Settings source repository in the
organization. Do not invent one merely for this design change. Before BH1
implementation, explicitly decide whether the Android Settings source delta
remains private integration/patch work or warrants a normal public platform
Settings role repository.

## Scheduling

Battery implementation is intentionally non-blocking for:

- Titan 2 N1I cellular closure;
- recovery/boot/radio qualification;
- the active P1-P5 product trains;
- existing KF-A..D implementation assignments.

Recommended pending sequence:

```text
current Titan / P1-P5 qualification
 -> existing KF-D / KF-A / KF-B assignments
 -> BH1-BH4 read-only Battery experience
 -> BH5 capability discovery in parallel
 -> BH6 only where backend qualification passes
 -> BH7 physical qualification
```

This sequencing may be adjusted when a developer is assigned, but BH6 must never
be pulled forward ahead of capability/backend proof.

## Definition of design-to-implementation handoff

```text
PUBLIC_DESIGN_MERGED=YES
VISUAL_ARTIFACT_MERGED=YES
ROADMAP_ENTRY_MERGED=YES
IMPLEMENTATION_OWNER_ASSIGNED=YES
SETTINGS_SOURCE_OWNER_SELECTED=YES
BH1_BASE_HEAD_FROZEN=YES
```

Until then:

```text
BATTERY_IMPLEMENTATION=PLANNED
BATTERY_DEVICE_MUTATION=NOT_AUTHORIZED
BATTERY_CHARGING_CONTROL=NOT_AUTHORIZED
```
