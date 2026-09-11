# Sable Start R3 live-data and interaction status — 2026-09-11

## Current state

The physical Sable Metro preview passed runtime causality and several internal
navigation semantics. R2 identified four genuine action failures:

```text
Start -> Settings                 FAIL
Search -> Settings                FAIL
Files -> Open                     FAIL
Files -> App info                 FAIL
```

Focused source review proved the failures were implementation gaps: the affected
controls used empty click handlers. The same review showed that the Live screen
still contained hard-coded date/weather/card text.

## R3 source delta

The applied R3-R1 delta:

- wires Start and Search Settings affordances to the Settings preview;
- opens the installed launcher entry labelled `Files`;
- opens Android application-details Settings for the resolved Files package;
- replaces the hard-coded Live date/time with the system clock;
- provides permission-gated Photos and Music counts through `MediaStore`;
- provides permission-gated Calendar event count for the current day;
- reports Weather and Tasks as explicitly unavailable until providers are selected;
- performs provider work on `Dispatchers.IO`;
- uses an explicit loading state for initial rendering;
- refreshes periodically and after permission-result delivery.

Source application was baseline-bound and passed:

```text
BASELINE_ACTIVITY=PASS
BASELINE_MANIFEST=PASS
SABLE_METRO_R3_SOURCE_DELTA_APPLIED=PASS
```

Applied hashes:

```text
SableMetroPreviewActivity.kt
12db1f5a6fc6584dd462395d5f30f44d8980c4edd92b901bb52f9cb921eca1a2

LiveSurfaceRepository.kt
e367bc36cb82541d77fe84ec289605aaf86531c446d6f17294e247793029040b

LiveSurfaceModels.kt
81c8d6854f50e0ae69809f394bb8eee08573a7627c35335f5d01094fc8a15978

AndroidManifest.xml
05adaebf862dd6c81cfe8326bf92ef152556bab3b4a78f8da34fb1000dc6bd25
```

## Pre-build qualification

R3-R1 static gate:

```text
MANIFEST_XML=PASS
CONFLICT_MARKERS=PASS
REQUIRED_ACTION_BINDINGS=PASS
LIVE_DATA_BINDINGS=PASS
PROVIDER_QUERIES_OFF_MAIN=PASS
NO_NETWORK_CLIENT=PASS
UI_PROVIDER_SEPARATION=PASS
```

Pure host Kotlin tests:

```text
UNIT_COMPILE=PASS
UNIT_TEST_COUNT=5
UNIT_TEST_FAILURES=0
UNIT_TESTS=PASS
```

The earlier contract suite also passed seven tests covering freshness and action
route contracts.

## Device capability probe

Read-only Panther probe:

```text
DEVICE_REACHABLE=PASS
OPEN_DOCUMENT_CAPABILITY=UNRESOLVED
APP_INFO_CAPABILITY=PASS
FILE_CAPABLE_PACKAGE_CANDIDATE_COUNT=2
MEDIA_PROVIDER=PRESENT
CALENDAR_PROVIDER=PRESENT
DEVICE_CAPABILITY_PROBE=PASS
```

`OPEN_DOCUMENT` being unresolved is not treated as proof that Files is absent; the
R3 implementation primarily launches the actual launcher entry labelled `Files`.

## Current build gate

Canonical environment confirmed:

```text
GrapheneOS tag: 2026081300
Android: 17
device: panther / Pixel 7
lunch: panther-cur-user
TARGET_PRODUCT=panther
TARGET_RELEASE=cur
TARGET_BUILD_VARIANT=user
BUILD_ID=CP2A.260705.006
security patch=2026-08-05
```

R3B module-scoped Soong compile/type-check is the active gate.

Not yet proven by this status record:

- successful R3B Android/Soong compilation;
- APK installation;
- live permission/provider correctness on device;
- four repaired interaction paths on the rebuilt APK;
- HOME replacement qualification;
- SystemUI/lock-screen integration;
- production readiness.
