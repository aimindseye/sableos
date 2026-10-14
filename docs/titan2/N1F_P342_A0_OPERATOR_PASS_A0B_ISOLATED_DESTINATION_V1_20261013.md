# PR #342 — Actual A0 operator PASS; A0B fresh isolated workspace vacancy preflight V1

Date: 2026-10-13. Operator completed previously shipped `N1F_P342_A0_CUSTODY_V1.zip` on ai-g732 and supplied real JSON. This document admits **actual A0 custody**, then offers one **separately gated metadata-only A0B next step**. Nothing in A0/A0B authorizes Android checkout creation, source mutation, system image build, network sync, hybrid super assembly, device contact, reboot, AVB change or flash.

## 1. Operator's actual A0 results — complete at intended scope

```text
A0_OUTER_AND_INNER_SHA=PASS_4_OF_4
A0_REGRESSIONS=PASS_30_OF_30 seconds=0.040
A0_PLAN=PLAN_ONLY_ZERO_EVIDENCE_IO
A0_REAL_INSPECT=A0_CUSTODY_METADATA_ONLY_NEW_PARENT_AND_OUT_NOT_BOUND
OCT03_ORIGINAL_ANDROID=DIRECTORY
OCT03_ORIGINAL_OUT=DIRECTORY
M4_ISOLATED_ANDROID=DIRECTORY
M4_FAILED_OUT=DIRECTORY
CW1_ISOLATED_ANDROID=DIRECTORY
CW1_WARM_OUT=DIRECTORY
C2_SEALED_STOCK_BUNDLE=DIRECTORY
CW1_SOURCE_PATCH=PRESENT_REGULAR bytes=2693
CW1_SOURCE_PATCH_SHA256=4d2ad6b567ca725e8cc45c0362cdd788e3425c668592241aa4da007aa019635d PASS
NEW_A1_OCT03_DERIVED_SOURCE_ROOT=UNBOUND
NEW_A1_OUT_DIR=UNBOUND
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

Seven protected directories are accessible and the CW1 patch is SHA-bound. The `A0_CUSTODY_METADATA_ONLY_NEW_PARENT_AND_OUT_NOT_BOUND` status was intentionally hard-coded and is **not** a failure. Avoid re-running A0, R1/B1, 991-project census, C2 36/33 native hashes, CW1 JAR compile/DEX, M4 image, A4/R2, PHH static member, LP/AVB. Preserve original Oct03, M4, and CW1 source trees and their outputs (including `out_cw1`). Old M4 source is a donor **not** a boot-qualified parent. Oct11 actual as-flashed super remains unbound.

## 2. Existing implementation/tooling review before another script

- [Previous A0 contract](N1F_P342_A0_PROTECTED_SOURCE_CUSTODY_PREFLIGHT_V1_20261013.md) already covers all fixed historical source/input paths and the CW1 small patch; repeat checks would not establish a new source build parent.
- [Current cellular + CW1 scope](N1F_P342_CELLULAR_CW1_EXPANDED_HYBRID_BUILD_DECISION_V1_20261013.md) already defines A1 minimum C1/R1/B1/PHH guard/MTK RRO/incoming-call property, followed by conditional A2 CW1 source + C2 28 imported natives / five reused AOSP16 native providers, conditional effective G3.
- Original Oct03 N1F driver `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh` is **build+flash coupled** and must NOT be invoked for a new isolated host-only checkpoint. Historic M4 isolated 991-project reconstruction and `m systemimage -j4`/source staging are **prior build design references**, not proof a new Android16 checkout exists or can be built from an unbound parent. C2 existing build/native installation and postbuild gates should be reused only when source and image revisions match; no blanket execution on new A1.
- A new Android16 source checkout still needs exact C3A 991-row project-head/369-patch manifest and OFFLINE source-materialization procedure; **no new source checkout is identified or created by this step**. PATH hints do not validate JDK/API36/Soong/toolchain dependency provenance.

## 3. Exact A0B proposed destination, read-only metadata

```text
FIXED_PARENT=/srv/data/sable-build/workspaces
CANDIDATE_CONTAINER=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated
FUTURE_ANDROID_SOURCE=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android
FUTURE_OUT=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/out-a1
```

These names are **proposed**, not reserved, real, or approved for mutation. A0B inspects only the physical parent ancestors with `os.lstat` (symlink refusal), the exact proposed container leaf with `os.lstat` (must be `ENOENT`; any existing file/dir/symlink is protected and STOP), `os.statvfs` capacity **metadata** on the known parent, and advisory command PATH lookup for Python3, Bash, Git, repo, Java, Ninja, unzip, sha256sum. It neither lists directories nor reads content; no `git`, `repo`, `java`, `ninja`, `m`, `soong_ui`, network or shell subprocess is executed. Default `plan` has zero host evidence access. `inspect --authorize-a0b-metadata-only` is read-only. PATH-present is **not** version/Android toolchain readiness; free space is a point-in-time hint; a vacant name can race future usage, must be rechecked when creating under separate authority.

A0B distribution `N1F_P342_A0B_ISOLATION_V1.zip` (8,323 bytes), SHA256 **`eb6caa17b36e0288f240c2897a19f5e1266f337364543ece835409fcddb12938`**. Main Python SHA256 `b68f62d5ec62ecade28abe80d0eec6828b0d558b71748752d887ff00cd2e8f81`. README+plan+test+script SHA256SUMS 4/4 PASS; ZIP CRC PASS. Both Python AST files PASS and README shell `bash -n` PASS; **30/30 synthetic regression tests PASS in 0.004–0.005 s core**, with negative occupied-directory/file/symlink, missing/unsafe ancestor, no-write assertions, flags/no-I/O plan. Synthetic 1200 end-to-end temporary fixture probes median **0.00547 ms**, p95 **0.00579 ms**, local 30-test process wall **0.68 s**, max RSS **98,704 KiB**; none measures ai-g732 filesystem or Android compilation. No proprietary files, keys or device identifiers in ZIP. Required interpreter Python3.10+ stdlib; unzip and sha256sum only for package transfer.

```text
A0_OPERATOR_INSPECT=PASS_ALL_PROTECTED_ROLES_AND_CW1_SHA
A0B_LOCAL_PACKAGE_SYNTAX_TESTS=PASS_30_OF_30
A0B_AI_G732_RUN=NOT_EXECUTED
NEW_CANDIDATE_CONTAINER=PROPOSED_UNRESERVED
NEW_ISOLATED_C3A_SOURCE_LINEAGE=UNBOUND
NEW_A1_OUT_DIR=PROPOSED_UNCREATED
CW1_RUNTIME=NOT_TESTED
A2_NATIVE_EFFECTIVE_G3=NOT_QUALIFIED_FOR_NEW_IMAGE
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO SUPER=NO DEVICE=NO FLASH=NO
```
