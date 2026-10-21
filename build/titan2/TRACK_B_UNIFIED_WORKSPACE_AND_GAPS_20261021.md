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
- One canonical call does full local CI, both Gradle project groups (keyboard/camera/setup/tools on Gradle 8.14.3; Hub/Messages/Calendar on Gradle 8.13; assembleDebug, JVM unit tests, lint, detekt, ktlintCheck), and AOSP `m systemimage target-files-package otatools`. Collects **all stage failures**, unique evidence, SHA256 logs. No device, ADB, fastboot, signing, flashing or release acceptance.
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
