# sablectl v0.3

`sablectl` is the host-side validation and regression CLI for SableOS development.

v0.3 keeps the v0.1 exact packaged-build identity and preserved-data checks, the v0.2/v0.2.1 D4 acceptance suite, and adds a read-only D4 release-candidate gate. The release gate binds automated acceptance, active-slot boot-control state, manual physical evidence and the documented default-role set into one machine-readable report.

## Install / upgrade

From the SableOS checkout:

```bash
python3 -m pip install -e 'tools/sablectl[dev]'
pytest -q tools/sablectl/tests
```

Editable installs update automatically when the checkout changes.

## Core commands

```bash
sablectl doctor
sablectl device wait --timeout 180
sablectl baseline capture
sablectl verify boot --target-files /path/to/panther-target_files.zip --expected-slot b
sablectl verify preserved-data --baseline .sablectl/baselines/<run>/baseline.json
sablectl smoke --target-files /path/to/panther-target_files.zip --expected-slot b
```

## D4 acceptance

```bash
sablectl acceptance d4 \
  --target-files /path/to/panther-target_files.zip \
  --baseline .sablectl/baselines/<pre-deployment>/baseline.json \
  --expected-device panther \
  --expected-slot b
```

The D4 suite combines exact BuildManifest + five ART identity, boot/slot/encryption, SELinux/core services, PackageManager, preserved-data baseline checks, crash-since-boot audit, Wi-Fi/connectivity, telephony/IMS observation, Bluetooth, USB/ADB, battery/power, WebView, default roles, and explicit physical/manual gates.

Use `--require-complete` when you want unresolved `MANUAL` gates to return exit code 4.

## D4 release gate

After physical/manual evidence is captured, run:

```bash
sablectl release d4 \
  --target-files /path/to/panther-target_files.zip \
  --baseline .sablectl/baselines/<pre-deployment>/baseline.json \
  --manual-evidence tools/validation/panther-d4/manual-acceptance-20260908.json \
  --expected-device panther \
  --expected-slot b
```

The release gate re-runs the automated D4 checks and additionally verifies:

```text
bootctl current slot
slot bootable state
slot marked-successful state
manual evidence device/build binding
required physical PASS results
documented HOME/browser/dialer/SMS role holders
```

`physical.nfc_rf=NOT_TESTED_NO_HARDWARE` is represented as an explicit non-blocking `SKIP`, never as a fabricated PASS. A release-gate PASS requires `FAIL=0`, `ERROR=0`, `MANUAL=0`, `OVERALL=PASS`, exit code 0.

## Result semantics

Every check returns one of:

```text
PASS
FAIL
SKIP
MANUAL
ERROR
```

Suite overall status is:

```text
PASS
PASS_WITH_MANUAL
FAIL
```

`MANUAL` means the automated portion has not proven the corresponding physical gate. It is never silently converted into `PASS`.

`FAIL` or `ERROR` returns exit code 2. `acceptance d4 --require-complete` returns exit code 4 while manual gates remain.

## Evidence

Every validation run writes `report.json`, `report.md`, and `junit.xml`. Reports mask ADB serials. JSON includes `overall`, `complete`, typed results and target-files/baseline metadata.

## Safety

v0.3 does not flash, wipe, unlock, install APKs, reboot the device, mark a slot successful, or change the active slot. Mutating test and deployment actions remain deferred until they have separate authorization gates and negative tests.
