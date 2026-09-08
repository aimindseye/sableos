# sablectl v0.1

`sablectl` is the host-side validation and regression CLI for SableOS development.
It is intentionally report-first: read-only validation is the default, while future
reboot/flash actions will live behind separate explicit authorization gates.

## v0.1 goals

- select and pin exactly one ADB device;
- capture repeatable baselines;
- read the packaged SableOS `target_files.zip` as the expected-build source of truth;
- verify the live device booted the expected build by exact BuildManifest and ART hashes;
- verify preserved userdata by exact third-party package-set and Android-user checks;
- run a reusable smoke suite;
- emit terminal, JSON, Markdown and JUnit reports;
- avoid fragile shell pipelines and stdin-sharing bugs.

## Install

```bash
python3 -m pip install -e .
```

For development:

```bash
python3 -m pip install -e '.[dev]'
pytest -q
```

## Commands

```bash
sablectl doctor
sablectl device wait --timeout 180
sablectl baseline capture
sablectl verify boot --target-files /path/to/panther-target_files.zip --expected-slot b
sablectl verify preserved-data --baseline .sablectl/baselines/<run>/baseline.json
sablectl smoke --target-files /path/to/panther-target_files.zip --expected-slot b
```

A baseline can be combined with smoke validation:

```bash
sablectl smoke \
  --target-files /path/to/panther-target_files.zip \
  --expected-slot b \
  --baseline .sablectl/baselines/<pre-flash>/baseline.json
```

Every validation run writes:

```text
report.json
report.md
junit.xml
```

## Status model

Each check returns one of:

```text
PASS
FAIL
SKIP
MANUAL
ERROR
```

`FAIL` and `ERROR` make a suite fail. `SKIP` and `MANUAL` remain visible without
being collapsed into generic success or failure.
