# SableOS Application Security and Privacy Transparency

Status: **normative application-transparency design policy**.

This document extends `APP_SECURITY_AND_COMPATIBILITY.md` from install/update-time Secure Package Intelligence into ongoing, user-visible application security and privacy transparency.

SableOS uses MuntashirAkon/AppManager as a design reference for rich package inspection, while independently implementing appropriate concepts at Android/AOSP enforcement and observation points. SableOS does **not** adopt App Manager's root/ADB privilege model as the platform trust model and does not require a single super-privileged package-management application.

## Core rule

> SableOS should make an application's effective authority, exposed surfaces, data use, network behavior and security-relevant history understandable without weakening Android's sandbox or granting broad ambient privilege to the UI.

Transparency must distinguish:

- what an application **declares**;
- what the OS has **granted or allowed**;
- what the application has **actually used or done** when trustworthy local evidence exists;
- what SableOS has **inferred** from static/local analysis;
- what remains **unknown**.

A declaration must not be presented as observed behavior, and observed behavior must not be inferred merely from a manifest permission.

## Relationship to Secure Package Intelligence

Secure Package Intelligence answers:

```text
Should this package/version be installed or updated?
What security-relevant authority changed?
```

Application Security & Privacy Transparency answers:

```text
What can this installed application do now?
What platform authority does it effectively have?
What has it used?
What data/network/background behavior is visible locally?
What changed over time?
```

Both should share the same package/signing/provenance model and must be backed by Android enforcement state rather than cosmetic UI state.

## Standard application transparency view

A future Sable application-security surface should organize information into these stable categories.

### 1. Identity and provenance

Display at least:

- package name;
- application label;
- installed version/version code;
- target/minimum SDK;
- installer of record / update owner where available;
- signing certificate identity;
- signing lineage/history;
- first-install and last-update timestamps where reliable;
- system/preinstalled/user-installed classification;
- debug/test-only state;
- supported ABI/native-code presence.

Security-sensitive identity changes must link to the update-security history rather than silently replacing old state.

### 2. Effective authority

Unify declared and enforced application authority without collapsing distinct Android mechanisms.

Display, where applicable:

- manifest permission request;
- runtime permission state;
- AppOps state;
- special access / role / admin-like authority;
- foreground/background limitation;
- user/profile scope;
- last-use information when Android exposes reliable evidence;
- compatibility exception state.

Example:

```text
Capability: Location
Manifest request: YES
Runtime permission: WHILE_IN_USE
AppOp: FOREGROUND_ONLY
Background access: DENIED
Last observed use: <time or UNKNOWN>
```

The user-visible state must correspond to real platform enforcement.

### 3. Component explorer and exposed attack surface

Provide a unified component inventory for:

- activities;
- services;
- broadcast receivers;
- content providers;
- instrumentation where relevant;
- accessibility services;
- notification listeners;
- VPN services;
- IME/autofill services;
- device-admin/device-policy receivers;
- boot receivers and other background-entry surfaces.

For each component expose, where meaningful:

```text
component_type=
component_name=
enabled=
exported=
required_permission=
intent_filters=
direct_boot_aware=
process=
```

Highlight security-relevant conditions such as:

- exported component without an appropriate permission;
- newly exported component after update;
- externally reachable privileged functionality;
- component enabled/disabled state changes.

SableOS may later support narrowly scoped component controls where Android can enforce them safely, but inspection does not imply that arbitrary component blocking must be exposed to users.

### 4. Code, libraries and trackers

Display locally derivable code/package characteristics, including:

- native code presence and ABI;
- packaged native libraries;
- declared/shared libraries where Android exposes them;
- dynamically loaded/code-loading indicators when reliably observable;
- known tracker/analytics library signals from a locally maintained dataset;
- major embedded SDK/library identifiers when detection quality is sufficient.

Tracker/library detection is a **privacy/security signal**, not proof of malicious behavior or proof that the detected code executed.

Distinguish:

```text
PACKAGED_OR_DETECTED
OBSERVED_LOADED
UNKNOWN
```

when the evidence source permits that distinction.

### 5. Storage and local data footprint

Expose locally available application storage information without crossing the sandbox unnecessarily.

Useful fields include:

- application/package size;
- user-data size where Android exposes it;
- cache size;
- external/media storage footprint where attributable;
- scoped-storage/media authority;
- all-files access state;
- persistent storage classes used by Sable-owned/preinstalled components where documented.

The transparency UI should not require privileged reading of another application's private files merely to calculate or display metadata already available through platform services.

### 6. Network capability and data use

Network transparency should separate **authority**, **usage**, and **destinations**.

Display where available:

```text
network_capability=ALLOWED|DENIED|UNKNOWN
mobile_data_usage=<bounded OS-reported value or UNKNOWN>
wifi_data_usage=<bounded OS-reported value or UNKNOWN>
background_data_policy=
vpn_relationship=
cleartext_policy=
```

SableOS should additionally research privacy-preserving local destination visibility, such as destination domains/classes where reliable attribution can be obtained without introducing a system-wide tracking service.

Rules:

- packet counters do not prove destination semantics;
- manifest Internet permission does not prove network activity;
- DNS observation alone does not prove a successful connection;
- destination history should be local by default;
- retention must be bounded and user-controllable;
- Sable must not upload per-app network history as mandatory telemetry.

Per-app network denial remains a separate enforcement feature and must cover meaningful indirect service-mediated paths before being represented as a complete network denial.

### 7. Background execution and resource behavior

Expose relevant Android background-execution state, including where available:

- running/foreground service state;
- recent background execution or process state;
- boot receiver presence;
- scheduled job/alarm surfaces where meaningful and safely attributable;
- battery-optimization / allowlist state;
- background-data restriction state;
- abnormal or sustained resource-use indicators when backed by reliable OS metrics.

Do not infer abusive behavior solely because an app is permitted to run in the background.

Resource transparency is diagnostic context, not an opaque risk score.

### 8. Security and privacy history

Maintain a bounded local history of security-relevant package changes.

Events should include, where applicable:

- install/update/remove;
- installer/update-owner change;
- signing identity/lineage change;
- new/removed permissions;
- runtime permission grants/revocations when feasible;
- AppOps changes when feasible;
- new exported components;
- new elevated component types such as accessibility/VPN/device admin;
- new tracker/library signals;
- target-SDK regression;
- compatibility exception enable/disable;
- material network or special-access policy changes.

History should answer:

```text
What changed?
When did it change?
Which package version introduced it?
Was user review required?
Was an elevated change explicitly approved?
```

Retention should be bounded and local by default.

## Observed versus declared evidence model

Every transparency datum should have an evidence class where ambiguity matters:

```text
DECLARED       # manifest/package metadata
ENFORCED       # effective OS permission/AppOp/policy state
OBSERVED       # locally observed runtime behavior from a trusted OS source
INFERRED       # bounded static/local analysis
UNKNOWN        # insufficient evidence
```

Examples:

```text
INTERNET permission = DECLARED
AppOps foreground location = ENFORCED
OS-reported recent microphone access = OBSERVED
embedded tracker class signature = INFERRED
remote endpoint purpose = UNKNOWN unless evidenced
```

SableOS should avoid language which turns `INFERRED` into `OBSERVED`.

## User actions and trust boundary

The transparency surface may request narrow policy changes through platform services, but presentation code must not become a generic privileged package manager.

Preferred:

```text
Sable application-security UI
        -> typed policy request
        -> narrow platform service / existing Android manager
        -> SELinux / PackageManager / AppOps / PermissionController enforcement
```

Rejected by default:

```text
UI -> root shell
UI -> generic command executor
UI -> arbitrary access to other apps' private data
UI -> unrestricted package/component mutation backend
```

Where Android already provides a secure Settings/PermissionController flow, Sable may deep-link or wrap the semantic operation instead of duplicating privilege.

## App Manager lessons adopted

The following App Manager concepts are explicitly useful to SableOS:

- dense but structured package information;
- permission and AppOps visibility;
- application component inventory;
- manifest/signature/package inspection;
- shared/embedded library visibility;
- tracker/library scanning as a signal;
- storage/data-usage visibility;
- application usage/background context;
- update-to-update comparison;
- making advanced package state inspectable instead of hiding it.

SableOS adapts these concepts by moving enforcement/observation to appropriate Android platform boundaries and by separating user-facing inspection from broad root/ADB authority.

## App Manager capabilities not adopted as the Sable trust model

App Manager also provides powerful root/ADB functions such as arbitrary component blocking, private-data inspection/editing, SSAID changes, broad file management, terminal access and other system-management operations.

These are not inherited as a single Sable application privilege set.

If SableOS needs equivalent user value, each operation must be evaluated independently for:

- legitimate product need;
- correct Android enforcement point;
- least-privilege API shape;
- SELinux boundary;
- negative authorization tests;
- compatibility impact;
- privacy consequences.

## Privacy requirements

Application transparency itself can become a privacy risk if implemented carelessly.

Therefore:

1. package/security history is local by default;
2. network-destination history is local and bounded by default;
3. no mandatory upload of installed-app inventory;
4. no mandatory upload of tracker/library findings;
5. no global Sable advertising/tracking identifier;
6. diagnostic export is user-initiated or explicitly authorized;
7. profiles/users remain separate trust/privacy domains;
8. another ordinary application cannot query the full Sable transparency database without an explicit narrow API and authorization model;
9. privileged transparency services expose only the minimum data required by their intended clients.

## Data quality and uncertainty

The UI must expose uncertainty rather than manufacture precision.

Use `UNKNOWN`, `NOT_AVAILABLE` or an equivalent state when Android/device APIs cannot support a reliable conclusion.

Examples:

- inability to attribute encrypted traffic to a domain must not be shown as "no network access";
- a detected library must not be shown as "tracker contacted" without runtime evidence;
- missing usage-access permission must not become zero usage;
- a stopped process does not imply the package never executes in background;
- storage metadata does not justify inspecting private user content.

## Validation requirements

Application Security & Privacy Transparency is not complete when the UI renders.

Validation must prove, where implemented:

- displayed package identity/signing data matches PackageManager/package parsing evidence;
- displayed permissions match effective PermissionController/PackageManager state;
- displayed AppOps match effective AppOps state;
- exported-component classification matches effective package metadata;
- library/tracker findings are reproducible from the documented local dataset/analyzer version;
- data-usage values match the selected Android accounting source;
- storage values match the selected Android storage-accounting source;
- network-denial UI corresponds to effective enforcement, including tested indirect paths where claimed;
- background-execution state does not overclaim beyond available Android evidence;
- update-history events correctly bind to package versions/signing identity;
- ordinary applications cannot read privileged transparency records;
- transparency databases/history are deleted or reset according to documented policy;
- collection remains local unless the user explicitly exports or enables a documented remote feature;
- compatibility with ordinary Android package install/update/runtime behavior is preserved.

## Initial implementation priority

Recommended order:

```text
1. identity + signing + installer provenance
2. permissions + AppOps + special access
3. component explorer / exported-surface audit
4. security-sensitive update history
5. libraries + tracker signals
6. storage + data-usage visibility
7. background/resource state
8. privacy-preserving network destination research
9. scoped enforcement controls only after observation is trustworthy
```

This ordering prioritizes reliable platform evidence before adding controls whose semantics are difficult to prove.

## Product outcome

The target is a first-class SableOS application transparency surface which can answer, without requiring root-style user applications:

```text
Who installed and signed this app?
What authority does it effectively have?
Which components are exposed?
What libraries/privacy signals are present?
How much local/network resource usage is visible?
What background privileges/state exist?
What security-relevant changes happened over time?
Which facts are declared, enforced, observed, inferred or unknown?
```

See `APP_SECURITY_AND_COMPATIBILITY.md` for install/update policy and `SECURITY_PRIVACY_ASSURANCE_STANDARD.md` for the project-wide security/privacy baseline.