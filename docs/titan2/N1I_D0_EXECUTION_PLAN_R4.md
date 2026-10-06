# Titan 2 N1I-D0 Boot-Compatibility Closure — Execution Plan R4

Status: **AUTHORIZED FOR HOST-ONLY D0-0H TOOLING**

Date: 2026-10-06

R4 incorporates the approved R3 plan plus the final BE1/BE2 precision
amendments. No physical action is authorized by this document.

## Safety boundary

```text
SOURCE_MUTATION_AUTHORIZED=YES_D0_TOOLING_ONLY
BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
MODE_TRANSITION_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

N1F remains the boot-qualified control. C2 remains failed physical evidence.
A4 is permanently reference-only and must never generate product imports.

## Harness trust rules

Every applicable gate runs the same algorithm on N1F and C2. C1 runs only
where retained exact inputs exist. Stock is reference authority where relevant.

A C2 finding can be causal only when its N1F control passes. Missing required
evidence is `UNKNOWN`, never PASS. Gate F and Gate G have no N1F IMS-app
analogue: F is `NOT_APPLICABLE_CONTROL`; the Gate G control is the pinned B2
self-test suite.

Every image, extracted input, APEX payload and host tool must be identity-bound.
Runtime reasoning must use the mounted Android layout, not only extraction
paths.

## D0-B0 — common-delta authority

Run before causal ranking.

Emit exact N1F->C1, N1F->C2 and C1->C2 tables for:

- installed files and product packages;
- framework/source patches;
- init rc files;
- shipped SELinux CIL and mapping outputs;
- property/service contexts;
- permissions/sysconfig;
- BCP and system-server classpath;
- properties and overlays;
- APEX names and versions;
- native imports and source shims.

If retained C1 bytes are absent, emit
`C1_BINARY_CONTROL=UNKNOWN_NOT_RETAINED`.

The TelephonyMetrics shim must be classified COMMON_C1_C2 or C2_ONLY from
source/build evidence before it is used in a causal claim.

## Gate A — SELinux policy

### A0 — policy-path selection

Before compiling anything, reproduce the Android 16 init precompiled-policy
hash decision for N1F and C2 against the exact V01.00.14 vendor/odm inputs.

Report exactly one:

```text
SPLIT_COMPILE
PRECOMPILED_USED
UNKNOWN
```

A1 is meaningful only for `SPLIT_COMPILE`.

### A1 — init-equivalent split compile

Derive file ordering, policy version and flags from the exact Android 16
`system/core/init/selinux.cpp` source associated with the candidate build.
Use the canonical Sable Android-16 `secilc` executable and record its identity.

Only A1 may produce SELinux `BOOT_FATAL`.

N1F must pass the same A0/A1 model or the C2 result is invalid.

### A2 — compliance mode

Run stronger neverallow/compliance checks separately. A finding unique to A2 is
`COMPLIANCE_ONLY`, never the boot cause.

## Gate B — property contexts

Gate B runs after A1 and consumes A1's merged policy.

The pure duplicate/prefix-conflict analysis may run independently. Type
existence/property-info validation is `UNKNOWN` unless A1 produced a valid
merged policy.

Only a condition rejected by the real Android property-info assembly can be
`BOOT_FATAL`.

## Gate C — service contexts and VINTF

Union platform/system_ext/product/vendor/odm service contexts and report
duplicate/conflicting labels.

Compare C1-added MediaTek radio-extension and radio imsSlot service names with
the V01.00.14 vendor/odm VINTF manifests.

A context entry with no provider in vendor VINTF is
`FUNCTIONAL_RISK_MISSING_VINTF_PROVIDER` by default, not a boot blocker.

## Gate D — privileged package/shared UID

Stock authority comes first. Find the real stock
`privapp-permissions package="com.mediatek.ims"` block across all stock
partitions and record its partition/path.

Determine effective `ro.control_privapp_permissions` for stock, N1F and C2.

Compute the permissions requiring allowlisting from the exact C2 framework
permission definitions; never use a hard-coded permission list.

Evaluate C2 coverage under the package's actual partition
(`system_ext/priv-app`). Under enforcement, missing required system_ext
coverage is `BOOT_FATAL`.

Run the same allowlist algorithm on N1F's own privileged apps as the N1F
control.

D4 also parses and compares stock/C2 `seapp_contexts` for the
`android.uid.phone` / platform-signed IMS mapping, including user, seinfo and
resulting domain. A domain mismatch is reported separately from permission
coverage.

## Gate E — bootclasspath/classloader

Decode N1F, C2, stock and C1 when retained:

- bootclasspath.pb and system-server classpath fragments;
- mounted runtime paths;
- APEX classpath fragments and APEX payload contents;
- updatable BCP package handling;
- duplicate classes;
- stock membership/order/shared-library model for
  `mediatek-common.jar` and `mediatek-ims-base.jar`.

The B2 member resolver is pinned to
`1697f21989b8ed6f1db90f8886952894592c7d0f` and runs against C2's runtime
classpath.

### Gate E severity

`BOOT_FATAL` is allowed only for:

1. a required classpath entry absent under the mounted runtime layout;
2. a duplicate class whose resolution changes a class proven used by zygote or
   system_server;
3. a member-resolution failure on code proven by Gate F to execute during
   boot: zygote preload, system-server startup, persistent process startup or a
   component hosted in `com.android.phone`.

All other member failures are `FUNCTIONAL_RISK`.

ICCE risk must use existing resolver classes such as `ICCE_KIND`,
`DESCRIPTOR_MISMATCH` and `STATIC_INSTANCE_MISMATCH`; no ad-hoc ICCE
heuristic is permitted.

APEX analysis must de-duplicate updatable boot-classpath ownership and record
APEX versions. Missing APEX payload evidence makes the affected result UNKNOWN.

The N1F Gate E control is N1F's own BCP/system-server classpath resolution and
duplicate-class check; absence of ImsService in N1F is not UNKNOWN.

## Gate F — OEM IMS runtime role

Gate F is factual and has no N1F IMS-app control.

For ImsService record manifest/signature/shared UID/process/direct-boot/library
facts and emit explicit flags:

```text
BOOT_PATH_COMPONENT=YES|NO
REQUIRED_LIBRARY_MISSING=YES|NO|UNKNOWN
REQUIRED_NATIVE_LIBRARY_MISSING=YES|NO|UNKNOWN
FOREIGN_RESOURCE_PACKAGE_DEPENDENCY=YES|NO|UNKNOWN
```

Gate E may use `BOOT_PATH_COMPONENT` when assigning member-resolution
severity.

## Gate G — B2 native rederivation

Materialize the exact B2 analyzer sources from commit
`1697f21989b8ed6f1db90f8886952894592c7d0f` from the local Git object
database. No network fetch is allowed.

Run the pinned self-tests, then rederive native roots from C2's ImsService APK
and admitted JAR/runtime environment.

A4 is comparison evidence only. No fallback admission is permitted.

## Gate G2 — conditional ABI/provider proof

Run only for Gate-G-admitted consumers.

The pinned B2 tooling does not implement GNU ELF symbol-version resolution or a
full Android linker-namespace model. D0 must either add independently tested
checks using `readelf -V` as the version oracle plus explicit linkerconfig
evidence, or emit:

```text
SYMBOL_VERSION_CHECK=UNKNOWN_NOT_IMPLEMENTED
LINKER_NAMESPACE_CHECK=UNKNOWN_NOT_IMPLEMENTED
```

D0 must never imply these capabilities already exist.

## Overall verdict

```text
N1I_D0_0H=DEFECT_FOUND
```

only when at least one boot-critical C2 gate is BOOT_FATAL, the corresponding
N1F control passes, and the required inputs are complete.

```text
N1I_D0_0H=NOT_CLOSED
```

when C2 or the relevant N1F control is UNKNOWN for Gate A, B, D or E.

```text
N1I_D0_0H=NO_FATAL_DEFECT_FOUND
```

only when all four closure gates are complete and contain no validated
BOOT_FATAL finding.

A second independent summary key is mandatory:

```text
N1I_D0_C1J_COMPOSITION_READY=YES|NO
```

It is YES only when Gate E2 has a decided JAR/classloader model, Gate F is
complete, and Gate G produced a closure (possibly empty) with no unresolved
constant roots.

D0 closure never implicitly authorizes a physical build.

## Next physical image rule

The first physical image after D0 is always N1F-OBS, whether D0 finds a defect
or not.

N1F-OBS must prove early ADB/log availability during boot and after factory
reset before C1J-OBS is admitted.

No custom recovery, boot, vendor_boot or other boot-chain image may be flashed
solely to obtain logs.
