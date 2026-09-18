# SableOS current validated Panther status

Last updated: 2026-09-18

The canonical Android/Pixel base for active SableOS Pixel 7 development is the exact signed **GrapheneOS 2026081300** Android 17 release, with audited Sable-specific deltas layered on top.

## 2026-09-18 UI refresh handoff

The product UI refresh is now a cross-surface contract rather than a collection of app-specific restyles.

```text
UI_REFRESH=ACTIVE
UI_CONTRACT=SABLE_DESIGN_SYSTEM_V1
UI1_SHARED_DESIGN_AND_START=MERGED
UI2_FIRST_PARTY_APPS=MERGED
UI2G_SEPARATE_GAME_APKS=IN_IMPLEMENTATION
UI3_READER_COMPOSITION=QUEUED
UI4_SYSTEMUI_SHADE_QUICK_SETTINGS=QUEUED
UI5_SETUP_SETTINGS_APP_SECURITY_BRANDING=QUEUED
UI6_REMAINING_SYSTEM_SURFACES=QUEUED
```

All new or refreshed screens must follow `docs/UI_UX_CONTRACT.md`. The same shared Compose design source is intended for R8 Gradle apps and Soong-built Sable surfaces such as SableStart. User-facing product copy should use SableOS branding where SableOS owns the surface, while internal identifiers and technically truthful provider/service references are not globally renamed.

## 2026-09-18 execution handoff

The current implementation line has advanced beyond the older M1-only snapshot below. Where this handoff conflicts with an older near-term milestone label in this file, this section is the current execution authority.

```text
R8_APPLICATION_FOUNDATION=MERGED
R8_CALCULATOR_CONVERT_GAMES_JNI=MERGED
INFRA2_CI_SECURITY_QUALITY=INTEGRATED
INFRA3_SUPPLY_CHAIN_BASELINE=INTEGRATED
INFRA4_TRUSTED_RUNNER_GATE=INTEGRATED
INFRA5_TRUSTED_RUNNER_ACTIVATION=DEFERRED_NON_BLOCKING
TRUSTED_SELF_HOSTED_RUNNER=DISABLED
PRODUCTION_SIGNING=DEFERRED
NEXT_ACTIVE_DELIVERABLE=R8_APPLICATION_IMPLEMENTATION_AND_BUILD_PREPARATION
```

INFRA5 is parked intentionally for the current hobby/development phase. The `ai-g732` host may continue to be used as a normal development/build machine, but its unencrypted Sable source/build storage does not qualify it as a trusted self-hosted release runner. GitHub-hosted CI remains authoritative for current qualification. INFRA5 should be reopened together with build-storage encryption, production signing/key custody and release-candidate hardening rather than weakening the existing INFRA4 fail-closed policy.

The active R8 handoff is to finish application implementation and build preparation across the shared design/Kotlin surfaces, Calculator+Convert, Games, Reader/Text Reader composition and Media, then run the already-defined standalone qualification/artifact-freeze gates before product-image integration.

See `docs/INFRA5_DEFERRED_TRUSTED_RUNNER.md` and `apps/r8/README.md`.

## Current project priority

SableOS has moved from substrate/release-engineering closure back to **active product development**.

The accepted near-term product direction is **Sable Flow**: a Metro-inspired, information-first shell with Sable-owned visual identity, live tiles, native phone essentials, and a central Sable Hub for people, communication and social-service access.

```text
SABLEOS_PRODUCT_DEVELOPMENT=ACTIVE
SABLEOS_CORE_PRODUCT_STAGE=PRODUCT_INTEGRATION_START
NEXT_PRODUCT_MILESTONE=SABLE_M1_METRO_SHELL_PROTOTYPE
TARGET=panther
```

Primary sequence:

```text
Sable Flow shared UI primitives
    -> Sable Start vertical live-tile shell
    -> Phone / People / Messages / Settings vertical slice
    -> Sable Hub provider capability framework
    -> isolated social-service web capsules
    -> broader native apps and polish
    -> Titan 2 N0 GSI/userspace/UI portability lab when Panther is ready
    -> Q27 full-QWERTY evaluation when shipped hardware qualifies
    -> production signing/OTA closure before release candidate
```

See `docs/SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md`, `docs/CORE_PRODUCT_ROADMAP.md`, and `docs/NON_PIXEL_DEVICE_ROADMAP.md`.

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

Installed BuildManifest:

```text
/system/etc/security/fsverity/BuildManifest.apk
sha256=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

## Panther D4 — CLOSED

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

D4 release gate:

```text
PASS=56 FAIL=0 SKIP=8 MANUAL=0 ERROR=0
OVERALL=PASS
RELEASE_D4_RC=0
```

NFC framework/service/HAL initialization and enable/routing passed. RF tag read remains:

```text
NFC_RF_TAG_READ=NOT_TESTED_NO_TEST_HARDWARE
NFC_DISPOSITION=DEFERRED_NON_BLOCKING_EXTERNAL_HARDWARE_VALIDATION
```

This is not a D4 blocking defect.

## R1 release engineering — PAUSED / NON-BLOCKING

R1 established the production release identity, update endpoint, key-custody policy, source-mutation controls and signing architecture. It is intentionally paused while SableOS product/UI work advances.

### Closed release foundations

```text
R1_R0=CLOSED
R1_R1=CLOSED
R1_R3R2=PASS_EXACT_TWO_FILE_SOURCE_MUTATION
R1_R4R2=PASS_POST_MUTATION_STATIC_VALIDATION
```

Canonical release policy:

```text
release/r1/panther-release-policy-v1.json
sha256=32d09f8ccb7b21bca083c8db3d41ae838daa1ee46e953454dfdb3c3f596a8c92
git_blob=9db278de6bdaa8781043762a326f2f9df03f0902
```

Adopted policy:

```text
CERTIFICATE_SUBJECT=CN=SableOS
SIGNING_KEY_DOMAINS=9_BOUND
SABLE_UPDATE_BASE_URL=https://updates.sableos.org/
UPDATE_ENDPOINT_OWNERSHIP=OPERATOR_VERIFIED
BUILD_VARIANT=user
OFFICIAL_BUILD=true
BUILD_NUMBER_POLICY=YYYYMMDDRR_NO_REUSE
TESTING_CHANNEL_FIRST=YES
FUTURE_UPDATE_PATH_TEST=REQUIRED
PERSISTENT_PRIVATE_KEYS=OFFLINE_ENCRYPTED_EXTERNAL_TO_WORKSPACE
DECRYPTED_SIGNING_WORKDIR=TMPFS
PRIVATE_KEY_MATERIAL_IN_PUBLIC_EVIDENCE=NO
PRIVATE_KEY_HASHES_IN_PUBLIC_EVIDENCE=NO
```

### Applied exact Android source mutations

The two authorized source mutations were completed and postvalidated:

```text
script/generate-keys
    CN=GrapheneOS -> CN=SableOS
    sha256=c9957d82c62c61ec404c2d7366b0d80b71d98e2e6a6df60322fe066f0d58b440
    git_blob=211209f492071e3a9f9c4247ad63c2dee3ffbf30

packages/apps/Updater/res/values/config.xml
    https://releases.grapheneos.org/
    -> https://updates.sableos.org/
    sha256=84a7aac655c3e863cb1b473b11d12269baa16c44ccc242757d9c2c9051428b3d
    git_blob=9c0b38b3189c9674d4a150ffead95336211d462c
```

Postmutation validation:

```text
SOURCE_POSTIMAGES=PASS_2_OF_2
GIT_INDEX_UNCHANGED=PASS_2_OF_2
SOURCE_DELTA_CARDINALITY=PASS_EXACT_2_FILES
TARGET_PROJECT_DELTA_SCOPE=PASS_2_OF_2
GENERATOR_CN_SEMANTICS=PASS
UPDATER_ENDPOINT_SEMANTICS=PASS
R1_R4R2_POST_MUTATION_VALIDATION=PASS
R1_R4R2_RC=0
```

### Key-custody exploration status

No production key has been generated.

The ThinkPad host was proven unsuitable for immediate key generation while unencrypted persistent swap is active. The `/dev/sda` external disk was safely inspected and temporarily unmounted for read-only classification; its existing GPT/ext4 contents remain preserved and it is no longer on the critical path for production keystore provisioning.

Latest storage review:

```text
R1_R5R5ER5R2_POST_UNMOUNT_READONLY_REVIEW=PASS
R1_R5R5ER5R2_REPORT_SHA256=51e79fdc7fc39a4103ee7001c47b3f8c8031a089b90a7f2a70ffd109e407483d
EXTERNAL_STORAGE=/dev/sda
EXTERNAL_STORAGE_PARTITION=/dev/sda1
PARTITION_TABLE=gpt
FILESYSTEM=ext4
ACTIVE_MOUNT_COUNT=0
OVERWRITE_SAFE=NO
OVERWRITE_AUTHORIZED=NO
```

A future dedicated or isolated signing-host environment remains preferred, but host selection is intentionally deferred. No hardware purchase is required for current product development.

### Current release authorization boundary

```text
SOURCE_MUTATION_AUTHORIZED=NO
WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
MOUNT_MUTATION_AUTHORIZED=NO
OVERWRITE_AUTHORIZED=NO
KEYSTORE_PROVISIONING_AUTHORIZED=NO
PARTITION_AUTHORIZED=NO
FORMAT_AUTHORIZED=NO
CRYPTSETUP_AUTHORIZED=NO
SWAP_MUTATION_AUTHORIZED=NO
DELETE_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
DEVICE_REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
```

Release-signing work resumes before release-candidate/OTA distribution. It does not block feature/UI development.

## Non-Pixel / MediaTek planning

No non-Pixel device is currently declared a supported SableOS production target. The September 2026 Brax3/iodéOS source review established a formal non-Pixel architecture without changing Panther's priority.

```text
N0_GSI_USERSPACE_LAB
N1_INTEGRATED_VENDOR_BSP_PORT
N2_PRODUCTION_QUALIFIED

1. Pixel 7 / panther
   canonical full-stack SableOS development target

2. Unihertz Titan 2
   preferred interim N0 GSI/userspace/UI development lab

3. Zinwa Q27
   preferred future full physical-QWERTY candidate if shipped hardware qualifies

4. Zinwa Q25
   optional source-available MediaTek/kernel/device research platform
```

A booting GSI does not imply production support. A prebuilt kernel/BSP can be useful for N0/N1 functionality work but does not provide Sable-owned kernel security maintenance. Platform, kernel, vendor, modem, TEE, bootloader and connectivity firmware provenance must remain separate release inputs. Radio/data/5G/IMS/VoLTE/VoWiFi are separate acceptance gates rather than one generic telephony result.

See `docs/NON_PIXEL_MEDIATEK_ARCHITECTURE.md`, `docs/NON_PIXEL_DEVICE_ROADMAP.md`, `docs/TITAN2_GSI_PLAN.md`, `docs/Q25_PORT_PLAN.md`, `docs/NON_PIXEL_RELEASE_VALIDATION.md`, and `docs/BRAX3_IODEOS_REFERENCE.md`.

## Sable Flow M1 — NEXT

The first concrete product milestone is:

```text
SABLE_M1=METRO_SHELL_PROTOTYPE
TARGET=panther

DELIVERABLES:
  Sable Flow shared primitives
  Sable Start vertical tile grid
  typography + accent themes
  app/service list transition
  live-tile provider contract
  Phone tile
  People tile
  Messages tile
  Settings tile
  Social Hub placeholder
```

Sable Hub will use a provider capability model rather than pretending every service exposes a universal native API. Initial social targets are WhatsApp, Instagram, Facebook and LinkedIn, with isolated web capsules used where supported native/API consumer integration is unavailable.

The same semantic shell/Hub model is intended to become the base for Titan 2, Q25 and Q27 compact/QWERTY work without device-specific application forks.

## Start here

- `docs/SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` — accepted Sable Flow / Sable Start / Hub direction and M1-M5 sequence.
- `docs/CORE_PRODUCT_MODEL.md` — normative product architecture and trust boundaries.
- `docs/CORE_PRODUCT_ROADMAP.md` — active product-integration roadmap.
- `docs/NON_PIXEL_DEVICE_ROADMAP.md` — non-Pixel hardware strategy and assurance ordering.
- `docs/NON_PIXEL_MEDIATEK_ARCHITECTURE.md` — normative non-Pixel/MediaTek architecture.
- `docs/TITAN2_GSI_PLAN.md` — Titan 2 N0 GSI/userspace/UI plan.
- `docs/PANTHER_D4_CLOSURE_20260908.md` — D4 final closure record.
- `docs/SABLE_R1_R1_RELEASE_POLICY_AND_CUSTODY.md` — preserved release/signing custody architecture.
- `release/r1/panther-release-policy-v1.json` — canonical Panther release policy.
- `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` — canonical GrapheneOS-based build procedure.

Historical pure-AOSP Panther bring-up records remain forensic/reference evidence only; the active GrapheneOS-derived Android 17 Panther workspace is the canonical product-development substrate.
