# SableOS current validated Panther status

Last updated: 2026-09-08

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
exact post-boot BuildManifest identity: PASS
exact post-boot ART identity: PASS_5_OF_5
initial sablectl smoke: PASS_16_OF_16
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

The historical R10R3 harness itself ended as a bounded failure after boot because its shell `while read ... < expected_b2_art_sha256.tsv` loop allowed `adb` to consume the loop's stdin after the first ART row. This is a **host validation harness defect**, not evidence of a failed flash or failed boot.

That exact post-boot gap is now closed by `sablectl`.

## sablectl live Panther validation

The first live `sablectl verify boot` run against the packaged B2 target-files completed:

```text
PASS=11 FAIL=0 SKIP=0 MANUAL=0 ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/verify-boot/20260908T181140Z
```

It proved:

- device codename `panther`;
- `sys.boot_completed=1`;
- active slot `_b`;
- encrypted data state;
- exact installed BuildManifest match;
- all five D4 residual ART images match the exact packaged B2 bytes;
- aggregate `artifact.art.count expected=5 actual=5`.

The immediately following `sablectl smoke` run completed:

```text
PASS=16 FAIL=0 SKIP=0 MANUAL=0 ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/smoke/20260908T181212Z
```

Additional runtime smoke proved:

```text
SELinux=Enforcing
servicemanager=running
surfaceflinger=running
zygote=running
PackageManager=PASS installed_packages=229
```

This is the first reusable SableOS automated physical validation result and supersedes the R10R3 post-boot shell aggregate defect.

## Offline closure reached before physical deployment

The D4 B2 forensic chain now includes:

- **R7R7: fs-verity manifest-input fidelity closed.** All 220 BuildManifest entries were recomputed from their exact named inputs, including target-files symlink semantics. The B2-vs-B1 five-key delta and B2-vs-C2 six-key delta were reproduced exactly.
- **R8R4: ART residual narrowed.** The five remaining B2 ART differences are `ART_ONLY` in both B2-vs-B1 and B2-vs-C2; corresponding ODEX and VDEX siblings are byte-stable. Direct producer records were recovered for B1 and B2. C2 producer Ninja evidence was unavailable, so the exact upstream C2 ART producer cause remains an evidence-boundary item rather than a contradiction.
- **R9: preserved-data flash preflight passed.** Panther identity, slot B, unlocked state, B2 artifact identity, AVB metadata and device readiness were established without reboot or flash.
- **R10R3: packaged B2 flash + boot succeeded.** Target-files was treated as the sole flash image source. Fourteen required images were staged from `IMAGES/`, sealed, verified immediately before mutation, flashed with no wipe flag and no inactive-slot task, and Android booted successfully.
- **sablectl v0.1: exact post-boot identity + initial runtime smoke closed.** BuildManifest and all five ART files match packaged B2 exactly; SELinux and core runtime services are healthy.

## Current active milestone: D4

D4 remains **Sable identity + default app set + functional acceptance**, but the development process is now transitioning from one-off shell gates to reusable automated validation.

The current D4 state is:

```text
D4 packaged build production         PASS
D4 offline artifact identity         PASS
D4 fs-verity closure                 PASS
D4 exact packaged flash              PASS
D4 post-flash Android boot           PASS
D4 exact post-boot artifact identity PASS
D4 initial automated smoke           PASS_16_OF_16
D4 preserved-data flash path         PASS physically; future comparisons use pre-flash sablectl baselines
D4 full functional acceptance        OPEN
D4 release-candidate automation      IN PROGRESS
```

The next engineering focus is expanding **`sablectl`** from the validated v0.1 boot/smoke foundation into the D4 automated acceptance suite. A later **SableTestAgent APK** will extend automation to device-side camera, sensors, audio, location, WebView, notification, storage and lifecycle testing through Android instrumentation.

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
- `docs/PANTHER_D4_B2_PHYSICAL_VALIDATION.md` — exact B2 packaged flash, boot and post-boot sablectl closure.
- `docs/PANTHER_D4_R0_PLAN.md` — original D4-R0 read-only audit and functional-baseline plan.
- `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` — clean source/vendor/delta/build procedure.
- `docs/PANTHER_D3_VALIDATION.md` — exact D3 build/artifact/physical validation record.
- `docs/SABLECTL_PLAN.md` — host-side validation CLI architecture and staged delivery plan.
- `docs/SABLETEST_AGENT_PLAN.md` — test-only Android instrumentation agent plan.
- `patches/android-17-grapheneos-2026081300/` — exact text delta applicator, source/head seals, changed-file inventory and binary-asset SHA-256 manifest.

Historical pure-AOSP Panther bring-up records remain useful forensic evidence, but `/srv/data/aosp_panther17_workspace` is no longer the canonical SableOS Android/Pixel substrate.
