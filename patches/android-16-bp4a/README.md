# Android 16 / BP4A Patch Queue

This directory records the patch classes needed while establishing the SableOS Android 16 / BP4A GSI build path.

The current focus is the Titan 2 N0-AOSP control build:

```text
TARGET=generic_system_arm64-bp4a-userdebug
GOAL=systemimage
AOSP_TAG=android-16.0.0_r4
BUILD_ID=BP4A.251205.006
```

## Current patch classes

### 1. `platform_testing` test-package graph unblocker

Classification:

```text
CLASS=temporary_scratch_unblocker
RUNTIME_SYSTEM_IMG_IMPACT=NO_EXPECTED
REVERT_FOR_ZERO_MUTATION_BASELINE=YES
```

Reason:

Soong globally parses and validates Blueprint graph state before building `systemimage`. Some `platform_testing` `test_package` bundles refer to host-side artifacts under the output directory in a way that fails path validation even though those Tradefed test bundles are not runtime `system.img` content.

Observed failing host artifact classes included:

```text
perfetto_trace_processor_shell
net-tests-utils-host-common.jar
```

Current handling:

```text
Disable only the specific failing platform_testing test_package blocks in scratch workspace evidence.
Do not set SOONG_ALLOW_MISSING_DEPENDENCIES=true.
Do not classify this as a runtime SableOS product change.
```

### 2. `com.android.ranging` existence-check allowlist

Classification:

```text
CLASS=reusable_android16_bp4a_control_patch_candidate
RUNTIME_SYSTEM_IMG_IMPACT=NO_EXPECTED
BASE_SYSTEM_PRESERVED=YES
RELEASE_RANGING_STACK_PRESERVED=YES
```

Reason:

For the BP4A control build, local verification showed:

```text
RELEASE_RANGING_STACK=true
com.android.uwb:framework-ranging present in classpath dump
com.android.uwb:service-ranging present in classpath dump
no local Android.bp module declaration named com.android.ranging
base_system.mk still contributes com.android.ranging when RELEASE_RANGING_STACK is set
```

The selected narrow patch is to allowlist the absent package at the generic-system existence-check call:

```make
$(call enforce-product-packages-exist,com.android.ranging)
```

instead of deleting `com.android.ranging` from `base_system.mk` or disabling `RELEASE_RANGING_STACK`.

## Explicit non-goals

Do not use these as N0-AOSP fixes:

```text
SOONG_ALLOW_MISSING_DEPENDENCIES=true
Adding packages/modules/Ranging from main into a tagged BP4A tree
Deleting com.android.ranging from build/make/target/product/base_system.mk
Disabling RELEASE_RANGING_STACK
Sharing OUT_DIR across AOSP, Treble, and Sable product graphs
```

## Promotion rule

A scratch patch can be promoted only after it has:

```text
clear scope
clear runtime impact assessment
reproducible evidence path
idempotent application path
rollback instructions
stage ownership
```

## Stage ownership

| Stage | Allowed patch sources |
| --- | --- |
| `N0-AOSP` | AOSP/BP4A control patches only |
| `N1-TREBLE` | RestlessOS / TrebleDroid patch series only |
| `N2-SABLE` | SableOS product overlay and package deltas only |
| `N3-TITAN2` | validation notes and device-specific runtime findings |
