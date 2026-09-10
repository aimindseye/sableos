# SableOS R1-R1 closure — release identity, endpoint, source-seal and key-custody policy

Date: 2026-09-08  
Device: Pixel 7 (`panther`)  
Status: **CLOSED**

## Closure result

R1-R1 is closed as a read-only release-policy and custody gate. The endpoint-bound policy completed with no blockers or errors:

```text
R1_R1_TESTS=PASS_34_OF_34
PASS=55 BLOCKER=0 INFO=9 SKIP=0 ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=READY_TO_REQUEST_KEYGEN_AUTHORIZATION
R1_R1_ENDPOINT_RC=0
```

Evidence directory:

```text
/tmp/SABLE_R1_R1_POLICY_PREFLIGHT_20260909T002354Z_qdw0b9dv
```

A zero exit code means only that policy is complete enough to request a separately authorized key-generation phase. It does not authorize key generation, source mutation, build, signing, OTA generation or device operations.

## Canonical release policy

```text
path=release/r1/panther-release-policy-v1.json
sha256=32d09f8ccb7b21bca083c8db3d41ae838daa1ee46e953454dfdb3c3f596a8c92
git_blob=9db278de6bdaa8781043762a326f2f9df03f0902
```

Release identity:

```text
CERTIFICATE_SUBJECT=CN=SableOS
SABLE_UPDATE_BASE_URL=https://updates.sableos.org/
UPDATE_ENDPOINT_OWNER=SableOS
UPDATE_ENDPOINT_OWNERSHIP_STATUS=OPERATOR_VERIFIED
BUILD_VARIANT=user
OFFICIAL_BUILD=true
BUILD_NUMBER_SCHEME=YYYYMMDDRR
BUILD_NUMBER_REUSE=NO
```

## Endpoint validation

Before policy closure, the Sable-owned update endpoint was independently exercised through the public custom domain.

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

The first endpoint attempt was challenged by Cloudflare and was not accepted. After the challenge-producing configuration was corrected, ordinary machine GET/HEAD and byte-range requests succeeded. R1-R1 therefore binds the final custom-domain base URL, not an `r2.dev` or GitHub-hosted URL.

## Historical R1-R1 progression

Initial live policy gate before the endpoint was supplied:

```text
PASS=54 BLOCKER=1 INFO=9 SKIP=0 ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=BLOCKED_1
R1_R1_RC=3
SOLE_BLOCKER=policy.update_endpoint=UNSET
EVIDENCE_DIR=/tmp/SABLE_R1_R1_POLICY_PREFLIGHT_20260908T231345Z_fts6loeb
```

The endpoint was then staged in `/tmp`, with the exact policy delta limited to:

```text
update_endpoint.url:
  null -> https://updates.sableos.org/

update_endpoint.ownership_status:
  UNVERIFIED -> OPERATOR_VERIFIED

update_endpoint.note:
  stale unresolved-endpoint note -> endpoint-validation record
```

The final candidate identity was:

```text
sha256=32d09f8ccb7b21bca083c8db3d41ae838daa1ee46e953454dfdb3c3f596a8c92
git_blob=9db278de6bdaa8781043762a326f2f9df03f0902
```

The canonical repository policy was committed with that exact Git blob.

## Bound policy

R1-R1 retains the exact nine GrapheneOS 2026081300 signing domains:

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

Future Panther key inventory remains:

```text
<domain>.pk8 + <domain>.x509.pem for all nine domains
avb.pem
avb_pkmd.bin
id_ed25519
```

Custody policy remains:

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

## Exact future Android source mutation scope

No Android source mutation was performed during R1-R1. The separately authorized future source delta remains exactly two files:

```text
script/generate-keys
    CN=GrapheneOS
 -> CN=SableOS

packages/apps/Updater/res/values/config.xml
    https://releases.grapheneos.org/
 -> https://updates.sableos.org/
```

No change to `script/common.sh` signing domains is planned.

## Authorization boundary after closure

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

The next release-engineering deliverable is a static/adversarially validated exact two-file source-mutation harness plus key-generation harness design. Neither should be executed until independently sealed and separately authorized.

```text
R1_R1=CLOSED
KEY_GENERATION_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
```
