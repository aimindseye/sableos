# sablectl — SableOS host validation CLI plan

Date: 2026-09-08
Status: v0.1 implemented and live-validated on Panther B2

## Purpose

`sablectl` is the reusable host-side validation and regression tool for SableOS development. It replaces one-off post-boot shell harnesses with typed checks, deterministic subprocess handling, structured evidence and named acceptance suites.

The primary development loop becomes:

```text
source change
  -> build
  -> target_files.zip
  -> controlled deployment
  -> sablectl smoke
  -> sablectl acceptance <milestone>
  -> manual checkpoints where truly required
  -> JSON / Markdown / JUnit evidence
```

## v0.1 live validation result

The first physical Panther run on the successfully flashed D4 B2 device closed the exact post-boot gap left by the historical R10R3 shell harness.

Host installation/self-test:

```text
pytest=PASS_6_OF_6
sablectl doctor=PASS
sablectl device wait=PASS
```

Exact packaged B2 verification:

```text
sablectl verify boot
PASS=11 FAIL=0 SKIP=0 MANUAL=0 ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/verify-boot/20260908T181140Z
```

The run proved:

```text
device=panther
boot_completed=1
active_slot=_b
crypto=encrypted
BuildManifest exact match=PASS
ART exact match=PASS_5_OF_5
artifact.art.count expected=5 actual=5
```

Initial smoke:

```text
sablectl smoke
PASS=16 FAIL=0 SKIP=0 MANUAL=0 ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/smoke/20260908T181212Z
```

Additional runtime checks:

```text
SELinux=Enforcing
servicemanager=running
surfaceflinger=running
zygote=running
PackageManager=PASS installed_packages=229
```

This establishes `sablectl` as the maintained post-boot validation path for Panther development.

## Design principles

### 1. Packaged build is the source of truth

Release/device validation compares the live device against `target_files.zip`, not loose product-output files when the two namespaces differ.

### 2. Separate collection, checks, suites, actions and reports

```text
COLLECT
  capture facts/evidence

CHECK
  compare facts to explicit expectations

SUITE
  compose checks into a named gate

ACTION
  mutating operation; explicit authorization required

REPORT
  serialize results without changing semantics
```

### 3. Typed result model

Every check returns one of:

```text
PASS
FAIL
SKIP
MANUAL
ERROR
```

A non-applicable or manual check must not be silently converted into pass/fail.

### 4. No ambient shell authority

- no `shell=True` host execution;
- subprocess stdin isolated from caller input;
- ADB serial pinned before commands;
- no generic device root requirement for validation;
- mutating operations are separate from read-only validation.

### 5. Evidence is a first-class output

Each run produces or is designed to produce:

```text
report.json
report.md
junit.xml
raw evidence files as needed
```

Reports mask serial/device identifiers by default while preserving exact local evidence where explicitly requested.

## v0.1 implementation

Repository path:

```text
tools/sablectl/
```

Commands:

```text
sablectl doctor
sablectl device wait
sablectl baseline capture
sablectl verify boot
sablectl verify preserved-data
sablectl smoke
```

### `doctor`

- ADB executable present;
- exactly one authorized device unless serial explicitly selected.

### `baseline capture`

Captures timestamped evidence including:

- `getprop`;
- package lists;
- third-party packages;
- features;
- Android users;
- battery;
- Wi-Fi;
- connectivity;
- telephony registry;
- Bluetooth manager;
- location;
- SELinux state.

It also stores a structured device snapshot for later preserved-data comparison.

The first B2 baseline should be captured now and used as the reference for subsequent deployments. It is post-B2 and must not be used to retroactively claim pre-B2 package/user preservation for the already-completed flash.

### `verify boot`

Given the exact `target_files.zip`:

- parse nested `BuildManifest.apk/assets/build_manifest.pb`;
- compute expected installed BuildManifest SHA-256;
- compute expected SHA-256 for the five D4 ART residual files;
- verify device codename;
- verify `sys.boot_completed=1`;
- verify expected slot when requested;
- verify encrypted state;
- compare installed BuildManifest exactly;
- compare all five ART files exactly;
- require an explicit aggregate 5/5 result.

The implementation uses Python subprocesses with `stdin=DEVNULL`; an ADB child cannot consume the parent validation loop input. The first live Panther run proved the full 5/5 path.

### `verify preserved-data`

Against a pre-flash baseline:

- credential-encrypted user-0 data available;
- exact third-party package set preserved;
- Android user count preserved.

Future versions can add stronger stable identifiers for user/profile and selected application data without collecting sensitive content.

### `smoke`

Combines:

- exact boot/build identity;
- exact ART identity;
- SELinux enforcing;
- `servicemanager`, `surfaceflinger`, `zygote` running;
- PackageManager responding;
- optional preserved-data checks.

The first live Panther smoke run passed 16/16 checks.

## v0.2 — D4 automated acceptance

Next host checks:

- crash/ANR/tombstone and DropBox audit;
- Wi-Fi state and reconnect;
- connectivity/default network;
- cellular registration/data;
- IMS state where observable;
- Bluetooth adapter/service state;
- USB/ADB health;
- battery/charging and Sable power-service checks;
- PackageManager/default role validation;
- WebView provider identity;
- package install/launch test;
- notification host-observable sanity;
- reboot/persistence suite;
- D4 named suite and release-gate summary.

## v0.3 — SableTestAgent integration

`sablectl` orchestrates a test-only Android instrumentation APK and ingests structured results for:

- camera;
- sensors;
- audio;
- location;
- WebView;
- notifications;
- storage;
- lifecycle;
- selected permission paths.

See `SABLETEST_AGENT_PLAN.md`.

## v0.4 — deployment and lab automation

Only after read-only validation is stable:

- controlled reboot/flash orchestration;
- OTA apply/verify workflows;
- active/inactive-slot policy;
- rollback/fallback checks;
- multi-device serial inventory;
- self-hosted hardware runner support;
- release-candidate batch execution.

Mutating commands must retain the explicit authorization model proven during Panther D4: contact, reboot, flash, slot and wipe authorities are separate decisions.

## Testing requirements

Every release must include unit tests for:

- subprocess stdin isolation;
- target-files parsing;
- all expected artifact loops reaching full cardinality;
- device serial selection;
- result aggregation;
- baseline comparisons;
- report generation.

New mutating features additionally require negative tests for forbidden operations and interrupted workflows.

## Release integration

A future SableOS release candidate should be able to produce:

```text
BUILD_ARTIFACT_IDENTITY=PASS
DEPLOYMENT=PASS
BOOT=PASS
SMOKE=PASS
PRESERVED_DATA=PASS
D4_AUTOMATED_ACCEPTANCE=PASS
D4_MANUAL_ACCEPTANCE=PASS
RELEASE_CANDIDATE=PASS
```

with exact machine-readable report artifacts attached to the release evidence record.
