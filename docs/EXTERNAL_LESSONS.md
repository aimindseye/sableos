# External Lessons: MarathonOS Review

## Purpose

SableOS studies other mobile OS projects for product and systems-engineering ideas without importing their trust model uncritically.

## Ideas Worth Borrowing

### Mobile-first Product Direction

Useful areas to investigate later:

- gesture-first navigation;
- unified communication/notification hub;
- live task previews;
- fast peek/return workflows;
- physical-keyboard-aware interaction.

### Measurement-driven Power Work

Adopt:

```text
measure -> change -> remeasure -> keep/revert
```

for thermal, CPU, modem, memory and standby tuning.

### Device Layering

Maintain separation between:

- generic Sable platform services;
- Android compatibility integration;
- bramble-specific behavior.

### Recovery as a Product Feature

Continue treating A/B rollback, recovery visibility and bounded diagnostics as product architecture.

### Immutable-image Awareness

Runtime configuration assumptions must be validated against the actual image/boot model.

## Ideas Not to Copy Directly

### Shell as Privilege Aggregator

Sable should retain:

```text
UI -> typed Sable service -> platform/framework/HAL
```

rather than putting broad hardware/system privilege in the shell.

### Broad Capabilities on General-purpose Utilities

A narrow privileged service is preferable to giving a generic tool a broad capability for one UI feature.

### Release Shortcuts in Production

Development convenience must be separated from release procedure. Avoid untrusted package installation, throwaway signing, embedded developer credentials, personal SSH access, password helper files, and unpinned source heads.

### Disabled Tests for Core Components

If a core component cannot run its normal test phase, make the exception explicit and compensate with a defined gate.

## Resulting Sable Decisions

1. Keep UI unprivileged relative to hardware services.
2. Continue typed AIDL/service boundaries.
3. Require explicit client SELinux authorization.
4. Build lifecycle/resource policy as dedicated platform logic.
5. Use real device measurements for tuning.
6. Preserve device layering.
7. Treat recovery and immutable-image behavior as architecture.
8. Borrow mobile UX ideas independently from privilege design.
