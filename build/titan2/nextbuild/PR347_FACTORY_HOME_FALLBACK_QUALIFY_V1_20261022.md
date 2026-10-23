# PR347 — Factory HOME fallback and packaged priority qualification V1

Date: 2026-10-22. Branch: `titan2/nextbuild-q25-app-conformance-20261021`. Scoped architecture: `docs/adr/0013-titan2-track-b-standalone-home-quickstep-fallback.md`.

## Previous AI-G732 result (already qualified; not repeated)

- `TB2_PR347_HOME_PRODUCT_RUNTIME_ADMISSION_V1` passed 31/31 hermetic tests in 0.112 sec, and real `PASS_PINNED_DUAL_MODULE_STAGING_RELEASE_HOLD` at `/srv/sable-build/evidence/titan2/pr347-home-admission-20261023T002717Z/HOME_PRODUCT_ADMISSION.json`.
- SableLauncher: current `system/app/SableLauncher/SableLauncher.apk`, 5,177,311 bytes, SHA256 `f331848ca742aae888233edb8fa6dcbc9c0c1fed80f35f8f46d2d7d07564126e`.
- Quickstep: current `system/system_ext/priv-app/Launcher3QuickStep/Launcher3QuickStep.apk`, 17,422,140 bytes, SHA256 `580f795e1e4830014a9d691a4c790b36fe2cc3f097d5d5d9f7eebea48536e2e7`.
- Effective selected inherited product and factory HOME RoleManager owner remain HOLD. User's `DEVICE_PLAN.json` was generated read-only; no device contacted.

## Next host-only qualification package

`TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1.zip`, 19,836 bytes, SHA256 `817f580cbc67725d490d3aeb41f902f5e1f204f5e4a27a9e5501ff58b5a5441f`, 9 ZIP members, CRC PASS, 8 exact member SHA256SUMS PASS. Python AST/py_compile and Bash syntax PASS. Hermetic tests 23/23 PASS, independently extracted 23/23 PASS (0.051 sec). Real AI-G732 selected source inspection has NOT been performed.

Public upstream Android16 PermissionController roles.xml defines HOME using `HomeRoleBehavior` and no `defaultHolders` resource. Upstream `HomeRoleBehavior.getFallbackHolder()` chooses a unique top-priority eligible launcher and nulls ties; these upstream facts must be checked against the selected AI-G732 source before attribution.

The new operator checks the exact selected `packages/modules/Permission/PermissionController/res/xml/roles.xml` and `HomeRoleBehavior.java`, then verifies full packaged binary manifests of *both PINNED APKs* with current `aapt2 dump xmltree`. It reads the exported exact HOME filter and `android:priority`, compares only SableLauncher vs Quickstep, and writes an external create-only JSON.

`PASS_DUAL_APK_HOME_FALLBACK_SOURCE_CANDIDATE_RUNTIME_HOLD` means only that the selected role SOURCE fallback method and the TWO pinned APKs' priority ordering are compatible with SableLauncher winning that fallback. It is not a selected factory role, not proof of a unique winner among other installed launchers, and does not establish a compiled PermissionController, product graph, user state, role migration, resource overlay or Recents runtime. Unknown/drift returns HOLD.

## AI-G732 commands

```bash
cd ~/Downloads
unzip -q TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1.zip
cd TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-factory-home-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
bash operator.sh inspect --android "$ANDROID" --out "$EVIDENCE/FACTORY_HOME_FALLBACK.json"
RC=$?
echo "FACTORY_HOME_OPERATOR_RC=$RC"
test ! -f "$EVIDENCE/FACTORY_HOME_FALLBACK.json" || cat "$EVIDENCE/FACTORY_HOME_FALLBACK.json"
```

## Unchanged guardrails

No source mutation, rebuild, permissions change, RoleManager write, reboot, device contact, flash, full image or bypass of `build/titan2/nextbuild/check-ready.py --require-ready`. PR347 remains DRAFT. The 22 Q25 applicable rows, SMS/default role, IMS G1–G3, final image/privapp grants, effective RRO and factory HOME holder/gesture and keyboard runtime all remain HOLD.

If selected role source and APK rank PASS, qualify the real factory role on an authorized finished image rather than add a boot-time role setter. If they HOLD, review the actual drift before proposing a scoped code patch.