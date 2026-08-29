# B2 power backend decision

Status: **selected after read-only physical investigation; bramble source mapping frozen**.

## Decision

B2 will use a dedicated, non-root Rust helper named `sable-powerd` as the physical Android/bramble power adapter.

`oxynoded` will not receive direct sysfs, Binder, HIDL, AIDL, hwservicemanager, radio, network, device-node, or Linux-capability access for `power.read_state`.

The intended path is:

```text
PowerService
    |
    v
AndroidPowerBackend in oxynoded
    |
    | private Unix request/response IPC
    v
sable-powerd
    |
    | read-only
    v
selected sysfs_batteryinfo fields
```

The Android Health HAL remains present and untouched for Android/framework consumers.

## Investigation evidence

The B1.1 physical device investigation established:

- Android Battery Service is working and reported expected battery/charging state;
- `android.hardware.health@2.1::IHealth/default` is declared and active through the retained redbull Health 2.1 stack;
- bramble/redbull source includes `android.hardware.health@2.1-impl-redbull` and `android.hardware.health@2.1-service`;
- `/sys/class/power_supply` exposes the state required for B2;
- relevant semantic files are labeled `u:object_r:sysfs_batteryinfo:s0`;
- SELinux remained enforcing throughout investigation;
- `oxynoded` remained running and produced no observed AVC denials;
- adbd was returned to non-root state after inspection.

Two clean physical source observations were then captured.

Unplugged:

```text
Android: AC=false USB=false Wireless=false
battery/status=Discharging
battery/capacity=100
dc/online=0
pc_port/online=0
usb/online=0
```

ThinkPad USB-C/PD connection:

```text
Android: AC=true USB=false Wireless=false
battery/status=Full
battery/capacity=100
dc/online=0
pc_port/online=0
usb/type=USB_PD
usb/online=1
```

An earlier valid wired observation also showed `pc_port/online=1` while `usb/online=0`. Therefore the bramble backend must treat either wired-online field as a USB source.

## Why not consume Health 2.1 directly in B2

The existing Health HAL is mature platform capability and must be preserved. However, consuming the binderized HIDL service directly from the Sable core would require a larger client privilege/dependency surface: HIDL/HwBinder plumbing plus service discovery and associated SELinux permissions.

For the deliberately narrow first Sable hardware service, that is more privilege and integration complexity than necessary for three semantic outputs.

This is not a decision to replace or remove Health HAL. It is a decision not to grant the Sable core broad hardware-service IPC merely to read battery state.

## Why use a helper instead of direct oxynoded sysfs access

B1.1 proved `oxynoded` can remain a narrow core daemon with no hardware feature privilege. B2 preserves that boundary.

Only `sable-powerd` should receive the minimum read permission required for the existing `sysfs_batteryinfo` type. The helper must:

- run as UID/GID `system`, not root;
- have no Linux capabilities;
- have no Binder/HIDL/AIDL access;
- have no radio, network, telephony, Bluetooth, audio, camera, sensor, or generic device-node access;
- perform no sysfs writes;
- open only the explicitly coded power-state paths;
- return a small semantic response over a private Unix socket;
- reject malformed or missing data explicitly.

`oxynoded` should gain only the narrow IPC permission necessary to connect to this helper.

## Frozen bramble mapping

B2 uses these fields:

- `battery_percent` from `/sys/class/power_supply/battery/capacity`;
- charging state from `/sys/class/power_supply/battery/status`;
- wireless source from `/sys/class/power_supply/dc/online`;
- wired USB source from either `/sys/class/power_supply/pc_port/online` or `/sys/class/power_supply/usb/online`.

Source precedence is:

1. `dc/online=1` -> `Wireless`;
2. `pc_port/online=1` or `usb/online=1` -> `Usb`;
3. charging/full status without a recognized external source -> `Unknown`;
4. otherwise -> `Battery`.

`charging=true` when battery status is `Charging` or `Full`. `Discharging`, `Not charging`, and `Unknown` map to `charging=false`. Malformed status is an explicit error.

`PowerSource::Ac` remains part of the portable Sable semantic API but is not emitted by the bramble B2 backend. Bramble exposes USB-C/PD as the physical wired source even when Android Battery Service classifies the same connection as `AC powered=true`. Sable's `source` describes the backend-observed physical input class, not Android framework plug-type classification.

A wall-charger capture is therefore not required to complete the B2 bramble mapping.

## Next gate

Before adding SELinux rules, implement and host-test:

1. a pure parser/mapper for sysfs text values;
2. deterministic source-precedence tests, including both observed wired-online variants;
3. a helper-side reader abstraction with injectable mock files/data;
4. a minimal request/response protocol definition;
5. malformed/missing-file error tests.

Only after those host tests pass should B2 add the helper binary, init service/socket, and narrow SELinux policy.
