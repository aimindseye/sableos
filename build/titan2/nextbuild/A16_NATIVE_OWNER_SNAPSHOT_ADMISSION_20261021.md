# AI-G732 Android16 Q25 owner snapshot admission — 2026-10-21

Status: **PASS_EVIDENCE_INTEGRITY / PARTIAL_NATIVE_SOURCE_READY / NO_ANDROID_BUILD**.
Source scope: draft PR347 based on frozen PR346 commit `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`. Current branch at analysis start `2f135e18d3685892ad0de9f3641043b6f21a163e`.

## Actual user-provided source snapshot
- Original owner ZIP: `TB2_Q25_A16_OWNER_SNAPSHOT.zip`, SHA256 `a287e8e06daa2cf867aa2bdeaa174c7d0c12ecedf770c9f9b9f534f8829661aa`.
- Original command was `a16_owner_snapshot.py --android-root /srv/sable-build/workspaces/titan2-track-b/android --plan` followed by `--collect`. Both reported `TB2_A16_NATIVE_OWNER_FOUND=34`, `MISSING=66`, `requested=100`.
- Archive integrity: ZIP CRC PASS, **34/34 embedded source path SHA256 and byte-size confirmations PASS**, no unexpected member paths.
- Captured: **SystemUI 16**, framework services **4**, Dialer **3**, DocumentsUI **6**, Settings **5**.
- Missing **66** exact Q25 target filenames includes *new files introduced by original Q25 patches*, but also names for absent Jelly browser and Lineage SetupWizard owners. Missing does not imply all are missing from a working image; only the exact named owner paths were checked.

## Actual engineering work from this snapshot — sealed host-only handoff
- Hand-off ZIP `TB2_Q25_A16_NATIVE_SNAPSHOT_V1.zip`, SHA256 `05b7aa564c16539596d499578e22b765e4dfa835041582a7a7d2091210161c4c`. Distributed as conversation attachment, **not GitHub source bytes**.
- `QS_SOURCE_REVIEW_ONLY.patch`, SHA256 `1cca337712d1d0f14dfed8b2bfb0ea44bd92f4b62c2a57301fe162eebeca5d23`, is a concrete **five-path** resource/shape adaptation of Q25 SystemUI 0101/0102 against captured A16 owners:
  - `DefaultLargeTilesRepository.kt`: replace hard-coded internet/bt/dnd/cast default set with a resources-based list.
  - `DefaultLargeTilesRepositoryKosmos.kt`: main-resources fixture.
  - `CommonTile.kt`: inactive 50dp pill -> 12dp card.
  - `Tile.kt`: active 24dp tile -> 12dp card; active icon 16dp -> 8dp.
  - `res/values/config_qs_large_tiles.xml`: new overlayable resource with upstream-equivalent defaults.
- **Exact uploaded owner source fingerprint + git apply --check PASS** in a temporary copy. `qs_exact.py` rebuilds the patch without touching AOSP.
- Pure Kotlin/JVM compilation of the revised resource repository with Android/DI/TileSpec stubs, **2/2 assertions PASS** (default tiles, trim+dedup). This is **not** a real SystemUI Soong build and does not decide 2 vs 3 QS columns.
- `native_trial.py` previews four Git blob-pinned **existing** Q25 patches: framework 0101/0102 and DocumentsUI 1001/1002. It performs actual `git apply --check` and scratch-only application, orders prerequisites, generates combined review source diff and per-patch admission report. Direct real DocumentsUI replay against the snapshot was **not executed on this assistant host**, because the original Q25 patch inputs remain in user's connected SableOS checkout; only the scratch operator fixture was executed. Never claim Files compile or runtime.
- **12/12 Python regression tests PASS in 0.348s**, covering actual ZIP sha integrity, owner file context and QS source fingerprint drift, synthetic multi-patch Q25 scratch apply and hold behavior, fresh output, path-security checks. Source snapshot hash scan **50 iterations 0.498s, ~10ms per scan** on assistant host. Python AST/py_compile PASS; Bash syntax PASS; review handoff ZIP CRC/SHA PASS.

## Explicit boundaries for further Q25 native integration
- Q25 original Files patches historically `PASS_SCRATCH_CONTEXT_ONLY` in the earlier v1.1 receipt, but on **this exact new snapshot** native_trial real result is pending. Apply no patch to actual AI-G732 source until reviewed compile-qualified promotion.
- `PhoneWindowManager.java`, `SysUIKeyEventHandler.kt`, `KeyguardKeyEventInteractor.kt` captured: global Alt+Space and SystemUI navigation need source-context adaptation. Seven earlier native SystemUI/Dialer source modifications are separately committed on AI-G732; preserve them.
- Browser Jelly, Lineage SetupWizard absent. Settings AppLock/Focus/Vault private security need real privileged enforcement, not UI-only source.
- Actual default SMS role/READ_SMS, IMS G1/G2/G3, selected image/app provenance and device runtime remain unqualified.
- PR347's `Q25_SOURCE_READINESS.json` remains **30 open prerequisites, one N/A**; no new full AOSP image attempt. Frozen PR346 AOSP intermediate outputs remain preserved after SSH SIGHUP; no AOSP source mutation, test reflash, reboot, or device action performed.

## Usage
Handoff README instructs ai-g732 to use the independent PR347 checkout, set `TB2_Q25_SNAPSHOT`, verify SHA256SUMS, run the 12 standard-library Python regressions and QS JVM smoke, reproduce QS review diff and run bounded native patch trial with fresh output path. Any mismatch is **HOLD**, not a fix-by-guess instruction.
