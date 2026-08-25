# G025E hardware acceptance and safe-flash runbook

This runbook is for the Google Pixel 4a 5G G025E (`bramble`) used to validate SableOS B0 and B1.

## Safety rules

1. Capture the factory state before unlocking or flashing anything.
2. Bootloader unlocking erases user data. Back up anything important first.
3. Do **not** flash `bootloader.img` or `radio.img` until the factory bootloader/baseband versions have been captured and compared.
4. Do **not** use `fastboot flashing unlock_critical` for this workflow.
5. Do **not** relock the bootloader while B0/B1 custom images are installed.
6. Stop if the device reports a product other than `bramble`, OEM unlocking is unavailable, Fastboot is unstable, or any version check is ambiguous.
7. Keep device serial numbers and IMEI values in local logs only; do not commit them to this repository.

Official references:

- Bootloader locking/unlocking: https://source.android.com/docs/core/architecture/bootloader/locking_unlocking
- AOSP Fastboot flashing: https://source.android.com/docs/setup/test/running

## Phase 0 — host preparation

Use one consistent pair of `adb`/`fastboot` binaries for the session and record their versions.

```bash
export G025ELOG=/srv/data/sableos_device_logs/G025E
mkdir -p "$G025ELOG/factory" "$G025ELOG/post-unlock" "$G025ELOG/B0" "$G025ELOG/B1"

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

## Phase 1 — factory Android state

Before changing Developer options beyond what is necessary for ADB/OEM unlocking, capture the shipped software identity.

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

Allow Android to boot, complete minimal setup, then re-enable USB debugging. Do not relock the bootloader during B0/B1 testing.

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

## Phase 5 — compatibility gate before flashing B0

Do not blindly flash the archived `bootloader.img` or `radio.img`.

Compare the factory values captured in `fastboot-vars.txt` against the software level expected by the pinned B0 baseline (`SQ3A.220705.003.A1`). If the phone ships with a newer bootloader/baseband, do not downgrade them just to match B0 without an explicit compatibility review.

Before issuing a whole-device Fastboot command, inspect the exact package or product output that Fastboot will consume, especially its `android-info.txt` requirements and whether it contains bootloader/radio images.

AOSP's `img_from_target_files.py` can convert target-files into an image ZIP intended for `fastboot update`. Inspect the generated ZIP before using it; if it contains bootloader/radio images, stop and review rather than flashing automatically.

## Phase 6 — B0 acceptance

B0 is the control build. It must pass before B1 is tested.

After B0 is safely flashed and booted, record:

```bash
adb shell getprop ro.build.id
adb shell getprop ro.build.fingerprint
adb shell getprop ro.product.device
adb shell getprop gsm.version.baseband
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.boot.verifiedbootstate
```

Then validate at minimum:

- boot and UI stability
- display and touch
- Wi-Fi
- Bluetooth
- SIM detection
- cellular data
- LTE and 5G registration where available
- SMS send/receive
- voice calling
- IMS/VoLTE behavior
- earpiece, speaker and microphone
- camera
- sensors
- USB/ADB
- suspend/resume and charging

Record pass/fail and observations in `$G025ELOG/B0/`.

### B0 stop rule

If B0 has a hardware regression, do **not** continue to B1. Establish whether the problem is the AOSP/vendor baseline first.

## Phase 7 — B1 acceptance

Only after B0 passes should B1 be flashed.

Repeat the same hardware checklist. Then validate the Rust executable:

```bash
adb root
adb wait-for-device
adb shell /system_ext/bin/oxynoded --probe
```

Expected output:

```text
[SableOS] SableOS oxynoded B1 starting
[SableOS] Rust userspace probe successful
[SableOS] version=SableOS oxynoded B1
```

Confirm its installed identity if needed:

```bash
adb shell ls -l /system_ext/bin/oxynoded
adb shell sha256sum /system_ext/bin/oxynoded
```

Expected SHA-256:

```text
753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45
```

Record results in `$G025ELOG/B1/`.

## Acceptance criteria for B1

B1 passes when:

- B0 hardware acceptance has already passed
- B1 boots reliably
- the B0 hardware checklist still passes
- `oxynoded --probe` exits successfully with the expected version
- the installed `oxynoded` hash matches the frozen B1 artifact
- no unexpected SELinux weakening or broad privileges have been introduced

## After B1 passes

The next milestone is B1.1:

- add an init service for `oxynoded`
- add a dedicated SELinux domain and file type
- keep SELinux enforcing
- grant only narrowly required permissions
- do not run `oxynoded` in the generic `init` domain

Do not begin B1.1 until the physical G025E acceptance record is complete.
