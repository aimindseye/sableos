# PR347 — product graph V1.1 actual four-line HOLD and V1.2 no-rerun contamination forensics

Date: October 22 2026 local / October 23 UTC. Track B only under ADR-0013, PR347 draft; PR346 frozen.

## Actual AI-G732 evidence

Owner ran `TB2_PR347_PRODUCT_GRAPH_V1_1_LOG_RECOVERY` on AI-G732, independently validated package SHA members and passed **36/36 tests (0.095s)**. Actual replay returned **RC78**, status `HOLD_DUMPVAR_LOG_NOT_UNAMBIGUOUS`, path `/srv/sable-build/evidence/titan2/pr347-product-graph-20261023T015938Z/PRODUCT_EVALUATED_REPLAY_V1_1.json`. The prior isolated `soong_ui.bash --dumpvar-mode PRODUCT_PACKAGES` **subprocess RC0**, 7.285 seconds, log 29,843 bytes exact SHA256 `1dffa094530dacc25ed53b3549783a94dbe9660c7abcc2456ae8e0f4f64c64a7`; V1 parser RC78.

The V1.1 replay verified the original hash and indicated **exactly four lines**, none accepted by its strict shape rules:

1. `21:59:54 Build sandboxing disabled due to nsjail error.`
2. `mkdir: '/system': Permission denied`
3. `mkdir: '/system': Permission denied`
4. One long payload beginning `+= AccessibilityMenu AndroidClock.ttf AppStore ...` (the original full 29.8KB log was **not** uploaded). Invalid token samples: `+=` and `device/generic/common/overlays/overlay-config.xml:||SYSTEM_EXT-PATH-PH||/overlay`.

These are **not merely harmless parser punctuation**. `PRODUCT_PACKAGES` is a Make list of module names; the literal assignment operator and placeholder/copy-like string may reflect bad or contaminated product variable expansion. The failed host `/system` mkdir operations are also real diagnostic outputs that require provenance; do **not** mkdir `/system` or use sudo to make this disappear. The log was captured with stdout and stderr merged, so the source stream of each line cannot be reconstructed from that file alone. The successful process exit does not prove the variable is usable or that the final image contains any package.

Relevant public AOSP: `build/soong/cmd/soong_ui/main.go` describes `--dumpvar-mode` as printing a Make variable to stdout; `build/soong/ui/build/sandbox_linux.go` emits the known nsjail fallback message; `source.android.com/docs/setup/create/new-device` defines `PRODUCT_PACKAGES` as modules to install. These contextual facts are not a substitute for inspecting the actual AI-G732 29.8KB original.

## Deliverable V1.2 — offline forensic gate, never PASS product qualification

`TB2_PR347_PRODUCT_GRAPH_V1_2_CONTAMINATION_FORENSICS.zip`, 16,354 bytes, SHA256 **`e122322f59783b08b7b4a86cd1b26062884ef810258d04398ab660b5ad873763`**. Contains eight ZIP entries including SHA256SUMS (seven member hashes). ZIP CRC PASS, all seven members SHA PASS, Python AST PASS_3, Bash syntax PASS, **33/33 Python regression tests PASS** (also **33/33 after independent extraction**, 0.051s). Test cases include four-line fixture, `+=` and `||` classification, exact core token observations but not promotion, unsafe/symlink/hardlink/overwrite and changed-hash rejection, 100,005-token cap, no subprocess and bounded source hints. Validated on author host; **not run on AI-G732**.

The tool reuses the exact V1.1 `recover_graph.py` prior-command/RC0/report/log hash safety chain, optionally binds the V1.1 replay JSON to the same original, reads full SHA-pinned log once, and emits a **create-only external JSON**. Reports: raw exact `SableLauncher`/`Launcher3QuickStep` token presence (`potential_core_tokens` explicitly **not evaluated membership**), IMS/SMS name candidates only, literal operators, unexpanded placeholder/copy-like tokens, sandbox and mkdir diagnostics, and up to seven exact safe Makefile source references (no recursive search). All final qualification status values HOLD; exit code always 78.

### AI-G732 commands

```bash
cd ~/Downloads
unzip -q TB2_PR347_PRODUCT_GRAPH_V1_2_CONTAMINATION_FORENSICS.zip
cd TB2_PR347_PRODUCT_GRAPH_V1_2_CONTAMINATION_FORENSICS
sha256sum -c SHA256SUMS.txt
bash operator.sh test
EVIDENCE=/srv/sable-build/evidence/titan2/pr347-product-graph-20261023T015938Z
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
RC=0
bash operator.sh audit \
  --prior "$EVIDENCE/PRODUCT_EVALUATED.json" \
  --replay "$EVIDENCE/PRODUCT_EVALUATED_REPLAY_V1_1.json" \
  --android "$ANDROID" \
  --out "$EVIDENCE/PRODUCT_CONTAMINATION_FORENSICS_V1_2.json" || RC=$?
echo "PR347_PRODUCT_FORENSICS_RC=$RC"
cat "$EVIDENCE/PRODUCT_CONTAMINATION_FORENSICS_V1_2.json"
```

**Expected RC78 is intentional**. If references do not attribute the malformed value, attach original `PRODUCT_EVALUATED_dumpvar.log` and new JSON; then trace the actual selected Make expansion and shell side effect with pinned source before reviewing any source-only fix. Do not rerun Soong first, broadly modify overlays, or bypass source readiness.

## Unchanged release boundaries

PR347 `check-ready.py --require-ready` remains fail closed: 22 applicable Q25 rows and eight IMS/SMS/product/role prerequisites OPEN. Both known current launcher APKs remain only staged; factory HOME and selected Recents source fallback PASS in their previously limited scopes. Evaluated package graph, full installed image, effective single IMS provider, G1/G2/G3, hard-restricted SMS role, signing/AVB, privileged grants, actual HOME/Recents/profile runtime and flash remain HOLD. No device contact, source/build/output modification or role mutation from this operator.