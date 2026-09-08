# sablectl v0.2

`sablectl` is the host-side validation and regression CLI for SableOS development.

v0.2 keeps the v0.1 exact packaged-build identity and preserved-data checks and adds the first named D4 acceptance suite. Read-only validation remains the default. Physical checks which cannot yet be proven reliably through host ADB remain explicit `MANUAL` results rather than being silently treated as passes.

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
  --expected-slot b \
  --hash-container
```

The D4 suite combines exact BuildManifest + five ART identity, boot/slot/encryption, SELinux/core services, PackageManager, preserved-data baseline checks, crash-since-boot audit, Wi-Fi/connectivity, telephony/IMS observation, Bluetooth, USB/ADB, battery/power, WebView, default roles, and explicit physical/manual gates.

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

By default `PASS_WITH_MANUAL` returns exit code 0. Add `--require-complete` to return exit code 4 while manual gates remain:

```bash
sablectl acceptance d4 ... --require-complete
```

`FAIL` or `ERROR` returns exit code 2.

## Evidence

Every validation run writes `report.json`, `report.md`, and `junit.xml`. Reports mask ADB serials. JSON includes `overall`, `complete`, typed results and target-files/baseline metadata.

## Safety

v0.2 does not flash, wipe, unlock, install APKs or reboot the device. Those mutating test actions remain deferred until they have separate authorization gates and negative tests.
