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
