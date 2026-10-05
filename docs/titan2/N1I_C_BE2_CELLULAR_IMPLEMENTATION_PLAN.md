# Titan 2 N1I-C — Build Engineer 2 cellular implementation plan

Status: **C1 BUILD QUALIFICATION IN PROGRESS — ANDROID 16 ISOLATION; PR #321 DRAFT**

Date: 2026-10-04

## Authority

```text
N1I_C0_PREMERGE_BASE=47f60001438ed2fdba6937982fbdb4cda281d665
N1I_C1_BASE_MAIN=177ef4fb76d661725165c5224f6a8495b2b420ec
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

Titan 2 N1I is pinned to **Android 16**:

```text
AOSP_REVISION=android-16.0.0_r4
GRAPHENEOS_TAG=2026061600
RESTLESS_TAG=16.0.0-202606230923
RELEASE_CONFIG=bp4a
ANDROID_17_ALLOWED=NO
```

Android 17 source, framework assumptions, release configuration, or policy are
out of scope for Titan 2 N1I.

## N1I-C1 cellular-isolation rule

The next build is intentionally bounded to:

```text
exact C3A boot-qualified compatibility substrate
+ five already boot-qualified Sable Titan modules
+ no initial registration/data change; preserve the physically proven C3A/N1F behavior
+ OEM MediaTek IMS APK + two admitted framework JARs + config/policy as the only new functional delta
+ zero initial stock native SO imports; native escalation only from observed runtime evidence
```

Do not admit unrelated product work into N1I-C1. Launcher3/Sable Start,
canonical IME provisioning, SetupWizard2 integration, Weather city work,
Reader v2, Hub/Attention, SystemUI convergence, Sable Tools and Battery remain
for the later N1I-D product-convergence build after cellular acceptance.

Registration/data and IMS/voice remain independently attributable. The first
C1 candidate deliberately adds no new registration/data patch because C3A/N1F
already demonstrated registration and data; any later correction requires new
runtime evidence.

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
`build/titan2/n1i-c-oem-ims-admission.env`. N1I-A A4 remains a broad native
audit superset, but N1I-B2 explicitly replaces the keyword heuristic for native
dependency admission and records native gaps as candidate/coverage evidence
only, not import authority.

Therefore the initial C1 candidate imports **zero stock native `.so` files**.
It stages only the OEM IMS APK, the two explicitly admitted framework JARs and
the exact required configuration/policy surface. If physical runtime later
proves an `UnsatisfiedLinkError` or equivalent missing native dependency, that
specific library and its DT_NEEDED closure require a separate evidence-backed
admission. This prevents Android-source-owned libraries from being shadowed by
stock prebuilts and preserves the one-delta experiment.

## First C1 Android-16 build result

Source commit `194b633bc2d4e09498ae6020c8fc848625729b37` completed the
Android `systemimage` build successfully and produced a valid raw GSI of
3210674176 bytes. The run then stopped in the post-build IMS-package check.

Read-only inspection proved that the installed
`/system_ext/priv-app/ImsService/ImsService.apk` is still
`com.mediatek.ims`, retains shared UID `android.uid.phone`, and is signed by
the same platform certificate as `framework-res.apk`. Therefore the
`ims_package` stop is classified as a verifier false negative, not an Android
composition failure.

Root cause: under `set -o pipefail`, the old verifier used
`aapt2 ... | grep -q ...`. A successful early `grep -q` match can close the
pipe while `aapt2` is still producing output, causing SIGPIPE and a nonzero
pipeline result. Regression T2-013 now requires complete-output capture before
matching and adds a staged-APK identity check before the long Android build.

That verifier-only conclusion was subsequently superseded by the read-only
post-build qualifier: 194b633 has a real configured boot-jar location mismatch.
The image is retained as failure evidence and must not be flashed.

## Build-regression framework and current in-flight build

PR #321 now contains a shared build-regression ledger and executable preflight:

```text
REGRESSION_LEDGER=build/BUILD_REGRESSIONS.tsv
REGRESSION_GATE=build/gates/build-regression-contract.py
CANONICAL_CI_HOOK=build/local-ci/run.sh
CANONICAL_TITAN_BUILD_HOOK=build/devices/titan2.sh
```

This framework captures repeatable failures already seen in the engineering
lane, including CI false-success propagation, unrelated-ref Gitleaks scans,
Android-version drift, delegated output-directory ownership, staging cleanup,
SELinux property multiplicity, system_ext path mapping and over-admission of
the N1I-A A4 native superset.

A C1 build that was already running when the framework was added is not
interrupted. It remains valid evidence for its exact starting source commit.
The regression framework becomes mandatory for the next build and later builds
after canonical CI qualifies the newer source head.

## Bootclasspath location correction after 194b633 qualification

The preserved 194b633 image passed systemimage/GSI/five-app/IMS identity and
platform-signature checks, but failed bootclasspath qualification. Android 16
derives configured boot-jar device paths from the configured module name, not
the `dex_import` `stem`. The C1 modules intentionally use collision-safe
Sable names while installing stock-compatible filenames, so explicit configured
jar location overrides are required:

```text
system_ext:SableN1IC1MediatekCommon
  -> system_ext:mediatek-common

system_ext:SableN1IC1MediatekImsBase
  -> system_ext:mediatek-ims-base
```

C1 now uses `PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES` for both mappings and
checks the final product variable before compilation. The 194b633 image is
retained as composition-failure evidence and is **not** a physical candidate.
A corrected Android 16 systemimage rebuild is required.

## Current next operator step: corrected C1 rebuild

The 194b633 post-build qualifier identified a real bootclasspath location
mismatch after the IMS verifier false negative was cleared. Preserve that image
as evidence and do not flash it.

The next operator step is canonical full CI on the corrected C1 source, then a
fresh source-commit-scoped N1I build. The historical qualifier invocation is
retained below for provenance only:

```bash
bash build/titan2/qualify-n1i-c1-postbuild.sh \
  --source-commit 194b633bc2d4e09498ae6020c8fc848625729b37 \
  --out-dir /srv/sable-build/workspaces/titan2-n1d/out-n1i-c1-194b633bc2d4
```

The qualifier performs no compilation, device contact or flash. It verifies the
system image, five N1F apps, OEM IMS package/shared UID/platform signature,
bootclasspath JARs, config/sysconfig, SELinux outputs, zero stock-native
prebuilts and Android-source restoration. On success it seals the existing
system image into the Titan artifact store and emits
`N1I_C1_POSTBUILD_QUALIFICATION=PASS` and
`N1I_C1_READY_FOR_PHYSICAL_REVIEW=YES`.

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
N1I_C1_SOURCE_IMPLEMENTATION=PR321_DRAFT
N1I_C1_ANDROID_WORKSPACE_STAGING=IN_PROGRESS_OR_COMPLETE_PER_PINNED_BUILD_HEAD
N1I_C1_BUILD=IN_PROGRESS_OPERATOR_RUN_NOT_TO_BE_INTERRUPTED
N1I_C1_REGRESSION_FRAMEWORK=NEXT_BUILD_MANDATORY
DEVICE_CONTACT=NO
FLASH=NO
CELLULAR_DEVICE_MUTATION=NO
PRODUCTION_SIGNING=NO
```
