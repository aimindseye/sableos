# PR342 A1M V1.1 real host complete; A1N retained evidence binding handoff

Checkpoint: 2026-10-14. Status: **no Android image build until all PRE-build technical admission gates pass**. User host-only image-build permission remains, but technical BUILD_READY=NO. Device/super/flash NO.

## Actual ai-g732 A1M V1.1 result

Operator checksum `N1F_P342_A1M_ALL_GATES_READONLY_V1_1.zip` PASS, 9 bundled SHA256 checks PASS, 104/104 regression tests PASS (0.045s), I/O-free plan PASS, real consolidated read-only inspection returned **`HOLD_A1M_ALL_PREBUILD_GATES_NOT_COMPLETE`**, `gate_count=13`, `not_fully_admitted_gate_count=11`, no writes/source mutation/build/device/super/flash.

Two accepted at bounded scope: (1) exact 11 A1 POST source pins with PHH guard, C1 ROM inheritance, one marker copy rule, `.A1_INCOMPLETE_DO_NOT_BUILD` preserved and `out-a1`/`.repo` absent; (2) five SHA256-sealed N1I-A audit receipt FILE CONTENTS, not exact stock partition-to-file extraction proof. Six retained M4 IMS APK/JAR/XML candidate files match 3 canonical binary SHA pins and 3 M4 observed XML hashes; all `MATCH_DECLARED_CONTENT_NOT_STOCK_PROVEN`. Five retained M4 C3B APKs are regular and hashed, not linked to an independently sealed build bundle. Retained `property.te` regular but exact stock CIL path not supplied. No source drift found. Do not repeat A1M.

Open PRE-build requirements: stock byte provenance and six payload admission, five Sable app APK source build seal & unsigned status, `property.te` generation from verified CIL, independent Git objects/.repo, patch/TrebleApp selected-source fidelity and config-only Soong/Kati graph, SELinux source policy correctness. Compiled policy and final effective G1/G2/G3/image content/PHH marker runtime visibility are inherently POST-image-build verification and remain hard pre-device/flash gates. The technical *pre-build* gates must pass before image build; these post-image gates cannot be asserted before an image exists.

## A1N: bounded prior receipt binding (new external ZIP)

`N1F_P342_A1N_RETAINED_PROVENANCE_BIND_V1.zip` SHA256 **`0f527043481e91f171ab73148720b3bd97fb5bc5780d3c5b6adbefe90af48fd1`**, 32,026 bytes. Main new Python SHA256 `c1f0bafaf4075161f35b3aa70fdb8e6c64c563345e16f2893a119b6623953bdc`. Inherited UNCHANGED A1M Python SHA256 `00fd3edd2b5b842bbb24a8fab9838063846e962464f14c69ba4bf591186da544`; A1D nofollow SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`.

Offline assistant-container validation: ZIP CRC PASS, **11/11 bundled internal SHA** PASS, 6 Python AST/compile PASS, Bash wrapper syntax PASS, **137/137 A1D+A1M+A1N regressions PASS under umask 077 and 022** and **fresh extracted exact ZIP 137/137 PASS under both umasks**. Scoped 24-entry metadata enumeration synthetic median 0.0626ms, p95 0.1199ms (local synthetic only; NOT 5-app APK hashing performance). **A1N actual ai-g732 NOT EXECUTED**.

Distinct A1N read-only checks:

- Exact canonical builder historical output roots only: `/srv/sable-build/artifacts/titan2/n1i-c1-five-app-bundle/<UTC-stamp>` and `/srv/sable-build/artifacts/titan2/n1d-c3b-e2-product-apps/aafb543565c9d59ed5e0d9cda876aabb4967f8aa/<UTC-stamp>`. One-level `os.scandir` max 24 real UTC-stamped directories per root, maximum 4 manifest-bearing APK bundles fully hashed. Reuse UNCHANGED A1M app manifest/5 file checksum/M4 APK content checker. Matching content not independent unsigned apksigner/signature/source-snapshot certification. No recursive search.
- Exact historical candidate stock `system_ext_sepolicy.cil` under sealed N1I-A audit original work path and old C1 isolation stamped output work path, maximum 4 CIL files hashed; reuse UNCHANGED A1M nine-context five-type property.te derivation and compare historical M4 policy bytes. Matching policy not independently stock-origin-certified.
- Whole exact stock `system_ext.img` inspected only at 0,1024,1080 byte offsets for raw SPARSE/EXT4/EROFS magic. Only filesystem TYPE is inferred, not image SHA, extracted source proofs, or data lineage.

All checked paths use fd nofollow and fixed known roots. Symlinks/unexpected entries/excess counts/source pins drift fail closed. Default plan has zero host I/O; explicit inspect gate `--authorize-a1n-bounded-retained-evidence-readonly` emits `HOLD_A1N_PREBUILD_ORIGIN_BINDING_INCOMPLETE` with app `matching_paths`, policy `matched_paths` or exact absent/hold reasons. No data writes, Git, repo, Android config, Gradle, stock extraction or mounts. A1N may identify original artifact paths for reuse by A1M's existing explicit optional selectors; it never automatically stages them or authorizes build.

Run from independently SHA-verified fresh extraction `bash ./n1f_p342_a1n_verify_then_inspect_v1.sh`. If no original artifacts remain, normal HOLD and next action is qualified reconstruction, not guessed paths; any REFUSED means stop. Preserve completed A1F–A1L and A1M evidence. `.A1_INCOMPLETE_DO_NOT_BUILD` must remain; `out-a1` absent; no build/super/device/flash.

```text
A1M_V11_REAL_OPERATOR=HOLD_11_OF_13_NOT_FULLY_ADMITTED
A1N_LOCAL=PASS_ZIP_CRC_SHA11_AST6_BASH_TEST137_BOTH_UMASKS
A1N_AI_G732=NOT_EXECUTED
PREBUILD_GATE_READY=NO
HOST_IMAGE_BUILD_AUTHORIZED=YES
IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 remains OPEN/DRAFT/UNMERGED.