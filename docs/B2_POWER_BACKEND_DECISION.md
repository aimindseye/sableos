# B2 power backend decision

Status: **selected after read-only physical investigation**.

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

- Android Battery Service is working and reported the expected battery/charging state;
- `android.hardware.health@2.1::IHealth/default` is declared and active through the retained redbull Health 2.1 stack;
- bramble/redbull source includes `android.hardware.health@2.1-impl-redbull` and `android.hardware.health@2.1-service`;
- `/sys/class/power_supply` exposes battery and charger state required for B2;
- relevant semantic files are labeled `u:object_r:sysfs_batteryinfo:s0` rather than generic writable device types;
- the required state can be derived read-only from battery capacity/status and charger online state;
- SELinux remained enforcing throughout investigation;
- `oxynoded` remained running and produced no observed AVC denials;
- adbd was returned to non-root state after inspection.

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

## Initial bramble mapping

The first adapter should derive:

- `battery_percent` from `/sys/class/power_supply/battery/capacity`;
- battery charging/full state from `/sys/class/power_supply/battery/status`;
- wireless source from `/sys/class/power_supply/dc/online`;
- USB source from the appropriate observed USB/PC-port online field selected by validation.

Source precedence must be deterministic. A starting rule is:

1. wireless online -> `Wireless`;
2. USB/PC-port online -> `Usb`;
3. charging/full status without a recognized external source -> `Unknown`;
4. otherwise -> `Battery`.

The exact USB field is not frozen until plugged/unplugged physical observations are compared, because the investigation showed more than one USB-related power-supply node.

## Next gate

Before adding SELinux rules, implement and host-test:

1. a pure parser/mapper for sysfs text values;
2. deterministic source-precedence tests;
3. a helper-side reader abstraction with injectable mock files/data;
4. a minimal request/response protocol definition;
5. malformed/missing-file error tests.

Only after those host tests pass should B2 add the helper binary, init service/socket, and narrow SELinux policy.
