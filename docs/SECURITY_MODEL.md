# SableOS Security Model

## Core Rule

> A component receives only the authority required for its narrow responsibility.

User-facing importance does not imply system privilege.

SableOS security and privacy claims are governed by `SECURITY_PRIVACY_ASSURANCE_STANDARD.md`. The security model defines trust boundaries; the assurance standard defines the common control families, privacy defaults, evidence states and development/release/production gates used to prove them.

## UI / Shell

Treat the UI as high-exposure code because it handles rendering, user input, apps, notifications, and external data.

It must not own:

- raw battery sysfs;
- Health HAL handles;
- generic network-administration capability;
- unrestricted service-manager discovery;
- arbitrary privileged command execution.

## Sable Platform Daemons

Privileged daemons should:

- own one policy/domain;
- expose typed operations;
- validate inputs;
- avoid generic command execution;
- avoid exposing backend handles;
- remain useful without UI availability.

## IPC Policy

Prefer stable typed IPC.

Good:

```text
PowerSnapshot getLatestState()
```

Potentially good future operation:

```text
setPowerSaveMode(boolean enabled)
```

if a dedicated service owns and validates it.

Avoid:

```text
execute(String command)
writeSysfs(String path, String value)
runTool(String binary, String args)
```

## Service-manager Policy

Each Binder service gets:

- a dedicated service-manager type;
- provider registration restricted to its owner;
- intended-client `find` and Binder-call authority kept explicit and narrow;
- negative tests based on effective compiled/runtime policy, including attribute-based platform grants.

Android platform policy may grant broad service-name discovery to development domains such as `shell`. Discovery alone is not authority. For Sable services, the security invariant is that an unauthorized domain cannot transact with or use the API even when platform policy permits discovering the service name.

## Capability Policy

Broad Linux file capabilities are not the default Sable design.

Especially avoid granting capabilities to general-purpose tools just so a UI can indirectly exercise broad authority.

Use:

```text
UI -> typed Sable service -> validated privileged action
```

## Hardware Security Capability Policy

SableOS separates its portable security baseline from hardware-specific enhancements.

MTE, PAC, BTI, StrongBox, secure processors and similar hardware features are **capability-dependent hardening**, not universal device-admission, build-success or production-eligibility requirements.

A target without one of these features remains eligible when its mandatory security/privacy/platform gates pass. Build and validation scripts classify absent optional hardware as `NOT_APPLICABLE`, not `FAIL`.

When a hardware capability exists, SableOS should preserve/enable it where compatible and must validate the effective configuration before claiming the protection is active.

The canonical capability registry and state model are defined in `HARDWARE_SECURITY_CAPABILITIES.md`.

## Privacy architecture

Privacy is enforced at the same architectural boundaries as security rather than being left only to application UI.

Default Sable policy:

- no mandatory Sable telemetry or analytics channel;
- remote diagnostics are opt-in unless a future explicit policy authorizes a narrowly justified exception;
- Sable-owned network access is denied unless the feature requires it;
- persistent identifiers are avoided unless a protocol/security function requires them;
- local processing is preferred when remote processing is unnecessary;
- sensitive persistent storage and retention are documented;
- compatibility components do not inherit unrelated user data or privilege;
- UI privacy controls must reflect real Android/SELinux/AppOps/network enforcement rather than cosmetic state.

Every shipped Sable-owned privileged service, preinstalled application and compatibility component should have the bounded privacy/data-flow record defined by `SECURITY_PRIVACY_ASSURANCE_STANDARD.md`.

## Sysfs Policy

For bramble power:

```text
vendor Health HAL -> battery sysfs
oxynoded -> Health HAL
clients -> Sable AIDL
```

Neither `oxynoded` nor its clients require direct battery sysfs access.

## Backend Isolation

Public contracts must not expose:

- HIDL/AIDL backend choice;
- sysfs paths;
- vendor enum quirks;
- HAL lifecycle details.

## Failure Isolation

- monitoring continues if optional IPC publication fails;
- UI failure does not stop Health consumption;
- client crashes do not alter daemon state;
- HAL failure triggers bounded daemon recovery.

## State Authenticity

Power flow:

1. callback enters compatibility bridge;
2. state converts to Sable semantics;
3. invalid level/status is rejected;
4. `PowerMonitor` determines event semantics;
5. latest validated state is published.

## Queue Bounds

Event paths must be bounded. The callback bridge uses a bounded snapshot queue and may drop the oldest item on overflow rather than allow unbounded memory growth.

Do not describe a bounded queue as mathematically lossless.

## Logging

Production logs should:

- identify lifecycle;
- expose bounded state transitions;
- suppress unchanged spam;
- report first error and recovery;
- avoid secrets and unnecessary personal data;
- avoid stable identifiers unless required for the diagnostic purpose;
- use Android platform logging;
- keep verbose/debug collection bounded and deliberate.

## Build / Supply Chain

Production-oriented procedure should avoid:

- unpinned source heads;
- untrusted package installation;
- throwaway release signing;
- personal Wi-Fi credentials in release images;
- embedded personal SSH access;
- password helper files;
- disabled tests for privileged core components without explicit exception;
- unreviewed network-fetched build dependencies;
- claims of provenance that are not backed by hashes/manifests/repeatable build evidence.

Build configuration must also avoid importing hardware requirements from a reference project as unconditional SableOS requirements. Capability-dependent protections belong behind capability checks and must not block targets solely because the optional hardware feature is absent.

Supply-chain evidence should move toward the provenance model in `SECURITY_PRIVACY_ASSURANCE_STANDARD.md` and `SECURITY_MAINTENANCE.md`.

## Negative Security Tests

For new services prove:

- effective service-manager discovery matches platform policy and is not confused with transaction authority;
- unauthorized domains cannot Binder-call or use the API;
- unauthorized shell cannot trigger a privileged dedicated test/client service;
- intended clients have no backend permission beyond the typed Sable API;
- service registration remains restricted to the provider;
- malformed inputs cannot widen privilege;
- runtime remains enforcing, and expected negative-test AVCs are distinguished from unexpected denials.

For network/privacy controls also prove, where relevant:

- a component classified as network-denied cannot communicate through direct or meaningful indirect OS-mediated paths;
- disabled telemetry/diagnostics do not continue network submission;
- privacy UI state matches actual enforcement;
- reset/delete operations remove the data the product claims they remove.

S1.7 is the reference service-boundary example: Android 14 shell can discover `sable_power_service` through a broad `service_manager_type` `find` grant, but Binder `call` from `u:r:shell:s0` to `u:r:oxynoded:s0` is denied while `sable_power_test_client` succeeds.

## Recovery

Do not disable SELinux, verified boot, authorization checks or privacy controls as a normal recovery mechanism. Prefer A/B rollback and narrow diagnostic exceptions.
