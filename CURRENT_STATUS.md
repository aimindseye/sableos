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

Start here for current work:

- `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` — clean source/vendor/delta/build procedure.
- `docs/PANTHER_D3_VALIDATION.md` — exact D3 build/artifact/physical validation record.
- `patches/android-17-grapheneos-2026081300/` — exact Sable source delta and binary branding assets.
- `docs/PANTHER_D3_VALIDATION.md` also records the exact SHA-256 seals of the final state-bound validation/deployment gates.

Historical pure-AOSP Panther bring-up records remain useful forensic evidence, but `/srv/data/aosp_panther17_workspace` is no longer the canonical SableOS Android/Pixel substrate.
