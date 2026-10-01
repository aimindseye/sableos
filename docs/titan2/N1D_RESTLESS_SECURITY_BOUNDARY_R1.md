# Titan 2 N1D Restless/Treble security boundary

Status: **architecture corrected before source sync**

Date: 2026-10-01

## Decision

RestlessOS remains valuable for Titan 2, but the Android-16 Restless/Treble
product must not be inherited wholesale by the actual N1D SableOS image.

N1D now has two deliberately separate roles:

```text
C2 fresh diagnostic control
  pinned RestlessOS Android 16 / TrebleDroid
  product: treble_arm64_bvN
  purpose: reproduce a known Titan-capable Treble control
  Sable security claim: NO
  Sable release artifact: NO

C3 actual N1D
  pinned GrapheneOS/AOSP Android 16 GSI base
  + Sable-owned Titan Treble compatibility delta
  + Sable product delta
  direct device/phh/treble/base.mk inheritance: NO
  Restless patch admission: deny by default
```

This is an architecture change from the earlier N1D product-chain draft which
directly inherited the PHH/Treble base.

## Why direct PHH/Treble base inheritance is rejected

Review of the Android-16 `device/phh/treble/base.mk` used by the Restless
product shows that it intentionally carries universal-GSI compatibility and
debug/remediation behavior which is not an acceptable Sable release baseline.

The reviewed base includes or enables, among other things:

- `SELINUX_IGNORE_NEVERALLOWS := true`;
- `ro.adb.secure=0`;
- `persist.sys.usb.config=adb`;
- `resetprop_phh` and `phh-securize.sh`;
- PHH OTA scripts and `phh-ota`;
- remote debugging payloads including dbclient/remotectl;
- TrebleApp privileged configuration;
- QCOM-specific `QcRilAm`;
- extra legacy VNDK 28/29 support;
- broad unrelated OEM compatibility payloads and proprietary files.

Those choices are understandable for a universal compatibility GSI. They are
not automatically appropriate for a security/privacy-focused Titan 2 product
whose exact vendor/kernel basis is already known.

The Restless patch stack also contains compatibility patches which can weaken
normal platform assumptions, including AVB fallback/disable behavior,
world-writable `/dev/uinput`, permissive-domain allowances in user builds,
legacy encryption workarounds and no-BPF fallbacks. These are not admitted into
C3 merely because upstream Restless uses them.

## C2 role

The historical N1B result proved that the Treble/Restless hierarchy is useful as
a device compatibility control. Exact historical N1B image bytes are no longer
available, so C2 will be a fresh, sealed control rather than a claim that the old
image was reconstructed byte-for-byte.

C2 may reproduce the pinned Android-16 Restless/Treble composition for
diagnostic comparison. Any weaker compatibility/security posture it contains is
part of the control definition only.

C2 cannot become a Sable release artifact and cannot transfer security
acceptance to C3.

## C3 N1D product basis

The intended C3 product chain is:

```text
GrapheneOS 2026061600
  -> AOSP android-16.0.0_r4 / bp4a
  -> build/make/target/product/generic_system_arm64.mk
  -> build/make/target/product/gsi_release.mk
  -> vendor/sable/n1d/treble_compat.mk
  -> vendor/sable/n1d/sable_n1d_product_delta.mk
```

The AOSP GSI release layer provides the generic GSI mechanisms such as
`gsi_skip_mount.cfg`, current VNDK compatibility through vendor API 34 and a
system-only image boundary without inheriting PHH's universal product policy.

`vendor/sable/n1d/treble_compat.mk` is the sole owner for compatibility
material intentionally imported from TrebleDroid/RestlessOS into C3.

## Initial compatibility policy

C3 begins with a zero-item Restless patch allowlist.

```text
N1D_C3_RESTLESS_PATCH_POLICY=DENY_BY_DEFAULT_EVIDENCE_ADMIT
N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0
```

A Restless/Treble source change may be admitted only after one of these is true:

1. clean C3 build requires it and the dependency is understood;
2. C2 boots but C3 fails with evidence attributable to that compatibility path;
3. a Titan 2 runtime failure is reproduced and the patch is the narrow fix;
4. Option B IMS work explicitly requires a reviewed telephony bridge.

Patch families aimed at unrelated OEMs, old kernels, old encryption modes or
different vendor API levels remain excluded.

## Hard C3 security boundaries

```text
SELINUX_ENFORCING_REQUIRED=YES
NEVERALLOW_ENFORCEMENT_REQUIRED=YES
SELINUX_IGNORE_NEVERALLOWS_ALLOWED=NO
PERMISSIVE_DOMAINS_ALLOWED=NO

ADB_AUTH_REQUIRED=YES
RO_ADB_SECURE_ZERO_ALLOWED=NO
DEFAULT_USB_ADB_ALLOWED=NO

PHHSU_ALLOWED=NO
RESETPROP_PHH_ALLOWED=NO
PHH_SECURIZE_ALLOWED=NO
PHH_OTA_ALLOWED=NO
PHH_REMOTE_DEBUG_ALLOWED=NO
TREBLEAPP_ALLOWED=NO

LEGACY_VNDK_28_29_ALLOWED=NO
VENDOR_MAGISK_ALLOWED=NO
QCRILAM_ALLOWED=NO
PRIVATE_RESTLESS_VENDOR_ALLOWED=NO
```

These are C3 product constraints, not claims about the diagnostic C2 control.

## Titan-specific compatibility intake

Titan 2 uses a Linux 6.1 kernel and vendor/VNDK API 34. Therefore old-kernel
fallbacks, VNDK 28/29 restoration and generic legacy-device workarounds are not
baseline requirements.

MediaTek-specific changes are not automatically accepted merely because the
device is MediaTek. They require a reproduced failure or a later Option B IMS
review.

APN ownership remains explicit. A generic upstream APN replacement is not
silently inherited.

Keyboard/keylayout ownership remains the Titan device profile; generic Unihertz
key files are reference material, not final Sable policy.

## Phase interpretation

```text
C2 fails:
  investigate control/source/device assumptions before N1D

C2 passes, C3 fails:
  compare C2/C3 and admit the narrowest proven compatibility delta

C3 passes system-only, C4 fails full-super:
  LP/super/AVB representation remains the fault domain

C3 and C4 pass:
  proceed to Option B IMS/runtime work without importing unrelated PHH policy
```

## Authorization boundary

This document and its contracts authorize no source sync, Android build, device
contact or flash.

```text
SOURCE_SYNC=NO
BUILD=NO
DEVICE_CONTACT=NO
FLASH=NO
```
