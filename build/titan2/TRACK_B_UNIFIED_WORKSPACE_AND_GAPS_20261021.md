# Track B unified build source: reuse ledger and incomplete work (2026-10-21)

**Goal:** one PR346 Sable source checkout and the existing Android16 Track B checkout, invoked through `bash build/sable.sh titan2 TB2 build --direct`. No more detached module quality handoffs. This change wires a build-only path; it does **not** claim the Q25/IMS merge or selected product graph is complete.

## What is actually already done

- Host `android/`: Phase12 7 Android16 promoted sources, real SystemUI/Dialer compile PASS; Phase13 frozen source and combined receipts PASS. Do not replay/recompile these simply to create another gate.
- Host `q25-app-quality-pr346-257a037e88f2/`: detached pinned PR346 source, **four modified/new Camera/Keyboard files applied uncommitted** and SHA verified (`PASS_PATCHED_4_FILES_PINNED`). Must promote those four file contents to this PR346 branch; do not reset the detached worktree.
- Host `native34-postbuild-receipts/`, `tb2-native34-module-out-*`, `tb2-native34-module-receipt-*`, `tb2-q25-nextslice-module-out-*`, `tb2-q25-nextslice-module-receipt-*`: historical APK/DEX/CRC/module evidence, not to be repeated.
- Host `q25-ims-conformance-receipts/`: reuse source/static IMS and Q25 evidence, but does not establish new selected-image G1/G2/G3.
- Host `out-integrated-13-floss-ims/` and `out-integrated-13-floss-ims-retained-v110-conflict/`: retain; the latter is explicitly conflicting. Never install FLOSS and OEM providers together blindly.
- Host `TRACK_B_C3A_REPLAY.json`, `TRACK_B_MANIFEST_LINK_REPAIR.json`, `track-b-active-manifest-for-links.xml`, `track-b-prepatch-heads.tsv`, `track-b-postpatch-heads.tsv`, `track-b-*logs`: reuse prior checkout/manifest evidence rather than re-syncing and replaying source.
- Host `tb2-sable/` is the likely existing Sable source checkout; verify its actual branch/HEAD before updating. `bb10-module-trials/`, `source/`, `inputs/`, `dist/`, `config/`, `evidence/`, `logs/`, `out/`, `scratch/`, `cache/` need content-level review before considering anything missing. Their names alone prove no build pass.

The directory listing is supplied by the owner; this environment cannot read those ai-g732 filesystem contents directly. The PASS statements above come from **prior actual operator logs** in this project, not from the directory listing.

## Cross-PR provenance

- PR342: historical IMS source, ABI, LP/AVB and runtime debugging; M4 did not boot Android. Selected Track B provider closure unproven.
- PR343 closed Track A OEM product experiment: 131 changed paths, 128 pathnames overlap PR346's 206. Selected Hub and Gradle files have identical blobs. Only Track A-specific pathnames not already changed by PR346 are two engineering documents and `product/titan2/track-a-oem16/apps.tsv`. OEM manifest is **reference only**, not a product makefile to import into A16 GSI.
- PR344: dual-track source and custody handoff (documentation), not missing implementation code.
- PR345: Sonar CI-only, not native/system image proof.
- PR346: actual Q25 app source and **26 upstream framework patch candidates**; source presence does not prove Android16 applicability, privilege, selected product installation or IMS closure.

## Newly committed consolidated build plumbing

- `build/devices/titan2.sh` supports release `TB2` for **build only**, calling `build/titan2/run-track-b-integrated.sh`.
- One canonical call runs **existing full local CI once**, which already handles R8 Hub/Messages/Calendar plus the remaining R8 applications, and now incorporates Titan 2 `displaycompat/keyboard/camera/setup/tools` assembly/unit-test/lint/detekt/ktlint tasks in that same CI run; afterward it runs AOSP `m systemimage target-files-package otatools`. The parent driver preserves CI and AOSP failures in one unique evidence location and SHA256 logs; there is no duplicate R8 Gradle pass. No device, ADB, fastboot, signing, flashing or release acceptance.
- `N1B2` stays `AUDIT_ONLY_FAIL_CLOSED`; original `N1I` path and flash policies are unchanged.
- `SetupReader.kt` now uses the read-only SDK `Settings.Secure.getInt` with literal `user_setup_complete` setting key; this addresses the observed compiler missing-public-constant error, **not yet proven by real post-merge compilation**.

## Important unmerged features (not fake gate PASSes)

1. Promote four host-only Camera/Keyboard refactor files to PR346; promote seven A16 native source edits into their actual AOSP Git project branches, preserving pinned hashes/Soong context. The GitHub Sable source alone cannot contain a full 991+ AOSP manifest checkout.
2. Port 26 Q25 patches to real A16 owners, not LineageOS filenames: `packages/apps/Jelly` and `packages/apps/SetupWizard` are absent. Finish shade/QS/lock, Browser/Files, Settings, Phone/Dialer/Contacts/Camera and actual setup/Hub integration.
3. Resolve **SableLauncher HOME + Quickstep RECENTS-only** (platform_sable design, older N1B2 driver) versus **Launcher3QuickStep HOME + Recents** (current Track B README); select and implement one product role contract.
4. Implement privileged enforcement for AppLock, Freezer, Vault, Android Dual/Private profiles, hardRestricted READ_SMS, role/privapp/SELinux grants; UI controls alone are not enforcement.
5. Choose one effective OEM C1 or FLOSS IMS provider from existing stage candidates, complete installed package/JAR/UID/cert/classpath/SELinux and ELF/linker G1/G2/G3, then eventually SIM1/SIM2/VoLTE live qualification.
6. Bind **all included Sable APKs** and feature modules into selected AOSP makefiles/Soong product graph. Today's `m systemimage` can produce an **incomplete GSI** if this wiring is not finished. OEM stock Track A product manifests cannot be copied blindly. Signing/AVB/LP/flash still separate.

## Last real quality evidence

`TB2_Q25_TITAN2_GRADLE_ONLINE_QUALITY_20261021.log` SHA256 `6b5f1d431dea9c0005d7c2e392aa8194a20b999c6f757bd351846a439b9aca73`: Gradle got through dependency/cache blockers but `:setup:compileDebugKotlin` failed on `Settings.Secure.USER_SETUP_COMPLETE` in `SetupReader.kt`. No seven-app PASS. Do not launch another detached Gradle acceptance package.

**Disposition:** `BUILD_ENTRYPOINT_WIRED_ONLY`; source/product not converged and image/flash not qualified. No `sable.sh TB2` host execution is claimed in this commit.


## 2026-10-21 direct source-promotion and 13-app selected-product integration update

- **Completed in this branch:** the previously ai-g732-applied four Camera/Keyboard source changes were reconstructed from the original pinned script and committed directly, without repeating any Gradle/module quality gate. Remote GitHub SHA256 contents were independently checked byte-exact against host source receipt: ControlDeck `d5e07fe4ea57df58cb4bcbcbbb08749e67d14c80f4ff396822179e8bba02eea0`, CameraScreenFrame `9d4901baff61c1f2b59dff92b613c7e61ef4a4dfb926919a84c81b08efb8cce2`, MainActivity `12cd92f40e42a06141852b3b6916c0bc948a0d3e593fe07acba071359943c761`, HardwareKeyboardStatus `e4cc2eddad5d36f5b4e9c2390f5fa93205d927bc25a0b8f6488087e12c43da42`.
- **Real source build wiring:** `product/titan2/track-b-integrated/sable-track-b.mk` declares the 13 included Track A/Q25 apps (nonprivileged) and SableLauncher, with explicit OEM vs FLOSS IMS branch. `build/titan2/stage-track-b-product.sh` is called from the canonical TB2 `sable.sh` build after existing full CI, before AOSP Soong; it consumes the ten stable APK outputs plus the pinned Reader/Mail/TextReader outputs **already built by full CI** in its cache, validates package IDs and signing classes, generates the selected AOSP app imports, stages matching SableLauncher/SableDesign sources, inserts the product include once and refuses to overwrite differing pre-existing AOSP source. `ims-oem-only.mk` excludes C3B RadioDiag while retaining N1I-C1 prior IMS declared module/JAR/classpath/SELinux source scope. Neither option claims qualified IMS; no new detached app build loops.
- **Design authority:** SableLauncher HOME + Quickstep Recents-only is selected by platform_sable and the upstream Q25 design. Source-only docs reflect that architecture; actual A16 Quickstep HOME role removal/default HOME selection still OPEN.
- **Validation:** source-identical script mirrors vs GitHub blob SHA1, both Bash `bash -n` PASS, 13-app local fake-package fixture PASS for provider refusal/no-write, correct signing and product stage, idempotence and preserved native source conflict (~0.8s); GNU Make syntax OEM/FLOSS 14 module names and UNSELECTED fails as designed. Mock fixture timing is not Gradle/AOSP performance. **No real merged ai-g732 AOSP build executed**.
- **Still incomplete:** actual host seven native A16 source edits need corresponding AOSP project commits and complete source-graph custody; full 26 Q25 candidate patch adaptation to actual Android16 SystemUI/Settings/Files/Browser/Setup/Phone/Contacts owners; security privileges/profiles; hardRestricted SMS role; installed default HOME and no duplicate Quickstep HOME; selected single effective OEM/FLOSS provider provenance + installed-image G1/G2/G3 and eventual SIM1/2 VoLTE; full image and AVB/restore. Source prep and manifest receipts under workspace remain preserved without replay.

This supersedes the earlier claim in this document that the four Camera/Keyboard changes still await PR promotion. `PRODUCT_SOURCE_STAGE_IMPLEMENTED_13_INCLUDED_APPS` is not `FULL_ANDROID16_Q25_IMS_PRODUCT_COMPLETE`.
