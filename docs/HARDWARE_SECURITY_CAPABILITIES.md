# SableOS Hardware Security Capability Policy

SableOS defines a portable security baseline which must work across supported hardware families. Hardware-specific mitigations strengthen that baseline when available, but they do not automatically become device-admission requirements.

## Core rule

> Hardware security features are capability-dependent enhancements unless SableOS explicitly classifies a feature as part of the portable mandatory baseline.

A device must not be rejected, a build must not fail, and a release must not be classified insecure solely because the SoC lacks ARM Memory Tagging Extension (MTE) or an equivalent hardware memory-tagging feature.

The absence of MTE must never be used as a reason to weaken portable protections such as SELinux enforcing policy, verified boot / AVB, process and application isolation, exploit mitigations available on the target, update integrity, privilege separation, or other device-supported hardening.

## Security capability classes

### 1. Portable required baseline

These protections are expected wherever the Android/device substrate supports a production implementation and are not conditional on MTE availability:

- SELinux enforcing;
- verified boot / AVB and release-signing discipline;
- Android application sandboxing and process isolation;
- narrow Binder/IPC and Linux privilege boundaries;
- secure update, rollback and recovery behavior appropriate to the target;
- exploit mitigations supported by the target compiler, kernel and userspace;
- hardened allocator behavior where portable and compatible;
- least-privilege service design;
- maintained kernel/vendor/firmware provenance appropriate to the claimed support level.

A port may still have target-specific limitations, but those limitations must be documented rather than silently converted into unrelated security exceptions.

### 2. Capability-dependent hardening

These protections depend on SoC, CPU architecture, kernel, firmware, vendor implementation, or platform support. They are desirable when available but are not universal SableOS device-admission requirements.

Examples include:

- ARM MTE or equivalent hardware memory tagging;
- hardware-assisted memory-safety features exposed only by some CPU generations;
- device-specific virtualization or isolation features;
- hardware-backed mitigations which are absent from otherwise viable devices.

For capability-dependent hardening, the correct question is not "does every SableOS device have this feature?" but "if the device has the capability, can SableOS preserve, enable and validate it safely?"

### 3. Device-specific enhancements

Some protections may exist only on one vendor or device family. They should remain behind device/platform capability checks and must not leak into common product logic as unconditional requirements.

## ARM MTE policy

ARM MTE is explicitly classified as **optional / capability-dependent hardening**.

SableOS policy is:

```text
hardware MTE availability = OPTIONAL
SableOS device eligibility = MUST NOT depend on MTE availability
build success               = MUST NOT depend on MTE availability
production eligibility      = MUST NOT depend on MTE availability
```

When hardware MTE is absent:

```text
SABLEOS_MTE_AVAILABLE=NO
SABLEOS_MTE_REQUIRED=NO
SABLEOS_MTE_STATUS=NOT_APPLICABLE
SABLEOS_DEVICE_ELIGIBLE=YES
```

When hardware MTE is present:

```text
SABLEOS_MTE_AVAILABLE=YES
SABLEOS_MTE_SUPPORT=DESIRED
SABLEOS_MTE_ENABLEMENT=PREFERRED_WHERE_COMPATIBLE
SABLEOS_MTE_RUNTIME_VALIDATION=REQUIRED_IF_ENABLED
```

A build or release gate must not turn `SABLEOS_MTE_AVAILABLE=NO` into a failure. `NOT_APPLICABLE` is a successful capability classification for hardware without MTE.

If MTE is available but intentionally not enabled, the release/validation record should state that fact and rationale. It is a hardening gap or product decision to track, not an automatic device-rejection condition unless a future milestone explicitly declares otherwise.

## Build-system rules

Common SableOS build logic must:

1. detect or inherit hardware capability instead of assuming MTE exists;
2. avoid unconditional MTE compiler, linker, kernel, init, allocator, or runtime requirements on targets without MTE;
3. preserve upstream/AOSP/vendor MTE support when present unless there is a documented incompatibility;
4. avoid disabling common portable hardening merely to accommodate non-MTE hardware;
5. keep device-specific MTE configuration below common Sable semantic/application layers;
6. record capability state in validation evidence instead of using product-name allowlists where a real capability check exists.

A target without MTE should build through the normal product path. MTE-specific modules, flags or runtime tests should be conditional on the target advertising/supporting the feature.

## Validation-state model

Hardware-security capability gates should use explicit states rather than binary assumptions:

```text
AVAILABLE=YES|NO|UNKNOWN
ENABLED=YES|NO|NOT_APPLICABLE|UNKNOWN
VALIDATED=PASS|FAIL|NOT_APPLICABLE|NOT_RUN
```

Recommended decision model:

```text
AVAILABLE=NO
  -> ENABLED=NOT_APPLICABLE
  -> VALIDATED=NOT_APPLICABLE
  -> device/build remains eligible

AVAILABLE=YES and ENABLED=YES
  -> run feature-specific runtime validation
  -> PASS required for claiming the feature is active

AVAILABLE=YES and ENABLED=NO
  -> document reason
  -> do not claim MTE protection
  -> device/build remains eligible unless a milestone explicitly requires it

AVAILABLE=UNKNOWN
  -> investigate before making an MTE security claim
  -> do not infer unsupported or supported from product family alone
```

## Device examples

### Pixel 7 (`panther`)

Pixel 7 is a valid SableOS development and production-capable target even though hardware MTE is not part of its security capability set.

For Panther validation:

```text
SABLEOS_MTE_AVAILABLE=NO
SABLEOS_MTE_REQUIRED=NO
SABLEOS_MTE_STATUS=NOT_APPLICABLE
SABLEOS_DEVICE_ELIGIBLE=YES
```

MTE must therefore not be introduced as a blocker in Panther P1B, V0, release, signing or device-flash gates.

### Zinwa / MediaTek targets

Zinwa Q25/Q27-class and other future MediaTek or non-Pixel devices remain eligible for SableOS regardless of MTE presence, provided they pass their actual source, unlock/recovery, vendor, radio, hardware, security-lifecycle and release gates.

MTE capability must be detected and recorded if available, not presumed as a prerequisite.

### Future MTE-capable devices

For devices with hardware MTE, SableOS should preserve and make useful use of the capability where compatible. If enabled, runtime validation should prove the configuration rather than relying on CPU-family assumptions.

## Security claims

SableOS release notes and security documentation must distinguish:

- protections guaranteed by the portable SableOS baseline;
- protections available only on the specific device;
- protections which exist in hardware but are not enabled;
- protections which were enabled and runtime-validated.

Do not imply that all SableOS devices provide MTE. Do not imply that a non-MTE device fails the SableOS security model.

## Change-control rule

Changing MTE from optional capability-dependent hardening to a mandatory device-admission requirement requires an explicit project policy/ADR change. It must not happen implicitly through a build flag, borrowed upstream device policy, GrapheneOS reference requirement, or validation script.

GrapheneOS and other security-focused projects remain valuable engineering references, but their hardware admission requirements are not automatically SableOS requirements. SableOS prioritizes a portable security baseline across Pixel, Zinwa/MediaTek and other viable devices, then layers stronger hardware-specific protections on top when available.
