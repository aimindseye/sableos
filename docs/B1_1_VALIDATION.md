# B1.1 validation record and acceptance gates

Status: **PASS — physically validated and Gold Master frozen**.

B1.1 is intentionally a narrow change from the physically validated B1 baseline. Its purpose was to prove that the B1-validated `oxynoded` code can start automatically through Android init in its own SELinux domain while SELinux remains enforcing and while no new radio, Binder, network, HAL, device-node, socket, or Linux-capability feature privileges are granted.

## Reference baseline

- Device: Google Pixel 4a 5G G025E
- codename: `bramble`
- Android: 12.1
- AOSP tag: `android-12.1.0_r11`
- build ID: `SQ3A.220705.003.A1`
- B1 physical hardware/carrier acceptance: passed
- B1 frozen `oxynoded` SHA-256: `753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45`

## Intended B1 -> B1.1 delta

- add B1.1 product target;
- keep the same `oxynoded` source/code behavior;
- install an init service definition;
- run as UID/GID `system`, not root;
- add dedicated `oxynoded` and `oxynoded_exec` SELinux types;
- allow init to transition into the dedicated domain;
- keep SELinux enforcing;
- grant no feature privileges yet.

## Rust binary-equivalence gate

B1.1 installed `oxynoded` SHA-256:

```text
39cd9b55f240cb2ca8e7efebff82b3228ccb3fd393489ea46b9a9deefdd4628c
```

The whole-file hash differs from B1 because the GNU build-id differs. After removing `.note.gnu.build-id`, B1 and B1.1 normalize to the same SHA-256:

```text
ff598082b5889e07bcabd7333740584e0428dbe3002c7401315f65cdfcb255f3
```

Gate: **PASS**.

## Init and SELinux gate

Installed init definition:

```rc
service oxynoded /system_ext/bin/oxynoded
    class main
    user system
    group system
```

SELinux source policy:

```te
type oxynoded, domain, coredomain;
type oxynoded_exec, system_file_type, exec_type, file_type;

init_daemon_domain(oxynoded)
```

File context:

```text
/system_ext/bin/oxynoded    u:object_r:oxynoded_exec:s0
```

Compiled-policy inspection established that the only outbound `allow` from `oxynoded` is its own executable entrypoint. No radio, Binder, network, HAL, service-manager, generic device-node, or Linux-capability access was introduced.

`oxynoded` is not permissive. The B1 and B1.1 permissive-domain sets are identical for the userdebug build.

Gate: **PASS**.

## Build and target-files gate

The isolated full build used `OUT_DIR=out_b11` and completed successfully.

Target-files package SHA-256:

```text
064d607b33fccd90b1e408ad3a790b24dc8ee70806eac8176d8ae70d535727b3
```

Target-files ZIP integrity: **PASS**.

Gate: **PASS**.

## B1 -> B1.1 structural and capability audit

Strictly preserved hardware/vendor-bound artifacts included:

- bootloader image;
- radio image;
- vendor image;
- DTB;
- super layout.

The DTBO whole-image hash changed because of finalized image/AVB metadata, but the stripped DTBO payload remained identical:

```text
982ae82c5dca424e2db3ef159b8012a488dc21b1c79ab4f02005cb92c4ff9266
```

BOOT/VENDOR_BOOT ELF differences were classified through build-id/debug-link normalization, section analysis, disassembly-shape comparison, control-flow-target comparison, and constant-table relocation checks. No unintended executable control-flow change was found.

`SYSTEM` and `PRODUCT` preserved their complete file sets:

```text
SYSTEM:  2613 -> 2613, added 0, removed 0
PRODUCT:  344 -> 344, added 0, removed 0
```

Application/framework file set:

```text
347 -> 347, added 0, removed 0
```

Capability-bearing permission/sysconfig/VINTF/init/seccomp/overlay configuration had no unintended change.

`services.jar` executable bytecode remained unchanged; generated compat-config XML differences normalized to output-directory provenance only. NetworkStack retained the same managed payload, normalized-identical native libraries, and the same signing certificate.

Gate: **PASS**.

## Flash-package gate

Canonical flash package:

```text
B1.1-full-images.zip
SHA-256: 2b7dab2f5f5b5d66efacaf8ab908a3e3e78ea508c743837246bbaedcf792d1d4
```

Requirements verified:

- ZIP integrity passed;
- `android-info.txt` requires `board=bramble`;
- no `bootloader.img`;
- no `radio.img`;
- exact expected flash file set;
- 12/12 packaged `.img` files match the finalized `IMAGES/*` entries in the audited target-files package;
- final DTBO payload matches the audited payload;
- DTB embedded in final `vendor_boot.img` matches the frozen bramble DTB.

Gate: **PASS**.

## Physical security/health gate

Observed on-device:

```text
sys.boot_completed=1
ro.build.id=SQ3A.220705.003.A1
ro.product.name=sable_bramble_b11
SELinux=Enforcing
init.svc.oxynoded=running
```

Runtime `oxynoded` observations:

- one process;
- process context `u:r:oxynoded:s0`;
- UID/GID `1000/1000` (`system/system`);
- executable context `u:object_r:oxynoded_exec:s0`;
- inheritable capabilities: zero;
- permitted capabilities: zero;
- effective capabilities: zero;
- ambient capabilities: zero;
- no observed `oxynoded` AVC denial during the validation run;
- remains running after a real reboot with SELinux enforcing.

Gate: **PASS**.

## Physical AOSP/vendor capability-parity gate

Physically validated after the B1.1 flash:

- display/touch: PASS;
- Wi-Fi: PASS;
- Bluetooth: PASS;
- audio playback: PASS;
- microphone: PASS;
- rear camera: PASS;
- front camera: PASS;
- sensors/rotation: PASS;
- USB: PASS;
- charging: PASS;
- suspend/resume: PASS;
- mobile data/Internet: PASS;
- outgoing call: PASS;
- incoming call: PASS;
- outgoing SMS: PASS;
- incoming SMS: PASS;
- MMS: PASS;
- available 5G registration/data behavior: PASS.

`oxynoded` remained running and SELinux remained enforcing through capability and telephony testing.

Gate: **PASS**.

## Firmware-preservation gate

Post-flash checks confirmed:

- product remains `bramble`;
- bootloader version unchanged from the pre-flash validated baseline;
- baseband version unchanged from the pre-flash validated baseline;
- no bootloader or radio image was present in the B1.1 flash package.

Gate: **PASS**.

## Gold Master

The B1.1 Gold Master was checksum-verified and frozen read-only at:

```text
/srv/data/aosp_gold_master_bramble/B1.1-oxynoded-selinux-SQ3A.220705.003.A1
```

Gold Master full verification: **PASS**.

## Acceptance result

All B1.1 acceptance gates passed.

B1.1 establishes the validated foundation for the first narrow Sable semantic hardware service. The next milestone is B2 `power.read_state`; see `docs/B2_POWER_READ_STATE.md`.
