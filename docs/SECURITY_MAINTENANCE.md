# SableOS security maintenance policy

Status: **required project-wide security gate**.

SableOS treats its pinned Android reference builds as reproducibility and compatibility baselines, not as permanent security baselines.

A historical AOSP tag, successful SELinux enforcement, or a narrow Rust service architecture does not prove that the complete device is current against later Android, Linux-kernel, chipset, firmware, browser/WebView, media, vendor, or third-party framework/dependency vulnerabilities.

## Core rule

> A SableOS release must not claim a security patch level or current-security status that its integrated platform, kernel, firmware, vendor components, maintained modules and Sable-owned dependency graph do not actually satisfy.

Security provenance must be evidence-based. Version strings alone are not proof because fixes may be backported without version changes and conversely a high patch-level string can be dishonest if required fixes are absent.

## Security layers

SableOS tracks security independently across at least these layers:

1. AOSP/framework/native platform source;
2. Linux kernel and device kernel modules;
3. device/vendor proprietary binaries and firmware;
4. browser/WebView and independently updatable components/APEX modules;
5. Sable-owned Rust/C/C++ code and dependencies, including selected UI-framework dependencies and any separately pinned UI Rust toolchain;
6. boot chain, AVB/signing, SELinux, seccomp and other platform mitigations.

A release is limited by the weakest unremediated layer.

## Android Security Bulletin intake

The Android Security Bulletin is the canonical monthly intake source for Android platform and Android-relevant kernel vulnerabilities.

For every applicable bulletin item, maintain one of these evidence states:

- `patched` — the fix is integrated and its provenance is recorded;
- `not-affected` — applicability analysis proves the vulnerable code/component is absent or unreachable;
- `mitigated` — the vulnerable component remains but an independently justified mitigation blocks exploitation; this does not automatically equal patched;
- `vendor-unavailable` — the required fix is proprietary and no compatible corrected binary/firmware is available;
- `unknown` — investigation incomplete.

Critical/high remote-code-execution or privilege-escalation issues, known-exploited issues, and vulnerabilities in exposed media/network/radio/kernel surfaces receive priority.

## Patch provenance

Backports must record:

- CVE identifier;
- Android Security Bulletin month/patch level;
- affected component;
- upstream AOSP/kernel/vendor reference when public;
- original upstream commit(s) when available;
- Sable backport commit/patch;
- applicability rationale;
- build/test/physical-regression evidence.

Do not silently edit old source to resemble a newer branch. Maintain an auditable patch queue on top of the pinned baseline.

## Security patch level honesty

Do not advance `ro.build.version.security_patch` merely because some later fixes were cherry-picked.

Only claim an Android security patch level after all issues required for that patch level and applicable to the build have been addressed according to Android's patch-level rules, including relevant device/kernel/vendor requirements.

Until then, Sable may maintain its own security-maintenance date/manifest, but that must not masquerade as an Android SPL.

## Kernel policy

For each device record:

- kernel version and source commit;
- config and module set;
- Android/device kernel branch used as the security-reference upstream;
- relevant Android Security Bulletin kernel CVEs;
- upstream stable/LTS and Android-device backports applied;
- unresolved driver/vendor-kernel risks.

Bramble uses the legacy redbull 4.19 kernel family and is now historical. Later public redbull kernel branches may still be useful as patch-provenance/reference sources, but no current Sable security claim depends on keeping bramble modern.

Panther kernel/vendor provenance must be established by `PANTHER-P0/PANTHER-V0` before the new active baseline is considered security-qualified.

## Proprietary vendor and firmware policy

Closed-source GPU, camera, media, DSP, radio/IMS, Wi-Fi/Bluetooth, firmware, bootloader and other vendor components create a hard security ceiling when the device manufacturer/chipset vendor stops publishing corrected binaries.

For every supported device record:

- exact proprietary component hashes/versions;
- final officially available vendor/firmware baseline;
- known applicable vendor/security-bulletin issues;
- whether a corrected compatible binary exists;
- whether the risk is remediated, isolated, or remains unresolved.

Never represent an end-of-life device with unresolved proprietary vulnerabilities as fully current merely because AOSP and the kernel have been patched.

## Bramble policy

Pixel 4a 5G (`bramble`) is now a frozen architecture/regression reference.

The authoritative Sable bramble baseline is Android 14. Earlier Android 12.1 `SQ3A.220705.003.A1` B0/B1 records remain valuable historical physical-capability and carrier evidence, but they are not the current Sable development target.

Android 14 materially improved the original platform-development substrate and is the frozen reference for the S1.7 service/API boundary. It does **not** remove bramble's proprietary firmware/vendor end-of-life security ceiling.

The previously planned Android 15 bramble portability experiment is closed without execution. Sable will not spend current engineering effort attempting to turn bramble into a maintained-security target or forcing modern UI dependencies onto its Rust/Cargo 1.68 platform.

If future regression archaeology uses bramble, preserve honest status:

- architecture/reference only;
- unsupported OEM firmware/vendor security ceiling;
- no production-security claim;
- no claim that newer Android or Rust versions are required or prevented by the device CPU itself.

## Panther policy

Pixel 7 (`panther`) becomes the active touch-first development reference.

This does not automatically make any arbitrary panther build security-qualified. `PANTHER-P0` and `PANTHER-V0` must establish:

1. exact current stock/restore baseline;
2. reproducible Android/platform source baseline;
3. kernel source/branch and partition model;
4. exact proprietary vendor/firmware provenance;
5. current OEM support status and available security fixes;
6. browser/WebView/updatable-component currency;
7. exact platform Rust/Cargo/Clang/Soong provenance;
8. ordinary Android application compatibility;
9. AVB/bootloader/update/recovery behavior;
10. Sable-owned service/UI dependency provenance.

Prefer the newest supported/reproducible panther Android release. If the newest official stock release is temporarily not reproducible as a clean AOSP hardware baseline, record that gap explicitly rather than pretending an older platform is equally current.

Pixel 7's remaining OEM support lifetime is finite. It is an active engineering improvement over bramble, not the final production-security device. Later Pixel hardware with a longer remaining support window may replace it without changing Sable semantic contracts.

## Maintained-hardware rule

SableOS should maintain at least one security-reference device that is still receiving upstream manufacturer/chipset security updates. Architecture validation on older hardware is useful, but a privacy/security-first project needs an actively supported hardware path for current security claims.

Device-port acceptance must therefore consider security-support lifetime, unlock/relock/verified-boot support, kernel/vendor source availability, firmware update availability, and vendor security-bulletin responsiveness in addition to hardware features.

## Third-party Rust/UI dependency and toolchain policy

Rust-first does not eliminate supply-chain risk. Any Slint, WaterUI, Makepad/Robius, Blinc, Vexo, Dioxus/Blitz, `wgpu`, text/layout/input dependency, fork, or eventual SableUI dependency entering a production image must have:

- pinned source/version/commit provenance;
- license classification compatible with Sable's open-source distribution model;
- reproducible/offline-capable build inputs;
- a bounded dependency inventory;
- security-advisory monitoring;
- a documented update path;
- review of network/filesystem/native/unsafe surface where relevant;
- removal of demo/development/network features not required by the shipped component.

If Sable UI uses a separately pinned Rust compiler rather than the AOSP platform compiler, the UI compiler itself becomes part of the release provenance and security-maintenance inventory.

Do not globally uplift AOSP's Rust compiler solely to satisfy a renderer. Do not directly link independently compiled Rust components across compiler-private Rust ABI. Cross-toolchain integration must use a stable C/NDK/AIDL boundary.

S1.8 framework qualification is the first application of this policy.

## Release gates

Before a security-qualified release:

1. generate a component/security inventory;
2. evaluate Android Security Bulletins since the previous qualified baseline;
3. integrate and provenance-record applicable AOSP fixes;
4. integrate and provenance-record applicable kernel fixes;
5. verify vendor/firmware status;
6. update browser/WebView/updatable components where applicable;
7. review Sable-owned and third-party Rust/UI dependency and compiler advisories/provenance;
8. run Soong/build, SELinux neverallow/policy tests and Sable unit/integration tests;
9. run targeted vulnerability regression tests when a public reproducer/test exists;
10. run physical capability parity and stability checks;
11. verify AVB/signing/boot-chain state appropriate to the release stage;
12. publish an unresolved-risk manifest rather than hiding unsupported components.

A critical unresolved remotely reachable vulnerability or an unresolved security-critical vendor component blocks a claim of a fully security-qualified release unless the vulnerable capability is removed or independently isolated with documented evidence.

## Development versus release

Development builds may intentionally use unlocked bootloaders, `userdebug`, root-capable adbd, test keys, and historical baselines for bring-up. These states must never be confused with production security posture.

A future production SableOS release should use release signing, verified boot and an appropriately locked/relockable boot chain once recovery/update procedures are proven.

## Continuous maintenance

Security maintenance is recurring work, not a one-time audit. Monitor Android Security Bulletins, relevant Linux/kernel/device branches, chipset/vendor advisories, browser/WebView security releases, Sable-owned dependencies, selected UI-framework/dependency advisories, and any separately pinned UI Rust compiler for the lifetime of each supported release.
