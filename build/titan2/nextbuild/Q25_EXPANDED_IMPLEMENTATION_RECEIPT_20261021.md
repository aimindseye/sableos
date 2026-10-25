# Track B next-build expanded Q25 source implementation receipt
2026-10-21 | PR347 | **DRAFT — not AOSP/image/device/IMS qualified**

## Branch and custody
- Current interrupted AOSP build: PR346 exact source `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`. This PR made **zero changes** to the running ai-g732 Android checkout or its retained Ninja outputs.
- Next source branch: `titan2/nextbuild-q25-app-conformance-20261021`, draft PR347 against PR346.
- This is an implementation receipt, **not an attestation that all 23 Q25 rows are complete**.

## Coordinated source implementation (this expansion)
1. **Full upstream Q25 SableLauncher source port:** 16 exact Q25 Git-blob files under `src/android/packages/apps/SableStart`, preserving `org.sableos.launcher` identity and existing `SableLauncher` Soong module; uses Android's LauncherApps/physical profile APIs. Includes Glance/Home/Hub pager, BlackBerry10 default Home cards/grid, edit Home and widget/quick-bar persistence, session-safe recents, AppPrivacy permission/AppOps/role-bound descriptions, private/work profile awareness, system-confirmed uninstall and settings actions. Soong `Android.bp` updated for all new model, presenter, privacy and platform sources. Added requested signature/privileged uses-permissions from original manifest; **their grants and source SDK compatibility are not proved until installed image/compile**.
2. **Presentation quality support:** `apps/r8/android/sablestart-presentation-check/build.gradle.kts` source sync expanded from 6 into 17 launcher presentation sources; exact eight upstream Q25 JVM test files imported: CommandQuery, CoreAppIdentity, HomeLayout, QuickBar, DeviceStatsFormat, PrivacyCacheAndInteraction, PrivacyEvaluator, PrivacySummaryPolicy. Restored JUnit dependency and unit-test compile synchronization. These tests have been source-imported, **not run on ai-g732 or in Android Gradle**.
3. **Cross-app Command routing:** SableLauncher manifest/activity now expose `org.sableos.start.action.OPEN_COMMAND`, reopen local Search/Command on repeated intents. `TB2SableHub` MainActivity/HubScreen adds a visible Command action, explicitly targets the SableLauncher component and reports unavailable when it cannot open. No provider spoofing and **no system-wide Alt+Space interception yet**; that still needs the actual Android16 input policy owner.
4. **Camera:** Preserved Android16 source's real Z/Alt+Z zoom, R RAW, plus existing camera HAL/preview/recording path; changed preview touch-chrome interaction to accept only direct touchscreen finger/stylus events, ignoring trackpad/mouse source, with pure `CameraPreviewInputPolicy.kt` and five JUnit test methods. No new native Camera default role or HAL claims.
5. **Setup (nonprivileged):** Retained observed-only, post-provisioning `TB2SableSetup`. Added `SetupPresentation.stepLabel` for `Review i of n`, read-only Android-owned Wi-Fi/password guidance, and three unit test methods. Does **not** replace first-boot provisioner, configure Wi-Fi or claim setup role.
6. **Calendar / Hub reuse:** Current PR346 Calendar already implements `CalendarMode.Week`, NOW label/time row, Today routing and `CalendarBrowseKeys`; current Hub source is semantically equivalent to Q25 main Hub screen (formatting-only differences in two functions); preserved to avoid regressions. MessagesInteractionModel remains byte-identical to Q25. Original DocumentsUI 1001+1002 and Jelly 1041+1042 patches already retained; **not applied** to missing/unverified A16 owners.

## Validation performed without Android build
- Direct GitHub repository tree/source graph checked at development commit after writes: **20/20 Soong launcher source paths exist; 17/17 Gradle presentation source paths exist**.
- Cross-component source-contract audit **9/9**: explicit HOME Command action, activity route, Q25 three-page screen, Hub callback/activity, Camera callback/policy, Setup step/help.
- Pure Kotlin smoke for two new policy files reconstructed **byte-for-byte to GitHub blobs** `0f04d9f64f926015198fe1bee1879a772c9f7423` (Camera) and `61991c3a6a0501d691fe1c3ba5bb6f545d65f1ce` (Setup): **real kotlinc-jvm 1.9.0 + JRE21 compile and 11/11 asserts PASS**. Does not compile Compose/Android UI.
- Previously verified exact source-policy portable Kotlin smoke 28/28 PASS and Q25/IMS fail-closed Python gate 10/10 PASS on assistant host before the full port.
- No AOSP m, Android Gradle test run, actual SystemUI edit, package role action, device, adb, IMS test or flash performed.

## Scope NOT closed — next full image remains HOLD
1. Android16 selected `SableLauncher` full Compose/Soong compile, default HOME assignment, Launcher3 Recents-only runtime, actual dynamic profile permissions and cross-user permission grant checks; updated selected APK provenance.
2. **Global** Alt+Space needs exact active `frameworks/base` input policy source and integration tests; explicit Hub/Launcher Intent is implemented but is not a global keyboard hook.
3. DocumentsUI Files keyboard patch adaptation and compiling against the actual ai-g732 A16 owner; do not use Q25 Lineage path assumptions without context.
4. Browser T/B/L and reader policy: Q25 Jelly owner is absent in prior ai-g732 checkout; bind exact selected browser package/source before any source adaptation.
5. Privileged **first-boot** SetupWizard owner absent under Q25 name; this normal post-provision app is not that owner.
6. Native SystemUI Keyguard/QS/notifications/focus/redaction source adaptation and Settings/Dialer owner completion; preserve the prior seven compiled native source files and original owner source preconditions documented in `build/titan2/q25-onepass/OWNER_SOURCE_RECOVERY_20261020.md`.
7. AppLock/Vault/Freezer/Student/private profiles require real ActivityTaskManager/profile/SELinux/device-policy enforcement; hiding or disabling nonworking UI preferable to unbacked claims.
8. Android16 restricted READ_SMS default role and grants, effective selected PhhIms/Iwlan/G1-G3 classpath/service/ABI/privapp and real telephony runtime qualification. No IMS success inferred from source selection.
9. Original five Q25 owner decisions (emergency key, Diagnostics placement, QS columns, Seedvault restore fail-closed, legacy Settings rows) remain recorded and unforced.

**Operational status:** `FULL_23_ROW_Q25_CONFORMANCE=OPEN` / `NEXT_AOSP_BUILD=HOLD` / `FLASH=NO`. Run targeted app unit tests/Android16 compile only after controlled source staging in a non-running workspace. Preserve all previous image and log receipts.

## Host-only exact A16 owner snapshot (new, optional)
`build/titan2/nextbuild/a16_owner_snapshot.py` parses the 26 pinned original Q25 patch diff headers and the active global input-policy owner, reads **only** matching Android16 source files, and produces a bounded receipt or explicitly requested ZIP; it does not mutate `android/`, stage product, execute builds, or contact a device. Missing sources remain reported as missing rather than guessed.

From a **separate read-only checkout of the PR347 branch**, not the frozen PR346 build terminal:

```bash
cd /srv/sable-build/workspaces/titan2-track-b/tb2-pr347-nextbuild-source
python3 -B build/titan2/nextbuild/a16_owner_snapshot.py \
  --android-root /srv/sable-build/workspaces/titan2-track-b/android --plan
# Optional, only when source handoff is needed and output path is new:
python3 -B build/titan2/nextbuild/a16_owner_snapshot.py \
  --android-root /srv/sable-build/workspaces/titan2-track-b/android \
  --collect --out "$HOME/Downloads/TB2_Q25_A16_OWNER_SNAPSHOT.zip"
```
The source checkout path above is an **example**, not a claimed existing host directory; do not checkout PR347 into the running PR346 workspace. Output ZIP must be outside Android and Sable source trees and must not exist. Input symlinks, owner path escapes, size overflow, module drift and patch count changes fail closed.

**Exact snapshot tool test evidence (assistant host, not ai-g732):** source Git blob `0f8a5f457536bc44d173e4a3dd3fbac554ff678b`; regression file Git blob `9a65dc827df2bd00194735b7b5be62f6a954fd2a`; both independently reconstructed with exact SHA1 identities. Python `py_compile` PASS, 8/8 real standard-library regression tests PASS (0.052s), 3,000 small-file scans 0.365s test-fixture microbenchmark. A whole Android source snapshot has **not** yet been run on ai-g732.

This tool is **not required to finish already-existing portable UI port**; it is the safe dependency to adapt actual SystemUI/Settings/Dialer/DocumentsUI source and to identify missing browser/first-boot owners without fabricating success.
