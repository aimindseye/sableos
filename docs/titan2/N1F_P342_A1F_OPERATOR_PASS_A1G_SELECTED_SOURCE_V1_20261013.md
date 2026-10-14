# PR342 — operator A1F actual PASS / A1G selected A1 source-state gate V1 (October 13)

**Scope:** docs-only PR engineering handoff, no Android build/super/flash/device authorization. Actual user-operated ai-g732 evidence below; assistant only read GitHub records and validated a new local synthetic package. **Never rerun A1F.**

## A1F real operator result

- `N1F_P342_A1F_EXACT_11_MANIFEST_REPLAY_V1.zip` outer ZIP and 11/11 internal checksum entries PASS. Inherited A1D/A1E/A1F synthetic regressions **132/132 PASS in 0.382 s**; plan `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO`.
- Authorized exact prewrite QUALIFY **`PASS_EXACT_11_MANIFEST_GAPS_QUALIFIED_READONLY_NOT_BUILD_READY`**, `manifest_declarations=11`, `manifest_linkfiles=10`, `manifest_copyfiles=1`, `content_reads=37`, `content_bytes=471362`. Five scaffold regular file SHA content, four C3A dirty source SHA, A1C original link source sha, nine other link sources, and `lk_inc.mk` copy source/donor equality passed at exact target.
- Exact isolated A1-only source replay **`PASS_EXACT_11_ARCHIVED_MANIFEST_DESTINATIONS_MATERIALIZED_NOT_BUILD_READY`**: ten new symlinks `Android.bp`, `bootstrap.bash`, `build/CleanSpec.mk`, `build/buildspec.mk.default`, `build/core`, `build/envsetup.sh`, `build/target`, `build/tools`, `trusty/.bazelrc`, `trusty/WORKSPACE.bazel`; one regular copyfile `lk_inc.mk`. `created_count=11`; protected donor not modified.
- Copyfile `lk_inc.mk` size 652, SHA256 `083778590fe579ecc6b484cb6381c7b09649397bde9665c089d83e45774108d4`, original donor mode `0o444`; A1F copy materializer also rehashed immediately after write. Final manifest census `BOTH_MATCH_EXACT_LINK_TARGET=10`, `BOTH_REGULAR_METADATA_ONLY_NOT_BYTE_EQUALITY=1`; copyfile content attestation belongs to materializer, not final census alone.
- No-build marker `.A1_INCOMPLETE_DO_NOT_BUILD` **PRESERVED**, `out-a1=ABSENT`. `A1F_END=NOT_BUILD_READY; IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO`. No evidence of partial/interrupted replay.

This closes the **exact 11 archived manifest checkout-artifact gaps only**. It does **not** prove all 991 Git object stores are independent of protected donor, build graph works without `.repo`, original 369-patch semantics, TrebleApp Oct03 POST bytes, R1/B1/C1/CW1/IMS source integration, complete effective G1/G2/G3 or new image boot success.

## Next nonduplicative selected-source gate — A1G

New standalone operator package `N1F_P342_A1G_SELECTED_SOURCE_PREBUILD_V1.zip` SHA256 **`11e9bf4bf2b836887c92f7a39d8bf7be7dcf2e469dffa2cdf995fe3409c89390`**, 22,394 bytes; A1D Python is reused **UNCHANGED** exact SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`. ZIP CRC PASS and **9/9 inner member SHA PASS**. Python source/tests AST+compile 4/4 PASS, Bash wrapper and README fenced syntax PASS, **88/88 local synthetic tests PASS (48 reused A1D, 40 new A1G)**, synthetic 100-fixture median **0.9028 ms** / p95 **1.1525 ms**; *not* ai-g732 performance. **Actual ai-g732 A1G NOT EXECUTED.**

Selected new A1 root is definitively `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android` (avoid historical protected V38 original and failed M4 source). A1G performs readonly:
1. SHA-bound Oct03 archived manifest census recheck exact 10 links + 1 copy state; independently rehash A1 `lk_inc.mk` 652-byte source copy / mode `0o444` in a new session, preserving marker/out.
2. Exactly two **new A1** source-state checks: R1 `frameworks/base/core/res/AndroidManifest.xml` PRE raw SHA256 `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c` / POST `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`; B1 `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java` PRE **Git blob SHA1** `27638e5be9c008101c2f9b8f1e7a9af49d94f838` / POST `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`. Each file <=2 MiB, no symlink-following. Prior PR339 original donor PRE and M4 POST results are *not* new A1-state proof; no need to re-read those historical roots.
3. Four **metadata sample only** `.git/objects/info/alternates` text leaves under `frameworks/base`, `build/soong`, `device/phh/treble`, `treble_app` (each <=8KiB). No target dereference/Git command, no independence PASS; A1 `.repo` expected ABSENT metadata, no creation.

A1G package launcher performs SHA/test/plan; optional inspect requires `N1F_P342_A1G_AUTHORIZE_READONLY=YES_EXACT_SELECTED_A1`. No source mutation/image build/repack/device/flash on any outcome; script reports `build_ready=false`.

## Next prebuild integration decisions after host A1G

If A1 R1/B1 are PRE/PRE, bind the existing exact R1 one-line and official B1 two-source PRE->POST mutation contracts specifically to A1, validate no-write diffs before any exact A1-only mutation, reuse historically passed C1/IMS/CW1/R2 evidence only within original scope. If unknown or mixed PRE/POST, stop for exact changed file. Do **not** blindly copy M4 generated sources, `.repo` metadata, C2 28+5 native set or failed M4 system image. Build admission remains blocked by original C3A patch source semantics, TrebleApp Oct03 POST byte authority, donor object dependency, `.repo`/Soong product graph and new-image effective G1/G2/G3.

```text
A1F_OPERATOR_HOST=PASS_EXACT_11_DESTINATIONS_MATERIALIZED
A1F_NO_BUILD_MARKER=PRESERVED OUT_A1=ABSENT
A1G_LOCAL_ZIP_SHA_TESTS=PASS_9_INNER_88_SYNTHETIC
A1G_OPERATOR_HOST_READONLY=NOT_EXECUTED
A1_GIT_ALTERNATES_INDEPENDENCE=UNBOUND
A1_REPO_METADATA=NOT_MATERIALIZED
NEXT_IMAGE_SOURCE_INTEGRATION=NOT_EXECUTED
BUILD_READY=NO BUILD=NO SUPER=NO NETWORK=NO DEVICE=NO FLASH=NO
```

PR342 remains **OPEN / DRAFT / UNMERGED**, no release/production admission.