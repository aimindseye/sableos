# Titan 2 N1I-D0 host boot-compatibility closure R4

Date: 2026-10-06

Status: **HOST-ONLY ROOT-CAUSE QUALIFICATION**

This document supersedes R3 and incorporates the final BE1/BE2 review before
the D0-0H driver is executed.

## Safety boundary

```text
SOURCE_MUTATION_AUTHORIZED=YES_D0_TOOLING_ONLY
BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO_BY_DEFAULT
DEVICE_CONTACT_AUTHORIZED=NO
MODE_TRANSITION_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

No D0 tool may mutate Android source, contact the Titan, build an Android image,
or authorize a physical candidate.

## Harness trust rules

Every applicable gate runs against the physically boot-qualified N1F control as
well as C2. A candidate defect is actionable only when C2 fails and the
corresponding N1F control passes. A condition that also fails N1F is a harness
problem or a non-causal compatibility condition, never a C2 boot cause.

Missing input is always `UNKNOWN`, never PASS. N1F/C2 and the stock
system/system_ext/product/vendor images are pinned before extraction. If a
standalone stock ODM image exists without independent pin authority, ODM-
dependent gates are `UNKNOWN`, never PASS. Runtime paths must use the mounted
Android layout, including system_ext under the system image and APEX mount
points.

APEX payloads used by Gates E/G are freshly materialized from the exact pinned
stock/N1F/C2 system images during D0. Earlier scratch APEX extraction trees are
not trusted as gate inputs.

C1 is used only when exact retained binary/out evidence is present. If not,
`C1_BINARY_CONTROL=UNKNOWN_NOT_RETAINED` is explicit and C1/C2 commonality is
derived from source/product composition only.

## D0-B0: composition authority before causal ranking

Emit exact N1F->C1, N1F->C2 and C1->C2 change tables covering product packages,
installed paths, framework/source patches, SELinux, property/service contexts,
permissions/sysconfig, boot/system-server classpaths, properties, overlays,
init rc files, shipped SELinux CIL, APEX versions and native imports.

The TelephonyMetrics compatibility shim must be classified as COMMON_C1_C2,
C1_ONLY, C2_ONLY or ABSENT before it is used in any root-cause ranking.

## Gate A0: does init use precompiled policy?

Android 16 init first compares:

- system plat policy/mapping hash;
- system_ext policy/mapping hash;
- product policy/mapping hash;

against the sidecar hashes stored beside vendor/odm
`precompiled_sepolicy`.

D0 reproduces that exact decision separately for N1F and C2.

Results:

```text
PRECOMPILED_MATCH
SPLIT_COMPILE_REQUIRED
UNKNOWN
```

If precompiled policy matches, Gate A1 does not claim the system_ext policy was
compiled at boot. If hashes differ, Gate A1 is mandatory.

## Gate A1: init-equivalent split SELinux compile

The command and input order are bound to this Android 16 tree's
`system/core/init/selinux.cpp`, not handwritten policy assumptions.

For the pinned Android 16 implementation this includes:

- platform policy CIL;
- vendor mapping version selected by
  `vendor/etc/selinux/plat_sepolicy_vers.txt`;
- platform mapping and optional compat CIL;
- optional system_ext policy/mapping/compat CIL;
- optional product policy/mapping CIL;
- vendor `plat_pub_versioned.cil`;
- vendor policy CIL;
- optional odm policy CIL;
- applicable genfs version CIL.

The init-equivalent mode uses init's `secilc` semantics, including `-N`.
Only this pass can produce `BOOT_FATAL`.

A second compliance pass may enable stronger neverallow checks. Compliance-only
failure never becomes the asserted physical boot cause.

The canonical Sable `secilc` binary is used. D0 records its SHA/version and
does not rely on ambient host m4/policy tooling. Before either A0 or A1 is
trusted, the driver verifies the current Android workspace `system/core` and
`system/sepolicy` project HEADs against the sealed C3A
`all-project-heads.tsv`, verifies those worktrees are clean, and hashes the
exact `system/core/init/selinux.cpp` and `system/sepolicy/Android.bp` files
used to derive the init-equivalent command.

## Gate B: property-context union

Gate B runs only after Gate A establishes a usable merged policy. Its type
validation is UNKNOWN when A1 is not available/valid.

It compares platform/system_ext/product/vendor/odm property contexts and reports
exact/prefix collisions, type disagreements and the C1 MediaTek property
additions.

D0 runs the canonical Android `property_info_checker` against the exact
merged/precompiled policy selected by Gate A and the built partition context
files (`plat_property_contexts`, `system_ext_property_contexts`,
`product_property_contexts`, `vendor_property_contexts`, and ODM when
pinned). A missing checker or merged-policy authority is `UNKNOWN`.

Only a conflict rejected by that Android property-info assembly is
`BOOT_FATAL`; manual duplicate/type scans remain explanatory findings.

## Gate C: service-context and VINTF union

Service-context conflicts are `FUNCTIONAL_RISK` by default, not boot blockers.

All C1-added MediaTek/radio service instances are compared against the exact
V01.00.14 vendor/odm VINTF manifests. A system-side service context absent from
vendor VINTF is explicitly reported as `SERVICE_PROVIDER_MISSING`.

It becomes `BOOT_FATAL` only if the exact context database or a proven
boot-critical service-manager path cannot load.

## Gate D: privapp/shared UID/seapp

The current repository has a structural mismatch: `ImsService` is
system_ext-specific while its copied stock privapp allowlist is currently a
system-partition prebuilt.

D0 does not promote that mismatch to a proven boot cause until it establishes:

1. stock's real `com.mediatek.ims` privapp allowlist location and contents;
2. effective `ro.control_privapp_permissions`;
3. permissions requested by the exact C2 APK;
4. which requested permissions require allowlisting according to the exact C2
   framework;
5. coverage in the APK's actual system_ext partition;
6. shared UID and signing constraints.

Missing required system_ext coverage under enforce is `BOOT_FATAL`.

Gate D4 also parses the built stock/N1F/C2 `mac_permissions.xml` and
`seapp_contexts`. The IMS signing certificate must bind unambiguously to a
`mac_permissions.xml` signer (or package-specific signer rule) before its
`seinfo` value is used for seapp resolution. D0 must not assume
`seinfo=platform` merely because the APK was platform-resigned.

The resolved seinfo/user/package/privapp selectors are then evaluated against
the shipped seapp contexts for `android.uid.phone` and
`com.mediatek.ims`. Missing, ambiguous or unbound signing-to-seinfo authority
is `UNKNOWN`; a domain delta is classified by its exact policy effect and is
not converted into an automatic fatal verdict without evidence.

## Gate E: bootclasspath/APEX/classloader

Gate E decodes stock, N1F and C2 boot and system-server classpath authority,
including freshly extracted APEX contents and
`updatable-bcp-packages.txt` when present.

It records stock truth for `mediatek-common.jar` and
`mediatek-ims-base.jar`: bootclasspath membership/order and any named shared
library declarations.

APEX de-duplication is explicit. A class moved to/updatable through a Mainline
APEX is resolved using the actual runtime provider/order, not only a path-name
match. D0 emits an explicit system-vs-APEX overlap report, including a focused
report for either MediaTek JAR, and records
`updatable-bcp-packages.txt` authority when present. An overlap is a
`FUNCTIONAL_RISK` unless the exact changed runtime winner is separately proven
to execute in zygote/system_server during boot.

Severity is constrained:

`BOOT_FATAL` only for:

- a boot/system-server classpath entry that does not exist at runtime;
- a duplicate class only when separate evidence proves the changed winner is
  actually loaded by zygote/system_server during boot;
- a member failure only when the exact failing callsite is proven to execute
  during boot.

The present D0 implementation does not infer those two execution facts merely
from BCP membership or from the IMS package being persistent. Changed winners
and unresolved members therefore remain `FUNCTIONAL_RISK` unless explicit
boot-code reachability evidence is supplied. The existing B2 member resolver
result types are reused; no new heuristic ICCE category is invented.

For the N1F control, Gate E evaluates N1F's own boot/system-server classpaths;
it does not require an IMS APK.

## Gate F: OEM IMS runtime role

Gate F is C2/stock-specific and is `NOT_APPLICABLE` for N1F.

It records package/signing/shared UID, persistent/direct-boot flags, component
processes, boot receivers/providers, uses-library/uses-native-library and
whether any admitted component is proven to execute before boot completion.

Gate F distinguishes `BOOT_EXECUTION_PROVEN` from
`BOOT_EXECUTION_REACHABLE`. Persistent-package metadata can prove the former
at the package level; direct-boot/receiver declarations establish only
reachability. Neither alone proves execution of a specific failing member
callsite.

## Gate G: B2 native rederivation

Gate G is C2/stock-specific and is `NOT_APPLICABLE` for N1F.

The existing B2 analyzers are source-pinned to commit
`1697f21989b8ed6f1db90f8886952894592c7d0f`, which is already an ancestor of
the current SableOS source. No runtime network fetch is required.

Native roots are only constant JNI load sites or manifest native-library
declarations. Exact DT_NEEDED closure follows. Optimized framework JARs without
embedded DEX are analyzed through a D0-only, SHA-recorded container reconstructed
from standard DEX slices in their sibling VDEX; the pinned B2 analyzer itself is
never modified. A4 is never an import fallback.

## Gate G2: conditional ABI proof

G2 runs only for B2-admitted consumers.

Existing B2 tooling does not prove GNU symbol versions or full linker namespace
reachability. D0 must either augment this check with pinned `readelf -V` plus
an explicit linker namespace model, or report:

```text
UNKNOWN_NOT_IMPLEMENTED
```

It must never claim ABI PASS from filename/SONAME or partition visibility alone.

## Known-good control applicability

- Gates A/B/C/E: N1F mandatory.
- Gate D: run the same partition/enforcement logic over N1F's own privileged
  apps; IMS-specific subchecks are NOT_APPLICABLE.
- Gates F/G/G2: N1F = NOT_APPLICABLE, not UNKNOWN.

## Recovery evidence

Only a bounded transport availability check may be proposed separately. If
stock recovery has no usable adb shell, record
`NOT_AVAILABLE_USER_RECOVERY` and stop. No custom recovery/vendor_boot/boot
flash is authorized to obtain logs.

## Summary semantics

`N1I_D0_0H=DEFECT_FOUND` requires at least one C2 BOOT_FATAL result whose N1F
control passes with complete/pinned inputs.

`N1I_D0_0H=NOT_CLOSED` is mandatory when any of A, B, D or E is UNKNOWN for
C2, or the corresponding N1F control is invalid.

`N1I_D0_0H=NO_FATAL_DEFECT_FOUND` is allowed only when A/B/D/E close with
valid N1F controls and no unresolved boot-fatal evidence.

A separate key is mandatory:

```text
N1I_D0_C1J_COMPOSITION_READY=YES|NO
```

Finding no fatal defect does not imply that the JAR model, policy, process
placement or native roots are sufficiently decided for the next image.

## Next physical image

Observability is mandatory regardless of D0 outcome.

The next physical image is always N1F-OBS first. It must prove early adb/log
availability during boot and again after factory reset. Only after that control
passes may C1J-OBS add the D0-proven OEM Java island.

No D0 tooling result itself authorizes a build or flash.
