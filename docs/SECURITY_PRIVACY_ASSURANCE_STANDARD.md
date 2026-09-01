# SableOS Security and Privacy Assurance Standard

Status: **normative project-wide policy**.

SableOS uses one portable security and privacy baseline across supported hardware families. Device-specific hardware security features strengthen that baseline when available, but they do not silently redefine device eligibility or weaken the common standard when absent.

This document standardizes what SableOS means by a secure/private build, what evidence each release stage must produce, and how hardware-dependent protections are recorded.

## Core principles

1. **Portable baseline first.** Mandatory protections must be implementable across viable Pixel, MediaTek/Zinwa, and future hardware families.
2. **Capability-dependent hardening is additive.** MTE, PAC, BTI, StrongBox, secure processors and similar hardware features are used when available but are not universal device-admission requirements unless explicitly promoted by a future policy/ADR.
3. **Least privilege is the default.** Services, applications, SELinux domains, Binder APIs, filesystem access, Linux capabilities and network access receive only the authority required for their narrow responsibility.
4. **Privacy is an architectural property.** Data minimization, local processing, bounded retention and explicit user control are defaults, not optional UI features layered on later.
5. **No hidden security claims.** A feature is claimed only when its configuration and runtime state are evidenced. `NOT_APPLICABLE` is valid when hardware lacks a capability.
6. **No hidden privacy claims.** Network destinations, telemetry, identifiers, privileged data flows and persistent storage must be inventoried and testable.
7. **Security maintenance is continuous.** Platform, kernel, firmware/vendor, browser/WebView, modules and Sable-owned dependencies are tracked independently; the weakest unremediated layer limits the security claim.
8. **Compatibility exceptions are scoped.** A broken application or device feature does not justify globally weakening the OS when a narrow per-app/per-device exception is possible.
9. **Development state is not production state.** `userdebug`, root-capable adb, test keys and unlocked bootloaders are acceptable for bring-up but cannot be represented as production security posture.
10. **Evidence closes milestones.** Compilation alone is not acceptance; source, generated artifacts, policy, images, runtime behavior and physical-device behavior are proven where relevant.

## Reference standards and scope

SableOS uses established standards as reference vocabularies and cross-checks. This does **not** claim certification or conformance unless a separate audit explicitly establishes it.

- **AOSP / Android security architecture** — normative technical reference for Android platform behavior, SELinux, AVB, Keystore/KeyMint, permissions, application sandboxing, memory-safety features and update architecture.
- **NIST SP 800-218 Secure Software Development Framework (SSDF)** — secure-development lifecycle reference for protecting software, producing well-secured releases, responding to vulnerabilities and preventing recurrence.
- **NIST Privacy Framework** — privacy-risk management reference, especially Identify/Govern/Control/Communicate/Protect outcomes.
- **OWASP MASVS** — application-facing mobile security verification reference for storage, cryptography, authentication, network, platform interaction, code quality and resilience.
- **SLSA** — software supply-chain provenance/build-integrity reference.

SableOS adapts these references to an Android operating-system project; it does not import requirements that conflict with the project’s hardware portability or trust-boundary model without explicit review.

## Assurance stages

Every build or milestone intended for device use must identify its assurance stage.

### DEVELOPMENT

Purpose: bring-up, diagnosis and architecture validation.

Allowed:

- `userdebug`;
- unlocked bootloader;
- test/dev keys;
- root-capable adb where deliberately enabled;
- temporary diagnostics and narrowly bounded instrumentation.

Required even in development:

- SELinux stays enforcing unless a narrowly documented diagnostic exception is explicitly authorized;
- source and build inputs are pinned/sealed for the gate being evaluated;
- no unexplained global privilege expansion;
- no fabricated security patch level or production claim;
- hardware-security capability state is recorded when relevant.

### RELEASE_CANDIDATE

Purpose: prove production architecture before release signing/rollout.

Required:

- complete product build and image provenance;
- enforcing SELinux and compiled-policy audit;
- AVB/partition verification;
- privacy/network/data-flow inventory for shipped Sable components;
- security-maintenance and unresolved-risk review;
- hardware-security capability record;
- application compatibility and critical hardware capability regression checks;
- no unexplained telemetry or network egress;
- release blockers classified rather than hidden.

### PRODUCTION

Purpose: end-user security/privacy claim.

Required in addition to release-candidate gates:

- `user` production configuration unless a documented product exception says otherwise;
- production release signing and verified boot;
- relocked/relockable boot chain when the supported device architecture permits it;
- honest Android security patch level and Sable security-maintenance manifest;
- current supported kernel/vendor/firmware status consistent with the release claim;
- production update/recovery/rollback path proven;
- privacy defaults and user controls validated on physical hardware;
- published unresolved-risk/security-capability statement;
- no development credentials, personal Wi-Fi, SSH backdoors, debug-only trust anchors or equivalent artifacts.

## Standard control families

Control IDs give future validation scripts and release records a stable vocabulary.

### SEC-BOOT — Boot and integrity

Required baseline:

- AVB/verified-boot chain understood and validated;
- image/signing provenance recorded;
- rollback/version-binding behavior preserved where supported;
- bootloader state appropriate to assurance stage;
- recovery path does not require disabling core security controls as normal procedure.

### SEC-ISO — Isolation and least privilege

Required baseline:

- SELinux enforcing;
- dedicated domains for privileged Sable services;
- Android UID/app sandbox preserved;
- Binder/service-manager authority explicit;
- Linux capabilities/device nodes/filesystems limited to actual need;
- negative authorization tests for new privileged APIs;
- no generic privileged command executor.

### SEC-MEM — Memory and control-flow hardening

Required portable behavior:

- preserve Android/compiler/kernel hardening applicable to the target;
- do not disable portable mitigations merely because a hardware-specific feature is absent;
- prefer memory-safe implementation languages for new privileged Sable code where practical;
- compatibility exceptions are narrow and evidence-backed.

Capability-dependent examples:

- MTE;
- PAC;
- BTI;
- tagged-pointer/TBI readiness;
- device/compiler-specific control-flow or memory-hardening features.

### SEC-KEY — Key, credential and secure-execution protection

Record and preserve where available:

- KeyMint security level;
- TEE;
- StrongBox or discrete secure element;
- hardware root-of-trust binding;
- key attestation;
- rollback-resistant key support;
- secure credential/authenticator integration.

Absence of a stronger optional hardware tier must not cause software to pretend that hardware enforcement exists.

### SEC-UPD — Security maintenance and vulnerability response

Required:

- Android Security Bulletin intake;
- kernel and vendor/firmware vulnerability tracking;
- browser/WebView/updatable-module currency;
- Sable/Rust/native dependency advisory review;
- applicability state recorded as patched/not-affected/mitigated/vendor-unavailable/unknown;
- honest security-patch-level claims.

### SEC-SUPPLY — Software supply chain

Required:

- pinned source/commit provenance for release inputs;
- artifact hashes/manifests for critical outputs;
- auditable patch queue instead of silent source rewriting;
- dependency/toolchain inventory;
- reproducible or independently repeatable build procedure where practical;
- offline-capable/pinned dependency inputs where practical;
- build provenance evidence modeled toward SLSA-style attestable provenance;
- no unreviewed network-fetched code entering a production build.

### PRIV-DATA — Data minimization and retention

Required baseline:

- collect/process only data required for the stated local or user-requested function;
- prefer on-device processing when remote processing is not necessary;
- do not retain sensitive data longer than the feature requires;
- document persistent stores containing sensitive/user-linked data;
- deletion/reset behavior must be defined;
- compatibility components do not inherit unrelated user data.

### PRIV-NET — Network privacy and egress accountability

Required baseline:

- every Sable-owned component with network access has a documented reason;
- production images maintain an inventory of expected Sable-owned network destinations or destination classes;
- no mandatory Sable telemetry/analytics channel by default;
- diagnostics/crash upload is opt-in unless an explicit future policy defines a narrowly justified exception;
- disabled network capability must be tested semantically, including indirect service-mediated paths where applicable;
- cleartext transport is rejected unless specifically justified for a local/protocol requirement.

### PRIV-ID — Identifier discipline

Required baseline:

- avoid persistent device/user identifiers when a feature can work without them;
- do not create a Sable global advertising/tracking identifier;
- use scoped/rotating identifiers where an identifier is technically necessary and compatible with the protocol;
- hardware/attestation identifiers are exposed only through the narrow platform policy that requires them;
- logs and telemetry must not casually include stable identifiers.

### PRIV-CONSENT — User control and understandable authority

Required baseline:

- preserve Android runtime permission/AppOps enforcement;
- sensitive access is contextual and revocable where Android supports it;
- Sable UI reflects real enforcement state rather than cosmetic toggles;
- high-authority compatibility components are optional where feasible;
- security/privacy-sensitive update deltas should be surfaced when Sable implements package intelligence.

### PRIV-LOG — Logging and diagnostics

Required baseline:

- production logs avoid secrets and unnecessary personal data;
- verbose/debug logging is not permanently enabled without reason;
- diagnostic bundles are user-initiated or explicitly authorized;
- retention is bounded;
- crash/security evidence is useful without becoming a tracking channel.

### APP-SEC — Application ecosystem security

Required baseline:

- preserve standard Android APK/ART/PackageManager sandbox semantics;
- alternate installers cannot bypass platform enforcement;
- preinstalled Sable applications use minimum permissions/privileges;
- compatibility hardening exceptions are app-scoped where practical;
- application-security validation may cross-check OWASP MASVS concepts without requiring Sable-specific APK packaging.

## Hardware security capability record

Each device port maintains a hardware capability record using the canonical state model defined in `HARDWARE_SECURITY_CAPABILITIES.md`.

At minimum evaluate, when applicable:

```text
MTE
PAC
BTI
TBI_TAGGED_POINTERS
TEE
KEYMINT
STRONGBOX
HW_ROOT_OF_TRUST
KEY_ATTESTATION
KEY_ROLLBACK_RESISTANCE
RPMB_OR_REPLAY_PROTECTED_STORAGE
SECURE_PROCESSOR
AVB_VERIFIED_BOOT
BOOT_ROLLBACK_PROTECTION
IOMMU_OR_DMA_ISOLATION
REMOTE_KEY_PROVISIONING
```

The list is extensible. An unsupported optional capability is not a failed portable baseline control.

## Privacy inventory for shipped Sable components

Every Sable-owned privileged service, preinstalled application and compatibility component should have a bounded privacy record:

```text
component=
data_classes_read=
data_classes_written=
persistent_storage=
retention=
network_access=YES|NO
network_purpose=
expected_destinations=
identifiers_used=
sensors_used=
privileged_permissions=
user_control=
delete_reset_behavior=
```

`NONE` and `NOT_APPLICABLE` are explicit values. Empty/unknown fields are not acceptable for a production privacy claim.

## Release evidence record

A security/privacy-qualified release should be able to emit a machine-readable or line-oriented summary such as:

```text
SABLEOS_ASSURANCE_STAGE=PRODUCTION
SABLEOS_SELINUX=ENFORCING
SABLEOS_AVB=VERIFIED
SABLEOS_BOOTLOADER_STATE=LOCKED
SABLEOS_SECURITY_PATCH_LEVEL_STATUS=VERIFIED
SABLEOS_UNRESOLVED_CRITICAL_SECURITY_RISKS=0
SABLEOS_UNEXPLAINED_SABLE_NETWORK_EGRESS=0
SABLEOS_MANDATORY_TELEMETRY=NO
SABLEOS_PRIVACY_INVENTORY=PASS
SABLEOS_HWSEC_CAPABILITY_RECORD=PASS
SABLEOS_SUPPLY_CHAIN_PROVENANCE=PASS
SABLEOS_UPDATE_RECOVERY=PASS
```

Hardware-dependent feature claims are reported separately, for example:

```text
SABLEOS_HWSEC_MTE_AVAILABLE=NO
SABLEOS_HWSEC_MTE_ENABLED=NOT_APPLICABLE
SABLEOS_HWSEC_MTE_VALIDATED=NOT_APPLICABLE

SABLEOS_HWSEC_PAC_AVAILABLE=YES
SABLEOS_HWSEC_PAC_ENABLED=YES
SABLEOS_HWSEC_PAC_VALIDATED=PASS
```

## Privacy defaults

Unless a later explicit product policy says otherwise, SableOS defaults are:

```text
mandatory Sable telemetry          = NO
mandatory Sable analytics          = NO
personalized advertising ID        = NO
remote diagnostics upload          = OPT_IN
local diagnostic collection        = USER_INITIATED_OR_BOUNDED_SYSTEM_SECURITY_NEED
preinstalled Sable network access  = DENY_UNLESS_FEATURE_REQUIRES
persistent identifiers             = DENY_UNLESS_PROTOCOL/SECURITY_REQUIRES
```

This does not mean the operating system never communicates over the network. Networking, update checks, time synchronization, captive-portal behavior, emergency/carrier services, user applications and optional compatibility services may legitimately communicate. The requirement is that Sable-owned behavior is intentional, documented and testable, and that third-party/vendor behavior is classified rather than falsely represented as Sable telemetry.

## Exception rule

Any exception to a mandatory baseline control must record:

- control ID;
- affected device/component/build;
- technical reason;
- scope;
- compensating control if any;
- expiry/review condition;
- validation evidence.

Hardware absence for a capability-dependent control is **not** an exception; it is `NOT_APPLICABLE`.

## Change control

A hardware-dependent feature becomes a universal SableOS admission requirement only through an explicit policy/ADR change.

A new mandatory telemetry/data collection behavior likewise requires explicit privacy-policy review and documentation; it must not enter through an inherited upstream default, vendor package, build flag or convenience diagnostic.

The objective is a consistent security/privacy contract across heterogeneous hardware: the common baseline remains strong and portable, while every device uses additional hardware protection it can actually provide.