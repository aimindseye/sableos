# Panther D4 roadmap — Sable identity, default apps and functional acceptance

Date: 2026-09-08

Baseline: Pixel 7 (`panther`), Android 17 / GrapheneOS `2026081300` substrate, SableOS D4 B2 packaged population physically flashed and booted successfully on slot B with shared userdata preserved.

D3 is closed. D4 has now passed the build, packaged-artifact, exact-flash, Android-boot, exact post-boot artifact-identity and initial runtime smoke gates. The active D4 work is **expanded automated functional acceptance and release-candidate evidence**, not basic flashability or boot identity.

## Current D4 status

```text
D4-R0 package/provenance + functional baseline        CLOSED
D4-R1 combined mutation scope                         CLOSED FOR CURRENT B2
D4-B1/B2 build + packaged target-files               PASS
R7R7 fs-verity named-input fidelity                   PASS / CLOSED
R8 ART residual classification                        PARTIAL CLOSURE / EVIDENCE BOUNDARY
R9 preserved-data flash preflight                     PASS
R10R3 exact packaged B2 flash                         PASS
R10R3 Android boot                                    PASS
R10R3 exact installed BuildManifest identity          PASS
R10R3 shell post-boot ART aggregate                   SUPERSEDED HARNESS DEFECT
sablectl exact post-boot BuildManifest                PASS
sablectl exact post-boot ART aggregate                PASS_5_OF_5
sablectl verify-boot                                  PASS_11_OF_11
sablectl smoke                                        PASS_16_OF_16
D4-V1 automated functional acceptance                 ACTIVE
D4-R2 final closure                                   OPEN
```

The exact packaged B2 target-files used for physical deployment was:

```text
panther-target_files.zip
sha256=b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78
```

The installed post-boot BuildManifest identity was:

```text
/system/etc/security/fsverity/BuildManifest.apk
sha256=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

## D4 operating rules

The canonical Android/Pixel substrate remains GrapheneOS `2026081300`. Sable changes are bounded deltas on top.

For historical Sable work:

```text
needed + clean on current base       -> PORT
needed + incompatible old design     -> REDESIGN
obsolete workaround                  -> DROP
independent Sable project            -> RETAIN / ADAPT / INTEGRATE
```

Do not globally rename GrapheneOS internal package/API identifiers. Do not relabel Graphene-operated services, URLs or infrastructure as Sable until Sable owns a truthful replacement.

Important app-removal rule:

```text
REMOVE_USER_FACING_GRAPHENE_DEFAULTS
!=
REMOVE_GRAPHENE_PLATFORM_DEPENDENCIES
```

## D4-R0 — read-only baseline and provenance audit

Status: **CLOSED for the current B2 path**.

The R0 model remains normative for future app-removal batches: capture package provenance, roles/defaults, product inheritance, overlays, privileged permissions, SELinux references, SetupWizard/Settings dependencies, WebView/browser relationships and user-visible Graphene ownership before mutation.

Candidate applications/components remain classified as:

```text
KEEP_REQUIRED_PLATFORM_COMPONENT
KEEP_TEMPORARILY
REMOVE_FROM_SABLE_DEFAULT
REPLACE_WITH_SABLE_COMPONENT
REQUIRES_DEPENDENCY_FORENSICS
```

## D4-R1 / B1 / B2 — combined mutation and build

Status: **CURRENT B2 BUILD PASS**.

The current B2 population was generated from the canonical workspace and reached exact target-files identity, fs-verity named-input closure and physical deployment.

Important evidence chain:

```text
source/config
    -> build graph / dexpreopt
    -> packaged files
    -> fs-verity BuildManifest named inputs
    -> target_files.zip
    -> staged exact flash payload
    -> physical slot B
    -> Android userspace boot
    -> exact installed BuildManifest
    -> exact installed five ART residuals
    -> initial runtime smoke
```

### R7R7 — fs-verity boundary closed

All 220 BuildManifest entries were recomputed from their exact named input files. Target-files symlink semantics were handled explicitly. The B2-vs-B1 five-key delta and B2-vs-C2 six-key delta were reproduced exactly.

### R8 — ART residual narrowed

The five residual ART differences are `ART_ONLY` in both B2-vs-B1 and B2-vs-C2: the matching ODEX and VDEX siblings are byte-stable. Direct producer records were recovered for B1 and B2. C2 no longer retains the necessary Ninja producer graph, so exact C2 upstream producer causality remains an evidence-availability boundary rather than a contradiction.

### R9 / R10R3 — physical deployment

R9 established:

- physical product `panther`;
- active slot `_b`;
- bootloader already unlocked;
- file-based encryption enabled;
- exact B2 artifact readiness;
- no wipe or unlock requirement.

R10R3 then:

- treated `B2_TARGET_FILES!IMAGES/` as the sole flash image source;
- staged 14 exact images under a temporary evidence directory;
- rejected wipe, userdata/metadata, and inactive-slot directives;
- sealed the payload and reverified it immediately before mutation;
- flashed current slot B with no `-w` and no inactive-slot image task;
- kept slot B active;
- booted successfully into Android userspace;
- proved the installed BuildManifest exactly matches B2.

The historical R10R3 script ended `BOUNDED_FAIL` only because an `adb` child inherited the shell loop stdin while validating the five ART rows. That child consumed the remaining TSV records after row one. This is now a superseded host-harness defect: `sablectl` subsequently proved all five ART files match the packaged B2 population exactly.

### sablectl v0.1 — live Panther closure

The first live `sablectl verify boot` run completed:

```text
PASS=11 FAIL=0 SKIP=0 MANUAL=0 ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/verify-boot/20260908T181140Z
```

It verified:

- device codename `panther`;
- `sys.boot_completed=1`;
- active slot `_b`;
- encrypted data state;
- exact installed BuildManifest SHA-256;
- all five D4 residual ART files byte-for-byte against target-files;
- explicit aggregate `artifact.art.count expected=5 actual=5`.

The immediately following `sablectl smoke` run completed:

```text
PASS=16 FAIL=0 SKIP=0 MANUAL=0 ERROR=0
OVERALL=PASS
REPORT_DIR=.sablectl/runs/smoke/20260908T181212Z
```

Additional checks proved:

- SELinux `Enforcing`;
- `servicemanager` running;
- `surfaceflinger` running;
- `zygote` running;
- PackageManager responding with 229 installed packages.

## D4-V1 — automated physical phone functional acceptance

Status: **ACTIVE**.

A successful boot remains insufficient for D4 closure. The acceptance matrix is now split into three classes:

```text
AUTOMATED_HOST_ADB
AUTOMATED_DEVICE_AGENT
MANUAL_PHYSICAL
```

### Automated host/ADB checks — `sablectl`

v0.1 live-validated scope:

- host/ADB doctor;
- single-device serial pinning;
- baseline capture;
- exact target-files BuildManifest identity;
- exact five ART image identity;
- boot completion;
- expected slot;
- encryption state;
- SELinux enforcing;
- core service health;
- PackageManager health;
- credential-encrypted data availability;
- exact third-party package-set preservation;
- Android user-count preservation;
- terminal + JSON + Markdown + JUnit evidence.

Current live proof:

```text
sablectl doctor=PASS
sablectl device wait=PASS
sablectl verify-boot=PASS_11_OF_11
sablectl smoke=PASS_16_OF_16
```

The next live automation step is to capture a B2 baseline and use it as the reference for all subsequent deployment cycles. Because that baseline is post-B2, it must not be used to retroactively claim a pre-B2 package/user comparison for the already-completed flash.

Planned v0.2 host automation:

- crash/ANR/tombstone audit;
- Wi-Fi state and reconnect;
- connectivity/default network;
- cellular registration/data;
- IMS state where observable;
- Bluetooth adapter/service state;
- USB/ADB health;
- battery/charging and Sable power-service checks;
- WebView provider and package/default-role checks;
- package install/launch test;
- notification host-observable sanity;
- reboot/persistence suite;
- D4 named suite and release-gate summary.

### Automated device-agent checks — SableTestAgent

A later test-only instrumentation APK will exercise Android APIs directly for checks that host-side `dumpsys` cannot prove reliably:

- camera capture;
- sensors;
- location;
- audio playback/record;
- notification delivery;
- WebView rendering/navigation;
- device-protected and credential-protected storage;
- lifecycle/service behavior;
- selected permission flows;
- optional NFC/Bluetooth API checks where test hardware permits.

The test agent is not part of production SableOS and receives no generic root/shell authority.

### Manual physical checks

Some acceptance remains intentionally human or hardware-dependent:

| Area | Required validation |
| --- | --- |
| Voice | outgoing/incoming call, earpiece, microphone, speakerphone |
| SMS | outgoing/incoming SMS |
| MMS | send/receive where carrier/APN support permits |
| Hotspot | client connects and reaches internet |
| Bluetooth audio | pair/reconnect/audio with test hardware |
| Camera quality | front/rear photo/video visual sanity |
| Biometrics | enrollment/unlock when configured |
| NFC | physical tag/read where available |

Minimum mandatory user-facing gates remain:

```text
VOICE_OUT=PASS
VOICE_IN=PASS
SMS_OUT=PASS
SMS_IN=PASS
CELLULAR_DATA=PASS
WIFI=PASS
```

No live emergency-services call is part of normal ROM sanity testing.

## D4-R2 — final closure

D4 closes only when the automated and manual acceptance matrix is retained with the exact source/build/package/device evidence.

Target closure:

```text
D4_GRAPHENE_USER_FACING_DEFAULTS=REMOVED_OR_EXPLICITLY_JUSTIFIED
D4_DEFAULT_APP_SET=DOCUMENTED
D4_FUNCTIONAL_ACCEPTANCE=PASS
D4_SLOT_B_BOOT=PASS
D4_SLOT_B_SUCCESSFUL=PASS
D4_SHARED_DATA_PRESERVED=PASS
D4_AUTOMATED_REGRESSION=PASS
```

## After D4

### R1 — Sable-owned release engineering

Move from `userdebug/test-keys` development artifacts toward an independently maintainable release pipeline:

```text
Sable signing keys
Sable release versioning
release/user build policy
OTA generation and signing
update metadata
Updater integration
A/B OTA/rollback validation
factory/fastboot distribution artifacts
recovery/rescue procedure
key custody/rotation documentation
```

`sablectl` becomes part of the release gate: artifact identity, flash/OTA result, post-boot smoke, persistence, security/privacy checks and named acceptance suites should all produce machine-readable evidence suitable for CI and release records.

### F1 — first combined Sable functional-feature batch

Port/redesign functional Sable features in coherent batches using the canonical-base rules above. Every batch receives an automated regression profile before it is considered closed.

### R2 — production hardening

Repeatable signed releases, broader regression coverage, upgrade/rollback testing, key-management exercises, hardware-lab automation and release-candidate acceptance.

## Current sequence

```text
D3  canonical GrapheneOS 2026081300 base
    + initial Sable UI identity
    + Sable fallback boot logo
    + AVB/fs-verity closure
    + physical boot / dual-known-good A/B
    COMPLETE

D4  identity/default-app work
    + packaged B2 build
    + exact target-files flash
    + Android boot
    + exact post-boot BuildManifest
    + exact post-boot ART 5/5
    + initial runtime smoke 16/16
    PASS THROUGH INITIAL AUTOMATED SMOKE

D4-V1
    + expand sablectl host automation
    + SableTestAgent planning
    + remaining manual phone acceptance
    ACTIVE

D4-R2
    final functional/release closure
    OPEN

R1  Sable signing/versioning/OTA/release pipeline
F1  combined Sable functional feature batch
R2  production hardening / repeatable release validation
```
