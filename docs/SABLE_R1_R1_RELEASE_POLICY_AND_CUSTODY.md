# SableOS R1-R1 — release identity, source-seal and key-custody policy

Date: 2026-09-08  
Status: **CLOSED**

## Purpose

R1-R1 defines and validates the policy/configuration required before production signing-key generation can be requested. It is intentionally non-mutating.

R1-R1 did **not**:

```text
generate keys
modify Android source
build Android
sign target-files
create OTAs
create factory images
contact a device
reboot/flash/change slots
lock or unlock a bootloader
wipe userdata or metadata
```

Final closure is recorded in:

```text
docs/SABLE_R1_R1_CLOSURE_20260908.md
release/r1/r1-r1-closure-20260908.json
```

## Final live result

```text
R1_R1_TESTS=PASS_34_OF_34
PASS=55 BLOCKER=0 INFO=9 SKIP=0 ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=READY_TO_REQUEST_KEYGEN_AUTHORIZATION
R1_R1_ENDPOINT_RC=0
```

Evidence:

```text
/tmp/SABLE_R1_R1_POLICY_PREFLIGHT_20260909T002354Z_qdw0b9dv
```

A zero exit code means only that policy is complete enough to request separate key-generation authorization. It does not authorize key generation.

## Release identity

```text
CERTIFICATE_SUBJECT=CN=SableOS
SABLE_UPDATE_BASE_URL=https://updates.sableos.org/
UPDATE_ENDPOINT_OWNER=SableOS
UPDATE_ENDPOINT_OWNERSHIP_STATUS=OPERATOR_VERIFIED
```

The canonical policy is:

```text
release/r1/panther-release-policy-v1.json
sha256=32d09f8ccb7b21bca083c8db3d41ae838daa1ee46e953454dfdb3c3f596a8c92
git_blob=9db278de6bdaa8781043762a326f2f9df03f0902
```

The pinned upstream `script/generate-keys` still uses `CN=GrapheneOS`; R1-R1 records a future source mutation but does not apply it.

The exact signing domains remain:

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

Future Panther key inventory also requires:

```text
avb.pem
avb_pkmd.bin
id_ed25519
```

The upstream key generator creates the APK/certificate pairs and AVB key/material but does not create `id_ed25519`; the later authorized Sable key-generation harness must generate the factory-archive OpenSSH key separately.

## Update endpoint validation

The first custom-domain test was challenged by Cloudflare and was rejected for OTA use. After the challenge-producing configuration was corrected, the public endpoint passed machine access:

```text
DNS_PUBLIC_RESOLUTION=PASS
HTTPS_OBJECT_GET=PASS
HTTPS_HEAD_STATUS=200
HTTP_RANGE_STATUS=206
CONTENT_RANGE=bytes 0-5/23
RANGE_BODY=SableO
CLOUDFLARE_INTERACTIVE_CHALLENGE=ABSENT_AFTER_CONFIGURATION
OTA_MACHINE_ACCESS=PASS
```

R1-R1 therefore binds:

```text
https://updates.sableos.org/
```

rather than an `r2.dev`, GitHub Pages or GitHub Releases URL.

The validator rejects:

```text
non-HTTPS URLs
GrapheneOS hosts
localhost / .local
reserved test/example/invalid hostnames
IP literals
embedded credentials
query strings or fragments
base URLs without a trailing slash
owner != SableOS
ownership_status != OPERATOR_VERIFIED
```

## Exact planned source mutation scope

R1-R1 permits only this future plan:

```text
script/generate-keys
    CN=GrapheneOS
 -> CN=SableOS

packages/apps/Updater/res/values/config.xml
    https://releases.grapheneos.org/
 -> https://updates.sableos.org/
```

Both remain behind future `SOURCE_MUTATION_AUTHORIZED=YES`.

No change to `script/common.sh` signing-key domains is planned.

## Key custody

Normative policy:

```text
UNIQUE_KEYS_PER_DEVICE_VARIANT=YES
PRIVATE_KEYS_IN_GIT=NO
PERSISTENT_PRIVATE_KEYS_OUTSIDE_ANDROID_WORKSPACE=YES
ENCRYPTED_AT_REST=YES
OFFLINE_BACKUPS>=2
BACKUPS_PHYSICALLY_SEPARATED=YES
OPERATOR_AUTHORIZATION_REQUIRED=YES
SIGNING_SESSION_AUDIT_REQUIRED=YES
DECRYPTED_WORKDIR=TMPFS
PASSPHRASE_IN_ARGV=NO
PASSPHRASE_IN_REPO=NO
PRIVATE_KEY_MATERIAL_IN_PUBLIC_EVIDENCE=NO
PRIVATE_KEY_HASHES_IN_PUBLIC_EVIDENCE=NO
```

The persistent store is classified as `OFFLINE_ENCRYPTED_EXTERNAL_TO_WORKSPACE`. During a separately authorized signing session, only an ephemeral `keys/panther` binding may expose the encrypted Panther keyset to the pinned release script. The pinned `generate-release.sh` then copies keys into `/dev/shm` and invokes `decrypt-keys` there.

The later key-generation procedure must also account for the OpenSSH `id_ed25519` passphrase separately because the pinned `encrypt-keys` / `decrypt-keys` scripts handle the Android signing keys and AVB key, not the OpenSSH key.

## Build policy

```text
TARGET=panther-cur-user
OFFICIAL_BUILD=true
BUILD_NUMBER_FORMAT=YYYYMMDDRR
BUILD_NUMBER_REUSE=NO
BUILD_NUMBER_ALLOCATED_AFTER_SOURCE_SEAL=YES
BUILD_DATETIME=PINNED_AND_RECORDED
TESTING_CHANNEL_FIRST=YES
FUTURE_UPDATE_PATH_TEST=REQUIRED
```

The current B2 `userdebug/test-keys` artifact is never promoted directly into production. A new user build is required.

## Release source seal v1

`release/r1/release-source-seal-v1.schema.json` requires:

```text
schema_version
device
graphene_manifest_tag
pinned_manifest_sha256
pinned_repo_manifest
sable_tools_commit
sable_delta_commits
release_policy_sha256
updater_config_sha256
release_tooling_heads
vendor_state_commit
build_number
build_variant
official_build
build_datetime_policy
host_tool_hashes
```

Private key material and private-key hashes are explicitly prohibited from the source seal.

## Pinned source contract checked by R1-R1

The validator binds the exact GrapheneOS `2026081300` source preimages for:

```text
script/common.sh
script/generate-keys
script/encrypt-keys
script/decrypt-keys
script/generate-release.sh
packages/apps/Updater/res/values/config.xml
```

It also confirms the script/Updater repository heads, nine signing domains, current upstream `CN=GrapheneOS`, current GrapheneOS update URL, tmpfs encrypt/decrypt design, and release flow tokens for target-files signing, OTA generation, factory image generation and optional `id_ed25519` factory archive signing.

## Historical gate progression

Initial live run with the endpoint intentionally unset:

```text
PASS=54 BLOCKER=1 INFO=9 SKIP=0 ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=BLOCKED_1
R1_R1_RC=3
EVIDENCE_DIR=/tmp/SABLE_R1_R1_POLICY_PREFLIGHT_20260908T231345Z_fts6loeb
```

The sole blocker was `policy.update_endpoint=UNSET`.

The endpoint-bound candidate was staged in `/tmp`, validated with the unchanged 34-test suite, then executed against the unchanged R1-R1 validator with all mutation/device authorizations disabled. It closed at `55/0/9/0/0` and `RC=0`.

## Authorization boundary after R1-R1 closure

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

## Next gate

The next deliverable is a statically and adversarially validated exact two-file source-mutation harness plus key-generation harness design. Neither is to be executed until independently sealed and separately authorized.
