# ADR-0013: Titan 2 Track B standalone SableLauncher HOME with Quickstep Recents fallback

**Status:** APPROVED — **Track B PR347 architecture choice only**; implementation and release acceptance remain OPEN.
**Decision date:** 2026-10-22.
**Decision authority:** Explicit SableOS product-owner direction in the Track B engineering conversation: "Approve standalone SableLauncher + Quickstep fallback for Track B."
**Scope:** Titan 2 **Track B** Android 16 next-build branch `titan2/nextbuild-q25-app-conformance-20261021`, draft PR347, generated engineering product `treble_arm64_bvN-bp4a-userdebug`. Not an approval for Track A, Panther, other Sable devices, all of SableOS, or flashing.

## Context and relationship to the canonical architecture

`docs/CURRENT_HOME_AND_C3B_INTEGRATION_AUTHORITY.md`, `docs/ARCHITECTURE.md`, `docs/adr/0012-keyboard-device-user-choice-camera-control-deck.md`, and `sableos-project/platform_sable/docs/ARCHITECTURE.md` designate **Launcher3QuickStep-hosted Sable Start** as the canonical first-party HOME. Those global documents are **not silently replaced** by this decision. This is an explicit **Track B scoped exception** accepted for PR347 engineering; before promotion beyond Track B, the maintainers must reconcile the exception in those authority documents or obtain a separately reviewed cross-device change.

The historical `docs/R9_SABLE_HOME_REPLACEMENT.md` explored a standalone SableLauncher with Quickstep's alternate-home Recents fallback, but declares itself superseded by R9L8. It is a useful technical precedent, **not** independently current product authority.

## Decision: responsibilities and factory behavior

1. **SableLauncher is Track B's intended first-party HOME UI.** Package `org.sableos.launcher`; component `org.sableos.start.SableStartActivity`; owns Sable Start/Glance/Home/Hub, All Apps, local Search/Command entry and keyboard-first surface. Factory default HOME **must be explicitly established using supported Android role/default-app mechanisms**, subject to setup/user state. An APK HOME intent filter, higher intent-filter priority or `PRODUCT_PACKAGES` alone does not prove default selection.
2. **Launcher3QuickStep remains installed and enabled as the Quickstep/Recents substrate.** Package `com.android.launcher3`; keep `com.android.quickstep.TouchInteractionService`, the `android.intent.action.QUICKSTEP_SERVICE` service, and `com.android.quickstep.RecentsActivity`; preserve valid SystemUI binding and required privileges. Quickstep's existing `QuickstepLauncher` HOME eligibility may remain in the initial engineering image. **Do not remove its HOME intent filter or disable the package as a shortcut**: changing launcher eligibility needs separate reviewed source and regression evidence.
3. **Use the existing alternate-HOME fallback**, not an invented proxy. `OverviewComponentObserver` resolves the selected HOME and, when it differs from Quickstep's own HOME, uses `mFallbackIntent` targeting `RecentsActivity`, with the fallback-window/container decision controlled by active flags. `SystemUI/LauncherProxyService` binds the Quickstep service via `config_recentsComponentName` and `ILauncherProxy`; `OverviewProxyRecentsImpl` forwards Recents commands through that proxy. This is **source-level evidence only** until the selected compiled image and device confirm the path.
4. **Respect Android user choice.** Third-party HOME remains selectable; neither setup, update, reboot nor a service should forcibly reassign HOME after an explicit user change. Preserved-data migration requires distinct testing and a consent-respecting default-home policy. A third-party launcher does not inherit Sable privileged integration, hidden-profile or Quickstep guarantees.
5. **Keep security boundaries.** Do not grant new permissions, weaken SELinux/AVB, repurpose private profile APIs, disable Quickstep service/Recents or conflate a signature declaration with runtime grants to make this design appear complete.

## Existing evidence carried forward; no recompilation requested

All observations below are from the user's AI-G732 **partial selected module output**, not a finished image:

| Subject | Evidence and scope |
| --- | --- |
| SableLauncher | Native `m SableLauncher` PASS; current staged APK 5,177,311 bytes; SHA256 `f331848ca742aae888233edb8fa6dcbc9c0c1fed80f35f8f46d2d7d07564126e`; static HOME and source-platform reference signing PASS. |
| Quickstep | Native `m -j4 Launcher3QuickStep` PASS on 2026-10-22 (38.701 s); current `system/system_ext/priv-app/Launcher3QuickStep/Launcher3QuickStep.apk`, 17,422,140 bytes; SHA256 `580f795e1e4830014a9d691a4c790b36fe2cc3f097d5d5d9f7eebea48536e2e7`. |
| Packaged manifest | Exact AAPT2 audit PASS; **both** `SableStartActivity` and `QuickstepLauncher` have MAIN/HOME/DEFAULT. Quickstep also contains Recents and exported TouchInteractionService. Two HOME candidates do not establish selected HOME or a failure by themselves. |
| Binding source | Selected A16 source has `LauncherProxyService` binding `QUICKSTEP_SERVICE` to the configured Recents package; `OverviewComponentObserver` has an explicit alternate-HOME fallback. `config_recentsComponentName` base XML reads `com.android.launcher3/com.android.quickstep.RecentsActivity`; bounded 2,742-entry scan found **0** override candidates in its scoped roots. These are source-level checks, not effective overlay/bind evidence. |
| Flags | `SEPARATE_RECENTS_ACTIVITY` source default is `DISABLED`. The different-default-HOME branch exists regardless; **active flags and window-vs-activity fallback are not qualified**. |

Key receipts:
- `/srv/sable-build/evidence/titan2/pr347-quickstep-v1-1-20261022T230353Z/BUILD_RESULT.json`
- `/srv/sable-build/evidence/titan2/pr347-dual-home-aapt2-20261022T231617Z/DUAL_HOME_STATIC.json`
- `/srv/sable-build/evidence/titan2/pr347-recents-binding-20261022T235654Z/RECENTS_BINDING_SOURCE.json`

## Acceptance gates before any release claim

**Architecture direction is approved; the following are still HOLD, with no gate bypass:**

1. **Canonical source and product selection:** review intended Track B product inheritance for both modules, correct partition/priv-app allowlists, selected browser/setup owners and the HOME provisioning/role policy. Verify pinned APK provenance in the selected finished product and preserve source/version custody. Do not count a standalone module stage as installed-image proof.
2. **Resource and service:** verify effective built `framework-res` value, runtime RRO/resource precedence, configured Recents package, `QUICKSTEP_SERVICE` binder connection, SystemUI/Quickstep permissions and no fallback to an unrelated provider. Source-level `config_recentsComponentName` is not the final effective value.
3. **HOME and Overview at runtime:** on an explicitly authorized, recoverable Titan 2 test image/device, verify first-boot factory HOME, repeated HOME presses, user switching, unlock/process restart, user-selected third-party HOME persistence, and preserved-data migrations. Exercise gestures, task animations, Overview show/hide/toggle, Alt-Tab and the physical keyboard with SableLauncher selected; test denied-service/fallback cases.
4. **Profile/privacy/security:** verify hidden-profile/Private Space behavior, profile credential boundaries, locked-state Recents redaction, app launch restrictions and privileged permission grants in the actual installed system. Source policy checks alone are insufficient.
5. **Broader PR347 release prerequisites:** the Q25 23-row conformance program (22 applicable rows), source/effective APK provenance, SMS/default-role restrictions, IMS G1 framework/classloader, G2 native/ABI, G3 vendor/transport and runtime registration, signing/AVB, recovery and image qualification remain independently required. `build/titan2/nextbuild/check-ready.py --require-ready` **must continue to hold** while requirements are open.

## No automatic implementation or release action

This ADR is a **decision record**. It does not modify `AndroidManifest.xml`, `Android.bp`, `rom.mk`, SystemUI/Quickstep code, source/target outputs, default roles, active flags, readiness JSON or the user's Android workspace. It does **not** authorize `repo sync`, full AOSP image build, unlock/flash, device contact, promotion of PR346, PR347 merge or relaxing any hold. Any source changes implementing provisioning/role defaults require their own review, tests and source pins.

**PR347 remains DRAFT and `release_ready=false`.** The first-party Track B HOME/Recents architecture decision is closed as a product choice; effective product, migration and hardware acceptance are **not** closed.
