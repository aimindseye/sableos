# SableOS R1-R2 — static source-mutation / keygen preparation and ThinkPad disk audit

Date: 2026-09-08  
Status: **DELIVERED / LIVE READ-ONLY GATES PENDING**

## Scope

R1-R2 is a non-mutating preparation milestone. It does not modify Android source, generate production keys, build, sign, generate OTA/factory artifacts, contact a device, reboot, flash, change slots, lock/unlock a bootloader, or wipe data.

Two read-only gates are delivered:

1. `tools/validation/release-r1/SABLE_R1_R2_STATIC_PREFLIGHT.py`
2. `tools/maintenance/SABLE_DISK_SPACE_AUDIT.py`

The static preflight writes only candidate postimages, a unified patch, and audit evidence under `/tmp`. The disk audit only measures an explicit allowlist of known paths and direct Sable/Panther evidence directories under `/tmp`; it contains no deletion path.

## Exact two-file future Android source mutation

The plan is byte-bound in `release/r1/r1-r2-source-mutation-plan-v1.json`.

### `script/generate-keys`

```text
preimage git blob = 5c38a53eeda4eb16c55bd3a3ad776a3cb1d6349e
preimage sha256   = f47098e935b3418f267c2f06f41105d01fef57ed74e872a46e888d63cf89f588

    CN=GrapheneOS
 -> CN=SableOS

postimage git blob = 211209f492071e3a9f9c4247ad63c2dee3ffbf30
postimage sha256   = c9957d82c62c61ec404c2d7366b0d80b71d98e2e6a6df60322fe066f0d58b440
```

### `packages/apps/Updater/res/values/config.xml`

```text
preimage git blob = b3804bbeb82f3f6abda53f6401f8d1119dd5416d
preimage sha256   = bf91595fb7d229ae752bf25e6ab806950f848adb4a9dde9f9d1f8778d811d59a

https://releases.grapheneos.org/
 -> https://updates.sableos.org/

postimage git blob = 9c0b38b3189c9674d4a150ffead95336211d462c
postimage sha256   = 84a7aac655c3e863cb1b473b11d12269baa16c44ccc242757d9c2c9051428b3d
```

R1-R2 does not apply either postimage.

## Key-generation safety finding

The pinned Android 17 `development/tools/make_key` implementation has good raw-key handling via named pipes, but it is not acceptable for direct Sable production use with a non-empty password. It explicitly tells the operator that the password will be visible and later prints the password value to stdout.

The Sable production contract therefore requires a Sable-owned harness with:

```text
RAW_PRIVATE_KEY_STAGING=TMPFS_ONLY
PERSISTENT_KEY_STORE=OFFLINE_ENCRYPTED_EXTERNAL_TO_ANDROID_WORKSPACE
PERSISTENT_WORKSPACE_KEY_MATERIAL=NO
PASSPHRASE_PROMPT_HIDDEN=YES
PASSPHRASE_IN_ARGV=NO
PASSPHRASE_IN_ENVIRONMENT=NO
PASSPHRASE_IN_LOGS=NO
PASSPHRASE_CHILD_TRANSPORT=INHERITED_FD_OR_EQUIVALENT
APK_KEYS=RSA_4096
APK_CERT_DIGEST=SHA256
APK_CERT_VALIDITY_DAYS=10000
APK_PK8=DER_SCRYPT_ENCRYPTED
AVB_ALGORITHM=SHA256_RSA4096
FACTORY_ARCHIVE_KEY=id_ed25519_ENCRYPTED
ATOMIC_EXTERNAL_PUBLISH=YES
REFUSE_EXISTING_DESTINATION=YES
```

This is a static contract only. No production key-generation executable is authorized or executed by R1-R2.

## Disk-space audit policy

The audit reports these known paths separately:

```text
KEEP
  out_d4_b2_final

REVIEW_RECLAIM
  out_graphene_control
  out_c2r32_sable_fresh

REVIEW_RECLAIM_HIGH_VALUE
  /srv/data/aosp_panther17_workspace

DO_NOT_TOUCH_OTHER_DEVICE
  /srv/data/aosp_bramble_workspace

KEEP
  canonical Android source workspace
  /home/mindseye73/sableos-tools

REVIEW_CACHE
  ~/.ccache

REVIEW_CACHE_BROAD
  ~/.cache
```

No directory in any category is automatically deleted. The measured audit is used to prepare a later exact-path cleanup proposal. In particular, B2 and the canonical source workspace remain protected by default.

The audit also reports B1/B2/C2 target-files archive sizes and the aggregate/largest direct `/tmp/SABLE_*` and `/tmp/PANTHER_*` evidence directories. `--hash-target-files` is optional because hashing multi-gigabyte archives is expensive and is not needed for the first space inventory.

## Pre-delivery validation

```text
PINNED_PUBLIC_PRE_POST_BINDINGS=PASS_2_OF_2
R1_R2_EXECUTION_SURFACE_SCAN=PASS
DISK_AUDIT_DELETE_SURFACE=ABSENT
R1_R2_AND_DISK_TESTS=PASS_31_OF_31
```

The test suite covers authorization ordering, exact source head/blob/hash drift, duplicate replacement detection, postimage binding, policy binding, endpoint ownership, upstream make_key drift, existing workspace key material, keygen secret-safety policy drift, repeated evidence-directory uniqueness, disk audit non-deletion, bounded `/tmp` discovery, optional target-files hashing, and fresh-process CLI startup.

## Authorization boundary

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

A successful R1-R2 static preflight means only that the exact source mutation is ready for a later separate authorization. It does not grant that authorization and does not authorize production key generation.
