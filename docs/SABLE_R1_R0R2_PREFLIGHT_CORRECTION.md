# Sable R1-R0R2 preflight correction

Date: 2026-09-08

## Status

`SABLE_R1_R0R2_RELEASE_PREFLIGHT.py` supersedes both earlier R1-R0 entrypoints for execution:

```text
SABLE_R1_R0_RELEASE_PREFLIGHT.py      HISTORICAL BASE / DO NOT EXECUTE DIRECTLY
SABLE_R1_R0R1_RELEASE_PREFLIGHT.py    SUPERSEDED / KNOWN RECURSION DEFECT
SABLE_R1_R0R2_RELEASE_PREFLIGHT.py    CURRENT EXECUTION ENTRYPOINT
```

R0 remains the bound policy/implementation base. R0R2 loads that exact file by SHA-256 and changes only the parser/adapter layer required by the physical-host findings.

## Failure lineage

### R1-R0

The first physical-host execution completed most of the audit but reported two `ERROR` checks that were parser defects rather than release defects:

```text
signing.generator_subject=ERROR_UNPARSEABLE
artifact.device=ERROR_GENERIC
```

Causes:

1. upstream `script/generate-keys` indents `CN=GrapheneOS`, while the original parser required `CN=` at column 1;
2. `SYSTEM/build.prop` reports the generic system partition identity and is not authoritative for Panther target product identity.

The release blockers found by R0 remain substantive.

### R1-R0R1

R0R1 corrected both parser semantics but introduced a runtime monkeypatch recursion:

```python
BASE.find_build_properties = find_build_properties
...
find_build_properties(...):
    BASE.find_build_properties(...)
```

Once patched, the replacement called itself recursively. The ThinkPad run reached:

```text
R1_R0R1_BINDING=PASS
R1_R0R1_TESTS=PASS_15_OF_15
RecursionError: maximum recursion depth exceeded
R1_R0R1_RC=1
```

This also proved the R0R1 tests were insufficient: they exercised the replacement function directly but did not exercise the actual patched `main()` lifecycle.

Formal disposition:

```text
R1_R0R1_FAILURE_CLASS=HOST_HARNESS_MONKEYPATCH_SELF_RECURSION
R1_R0R1_RELEASE_CONTRADICTION=NONE
R1_R0R1_DEVICE_CONTACT=NONE
R1_R0R1_BUILD_SIGN_OTA_ACTION=NONE
R1_R0R1=SUPERSEDED_BY_R1_R0R2
```

## R0R2 architecture

R0R2 removes the self-reference structurally:

1. bind and load the exact R0 base script;
2. capture `base.find_build_properties` before any patch;
3. build a closure that calls only that captured original function;
4. patch the two base parser functions only for one `base.main()` invocation;
5. patch base-module `__file__` only so evidence records the R0R2 entrypoint identity;
6. restore both functions and `__file__` in `finally`, including exceptional exits.

The corrected product identity order is:

```text
OTA/android-info.txt require product=...
    -> preferred authoritative source
PRODUCT/VENDOR/ODM/SYSTEM_EXT build.prop
    -> bounded fallback
SYSTEM build.prop with ro.product.device=generic
    -> rejected as target identity
```

The signing-subject parser accepts indentation, optional spaces, quoting and an inline shell comment, so the pinned upstream `CN=GrapheneOS` is reported as a release `BLOCKER` rather than a parser `ERROR`.

## Safety boundary

R0R2 adds no execution backend. It imports neither `subprocess` nor `os` and contains no build/sign/OTA/device mutation command path.

The bound R0 base retains the original read-only authorization gate:

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

No key generation, user/release build, target-files signing, OTA generation, factory-image generation, device install, bootloader lock, reboot, flash, slot change or wipe is authorized by R0R2.

## Pre-delivery adversarial validation

The R0R2-specific suite directly exercises the failure mode R0R1 missed:

```text
PY_COMPILE=PASS
R0R2_FOCUSED_TESTS=PASS_11_OF_11

GENERATOR_SUBJECT_INDENT_QUOTES_COMMENTS=PASS
ANDROID_INFO_MULTI_PRODUCT_DEDUP=PASS
CAPTURED_ORIGINAL_FUNCTION_NOT_MUTABLE_GLOBAL=PASS
PARTITION_FALLBACK_REJECTS_GENERIC_SYSTEM=PASS
PATCHED_MAIN_PATH=PASS
PATCH_RESTORE_SUCCESS=PASS
PATCH_RESTORE_EXCEPTION=PASS
REPEATED_PATCHED_MAIN_250=PASS
BOUND_BASE_HASH_MISMATCH_FAIL_CLOSED=PASS
NO_EXECUTION_BACKEND_OR_MUTATION_TOKENS=PASS
LOADED_MODULE_REPEATED_MAIN_100=PASS
```

The 250-run state-leak test and separate 100-run dynamically loaded-module test both invoke the monkeypatched `main()` path repeatedly and verify that the original functions and `__file__` are restored after every invocation.

The existing R0 suite remains independently required. On the ThinkPad, the combined gate should run:

```text
test_release_preflight.py       9 tests
test_release_preflight_r0r2.py 11 tests
TOTAL                           20 tests
```

R0R1 tests are retained only as historical regression evidence and are not part of the current execution gate.

## Expected live outcome

A healthy R0R2 audit is expected to finish with no `ERROR` entries and with release blockers still present:

```text
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
R1_R0R2_RC=3
```

The exact blocker count is determined by the physical-host run and must not be predeclared.

Expected corrected classifications include:

```text
signing.generator_subject=BLOCKER actual=GrapheneOS
artifact.device=PASS actual=panther
```

Only after `ERROR=0` and `R1_R0R2_RC=3` should R1-R0 be considered closed as a release-readiness inventory and the blocker set promoted into R1-R1 planning.
