# Titan 2 N1F — M3 R2 prior-evidence reuse matrix (2026-10-12)

**Active image:** operator-reported Oct 11 Atlas-inspired N1F hybrid runtime; exact flash artifact journal unbound. **Target:** C1 minimal IMS island and five R2 libraries in embedded `/system/system_ext` while preserving `skip_mount.cfg`. **This is a source-based evidence reconciliation, not new qualification or permission to build/flash.**

## Decision rule

Do **not** reset all five libraries to `UNRESOLVED` because a later bounded scan omitted the platform/APEX runtime root. Inherit *each previously demonstrated assertion at its original scope*. A broader claim may be made only if the exact parent library/provider bytes and relevant linker config are identical or a documented compatibility comparison validates the difference.

| Previously investigated fact | Authority | Reuse decision | Limitation / only needed difference |
|---|---|---|---|
| Five stock library identities | Operator P0-AV; Oct 12 M3 targeted gate | **REUSE_PASS: SHA/ELF identity** | Destination partition and runtime load still separate |
| ELF64 AArch64 | Operator P0-AV; M3 v1 | **REUSE_PASS** | Not ABI / namespace pass |
| Direct `DT_NEEDED` | M3 targeted gate, 20/15/6/8/7 = 56 edge references | **REUSE_PASS: direct graph** | Do not parse/re-inventory unchanged ELF files again |
| Bionic versioned-symbol subset | Earlier P0-AO 19/19 | **REUSE_PASS_FOR_19_EXACT_TESTS** | No global symbol/version or transitive claim |
| Stock/C3A provider model | Earlier N1I-B2 analyses and `build/titan2/n1i-b2-native.py` | **REUSE_WITH_EXACT_INPUT_MATCH** | B2 models APK→system/system_ext/product/APEX, marks vendor-only `FILE_PRESENT_NAMESPACE_UNPROVEN`; cannot turn this into dynamic linker proof automatically |
| Android 16 C3A→N1F platform relationship | N1F physically boot-qualified Oct 3; C3A-derived five-app system build | **REUSE_WITH_EXACT_INPUT_MATCH** | Same Android version alone is insufficient; provider ELF SHA, APEX identity, namespace config must match per assertion |
| R2 v2 historical-stock search | Operator Oct 12: 56 edges, 6 stock-hit *records*, 51 unmatched records, runtime root omitted | **REUSE_AS_INPUT_COVERAGE_EVIDENCE_ONLY** | **Not** 51 proven missing on device; candidate presence is not loadability |
| Embedded system_ext target | R8Q3 live symlinks; operator/engineer `skip_mount.cfg` finding | **REUSE_DESIGN_BOUNDARY** | Keep physical stock system_ext/product unmounted; no standalone partition copyout |
| OEM IMS app and C1 compatibility pieces | Existing C1 Android.bp and pinned TelephonyMetrics patch | **REUSE_SOURCE_IMPLEMENTATION** | Exact staged APK/JAR identities and N1F build integration still need pinning |
| R1 manifest baseline | M3 v1 SHA `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c` / Git blob `a7675341e1575039845d09c64fa22006612cca4a`, target declaration count 0 | **REUSE_PASS: edit baseline** | One declaration candidate; effective framework-res post-build remains unqualified |
| LTE registration stability | R8M Oct11, temporary ADB diagnostic followed by recurrent disablement | **REUSE_FAIL: STABILITY** | Distinct from OEM IMS inclusion / ViLTE loader admission |

## Exact unresolved delta list — no global rescan

1. **Prior R2 full closure evidence**: before running any new analyzer, check the already-retained P0-AO/P0-AV/B2 result summaries for whether recursive provider bytes, required strong-symbol/version bindings or classloader namespace were *actually* qualified. **No such complete PASS is visible in the material consolidated here; do not fabricate it.**
2. **Provider identity comparison**: for names from the 56-edge graph that earlier B2/C3A work already resolved, reuse those mappings **if** selected N1F provider identity and applicable APEX/namespace state match the historical inputs. Record `prior_evidence_ref,prior_provider_sha,target_provider_sha,configuration_comparison,decision`. `NOT_SUPPLIED` is not `FAIL`.
3. **Genuinely risky edges**: `libhidltransport.so`, `libion.so`, `libstagefright_omx_utils.so`, `android.hardware.graphics.bufferqueue@2.0.so`, `android.hardware.common-V2-ndk.so`, `android.hardware.common.fmq-V1-ndk.so` and any additional symbol/version edges exposed by validated prior closure. For vendor-only candidates, require explicit APK namespace reachability, never assume `/vendor/lib64` is linkable.
4. **Staging**: verify existing C1 `system_ext_specific` modules really install to embedded `/system/system_ext` in the *selected derived N1F image*. Preserve skip_mount configuration and do not import D1R2 broad stack.
5. **R1**: prepare the single-action manifest patch against the pinned blob. No new manifest owner search needed unless the underlying source blob changes.

## Minimal handoff rows for only unresolved deltas

```tsv
soname	prior_evidence_ref	prior_provider_sha256	target_provider_sha256	namespace_evidence	decision
libhidltransport.so	NOT_BOUND	NOT_BOUND	NOT_BOUND	NOT_BOUND	UNRESOLVED_SPECIFIC_DELTA
libion.so	NOT_BOUND	NOT_BOUND	NOT_BOUND	NOT_BOUND	UNRESOLVED_SPECIFIC_DELTA
libstagefright_omx_utils.so	NOT_BOUND	NOT_BOUND	NOT_BOUND	NOT_BOUND	UNRESOLVED_SPECIFIC_DELTA
android.hardware.graphics.bufferqueue@2.0.so	NOT_BOUND	NOT_BOUND	NOT_BOUND	NOT_BOUND	UNRESOLVED_SPECIFIC_DELTA
android.hardware.common-V2-ndk.so	NOT_BOUND	NOT_BOUND	NOT_BOUND	NOT_BOUND	UNRESOLVED_SPECIFIC_DELTA
android.hardware.common.fmq-V1-ndk.so	NOT_BOUND	NOT_BOUND	NOT_BOUND	NOT_BOUND	UNRESOLVED_SPECIFIC_DELTA
```

These are **worklist placeholders**, not evidence of missing providers. Add or delete rows only on a previously sourced provider/namespace comparison.

## Decision at this checkpoint

```text
M3_R2_REUSE_MATRIX=COMPLETE_REVIEWED_SCOPE
FIVE_LIBRARY_IDENTITY=REUSE_PASS
DIRECT_DT_NEEDED_56=REUSE_PASS
BIONIC_19_SUBSET=REUSE_PASS_SUBSET_ONLY
B2_C3A_PROVIDER_MAPPING=REUSE_CONDITIONAL_ON_EXACT_TARGET_INPUTS
R2_V2_MISSING_51=INVALID_AS_DEVICE_ABSENCE_CLAIM
R2_FULL_RECURSIVE_ABI_AND_IMS_NAMESPACE=NOT_PROVEN_IN_AVAILABLE_EVIDENCE
R1_MANIFEST_SOURCE_PIN=REUSE_PASS
IMS01_EMBEDDED_TARGET=DESIGN_ACCEPTED
CELLULAR_ADB_TOGGLE=TRANSIENT_DIAGNOSTIC_ONLY
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

Next work product must be **a minimal patch preview** plus a **delta-only** R2 linkage decision. No third baseline census or repeated five-ELF inventory. Preserve historical evidence and original PR #339 draft status.
