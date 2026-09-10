# Sable R1-R0R3 preflight correction

Date: 2026-09-08
Status: **CURRENT READ-ONLY R1-R0 EXECUTION ENTRYPOINT / LIVE VALIDATION PENDING**

## Failure lineage

```text
R1-R0
  signing.generator_subject=ERROR_UNPARSEABLE
  artifact.device=ERROR_GENERIC
  -> parser defects

R1-R0R1
  parser fixes introduced mutable-global self-recursion
  -> RecursionError despite 15/15 tests
  -> superseded

R1-R0R2
  recursion architecture fixed
  generator subject correctly became BLOCKER GrapheneOS
  artifact.device remained ERROR generic on the real B2 target-files
  -> target-files partition property/path model was still wrong
  -> superseded

R1-R0R3
  current entrypoint
```

The physical-host R0R2 run completed with:

```text
PASS=18 BLOCKER=10 INFO=11 SKIP=2 ERROR=1
R1_R0_PREFLIGHT_EXECUTION=ERROR
R1_RELEASE_READINESS=UNKNOWN
R1_R0R2_RC=2
```

The sole error was `artifact.device=generic`. All ten release blockers remain substantive; there was no release/product contradiction and no build/sign/OTA/device action.

## Exact root cause

The pinned GrapheneOS `2026081300` manifest resolves `platform_build` / `build/make` to:

```text
7f0398241bc8c4ef5255a8063befa5045e5cfab4
```

At that exact revision, `core/sysprop.mk` emits partition-scoped identity:

```text
ro.product.<partition>.device=$(TARGET_DEVICE)
```

For the relevant partitions the expected keys/target-files paths are:

```text
SYSTEM/build.prop          ro.product.system.device
VENDOR/build.prop          ro.product.vendor.device
PRODUCT/etc/build.prop     ro.product.product.device
ODM/etc/build.prop         ro.product.odm.device
SYSTEM_EXT/etc/build.prop  ro.product.system_ext.device
```

R0R2 incorrectly searched `ro.product.device` in several wrong partition paths. The historical R0 base had already captured `ro.product.system.device`, but then selected generic `ro.product.device` first.

R0R3 resolves the built device from the exact partition-scoped contract. It treats `OTA/android-info.txt` product requirements as an allowed-product constraint when present. Multiple conflicting non-generic partition identities, or an OTA-vs-partition contradiction, become a synthetic `CONFLICT[...]` device value so the existing base `artifact.device` check fails closed.

R0R3 does **not** accept generic as Panther and does not infer device identity from the target-files filename.

## Non-recursive patch lifecycle

R0R3 retains the corrected R0R2 lifecycle:

1. bind the historical R0 base by exact SHA-256;
2. capture the original `find_build_properties` before patching;
3. create a closure over that captured function;
4. patch only for one `base.main()` invocation;
5. restore the parser function, build-property function and `base.__file__` in `finally`;
6. fail closed on base hash drift.

Bound R0 SHA-256:

```text
cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7
```

Published R0R3 identity:

```text
GIT_BLOB=e35081e18cbbd12e7d49accb26766bc03721c649
SHA256=595db875192ab5c3753e6d31698bce8adefdd3af5900de217bf4ea987ef7b88f
```

Published R0R3 test identity:

```text
GIT_BLOB=b0122478f47198f35a5d772c254c0eb7afddf4cf
SHA256=9d4d34354985237d90259ff39ceed781c72915545c77438f89dddb3c4dcd05fd
```

## Pre-delivery validation

The R0R3-specific suite passed **18/18** after the final repository-relative test-path correction.

Coverage includes:

```text
PINNED_STYLE_GENERATOR_SUBJECT=PASS
LIVE_GENERIC_PLUS_SYSTEM_SCOPED_PANTHER=PASS
EXACT_PRODUCT_ETC_PATH_AND_KEY=PASS
PARTITION_IDENTITY_AGREEMENT=PASS
PARTITION_IDENTITY_CONFLICT_FAIL_CLOSED=PASS
OTA_ALLOWED_SET_PLUS_PARTITION=PASS
OTA_PARTITION_CONFLICT_FAIL_CLOSED=PASS
OTA_ONLY_EXPECTED_DEVICE=PASS
NO_EVIDENCE_LEAVES_BASE_VALUE_UNCHANGED=PASS
CAPTURED_ORIGINAL_NOT_MUTABLE_GLOBAL=PASS
PATCHED_MAIN_AND_RESTORE=PASS
RESTORE_ON_EXCEPTION=PASS
REPEATED_PATCHED_MAIN_500=PASS
BOUND_BASE_HASH_MISMATCH_FAIL_CLOSED=PASS
EXACT_BOUNDED_PARTITION_CONTRACT=PASS
NO_EXECUTION_BACKEND_OR_MUTATION_COMMANDS=PASS
MAIN_LOADS_BOUND_BASE_ONCE=PASS
FRESH_PROCESS_ENTRYPOINT=PASS
```

The fresh-process test launches the R0R3 executable as a separate Python process against a synthetic SHA-bound base and a target-files fixture reproducing the live `generic` / partition-scoped Panther symptom. It returns the expected blocker exit code and does not recurse.

The final test suite itself resolves its sibling executable via `__file__`; no `/mnt/data` or developer-machine path is embedded in the published test.

## Safety boundary

R0R3 adds no command execution backend. It imports neither `subprocess` nor `os`; all subprocess behavior remains owned by the byte-bound historical R0 base and is limited to the already-tested read-only `repo manifest -r` and `git rev-parse HEAD` queries.

Required authorization context remains:

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

## Expected live disposition

R0R3 is expected to change only the remaining harness error:

```text
artifact.device: ERROR generic
    -> PASS panther
```

The ten genuine release blockers are expected to remain blockers. The live run, not this document, determines the authoritative aggregate.

Required R1-R0 inventory closure markers:

```text
ERROR=0
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_<N>
R1_R0R3_RC=3
```

Only after those markers are observed is R1-R0 closed as a release-readiness inventory and the blocker set promoted into R1-R1 planning.
