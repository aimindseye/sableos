# SableOS R1-R0 — release-engineering preflight and signing/OTA architecture

Date: 2026-09-08
Status: **DELIVERED / LIVE READ-ONLY PREFLIGHT PENDING**
Device scope: Pixel 7 (`panther`)
Canonical Android substrate: GrapheneOS `2026081300` / Android 17

## 1. Purpose

D4 is closed for the current Panther B2 development population. R1 begins the transition from a physically validated `userdebug/test-keys` development build to a Sable-owned release pipeline.

R1-R0 does **not** generate keys, build, sign, create an OTA, contact a device, reboot, flash, change slots, lock/unlock a bootloader, or wipe data. Its purpose is to bind the exact upstream release tooling, inventory the current development artifact's signing state, identify production blockers, and define the trust/custody architecture before any irreversible key material is created.

R1-R0 therefore separates:

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
exit=3
```

A blocker result is expected and healthy at this stage. It prevents development artifacts or upstream Graphene identity from being promoted into a Sable release by accident.

## 2. Bound upstream release-tooling substrate

The signed GrapheneOS `2026081300` manifest pins:

```text
script                         b54206456a15f1c1ef5776b752d2705fe75f1b0a
packages/apps/Updater          d7e29f110890de68b63bb8c256b4d249a2d29cf9
```

The Sable baseline lock already binds the canonical pinned manifest SHA-256:

```text
c50f0096f538e604aa008e8ab4e3f1a3739f142c60c878a32f402c11eb406572
```

The preflight independently runs the read-only command:

```text
repo manifest -r
```

and requires that exact manifest hash. It also binds the `script` and `Updater` repository heads using read-only `git rev-parse HEAD` queries.

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

The preflight does not recompute the 3.65 GB container hash by default because D4 already sealed it. `--hash-container` enables an independent full SHA-256 pass when specifically desired. A full ZIP-member CRC scan is also off by default and must be requested with `--full-zip-crc`.

The default audit reads only bounded metadata and build-property entries from target-files.

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

In addition, Panther release engineering needs:

```text
avb.pem         AVB RSA-4096 private key
avb_pkmd.bin    derived AVB public-key metadata for device verified boot
id_ed25519      OpenSSH private key used to sign factory-image archives
```

The pinned `generate-release.sh` uses the release-key directory to:

1. replace public build test keys in target-files;
2. sign AVB/vbmeta with the per-device AVB key;
3. sign APEX containers/payloads using the configured releasekey/AVB mapping;
4. create the signed full OTA package;
5. create signed image/factory artifacts;
6. optionally create a detached OpenSSH signature for the factory-image archive.

The OTA package is signed with `releasekey`. AOSP documents that released images must replace the default public test key so that only packages signed by the release owner are accepted.

## 5. Critical Sable key-generation rule

The pinned upstream file:

```text
script/generate-keys
```

contains:

```text
CN=GrapheneOS
```

That script must **not** be run unchanged for Sable production keys.

R1-R1 must choose and bind a Sable-owned certificate subject before generation. A minimal intended identity is:

```text
CN=SableOS
```

but the final distinguished-name policy is an R1-R1 decision and must be recorded before key creation. Key generation requires separate explicit authorization.

## 6. Key custody policy to approve before generation

Production keys are long-lived release trust anchors, not ordinary build artifacts.

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

The persistent key set should be encrypted at rest. The GrapheneOS release script copies persistent keys to `/dev/shm`, decrypts them there, and removes the temporary key directory on exit. This is a useful base model, but Sable must separately define where the persistent encrypted master set is stored, who can initiate signing, how backups are protected, and how public fingerprints are recorded.

The R1-R0 preflight intentionally **never reads or hashes private-key bytes**. If `keys/panther` already exists, it reports the directory as present-but-unvalidated rather than inspecting its contents.

## 7. Sable Updater ownership is a hard release blocker

The exact GrapheneOS `2026081300` Updater configuration is:

```text
https://releases.grapheneos.org/
```

GrapheneOS explicitly instructs derivative builders to replace this with their own update-server URL before setting:

```text
OFFICIAL_BUILD=true
```

Using the official GrapheneOS endpoint with differently signed artifacts causes the Updater to retrieve GrapheneOS releases that cannot validate under Sable keys and can repeatedly retry them.

Therefore R1 requires:

```text
SABLE_UPDATE_BASE_URL=DECIDED
SABLE_UPDATE_BASE_URL_HTTPS=YES
GRAPHENE_UPDATE_URL_PRESENT=NO
OFFICIAL_BUILD=true
```

No update-server hostname is invented by R1-R0. The project owner must select the Sable-owned HTTPS endpoint before the first official build.

## 8. Production build policy

The current B2 artifact is intentionally:

```text
userdebug
test-keys
```

It is not eligible for production promotion.

The first Sable production candidate must be rebuilt as:

```text
lunch panther-cur-user
OFFICIAL_BUILD=true
```

with a new monotonically increasing `BUILD_NUMBER`, a Sable-owned Updater endpoint, and an exact release-source seal.

The recommended build-number policy remains the date/revision shape already used by the project:

```text
YYYYMMDDRR
```

Rules:

```text
BUILD_NUMBER_MONOTONIC=YES
BUILD_NUMBER_REUSE=NO
SOURCE_SEAL_BEFORE_BUILD=REQUIRED
USER_BUILD=REQUIRED
RELEASE_SIGNING_AFTER_TARGET_FILES=REQUIRED
```

## 9. Source identity gate

D4 proves the exact development B2 packaged population, but R1 must define a production source seal before the first `user` build.

That seal should bind at least:

```text
GrapheneOS manifest tag + manifest SHA-256
all pinned repo revisions
Sable delta repository commit(s)
Sable patch/input hashes
Updater endpoint change
release/version configuration
vendor-state identity
host release-tool versions that remain external inputs
BUILD_NUMBER
BUILD_DATETIME policy/value
```

R1-R0 reports this as a blocker until the production source-seal format is defined.

## 10. Release artifact pipeline

Once R1-R0 blockers are closed and later phases are separately authorized, the intended flow is:

```text
SIGNED GRAPHENE TAG 2026081300
        +
PINNED SABLE RELEASE DELTA
        +
SABLE UPDATER ENDPOINT
        +
OFFICIAL_BUILD=true
        +
PANther USER BUILD
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

The exact GrapheneOS script supports `panther` in its release-generation path.

## 11. OTA policy

AOSP `ota_from_target_files` consumes target-files for both full and incremental A/B OTA packages.

Sable policy:

```text
FULL_OTA_FROM_SIGNED_TARGET_FILES=REQUIRED
SIGNED_TARGET_FILES_RETAINED_PER_RELEASE=REQUIRED
INCREMENTAL_OTA_SOURCE_AND_TARGET_SIGNED_TARGET_FILES=REQUIRED
TESTING_CHANNEL_FIRST=REQUIRED
BETA_BEFORE_STABLE=RECOMMENDED
FUTURE_UPDATE_PATH_TEST=REQUIRED
```

The GrapheneOS build guide recommends publishing first to an internal testing channel and then testing that the candidate can update to a sample future release before promotion. Sable adopts that as a release gate.

## 12. First transition from D4 test keys to Sable release keys

The current Panther is running an unlocked, `test-keys` development build. The first production-key transition is **not** an ordinary in-place OTA acceptance path.

GrapheneOS documents that the per-device release keys must be retained for subsequent builds and that changing them later requires flashing factory images again, which resets the device.

Therefore the first Sable release-key install is a separately authorized future phase with an explicit migration plan covering:

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

R1-R0 authorizes none of those operations.

## 13. Preflight tool

Tool:

```text
tools/validation/release-r1/SABLE_R1_R0_RELEASE_PREFLIGHT.py
```

It enforces this authorization context:

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

If any of those variables is not `NO`, the preflight refuses to proceed.

It performs only:

- file reads;
- ZIP metadata/member reads;
- hashing of small evidence files and optionally the target-files container;
- `repo manifest -r`;
- `git -C <repo> rev-parse HEAD`;
- `/tmp` evidence creation.

It never executes `adb`, `fastboot`, `make_key`, `sign_target_files_apks`, `ota_from_target_files`, `generate-release.sh`, or a build command.

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

python3 tools/validation/release-r1/SABLE_R1_R0_RELEASE_PREFLIGHT.py
RC=$?
echo "R1_R0_RC=$RC"
```

Do not add `--hash-container` for the routine first pass. The B2 container is already independently sealed by D4.

Expected current high-level result:

```text
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
R1_R0_RC=3
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

The exact blocker count must come from the live ThinkPad preflight; it is not asserted in advance.

## 14. R1-R1 boundary after the live preflight

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
