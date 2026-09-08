# SableOS R1-R0 — release-engineering preflight and signing/OTA architecture

Date: 2026-09-08
Status: **DELIVERED / R0R3 LIVE READ-ONLY PREFLIGHT PENDING**
Device scope: Pixel 7 (`panther`)
Canonical Android substrate: GrapheneOS `2026081300` / Android 17

## 1. Purpose and execution lineage

D4 is closed for the current Panther B2 development population. R1 transitions from the physically validated `userdebug/test-keys` build to a Sable-owned production release pipeline.

R1-R0 does **not** generate keys, build, sign, create an OTA, contact a device, reboot, flash, change slots, lock/unlock a bootloader, or wipe data. It binds the upstream release tooling, inventories the current development artifact's signing state, identifies production blockers, and defines the release trust/custody architecture before any production key material is created.

Current execution lineage:

```text
SABLE_R1_R0_RELEASE_PREFLIGHT.py      HISTORICAL BYTE-BOUND BASE / DO NOT EXECUTE DIRECTLY
SABLE_R1_R0R1_RELEASE_PREFLIGHT.py    SUPERSEDED / KNOWN SELF-RECURSION DEFECT
SABLE_R1_R0R2_RELEASE_PREFLIGHT.py    SUPERSEDED / LIVE TARGET-IDENTITY DEFECT
SABLE_R1_R0R3_RELEASE_PREFLIGHT.py    CURRENT EXECUTION ENTRYPOINT
```

R0R3 binds the original R0 base by SHA-256 and changes only the parser/adapter semantics proven defective by live ThinkPad runs. Release blocker policy, authorization checks, evidence output and exit-code semantics remain owned by the byte-bound R0 base.

Healthy R1-R0 closure means:

```text
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
exit=3
```

A blocker result is expected. `ERROR=0` is mandatory.

## 2. Bound upstream source and release tooling

The signed GrapheneOS `2026081300` manifest is already sealed by:

```text
manifest tag: 2026081300
manifest SHA256: c50f0096f538e604aa008e8ab4e3f1a3739f142c60c878a32f402c11eb406572
```

Important pinned release-tool revisions:

```text
script                         b54206456a15f1c1ef5776b752d2705fe75f1b0a
packages/apps/Updater          d7e29f110890de68b63bb8c256b4d249a2d29cf9
platform_build / build/make    7f0398241bc8c4ef5255a8063befa5045e5cfab4
```

The preflight runs only the read-only source queries:

```text
repo manifest -r
git -C <repo> rev-parse HEAD
```

and requires the pinned source closure.

## 3. Current D4 development artifact bound into R1

Canonical B2 target-files:

```text
/srv/data/sableos_panther_graphene_2026081300_workspace/
  out_d4_b2_final/target/product/panther/obj/PACKAGING/
  target_files_intermediates/panther-target_files.zip
```

Known D4 seal:

```text
size=3650769747
sha256=b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78
BuildManifest.apk=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

The routine R1-R0 run intentionally does not recompute the 3.65 GB container SHA or read every ZIP member. `--hash-container` and `--full-zip-crc` are explicit O(container-size) options and are not required for the first preflight because D4 already sealed the archive.

## 4. Target-files device identity contract

The first R0 run incorrectly preferred generic `ro.product.device`. R0R2 then used incorrect legacy property keys/paths. R0R3 is based on the exact pinned GrapheneOS `platform_build` source.

At revision `7f0398241bc8c4ef5255a8063befa5045e5cfab4`, `core/sysprop.mk` emits:

```text
ro.product.<partition>.device=$(TARGET_DEVICE)
```

Relevant target-files evidence is therefore:

```text
SYSTEM/build.prop          ro.product.system.device
VENDOR/build.prop          ro.product.vendor.device
PRODUCT/etc/build.prop     ro.product.product.device
ODM/etc/build.prop         ro.product.odm.device
SYSTEM_EXT/etc/build.prop  ro.product.system_ext.device
```

R0R3 collects these bounded entries, ignores only literal `generic` as a target identity, and requires all available non-generic partition identities to agree. If `OTA/android-info.txt` supplies `require product=...`, that becomes an allowed-product constraint. Any cross-partition or OTA-vs-partition disagreement fails closed as `CONFLICT[...]` and causes the existing `artifact.device` check to fail.

R0R3 never infers Panther solely from the ZIP filename.

## 5. Release signing trust anchors

The exact GrapheneOS `2026081300` release tooling defines nine certificate/signing domains:

```text
bluetooth
gmscompat_lib
media
networkstack
nfc
platform
releasekey
sdk_sandbox
shared
```

Panther release engineering additionally needs:

```text
avb.pem         AVB RSA-4096 private key
avb_pkmd.bin    AVB public-key metadata
id_ed25519      factory archive signing key
```

The pinned release flow uses these to replace development test keys, sign target-files/APKs/APEX/AVB, generate OTA and image/factory artifacts, and optionally sign the factory archive.

## 6. Sable key-generation rule

Pinned upstream `script/generate-keys` assigns:

```text
CN=GrapheneOS
```

It must **not** be run unchanged for Sable production keys. R1-R1 must define and seal the Sable certificate/DN policy before key generation. Key generation remains separately authorized.

## 7. Key custody policy before generation

Required policy baseline:

```text
KEYS_UNIQUE_PER_DEVICE_VARIANT=YES
PRIVATE_KEYS_IN_GIT=NO
PRIVATE_KEYS_IN_REPOSITORY_OR_ISSUES=NO
PRIVATE_KEYS_IN_LOGS=NO
ENCRYPTED_AT_REST=YES
OFFLINE_BACKUP_COUNT>=2
BACKUPS_PHYSICALLY_SEPARATED=YES
SIGNING_OPERATOR_AUTHORIZATION=REQUIRED
SIGNING_SESSION_AUDIT_LOG=REQUIRED
DECRYPTED_KEY_WORKDIR=TMPFS
```

R1-R0 intentionally never reads or hashes private-key bytes. An existing `keys/panther` directory would still require a separately authorized custody/public-fingerprint gate.

## 8. Sable Updater ownership

The pinned Updater currently points to:

```text
https://releases.grapheneos.org/
```

That is a hard Sable release blocker. Before `OFFICIAL_BUILD=true`, Sable needs its own HTTPS update base URL and release metadata/channel ownership.

## 9. Production build policy

Current B2 is intentionally:

```text
userdebug
test-keys
```

It is not promotable to production.

The first Sable production candidate requires a fresh build with at least:

```text
lunch panther-cur-user
OFFICIAL_BUILD=true
new monotonically increasing BUILD_NUMBER
Sable-owned Updater endpoint
exact production source seal
```

Recommended build-number shape remains `YYYYMMDDRR`, with no reuse.

## 10. Production source seal

Before the first production `user` build, seal at least:

```text
GrapheneOS manifest tag and exact pinned manifest
all pinned repository revisions
Sable repository commit / bounded source delta
Sable binary asset hashes
Updater endpoint configuration
release/version configuration
vendor-state identity
external host-tool identities that affect output
BUILD_NUMBER
BUILD_DATETIME policy/value
```

D4's development artifact seal is evidence for the B2 population; it does not substitute for the future production source seal.

## 11. Intended release artifact pipeline

After policy blockers are closed and later phases are explicitly authorized:

```text
SIGNED GRAPHENE TAG 2026081300
        +
PINNED SABLE RELEASE DELTA
        +
SABLE UPDATE ENDPOINT
        +
OFFICIAL_BUILD=true
        +
PANTHER USER BUILD
        |
        +--> target-files-package
        +--> otatools-package
        +--> finalize/release tooling
        v
SABLE-SIGNED TARGET-FILES
        +--> AVB-signed images
        +--> full OTA
        +--> factory/install archive
        +--> factory archive signature
        +--> updater metadata/channel data
```

Signed target-files must be retained per release because they are the canonical input for future full/incremental OTA generation and reproducible release analysis.

## 12. OTA policy

```text
FULL_OTA_FROM_SIGNED_TARGET_FILES=REQUIRED
SIGNED_TARGET_FILES_RETAINED_PER_RELEASE=REQUIRED
INCREMENTAL_SOURCE_AND_TARGET_SIGNED_TARGET_FILES=REQUIRED
TESTING_CHANNEL_FIRST=REQUIRED
FUTURE_UPDATE_PATH_TEST=REQUIRED
```

A candidate is not stable merely because its first full OTA installs; forward-update behavior must also be demonstrated.

## 13. First transition from development keys

The current Panther is unlocked and running the D4 `test-keys` development build. The first Sable release-key deployment is a separate future migration operation, not implied by R1-R0.

That phase must explicitly plan:

```text
factory artifact verification
userdata backup/reset decision
AVB public-key provisioning
first signed boot
release artifact identity
Updater testing channel
bootloader relock decision
post-lock verified-boot validation
```

R1-R0 authorizes none of these actions.

## 14. Current preflight tool

Current entrypoint:

```text
tools/validation/release-r1/SABLE_R1_R0R3_RELEASE_PREFLIGHT.py
```

Bound base:

```text
SHA256=cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7
```

Published R0R3:

```text
GIT_BLOB=e35081e18cbbd12e7d49accb26766bc03721c649
SHA256=595db875192ab5c3753e6d31698bce8adefdd3af5900de217bf4ea987ef7b88f
```

The required authorization context is all `NO`:

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

R0R3 adds no execution backend. The bound base performs file/ZIP reads, `/tmp` evidence creation, `repo manifest -r`, and `git rev-parse HEAD` only.

Exit codes:

```text
0  preflight complete; no remaining release blockers
2  audit incomplete / ERROR
3  audit complete; release blockers identified
```

Current validation gate:

```bash
cd /home/mindseye73/sableos-tools
git pull --ff-only

PY="$HOME/.venvs/sablectl/bin/python"

PYTHONDONTWRITEBYTECODE=1 "$PY" -m pytest \
  tools/validation/release-r1/test_release_preflight.py \
  tools/validation/release-r1/test_release_preflight_r0r2.py \
  tools/validation/release-r1/test_release_preflight_r0r3.py -q

PYTHONDONTWRITEBYTECODE=1 env \
  SOURCE_MUTATION_AUTHORIZED=NO \
  WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO \
  BUILD_AUTHORIZED=NO \
  KEY_GENERATION_AUTHORIZED=NO \
  SIGNING_AUTHORIZED=NO \
  OTA_GENERATION_AUTHORIZED=NO \
  DEVICE_CONTACT_AUTHORIZED=NO \
  DEVICE_REBOOT_AUTHORIZED=NO \
  FLASH_AUTHORIZED=NO \
  SLOT_CHANGE_AUTHORIZED=NO \
  USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO \
  "$PY" tools/validation/release-r1/SABLE_R1_R0R3_RELEASE_PREFLIGHT.py
```

Expected healthy closure of the inventory itself:

```text
ERROR=0
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
R1_R0R3_RC=3
```

## 15. R1-R1 boundary

After R1-R0 closes as an inventory, R1-R1 should resolve policy/configuration blockers **before key generation**:

1. choose and prove ownership/control of the Sable HTTPS update endpoint;
2. define Sable certificate subject/DN policy;
3. define encrypted key custody, backup, operator-access and audit procedures;
4. define the production source-seal schema;
5. define first production build-number/reproducibility inputs;
6. prepare the bounded Updater/config + release-source mutation;
7. statically/adversarially validate the key-generation harness without generating keys;
8. request explicit key-generation authorization only after those items are sealed.

No production signing key should exist before that boundary is closed.
