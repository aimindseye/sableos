# PR347 Track B Native25 Q25 0302 PhoneWindowManager Java scope correction — 2026-10-22

**Status:** `STAGED_NATIVE25_MODULE_BUILD_RC_1` (real AI-G732 compiler), fix `HOST_TESTED_AWAITING_AOSP_REBUILD`. Do not mistake this for image readiness. PR346 frozen remote HEAD is `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`.

## Actual first Android16 module build evidence
Owner executed `TB2_PR347_TRACK_B_NATIVE25_MODULE_V1_1` in existing `/srv/sable-build/workspaces/titan2-track-b/android`, with its existing incremental `out/`. The 25 exact Q25 source files were staged, Ninja got to ~52% of the planned `m -j4 SystemUI DocumentsUI services` target work before `services.core.unboosted javac31` failed in `PhoneWindowManager.java` lines 3449–3453. Four *actual* errors:
```
cannot find symbol: variable virtualKey
cannot find symbol: variable keyguardOn
cannot find symbol: variable down
cannot find symbol: variable repeatCount
```
The annotation-processing `RELEASE_17` versus source 21 and unrelated Kotlin nullable `listFiles()` messages are WARNINGS and not this failing code. `TRACK_B_NATIVE25_MODULE_RC=1`. No evidence supplied of a complete SystemUI/DocsUI/services module compile or any image/flash.

## Root cause
The pinned original Q25 shade patch 0302 inserted its `case KeyEvent.KEYCODE_DPAD_DOWN` in A16 `PhoneWindowManager.interceptSystemKeysAndShortcuts(IBinder, KeyEvent)`. The method declares only `final int keyCode = event.getKeyCode()`, not the four symbols assumed by the older patch. The source-context trial passed but did not establish *semantic compilation*.

Original exact staged `PhoneWindowManager.java` SHA256 `1c3c3a742ab4c6585c3049019a9ad1bd828fb03ee3ff58ca6baf5fea856692e3`; exact one-file corrected postimage SHA256 `5b45a3a980af5854c4f52b056ee64fe2d9a9f27b8d2cdc6cbbead8a576204b08`.

Corrected code uses:
- `final InputDevice shadeDevice = event.getDevice();` and `shadeDevice == null || shadeDevice.isVirtual() || (event.getFlags() & KeyEvent.FLAG_VIRTUAL_HARD_KEY) != 0` to exclude unknown/virtual input devices.
- `keyguardOn()`, `event.getAction() == KeyEvent.ACTION_DOWN`, `event.getRepeatCount() == 0` and `!event.isCanceled()`.
- Keeps original pure `SableShadeKeys.systemKeyFor`, source owner, display ID and SystemUI forwarding logic unchanged. Does NOT add global Alt+Space.

## Sealed one-file recovery operator
Conversation ZIP `TB2_PR347_PWM_SHADE_SCOPE_FIX_V1.zip`, SHA256 `cb1232bfc72d19bfb3a348ae1fe2f1425eab42b6e9d48e385e77d0339646536b`, 78,355 bytes; 14 archive members. Contains original exact PWM staged owner and SableShadeKeys owner, a review-only one-file unified diff, bounded SHA-pinned source fix operator, backup/restore, diagnostics, tests. No clone, repo sync, 25 file re-staging, source-wide audit, out clean, systemimage, device, flash or reboot.

Author-host validation: Python AST syntax 3/3, Bash `-n`, **16/16 Python regressions PASS (0.18s)**, exact source one-file `git apply --check` + actual scratch `git apply` reproduce corrected SHA, **standalone javac and 11/11 input-gesture tests PASS** using actual changed switch case and original SableShadeKeys.java against Android API stubs; ZIP CRC, SHA256SUMS all PASS; 100 repeated deterministic SHA/postimage derivations PASS. These are *not* real AOSP Soong compile results.

Run inside tmux on AI-G732 only after exact unchanged staged source fingerprint check:
```bash
cd ~/Downloads && unzip -q TB2_PR347_PWM_SHADE_SCOPE_FIX_V1.zip
cd TB2_PR347_PWM_SHADE_SCOPE_FIX_V1
sha256sum -c SHA256SUMS.txt
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-pwm-scopefix-$(date -u +%Y%m%dT%H%M%SZ)"
bash operator.sh run "$EVIDENCE" 4
```
Run intentionally patches **only the one real Track B PhoneWindowManager.java** and resumes `m -j4 services SystemUI DocumentsUI` in existing incremental `out/`. Backup and original source mode saved to `$EVIDENCE` before mutation, with exact-SHA restore option; build RC recorded in `RESULT.json` and compiler details in `module.log`. If unexpectedly drifted source, return HOLD instead of guessing. Earlier Native25 25-source staging journal stays preserved. Initial operator run not yet executed on AI-G732.

**Remaining:** all previously held Q25/IMS prerequisites, native module compile and subsequent runtime/role/device acceptance; full image readiness gate remains HOLD.
