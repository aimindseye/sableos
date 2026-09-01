# ADR 0005: Independent kernel security updates

Status: **Accepted**

## Context

SableOS needs to reduce exposure time to Linux/Android kernel vulnerabilities without coupling every kernel security fix to a complete operating-system feature release.

Modern Android devices may use the Generic Kernel Image (GKI) model with a stable Kernel Module Interface (KMI) within a bounded Android/LTS/KMI family. This can permit a security-fixed kernel to remain compatible with vendor modules across allowed same-KMI updates. However, GKI modules in `system_dlkm` are tied to their matching GKI build, and cross-KMI/LTS movement can invalidate vendor/device module assumptions.

SableOS also requires production verified boot, A/B rollback, honest security claims and heterogeneous device support across Pixel and future MediaTek/Zinwa targets. A policy that simply flashes the newest upstream kernel would violate those goals.

## Decision

SableOS supports independent kernel security updates under three classes:

```text
K1 = specific security backport within the existing supported kernel/KMI contract
K2 = same-KMI stable/GKI sublevel advance with expanded regression testing
K3 = cross-KMI/LTS migration; treated as a full device/platform migration
```

K1 is preferred. K2 is supported when the same KMI and module/device contracts remain valid. K3 is not a routine kernel-only hotfix.

Production K1/K2 updates must:

- use pinned supported Android/device kernel source and toolchain provenance;
- preserve the allowed KMI contract;
- build/update matching GKI modules where required;
- validate vendor module compatibility;
- produce exact affected-partition/image manifests;
- preserve AVB/signing correctness;
- use signed A/B update delivery on supported production devices;
- validate boot, module loading, SELinux and device capability parity on physical hardware;
- require natural slot success and preserve the previous successful slot during closure;
- report kernel fixes independently from unresolved vendor/firmware risk and Android SPL claims.

A production SableOS kernel security update must not require root or an unlocked bootloader.

## Build integration

Each supported device establishes a sealed kernel baseline covering kernel release, Android kernel branch, KMI, source manifest, config, module sets, kernel-related partitions and update topology.

Ordinary platform/product builds reference or verify that baseline when kernel inputs are unchanged. They do not rebuild or replace the kernel merely because independent kernel updates are supported.

Only a dedicated kernel-security gate may intentionally mutate the sealed kernel baseline under K1/K2 rules.

The current Panther P1B product build predates this ADR and is not restarted or invalidated. Panther's first canonical kernel baseline is established after target-files closure during V0/device provenance and runtime qualification.

## Security patch level

A Sable kernel backport may be reported as an exact CVE/security fix, but it does not by itself authorize advancing Android's security patch level. Android SPL remains governed by complete applicable bulletin coverage and the Sable security-maintenance policy.

## Device portability

The update capability is device-specific:

- Pixel/GKI-class targets may support K1/K2 when the ACK/GKI/KMI/module/A-B contracts are proven.
- MediaTek/Zinwa targets may support the same model when sufficient kernel source, module compatibility and signed update control are available.
- A target that cannot safely support independent kernel updates remains eligible for SableOS; it simply records that capability as unavailable for that device.

## Consequences

Positive:

- shorter kernel-vulnerability exposure windows;
- security fixes can ship without waiting for feature releases;
- locked-bootloader/AVB security is preserved;
- previous A/B slot remains a rollback path;
- kernel and proprietary-vendor security state remain honestly separated.

Costs:

- SableOS must maintain per-device kernel/KMI/module baselines;
- same-KMI updates still require significant ABI/module/physical regression testing;
- independent kernel updates may be impossible on targets with unavailable/incompatible proprietary modules;
- kernel security maintenance becomes a recurring release-engineering responsibility.

## Rejected alternatives

### Wait only for complete OEM/OS releases

Rejected because it unnecessarily extends exposure to open-source kernel vulnerabilities that SableOS can safely patch and validate itself.

### Flash the newest upstream kernel image

Rejected for production because it ignores Android ACK/GKI/KMI, module, device configuration, AVB and update/rollback contracts.

### Treat every kernel version bump as proof of security

Rejected because Android/OEM kernels may backport fixes without changing the upstream sublevel, and a higher version can still be misconfigured or incompatible.

## Normative implementation

See `../KERNEL_SECURITY_UPDATE_POLICY.md`, `../SECURITY_MAINTENANCE.md`, and `../RELEASE_VALIDATION.md`.