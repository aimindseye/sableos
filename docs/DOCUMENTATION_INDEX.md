# SableOS Documentation Index

## Start here

For the current project state and active product direction:

- `../CURRENT_STATUS.md` — current execution handoff, R8 implementation/build-prep priority, paused release work, and validated Panther state.
- `R8_PIXEL_UI_PRODUCT_CLOSURE.md` — build-blocking final Pixel UI matrix covering R8-A through R8-E, SystemUI/Settings/Setup/Keyguard, Reader OCR, product composition, final Panther build/physical acceptance, and Titan 2 handoff.
- `R8_SABLESTART_V4_SIGNING_INCIDENT_20260919.md` — R8 physical PackageManager failure, confirmed v4 `.idsig`/fs-verity/SELinux causal chain, source fix, CI/build gates, and requalification contract.
- `R8_SABLESTART_HOME_RUNTIME_INCIDENT_20260920.md` — R8 physical HOME-role selection gap and SableStart early-window startup crash, lifecycle-safe system-bar fix, HOME priority contract, and cold-launch acceptance requirements.
- `INFRA5_DEFERRED_TRUSTED_RUNNER.md` — decision to defer encrypted trusted-runner activation until release/security hardening while preserving the INFRA4 fail-closed gate.
- `UI_UX_CONTRACT.md` — cross-surface SableOS design language, shared Compose primitives, branding rules, accessibility requirements, and UI refresh rollout order.
- `R9_SABLESTART_LAUNCHER_DESIGN.md` — design-first SableStart expansion using pinned Niagara/Kvaesitso/Lawnchair/Olauncher/OpenMiniLaunch references, one-hand app navigation, Sable Rail, Search/Command, Sable Peek, Quickstep boundary, privacy rules, and the no-full-build-before-visual-review gate.
- `R9_SABLESTART_VISUAL_REVIEW_20260920.md` — source-derived combined L1-L6 review sheet for Start dark/light, Sable Rail, Search/Command, Sable Peek, truthful local context and accessibility states; visual acceptance remains pending.
- `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` — accepted Sable Flow / Sable Start / Sable Hub direction, provider/capsule model, native phone baseline, and M1-M5 sequence.
- `CORE_PRODUCT_MODEL.md` — normative product architecture and retain/replace boundaries.
- `CORE_PRODUCT_ROADMAP.md` — active product-integration roadmap.
- `ROADMAP.md` — broader historical/platform/service roadmap.
- `NON_PIXEL_DEVICE_ROADMAP.md` — Panther-first non-Pixel device ordering and Titan 2/Q27/Q25 roles.

## Normative architecture / policy

When an older concept note or historical validation record conflicts with an accepted ADR or normative document, the normative/ADR decision takes precedence.

- `ARCHITECTURE.md` — platform layering, service boundaries, privilege placement, device separation, and N0/N1/N2 non-Pixel assurance classes.
- `NON_PIXEL_MEDIATEK_ARCHITECTURE.md` — normative candidate-port architecture for MediaTek/non-Pixel devices, including prebuilt-kernel policy, BSP/VINTF/ABI-shim boundaries, firmware lifecycle, AVB, recovery and production-support classification.
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
- `NON_PIXEL_DEVICE_ROADMAP.md` — current non-Pixel device strategy: Panther first, Titan 2 as preferred interim N0 GSI/UI lab, Q27 as future full-QWERTY candidate, Q25 as optional low-level MediaTek/kernel research target.
- `TITAN2_GSI_PLAN.md` — staged Titan 2 GSI/userspace development plan, stock-artifact qualification, UI/keyboard/5G work, assurance boundaries, and possible later N1 research.
- `TITAN2_KEYBOARD_FIRST_REFERENCE.md` — normative Titan 2 keyboard-first interaction contract plus pinned Pastiera, OpenMiniLaunch, TypeQ25 and Q25 Toolbox reference review and licensing boundary.
- `KEYBOARD_FIRST_SABLE_TOOLS_REFERENCE.md` — common Titan 2/Q27 Sable Tools direction inspired by BB10 power-user/device utilities, with pinned bb10tools revision, GPL boundary, safe capabilities and explicit non-goals.
- `Q25_PORT_PLAN.md` — optional source-available MediaTek/kernel/QWERTY research-port plan; not a required first non-Pixel purchase or Q27 precursor.
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
    -> Titan 2 N0 GSI/userspace/UI portability lab when Panther is ready
    -> Q27 full-port evaluation when shipped hardware qualifies
    -> release-candidate signing/OTA closure
```

## Current milestone snapshot

```text
PANTHER_D4                          CLOSED / PASS
SABLEOS_PRODUCT_DEVELOPMENT        ACTIVE
SABLEOS_CORE_PRODUCT_STAGE         R8_RUNTIME_CLOSURE + R9_LAUNCHER_DESIGN
SABLE_FLOW_STATUS                  IMPLEMENTED_IN_REPO_PRODUCT_INTEGRATION_PENDING
SABLE_START_STATUS                 IMPLEMENTED_NOT_PRODUCT_PROVEN
SABLE_HUB_STATUS                   NOT_INTEGRATED
NEXT_PRODUCT_MILESTONE             R8_SABLESTART_RUNTIME_FIX + R9_VISUAL_REVIEW

NON_PIXEL_ASSURANCE_MODEL           N0_GSI_USERSPACE_LAB -> N1_INTEGRATED_VENDOR_BSP_PORT -> N2_PRODUCTION_QUALIFIED
TITAN2_ROLE                         PREFERRED_INTERIM_N0_LAB_AFTER_PANTHER
Q27_ROLE                            FUTURE_FULL_QWERTY_CANDIDATE_PENDING_QUALIFICATION
Q25_ROLE                            OPTIONAL_MEDIATEK_KERNEL_DEVICE_RESEARCH

R1_RELEASE_SIGNING_WORK            PAUSED_NON_BLOCKING
INFRA5_TRUSTED_RUNNER              DEFERRED_NON_BLOCKING
TRUSTED_SELF_HOSTED_RUNNER         DISABLED
SOURCE_BUILD_STORAGE_ENCRYPTED     NO
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
- `NON_PIXEL_RELEASE_VALIDATION.md` — additional N0/N1/N2 gates for non-Pixel kernel/BSP/vendor/firmware provenance, ABI shims, 5G/IMS, AVB, recovery, physical variants and release claims.

Production signing/OTA work is intentionally paused during current UI/feature development. Completed release identity and source-mutation evidence remains valid; no production private key has been generated.

Trusted self-hosted runner activation is likewise deferred. Current CI remains GitHub-hosted; the unencrypted `ai-g732` Sable build volume is not accepted as a trusted release-runner environment. INFRA5 should be reopened with production signing/release hardening.

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
- `NON_PIXEL_RELEASE_VALIDATION.md` — non-Pixel assurance and BSP/kernel/vendor/firmware validation extension.
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
- Brax3/iodéOS — MediaTek device-port, prebuilt-kernel/BSP, VINTF/SELinux, firmware/OTA, ABI-shim and recovery reference; see `BRAX3_IODEOS_REFERENCE.md`.
- Rust UI frameworks such as Slint, WaterUI, Project Robius/Makepad, Blinc, Vexo and Dioxus Native/Blitz — qualification candidates/references, not automatic dependencies.

Third-party social provider capability must be verified against current official provider documentation at implementation time. Sable Hub must not rely on private application-database scraping or claim unsupported native/API integrations.
