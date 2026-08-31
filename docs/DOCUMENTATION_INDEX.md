# SableOS Documentation Index

## Normative Architecture / Policy

These documents define the current project architecture. When an older concept note or historical validation record conflicts with an accepted ADR or a normative document, the normative/ADR decision takes precedence.

- `ARCHITECTURE.md` — platform layering, service boundaries, privilege placement, device separation.
- `SECURITY_MODEL.md` — trust boundaries, IPC policy, SELinux/service-manager rules.
- `AOSP_CAPABILITY_POLICY.md` — preserve mature Android/vendor capability unless a reviewed replacement is justified.
- `APP_SECURITY_AND_COMPATIBILITY.md` — standard Android APK/ART/PackageManager compatibility and Secure Package Intelligence direction.
- `ANDROID_VERSION_PORTABILITY.md` — stable Sable semantics across Android substrate changes.
- `INTERACTION_PROFILES.md` — common application semantics with touch-first and keyboard-first interaction profiles.
- `SECURITY_MAINTENANCE.md` — platform/kernel/vendor/browser/security-update provenance and release claims.
- `adr/0001-mobile-ux-with-strict-privilege-separation.md` — UX remains separate from hardware/system privilege.
- `adr/0002-rust-ui-framework-and-android-app-compatibility.md` — Rust UI qualification, Android APK coexistence, Metro-inspired touch and BlackBerry-inspired keyboard profiles, Slint/Vexo/SableUI decision model.

## Planning

- `ROADMAP.md` — completed, current and planned milestones.
- `Q25_PORT_PLAN.md` — optional MediaTek/QWERTY reference-port plan.

## Engineering / Release

- `ENGINEERING_PRINCIPLES.md` — measurement, architecture correction, negative testing, recovery discipline.
- `RELEASE_VALIDATION.md` — build, image, AVB, flashing, runtime and slot-closure gates.

## Frozen Validation / Evidence

Validation records document the architecture and evidence applicable to their milestone. They are historical evidence, not a license to revive superseded design assumptions.

- `S1_7_VALIDATION.md` — frozen Power AIDL V1 source/image/device/runtime seal and physical acceptance record.
- `S0_*`, `S1_*`, `B1_*`, `B2_*` — milestone-specific build/runtime evidence.
- `G025E_HARDWARE_ACCEPTANCE.md` — bramble safe-flash and physical capability history.

## External Reference Notes

- `EXTERNAL_LESSONS.md` — MarathonOS/Marathon Shell lessons and resulting Sable decisions.
- `SECURITY_REFERENCE_GRAPHENEOS.md` — GrapheneOS security-engineering lessons adapted to Sable boundaries.
- App Manager is a design reference for the Secure Package Intelligence work described in `APP_SECURITY_AND_COMPATIBILITY.md`; its privileged/root application model is not the Sable platform trust model.

## Current Milestone Snapshot

```text
S1.6   PASS
S1.7A  PASS
S1.7B  PASS
S1.7   PASS / FROZEN
S1.8   D0/F0 — architecture reconciliation + Rust UI framework qualification
A15-P  after S1.8, before S1.9
S1.9+  PLANNED
```

S1.7 closed with frozen AIDL V1, dedicated least-privilege client authorization, verified unauthorized-call blocking, physical callback-to-AIDL sequence correlation, natural slot-A success, and preserved successful slot-B fallback. See `S1_7_VALIDATION.md` for the exact seals.

S1.8 does not assume a renderer in advance. Slint and Vexo are qualification candidates; a focused fork or Sable-owned Rust UI framework remains an allowed outcome if evidence shows that neither upstream framework meets Sable's Android integration, touch, keyboard, accessibility, security, reproducibility and portability requirements.
