# SableOS Build, Release, and Runtime Validation

## Gate Sequence

```text
1. baseline hashes / guards
2. controlled source mutation
3. source contract audit
4. targeted tests
5. affected build
6. generated-artifact audit
7. compiled SELinux audit
8. full product build
9. exact image-content proof
10. AVB validation
11. expected image-delta classification
12. inactive-slot deployment
13. runtime security proof
14. physical behavior proof
15. natural slot success
16. fallback-slot health
```

## Baseline

Before mutation verify exact source hashes, absence/presence expectations, and known-good image hashes.

If a baseline guard fails, do not mutate.

## Mutation

After a mutation has applied, do not rerun the whole block to repair a later failure. Use a targeted repair gate from post-mutation hashes.

Never put `exit` or `set -e` into commands intended for an interactive tmux shell.

## Build Output

Write full logs to `/tmp/...` and print bounded tails. With `tee`, preserve the producing command result via `${PIPESTATUS[0]}`.

Avoid recursive scans of giant Soong trees when `build.ninja` or `installs-<product>.mk` provide direct evidence.

## Generated Artifacts

Validate effective build topology:

- AIDL backend placement;
- Rust dylib/rlib choice;
- target partition;
- service contexts;
- frozen API dumps.

Do not rely only on source declarations when generated build files can prove the result.

## Hardware Security Capability Classification

Build and release gates must distinguish the portable SableOS security baseline from optional hardware-dependent hardening.

ARM MTE or equivalent hardware memory tagging is not a universal device-admission or production-release requirement. A target without hardware MTE must not fail merely because MTE is unavailable.

Record hardware-dependent security features using explicit states:

```text
AVAILABLE=YES|NO|UNKNOWN
ENABLED=YES|NO|NOT_APPLICABLE|UNKNOWN
VALIDATED=PASS|FAIL|NOT_APPLICABLE|NOT_RUN
```

For MTE specifically:

```text
AVAILABLE=NO
  -> ENABLED=NOT_APPLICABLE
  -> VALIDATED=NOT_APPLICABLE
  -> build/device remains eligible

AVAILABLE=YES and ENABLED=YES
  -> run MTE-specific validation
  -> PASS required before claiming MTE is active

AVAILABLE=YES and ENABLED=NO
  -> document the state and rationale
  -> do not claim MTE protection
  -> do not automatically reject the target
```

Validation scripts must not convert `NOT_APPLICABLE` into failure. They must also avoid unconditional MTE compiler, linker, kernel, allocator or runtime assumptions on non-MTE devices.

The absence of MTE does not authorize weakening SELinux, AVB/verified boot, app/process isolation, privilege separation, update integrity, or other portable mitigations.

See `HARDWARE_SECURITY_CAPABILITIES.md` for the normative policy.

## SELinux

Validate positive and negative policy:

- provider can register;
- required backend permission exists;
- intended client transaction authority is explicit;
- attribute-based platform grants are included in effective-policy review;
- unauthorized domains cannot transact with the service even if platform policy permits service-name discovery;
- no direct battery sysfs grant;
- no broad policy expansion.

Runtime must remain enforcing. Expected AVC denials from deliberate negative tests should be recorded separately from unexpected runtime denials.

## Image Proof

- extract target binary from filesystem image;
- compare byte-for-byte with built binary;
- verify runtime libraries in expected partition;
- verify service contexts in image;
- verify immutable vendor image unchanged where required.

## AVB

Validate `system_ext`, `vbmeta_system`, and expected top-level `vbmeta` behavior.

## Expected Delta

Expected image deltas are milestone-specific and must be classified from generated content rather than assumed from the primary install partition.

For frozen S1.7 power IPC on bramble, stable AIDL metadata and SELinux policy propagation produce the validated pattern:

```text
system.img          changed
product.img         changed
system_ext.img      changed
vendor_boot.img     changed
vbmeta_system.img   changed   # downstream AVB consequence
vbmeta.img          changed   # downstream AVB consequence

boot.img            unchanged
dtbo.img            unchanged
vendor.img          unchanged # immutable Google prebuilt
```

The root changes were classified file/component-by-file/component: `product` and `system` changes were policy/metadata propagation, `vendor_boot` changed only through its vendor ramdisk policy content, and AVB changes followed their covered partitions.

Unexpected deltas still block deployment until explained.

## Deployment

Determine active/inactive slots at runtime.

```text
known-good active slot
 -> fastbootd
 -> write inactive logical partition(s)
 -> bootloader
 -> write inactive vbmeta partition(s)
 -> verify source preserved
 -> activate target
 -> reboot Android
```

Activation is last.

## Runtime Proof

Verify:

- correct slot/device;
- enforcing SELinux;
- service domain/UID/GID;
- exact host/device binary hash;
- expected service registration;
- authorized client success;
- unauthorized transaction denial;
- expected negative-test AVCs only, with no unexplained relevant AVC denials;
- zero crash evidence;
- daemon stability.

For hardware-dependent security capabilities that are enabled, include their feature-specific runtime proof before claiming them. If the hardware capability is absent, record `NOT_APPLICABLE` rather than fabricating a pass or failing the device.

Root may be used briefly on userdebug for exact evidence where shell policy intentionally forbids access. Restore normal adb afterward.

## Physical Proof

When behavior depends on actual hardware state, use actual hardware rather than synthetic state.

## Acceptance Models

Harness logic must model valid intermediate states.

Both may be correct:

```text
external -> Battery -> external
external -> Battery -> Unknown -> external
```

## Slot Closure

Do not manually mark successful.

Require target naturally successful/bootable and fallback still successful/bootable.
