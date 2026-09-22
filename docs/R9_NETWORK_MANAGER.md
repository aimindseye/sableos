# R9 Sable Network Manager

Status: **source implemented / WS7 compile qualification pending**

## Video-derived requirement

The reviewed Unihertz Titan 2 Elite video shows a per-app **Network Manager**
with separate **Mobile** and **WLAN** columns.

SableOS does not claim that exact transport split exists in GrapheneOS.

## GrapheneOS capability used by SableOS

The pinned GrapheneOS Android 17 base changes:

```text
android.permission.INTERNET
```

to a user-revocable dangerous permission. GrapheneOS then enforces revocation
as a Network permission, blocking both direct socket access and indirect
network access through OS/app APIs that honor the permission. The GrapheneOS
design also reports the network as unavailable to many APIs when Network is
revoked.

SableOS reuses that implementation directly. It does not add a parallel
firewall policy database.

Pinned framework contract:

```xml
<permission android:name="android.permission.INTERNET"
    android:permissionGroup="android.permission-group.UNDEFINED"
    android:description="@string/permdesc_createNetworkSockets"
    android:label="@string/permlab_createNetworkSockets"
    android:protectionLevel="dangerous|instant" />
```

## Sable Settings presentation

Path:

```text
Settings
  -> Privacy & Security
     -> Network Manager
```

The screen lists installed applications which request
`android.permission.INTERNET`.

Each mutable row exposes:

```text
App Name                         Network access [on/off]
```

The switch delegates directly to Android 17 `PermissionManager`:

```text
grantRuntimePermission(package, INTERNET, user)
revokeRuntimePermission(package, INTERNET, user, reason)
```

Permissions marked system-fixed or policy-fixed are visible but not mutable.

## Enforcement semantics

`Network access = OFF` means the GrapheneOS Network permission is revoked.
It is intended to cover all network transports available to the app rather
than only a packet-filtered cellular or Wi-Fi interface.

This R9 implementation therefore intentionally exposes one **Network access**
toggle, not fake Mobile/WLAN toggles.

## What R9 does not implement

R9 does **not** implement independent per-app:

- Mobile-data allow/deny;
- Wi-Fi-data allow/deny;
- VPN-only allow/deny.

Those controls are present in the reviewed Unihertz implementation but are not
the same feature as GrapheneOS' Network permission.

Adding true transport-scoped policy would require a separately designed
Connectivity/netd/network-policy enforcement layer, persistence model,
multi-user semantics, VPN interactions, tethering/local-network semantics and
CTS/regression work. It must not be represented by UI switches until the
underlying enforcement exists.

## Source files

```text
patches/android-17-grapheneos-2026081300/
  r9_settings_cohesion/SableNetworkManagerSettings.java
  r9_settings_cohesion/sable_network_manager_settings.xml
  r9_settings_cohesion/strings_sable_cohesion.xml
  apply_r9_settings_cohesion.py
```

## WS7 requirements

Before a full Panther image:

```text
R9_SETTINGS_NETWORK_MANAGER=PASS_GRAPHENE_NETWORK_PERMISSION
R9_SETTINGS_NETWORK_MANAGER_TRANSPORT_SCOPE=ALL_NETWORKS_NOT_MOBILE_WIFI_SPLIT
R9_SABLE_NETWORK_MANAGER_CONTRACT=PASS_GRAPHENE_NETWORK_PERMISSION
```

The Settings module must compile after these markers.

## WS8 physical acceptance

Use a disposable/noncritical application that requests Network permission.

1. Open Sable Settings -> Network Manager.
2. Confirm the app is listed by user-facing name.
3. Toggle Network access OFF.
4. Confirm the underlying `android.permission.INTERNET` grant becomes denied.
5. Confirm the app cannot reach the network.
6. Toggle Network access ON.
7. Confirm the permission is granted again and network access returns.
8. Confirm policy/system-fixed applications cannot be changed through the
   Sable screen.

Required physical markers:

```text
R9_SABLE_NETWORK_MANAGER_UI=PASS
R9_SABLE_NETWORK_PERMISSION_REVOKE=PASS
R9_SABLE_NETWORK_PERMISSION_RESTORE=PASS
R9_SABLE_NETWORK_FIXED_POLICY=PASS
```

Transport-specific Mobile/WLAN acceptance is explicitly **not** part of R9.
