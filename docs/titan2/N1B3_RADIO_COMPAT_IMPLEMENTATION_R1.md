# N1B3 Radio Compatibility Implementation R1

## Status

N1B3 is the first implementation-prep checkpoint after PR209. PR209 superseded PR208 and preserved the clean evidence path for Titan 2 radio compatibility work.

PR210 initially added standalone source-audit tooling. That direction is retired. SableOS already has repository-owned build, host-tool, device, release and local-CI orchestration under `build/`. Titan 2 radio work must use those existing entry points and gates instead of ad hoc source-discovery or audit scripts.

## Contract markers

```text
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BASE_MAIN=e5267b928a53c8fc4861c5f8118b58e6a10d68b3
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BUILDS_ON_PR209=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_SUPERSEDES_PR208=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_STOCK_APK_IMPORT=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_MTK_JAR_SO_PAYLOAD=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_VENDOR_COPY=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_FLASH=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_STANDALONE_AUDIT_SCRIPTS=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_USE_CANONICAL_BUILD_PROCESS=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_USE_LOCAL_CI=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_MTK_INDICATION=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_IMS_BINDING=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_WWAN_DROP=YES
```

## Evidence basis

PR209 local evidence showed:

- LTE / WWAN service can come up on the N1B1 baseline.
- WWAN data can connect through `ccmni1`.
- The observed failure is a later WWAN disconnect with `ERROR_UNSPECIFIED`.
- MTK indication callbacks and IMS binding remain the high-signal suspects.
- Stock telephony APK payload import remains blocked and is not part of this path.

## Required process

Use the existing SableOS build and CI entry points in `build/`.

Canonical local CI for Titan 2 N1B:

```bash
SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

Do not add or run milestone-specific standalone source-discovery/audit scripts for Android source roots, host tools, SDK, NDK, Java, Gradle, Rust, repo workspace discovery, or build graph inspection. The repository build layer owns those responsibilities.

For implementation work, use targeted source changes and existing repository gates. If a new gate is needed, it must be integrated into the canonical build/local-CI flow rather than introduced as a separate exploratory audit script.

## Explicit non-goals

- No standalone Android source audit scripts
- No milestone-specific source-root discovery scripts
- No milestone-specific host-tool discovery scripts
- No `MtkTeleService.apk`
- No `MtkTelephonyProvider.apk`
- No `MtkMmsService.apk`
- No `MtkTelecom.apk`
- No stock `ImsService.apk`
- No MTK framework jar payload import
- No native MTK `.so` payload import
- No vendor partition copy
- No full vendor copy
- No flash script mutation

## Next implementation direction

N1B4 should be an implementation branch based on existing SableOS build/process knowledge. It should not start with another audit or discovery script. The expected path is:

1. Select the targeted radio/IMS compatibility change.
2. Add the smallest source/build integration patch required.
3. Validate through existing local CI and release gates.
4. Use device contact only through an explicitly authorized runtime validation step.
