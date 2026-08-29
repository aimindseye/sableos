# S0.7 Validation — Android 14 Vanilla Gold Master Freeze

Status: **PASS**

Baseline:
- Device family: bramble
- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Gold Master: `/srv/data/aosp_gold_master_bramble/S0-vanilla-UP1A.231105.001.B2`

Evidence:
- Compact GM audit: PASS
- GM size: 4.5G
- Target-files SHA256: `86d69608d548cdcf20b713424b156b53a87c7d667099f251eb0589403eb80549`
- Target-files integrity: PASS
- Firmware component hashes: PASS
- Build ID audit: PASS
- Identifier text audit: PASS
- Final filesystem write-bit audit: no writable paths returned
- GM sealed read-only: PASS

The compact GM preserves top-level product images, exact target-files, verified Android 14 bootloader/radio components, pinned repo manifest, repo status, the local iproute2 Android 14 compatibility backport state, vendor-tree hash inventory, validation evidence, and a complete SHA256 manifest. Proprietary blobs, firmware, images, and target-files remain local and are not committed to this repository.

Known vanilla baseline observation:
- AOSP Messaging reports `minSdk=34 targetSdk=24` on the installed Android 14 baseline and triggers Android's older-target warning.
- Physical SMS capability passed in S0.6.
- This is tracked as legacy application-stack/security debt, not as a telephony or modem failure.

S0.7 closes the vanilla Android 14 freeze. The next gate is Android 14 `oxynoded` reintegration, beginning with a read-only migration audit before any Android-12 Sable integration files are copied into the live Android 14 tree.
