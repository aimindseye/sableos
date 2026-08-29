# S0.6 Validation — Vanilla Android 14 capability baseline

Status: **PASS**

Target: Pixel 4a (5G) / bramble

Baseline:
- Android release: 14
- Build ID: `UP1A.231105.001.B2`
- SELinux: Enforcing
- Bootloader: `b5-0.6-10489838`
- Baseband: `g7250-00264-230619-B-10346159`

## S0.6A — capability inventory

PASS evidence:
- Expected Wi-Fi, Bluetooth, telephony, camera, NFC, sensor, USB, and audio features declared.
- Platform services present for Wi-Fi, Bluetooth, telephony, camera, sensors, audio, power, and fingerprint.
- Network interfaces include WLAN and RMNET interfaces.
- Power-supply topology includes `battery`, `dc`, `pc_port`, and `usb` among the expected bramble supplies.
- SELinux reports `Enforcing`.

## S0.6B — UI/media physical checks

- Touch: PASS
- Wi-Fi: PASS
- Bluetooth scan: PASS
- Rear camera: PASS
- Front camera: PASS
- Speaker: PASS

Gate: `S0_6B_PHYSICAL_UI_MEDIA_GATE=PASS`

## S0.6C — telephony/biometric physical checks

- Microphone: PASS
- Cellular call: PASS
- SMS: PASS
- Mobile data: PASS
- Fingerprint enrollment: PASS
- Fingerprint unlock: PASS

Gate: `S0_6C_TELEPHONY_BIOMETRIC_GATE=PASS`

## S0.6D — charging/sensors/resume physical checks

- USB charging: PASS
- USB ADB reconnect: PASS
- Auto-rotate: PASS
- Proximity sensor: PASS
- Ambient light response: PASS
- Suspend/resume: PASS

Gate: `S0_6D_CHARGING_SENSOR_RESUME_GATE=PASS`

## Result

The vanilla Android 14 `UP1A.231105.001.B2` bramble baseline preserves the tested hardware capability set needed before SableOS reintegration.

Overall gate: `S0_6_VANILLA_CAPABILITY_BASELINE=PASS`

No device serial, IMEI, IMSI, ICCID, phone number, or other sensitive device identifier is recorded in this validation file.
