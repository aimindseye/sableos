# Titan 2 Track B — consolidated source, Q25 and IMS custody (2026-10-20)

**Authority:** operator's Track B workspace inventory; original five supplied tar.gz archives; exact user-supplied `DESIGN_CONFORMANCE_Q25.md`, Native34 postbuild and Q25 IMS admission receipts; GitHub comparisons of PRs #342/#344/#345, Q25 PR #26, Track A and CI branches. This is **source/status consolidation before any new code changes**, not an implementation or device-release declaration.

## Current decision

```
ANDROID_SOURCE_MUTATION=NO
CANONICAL_SABLE_SH_IMAGE_BUILD=DEFERRED_UNTIL_PORTABLE_FEATURE_SOURCE_COMPLETE
LATEST_NATIVE34_APK=PASS_HOST_STRUCTURAL_AUDIT_ONLY
TRACK_B_FINAL_IMAGE=NOT_QUALIFIED
Q25_PORTABLE_DESIGN=PARTIAL
FLOSS_IMS=TRACK_B_STAGED_SOURCE_NOT_DEVICE_QUALIFIED
OEM_IMS=HISTORICAL_QUALIFIED_COMPONENTS_REUSABLE_NOT_SELECTED_NEW_IMAGE
IMS_G1_G2_G3=PASS_PRIOR_SCOPES_WITH_SELECTED_TARGET_DELTAS_OPEN
IMS_REGISTRATION_AND_VOLTE=NOT_QUALIFIED
DEVICE_CONTACT=NO
FLASH=NO
```

## Existing Track B host custody: do not replace or recreate

- Active Android 16 checkout: `/srv/sable-build/workspaces/titan2-track-b/android`; source/Gradle tools under sibling `tb2-sable`, including Q25 pinned checkout reference. Operator shows `bb10-module-trials` and multiple retained output/receipt directories. Directory existence does not prove build success.
- **Oct19 source review** `TB2_SOURCE_REVIEW_20261019T234957Z.tar.gz`: validated 8/8 archive member hashes, `STAGE_RECEIPT.json` binds **13** staged Sable APK identities; actual `vendor/sable/tb2-rebuilt` module/product files exist.
- **Track B IMS staging**: `vendor/sable/trackb13ims` declares FLOSS `PhhIms`, `PhhImsOverlay`, `Iwlan`, `QualifiedNetworksService`; MTK-only routing overlay excluded. Source/staging does **not** prove service install, privilege, registration or voice.
- **Oct20 BB10 source snapshot** `TB2_BB10_NATIVE_SOURCES_20261020T010513Z.tar.gz`: 22/22 hash-pinned members; PR26 branch presentation files, Android16 Launcher3/Settings/SystemUI build source snippets, and readiness issues. Some report claims are earlier than Native34 and must not overwrite later results.
- **Oct20 A16 task API** `TB2_A16_TASK_API_V11_20261020T043006Z.tar.gz`: 14/14 hash-pinned entries; exact 13 Quickstep source files; module compile PASS in isolated `bb10-module-trials` checkout, then **32 temporary source paths restored**; real task/thumbnail namespace remained unqualified at that historical checkpoint.
- **Oct20 A16 compile** `TB2_A16_NATIVE_COMPILE_EVIDENCE_20261020T115113Z.tar.gz`: 2/2 hashes; module build exit 0, signed intermediate 18,036,540 bytes, **33 temporary source paths restored**, signer cryptographic proof absent.
- **Later Native34**: `Launcher3QuickStep.apk` exact SHA `5d97ac40e8d62e03ed81bf85acc4d0359359ecad577ce90732c7e64fb10f137b`, 18,061,116 bytes and two DEX with 16,452 defined classes. NativeTaskFramePolicy, AllAppsPrivacyFilters and SableQuickstepLauncher definitions verified; **host structural pass only, no image or runtime admission**.
- **Canonical Git custody** `TRACK_B_CANONICAL_SOURCE_CUSTODY_3be8bdc1c4bdaf.tar.gz`: 17/17 hash-pinned files from `/srv/sable-build/sableos/repo`; historical HEAD `7120a783...`. `build/devices/titan2.sh` had a **preserved working-tree modification** (working SHA `3bcfeadbbe27f39a39cec8ff8c1a4c93107ba2a058e864cf1a486911c1a4a22c` versus HEAD/index SHA `01d0e8597daa02a2e00a6a12e32e34c1955f0e51b1e2401e753d581f4ec7da3c`). Do **not** run reset/clean or overwrite it.

## Branches and reusable source (2026-10-20 diff vs main)

| Branch | Diff | Reuse |
|---|---|---|
| `ci-sonarcloud-20261019` / PR #345 | 3 commits, two Sonar workflow/config files | Quality workflow **only**, not source feature completion |
| `docs/titan2-dual-track-20261018` / PR #344 | Documentation-only before this custody commit | Current handoff/RestlessOS authority |
| `track-a-oem16-q25-full-product-20261016` (PR #343 closed unmerged) | 4 ahead, many Hub and Sable Tools implementation/tests paths | Major **pre-existing Hub/Tools source**. Do not blindly port OEM boot/firmware/signing assumptions |
| Q25 `feature/sable-start-bb10-layout-20261019` / PR #26 | 9 ahead, four Q25 presentation/test/ledger paths | BB10 Sable Start presentation; **must remain hosted by Launcher3QuickStep** on Titan2 |

The previous Wave 1/2 ZIPs were **not pushed or merged into these branches**. Their limited host tests do not prove complete Android owner-module features. Specifically **Wave 2 ZIP is flat** (no enclosing directory): extracting into Downloads overwrote top-level files and caused the operator's subsequent `cd` failure; extract into explicit empty directory only.

## Q25 gap disposition

Original Q25 design report: **23 rows covering 24 artifacts**, `3 Done/Done in code`, `18 Partial`, `1 Missing` (Utilities/Notes/Recorder/Clock), `1 N/A` (Q25 subscreen, **not** Titan2). Q25 framework patches were source-written for different LineageOS modules; not Track B GrapheneOS/RestlessOS acceptance.

**Reuse/adapt before writing more:** Q25 Hub PR #20/KF-A privacy and Track A Hub source/tests; Q25 Settings Apps/Network Manager patches; Q25 SetupWizard 0401–0408; Browser Jelly 1041–1042; DocumentsUI 1001–1002; Calendar event edit/delete; Camera/Aperture; Glimpse/Media; Track A Sable Tools `Utilities.kt`. Wave 2 Notes/Recorder/Clock may add functionality but needs ownership review **inside** existing Tools/Utilities, not another accidental launcher/app. Preserve already compiled Native34 task/privacy source.

**Still open:** actual Track B HOME task-frame/runtime, Command shortcuts/actions, Hub menu and locked/private behavior, Messages/Phone/Contacts semantic integration, SystemUI/Keyguard/Settings/Setup Android16 screen patches, Calendar week/NOW and keyboard, Browser/Files true tabs/previews/reader, Camera2 and default-camera/device-specific features, media captions, Mobile Manager/Private Space/Vault/Dual/AppLock **real enforcement**, display profile application and Utilities placement. No claim of all 24 artifacts complete.

## IMS split and exact reuse rule

**Do not combine effective FLOSS and OEM providers.** Existing FLOSS source is staged in Track B; canonical OEM C1 Android16 source separately defines six modules: ImsService APK, two MediaTek boot JARs with location overrides, three XML/policy modules plus SELinux. Historical PR #342 and archived PR #339 supply **G1 M4** image graph/11 embedded member hashes/skip_mount, **G2 M11** APK platform signer/shared UID + two API36 bootclasspath records, **G3** OEM A4 native closure + five R2 ELF/56 direct DT_NEEDED/19 Bionic/bounded symbols as **PASS_PRIOR_SCOPE**. Historical M4 device **FAILED_RECOVERY**. New selected Track B image needs only the *effective installed provider/partition G1*, *merged actual UID/privapp/SELinux/classloader G2*, *full selected IMS process namespace G3* delta; live SIM1/SIM2/DSDS registration/IMS/VoLTE follows separately. Never rerun historical scope merely to reproduce prior PASS.

## Ordered no-rework next boundary

1. Freeze original archives/receipts and all existing workspace, branch and source identities; **no new scan that repeats these receipts**.
2. Resolve exact feature ownership across Q25, Track A and Track B; choose **one** IMS strategy before merging any code.
3. Make **one reviewed integrated source delta** after deduplication, with app/UI/framework security tests and no parallel HOME or Tools clone.
4. Only after portable source completion use canonical `sable.sh titan2 <bound release> ci full`, then its matching `build` action. Qualify final selected image G1/G2/G3. Physical boot/registration/voice and flash remain distinct permissions.

**Full evidence custody package delivered separately in this conversation:** `TB2_CONSOLIDATED_CUSTODY_20261020_V1.zip` includes all five original archives unchanged, source Waves 1/2 and prior integration ZIP, user supplied receipts, SHA manifest, machine-readable 23-row feature matrix, and detailed status/IMS/space reports. It is not committed to GitHub because it includes source snapshots and local historical receipts; this doc is the review entry point.


## 2026-10-20 implementation progression: portable Hub/Tools GitHub source promotion

**Actual GitHub source change:** [draft PR #346](https://github.com/aimindseye/sableos/pull/346), portable code branch `titan2/track-b-portable-hub-tools-reuse-20261020`, commit `a8f2a756938b9260ef6fd86809ffba581f5da705`. Started from `main` `12e9793627babd0294a0022d8644360bc7727f6c`; code exactly reuses historical Track A branch `29bd50ce9d81684566dca410ec57816e261fdda3` with precisely **three Track A-only paths excluded**: `TRACK_A_ISOLATED_HOST_AND_AVB_POLICY`, `TRACK_A_OEM16_Q25_INTEGRATION`, `product/titan2/track-a-oem16/apps.tsv`.

GitHub comparison **confirmed 128 real changed source files:** 69 Hub, 47 Tools, 10 shared-design, 2 Gradle settings/dependency files; **no changes outside portable source allowlist**. Portable files are source-reused, not duplicated. The pre-existing Tools app is the retained Utilities owner; the Wave 2 alternate standalone `SableUtilities` app is **not** promoted. Its Notes/Recorder/Clock work remains a source-integration task until implemented within a reviewed owner.

Companion bounded check: `TB2_P346_PORTABLE_SOURCE_PROMOTION_V1.zip`, SHA256 `eb8214bcf875716fa7d7e29ab001b61318ebb0c226e57d48a39eb18d3bff7a1f`; `verify_reuse.py` compares exact commit-parent and Git blob object identities using Git's local objects. Test command is *read-only*; needs exact commits fetched and does not alter the ai-g732 Android checkout. Local AST/Bash syntax PASS, **10/10 synthetic regression PASS** (0.633s), `bash -n` 30 samples median 1.3ms/max 2.053ms; historical canonical `sable.sh` and `titan2.sh` Bash parse PASS. These do **not** establish Android/Gradle compilation, real-runtime performance or security readiness.

**Hard gates before PR #346 merge or selected Android image build:** Test Hub and Tools on actual Android16 Gradle/Soong dependencies; reconcile existing 13-APK staged module names; review exported Hub providers, SMS/notification privileges, profile/lock redaction and permissions; port PR#26 BB10 presentation only into Launcher3QuickStep Native34 HOME; complete remaining Settings/SystemUI/Setup/Phone/Contacts/Calendar/Browser/Files/Camera/Notes/Recorder/Clock/security-gate features. The IMS choice remains **FLOSS vs OEM unresolved**; no G1/G2/G3 new target image PASS or registration/voice result. Only after source completion use canonical `sable.sh` full CI and build. Physical device/flash are separate.

**PR #346 is draft/unmerged and the active `/srv/sable-build/workspaces/titan2-track-b/android` tree was not modified by this GitHub promotion.** This section advances the previous source-custody *no-actual-code-yet* statement, not earlier historical evidence or runtime qualification.

## 2026-10-20 Sable Tools personal Utilities — committed source, test-only acceptance

**Source implemented on the existing [draft PR #346](https://github.com/aimindseye/sableos/pull/346)**, head `f388074056768c3735c0188e915532bbe5c76430` (131 changed source files vs main; allowlisted Hub/Tools/shared/Gradle paths only). This is the next **actual code integration**, not another source census:
- Reused existing Wave 2 `PrivateNotes.java` app-private Notes code by relocating into established `org.sableos.tools` package.
- Added `PersonalUtilitiesControllers.kt` Notes editor/list/save/delete, foreground-only microphone Recorder record/play/delete (five-minute limit; pauses stop capture), and session Clock/stopwatch with Android system Clock alarm handoff.
- Registered `NOTES`, `VOICE_RECORDER`, `CLOCK_STOPWATCH` in existing Tools `ToolCatalog.kt` and `Controllers.kt`; revised `HomeModelTest.kt` to permit software-only utilities for Q25 while maintaining hardware capability gates; new real `PrivateNotesTest.java`. **No second app/manifest, HOME intent, Android Launcher3 owner or product image changes.**
- Companion exact source/test ZIP `TB2_P346_PERSONAL_UTILITIES_V1.zip`, SHA-256 `c1abe272036f812a75a8e0c6fa6a4f8104e8bb346e498bf6441efd6f869d88c7`. Local: 12 ZIP members verified, 8 Python source tests including 40,000 hash benchmark (~0.2s) PASS, Java Notes 6 behavior checks PASS, Kotlin syntax/type smoke with synthetic Android API stubs PASS. This is NOT a real Android SDK/Gradle/Soong/physical test.

**Gate remains HOLD_SOURCE_INTEGRATION_PENDING:** Full Q25 partial conformance is not complete; the revised Tools screens require Android16 Gradle compile, JUnit/permissions/audio/keyboard/720px review. IMS selection FLOSS vs OEM, exact new-image G1/G2/G3 and runtime registration/VoLTE remain open; PR #342 historical PASS reused. Owner requires **no `sable.sh` build** until portable Q25 feature source completion and source-level integration review. PR #346 is still draft and unmerged; active `titan2-track-b/android` was not modified.

## 2026-10-20 Calendar actual Q25 source port and work-window implementation

[PR #346](https://github.com/aimindseye/sableos/pull/346) draft head `12d2fcf0291374987d5cd799949f4d8a5efa85e8` adds **seven actual Calendar source/build/test files**, on top of the existing 131-file Hub/Tools/source reuse. Upstream origin Q25 PR #18 (same `aimindseye/zinwaq25-sableos` BB10 branch; not an invented new Calendar UI). It **ported the already-written Q25 `MainActivity.kt`, `CalendarRepository.kt`, `CalendarEventPolicy.kt`, `CalendarEventPolicyTest.kt`**, retaining advanced provider-bound event details, edit/delete permissions, drafts and safe delete confirmation. Q25 policy and tests have byte-identical Git blob IDs `a7acfad03f04374b7bb87c9461a52b368562830b` and `c831541a12bde9d8f4354e2a50e11ed7090d09d5`. Do not rewrite these again.

The new delta actually implements the still-missing **five-column current-day/window** from `platform_sable/docs/design/MAIL_CALENDAR_PRODUCTIVITY_UX.md`: Week default with a visible **NOW**, next future event, selected-day inspector, date navigation, TODAY control, and focusable day cells. One bounded five-day `CalendarContract.Instances` provider query per window; original one-day agenda semantics remain. A new pure policy maps C new, T today, V view cycle, J/N forward, K/P back; disabled in text-editing modes and for modifiers/repeats. **R/RSVP deliberately remains unimplemented** because no authorized provider response path was established. Newly added JUnit date/DST/UTC all-day and guarded-key tests use canonical `libs.junit` Gradle catalog, no new external modules.

**Actual verification:** local Kotlin/JVM equivalent policy compile+20 smoke cases PASS (using Android KeyEvent + CalendarEvent test stubs only); 100 × 10,000-event overlap+next loops took 53.70ms locally. Exact upstream policy/test source identities verified in GitHub; downstream structural check confirmed actual Week mode, five-day single-query repository, NOW/next/cell focus and mode-based input guard. No new shell scripts, no ai-g732 Gradle/Soong/Compose compilation, no 720×720/device snapshot, no source staging into active Track B, no `sable.sh` build and no flash.

**Still open before Q25 complete:** Calendar RSVP/search/explicit time-block paging and provider/privacy UI acceptance, plus all other Q25 partial app/framework/backend rows. PR #342 historical IMS G1/G2/G3 scoped PASS remains reusable but neither staged FLOSS nor OEM C1 has selected-new-image effective acceptance; new target composition/G2 classloader+SELinux/G3 namespace and live IMS/VoLTE remain separate. **Do not equate this Calendar source implementation with Android/device acceptance or full feature completion.**

## 2026-10-20 cross-module Q25 next source slice — exact completion vs owner-bound HOLD

**Source implementation (new actual GitHub code):** [draft PR #346](https://github.com/aimindseye/sableos/pull/346), head `2b490fc7676c2f96385c180d0fb7aae32af5a7ab`; verified GitHub comparison 141 changed source files: Hub 69, existing Tools 50, shared design 10, Calendar 7, Messages 3, Gradle 2, **no unexpected paths**. PR #342 and #344 review context preserved; no vendor image, IMS or launcher HOME source was modified.

| Requested area | Prior source already written | Current true remaining owner/delta |
|---|---|---|
| **Calendar** | Q25 PR #18 event details/edit/delete/date keyboard and CalendarProvider wrappers ported on PR #346 | **New source**: five-day NOW, bounded search, explicit four-hour pages, guarded browse shortcuts, R opens the real Calendar provider's event. This is provider RSVP **handoff**, not self-managed RSVP. Android Gradle/UI/provider acceptance open. |
| **Messages** | canonical Sable Messages Compose keyboard UI, static sample threads, external `smsto:` handoff (see `docs/C3B_MESSAGES_RECONCILIATION.md`) | **New source**: fail-closed `KeyguardManager.isDeviceLocked` gate hides app content while Android user locked, with JVM gate tests. **Live conversations/data path and provider integration still not implemented**; private-profile/notification privacy and lock state transitions need Android runtime validation. |
| **Settings / Mobile Manager** | Q25 1101/1102, Q25 Settings keyboard/backlight and 1103 setup handoff | Not proven compatible/applied against Track B Android16 Settings. App Lock/Freezer policy screens **do not mean enforced backend**. |
| **SystemUI / lockscreen** | Q25 SystemUI overlays, framework Keyguard keyboard tests | Effective Android16 Keyguard/SystemUI policies, per-profile redaction, lockscreen key actions and acceptance OPEN. |
| **Setup** | Q25 SetupWizard 0405/0408 overlays and `apps/titan2/platform/setup` software app/SetupRows source | First-boot system authority, restore fail-closed, keyboard fallback and theme propagation in actual Track B setup owner OPEN. |
| **Browser** | Q25 Jelly 1041/1042 keyboard model/patches | Android16 selected browser package and tab/page/reader implementation binding OPEN; Lineage Jelly patches not blindly admitted. |
| **Files** | Q25 DocumentsUI 1001/1002 keyboard model/patches | Selected Android16 DocumentsUI exact source match + storage grants, copy/move/rename/create action semantics OPEN. |
| **Camera** | Q25 Camera review bundle includes `ReviewActions`, `QuickReview`, `QuickReviewHost`, `QuickReviewOverlay`, `CameraKeys`; canonical Titan2 Camera currently lacks them | **Do not copy only Q25 `MainActivity`**: it depends on Q25 camera/key, saved-capture, lock-control and profile APIs. Compatible camera bundle and target-specific Camera2/50MP/physical keys qualification OPEN. |
| **Phone / Contacts** | Q25 Dialer 0704 in-call Space key patch, Q25 Contacts/Dialer subtitle tests | Android16 owner binding, default dialer role, call/audio handling/contacts semantics OPEN; no IMS regression permission. |
| **Enforced privacy / Vault / Dual** | Q25 privacy UI policies, overlays and some user-facing Controls; Track A Hub redaction models | Android privileged backend for App Lock/Freezer/Dual/Private Space, source isolation, real policy-enforcement, SELinux/permission gates **OPEN**. No UI-only claim accepted. |
| **Native34 HOME** | host Launcher3QuickStep APK compilation and class/DEX audit PASS, BB10 Q25 presentation branch and native task trials preserved | Permanent selected Track B Launcher3QuickStep HOME/Recents build source and real runtime/task thumbnails still **OPEN**; do not introduce independent `SableLauncher`. |
| **IMS** | PR #342 G1/G2/G3 historic OEM scopes PASS; staged FLOSS IMS source available | FLOSS-vs-OEM chosen route **OPEN**; selected new-image G1/G2/G3 deltas + device boot/registration/VoLTE **OPEN**, separate from portable Q25 source. |

**Local validation:** exact GitHub Calendar source blob `48e9ae690cbdd98744d9d8e3c41c92bc13bb0b26` Kotlin/JVM compiled under minimal Android KeyEvent/CalendarEvent test stubs; 215 assertions PASS, 100 × 10k-event search/next ~86 ms local policy-only. Exact GitHub Messages gate blob `6c897ebd75756ee95ebd20a66131d8aeb035e947` Kotlin/JVM compile and 2 checks PASS. Calendar R/RSVP policy unit-test source updated; actual Gradle/JUnit/Compose/CalendarProvider and Messages KeyguardManager device runtime not tested. Canonical R8 Calendar Gradle dependency corrected to `testImplementation("junit:junit:4.13.2")` (the earlier `libs.junit` alias was invalid because canonical R8 root lacks the version catalog). No new script/host tool setup needed.

**Do not mistake these app-source changes for completion of all requested Q25 areas.** No active ai-g732 source mutation, no `sable.sh` full CI/build, no whole system.img, no device, no flash. Owner's source-completion-before-build sequencing remains controlling.
