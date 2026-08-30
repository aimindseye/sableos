# SableOS roadmap

## Roadmap rule

SableOS advances through independently testable security and capability gates.

A milestone is complete only when its implementation, policy boundary, build integration and relevant physical-device behavior are validated. New security features must not silently remove working Android capability.

## S0 — Android 14 security baseline uplift

Goal: move the bramble development substrate from the prior Android 12.1 baseline to the final official Android 14 baseline while keeping vanilla AOSP capability measurable.

Key objectives:

- validated Android 14 source/vendor baseline;
- vanilla build and physical capability reference;
- explicit bramble end-of-life security ceiling;
- preserve a clean comparison point before reintroducing Sable services.

Status: baseline uplift work established the Android 14 substrate used by current S1 development.

## S1 — reintroduce narrow Sable services on Android 14

Goal: restore Sable-owned Rust services without weakening Android 14 partition, SELinux or vendor/platform boundaries.

### S1.1 — oxynoded Android 14 integration

- system_ext Rust daemon;
- dedicated SELinux domain;
- Sable-owned product integration;
- no raw hardware privilege in the shell/service layer.

### S1.2 — semantic power contract migration

- retain the typed `power.read_state` contract;
- preserve the separation between semantic policy and physical device access;
- reuse host-testable mapper logic.

### S1.3 — vendor power-observation helper

- `sable-powerd` packaged under `/vendor`;
- dedicated vendor SELinux domain;
- read-only `sysfs_batteryinfo` access;
- no generic sysfs file writes, networking, Binder service privilege or device-node authority;
- helper remains disabled until controlled runtime validation;
- compile-only SELinux and vendor-image packaging gates passed before device runtime work;
- full product build/integrity gate is the next closure point before controlled physical validation.

## S2 — Secure Package Intelligence

Goal: keep full ordinary Android APK compatibility while making increases in application authority visible and reviewable.

Design reference: `docs/APP_SECURITY_AND_COMPATIBILITY.md`.

### S2.1 — package security analyzer

Implement a local, deterministic analyzer for:

- requested permissions/protection levels;
- signing identity;
- target/min SDK;
- exported components;
- special-access declarations;
- debuggable/test-only state;
- cleartext policy;
- native-code presence;
- known tracker/library signals.

No opaque AI trust score is required for the first implementation.

### S2.2 — update delta engine

Compare installed and incoming package state for:

- permissions added/removed;
- signing identity/lineage;
- components added/removed/exported;
- target SDK changes;
- tracker/library changes;
- elevated capability changes.

Unchanged updates should remain low-friction.

### S2.3 — Sable Secure Install UI

Add an install/update security review which presents explainable findings as:

- Informational;
- Review;
- Elevated;
- Critical;
- Privacy signal.

Do not claim that Sable can determine with certainty whether a permission is "needed" by an application.

### S2.4 — PackageManager enforcement

Move mandatory-review enforcement below installer UI so alternate stores/installers cannot bypass security-sensitive update review.

Preserve standard Android package formats, PackageInstaller sessions and installer-of-record semantics.

### S2.5 — PermissionController integration

Preserve contextual Android runtime permission prompts while adding relevant Sable security context.

Sensitive runtime permissions should normally begin ungranted and be requested when used rather than pre-granted during installation.

### S2.6 — unified permission/AppOps capability view

Present real enforcement state for capabilities such as location, microphone and camera without hiding the distinction between runtime permission and AppOps enforcement.

### S2.7 — local tracker/library intelligence

Maintain an optional local signature dataset for tracker/analytics/library signals.

Treat matches as privacy/security signals rather than proof of malicious behavior.

### S2.8 — exported-component and special-access analysis

Prioritize changes involving:

- accessibility;
- notification listeners;
- VPN;
- device admin;
- overlays;
- package installation;
- all-files access;
- background location;
- boot/background execution;
- exported unprotected components.

### S2.9 — compatibility regression corpus

Continuously test representative applications across:

- F-Droid/open-source applications;
- Play-dependent applications;
- split APK/app bundle delivery;
- banking/DRM/integrity-check edge cases;
- accessibility;
- VPN;
- notifications/push;
- camera/location/media;
- background execution.

### S2.10 — Install Quarantine research

Research an optional state where a newly installed high-risk package cannot launch or automatically execute until the user completes security review.

This is deferred until PackageManager and ActivityManager semantics can be changed without creating bypasses or compatibility regressions.

## S3 — Android ecosystem compatibility without ambient trust

Goal: allow users broad Android application availability without making external ecosystems trusted OS components.

### S3.1 — multi-source standard APK installation

Support ordinary user-authorized Android installation paths for:

- direct APK/split APK installation;
- F-Droid-compatible clients;
- other Android stores;
- ADB/developer installation when explicitly enabled.

Every source converges on the same package verification and Sable security-policy enforcement path.

### S3.2 — optional sandboxed Google compatibility

Evaluate and implement, where maintainable, an optional compatibility layer allowing official Google Play services / Play Store applications to run as ordinary sandboxed user applications rather than privileged system components.

Requirements:

- not bundled as a trusted Sable dependency;
- ordinary app sandbox by default;
- explicit user permissions;
- profile-scoped availability;
- no ambient access to Sable services;
- narrow documented compatibility shims only where necessary;
- explicit documentation for functionality that cannot be safely reproduced without privilege.

### S3.3 — application integrity compatibility reporting

Document separately from APK compatibility the applications which reject alternate operating systems due to Play Integrity, banking anti-tamper, proprietary certification, DRM or device-attestation policy.

Sable should not weaken verified boot, app sandboxing or platform integrity merely to spoof acceptance by third-party applications.

### S3.4 — per-app compatibility exceptions

Where Sable hardening exposes an app defect, prefer a visible per-app compatibility exception over globally weakening exploit mitigations or security policy.

## S4 — user-facing capability hardening

Goal: extend least-privilege controls while maintaining application usability.

### S4.1 — per-app Network capability

Evaluate a user-facing network denial that blocks direct sockets and meaningful indirect network paths through cooperating OS services.

A packet-only firewall is insufficient as the complete semantic boundary.

### S4.2 — Storage Scopes

Provide compatibility-preserving access to explicitly selected files/directories rather than broad shared-storage access where technically feasible.

### S4.3 — Contact Scopes

Allow applications to receive access only to selected contacts/contact fields rather than the complete contact database where technically feasible.

### S4.4 — sensor/local-network scopes

Evaluate narrow controls for sensor and local-network discovery capabilities where reliable Android/kernel enforcement exists.

### S4.5 — profile-centered trust separation

Make Android user/work/private profiles first-class Sable trust domains for separating applications, data and optional compatibility services.

## S5 — production security posture

Goal: move from a development/reference ROM to a release process capable of defensible production-security claims on supported hardware.

### S5.1 — Sable release keys and locked verified boot

- Sable-owned release signing;
- AVB verification;
- rollback protection;
- documented bootloader-lock/relock model;
- recovery/update trust chain.

### S5.2 — update infrastructure

- signed OTA pipeline;
- rapid Android security patch intake;
- kernel/vendor/firmware tracking;
- emergency release process;
- rollback/interrupted-update validation.

### S5.3 — software provenance

- reproducible/traceable release inputs where practical;
- signed build provenance;
- dependency and binary inventory/SBOM for release artifacts;
- auditable patch/source lineage.

### S5.4 — browser/WebView rapid update track

Treat browser and WebView security updates as an independent high-priority channel rather than waiting on broad OS feature milestones.

### S5.5 — physical attack-surface controls

Evaluate on supported hardware:

- USB data restriction while locked;
- secure auto-reboot / return to Before First Unlock state after inactivity;
- memory clearing around boot/recovery transitions;
- strong authentication options;
- hardware-backed keystore/attestation posture.

## Device roadmap relationship

`bramble` remains an architecture/regression target with an end-of-life firmware/vendor security ceiling.

Production-security milestones must be validated on hardware receiving active OEM firmware/vendor security maintenance. Future Pixel and other targets are accepted only after source, bootloader, flashing, vendor-interface, update-lifecycle and physical capability gates pass.

## Standing priorities

Across all milestones:

1. preserve standard Android application compatibility;
2. preserve working telephony/camera/audio/connectivity capability unless removal is intentional and documented;
3. do not bypass SELinux `neverallow` or similar platform boundaries for convenience;
4. do not make the Sable shell a privileged universal client;
5. prefer narrow semantic services and app-scoped exceptions;
6. keep compatibility software unprivileged wherever possible;
7. make security UI correspond to real enforceable behavior;
8. prefer local analysis and local provenance over unnecessary telemetry;
9. validate security features with negative tests proving what they cannot access;
10. treat device/vendor/firmware support lifetime as part of the security model.
