# sablectl — SableOS host validation CLI plan

Date: 2026-09-08
Status: v0.2 implementation delivered; live Panther D4 acceptance run pending

## Purpose

`sablectl` is the reusable host-side validation and regression tool for SableOS development. It replaces one-off post-boot shell harnesses with typed checks, deterministic subprocess handling, structured evidence and named acceptance suites.

## Delivered milestones

### v0.1 — operationally closed on Panther B2

```text
pytest=PASS_6_OF_6
sablectl doctor=PASS
sablectl device wait=PASS
sablectl verify boot=PASS_11_OF_11
ART exact match=PASS_5_OF_5
sablectl smoke=PASS_16_OF_16
baseline capture=PASS
verify preserved-data=PASS_3_OF_3
smoke + baseline=PASS_19_OF_19
```

The first post-B2 baseline is the reference for subsequent deployments and is not retrospective pre-B2 evidence.

### v0.2 — D4 named acceptance suite delivered

New command:

```text
sablectl acceptance d4
```

Required inputs:

```text
--target-files <exact packaged target-files>
--baseline <pre-deployment sablectl baseline>
--expected-slot <slot>
```

The suite combines v0.1 exact identity/smoke/preserved-data checks with:

- crash-buffer audit scoped to the current boot;
- Wi-Fi framework status and validated-network observation;
- telephony registry and cellular-data observation;
- IMS observation where exposed;
- Bluetooth manager state;
- USB/ADB function health;
- battery service and sane battery level;
- Sable power-service observation, currently SKIP until the Panther service port exists;
- WebView provider through read-only `dumpsys webviewupdate`;
- Home/browser/dialer/SMS role holders using the current Android `cmd role get-role-holders` interface;
- explicit `MANUAL` results for voice, SMS, MMS, hotspot, Bluetooth audio, camera quality, location, biometrics and NFC.

Result semantics now distinguish:

```text
PASS
PASS_WITH_MANUAL
FAIL
```

`--require-complete` returns exit 4 while manual gates remain. FAIL/ERROR returns exit 2.

Local delivery validation:

```text
compileall=PASS
pytest=PASS_11_OF_11
adb reboot execution path=ABSENT
pm install execution path=ABSENT
pm uninstall execution path=ABSENT
fastboot execution path=ABSENT
wipe flag execution path=ABSENT
shell=True=ABSENT
```

v0.2 remains read-only. APK install/uninstall and reboot/persistence automation are deferred until they have separate authorization gates and negative tests.

## Design principles

1. Packaged `target_files.zip` is the release/device source of truth.
2. Collection, checks, suites, actions and reporting remain separate layers.
3. Every check is typed: PASS, FAIL, SKIP, MANUAL or ERROR.
4. Child subprocess stdin is isolated; no `shell=True` host execution.
5. Reports are machine-readable and mask serial identifiers by default.
6. Mutating operations require explicit, separately tested authorization gates.

## Current command surface

```text
sablectl doctor
sablectl device wait
sablectl baseline capture
sablectl verify boot
sablectl verify preserved-data
sablectl smoke
sablectl acceptance d4
```

## Next after live v0.2 closure

### v0.2.1 / v0.3 host actions and device agent

- separately authorized reboot/persistence test;
- separately authorized APK install/launch/uninstall fixture;
- richer crash/ANR/tombstone evidence;
- SableTestAgent instrumentation integration for camera, sensors, audio, location, WebView, notifications, storage, lifecycle and selected permission paths.

### v0.4 deployment and lab automation

Only after read-only and bounded mutating test actions are proven:

- controlled reboot/flash orchestration;
- OTA apply/verify;
- active/inactive-slot policy;
- rollback/fallback checks;
- multi-device lab support;
- release-candidate batch execution.

## Release target

A future SableOS release candidate should emit:

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
