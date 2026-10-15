# PR #342 — actual A1J PHH POST and A1K exact marker/product source staging V1

Date: 2026-10-14 UTC. This PR update is documentation/evidence only; no GitHub source mutation or ai-g732 build via assistant.

## Operator's actual A1J integration PASS

Operator-reported output `PASS_EXACT_A1_PHH_GUARD_POST_SOURCE_ONLY_NOT_BUILD_READY`; selected A1 `device/phh/treble/phh-on-boot.sh` exact SHA256 `ab3369f6b06b751ecd59d43368daef0057470674cc233c0d468a84b7d465386e`. Exactly one A1 source path modified; evidence `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/.A1J_PHH_GUARD_REUSE_NO_BUILD_V1` exists. `.A1_INCOMPLETE_DO_NOT_BUILD` marker preserved, `out-a1` absent; no build, network, super, device or flash. **Do not rerun A1J.** This closes source guard POST only: actual marker file, installed product visibility and boot timing remain unproven.

## Existing exact source authorities reused, NOT M4 image

Historic M4 C1 marker/product source in PR339: marker SHA256 `13ea9199448fb91a85b6fb5806090c6bb7a1201dfb93ae5342c8aa0488551d2f` (46 bytes); C1 mk POST SHA256 `fb0d801edd470d13d68f4105586f8f18ac30c1255dd7fd1076bf02157c017c5e`. The new A1K gate rechecks those on the host, rather than assuming historical receipt binds current bytes. The M4 physical system_a experiment entered Recovery and is not reused as an image or code baseline. Canonical main C1/C3B source Git blobs: C1 BP `5b68bdde3a158a38fc7532abb571de88d2688649`, C1 base mk `56f7d1fdca8427b4e1d64376c8e18ad19b49c82c`, C3B BP `82a702a8d4863aa5c0b314e04563b3b28ae77a06`, C3B mk `482d24509530d94375f47f5cd3b63f15e2340ba4`. No stock native admitted.

## A1K downloadable handoff — source-only, preview first

`N1F_P342_A1K_MARKER_PRODUCT_STAGE_V1.zip` **SHA256 `f2da21cd93c24f736d58617f5042a988edef49ee305f5d2dbb353cb412eafba7`**; size **23,361 bytes**; main Python SHA256 **`86d73e7b3214de10c508fb891cb9b69d67e7c954d3c78f9dcbcecb1f85afb4e1`**. Unchanged A1D helper SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`. ZIP CRC PASS, **9/9 inner SHA256 PASS**, 4/4 Python AST/compile PASS, Bash syntax PASS, **92/92 synthetic combined A1D + A1K regression cases PASS** with `umask 077` (0.172s) and `022` (0.172s), and fresh extracted ZIP `umask 077` 92/92 PASS (0.162s). Synthetic tiny marker-diff classification median 0.00650 ms/p95 0.00860 ms; **NOT real ai-g732 timing**. Actual A1K host inspect/apply **NOT_EXECUTED**.

A1K first invokes `plan` without host evidence I/O, then `inspect --authorize-a1k-readonly-stage-preview`: verifies selected R1/B1 POST, A1J PHH POST, original ROM/skip_mount SHA; A1H+J evidence; marker/out/.repo guard; source bytes of four exact canonical templates, M4 retained C1 post mk and exactly **one appended** marker-only `PRODUCT_COPY_FILES` block, M4 46B marker derived from precisely that stanza, exact expected hash. Symlink traversal and broad directory search denied. Any M4 source drift or unrelated product edits refuses. A1K preview has no writes.

OPTIONAL **separately explicit** `apply --authorize-a1k-exact-five-a1-source-writes` after actual preview review: requalifies and creates only five isolated A1 files, exactly C1 `Android.bp`, C1 marked product `.mk`, C3B `Android.bp`, C3B app `.mk`, and marker source at the path parsed from verified product mk. Only absent A1 stage ancestor directories, one no-build receipt dir and exact five file leaves may be created. Files created using fd nofollow/O_EXCL/fsync and rehashed, no donor/M4/canonical edits, no retries/rollback/cleanup on partial state. The marker install **SOURCE** and owner are not actual installed/early-boot marker proof.

Remaining blockers after even A1K successful stage: original C1 signed APK and two framework JARs, three config XMLs, C1 SELinux materialization, five C3B release app APKs, A1 `rom.mk` C1 inherit and C3B graph, `.repo` metadata and independent 991 Git object-store closure, original Oct03 369 patch semantics/TrebleApp post bytes, evaluated Kati/Soong bootclasspath and system_ext copyout, image-bound effective G1/G2/G3. Never automatically clear `.A1_INCOMPLETE_DO_NOT_BUILD` or launch old combined N1F build+flash runner. User **host-only image build authorization remains YES**, technical readiness NO. No super/LP/AVB/device/flash authorization.

```text
A1J_HOST_ACTUAL=PASS_PHH_POST
A1K_ZIP_SHA256=f2da21cd93c24f736d58617f5042a988edef49ee305f5d2dbb353cb412eafba7
A1K_ASSISTANT_QA=PASS_ZIP_INNER9_AST4_BASH_TESTS92
A1K_AI_G732_PREVIEW=NOT_EXECUTED
A1K_AI_G732_SOURCE_STAGE=NOT_EXECUTED
A1_NO_BUILD_MARKER=PRESERVE
BUILD_AUTHORIZED_HOST_ONLY=YES
BUILD_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR #342 remains OPEN/DRAFT/UNMERGED.