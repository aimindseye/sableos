# SableOS Android application security and compatibility

## Purpose

SableOS must improve application security without creating a closed or Sable-specific application ecosystem.

The standing compatibility rule is:

> Standard Android applications remain standard Android applications. SableOS adds inspection, policy and containment around the Android application model rather than replacing the APK format, ART runtime, PackageManager or ordinary app sandbox.

This document defines the application compatibility target and the planned Secure Package Intelligence workstream.

## Compatibility objective

SableOS should preserve the mature AOSP application substrate, including:

- standard APK and split-APK packaging;
- APK signature verification and signing lineage;
- PackageInstaller / PackageManager installation semantics;
- ART / DEX execution;
- Binder application IPC semantics;
- Android UID sandboxing and SELinux app domains;
- Android runtime permissions and PermissionController;
- AppOps enforcement;
- Storage Access Framework and scoped-storage behavior;
- standard intent, activity, service, provider and broadcast semantics;
- WebView and browser-facing Android APIs;
- ordinary user/profile isolation.

SableOS security features must not require developers to produce a Sable-specific APK or repackage a normal Android application.

The practical target is that an APK which is compatible with the selected Android API/device ABI should install and run on SableOS unless one of the following applies:

1. the application explicitly depends on proprietary services not installed by the user;
2. the application depends on privileged OEM/system integration unavailable on SableOS;
3. the application performs device/OS integrity checks and chooses to reject SableOS;
4. SableOS intentionally blocks behavior that violates an explicit security policy;
5. a Sable hardening feature exposes an application bug and the user has not enabled a narrowly scoped compatibility exception.

## App source is not the trust boundary

SableOS should accept applications through standard Android installation paths from multiple sources, including:

- F-Droid and compatible repositories/clients;
- Google Play Store when an optional sandboxed Google compatibility layer is installed;
- other user-authorized Android stores;
- direct APK/split-APK installation;
- development/ADB installation when developer mode explicitly permits it.

The installer source may provide provenance and update information, but SableOS must not equate a store with system privilege.

The policy is:

```text
application source
        ↓
standard Android package verification
        ↓
Sable local security analysis
        ↓
user/security-policy review when required
        ↓
ordinary Android app sandbox
```

All sources should ultimately converge on the standard package-management enforcement path so that alternate installers cannot bypass Sable security review merely by using a different UI.

## Optional Google Play compatibility

SableOS should not require or bundle proprietary Google applications as trusted OS components.

A future Google compatibility option should follow the compatibility-without-ambient-trust rule already adopted by SableOS:

- Google Play services and Play Store are optional and user installed;
- they run as ordinary sandboxed applications rather than privileged system applications wherever technically possible;
- they receive only ordinary Android permissions/capabilities explicitly granted by the user;
- only applications in an allowed user/profile context can interact with them through normal application mechanisms;
- Sable-owned OS services do not silently become dependent on Google Play;
- compatibility shims are narrow, documented and independently testable;
- functionality that inherently requires privileged Google/OEM integration may remain unavailable rather than granting broad trust.

This should be treated as a compatibility layer, not a Google-services substrate for SableOS itself.

Some applications may still reject SableOS because of Play Integrity, proprietary certification, DRM, banking anti-tamper policy or other application-controlled integrity checks. APK compatibility and application-vendor acceptance are separate problems and must be documented separately.

## Secure Package Intelligence

SableOS should perform local, explainable security analysis of an APK before installation and especially before a security-sensitive update.

The analyzer should consume package metadata already available to PackageManager plus bounded local static analysis where useful.

Initial signals should include:

- requested permissions and protection levels;
- permission additions/removals on update;
- signing certificate identity and signing-lineage changes;
- target/minimum SDK changes;
- exported activities, services, receivers and providers;
- newly exported components;
- components exported without an appropriate permission;
- accessibility services;
- notification listeners;
- VPN services;
- device-admin receivers;
- autofill/IME services;
- boot receivers and background-start surfaces;
- overlay / package-install / all-files / background-location style elevated capabilities;
- declared cleartext-network policy;
- debuggable/test-only package state;
- native-code presence;
- known tracker/analytics library signals from a locally maintained dataset;
- application-feature and component deltas between installed and incoming versions.

Tracker/library identification is a privacy/security signal, not proof of malicious behavior.

## Explainable findings, not opaque scores

SableOS should not initially present an AI-generated or opaque numeric trust score.

Findings should be deterministic and explainable, for example:

```text
NEW: Background location
Classification: Elevated
Reason: permits location access when the application is not in active use.
```

or:

```text
NEW: Accessibility service
Classification: Elevated
Reason: accessibility services can observe screen content and interact with other applications.
```

Suggested finding classes:

- **Informational** — useful context without an inherent security judgment;
- **Review** — security-relevant change the user should understand;
- **Elevated** — broad or sensitive authority requiring explicit review;
- **Critical** — signing identity conflict, blocked downgrade/integrity condition or similarly fundamental trust change;
- **Privacy signal** — known analytics/tracker/library presence without claiming malicious intent.

SableOS should say that a capability is unusual or sensitive when justified. It should not claim to know with certainty that a permission is "beyond the app's needs" because static analysis cannot reliably determine developer intent.

## Install-time versus runtime authorization

The install review and Android runtime-permission model solve different problems.

SableOS should normally preserve contextual runtime permission prompts rather than asking users to pre-grant camera, microphone, contacts or location during installation.

Secure Install should therefore:

1. show what authority the application declares or may later request;
2. highlight unusual/elevated capabilities;
3. install ordinary dangerous/runtime permissions initially ungranted unless Android semantics require otherwise;
4. let PermissionController request sensitive access when the app actually uses the feature;
5. enrich runtime prompts with relevant install-time context where this can be done without confusing the Android permission model.

## Security-sensitive update review

Update deltas are more valuable than repeatedly showing a complete manifest.

SableOS should require explicit review when an update materially increases application authority. Examples include:

- new dangerous permissions;
- background location;
- new accessibility/VPN/device-admin/notification-listener functionality;
- new package-install or overlay capability;
- new exported unprotected components;
- significant target-SDK regression;
- significant new tracker/analytics surface;
- signing identity anomalies;
- downgrade or reinstall conditions with security implications.

A normal update with no meaningful security delta should remain low-friction.

## Permission and AppOps presentation

Android permissions and AppOps are separate enforcement mechanisms but should be understandable as one capability state in Sable UI.

Future UI should be able to express a capability such as location as:

```text
Manifest request: yes
Runtime permission: while in use
AppOp: foreground only
Background access: denied
Last use: <time if available>
```

The UI must reflect real enforcement, not merely present a cosmetic policy toggle.

## Scoped-data capabilities

High-value future work includes Sable equivalents of scoped compatibility controls for data classes where applications often request broad access:

- storage/file scopes;
- contact scopes;
- media scopes;
- local-network discovery scopes where technically enforceable;
- sensor scopes where Android/hardware semantics permit reliable enforcement.

The preferred model is to expose only explicitly selected data while preserving application compatibility where possible, rather than granting all-or-nothing access.

## Network capability

SableOS should evaluate a user-facing per-app Network capability which denies both direct socket access and meaningful indirect network paths through cooperating system services.

A packet-only firewall is not sufficient if an application can route work through an OS service that still has network access. The security property must be defined semantically and tested end-to-end.

## Install quarantine — later research

A later milestone may research an Install Quarantine state for untrusted or high-risk packages:

- package installed but not launchable;
- runtime permissions ungranted;
- no automatic background/boot execution;
- no special-access grants;
- user reviews Sable findings before release.

This requires careful PackageManager/ActivityManager design and is intentionally deferred until the core analyzer and ordinary install/update review are proven.

## App-source provenance and update ownership

SableOS should retain Android's installer-of-record / update-ownership semantics rather than creating a central store monopoly.

The system should record enough local provenance to answer:

- which installer installed the current version;
- package signing identity;
- version installed and update history;
- whether an update changed security-relevant manifest state;
- whether a user approved an elevated security delta.

Provenance must not become an unnecessary telemetry channel. Local records are preferred by default.

## Compatibility exception model

Hardening can expose application defects. SableOS should prefer per-application compatibility exceptions over globally weakening the OS.

Examples to evaluate include narrowly disabling a specific exploit mitigation or compatibility restriction for one application while clearly displaying the reduced protection.

Compatibility exceptions must be:

- opt-in;
- per application where practical;
- reversible;
- visible in application security settings;
- excluded from privileged Sable services unless explicitly justified;
- covered by regression tests.

## App Manager reference

MuntashirAkon/AppManager is a useful design reference for application inspection. Relevant ideas include:

- displaying permissions and AppOps;
- inspecting signatures, manifest data and components;
- identifying tracker/library components;
- comparing permissions, signing certificates, components, SDK information and features across application updates;
- surfacing security-relevant package details before installation/update.

SableOS should learn from these concepts and independently implement them at appropriate AOSP/platform enforcement points rather than embedding App Manager as a privileged dependency or copying its GPLv3+ implementation into Apache-licensed AOSP components.

## Additional application-security recommendations

The app-security program should also include:

1. **Per-app network denial** with indirect-path testing.
2. **Storage and contact scopes** for compatibility-preserving least privilege.
3. **User/profile isolation** as a first-class way to partition trust domains and optional Google-dependent apps.
4. **Per-app exploit-protection compatibility mode** instead of globally weakening mitigations for incompatible apps.
5. **Browser/WebView rapid-update discipline** independent of long OS feature milestones.
6. **Application compatibility regression corpus** covering open-source apps, Play-dependent apps, banking/DRM edge cases, accessibility, VPN, notifications, media, camera, location and background execution.
7. **Local package provenance/history** for signing identity and security-delta auditability.
8. **No installer bypass path**: PackageManager-level enforcement must back the installer UI.

## Validation requirements

Secure Package Intelligence is not complete when a UI renders.

At minimum, tests must prove:

- ordinary Android APKs still install from multiple authorized sources;
- split APKs and updates continue to work;
- unchanged updates remain low-friction;
- sensitive update deltas are detected reliably;
- alternate installers cannot bypass mandatory review;
- denied runtime permissions remain denied after installation;
- AppOps state matches displayed capability state;
- signing lineage and signature mismatch cases are handled correctly;
- compatibility exceptions are app-scoped;
- vanilla AOSP behavior is not unintentionally weakened for unrelated packages;
- Google compatibility components, if implemented, remain ordinary sandboxed applications absent explicit narrow exceptions.
