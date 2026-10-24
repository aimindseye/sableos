# PR347 — real AI-G732 V1 fallback HOLD; V1.1 PermissionController source-layout correction

Date: 2026-10-22 local / October 23 UTC. Track B exception authority: `docs/adr/0013-titan2-track-b-standalone-home-quickstep-fallback.md`. PR347 remains **draft**.

## Real result (not a hypothetical test)

`TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1` was run on AI-G732:
- All package SHA member checks PASS; **23/23** local tests PASS (0.027sec).
- Actual `factory_home` source gate **HOLD**, RC=78, report `/srv/sable-build/evidence/titan2/pr347-factory-home-20261023T003913Z/FACTORY_HOME_FALLBACK.json`.
- `roles.xml`: `android.app.role.HOME` exclusive=`true`, `behavior=HomeRoleBehavior`, no default holders attribute; `PASS_HOME_ROLE_FALLBACK_POLICY_SOURCE`.
- Actual pinned packaged `org.sableos.launcher` exported `SableStartActivity` priority **10** (5,177,311 bytes, SHA256 `f331848ca742aae888233edb8fa6dcbc9c0c1fed80f35f8f46d2d7d07564126e`).
- Actual pinned packaged `com.android.launcher3` exported `QuickstepLauncher` priority **0** (17,422,140 bytes, SHA256 `580f795e1e4830014a9d691a4c790b36fe2cc3f097d5d5d9f7eebea48536e2e7`).
- `fallback_rank.unique_higher_sable=true`, but `home_behavior=NOT_EVALUATED`, **only diagnostic** `HOME_BEHAVIOR_MISSING_OR_AMBIGUOUS`, source report `HOLD_FACTORY_HOME_SOURCE_OR_PACKAGED_PRIORITY`. The composite status does **not** mean either APK priority failed.

## Defect in V1 inspection tool, not demonstrated product-code defect

V1 searched two outdated `PermissionController/src/com/android/permissioncontroller/role/model/` behavior paths and parsed **only** `getFallbackHolder(...)`. AOSP's newer `PermissionController/role-controller/java/com/android/role/controller/behavior/HomeRoleBehavior.java` and multi-user `getFallbackHolderAsUser(...)` were excluded. AOSP public commit `cc07e927a8e2d3074901d4f8c45575f92a7e6821` shows this path and method, whose implementation queries user-visible eligible HOME activities, ranks `ResolveInfo.priority`, nulls ties, and ignores the Settings fallback. Exact AI-G732 checkout source was not available to the author host; the V1 false HOLD is **strongly indicated, not independently established** until V1.1 observes it.

## V1.1 sealed replacement

Archive: `TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1_1.zip`, **23,479 bytes**, SHA256 `43322ec71a59751b9682bad671b0b8920d007b63b4a562062e4a332b1a50ac71`, 10 members. V1.1 keeps APK hash/bytes/manifest role XML logic unchanged; fixes `factory_home.py`/`tests/test_factory_home.py` only and ships `SOURCE_DIFF_V1_TO_V1_1.patch`.

Guards: fixed three safe source candidates (not recursive walk), zero/multiple candidates HOLD; modern `getFallbackHolderAsUser` must show `UserUtils.getUserContext(context,user)`, user-scoped PackageManager, priority comparison, tie-null, Settings exception and return; source anchors drifting still HOLD with capped method excerpt. Outputs write new JSON outside Android only; no Soong, role assignment, ADB, image or flash.

Assistant-host validation: Python AST PASS_3; Bash syntax PASS; **30/30** hermetic tests PASS (also after independent ZIP extraction, 0.059 sec), full 9 file SHA256SUMS PASS, ZIP CRC PASS_10, V1-to-V1.1 patch replay PASS_2. AI-G732 **not run** with V1.1 yet.

### Exact owner command

```bash
cd ~/Downloads
unzip -q TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1_1.zip
cd TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1_1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-factory-home-v1-1-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
bash operator.sh inspect --android "$ANDROID" --out "$EVIDENCE/FACTORY_HOME_FALLBACK_V1_1.json"
RC=$?
echo "FACTORY_HOME_V1_1_OPERATOR_RC=$RC"
test ! -f "$EVIDENCE/FACTORY_HOME_FALLBACK_V1_1.json" || cat "$EVIDENCE/FACTORY_HOME_FALLBACK_V1_1.json"
```

## Remaining nonwaivable boundaries

A source-level V1.1 PASS is only a compatible HOME fallback **among two inspected packaged APKs** and one selected source implementation. It cannot prove effective unique eligible app among all installed candidates, factory role assignment, preserved-data user choice, evaluated product module graph, compiled PermissionController or framework RRO, Quickstep binder/Recents runtime, Q25 22 rows, hard-restricted SMS, IMS G1–G3, privilege/security, final image, device, signing/AVB or flash. `build/titan2/nextbuild/check-ready.py --require-ready` still HOLD. PR347 stays DRAFT; PR346 frozen.