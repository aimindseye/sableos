# PR346 app-quality source availability HOLD — isolated detached worktree handoff

**Actual owner ai-g732 finding (2026-10-21):** Combined native acceptance succeeded with `status=PASS_PHASE1_SOURCE_AND_PHASE2_NATIVE_COMPILE_ATTESTED`; Phase1 seven-source promotion PASS, real A16 `m -j4 SystemUI Dialer` PASS in 362.602 s, and Phase13 source freeze PASS. The optional `quality-plan --sable-repo /srv/sable-build/sableos/repo` stopped **before any Gradle execution** with:

```
PHASE12_COMBINED_HOLD=FILE_MISSING:/srv/sable-build/sableos/repo/apps/titan2/platform/setup/src/main/java/org/sableos/titan2/setup/core/OwnerEvidence.kt
```

This exact source exists at [PR346](https://github.com/aimindseye/sableos/pull/346) Git blob `4c91a68c3e15fb723ecf26bab37c1d170de3e8f8`. Its absence is a **canonical worktree source-state mismatch**, not a regression in seven native AOSP owners, compiler output or Phase13 snapshot. Because this gate stops at the **first missing marker**, no claim is made that all other PR346 files are present or absent in the local canonical worktree.

**Do not** copy only `OwnerEvidence.kt`, cherry-pick the entire 203-file draft into the active canonical checkout, reset/clean the dirty worktree, or rerun native `m`. The remaining PR346 app files, Gradle registration and dependencies must stay coherent.

## Next one-pass source binding (local sealed operator, not yet run on ai-g732)

`TB2_Q25_PR346_ISOLATED_QUALITY_SOURCE_V1.zip` SHA256 `924325bb4ddd3e5ca1e61189db7d75fab6be713b3449322e59a098b02cb16010`, local distribution only (not Git committed). Pure Python3+Git `quality_checkout.py` creates a **separate detached Git worktree** exactly pinned to PR346 HEAD `257a037e88f20d5f998c89c5047f9d903640c4f1`. It verifies six PR346 exact Git blob pins (Setup, Keyboard, Tools, Hub, Messages, Calendar) and seven Gradle module source roots in the isolated checkout. The canonical SableOS worktree, its current HEAD, and AOSP Track B native owners are not reset, checked out or rewritten.

Default `plan` uses local Git objects only; `prepare` requires `CREATE_ISOLATED_PR346_Q25_QUALITY_WORKTREE`. Only if the commit is absent locally may the owner additionally opt into a canonical GitHub `refs/pull/346/head` fetch with acknowledgement `FETCH_PINNED_PR346_IF_NOT_ALREADY_LOCAL`, pinned SHA object presence and ancestor verification (newer PR documentation commits allowed), and no tags/submodules. A rebased/unrelated PR head fails closed. The new isolated path must not exist and must be outside canonical and Android worktrees. Source qualification report is `PR346_QUALITY_SOURCE_RECEIPT.json`.

**After successful isolated checkout**, run the **existing** combined operator `quality-plan --sable-repo <isolated PR346 worktree> --combined <successful COMBINED_RESULT.json>` and only then optionally `quality-run` with its separate explicit Gradle authorization. Offline Gradle distributions 8.14.3 (Titan2) and 8.13 (R8) plus cached dependencies/JDK17/SDK must already be available; no wrapper/bootstrap downloads. This source handoff **does not run app assembly or quality** itself, no AOSP recompilation, no `sable.sh` image build, no device or flash.

Local validations on sealed operator: Python `py_compile`, Bash `bash -n`, 12/12 synthetic real-Git worktree tests (~0.72 s), ZIP member hashes/CRC and package SHA PASS; 100k local small Git blob hash operations ~1.0395 s (not a Git checkout or Android/Gradle performance claim). The isolated checkout has not run on ai-g732 and optional seven-app quality remains **NOT_RUN**.

## Ownership and remaining gates

PR342 draft historical IMS image evidence; PR344 current Track B handoff; PR345 Sonar static CI independent; PR346 open draft app source remains unmerged. Full portable Q25 feature closure, privileged AppLock/Vault/Freezer/Dual, selected image HOME/READ_SMS/Setup/Browser/IMS G1/G2/G3, physical VoLTE, complete `sable.sh` image and device/flash remain OPEN. Phase1+required Phase2+Phase13 are **already PASS** and are not rerun to cure this app checkout mismatch.
