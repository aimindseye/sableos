# SableOS R1-R0 — release-engineering preflight and signing/OTA architecture

Date: 2026-09-08
Status: **DELIVERED / R0R2 LIVE READ-ONLY PREFLIGHT PENDING**
Device scope: Pixel 7 (`panther`)
Canonical Android substrate: GrapheneOS `2026081300` / Android 17

## 1. Purpose and current execution lineage

D4 is closed for the current Panther B2 development population. R1 begins the transition from a physically validated `userdebug/test-keys` development build to a Sable-owned release pipeline.

R1-R0 does **not** generate keys, build, sign, create an OTA, contact a device, reboot, flash, change slots, lock/unlock a bootloader, or wipe data. Its purpose is to bind the exact upstream release tooling, inventory the current development artifact's signing state, identify production blockers, and define the trust/custody architecture before any irreversible key material is created.

Current execution lineage:

```text
SABLE_R1_R0_RELEASE_PREFLIGHT.py      HISTORICAL BASE / DO NOT EXECUTE DIRECTLY
SABLE_R1_R0R1_RELEASE_PREFLIGHT.py    SUPERSEDED / KNOWN RECURSION DEFECT
SABLE_R1_R0R2_RELEASE_PREFLIGHT.py    CURRENT EXECUTION ENTRYPOINT
```

The original R0 file remains byte-frozen because R0R2 binds it by exact SHA-256 and reuses its authorization, blocker, evidence and bounded-scan policy. R0R2 changes only the parser/adapter semantics proven defective by the first two physical-host attempts. See `SABLE_R1_R0R2_PREFLIGHT_CORRECTION.md` for the supersession record.

R1-R0 separates:

```text
PREFLIGHT_EXECUTION
    did the read-only audit complete correctly?

RELEASE_READINESS
    are all prerequisites for an authorized production signing/build phase satisfied?
```

Expected current outcome:

```text
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
R1_R0R2_RC=3
```

A blocker result is expected and healthy at this stage. `ERROR=0` is mandatory before R1-R0 is considered closed as an inventory.

## 2. Bound upstream release-tooling substrate

The signed GrapheneOS `2026081300` manifest pins:

```text
script                         b54206456a15f1c1ef5776b752d2705fe75f1b0a
packages/apps/Updater          d7e29f110890de68b63bb8c256b4d249a2d29cf9
```

The canonical pinned manifest SHA-256 is:

```text
c50f0096f538e604aa008e8ab4e3f1a3739f142c60c878a32f402c11eb406572
```

The bound R0 preflight independently executes only the read-only source queries:

```text
repo manifest -r
git -C <repo> rev-parse HEAD
```

and requires the pinned manifest plus exact `script` and `Updater` repository heads.

Upstream references:

- https://grapheneos.org/build
- https://source.android.com/docs/core/ota/sign_builds
- https://source.android.com/docs/core/ota/tools
- https://source.android.com/docs/core/ota/ab/ab_implement

## 3. Current D4 development artifact bound into R1-R0

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

The routine preflight does not recompute the 3.65 GB container hash because D4 already sealed it. `--hash-container` enables an independent full SHA-256 pass only when specifically requested. `--full-zip-crc` enables a full member CRC scan. Both are intentionally off for the bounded routine run.

R0R2 corrects target identity semantics by preferring:

```text
OTA/android-info.txt require product=...
    -> authoritative target product identity
PRODUCT/VENDOR/ODM/SYSTEM_EXT build.prop
    -> bounded fallback
SYSTEM build.prop ro.product.device=generic
    -> not authoritative for target identity
```

## 4. Release signing trust anchors

The exact GrapheneOS `2026081300` release tooling defines nine APK/certificate signing domains:

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

Panther release engineering also needs:

```text
avb.pem         AVB RSA-4096 private key
avb_pkmd.bin    derived AVB public-key metadata
id_ed25519      OpenSSH private key used to sign factory-image archives
```

The pinned `generate-release.sh` flow replaces public build test keys, signs AVB/vbmeta, signs APK/APEX payloads according to the configured mappings, creates the full OTA, creates image/factory artifacts and can produce a detached OpenSSH signature for the factory archive.

The OTA package is signed with `releasekey`. Production images must not use the public AOSP test keys.

## 5. Critical Sable key-generation rule

The pinned upstream `script/generate-keys` contains an indented assignment equivalent to:

```text
CN=GrapheneOS
```

That generator must **not** be run unchanged for Sable production keys.

R0R2 parses the actual upstream assignment correctly and reports `GrapheneOS` as a release `BLOCKER`, not a parser error. R1-R1 must choose and bind a Sable-owned certificate subject before generation. A minimal intended identity is:

```text
CN=SableOS
```

but the final distinguished-name policy remains an R1-R1 decision. Key generation requires separate explicit authorization.

## 6. Key custody policy to approve before generation

Required policy:

```text
KEYS_UNIQUE_PER_DEVICE_VARIANT=YES
PRIVATE_KEYS_IN_GIT=NO
PRIVATE_KEYS_IN_SABLE_REPOSITORY=NO
PRIVATE_KEYS_IN_ISSUE_TRACKER=NO
PRIVATE_KEYS_IN_BUILD_LOGS=NO
PRIVATE_KEY_HASHES_IN_PUBLIC_EVIDENCE=NO
ENCRYPTED_AT_REST=YES
OFFLINE_BACKUP_COUNT>=2
BACKUPS_PHYSICALLY_SEPARATED=YES
SIGNING_OPERATOR_AUTHORIZATION=REQUIRED
SIGNING_SESSION_AUDIT_LOG=REQUIRED
DECRYPTED_KEY_WORKDIR=TMPFS
SWAP_DURING_SIGNING=DISABLED_OR_EPHEMERALLY_ENCRYPTED
```

The GrapheneOS release model decrypts the persistent key set in `/dev/shm` and removes the temporary directory on exit. Sable still needs its own persistent encrypted storage, access-control, backup, public-fingerprint and audit policy.

R1-R0 never reads or hashes private-key bytes. If `keys/panther` exists, it is reported as present-but-unvalidated rather than inspected.

## 7. Sable Updater ownership is a hard release blocker

The exact pinned Updater configuration currently points to:

```text
https://releases.grapheneos.org/
```

A derivative official build must use a Sable-owned HTTPS update endpoint before `OFFICIAL_BUILD=true`.

R1 therefore requires:

```text
SABLE_UPDATE_BASE_URL=DECIDED
SABLE_UPDATE_BASE_URL_HTTPS=YES
GRAPHENE_UPDATE_URL_PRESENT=NO
OFFICIAL_BUILD=true
```

R1-R0 does not invent an update-server hostname.

## 8. Production build policy

The current B2 artifact is intentionally:

```text
userdebug
test-keys
```

It is not eligible for production promotion.

The first Sable production candidate must be rebuilt as a `user` build with `OFFICIAL_BUILD=true`, a new monotonically increasing build number, the Sable-owned Updater endpoint, and an exact production source seal.

Recommended policy:

```text
BUILD_NUMBER_FORMAT=YYYYMMDDRR
BUILD_NUMBER_MONOTONIC=YES
BUILD_NUMBER_REUSE=NO
SOURCE_SEAL_BEFORE_BUILD=REQUIRED
USER_BUILD=REQUIRED
RELEASE_SIGNING_AFTER_TARGET_FILES=REQUIRED
```

## 9. Production source identity gate

The production source seal should bind at least:

```text
GrapheneOS manifest tag + manifest SHA-256
all pinned repo revisions
Sable repository commit(s)
Sable patch/input hashes
Updater endpoint change
release/version configuration
vendor-state identity
external host release-tool versions
BUILD_NUMBER
BUILD_DATETIME policy/value
```

R1-R0 reports this as a blocker until the production source-seal schema exists.

## 10. Intended release artifact pipeline

After R1-R0 blockers are closed and later phases are separately authorized:

```text
SIGNED GRAPHENE TAG 2026081300
        +
PINNED SABLE RELEASE DELTA
        +
SABLE UPDATER ENDPOINT
        +
OFFICIAL_BUILD=true
        +
PANTHER USER BUILD
        |
        v
unsigned/test-key target-files build output
        |
        +--> m otatools-package
        +--> script/finalize.sh
        |
        v
script/generate-release.sh panther BUILD_NUMBER
        |
        +--> release-key-signed target-files
        +--> AVB-signed images
        +--> full OTA package
        +--> factory/install image archive
        +--> factory archive OpenSSH signature
        +--> updater channel metadata
```

R1-R0 authorizes none of those mutating operations.

## 11. OTA policy

```text
FULL_OTA_FROM_SIGNED_TARGET_FILES=REQUIRED
SIGNED_TARGET_FILES_RETAINED_PER_RELEASE=REQUIRED
INCREMENTAL_OTA_SOURCE_AND_TARGET_SIGNED_TARGET_FILES=REQUIRED
TESTING_CHANNEL_FIRST=REQUIRED
BETA_BEFORE_STABLE=RECOMMENDED
FUTURE_UPDATE_PATH_TEST=REQUIRED
```

A candidate should first be published to an internal/testing channel and must prove that it can update to a sample future release before stable promotion.

## 12. First transition from D4 test keys to Sable release keys

The current Panther runs an unlocked `test-keys` development build. The first production-key transition is **not** an ordinary in-place OTA acceptance path.

A separately authorized future migration must cover:

```text
factory artifact verification
userdata backup/restore decision
factory reset expectation
AVB public-key provisioning
first signed boot
release artifact identity
Updater testing channel
bootloader relock only after signed-image validation
post-lock verified-boot validation
```

R1-R0 authorizes none of those actions.

## 13. Current preflight tool and validation gate

Current executable:

```text
tools/validation/release-r1/SABLE_R1_R0R2_RELEASE_PREFLIGHT.py
```

Bound historical base:

```text
tools/validation/release-r1/SABLE_R1_R0_RELEASE_PREFLIGHT.py
sha256=cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7
```

Known-defective R0R1 is retained only for forensic lineage and must not be executed.

R0R2 enforces the same fail-closed authorization context as R0:

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

The base implementation performs only file/ZIP reads, bounded hashing, optional explicitly requested full hashing/CRC work, `repo manifest -r`, `git rev-parse`, and `/tmp` evidence creation. R0R2 itself has no subprocess or OS execution backend.

Current test gate:

```text
test_release_preflight.py       9 tests
test_release_preflight_r0r2.py 11 tests
TOTAL                           20 tests
```

The R0R2-specific validation directly exercises the actual patched `main()` lifecycle, restoration on success, restoration on exception, 250 repeated patched-main invocations and 100 dynamically loaded-module invocations. This specifically closes the coverage hole that allowed R0R1 self-recursion to pass its tests.

### Exit codes

```text
0  preflight complete; no remaining release blockers
2  audit incomplete / ERROR
3  audit complete; release blockers identified
```

### Run

```bash
cd /home/mindseye73/sableos-tools

git pull --ff-only

PY="$HOME/.venvs/sablectl/bin/python"

"$PY" -m pytest \
  tools/validation/release-r1/test_release_preflight.py \
  tools/validation/release-r1/test_release_preflight_r0r2.py \
  -q

R1_R0R2_TEST_RC=$?
echo "R1_R0R2_TEST_RC=$R1_R0R2_TEST_RC"

if [[ "$R1_R0R2_TEST_RC" -eq 0 ]]; then
  env \
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
    "$PY" tools/validation/release-r1/SABLE_R1_R0R2_RELEASE_PREFLIGHT.py

  R1_R0R2_RC=$?
  echo "R1_R0R2_RC=$R1_R0R2_RC"
fi
```

Do not add `--hash-container` or `--full-zip-crc` for the routine pass.

Expected high-level result:

```text
ERROR=0
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
R1_R0R2_RC=3
```

Expected blocker families include:

```text
UPDATER_STILL_POINTS_TO_GRAPHENEOS
PRODUCTION_KEYS_NOT_PROVISIONED_OR_NOT_CUSTODY_VALIDATED
UPSTREAM_KEY_GENERATOR_SUBJECT_IS_GRAPHENEOS
PRODUCTION_SOURCE_SEAL_NOT_YET_DEFINED
CURRENT_ARTIFACT_IS_USERDEBUG
CURRENT_ARTIFACT_USES_TEST_KEYS
CURRENT_ARTIFACT_MAY_OMIT_OFFICIAL_UPDATER
CURRENT_TARGET_FILES_CONTAINS_TEST_KEY_SIGNING_METADATA
```

The exact blocker count must come from the live ThinkPad run.

## 14. R1-R1 boundary after the live R0R2 preflight

R1-R1 should close policy/configuration blockers **before key generation**:

1. choose the Sable update-server HTTPS base URL;
2. define the Sable certificate subject / DN policy;
3. define encrypted key custody, backups, operator access, and audit records;
4. define the production source-seal schema;
5. define the first production build number and reproducibility inputs;
6. prepare the bounded Updater/config + release-source mutation;
7. statically validate the key-generation harness without generating keys;
8. request explicit authorization only after all of the above is sealed.

No production signing key should exist before that boundary is closed.
