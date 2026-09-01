# SableOS Documentation Index

## Normative Architecture / Policy

These documents define the current project architecture. When an older concept note or historical validation record conflicts with an accepted ADR or a normative document, the normative/ADR decision takes precedence.

- `ARCHITECTURE.md` — platform layering, service boundaries, privilege placement, device separation.
- `SECURITY_MODEL.md` — trust boundaries, IPC policy, SELinux/service-manager rules and privacy architecture.
- `SECURITY_PRIVACY_ASSURANCE_STANDARD.md` — project-wide security/privacy assurance stages, control families, privacy defaults, evidence records and standards crosswalk.
- `HARDWARE_SECURITY_CAPABILITIES.md` — canonical per-device hardware-security capability registry; MTE/PAC/BTI/StrongBox/etc. are capability-dependent and absent optional hardware is `NOT_APPLICABLE`, not device failure.
- `AOSP_CAPABILITY_POLICY.md` — preserve mature Android/vendor capability unless a reviewed replacement is justified.
- `APP_SECURITY_AND_COMPATIBILITY.md` — standard Android APK/ART/PackageManager compatibility and Secure Package Intelligence direction.
- `APPLICATION_SECURITY_PRIVACY_TRANSPARENCY.md` — ongoing per-app identity, authority, components, libraries/trackers, storage, network/data use, background behavior and security-history transparency, with declared/enforced/observed/inferred evidence separation.
- `ANDROID_VERSION_PORTABILITY.md` — stable Sable semantics across Android substrate, device and compiler changes.
- `INTERACTION_PROFILES.md` — common application semantics with touch-first and keyboard-first interaction profiles.
- `SECURITY_MAINTENANCE.md` — platform/kernel/vendor/browser/security-update provenance and release claims.
- `adr/0001-mobile-ux-with-strict-privilege-separation.md` — UX remains separate from hardware/system privilege.
- `adr/0002-rust-ui-framework-and-android-app-compatibility.md` — Rust UI qualification, Android APK coexistence, Metro-inspired touch and BlackBerry-inspired keyboard profiles, framework/fork/SableUI decision model.
- `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md` — move active development from bramble to Pixel 7, close the bramble A15/UI-backport path, and decouple modern UI Rust toolchains from platform Rust through stable ABI boundaries when necessary.
- `adr/0004-portable-security-privacy-and-hardware-capability-model.md` — portable mandatory security/privacy baseline with additive per-device hardware security capabilities.

## Planning

- `ROADMAP.md` — completed, current and planned milestones.
- `Q25_PORT_PLAN.md` — optional MediaTek/QWERTY reference-port plan.
- `S1_8_PLATFORM_TRANSITION.md` — bramble S1.8 qualification closure and panther restart sequence.

## Engineering / Release

- `ENGINEERING_PRINCIPLES.md` — measurement, architecture correction, negative testing, recovery discipline.
- `RELEASE_VALIDATION.md` — build, image, AVB, flashing, hardware-security capability, privacy/data-flow/network-egress, runtime and slot-closure gates.
- `SECURITY_PRIVACY_RELEASE_RECORD_TEMPLATE.md` — canonical machine/line-oriented release evidence fields for portable security, hardware capabilities, privacy, provenance and unresolved risk.

## Frozen Validation / Evidence

Validation records document the architecture and evidence applicable to their milestone. They are historical evidence, not a license to revive superseded design assumptions.

- `S1_7_VALIDATION.md` — frozen Power AIDL V1 source/image/device/runtime seal and physical acceptance record on bramble Android 14.
- `S1_8_D0_F0_QUALIFICATION.md` — bramble D0/F0-F3 architecture/toolchain evidence leading to the platform transition.
- `S1_8_BRAMBLE_UI_QUALIFICATION_FINAL.md` — final F4 closure: Slint 1.5 core proven on Rust 1.68 with bounded compatibility work, public API then blocked by another transitive compiler floor (`toml_edit 0.21.1` requiring Rust 1.69), confirming that further dependency down-rev work should stop.
- `PANTHER_P0_VALIDATION.md` — Pixel 7 Android-17 physical/source/toolchain inventory; Android 17 selected as preferred reconstruction candidate, with Android 15 retained as the official-Google-publication fallback.
- `PANTHER_P0R1_VALIDATION.md` — signed Android-17 reconstruction/provenance qualification: exact AOSP/Pixel/adevtool/vendor-state/kernel reference pins, correction of the GrapheneOS-manifest classification blind spot, official July Pixel 7 stock/recovery baseline, and requirement to decouple GrapheneOS-only `adevtool` product hooks before a pure-AOSP workspace build.
- `PANTHER_P1A_VALIDATION.md` — pure-AOSP decoupling audit: six explicit GrapheneOS-only product/init hooks in the active Pixel include closure, standard AOSP product inheritance retained, vendor-state classified reference-only, Panther Health backend identified as modern GS201 AIDL candidate, and bounded Sable-specific `adevtool` adapter authorized for the next host workspace gate.
- `PANTHER_P1B_ANDROID17_HOST_BRINGUP.md` — active Android-17 Panther host bring-up status: separate pure-AOSP workspace, pinned stock Pixel input, bounded GrapheneOS-reference host-tool compatibility contracts, Node/JDK runtime closure, AAPT2/ApkSigner compatibility gates, controlled `generate-all` progress, and explicit S1.8C sequencing guard.
- `S0_*`, `S1_*`, `B1_*`, `B2_*` — milestone-specific build/runtime evidence.
- `G025E_HARDWARE_ACCEPTANCE.md` — bramble safe-flash and physical capability history.

## External Reference Notes

- `EXTERNAL_LESSONS.md` — MarathonOS/Marathon Shell lessons and resulting Sable decisions.
- `SECURITY_REFERENCE_GRAPHENEOS.md` — GrapheneOS security-engineering lessons adapted to Sable boundaries.
- NIST SSDF, NIST Privacy Framework, OWASP MASVS and SLSA are cross-check/reference frameworks for the Sable assurance standard; they are not certification claims.
- App Manager is a design reference for Secure Package Intelligence and ongoing application security/privacy transparency. Sable adopts inspection, comparison and explainability ideas while explicitly rejecting a single root/ADB-supervisor application as the platform trust model.
- Slint, WaterUI, Project Robius/Makepad, Blinc, Vexo and Dioxus Native/Blitz are UI/framework qualification candidates or references, not automatic architecture dependencies.
- Crux is an application/core architecture reference; UniFFI and Flutter Rust Bridge are interop tools rather than preferred shell renderers; Tauri/WebView is not the preferred Sable system-shell model.

## Current Milestone Snapshot

```text
S1.6         PASS
S1.7A        PASS
S1.7B        PASS
S1.7         PASS / FROZEN on bramble Android 14
S1.8-D0      PASS
S1.8-F0-F4   CAPTURED / bramble qualification closed
PANTHER-P0   PASS
PANTHER-P0R1 PASS
PANTHER-P1A  PASS
PANTHER-P1B / V0-HOST  IN PROGRESS — Android 17 workspace + audited Pixel generation compatibility; product integration bring-up in progress
PANTHER-V0   NOT STARTED — physical vanilla acceptance after product-build/flashability closure
S1.7 Panther semantic-service port  BLOCKED ON P1B/V0
S1.8 / S1.8C modern UI qualification + first power client  BLOCKED until Panther baseline + S1.7 port
S1.9+        PLANNED
```

S1.7 closed with frozen AIDL V1, dedicated least-privilege client authorization, verified unauthorized-call blocking, physical callback-to-AIDL sequence correlation, natural slot-A success, and preserved successful slot-B fallback. See `S1_7_VALIDATION.md` for the exact seals.

Bramble remains a frozen architecture/regression reference. The previously planned Android 15 bramble portability experiment is closed without execution, and no additional UI-framework dependency down-rev work is required for its AOSP Rust/Cargo 1.68 platform. F4 is the final UI/toolchain evidence record for that branch. Bramble is not an S1.8C production target.

Pixel 7 (`panther`) is the active touch-first development reference on the Android 17 path. P0/P0R1/P1A selected and bounded the reconstruction model; P1B is now exercising that model in `/srv/data/aosp_panther17_workspace` using the stock `CP2A.260705.006` Pixel input and audited generation references. The current host-tool work imports only narrowly reviewed compatibility contracts required by `adevtool`/`arsclib`; GrapheneOS remains a reference/security source and is not the Sable operating-system substrate.

P1B has closed the Node 24/JDK 21 runtime mismatch and AAPT2 dependency closure. Product integration is now proceeding through the official Siso-backed Android build path with bounded source repairs and evidence gates. Physical V0 remains blocked until target-files/AVB/flashability closure.

S1.8 does not assume a renderer in advance. Modern framework qualification includes Slint, WaterUI, Project Robius + Makepad, Blinc, Vexo, Dioxus Native/Blitz, and `BUILD_SABLEUI` if necessary. Framework choice must satisfy both Metro-inspired touch-first and BlackBerry/BB10-inspired keyboard-first directions without fragmenting the common Sable application/service semantic core.

When a selected UI framework requires a newer Rust compiler than the AOSP platform compiler, Sable may use a separately pinned UI compiler but must cross into platform services only through a stable C/NDK/AIDL boundary, never compiler-private cross-version Rust ABI.
