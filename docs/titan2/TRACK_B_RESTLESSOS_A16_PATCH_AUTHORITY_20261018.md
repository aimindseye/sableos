# Track B RestlessOS Android 16 patch authority — upstream verification 2026-10-18

**Decision: PIN THE JUNE 23, 2026 RELEASE TAG; ALL FIVE PRODUCTION PATCH TIERS ARE THE LATEST AND UNCHANGED ON THE SUBSEQUENT ANDROID-16.2 BRANCH.**

This is a read-only upstream verification of GitHub release metadata, Git refs, full recursive Git trees, the upstream A16 build workflow, source-sync script, manifests and selected MTK/IMS/APN patches. It is **not** a claim that the ai-g732 Track B source has been synced, patched or built.

## Which published build?

The final official RestlessOS Android 16 GitHub release is:

- [RestlessOS 16.0.0-202606230923](https://github.com/cawilliamson/treble_restlessos/releases/tag/16.0.0-202606230923), published **2026-06-23 10:31:34 UTC**. The upstream releases API displayed 48 Android 16 releases and none later than this tag as of 2026-10-18.
- Mirrored upstream release directory specified by the owner: `https://build.chrisaw.io/RestlessOS-ab-16.0.0-202606230923/`.
- GitHub published asset: `RestlessOS-arm64-ab-16.0.0-202606230923.img.xz`, compressed **920,490,780 bytes**. This is a **system-only arm64-ab GSI**, not a full Titan2 stock/vendor/firmware image.
- Exact Git tag target `4adc5766f457849ca37e0b318bced65aef5a2233`, branch `android-16.2`, upstream release states GrapheneOS `2026061600`. Pinned GrapheneOS manifest commit `5d82aa9610855bc0b43b9eb7ca4470d30455cfeb`, AOSP `android-16.0.0_r4`, release configuration `bp4a` are the separately recorded canonical N1D Android16 source lock.

**Mirror qualification limit:** live content at build.chrisaw.io was inaccessible to the research environment. Upstream `.github/workflows/build.yml` at the tag uploads `RestlessOS-ab-${ANDROID_VERSION}-${BUILD_NUMBER}` image and CHANGELOG to that site **and** publishes the `.img.xz` to GitHub Releases. This supports release/directory identity; it does **not** independently authenticate the mirror asset bytes, establish mirror checksum, or prove a byte-identical local build.

## Exact patch selection and cryptographic tree authority

Inspected both `16.0.0-202606230923` (pinned release) and `android-16.2` (2026-06-24 branch HEAD `c59bdc15700992def1880e8d54ab66527c1697ba`) full non-truncated Git trees. The production patch-tier Git tree SHA-1s are **identical** at both refs:

| Apply order | Relative folder | Files | Git tree object ID (both refs) |
|---:|---|---:|---|
| 1 | `patches/trebledroid` | 198 | `2d4c06e0360940721b1518cd5359ec18f1b72296` |
| 2 | `patches/trebledroid-staging` | 121 | `9b0cf4f2e40cc1bc981457ab751d22bdb7f15957` |
| 3 | `patches/rom` | 29 | `f5b5fab4fe5b2d94e7d0f77c12e6870ed955c989` |
| 4 | `patches/personal` | 17 | `3ab4c4ed7960b72cb19d5f1b398400486adc5c3b` |
| 5 | `patches/release-builds` | 4 | `d8fd5c1c24dc2b76ba6dd6aec249b645e60543da` |
| **Total** | **Production release** | **369** | **Five pinned tier trees** |

Upstream `.github/workflows/build.yml` applies `trebledroid`, `trebledroid-staging`, `rom`, `personal` in that order, then **`release-builds` for normal user builds**. It applies `debug-builds` **instead of** `release-builds` for explicit debug builds; the debug tier must never be combined into a normal release build. The exact `patches/apply.sh` script uses `git am` or `patch -p1` against the mapped project paths, not a recursive glob over every folder.

Post-release `android-16.2` commits on 2026-06-24: `1c6308b`, `f8e9743`, `c59bdc1`. GitHub compare `16.0.0-202606230923...android-16.2` shows only two **added `patches/debug-builds/platform_device_phh_treble` files** for OnePlus OP6190L1 audio diagnostics. Debug tier expanded from **2** to **4** files; production tiers and workflow/manifest/ROM configuration were unchanged, with these additional matching Git blobs:
- `.github/workflows/build.yml` `12a11628f6ef2ae7b880908bba53aa3757d0ed63`
- `configs/manifests/default.xml` `b9a16920c7011d93c5bf1d6bd5eaa1ca2879acd0`
- `configs/manifests/remove.xml` `0bbfce1b7693e755629504fbea876ee073f2c544`
- `configs/rom/rom.mk` `7ca70d4899d33a50624d0e9b5eaf406ee6f5f4a8`
- `patches/apply.sh` `99ab897aefcb3a91c3247c4d09eec53184b9fa5d`

**Therefore:** selecting the June 23 tagged patch trees provides both the exact production release patch set and the **latest production patch content on upstream Android 16**. Do not float to the branch tip merely because its commit date is later.

## Device-relevant source evidence (present in the exact tag)

Check the following **as part of the full 369-tier control**, not as optional piecemeal cherry-picks:

- `trebledroid-staging/platform_frameworks_opt_telephony/0001-Reintroduce-TelephonyMetrics-stub-for-MediaTek-IMS.patch` (blob `7e941171a431de45c40246660efa22c37b9b1d41`): revives legacy MediaTek IMS TelephonyMetrics calls removed in Android 16. A key reason to reproduce full C3A compatibility instead of using an arbitrary AOSP GSI.
- `trebledroid/platform_frameworks_opt_net_ims/0001-Pie-MTK-IMS-calls-static-ImsManager.updateImsService.patch` (blob `4bd52062f6073f5abfb7d2661dcf3ba1f2a683e9`): legacy Mediatek IMS update API.
- `trebledroid-staging/platform_device_phh_treble/0003-Include-APN-configuration-database-in-build.patch` (blob `c0c2fa0b3f04015c03edac5d02918fd6a2f4194e`): LineageOS APN database route, **paired with** AOSP sample-APN exclusions in `rom/platform_build/0003` and `rom/platform_device_generic_common/0001`. Verify the resulting effective APN file in the compiled image; do not infer cellular attach or data registration merely from this file.
- `trebledroid-staging/platform_device_phh_treble/0001-Fix-MTK-sepolicy-errors-noticed-in-logcat.patch`: MTK vendor policy compatibility.
- `trebledroid-staging/platform_device_phh_treble/0015-Disable-restricted-networking-mode-on-BPF-less-devic.patch`: workaround for missing BPF maps; check system security consequence before any release admission.
- `trebledroid-staging/treble_app/0009-Catch-IMS-download-failures-instead-of-crashing-the-app.patch`: catches a download exception; **does not** integrate the newer FLOSS IMS service or establish IMS registration.

The tag also contains `patches/personal/treble_app/0001-Add-Unihertz-8849-hardware-controls.patch` and `patches/personal/platform_device_phh_treble/0002-Add-Unihertz-8849-SELinux-policy-and-proinfo-init-se.patch`. **Unihertz 8849 hardware is not evidence that these controls are safe or relevant to Titan 2.** They are part of the historical 369-patch control, not automatically part of a secure Sable release.

## Exact product build workflow vs reproducible SableOS Track B

The source-tag workflow:
1. dynamically fetches the current GrapheneOS stable tag (unsafe today; now Android 17), copies `configs/manifests/*.xml` and runs `repo sync`;
2. applies the five normal tiers above;
3. builds TrebleApp, copies `configs/rom/rom.mk` into `device/phh/treble` and invokes `generate.sh rom`;
4. chooses `treble_arm64_bvN-${ANDROID_VERSION_TAG}-user`, builds `systemimage`, `target-files-package` and `otatools`;
5. uses a **private** `vendor/cawilliamson-priv/keys/sign.sh` signing path; then publishes the image as `RestlessOS-arm64-ab-16.0.0-202606230923.img.xz`.

The tagged `configs/manifests/default.xml` includes `vendor/cawilliamson-priv` via SSH and **mutable revisions** such as `master`, `main`, `pie`, `android-16.0`. Thus even an exact tagged patch set is **not a complete immutable project graph**. Track B must **not** blindly execute upstream `scripts/sync-sources.sh` or its workflow, pull private vendor keys, or imply it can reproduce the manufacturer's byte-identical signed artifact.

The correct SableOS approach is a **fresh, public-only project graph** using the pinned GrapheneOS/AOSP version, exact 54 Restless remove inputs + pinned public Treble additions and a sealed `repo manifest -r` with every project HEAD pinned; preserve/compare it with C3A evidence. C3A's 991 managed project / 369-patch historical build is an exact **functional compatibility control**, not a signing-equivalent reproduction of the private release. Apply full 369 only in a separately flagged *compatibility control* build; promote any subset into Sable release/runtime only after patch-by-patch and atomic security review. Preserve no private signer or insecure default.

## FLOSS IMS scope

The exact A16 tag and the `android-16.2` branch do **not** contain the later `clangsdorff` FLOSS IMS integration patches (`frameworks_base` signature trust, `vendor_hardware_overlay` MMTEL selection, TrebleApp alternative installer). Those were introduced later on the upstream **Android 17** line. For Track B they are an independently reviewed **A16 backport/optional preinstalled source-built module**, **not** one of the 369 production patches, and not a claim that the published June 23 image already bundles FLOSS IMS.

Release pathway should retain a **pristine A16 compatibility control** and a **separate experimental FLOSS IMS composition** with explicit module/overlay/signing/IMS-service gates. FLOSS IMS addresses IMS/VoLTE integration; it cannot be assumed to fix the Titan2 data-bearer/APN problem.

## Mandatory admission gates before build-ready

1. Download/checkout the **exact Git tag commit**, not `android-16.2` HEAD or `android-17.0`, and verify **all five** tier tree IDs and counts above; verify `configs/manifests/remove.xml` and `configs/rom/rom.mk` object IDs.
2. Resolve every public Treble/GrapheneOS project to an explicit Git commit SHA; emit pinned `repo manifest -r`, project-head list and patch application receipts, and compare with the sealed C3A controls. Any missing object or unexpected patch reject: HOLD.
3. Verify resulting `treble_arm64_bvN-bp4a-user` control product, TrebleApp, effective IMS shim, APN composition, target-files and `system.img`, and exact binary metadata; no current build success is claimed.
4. Run security review of release-admitted patches (neverallow/SELinux, root/ADB, PHH remote-debug, telephony/IMS privilege), and separately qualify optional FLOSS IMS.
5. No physical device contact, partition writes, AVB edits or flash without a later explicitly authorized Titan2-specific mode/slot/restore decision.

**Current status:** `A16_RELEASE_PATCH_AUTHORITY=VERIFIED_UPSTREAM`; `LATEST_A16_PRODUCTION_PATCH_DELTA=NONE`; `LOCAL_PATCH_APPLICATION=NOT_RUN`; `TRACK_B_IMAGE=NOT_BUILT`; `FLASH_READY=NO`.
