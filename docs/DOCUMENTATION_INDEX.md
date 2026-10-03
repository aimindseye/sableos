# SableOS Documentation Index

## Current authority

For the current project state and active product direction, start here:

- `CURRENT_HOME_AND_C3B_INTEGRATION_AUTHORITY.md` — current R9L8 HOME ownership and Titan 2 N1D/C3B product/parallel-integration authority; use this to resolve older standalone-SableLauncher notes.
- `../CURRENT_STATUS.md` — current execution authority: Panther R9 Hub V1 closure merged, final accepted source/target-files seal, frozen touch-first reference state, Titan-family keyboard-first next work.
- `adr/0010-keyboard-first-sableos-design-v1.md` — accepted keyboard-first platform architecture and implementation workstreams.
- `adr/0011-sable-hub-v1.md` — accepted Sable Hub V1 product model: Priority / Messages / Email / People, Enabled / Available Connected Apps, truthful local reply handoff bubbles, bounded Sable Mail integration and keyboard-first semantics.
- `adr/0012-keyboard-device-user-choice-camera-control-deck.md` — accepted policy for user-selectable third-party HOME/IME, Sable first-party defaults, Camera Control Deck, and Pastiera 0.86 reference boundaries.
- `KEYBOARD_FIRST_MULTI_DEVICE_TRANSITION.md` — active Titan-family keyboard-first execution plan bound to ADR-0010.
- `TITAN2_KEYBOARD_FIRST_REFERENCE.md` — normative Titan 2 keyboard-first interaction contract plus pinned Pastiera, OpenMiniLaunch, TypeQ25 and Q25 Toolbox reference review and licensing boundary.
- `CAMERA_ENHANCEMENT_ROADMAP.md` — keyboard-device Sable Camera capability roadmap and Camera Control Deck physical-control direction.
- `KEYBOARD_FIRST_SABLE_TOOLS_REFERENCE.md` — common Titan 2/Q27 Sable Tools direction inspired by BB10 power-user/device utilities, with pinned bb10tools revision, GPL boundary, safe capabilities and explicit non-goals.
- `build/README.md` — canonical multi-device build/deploy/acceptance entry point.

When an older concept note or historical validation record conflicts with an
accepted ADR, `CURRENT_STATUS.md` or this index, the newer normative/current
status document takes precedence.

- `titan2/N1D_C3B_CURRENT_PLAN_AND_ASSIGNMENTS.md` — **current Titan 2 execution roadmap and P1-P5 assignment authority**. N0/N1B/N1B2/N1B3/N1C execution documents are historical evidence.
- `SABLE_READER_V2_ARCHITECTURE.md` — **accepted P5 product architecture** for EPUB/PDF, comics/manga/webtoons and audiobooks; Text Reader remains separate.
- `titan2/SABLESCREENS_REFERENCE_BASELINE.md` — **accepted design/reference baseline** mapping the 23-screen catalog into P1-P5/E8; not a runtime product.
- `titan2/KEYBOARD_FIRST_DESIGN_IMPLEMENTATION_QUEUE.md` — **implementation-ready queue** for accepted DESIGN-KF-A through DESIGN-KF-D after P1-P5 qualification.
- `titan2/N1D_C3B_E5A_EVIDENCE.md` — **sealed Titan 2 E5A physical read-only evidence**; clean PASS in userspace fastbootd, with E5B mutation still closed.
- `titan2/N1D_C3B_E5B_AUTHORIZATION_PACKAGE.md` — **offline-only E5B decision package**; current-slot/COW/group analysis without device contact or write-capable commands.
- `titan2/N1D_C3B_E5B_TITAN_DEPLOYMENT_MODEL.md` — **current Titan 2 deployment authority** correcting generic inactive-slot assumptions and binding E5B to the proven N1B active-system path.
- `titan2/N1D_C3B_E5B_STANDARD_DEPLOYMENT_INTEGRATION.md` — **canonical `build/sable.sh` registration + offline flash-plan integration for N1D C3B E5B**; execution remains fail-closed until the exact fastboot implicit-resize scope is qualified.

## Current milestone snapshot

```text
PRIVATE_MAIN_HEAD                         CURRENT_GIT_MAIN (exact external pin lives in sableos-project/.github)
R10_KEYBOARD_FIRST_DESIGN_V1              MERGED / PR #108
R9_PANTHER_HUB_V1_CLOSURE                 MERGED / PR #110
R9_PANTHER_ACCEPTED_SOURCE                edf62e5bb08372a1395841d6cc5d78d3148a7695
R9_PANTHER_TARGET_FILES_SHA256            a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285
R9_PANTHER_PHYSICAL_ACCEPTANCE            PASS_WITH_PRESERVED_PLAY_STATE
PANTHER_ROLE                              FROZEN_TOUCH_FIRST_REFERENCE
THEME_PROPAGATION                         DEFERRED_SEPARATE_PHYSICAL_APPEARANCE_GATE
CLEAN_BASELINE_APPSTORE                   NOT_CLAIMED_ON_PRESERVED_DATA_DEVICE

NON_PIXEL_ASSURANCE_MODEL                 N0_GSI_USERSPACE_LAB -> N1_INTEGRATED_VENDOR_BSP_PORT -> N2_PRODUCTION_QUALIFIED
TITAN2_ROLE                               ACTIVE_N1D_C3B_E5B_OFFLINE_DECISION
TITAN2_ELITE_ROLE                         NEXT_INDEPENDENT_KEYBOARD_FIRST_TARGET
Q27_ROLE                                  RESEARCH / FUTURE CANDIDATE

PRODUCTION_KEYS_GENERATED                 NO
SIGNING_AUTHORIZED                        NO
OTA_GENERATION_AUTHORIZED                 NO
PRODUCTION_SIGNING                        DEFERRED
```

Open follow-up issues are intentionally left open until the Titan 2 SableOS
install path proves or supersedes them. This includes physical appearance/theme
propagation, Reader appearance, large-library Media performance, duplicate
visible Messages review, production icons/launch performance, first-run crash
capture and All Apps permission summaries.

## Normative architecture / policy

- `ARCHITECTURE.md` — platform layering, service boundaries, privilege placement, device separation, and N0/N1/N2 non-Pixel assurance classes.
- `NON_PIXEL_MEDIATEK_ARCHITECTURE.md` — normative candidate-port architecture for MediaTek/non-Pixel devices, including prebuilt-kernel policy, BSP/VINTF/ABI-shim boundaries, firmware lifecycle, AVB, recovery and production-support classification.
- `CORE_PRODUCT_MODEL.md` — Sable Start, Hub, People, Search, Security/Privacy, AOD, Agent/Voice and default-app/product composition model.
- `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` — Sable Flow / Sable Start / Sable Hub direction and provider/capsule policy.
- `SECURITY_MODEL.md` — trust boundaries, IPC policy, SELinux/service-manager rules and privacy architecture.
- `SECURITY_PRIVACY_ASSURANCE_STANDARD.md` — project-wide security/privacy assurance stages, controls and evidence expectations.
- `HARDWARE_SECURITY_CAPABILITIES.md` — per-device security capability registry.
- `KERNEL_SECURITY_UPDATE_POLICY.md` — K1/K2 kernel security updates, KMI/module/AVB/A-B constraints and evidence markers.
- `LANGUAGE_AND_VOICE_POLICY.md` — multilingual/local-first STT/TTS and Hindi acceptance requirements.
- `AOSP_CAPABILITY_POLICY.md` — preserve mature Android/vendor capability unless a reviewed replacement is justified.
- `APP_SECURITY_AND_COMPATIBILITY.md` — standard Android application compatibility and Secure Package Intelligence direction.
- `APPLICATION_SECURITY_PRIVACY_TRANSPARENCY.md` — application authority, component, tracker/library, storage/network and history transparency.
- `ANDROID_VERSION_PORTABILITY.md` — stable Sable semantics across Android/device/compiler changes.
- `INTERACTION_PROFILES.md` — common product semantics with touch-first and keyboard-first profiles, including input-surface, app-display-profile and notification-attention capabilities.
- `SECURITY_MAINTENANCE.md` — platform/kernel/vendor/browser/security-update provenance and release claims.

Accepted ADRs include:

- `adr/0001-mobile-ux-with-strict-privilege-separation.md` — UX remains separate from hardware/system privilege.
- `adr/0002-rust-ui-framework-and-android-app-compatibility.md` — Rust UI qualification and shared Metro-inspired touch / keyboard-first interaction semantics.
- `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md` — Panther transition and stable ABI/toolchain boundary.
- `adr/0004-portable-security-privacy-and-hardware-capability-model.md` — portable security/privacy baseline plus additive hardware capabilities.
- `adr/0005-independent-kernel-security-updates.md` — independent K1/K2 kernel-security updates.
- `adr/0006-multilingual-local-first-voice.md` — multilingual/local-first voice architecture.
- `adr/0007-core-product-hub-aod-agent-and-aosp-boundary.md` — strategic Sable product surfaces over retained Android capability/enforcement.
- `adr/0008-configurable-local-conversation-adapters.md` — provider-agnostic package/profile Connected Apps using Android notification/conversation/RemoteInput authority.
- `adr/0009-separate-reader-and-text-reader-products.md` — separate publication Reader and plain-text/TTS/OCR Text Reader products.
- `adr/0010-keyboard-first-sableos-design-v1.md` — normative keyboard-first platform architecture.
- `adr/0011-sable-hub-v1.md` — accepted Sable Hub V1 communications surface.
- `adr/0012-keyboard-device-user-choice-camera-control-deck.md` — keyboard-device user-choice, Sable first-party defaults, Pastiera 0.86 intake, and Camera Control Deck.

## Product planning

- `CORE_PRODUCT_ROADMAP.md` — active product-integration roadmap.
- `NON_PIXEL_DEVICE_ROADMAP.md` — non-Pixel device strategy and device roles.
- `TITAN2_GSI_PLAN.md` — staged Titan 2 GSI/userspace development plan, stock-artifact qualification, UI/keyboard/5G work, assurance boundaries, and possible later N1 research.
- `Q25_PORT_PLAN.md` — optional source-available MediaTek/kernel/QWERTY research-port plan; not a required first non-Pixel purchase or Q27 precursor.
- `S1_8_PLATFORM_TRANSITION.md` — historical bramble UI/toolchain closure and Panther transition.

Current product progression:

```text
frozen Panther touch-first reference
    -> keyboard-first SableOS design V1 merged
    -> Titan 2 N1D/C3B E3 systemimage engineering and runtime bring-up
    -> first Titan 2 keyboard-first SableOS artifact + deployment path
    -> close remaining open Panther/Titan shared polish issues where proven or superseded
    -> Titan 2 Elite independent evidence and deployment sequence
    -> common Sable Camera Control Deck + Sable Keyboard/system input integration
    -> Q27 full-port evaluation when shipped hardware qualifies
    -> production signing / OTA closure after repeatable multi-device development qualification
```

## Panther / release evidence

Key Panther records:

- `R9_PANTHER_APPSTORE_THIRD_PARTY_FREEZE.md` — bounded final Panther compatibility closure, pinned AppStore, optional sandboxed Google Play and Connected Apps physical evidence.
- `adr/0011-sable-hub-v1.md` — final Hub V1 communications product decision.
- `PANTHER_D4_CLOSURE_20260908.md` — D4 final closure.
- `PANTHER_D4_ROADMAP.md` — closed D4 roadmap and R1 handoff history.
- `PANTHER_D4_B2_PHYSICAL_VALIDATION.md` — physical B2 validation evidence.
- `PANTHER_D4_R2_SLOT_SUCCESS_PROOF.md` — slot-success proof.
- `BUILD_PANTHER_GRAPHENE_2026081300.md` — canonical Panther build procedure history.

R1 release-engineering records:

- `SABLE_R1_R0_CLOSURE_20260908.md` — R1-R0 closure.
- `SABLE_R1_R1_RELEASE_POLICY_AND_CUSTODY.md` — release identity, custody and signing architecture.
- `SABLE_R1_R1_CLOSURE_20260908.md` — R1-R1 closure.
- `SABLE_R1_R2_STATIC_PREP_AND_DISK_AUDIT.md` — source/keygen static-preparation history.
- `RELEASE_VALIDATION.md` — release validation policy and gates.
- `NON_PIXEL_RELEASE_VALIDATION.md` — additional N0/N1/N2 gates for non-Pixel kernel/BSP/vendor/firmware provenance, ABI shims, 5G/IMS, AVB, recovery, physical variants and release claims.

Production signing/OTA work is intentionally paused during current UI/feature
and multi-device development. Completed release identity and source-mutation
evidence remains valid; no production private key has been generated.

## Frozen architecture / validation references

Historical validation records remain evidence for the milestone they closed.
They are not authority to revive superseded design assumptions.

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

- Windows Phone / Metro — information-first touch interaction and live-tile inspiration.
- BlackBerry Hub / BB10 — people/communication organization and keyboard-first workflow inspiration.
- OpenMiniLaunch / MinkLauncher — Apache-2.0 keyboard-first HOME type-to-command and active Conversations reference.
- Commander — keyboard-first command palette, recents and notification-Hub interaction reference.
- Pastiera 0.86 / Plektra — physical-keyboard IME, modifier/layout, compact-input and settings/product behavior reference; Pastiera 0.86 is pinned at `e7d8f27ecc7253e61690b5d34f110b25dc68bb16`, GPL-3.0, with no Sable source import authorized.
- q25toolbox — rooted Q25 hardware/input forensic reference; workarounds are not Sable platform architecture.
- TrebleDroid / RestlessOS — non-Pixel/GSI/vendor compatibility reference; not the Sable security baseline.
- App Manager — package/application transparency reference for Secure Package Intelligence.
- GrapheneOS — security-engineering reference and current audited Panther substrate source.
- MarathonOS — mobile/QWERTY and recovery/device lessons.
- Brax3/iodéOS — MediaTek device-port, prebuilt-kernel/BSP, VINTF/SELinux, firmware/OTA, ABI-shim and recovery reference.
- Rust UI frameworks such as Slint, WaterUI, Project Robius/Makepad, Blinc, Vexo and Dioxus Native/Blitz — qualification candidates/references, not automatic dependencies.

Third-party social provider capability must be verified against current official
provider documentation at implementation time. Sable Hub must not rely on private
application-database scraping or claim unsupported native/API integrations.
