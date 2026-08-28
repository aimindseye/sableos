# G025E hardware acceptance and safe-flash record

This document is the safe-flash runbook and acceptance record for the Google Pixel 4a 5G G025E (`bramble`) used as the SableOS reference platform.

Current status:

- stock July 2022 reference baseline: verified
- bootloader unlock: completed
- B0 vanilla AOSP physical acceptance: **PASS**
- B1 native Rust physical acceptance: **PASS**
- B1.1 init + dedicated SELinux validation: **in progress**

The B0/B1 results are the capability baseline for later Sable milestones. A later milestone must not silently lose working AOSP/vendor functionality. See `AOSP_CAPABILITY_POLICY.md`.

## Safety rules

1. Capture the factory state before unlocking or flashing anything.
2. Bootloader unlocking erases user data. Back up anything important first.
3. Do **not** flash `bootloader.img` or `radio.img` until the factory bootloader/baseband versions have been captured and compared.
4. Do **not** use `fastboot flashing unlock_critical` for this workflow.
5. Do **not** relock the bootloader while custom development images are installed.
6. Stop if the device reports a product other than `bramble`, OEM unlocking is unavailable, Fastboot is unstable, or any version check is ambiguous.
7. Keep device serial numbers, IMEI, IMSI, ICCID, phone numbers and similar identifiers in local logs only; do not commit them to this repository.
8. Do not remove or replace a working AOSP/vendor component merely because SableOS plans to replace its UI surface. Preserve the useful capability until an explicit replacement gate passes.

Official references:

- Bootloader locking/unlocking: https://source.android.com/docs/core/architecture/bootloader/locking_unlocking
- AOSP Fastboot flashing: https://source.android.com/docs/setup/test/running

## Reference software state

The handset was updated to the exact July 2022 reference software before unlocking:

- model: Pixel 4a (5G)
- device: `bramble`
- build ID: `SQ3A.220705.003.A1`
- fingerprint: `google/bramble/bramble:12/SQ3A.220705.003.A1/8672226:user/release-keys`
- slot observed: `_a`
- verified boot state before unlock: green
- flash locked before unlock: `1`
- baseband: `g7250-00202-220422-B-8489468`
- bootloader: `b5-0.4-8351080`

The unlocked B0/B1 custom-build state correctly reports orange verified-boot state and an unlocked bootloader.

## Phase 0 — host preparation

Use one consistent pair of `adb`/`fastboot` binaries for the session and record their versions.

```bash
export G025ELOG=/srv/data/sableos_device_logs/G025E
mkdir -p "$G025ELOG/factory" "$G025ELOG/post-unlock" "$G025ELOG/B0" "$G025ELOG/B1" "$G025ELOG/B1.1"

{
  date -Is
  hostname
  command -v adb
  command -v fastboot
  adb version
  fastboot --version
} | tee "$G025ELOG/host-tools.txt"
```

Use a reliable USB cable and connect directly to the workstation rather than through a hub.

## Phase 1 — factory / stock state

Before changing Developer options beyond what is necessary for ADB/OEM unlocking, capture the software identity.

```bash
adb devices -l

{
  echo "model=$(adb shell getprop ro.product.model | tr -d '\r')"
  echo "device=$(adb shell getprop ro.product.device | tr -d '\r')"
  echo "build_id=$(adb shell getprop ro.build.id | tr -d '\r')"
  echo "fingerprint=$(adb shell getprop ro.build.fingerprint | tr -d '\r')"
  echo "slot=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')"
  echo "verifiedbootstate=$(adb shell getprop ro.boot.verifiedbootstate | tr -d '\r')"
  echo "flash_locked=$(adb shell getprop ro.boot.flash.locked | tr -d '\r')"
  echo "baseband=$(adb shell getprop gsm.version.baseband | tr -d '\r')"
  echo "bootloader=$(adb shell getprop ro.boot.bootloader | tr -d '\r')"
} | tee "$G025ELOG/factory/factory-summary.txt"

adb shell getprop > "$G025ELOG/factory/getprop.txt"
```

Expected product/device identity is `bramble`. If it is not, stop.

## Phase 2 — bootloader state

Enable **OEM unlocking** and **USB debugging** in Developer options, then:

```bash
adb reboot bootloader
fastboot devices
```

Capture Fastboot variables. Fastboot writes many `getvar` results to stderr, so preserve both streams.

```bash
{
  fastboot getvar product
  fastboot getvar current-slot
  fastboot getvar unlocked
  fastboot getvar secure
  fastboot getvar version-bootloader
  fastboot getvar version-baseband
  fastboot getvar slot-count
  fastboot flashing get_unlock_ability
} 2>&1 | tee "$G025ELOG/factory/fastboot-vars.txt"
```

### Hard stop conditions

Stop before unlocking if any of these apply:

- `product` is not `bramble`
- `get_unlock_ability` is not `1`
- OEM unlocking is greyed out/unavailable
- Fastboot repeatedly disconnects
- the bootloader/baseband values are missing or unexpected

Observed pre-unlock state matched `bramble`, slot A, secure bootloader, two slots, and unlock ability `1`.

## Phase 3 — unlock

Unlocking wipes user data.

```bash
fastboot flashing unlock
```

Confirm the unlock on the device screen. After it completes:

```bash
fastboot getvar unlocked 2>&1 | tee "$G025ELOG/post-unlock/unlocked.txt"
fastboot reboot
```

Observed result: bootloader unlock completed successfully; product, bootloader and baseband identities remained on the expected July reference level.

Do not use `unlock_critical` and do not relock during development testing.

## Phase 4 — verify frozen gold masters before any flash

```bash
export B0=/srv/data/aosp_gold_master_bramble/B0-vanilla-SQ3A.220705.003.A1
export B1=/srv/data/aosp_gold_master_bramble/B1-oxynoded-SQ3A.220705.003.A1

(
  cd "$B0"
  sha256sum -c metadata/images.sha256
  test ! -f metadata/artifacts.sha256 || sha256sum -c metadata/artifacts.sha256
)

(
  cd "$B1"
  sha256sum -c metadata/images-and-artifacts.sha256
  sha256sum -c metadata/metadata.sha256
)
```

Every checked item must report `OK`.

## Phase 5 — compatibility gate before flashing

Do not blindly flash archived bootloader/radio images.

Compare device `version-bootloader` and `version-baseband` against the validated reference level. A custom Sable development package should not downgrade or unnecessarily replace these components.

Before issuing a whole-device Fastboot command, inspect the exact package Fastboot will consume:

- verify `android-info.txt` requires `bramble`;
- inspect the file list;
- stop if a package unexpectedly includes bootloader/radio firmware;
- preserve a known-good restore path.

For B0/B1, the generated fastboot image ZIPs intentionally did not include `bootloader.img` or `radio.img`.

## Capability baseline

The physically validated B0/B1 baseline is more than a boot test. It is the regression inventory for later Sable milestones.

Track at minimum:

- stable boot/reboot
- display/touch
- Wi-Fi
- Bluetooth
- audio playback/recording/routing
- SIM detection
- cellular data
- LTE registration
- available 5G/NR behavior
- outbound/inbound voice
- SMS send/receive
- MMS
- IMS/VoLTE behavior
- earpiece, microphone and speakerphone
- camera
- sensors
- USB/ADB
- suspend/resume
- charging/power
- storage
- notifications and other retained platform behavior relevant to the milestone
- update/rollback/recovery path when that feature enters the release gate

A later milestone that intentionally removes a capability must document the reason through the preserve-before-remove/replacement gate. Accidental loss is a regression.

## Phase 6 — B0 acceptance

B0 is the control build.

Observed B0 identity:

- product model: AOSP on bramble
- device: `bramble`
- build ID: `SQ3A.220705.003.A1`
- custom userdebug/test-key fingerprint
- bootloader remained `b5-0.4-8351080`
- baseband remained `g7250-00202-220422-B-8489468`

Observed telephony state included:

- SIM loaded
- network registered on LTE
- voice/data in service
- Android Radio HAL services present
- Qualcomm IMS/QtiRadio/UIM services present
- validated cellular network
- validated IMS network
- NR capability/connected state observed during testing

Manual B0 acceptance:

- cellular Internet: **PASS**
- outgoing call: **PASS**
- incoming call: **PASS**
- earpiece: **PASS**
- microphone: **PASS**
- speakerphone: **PASS**
- SMS send: **PASS**
- SMS receive: **PASS**
- MMS: **PASS**
- 5G/NR observed: **PASS**

B0 physical hardware/carrier gate: **PASS**.

Local acceptance record remains outside GitHub under `$G025ELOG/B0/`.

## Phase 7 — B1 acceptance

B1 was flashed only after B0 passed.

Observed B1 identity:

- model: `SableOS B1 on bramble`
- device: `bramble`
- build ID: `SQ3A.220705.003.A1`
- bootloader/baseband remained on the July reference level

The installed Rust executable:

```text
/system_ext/bin/oxynoded
```

Expected and observed SHA-256:

```text
753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45
```

Probe command:

```bash
adb root
adb wait-for-device
adb shell /system_ext/bin/oxynoded --probe
```

Observed probe output:

```text
[SableOS] SableOS oxynoded B1 starting
[SableOS] Rust userspace probe successful
[SableOS] version=SableOS oxynoded B1
```

Manual B1 parity checks:

- cellular Internet: **PASS**
- outgoing call: **PASS**
- incoming call: **PASS**
- SMS send: **PASS**
- SMS receive: **PASS**
- LTE/NR capability retained

B1 physical Rust + telephony regression gate: **PASS**.

Local acceptance record remains outside GitHub under `$G025ELOG/B1/`.

## Phase 8 — B1.1 acceptance

B1.1 adds only init-managed startup and a dedicated SELinux domain for the B1-validated Rust code.

Pre-full-build policy gates have already passed; see `B1_1_VALIDATION.md`.

Before flashing B1.1:

1. full build must succeed;
2. target-files/artifacts must pass integrity checks;
3. B1 -> B1.1 partition deltas must be understood;
4. bootloader/radio/vendor boundaries must be reviewed;
5. the flash package must not casually include bootloader/radio firmware.

After a safe B1.1 flash, validate:

```bash
adb shell getenforce
adb shell getprop init.svc.oxynoded
adb shell ps -AZ | grep oxynoded
adb shell ls -Z /system_ext/bin/oxynoded
```

Required results:

- SELinux = `Enforcing`
- init service = `running`
- process domain = `u:r:oxynoded:s0`
- process UID = `system`, not root
- executable file type = `oxynoded_exec`
- daemon remains running across time and reboot
- no unexpected `oxynoded` AVCs are papered over with broad policy

Then repeat the relevant B0/B1 capability baseline, especially:

- Wi-Fi/Bluetooth
- audio/call routing
- cellular Internet
- LTE/NR behavior
- outgoing/incoming voice
- SMS send/receive
- MMS where practical
- camera/sensors
- USB/ADB
- suspend/resume/charging

B1.1 passes only when the new service/security behavior works **and** the working AOSP/vendor baseline remains intact.

## AOSP/vendor reuse gate for later milestones

After B1.1, UI/framework cleanup must not start with deletion.

Before removing or replacing any inherited AOSP/vendor component:

1. identify the capability it provides;
2. identify dependencies and data flows;
3. inspect privilege/SELinux/Binder/socket/device/network access;
4. determine whether unwanted behavior can be constrained while retaining the capability;
5. prefer a narrow Sable broker/policy boundary over reimplementation when it safely preserves mature functionality;
6. prove replacement parity on the physical G025E before declaring the old component obsolete.

This applies to media, Bluetooth, Wi-Fi, audio, Telecom, notifications, camera, sensors, power, storage, updates, automotive/accessory interoperability, and other mature platform capabilities — not only telephony.

## Acceptance rule

The G025E remains the reference platform only while new Sable milestones preserve:

- the privacy/security boundary of narrow services and enforcing SELinux;
- the known-good bootloader/vendor/radio boundary;
- the relevant physical AOSP/vendor capability baseline;
- reproducible build and restore evidence.

A feature that boots but regresses mature baseline functionality has not passed the reference-platform gate.
