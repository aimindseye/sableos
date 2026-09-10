# sablectl v0.3 — Panther D4 release gate

Date: 2026-09-08

Status: **DELIVERED / LIVE PANTHER VALIDATION PENDING**

`sablectl` v0.3 adds a read-only D4 release-candidate gate on top of the live-validated v0.2.1 acceptance suite.

## Purpose

The new command binds the existing automated acceptance evidence, manual physical acceptance evidence, active-slot boot-control state and default-role state into one release report:

```text
sablectl release d4
```

It does not reboot, flash, erase, wipe, mark a slot successful, change the active slot, install packages or mutate Android source/build outputs.

## Additional D4-R2 checks

The release gate adds:

```text
release.slot_index
release.slot_bootable
release.slot_successful
release.manual_evidence_identity
release.default_app_set_documented
release.default_app.home
release.default_app.browser
release.default_app.dialer
release.default_app.sms
physical.voice_out
physical.voice_in
physical.sms_out
physical.sms_in
physical.mms_out
physical.mms_in
physical.hotspot
physical.bluetooth_audio
physical.camera
physical.location
physical.biometrics
physical.nfc_rf
```

`bootctl get-current-slot`, `bootctl is-slot-bootable SLOT` and `bootctl is-slot-marked-successful SLOT` are read-only boot-control queries. The release gate deliberately does **not** call `mark-boot-successful`.

## Manual evidence binding

The Panther B2 manual evidence file is:

```text
tools/validation/panther-d4/manual-acceptance-20260908.json
```

It is bound to:

```text
device=panther
build_fingerprint=google/panther/panther:17/CP2A.260705.006/2026090500:userdebug/test-keys
BuildManifest.apk sha256=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

Operator-reported PASS gates retained in that record:

```text
VOICE_OUT
VOICE_IN
SMS_OUT
SMS_IN
MMS_OUT
MMS_IN
HOTSPOT
BLUETOOTH_AUDIO
CAMERA
LOCATION
BIOMETRICS
```

NFC RF/tag interaction is recorded as:

```text
NOT_TESTED_NO_HARDWARE
```

That is an explicit non-blocking `SKIP`, not a PASS. The separately observed NFC feature/service/HAL/initialization/enable path was healthy, but no tag/test peer was available for RF interaction.

## Documented current default-role set

The release evidence records and the gate rechecks:

```text
HOME    com.android.launcher3
BROWSER app.vanadium.browser
DIALER  com.android.dialer
SMS     com.android.messaging
```

A mismatch is a release-gate FAIL.

## Run on ThinkPad-P50

```bash
cd /home/mindseye73/sableos-tools

git pull --ff-only

"$HOME/.venvs/sablectl/bin/python" -m pip install -e './tools/sablectl[dev]'

"$HOME/.venvs/sablectl/bin/python" -m pytest ./tools/sablectl/tests -q

TF=/srv/data/sableos_panther_graphene_2026081300_workspace/out_d4_b2_final/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target_files.zip
BASELINE=/home/mindseye73/sableos-tools/.sablectl/baselines/20260908T181640Z/baseline.json
MANUAL=/home/mindseye73/sableos-tools/tools/validation/panther-d4/manual-acceptance-20260908.json

sablectl release d4 \
  --target-files "$TF" \
  --baseline "$BASELINE" \
  --manual-evidence "$MANUAL" \
  --expected-device panther \
  --expected-slot b

echo "RELEASE_D4_RC=$?"
```

Do not add `--hash-container` for routine reruns; the 3.65 GB B2 target-files container was already independently SHA-256 bound during the physical-flash evidence chain.

## Expected healthy result

The exact PASS/SKIP cardinality depends on platform-observable IMS and NFC RF availability. Release success requires:

```text
FAIL=0
ERROR=0
MANUAL=0
OVERALL=PASS
RELEASE_D4_RC=0
```

Expected non-blocking SKIPs on the current B2 stage include:

```text
telephony.ims_observable
power.sable_service
physical.nfc_rf
```

The release gate is not considered live-validated until the physical Panther run produces a retained report directory and exit code 0.
