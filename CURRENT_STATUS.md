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

Bootloader-side slot proof:

```text
FASTBOOT_PRODUCT=panther
FASTBOOT_CURRENT_SLOT=b
FASTBOOT_SLOT_COUNT=2
FASTBOOT_SLOT_SUCCESSFUL_b=yes
FASTBOOT_SLOT_UNBOOTABLE_b=no
FASTBOOT_SLOT_RETRY_COUNT_b=2
POST_SLOT_SUFFIX=_b
POST_BOOT_COMPLETED=1
PANTHER_D4_R2_SLOT_SUCCESS_RESULT=PASS
R2_RC=0
```

Successful slot-proof evidence:

```text
/tmp/PANTHER_D4_R2_SLOT_SUCCESS_PROOF_20260908T215953Z_JS7omS
script sha256=d3cdb1dc4cdca4289ff7d835a96d9c96aebfee05a4feaa4c967bbf033115ca71
log sha256=8aaf2bbaf195cd5f48acc0eafad64022c3dd6ca339a4b400a933752a49738dbc
```

NFC framework/service/HAL initialization and enable/routing passed. RF tag read remains:

```text
NFC_RF_TAG_READ=NOT_TESTED_NO_TEST_HARDWARE
NFC_DISPOSITION=DEFERRED_NON_BLOCKING_EXTERNAL_HARDWARE_VALIDATION
```

This is not a D4 blocking defect.

## R1 release engineering

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

### R1-R0 — CLOSED

Final executable:

```text
tools/validation/release-r1/SABLE_R1_R0R3_RELEASE_PREFLIGHT.py
sha256=595db875192ab5c3753e6d31698bce8adefdd3af5900de217bf4ea987ef7b88f
git_blob=e35081e18cbbd12e7d49accb26766bc03721c649
```

Final ThinkPad gate:

```text
BRANCH_BINDING=PASS
R1_R0R3_FILE_BINDINGS=PASS
PY_COMPILE=PASS_6_OF_6
R1_R0R3_TESTS=PASS_38_OF_38
PASS=19 BLOCKER=10 INFO=11 SKIP=2 ERROR=0
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_10
R1_R0R3_RC=3
EVIDENCE_DIR=/tmp/SABLE_R1_R0_RELEASE_PREFLIGHT_20260908T225032Z_wfba8zy8
```

The ten substantive blockers were promoted into R1. R0R1 and R0R2 remain historical host-harness failures.

### R1-R1 — CLOSED

R1-R1 closes release identity, update endpoint, key-custody policy, production build policy and source-seal policy before any production key generation.

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

Endpoint transport validation:

```text
DNS_PUBLIC_RESOLUTION=PASS
HTTPS_OBJECT_GET=PASS
HTTPS_HEAD_STATUS=200
HTTP_RANGE_STATUS=206
CONTENT_RANGE=bytes 0-5/23
CLOUDFLARE_INTERACTIVE_CHALLENGE=ABSENT_AFTER_CONFIGURATION
OTA_MACHINE_ACCESS=PASS
```

Initial live R1-R1 gate before the endpoint was bound:

```text
PASS=54 BLOCKER=1 INFO=9 SKIP=0 ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=BLOCKED_1
R1_R1_RC=3
EVIDENCE_DIR=/tmp/SABLE_R1_R1_POLICY_PREFLIGHT_20260908T231345Z_fts6loeb
```

Final endpoint-bound gate:

```text
R1_R1_TESTS=PASS_34_OF_34
PASS=55 BLOCKER=0 INFO=9 SKIP=0 ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=READY_TO_REQUEST_KEYGEN_AUTHORIZATION
R1_R1_ENDPOINT_RC=0
EVIDENCE_DIR=/tmp/SABLE_R1_R1_POLICY_PREFLIGHT_20260909T002354Z_qdw0b9dv
R1_R1=CLOSED
```

The exact future Android source mutation remains limited to:

```text
script/generate-keys
    CN=GrapheneOS -> CN=SableOS

packages/apps/Updater/res/values/config.xml
    https://releases.grapheneos.org/
    -> https://updates.sableos.org/
```

Neither mutation has been applied.

### Current authorization boundary

```text
SOURCE_MUTATION_AUTHORIZED=NO
WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
DEVICE_REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
```

R1-R1 readiness means only that a separately sealed key-generation/source-mutation phase may now be prepared and authorization may later be requested. No production key exists yet.

## Next gate

Prepare and adversarially validate, without execution:

```text
1. exact two-file Android source-mutation harness
2. production Panther key-generation harness
3. encrypted external key-custody initialization procedure
4. source-seal inputs for the first panther-cur-user production build
```

Only after those are independently sealed should explicit source-mutation and key-generation authorization be requested.

## Start here

- `docs/PANTHER_D4_CLOSURE_20260908.md` — D4 final closure record.
- `docs/PANTHER_D4_ROADMAP.md` — closed D4 roadmap and handoff to R1.
- `docs/SABLE_R1_R0_CLOSURE_20260908.md` — final R1-R0 closure.
- `release/r1/r1-r0-closure-20260908.json` — structured R1-R0 closure record.
- `docs/SABLE_R1_R1_RELEASE_POLICY_AND_CUSTODY.md` — R1-R1 policy architecture.
- `docs/SABLE_R1_R1_CLOSURE_20260908.md` — final R1-R1 closure.
- `release/r1/r1-r1-closure-20260908.json` — structured R1-R1 closure record.
- `release/r1/panther-release-policy-v1.json` — canonical Panther release policy.
- `release/r1/release-source-seal-v1.schema.json` — production source-seal schema.
- `tools/validation/release-r1/README.md` — release-validation lineage and current authorization boundary.
- `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` — canonical GrapheneOS-based build procedure.

Historical pure-AOSP Panther bring-up records remain forensic/reference evidence only; `/srv/data/aosp_panther17_workspace` is not the canonical active substrate.
