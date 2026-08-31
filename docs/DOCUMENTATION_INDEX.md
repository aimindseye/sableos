# SableOS Documentation Index

## Normative Architecture / Policy

These documents define the current project architecture. When an older concept note or historical validation record conflicts with an accepted ADR or a normative document, the normative/ADR decision takes precedence.

- `ARCHITECTURE.md` — platform layering, service boundaries, privilege placement, device separation.
- `SECURITY_MODEL.md` — trust boundaries, IPC policy, SELinux/service-manager rules.
- `AOSP_CAPABILITY_POLICY.md` — preserve mature Android/vendor capability unless a reviewed replacement is justified.
- `APP_SECURITY_AND_COMPATIBILITY.md` — standard Android APK/ART/PackageManager compatibility and Secure Package Intelligence direction.
- `ANDROID_VERSION_PORTABILITY.md` — stable Sable semantics across Android substrate, device and compiler changes.
- `INTERACTION_PROFILES.md` — common application semantics with touch-first and keyboard-first interaction profiles.
- `SECURITY_MAINTENANCE.md` — platform/kernel/vendor/browser/security-update provenance and release claims.
- `adr/0001-mobile-ux-with-strict-privilege-separation.md` — UX remains separate from hardware/system privilege.
- `adr/0002-rust-ui-framework-and-android-app-compatibility.md` — Rust UI qualification, Android APK coexistence, Metro-inspired touch and BlackBerry-inspired keyboard profiles, framework/fork/SableUI decision model.
- `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md` — move active development from bramble to Pixel 7, close the bramble A15/UI-backport path, and decouple modern UI Rust toolchains from platform Rust through stable ABI boundaries when necessary.

## Planning

- `ROADMAP.md` — completed, current and planned milestones.
- `Q25_PORT_PLAN.md` — optional MediaTek/QWERTY reference-port plan.
- `S1_8_PLATFORM_TRANSITION.md` — bramble S1.8 qualification closure and panther restart sequence.

## Engineering / Release

- `ENGINEERING_PRINCIPLES.md` — measurement, architecture correction, negative testing, recovery discipline.
- `RELEASE_VALIDATION.md` — build, image, AVB, flashing, runtime and slot-closure gates.

## Frozen Validation / Evidence

Validation records document the architecture and evidence applicable to their milestone. They are historical evidence, not a license to revive superseded design assumptions.

- `S1_7_VALIDATION.md` — frozen Power AIDL V1 source/image/device/runtime seal and physical acceptance record on bramble Android 14.
- `S1_8_D0_F0_QUALIFICATION.md` — bramble D0/F0-F3 architecture/toolchain evidence leading to the platform transition.
- `S1_8_BRAMBLE_UI_QUALIFICATION_FINAL.md` — final F4 closure: Slint 1.5 core proven on Rust 1.68 with bounded compatibility work, public API then blocked by another transitive compiler floor (`toml_edit 0.21.1` requiring Rust 1.69), confirming that further dependency down-rev work should stop.
- `PANTHER_P0_VALIDATION.md` — Pixel 7 Android-17 physical/source/toolchain inventory; Android 17 selected as preferred reconstruction candidate, with Android 15 retained as the official-Google-publication fallback.
- `S0_*`, `S1_*`, `B1_*`, `B2_*` — milestone-specific build/runtime evidence.
- `G025E_HARDWARE_ACCEPTANCE.md` — bramble safe-flash and physical capability history.

## External Reference Notes

- `EXTERNAL_LESSONS.md` — MarathonOS/Marathon Shell lessons and resulting Sable decisions.
- `SECURITY_REFERENCE_GRAPHENEOS.md` — GrapheneOS security-engineering lessons adapted to Sable boundaries.
- App Manager is a design reference for the Secure Package Intelligence work described in `APP_SECURITY_AND_COMPATIBILITY.md`; its privileged/root application model is not the Sable platform trust model.
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
PANTHER-P0R1 NEXT — Android 17 source/vendor/kernel reconstruction qualification
PANTHER-V0   PLANNED after accepted panther source baseline
S1.8 modern Rust UI qualification + first power client  after panther baseline
S1.9+        PLANNED
```

S1.7 closed with frozen AIDL V1, dedicated least-privilege client authorization, verified unauthorized-call blocking, physical callback-to-AIDL sequence correlation, natural slot-A success, and preserved successful slot-B fallback. See `S1_7_VALIDATION.md` for the exact seals.

Bramble remains a frozen architecture/regression reference. The previously planned Android 15 bramble portability experiment is closed without execution, and no additional UI-framework dependency down-rev work is required for its AOSP Rust/Cargo 1.68 platform. F4 is the final UI/toolchain evidence record for that branch.

Pixel 7 (`panther`) is the active touch-first development reference. P0 confirmed the physical device is on Android 17 with enforcing SELinux and showed that Android 17 AOSP uses a modern Rust toolchain, while Google's old public `device/google/pantah` / downloadable-driver publication model stops at Android 15. Android 17 remains the preferred Sable candidate because current public external evidence proves panther Android-17 hardware builds are possible; `PANTHER-P0R1` must now qualify the minimum auditable source/vendor/kernel reconstruction path before a workspace is created or any flash is attempted.

S1.8 does not assume a renderer in advance. Modern framework qualification includes Slint, WaterUI, Project Robius + Makepad, Blinc, Vexo, Dioxus Native/Blitz, and `BUILD_SABLEUI` if necessary. Framework choice must satisfy both Metro-inspired touch-first and BlackBerry/BB10-inspired keyboard-first directions without fragmenting the common Sable application/service semantic core.

When a selected UI framework requires a newer Rust compiler than the AOSP platform compiler, Sable may use a separately pinned UI compiler but must cross into platform services only through a stable C/NDK/AIDL boundary, never compiler-private cross-version Rust ABI.
