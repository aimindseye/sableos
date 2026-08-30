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

## SELinux

Validate positive and negative policy:

- provider can register;
- required backend permission exists;
- no unintended client `find`;
- no direct battery sysfs grant;
- no broad policy expansion.

Runtime must remain enforcing.

## Image Proof

- extract target binary from filesystem image;
- compare byte-for-byte with built binary;
- verify runtime libraries in expected partition;
- verify service contexts in image;
- verify immutable vendor image unchanged where required.

## AVB

Validate `system_ext`, `vbmeta_system`, and expected top-level `vbmeta` behavior.

## Expected Delta

For current system_ext-only integration the normal pattern is:

```text
system_ext.img      changed
vbmeta_system.img   changed

boot.img            unchanged
dtbo.img            unchanged
product.img         unchanged
system.img          unchanged
vendor.img          unchanged
vendor_boot.img     unchanged
vbmeta.img          unchanged
```

Unexpected deltas block deployment until explained.

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
- zero relevant AVC denials;
- zero crash evidence;
- daemon stability.

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
