# PR347 Command/Keyguard source staged; AOSP module wrapper `TOP` nounset failure — recover without re-staging
2026-10-22 | Owner AI-G732 output | module result remains **NOT BUILT**

## Actual observed operator output
The owner ran the previous source operator:
```bash
bash operator.sh stage "$EVIDENCE"
bash operator.sh compile "$EVIDENCE"
cat "$EVIDENCE/RESULT.json"
```
Source stage outputs show exact bytes for both files:
- `frameworks/base/services/core/java/com/android/server/policy/PhoneWindowManager.java` staged SHA256 `6ebb07b1241222d51c5401ff6165046d708c790bc953cab030313d36f8fa01ad`;
- `frameworks/base/packages/SystemUI/src/com/android/systemui/keyguard/domain/interactor/KeyguardKeyEventInteractor.kt` staged SHA256 `bea9759c81e251bf6d1a1da4b606985b15cf21c197482d1a6dd165fdd911681e`.

**Actual failure:** `build/envsetup.sh: line 26: TOP: unbound variable`, operator returned `MODULES_FAIL`, `exit_code=1`, `source_mutation=true`. This occurred **before** Soong/Ninja compile because the previous nested compile shell used `set -euo pipefail` then sourced AOSP envsetup, which reads optional unset shell variables such as `TOP`. Do not diagnose a Java or Kotlin compile failure from this receipt. Neither source should be staged again. Original evidence should be preserved.

## Self-contained corrected resume package
Conversation artifact `TB2_PR347_COMMAND_MODULE_RESUME_V1.zip` SHA256 `9f45605cc77c129df3e25b4fb4be2df50134fd5fb2601bd8e02ed15f10352939`, 10481 bytes, seven member files, all SHA256SUMS/ZIP CRC PASS.

- Replacement `operator.sh resume "$EVIDENCE" 4` does **not** stage, restore, reset or change source. Requires exact source SHA256s and matching two original `STAGE.json` receipts plus original `RESULT.json` status `MODULES_FAIL` with exit code nonzero and prior two targets.
- Verifies the existing incremental `android/out/`, source path safety and repo-managed contained `build/envsetup.sh` symlink/target; HOLD on drift, untrusted path, missing owner or duplicate retry.
- In a fresh child Bash uses **`set -eo pipefail; set +u; source build/envsetup.sh; lunch treble_arm64_bvN-bp4a-userdebug; m -j4 services SystemUI`**. This removes `nounset` only from the AOSP build shell, keeping error propagation and existing targets/output.
- Writes `RESUME_IN_PROGRESS.json` as a one-shot crash marker, `resume-module.log` and `RESUME_RESULT.json` *beside but not over* original `module.log` and `RESULT.json`. No repeated execution if any resume evidence exists. Full systemimage/OTA/device/flash none.

Assistant-host qualification on exact old 310KB+7KB staged source content from earlier sealed package:
- **16/16 Python integration regression tests PASS**, including direct reproduced `TOP: unbound variable` under old `-u`, corrected mocked Android envsetup+module compile, nonzero module exit, read-only stage fingerprint hold, original evidence preservation and duplicate run refusal.
- Python `py_compile`, Bash `-n`, all packaged SHA256SUMS/ZIP CRC PASS. Independently extracted completed ZIP rerun **16/16 PASS (9.66s)**.
- 100 repeated preflight checks on synthetic exact staged sources **0.128s** total (~1.28ms/check) on assistant host; this is not a prediction of Android module compilation time.

## Operator
Within existing external tmux and old prior evidence directory, **do not create new evidence**:
```bash
cd ~/Downloads
unzip -q TB2_PR347_COMMAND_MODULE_RESUME_V1.zip
cd TB2_PR347_COMMAND_MODULE_RESUME_V1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
bash operator.sh check "$EVIDENCE"
bash operator.sh resume "$EVIDENCE" 4
cat "$EVIDENCE/RESUME_RESULT.json"
```
If `$EVIDENCE` is lost, rebind to exact prior `pr347-command-keyguard-<timestamp>` folder, not a new one.

**No AI-G732 compile result for this retry yet**; new services/SystemUI source qualification remains pending the operator receipt. Earlier Native25 services/SystemUI/DocumentsUI `MODULES_PASS` is retained for older source revisions. Full-image Q25, browser/first-boot ownership, privileged security/profiles, restricted SMS/role and IMS G1/G2/G3 remain OPEN; PR347 stays draft. PR346 remote pinned HEAD `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab` remains unchanged.
