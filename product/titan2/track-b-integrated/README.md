# Titan 2 Track B — selected engineering product source

This is source integration, **not** a production/flash-ready or fully Q25-conformant product.

**Build entrypoint:** `bash build/sable.sh titan2 TB2 build --direct`. The existing full SableOS CI performs R8 and Titan app builds once, then `build/titan2/stage-track-b-product.sh` assembles the selected development product, then AOSP Soong attempts `systemimage target-files-package otatools` in the previously compiled Track B Android16 source. No standalone Gradle handoff or repeated native module tests.

## Source owners admitted to this engineering product

- `selected-apps.tsv`: ten regular, **nonprivileged** APKs from existing SableOS Gradle project outputs (Keyboard, Camera, DisplayCompat, Setup, Tools, Calculator, Media, Hub, Weather, Calendar). Generated Soong imports are `SableTB2*` with `presigned: true`; no claims of platform signature, privapp access or inherited stock app replacement.
- SableLauncher source and SableDesign source are copied **only into missing or byte-identical paths**, never overwriting the retained native34/Quickstep work. `SableLauncher` is the design-selected HOME; Launcher3QuickStep must be Recents-only after a **separate Android16 owner source integration**. Product inclusion is not sufficient to remove Quickstep's HOME intent or select default HOME at runtime.
- `sable-track-b.mk`: engineering Soong PRODUCT_PACKAGES delta and explicit IMS provider branch. The repo's pre-existing five-app C3B product graph and Track A OEM app manifest are *not* inherited wholesale.
- `ims-oem-only.mk`: existing N1I-C1 OEM IMS source slice with its prior dex/Soong/SELinux declarations, **without** dragging old C3B RadioDiag apps into Track B. Requires original pinned OEM staging and selected Android16 validation before admission.
- FLOSS selection requires an **actual** `vendor/sable/trackb13ims/selected-provider.mk`. There is no such qualified file in GitHub and no claim that it exists on ai-g732. It must be implemented from source/Soong owners, with conflicting installed IMS owners removed. `SABLE_TB2_IMS_PROVIDER=OEM|FLOSS` is required; UNSELECTED fails closed.

## Scope that is not yet complete

1. **Source promotion:** the four ai-g732 Camera/Keyboard refactor bytes are now fully committed to PR346 and their SHA256 values independently match the host's `PASS_PATCHED_4_FILES_PINNED` receipt. The prior seven real native A16 owner-source changes are **only on the host**, with completed SystemUI/Dialer compile receipts. Need to commit or export those AOSP project diffs, not recompile simply for qualification.
2. **Installed app closure:** ten source apps are staged for engineering; Q25 Reader v2, Mail, Text Reader, potentially Messages/SMS, optional games, phone/contacts/photos/browser/file/setup/clock sources remain separate owners. Q25 upstream apps TSV is a reference; source presence is not installation. Full product app selection, resource sizes and roles are unverified.
3. **Q25 framework surface:** 26 retained Q25 patch candidates have **not** been ported to the exact Android16 SystemUI/Settings/Launcher3/Files/Dialer/Browser/first-boot owners. JellyBrowser and Lineage SetupWizard paths are absent. Never apply Q25 Lineage-only contexts blindly.
4. **Privileged security:** AppLock, Vault, Freezer, Dual Apps/Private Space require real framework/profile enforcement, SELinux, granted privileged APIs and tests; Settings UI alone must not report active protection. Restricted READ_SMS, default-SMS and default HOME roles are not installed/granted.
5. **IMS:** OEM C1 and staged FLOSS source are candidates, not selected-image pass. Product source choice does not prove package signer/UID, init/mount, classpath, privapp, policy, G1/G2/G3 ELF namespace or live SIM1/SIM2 VoLTE.
6. **Whole-system image:** Soong `m systemimage` may fail before producing an image; if it succeeds, the output remains **engineering-only/incomplete** until all the above product constraints are met. Stock partition layout, AVB, release signing, restore/flash and runtime checks remain entirely out of scope.

## Validation

Previously promoted source refactor SHA256 matches (actual PR346 Git content, confirmed via independent SHA-256 implementation):

- `ControlDeck.kt`: `d5e07fe4ea57df58cb4bcbcbbb08749e67d14c80f4ff396822179e8bba02eea0`
- `CameraScreenFrame.kt`: `9d4901baff61c1f2b59dff92b613c7e61ef4a4dfb926919a84c81b08efb8cce2`
- `MainActivity.kt`: `12cd92f40e42a06141852b3b6916c0bc948a0d3e593fe07acba071359943c761`
- `HardwareKeyboardStatus.kt`: `e4cc2eddad5d36f5b4e9c2390f5fa93205d927bc25a0b8f6488087e12c43da42`

Local syntax validation `bash -n` on source-identical stage and unified-driver mirrors PASS. Synthetic product staging tests PASS for missing IMS, OEM selection+ten apps, repeat operation avoiding product graph duplication, and existing source divergence hold; fixture runtime ~0.5 s, not a native/Gradle benchmark. Actual ai-g732 Android, multi-repository Soong compile, selected G1/G2/G3, and live network/device results are **not** available in this turn.

**Status:** `PR346_SOURCE_REFRACTOR_PROMOTED_AND_ENGINEERING_PRODUCT_STAGE_WIRED`; `FULL_Q25_IMS_AND_INSTALLED_IMAGE_COMPLETE=NO`. Do not mark PR346 ready/merged or authorize flashing from this deliverable.
