# Sable R1-R0R2 — superseded preflight correction

Date: 2026-09-08
Status: **SUPERSEDED / DO NOT EXECUTE**
Superseded by: `SABLE_R1_R0R3_RELEASE_PREFLIGHT.py`

## Historical purpose

R0R2 fixed the R0R1 monkeypatch self-recursion by capturing the original base `find_build_properties` function before patching and restoring all patched globals in `finally`. That architecture remains valid and is retained by R0R3.

R0R2 also retained the correct parser for the indented upstream `CN=GrapheneOS` assignment.

## Live ThinkPad result

R0R2 passed branch/file binding, compile and the combined 20-test gate, then completed the read-only audit with one remaining harness error:

```text
PASS=18 BLOCKER=10 INFO=11 SKIP=2 ERROR=1
R1_R0_PREFLIGHT_EXECUTION=ERROR
R1_RELEASE_READINESS=UNKNOWN
R1_R0R2_RC=2
```

The corrected key-generator classification worked:

```text
signing.generator_subject=BLOCKER
actual=GrapheneOS
```

The sole `ERROR` was:

```text
artifact.device=ERROR
expected=panther
actual=generic
```

This was not a release/product contradiction. The exact B2 artifact, source manifest, BuildManifest, A/B metadata, build type/tags and ten release blockers were otherwise inventoried correctly.

## R0R2 target-identity defect

R0R2 attempted to recover product identity from `OTA/android-info.txt` or from legacy `ro.product.device` values in assumed partition paths. That model was incomplete for the exact pinned Android 17 build system.

The pinned GrapheneOS `2026081300` manifest resolves `platform_build` to:

```text
7f0398241bc8c4ef5255a8063befa5045e5cfab4
```

At that exact revision, `core/sysprop.mk` emits partition-scoped identities such as:

```text
ro.product.system.device=$(TARGET_DEVICE)
ro.product.vendor.device=$(TARGET_DEVICE)
ro.product.product.device=$(TARGET_DEVICE)
ro.product.odm.device=$(TARGET_DEVICE)
ro.product.system_ext.device=$(TARGET_DEVICE)
```

and product/ODM/system_ext properties are stored below `etc/build.prop`.

R0R2 looked for the wrong property key and several wrong paths. It is therefore superseded for execution.

## Formal disposition

```text
R1_R0R2_BINDING=PASS
R1_R0R2_COMPILE=PASS
R1_R0R2_COMBINED_TESTS=PASS_20_OF_20
R1_R0R2_FAILURE_CLASS=HOST_HARNESS_TARGET_FILES_DEVICE_IDENTITY_MODEL
R1_R0R2_RELEASE_CONTRADICTION=NONE
R1_R0R2_BUILD_SIGN_OTA_ACTION=NONE
R1_R0R2_DEVICE_CONTACT=NONE
R1_R0R2=SUPERSEDED_BY_R1_R0R3
```

See `docs/SABLE_R1_R0R3_PREFLIGHT_CORRECTION.md` for the current entrypoint, exact source contract and validation.
