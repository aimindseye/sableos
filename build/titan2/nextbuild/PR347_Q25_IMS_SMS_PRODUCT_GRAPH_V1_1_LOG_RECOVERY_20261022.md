# PR347 — actual AI-G732 Q25/IMS/SMS product-graph V1 parser HOLD and no-rerun V1.1 recovery

Date: 2026-10-22 local / 2026-10-23 UTC. Owner's actual selected workspace: `/srv/sable-build/workspaces/titan2-track-b/android`. PR347 stays **DRAFT**, Track B-specific ADR-0013 remains in force. No PR346 changes.

## Actual AI-G732 evidence and what it proves

Owner's `TB2_PR347_Q25_IMS_SMS_PRODUCT_GRAPH_V1` package SHA checks PASS; **34/34 user-host regressions PASS** in **1.075s**.

- `inspect` returned `PASS_SOURCE_AND_STAGE_OBSERVATION_RELEASE_HOLD`, path `/srv/sable-build/evidence/titan2/pr347-product-graph-20261023T015938Z/PRODUCT_PREFLIGHT.json`.
- Both exact staged modules PASS unchanged: `SableLauncher.apk` 5,177,311 bytes SHA256 `f331848ca742aae888233edb8fa6dcbc9c0c1fed80f35f8f46d2d7d07564126e` and `Launcher3QuickStep.apk` 17,422,140 bytes SHA256 `580f795e1e4830014a9d691a4c790b36fe2cc3f097d5d5d9f7eebea48536e2e7`.
- Relevant source lexical cues: `device/phh/treble/rom.mk` adds SableLauncher and inherits `vendor/sable/trackb13ims/track-b.mk` with `PhhIms`, `PhhImsOverlay`, `Iwlan`; `handheld_system_ext.mk` refers to Quickstep. No installed-files manifest qualified.
- ACKed isolated `evaluate` command actually invoked `bash build/soong/soong_ui.bash --dumpvar-mode PRODUCT_PACKAGES`, target `treble_arm64_bvN`, release `bp4a`, userdebug. **Android command RC0**, duration **7.285s**. Combined stdout/stderr log **29,843 bytes**, SHA256 `1dffa094530dacc25ed53b3549783a94dbe9660c7abcc2456ae8e0f4f64c64a7`.
- Actual V1 *operator* `PR347_PRODUCT_EVAL_RC=78`, report `/srv/sable-build/evidence/titan2/pr347-product-graph-20261023T015938Z/PRODUCT_EVALUATED.json`, status **`HOLD_DUMPVAR_UNEXPECTED_TOKEN`**; evaluated `product_selection` was not emitted. **Do not infer a package absent or present from the parser HOLD**.

## Inspection-tool issue

`product_graph.py` V1 redirects both stdout and stderr into the same log, then validates every word with regex `[A-Za-z0-9_.+/@:-]+` as a package name. A build warning or other diagnostic may cause an unexpected token even when `soong_ui.bash` exits 0. **The actual 29,843-byte log has not been uploaded**, so the specific rejected token and log structure are not yet known; parsing noise is a plausible diagnosis, not a confirmed complete explanation.

## New V1.1 sealed evidence-recovery operator

`TB2_PR347_PRODUCT_GRAPH_V1_1_LOG_RECOVERY.zip`: **12,340 bytes**, SHA256 **`a79aac3a5e647fdd3d16f52566eccef84da5bb2f61dd623ff490a1267a31a462`**; 7 ZIP entries, ZIP CRC PASS, 6 member SHA256SUMS PASS. Python AST PASS_2, Bash syntax PASS, **36/36** hermetic tests PASS, and **36/36** independently extracted regressions PASS (0.210s). Tests include exact command/target/RC0/pinned-log requirements, user-controlled symlink/hardlink/overwrite rejects, bounded unknown-line excerpts, malformed shell-looking tokens, multi-payload, log tamper, large token parse and 32 MiB SHA throughput. Test runs are author-host only.

**The tool never starts Soong again.** It reads the *existing* V1 JSON and its referenced SHA-pinned combined log and attempts a conservative offline recovery: exactly one 10+-token whitespace-delimited package-list line, no unrecognized lines, only narrowly recognized nonfatal diagnostic lines, no error text, and both SableLauncher and Quickstep present. If anything is ambiguous, it reports HOLD and bounded diagnostics, **not** fabricated selected package membership.

### Exact AI-G732 commands (no new AOSP evaluation)

```bash
cd ~/Downloads
unzip -q TB2_PR347_PRODUCT_GRAPH_V1_1_LOG_RECOVERY.zip
cd TB2_PR347_PRODUCT_GRAPH_V1_1_LOG_RECOVERY
sha256sum -c SHA256SUMS.txt
bash operator.sh test
EVIDENCE=/srv/sable-build/evidence/titan2/pr347-product-graph-20261023T015938Z
bash operator.sh replay --prior "$EVIDENCE/PRODUCT_EVALUATED.json" --out "$EVIDENCE/PRODUCT_EVALUATED_REPLAY_V1_1.json"
RC=$?
echo "PR347_PRODUCT_LOG_REPLAY_RC=$RC"
if [[ -f "$EVIDENCE/PRODUCT_EVALUATED_REPLAY_V1_1.json" ]]; then
  cat "$EVIDENCE/PRODUCT_EVALUATED_REPLAY_V1_1.json"
fi
```

### Interpretation

- `PASS_RECOVERED_EVALUATED_SOURCE_PACKAGE_VARIABLE_NO_IMAGE`: **source-config variable selection only**, from one SHA-pinned original RC0 run; no image or role closure.
- `HOLD_EVALUATED_CORE_MODULES_MISSING`: only if one unambiguous candidate line genuinely lacks a core name; still not installed-image proof.
- `HOLD_DUMPVAR_LOG_NOT_UNAMBIGUOUS` or another HOLD: supply bounded JSON and original 29.8KB log for inspection; do not blindly rerun, alter makefiles, or bypass readiness.

## Guardrails and remaining gates

No source mutation, full build, canonical out write, network, adb/device, role change, flash, or new isolated Soong directory. No readiness JSON status changes. PR347 `build/titan2/nextbuild/check-ready.py --require-ready` still blocks full image compilation with **22 applicable Q25 rows + eight named IMS/SMS/product prerequisites OPEN**. IMS effective single provider/G1/G2/G3, hard-restricted SMS default role and installer allowlist, actual installed package graph, factory HOME role, Quickstep/Recents and private-profile runtime all remain HOLD.