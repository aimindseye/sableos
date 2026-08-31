# S1.8 platform transition: bramble closure and panther restart

Status: **BRAMBLE CLOSED / PANTHER ANDROID 17 HOST BRING-UP IN PROGRESS**.

## Decision

S1.8 framework work will no longer continue on Pixel 4a 5G (`bramble`) Android 14 solely to satisfy the branch's Rust/Cargo 1.68 toolchain.

The bramble program closes with:

- S1.7 overall PASS/FROZEN as the authoritative architecture/runtime seal;
- S1.8 D0 documentation reconciliation PASS;
- S1.8 F0/F1/F2/F3/F4 qualification evidence retained;
- no S1.8 production UI source landed on bramble;
- no global AOSP Rust uplift performed;
- no Android 15 bramble portability experiment required;
- no further Slint-1.5-on-Rust-1.68 dependency pinning/backport work required.

Normative decision: `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.

Final bramble UI/toolchain evidence: `S1_8_BRAMBLE_UI_QUALIFICATION_FINAL.md`.

## What the bramble UI experiment proved

The framework probes were useful despite not selecting a renderer.

1. The limitation was the Android 14 AOSP toolchain, not Pixel 4a 5G's CPU architecture.
2. The frozen bramble tree uses AOSP Rust/Cargo 1.68.
3. Current Rust UI frameworks have moved substantially beyond that toolchain.
4. Slint 1.5 core can compile on Rust 1.68 after bounded Cargo compatibility adjustments, proving that the framework was not fundamentally blocked by the device architecture.
5. F4 then showed the public Slint path entering successive transitive dependency compiler floors: after resolving Cargo-1.68 `fontdb` behavior and pinning `codemap-diagnostic` to 0.1.1, the next blocker was `toml_edit 0.21.1` requiring Rust 1.69.
6. Continuing to down-rev and pin modern UI-framework dependencies for an end-of-life Android baseline would make historical platform constraints drive Sable product architecture.
7. Current Vexo and other modern candidates also demonstrate that framework qualification should happen against a newer platform or a separately pinned UI compiler.
8. The S1.7 frozen semantic service boundary gives Sable a clean mechanism to decouple UI evolution from hardware/service implementation.

## Bramble final role

Pixel 4a 5G remains useful for:

- reproducing the frozen Android 14 S1.7 service/API architecture;
- regression archaeology;
- validating historical physical callback/slot behavior when specifically needed;
- comparison against later adapters.

It is not:

- the active S1.8 development target;
- the long-term security reference;
- a framework-selection constraint;
- a required Rust-development device;
- scheduled for an Android 15 Sable portability port;
- an S1.8C production implementation target.

A later Bramble observation or inventory gate may be retained as historical/regression evidence, but it does not reopen production development on that device.

## Panther role and selected baseline

Pixel 7 (`panther`) is the active touch-first development reference.

`PANTHER-P0`, `PANTHER-P0R1`, and `PANTHER-P1A` have now passed. The active reconstruction path is Android 17 with:

```text
device: panther / Pixel 7
Android: 17 / SDK 37
stock Pixel baseline: CP2A.260705.006
active host workspace: /srv/data/aosp_panther17_workspace
```

The base platform remains AOSP. GrapheneOS is used as a signed/pinned reference for Pixel-generation tooling, security engineering, and narrowly reviewed compatibility contracts; it is not adopted as the Sable OS substrate.

The current P1B host work is recorded in `PANTHER_P1B_ANDROID17_HOST_BRINGUP.md`.

## Current P1B execution status

The Android 17 workspace is active and controlled Pixel-generation work is in progress.

Closed host/runtime compatibility boundaries include:

- isolated Node 24 runtime required by `adevtool`;
- Android 17 JDK 21 child-tool runtime;
- AAPT2 host proto module required by the dependency graph;
- Graphene stringified resource-configuration contract;
- AAPT2 `dump brief-package-info --sdk-version` contract plus library field;
- ApkSigner `print-certs` contract under JDK 21.

Controlled `generate-all -d panther -v` has progressed through properties, file enumeration, sepolicy, overlays, presigned-app processing, blob copying, VINTF extraction, and firmware extraction without regression of those earlier blockers.

The current arsclib/AAPT2 boundary is the optimized `proto-adevtool` conversion contract. Its diagnostic closure is PASS; the complete repair gate is not promoted to PASS in the project record until its full source/build/runtime evidence is recorded.

The generated Panther vendor tree is still partial. FileTreeSpec verification, final generated-vendor acceptance, the vanilla Panther product build, and physical V0 acceptance remain open.

## UI framework reset

The S1.8 framework decision is reopened on the modern Panther baseline.

Qualification set:

- Slint;
- WaterUI;
- Project Robius + Makepad;
- Blinc;
- Vexo;
- Dioxus Native / Blitz;
- `BUILD_SABLEUI` if no candidate meets Sable requirements without disproportionate compromise.

Architectural references/tools:

- Crux: renderer-independent core/state/effect architecture;
- UniFFI: possible in-process Rust/Kotlin/Swift interop, not a shell renderer;
- Flutter Rust Bridge: Flutter/Rust interop, not a Rust-first renderer;
- Tauri: not preferred for the Sable system shell because the WebView/origin/IPC model adds an unnecessary system-shell trust surface.

Framework selection must consider:

- Metro-inspired touch-first interaction quality;
- BlackBerry/BB10-inspired physical-QWERTY interaction quality;
- shared semantic/application core across both profiles;
- multi-touch;
- keyboard/focus/traversal;
- IME/clipboard;
- accessibility;
- text shaping/localization;
- Android Activity/surface/lifecycle fit;
- SurfaceFlinger/GPU integration;
- performance, memory and idle power;
- offline/reproducible dependency integration;
- license and security provenance;
- Android-version portability;
- no renderer-specific privilege expansion.

## Rust toolchain rule

Do not make framework selection depend on whichever Rust compiler happens to be integrated into one Android branch.

Same-toolchain integration remains preferred because it permits direct use of generated Rust AIDL bindings.

If the chosen modern UI framework requires a newer separately pinned Rust toolchain:

```text
modern Rust UI
    -> stable C/NDK/AIDL adapter
    -> Sable semantic service
```

Do not directly link independently compiled Rust components across compiler-private Rust ABI.

Do not globally uplift AOSP's Rust compiler solely for UI convenience.

## Android application compatibility

The transition preserves the Android application model unchanged:

- APK/split APK;
- PackageManager/PackageInstaller;
- ART/DEX;
- ActivityManager;
- Binder;
- Android application UID/SELinux sandbox;
- runtime permissions/PermissionController;
- AppOps;
- intents/components;
- F-Droid/direct APK/other compatible stores;
- future optional sandboxed Google compatibility.

Sable's own Rust renderer is a presentation choice, not a replacement Android application runtime.

## Interaction profiles

Pixel-class devices remain the reference for the Metro-inspired touch profile.

Zinwa Q25/Q27-class devices remain the intended BlackBerry/BB10-inspired keyboard-first profile.

The panther transition must strengthen, not weaken, the requirement that both profiles share one Sable application/service semantic core.

## S1.8C sequencing guard

S1.8C is a Panther/Android-17 milestone, not a Bramble milestone.

It must not start by bypassing unfinished platform/service gates. Required order:

```text
PANTHER-P0 / P0R1 / P1A
PASS
      |
      v
PANTHER-P1B / V0-HOST
Android 17 workspace + audited Pixel generation
      |
      +-- complete vendor generation
      +-- FileTreeSpec verification
      +-- generated-vendor / GrapheneOS-hook audit
      +-- vanilla Panther product build
      |
      v
PANTHER-V0
vanilla hardware + Android app compatibility acceptance
      |
      v
S1.7 semantic service port to Panther
qualify Android 17 / GS201 Health AIDL adapter
preserve frozen PowerSnapshot / V1 semantics
      |
      v
S1.8 / S1.8C
modern Rust UI qualification + first standalone power client
      |
      v
S1.9 lifecycle
```

The first production S1.8C client remains a consumer of the frozen semantic service. It must not gain direct Health HAL access, battery-sysfs access, or shell/Binder-command shortcuts.

No implementation source mutation, image build, flash or device state change is implied by this documentation update itself.
