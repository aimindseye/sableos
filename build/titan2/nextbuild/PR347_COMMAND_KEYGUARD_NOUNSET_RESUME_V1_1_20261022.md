# PR347 Command/Keyguard same-evidence module resume — portable V1.1 package (2026-10-22)

**Supersedes** `PR347_COMMAND_KEYGUARD_NOUNSET_RESUME_V1_20261022.md` artifact packaging only. The original runtime cause and remedy have not changed.

Owner's Track B AOSP Command and Keyguard changes were correctly staged (PWM SHA `6ebb07b1241222d51c5401ff6165046d708c790bc953cab030313d36f8fa01ad`; Keyguard SHA `bea9759c81e251bf6d1a1da4b606985b15cf21c197482d1a6dd165fdd911681e`). The old `set -euo pipefail` compile wrapper aborted while sourcing AOSP `build/envsetup.sh` at `TOP: unbound variable` **before Ninja**. Both files stay staged; do **not** stage again, create a fresh evidence folder, clean out or reset sources.

## Correct final handoff

`TB2_PR347_COMMAND_MODULE_RESUME_V1_1.zip` SHA256 **`0408c4ccbab4a63a6846427de46ee1043cf024b52e1547e6ad6e6957a7f0a201`**, 74,388 bytes, **nine members**. This **replaces the earlier V1 archive** SHA256 `9f45605c...`, which passed assistant-host tests but had two test fixtures referencing a transient `/mnt/data` path. V1.1 bundles the byte-pinned original staged Java/Kotlin postimages in `inputs/`; all fixture paths are now relative to the package and runnable on AI-G732.

Operator `bash operator.sh resume "$EVIDENCE" 4`:
- Validates **the original** `pr347-command-keyguard-<timestamp>` evidence directory containing both correct STAGE receipts, original failed `RESULT.json`, two exact source hashes and existing Track B `out/`.
- Uses child Bash `set -eo pipefail; set +u; source build/envsetup.sh; lunch treble_arm64_bvN-bp4a-userdebug; m -j4 services SystemUI`. It retains all AOSP build standard mechanisms, targets only those two modules, and adds no source editing action.
- Writes `RESUME_IN_PROGRESS.json` and new `resume-module.log`/`RESUME_RESULT.json`, leaving the **original** failure `module.log`/`RESULT.json` unchanged. Second retry fails closed. Existing source/output are not cleared.
- Does not run an Android full-image build, OTA, adb, flash or device action.

Validation: **16/16** real Python tests PASS (including original nounset failure reproduction, corrected mock AOSP compiled success, failed compile receipt, symlink/path/source-drift rejection, repeated invocation and original report preservation). Python compile and Bash syntax PASS. All packaged SHA256SUMS and ZIP CRC PASS. Independently extracted completed V1.1 ZIP ran **16/16 tests PASS (11.9s)**. Source-only preflight microbenchmark 100 iterations ~0.128s on assistant host; no Android compile speed extrapolation.

**Actual AI-G732 services/SystemUI compile result for this retry is still pending.** Full Q25 security, browser/first-boot, SMS role and IMS G1–G3 remain open. PR347 stays draft with fail-closed full-image gate. Pinned PR346 remote head unchanged at `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`.
