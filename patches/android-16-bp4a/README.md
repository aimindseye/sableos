# Android 16 / BP4A Patch Queue

This directory records the patch classes needed while establishing the SableOS Android 16 / BP4A GSI build path.

The current focus is the Titan 2 N0-AOSP control build:

```text
TARGET=generic_system_arm64-bp4a-userdebug
GOAL=systemimage
AOSP_TAG=android-16.0.0_r4
BUILD_ID=BP4A.251205.006
```

## Canonical stage ownership

```text
N0-AOSP      = AOSP BP4A generic_system_arm64 control build
N0-B-TREBLE  = RestlessOS / TrebleDroid hardware-capable GSI baseline
N1-SABLE     = SableOS product overlay on the Treble baseline
N2-TITAN2    = physical Titan 2 / Titan 2 Elite validation
```

Do not use `N1-TREBLE` for the RestlessOS / TrebleDroid baseline. That stage is `N0-B-TREBLE`.

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

### 3. ABI check rerun setting

Classification:

```text
CLASS=build_control_environment_workaround
SOURCE_MUTATION=NO
RUNTIME_SYSTEM_IMG_IMPACT=NO_EXPECTED
```

Reason:

The N0-AOSP build produced `system.img` artifacts but returned nonzero after a late `header-abi-dumper` failure while processing `frameworks/base/native/android/libandroid`. The supported Soong knob is:

```text
SKIP_ABI_CHECKS=true
```

This setting is scoped to the N0-AOSP control build and should be recorded in evidence. It is not a Titan 2 runtime change and not a SableOS product feature.

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
| `N0-B-TREBLE` | RestlessOS / TrebleDroid patch series only |
| `N1-SABLE` | SableOS product overlay and package deltas only |
| `N2-TITAN2` | validation notes and device-specific runtime findings |
