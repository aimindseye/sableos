# SableOS

SableOS is an experimental privacy- and security-focused Android-compatible mobile OS with narrow privilege boundaries, a Rust-first userspace direction, and one common product core across hardware and interaction profiles.

The project is moving beyond substrate bring-up into a distinct user experience built around **Sable Flow**: a Metro-inspired, information-first shell with live tiles, people-centric communication and a central Sable Hub.

> **Applications provide capabilities; Sable organizes people, attention and actions.**

## Product direction

SableOS should not become a collection of unrelated device ROMs or a differently branded Android launcher.

The intended product model is:

```text
Android / third-party applications
        provide capabilities, content and authorized actions
                         |
                         v
AOSP / Android platform services
        provide mature enforcement and device capability
                         |
                         v
Sable product surfaces
        organize people, attention, actions, privacy and intent
```

Sable replaces presentation/orchestration where it creates a real product benefit while retaining mature Android transport, providers, HALs, application compatibility and enforcement where appropriate.

Core rules:

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven Android/vendor capability unless there is a demonstrated privacy, security, performance, maintainability or architectural reason to replace it.

> The shell may observe and request; privileged services decide and execute.

> Stable Sable semantic contracts should survive Android-version and device changes; substrate-specific behavior belongs behind bounded adapters.

## Sable Flow

**Sable Flow** is the working name for the Sable-owned design language. It is inspired by useful Windows Phone / Metro interaction principles while using original Sable naming, visual assets, implementation and product identity.

### Sable Start

The launcher/home experience is **Sable Start**:

```text
vertical Start surface
    -> information/action tiles
    -> large typography
    -> accent/theme system
    -> live state where privacy policy allows
    -> fast application/service list
```

Initial product tile set:

```text
PEOPLE      PHONE
MESSAGES    MAIL
CAMERA      PHOTOS
SOCIAL      CALENDAR
SETTINGS    CLOCK
```

The first Panther product milestone focuses on a real vertical slice:

```text
PHONE
PEOPLE
MESSAGES
SETTINGS
```

Launcher3 remains a development/reference fallback until Sable Start passes replacement qualification.

## Sable Hub

Sable Hub is the central people, communication, attention and service surface.

The Hub uses a provider capability model rather than pretending every third-party service exposes the same native API:

```text
native Android/Sable data
Android notification/conversation adapter
supported provider API adapter
isolated web capsule
```

Initial social-service targets are:

```text
WhatsApp
Instagram
Facebook
LinkedIn
```

Sable does **not** depend on scraping private application databases or building an unsupported universal client. Provider/API capability is revalidated against current official service support at implementation time. Where an appropriate consumer API is unavailable, the planned fallback is an isolated Sable-managed web capsule with independent provider session/storage state.

The UI must explicitly distinguish native, notification-derived, supported-API and web-backed capability.

See `docs/SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md`.

## Current milestone

Panther D4 physical acceptance is closed. The current product phase is:

```text
SABLEOS_PRODUCT_DEVELOPMENT=ACTIVE
SABLEOS_CORE_PRODUCT_STAGE=PRODUCT_INTEGRATION_START
NEXT_PRODUCT_MILESTONE=SABLE_M1_METRO_SHELL_PROTOTYPE
TARGET=panther
```

Near-term sequence:

```text
Sable Flow shared primitives
    -> Sable Start M1
    -> Phone / People / Messages
    -> Sable Hub provider framework
    -> social web capsules
    -> broader native apps and polish
    -> Q25/Q27 portability when justified
    -> production signing/OTA closure before release candidate
```

See `CURRENT_STATUS.md` and `docs/CORE_PRODUCT_ROADMAP.md`.

## CI qualification status

This is a dated qualification snapshot for the stacked R8 infrastructure work as of **2026-09-17**. It records what has been proven on the draft integration stack; it does **not** claim these controls are already merged into `main`.

Current stack:

```text
PR #7  R8 qualified source
  -> PR #9  INFRA2B1 deterministic CI
  -> PR #10 INFRA2B2 security baseline
  -> PR #11 INFRA2B3 quality + coverage baseline
```

| CI process | Status | Qualified evidence |
| --- | --- | --- |
| Repository structure | **PASS** | B2-R1 head `6f28c629...` |
| R8 Rust correctness | **PASS** | B2-R1 head `6f28c629...` |
| R8 Rust security / cargo-audit | **PASS** | B2-R1 head `6f28c629...` |
| CI trust policy | **PASS** | B2-R1 head `6f28c629...` |
| R8 Android compile and tests | **PASS** | INFRA2B1 head `213b29bd...` |
| R8 Android static analysis / Android Lint | **PASS** | INFRA2B1 head `213b29bd...` |
| R8 APK artifact seal | **PASS** | INFRA2B1 head `213b29bd...` |
| R8 Reader compile and tests | **PASS** | INFRA2B1 head `213b29bd...` |
| R8 Reader static and capability policy | **PASS** | INFRA2B1 head `213b29bd...` |
| R8 Text Reader compile and tests | **PASS** | INFRA2B1 head `213b29bd...` |
| R8 Text Reader static and capability policy | **PASS** | INFRA2B1 head `213b29bd...` |
| Gitleaks secret-history scan | **PASS** | B2-R1 head `6f28c629...` |
| MobSF Android source scan | **PASS / BASELINE** | Scanner execution passed; 14 findings retained for classification |
| cargo-deny advisory / ban / source policy | **PASS** | B2-R1 head `6f28c629...` |
| detekt Kotlin static analysis | **PASS / BASELINE** | PR #11 head `5038b571...`; 60 findings retained (51 MagicNumber, 5 LongMethod, 4 FunctionNaming) |
| ktlint Kotlin style analysis | **PASS / BASELINE** | PR #11 head `5038b571...`; 52 style findings retained for cleanup |
| Kover Kotlin coverage | **PASS / BASELINE** | `:design` line coverage 30.77% (16/52); no percentage gate |
| cargo-llvm-cov Rust coverage | **PASS / BASELINE** | Rust line coverage 71.90% (952/1324); no percentage gate |

Scanner success means the configured scanner executed successfully under its current policy; it does not mean the codebase is vulnerability-free. Coverage is introduced as a measured baseline first, then ratcheted with module-specific thresholds after evidence exists.

INFRA2B3 qualification on PR #11 completed successfully for head `5038b57112ec321de3ba1f57d4aeee19622ad379`; the quality and coverage workflow also preserved its generated reports as GitHub Actions artifacts.

## Current reference target

Active development:

- Device: Google Pixel 7 (`panther`)
- Role: touch-first development reference
- Android baseline: Android 17 / SDK 37
- Canonical development substrate: GrapheneOS `2026081300` Android 17 with audited Sable-specific deltas
- Physical D4 status: **CLOSED / PASS**
- Canonical B2 target-files SHA-256: `b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78`

Historical architecture/regression reference:

- Pixel 4a 5G (`bramble`)
- Android 14 / `android-14.0.0_r28`
- S1.7 power service/API/runtime boundary: **PASS / FROZEN**

Bramble no longer constrains active UI-framework/toolchain selection.

## Proven service architecture

Sable's first frozen semantic service is the read-only power API:

```text
com.sableos.power.IPowerService/default
    getLatestState() -> PowerSnapshot
```

The architecture demonstrates the intended privilege model:

```text
Android/vendor Health authority
        -> narrow Sable service
        -> typed semantic state
        -> authorized Sable/UI consumer
```

The UI does not gain Health HAL or raw battery-sysfs authority merely because it presents battery state.

Exact S1.7 source/image/device/runtime evidence is in `docs/S1_7_VALIDATION.md`.

## Architecture

```text
Sable shell / applications
        |
        | typed semantic IPC
        v
narrow Sable services / brokers
        |
        | SELinux + explicit capability policy
        v
AOSP framework / supported HAL / vendor stack
        |
        v
hardware
```

Preferred:

```text
UI -> semantic read-only service
UI -> narrow typed request -> dedicated service -> Android framework/HAL
```

Rejected as a base trust model:

```text
UI -> raw hardware sysfs
UI -> direct privileged HAL without need
UI -> generic privileged command executor
agent -> unrestricted root shell
```

When UI and platform Rust compilers differ, Sable crosses through stable C/NDK/AIDL contracts rather than compiler-private cross-version Rust ABI.

## Android application compatibility

SableOS preserves standard Android application packaging and runtime semantics:

```text
APK / split APK
PackageManager / PackageInstaller
ART
application sandbox
permissions / AppOps
intents / components
profiles
WebView / maintained browser path
```

A Rust-first Sable renderer is a presentation choice; it does not replace Android's application ecosystem.

## Interaction profiles and future devices

### Touch-first

Panther establishes the Sable Flow touch profile:

- live information tiles;
- strong typography and spatial hierarchy;
- low-chrome information surfaces;
- fast peek/return workflows;
- low-latency motion communicating hierarchy.

### Keyboard-first / compact

Future Q25/Q27 work should reuse the same semantic model with:

- physical keyboard as first-class input;
- deterministic focus;
- type-to-search;
- shortcuts/command palette;
- compact/square layout rules;
- predictable focus restoration.

Device roles:

- `panther` / Pixel 7 — active touch-first reference;
- `bramble` / Pixel 4a 5G — frozen architecture/regression reference;
- Zinwa Q25 — optional MediaTek/QWERTY engineering reference;
- Zinwa Q27 — future preferred modern QWERTY direction subject to platform/hardware acceptance.

The Sable Start/Hub data and capability model must remain common across these form factors.

## Release signing

Production signing/OTA engineering is intentionally **paused and non-blocking** while product features are developed.

Completed release identity, source-mutation, update-endpoint and custody policy work is preserved, but no production key has been generated.

```text
PRODUCTION_KEYS_GENERATED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
SIGNING_HOST_SELECTION=DEFERRED
```

Production signing returns to the critical path before release-candidate/OTA distribution.

## Engineering discipline

Runtime milestones close on evidence, not compilation alone:

```text
source guards
 -> targeted tests
 -> affected build
 -> generated-artifact audit
 -> compiled policy audit
 -> full product build
 -> exact image proof
 -> AVB validation
 -> controlled device deployment
 -> runtime/physical proof
 -> fallback/recovery validation
```

Power, thermal, scheduler, memory, modem and lifecycle tuning remain measurement-driven.

## Documentation

Start with:

- `CURRENT_STATUS.md` — current validated state and active milestone.
- `docs/SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` — Sable Flow, Sable Start, Hub/provider/capsule architecture and M1-M5 plan.
- `docs/CORE_PRODUCT_MODEL.md` — normative product architecture.
- `docs/CORE_PRODUCT_ROADMAP.md` — active product-integration roadmap.
- `docs/ARCHITECTURE.md` — platform/service layering and privilege boundaries.
- `docs/SECURITY_MODEL.md` — trust/SELinux/IPC model.
- `docs/DOCUMENTATION_INDEX.md` — broader documentation index.
