# Panther D4 roadmap — Sable identity, default apps and functional acceptance

Date: 2026-09-07

Baseline: physically validated D3 on Pixel 7 (`panther`), Android 17 / GrapheneOS `2026081300` substrate.

D3 is closed. The current Sable source delta is reconstructable from GitHub, the D3 SYSTEM/PRODUCT/AVB/fs-verity residuals are causally classified, slot B booted successfully, and both slot A and slot B are bootloader-authoritatively known good.

D4 is deliberately broader than another branding-only iteration. It combines **Sable identity closure, Graphene user-facing default-app removal/dependency analysis, intentional default-app selection, and full phone functional acceptance** into one bounded milestone.

## D4 operating rules

The canonical Android/Pixel substrate remains GrapheneOS `2026081300`. Sable changes are bounded deltas on top.

For historical Sable work:

```text
needed + clean on current base       -> PORT
needed + incompatible old design     -> REDESIGN
obsolete workaround                  -> DROP
independent Sable project            -> RETAIN / ADAPT / INTEGRATE
```

Do not globally rename GrapheneOS internal package/API identifiers. Do not relabel Graphene-operated services, URLs or infrastructure as Sable until Sable owns a truthful replacement.

Important app-removal rule:

```text
REMOVE_USER_FACING_GRAPHENE_DEFAULTS
!=
REMOVE_GRAPHENE_PLATFORM_DEPENDENCIES
```

The Graphene Apps/app-store client and other Graphene-branded user-facing defaults are removal candidates, but they are not authorized for removal until D4-R0 closes their dependencies.

## D4-R0 — read-only baseline and provenance audit

**No source mutation. No build.**

D4-R0 must produce two outputs before any D4 source change:

1. an exact package/app removal and remaining-branding provenance plan;
2. a D3 pre-change physical functional baseline.

### Source/package inventory

Capture and classify:

- installed packages and their partitions/paths;
- relevant `PRODUCT_PACKAGES` / product inheritance provenance;
- `system`, `product`, `system_ext` app/priv-app contents;
- Graphene-branded or Graphene-provenance user-facing applications;
- default role holders: launcher/home, browser, dialer, SMS and other relevant roles;
- overlays targeting candidate applications;
- privileged-permission allowlists;
- SELinux references;
- package visibility/component references;
- SetupWizard and Settings dependencies;
- updater/update-client/update-server dependencies;
- Graphene Apps/app-store dependencies;
- WebView/browser relationships;
- remaining user-visible GrapheneOS strings.

Classify GrapheneOS references as:

```text
REBRAND_TO_SABLE
KEEP_TRUTHFUL_GRAPHENE_SERVICE_OWNERSHIP
KEEP_INTERNAL_IDENTIFIER
KEEP_FUNCTIONAL_URL
DEPRECATED_OR_DROP
REQUIRES_SABLE_SERVICE_BEFORE_REBRAND
```

Classify candidate applications/components as:

```text
KEEP_REQUIRED_PLATFORM_COMPONENT
KEEP_TEMPORARILY
REMOVE_FROM_SABLE_DEFAULT
REPLACE_WITH_SABLE_COMPONENT
REQUIRES_DEPENDENCY_FORENSICS
```

### D3 physical functional baseline

Before D4 mutation, capture read-only Android state and then execute the human functional matrix on the known-good D3 system. This distinguishes a true D4 regression from a pre-existing D3 limitation.

Read-only diagnostic capture should include, as applicable:

```text
getprop
dumpsys telephony.registry
dumpsys telecom
dumpsys wifi
dumpsys connectivity
dumpsys package
dumpsys role
package list + install paths
default app/role state
SIM/service/data registration state
IMS state where exposed
```

Sensitive identifiers must be redacted before evidence is published publicly.

## D4-R1 — combined mutation plan

D4-R0 evidence defines one combined mutation batch. Where proven safe, D4-R1 may contain:

- remaining user-visible SableOS branding;
- Sable OS/version presentation surfaces that do not break Android compatibility properties;
- removal of Graphene user-facing default apps that have proven unnecessary;
- removal of Graphene Apps/app-store exposure if dependency closure permits it;
- cleanup of product-package references, overlays, permissions and other references caused by removal;
- a documented intentional default-app set.

Do not include broad `app.grapheneos.*` namespace rewrites, invented Sable service ownership, fake Sable update infrastructure or unowned update URLs.

The default app set must explicitly document at least:

```text
launcher
browser
dialer
SMS
camera
contacts
app store (or intentionally none)
updater
gallery/files
```

## D4-B1 — one combined build + audit

After D4-R1 is approved, perform one combined Panther build rather than one build per string/app removal.

Mandatory gates:

```text
D4_SOURCE_SCOPE=PASS
D4_BUILD=PASS
D4_WARNING_AUDIT=PASS
D4_ARTIFACT_CAUSALITY=PASS
```

Build warning review remains contextual: warnings are classified rather than blindly suppressed or treated as fatal by token match. D4 must end with zero unresolved D4-relevant correctness risk.

## D4-V1 — physical phone functional acceptance

A successful boot is insufficient. D4 must validate the device as a usable phone.

| Area | Required validation |
| --- | --- |
| Boot | cold boot, warm reboot, unlock, encrypted shared data preserved |
| Voice | outgoing call, incoming call, earpiece, microphone, speakerphone |
| SMS | outgoing SMS, incoming SMS |
| MMS | send/receive where carrier/APN support permits |
| Cellular data | LTE/5G data and airplane-mode recovery |
| IMS | VoLTE/IMS registration where carrier support permits |
| Wi-Fi | connect, internet traffic, disconnect/reconnect, reboot recovery |
| Hotspot | enable, client connects, client receives internet |
| Bluetooth | pair/reconnect; audio where test hardware is available |
| Audio | speaker, microphone and media playback |
| Camera | front/rear photo and video |
| Location | ordinary app obtains a location fix |
| NFC | basic enable/read where test hardware is available |
| USB | adb, charging and supported data role |
| Sensors | rotation/proximity/basic sensor sanity |
| Biometrics | fingerprint enrollment/unlock when configured |
| APK install | install and launch an APK |
| Permissions | runtime permission grant/revoke sanity |
| Browser/WebView | HTTPS page load and WebView-backed app sanity |
| Notifications | app notification delivery |
| Power | charging detected and no obvious power-service regression |
| A/B | active slot correct and successful bit closes |
| Persistence | settings/shared data survive another reboot |

Minimum mandatory user-facing gates:

```text
VOICE_OUT=PASS
VOICE_IN=PASS
SMS_OUT=PASS
SMS_IN=PASS
CELLULAR_DATA=PASS
WIFI=PASS
```

Target additional gates:

```text
HOTSPOT=PASS
BLUETOOTH=PASS
CAMERA=PASS
LOCATION=PASS
USB_ADB=PASS
```

Do not place a real emergency-services call merely as a ROM sanity test. Emergency-call validation requires a controlled/authorized arrangement.

## D4 app-removal acceptance criteria

For every removed package, require:

```text
SOURCE_PRODUCT_REFERENCE_REMOVED_OR_INTENTIONALLY_RETAINED
PRIVAPP_PERMISSION_REFERENCE_CLOSED
OVERLAY_REFERENCE_CLOSED
SELINUX_REFERENCE_CLASSIFIED
RUNTIME_PACKAGE_ABSENT
NO_BOOT_FAILURE
NO_SETUPWIZARD_FAILURE
NO_SETTINGS_CRASH
NO_MISSING_ROLE_HOLDER
NO_CORE_FUNCTIONAL_REGRESSION
```

A package merely disappearing from an image is not sufficient proof that its removal was correct.

## D4-R2 — final closure

After build and physical acceptance, retain the exact source delta, warning audit, artifact causality, package-removal closure, functional matrix, A/B state and reconstruction instructions in GitHub.

Target classification:

```text
D4_GRAPHENE_USER_FACING_DEFAULTS=REMOVED_OR_EXPLICITLY_JUSTIFIED
D4_DEFAULT_APP_SET=DOCUMENTED
D4_FUNCTIONAL_ACCEPTANCE=PASS
D4_SLOT_B_BOOT=PASS
D4_SLOT_B_SUCCESSFUL=PASS
D4_SHARED_DATA_PRESERVED=PASS
```

## After D4

### R1 — Sable-owned release engineering

Move from `userdebug/test-keys` development artifacts toward an independently maintainable release pipeline:

```text
Sable signing keys
Sable release versioning
release/user build policy
OTA generation and signing
update metadata
Updater integration
A/B OTA/rollback validation
factory/fastboot distribution artifacts
recovery/rescue procedure
key custody/rotation documentation
```

### F1 — first combined Sable functional-feature batch

Port/redesign functional Sable features in coherent batches using the canonical-base rules above.

### R2 — production hardening

Repeatable signed releases, broader regression coverage, upgrade/rollback testing, key-management exercises and release-candidate acceptance.

## Current sequence

```text
D3  canonical GrapheneOS 2026081300 base
    + initial Sable UI identity
    + Sable fallback boot logo
    + AVB/fs-verity closure
    + physical boot / dual-known-good A/B
    COMPLETE

D4  identity closure
    + Graphene user-facing default-app removal/dependency audit
    + documented default app set
    + full phone functional acceptance
    NEXT

R1  Sable signing/versioning/OTA/release pipeline
F1  combined Sable functional feature batch
R2  production hardening / repeatable release validation
```
