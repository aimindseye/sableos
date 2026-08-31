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
5. Sable-owned Rust/C/C++ code and dependencies, including selected UI-framework dependencies;
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

Bramble uses the legacy redbull 4.19 kernel family. Later public redbull kernel branches may be used as patch-provenance/reference sources, but kernel replacement or large rebases require the same physical capability and boot/security validation as other hardware-foundation changes.

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

The current Sable architecture/regression baseline on bramble is Android 14. Earlier Android 12.1 `SQ3A.220705.003.A1` B0/B1 records remain valuable historical physical-capability and carrier evidence, but they are no longer the current Sable system baseline.

Android 14 materially improves the platform-development substrate and is the frozen reference for the S1.7 service/API boundary. It does **not** remove bramble's proprietary firmware/vendor end-of-life security ceiling.

Before SableOS is considered a secure daily-driver on bramble, a separate security-uplift program must evaluate at minimum:

1. the exact final officially available bramble vendor/firmware baseline actually integrated or intentionally retained;
2. AOSP security fixes published after the selected Android 14 reference baseline;
3. redbull 4.19 kernel security backports;
4. browser/WebView and Mainline/updatable-component currency;
5. remaining Qualcomm/Google proprietary vulnerabilities for which no post-EOL fix is available;
6. Sable-owned Rust/UI dependency advisories and reproducible provenance.

The planned Android 15 bramble exercise after S1.8 is a portability experiment, not a mechanism for claiming restored OEM security maintenance.

If unresolved proprietary risk remains because bramble is end-of-life, bramble remains an architecture/reference target rather than SableOS's strongest security-reference hardware.

## Maintained-hardware rule

SableOS should maintain at least one security-reference device that is still receiving upstream manufacturer/chipset security updates. Architecture validation on older hardware is useful, but a privacy/security-first project needs an actively supported hardware path for current security claims.

Device-port acceptance must therefore consider security-support lifetime, unlock/relock/verified-boot support, kernel/vendor source availability, firmware update availability, and vendor security-bulletin responsiveness in addition to hardware features.

## Third-party Rust/UI dependency policy

Rust-first does not eliminate supply-chain risk. Any Slint, Vexo, `wgpu`, text/layout/input dependency, fork, or eventual SableUI dependency entering a production image must have:

- pinned source/version/commit provenance;
- license classification compatible with Sable's open-source distribution model;
- reproducible/offline-capable build inputs;
- a bounded dependency inventory;
- security-advisory monitoring;
- a documented update path;
- review of network/filesystem/native/unsafe surface where relevant;
- removal of demo/development/network features not required by the shipped component.

S1.8-F0 is the first application of this policy to UI-framework qualification.

## Release gates

Before a security-qualified release:

1. generate a component/security inventory;
2. evaluate Android Security Bulletins since the previous qualified baseline;
3. integrate and provenance-record applicable AOSP fixes;
4. integrate and provenance-record applicable kernel fixes;
5. verify vendor/firmware status;
6. update browser/WebView/updatable components where applicable;
7. review Sable-owned and third-party Rust/UI dependency advisories/provenance;
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

Security maintenance is recurring work, not a one-time audit. Monitor Android Security Bulletins, relevant Linux/kernel/device branches, chipset/vendor advisories, browser/WebView security releases, Sable-owned dependencies and selected UI-framework/dependency advisories for the lifetime of each supported release.
