# ADR 0004: Portable security/privacy baseline with additive hardware capabilities

- Status: Accepted
- Date: 2026-09-01

## Context

SableOS targets heterogeneous hardware: current Pixel development, historical Pixel references, and future MediaTek/Zinwa and other devices.

Security-focused reference projects may define hardware admission rules appropriate to their own product scope. SableOS also wants to use modern hardware mitigations such as MTE, PAC, BTI, StrongBox, secure processors and hardware-backed key protection when available.

Making any one optional CPU/SoC feature a universal prerequisite would unnecessarily couple the common OS architecture to one hardware generation and could exclude otherwise viable devices. Conversely, treating hardware diversity as a reason to weaken the common security/privacy baseline would undermine the project’s purpose.

The project also needs one repeatable meaning of "secure" and "private" across device ports rather than milestone-specific lists of ad hoc checks.

## Decision

SableOS adopts:

1. a **portable mandatory security/privacy baseline** shared across viable supported devices;
2. **additive hardware-security capabilities** which are detected, enabled where compatible and validated before being claimed;
3. an explicit three-state evidence model for optional hardware capabilities;
4. standardized security/privacy control families and assurance stages;
5. a canonical release evidence record for security, privacy, hardware capabilities, provenance and unresolved risk.

Hardware capability state is:

```text
AVAILABLE=YES|NO|UNKNOWN
ENABLED=YES|NO|NOT_APPLICABLE|UNKNOWN
VALIDATED=PASS|FAIL|NOT_APPLICABLE|NOT_RUN
```

If an optional capability is not implemented by the hardware:

```text
AVAILABLE=NO
ENABLED=NOT_APPLICABLE
VALIDATED=NOT_APPLICABLE
```

This does not make the device fail the portable baseline.

Examples of additive capabilities include:

- MTE;
- PAC;
- BTI;
- tagged-pointer/TBI support;
- TEE/KeyMint hardware enforcement;
- StrongBox;
- hardware root of trust and key attestation;
- rollback-resistant key support;
- replay-protected storage;
- secure processor;
- boot rollback protection;
- IOMMU/DMA isolation;
- Remote Key Provisioning.

The registry is extensible.

## Mandatory privacy direction

SableOS defaults to:

- no mandatory Sable telemetry/analytics;
- remote diagnostics opt-in;
- documented Sable-owned network egress;
- data minimization and local processing where practical;
- avoidance of unnecessary persistent identifiers;
- bounded logs/retention;
- real enforcement behind privacy UI;
- explicit privacy/data-flow records for shipped Sable-owned privileged services, preinstalled apps and compatibility components.

## Assurance stages

SableOS uses:

```text
DEVELOPMENT
RELEASE_CANDIDATE
PRODUCTION
```

Development state may use `userdebug`, unlocked bootloader and test keys. Production claims require production signing/verified boot, honest security-maintenance provenance, privacy/runtime evidence and the other gates defined by the assurance standard.

## Reference frameworks

AOSP remains the normative Android platform/security architecture source.

NIST SSDF, NIST Privacy Framework, OWASP MASVS and SLSA are used as cross-check/reference frameworks for secure development, privacy risk, application security and supply-chain provenance. SableOS does not claim certification merely by referencing them.

GrapheneOS remains a valuable security-engineering reference, but its device admission requirements are not automatically SableOS requirements.

## Consequences

Positive:

- Pixel and MediaTek/Zinwa ports can share one security/privacy architecture;
- newer devices receive stronger hardware-backed hardening without fragmenting common semantics;
- a missing optional capability cannot accidentally become a build failure;
- a present-but-disabled capability cannot be falsely advertised as active;
- privacy/network behavior becomes testable release evidence rather than only product intent;
- security claims become more comparable across devices and releases.

Costs:

- each new device needs a capability inventory and validation record;
- production releases need privacy/data-flow/network-egress evidence;
- hardware-specific validation requires more physical-device work;
- build/release scripts must distinguish `FAIL`, `NOT_APPLICABLE`, `NOT_RUN` and `UNKNOWN` correctly.

## Rejected alternatives

### Require MTE for all SableOS devices

Rejected because it would unnecessarily exclude viable devices, including device classes where MTE is not implemented, while adding no protection to the hardware that lacks it.

### Disable or ignore MTE/PAC/BTI to keep all devices identical

Rejected because portability should not mean discarding stronger protection available on newer hardware.

### Copy one reference project’s hardware admission rules wholesale

Rejected because SableOS has a broader hardware/product portability objective and must own its security claims.

### Use a single opaque security score

Rejected because it hides which controls are present, missing, not applicable or unvalidated. SableOS uses explicit control/capability evidence instead.

## Normative documents

- `SECURITY_PRIVACY_ASSURANCE_STANDARD.md`
- `HARDWARE_SECURITY_CAPABILITIES.md`
- `SECURITY_PRIVACY_RELEASE_RECORD_TEMPLATE.md`
- `SECURITY_MODEL.md`
- `RELEASE_VALIDATION.md`
- `SECURITY_MAINTENANCE.md`
