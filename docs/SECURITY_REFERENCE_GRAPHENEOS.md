# GrapheneOS security reference and SableOS delta review

## Purpose

GrapheneOS is a primary security-engineering reference for SableOS alongside AOSP itself.

SableOS does **not** aim to become a GrapheneOS fork, copy GrapheneOS product architecture, or imply endorsement or affiliation. GrapheneOS is fundamentally a hardened Android-compatible operating system. SableOS has a different long-term product architecture: a Rust-first service layer, narrow semantic APIs, multiple hardware adapters, multiple interaction profiles, and a Sable-owned shell/UI.

The goal is to learn from GrapheneOS security engineering methods and evaluate them deliberately against SableOS requirements.

The operating rule is:

> Learn from proven security engineering; preserve SableOS architecture.

## Why GrapheneOS is relevant

GrapheneOS provides several lessons that align closely with existing SableOS principles:

1. **Strengthen Android security boundaries instead of casually bypassing them.**
   Android already provides strong primitives such as process isolation, SELinux, verified boot, hardware-backed key handling, permissions, profiles, Binder isolation, and sandboxing. These are better starting points for hardening than replacing mature security mechanisms without evidence.

2. **Attack-surface reduction is an explicit engineering objective.**
   Security work should reduce unnecessary privilege, native memory-unsafe exposure, debugging surfaces, dynamic-code opportunities, ambient authority, legacy protocols, and unnecessary background/network capability.

3. **Compatibility must not automatically imply privilege.**
   GrapheneOS's sandboxed Google Play compatibility model demonstrates a useful general principle: compatibility software should work with ordinary sandboxing and explicit grants wherever possible instead of being made trusted merely because existing ecosystems expect it.

4. **Capabilities should have meaningful security semantics.**
   A user-visible control should correspond to a real enforcement boundary. GrapheneOS's Network permission is an important example: denial is designed to prevent both direct socket access and indirect network use through cooperating OS components rather than acting as a cosmetic firewall switch.

5. **Hardware and firmware support impose a security ceiling.**
   Kernel, firmware, drivers, secure elements, boot firmware, radios, vendor code, and OEM support lifetime are part of the security model. Userspace hardening cannot fully compensate for unsupported closed firmware.

6. **Verified boot, signing, rollback protection and attestation are product security features.**
   A development image with an unlocked bootloader is not a production security posture. SableOS must eventually own its signing/release process and define a verifiable locked-device deployment model on hardware that supports it.

7. **Security maintenance is continuous.**
   Hardening is not a one-time audit. It requires continuous Android security updates, kernel/vendor/firmware tracking, browser/WebView updates, regression testing, vulnerability triage, and explicit device-lifecycle decisions.

## Where SableOS deliberately differs

GrapheneOS remains Android as the primary application and user-interface environment. SableOS does not have that product goal.

SableOS intends to own:

- the primary shell and interaction model;
- common semantic service APIs;
- Sable-native applications;
- capability/policy presentation;
- touch-first and keyboard-first interaction profiles;
- a Rust-first common userspace service layer.

SableOS intends to preserve proven Android/vendor substrate where it remains the safest and most compatible implementation, including HAL infrastructure, radio/IMS, graphics, camera, audio, power/thermal, verified boot, keystore/key hardware, update machinery and other mature platform capability.

Therefore GrapheneOS patches or features are **not** imported wholesale. Each idea must be evaluated against the Sable architecture, target Android baseline and actual device hardware.

## Security-reference decision process

For every GrapheneOS security feature or design, evaluate:

```text
What threat does it address?
        ↓
Does the selected AOSP baseline already contain equivalent protection?
        ↓
Does the target hardware/firmware support it?
        ↓
Does it fit the Sable trust/service architecture?
        ↓
Can Sable test and maintain it independently?
        ↓
Adopt / adapt / defer / reject with documented reason
```

Every reviewed item receives one classification:

- **ALREADY_UPSTREAM** — equivalent protection exists in the selected AOSP baseline.
- **ADOPT** — use substantially the same security mechanism because it fits Sable directly.
- **ADAPT_FOR_SABLE** — preserve the security property but implement it through Sable APIs/services or a different integration model.
- **HARDWARE_UNAVAILABLE** — target hardware/firmware cannot provide the required property.
- **NOT_RELEVANT** — the feature solves a problem outside the Sable product architecture.
- **DEFER** — useful, but blocked by milestone, hardware, maintenance or validation requirements.

A classification is not permanent. A later Android release or hardware target may change it.

## S0 GrapheneOS security delta categories

S0 includes a structured security-delta review across at least these categories.

### 1. Memory safety and exploit mitigation

Review:

- hardened allocator strategy;
- memory tagging where hardware supports it;
- pointer authentication / branch target protection;
- native debugging restrictions;
- process spawning/isolation hardening;
- compiler and linker exploit mitigations;
- reduction or containment of memory-unsafe privileged code.

Sable-specific direction:

- prefer Rust for new Sable userspace components;
- do not assume Rust removes risk in retained C/C++ platform/vendor code;
- use hardware/compiler mitigations independently of implementation language.

### 2. App and process sandboxing

Review:

- app sandbox boundaries;
- user/profile isolation;
- privileged-app reduction;
- compatibility-layer isolation;
- IPC exposure;
- filesystem/data scopes;
- service-manager and Binder reachability.

Sable-specific direction:

- the Sable shell must not become a privileged universal client;
- privileged operations stay behind narrow semantic services;
- compatibility components receive explicit minimal access.

### 3. Network and sensor capability controls

Review:

- meaningful per-app network denial;
- indirect network access paths;
- sensor controls;
- location/scanning behavior;
- background-network behavior;
- local-vs-network service choices.

Sable-specific direction:

- capability controls should describe user/security semantics, not implementation details;
- revocation should be enforced at the narrowest reliable system boundary.

### 4. USB and debugging attack surface

Review:

- USB data controls;
- debugging availability on locked devices;
- ADB policy;
- recovery/fastboot attack surface;
- hardware-assisted USB restriction on capable devices;
- memory clearing/reset behavior around firmware boot modes.

### 5. Verified boot, signing and attestation

Review:

- AVB integrity;
- rollback protection;
- release-key ownership;
- locked-bootloader deployment;
- hardware-backed attestation;
- recovery/update trust chain;
- downgrade resistance.

Development unlock state must never be presented as production security.

### 6. Kernel hardening

Review:

- GKI/LTS status;
- kernel patch cadence;
- attack-surface reduction;
- device-specific kernel/driver exposure;
- SELinux interactions;
- hardware mitigation support;
- vulnerability/CVE backlog.

### 7. Browser and WebView security

Review:

- Chromium/WebView update cadence;
- sandboxing;
- exploit mitigations;
- JIT/dynamic-code exposure;
- isolation from privileged Sable components.

A browser is high-risk input-processing code and must not inherit Sable service privilege.

### 8. Update and rollback security

Review:

- A/B/virtual A/B mechanisms available on each target;
- update signature validation;
- rollback indices;
- interrupted-update recovery;
- reproducibility/traceability of release inputs;
- emergency security-update process.

### 9. Radio/baseband exposure reduction

Review:

- retention of vendor-supported Radio HAL/RIL/IMS path;
- legacy radio-mode exposure where configurable;
- unnecessary userspace reachability to radio services;
- modem/device-node/socket isolation;
- carrier/IMS capability regression risk.

SableOS must not implement raw modem protocols as a hardening shortcut.

### 10. Device lifecycle and security ceiling

Review:

- OEM firmware support;
- vendor patch availability;
- kernel support lifetime;
- secure-element support;
- hardware exploit mitigations;
- bootloader/relock capability;
- availability of complete security fixes.

A device that can boot SableOS is not automatically a device suitable for secure SableOS production use.

## The bramble security ceiling

Pixel 4a (5G), codename `bramble`, is a valuable architecture and regression device, but it is end-of-life hardware.

GrapheneOS explicitly lists Pixel 4a (5G) as end-of-life and no longer supported. GrapheneOS also states that full device security maintenance depends on active OEM maintenance of firmware, kernel/vendor code and other device support components.

SableOS therefore uses bramble under the following rule:

> Android 14 bramble is a controlled development/reference substrate, not evidence of indefinite production security.

Moving the bramble baseline from Android 12.1 to its final official Android 14 AOSP baseline materially improves the development substrate and reduces known age of the platform layer. It does **not** eliminate the closed-firmware/vendor EOL ceiling.

Future production-security claims require hardware with an active firmware/vendor support lifecycle and appropriate modern security features.

## Lesson from B2: neverallow is an architectural signal

The B2 power-service work exposed a useful concrete security lesson.

The first attempted design placed `sable-powerd` in a platform `coredomain` and tried to read `sysfs_batteryinfo`. Once the Sable policy directory was genuinely compiled, Android's SELinux `neverallow` rejected that architecture.

SableOS did **not** disable or patch around the `neverallow`.

Instead, the service boundary was redesigned so the privileged physical backend belonged on the vendor side, with `oxynoded` remaining isolated from raw sysfs access.

This becomes a standing Sable rule:

> Platform security boundaries are design constraints to understand first, not obstacles to disable for convenience.

An AVC or `neverallow` failure must trigger threat/boundary analysis before any permission expansion.

## Compatibility without ambient trust

The architectural lesson from GrapheneOS sandboxed Google Play is broader than Google Play itself.

SableOS compatibility policy is:

```text
compatibility requirement
        ↓
ordinary sandbox if possible
        ↓
explicit capability grants
        ↓
narrow compatibility broker only where necessary
        ↓
no unrelated ambient system privilege
```

Examples include future Android application compatibility, automotive/projection integration, cloud-provider components, push-notification compatibility or account-provider integrations.

A component being popular or ecosystem-critical is not sufficient reason to make it privileged.

## Relationship to the Sable capability model

GrapheneOS's Network permission reinforces the Sable direction toward semantic capabilities.

Future Sable policy should prefer concepts such as:

```text
network.internet
network.local
location.precise
location.approximate
sensors.motion
camera.capture
microphone.capture
telephony.call
telephony.sms
storage.user_files
background.execution
```

over controls that merely expose kernel/Android implementation details.

The exact capability vocabulary remains to be designed and tested. The security requirement is that UI-visible policy maps to enforceable system behavior.

## Adoption discipline

SableOS will not copy GrapheneOS code or patches merely because they are security-related.

Before adoption, record:

- upstream project/commit or design reference;
- threat addressed;
- selected AOSP status;
- target-device hardware dependencies;
- Sable integration point;
- additional privilege or attack surface introduced;
- tests proving the desired property;
- maintenance/update burden;
- adoption classification.

Security features that cannot be validated should not be represented as active protection.

## S0 relationship

The current S0 security-baseline uplift uses Android 14 on bramble to establish a cleaner, final official AOSP substrate before Sable components are ported back.

The sequence is intentionally:

```text
vanilla Android 14 baseline
        ↓
validate build + physical hardware capability
        ↓
restore Sable components incrementally
        ↓
re-derive Android 14 privilege/partition policy
        ↓
run GrapheneOS/AOSP security delta review
        ↓
apply justified hardening with regression gates
```

Do not mix security-hardening imports into the vanilla baseline gate. The baseline must first prove what unmodified tagged AOSP plus matching official device binaries provides.

## Primary references

Official GrapheneOS documentation used as security-design references:

- FAQ / device support / lifecycle / security: https://grapheneos.org/faq
- Usage guide / exploit protection / sandboxed Google Play: https://grapheneos.org/usage
- Releases / current hardening and maintenance activity: https://grapheneos.org/releases

AOSP remains the normative reference for Android platform architecture, SELinux policy, build behavior and device integration. GrapheneOS is an additional security-engineering reference, not a replacement for upstream Android documentation.
