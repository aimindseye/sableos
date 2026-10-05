# Titan 2 N1I-C1 physical runtime qualification

Status: **tooling-only physical evidence package**. It does not build or flash an
image and never mutates a connected device.

## Image and tooling authority

The physical run is bound to the already-qualified C1 image-source commit:

```text
N1I_C1_IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
ANDROID_PLATFORM=16
IMAGE_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
```

The exact `system.img` SHA-256 is deliberately not hard-coded. It comes from
the successful C1 post-build artifact and must equal both the operator-supplied
SHA and the sealed flash/install receipt SHA.

The collector also records `N1I_C1_TOOL_SOURCE_COMMIT`. Before device contact,
all C1 collector/qualifier files and the reused BE2/N1B capture engine must be
tracked and byte-identical to that HEAD. Thus a dirty local tool cannot claim
evidence for an unchanged tool commit.

The tooling branch is independent of the image-source PR. Tool changes do not
change or requalify the C1 image source.

## Read-only contract

Device contact requires the literal authorization:

```text
--authorize-device-contact YES_READ_ONLY
```

All CLI, artifact, SHA, receipt, tool-source and self-test checks happen before
the first adb command. The device must already be in fully booted Android/adbd
mode. If it is offline, unauthorized, in recovery/sideload, bootloader fastboot,
fastbootd, or absent, the collector stops. It never changes device mode.

The collector prohibits:

- property writes, including `persist.vendor.radio.simswitch` and
  `persist.vendor.radio.c_capability_slot`;
- RIL/modem/service restarts;
- airplane-mode, data or radio toggles;
- APN insert/update/delete;
- package mutation;
- reboot/flash/erase/resize commands;
- retry, recovery or “healing” actions.

The only admitted `cmd phone` forms are the four exact read-only
`ims get-ims-service` queries for slots 0 and 1. `content` access is
read-only and limited to the preferred-APN and siminfo queries.

The existing `capture-n1b2-cellular-runtime.sh` remains the long-window
BE2/N1B capture engine in its unchanged default profile. The C1 wrapper adds
bounded read-only start/end snapshots; it does not fork the BE2 state/timeline
machinery.

## Cryptographic device/image binding

### Qualified C1 artifact

The artifact directory must contain:

```text
artifact.env
system.img
SHA256SUMS.txt
```

with:

```text
ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
QUALIFICATION_MODE=POSTBUILD_READONLY
SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
ANDROID_PLATFORM=16
SYSTEM_SHA256=<exact corrected C1 SHA-256>
```

The SHA manifest is verified and `system.img` is independently hashed.

### Sealed flash/install receipt

The separately governed flash path must create:

```text
TITAN2_FLASH_RECEIPT.env
SHA256SUMS.txt
```

with at least:

```text
TITAN2_FLASH_RECEIPT_VERSION=1
DEVICE_SERIAL=<exact target serial>
POST_FLASH_DEVICE_SERIAL=<same serial>
ARTIFACT_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=<exact corrected C1 SHA-256>
TARGET_PARTITION=system_a
FLASH_RESULT=PASS
POST_FLASH_MODE=ANDROID_ADB
```

The collector refuses to reconstruct a missing receipt after the fact.

Required equality:

```text
artifact SYSTEM_SHA256
  == CLI --system-image-sha256
  == flash receipt SYSTEM_SHA256

CLI --serial
  == receipt DEVICE_SERIAL
  == receipt POST_FLASH_DEVICE_SERIAL
```

Android shell properties are runtime corroboration; they are not presented as a
cryptographic hash of the flashed raw logical partition.

## Runtime corroboration

After host-side binding passes, the collector verifies:

- adb transport is exactly the explicitly selected serial;
- `ro.serialno` matches that serial;
- exact stock Titan 2 vendor fingerprint from the committed N1I-F stock control;
- vendor-side device identity is Titan 2 / Unihertz;
- Android 16 / SDK 36;
- `sys.boot_completed=1`;
- active slot is `_a`, matching the sealed `system_a` receipt;
- the active Android build fingerprint is not the stock system fingerprint.

System-side `ro.product.device`, model and manufacturer are **evidence only**.
They are not hard-gated to `Titan_2`, because a Treble/GSI system-side product
identity can legitimately be generic. Physical identity comes from the exact
stock-vendor authority plus the sealed host artifact/receipt binding.

## Scenarios

Run three independent scenarios using the same exact C1 image SHA and device.

```text
tray1: gsm.sim.state=LOADED,ABSENT
tray2: gsm.sim.state=ABSENT,LOADED
dsds:  gsm.sim.state=LOADED,LOADED
```

The collector checks this topology before starting the long capture.

For tray 1 and tray 2, manually exercise:

```text
data
SMS send
SMS receive
MMS send
MMS receive
outgoing voice
incoming voice
```

For DSDS, manually exercise both subscriptions, including SIM1 as DDS and SIM2
as DDS. Any DDS change is an operator UI action. The collector only observes.

Copy `build/titan2/n1i-c1-operator-results.env.example` to a local evidence
directory and replace `PENDING` with only `PASS` or `FAIL`. Never place
phone numbers, IMSI/ICCID/IMEI, contact names or message content in that file.

## Independent functional acceptance

Registration, data, SMS/MMS, IMS provider, IMS registration, IMS bearer,
outgoing voice and incoming voice are independent results. One working surface
never masks another.

### Registration

Single-SIM registration requires the expected SIM topology and three stable
final snapshots with voice and packet service `IN_SERVICE` for the expected
phone. DSDS requires that stable registration for both phones.

### Data

Single-SIM data additionally requires three stable final `CONNECTED`
snapshots, a current validated cellular network and the operator data test.

DSDS data requires both line-specific operator DDS tests **and** observed runs of
connected in-service data for each phone during the capture. A PASS flag alone
cannot substitute for observed phone-level data state.

### SMS/MMS and voice

SMS/MMS requires all send/receive operator tests. Incoming and outgoing voice
remain separate operator-observed results; they are never inferred from
registration or IMS.

### IMS provider

Provider PASS requires the real OEM `com.mediatek.ims` package at the expected
system_ext priv-app path, phone shared-UID / privileged identity, and
slot-specific IMS service exposure. DSDS requires provider exposure for both
slots.

### IMS registration

Single-SIM IMS registration uses an **end-state** decision: current
phone/slot-specific registry evidence when available, otherwise the last
registration transition in the radio/runtime log. An earlier success followed
by a later unregister does not PASS.

DSDS requires phone/slot-specific registered end-state evidence for both lines.

### IMS bearer

A bearer must be cellular, advertise IMS + MMTEL, and be connected or validated.
DSDS aggregate bearer PASS requires two independently observed bearer
instances/interfaces.

`dumpsys ims` is deliberately not a standalone gate because known-working
stock lacks that service.

Known stock transients that are not standalone failures:

```text
ERROR_UNSPECIFIED
transient registration reject causes
early IMS setup errors
mtkImsIndication == NULL
missing dumpsys ims service
```

Recovered stable end state controls.

## Stock parity is diagnostic only

Single-SIM comparison targets:

```text
APN=fast.t-mobile.com
DATA_INTERFACE=ccmni1
IMS_INTERFACE=ccmni2
IMS_CAPABILITIES=IMS,MMTEL
```

These are reported independently from functional acceptance. Functional data
may PASS while the stock APN/interface target FAILs.

Tray-2 comparison additionally looks for phone-1/default-data movement and real
capability-switch evidence such as:

```text
MtkProxyController
SET_RADIO_CAPABILITY
EVENT_UNSOL_RADIO_CAPABILITY_CHANGED
DSSExt
```

No numeric change to the two vendor simswitch/capability properties is required
or performed.

## Static/regression qualification

Before physical use:

```bash
bash -n \
  build/titan2/collect-n1i-c1-physical-runtime.sh \
  build/titan2/n1i-c1-readonly-guard.sh \
  build/titan2/n1i-c1-physical-host-binding.sh \
  build/titan2/n1i-c1-physical-snapshot.sh

python3 -m py_compile \
  build/titan2/n1i_c1_physical_evidence.py \
  build/titan2/n1i_c1_physical_eval.py \
  build/titan2/n1i_c1_physical_selftest.py \
  build/titan2/qualify-n1i-c1-physical-runtime.py \
  tests/titan2/n1i-c1/test-physical-runtime-qualifier.py

bash tests/titan2/n1i-c1/test-physical-runtime-guard.sh
python3 tests/titan2/n1i-c1/test-physical-runtime-qualifier.py
```

The guard regression proves no-contact behavior for missing authorization,
invalid SHA and mismatched receipt serial; non-Android modes are allowed only
the single `adb -s SERIAL get-state` observation. It also proves generic GSI
system-side identity is accepted when the exact vendor/serial/Android/slot
authority is correct.

The qualifier self-test covers independent registration/IMS/voice verdicts,
slot-provider enforcement, final IMS registration semantics, usable bearer
requirements, APN parity separation, stock transient recovery and DSDS
anti-masking/data observation.

## Collect

After the corrected C1 post-build seal and governed flash receipt exist:

```bash
bash build/titan2/collect-n1i-c1-physical-runtime.sh \
  --authorize-device-contact YES_READ_ONLY \
  --serial "$TITAN_SERIAL" \
  --artifact-dir "$C1_ARTIFACT_DIR" \
  --system-image-sha256 "$C1_SYSTEM_SHA256" \
  --flash-receipt "$C1_FLASH_RECEIPT_DIR" \
  --scenario tray1 \
  --duration-min 20
```

Repeat for `tray2` and `dsds`.

Raw C1 snapshots remain local/private. BE2 redaction remains best-effort and
requires manual privacy review before sharing.

## Final qualifier

```bash
python3 build/titan2/qualify-n1i-c1-physical-runtime.py \
  --tray1 "$TRAY1_EVIDENCE" \
  --tray2 "$TRAY2_EVIDENCE" \
  --dsds "$DSDS_EVIDENCE" \
  --operator-results "$OPERATOR_RESULTS" \
  --out "$QUALIFICATION_OUT"
```

Outputs:

```text
N1I_C1_PHYSICAL_RUNTIME_SUMMARY.env
N1I_C1_PHYSICAL_RUNTIME_MATRIX.tsv
N1I_C1_STOCK_COMPARISON.tsv
N1I_C1_PHYSICAL_RUNTIME_REPORT.md
```

The summary always preserves all independent markers:

```text
N1I_C1_TRAY1_REGISTRATION=PASS|FAIL
N1I_C1_TRAY1_DATA=PASS|FAIL
N1I_C1_TRAY1_SMS_MMS=PASS|FAIL
N1I_C1_TRAY1_IMS_PROVIDER=PASS|FAIL
N1I_C1_TRAY1_IMS_REGISTRATION=PASS|FAIL
N1I_C1_TRAY1_IMS_BEARER=PASS|FAIL
N1I_C1_TRAY1_OUTGOING_VOICE=PASS|FAIL
N1I_C1_TRAY1_INCOMING_VOICE=PASS|FAIL

N1I_C1_TRAY2_REGISTRATION=PASS|FAIL
N1I_C1_TRAY2_DATA=PASS|FAIL
N1I_C1_TRAY2_SMS_MMS=PASS|FAIL
N1I_C1_TRAY2_IMS_PROVIDER=PASS|FAIL
N1I_C1_TRAY2_IMS_REGISTRATION=PASS|FAIL
N1I_C1_TRAY2_IMS_BEARER=PASS|FAIL
N1I_C1_TRAY2_OUTGOING_VOICE=PASS|FAIL
N1I_C1_TRAY2_INCOMING_VOICE=PASS|FAIL

N1I_C1_DSDS_REGISTRATION=PASS|FAIL
N1I_C1_DSDS_DATA=PASS|FAIL
N1I_C1_DSDS_SMS_MMS=PASS|FAIL
N1I_C1_DSDS_IMS_PROVIDER=PASS|FAIL
N1I_C1_DSDS_IMS_REGISTRATION=PASS|FAIL
N1I_C1_DSDS_IMS_BEARER=PASS|FAIL
N1I_C1_DSDS_OUTGOING_VOICE=PASS|FAIL
N1I_C1_DSDS_INCOMING_VOICE=PASS|FAIL
```

DSDS also emits per-line internal markers so one line cannot mask the other.
Only after all 24 mandatory surfaces PASS does the optional aggregate become:

```text
N1I_C1_PHYSICAL_RUNTIME_MATRIX=PASS
```
