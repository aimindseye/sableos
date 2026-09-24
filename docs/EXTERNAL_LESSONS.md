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

## Keyboard-first and non-Pixel reference lessons

### OpenMiniLaunch / MinkLauncher

Reviewed repository: `katoaapps/openminilaunch`, Apache-2.0.

Useful lessons include immediate printable-key entry from HOME with first-key
preservation, a searchable command surface, app-published shortcuts,
work-profile-aware results, local-first data handling, active message/email
conversation grouping through `NotificationListenerService`, source-app
`RemoteInput` reply and assistant-role invocation over the foreground app.

Sable does not replace its Launcher3/Quickstep integration with Mink. It may
reuse Apache-licensed implementation ideas only after normal provenance/NOTICE
review and should prefer platform-owned integration where Sable owns the OS.

### Commander

Reviewed repository: `astroboii47/Commander`.

Useful lessons include a broad keyboard command vocabulary, app/settings/contact
search, recent-app navigation, notification-Hub triage and explicit handling of
Android limitations around third-party messaging and reply actions.

Accessibility/overlay workarounds required by an ordinary Android app are not
automatically the Sable platform architecture.

### Pastiera / Plektra

Pastiera remains a strong GPL-3.0 physical-keyboard IME/modifier/layout and
trackpad-behavior reference. Current source points to a future successor named
Plektra. Until that successor's accessible source, license and maintenance model
are established, Sable treats the family primarily as behavioral/test input.

Direct GPL code reuse requires an explicit licensing decision. Process/IPC
separation is not treated as an automatic legal safe harbor.

### q25toolbox

q25toolbox is valuable empirical evidence about effective keylayout discovery,
MediaTek/Q25 input failure modes, per-app keyboard behavior, firmware quirks and
stock-device constraints. Its root/KernelSU/LSPosed/Accessibility/bind-mount
mechanisms are not the production SableOS design when Sable owns the platform.

### TrebleDroid / RestlessOS

RestlessOS/TrebleDroid is a useful compatibility laboratory for arbitrary vendor
partitions and contains concrete Unihertz/MediaTek lessons. It also documents
cases where GrapheneOS-derived hardening is removed or disabled for broader
vendor compatibility.

Sable therefore uses it to learn **where compatibility breaks**, not to define
what Sable security should disable. Each candidate workaround must be reproduced,
device-scoped and entered into the security delta ledger defined by ADR-0010.

### Community / prototype evidence

Discord, Facebook and prototype reports may generate test hypotheses for Titan
or Q27. They do not become repository hardware claims until reproduced or backed
by source/firmware/device evidence.

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