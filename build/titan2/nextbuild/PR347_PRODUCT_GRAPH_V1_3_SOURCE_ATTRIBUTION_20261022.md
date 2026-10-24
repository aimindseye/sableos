# PR347 — actual AI-G732 product-variable contamination and source attribution V1.3

Date: 2026-10-22 local (2026-10-23 UTC). PR347 draft Track B branch `titan2/nextbuild-q25-app-conformance-20261021`, ADR-0013 standalone SableLauncher/Quickstep exception. PR346 frozen.

## Actual owner execution (V1.2)

The owner ran `TB2_PR347_PRODUCT_GRAPH_V1_2_CONTAMINATION_FORENSICS` against the exact existing SHA-pinned V1 dumpvar log and V1.1 replay. **33/33 host Python tests PASS** (0.022s); real `PR347_PRODUCT_FORENSICS_RC=78`, intentionally `HOLD_PRODUCT_PACKAGES_EVALUATION_FORENSICS`. Receipt: `/srv/sable-build/evidence/titan2/pr347-product-graph-20261023T015938Z/PRODUCT_CONTAMINATION_FORENSICS_V1_2.json`. V1 original Soong dumpvar subprocess **RC0**, not source variable PASS; four-line combined output is **29,843 bytes** SHA256 `1dffa094530dacc25ed53b3549783a94dbe9660c7abcc2456ae8e0f4f64c64a7`, 1,256 raw tokens, each unique.

- Raw **position 1**: literal `+=`, tagged `ASSIGNMENT_OPERATOR_LITERAL`. Raw **position 449**: `device/generic/common/overlays/overlay-config.xml:||SYSTEM_EXT-PATH-PH||/overlay/config/config.xml`, tagged `UNEXPANDED_PATH_PLACEHOLDER`.
- Raw token sightings only: `SableLauncher=true`, `Launcher3QuickStep=true`; `PhhIms`, `PhhImsOverlay`, `Iwlan`, `ImsServiceEntitlement`, `Messaging`, `mtk-sms-fwk-ready`. **None qualifies evaluated installed-product, effective IMS provider, G1/G2/G3, SMS default role or image.**
- Three diagnostic lines: timestamped `Build sandboxing disabled due to nsjail error`, two `mkdir: '/system': Permission denied`. These are actual log observations, but not necessarily fatal to the dumpvar subprocess.
- Source hints with **selected actual SHA hashes**: `device/phh/treble/rom.mk` sha256 `a5b2f39741018eb7094a68812ce0b03fa080c07f1b2c036ca06c0ab286be1522` contains `$(shell mkdir -p $(PRODUCT_OUT)/system/product/fonts)` at line 5 (plausible Make-evaluation-time cause of `/system` errors when PRODUCT_OUT empty); `vendor/sable/trackb13ims/track-b.mk` `4146c78c7f4963a971117bb25003b62a294b550beff93eb124742b3fd0f1d97b` filters a telephony RRO, adds PhhIms/overlay/Iwlan and system privapp allowlist; `build/make/target/product/handheld_system_ext.mk` sha256 `9e548dc57becae4dddea2ef93a6a063adcb284c8` contains Quickstep. These are **lexical hints, not proven variable-construction root causes**.
- Public AOSP `build/make/core/envsetup.mk` deliberately defines `_system_ext_path_placeholder := ||SYSTEM_EXT-PATH-PH||` as an intermediate value *before partition-path substitution*. Placeholder existence is not inherently a source defect; its presence in the raw dumped `PRODUCT_PACKAGES` line calls for exact source attribution. `PRODUCT_PACKAGES` is specified as names of modules to install, while copy mappings belong in `PRODUCT_COPY_FILES`. The owner log itself does **not** prove the producing Makefile.

## Next V1.3 deliverable — hash-linked source attribution without rerun or mutation

`TB2_PR347_PRODUCT_GRAPH_V1_3_SOURCE_ATTRIBUTION.zip`, **24,639 bytes**, exact SHA256 **`ebe71e60142374595435fedbc19a9a9f15af4e7851f686bc1618e0498ccb9d69`**. ZIP contains ten entries; CRC **PASS_10**; nine SHA256 manifest member checks **PASS_9**. `attribution.py` plus byte-for-byte reused V1.1 `recover_graph.py` and V1.2 `forensics.py`; Bash/Python syntax PASS; full **52/52 hermetic tests PASS** (0.301s author host; 52/52 after independent extraction 0.481s). 1,200 synthetic source files and ~99,992 synthetic tokens bounded within test thresholds; subprocess full test wall 1.18s (not AI-G732 timing).

`operator.sh trace` reads exact previous V1 original JSON/log SHA, replay V1.1 and forensics V1.2 SHA chain; re-derives exact token positions and neighboring values, checks three pinned selected Makefile SHA256s, inspects AOSP's chosen `core/envsetup.mk` placeholder definition, and performs a bounded lexical scan for relevant Makefile assignments/copy paths under exactly four source roots. Hard caps: 12k directory entries, 2.5k Makefiles, depth 8, <=256 KiB per source file, <=12MiB aggregate source and <=128 bounded matches. Skips symlinks and unsafe sources. Generates **create-only external JSON**, status **`HOLD_PRODUCT_GRAPH_SOURCE_ATTRIBUTION_NOT_PROVEN`**, exit **78 by design**. Neither raw token presence nor source grep gets promoted to PASS.

### AI-G732 next command

```bash
cd ~/Downloads
unzip -q TB2_PR347_PRODUCT_GRAPH_V1_3_SOURCE_ATTRIBUTION.zip
cd TB2_PR347_PRODUCT_GRAPH_V1_3_SOURCE_ATTRIBUTION
sha256sum -c SHA256SUMS.txt
bash operator.sh test
EVIDENCE=/srv/sable-build/evidence/titan2/pr347-product-graph-20261023T015938Z
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
RC=0
bash operator.sh trace --prior "$EVIDENCE/PRODUCT_EVALUATED.json" \
 --replay "$EVIDENCE/PRODUCT_EVALUATED_REPLAY_V1_1.json" \
 --forensic "$EVIDENCE/PRODUCT_CONTAMINATION_FORENSICS_V1_2.json" \
 --android "$ANDROID" --out "$EVIDENCE/PRODUCT_SOURCE_ATTRIBUTION_V1_3.json" || RC=$?
echo "PR347_SOURCE_ATTRIBUTION_RC=$RC"
cat "$EVIDENCE/PRODUCT_SOURCE_ATTRIBUTION_V1_3.json"
```

Submit both the V1.3 JSON **and the original** `PRODUCT_EVALUATED_dumpvar.log` (29.8KB) for direct verification of the exact Make construction before a reviewed byte-pinned source-only patch. **No sudo mkdir /system, no blind placeholder stripping, no Soong rerun or readiness override.** Running V1.3 on selected AI-G732 source not yet done.

## Still HOLD

Product variable contamination and evaluated membership; final installed system/privapp/IMS provider and SMS role, G1–G3, Q25 22 applicable rows, factory HOME runtime, Quickstep/Recents/keyboard/profile security, signed/AVB image, device and flash. Current `build/titan2/nextbuild/check-ready.py --require-ready` remains fail-closed for the **22 Q25 rows and 8 requirements**. PR347 draft; PR346 frozen; no source, binary, product output or device changes.