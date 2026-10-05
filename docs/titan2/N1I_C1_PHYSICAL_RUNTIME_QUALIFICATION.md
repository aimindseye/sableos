# Titan 2 N1I-C1 physical runtime qualification

Status: tooling-only physical evidence package. It does not build or flash an
image and it never mutates a connected device.

## Image authority

The physical run is bound to the already-qualified C1 image-source commit:

```text
N1I_C1_IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
ANDROID_PLATFORM=16
IMAGE_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
```

The exact system-image SHA-256 is deliberately not hard-coded in source. It is
read from the successful post-build C1 artifact and must equal both the
operator-supplied SHA and the sealed flash/install receipt SHA.

The collector is a tooling layer only. Adding or changing this collector does
not change the C1 image source commit.

## Read-only contract

Device contact requires the literal authorization:

```text
--authorize-device-contact YES_READ_ONLY
```

All artifact, SHA, flash-receipt and CLI validation happens before adb is looked
up or invoked. The device must already be in fully booted Android/adbd mode.
The collector never attempts to transition from bootloader fastboot, fastbootd,
recovery, sideload, offline or unauthorized state.

The collector prohibits property writes, RIL/service restarts, airplane-mode or
data toggles, APN edits, SIM-switch property writes, package mutation,
reboot/flash commands, and any recovery/healing behavior. The only `cmd phone`
forms admitted are the four exact read-only IMS-service queries for slots 0 and
1. The only `content` forms admitted are exact read-only queries for preferred
APN and siminfo.

The existing `capture-n1b2-cellular-runtime.sh` remains the BE2/N1B long-window
capture engine. C1 does not fork its state/timeline machinery. Before contact,
the wrapper reruns the historical N1B read-only guard test plus its own C1 guard
and qualifier self-tests.

## Cryptographic binding

Three bindings are required.

### Qualified artifact

The artifact directory must contain:

```text
artifact.env
system.img
SHA256SUMS.txt
```

and `artifact.env` must contain:

```text
ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
QUALIFICATION_MODE=POSTBUILD_READONLY
SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
ANDROID_PLATFORM=16
SYSTEM_SHA256=<exact corrected C1 SHA-256>
```

The collector verifies `SHA256SUMS.txt` and independently hashes `system.img`.

### Sealed flash/install receipt

The separately governed flashing path must produce a directory containing:

```text
TITAN2_FLASH_RECEIPT.env
SHA256SUMS.txt
```

Minimum receipt contract:

```text
TITAN2_FLASH_RECEIPT_VERSION=1
DEVICE_SERIAL=<exact adb/flash target serial>
ARTIFACT_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=<exact corrected C1 SHA-256>
TARGET_PARTITION=system_a
FLASH_RESULT=PASS
POST_FLASH_DEVICE_SERIAL=<same exact serial>
POST_FLASH_MODE=ANDROID_ADB
```

The receipt is evidence produced by the flash path; do not reconstruct one after
the fact. Its SHA manifest is verified before any device contact.

The collector requires:

```text
artifact SYSTEM_SHA256
  == CLI --system-image-sha256
  == flash receipt SYSTEM_SHA256

CLI --serial
  == receipt DEVICE_SERIAL
  == receipt POST_FLASH_DEVICE_SERIAL
```

Android shell properties are runtime corroboration, not a claim that shell can
cryptographically re-hash the flashed raw logical system image.

### Runtime identity

After host-side binding, the device must report Android 16 / SDK 36, completed
boot, Titan 2 identity, Unihertz manufacturer and the Titan 2 stock-vendor
fingerprint family. `ro.serialno` must equal the explicitly selected adb serial.

## Collection scenarios

Run three independent scenarios with the same C1 system-image SHA.

### Tray 1

One physical SIM in tray 1 only. Expected end-state SIM property:

```text
gsm.sim.state=LOADED,ABSENT
```

During the capture window manually exercise data, SMS send/receive, MMS
send/receive, outgoing voice and incoming voice. The collector itself initiates
none of these actions.

### Tray 2

Move the same SIM to tray 2 only and boot normally before starting collection.
Expected state:

```text
gsm.sim.state=ABSENT,LOADED
```

Repeat the same user tests. The collector does not reboot the device and does
not write `persist.vendor.radio.simswitch` or
`persist.vendor.radio.c_capability_slot`.

### DSDS

Insert two physical SIMs. Expected state:

```text
gsm.sim.state=LOADED,LOADED
```

Manually validate data with SIM1 as default-data subscription and then SIM2 as
default-data subscription. Also validate SMS/MMS and incoming/outgoing voice on
both subscriptions independently. Any default-data switch is performed through
the normal Android UI; the collector only observes the resulting state.

## Operator results

Copy:

```text
build/titan2/n1i-c1-operator-results.env.example
```

to a local evidence directory and replace every required `PENDING` with `PASS`
or `FAIL`. Never put phone numbers, subscriber IDs or message contents in this
file.

## Functional acceptance

Registration, data, SMS/MMS, IMS provider, IMS registration, IMS bearer,
outgoing voice and incoming voice are separate results. A working surface can
never mask a failed one.

Registration requires the correct tray state and three stable final BE2
snapshots with voice and packet registration `IN_SERVICE` for the expected
phone. Data additionally requires three final `CONNECTED` snapshots, a current
validated cellular network, and the manual data result.

IMS provider requires `com.mediatek.ims` at the expected system_ext priv-app
path with `android.uid.phone` and privileged/system identity. IMS registration
uses successful end-state registration evidence; early startup errors are not
standalone failures. For DSDS, both phone IDs need slot/phone-specific registry
registration evidence. IMS bearer requires a connected cellular IMS/MMTEL
network; DSDS requires evidence of two bearer instances/interfaces.

`dumpsys ims` is deliberately not a standalone gate because the known-working
stock Titan 2 lacks that service while IMS and real voice work.

The following known stock transients are not standalone failure criteria:

```text
ERROR_UNSPECIFIED
transient registration reject causes
an early IMS setup error
mtkImsIndication == NULL
missing dumpsys ims service
```

Recovered stable end state controls.

## Stock comparison targets

Functional acceptance and stock parity are reported separately. Diagnostic
single-SIM targets include:

```text
APN=fast.t-mobile.com
DATA_INTERFACE=ccmni1
IMS_INTERFACE=ccmni2
IMS_CAPABILITIES=IMS,MMTEL
```

For tray 2, the comparison additionally looks for framework/default-phone state
on phone 1 plus real capability-switch evidence such as `MtkProxyController`,
`SET_RADIO_CAPABILITY`, `EVENT_UNSOL_RADIO_CAPABILITY_CHANGED`, or `DSSExt`.
No property-value change is required for `persist.vendor.radio.simswitch` or
`persist.vendor.radio.c_capability_slot`.

Stock-target failures are diagnostic only. For example, functional C1 data may
PASS while `N1I_C1_TRAY1_STOCK_APN_TARGET=FAIL`; the qualifier preserves both.

## Run collector

Example after C1 post-build qualification and a governed flash have both
produced their seals:

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

Repeat with `--scenario tray2` and `--scenario dsds`.

Raw C1 snapshots are intentionally local/private. The reused BE2 capture keeps
its existing redaction behavior, which remains best-effort and requires manual
privacy review before sharing.

## Final qualification

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

The summary always preserves the independent matrix:

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

## Regression/self-tests

Before physical use run:

```bash
bash -n build/titan2/n1i-c1-readonly-guard.sh
bash -n build/titan2/collect-n1i-c1-physical-runtime.sh

python3 -m py_compile \
  build/titan2/qualify-n1i-c1-physical-runtime.py \
  tests/titan2/n1i-c1/test-physical-runtime-qualifier.py

bash tests/titan2/n1i-c1/test-physical-runtime-guard.sh
python3 tests/titan2/n1i-c1/test-physical-runtime-qualifier.py
```

The collector also runs the guard/qualifier self-tests itself before its first
adb contact. Thus a later regression in the read-only contract blocks physical
collection instead of relying on an operator to remember a historical rule.
