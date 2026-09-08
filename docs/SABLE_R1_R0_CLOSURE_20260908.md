# SableOS R1-R0 closure — Panther release-engineering inventory

Date: 2026-09-08  
Status: **CLOSED**

R1-R0 is closed as a trustworthy read-only inventory. The current executable was `SABLE_R1_R0R3_RELEASE_PREFLIGHT.py`; R0R1 and R0R2 remain historical superseded harnesses.

## Final live gate

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

`RC=3` is the intended successful R1-R0 disposition: the audit itself completed without error and identified real production-release blockers.

## Target identity closure

The final target-files identity check correctly distinguished generic system-partition identity from Panther product identity:

```text
artifact.device=PASS expected=panther actual=panther
SYSTEM/build.prop          ro.product.system.device=generic
VENDOR/build.prop          ro.product.vendor.device=panther
PRODUCT/etc/build.prop     ro.product.product.device=panther
SYSTEM_EXT/etc/build.prop  ro.product.system_ext.device=panther
```

The three non-generic partition-scoped identities agree on `panther`.

## Blockers promoted to R1-R1 and later phases

```text
1  upstream generate-keys subject is GrapheneOS
2  Updater URL still points at releases.grapheneos.org
3  final Panther production keyset absent
4  production source-seal policy not yet defined
5  current B2 artifact is userdebug
6  current B2 artifact uses test-keys
7  current B2 artifact omits official Updater
8  apkcerts metadata contains test-key references
9  apexkeys metadata contains test-key references
10 misc_info metadata contains test-key references
```

R1-R1 can close policy/configuration items without generating keys or building. Keyset/artifact-state blockers remain intentionally deferred until separately authorized phases.

## Safety

No R1-R0 execution generated keys, mutated Android source, built Android, signed artifacts, generated OTAs, contacted the device, rebooted, flashed, changed slots, locked/unlocked the bootloader, or wiped data.
