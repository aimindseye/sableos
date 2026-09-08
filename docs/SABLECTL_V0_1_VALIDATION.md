# sablectl v0.1 live validation

Date: 2026-09-08
Device: Pixel 7 (`panther`)
Build: SableOS D4 B2 / Android 17 / SDK 37
Status: **PASS / OPERATIONALLY CLOSED**

## Purpose

This record closes the first end-to-end live validation of the host-side `sablectl` tool on the physically flashed SableOS D4 B2 Panther device.

The baseline captured here is a **post-B2 baseline**. It is valid as the pre-deployment reference for subsequent SableOS builds, but it must not be used to retroactively prove preservation across the already-completed B2 flash.

## Host installation and self-test

```text
SABLECTL_SOURCE=PASS
PYTHON=3.12
PYTEST=PASS_6_OF_6
SABLECTL_DOCTOR=PASS
SABLECTL_DEVICE_WAIT=PASS
```

## Exact packaged post-boot identity

Command class: `sablectl verify boot`

```text
PASS=11
FAIL=0
SKIP=0
MANUAL=0
ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/verify-boot/20260908T181140Z
```

Proven live state:

```text
DEVICE=panther
BOOT_COMPLETED=1
ACTIVE_SLOT=_b
CRYPTO_STATE=encrypted
BUILDMANIFEST_EXACT_MATCH=PASS
ART_EXACT_MATCH=PASS_5_OF_5
ART_EXPECTED_COUNT=5
ART_ACTUAL_MATCH_COUNT=5
```

## Initial runtime smoke

Command class: `sablectl smoke`

```text
PASS=16
FAIL=0
SKIP=0
MANUAL=0
ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/smoke/20260908T181212Z
```

Additional checks:

```text
SELINUX=Enforcing
SERVICEMANAGER=running
SURFACEFLINGER=running
ZYGOTE=running
PACKAGE_MANAGER=PASS
INSTALLED_PACKAGE_COUNT=229
```

## Baseline capture

The first reusable post-B2 baseline was captured at:

```text
.sablectl/baselines/20260908T181640Z/baseline.json
```

This baseline becomes the canonical pre-next-deployment reference for future preserved-data comparisons.

Raw baseline material is local evidence and may contain device/settings information. Do not publish raw baseline contents by default; publish sanitized summaries and hashes when required.

## Preserved-data comparator self-consistency

Command class: `sablectl verify preserved-data`

This run compares the unchanged live B2 device against the newly captured post-B2 baseline. It validates the comparator itself; it does not retroactively prove preservation across the earlier B2 flash.

```text
PASS=3
FAIL=0
SKIP=0
MANUAL=0
ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/verify-preserved-data/20260908T181852Z
```

Checks:

```text
CE_USER_0_AVAILABLE=PASS actual=true
THIRD_PARTY_PACKAGE_SET=PASS expected=6 actual=6
ANDROID_USER_COUNT=PASS expected=1 actual=1
```

## Combined smoke + baseline closure

Command class: `sablectl smoke --baseline <baseline>`

```text
PASS=19
FAIL=0
SKIP=0
MANUAL=0
ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/smoke/20260908T181912Z
```

This combines:

- exact packaged BuildManifest identity;
- exact 5/5 ART identity;
- boot/device/slot/encryption state;
- SELinux enforcing;
- core Android service health;
- PackageManager health;
- credential-encrypted user-0 availability;
- exact third-party package-set comparison;
- Android user-count comparison.

## Final v0.1 disposition

```text
SABLECTL_V0_1_UNIT_TESTS=PASS_6_OF_6
SABLECTL_V0_1_LIVE_BOOT_VERIFY=PASS_11_OF_11
SABLECTL_V0_1_ART_IDENTITY=PASS_5_OF_5
SABLECTL_V0_1_INITIAL_SMOKE=PASS_16_OF_16
SABLECTL_V0_1_BASELINE_CAPTURE=PASS
SABLECTL_V0_1_PRESERVED_DATA_COMPARATOR=PASS_3_OF_3
SABLECTL_V0_1_COMBINED_SMOKE_WITH_BASELINE=PASS_19_OF_19
SABLECTL_V0_1_RESULT=PASS_OPERATIONALLY_CLOSED
```

## Next active work

`sablectl v0.2` expands D4 automated acceptance with crash/ANR/tombstone auditing, Wi-Fi/connectivity, cellular/IMS, Bluetooth, USB, charging/power, WebView/default roles, install/launch testing, reboot/persistence and a named D4 acceptance suite.

SableTestAgent remains the later test-only Android instrumentation component for checks that host-side ADB cannot prove reliably.
