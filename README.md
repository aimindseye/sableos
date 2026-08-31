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

> UI-framework choice must not be dictated by one historical Android branch's Rust compiler. When platform and UI Rust toolchains differ, cross the boundary only through a stable ABI/AIDL/NDK contract, never compiler-private Rust ABI.

Minimalism means minimal privilege, attack surface, unnecessary background activity, telemetry, duplicated implementation, and UI complexity—not needless reinvention of working platform functionality.

## Current reference target

Active development is on:

- Device: Google Pixel 7 (`panther`)
- Role: active touch-first development reference
- Interaction profile: Metro-inspired touch-first
- Android baseline: **Android 17 / SDK 37**; PANTHER-P0/P0R1/P1A are PASS and the separate P1B/V0-HOST Android-17 workspace bring-up is in progress
- Stock Pixel baseline: `CP2A.260705.006`
- UI framework: not yet selected; modern Rust framework qualification resumes only after the Panther baseline and frozen S1.7 semantic-service port are proven

Pixel 7 is still in Google's supported five-year update cohort and receives current Android releases, making it a materially better engineering/security target than Pixel 4a 5G. It is still not an indefinite production-security baseline; later Pixel hardware with a longer remaining support window may replace it without changing Sable semantics.

Historical reference:

- Pixel 4a 5G (`bramble`)
- Android 14 / `android-14.0.0_r28`
- build `UP1A.231105.001.B2`
- Sable product `sable_bramble_s1-userdebug`
- S1.7 power service/API/runtime boundary: **PASS / FROZEN**

Bramble is now a frozen architecture/regression reference. Its end-of-life proprietary firmware/vendor ceiling and Android 14 Rust/Cargo 1.68 baseline no longer constrain S1.8 UI-framework selection. The previously planned Android 15 bramble portability experiment is closed without execution. Bramble is not a production S1.8/S1.8C target.

See `docs/adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`, `docs/S1_8_PLATFORM_TRANSITION.md`, and `docs/PANTHER_P1B_ANDROID17_HOST_BRINGUP.md`.

## Proven S1.7 architecture — PASS / FROZEN

S1 moved the power path from direct-sysfs concepts to a platform-compatible, callback-driven architecture and froze the first read-only Sable power API.

### S1.6 callback-driven power monitoring

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

### S1.7 frozen read-only power API and authorization proof

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

The runtime trust boundary is physically proven:

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

## Current milestone: Panther Android 17 bring-up before S1.8

S1.8 remains the first Sable-native user-facing consumer of a frozen semantic service, but production UI work is blocked until the modern Pixel baseline and service port are proven.

Captured bramble qualification evidence:

- D0 architecture/document reconciliation PASS;
- F0/F1/F2/F3/F4 framework/toolchain evidence captured;
- current Vexo and several modern frameworks exceed the Android 14 platform Rust toolchain;
- Slint 1.5 core was proven buildable on Rust 1.68 with bounded compatibility work, confirming that the constraint was the historical platform toolchain/dependency graph rather than the device CPU architecture;
- no production S1.8 UI source was landed on bramble;
- no global AOSP Rust uplift was performed.

Current Panther sequence:

```text
PANTHER-P0 / P0R1 / P1A
PASS
      |
      v
PANTHER-P1B / V0-HOST
Android 17 pure-AOSP workspace + audited Pixel generation
IN PROGRESS
      |
      v
PANTHER-V0
vanilla hardware + Android app compatibility acceptance
      |
      v
S1.7 semantic service port
Android 17 / GS201 Health adapter + frozen PowerSnapshot/V1 semantics
      |
      v
S1.8 / S1.8C
modern Rust UI qualification + first power client
```

The active P1B workspace is `/srv/data/aosp_panther17_workspace`. It uses the stock Pixel 7 `CP2A.260705.006` factory input and bounded, pinned generation references. Recent compatibility work has closed the Node 24/JDK 21 runtime boundary and the AAPT2 proto-module, stringified resource configuration, `brief-package-info`, and ApkSigner `print-certs` host contracts. The remaining host-generation work is tracked in `docs/PANTHER_P1B_ANDROID17_HOST_BRINGUP.md`.

GrapheneOS remains a reference/security source, not the Sable OS substrate. Compatibility patches imported during P1B are reviewed host-tool contracts required by the pinned `adevtool`/`arsclib` generation path; GrapheneOS applications, broad product policy, and wholesale platform-manifest inheritance remain rejected.

After the Panther baseline and S1.7 service port close, S1.8 requalifies a broader modern Rust UI set including Slint, WaterUI, Project Robius + Makepad, Blinc, Vexo, Dioxus Native / Blitz, and a possible Sable-owned UI framework.

Crux remains an application/core architecture reference. UniFFI and Flutter Rust Bridge are interop tools rather than preferred shell renderers. Tauri/WebView presentation is not the preferred Sable system-shell architecture.

The first real S1.8/S1.8C client remains deliberately narrow:

- standalone Android-managed Sable application;
- Launcher3 and AOSP SystemUI remain intact;
- consume stable Sable power semantics without Health/sysfs authority;
- display battery percentage, charging state, source and unavailable state;
- UI crash/restart cannot disturb the provider;
- no unnecessary Internet/network authority;
- Metro-inspired touch and BlackBerry/BB10-inspired keyboard semantics remain one shared application/core model.

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
UI -> read PowerSnapshot -> read-only semantic service
UI -> request narrow policy operation -> dedicated service -> framework/HAL

rejected:
UI -> raw power sysfs
UI -> direct Health HAL
UI -> broad-capability general-purpose networking tool
UI -> generic privileged command executor
```

When the Sable UI and platform use different Rust compiler versions:

```text
modern Rust UI
    -> stable C/NDK/AIDL adapter
    -> Sable semantic service
```

Direct linking across independently compiled Rust ABI is rejected.

See `docs/ARCHITECTURE.md`, `docs/SECURITY_MODEL.md`, `docs/adr/0001-mobile-ux-with-strict-privilege-separation.md`, and `docs/adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.

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

SableOS is mobile-first rather than a desktop shell adapted to a narrow display.

Two first-class interaction profiles share one application/service semantic core.

### Touch-first / conventional phones

Metro-inspired direction:

- strong typography and spatial hierarchy;
- edge-to-edge, low-chrome information surfaces;
- gesture-first navigation;
- persistent/live information where useful;
- fast peek/return workflows;
- low-latency transitions and motion which communicates hierarchy.

### Keyboard-first / physical QWERTY

BlackBerry/BB10-inspired direction:

- physical keyboard as primary input;
- deterministic focus and visible focus state;
- type-to-search;
- shortcuts and command palette;
- fast communication/notification triage;
- predictable back/navigation/focus restoration;
- touch/keyboard/pointer coexistence where available.

The project studies other systems, including GrapheneOS for security engineering, App Manager for package/application transparency, MarathonOS for mobile/QWERTY UX and device/recovery lessons, and multiple Rust UI frameworks for rendering/application architecture. Each idea is re-evaluated against Sable's own Android-compatible trust boundaries.

## Android application compatibility

SableOS preserves standard Android application packaging, PackageManager/PackageInstaller, ART, sandboxing, permissions, AppOps, intents/components and profiles rather than creating a Sable-specific package ecosystem.

F-Droid, direct APKs and compatible third-party stores remain ordinary Android applications. A future optional sandboxed Google compatibility layer is separate from base APK compatibility.

The Sable-native Rust renderer is a presentation choice; it does not replace the Android application runtime.

See `docs/APP_SECURITY_AND_COMPATIBILITY.md` and `docs/ROADMAP.md`.

## Device evolution

Current and planned roles:

- `panther` / Pixel 7 — active touch-first development reference on the Android 17 path; P1B/V0-HOST bring-up in progress.
- `bramble` / Pixel 4a 5G — frozen Android 14 S1.7 architecture/regression reference; no longer an active S1.8/S1.8C or Android-15-port target.
- later Pixel hardware — future longer-lived production/security reference when remaining support lifetime justifies transition.
- Zinwa Q25 — optional MediaTek/QWERTY study target.
- Zinwa Q27 — future primary QWERTY candidate subject to source, unlock, vendor, hardware, radio, suspend/power, and security-lifecycle acceptance.

The common semantic APIs, security model, package policy and UI/application architecture must remain shared across these tracks.

## Documentation

Start with `docs/DOCUMENTATION_INDEX.md`.
