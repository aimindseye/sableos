# SableOS roadmap

## Roadmap rule

SableOS advances through independently testable security and capability gates.

A milestone is complete only when implementation, policy boundary, build integration, generated artifacts, image composition and relevant physical behavior are validated. New security features must not silently remove working Android capability.

Portable semantic contracts and Rust logic should remain stable while Android-version/device integration is requalified behind bounded adapters.

## Milestone progression

```text
hardware correctness
    -> service correctness
    -> typed platform API
    -> authorized consumers
    -> lifecycle / policy
    -> measured resource policy
    -> mobile UX
```

A later layer must not paper over an unproven earlier layer.

## S0 — Android 14 security baseline uplift

Status: **established**.

Goal: move the bramble development substrate from Android 12.1 to the final official Android 14 baseline while keeping vanilla AOSP capability measurable.

Key outcomes:

- Android 14 source/vendor baseline;
- vanilla comparison point;
- explicit bramble end-of-life security ceiling;
- substrate used by current S1 development.

## S1 — narrow Sable services on Android 14

Goal: restore and evolve Sable-owned Rust services without weakening Android partition, SELinux, framework, or immutable vendor boundaries.

### S1.1 — oxynoded Android 14 integration

Status: **PASS**.

- `system_ext` Rust daemon;
- dedicated SELinux domain;
- Sable-owned product integration;
- no shell hardware privilege.

### S1.2 — semantic power contract migration

Status: **PASS**.

- retained typed semantic power state;
- portable host-testable mapper;
- separation between Sable semantics and physical backend.

### S1.3 — Health-backed power integration

Status: **PASS**.

The original vendor-helper plan was superseded after image audit proved `bramble` uses an immutable byte-for-byte Google prebuilt `vendor.img`.

Final architecture:

```text
vendor Health HAL / battery sysfs
        -> Health HIDL 2.1
        -> native bridge
        -> Rust HealthBackend / PowerState
```

Outcomes:

- `sable-powerd` retired;
- vendor image retained immutable;
- `oxynoded` gains Health-client permission, not battery sysfs;
- Sable power-source semantics tested and frozen.

### S1.4 — production Health monitoring

Status: **PASS**.

- normal init startup monitoring;
- nonfatal Health failures;
- stable retry behavior;
- physical runtime proof.

### S1.5 — production cleanup / logging

Status: **PASS**.

- removed diagnostic CLI scaffolding from production path;
- migrated logs to Android liblog;
- preserved Health semantics and SELinux boundary.

### S1.6 — callback-driven power monitoring

Status: **PASS**.

- physical testing proved steady polling can miss a real Battery state across suspend;
- Health callback feasibility proven via VTS;
- production poller removed;
- callback-time bounded snapshot queue added;
- HIDL RPC callback transport configured;
- HAL-death recovery added;
- unplug/reconnect proven while dozing without sampler/wakelock/synthetic state;
- valid `Battery -> Unknown -> AC` reconnect semantics accepted;
- closure had zero power read errors, relevant AVC denials, or daemon crashes.

### S1.7A — frozen read-only power API

Status: **PASS**.

Goal: expose latest validated `PowerState` through frozen AIDL V1 while keeping Health ownership inside `oxynoded`.

Frozen contract:

```text
com.sableos.power.IPowerService/default
    getLatestState() -> PowerSnapshot
```

V1 properties:

- read-only;
- availability;
- battery percentage;
- charging state;
- stable Sable source enum;
- monotonic externally-visible state-change sequence;
- no Health handle;
- no sysfs path;
- no mutation methods.

Validated closure:

- AIDL V1 frozen and ownerless on the Android 14 release graph;
- generated Rust AIDL dylib installed in `system_ext`, with no direct `/system/lib{,64}` Sable AIDL target;
- 31 host tests pass, including `PowerStateStore` availability/sequence semantics;
- affected and full product builds pass with compiled SELinux/neverallow checks;
- exact provider and generated AIDL library content verified in `system_ext.img`;
- stable-AIDL/SELinux propagation into `system`, `product`, vendor ramdisk and AVB metadata was classified rather than treated as an unexplained image delta;
- provider/API host seal closed before S1.7B client authorization was introduced.

### S1.7B — authorized consumer runtime proof

Status: **PASS**.

- dedicated `sable_power_test_client` domain and disabled oneshot test client;
- intended client can `find` the service and Binder-call `oxynoded`;
- client has no Health HAL or battery-sysfs authority;
- Android 14 shell can discover the service name through broad platform `service_manager_type` `find`, but cannot trigger the privileged client and is denied Binder `call` to `oxynoded` under enforcing SELinux;
- provider remains stable through authorized and denied-client tests;
- inactive slot A received the validated six-image S1.7 deployment, with activation last and slot B preserved as successful S1.6 fallback;
- slot A became naturally successful without manual success marking;
- physical unplug/reconnect while dozing produced callback-driven `Usb -> Battery -> Unknown -> Ac` state changes with no read errors, relevant AVCs, synthetic overrides or daemon wakelock;
- AIDL sequence advanced from `1` to `7`, exactly matching six externally visible callback state changes with the same `oxynoded` PID.

S1.7 overall status: **PASS / FROZEN**. Exact source, AIDL, image, device-binary and runtime seals are recorded in `S1_7_VALIDATION.md`.

### S1.8 — power UX integration

Status: **PLANNED**.

- first user-facing read-only power client;
- battery percentage, charging and source;
- graceful unavailable state;
- no backend-specific UI logic;
- UI restart cannot disturb monitoring;
- UI compromise does not become Health ownership.

### S1.9 — application lifecycle foundation

Status: **PLANNED**.

- explicit foreground/background state;
- process importance;
- bounded background execution;
- lifecycle event logging;
- policy hooks for later freezer/uclamp work.

No device-specific CPU tuning in this milestone.

### S1.10 — measured resource policy

Status: **PLANNED**.

Candidate areas:

- memory pressure;
- background process freezing;
- uclamp/scheduler hints through appropriate Android mechanisms;
- modem/Wi-Fi standby;
- display idle;
- thermal/wakeup accounting.

Required before/after evidence:

- power/current proxy;
- wakeup/interrupt rate;
- CPU residency;
- temperature;
- memory pressure;
- app launch and interaction latency;
- idle and active regressions;
- rollback criteria.

No tuning knob lands on folklore alone.

### S1.11 — connectivity policy services

Status: **PLANNED**.

Preferred:

```text
UI -> narrow typed request -> Sable connectivity service -> Android framework
```

Rejected:

```text
UI -> broad-capability general-purpose network utility
```

### S1.12 — recovery and diagnostics surface

Status: **PLANNED**.

- safe recovery workflow;
- bounded diagnostics;
- slot/fallback visibility;
- service-health reporting;
- no normal recovery bypass of SELinux/verified boot.

## Android substrate transition track

### A14 — current architecture baseline

Android 14 on bramble remains the architecture/regression baseline. The S1.7 power service/API/runtime boundary is closed and frozen; later S1 milestones continue on this baseline unless a deliberate portability experiment says otherwise.

### A15 — bramble portability experiment

After S1 architecture is stable:

- establish vanilla/upstream Android 15 baseline first;
- measure hardware/telephony/app parity;
- reintroduce minimum Sable integration;
- identify Android-version-specific SELinux/build/init/framework hooks;
- prove common semantic APIs do not require redesign;
- stop rather than globally weakening security if frozen vendor/HAL incompatibility dominates.

This is an engineering qualification target, not restored OEM security support.

### A16+ — maintained modern Pixel-class touch baseline

Move modern touch/security reference to actively supported hardware subject to source, bootloader, vendor, relock/update and physical capability acceptance.

## S2 — Secure Package Intelligence

Goal: preserve standard Android APK compatibility while making increases in application authority visible and reviewable.

### S2.1 package analyzer

Local deterministic analysis of permissions, signing identity, SDK levels, exported components, special accesses, debuggable/test-only state, cleartext policy, native code, and known tracker/library signals.

### S2.2 update delta engine

Compare installed/incoming permissions, signing lineage, components, SDK, libraries and elevated capabilities.

### S2.3 Secure Install UI

Explain findings as informational/review/elevated/critical/privacy signals without claiming certainty about whether an app "needs" a permission.

### S2.4 PackageManager enforcement

Put mandatory security-review enforcement below installer UI so alternate stores cannot bypass it.

### S2.5 PermissionController integration

Preserve contextual Android runtime permission prompts while adding relevant Sable context.

### S2.6 unified permission/AppOps view

Present real enforcement state without hiding the distinction between runtime permissions and AppOps.

### S2.7 local tracker/library intelligence

Optional local signatures; treat matches as signals rather than proof of malicious behavior.

### S2.8 special-access/exported-component analysis

Prioritize accessibility, notification listeners, VPN, device admin, overlays, package installation, all-files access, background location, boot/background execution, and unprotected exports.

### S2.9 compatibility regression corpus

Continuously test representative open-source, Play-dependent, banking/DRM, split APK, accessibility, VPN, notifications, camera/location/media, and background-execution cases.

### S2.10 Install Quarantine research

Research optional quarantine for newly installed high-risk packages only after PackageManager/ActivityManager semantics can support it without bypasses.

## S3 — ecosystem compatibility without ambient trust

- multi-source standard Android installation converging on the same enforcement path;
- optional sandboxed Google compatibility as ordinary user applications where maintainable;
- integrity/DRM compatibility reporting separate from APK compatibility;
- per-app compatibility exceptions instead of global hardening rollback.

## S4 — user-facing capability hardening

- semantic per-app Network capability including meaningful indirect paths;
- Storage Scopes;
- Contact Scopes;
- sensor/local-network scopes where enforceable;
- profile-centered trust separation.

## S5 — production security posture

- Sable release keys and locked verified boot;
- signed OTA/update infrastructure and rollback handling;
- provenance / SBOM / source lineage;
- rapid Browser/WebView security channel;
- physical attack-surface controls such as USB restriction and secure auto-reboot where hardware supports them.

## Mobile UX track

Once service boundaries are stable, explore a distinct mobile interaction model rather than merely cloning stock Android or adapting a desktop shell.

Potential themes:

- gesture-first navigation;
- unified communication/notification hub;
- persistent live task previews;
- fast peek/return workflows;
- physical-keyboard-aware interaction;
- explicit lifecycle visualization;
- low-latency transitions.

These are product ideas, not privilege justifications.

## Device roadmap

### Pixel 4a 5G (`bramble`)

Architecture/regression reference. Android 14 primary Sable substrate; Android 15 portability experiment candidate; not a long-lived production-security target.

### Modern Pixel-class hardware

Successor maintained touch/security reference for Android 16+ work, subject to source, flashing/relock, vendor and update-lifecycle acceptance.

### Zinwa Q25

Optional MediaTek/QWERTY development reference for portability validation; not required for SableOS or Q27 support.

### Zinwa Q27

Future primary QWERTY candidate pending public/maintainable source, reliable unlock/recovery, understood partitions/vendor interfaces, working radio/IMS/camera/audio/keyboard/suspend/power, and acceptable security lifecycle.

## Standing priorities

1. preserve standard Android app compatibility;
2. preserve working telephony/camera/audio/connectivity unless removal is intentional and documented;
3. do not bypass SELinux `neverallow` or platform boundaries for convenience;
4. do not make the Sable shell a privileged universal client;
5. prefer narrow semantic services and app-scoped exceptions;
6. keep compatibility software unprivileged wherever possible;
7. make security UI correspond to real enforceable behavior;
8. prefer local analysis/provenance over unnecessary telemetry;
9. include negative tests proving what a component cannot access;
10. treat device/vendor/firmware support lifetime as part of the security model;
11. keep Android-release integration bounded so Sable core semantics survive upgrades;
12. use MediaTek/QWERTY ports to prove portability, not create separate forks;
13. require measured evidence for power/performance tuning;
14. preserve a known-good fallback slot during runtime-changing deployment.

## Runtime milestone closure

```text
source guards
 -> targeted tests
 -> affected build
 -> generated-artifact audit
 -> security-policy audit
 -> full product build
 -> exact binary/image proof
 -> AVB validation
 -> inactive-slot deployment
 -> runtime/physical proof
 -> natural slot success
 -> fallback preserved
```
