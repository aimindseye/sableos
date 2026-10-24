# PR347 Native25: use existing Track B AOSP checkout — module-only incremental operator

**2026-10-22 / operator decision:** Owner explicitly directed **reuse** `/srv/sable-build/workspaces/titan2-track-b/android`, rather than provision a second Android16 checkout, and to stop repeating broad source audits. The separate checkout required by `PR347_NATIVE25_ISOLATED_MODULE_COMPILE_V1` was a false operational blocker: all ten standalone regressions had passed, then the operator correctly held on literal placeholder `/path/to/independent/pr347/android`. Three `.repo` workspaces existed, but the active Track B checkout is explicitly selected.

**Superseding sealed handoff:** conversation attachment `TB2_PR347_TRACK_B_NATIVE25_MODULE_V1.zip`, SHA256 `5cf9d89e6f3728e36f66c5ad766532dfbb05ddc0718912f64ad10a86fd836797`, size 825971 bytes, 8 ZIP files. It contains exact immutable original `TB2_PR347_NATIVE25_SEMANTIC_DEDUP_V1.zip` SHA256 `ea53ce44507575d9bf9fb399f4a8f63ab6c1e4c330428d69f469f8dbc1ee12f0` with nested approved 25-file overlay SHA256 `7141dd7ce9b82216edabc544f3349601a4e5da47afb8af99b8508d20869113d3`. No AOSP clone, repo sync, git clean/reset, output deletion, systemimage/OTA, adb, reboot or flash command.

## One-shot operation — owner must deliberately execute

Inside **external tmux** on AI-G732, after extracting the ZIP under `~/Downloads`:

```bash
cd ~/Downloads/TB2_PR347_TRACK_B_NATIVE25_MODULE_V1
sha256sum -c SHA256SUMS.txt
tmux new-session -s pr347-native25
# Within tmux, execute:
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-native25-$(date -u +%Y%m%dT%H%M%SZ)"
echo "NATIVE25_EVIDENCE=$EVIDENCE"
bash operator.sh run "$EVIDENCE" 4
```

`run` is an explicitly acknowledged, **live Track B source mutation of only the exact 25 Q25 approved source postimages**, not a dry run; 17 current preimages must match SHA256 and eight new paths must be absent. Existing `SableTitanInCallKeys.java` must still exist, and generic Q25 Dialer 0703 remains quarantined. A **single bounded 25-file SHA guard** before staging prevents overwriting unexpected edits; no 26-patch rescan or independent workspace validation. Before writes, originals+file modes are backed up to a fresh evidence directory *outside Android* and a crash recovery journal is persisted. Atomic replace applies only approved postimages; an exception during stage rolls written paths back. It then sources existing Android `build/envsetup.sh`, lunches `treble_arm64_bvN-bp4a-userdebug`, and runs **targeted incremental** `m -j4 SystemUI DocumentsUI services` in the **same Android root and preexisting `out/`**, with no alternate `OUT_DIR` or clean. This intentionally writes incremental build artifacts into prior `out/` but never deletes/rewinds them. Logs and explicit target exit code go to `$EVIDENCE/module.log` and `$EVIDENCE/RESULT.json`.

If and only if restoration of the staged **source** is required after stopping concurrent builds, run `bash operator.sh restore "$EVIDENCE"`. It replays only exact SHA-pinned old files from `PREIMAGES.zip`, removes only the eight added postimages, and refuses any user-edited source. It does not change existing `out/` artifacts.

## Validation in handoff author runtime

- Full ZIP and all seven SHA256SUMS members PASS, Python `py_compile` PASS, Bash `-n` PASS.
- **15/15 actual Python integration tests PASS** (0.716s), using the real pinned Native25 overlay plus independent disposable fake AOSP roots and mocked `m`: module PASS/failure exit receipts, staged 25/25 SHA outputs, original preimage restore, drift/unknown/new file/symlink/backup paths, hard failure injection rollback, preservation of old `out`, and no generic Dialer source.
- 20 fresh Python interpreter cold SHA-pinned Native25 archive extractions took **14.796 seconds** on author test host (~0.74s each); no performance claim for actual AOSP compile.
- **Actual AI-G732 execution has NOT occurred**, so Android16 module compilation, current APK provenance or device runtime is **not proven**.

## Source authorization boundary

This changes the **physical Track B Android checkout only after the operator runs**; PR346 remote frozen Git HEAD stays `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`, but the local AOSP source and incremental out tree will intentionally be advanced for PR347 native module compilation. This reverses the previous assumption of preserving the local Android source byte-for-byte at all costs, per the owner's explicit direction.

Full 23-row Q25/UI conformance, native 0304 Keyguard, true global Alt+Space, installed browser/first-boot ownership, privileged AppLock/Vault/Freezer and SMS roles, full launcher AOSP Compose, and IMS G1/G2/G3 still open. Next **full image** readiness gate remains HOLD. Module compile targets are only a bounded intermediate source check, not final acceptance.
