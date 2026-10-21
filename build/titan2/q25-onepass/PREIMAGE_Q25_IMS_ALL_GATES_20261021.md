# Titan 2 Track B: integrated Q25/IMS pre-image gate — all current source gates and explicit holds

**Evidence date:** 2026-10-21 (actual owner ai-g732 outputs supplied). **Disposition: HOLD_PREIMAGE_GATES_OPEN**; no whole image, runtime qualification, device/flash or signature authorization.

## Completed existing host gates (do not rerun)
- Phase 12 source promotion: four A16 modified + three new sources, all SHA pinned. Real `source build/envsetup.sh; lunch treble_arm64_bvN-bp4a-userdebug; m -j4 SystemUI Dialer` EXIT 0 in 362.602s.
- Phase 13 source freeze: seven exact compiled-source files, snapshot SHA256 `ee7453e5c23194968b80ff82cfdc0d34464bfc8c2443b47a5e69917466a84da2`, 19,313-line successful Soong log SHA `8472ebaf144512b6133dd44b489f91fae2b21138acaf7eb9155cd4b3738fdc46`.
- Real combined source-native receipt `PASS_PHASE1_SOURCE_AND_PHASE2_NATIVE_COMPILE_ATTESTED`; verified frozen A16 source. Combined report Phase12 original SHA `5eb502b295ea3a02cff50697fc8866d4c3b28d3b1dbd43cc36aa518d7b3992d1`, source manifest `c2fa66c12ec09c246579ee6cd4776d0ea99d74f6b3d4f55d866e3001a5470704`.
- **Newest actual ai-g732 results:** isolated PR346 app quality Git worktree `/srv/sable-build/workspaces/titan2-track-b/q25-app-quality-pr346-257a037e88f2` prepared with explicitly authorized pinned fetch; `PASS_ISOLATED_PR346_SOURCE_7_MODULES` with six Git blob pins; canonical checkout unchanged at `7120a783ed418f2bb60651ff70793c602b419f25`. Subsequent actual combined `quality-plan` returned `QUALIFIED_7_APP_SOURCE_MARKERS_FOR_OFFLINE_QUALITY`. **Offline Gradle assemble/unit/lint/detekt/ktlint for seven apps has NOT RUN.**

## Reviewed upstream/design/reuse

- PR342: historic M4/G1 11/11 embedded payload hashes and skip_mount, M11/G2 platform signer, `android.uid.phone`, API36 configured boot JARs, R2/G3 direct 56 DT_NEEDED, 19 bounded Bionic cases and partial ELF metadata. These are **PASS_PRIOR_SCOPE**, not selected new-image G1/G2/G3. Physically flashed M4 **FAILED_RECOVERY**.
- PR344: current Track B source and IMS custody; PR345: Sonar CI-only (not proof of Android app/module/image or device); PR346: 26 upstream Q25 framework patch candidates + app source, many A16 installed-owner/security tasks remain incomplete. Q25 upstream `aimindseye/zinwaq25-sableos/docs/SABLEOS_GAP_REVIEW.md` records Q4 framework never built/flashed; don't copy Q25 patch authorizations blindly.
- **New design conflict detected on public shared `sableos-project/platform_sable`:** `docs/design/KEYBOARD_FIRST_SYSTEM_IMG_COVERAGE_AUDIT.md` specifies *SableLauncher HOME + Quickstep Recents-only*, while PR346 Track B custody preserves *Launcher3QuickStep HOME+Recents* and intentionally omits Q25 HOME removal. This is an explicit **Q01_HOME_RECENTS=OPEN** architecture decision, not an implementation detail. Design also mandates Sable Start three pages (Glance/Start/Hub) and actual profile-isolated Private Space/Dual/AppLock, not cloned APKs.
- Canonical Android16 `product/titan2/n1i-c1` OEM `ImsService`/Mediatek JAR/XML sources and Track B staged `vendor/sable/trackb13ims` FLOSS `PhhIms`/`Iwlan` are **separate**; don't co-install both or infer installed permissions from a source path. Existing historical `build/gates/n1i-c1-android16-contract.py` and `build/titan2/qualify-n1i-c1-postbuild.sh` can inform exact provider checks, not authorize this new Track B image. Current `build/devices/titan2.sh` N1B2 release remains AUDIT_ONLY_FAIL_CLOSED.

## Integrated next artifact — sealed offline auditor

`TB2_Q25_IMS_PREIMAGE_INTEGRATED_GATE_V1.zip`, local distribution SHA256 **`1170c3d41d2ba3ba8cd735332144f081f677a176aa131633361a1dfc1c2dc607`**, not committed as a binary. `preimage_gate.py`, `policy.json`, `operator.sh`, full source-implementation backlog, tests, README, engineering review, validation log, member SHA manifest. Python3/Bash syntax PASS; **27/27 synthetic regressions PASS (~0.27s)**; ZIP integrity and independent extracted tests PASS; local 100k bounded small SHA256 operations ~0.057s (not build performance). **This new operator has not run on ai-g732.**

- Read-only `plan` or read-only + one new output directory `audit` over known A16 `/srv/sable-build/workspaces/titan2-track-b/android`, isolated PR346 root, actual combined `COMBINED_RESULT.json` and isolated `PR346_QUALITY_SOURCE_RECEIPT.json`.
- It re-verifies seven CURRENT A16 native after-SHAs, fixed combined source/Phase12/log/freeze digests, isolated exact Git HEAD and six marker Git blob SHA1s, seven Gradle owners, optional actual `QUALITY_RESULT.json` and both matching log SHA256 with 35 task identities.
- Source-only inventory: 26 PR346 retained Q25 patches, installed-owner directories, FLOSS/OEM staged IMS candidate paths. **Stage path presence does not pass selected effective image graph, privileges, or ABI namespace.**
- The policy lists source/privileged-Q25/IMS/build preimage gates plus **postimage** exact embedded G1/G2/G3/AVB/LP and **runtime** SIM1/SIM2/DSDS/VoLTE and HOME/SMS acceptance. `--ims OEM|FLOSS` is documented *intent*, not proof of a selected provider.
- Expected honest status: `HOLD_PREIMAGE_GATES_OPEN`, process exit 78, `image_build_authorized=false`, `flash_authorized=false`. Only pre-existing native and source gates can PASS now; Gradle may PASS after real execution. Other source/security/IMS gates have no real owner-specific validators, thus CANNOT be declared complete from an unchecked JSON claim.

## Next local commands (after checksum/tests)
```bash
cd "$HOME/Downloads/TB2_Q25_IMS_PREIMAGE_INTEGRATED_GATE_V1"
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
QUALITY_SOURCE=/srv/sable-build/workspaces/titan2-track-b/q25-app-quality-pr346-257a037e88f2
COMBINED="$HOME/Downloads/TB2_A16_PHASE12_COMBINED_ACCEPTED_20261021/COMBINED_RESULT.json"
SOURCE_RECEIPT="$QUALITY_SOURCE/PR346_QUALITY_SOURCE_RECEIPT.json"
bash operator.sh audit \
  --android "$ANDROID" --sable-repo "$QUALITY_SOURCE" \
  --combined "$COMBINED" --source-receipt "$SOURCE_RECEIPT" \
  --ims UNSELECTED \
  --out "$HOME/Downloads/TB2_Q25_IMS_PREIMAGE_AUDIT_20261021"
```
Optional *earlier* combined operator `quality-run` must be separately executed on exact isolated source with `--ack RUN_OFFLINE_Q25_SEVEN_APP_QUALITY_ONLY` to make a real `QUALITY_RESULT.json` and logs, then rerun this auditor with `--quality-result .../QUALITY_RESULT.json`.

**Source fixes remain to be written and qualified:** Q25 actual installed UI owner modules and 3-page Sable Start vs Quickstep roles, app Privileged AppLock/Freezer/Vault/Dual profile backends, read_sms hardRestricted selected app grant, browser/settings/setup/camera/contacts/files and full product wiring; one IMS provider, selected source+product G1/G2/G3 delta with signer/SELinux/classpaths and complete ELF namespace, then only after image the embedded and runtime checks. Do not run `build/sable.sh` full image yet. No new image, flash, device, network or AOSP source mutation by the auditor.


## ACTUAL_41_GATE_HOST_AUDIT_20261021

The owner ran the sealed **TB2_Q25_IMS_PREIMAGE_INTEGRATED_GATE_V1** on the real ai-g732 Android16 and detached PR346 source, after verifying outer ZIP integrity and **9/9 internal SHA256 members**, and executing **27/27 Python regressions PASS (0.071s)**. The **real host** `operator.sh audit --ims UNSELECTED` returned:

```
status=HOLD_PREIMAGE_GATES_OPEN
preimage_total=41
preimage_pass=2
preimage_open=39
preimage_hold=0
postimage_deferred=3
runtime_deferred=4
quality_invoked=false
ims_provider_requested=UNSELECTED
ims_selected_product_verified=false
ims_conflict_free_verified=false
image_build_authorized=false
flash_authorized=false
```

The two PASSes are the existing, byte-bound **P01 seven-source native compile** and **P02 isolated PR346 app-source** gates; optional P03 offline Gradle quality remains OPEN, not a failed Gradle run. Native Phase12/13 combined source freeze remains unchanged. No new image, AOSP source write, device contact or flash took place.

The host discovery confirmed `vendor/sable/trackb13ims/Android.bp` (FLOSS staging), `product/titan2/n1i-c1/Android.bp` (OEM C1 reference source) and selected `device/phh/treble/rom.mk` all exist, but **NONE** proves the installed **single effective IMS provider**. Historical PR342 G1/G2/G3 results are not a selected-image PASS. The retained PR346 patch inventory found **26** patch candidates. Actual A16 framework owner directories: Dialer, DocumentsUI, Launcher3 and Settings present; `packages/apps/Jelly` Browser and `packages/apps/SetupWizard` absent. Those Q25 patches require real selected owner adapters rather than blind copying. Shared SableLauncher HOME vs Track B Launcher3QuickStep HOME remains an explicit unresolved architecture decision.

**Reporting quality finding:** current v1 `patch_counts_by_owner` accidentally uses the fourth path component for `packages/apps/*`, resulting in filename-level keys instead of the expected owner grouping. This affects **presentation only**; the 26 patch count and fail-closed admission results are unchanged. Correct that aggregation in a later focused maintenance revision rather than misreport owner counts or rerun the entire qualification today.

**Next action:** execute the already-qualified combined operator's explicit **offline seven-app Gradle quality** against the pinned detached `.../q25-app-quality-pr346-257a037e88f2` checkout; capture `QUALITY_RESULT.json` and the two log hashes. If caches/tools are missing or Gradle fails, capture the first actual error rather than changing the Android16 tree. Resolve one actual HOME owner and one effective IMS provider, then implement/qualify outstanding Q25 privilege backends and selected-product G1/G2/G3 checks. `build/sable.sh` full image remains held; neither 39 OPEN gates nor historical IMS can be marked PASS by editing JSON statuses.


## 2026-10-21 actual seven-app offline Gradle attempt failed after 17.017 seconds

**New operator-owned first real quality receipt**, from `$HOME/Downloads/TB2_Q25_7_APP_QUALITY_REAL_20261021/QUALITY_RESULT.json`: `HOLD_OPTIONAL_APP_QUALITY_FAILED`. The exact PR346 isolated seven-app source preflight remained `QUALIFIED_7_APP_SOURCE_MARKERS_FOR_OFFLINE_QUALITY`. The Titan2 Gradle 8.14.3 group (`keyboard/camera/setup/tools`; five tasks each: assembleDebug, testDebugUnitTest, lint, detekt, ktlintCheck) **actually executed**, returned **exit_code=1** after **17.017s**. `titan2.log` SHA256 **`73060a9ee8d3640b0049b36a0f75b2fe1faffe2db08f7252a652f1be4b040751`**. No R8 group (`hub/messages/calendar`) step exists in the receipt, so these three tasks were **NOT RUN**. The quality receipt contains no actual Gradle exception text, so cause remains **UNCLASSIFIED_PENDING_TITAN2_LOG**. **Do not attribute to Kotlin, Gradle cache, Android SDK, AGP, detekt or lint without the full log**.

A **later retry using the same existing output path** failed closed at `PHASE12_COMBINED_HOLD=NEW_OUTPUT_REQUIRED`; that is an evidence-preservation guard, **not the reason** the prior Gradle task failed. Preserve the original `QUALITY_RESULT.json` and `titan2.log` unchanged. Read-only next step on ai-g732: `sha256sum titan2.log` equals the pinned SHA above, then `grep -nE 'FAILURE:|What went wrong:|Could not resolve|Could not find|^> Task .*FAILED|^e: |^error: '` and `tail -n 120` against the original file; record first actionable Gradle error. Only after a narrowly justified source/cache/tool correction should a fresh **new** `--out` directory be used.

Phase1 7 native files, Phase2 real A16 SystemUI/Dialer compiler PASS, Phase13 source freeze PASS and isolated PR346 source qualification PASS remain intact. This Gradle failure cannot close the pending Q25 app-quality gate. Full Q25/privileged security, selected IMS G1/G2/G3, image and physical device/flash gates remain open. No new image/source mutation/flash from this latest quality run.


## 2026-10-21 Detekt confirmed four source findings; targeted refactor candidate delivered

**Verified real failing log:** `TB2_Q25_7_APP_QUALITY_REAL_20261021/titan2.log`, SHA256 `73060a9ee8d3640b0049b36a0f75b2fe1faffe2db08f7252a652f1be4b040751`. The first actual offline Titan2 Gradle group returned exit 1 after 17.017 seconds. Precise fatal tasks and code-quality findings:
- `:camera:detekt` **FAILED**, 3 weighted issues: `MainActivity.kt` `LargeClass` (class at line 111), `doCaptureAction` `CyclomaticComplexMethod` complexity **17 vs 15**, and `ControlDeck.kt` `captureGate` complexity **15 vs 15**.
- `:keyboard:detekt` **FAILED**, 1 weighted issue: `HardwareKeyboardStatus.kt` `LoopWithTooManyJumpStatements`, original nullable-device and virtual-device `continue` paths.
- Kotlin/Java deprecation warnings, `libandroidx.graphics.path.so` unstripped notice and future Gradle 9 warning were **not** the fatal failure. No evidence yet that all other Titan2 tasks or Hub/Messages/Calendar quality passed. The R8 group was not run. Later `NEW_OUTPUT_REQUIRED` is the correct refusal to overwrite this original failed receipt.

**Targeted source-correction operator (distributed locally; not yet executed on ai-g732):** `TB2_Q25_DETEKT_REFACTOR_V1.zip`, SHA256 **`90cd01e10ed15e7ba3a206b0da97f4f288638d87e1445e598291dfd2feaa36d0`**. It checks isolated exact Git HEAD `257a037e88f20d5f998c89c5047f9d903640c4f1`, three original Git blobs, absence of the new helper and clean tracked state before requiring explicit `APPLY_PINNED_PR346_DETEKT_REFACTOR_TO_ISOLATED_WORKTREE`. It splits the Camera complexity branches, moves stateless Camera UI, preview matrix, surface callback, and mode selector to `CameraScreenFrame.kt`, and replaces keyboard dual continues with a guarded block. No Detekt config/exclusion/baseline/suppression changes. The operator supports read-only plan and unified diff, exact source verification, narrowly authorized restore and **new** offline seven-app quality run using pinned changed-source hashes. The old combined quality-run is intentionally not reused because it pins the original unmodified Keyboard blob.

**Local validation only:** Python/Bash syntax PASS, 24/24 real-Git/synthetic Gradle harness regressions PASS, ZIP CRC and internal SHA PASS, independent extracted-package tests 24/24 PASS, separate Kotlin/JVM Keyboard behavioral compile/run PASS (virtual and missing input devices ignored). ~0.070s for 100,000 tiny host SHA-256 operations; not a Gradle/build benchmark. **No real patched Camera Android/Compose compile, detekt pass or seven-app quality claim yet.** After ai-g732 testing, attach full new quality receipt/logs and only then reconcile newer Kotlin source pins into integrated preimage gate. Existing native Phase1/Phase2/Phase13 PASS intact. Q25 privileged, selected IMS G1/G2/G3, HOME, image and device/flash holds intact.


## 2026-10-21 Real Detekt-refactor quality rerun failed; error log pending

The operator provided actual `$HOME/Downloads/TB2_Q25_7_APP_DETEKT_REFACTOR_REAL_20261021/QUALITY_RESULT.json` after applying the bounded `TB2_Q25_DETEKT_REFACTOR_V1` patch to the detached PR346 source.

**Proven source state:** schema `sableos-pr346-detekt-refactor-quality-v1`; `source_preflight.status=PASS_PATCHED_4_FILES_PINNED`, unchanged detached Git commit `257a037e88f20d5f998c89c5047f9d903640c4f1`, `native_source_mutation=false`. Four exact SHA256 pins: Camera `ControlDeck.kt` `d5e07fe4ea57df58cb4bcbcbbb08749e67d14c80f4ff396822179e8bba02eea0`; Camera `CameraScreenFrame.kt` `9d4901baff61c1f2b59dff92b613c7e61ef4a4dfb926919a84c81b08efb8cce2`; Camera `MainActivity.kt` `12cd92f40e42a06141852b3b6916c0bc948a0d3e593fe07acba071359943c761`; Keyboard `HardwareKeyboardStatus.kt` `e4cc2eddad5d36f5b4e9c2390f5fa93205d927bc25a0b8f6488087e12c43da42`.

**Real quality run:** `status=HOLD_APP_QUALITY_FAILED_AFTER_REFACTOR`. First Titan2 Gradle 8.14.3 offline group (keyboard/camera/setup/tools, all five tasks requested per module) exited **1** after **2.669 seconds**; exact `titan2.log` SHA256 **`c26996de6accf5d6e3716cfe6647ed6a1b607e9fb6e7c366aef40c1b2be0b6d3`**. No second R8 group (`hub/messages/calendar`) entry appears, so that group was **NOT RUN**. The operator supplied only the QUALITY_RESULT.json summary, not the new log text: **failure cause is UNCLASSIFIED**; do not carry forward the previous Detekt failure category without verifying fresh log. Three known patches plus one helper match intended bytes; successful `source_preflight` is not successful Kotlin/Detekt build proof.

**Next host-only check:** Verify `sha256sum -c` against exact new `titan2.log`; emit bounded first error matches and final 160–200 lines, including Gradle `What went wrong:`, `Task .. FAILED`, Kotlin diagnostics, plugin/buildscript errors. Preserve both old and new failure directories untouched; do not reset Gradle caches, weaken Detekt, reapply patch or rerun native A16. The diagnosis must precede another code change. Native P1/P2/P13, isolated PR346 ownership and previous combined receipts remain PASS; optional Gradle quality and 39 Q25/IMS pre-image gates remain OPEN. No image/device/flash authorization.


## 2026-10-21 second Gradle failure root cause: offline Kotlin plugin marker unresolved

The owner supplied the **verified new** post-refactor Gradle log `TB2_Q25_7_APP_DETEKT_REFACTOR_REAL_20261021/titan2.log`, SHA256 `c26996de6accf5d6e3716cfe6647ed6a1b607e9fb6e7c366aef40c1b2be0b6d3`. The exact fatal error occurs while configuring `apps/titan2/platform/build.gradle.kts` line **2**: `Plugin [id: 'org.jetbrains.kotlin.android', version: '2.0.21', apply: false] was not found`; Gradle tried Google, Maven Central and Gradle Plugin Portal and could not resolve `org.jetbrains.kotlin.android:org.jetbrains.kotlin.android.gradle.plugin:2.0.21` **in offline mode**. `BUILD FAILED in 2s`. **Zero app tasks reached.** This second run is **not** a recurrence of the original four Detekt issues, and it does not invalidate or validate the four refactored Kotlin sources.

GitHub source identity confirmed: pinned PR346 source `apps/titan2/platform/gradle/libs.versions.toml` declares `kotlin = "2.0.21"`; `build.gradle.kts` uses `alias(libs.plugins.kotlin.android) apply false`. Both the earlier combined operator and newer refactor operator set the effective `GRADLE_USER_HOME` to `${SABLE_GRADLE_USER_HOME:-${SABLE_HOST_TOOLS_ROOT:-/srv/data/sable-host-tools}/gradle}`, JDK17 and Android SDK similarly. The first unpatched run reached `:camera:detekt` and `:keyboard:detekt` on Gradle 8.14.3, suggesting an effective offline plugin cache/repository metadata context difference, **but the logs alone cannot determine whether the plugin metadata/JAR is absent, stale, or cached in another home**.

**Next bounded action is read-only cache metadata inspection**, for active and alternate user Gradle homes: verify plugin marker `org.jetbrains.kotlin.android/org.jetbrains.kotlin.android.gradle.plugin/2.0.21` and implementation `org.jetbrains.kotlin/kotlin-gradle-plugin/2.0.21` in `caches/modules-2/files-2.1`, compare `SABLE_GRADLE_USER_HOME` against the normal `GRADLE_USER_HOME`, check Gradle metadata cache roots. No Gradle invocation, network fetch, cache deletion/copy, Kotlin version/AGP change or weakening of lint/Detekt until the cache state is known.

Existing failed quality receipt/log remain sealed and must not be overwritten. Source preflight `PASS_PATCHED_4_FILES_PINNED` and native P1/P2/P13 remain PASS. All app quality and selected IMS/Q25 preimage, image/flash/device readiness remain HOLD.


## 2026-10-21 Canonical host-tools Gradle plugin-marker cache diagnosis

**Actual ai-g732 read-only host-tools output:** `HOST_TOOLS_ROOT=/srv/data/sable-host-tools`, `GRADLE_USER_HOME=/srv/data/sable-host-tools/gradle`. Kotlin Gradle Plugin `2.0.21` implementation directory **PRESENT** and JAR `kotlin-gradle-plugin-2.0.21-gradle85.jar` found under hash `ea69d8de091115a98ce7f3901994b2fb3432480b`, but **plugin marker directory MISSING** for `org.jetbrains.kotlin.android:org.jetbrains.kotlin.android.gradle.plugin:2.0.21`. Canonical `gradle-8.14.3/bin/gradle` PRESENT under wrapper/dists hash `cv11ve7ro1n3o1j4so8xd9n66`; metadata cache directories `metadata-2.107` and `metadata-2.99` present. The post-refactor offline Gradle failure's reported inability to resolve marker is therefore consistent with actual cache state, **not proof of bad Kotlin source**.

**Source authority:** `apps/titan2/platform/settings.gradle.kts` declares `pluginManagement` repositories (Google, Maven Central, Gradle Plugin Portal); `gradle/libs.versions.toml` requests Kotlin `2.0.21` through `kotlin-android` alias. Official Gradle plugin marker for `org.jetbrains.kotlin.android:2.0.21` exists at the Plugin Portal. The existing implementation JAR alone cannot substitute for the marker in the default plugins DSL. No Kotlin version bump, Detekt exemption, manual cache file copy, self-built plugin POM, or alternative host tool root is justified.

**Next bounded resolution (host command offered, not yet executed):** Source existing canonical `build/config/host-tools.env`; assert `SABLE_GRADLE_USER_HOME=$SABLE_HOST_TOOLS_ROOT/gradle`, frozen detached PR346 code HEAD `257a037e88f20d5f998c89c5047f9d903640c4f1`, installed `$SABLE_JDK17/bin/java` and `$SABLE_ANDROID_SDK`; use the single installed Gradle 8.14.3 binary from the **canonical Gradle home** and run one **network-enabled** `help` configuration task in `apps/titan2/platform`, with `GRADLE_USER_HOME`, `JAVA_HOME` and Android SDK env set canonically. This invokes only Gradle-declared plugin/dependency repositories, writes its normal canonical dependency metadata and project `.gradle` configuration state (not A16 source), and logs result with SHA256. Do not use `--refresh-dependencies` unnecessarily. A successful `help` is **cache/configuration qualification only**, not app quality or Detekt pass; return to explicitly acknowledged offline new-output app-quality runner after success.

The explanatory inline Bash host command passed `bash -n` locally; it was not executed against ai-g732, so no host network/download, full image, device or flash action is claimed. Earlier 4-file refactor SHA receipt and both failed Gradle logs remain preserved, native A16 P1/P2/P13 PASS intact. Full Q25/IMS/image gates remain held.


## 2026-10-21 Refactored Q25 seven-app quality RETRY2 failed after 5.724 seconds

**New actual owner ai-g732 `QUALITY_RESULT.json`:** `schema=sableos-pr346-detekt-refactor-quality-v1`, `status=HOLD_APP_QUALITY_FAILED_AFTER_REFACTOR`, `source_preflight.status=PASS_PATCHED_4_FILES_PINNED`, exact pinned detached PR346 Git HEAD `257a037e88f20d5f998c89c5047f9d903640c4f1`. All four previously qualified refactor SHA256 values still match: `ControlDeck.kt=d5e07fe4ea57df58cb4bcbcbbb08749e67d14c80f4ff396822179e8bba02eea0`; `CameraScreenFrame.kt=9d4901baff61c1f2b59dff92b613c7e61ef4a4dfb926919a84c81b08efb8cce2`; `MainActivity.kt=12cd92f40e42a06141852b3b6916c0bc948a0d3e593fe07acba071359943c761`; `HardwareKeyboardStatus.kt=e4cc2eddad5d36f5b4e9c2390f5fa93205d927bc25a0b8f6488087e12c43da42`. Native source mutation=false.

The offline Gradle Titan2 first group (`keyboard,camera,setup,tools`, five requested tasks per app) **exit 1 after 5.724s**, with `titan2.log` SHA256 **`25811ce8cebf65b7c0d9f119a9eb51be4281611a57b4eaf553137afdcaefdb56`**; no R8 group step exists, so `hub/messages/calendar` were **NOT RUN**. The user has not supplied the RETRY2 `titan2.log` lines or a confirmed `CANONICAL_GRADLE_HELP_EXIT=0` receipt. **Root cause remains UNCLASSIFIED**. Do not assume the prior Kotlin plugin marker issue is cured, nor that original Detekt findings recur.

**Next host step (read only):** using the existing RETRY2 directory `$HOME/Downloads/TB2_Q25_7_APP_DETEKT_REFACTOR_RETRY2_20261021`, pin-check `titan2.log` against SHA256 above and print first `FAILURE:/What went wrong/Task FAILED/plugin not found/Kotlin compiler` matches and last 160 log lines. If plugin marker still missing, confirm canonical `gradle help` hydration outcome before any new build. Preserve three failed quality receipt/log directories; never rerun with same `--out`, change Kotlin/Detekt settings without reason, or touch A16 native sources. Phase1/2/13 and isolated refactor source gates remain PASS; app-quality, Q25/IMS/image/device remain HOLD.


## 2026-10-21 RETRY2 resolved plugin but hit missing offline AndroidX runtime dependencies

The owner supplied the **full verified** read-only extraction of `TB2_Q25_7_APP_DETEKT_REFACTOR_RETRY2_20261021/titan2.log` (SHA256 `25811ce8cebf65b7c0d9f119a9eb51be4281611a57b4eaf553137afdcaefdb56`). Gradle 8.14.3 now resolves project plugins and starts dependency checks. The fatal errors are exactly **four** `:keyboard:checkDebugAarMetadata`, `:setup:checkDebugAarMetadata`, `:tools:checkDebugAarMetadata`, and `:camera:checkDebugAarMetadata`: all report `No cached version of androidx.core:core-ktx:1.15.0 available for offline mode`; Camera additionally reports missing `kotlin-stdlib-common:2.0.21`, `kotlin-stdlib-jdk8:1.8.20`, `material-icons-core:1.7.6`, AndroidX savedstate/annotation/graphics/emoji2, and Kotlin coroutines/other transitive artifacts. The log reports 28 further failures with identical offline-cache causes. `BUILD FAILED in 5s`, `4 actionable tasks: 4 executed`. **No application compilation, lint, unit test or Detekt result** from RETRY2; no evidence of code regression. The earlier Kotlin Android plugin marker error is no longer this attempt's first blocker; the `help` result itself has not been supplied independently.

Source authority confirms `apps/titan2/platform/settings.gradle.kts` lists Google and Maven Central repositories and `libs.versions.toml` fixes `coreKtx=1.15.0`, `kotlin=2.0.21`, Compose BOM `2024.12.01`; unchanged by the four-file refactor. The canonical `build/config/host-tools.env` sets Gradle cache, JDK17 and Android SDK paths. Recommended bounded correction: **one explicitly network-enabled Gradle invocation of the exact 20 Titanium keyboard/camera/setup/tools assembleDebug, testDebugUnitTest, lint, detekt, ktlintCheck tasks** in the detached patched worktree, with canonical 8.14.3 Gradle binary + cache, JDK17, Android SDK, original source SHA precheck, unique log and its SHA256. Do **not** use `--offline` for this hydration/real-quality pass; full tasks rather than `dependencies` or `help` ensure actual resolved artifacts enter the Gradle-managed cache. The proposed inline command was **bash -n validated locally**, but its network Gradle action has **not run on ai-g732**. If it succeeds, separately rerun existing signed refactor operator offline with a **new** output directory for sealed seven-app quality; if it fails, use its actual new log for the next narrow correction. No changing Kotlin versions, Android source, Detekt config, manually copying cache binaries or building system images. Previous failed receipts preserved.
