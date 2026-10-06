# Titan 2 N1I-D0 Boot-Compatibility Closure — Execution Plan R4

Status: **AUTHORIZED — HOST-ONLY TOOLING IMPLEMENTATION**

Date: 2026-10-06

R4 incorporates the final BE1/BE2 precision amendments to R3. It does not
change the architecture: physical iteration remains frozen while D0 reproduces
the boot-critical C1/C2 integration boundaries on the host.

## Authority

```text
C2_BUILD_SOURCE_COMMIT=27d671b004f5ae7394f147018fc4fffdf4d78498
N1F_SYSTEM_SHA256=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a
N1F_SYSTEM_BYTES=3200540672
C2_SYSTEM_SHA256=630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50
C2_SYSTEM_BYTES=3218440192
B2_ANALYZER_PROVENANCE_COMMIT=1697f21989b8ed6f1db90f8886952894592c7d0f
A4_NATIVE_IMPORT_AUTHORITY=RETIRED
```

Commit `1697f21` is already an ancestor of the C2/tooling source stack. D0
therefore pins and verifies the B2 analyzer provenance without a runtime network
fetch.

## Non-negotiable boundary

```text
SOURCE_MUTATION_AUTHORIZED=YES_D0_TOOLING_ONLY
BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
MODE_TRANSITION_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

No D0 result authorizes a physical image.

## Harness rules

1. Every applicable boot gate runs on N1F and C2. N1F is the known-good
   physical control.
2. A C2 failure is causal evidence only when the same gate passes N1F.
3. Missing required evidence is `UNKNOWN`, never PASS.
4. Every image/root/tool is hash/version recorded before analysis.
5. Runtime mounted layout is modeled explicitly, including
   `/system/system_ext`, `/product`, and APEX mount points.
6. Gate F/G are `NOT_APPLICABLE` for N1F when they specifically analyze the
   absent OEM `ImsService`; they do not invalidate the N1F control.
7. Gates A/B/D/E are the boot-critical verdict gates. UNKNOWN in any required
   C2 instance leaves D0 `NOT_CLOSED`.

## D0-B0 — composition table first

Before causal ranking, emit exact composition evidence for:

- N1F -> C1;
- N1F -> C2;
- C1 -> C2.

Include product packages, installed files, source patches, SELinux,
property/service contexts, permissions/sysconfig, boot/system-server
classpaths, init rc files, APEX versions, properties, overlays and native
imports.

C1 physical equivalence is not assumed when exact retained C1 bytes are absent.

The TelephonyMetrics compatibility patch is classified explicitly as common or
C2-only from source/build evidence.

## Gate A0 — precompiled versus split policy

Reproduce Android 16 init's `FindPrecompiledSplitPolicy()` decision.

The harness must compare the exact platform/system_ext/product policy hashes
against the corresponding hash files adjacent to the vendor/odm
`precompiled_sepolicy`.

Output:

```text
PRECOMPILED_MATCH
SPLIT_COMPILE_REQUIRED
UNKNOWN
```

If hashes match, the precompiled policy is the boot authority and Gate A1 does
not invent a split compile as the boot cause.

## Gate A1 — init-equivalent split compilation

When A0 requires a split compile, derive the exact input set and flags from the
checked-out Android 16 `system/core/init/selinux.cpp`.

Required semantics include:

- platform CIL;
- vendor API mapping and compat mapping;
- optional system_ext/product policy and mapping;
- vendor policy;
- vendor `plat_pub_versioned.cil`;
- optional odm policy;
- vendor genfs-labels version and matching platform genfs CIL;
- exact Android policydb version;
- `secilc -m -M true -G -N` init-equivalent flags.

Use the canonical Sable host `secilc`; do not use host distro policy tools.
Record the exact command and every input SHA.

Only A1 may report a SELinux `BOOT_FATAL`.

A second stronger neverallow/compliance pass is reported independently and
cannot be promoted to the boot cause when A1 succeeds.

## Gate B — property contexts after Gate A

Property-context analysis runs after A1/precompiled authority is established.

It checks the merged platform/system_ext/product/vendor/odm namespace and
validates that referenced property types exist in the effective policy.

A finding is `BOOT_FATAL` only when the actual property-info assembly/effective
policy rejects it. Namespace/design findings are `COMPLIANCE_ONLY` or
`FUNCTIONAL_RISK`.

## Gate C — service contexts and VINTF

Check duplicate/conflicting context entries and compare C1-added MediaTek/radio
instances with the exact V01.00.14 vendor/odm VINTF manifests.

A context entry for a service missing from VINTF is
`FUNCTIONAL_RISK` by default, not a boot blocker.

## Gate D — privileged package, shared UID and seapp

Gate D starts from stock truth.

1. Locate every stock `privapp-permissions` block for
   `com.mediatek.ims` and record its partition.
2. Resolve effective `ro.control_privapp_permissions`.
3. Derive the set needing allowlisting from the exact C2 framework permission
   definitions and the APK's requested permissions; do not hard-code it.
4. Evaluate coverage in the APK's actual `system_ext` partition.
5. Verify signing/shared-UID constraints for `android.uid.phone`.
6. Parse effective stock/C2 `seapp_contexts` and record the seinfo/domain
   assignment expected for the resigned package.

The current system-vs-system_ext XML placement is a confirmed structural
mismatch. It becomes `BOOT_FATAL` only when enforcement plus missing required
system_ext coverage proves the fatal path.

## Gate E — bootclasspath, APEX and executable severity

Decode the complete runtime classpath for N1F/C2/stock, including APEX
classpath fragments and de-APEXed payloads.

Handle `updatable-bcp-packages.txt`/Mainline ownership explicitly so an MTK
class does not silently override or duplicate an Android 16 APEX class.

Reuse the B2 member resolver for exact method/field/type results.

Severity is evidence-driven:

`BOOT_FATAL` only for:

- a runtime classpath entry that does not exist;
- duplicate class ownership that changes what zygote/system_server actually
  loads;
- a member/type failure on code proven to execute during boot.

Other linkage/member findings are `FUNCTIONAL_RISK` unless boot reachability
is separately proven.

Do not invent a separate heuristic ICCE category; use the resolver's existing
result classes.

## Gate F — OEM runtime role

For C2 record the IMS APK's signing/shared UID, SDK levels, persistent/direct
boot flags, process placement, services/receivers/providers, uses-library and
uses-native-library declarations, and boot-time component reachability flags
consumed by Gate E severity.

For N1F this gate is `NOT_APPLICABLE_OEM_IMS_ABSENT`.

## Gate G — B2 native rederivation

Pin the existing B2 tooling to ancestor commit
`1697f21989b8ed6f1db90f8886952894592c7d0f`.

Run it against C2's actual APK/JAR/runtime partition/APEX model.

Only constant JNI load sites, manifest native declarations and their exact
`DT_NEEDED` closure can create native admission candidates.

A4 is comparison evidence only.

For N1F this OEM-IMS-specific gate is `NOT_APPLICABLE_OEM_IMS_ABSENT`.

## Gate G2 — conditional ABI proof

Run only for libraries reached by Gate G.

Existing B2 tooling does not prove GNU symbol versions or full linker namespace
reachability. Until D0 adds that evidence:

```text
SYMBOL_VERSION_CHECK=UNKNOWN_NOT_IMPLEMENTED
LINKER_NAMESPACE_CHECK=UNKNOWN_NOT_IMPLEMENTED
```

D0 may add a small readelf-based version checker and an explicit namespace
model. It must be validated against `readelf -V` fixtures before those fields
can become PASS/FAIL.

The five former Kati-collision providers are examined only when a proven
consumer reaches them.

## Verdicts

`N1I_D0_0H=DEFECT_FOUND` requires at least one boot-critical gate with:

- C2 = BOOT_FATAL;
- N1F = PASS;
- complete pinned inputs.

`N1I_D0_0H=NOT_CLOSED` if a required C2 A/B/D/E result is UNKNOWN or its N1F
control is invalid.

`N1I_D0_0H=NO_FATAL_DEFECT_FOUND` only after all boot-critical gates close
without a candidate-only fatal result.

A separate key is mandatory:

```text
N1I_D0_C1J_COMPOSITION_READY=YES|NO
```

"No fatal defect found" never implies that the next Java-island composition has
been decided.

## Next physical image

Observability is mandatory regardless of D0's verdict.

The first physical candidate after D0 is N1F-OBS: exact known-good N1F plus only
reviewed early-boot ADB/persistent logging. It must prove observability during
boot and again after factory reset.

Only after N1F-OBS passes may C1J-OBS add the D0-proven OEM IMS Java/policy/JNI
island.

No A4 fallback, permissive SELinux, generic RIL restart, healer loop or blind
native import is permitted.
