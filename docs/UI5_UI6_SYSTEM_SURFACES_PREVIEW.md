# UI5/UI6 system surfaces preview

Status: **preview implementation**

Tracking: GitHub issue #38

## Purpose

Resume the SableOS system UI refresh after the standalone-app and Media tranches
without mutating the Android platform tree before the visual contract is
approved.

UI4 already owns the source-qualified Quick Settings, notification shade and
SystemUI media visual delta. This preview therefore concentrates on the
remaining system-owned surfaces:

1. Settings home
2. Applications list
3. Application Security & Privacy detail
4. SetupWizard welcome
5. SetupWizard finish
6. About SableOS / branding
7. Lockscreen visual baseline

## Preview boundary

The Android Studio module is:

```text
apps/r8/android/system-preview
```

It is a standalone design-review APK. It does **not** replace or modify:

- AOSP / GrapheneOS Settings;
- SetupWizard2;
- PermissionController;
- PackageManager;
- AppOps;
- SystemUI;
- Keyguard authentication;
- lockscreen security behavior.

The application-security screens use explicit sample data and must remain
visibly marked as preview evidence. Production UI must source state from
qualified Android platform services and preserve the evidence classes defined
in `APPLICATION_SECURITY_PRIVACY_TRANSPARENCY.md`.

## Product direction

The preview follows the shared Sable contract:

- dark color-phone baseline;
- Metro / Modern UI influence;
- large typography and whitespace;
- restrained 6dp-or-less surface geometry;
- 48dp minimum interactive targets;
- Sable Blue for active state;
- app names, not package names, in normal list context;
- concise effective-sensitive-access summary beneath each app;
- advanced package identifiers and evidence in the per-app detail surface.

## Application Security & Privacy preview

The preview demonstrates the intended information hierarchy only:

```text
Applications
  -> app label
  -> concise effective-sensitive-access summary
  -> Application Security & Privacy
       -> identity & provenance
       -> effective authority
       -> components / attack surface
       -> libraries & privacy signals
       -> data / network / background
       -> security & privacy history
```

Evidence labels shown in the preview include:

```text
DECLARED
ENFORCED
OBSERVED
INFERRED
UNKNOWN
```

No preview datum is production evidence.

## SetupWizard / branding preview

The welcome and finish surfaces establish:

- SableOS naming and iconography;
- dark Sable visual language;
- privacy/security-oriented copy without unsupported guarantees;
- accessibility entry during setup;
- a finish summary that does not imply cloud/account enrollment.

Production implementation will remain bounded to the pinned SetupWizard2,
Settings and framework source revisions already used by the branding
applicator unless an expanded source ledger is reviewed first.

## Lockscreen preview

The lockscreen surface is visual-only. Authentication, biometric, credential,
notification-redaction, emergency-call and trust behavior remain upstream
until separately qualified.

## Review command

From `apps/r8/android`:

```bash
./gradlew :system-preview:assembleDebug
```

Install and launch:

```bash
adb install -r system-preview/build/outputs/apk/debug/system-preview-debug.apk
adb shell am force-stop org.sableos.system.preview
adb shell am start -W \
  -n org.sableos.system.preview/.SystemSurfacesPreviewActivity
```

The bottom review navigator exposes all seven surfaces.

## UI5R1 correction pass

The review pass after the first seven-screen capture adds:

- live device-local clock/date in the lockscreen preview;
- a swipe-up unlock affordance instead of a fake unlock button;
- an Application Security & Privacy control strip for Permissions, Network,
  Notifications and standard App Info entry points;
- explicit copy that preview controls do not replace Android enforcement;
- the canonical SableOS branding asset remains a production wiring concern and
  is not duplicated into this preview module.

## Production handoff after visual approval

```text
UI5A  Settings home + Applications list
UI5B  Application Security & Privacy detail and evidence wiring
UI5C+UI6  combined final production tranche:
          SetupWizard + About/branding
          Lockscreen / Keyguard visual refresh
          remaining SystemUI/accessibility/motion acceptance
```

Each production tranche must retain fail-closed source binding and must not
weaken Android security behavior merely to simplify presentation.


## Combined final production decision

UI5C and UI6 are implemented as one final production tranche on
`ui/ui5c-setupwizard-about-branding-production-20260919`.

See `docs/UI5C_UI6_FINAL_SYSTEM_SURFACES.md`. The branch name is retained to
avoid checkout churn; scope is explicitly broadened to include UI6. A full
Panther build follows only after the combined incremental SetupWizard / Settings
/ SystemUI qualification gates pass.
