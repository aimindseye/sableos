# SableOS keyboard-device camera enhancement roadmap

Status: **active architecture / research plan; no device camera enhancement is
accepted until physical evidence exists.**

Targets:

```text
Unihertz Titan 2
Unihertz Titan 2 Elite
Zinwa Q27
```

The objective is not to copy Google Camera. The objective is to achieve a
high-quality, privacy-respecting Sable camera experience by combining the
device's vendor camera HAL/ISP with an open-source camera application and
measured device-specific capability/tuning.

## Product decision

Use **GrapheneOS Camera** as the preferred application/source baseline.

Reasons:

- already aligned with the GrapheneOS-derived SableOS substrate;
- modern CameraX architecture;
- privacy/security-oriented product model;
- MIT-licensed standalone source;
- QR/barcode support already exists;
- materially lower legal/supply-chain risk than redistributing proprietary GCam
  ports.

Community GCam/LMC/SGCam ports are **reference behavior only**. Do not import,
redistribute or depend on opaque Google Camera-derived APKs as Sable product
source.

Open Camera may be used as a secondary open-source reference for Camera2 manual
controls, HDR/exposure bracketing, RAW, slow motion, focus bracketing and
device-capability probing.

## Device matrix

### Titan 2

Known public hardware:

```text
SoC        Dimensity 7300
display    1440x1440 main LCD + rear display
rear       50MP main + 8MP telephoto
front      32MP
stock OS   Android 15, Android 16 update available
```

Community feedback indicates GCam-family ports can improve still-image behavior,
but square-screen UI and auxiliary-camera handling need device-specific care.

### Titan 2 Elite

Known public hardware:

```text
SoC        Dimensity 7400
display    1080x1200 4.03-inch AMOLED
rear       50MP main + 50MP telephoto
front      32MP
stock OS   Android 16
```

A community LMC/GCam adaptation reports fixes for:

- missing/overlapping controls on the near-square viewport;
- tap-to-focus coordinate offset;
- low-resolution stretched preview;
- video smearing caused by unsuitable stabilization;
- overly red skin-tone/color transform;
- native 1:1 composition;
- local QR/barcode scanning.

That report also says the Elite telephoto is exposed as a
`SYSTEM_CAMERA`. Android's camera framework supports this capability for
system/privileged apps holding both `CAMERA` and
`android.permission.SYSTEM_CAMERA`.

SableOS therefore has an architectural opportunity that ordinary third-party
GCam ports do not: a narrowly privileged **Sable Camera** integrated into the
system image may be able to access the real telephoto camera. This must be
proved with Camera2 metadata and physical capture evidence before the privilege
is granted permanently.

### Zinwa Q27

Current manufacturer/preorder information:

```text
SoC        Dimensity 7300
display    1080x1240 ~4-inch AMOLED
rear       50MP single camera
front      16MP
stock OS   Android 16
```

Q27 has not yet completed Sable hardware acceptance. Camera implementation must
be capability-driven and must not assume Titan camera IDs, sensor tuning or
privileged-camera behavior.

## Architecture

```text
Sable Camera UI
    -> GrapheneOS Camera / CameraX baseline
    -> Sable camera capability adapter
    -> CameraX extensions where exposed
    -> Camera2 for exact capability/system-camera/manual paths
    -> stock vendor camera HAL
    -> stock ISP / sensor drivers
```

The GSI phase intentionally retains stock kernel/vendor/ODM/camera HAL. Camera
quality work first uses those mature vendor components instead of attempting to
replace MediaTek sensor/ISP drivers.

## C0 — read-only camera capability probe

Before tuning UI or image processing, record for every camera ID:

```text
public vs SYSTEM_CAMERA
logical vs physical camera IDs
lens facing
sensor active/pixel array
hardware support level
stream configurations + maximum-resolution modes
RAW capability
manual sensor/post-processing capability
logical multi-camera membership
focus-distance calibration
AF/AE/AWB modes
flash
OIS modes
video stabilization modes
dynamic-range profiles
color-space profiles
CameraX extensions
supported FPS/video sizes
vendor tags
```

Run the probe as both an ordinary app and, only on a controlled development
build, as the candidate system camera. The delta is part of the privilege
decision.

## C1 — geometry and interaction

Required on Titan 2 / Elite / Q27:

- square/near-square safe control layout;
- no overlapping top/bottom chrome;
- tap-to-focus coordinates mapped against the actual preview transform;
- high-resolution preview selected without compromising capture reliability;
- 1:1, 4:3 and device-supported video framing shown truthfully;
- keyboard shutter/focus/zoom controls where useful;
- touch remains fully supported;
- no forced soft keyboard;
- orientation and inset handling validated at actual density.

## C2 — image-quality baseline

Use a repeatable scene set and compare stock camera vs Sable Camera:

```text
daylight detail
mixed indoor light
skin tones
high dynamic range / backlight
low light
moving subject
close focus
telephoto / crop
front camera
QR / document
```

Measure/record:

- focus accuracy and focus latency;
- exposure consistency;
- white balance / color bias;
- highlight retention and shadow noise;
- sharpening/halo artifacts;
- motion blur;
- capture latency;
- preview/capture framing mismatch;
- JPEG/HEIC resolution and metadata;
- crash/ANR rate.

## C3 — GCam-inspired outcomes, open implementation

Candidate enhancements, only where the HAL/capability supports them:

- multi-frame HDR/exposure fusion;
- low-light multi-frame denoise;
- super-resolution crop for devices without an accessible telephoto path;
- tuned tone mapping and color transforms;
- motion-aware frame selection;
- EIS/gyro-assisted stabilization where it improves rather than warps video;
- RAW/DNG and manual controls for advanced users;
- local QR/barcode scanning;
- optional local face/scene assistance only with explicit privacy review.

Do not claim "HDR+" or other Google-proprietary implementations unless the
actual implementation and licensing justify that name.

## Privilege rule for SYSTEM_CAMERA

`android.permission.SYSTEM_CAMERA` is high-value authority and is not granted
merely to match a stock camera feature.

Before granting:

1. prove the target camera is actually hidden behind SYSTEM_CAMERA;
2. prove product value (for example the Elite physical telephoto);
3. keep the app's ordinary `CAMERA` runtime permission user-revocable;
4. use the narrowest system/privapp integration allowed by Android;
5. add a device/product allowlist rather than making the authority universal;
6. run CTS/system-camera discovery and negative third-party-access tests;
7. document rollback if the vendor implementation is unstable.

## Acceptance markers

```text
SABLE_CAMERA_OPEN_SOURCE_BASELINE=PASS
CAMERA_CAPABILITY_PROBE_<DEVICE>=PASS
CAMERA_SQUARE_LAYOUT_<DEVICE>=PASS
CAMERA_TAP_TO_FOCUS_<DEVICE>=PASS
CAMERA_PREVIEW_FIDELITY_<DEVICE>=PASS
CAMERA_COLOR_BASELINE_<DEVICE>=PASS
CAMERA_VIDEO_STABILIZATION_<DEVICE>=PASS_OR_EXPLICITLY_DISABLED
CAMERA_TELEPHOTO_<DEVICE>=PASS_OR_UNAVAILABLE_WITH_REASON
CAMERA_PRIVILEGE_NEGATIVE_TEST=PASS
CAMERA_STOCK_COMPARISON_<DEVICE>=PASS
```

Panther remains the full-stack security reference; keyboard-device camera
enhancement must not weaken the common Android camera permission model.

## External references

- Android GSI requirements:
  https://source.android.com/docs/core/tests/vts/gsi
- Android system cameras:
  https://source.android.com/docs/core/camera/system-cameras
- GrapheneOS Camera:
  https://github.com/GrapheneOS/Camera
- Open Camera:
  https://opencamera.org.uk/
- Titan 2 Elite community GCam/LMC adaptation reviewed 2026-09-20:
  https://www.reddit.com/r/unihertz/comments/1vzxax6/gcam_port_for_the_unihertz_titan_2_elite_square/
- Unihertz Titan 2:
  https://www.unihertz.com/products/titan-2
- Unihertz Titan 2 Elite:
  https://www.unihertz.com/products/titan-2-elite
- Zinwa Q27:
  https://zinwa.com/product/zinwa-q27-physical-keyboard-smartphone-12gb-ram-5g-android-16-early-birds/
