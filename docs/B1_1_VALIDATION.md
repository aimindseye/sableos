# B1.1 validation record and acceptance gates

Status: **pre-full-build gates passed; full image and physical validation pending**.

B1.1 is intentionally a narrow change from the physically validated B1 baseline.

Its purpose is to prove that the B1-validated `oxynoded` code can start automatically through Android init in its own SELinux domain while SELinux remains enforcing and while no new hardware, radio, Binder, network, device-node, socket, or Linux-capability permissions are granted.

## Reference baseline

- Device: Google Pixel 4a 5G G025E
- codename: `bramble`
- Android: 12.1
- AOSP tag: `android-12.1.0_r11`
- build ID: `SQ3A.220705.003.A1`
- B1 physical hardware/carrier acceptance: passed
- B1 frozen `oxynoded` SHA-256: `753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45`

## Intended B1 -> B1.1 delta

- add B1.1 product target
- keep the same `oxynoded` source/code behavior
- install an init service definition
- run as UID `system`, not root
- add dedicated `oxynoded` and `oxynoded_exec` SELinux types
- allow init to transition into the dedicated domain
- keep SELinux enforcing
- grant no feature privileges yet

## Binary-equivalence gate

The B1.1 build of the same Rust source has a different whole-file SHA-256 because the GNU build-id differs.

B1.1 installed binary SHA-256 before the full image build:

```text
39cd9b55f240cb2ca8e7efebff82b3228ccb3fd393489ea46b9a9deefdd4628c
```

A section-level comparison established:

- same file size
- same AArch64 PIE structure
- same entry point
- same ELF layout
- same Android note
- same dynamic dependencies
- identical `.text`
- identical `.rodata`
- identical `.data`
- identical `.dynamic`
- identical `.dynsym`
- identical `.dynstr`
- identical `.eh_frame`
- identical `.got`
- identical `.rela.plt`
- exactly 16 differing bytes, confined to the GNU build-id payload

After removing `.note.gnu.build-id`, B1 and B1.1 normalize to the same SHA-256:

```text
ff598082b5889e07bcabd7333740584e0428dbe3002c7401315f65cdfcb255f3
```

Gate: **PASS**.

Whole-file equality with B1 is therefore not a B1.1 requirement. The B1.1 binary is recorded independently while normalized code/data identity is retained as the provenance check.

## Init-service gate

Expected installed service definition:

```rc
service oxynoded /system_ext/bin/oxynoded
    class main
    user system
    group system
```

Requirements:

- no root UID
- no `seclabel` override
- no Linux capabilities
- no sockets
- no hardware interfaces
- no restart hooks that grant additional privilege
- not `oneshot`
- not manually `disabled`

Packaging gate: **PASS** before full image build.

## SELinux source policy

Expected policy:

```te
type oxynoded, domain, coredomain;
type oxynoded_exec, system_file_type, exec_type, file_type;

init_daemon_domain(oxynoded)
```

Expected file context:

```text
/system_ext/bin/oxynoded    u:object_r:oxynoded_exec:s0
```

No explicit hand-written `allow`, `permissive`, `net_domain`, `binder_use`, `binder_call`, `unix_socket_connect`, `set_prop`, or `get_prop` grants are present in the Sable B1.1 policy source.

Source privilege audit: **PASS**.

## Pre-full-build SELinux gates

The following targets have passed for `sable_bramble_b11-userdebug` with `OUT_DIR=out_b11`:

- `system_ext_sepolicy.cil`
- `system_ext_file_contexts`
- `system_ext_file_contexts_test`
- `sepolicy_neverallows`
- combined `sepolicy`
- `sepolicy_tests`

Generated policy confirms:

- `oxynoded` is a dedicated domain/coredomain
- `oxynoded_exec` is the executable file type
- init transition into `oxynoded` exists
- `oxynoded_exec` is an allowed entrypoint for the new domain
- no Sable-authored radio/Binder/network/device/capability grants were introduced

Gate: **PASS**.

## Full-build gate

The full `sable_bramble_b11-userdebug` image build must complete successfully using the isolated `out_b11` output tree.

Do not flash if the full build fails.

After a successful full build, re-verify:

- installed `oxynoded` path and SHA-256
- installed init RC
- installed `system_ext_file_contexts` mapping
- installed `system_ext_sepolicy.cil` types
- target-files integrity

Status: **pending**.

## B1 -> B1.1 partition-delta gate

Before generating or using a flash package, hash and compare the full B1.1 image set against the frozen B1 reference.

The following hardware/vendor-bound artifacts are expected to remain outside the intended B1.1 change and require strict review if they differ:

- `bootloader.img`
- `radio.img`
- `vendor.img`
- `dtb.img`
- `super_empty.img`

Do not assume equality before hashing.

Changes to `system_ext`, AVB/vbmeta, product identity, boot/vendor-boot/ramdisk or other product-generated images must be investigated structurally rather than treated as automatic failures or automatic successes.

A flash package must not casually include or update bootloader/radio firmware.

Status: **pending full build**.

## AOSP capability-parity gate

B1.1 is not accepted merely because `oxynoded` starts.

The B1 baseline established working Android/vendor capability that must not be silently lost by the init/SELinux change.

At minimum, physically re-check the relevant B1 capabilities:

- stable boot and UI
- display/touch
- Wi-Fi
- Bluetooth
- audio playback/recording/routing needed for calls
- SIM detection
- cellular packet data
- LTE registration
- available 5G/NR behavior
- outbound/inbound voice
- SMS send/receive
- MMS where practical
- IMS/VoLTE behavior
- earpiece/microphone/speakerphone
- camera
- sensors
- USB/ADB
- suspend/resume
- charging

An intentional future capability removal must be documented through `AOSP_CAPABILITY_POLICY.md`; it must not be hidden as a regression.

## Physical B1.1 security/health gate

After a safe flash, all of the following are required:

```bash
adb shell getenforce
adb shell getprop init.svc.oxynoded
adb shell ps -AZ | grep oxynoded
adb shell ls -Z /system_ext/bin/oxynoded
```

Required observations:

- SELinux reports `Enforcing`
- `init.svc.oxynoded` reports `running`
- the process runs in `u:r:oxynoded:s0`
- process UID is `system`, not root
- `/system_ext/bin/oxynoded` is labeled `oxynoded_exec`
- daemon remains running over time and after reboot
- no unexpected `oxynoded` AVC denials indicate undeclared feature dependencies
- no broad policy weakening was added to suppress AVCs

Because the B1 source currently prints startup text and then sleeps, `init.svc` plus process/context checks are the primary health evidence. Do not change the Rust source merely to produce more logging unless physical validation demonstrates a real observability requirement.

Status: **pending physical validation**.

## Firmware-preservation gate

Before and after B1.1 flashing, verify the device remains `bramble`, unlocked for development, and on the expected validated bootloader/baseband level.

B1.1 must not require a bootloader/radio downgrade or an unrelated firmware change.

Status: **pending physical validation**.

## Acceptance rule

B1.1 passes only when all of the following are true:

1. normalized B1/B1.1 Rust binary identity remains proven;
2. full B1.1 image build succeeds;
3. target-files and generated artifacts pass integrity checks;
4. partition-delta audit is understood and approved;
5. no unintended bootloader/radio/vendor change is introduced;
6. SELinux remains enforcing;
7. `oxynoded` starts automatically in its dedicated domain as UID `system`;
8. no broad privileges are introduced merely to make the daemon run;
9. the relevant B1 AOSP/vendor capability baseline remains functional;
10. telephony data/voice/SMS parity remains intact;
11. physical reboot/stability and AVC checks pass;
12. a safe restore path remains available.

Only after this gate should the project move from daemon-startup validation toward new privileged services, hardware brokers, or larger UI/framework replacement work.
