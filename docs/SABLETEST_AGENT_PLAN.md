# SableTestAgent — Android instrumentation validation agent plan

Date: 2026-09-08
Status: planned after `sablectl` host validation stabilizes

## Purpose

SableTestAgent is a **test-only Android APK** used by `sablectl` to exercise Android APIs that cannot be proven reliably through host-side `adb`, `getprop` or `dumpsys` alone.

It is not a production SableOS component and must not become a generic privileged command executor.

## Trust model

```text
sablectl host
    -> adb shell am instrument
    -> SableTestAgent instrumentation
    -> ordinary Android APIs / test permissions
    -> structured result bundle
```

Rules:

- no generic root shell API;
- no arbitrary command-execution endpoint;
- no persistent background daemon;
- no network dependency for ordinary tests;
- use normal Android permission/app-op boundaries wherever possible;
- any privileged test-only permission must be narrowly justified and unavailable to production builds;
- test APK absent from release product images by default.

## Initial test modules

### Camera

- enumerate front/rear cameras;
- open each camera;
- capture a small still frame;
- verify callback completion and non-empty image;
- optionally record a short video in later revisions.

### Sensors

- enumerate required sensor classes;
- subscribe to accelerometer/gyro/proximity/light where available;
- require samples within timeout;
- report missing hardware as `SKIP` only when capability policy marks it optional.

### Location

- request an ordinary app location fix;
- distinguish provider unavailable, permission missing, timeout and successful fix;
- avoid storing precise coordinates in normal reports.

### Audio

- play deterministic short audio;
- record through ordinary microphone API where permission is granted;
- verify capture buffer activity;
- physical audible-quality validation remains manual.

### WebView

- instantiate WebView;
- load local bundled HTML without network dependency;
- execute a small JavaScript bridge sanity check;
- report provider/package/version.

### Notifications

- create test notification channel;
- post notification;
- verify application-side lifecycle/state;
- host-side checks can additionally inspect notification service state.

### Storage and persistence

- write/read device-protected storage before credential unlock where applicable;
- write/read credential-protected storage after unlock;
- persist a test token across reboot for a dedicated persistence suite;
- never inspect arbitrary user application content.

### Lifecycle

- Activity create/start/resume/pause/stop/recreate;
- foreground service behavior where relevant;
- process-death/relaunch persistence in later versions.

### Permissions

- explicit grant/deny behavior for the agent's own permissions;
- no attempts to bypass Android permission policy.

## Result protocol

Instrumentation output should be machine-readable and stable, for example:

```json
{
  "schema": 1,
  "suite": "hardware-smoke",
  "results": [
    {
      "id": "camera.rear.capture",
      "status": "PASS",
      "duration_ms": 412,
      "details": {"bytes": 18432}
    }
  ]
}
```

`sablectl` remains the authority for suite composition, baseline comparison, evidence storage and final report rendering.

## Build integration

Recommended repository path:

```text
tools/SableTestAgent/
```

Preferred implementation:

- normal Android application/test module;
- instrumentation runner;
- minSdk aligned to active SableOS Android baseline initially;
- debug/test signing only;
- no production product package inclusion;
- reproducible host-side build documented separately from the ROM build where practical.

## D4 acceptance mapping

Candidate agent-backed D4 checks:

```text
CAMERA_API=PASS
SENSORS_SAMPLE=PASS
LOCATION_API=PASS
AUDIO_RECORD_API=PASS
WEBVIEW_LOCAL_RENDER=PASS
NOTIFICATION_POST=PASS
CE_STORAGE_RW=PASS
DP_STORAGE_RW=PASS
LIFECYCLE_RECREATE=PASS
```

Manual checks remain required for user-perceived quality and external hardware/radio interactions such as voice call quality, remote SMS receipt, Bluetooth audio quality, physical NFC tag behavior and biometric usability.

## Delivery phases

```text
A0  project skeleton + instrumentation result protocol
A1  storage / lifecycle / WebView / notification tests
A2  sensors / location / camera / audio
A3  reboot persistence + sablectl orchestration
A4  D4 named agent suite + CI/hardware-lab integration
```
