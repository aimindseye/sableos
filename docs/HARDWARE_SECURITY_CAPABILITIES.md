# SableOS Hardware Security Capability Policy

Status: **normative project-wide policy**.

SableOS defines a portable security baseline which must work across supported hardware families. Hardware-specific mitigations strengthen that baseline when available, but they do not automatically become device-admission requirements.

This document defines the canonical hardware-security capability record used by device ports, build gates and release evidence.

See `SECURITY_PRIVACY_ASSURANCE_STANDARD.md` for the full project-wide security/privacy baseline.

## Core rule

> Hardware security features are capability-dependent enhancements unless SableOS explicitly classifies a feature as part of the portable mandatory baseline.

A device must not be rejected, a build must not fail, and a release must not be classified insecure solely because the SoC lacks ARM Memory Tagging Extension (MTE), PAC, BTI, StrongBox, a discrete secure processor, or another optional hardware security feature.

The absence of optional hardware must never be used as a reason to weaken portable protections such as SELinux enforcing policy, verified boot / AVB, process and application isolation, exploit mitigations available on the target, update integrity, privilege separation or other device-supported hardening.

## Canonical capability state

Every hardware-security capability uses three orthogonal states:

```text
AVAILABLE=YES|NO|UNKNOWN
ENABLED=YES|NO|NOT_APPLICABLE|UNKNOWN
VALIDATED=PASS|FAIL|NOT_APPLICABLE|NOT_RUN
```

Interpretation:

```text
AVAILABLE=NO
  -> ENABLED=NOT_APPLICABLE
  -> VALIDATED=NOT_APPLICABLE
  -> device/build remains eligible

AVAILABLE=YES and ENABLED=YES
  -> feature-specific runtime validation is required before claiming protection

AVAILABLE=YES and ENABLED=NO
  -> document reason
  -> do not claim the protection
  -> target remains eligible unless an explicit milestone requires the feature

AVAILABLE=UNKNOWN
  -> investigate before making a security claim
  -> do not infer capability from vendor/product family alone
```

`NOT_APPLICABLE` is a successful classification for hardware which does not implement a capability. It is not equivalent to `FAIL`.

## Canonical SableOS hardware capability record

Device validation records should use these names where applicable:

```text
SABLEOS_HWSEC_MTE_AVAILABLE=
SABLEOS_HWSEC_MTE_ENABLED=
SABLEOS_HWSEC_MTE_VALIDATED=

SABLEOS_HWSEC_PAC_AVAILABLE=
SABLEOS_HWSEC_PAC_ENABLED=
SABLEOS_HWSEC_PAC_VALIDATED=

SABLEOS_HWSEC_BTI_AVAILABLE=
SABLEOS_HWSEC_BTI_ENABLED=
SABLEOS_HWSEC_BTI_VALIDATED=

SABLEOS_HWSEC_TBI_TAGGED_POINTERS_AVAILABLE=
SABLEOS_HWSEC_TBI_TAGGED_POINTERS_ENABLED=
SABLEOS_HWSEC_TBI_TAGGED_POINTERS_VALIDATED=

SABLEOS_HWSEC_TEE_AVAILABLE=
SABLEOS_HWSEC_TEE_ENABLED=
SABLEOS_HWSEC_TEE_VALIDATED=

SABLEOS_HWSEC_KEYMINT_AVAILABLE=
SABLEOS_HWSEC_KEYMINT_SECURITY_LEVEL=STRONGBOX|TRUSTED_ENVIRONMENT|SOFTWARE|UNKNOWN
SABLEOS_HWSEC_KEYMINT_VALIDATED=

SABLEOS_HWSEC_STRONGBOX_AVAILABLE=
SABLEOS_HWSEC_STRONGBOX_ENABLED=
SABLEOS_HWSEC_STRONGBOX_VALIDATED=

SABLEOS_HWSEC_HW_ROOT_OF_TRUST_AVAILABLE=
SABLEOS_HWSEC_HW_ROOT_OF_TRUST_ENABLED=
SABLEOS_HWSEC_HW_ROOT_OF_TRUST_VALIDATED=

SABLEOS_HWSEC_KEY_ATTESTATION_AVAILABLE=
SABLEOS_HWSEC_KEY_ATTESTATION_ENABLED=
SABLEOS_HWSEC_KEY_ATTESTATION_VALIDATED=

SABLEOS_HWSEC_KEY_ROLLBACK_RESISTANCE_AVAILABLE=
SABLEOS_HWSEC_KEY_ROLLBACK_RESISTANCE_ENABLED=
SABLEOS_HWSEC_KEY_ROLLBACK_RESISTANCE_VALIDATED=

SABLEOS_HWSEC_RPMB_OR_REPLAY_PROTECTED_STORAGE_AVAILABLE=
SABLEOS_HWSEC_RPMB_OR_REPLAY_PROTECTED_STORAGE_ENABLED=
SABLEOS_HWSEC_RPMB_OR_REPLAY_PROTECTED_STORAGE_VALIDATED=

SABLEOS_HWSEC_SECURE_PROCESSOR_AVAILABLE=
SABLEOS_HWSEC_SECURE_PROCESSOR_ENABLED=
SABLEOS_HWSEC_SECURE_PROCESSOR_VALIDATED=

SABLEOS_HWSEC_AVB_VERIFIED_BOOT_AVAILABLE=
SABLEOS_HWSEC_AVB_VERIFIED_BOOT_ENABLED=
SABLEOS_HWSEC_AVB_VERIFIED_BOOT_VALIDATED=

SABLEOS_HWSEC_BOOT_ROLLBACK_PROTECTION_AVAILABLE=
SABLEOS_HWSEC_BOOT_ROLLBACK_PROTECTION_ENABLED=
SABLEOS_HWSEC_BOOT_ROLLBACK_PROTECTION_VALIDATED=

SABLEOS_HWSEC_IOMMU_OR_DMA_ISOLATION_AVAILABLE=
SABLEOS_HWSEC_IOMMU_OR_DMA_ISOLATION_ENABLED=
SABLEOS_HWSEC_IOMMU_OR_DMA_ISOLATION_VALIDATED=

SABLEOS_HWSEC_REMOTE_KEY_PROVISIONING_AVAILABLE=
SABLEOS_HWSEC_REMOTE_KEY_PROVISIONING_ENABLED=
SABLEOS_HWSEC_REMOTE_KEY_PROVISIONING_VALIDATED=
```

The registry is extensible. A device-specific capability may be added without making it universal.

## Capability classes

### Memory and control-flow hardening

#### ARM MTE

ARM MTE is explicitly classified as **optional / capability-dependent hardening**.

SableOS policy:

```text
hardware MTE availability = OPTIONAL
SableOS device eligibility = MUST NOT depend on MTE availability
build success               = MUST NOT depend on MTE availability
production eligibility      = MUST NOT depend on MTE availability
```

When hardware MTE is absent:

```text
SABLEOS_HWSEC_MTE_AVAILABLE=NO
SABLEOS_HWSEC_MTE_ENABLED=NOT_APPLICABLE
SABLEOS_HWSEC_MTE_VALIDATED=NOT_APPLICABLE
SABLEOS_DEVICE_ELIGIBLE=YES
```

When MTE is present and enabled, runtime validation is required before SableOS claims that protection.

Build logic must not add unconditional MTE compiler, linker, kernel, allocator, init or runtime requirements on non-MTE targets.

#### Pointer Authentication (PAC)

PAC is capability-dependent control-flow hardening. It should be preserved/enabled where supported by the CPU, kernel, compiler and Android target configuration.

A target lacking PAC remains eligible. A target with PAC should not claim it is active solely because the CPU architecture nominally supports it; effective binary/kernel/runtime state should be checked where practical.

#### Branch Target Identification (BTI)

BTI is capability-dependent indirect-branch hardening. It follows the same model as PAC: preserve/use it where supported, validate before claiming, and classify absence as `NOT_APPLICABLE` rather than failure.

#### TBI / tagged-pointer readiness

Android tagged-pointer/TBI behavior is useful memory-safety hardening and MTE-readiness on compatible AArch64 devices/kernels. Record it separately from MTE because tagged pointers can be available without hardware MTE.

### Secure execution and key protection

#### TEE

A Trusted Execution Environment is common but not universal in implementation quality. Record whether the Android security services actually use the TEE, rather than assuming a vendor marketing name proves effective isolation.

#### KeyMint

Record KeyMint availability and effective security level:

```text
STRONGBOX
TRUSTED_ENVIRONMENT
SOFTWARE
UNKNOWN
```

Do not represent software-enforced key characteristics as hardware-enforced.

#### StrongBox

StrongBox is a stronger optional hardware tier, not a universal SableOS requirement. When present, preserve and validate it. When absent, a TEE-backed KeyMint target may still be SableOS eligible.

#### Hardware root of trust

Record whether the secure key/attestation environment is cryptographically bound to verified boot/root-of-trust state. Validate using Android-supported evidence where available rather than relying on SoC branding.

#### Key attestation

Record whether hardware-backed key attestation is available and whether the attested security level/root-of-trust data matches the claimed platform state.

#### Key rollback resistance / replay-protected storage

Record rollback-resistant key capability independently from boot/image rollback protection. RPMB or another replay-protected mechanism may back this feature; the exact mechanism is device-specific.

#### Secure processor / discrete security controller

Some devices expose a discrete secure processor or equivalent isolated security controller. This is additive hardening. Record what security services it actually anchors; do not assume a vendor feature name implies StrongBox or any specific Android guarantee.

### Boot and DMA/isolation hardening

#### AVB / verified boot

AVB/verified boot is part of SableOS production integrity expectations when the device supports a viable production/relock path. Development builds may run unlocked, but this is a development-state exception, not a production-security claim.

#### Boot rollback protection

Record whether anti-rollback/version binding is available and enabled for the boot chain/partitions relevant to the device.

#### IOMMU / DMA isolation

Record platform DMA isolation capability where it materially affects device security. Validation is device/kernel specific; availability should not be guessed from SoC family alone.

### Provisioning capabilities

#### Remote Key Provisioning

Record Android Remote Key Provisioning capability when present. It is not a universal device-admission requirement but may strengthen attestation/provisioning architecture on supported devices.

## Build-system rules

Common SableOS build logic must:

1. detect or inherit hardware capability instead of assuming a Pixel-specific feature set;
2. avoid unconditional compiler/linker/kernel/init/allocator/runtime requirements for optional features on unsupported targets;
3. preserve upstream/AOSP/vendor hardening when present unless there is a documented incompatibility;
4. avoid disabling common portable hardening merely to accommodate hardware without one optional capability;
5. keep device-specific security configuration below common Sable semantic/application layers;
6. record capability state in validation evidence instead of product-name allowlists where a real capability check exists;
7. prefer runtime/effective-state probes to marketing/spec-sheet assumptions;
8. fail a feature claim when the feature is reported enabled but validation fails;
9. not fail device eligibility solely because an optional capability is `NO` / `NOT_APPLICABLE`.

## Security capability claim rule

A release must distinguish:

- capability not present;
- capability present but disabled;
- capability enabled but not yet validated;
- capability enabled and validated.

Examples:

```text
# Valid non-MTE target
SABLEOS_HWSEC_MTE_AVAILABLE=NO
SABLEOS_HWSEC_MTE_ENABLED=NOT_APPLICABLE
SABLEOS_HWSEC_MTE_VALIDATED=NOT_APPLICABLE

# Valid PAC-enabled target
SABLEOS_HWSEC_PAC_AVAILABLE=YES
SABLEOS_HWSEC_PAC_ENABLED=YES
SABLEOS_HWSEC_PAC_VALIDATED=PASS

# Capability exists but is not enabled
SABLEOS_HWSEC_STRONGBOX_AVAILABLE=YES
SABLEOS_HWSEC_STRONGBOX_ENABLED=NO
SABLEOS_HWSEC_STRONGBOX_VALIDATED=NOT_RUN
```

The third case must not be advertised as StrongBox protection.

## Device policy

### Pixel 7 (`panther`)

Panther remains eligible even though hardware MTE is not part of its capability set. MTE must not become a Panther P1B, V0, signing, release or flash blocker.

Panther should still receive a complete capability record for PAC/BTI/tagged pointers, TEE/KeyMint, root-of-trust/attestation, rollback protections and other available hardware security features.

### Zinwa / MediaTek targets

Zinwa Q25/Q27-class and other future MediaTek/non-Pixel devices remain eligible regardless of MTE/PAC/BTI/StrongBox presence provided they pass the actual mandatory SableOS baseline and device-specific source, unlock/recovery, vendor, radio, hardware, security-lifecycle and release gates.

Do not assume MediaTek devices lack a feature merely because another MediaTek generation lacks it. Do not assume a feature exists because a newer Dimensity platform advertises it. Probe and record the actual target.

### Future devices

For any new target, generate the capability record before making hardware-specific security claims. Stronger hardware should result in stronger enabled SableOS protections where practical, without fragmenting common security semantics.

## Security claims

SableOS release notes and security documentation must distinguish:

- protections guaranteed by the portable SableOS baseline;
- protections available only on the specific device;
- protections which exist in hardware but are not enabled;
- protections which were enabled and runtime-validated.

Do not imply that all SableOS devices provide MTE, PAC, BTI, StrongBox or a secure processor. Do not imply that absence of one of these features fails the SableOS security model.

## Change-control rule

Changing an optional hardware security capability into a mandatory device-admission requirement requires an explicit project policy/ADR change. It must not happen implicitly through a build flag, borrowed upstream hardware requirement, GrapheneOS reference requirement or validation script.

GrapheneOS and other security-focused projects remain valuable engineering references, but their device admission requirements are not automatically SableOS requirements. SableOS prioritizes a portable security baseline across Pixel, Zinwa/MediaTek and other viable devices, then layers stronger hardware-specific protections on top when available.