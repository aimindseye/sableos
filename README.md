# SableOS

SableOS is an experimental privacy- and security-focused mobile OS with a Rust-first userspace architecture, narrow privilege boundaries, and one common core across hardware and interaction profiles.

The project is not intended to become a collection of unrelated device ROMs. Hardware-specific behavior belongs behind adapters; form-factor-specific behavior belongs in interaction profiles; common application and service semantics should remain shared wherever practical.

Privacy and security come first, but SableOS does not discard mature Android/AOSP/vendor capability merely to reduce inherited code.

## Core rules

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven AOSP/vendor capability unless there is a demonstrated privacy, security, performance, maintainability, or architectural reason to replace it.

> The shell may observe and request; privileged services decide and execute.

> Platform security boundaries are design constraints to understand first, not obstacles to disable for convenience.

> Stable Sable semantic contracts should survive Android-version and device changes; substrate-specific behavior belongs behind bounded adapters.

Minimalism means minimal privilege, attack surface, unnecessary background activity, telemetry, duplicated implementation, and UI complexity—not needless reinvention of working platform functionality.

## Current reference target

- Device: Google Pixel 4a 5G (`bramble`)
- SoC: Qualcomm Snapdragon 765G / SM7250
- Current substrate: Android 14 / `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Sable product: `sable_bramble_s1-userdebug`
- Build output: `out_s13b`
- SELinux: enforcing in validated runtime gates

`bramble` is an end-of-life architecture/regression device. It remains useful for controlled development, but unsupported closed firmware/vendor components impose a production-security ceiling.

## Current milestone: S1.7 — typed power IPC — PASS

S1 has moved the power path from direct-sysfs concepts to a platform-compatible, callback-driven architecture and frozen the first read-only Sable power API.

### Proven S1.6 runtime baseline

```text
Android Health HAL 2.1
        |
        | healthInfoChanged_2_1 callback
        v
C++ callback bridge
        |
        | bounded callback-time snapshots
        v
Rust PowerMonitor
        |
        +-- INITIAL
        +-- CHANGED
        +-- ERROR / RECOVERED
        +-- unchanged suppressed
```

S1.6 is closed and runtime-proven:

- immutable Google bramble `vendor.img` retained;
- vendor Health HAL remains the battery/sysfs authority;
- `oxynoded` is a Health client, not a battery-sysfs reader;
- 60-second production polling was removed after physical testing proved it can miss transitions across suspend;
- HIDL callback delivery was proven with VTS and physical unplug/reconnect while the device was dozing;
- callback-time queueing preserves delivered transient states across scheduling gaps;
- HAL-death handling unblocks the Rust retry path;
- `Battery -> Unknown -> AC` is accepted as valid reconnect behavior when charging state settles before source flags;
- zero relevant AVC denials or daemon crashes in the closure test.

### S1.7 — frozen read-only power API and authorization proof

Status: **PASS**.

Frozen contract:

```text
com.sableos.power.IPowerService/default
    getLatestState() -> PowerSnapshot
```

The V1 API is intentionally narrow:

- read-only latest validated battery percentage / charging / source;
- explicit availability state;
- monotonic externally-visible state-change sequence;
- no Health handle;
- no raw sysfs;
- no setters or mutation methods.

The runtime trust boundary is now physically proven:

```text
Health HAL callback
    -> oxynoded / PowerMonitor
    -> PowerStateStore
    -> frozen AIDL V1
    -> dedicated sable_power_test_client
```

Validated S1.7 outcomes:

- frozen ownerless AIDL V1 with Rust backend installed in `system_ext`;
- 31 host tests pass;
- provider, client and generated AIDL library are byte-for-byte verified in the final image and on-device;
- dedicated `sable_power_test_client` can `find` and transact with `oxynoded`;
- the client has no Health HAL or battery-sysfs authority;
- ordinary Android shell may discover the Binder service name through platform service-manager policy, but cannot start the privileged test client and is denied Binder `call` to `oxynoded` under enforcing SELinux;
- inactive-slot deployment wrote the validated S1.7 image set to slot A and activated it only after all writes completed;
- slot A became naturally successful while slot B remained the known-good successful S1.6 fallback;
- physical unplug/reconnect while dozing produced `Usb -> Battery -> Unknown -> Ac` transitions without daemon restart, read errors, relevant AVCs, synthetic overrides or a daemon wakelock;
- AIDL state sequence advanced from `1` to `7`, exactly matching six externally visible callback state changes, with the same `oxynoded` PID throughout.

Exact source, AIDL, image, device-binary and runtime seals are recorded in `docs/S1_7_VALIDATION.md`.

Next planned milestone: S1.8 power UX integration, consuming the frozen V1 contract without moving Health ownership or hardware privilege into the UI.

## Architecture

```text
Sable shell / applications
        |
        | typed semantic IPC
        v
narrow Sable services / brokers
        |
        | SELinux + explicit capability policy
        v
AOSP framework / supported HAL / vendor stack
        |
        v
hardware
```

The shell does not gain a hardware/security privilege merely because it presents that feature.

Examples:

```text
preferred:
UI -> read PowerSnapshot -> read-only AIDL
UI -> request narrow policy operation -> dedicated service -> framework/HAL

rejected:
UI -> raw power sysfs
UI -> direct Health HAL
UI -> broad-capability general-purpose networking tool
UI -> generic privileged command executor
```

See `docs/ARCHITECTURE.md`, `docs/SECURITY_MODEL.md`, and `docs/adr/0001-mobile-ux-with-strict-privilege-separation.md`.

## Engineering and release discipline

Runtime milestones close on evidence, not compilation alone:

```text
source guards
 -> targeted tests
 -> affected build
 -> generated-artifact audit
 -> compiled policy audit
 -> full product build
 -> exact image proof
 -> AVB validation
 -> inactive-slot deployment
 -> runtime/physical proof
 -> natural slot success
 -> fallback preserved
```

Power, thermal, scheduler, memory, modem, and lifecycle tuning must be measurement-driven. A plausible explanation is not sufficient evidence.

See `docs/ENGINEERING_PRINCIPLES.md` and `docs/RELEASE_VALIDATION.md`.

## Product direction

SableOS should be mobile-first rather than a desktop shell adapted to a narrow display. Areas worth exploring after service boundaries are stable include:

- gesture-first navigation;
- unified communication/notification hub;
- live task previews;
- fast app switching / peek-return workflows;
- explicit foreground/background lifecycle;
- keyboard-first interaction profiles on physical-QWERTY hardware.

These product ideas do not justify moving hardware privilege into the shell.

The project studies other systems, including GrapheneOS for security engineering and MarathonOS for mobile UX/device/power/recovery lessons, while evaluating each idea against Sable's own trust boundaries and Android substrate.

See `docs/SECURITY_REFERENCE_GRAPHENEOS.md` and `docs/EXTERNAL_LESSONS.md`.

## Android application compatibility

SableOS intends to preserve standard Android application packaging, PackageManager/PackageInstaller, ART, sandboxing, permissions, and AppOps rather than creating a Sable-specific package ecosystem.

Later roadmap tracks cover Secure Package Intelligence, optional compatibility services, user-facing capability hardening, and production release/update security.

See `docs/APP_SECURITY_AND_COMPATIBILITY.md` and `docs/ROADMAP.md`.

## Device evolution

Current and planned roles:

- `bramble` / Pixel 4a 5G — Android 14 architecture/regression baseline; Android 15 portability experiment candidate; not a long-lived production-security target.
- modern Pixel-class hardware — future maintained touch/security reference.
- Zinwa Q25 — optional MediaTek/QWERTY study target.
- Zinwa Q27 — future primary QWERTY candidate subject to source, unlock, vendor, hardware, radio, suspend/power, and security-lifecycle acceptance.

The common semantic APIs, security model, package policy, and service architecture should remain shared across tracks.

## Documentation

Start with `docs/DOCUMENTATION_INDEX.md`.
