# sablectl v0.2 live Panther D4 acceptance validation

Date: 2026-09-08
Device: Pixel 7 (`panther`)
Build: SableOS D4 B2 / Android 17
Branch: `sablectl-v0.1-clean`

## First live v0.2 run

The first physical `sablectl acceptance d4` run used the exact packaged B2 target-files and the post-B2 baseline captured at `20260908T181640Z`.

Observed aggregate:

```text
PASS=36
FAIL=1
SKIP=2
MANUAL=11
ERROR=0
OVERALL=FAIL
```

The single failure was:

```text
usb.adb expected=adb actual=''
```

All other automated checks were healthy, including exact BuildManifest identity, exact five ART files, SELinux, core services, preserved-data self-consistency, zero current-boot crash markers, Wi-Fi, validated connectivity, cellular registration/data, Bluetooth, battery, WebView and default role holders.

The two skips were expected evidence boundaries:

```text
telephony.ims_observable=SKIP  # dumpsys ims returned rc=0 with empty payload
power.sable_service=SKIP       # Panther semantic Sable power service not yet ported
```

The eleven manual results are intentional physical gates, including voice, SMS, MMS, hotspot, Bluetooth audio, camera quality, location, biometrics and NFC.

## USB failure classification

The `usb.adb` failure is a host-probe defect, not a demonstrated device or ADB failure. The same acceptance process was actively executing successful ADB commands against the authorized device while `sys.usb.state` was empty. Therefore an empty Android USB-function property cannot safely be treated as proof that the ADB transport is unhealthy.

Classification:

```text
V0_2_USB_FAILURE_CLASS=USB_PROPERTY_OBSERVABILITY_FALSE_NEGATIVE
DEVICE_COMPATIBILITY_CONTRADICTION=NONE
ADB_TRANSPORT_CONTRADICTION=NONE
V0_2_FIRST_RUN=BOUNDED_FAIL_HOST_PROBE
```

## v0.2.1 correction

v0.2.1 separates two different claims:

```text
adb.transport
  -> `adb get-state` must return `device`
  -> FAIL only when the authorized ADB transport itself is unhealthy

usb.function_state
  -> inspect sys.usb.state, sys.usb.config and persist.sys.usb.config
  -> PASS when exposed properties include adb
  -> SKIP when properties are empty/unavailable or do not establish the active transport
```

The legacy `usb.adb` result is filtered out of the D4 suite and superseded by those two checks.

Regression coverage requires:

- healthy ADB + empty USB properties => `adb.transport=PASS`, `usb.function_state=SKIP`, no FAIL;
- healthy ADB + exposed `mtp,adb` => both checks PASS;
- unhealthy ADB transport => `adb.transport=FAIL`;
- D4 wrapper removes the legacy false-fail result.

Local v0.2.1 validation before branch update:

```text
compileall=PASS
pytest=PASS_15_OF_15
adb_reboot_exec=ABSENT
pm_install_exec=ABSENT
pm_uninstall_exec=ABSENT
fastboot_exec=ABSENT
wipe_flag_exec=ABSENT
shell_true=ABSENT
```

A live v0.2.1 rerun is required before promoting the automated D4 result from bounded host-probe failure to `PASS_WITH_MANUAL`.
