# S1.7 Validation — Frozen Power IPC V1

Status: **PASS**  
Reference device: Google Pixel 4a 5G (`bramble`)  
Substrate: Android 14 / `android-14.0.0_r28`  
Build ID: `UP1A.231105.001.B2`  
Product: `sable_bramble_s1-userdebug`  
Build output: `out_s13b`

## Scope

S1.7 closes the first stable Sable power IPC boundary:

```text
Android Health HAL 2.1 callback
        -> native callback bridge
        -> Rust PowerMonitor
        -> PowerStateStore
        -> frozen read-only AIDL V1
        -> explicitly authorized Sable client
```

The vendor Health HAL remains the battery/sysfs authority. `oxynoded` remains the only Sable Health client. Neither the Sable AIDL client nor ordinary shell receives Health HAL or battery-sysfs authority.

## Frozen V1 contract

Service:

```text
com.sableos.power.IPowerService/default
```

Operation:

```text
PowerSnapshot getLatestState();
```

Snapshot semantics:

- `available` is false until the first validated Health state;
- after the first valid state, the latest valid state remains available through transient backend failure;
- `batteryPercent` is validated before publication;
- `charging` is derived from validated Health status;
- `source` uses the stable Sable enum `UNKNOWN`, `BATTERY`, `USB`, `AC`, `WIRELESS`;
- `sequence` starts at 1 on the first externally visible valid state and increments only when externally visible `PowerState` changes;
- no setters, backend handles, raw sysfs paths or mutation methods exist in V1.

Frozen AIDL API hash:

```text
a4a80109b0e031d743c4530fe8688325bfb01ed4
```

SHA-256 of frozen V1 `.hash` file:

```text
0f88d12e0f72aa5bb7625f134ff7da2e86809b9b50e095e2ca38f2cb71f28650
```

## Final source seals

```text
60e57eb9121ef88ffa1532c23eac6bf0fd5c1b2f6b3e60f4e35bef1f3c1b9155  device/sable/bramble/oxynoded/src/main.rs
ab0fb13133f0c0773c19726c10fa5f95fd6105fd2eda4cf9215c948e30621543  device/sable/bramble/oxynoded/src/power.rs
9bdf37270e4ff82b76c39aee0e7ba967ad1847ddd44af0b657f6872c219741ee  device/sable/bramble/oxynoded/src/power_ipc.rs
9473e70a5a74e3e5a7a2b814c4b88a5c8567f6bc74ee48d1162965bf89e3e7f4  device/sable/bramble/oxynoded/src/power_client_test.rs
29f02cc1ff721ee3d9aa310d81fceab123dc297160e715478c4627d055bae74b  device/sable/bramble/oxynoded/sable-power-client-test.rc
642107b59cd9ce50cd26503526bc3d3eb73ecaea1a2e174aaa5631853585484d  device/sable/bramble/oxynoded/Android.bp
b32b20cc11c1a172b33fa95a1f6ca0cd3ee713070c49386e199cc9944969d65a  device/sable/bramble/sable_bramble_s1.mk
f076949283ae0bb2b6d4545ea019949aa27f44b58cf3fb4efd1e7d9d41550900  device/sable/bramble/sepolicy/system_ext/private/sable_power_test_client.te
89ce5b0cc0605422520e303b225ab4da81fdfdfb5eb608632c69c63204a045  device/sable/bramble/sepolicy/system_ext/private/file_contexts
6acbd82e04c09e587e743778ade168e4222da3ad7237539a08aae83f77bc8041  device/sable/bramble/sepolicy/system_ext/private/oxynoded.te
431096473997336f125fb0613989a846bb0b632c6995ae0fb63fb91502c48b5f  device/sable/bramble/sepolicy/system_ext/private/sable_power_service.te
87d25f27cf10568c1bcc54383c61b0d972da2273b0067f5d8b09c3d40adfd472  device/sable/bramble/sepolicy/system_ext/private/service_contexts
47fde80ba3718a8d69e338578b6cae65c0bc03be76be35d6ca49a8debb4e057b  device/sable/bramble/oxynoded/health_event_bridge.cpp
```

Frozen AIDL source seals:

```text
7b69620e41ddd8d9500a11b7fe5ba2158b884443f4edc7ca09ed6d1d4695b813  IPowerService.aidl
5a866e4cf299972afeea3bae7348d33960a1f4354d8ea9c0f8576b08c7e0eba9c  PowerSnapshot.aidl
d092ea928a9eb52f22038bde36edce0132b09012cf7e66294eabc9113285bd1d  PowerSource.aidl
```

## Host/build closure

- AIDL V1 is frozen and ownerless on the Android 14 release build graph.
- Generated Rust AIDL dylibs install under `system_ext`, not `/system/lib{,64}`.
- 31 host tests pass, including `PowerStateStore` availability and sequence behavior.
- Clippy/Rust builds pass for provider and client.
- `sepolicy_test`, neverallow checks and full product build pass.
- Exact `oxynoded`, `sable-power-client-test` and generated AIDL dylib content was extracted from `system_ext.img` and matched the built artifacts.
- Service and file contexts were verified inside the image.
- The immutable Google `vendor.img` remains byte-for-byte unchanged.

## Final deployed image seal

```text
e094666c78675de5acdb50e178511e6fe606ffc070c54082360c3e448f8dd188  boot.img
33f9152c63aa2c45fc171b38f9baff522c4ea6ed5566a85d016e78143f3ed9be  dtbo.img
950cc79de4b2406d7a108346b2c5944e252f9991aea9666bd13136ee771070b4  product.img
d890d1d546acdf527063122a756dff87f81950d2c1be72143730c21248e82547  system.img
d198ab376060e2353841eb60249c69e56501381f1259544133e163e6a0f66473  system_ext.img
49d776911f955fd7b0a677980710be24aa567a900671b7fee0a0fd87ecb2e2fd  vendor.img
7fb952ade542cac0e1e96a63ad71333b797f4806a0e74222f12e7f3a4c4ad3d3  vendor_boot.img
ee87dd8478eddf0b4efb0b09323dd724bcf481d387ef4e6b4da2d08f2ea023a3  vbmeta_system.img
98042fbdf4f04426b8741adaf32592e04ac2f5426e959fc1331595176a4c6a69  vbmeta.img
```

The S1.7 image delta is intentionally broader than the earlier `system_ext`-only expectation. Adding the stable AIDL surface and SELinux service/client policy propagates generated metadata/policy into `system`, `product`, the vendor ramdisk in `vendor_boot`, and the corresponding AVB metadata. The validated changed root images are therefore `system`, `product`, `system_ext`, and `vendor_boot`; `vbmeta_system` and `vbmeta` change as required downstream AVB consequences. `boot`, `dtbo`, and immutable Google `vendor` remain unchanged.

## Final device binary seal

```text
40d0c2ef92f65fa72acb918a00c320e6955b0181a4bf0d8d967520d607028873  /system_ext/bin/oxynoded
032e22d56d586cfc1e48e44555ad2ae69c4858c4596fa3eb1dd191582d1a70a2  /system_ext/bin/sable-power-client-test
c84e566f3bc59f0eb09abfe7d88fff2c3ceaf60845c2401f59bed4dac01b227c  /system_ext/lib64/libsable_power_aidl_V1.dylib.so
```

## Authorization closure

Provider policy:

```text
oxynoded -> add/find sable_power_service
```

Authorized client policy:

```text
sable_power_test_client -> find sable_power_service
sable_power_test_client -> Binder call/transfer to oxynoded
```

Negative boundary:

- `sable_power_test_client` has no Health HAL or battery-sysfs access;
- ordinary shell cannot trigger the disabled `sable-power-client-test` init service;
- Android 14 platform policy allows ordinary shell to discover many `service_manager_type` services, so `service check` can report the Sable service as found;
- discovery is not treated as authority: an ordinary-shell Binder transaction to `oxynoded` is denied under enforcing SELinux with `avc: denied { call }`;
- the provider remains alive after the denied transaction.

The accepted invariant is therefore: **unauthorized shell may discover the service name through platform policy, but cannot transact with or use the Sable power API.**

## Inactive-slot deployment closure

Deployment preserved the known-good successful S1.6 slot B until all S1.7 writes to inactive slot A completed. Activation occurred last.

Final state:

```text
active slot: A
slot A naturally successful: yes
slot B successful fallback: yes
SELinux: Enforcing
manual slot-success marking: no
```

## Physical callback / AIDL correlation

Pre-unplug authorized snapshot:

```text
available=true
batteryPercent=100
charging=true
source=USB
sequence=1
```

The device was dozing before the physical cable event. ADB disappeared after the cable was physically unplugged, and the device remained unplugged for 45 seconds. The same `oxynoded` PID survived the complete event window.

Buffered callback transitions:

```text
Usb -> Battery
Battery -> Unknown
Unknown -> Ac
Ac -> Battery
Battery -> Unknown
Unknown -> Ac
```

No power-read errors and no relevant AVC denials occurred.

Post-event authorized snapshot:

```text
available=true
batteryPercent=100
charging=true
source=AC
sequence=7
```

Correlation:

```text
pre sequence:  1
post sequence: 7
delta:         6
callback externally-visible state changes: 6
provider PID before/after: unchanged
```

This exactly proves that the frozen AIDL sequence tracks externally visible callback-driven `PowerState` changes without polling, synthetic state or a daemon wakelock.

`Battery -> Unknown -> AC` remains an accepted reconnect path because the Health HAL can report charging before external-source flags settle.

## Test-harness transport note

After physical reconnect, ADB required USB File transfer/data mode before the post-event root evidence could be collected. The physical callback evidence had already completed and the same provider PID remained alive. The post-event AIDL read was resumed without repeating the physical test. This is recorded as a host/device USB transport condition, not a Sable power-path failure.

## Final acceptance

```text
S1_7_AIDL_V1_FROZEN=PASS
S1_7_PROVIDER_HOST_BUILD=PASS
S1_7_31_HOST_TESTS=PASS
S1_7_FULL_PRODUCT_RESEAL=PASS
S1_7_IMAGE_DELTA_CLASSIFIED=PASS
S1_7_AUTHORIZED_CLIENT=PASS
S1_7_CLIENT_BACKEND_ISOLATION=PASS
S1_7_SHELL_CLIENT_TRIGGER=DENIED_PASS
S1_7_SHELL_BINDER_TRANSACTION=DENIED_PASS
S1_7_RUNTIME_AUTHORIZATION=PASS
S1_7_PHYSICAL_CALLBACK=PASS
S1_7_CALLBACK_AIDL_SEQUENCE_CORRELATION=PASS
S1_7_PROVIDER_PID_CONTINUITY=PASS
S1_7_NO_POWER_READ_ERRORS=PASS
S1_7_NO_RELEVANT_AVC=PASS
S1_7_SLOT_A_SUCCESSFUL=PASS
S1_7_SLOT_B_FALLBACK_SUCCESSFUL=PASS
S1_7_SELINUX_ENFORCING=PASS
S1_7_OVERALL=PASS
```

S1.7 is frozen. Future user-facing power work should consume V1 rather than expanding Health/sysfs authority into clients. Any incompatible API change should be treated as a future versioned contract rather than rewriting frozen V1.
