# PR347 — ADR-0013 HOME/product/runtime admission V1 handoff (2026-10-22)

**User-approved Track B HOME architecture:** standalone `org.sableos.launcher` `SableStartActivity` as intended factory HOME with `com.android.launcher3` Quickstep retained for Recents/Overview; see `docs/adr/0013-titan2-track-b-standalone-home-quickstep-fallback.md`. This is *not* a completed factory-default implementation, final image or runtime result.

## Existing evidence reused without rebuilding

The owner's actual selected Track B output `/srv/sable-build/workspaces/titan2-track-b/android/out/target/product/tdgsi_arm64_ab`:
- `system/app/SableLauncher/SableLauncher.apk`, **5,177,311 bytes**, SHA256 `f331848ca742aae888233edb8fa6dcbc9c0c1fed80f35f8f46d2d7d07564126e`.
- `system/system_ext/priv-app/Launcher3QuickStep/Launcher3QuickStep.apk`, **17,422,140 bytes**, SHA256 `580f795e1e4830014a9d691a4c790b36fe2cc3f097d5d5d9f7eebea48536e2e7`.
- Actual owner receipts: `/srv/sable-build/evidence/titan2/pr347-quickstep-v1-1-20261022T230353Z/BUILD_RESULT.json`, `/srv/sable-build/evidence/titan2/pr347-dual-home-aapt2-20261022T231617Z/DUAL_HOME_STATIC.json`, `/srv/sable-build/evidence/titan2/pr347-recents-binding-20261022T235654Z/RECENTS_BINDING_SOURCE.json`. All three describe source/module-level or packaged-manifest evidence; no complete installed image.

## Next deliverable to run on AI-G732

**`TB2_PR347_HOME_PRODUCT_RUNTIME_ADMISSION_V1.zip`**, SHA256 **`62b101ee18a836ef1f1f069e2fda43e2df528c534b80417ab3b80de4b912cb69`**, 20,223 bytes; 9 ZIP members. Independent archive SHA manifest PASS (8 files), ZIP CRC PASS (9), Python AST/py_compile PASS, `bash -n operator.sh` PASS, **31/31 regressions PASS** (0.156s on author host); independently extracted 31/31 PASS, including 32MiB streamed SHA, ZIP CRC tamper, path/symlink/hardlink rejects, no overwrite, factory HOME roles and offline runtime evidence HOLD.

**Mode 1: current host admission** (no `m`, no ADB):
```bash
cd ~/Downloads
unzip -q TB2_PR347_HOME_PRODUCT_RUNTIME_ADMISSION_V1.zip
cd TB2_PR347_HOME_PRODUCT_RUNTIME_ADMISSION_V1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-home-admission-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
bash operator.sh host \
  --android "$ANDROID" \
  --quickstep-build /srv/sable-build/evidence/titan2/pr347-quickstep-v1-1-20261022T230353Z/BUILD_RESULT.json \
  --dual-home /srv/sable-build/evidence/titan2/pr347-dual-home-aapt2-20261022T231617Z/DUAL_HOME_STATIC.json \
  --recents-source /srv/sable-build/evidence/titan2/pr347-recents-binding-20261022T235654Z/RECENTS_BINDING_SOURCE.json \
  --out "$EVIDENCE/HOME_PRODUCT_ADMISSION.json"
RC=$?
echo "HOME_PRODUCT_ADMISSION_RC=$RC"
test ! -f "$EVIDENCE/HOME_PRODUCT_ADMISSION.json" || cat "$EVIDENCE/HOME_PRODUCT_ADMISSION.json"
```

Host gate checks exact APK bytes and SHA256, ZIP integrity and DEX+manifest, all three actual receipts/IDs, current source reference makefiles, no output inside Android; emits create-only JSON with **source/installed/runtime HOLD labels**. Does **not** assert effective package inheritance, signer/privapp grants, first-boot role, completed image or runtime.

**Mode 2: factory HOME role observation**: `bash operator.sh device-plan --out "$EVIDENCE/DEVICE_PLAN.json"` produces *future read-only commands* without invoking adb. `factory-policy --observation <real observed HOME role JSON> --out <fresh JSON>` distinguishes fresh-user `org.sableos.launcher` role holder from existing user-selected other HOME, which must be preserved. It never writes HOME roles. Missing role owner/consent provenance remains HOLD. The selected first-boot owner and RoleController mechanism must be identified before applying any factory-default source policy change; adding an unconditional `pm set-home-activity`, `cmd role` setter or boot receiver is disallowed. **An APK priority is not role selection.**

**Mode 3: runtime-review**: offline `runtime-review --evidence <qualified image and authorized manual test JSON> --out <fresh JSON>`. Full 14 checks in `RUNTIME_ACCEPTANCE.md`: actual fresh HOME holder, after process restart/reboot, user choice, Quickstep TIS binding, Overview show/hide/toggle, gesture abort/commit, Alt-Tab/keyboard, locked profiles/privacy, effective framework resources, installed packages and privileged grants, image provenance. This mode **does not contact device**; even a complete user-attested PASS requires independent review and does not close SMS/IMS/release.

## Current release and source scope

Factory HOME *policy choice* is approved by ADR-0013, **effective factory role selection and actual selected first-boot implementation remain HOLD**. Read-only source references for both apps are not evaluated product inheritance. The 22 applicable Q25 rows, IMS G1/G2/G3, hard-restricted SMS role, selected installed product, signing/AVB, device and flash are independent HOLDS. `build/titan2/nextbuild/check-ready.py --require-ready` must not be bypassed, PR347 stays **DRAFT**, PR346 frozen. The ZIP has been validated on assistant host only; AI-G732 operator not yet run. No source/image/device changes made by the ZIP.
