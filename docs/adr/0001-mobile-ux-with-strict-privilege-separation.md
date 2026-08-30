# ADR-0001: Mobile-first UX With Strict Privilege Separation

Status: Accepted

## Context

SableOS wants a distinct mobile interaction model and studies other mobile systems for gesture navigation, application lifecycle, task switching, notification aggregation and power-management ideas.

SableOS has strong Android security primitives available: SELinux, Binder/AIDL, framework/HAL services, and A/B verified deployment.

## Decision

SableOS separates product UX from hardware/system privilege.

```text
Sable UI
    |
    | typed IPC
    v
narrow Sable platform service
    |
    | Android framework / HAL
    v
hardware authority
```

Rejected as default architecture:

- UI direct sysfs writes;
- UI-owned Health HAL;
- broad capabilities on generic command-line tools;
- generic privileged-command IPC;
- privilege granted solely because a feature is displayed in the shell.

## Consequences

Positive:

- smaller attack surface;
- cleaner SELinux review;
- backend replacement without UI redesign;
- independent service testing;
- UI crashes do not disable hardware observation;
- authorization can be tested negatively.

Costs:

- more upfront API/service work;
- explicit versioning;
- additional policy/runtime tests.

## Applied Example

```text
Health HAL 2.1
 -> callback bridge
 -> Rust PowerMonitor
 -> PowerStateStore
 -> frozen read-only AIDL
 -> authorized client
```

The UI does not need battery sysfs or Health HAL permission.

## Future Application

Apply the same rule to connectivity power policy, modem controls, lifecycle/resource policy, display policy, privileged diagnostics and recovery controls.
