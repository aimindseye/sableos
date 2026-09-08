# Sable R1-R0R1 — superseded release-preflight correction

Date: 2026-09-08
Status: **SUPERSEDED / DO NOT EXECUTE**
Superseded by: `SABLE_R1_R0R2_RELEASE_PREFLIGHT.py`

## Historical purpose

R0R1 was created after the first physical-host R1-R0 audit exposed two parser defects:

```text
signing.generator_subject=ERROR_UNPARSEABLE
artifact.device=ERROR_GENERIC
```

Those were correctly identified as host-harness parser defects, not release/product defects.

R0R1 intended to correct:

1. the indented upstream `CN=GrapheneOS` assignment;
2. target product identity being taken from generic `SYSTEM/build.prop` instead of target-files OTA/product metadata.

## R0R1 identity

Historical entrypoint:

```text
tools/validation/release-r1/SABLE_R1_R0R1_RELEASE_PREFLIGHT.py
```

Bound base:

```text
BASE_R1_R0_SHA256=cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7
```

Historical R0R1 identity:

```text
GIT_BLOB_SHA1=8cfc3f129dc8937d6a524b7031c1ab85c8434d1e
SHA256=2a1cb305ae0c0a3d8480a11b2156b099d71ca21d1d6791fb0ecdef158d6928c8
```

The R0R1 file is intentionally retained byte-for-byte for forensic lineage. Do not modify or execute it.

## Physical-host failure

The ThinkPad bound the exact R0R1 bytes and the combined test suite reported:

```text
R1_R0R1_BINDING=PASS
R1_R0R1_TESTS=PASS_15_OF_15
```

The live audit then failed before producing a release-readiness result:

```text
RecursionError: maximum recursion depth exceeded
R1_R0R1_RC=1
```

Root cause:

```python
BASE.find_build_properties = find_build_properties
...
find_build_properties(...):
    BASE.find_build_properties(...)
```

After monkeypatching, the replacement called the mutable patched global and therefore called itself recursively.

Formal disposition:

```text
R1_R0R1_FAILURE_CLASS=HOST_HARNESS_MONKEYPATCH_SELF_RECURSION
R1_R0R1_TEST_COVERAGE_DEFECT=PATCHED_MAIN_PATH_NOT_EXERCISED
R1_R0R1_RELEASE_CONTRADICTION=NONE
R1_R0R1_BUILD_EXECUTION=NONE
R1_R0R1_KEY_GENERATION=NONE
R1_R0R1_SIGNING=NONE
R1_R0R1_OTA_GENERATION=NONE
R1_R0R1_DEVICE_CONTACT=NONE
R1_R0R1=SUPERSEDED_BY_R1_R0R2
```

The fact that 15 tests passed while the actual entrypoint recursed is itself part of the evidence: the R0R1 tests were insufficient because they exercised the correction function directly but did not execute the monkeypatched `main()` lifecycle.

## Correct current entrypoint

Use only:

```text
tools/validation/release-r1/SABLE_R1_R0R2_RELEASE_PREFLIGHT.py
```

R0R2 captures the original base function before patching, calls that immutable captured reference through a closure, restores patched globals in `finally`, and directly tests the repeated patched-main lifecycle.

See:

- `docs/SABLE_R1_R0R2_PREFLIGHT_CORRECTION.md`
- `docs/SABLE_R1_R0_RELEASE_ENGINEERING_PREFLIGHT.md`
- `tools/validation/release-r1/README.md`
