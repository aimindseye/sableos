# SableOS current validated Panther status

Last updated: 2026-09-07

The canonical Android/Pixel base for active SableOS Pixel 7 development is now the exact signed **GrapheneOS 2026081300** Android 17 release, with audited Sable-specific deltas layered on top.

Current validated physical state:

```text
Pixel 7 / panther
Android 17 / SDK 37
BUILD_ID CP2A.260705.006
BUILD_NUMBER 2026090500
userdebug / test-keys

slot A: Graphene control, successful=yes, unbootable=no
slot B: Sable D3, successful=yes, unbootable=no
shared userdata preserved and encrypted
DUAL_KNOWN_GOOD_SLOTS=PASS
```

D3 adds the current visible Sable identity in SetupWizard/Settings and replaces the built-in fallback boot-logo mask with the Sable shield. The D3 physical deployment, AVB coupling, fs-verity downstream artifacts, live asset hashes and bootloader-authoritative slot-success state are all closed.

## Current active milestone: D4

D4 is **Sable identity + default app set + functional acceptance**. It intentionally combines the next safe branding batch, removal/dependency analysis for Graphene user-facing default applications (including the Graphene Apps/app-store client if proven removable), intentional default-app documentation, and full physical phone acceptance testing.

The first step is **D4-R0**, a read-only host/source and live-device baseline audit. D4-R0 performs no source mutation and no build. It must establish package/app provenance and capture the known-good D3 functional baseline before D4 changes are made.

Start here:

- `docs/PANTHER_D4_ROADMAP.md` — current Panther D4 scope and post-D4 release roadmap.
- `docs/PANTHER_D4_R0_PLAN.md` — exact D4-R0 read-only audit and functional-baseline plan.
- `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` — clean source/vendor/delta/build procedure.
- `docs/PANTHER_D3_VALIDATION.md` — exact D3 build/artifact/physical validation record.
- `patches/android-17-grapheneos-2026081300/` — exact text delta applicator, source/head seals, changed-file inventory and binary-asset SHA-256 manifest.

D4 minimum physical acceptance includes outgoing/incoming voice calls, outgoing/incoming SMS, cellular data and Wi-Fi. The broader target matrix also covers MMS/IMS where carrier support permits, hotspot, Bluetooth, audio, camera, location, NFC, USB, sensors, biometrics, APK install, permissions, browser/WebView, notifications, charging/power and persistence. No live emergency-services call is part of normal ROM sanity testing.

The two exact D3 binary branding inputs are `sableos_setupwizard_icon.png` and `sableos_boot_fallback_mask_448x605.png`; their required hashes are in `patches/android-17-grapheneos-2026081300/assets/SHA256SUMS`.

Historical pure-AOSP Panther bring-up records remain useful forensic evidence, but `/srv/data/aosp_panther17_workspace` is no longer the canonical SableOS Android/Pixel substrate.
