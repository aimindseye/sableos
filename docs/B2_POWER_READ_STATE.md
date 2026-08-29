# B2 — `power.read_state` service and hardware adapter

Status: **planned / implementation not started**.

B2 is the first SableOS semantic service and hardware-adapter milestone after the physically validated B1.1 init/SELinux foundation.

Its purpose is to prove that SableOS can expose useful hardware state through a small, typed, portable semantic API without turning `oxynoded` into a broad privileged hardware daemon and without regressing inherited Android/AOSP/vendor capability.

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
MockPowerBackend  Android/Bramble backend
```

The preferred implementation rule is:

> Core Sable service semantics must not contain device-specific paths, property names, HAL identifiers, or vendor-specific branching.

If the physical Android/bramble backend requires privilege not otherwise needed by `oxynoded`, that privilege belongs in a narrow helper/service with its own SELinux domain rather than being granted broadly to `oxynoded`.

A possible separated implementation is:

```text
oxynoded
   |
   | narrow private request/response IPC
   v
sable-powerd
   |
   v
PowerBackend
   |
   v
specific Android/kernel power-state interface
```

B2 should use the narrowest mature Android/AOSP interface that can provide the required state reliably. Direct kernel/sysfs reads are acceptable only when they are well-defined for the target and can be confined narrowly. AOSP/Android health-service integration is preferred long-term when it can be used without unnecessarily broad privilege.

## Backend contract

The backend boundary should be typed and testable. A starting shape is:

```rust
pub trait PowerBackend {
    fn read_state(&self) -> Result<PowerState, PowerError>;
}
```

The first two backends are:

- `MockPowerBackend` — desktop/unit-test/development backend;
- Android/bramble physical backend — maps the retained Android hardware substrate into Sable semantics.

The adapter may know platform-specific details. `PowerService`, callers, and future shells may not.

## Privilege rules

B1.1 established `oxynoded` as UID/GID `system`, in `u:r:oxynoded:s0`, with no Linux capabilities and no radio, Binder, network, HAL, service-manager, device-node, or other feature privileges.

B2 starts from that boundary.

Requirements:

- SELinux remains enforcing;
- no root execution;
- no Linux capabilities;
- no radio access;
- no telephony permissions;
- no network access;
- no generic device-node access;
- no broad filesystem read permission;
- no broad Binder/service-manager/HAL permission merely for convenience;
- any new allow rule must be directly attributable to `power.read_state` and documented;
- read-only access only for the first B2 milestone.

If a helper is introduced, `oxynoded` should gain only the narrow IPC permission required to request `power.read_state`, while the helper receives only the minimum read permission needed for the physical backend.

## Mock-backend gate

Before touching physical hardware access, the semantic layer should be testable using deterministic mock states, including at least:

- battery / not charging;
- USB charging;
- AC charging where representable;
- wireless charging where representable;
- unknown source;
- low battery;
- full battery;
- backend read failure.

The semantic API must reject invalid battery percentages above 100 rather than silently exposing malformed state.

## Physical backend gate

The physical backend must correctly map the retained Android/AOSP power state into the Sable `PowerState` contract.

At minimum validate:

1. unplugged state reports `charging = false` and `source = Battery`;
2. USB charging reports `charging = true` and `source = Usb` when the platform can distinguish the source;
3. battery percentage matches the Android-visible value within the same observation window;
4. repeated reads do not leak resources or destabilize the service;
5. reads continue to work after reboot;
6. failure is returned as an explicit error rather than stale or invented data.

## B2 success criteria

B2 passes only when all of the following are true:

1. `power.read_state` exists as a typed Sable semantic API;
2. core service code contains no bramble-specific paths/constants;
3. `MockPowerBackend` exists and has deterministic tests;
4. a physical Android/bramble backend exists behind the same backend contract;
5. the physical implementation is read-only;
6. `oxynoded` remains non-root and without Linux capabilities;
7. no radio/network/telephony permissions are introduced;
8. any new SELinux permissions are minimal, documented, and attributable only to the power-state path;
9. reported battery percentage and charging state match the Android baseline on-device;
10. repeated polling and reboot persistence pass;
11. no unexpected AVCs are hidden by broad policy weakening;
12. B1.1 capability parity remains intact, including Wi-Fi, Bluetooth, audio, camera, sensors, USB, suspend/resume, charging, mobile data, calls, SMS, MMS, and available 5G behavior;
13. bootloader/baseband/vendor hardware foundations remain untouched.

## Explicit non-goals

B2 is not the telephony broker milestone and must not open the modem/radio boundary.

B2 is not a shell/UI milestone. A future shell may consume the semantic API, but the service contract is validated independently first.

B2 is not a generic hardware abstraction rewrite. It reuses the proven Android/AOSP/vendor substrate and adds only the narrow Sable semantic boundary required for power state.

## Expected follow-on

After B2 is physically validated, a reasonable next write-capable milestone is brightness/display control through a similarly narrow service boundary. Network and telephony services remain later milestones because they introduce substantially larger Android framework/vendor privilege surfaces.
