# SableOS R1-R1 — release identity, source-seal and key-custody policy

Date: 2026-09-08  
Status: **DELIVERED / LIVE READ-ONLY POLICY PREFLIGHT PENDING**

## Purpose

R1-R1 defines and validates the policy/configuration required *before* production signing-key generation can be requested. It is intentionally non-mutating.

R1-R1 does **not**:

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

## Release identity

The adopted certificate identity is:

```text
CN=SableOS
```

The pinned upstream `script/generate-keys` currently uses `CN=GrapheneOS`; R1-R1 records a future two-file mutation plan but does not apply it.

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

## Update endpoint

No Sable update hostname is invented by this deliverable.

The checked-in policy intentionally contains:

```json
"update_endpoint": {
  "url": null,
  "owner": "SableOS",
  "ownership_status": "UNVERIFIED"
}
```

The R1-R1 gate will remain `BLOCKED_1` until an operator supplies a real Sable-controlled HTTPS base URL and marks ownership as verified.

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

R1-R1 permits only this *plan*:

```text
script/generate-keys
    CN=GrapheneOS
 -> CN=SableOS

packages/apps/Updater/res/values/config.xml
    https://releases.grapheneos.org/
 -> <operator-selected Sable-owned HTTPS base URL>
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

## Exit semantics

```text
0  policy complete; eligible to REQUEST separate key-generation authorization
2  audit ERROR; policy state not trustworthy
3  audit completed; one or more policy BLOCKERs remain
```

A zero exit code **does not itself authorize key generation**.

With the delivered policy, the expected initial live result is:

```text
ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=BLOCKED_1
R1_R1_RC=3
```

The sole expected blocker is the intentionally unset Sable-owned update endpoint.
