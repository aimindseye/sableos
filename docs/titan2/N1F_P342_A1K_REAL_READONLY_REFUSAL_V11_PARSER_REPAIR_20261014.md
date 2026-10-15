# PR342 — actual A1K V1 read-only parser refusal; A1K V1.1 correction

Date: 2026-10-14. A1K real operator outcome is a controlled READONLY REFUSAL, not staging PASS. This is a docs-only engineering checkpoint in draft PR342, not a source or image change.

## Actual ai-g732 V1 result

- Outer `N1F_P342_A1K_MARKER_PRODUCT_STAGE_V1.zip` SHA PASS and 9/9 internal member SHA256 PASS.
- 92/92 A1D+A1K regressions PASS (0.116s). Their printed `REFUSED_READ_FLAG_REQUIRED`, `REFUSED_WRITE_FLAG_REQUIRED`, synthetic `PASS_A1K_EXACT_MARKER_AND_PRODUCT_STAGE_PREVIEW_NOT_BUILD_READY`, and synthetic `PASS_A1K_FIVE_STATIC_C1_C3B_MARKER_SOURCE_FILES_STAGED_NOT_BUILD_READY`, including `created_count=5`, originated **inside ephemeral `/tmp/.../A1/android` fixtures**, not actual A1.
- Actual plan `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO` PASS. Actual selected A1/M4 read-only inspector returned `REFUSED_A1K_READONLY_NOT_BUILD_READY`, `reason=Stop:unexpected_nonblank_line_in_marker_block`, `writes=false`, `build=false`. With wrapper `set -e`, **no source writes, evidence-stage creation, Android build or super/device/flash** followed.

## Failure scope and cause hypothesis

V1 `qualify()` validates the selected A1 guards, R1/B1/PHH/rom/skip_mount source hashes, canonical C1/C3B template Git blob pins, and **exact** historical M4 C1 makefile SHA256 `fb0d801edd470d13d68f4105586f8f18ac30c1255dd7fd1076bf02157c017c5e` **before** calling `marker_owner_diff`. The latter establishes exactly one EOF `insert` and then in V1 wrongly required exactly **two nonblank lines**. The observed refusal therefore points to the appended block's line grammar, **not M4 content hash drift or a missing marker**. Since actual appended lines were not printed, do NOT state unconditionally that the extra nonblank line was a comment.

## A1K V1.1 sealed package

Distribution: `N1F_P342_A1K_MARKER_PRODUCT_STAGE_V1_1.zip`, **SHA256 `e3f26054604f144499b8852c219c389035b7a625b081a8bbff66b83d24bd61ef`**, **24,805 bytes**. Main Python SHA256 **`730bf76bda7cf13fbe99348865f85bd344fbdb1cd913d9962afe8dd0f605d360`**; inherited A1D Python unchanged SHA256 **`6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`**.

Inspected source diff from frozen V1: only `VERSION=1.1`, scoped `marker_owner_diff` recognition, and two bounded inspect diagnostic fields. **All original A1 selected paths, hashes, evidence directory, no-build, five exact source file destinations, historical M4 C1 mk+46B marker SHA pins, canonical 4 Git blob pins, O_NOFOLLOW/no-overwrite/one-use/partial refusal policies unchanged**.

The new grammar requires at most five EOF appended lines, one exact `PRODUCT_COPY_FILES += \\` assignment and exactly one adjacent mapping `vendor/sable/titan2/n1i-c1/.../titan2-cellular-mvp:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/sable/titan2-cellular-mvp`; allows inert blank/comment lines only **outside** the adjacent assignment/continuation pair. Refuses comments containing `PRODUCT_COPY_FILES` or backslashes, a comment inserted between Make continuation lines, another active Makefile statement, duplicate copy/mapping, source/destination drift, or extra edits. The exact pinned M4 makefile SHA requirement is not relaxed. Preview newly reports `marker_block_comment_count` and `marker_block_assignment_adjacent`.

Assistant local validation: ZIP CRC PASS; **9/9 internal SHA256** PASS; Python AST/compile **4/4** PASS; Bash syntax PASS; **104/104 combined A1D+A1K synthetic regressions PASS under umask 077 (0.190s) and 022 (0.182s)**; freshly extracted exact ZIP: 104/104 PASS (0.204s). Extra tests cover accepted leading/trailing comments, exact five-file synthetic replay with comment, and refusal for second make statements, duplicate copy rules, interrupted Make continuation, risky commented assignments. 1,000 tiny synthetic marker parsings median **0.007561 ms**, p95 **0.009975 ms**; NOT an ai-g732 benchmark. **Actual operator A1K V1.1 NOT RUN**.

## Operator next action

Reject V1 for further use. Check new ZIP outer SHA above, unzip to a fresh `/tmp/n1f-p342-a1k-v11.XXXXXXXX`, run `bash ./n1f_p342_a1k_verify_then_inspect_v1_1.sh` to perform checksum/test/plan and real exact A1/M4 read-only inspection. No write enabled by the wrapper. Expected status if original suffix contains only inert comments: `PASS_A1K_EXACT_MARKER_AND_PRODUCT_STAGE_PREVIEW_NOT_BUILD_READY`, `marker_block_assignment_adjacent=true`; **share actual preview for review first**. If still refuses, STOP; do not force another parser relaxation or stage source. Optional once-only `apply --authorize-a1k-exact-five-a1-source-writes` remains separate; no retries/cleanup/rollback on refusal or partial.

Even successful five-source staging only pins C1/C3B static sources and 46-byte marker source; it does not stage IMS APK/JAR/XML/policy, five Sable APKs, prove installed marker/boot timing, `.repo` namespace, evaluated Kati/Soong product graph, independent Git closure, effective image G1/G2/G3 or Android boot. **Host-only image-build permission remains granted**, technical BUILD_READY still NO; `out-a1` absent and `.A1_INCOMPLETE_DO_NOT_BUILD` must remain. No super/LP/AVB/device/flash.

```text
A1K_V1_ACTUAL_HOST_REGRESSIONS=PASS_92_OF_92
A1K_V1_ACTUAL_HOST_READONLY=REFUSED_UNEXPECTED_NONBLANK_LINE_IN_MARKER_BLOCK
A1K_V1_ACTUAL_HOST_SOURCE_WRITE=NOT_EXECUTED
A1K_V11_ASSISTANT_ZIP_AND_TESTS=PASS_9_OF_9_104_OF_104
A1K_V11_ACTUAL_HOST=NOT_EXECUTED
A1F_TO_A1J_PRIOR_SOURCE_GATES=RETAINED
IMAGE_BUILD_AUTHORIZED_HOST_ONLY=YES
BUILD_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 remains OPEN/DRAFT/UNMERGED.