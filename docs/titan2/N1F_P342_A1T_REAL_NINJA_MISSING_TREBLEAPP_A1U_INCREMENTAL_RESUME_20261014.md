# PR342 — Actual A1T Ninja failure and A1U exact historical TrebleApp restore + incremental resume

**Date:** 2026-10-14 America/New_York. **Scope:** Titan 2 isolated A1 host-only image build, expressly authorized by operator. PR remains OPEN/DRAFT/UNMERGED. No device, super, flash, reboot or release authorization.

## Actual ai-g732 A1T host result

Operator uploaded the A1T `systemimage.log` tail from the first image build. Exact bootstrapping and graph events:

- 280/280 Soong Go/bootstrap steps finished, Android.bp analyzed and target Ninja file generated.
- Android Make parser and packaging rules completed at 778/778; Ninja entered image-building stage.
- Genuine error: `FAILED: ninja: 'treble_app/TrebleApp.apk', needed by '.../obj/APPS/TrebleApp_intermediates/package.apk', missing and no known rule to make it`.
- `ninja failed with: exit status 1`, `A1T_IMAGE_BUILD=FAIL build_rc=1`, `A1T_DRIVER_EXIT_CODE=1`. **No resulting image, no flash**. The original A1T output directory and failed receipt are one-use artifacts: **DO NOT rerun the original A1T driver or clean/clobber**.
- Host-only Ubuntu `Build sandboxing disabled due to nsjail error.` and `mkdir: '/system': Permission denied` remain **known non-blocking diagnostics**; no impact on the genuine Ninja missing-input exit status.
- `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS` warns about absent installed kernel/boot for a GSI; this warning is not the observed fatal error for the `systemimage` goal. Keep log intact.

## Historical source contract: a required C3A prebuild was skipped by A1T

Main SableOS `build/titan2/build-n1d-c3-trebledroid-systemimage.sh` and `docs/titan2/N1D_C3A_CONTROL_R1.md` prove the previous successful C3A/TrebleDroid Android 16 reference **first** ran `treble_app/build.sh release` with canonical `SABLE_JDK17`, recorded `treble-app.sha256` and `treble-app.bytes`, **then** `make systemimage`. The retained selected Oct03 A1 product still contains the `TrebleApp` prebuilt Make module requiring the relative APK path. The previous generic A1T driver omitted this prebuild prerequisite; simply regenerating Ninja or ignoring the error is not acceptable. The C3B later source-retirement policy does not retrospectively remove TrebleApp from the selected Oct03 C3A-derived graph. User-requested previous-chat/repo scope review: this prebuild was completed in earlier C3A control history, so prefer exact artifact reuse over another network-dependent Gradle build.

## A1U V1 one-use operator ZIP

**Archive:** `N1F_P342_A1U_C3A_TREBLEAPP_INCREMENTAL_RESUME_V1.zip`, exact outer **SHA256 `2d79ce800748c685800bd151ddcf57470106b3f1ca4387f1a43f9f8d52ae1c1f`**, **15,648 bytes**, 9 ZIP members (8 SHA256-sealed payloads, one `SHA256SUMS.txt`). Main `n1f_p342_a1u_resume_v1.py`, one-command `n1f_p342_a1u_one_command_v1.sh`, two hermetic unit test files, README/plan/review/validation. No external dependency or source patch pulled from network.

**Original successful C3A SHA authority:**
`/srv/sable-build/evidence/titan2/n1d-c3a-trebledroid-build/20261001T214611Z-trebledroid-systemimage/treble-app.sha256`; optional preserved `/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z/build-evidence/treble-app.sha256`. If two available, their hash must agree. Exact candidate generated APKs, in order:
`/srv/sable-build/workspaces/titan2-n1d/android/treble_app/TrebleApp.apk` and `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android/treble_app/TrebleApp.apk`. Only an existing **regular APK leaf <=128 MiB whose full SHA256 matches original C3A build proof** is admitted. Unknown host availability: **real A1U ai-g732 not executed**. If no SHA receipt or hash-matching APK exists, REFUSE **BEFORE A1 write**; do not guess hashes, install dependencies or implicitly run Gradle/network.

**Only permitted source mutation:** exclusive/no-follow create one missing generated `android/treble_app/TrebleApp.apk`, SHA256+size checked before/after with fsync; preserve A1/other receipts and original `.A1_INCOMPLETE_DO_NOT_BUILD` marker. New `.A1U_TREBLEAPP_RESTORE_INCREMENTAL_SYSTEMIMAGE_V1` one-use evidence (stage and incremental log/rc). Use the **existing failed A1T OUT_DIR** for incremental `make -j8 systemimage`, so Soong/Make outputs already generated are reused. Original A1T BUILD_RC=1 and original log **remain unchanged**; A1U has its own `RESUME_RC.txt` and successful `IMAGE_RESULT.txt` only after nonempty `system.img` produced. No `m nothing`, stock/APK/policy census, Git repack, source sync, image cleanup, device/fastboot/flash/super/reboot. Executing `make` cannot guarantee no implicit upstream network behavior but the driver itself initiates no fetch; no Gradle step.

**Operator invocation from SHA-verified fresh extraction:**
```sh
bash ./n1f_p342_a1u_one_command_v1.sh --authorize-a1u-c3a-trebleapp-restore-and-incremental-systemimage
```
Run in tmux if SSH is unstable. This is a one-use source-stage-and-incremental-build operation; preserve any partial stage or failed build; do not retry automatically. Success status `A1U_IMAGE_BUILD=PASS_INCREMENTAL_SYSTEMIMAGE_HOST_ONLY`, not physical GSI or flash readiness.

## Independent local tests and performance

- ZIP CRC PASS, all **8/8** bundled internal SHA256 PASS, Bash `bash -n` PASS, **3 Python AST/compile PASS**.
- **28/28 synthetic tests PASS** under `umask 077` and `022` (each about 14–15 seconds) and separately **28/28 PASS after fresh exact ZIP extraction** under both umasks; SHA8 repeated PASS.
- Unit tests exercise exact A1T failure, one-use denial, artifact SHA match, conflicting receipts, absent/symlinked candidate, guarded source/leaf/ancestor paths, no overwrite, partial copy preservation, authorization required, and no main(stage) direct invocation. Four end-to-end shell-wrapper tests exercise fake Android `lunch` and `make` success/failure (rc7), both umasks, with **all production absolute paths rewritten to a temporary fixture**, asserted absent before shell execution. Test harness is isolated even on a real ai-g732 machine with production A1 present.
- Synthetic 4MiB copy+hash+readback median **9.752ms**, p95 **10.665ms**, max **12.369ms** in assistant container across 12 runs; **not a real TrebleApp transfer, incremental Ninja, or ai-g732 benchmark**.
- Assistant has **not executed A1U against ai-g732** and does not claim that retained C3A APKs are present until host preflight returns PASS.

```text
A1P=PASS_12 A1Q_GIT=PASS_3 A1R_GRAPH=PASS A1_RELEASE_PROBE=PASS
A1T_SYSTEMIMAGE=ACTUAL_FAIL_RC1_NINJA_MISSING_TREBLEAPP
A1T_OUT_EVIDENCE=PRESERVE_NO_RERUN
A1U_ARCHIVE=PASS_CRC_SHA8_BASH_AST3_TEST28_BOTH_UMASKS
A1U_AI_G732=NOT_EXECUTED
IMAGE_READY=NO DEVICE=NO FLASH=NO
```
