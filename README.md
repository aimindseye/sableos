# SableOS

SableOS is an experimental privacy- and security-focused mobile OS with a Rust-first userspace architecture, narrow privilege boundaries, and one common core across different hardware and interaction profiles.

The project is not intended to become a collection of unrelated device ROMs. Hardware-specific behavior belongs in adapters; form-factor-specific behavior belongs in interaction profiles; common application and service semantics should remain shared wherever practical.

SableOS is also not intended to discard mature Android capability merely to minimize inherited code. Privacy and security come first while proven AOSP/vendor functionality is preserved wherever it can be reused safely.

## Core rules

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven AOSP/vendor capability unless there is a demonstrated privacy, security, performance, maintainability, or architectural reason to replace it.

> The shell may observe and request; privileged services decide and execute.

> Platform security boundaries are design constraints to understand first, not obstacles to disable for convenience.

> Standard Android applications remain standard Android applications; SableOS adds policy and containment around the Android app model rather than requiring a Sable-specific package ecosystem.

Minimalism means minimal privilege, attack surface, unnecessary background activity, data collection, duplicated implementation, and UI complexity — not needless reinvention of working platform functionality.

## Current reference target

- Device: Google Pixel 4a 5G G025E
- AOSP device codename: `bramble`
- SoC: Qualcomm Snapdragon 765G / SM7250
- GPU: Adreno 620
- Current substrate: Android 14 / `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Current Sable product: `sable_bramble_s1-userdebug`
- Current Sable build output: `out_s13b`

`bramble` is now an end-of-life reference/development device. Android 14 materially improves the development substrate over the prior Android 12.1 baseline, but it does not remove the security ceiling created by unsupported closed firmware/vendor components.

## Current milestone: S1 — narrow Sable services on Android 14

S1 reintroduces Sable-owned Rust services on top of the validated Android 14 bramble substrate without weakening Android partition, SELinux or vendor/platform boundaries.

### S1.1 — oxynoded Android 14 integration

The Sable Android 14 product retains `oxynoded` as a `system_ext` Rust daemon with Sable-owned private SELinux policy.

The service layer remains separate from raw device access.

### S1.2 — semantic power contract migration

The typed read-only semantic operation:

```text
power.read_state
```

and the host-testable power mapper are retained from the Android 12 B2 work.

### S1.3 — vendor power-observation helper

S1.3 introduces `sable-powerd` as a narrow vendor-side helper for read-only battery/power-source observation.

Validated so far:

- `sable-powerd` and its init RC build successfully as vendor modules;
- the product packages both modules only for the Sable product;
- vanilla `aosp_bramble` does not inherit Sable vendor policy;
- the helper runs in a dedicated `sable_powerd` vendor SELinux domain;
- `/vendor/bin/sable-powerd` is labeled `sable_powerd_exec`;
- policy permits read-only `sysfs_batteryinfo` access and generic sysfs directory traversal, without generic sysfs file write access;
- SELinux compilation and `sepolicy_test` pass;
- `vendor.img` packages the daemon, init RC and compiled policy successfully;
- the service remains `disabled` until controlled runtime validation.

The full Sable product build/integrity gate is the current closure point before physical runtime validation.

See `docs/ROADMAP.md` for the staged Sable roadmap.

## Prior Android 14 baseline milestone

### S0 — security baseline uplift

S0 moved the `bramble` reference target from the July 2022 Android 12.1 baseline to the final official Android 14 AOSP baseline before Sable services were ported back.

The transition established:

1. a final official Android 14 `bramble` substrate;
2. a clean vanilla comparison point before restoring Sable source;
3. the basis for reviewing additional hardening ideas from AOSP, GrapheneOS and other security work.

See the S0 validation records under `docs/`.

## Prior Android 12 milestones

The Android 12 work remains useful architectural and physical-validation evidence even though production development has moved to Android 14.

### B0 — vanilla physical baseline passed

Vanilla Android 12.1 AOSP was physically validated on the G025E, including cellular Internet, inbound/outbound voice, SMS/MMS, audio paths, LTE and available 5G/NR behavior.

### B1 — native Rust validation passed

B1 proved native Rust compilation/packaging and retained the known-good Google/Qualcomm hardware and radio stack.

### B1.1 — init + dedicated SELinux domain passed

B1.1 is physically validated and its Gold Master is frozen.

It proved that `oxynoded` could:

- start automatically through Android init;
- run as UID/GID `system`, not root;
- run in dedicated SELinux domain `u:r:oxynoded:s0`;
- keep SELinux enforcing;
- run with zero Linux capabilities;
- survive reboot;
- preserve hardware and telephony capability parity;
- avoid broad radio, Binder, network, HAL, service-manager or device-node privilege.

See `docs/B1_1_VALIDATION.md`.

### B2 — first narrow semantic hardware service

B2 introduced the typed read-only semantic operation:

```text
power.read_state
```

B2.0 through B2.4 passed their semantic/host/build gates. B2.5P proved the intended vendor-side privileged-helper architecture and policy/build bridge on Android 12.1. The later complete-image gate exposed Android-12 product-packaging behavior that placed the helper in the wrong final partition despite vendor module metadata.

Rather than spending more effort on a legacy build-system workaround, physical B2 completion was intentionally superseded by S0. The semantic contract, mapper logic, tests and narrow service/helper boundary are retained for the Android 14 port; Android-12-specific packaging mechanics are not assumed to carry forward.

See `docs/B2_POWER_READ_STATE.md`, `docs/B2_POWER_BACKEND_DECISION.md` and the B2 validation records.

## Architecture

SableOS keeps presentation, semantic services, Android/AOSP substrate and device/vendor adaptation as separate trust and portability layers.

```text
Sable shell / applications
        ↓
typed semantic Sable APIs
        ↓
narrow Rust services / brokers
        ↓
SELinux + capability policy
        ↓
AOSP framework / supported HAL / vendor stack
        ↓
hardware
```

The shell must not gain a privileged hardware/security interface merely because it presents a control for that feature.

See `docs/ARCHITECTURE.md`.

## AOSP capability policy

SableOS classifies inherited functionality as:

- **foundation** — retain and harden mature platform capability;
- **compatibility** — retain when useful, but isolate and grant only required data/privilege;
- **replacement candidate** — Sable-owned presentation/policy where replacement has a clear benefit while useful lower layers remain available.

Before removing an AOSP, LineageOS or vendor component, identify the capability it provides, its dependencies/data flows/privileges, whether unwanted behavior can be constrained, and whether a replacement has proven physical-device capability parity.

A milestone must not silently lose working baseline functionality. Intentional removals are explicit product decisions with documented rationale.

See `docs/AOSP_CAPABILITY_POLICY.md`.

## Security references

AOSP remains the normative platform/security reference for Android architecture, SELinux, verified boot, build behavior and device integration.

GrapheneOS is a primary additional security-engineering reference. SableOS should learn from its attack-surface reduction, compatibility-without-privilege approach, capability enforcement, exploit mitigations, verified-boot/attestation posture, update discipline and explicit device-lifecycle security model.

SableOS does not aim to become a GrapheneOS fork or copy its product architecture. Each security idea is evaluated against the selected AOSP baseline, target hardware, Sable trust boundaries, independent testability and maintenance cost.

Security-delta classifications are:

```text
ALREADY_UPSTREAM
ADOPT
ADAPT_FOR_SABLE
HARDWARE_UNAVAILABLE
NOT_RELEVANT
DEFER
```

See `docs/SECURITY_REFERENCE_GRAPHENEOS.md`.

## Android application compatibility and Secure Package Intelligence

SableOS intends to preserve broad Android application availability.

The OS should continue using the standard Android package format, PackageInstaller/PackageManager path, ART runtime, app sandbox, permissions and AppOps. Applications should not require a Sable-specific package format or Sable rebuild merely to run.

User-authorized application sources can include:

- direct APK/split-APK installation;
- F-Droid-compatible clients;
- other Android application stores;
- optional Google Play Store support through a future sandboxed compatibility layer;
- developer/ADB installation when explicitly enabled.

Application source and application trust are separate. Every source should converge on the same package verification and Sable security-policy path.

Planned **Secure Package Intelligence** work will add local, explainable security review for installation and updates, including:

- permission and special-capability inspection;
- signing identity and signing-lineage presentation;
- permission/component/SDK/signing deltas across updates;
- exported-component analysis;
- accessibility/VPN/device-admin/notification-listener and similar elevated capability review;
- local tracker/library privacy signals;
- PermissionController/AppOps integration;
- mandatory review for material increases in application authority without forcing low-risk updates through excessive prompts.

SableOS must not claim it can know with certainty whether a requested permission is "needed" by an application. It should instead provide evidence, classify sensitive/unusual authority and let enforceable policy remain explicit.

See `docs/APP_SECURITY_AND_COMPATIBILITY.md` and `docs/ROADMAP.md`.

## Additional hardening direction

High-value future work includes:

- user-facing per-app Network denial with direct and indirect path enforcement;
- storage and contact scopes for compatibility-preserving least privilege;
- profile-centered trust separation for applications and optional compatibility services;
- per-app exploit-protection compatibility exceptions instead of global weakening;
- rapid independent Browser/WebView security updates;
- locked verified boot with Sable-owned release keys on supported production hardware;
- signed OTA/update infrastructure and rollback protection;
- release provenance/SBOM discipline;
- USB data restriction while locked on capable hardware;
- secure auto-reboot back to Before First Unlock state after inactivity;
- application compatibility regression testing across open-source, Play-dependent, banking/DRM and hardware-integrated use cases.

These are staged after the current S1 service-port work rather than mixed into the active S1.3 boundary validation.

## Interaction profiles

SableOS does not require radically different form factors to use one slab-phone UI.

### Touch-first

The Pixel reference experience is touch-first with a Metro-inspired direction: strong typography, simple geometry, glanceable information, low chrome and fast gesture navigation.

### Keyboard-first

Physical-QWERTY devices use a keyboard-first profile built around focus navigation, shortcuts, type-to-search, command routing, dense information presentation, and touch/keyboard coexistence.

See `docs/INTERACTION_PROFILES.md`.

## Device roadmap

### Google Pixel 4a 5G G025E (`bramble`)

Status: **architecture/regression reference; Android 14 S1 development target**.

- Android 12 B0/B1/B1.1 physical gates: passed
- B2 semantic/service architecture: retained
- Android 14 S0 baseline uplift: established
- Android 14 S1 service reintroduction: current
- production-security limitation: end-of-life firmware/vendor support ceiling

### Pixel 7

Status: **future modern touch reference candidate**.

A newer supported security baseline is required before SableOS can make meaningful production-security claims beyond architecture/development work on `bramble`.

### Zinwa Q25

Status: **planned/optional port; not yet supported**.

Q25 remains useful as a MediaTek/QWERTY architecture study if source, unlock and hardware availability justify the port.

See `docs/Q25_PORT_PLAN.md`.

### Zinwa Q27

Status: **future physical-QWERTY target pending hardware/source acceptance**.

Q27 must pass source availability, bootloader/unlock, flashing, vendor-interface and physical hardware acceptance before SableOS assumes support. If accepted, it should reuse the common Sable core and keyboard-first interaction framework rather than become a separate OS fork.

## Telephony rule

SableOS preserves the supported vendor modem path.

On Qualcomm this means retaining the Google/Qualcomm Radio HAL, QCRIL, IMS and modem firmware stack. On MediaTek targets it means retaining Android Radio HIDL/AIDL plus the supported MediaTek vendor RIL/IMS stack.

A future Rust telephony broker must use narrow supported Android/vendor interfaces. It must not talk directly to raw modem sockets or implement a replacement modem protocol.

## Automotive / Android compatibility

SableOS should retain Android media, Bluetooth, Telecom, notification, navigation/location, audio-routing, USB/networking and related semantics that enable automotive and accessory interoperability.

The core OS must not depend on proprietary Google components. Third-party/proprietary compatibility layers should be optional and tightly sandboxed with explicit access only to the data/capabilities actually required and enabled by the user.

The goal is reuse without surrendering privacy/security control.

## Repository layout

```text
device/sable/bramble/        Sable bramble service/product source and historical integration
patches/                     Minimal AOSP patches/backports required by pinned bases
docs/                        Architecture, security, build, validation and porting notes
```

Generated Android images, proprietary vendor archives, firmware blobs and target-files ZIPs are intentionally not committed to this repository.

## Documentation

- `docs/ROADMAP.md` — staged S0–S5 service, app-security, compatibility and production-security roadmap
- `docs/ARCHITECTURE.md` — common-core, hardware-adapter, security and telephony architecture
- `docs/AOSP_CAPABILITY_POLICY.md` — preserve/remove/replacement, compatibility, parity and privacy/security gates
- `docs/APP_SECURITY_AND_COMPATIBILITY.md` — standard Android APK compatibility, Secure Package Intelligence and app-source policy
- `docs/SECURITY_REFERENCE_GRAPHENEOS.md` — GrapheneOS lessons, Sable security-delta categories and adoption discipline
- `docs/INTERACTION_PROFILES.md` — touch-first and keyboard-first UI/input design
- `docs/Q25_PORT_PLAN.md` — planned MediaTek/QWERTY port methodology
- `docs/S0_2_VALIDATION.md` — Android 14 source-transition validation
- `docs/B1_VALIDATION.md` — B1 build and physical validation record
- `docs/B1_1_VALIDATION.md` — completed B1.1 SELinux/physical validation record
- `docs/B2_POWER_READ_STATE.md` — B2 semantic API/backend plan and evidence
- `docs/B2_POWER_BACKEND_DECISION.md` — B2 backend boundary decision
- `docs/G025E_HARDWARE_ACCEPTANCE.md` — factory/unlock/safe-flash hardware acceptance runbook
