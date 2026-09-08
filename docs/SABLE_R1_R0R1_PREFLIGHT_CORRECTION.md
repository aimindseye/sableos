# Sable R1-R0R1 — release-preflight parser correction

Date: 2026-09-08

## Disposition

The first physical-host R1-R0 run correctly bound the script and passed its 9/9 unit suite, but the preflight ended with two parser-originated `ERROR` results:

```text
signing.generator_subject=ERROR_UNPARSEABLE
artifact.device=ERROR_GENERIC
R1_R0_PREFLIGHT_EXECUTION=ERROR
R1_R0_RC=2
```

Neither result is a product/release defect.

### Defect 1 — key-generator subject parser

The exact pinned GrapheneOS `script/generate-keys` uses an indented shell assignment:

```text
    CN=GrapheneOS
```

The R1-R0 parser anchored `CN=` at column 1 and therefore failed to parse the exact upstream file. R0R1 accepts normal shell indentation and quoted/unquoted values. The resulting semantic classification remains fail-closed:

```text
signing.generator_subject=BLOCKER
expected=Sable-owned certificate subject
actual=GrapheneOS
```

The correction does **not** authorize key generation and does not change the policy that the upstream generator must not be used unchanged for Sable production keys.

### Defect 2 — target product identity

The R1-R0 parser took the first `ro.product.device` from `SYSTEM/build.prop`. On modern target-files this partition property can legitimately be `generic`; it is not authoritative package/product identity.

R0R1 resolves product identity in this order:

1. bounded read of `OTA/android-info.txt` and `require product=...`;
2. if unavailable, bounded reads of partition build properties in product/vendor/odm/system_ext/system order;
3. generic system identity is not promoted to device identity.

For Panther target-files, the expected result is:

```text
artifact.device=PASS
expected=panther
actual=panther
```

## Scope

Canonical corrected entrypoint:

```text
tools/validation/release-r1/SABLE_R1_R0R1_RELEASE_PREFLIGHT.py
```

It binds and reuses the original R1-R0 implementation:

```text
BASE_R1_R0_SHA256=cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7
```

Published correction-layer identity:

```text
GIT_BLOB_SHA1=8cfc3f129dc8937d6a524b7031c1ab85c8434d1e
SHA256=2a1cb305ae0c0a3d8480a11b2156b099d71ca21d1d6791fb0ecdef158d6928c8
```

The correction layer changes only the two parser functions. Authorization enforcement, source/tool revision binding, target-files inventory, blocker policy, evidence writing, bounded ZIP policy, and exit-code semantics remain owned by the bound R1-R0 base.

## Safety

R1-R0R1 remains strictly read-only with respect to the Android workspace and device:

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

The correction layer has no subprocess execution backend of its own. The bound R1-R0 base remains limited to its previously tested read-only `repo manifest -r` and `git rev-parse HEAD` subprocess surface.

## Validation

Existing R1-R0 tests:

```text
9/9 PASS on the ThinkPad before the first live audit
```

Focused R0R1 correction tests cover:

```text
BASE_SCRIPT_SHA256_BINDING
INDENTED_AND_QUOTED_CN_PARSE
ANDROID_INFO_PRODUCT_PARSE
OTA_PRODUCT_OVERRIDES_GENERIC_SYSTEM
PARTITION_FALLBACK_REJECTS_GENERIC_SYSTEM
NO_CORRECTION_LAYER_EXECUTION_BACKEND
```

Local focused result:

```text
6/6 PASS
```

The combined ThinkPad suite must be run before accepting the corrected live preflight.

## Expected corrected live disposition

The existing valid release blockers are intentionally retained, including:

- GrapheneOS updater URL;
- missing final Sable per-device signing-key set / custody validation;
- undefined R1 production source seal;
- current `userdebug` build type;
- current `test-keys` build tags;
- Updater omitted from the current development B2 artifact;
- test-key references in current APK/APEX/misc signing metadata;
- upstream `CN=GrapheneOS` generator subject, now correctly classified as a blocker.

A healthy R0R1 execution therefore ends:

```text
ERROR=0
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
R1_R0R1_RC=3
```

The blocker count is taken from the live corrected run and is not predeclared as evidence.
