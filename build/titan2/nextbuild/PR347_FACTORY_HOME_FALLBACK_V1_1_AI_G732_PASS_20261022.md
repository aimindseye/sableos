# PR347 — AI-G732 selected Android16 factory HOME fallback V1.1 PASS (two-APK scope)

Date: 2026-10-22 local / 2026-10-23 UTC.
PR: [347](https://github.com/aimindseye/sableos/pull/347), branch `titan2/nextbuild-q25-app-conformance-20261021`.
Track B architecture decision: [ADR-0013](../../../../docs/adr/0013-titan2-track-b-standalone-home-quickstep-fallback.md). PR347 remains **DRAFT**.

## Actual owner execution and result

The owner ran `TB2_PR347_FACTORY_HOME_FALLBACK_QUALIFY_V1_1` against the selected Android16 workspace `/srv/sable-build/workspaces/titan2-track-b/android`, verified all nine package SHA256 manifest entries, and passed **30/30 Python tests in 0.033 seconds**.

Actual operator result: **`FACTORY_HOME_V1_1_OPERATOR_RC=0`**, status **`PASS_DUAL_APK_HOME_FALLBACK_SOURCE_CANDIDATE_RUNTIME_HOLD`**, factory scope **`PASS_UNIQUE_HIGHER_PRIORITY_BETWEEN_TWO_PACKAGES_ONLY`**, empty diagnostics.

Create-only report on AI-G732:
`/srv/sable-build/evidence/titan2/pr347-factory-home-v1-1-20261023T011701Z/FACTORY_HOME_FALLBACK_V1_1.json`.

**The old V1 `HOME_BEHAVIOR_MISSING_OR_AMBIGUOUS` HOLD is closed** as a source-location/method discovery issue (not an observed product failure).

## Selected Android16 permission role behavior

- Selected `packages/modules/Permission/PermissionController/res/xml/roles.xml` HOME policy: role `android.app.role.HOME`, exclusive=true, `HomeRoleBehavior`, no `defaultHolders` resource, `PASS_HOME_ROLE_FALLBACK_POLICY_SOURCE`; SHA256 `ab0edf2685644f641984fa508d138e2ac15d3ca0d3900d0e2309d16a10dd730e`.
- Selected `packages/modules/Permission/PermissionController/role-controller/java/com/android/role/controller/behavior/HomeRoleBehavior.java`: method `getFallbackHolderAsUser`, SHA256 `e6b40b6bf24f7f572094f5f740b7756401d8cf63961f4a766958f940b826f143`. Source anchor booleans **all true**: eligible activities query, user-scoped context, `ResolveInfo.priority` comparison, null on a priority tie, Settings-fallback exclusion and a real return path. Status `PASS_SOURCE_PRIORITY_FALLBACK_ANCHORS`.
- V1's two outdated paths were `NOT_PRESENT`; V1.1 found this modern path as `FOUND_SAFE_FILE`.

## Actual compiled APK HOME filters — same pinned APKs, no rebuild

| Package | Exported MAIN/HOME/DEFAULT component | `android:priority` | SHA256 | Stage only |
| --- | --- | ---: | --- | --- |
| `org.sableos.launcher` | `org.sableos.start.SableStartActivity` | **10** | `f331848ca742aae888233edb8fa6dcbc9c0c1fed80f35f8f46d2d7d07564126e` | `system/app/SableLauncher/SableLauncher.apk`, 5,177,311 bytes |
| `com.android.launcher3` | `com.android.launcher3.uioverrides.QuickstepLauncher` | **0** (priority attribute absent) | `580f795e1e4830014a9d691a4c790b36fe2cc3f097d5d5d9f7eebea48536e2e7` | `system/system_ext/priv-app/Launcher3QuickStep/Launcher3QuickStep.apk`, 17,422,140 bytes |

The **two inspected packages** have a unique higher-priority SableLauncher candidate, consistent with the selected `HomeRoleBehavior` *source* fallback when HOME is unassigned and this ordering applies.

This is **not a factory default implementation or runtime result**. The operator explicitly reports `fallback_rank.global_unique_eligible=NOT_PROVEN_OTHER_HOME_CANDIDATES`, `role_fallback_applied=NOT_PROVEN`.

## Decision and gates

1. **Do not implement a boot-time HOME role setter** or delete Quickstep's HOME eligibility based on this result. Candidate eligibility and fallback code exist already; there is no proven source defect left in that narrow behavior.
2. **Product integration remains HOLD**: no evaluated `PRODUCT_PACKAGES` inheritance, all installed eligible HOME activities, sealed target-files/image, PermissionController resource and image/provisioning owner evidence, or installed `system` / `system_ext` privileges. Standalone staged APK and source makefile references do not constitute selected image.
3. **Factory default runtime remains HOLD**: actual fresh-user role holder, first-boot/setup order, preserved-data role/user choice, restart/reboot and switching are untested. On a later explicitly authorized known-recoverable device, perform read-only role/package probes and manual acceptance using the already generated `DEVICE_PLAN.json`. Do not contact or flash a device in this handoff.
4. **Quickstep runtime remains HOLD**: service binding, Overview fallback/gesture/Alt-Tab, keyboard, profile redaction, app grants, selected overlay config are source-supported but untested.
5. **Next integrated image remains blocked** by the deliberate `build/titan2/nextbuild/check-ready.py --require-ready` gate: **22 Q25 applicable rows OPEN** and **8 prerequisites OPEN**, including effective single IMS provider, G1/G2/G3, SMS default role and installed-image provenance. No waiver, no full image, no flash. PR346 remains frozen.

**Scope closed by this receipt:** source-level factory fallback mechanism **among SableLauncher and Launcher3QuickStep**. **Not closed:** globally unique candidate, installed role, factory selection, product/image, runtime, or release.
