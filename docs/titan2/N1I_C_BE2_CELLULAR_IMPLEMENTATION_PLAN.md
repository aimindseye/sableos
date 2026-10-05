# Titan 2 N1I-C — Build Engineer 2 cellular implementation plan

Status: **IMPLEMENTATION READY — OEM IMS ADMISSION CLOSED; CELLULAR ISOLATION NEXT**

Date: 2026-10-04

## Authority

```text
SABLE_MAIN=47f60001438ed2fdba6937982fbdb4cda281d665
N1I_A_RESTACK_SOURCE=c667383b1466b851bfb8e8b5dfe02351f907fa51
C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
OEM_IMS_PACKAGE=com.mediatek.ims
OEM_IMS_APK_SHA256=30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539
OEM_MTKIMS_PORT_FEASIBILITY=MODERATE_TITAN_SPECIFIC_LAYER
AUDIT_EVIDENCE=/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z
```

The machine-readable implementation boundary is
`build/titan2/n1i-c-oem-ims-admission.env`.

## Android platform boundary

Titan 2 N1I remains on **Android 16**. The cellular-isolation implementation
must use the pinned GrapheneOS/AOSP 16 substrate:

```text
AOSP_REVISION=android-16.0.0_r4
GRAPHENEOS_TAG=2026061600
RELEASE_CONFIG=bp4a
ANDROID_17_ALLOWED=NO
```

Android 17 source, framework assumptions, or compatibility policy are out of
scope for Titan 2 N1I.

## N1I-C1 cellular-isolation rule

The next build is intentionally bounded to:

```text
exact C3A boot-qualified compatibility substrate
+ five already boot-qualified Sable Titan modules
+ smallest evidence-backed registration/data correction
+ dependency-closed OEM MediaTek IMS compatibility layer
```

Do not admit unrelated product work into N1I-C1. Launcher3/Sable Start,
canonical IME provisioning, SetupWizard2 integration, Weather city work,
Reader v2, Hub/Attention, SystemUI convergence, Sable Tools and Battery remain
for the later N1I-D product-convergence build after cellular acceptance.

Registration/data recovery and IMS/voice remain independently identifiable
source deltas and serial physical experiments.

## Build Engineer 2 disposition

All still-valid BE2 work is carried forward:

- TrebleDroid/phh remains the hardware-capability substrate.
- Sable product policy stays out of AOSP base-product files.
- Global SOONG_ALLOW_MISSING_DEPENDENCIES is forbidden.
- The generic TrebleDroid IMS trial is complete and must not be repeated.
- OEM MediaTek IMS is the next voice-path implementation candidate.
- Vendor/kernel/firmware compatibility is preserved.
- Property writes are not accepted as proof of modem capability switching.
- Both physical SIM trays and DSDS are mandatory acceptance targets.
- Registration, data, SMS/MMS, IMS and voice evidence remain separate.
- Permissive SELinux and broad compatibility bypasses are forbidden.
- Production signing remains separate from engineering bring-up.
- Titan 2 Elite remains a separate portability target pending its own evidence.

## OEM IMS closure

The corrected V01.00.14 audit passed:

```text
N1I_A_OEM_IMS_PACKAGE=PASS
N1I_A_OEM_IMS_SIGNATURE=PASS
N1I_A_FRAMEWORK_DEPENDENCY_CLOSURE=PASS
N1I_A_NATIVE_DEPENDENCY_CLOSURE=PASS
N1I_A_PERMISSIONS_SYSCONFIG=PASS
N1I_A_SELINUX_INVENTORY=PASS
N1I_A_V010014_STOCK_SOURCE=PASS
N1I_A_NO_BLOB_IMPORT=PASS
N1I_A_NO_DEVICE_CONTACT=PASS
N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS
```

Static provider boundary:

```text
/system_ext/priv-app/ImsService/ImsService.apk
/system_ext/framework/mediatek-common.jar
/system_ext/framework/mediatek-ims-base.jar
```

The provider uses `android.uid.phone`. The stock platform certificate is not
reused; the engineering integration must use the Sable platform identity
consistently for this privileged/shared-UID compatibility layer.

The exact framework/native/config/SELinux audit artifacts are hash-pinned in
`build/titan2/n1i-c-oem-ims-admission.env`. Required stock payloads may be
staged from the locally retained V01.00.14 reference into the isolated Android
workspace, but stock binaries must not be committed to Git.

## Physical acceptance after N1I-C1 build qualification

1. tray 1: LTE/NR_NSA, stable data, SMS/MMS, IMS, outgoing/incoming voice;
2. tray 2: same plus normal phone-1/default-data routing and real capability
   transaction, with no property hold;
3. two physical SIMs: both subscriptions register and correct call/SMS routing;
4. default voice/SMS/data selections and data-SIM switching work;
5. reboot and repeat stability/IMS/voice checks.

No cellular completion claim exists until tray 1, tray 2 and DSDS pass.

## Current authorization

```text
N1I_C0_EVIDENCE_CLOSURE=PASS
N1I_C1_SOURCE_IMPLEMENTATION=NEXT
N1I_C1_ANDROID_WORKSPACE_STAGING=NEXT
N1I_C1_BUILD=NEXT
DEVICE_CONTACT=NO
FLASH=NO
CELLULAR_DEVICE_MUTATION=NO
PRODUCTION_SIGNING=NO
```
