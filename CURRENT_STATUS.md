# SableOS current validated Panther status

Last updated: 2026-09-10

The canonical Android/Pixel base for active SableOS Pixel 7 development is the exact signed **GrapheneOS 2026081300** Android 17 release, with audited Sable-specific deltas layered on top.

## Current validated physical state

```text
Pixel 7 / panther
Android 17 / SDK 37
BUILD_ID CP2A.260705.006
BUILD_NUMBER 2026090500
userdebug / test-keys

active slot: B
bootloader: unlocked
verified boot state: orange (expected for unlocked test-key development device)
file-based encryption: enabled
SableOS B2 packaged target-files population: flashed successfully
SableOS B2: booted successfully into Android userspace
shared userdata: preserved through flash
```

The 2026-09-08 D4 B2 validation closed the most important practical milestone: an exact packaged B2 payload derived solely from the bound `panther-target_files.zip` was flashed to the already-active slot B without `-w`, without bootloader unlock, without inactive-slot flashing, and without an intentional userdata/metadata wipe. Fastboot completed successfully, slot B remained active, and Android reached `sys.boot_completed=1`.

The exact packaged B2 target-files SHA-256 used for the physical flash was:

```text
b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78
```

The installed post-boot `BuildManifest.apk` matched the B2 target-files population exactly:

```text
8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

The R10R3 harness itself ended as a bounded failure after boot because its shell `while read ... < expected_b2_art_sha256.tsv` loop allowed `adb` to consume the loop's stdin after the first ART row. This is a **host validation harness defect**, not evidence of a failed flash or failed boot. The phone booted successfully into SableOS and the exact B2 BuildManifest identity was already proven on-device before that harness defect.

## Offline closure reached before physical deployment

The D4 B2 forensic chain now includes:

- **R7R7: fs-verity manifest-input fidelity closed.** All 220 BuildManifest entries were recomputed from their exact named inputs, including target-files symlink semantics. The B2-vs-B1 five-key delta and B2-vs-C2 six-key delta were reproduced exactly.
- **R8R4: ART residual narrowed.** The five remaining B2 ART differences are `ART_ONLY` in both B2-vs-B1 and B2-vs-C2; corresponding ODEX and VDEX siblings are byte-stable. Direct producer records were recovered for B1 and B2. C2 producer Ninja evidence was unavailable, so the exact upstream C2 ART producer cause remains an evidence-boundary item rather than a contradiction.
- **R9: preserved-data flash preflight passed.** Panther identity, slot B, unlocked state, B2 artifact identity, AVB metadata and device readiness were established without reboot or flash.
- **R10R3: packaged B2 flash + boot succeeded.** Target-files was treated as the sole flash image source. Fourteen required images were staged from `IMAGES/`, sealed, verified immediately before mutation, flashed with no wipe flag and no inactive-slot task, and Android booted successfully.

## Current active milestone: D4

D4 remains **Sable identity + default app set + functional acceptance**, but the development process is now transitioning from one-off shell gates to reusable automated validation.

The current D4 state is:

```text
D4 packaged build production         PASS
D4 offline artifact identity         PASS
D4 fs-verity closure                 PASS
D4 exact packaged flash              PASS
D4 post-flash Android boot            PASS
D4 preserved-data flash path          PASS (physical boot confirmed; automated CE/package closure to be rerun under sablectl)
D4 full functional acceptance         OPEN
D4 release-candidate automation       IN PROGRESS
```

The next engineering focus is **`sablectl`**, a host-side Python validation CLI for repeatable SableOS build/device testing. It will replace fragile one-off post-boot shell loops with typed checks, structured evidence, JSON/Markdown/JUnit reports, resumable baselines, and named acceptance suites. A later **SableTestAgent APK** will extend automation to device-side camera, sensors, audio, location, WebView, notification, storage and lifecycle testing through Android instrumentation.

## Non-Pixel / MediaTek planning

No non-Pixel device is currently declared a supported SableOS production target.

The September 2026 Brax3/iodéOS source review established a formal non-Pixel architecture and refined the device roadmap without changing Panther's priority or active build state.

Current planning order:

```text
1. Pixel 7 / panther
   canonical full-stack SableOS development target

2. Unihertz Titan 2
   preferred interim N0 GSI/userspace/UI development lab

3. Zinwa Q27
   preferred future full physical-QWERTY candidate if shipped hardware qualifies

4. Zinwa Q25
   optional source-available MediaTek/kernel/device research platform
```

Non-Pixel assurance classes are now explicit:

```text
N0_GSI_USERSPACE_LAB
N1_INTEGRATED_VENDOR_BSP_PORT
N2_PRODUCTION_QUALIFIED
```

A booting GSI does not imply production device support. Titan 2 would initially reuse its stock kernel/vendor/firmware stack and therefore be classified as development-only. Q25 remains useful when source-level kernel/device experimentation is specifically required. Q27 must independently qualify kernel/BSP/vendor/firmware, AVB/relock, radio/IMS/5G, recovery/update behavior and security lifecycle before any production-support decision.

The reviewed Brax3 implementation demonstrates that a modern Android userspace can be maintained above a proprietary MediaTek BSP and prebuilt kernel/module set, but it also reinforces that kernel, vendor, modem, TEE, bootloader and firmware security provenance remain separate support obligations.

See:

- `docs/NON_PIXEL_MEDIATEK_ARCHITECTURE.md`
- `docs/NON_PIXEL_DEVICE_ROADMAP.md`
- `docs/TITAN2_GSI_PLAN.md`
- `docs/Q25_PORT_PLAN.md`
- `docs/NON_PIXEL_RELEASE_VALIDATION.md`
- `docs/BRAX3_IODEOS_REFERENCE.md`

## D4 physical acceptance matrix

D4 minimum physical acceptance includes outgoing/incoming voice calls, outgoing/incoming SMS, cellular data and Wi-Fi. The broader target matrix covers MMS/IMS where carrier support permits, hotspot, Bluetooth, audio, camera, location, NFC, USB, sensors, biometrics, APK install, permissions, browser/WebView, notifications, charging/power and persistence. No live emergency-services call is part of normal ROM sanity testing.

Automation policy going forward:

- automate deterministic host/ADB checks first;
- keep physical/manual checkpoints only where Android or external hardware makes automation unreliable;
- collect every run as machine-readable evidence;
- distinguish `PASS`, `FAIL`, `SKIP`, `MANUAL`, and `ERROR` rather than collapsing all non-zero outcomes;
- separate collection, checking, suites, mutating actions and reporting;
- require explicit authorization for reboot/flash/wipe-capable actions;
- prefer target-files as the packaged build source of truth for release validation.

## Start here

- `docs/PANTHER_D4_ROADMAP.md` — current Panther D4 scope and post-D4 release roadmap.
- `docs/PANTHER_D4_R0_PLAN.md` — original D4-R0 read-only audit and functional-baseline plan.
- `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` — clean source/vendor/delta/build procedure.
- `docs/PANTHER_D3_VALIDATION.md` — exact D3 build/artifact/physical validation record.
- `docs/SABLECTL_PLAN.md` — host-side validation CLI architecture and staged delivery plan.
- `docs/SABLETEST_AGENT_PLAN.md` — test-only Android instrumentation agent plan.
- `docs/NON_PIXEL_DEVICE_ROADMAP.md` — current non-Pixel hardware strategy and assurance ordering.
- `patches/android-17-grapheneos-2026081300/` — exact text delta applicator, source/head seals, changed-file inventory and binary-asset SHA-256 manifest.

Historical pure-AOSP Panther bring-up records remain useful forensic evidence, but `/srv/data/aosp_panther17_workspace` is no longer the canonical SableOS Android/Pixel substrate.