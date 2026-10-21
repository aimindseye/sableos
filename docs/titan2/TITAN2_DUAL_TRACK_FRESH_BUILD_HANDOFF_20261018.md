# Titan 2 dual-track clean-build handoff — 2026-10-18

**Status: HOST BOOTSTRAP PASS; TRACK A OEM-DERIVED ENGINEERING PRODUCT EROFS BUILT WITH 13 VERIFIED APK SIGNATURES; COMPLETE OEM FIRMWARE, NATIVE QUICKSTEP AND TRACK B IMAGE NOT BUILT; FLASH NOT AUTHORIZED.**
**Scope:** Titan 2 Android 16 only. This is the current operator-provided state, not a SableOS release or a qualification of firmware.

## Evidence and source-of-truth precedence

Operator logs on ai-g732, 2026-10-18:

| Check | Observed result |
|---|---|
| Legacy workspace retirement | `/srv/sable-build/workspaces/titan2-n1d` and `titan2-n1d-c3b` absent; retirement record `/home/mindseye73/titan2-retirement-20261018T142229Z` |
| Build filesystem after retirement | 3.6T total, 1.7T used, 2.0T available, 47% used (rounded `df -h`) |
| C3A control image | `/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z/system.img`; SHA-256 `4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16`; operator `sha256sum -c` PASS |
| N1F control image | `/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img`; SHA-256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`; operator `sha256sum -c` PASS |
| Dual-track bootstrap V1 | SHA-256 package check PASS; 16 hermetic tests PASS; `prepare` PASS; local `checkout-sable` PASS in both workspaces |
| Bootstrap checkouts | Both local SableOS checkouts HEAD `177ef4fb76d661725165c5224f6a8495b2b420ec`; **not** current GitHub `main` at review (`12e9793627babd0294a0022d8644360bc7727f6c`). Do not build until source authority is refreshed and pinned. |
| Android source sync / compile / firmware / physical device | NOT EXECUTED by bootstrap. Later, a genuine Track A engineering product-only EROFS was rebuilt on-host from verified historical image/PAX; no native stock Android source/Launcher3 build, whole firmware, device contact or flash |
| Track A V1.3 engineering image, operator 2026-10-18 | **PASS_HOST_BUILD_NONFLASH** — `NOT_FLASH_READY_SIGNED_13_APPS_PRODUCT.erofs.img`; SHA-256 `fcd1bd62f4259222084fc9651186925cc42b59eb530f9cee66dfcbb4fa36dc45`; 13/13 APK signatures (10 newly engineering-signed + three retained), PAX stock 462/462 members copied, `mkfs.erofs` and `fsck.erofs` build+extract completed; report `ENGINEERING_RESULT.json`. Full post-build independent inode/xattr comparison and AVB/LP/live-device boot NOT claimed. |
| Q25 | Not accessed or mutated by bootstrap or retirement. Keep untouched. |

The bootstrap's `verify` was invoked with output redirected to `~/titan2-dual-track-verify-v1.json`, but that JSON was not supplied. No claim is made about its individual toolchain checks.

Historical evidence is preserved at `/srv/sable-build/evidence/titan2/` and the separate stock-firmware, C3A and N1F artifact stores. Previously designated legacy cleanup candidates are not claimed purged unless a real purge receipt exists. No inference of device readiness follows from workspace cleanup.

## Workspaces and isolation contract

| Track | Root | Purpose |
|---|---|---|
| A V2 | `/srv/sable-build/workspaces/titan2-track-a-v2` | OEM V01.00.14-preserving, integrated Android 16 SableOS |
| B | `/srv/sable-build/workspaces/titan2-track-b` | Independent Android 16 Treble/RestlessOS build, N1F compatibility reference and optional FLOSS IMS |

Each track owns its own source checkout, Android `out`, app outputs, Gradle home, build logs and image manifests. Retained `/srv/sable-build/sableos/repo` is an authority source, not an output directory. Shared pinned read-only host SDK/JDK/tools are permitted. **Never invoke the Q25 build driver, source `~/.q25env`, or touch `/srv/sable-build/workspaces/q25`.** The two retired `titan2-n1d*` build directories are not dependencies.

## Track A V2 — OEM-preserving integrated product

**Baseline:** exact Unihertz Titan 2 V01.00.14 TEE14 stock reference partition images described in [Track A source integration contract](https://github.com/aimindseye/sableos/blob/track-a-oem16-q25-full-product-20261016/docs/titan2/TRACK_A_OEM16_Q25_INTEGRATION_V1.md) and the [closed, unmerged PR #343](https://github.com/aimindseye/sableos/pull/343). For the OEM partition hashes and app matrix, read `docs/titan2/TRACK_A_OEM16_Q25_INTEGRATION_V1.md` *on PR #343's historical branch*, not as if it were merged.

- Fresh source authority: remote canonical SableOS `main`, after explicitly pinning the intended commit and importing/reviewing required PR #343 changes; no silent branch replacement. The 13 required apps, three optional games, OEM-compatible Sable Start/HOME + Recents, Setup, keyboard and other system surfaces form one integrated build target, not a loose APK bundle.
- Preserve OEM Phone, SMS/MMS, CarrierConfig, `com.mediatek.ims`, framework/vendor/modem, proprietary camera and firmware; retain stock HOME/IME fallbacks until replacement is proven. Do **not** transplant LineageOS Q25 framework/Quickstep patches, keys, kernel or partition geometry.
- Read stock partition source and filesystem metadata (including EROFS/SELinux/xattrs, labels, privileges, dynamic LP sizes, signing/AVB) from exact matched inputs. The original Titan 2 is reported unlocked/ORANGE: proprietary OEM production-signing keys are **not required merely to run a separately authorized engineering experiment**. APK package signing and a demonstrably compatible engineering AVB/hashtree/product verification strategy remain open host/flash GO/NO-GO requirements; production OEM keys/release acceptance are a separate boundary. Never disable verification by assumption or flash an unqualified image.
- Deliver **one** complete host build/qualification set: exact source and toolchain pins, signed APK package identities, executable product image and composition, metadata preservation, LP/AVB/rollback/restore report, tests and failure reasons. Avoid multiple partial release claims.

**Track A state (2026-10-18):** The real ai-g732 `TITAN2_TRACK_A_ENGINEERING_IMAGE_V1_3` host run **BUILT** an OEM-derived *product-only* signed-app engineering EROFS at `/srv/sable-build/workspaces/titan2-track-a-v2/dist/track-a-oem16-signed-app-product-20261018T155147318439Z/NOT_FLASH_READY_SIGNED_13_APPS_PRODUCT.erofs.img` (SHA-256 `fcd1bd62f4259222084fc9651186925cc42b59eb530f9cee66dfcbb4fa36dc45`). `APK_VERIFIED=13/13` including 10 locally engineering-signed APKs and three previously signed APKs; metadata-source PAX stock members 462/462 retained; PAX-content consistency, EROFS `mkfs`, fsck and extraction succeeded. The original 13-app P10 image and quarantine evidence remain immutable. **Independent post-build inode/xattr inspection, new-app enforcing policy, product AVB hashtree/LP/COW/restore and physical boot remain unqualified.** This does not implement native OEM Launcher3QuickStep Sable Start or a complete OEM firmware/OTA. PR #343 stays closed unmerged and its source imports are not automatically adopted. OEM production keys were **not required** to create this host engineering image.

### October 18 completed Track A host admission and AVB/metadata identity

**Freeze and reuse the existing build, do not re-sign or rebuild on this evidence alone.** Exact final signed-app engineering EROFS SHA-256 `fcd1bd62f4259222084fc9651186925cc42b59eb530f9cee66dfcbb4fa36dc45` at `/srv/sable-build/workspaces/titan2-track-a-v2/dist/track-a-oem16-signed-app-product-20261018T155147318439Z/NOT_FLASH_READY_SIGNED_13_APPS_PRODUCT.erofs.img` (3,162,714,112 bytes). Real owner host admission PASS: all 462 stock content/link paths, 13/13 installed APK signatures, 26 new app entries and archived April LP arithmetic; `flash_ready=false`.

**Actual `TRACK_A_INTEGRATED_REPORT.json` reviewed:** `/srv/sable-build/workspaces/titan2-track-a-v2/avb-metadata-integrated/track-a-v1-20261018T163909914944Z/TRACK_A_INTEGRATED_REPORT.json`. Exact current image versus matched TEE14 original `product.img`: **462/462 UID/GID/mode and full raw xattr name/value semantics equal, semantic mismatch count 0**; 452 xattr-storage-size differences are layout differences only. **All 26 new Sable `app/` directory/APK entries** have `uid=gid=0`, directory 0755 / regular APK 0644, `security.selinux=u:object_r:system_file:s0`—explicitly **PROVISIONAL, not approved Android enforcing/privapp policy**, and not proof of OEM signature/role grants.

**Image growth explained at filesystem-feature level:** P10 2,010,750,976 B `feature_incompat=0x1`, `is_compressed_field=65535`; final 3,162,714,112 B `feature_incompat=0x0`, `is_compressed_field=0`; V1.3 did not pass an explicit compressor flag. Difference **1,151,963,136 B**. Current final image's 1MiB-aligned dynamic product allocation **3,163,553,792 B** yields **4,137,246,720 B historical free** in archived `main_a`, but **NO live LP/group/snapshot/COW admission**.

**Three matched V01.00.14 stock AVB images verified, not missing** from the original April TEE archive `2026042212_g71v78c2k_dfl_tee.zip`:
- root `vbmeta.img` 8192 B SHA256 `58db651a312f3f3f350d11142de55f8c37e1394f1ecea870e6b97a5ae7e0edac`; direct hashtrees **odm_dlkm, product, system_dlkm, system_ext, vendor_dlkm**; chains **boot, vbmeta_system, vbmeta_vendor**;
- `vbmeta_system.img` 4096 B SHA256 `4dda8ebc659f2e1db9fdf2977a16224521b738e74ced387caa2bab9f7dfede7e`; direct `system` hashtree;
- `vbmeta_vendor.img` 4096 B SHA256 `5d01ab8a94fcf642d8197a759394541d2aa4689858d8f92283a808ea6f5ca9b7`; direct `vendor` hashtree.

The stock root `product` descriptor **does not demonstrate authentication of this changed image**. OEM production signing keys were **not** required for 13 engineering APK signatures, but a device-compatible engineering `product` AVB/hashtree strategy (including the other root descriptors/chains and rollback policy) is an **unresolved physical-boot prerequisite**. Never copy root vbmeta onto chained images, blind-disable AVB, or assume a successful earlier `system_a` flash qualifies `product_a`.

**Next single integrated phase:** (1) bind canonical Titan2 flash-regression/restore driver and existing eight-image matched-stock recovery corpus without executing any writes; (2) obtain *separately authorized read-only present-device* mode-aware exact-slot/LP/VAB/snapshot/COW/rollback evidence and verify the original product/vbmeta chain's deployment constraints; (3) decide legitimate engineering AVB trust route for this exact frozen image, with a documented stock restoration path; (4) only then request a new one-time explicit product boot-experiment authorization. Independently complete stock OEM Launcher3QuickStep-hosted Sable Start and review of app contexts/role behavior before claiming the full SableOS product experience. Existing `build/devices/titan2.sh` and `build/deploy/flash.sh` remain fail-closed for generic Titan2/product flashing. **No current device-contact/flash authorization is implied here.**

## Track B — N1F-derived compatibility reference, fresh Android 16 source

**Upstream release/patch authority verified 2026-10-18:** [RestlessOS Android 16 exact 369-patch tree audit](TRACK_B_RESTLESSOS_A16_PATCH_AUTHORITY_20261018.md). The June 23 `16.0.0-202606230923` tag is the final official published A16 release; the three following `android-16.2` commits add only debug-build audio diagnostics, with all five production patch Git trees unchanged. Track B must pin the release tag and its five production-tier tree hashes, not float to the branch tip. The official mirror could not be independently byte-checked here.


- Anchor GrapheneOS `2026061600` manifest SHA `5d82aa9610855bc0b43b9eb7ca4470d30455cfeb`; AOSP `android-16.0.0_r4`, SDK 36, `bp4a`; exact RestlessOS 16 release `16.0.0-202606230923` commit `4adc5766f457849ca37e0b318bced65aef5a2233`.
- Reproduce the C3A/N1F known-booting Treble source/product compatibility control **from freshly pinned public projects** and the sealed source/patch evidence. Historical C3A has 991 projects and 369 Restless patches across five tiers. Those 369 control patches are **not** a blanket production-security allowlist. Apply any release/runtime subset only via reviewed, atomic, security-qualified allowlist.
- Preserve N1F exact `system.img` as a boot-tested, five-app comparison baseline, not as a mutable build output. It does not prove present cellular data/IMS readiness. PHH Treble settings showing provider or connectivity UI does not demonstrate attached mobile data.
- Review and integrate FLOSS IMS as an **optional** built-in from pinned `clangsdorff/ims` source (historical study pin `e9e06c691953e8cdb80a230e7e7b888ee16a74de`), validating Android 16 module/overlay compatibility, signing, package privileges, service registration and conflicts with OEM/PHH IMS. The local `floss-ims-84.apk` download is **not** provenance-, signer- or SHA-qualified and is **not** admitted for blind platform deployment. FLOSS IMS is VoLTE/IMS-oriented and not a cellular APN/data-bearer fix.
- Reference [N1D source lock](N1D_ANDROID16_SOURCE_LOCK_R1.md), [Restless security boundary](N1D_RESTLESS_SECURITY_BOUNDARY_R1.md), and [N1F boot result](N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md). Never execute upstream Restless dynamic 'latest stable' sync or depend on private `vendor/cawilliamson-priv`; reject mutable `main`/master refs in the pinned Android manifest.

**Track B state:** workspace + canonical local checkout only; Android 16 source sync, patches, IMS module compile, signed build, full GSI/ROM qualification and device tests all OPEN.

## Single next integrated implementation boundary

1. Reconcile local/remote canonical source HEAD, target branch and retained PR #343 diff before any new build. Pin exact Git objects and the tools available on ai-g732. Resolve open source authority and no-private-repo dependencies.
2. Establish Track A OEM and Track B public-only Android 16 source graphs independently and seal their manifests. Build from the new roots; do not resurrect retired `titan2-n1d*` directories.
3. **Reuse, do not rebuild** the Track A signed-app engineering product EROFS identified above. In a single consolidated OEM Android16 image/host-to-device admission workstream, close post-build independent metadata/SELinux review, stock `product` AVB hashtree trust, dynamic LP/Virtual A/B COW and matched restore; separately integrate stock-compatible Launcher3QuickStep-hosted Sable Start before representing the full OEM product as complete. For Track B, produce the first real full-image artifact from pinned A16 public sources, with one consolidated qualification record.
4. Require **separate explicit owner authorization** for device inspection and any one-shot mode-aware Titan 2 flash/restore procedure. No `fastboot flashall`, implicit slot/mode assumptions, OEM signature bypass or automatic retry. Keep C3A and N1F independently boot-qualified as rollback/reference images.

## PR and ownership ledger

- Shared public-platform coordination PR: [sableos-project/platform_sable #54](https://github.com/sableos-project/platform_sable/pull/54), documentation-only; no cross-repository source or BSP inheritance.


- [PR #343](https://github.com/aimindseye/sableos/pull/343): Track A historical source work; **CLOSED UNMERGED**. Reference only, not active source authority.
- [PR #342](https://github.com/aimindseye/sableos/pull/342): Oct 11/13 N1F-M4 IMS evidence and recovery diagnosis; **OPEN DRAFT**, not a new Track B build or flash authorization.
- `sableos-project/platform_sable`: shared design/portability/interaction contracts, not owner of Titan 2 OEM partition source, vendor IMS or flash tooling.
- Panther frozen touch-first acceptance, Q25 and other R8 applications remain unaffected.

**Guardrails:** `TRACK_A_BUILD=NOT_RUN`, `TRACK_B_BUILD=NOT_RUN`, `SOURCE_SYNC=NOT_RUN`, `DEVICE_CONTACT=NO`, `FLASH=NO`, `PRODUCTION_SIGNING=NOT_AUTHORIZED`.
