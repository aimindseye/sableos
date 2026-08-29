# B2 — `power.read_state` service and hardware adapter

Status: **in progress — B2.0 semantic/mock, B2.1 Soong integration, and B2.2 backend-investigation gates passed**.

B2 is the first SableOS semantic service and hardware-adapter milestone after the physically validated B1.1 init/SELinux foundation.

Its purpose is to prove that SableOS can expose useful hardware state through a small, typed, portable semantic API without turning `oxynoded` into a broad privileged hardware daemon and without regressing inherited Android/AOSP/vendor capability.

## Current progress

### B2.0 — semantic/mock gate

Complete:

- typed `PowerState`, `PowerSource`, `PowerError`, `PowerBackend`, and `PowerService` exist;
- `MockPowerBackend` exists;
- core portability audit passed with no bramble/Qualcomm/sysfs/procfs/dev/Binder/radio/telephony/service-manager/Android-HAL references;
- the pinned Android 12.1 AOSP Rust compiler is `rustc 1.51.0-dev`;
- host semantic tests compile with Rust edition 2018;
- all 9 deterministic semantic/mock tests pass.

Gate: **PASS**.

### B2.1 — Soong integration gate

Complete:

- isolated `sable_bramble_b2-userdebug` product target exists;
- the B2 product inherits the stock bramble AOSP product and packages `oxynoded` plus the existing init RC;
- `power.rs` is compiled into the B2 `oxynoded` crate through `mod power;`;
- host integration build passes with the pinned Rust compiler;
- explicit `--power-mock-probe` returns the deterministic mock state successfully;
- Soong builds and installs `out_b2/target/product/bramble/system_ext/bin/oxynoded` successfully;
- no physical power backend has been added;
- no new SELinux permission, Binder/HAL access, device-node access, sysfs access, network access, radio access, telephony access, Linux capability, or root execution has been introduced.

Gate: **PASS**.

### B2.2 — physical backend investigation

Complete:

- Android Battery Service reports expected battery/charging state;
- retained Health 2.1 service/implementation is present;
- `/sys/class/power_supply` exposes the B2-required state;
- relevant power-supply semantic files use the dedicated `sysfs_batteryinfo` SELinux type;
- the investigation was read-only with SELinux enforcing;
- `oxynoded` remained running with no observed AVC denials;
- adbd was restored to non-root state.

Decision:

- preserve Android Health HAL unchanged for Android/framework consumers;
- do not grant `oxynoded` direct Health/HwBinder or sysfs access;
- implement a dedicated non-root Rust helper, `sable-powerd`;
- grant the helper only the minimum read-only `sysfs_batteryinfo` access required by the physical adapter;
- connect `oxynoded` to the helper through narrow private Unix request/response IPC.

See `docs/B2_POWER_BACKEND_DECISION.md`.

Gate: **PASS**.

The next gate is host-only parser, source-precedence, helper-reader, protocol, and malformed-input testing before any init or SELinux change.

## Scope

B2 implements one read-only semantic operation:

```text
power.read_state
```

The returned state is intentionally minimal:

```rust
pub struct PowerState {
    pub battery_percent: u8,
    pub charging: bool,
    pub source: PowerSource,
}

pub enum PowerSource {
    Battery,
    Usb,
    Ac,
    Wireless,
    Unknown,
}
```

B2 does **not** add:

- brightness control;
- charge-limit control;
- thermal policy;
- battery-health policy;
- voltage/current telemetry unless required internally and not exposed;
- networking;
- telephony;
- Bluetooth control;
- audio routing;
- generic Binder/HAL access;
- arbitrary `/sys`, `/proc`, `/dev`, or filesystem access.

## Architecture

The semantic API must remain independent of `bramble` paths and Qualcomm-specific details.

```text
Sable client / future shell
          |
          v
     power.read_state
          |
          v
      PowerService
          |
          v
      PowerBackend
       /        \
MockPowerBackend  AndroidPowerBackend
                       |
                       v
                  sable-powerd
                       |
                       v
             selected sysfs_batteryinfo
```

The preferred implementation rule is:

> Core Sable service semantics must not contain device-specific paths, property names, HAL identifiers, or vendor-specific branching.

The physical privilege is isolated in `sable-powerd`; `oxynoded` should receive only the private IPC access needed to request the semantic power state.

## Backend contract

The backend boundary should be typed and testable. The current shape is:

```rust
pub trait PowerBackend {
    fn read_state(&self) -> Result<PowerState, PowerError>;
}
```

The backends are:

- `MockPowerBackend` — desktop/unit-test/development backend;
- `AndroidPowerBackend` — client-side adapter that obtains semantic state from `sable-powerd`;
- helper-side bramble reader — maps selected retained kernel power-supply state into the Sable semantic contract.

The helper-side adapter may know platform-specific paths. `PowerService`, callers, and future shells may not.

## Privilege rules

B1.1 established `oxynoded` as UID/GID `system`, in `u:r:oxynoded:s0`, with no Linux capabilities and no radio, Binder, network, HAL, service-manager, device-node, or other feature privileges.

B2 preserves that boundary.

Requirements:

- SELinux remains enforcing;
- neither daemon runs as root;
- no Linux capabilities;
- no radio access;
- no telephony permissions;
- no network access;
- no generic device-node access;
- no broad filesystem read permission;
- no broad Binder/service-manager/HAL permission merely for convenience;
- any new allow rule must be directly attributable to `power.read_state` and documented;
- read-only hardware interaction only for B2;
- `oxynoded` gains only narrow IPC permission to `sable-powerd`;
- `sable-powerd` gains only the minimum read permission necessary for selected `sysfs_batteryinfo` paths.

## Mock-backend gate

Deterministic tests cover:

- battery / not charging;
- USB charging;
- AC charging;
- wireless charging;
- unknown source;
- low battery;
- full battery;
- backend read failure;
- invalid battery percentage.

Gate: **PASS**.

## Physical backend gate

The physical backend must correctly map the retained Android/AOSP power state into the Sable `PowerState` contract.

At minimum validate:

1. unplugged state reports `charging = false` and `source = Battery`;
2. USB charging reports `charging = true` and `source = Usb` when the selected platform field identifies USB power;
3. wireless charging maps to `Wireless` when available;
4. battery percentage matches the Android-visible value within the same observation window;
5. repeated reads do not leak resources or destabilize either service;
6. reads continue to work after reboot;
7. malformed or missing data returns an explicit error rather than stale or invented state.

Status: **pending implementation**.

## B2 success criteria

B2 passes only when all of the following are true:

1. `power.read_state` exists as a typed Sable semantic API;
2. core service code contains no bramble-specific paths/constants;
3. `MockPowerBackend` exists and has deterministic tests;
4. a physical Android/bramble backend exists behind the same backend contract;
5. the physical implementation is read-only;
6. `oxynoded` remains non-root and without Linux capabilities;
7. `sable-powerd` is non-root and without Linux capabilities;
8. no radio/network/telephony permissions are introduced;
9. any new SELinux permissions are minimal, documented, and attributable only to the power-state path;
10. reported battery percentage and charging state match the Android baseline on-device;
11. repeated polling and reboot persistence pass;
12. no unexpected AVCs are hidden by broad policy weakening;
13. B1.1 capability parity remains intact, including Wi-Fi, Bluetooth, audio, camera, sensors, USB, suspend/resume, charging, mobile data, calls, SMS, MMS, and available 5G behavior;
14. bootloader/baseband/vendor hardware foundations remain untouched.

## Explicit non-goals

B2 is not the telephony broker milestone and must not open the modem/radio boundary.

B2 is not a shell/UI milestone. A future shell may consume the semantic API, but the service contract is validated independently first.

B2 is not a generic hardware abstraction rewrite. It reuses the proven Android/AOSP/vendor substrate and adds only the narrow Sable semantic boundary required for power state.

B2 does not replace Android Health HAL. The retained Android health stack remains available to Android/framework consumers.

## Expected follow-on

After B2 is physically validated, a reasonable next write-capable milestone is brightness/display control through a similarly narrow service boundary. Network and telephony services remain later milestones because they introduce substantially larger Android framework/vendor privilege surfaces.
