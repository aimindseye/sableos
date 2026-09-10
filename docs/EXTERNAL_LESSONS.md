# External Lessons

## Purpose

SableOS studies other mobile OS projects for product and systems-engineering ideas without importing their trust model uncritically.

External projects are evidence and design references. AOSP documentation remains normative for Android platform architecture, and GrapheneOS remains the primary additional security-engineering reference.

## MarathonOS lessons

### Ideas worth borrowing

#### Mobile-first product direction

Useful areas to investigate later:

- gesture-first navigation;
- unified communication/notification hub;
- live task previews;
- fast peek/return workflows;
- physical-keyboard-aware interaction.

#### Measurement-driven power work

Adopt:

```text
measure -> change -> remeasure -> keep/revert
```

for thermal, CPU, modem, memory and standby tuning.

#### Device layering

Maintain separation between:

- generic Sable platform services;
- Android compatibility integration;
- device-specific behavior.

#### Recovery as a product feature

Continue treating A/B rollback, recovery visibility and bounded diagnostics as product architecture.

#### Immutable-image awareness

Runtime configuration assumptions must be validated against the actual image/boot model.

### Ideas not to copy directly

#### Shell as privilege aggregator

Sable should retain:

```text
UI -> typed Sable service -> platform/framework/HAL
```

rather than putting broad hardware/system privilege in the shell.

#### Broad capabilities on general-purpose utilities

A narrow privileged service is preferable to giving a generic tool a broad capability for one UI feature.

#### Release shortcuts in production

Development convenience must be separated from release procedure. Avoid untrusted package installation, throwaway signing, embedded developer credentials, personal SSH access, password helper files, and unpinned source heads.

#### Disabled tests for core components

If a core component cannot run its normal test phase, make the exception explicit and compensate with a defined gate.

## Brax3 / iodéOS lessons

A September 2026 source review covered the Brax3 iodéOS manifest, device, prebuilt-kernel, vendor, MediaTek flashing and build repositories. Exact revisions and detailed findings are recorded in `BRAX3_IODEOS_REFERENCE.md`.

### Ideas worth borrowing

#### Explicit device-layer ownership

The Brax-specific manifest keeps device support concentrated in a small set of MediaTek/device/kernel-prebuilt/vendor repositories rather than scattering model-specific changes through common applications.

Sable should follow the same principle for non-Pixel targets.

#### Prebuilt-kernel support as a valid development model

Brax3 demonstrates that a modern Android userspace can be maintained above a vendor-controlled prebuilt kernel, DTB/DTBO and module set.

This is useful for Titan 2 development, but it is a **functional portability** precedent, not proof of independent kernel-security ownership.

#### Preserve mature vendor hardware stacks

Brax3 retains substantial MediaTek radio/IMS, camera, graphics, audio, GNSS, TEE/KeyMint/Gatekeeper and firmware components while adapting newer Android userspace around them.

Sable should initially preserve working vendor paths behind Android/VINTF boundaries rather than replacing modem or hardware protocols without evidence.

#### Make compatibility shims explicit

The Brax3 extraction layer performs versioned ABI compatibility work between newer Android and older vendor binaries.

Sable should permit narrowly documented compatibility shims but track each shim as maintenance/security debt with exact reason, target component, test and removal condition.

#### Firmware/update ownership matters

The Brax3 update model includes modem, TEE and SoC firmware partitions rather than treating a system image as the entire OS lifecycle.

Sable non-Pixel qualification must therefore track platform, kernel, vendor, modem, TEE, bootloader and connectivity firmware separately.

#### SELinux fixes should remain narrow

Brax3 device maintenance includes targeted SELinux corrections for real hardware regressions. This reinforces Sable's rule that AVCs are architecture evidence and do not justify broad permissive policy.

#### Physical partition variation must be qualified

Brax3 tooling evolved after discovering real hardware storage-layout variation. Sable should similarly qualify actual hardware capacity/layout before approving image or flashing assumptions.

### Patterns not to copy into Sable production

#### AVB fail-open fallback

A developer fallback from private keys to public AOSP test keys / verification-disabled vbmeta is not acceptable for Sable release-candidate or production builds.

Required Sable behavior:

```text
required production signing material missing
    -> release/build failure
```

#### Unguarded multi-partition flash scripts

Sable flash tooling must verify product identity, partition/slot expectations, image hashes and authorization immediately before mutation.

#### Moving release inputs

Container tags, unpinned apt state, `platform-tools-latest` downloads and moving manifest branches do not constitute an immutable release definition.

Sable releases require exact source/tool/vendor/kernel/firmware/signing provenance.

#### Treating a booting image as complete support

`BOOT=PASS` and `HOME=PASS` are bring-up signals only. Non-Pixel support requires radio/IMS, camera/audio, connectivity, suspend/power, security, OTA/recovery, AVB and firmware-lifecycle acceptance.

## Resulting Sable decisions

1. Keep UI unprivileged relative to hardware services.
2. Continue typed AIDL/service boundaries.
3. Require explicit client SELinux authorization.
4. Build lifecycle/resource policy as dedicated platform logic.
5. Use real device measurements for tuning.
6. Preserve device layering.
7. Treat recovery and immutable-image behavior as architecture.
8. Borrow mobile UX ideas independently from privilege design.
9. Allow prebuilt-kernel/vendor-BSP devices as development/integration targets without overstating their security ownership.
10. Separate N0 GSI labs, N1 integrated vendor/BSP ports and N2 production-qualified devices.
11. Treat platform, kernel, vendor, modem, TEE and bootloader security provenance independently.
12. Fail closed on missing production AVB/signing material.
13. Version and test every framework/vendor compatibility shim.
14. Use Titan 2 as the preferred interim non-Pixel UI/GSI candidate after Panther; retain Q25 as optional low-level MediaTek/kernel research; keep Q27 as the preferred future full-QWERTY candidate pending qualification.

See `BRAX3_IODEOS_REFERENCE.md`, `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`, `TITAN2_GSI_PLAN.md`, and `NON_PIXEL_DEVICE_ROADMAP.md`.