# SableOS Documentation Index

## Start here

For the current project state and active product direction:

- `../CURRENT_STATUS.md` — current validated Panther state, paused R1 release work, and active Sable Flow milestone.
- `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` — accepted Sable Flow / Sable Start / Sable Hub direction, provider/capsule model, native phone baseline, and M1-M5 sequence.
- `CORE_PRODUCT_MODEL.md` — normative product architecture and retain/replace boundaries.
- `CORE_PRODUCT_ROADMAP.md` — active product-integration roadmap.
- `ROADMAP.md` — broader historical/platform/service roadmap.

## Normative architecture / policy

When an older concept note or historical validation record conflicts with an accepted ADR or normative document, the normative/ADR decision takes precedence.

- `ARCHITECTURE.md` — platform layering, service boundaries, privilege placement and device separation.
- `CORE_PRODUCT_MODEL.md` — Sable Start, Hub, People, Search, Security/Privacy, AOD, Agent/Voice and default-app/product composition model.
- `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` — concrete Metro-inspired Sable Flow implementation direction and social-service provider/capsule policy.
- `SECURITY_MODEL.md` — trust boundaries, IPC policy, SELinux/service-manager rules and privacy architecture.
- `SECURITY_PRIVACY_ASSURANCE_STANDARD.md` — project-wide security/privacy assurance stages, controls and evidence expectations.
- `HARDWARE_SECURITY_CAPABILITIES.md` — per-device security capability registry.
- `KERNEL_SECURITY_UPDATE_POLICY.md` — K1/K2 kernel security updates, KMI/module/AVB/A-B constraints and evidence markers.
- `LANGUAGE_AND_VOICE_POLICY.md` — multilingual/local-first STT/TTS and Hindi acceptance requirements.
- `AOSP_CAPABILITY_POLICY.md` — preserve mature Android/vendor capability unless a reviewed replacement is justified.
- `APP_SECURITY_AND_COMPATIBILITY.md` — standard Android application compatibility and Secure Package Intelligence direction.
- `APPLICATION_SECURITY_PRIVACY_TRANSPARENCY.md` — application authority, component, tracker/library, storage/network and history transparency.
- `ANDROID_VERSION_PORTABILITY.md` — stable Sable semantics across Android/device/compiler changes.
- `INTERACTION_PROFILES.md` — common product semantics with touch-first and keyboard-first profiles.
- `SECURITY_MAINTENANCE.md` — platform/kernel/vendor/browser/security-update provenance and release claims.

Accepted ADRs include:

- `adr/0001-mobile-ux-with-strict-privilege-separation.md` — UX remains separate from hardware/system privilege.
- `adr/0002-rust-ui-framework-and-android-app-compatibility.md` — Rust UI qualification and shared Metro-inspired touch / keyboard-first interaction semantics.
- `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md` — Panther transition and stable ABI/toolchain boundary.
- `adr/0004-portable-security-privacy-and-hardware-capability-model.md` — portable security/privacy baseline plus additive hardware capabilities.
- `adr/0005-independent-kernel-security-updates.md` — independent K1/K2 kernel-security updates.
- `adr/0006-multilingual-local-first-voice.md` — multilingual/local-first voice architecture.
- `adr/0007-core-product-hub-aod-agent-and-aosp-boundary.md` — strategic Sable product surfaces over retained Android capability/enforcement.

## Product planning

- `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` — active product plan.
- `CORE_PRODUCT_ROADMAP.md` — active M1-M6 / CP integration track.
- `Q25_PORT_PLAN.md` — optional MediaTek/QWERTY engineering-reference plan; future Q25 work must reuse the common Sable Start/Hub semantic model.
- `S1_8_PLATFORM_TRANSITION.md` — historical bramble UI/toolchain closure and Panther transition.

Current product progression:

```text
validated Panther substrate
    -> Sable Flow shared primitives
    -> Sable Start M1
    -> Phone / People / Messages
    -> Sable Hub provider framework
    -> social web capsules / supported API adapters
    -> broader native apps and polish
    -> Q25/Q27 portability when justified
    -> release-candidate signing/OTA closure
```

## Current milestone snapshot

```text
PANTHER_D4                          CLOSED / PASS
SABLEOS_PRODUCT_DEVELOPMENT        ACTIVE
SABLEOS_CORE_PRODUCT_STAGE         PRODUCT_INTEGRATION_START
SABLE_FLOW_STATUS                  PLANNING_COMPLETE_IMPLEMENTATION_NEXT
SABLE_START_STATUS                 NOT_INTEGRATED
SABLE_HUB_STATUS                   NOT_INTEGRATED
NEXT_PRODUCT_MILESTONE             SABLE_M1_METRO_SHELL_PROTOTYPE

R1_RELEASE_SIGNING_WORK            PAUSED_NON_BLOCKING
PRODUCTION_KEYS_GENERATED          NO
KEY_GENERATION_AUTHORIZED          NO
SIGNING_AUTHORIZED                 NO
OTA_GENERATION_AUTHORIZED          NO
SIGNING_HOST_SELECTION             DEFERRED
```

## Panther / release evidence

Key current Panther records:

- `PANTHER_D4_CLOSURE_20260908.md` — D4 final closure.
- `PANTHER_D4_ROADMAP.md` — closed D4 roadmap and R1 handoff history.
- `PANTHER_D4_B2_PHYSICAL_VALIDATION.md` — physical B2 validation evidence.
- `PANTHER_D4_R2_SLOT_SUCCESS_PROOF.md` — slot-success proof.
- `BUILD_PANTHER_GRAPHENE_2026081300.md` — canonical current Panther build procedure.

R1 release-engineering records:

- `SABLE_R1_R0_CLOSURE_20260908.md` — R1-R0 closure.
- `SABLE_R1_R1_RELEASE_POLICY_AND_CUSTODY.md` — release identity, custody and signing architecture.
- `SABLE_R1_R1_CLOSURE_20260908.md` — R1-R1 closure.
- `SABLE_R1_R2_STATIC_PREP_AND_DISK_AUDIT.md` — source/keygen static-preparation history.
- `RELEASE_VALIDATION.md` — release validation policy and gates.

Production signing/OTA work is intentionally paused during current UI/feature development. Completed release identity and source-mutation evidence remains valid; no production private key has been generated.

## Frozen architecture / validation references

Historical validation records remain evidence for the milestone they closed. They are not authority to revive superseded design assumptions.

Important frozen records:

- `S1_7_VALIDATION.md` — frozen Power AIDL V1 source/image/device/runtime seal on bramble Android 14.
- `S1_8_D0_F0_QUALIFICATION.md` — bramble architecture/toolchain evidence.
- `S1_8_BRAMBLE_UI_QUALIFICATION_FINAL.md` — final historical UI/toolchain qualification evidence.
- `PANTHER_P0_VALIDATION.md` — Pixel 7 Android-17 physical/source/toolchain inventory.
- `PANTHER_P0R1_VALIDATION.md` — signed Android-17 reconstruction/provenance qualification.
- `PANTHER_P1A_VALIDATION.md` — pure-AOSP decoupling audit history.
- `PANTHER_P1B_ANDROID17_HOST_BRINGUP.md` — historical Android-17 host bring-up record.
- `S0_*`, `S1_*`, `B1_*`, `B2_*` — milestone-specific build/runtime evidence.
- `G025E_HARDWARE_ACCEPTANCE.md` — bramble safe-flash and hardware-capability history.

## Engineering / assurance references

- `ENGINEERING_PRINCIPLES.md` — measurement, architecture correction, negative testing and recovery discipline.
- `RELEASE_VALIDATION.md` — build/image/AVB/product/runtime/slot release gates.
- `SECURITY_PRIVACY_RELEASE_RECORD_TEMPLATE.md` — canonical release evidence fields.
- `SECURITY_REFERENCE_GRAPHENEOS.md` — GrapheneOS engineering lessons adapted to Sable boundaries.
- `EXTERNAL_LESSONS.md` — external project lessons and resulting Sable decisions.

## External design references

SableOS studies external systems for specific lessons rather than inheriting complete trust/product models.

- Windows Phone / Metro — information-first touch interaction and live-tile inspiration; Sable Flow uses original Sable identity and implementation.
- BlackBerry Hub / BB10 — people/communication organization and keyboard-first workflow inspiration.
- App Manager — package/application transparency reference for Secure Package Intelligence.
- GrapheneOS — security-engineering reference and current audited Panther substrate source.
- MarathonOS — mobile/QWERTY and recovery/device lessons.
- Rust UI frameworks such as Slint, WaterUI, Project Robius/Makepad, Blinc, Vexo and Dioxus Native/Blitz — qualification candidates/references, not automatic dependencies.

Third-party social provider capability must be verified against current official provider documentation at implementation time. Sable Hub must not rely on private application-database scraping or claim unsupported native/API integrations.
