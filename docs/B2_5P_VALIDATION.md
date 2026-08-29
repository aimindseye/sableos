# B2.5P validation — Android 12.1 Rust vendor packaging bridge

Status: **PASS**.

B2.5P resolves two constraints discovered by the B2.5 pre-flash gates:

1. Android 12 Treble SELinux correctly rejects direct `sysfs_batteryinfo` reads from a `coredomain` service.
2. The pinned Android 12.1 Soong tree does not support `vendor: true` directly on a `rust_binary` (`vendor or soc_specific: Rust modules do not yet support soc-specific modules`).

The validated compatibility architecture is:

```text
/system_ext/bin/oxynoded
    -> coredomain

/vendor/bin/sable-powerd
    -> non-coredomain vendor domain
    -> read-only sysfs_batteryinfo
```

`oxynoded` remains isolated from `sable-powerd`; no IPC has been introduced yet.

## Android 12.1 build bridge

The Rust helper is compiled as a non-installable 64-bit Rust artifact and then packaged into `/vendor/bin/sable-powerd` through a vendor `cc_prebuilt_binary`. This is a frozen Android-12.1 compatibility measure only; it does not change the runtime trust boundary.

Validated gates:

- Rust build-only source boundary: PASS;
- vendor packaging bridge: PASS;
- host mapper/protocol regression: PASS;
- vendor helper binary present: PASS;
- vendor init RC present: PASS;
- no stale system_ext helper binary/init RC: PASS;
- final helper ELF is ARM64 PIE;
- final helper ELF depends only on `libc.so` and `libdl.so`;
- system_ext policy contains `oxynoded` and not `sable_powerd`: PASS;
- vendor policy contains `sable_powerd`: PASS;
- `oxynoded` file context is present: PASS;
- `/vendor/bin/sable-powerd` file context is present: PASS;
- precompiled SELinux policy present: PASS;
- `sable_powerd` is not permissive: PASS;
- permissive-domain output contains only `su` on the userdebug build.

Validated vendor helper SHA-256:

```text
fccd5f9d605fcb16fb7d596ae66e1806ac50b132337eed907ad84ffe80bd4c5e
```

Validated precompiled SELinux policy SHA-256:

```text
050a214e54a6442d72f258d965d901fc8d2d1ef07747e2dcf65b321581c4e86c
```

## Superseded evidence

The earlier B2.5A SELinux-policy build PASS is not valid SELinux-integration evidence because the Sable policy directory was not yet registered in the Android policy build. Its host/source/package checks remain useful.

The initial B2.5B pre-flash audit correctly failed because both Sable executables were still labeled `system_file` and the Sable domains were absent from generated policy. That failure prevented an unsafe flash.

A later direct vendor-Rust attempt also correctly failed at Soong bootstrap because the pinned Android 12.1 Rust build system lacks vendor/soc-specific Rust-module support.

## Next gate

Regenerate the complete B2 images and target-files incrementally, then verify the actual filesystem SELinux xattrs for both `/system_ext/bin/oxynoded` and `/vendor/bin/sable-powerd`, compiled-policy confinement, target-files integrity, and partition placement before constructing any flash package.
