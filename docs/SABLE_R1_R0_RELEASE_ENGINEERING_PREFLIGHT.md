# SableOS R1-R0 — release-engineering preflight and signing/OTA architecture

Date: 2026-09-08  
Status: **CLOSED**  
Device scope: Pixel 7 (`panther`)  
Canonical Android substrate: GrapheneOS `2026081300` / Android 17

R1-R0 is the completed read-only inventory that established the transition from the physically validated `userdebug/test-keys` D4 population to a Sable-owned production release pipeline.

The authoritative closure record is:

- `docs/SABLE_R1_R0_CLOSURE_20260908.md`
- `release/r1/r1-r0-closure-20260908.json`

The current next-stage policy is:

- `docs/SABLE_R1_R1_RELEASE_POLICY_AND_CUSTODY.md`
- `release/r1/panther-release-policy-v1.json`
- `release/r1/release-source-seal-v1.schema.json`

## Execution lineage

```text
SABLE_R1_R0_RELEASE_PREFLIGHT.py      HISTORICAL BYTE-BOUND BASE
SABLE_R1_R0R1_RELEASE_PREFLIGHT.py    SUPERSEDED / SELF-RECURSION DEFECT
SABLE_R1_R0R2_RELEASE_PREFLIGHT.py    SUPERSEDED / TARGET-IDENTITY DEFECT
SABLE_R1_R0R3_RELEASE_PREFLIGHT.py    FINAL R1-R0 EXECUTABLE
```

Final R0R3 identity:

```text
sha256=595db875192ab5c3753e6d31698bce8adefdd3af5900de217bf4ea987ef7b88f
git_blob=e35081e18cbbd12e7d49accb26766bc03721c649
```

## Final live result

```text
BRANCH_BINDING=PASS
R1_R0R3_FILE_BINDINGS=PASS
PY_COMPILE=PASS_6_OF_6
R1_R0R3_TESTS=PASS_38_OF_38

PASS=19
BLOCKER=10
INFO=11
SKIP=2
ERROR=0

R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_10
R1_R0R3_RC=3
```

Evidence directory:

```text
/tmp/SABLE_R1_R0_RELEASE_PREFLIGHT_20260908T225032Z_wfba8zy8
```

`RC=3` is the successful R1-R0 audit outcome: the inventory completed with no error and identified ten genuine release-readiness blockers.

## Bound upstream release-tooling substrate

R1-R0 bound the exact GrapheneOS `2026081300` release tooling, including:

```text
script                         b54206456a15f1c1ef5776b752d2705fe75f1b0a
packages/apps/Updater          d7e29f110890de68b63bb8c256b4d249a2d29cf9
pinned manifest sha256         c50f0096f538e604aa008e8ab4e3f1a3739f142c60c878a32f402c11eb406572
```

It established the nine signing domains:

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

and the additional Panther release trust material:

```text
avb.pem
avb_pkmd.bin
id_ed25519
```

## Key release-engineering findings

The pinned upstream `script/generate-keys` uses:

```text
CN=GrapheneOS
```

and must not be used unchanged for Sable production keys.

The pinned Updater configuration uses:

```text
https://releases.grapheneos.org/
```

and must be changed to a Sable-owned HTTPS endpoint before an official Sable release build.

The current B2 artifact remains intentionally:

```text
userdebug
test-keys
```

and is not eligible for production promotion. Production requires a fresh `panther-cur-user` build with `OFFICIAL_BUILD=true`, Sable release keys, a sealed release source state, signed target-files/factory artifacts and subsequent OTA validation.

## Final ten blockers

```text
1  upstream generate-keys subject is GrapheneOS
2  Updater URL is releases.grapheneos.org
3  final Panther production keyset absent
4  production source-seal policy undefined
5  current artifact is userdebug
6  current artifact uses test-keys
7  current artifact omits official Updater
8  apkcerts contains test-key references
9  apexkeys contains test-key references
10 misc_info contains test-key references
```

These are now owned by R1-R1 and later separately authorized R1 build/signing phases.

## Safety boundary

R1-R0 performed no key generation, Android source mutation, build, signing, OTA generation, device contact, reboot, flash, slot change, bootloader lock/unlock or userdata/metadata wipe.

The current policy/configuration phase remains under:

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

No key-generation authorization should be requested until the R1-R1 policy gate is complete.
