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
verified boot state: orange
file-based encryption: enabled
SableOS B2 packaged target-files: flashed successfully
shared userdata: preserved
exact post-boot BuildManifest identity: PASS
exact post-boot ART identity: PASS_5_OF_5
slot B current: PASS
slot B bootable: PASS
slot B marked successful: PASS
```

Canonical packaged B2 target-files:

```text
/srv/data/sableos_panther_graphene_2026081300_workspace/
  out_d4_b2_final/target/product/panther/obj/PACKAGING/
  target_files_intermediates/panther-target_files.zip

sha256=b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78
```

Installed BuildManifest identity:

```text
/system/etc/security/fsverity/BuildManifest.apk
sha256=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

## Panther D4 closure

D4 is **CLOSED** for the current B2 development population.

Validated chain:

```text
R7R7 fs-verity named-input fidelity                 PASS / CLOSED
R8 ART residual classification                      PARTIAL / historical C2 evidence unavailable
R9 preserved-data flash preflight                   PASS
R10R3 exact packaged B2 flash                       PASS
R10R3 Android boot                                  PASS
R10R3 BuildManifest identity                        PASS
R10R3 postboot ART loop                             SUPERSEDED HOST HARNESS DEFECT
sablectl exact postboot ART                         PASS_5_OF_5
sablectl v0.3.1 full tests                          PASS_26_OF_26
sablectl D4 release gate                            PASS
D4 automated acceptance                             PASS
D4 minimum physical acceptance                      PASS
D4 broad functional acceptance                      PASS_WITH_NONBLOCKING_NFC_RF_GAP
D4 slot B boot                                      PASS
D4 slot B current                                   PASS
D4 slot B bootable                                  PASS
D4 slot B successful                                PASS
D4 shared data preserved                            PASS
D4 automated regression                             PASS
PANTHER_D4_R2                                       PASS
PANTHER_D4                                          CLOSED
```

The D4 release gate completed with:

```text
PASS=56
FAIL=0
SKIP=8
MANUAL=0
ERROR=0
OVERALL=PASS
RELEASE_D4_RC=0
```

The dedicated bootloader-side slot proof then established:

```text
FASTBOOT_PRODUCT=panther
FASTBOOT_CURRENT_SLOT=b
FASTBOOT_SLOT_COUNT=2
FASTBOOT_SLOT_SUCCESSFUL_b=yes
FASTBOOT_SLOT_UNBOOTABLE_b=no
FASTBOOT_SLOT_RETRY_COUNT_b=2
D4_SLOT_B_SUCCESSFUL=PASS
D4_SLOT_B_BOOTABLE=PASS
D4_SLOT_B_CURRENT=PASS
POST_SLOT_SUFFIX=_b
POST_BOOT_COMPLETED=1
POST_SLOT_PRESERVED=PASS
PANTHER_D4_R2_SLOT_SUCCESS_RESULT=PASS
R2_RC=0
```

The successful slot-proof evidence directory was:

```text
/tmp/PANTHER_D4_R2_SLOT_SUCCESS_PROOF_20260908T215953Z_JS7omS
```

with:

```text
script sha256=d3cdb1dc4cdca4289ff7d835a96d9c96aebfee05a4feaa4c967bbf033115ca71
log sha256=8aaf2bbaf195cd5f48acc0eafad64022c3dd6ca339a4b400a933752a49738dbc
```

The earlier slot-proof attempt is superseded as a host fastboot-readiness race. It produced no flash, slot change, unlock or wipe, and Android was recovered on slot B before the corrected proof passed.

## Functional acceptance

Automated D4 acceptance and release checks proved, among other items:

```text
exact BuildManifest identity
five exact ART images
SELinux enforcing
core Android services healthy
credential-encrypted data available
third-party package count preserved: 6
Android user count preserved: 1
Wi-Fi enabled and validated
cellular registration and data
Bluetooth enabled
Vanadium WebView selected
default launcher/browser/dialer/SMS roles
ADB/USB transport health
```

Physical validation passed:

```text
VOICE_OUT=PASS
VOICE_IN=PASS
SMS_OUT=PASS
SMS_IN=PASS
MMS_OUT=PASS
MMS_IN=PASS
HOTSPOT=PASS
BLUETOOTH_AUDIO=PASS
CAMERA=PASS
LOCATION=PASS
BIOMETRICS=PASS
CELLULAR_DATA=PASS
WIFI=PASS
```

NFC framework/service/HAL initialization and enable/routing path passed. RF tag read remains:

```text
NFC_RF_TAG_READ=NOT_TESTED_NO_TEST_HARDWARE
NFC_DISPOSITION=DEFERRED_NON_BLOCKING_EXTERNAL_HARDWARE_VALIDATION
```

This is not a D4 blocking defect.

## Current active milestone: R1 release engineering

The active milestone is now **R1 — Sable-owned release engineering**.

R1 goal:

```text
Sable signing-key architecture and custody
Sable release/version identity
user/release build policy
signed target-files and factory artifacts
full/incremental OTA generation and signing
Sable-owned update metadata and Updater endpoint
A/B OTA forward-update validation
rollback/recovery validation
sablectl release evidence integration
```

### R1-R0 preflight lineage

The original read-only R1-R0 base is byte-frozen:

```text
tools/validation/release-r1/SABLE_R1_R0_RELEASE_PREFLIGHT.py
sha256=cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7
```

The first live R0 run exposed two parser defects. R0R1 fixed those semantics but introduced a monkeypatch self-recursion and is retained only as historical evidence.

Current executable:

```text
tools/validation/release-r1/SABLE_R1_R0R2_RELEASE_PREFLIGHT.py
```

Current release-preflight disposition before the next ThinkPad run:

```text
R1_R0_BASE_TESTS=PASS_9_OF_9_ON_THINKPAD
R1_R0R1=SUPERSEDED_MONKEYPATCH_SELF_RECURSION
R1_R0R2_LOCAL_FOCUSED_TESTS=PASS_11_OF_11
R1_R0R2_LIVE_THINKPAD_PREFLIGHT=PENDING
KEY_GENERATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
```

A healthy R0R2 run is expected to complete the audit with `ERROR=0` and release blockers still present. Only after that should the blocker set become the R1-R1 worklist.

## Start here

- `docs/PANTHER_D4_CLOSURE_20260908.md` — D4 final closure record.
- `docs/PANTHER_D4_ROADMAP.md` — closed D4 roadmap and handoff to R1.
- `docs/SABLE_R1_R0_RELEASE_ENGINEERING_PREFLIGHT.md` — current R1 architecture and R0R2 execution gate.
- `docs/SABLE_R1_R0R2_PREFLIGHT_CORRECTION.md` — R0/R0R1 failure lineage and R0R2 validation.
- `tools/validation/release-r1/README.md` — current executable/test commands.
- `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` — canonical GrapheneOS-based build procedure.

Historical pure-AOSP Panther bring-up records remain forensic/reference evidence only; `/srv/data/aosp_panther17_workspace` is not the canonical active substrate.
