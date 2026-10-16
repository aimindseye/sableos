# Track A OEM Android 16 — broad SableOS import and firmware image

**Status: source integration underway; actual image NOT BUILT, flash NOT AUTHORIZED.**

This branch is the implementation lane for the owner's Track A choice: **unmodified Unihertz Titan 2 Android16 V01.00.14 telephony, vendor and firmware below a complete SableOS experience**. Generic Treble GSI image builds are not this lane. Do not reinterpret the five stock-installed debug apps as OEM image completion.

## Actual implementation in this branch

- Import the 47-file Sable Tools module (Kotlin Android, resources, unit tests, module Gradle config), verbatim from `aimindseye/zinwaq25-sableos@e9bed8cec9da387301dc6a0124b22b28615f5f31`, into **canonical** `apps/titan2/platform/tools/`.
- Enable `:tools` alongside the existing Titan2 platform apps using the canonical Gradle root, with no changes to shared Gradle/plugin/toolchain pins.
- Define the **13 included, 3 optional, 2 excluded** portable product applications in `product/titan2/track-a-oem16/apps.tsv`. Three games are optional until stock product-partition fit is measured; the inactive Messages app is a demo, and RadioDiag is superseded by Tools.
- Q25's 19 source patch sets, Reader v2, Sable Hub source dock, and proposed OEM adaptations remain to be reconciled; do not silently overwrite canonical sources with the Q25 snapshot imported from Oct09.

## Platform integration contract

- **Immutable baseline inputs:** the matched stock `TEE14-large-reference` under `stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence`, not an arbitrary firmware ZIP. SHA256: `system.img b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd`; `system_ext.img 1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170`; `product.img de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37`; `vendor.img cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada`.
- Stock `Phone`, `CarrierConfig`, `com.mediatek.ims`, SMS provider and stock messaging, RIL/vendor/modem, camera HAL, original signed framework and hardware stack **remain authoritative**. The stock-app control already passed post-install LTE/data/calls/messaging.
- Canonical current HOME is **Sable Start hosted by Launcher3QuickStep** (`docs/CURRENT_HOME_AND_C3B_INTEGRATION_AUTHORITY.md`). Q25 instead revives standalone `SableLauncher` by patching LineageOS Quickstep. **Never carry that patch unmodified to Unihertz stock**, where source/production certificates are unavailable. Preserve stock HOME and Recents fallback until a supported OEM-compatible Sable Start path is actually built.
- Sable Keyboard may become the default only with stock IME fallback and emergency/pairing/password text entry preserved. Q25's "only IME" behavior is not imported.
- Q25 Settings, SystemUI, SetupWizard, Contacts, Dialer, Files, Browser, Photos modifications are **LineageOS source patches**; OEM .apk cannot be patched using `git apply`. Supported signed/RRO or source-independent functionality must be implemented separately, with any blocked features labeled.
- Q25 `AppLockPolicy` is not enforced; Hub does not prove default SMS ownership; OEM `platform` signature permissions and Private Space APIs cannot be granted with an engineering key. No claim of implemented controls without actual enforcement.
- No Q25 keylayout, kernel, partition geometry, boot scripts, firmware, proprietary blobs or signing keys may be imported to Titan2.

## One consolidated build/flash boundary, no micro-gates

The next output **must be a genuine stock-derived partition image** including the broad set and meaningful SableOS system integration, not a loose APK bundle. Build host (ai-g732) must retain exact OEM filesystem metadata/SELinux labels and verify dynamic partition size, stock AVB chain, signing and rollback in ONE host build+qualification, with no generic-GSI image mixing. If production OEM signing or safe product partition recomposition is unavailable, report explicit HOLD rather than falsely labeling a repack as a flash-ready firmware image.

Physical flashing/AVB changes require separate authorization after the actual image exists and the exact Titan 2 mode/slot/snapshot/restore pathway is resolved; no generic `fastboot flashall`. One postflash acceptance session checks Sable Start/Recents/IME, complete Sable app set and OEM phone, SMS/MMS, mobile data, IMS/VoLTE, Wi-Fi, BT/NFC, sensors, camera, charging, both SIM trays and recovery. Prior GSI/boot work remains recorded in PR342 but is **not** Track A.

## Validation truth

The Q25 app CI passed at its Oct15 head; **this canonical merged source has not yet undergone a Gradle build**, and there is **no OEM image in this PR**. The user wants delivery over audits; do not introduce serial preview/preflight micro-gates. 
