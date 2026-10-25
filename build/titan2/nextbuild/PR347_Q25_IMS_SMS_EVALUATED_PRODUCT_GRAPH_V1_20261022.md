# PR347 — Q25, IMS, SMS and evaluated selected product-graph admission V1

Date: October 22 2026 local / October 23 UTC. Target branch: `titan2/nextbuild-q25-app-conformance-20261021` (PR347 DRAFT). Scope: Track B ADR-0013 standalone SableLauncher HOME + Launcher3QuickStep Recents fallback, not global Panther/Track A. Source and prior chat receipts reconciled before starting new work.

## Prior qualified evidence reused rather than rebuilt

- On AI-G732 the two compiled/staged exact-current APKs are `SableLauncher.apk` (system/app, 5,177,311 bytes, SHA256 `f331848ca742aae888233edb8fa6dcbc9c0c1fed80f35f8f46d2d7d07564126e`) and `Launcher3QuickStep.apk` (system/system_ext/priv-app, 17,422,140 bytes, SHA256 `580f795e1e4830014a9d691a4c790b36fe2cc3f097d5d5d9f7eebea48536e2e7`). Module/packaged HOME/Recents source PASS; not installed-image evidence.
- Factory HOME fallback V1.1 on AI-G732 PASS (`FACTORY_HOME_V1_1_OPERATOR_RC=0`, 30/30 regressions): selected `HomeRoleBehavior.getFallbackHolderAsUser`, SableLauncher binary HOME priority 10, Quickstep priority 0, **among only these two eligible sources**. Actual default HOME, other installed launchers, setup/role and user choices unproven.
- Earlier PR347 source handoffs already cover `PR347_SELECTED_OWNER_SECURITY_SMS_IMS_BINDING_V1`, `PR347_CONSOLIDATED_Q25_HANDOFF_V1`, `PR347_Q25_NATIVE_27_TRIAGE_ADMISSION_V2`, `PR347_LAUNCHER_PRODUCT_FALLBACK_V1`, and `PR347_HOME_PRODUCT_RUNTIME_ADMISSION_V1`. Do NOT reimport Q25 patches or recompile these launcher binaries.
- The current `build/titan2/nextbuild/Q25_SOURCE_READINESS.json` blob `90e5e5818d92af68de9aae521e972822ee16004f` has 23 Q25 IDs, 22 applicable OPEN, one N/A; eight exact requirements OPEN. `check-ready.py --require-ready` intentionally prevents a new full AOSP image build. This deliverable leaves it unchanged.

## New deliverable — evaluated product source selection, not a new image

`TB2_PR347_Q25_IMS_SMS_PRODUCT_GRAPH_V1.zip`, 16,626 bytes, SHA256 **`ac49a4cd7b30bc902984948dee2a4c8400bc9fd7db19642974e91605e18945d7`**; eight members incl. SHA256SUMS, ZIP CRC PASS; seven member hashes PASS; Bash syntax/Python AST PASS; **34/34** hermetic tests PASS and **34/34** independently extracted tests PASS (1.230s) including 32 MiB streaming hash, isolated mock Soong build-product dump, invalid environment, absent module, tool failure and timeout.

Package includes `product_graph.py`, `operator.sh`, `tests/test_product_graph.py`, `RELEASE_GATE_MATRIX.md`, `ENGINEERING_REVIEW.md`, `README.md`, `VALIDATION_LOG.txt`, `SHA256SUMS.txt`.

`inspect` mode is read-only except explicit external create-only JSON. It hashes current staged APKs; reads three capped source owner Makefiles (`device/phh/treble/rom.mk`, `vendor/sable/trackb13ims/track-b.mk`, `build/make/target/product/handheld_system_ext.mk`); captures lexical IMS/SMS/package selection cues; detects any installed-files manifest candidate WITHOUT treating it as sealed installed image; supplies all 22+8 open IDs as a pinned GitHub snapshot. A PASS at this step means report emitted, **not** all staged pins passed; examine `snapshot.modules.*.status`.

`evaluate` mode is explicitly opt-in. It calls exact Android source config program **`bash build/soong/soong_ui.bash --dumpvar-mode PRODUCT_PACKAGES`**, with `TARGET_PRODUCT=treble_arm64_bvN`, `TARGET_RELEASE=bp4a`, `TARGET_BUILD_VARIANT=userdebug`, **fresh external `OUT_DIR` under the evidence directory**, not canonical `android/out`. Uses an explicit ACK, single subprocess/isolated scratch, 180s default timeout (max 300s), create-only JSON, external log SHA256, 4 MiB dumpvar bound. Evaluation is a *configuration invocation* and **may write external intermediates**, so not fully filesystem-read-only. It does not invoke a full AOSP/target-files/image build and never contacts/flashes hardware.

`PASS_EVALUATED_PACKAGE_VARIABLE_SOURCE_ONLY_NO_IMAGE` requires both module identifiers returned by actual evaluated `PRODUCT_PACKAGES`. Provider-related `PhhIms`, `Iwlan`, SMS/Messaging module names are separately listed as **candidates**. These cannot prove a single effectively installed provider, G1/G2/G3 classloader/ABI/vendor IPC, a valid per-user SMS role/READ_SMS allowlist, privileged grants, installed APK hashes, compiled framework resources, or runtime.

## Exact AI-G732 operator commands

```bash
cd ~/Downloads
unzip -q TB2_PR347_Q25_IMS_SMS_PRODUCT_GRAPH_V1.zip
cd TB2_PR347_Q25_IMS_SMS_PRODUCT_GRAPH_V1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-product-graph-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
bash operator.sh inspect --android "$ANDROID" --out "$EVIDENCE/PRODUCT_PREFLIGHT.json"
cat "$EVIDENCE/PRODUCT_PREFLIGHT.json"
# Optional, once preflight is reviewed; may use CPU and write scratch only under external EVIDENCE.
PR347_PRODUCT_GRAPH_ACK=ISOLATED_DUMPVAR_NO_IMAGE bash operator.sh evaluate --android "$ANDROID" --out "$EVIDENCE/PRODUCT_EVALUATED.json" --timeout 180
RC=$?
echo "PR347_PRODUCT_EVAL_RC=$RC"
test ! -f "$EVIDENCE/PRODUCT_EVALUATED.json" || cat "$EVIDENCE/PRODUCT_EVALUATED.json"
```

## Hand-off of 22 + 8 genuine blockers

`RELEASE_GATE_MATRIX.md` in the ZIP maps all eight exact requirement IDs to concrete source/image/device acceptance evidence and groups the 22 active Q25 rows into four owned source workstreams. The high-value near-term sequence is: (1) evaluate selected source `PRODUCT_PACKAGES`, (2) if both HOME modules are present, bind a **named actual PhhIms/Iwlan candidate and SMS client owner** without inferring roles, (3) collect a qualified final image installed-files/package/signer/privapp graph once the source readiness gate permits a build, (4) do separately authorized device HOME/Recents/IMS/SMS/privacy acceptance.

If the evaluated graph is missing SableLauncher/Quickstep, HOLD and propose a **reviewed exact Track B source-only patch** for selected inheritance; do not change PR346 or invent a bypass. If the dumpvar cannot run in the isolated output, HOLD with external log; avoid repeating indefinite source scans.

## Safety and release status

No edits in AOSP source, APKs, canonical `out`, readiness JSON, default HOME/SMS role or installed device. No `repo sync`, full image, ADB, reboot, flash or user choice reset. The optional product-config command may consume resources/write to the explicit external scratch and is protected by an operator ACK and timeout. PR347 DRAFT; PR346 frozen; Q25, SMS, IMS G1–G3, image, device and final release remain HOLD. **The AI-G732 product evaluation is not yet run; only synthetic mock tests passed on author host.**