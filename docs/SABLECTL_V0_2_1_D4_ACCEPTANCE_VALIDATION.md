# sablectl v0.2.1 Panther D4 acceptance validation

Date: 2026-09-08
Device: Pixel 7 (`panther`)
Build: SableOS D4 B2 on Android 17 / SDK 37
Active slot: B

## Result

The corrected `sablectl v0.2.1` D4 acceptance suite completed successfully on the live Panther device after the v0.2 USB false-negative was fixed.

```text
PASS=38
FAIL=0
SKIP=2
MANUAL=11
ERROR=0
OVERALL=PASS_WITH_MANUAL
ACCEPTANCE_RC=0
REPORT_DIR=.sablectl/runs/acceptance-d4/20260908T203559Z
```

A second immediate verbose replay reproduced the same result:

```text
PASS=38
FAIL=0
SKIP=2
MANUAL=11
ERROR=0
OVERALL=PASS_WITH_MANUAL
REPORT_DIR=.sablectl/runs/acceptance-d4/20260908T203624Z
```

## Automated gates closed

The live suite passed all currently-enforced host/ADB checks, including:

```text
boot.device=PASS panther
boot.completed=PASS
boot.slot=PASS _b
boot.crypto=PASS encrypted
artifact.buildmanifest=PASS exact packaged B2
artifact.art.count=PASS_5_OF_5
security.selinux=PASS Enforcing
service.servicemanager=PASS
service.surfaceflinger=PASS
service.zygote=PASS
service.package_manager=PASS packages=229
data.ce_available=PASS
data.third_party_packages=PASS expected=6 actual=6
data.users=PASS expected=1 actual=1
crash.since_boot=PASS 0 fatal markers
wifi.status_command=PASS
wifi.enabled=PASS
connectivity.dumpsys=PASS
connectivity.validated_network=PASS
telephony.registry=PASS
telephony.registered=PASS
telephony.data_connected=PASS
bluetooth.manager=PASS
bluetooth.enabled=PASS
power.battery_service=PASS
power.battery_level=PASS 100
webview.provider=PASS app.vanadium.webview 152.0.7977.84.0
role.home=PASS com.android.launcher3
role.browser=PASS app.vanadium.browser
role.dialer=PASS com.android.dialer
role.sms=PASS com.android.messaging
adb.transport=PASS device
usb.function_state=PASS sys.usb.config=adb persist.sys.usb.config=adb
```

## Expected SKIP results

```text
telephony.ims_observable=SKIP
```

`dumpsys ims` returned success with no payload, so IMS is not host-observable through that interface on this build/carrier state. This is not treated as a compatibility failure.

```text
power.sable_service=SKIP
```

`com.sableos.power.IPowerService/default` is not present on the current Panther D4 B2 stage. The check is intentionally optional until the Panther S1.7 semantic power service is ported.

## Outstanding manual D4 gates

The automated suite intentionally retained the following as `MANUAL`:

```text
manual.voice_out
manual.voice_in
manual.sms_out
manual.sms_in
manual.mms
manual.hotspot
manual.bluetooth_audio
manual.camera_quality
manual.location_fix
manual.biometrics
manual.nfc
```

These are not failures. D4 cannot be called fully closed until the required physical gates are recorded.

Minimum mandatory user-facing gates still outstanding from this list are:

```text
VOICE_OUT
VOICE_IN
SMS_OUT
SMS_IN
```

`CELLULAR_DATA` and `WIFI` now have automated host evidence passing in the v0.2.1 acceptance run.

## USB regression disposition

The initial v0.2 live run reported:

```text
usb.adb=FAIL expected=adb actual=''
```

while the same process was successfully using an authorized ADB device. That was a host-probe contradiction caused by treating an empty `sys.usb.state` as proof that ADB was unavailable.

v0.2.1 replaced that check with two independent observations:

```text
adb.transport
usb.function_state
```

The live corrected result is:

```text
adb.transport=PASS expected=device actual=device
usb.function_state=PASS actual='sys.usb.config=adb, persist.sys.usb.config=adb'
```

Therefore:

```text
V0_2_USB_FAILURE_CLASS=HOST_PROBE_FALSE_NEGATIVE
V0_2_USB_DEVICE_COMPATIBILITY_CONTRADICTION=NONE
V0_2_1_USB_REGRESSION=CLOSED
```

## Current D4 disposition

```text
D4_EXACT_PACKAGED_BOOT_IDENTITY=PASS
D4_ART_IDENTITY=PASS_5_OF_5
D4_SECURITY_AND_CORE_SMOKE=PASS
D4_PRESERVED_DATA_SELF_CONSISTENCY=PASS
D4_WIFI_AUTOMATED=PASS
D4_CELLULAR_REGISTRATION_AUTOMATED=PASS
D4_CELLULAR_DATA_OBSERVED=PASS
D4_BLUETOOTH_AUTOMATED=PASS
D4_ADB_USB_AUTOMATED=PASS
D4_WEBVIEW_AND_DEFAULT_ROLES=PASS
D4_AUTOMATED_HOST_ACCEPTANCE=PASS_WITH_MANUAL
D4_AUTOMATED_HOST_FAILURES=0
D4_FULL_PHYSICAL_ACCEPTANCE=OPEN
D4_R2=OPEN
```

The canonical next step is to execute and record the remaining physical gates, then use `--require-complete` to verify strict suite semantics while those manual gates remain outstanding.
