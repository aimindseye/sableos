# Titan 2 dual-track clean-build handoff — 2026-10-18

**Status: HOST BOOTSTRAP PASS; BOTH FIRMWARE BUILDS NOT STARTED; FLASH NOT AUTHORIZED.**
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
| Android source sync / compile / firmware / physical device | NOT EXECUTED by bootstrap; no fresh Track A or Track B image; no flash |
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
- Read stock partition source and filesystem metadata (including EROFS/SELinux/xattrs, labels, privileges, dynamic LP sizes, signing/AVB) from exact matched inputs. OEM private signing/AVB availability is an unresolved GO/NO-GO, not a permission to disable verification or flash an unsigned image.
- Deliver **one** complete host build/qualification set: exact source and toolchain pins, signed APK package identities, executable product image and composition, metadata preservation, LP/AVB/rollback/restore report, tests and failure reasons. Avoid multiple partial release claims.

**Track A state:** source imports on PR #343 started; PR closed unmerged, stock-compatible Launcher3/Quickstep and image signing still unresolved; **no new OEM system/product image compiled or sealed**.

## Track B — N1F-derived compatibility reference, fresh Android 16 source

- Anchor GrapheneOS `2026061600` manifest SHA `5d82aa9610855bc0b43b9eb7ca4470d30455cfeb`; AOSP `android-16.0.0_r4`, SDK 36, `bp4a`; exact RestlessOS 16 release `16.0.0-202606230923` commit `4adc5766f457849ca37e0b318bced65aef5a2233`.
- Reproduce the C3A/N1F known-booting Treble source/product compatibility control **from freshly pinned public projects** and the sealed source/patch evidence. Historical C3A has 991 projects and 369 Restless patches across five tiers. Those 369 control patches are **not** a blanket production-security allowlist. Apply any release/runtime subset only via reviewed, atomic, security-qualified allowlist.
- Preserve N1F exact `system.img` as a boot-tested, five-app comparison baseline, not as a mutable build output. It does not prove present cellular data/IMS readiness. PHH Treble settings showing provider or connectivity UI does not demonstrate attached mobile data.
- Review and integrate FLOSS IMS as an **optional** built-in from pinned `clangsdorff/ims` source (historical study pin `e9e06c691953e8cdb80a230e7e7b888ee16a74de`), validating Android 16 module/overlay compatibility, signing, package privileges, service registration and conflicts with OEM/PHH IMS. The local `floss-ims-84.apk` download is **not** provenance-, signer- or SHA-qualified and is **not** admitted for blind platform deployment. FLOSS IMS is VoLTE/IMS-oriented and not a cellular APN/data-bearer fix.
- Reference [N1D source lock](N1D_ANDROID16_SOURCE_LOCK_R1.md), [Restless security boundary](N1D_RESTLESS_SECURITY_BOUNDARY_R1.md), and [N1F boot result](N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md). Never execute upstream Restless dynamic 'latest stable' sync or depend on private `vendor/cawilliamson-priv`; reject mutable `main`/master refs in the pinned Android manifest.

**Track B state:** workspace + canonical local checkout only; Android 16 source sync, patches, IMS module compile, signed build, full GSI/ROM qualification and device tests all OPEN.

## Single next integrated implementation boundary

1. Reconcile local/remote canonical source HEAD, target branch and retained PR #343 diff before any new build. Pin exact Git objects and the tools available on ai-g732. Resolve open source authority and no-private-repo dependencies.
2. Establish Track A OEM and Track B public-only Android 16 source graphs independently and seal their manifests. Build from the new roots; do not resurrect retired `titan2-n1d*` directories.
3. Produce a real full-image artifact **for each track** with one consolidated host-side qualification record, including Python/Bash syntax/regressions, resource/performance checks, package/partition/AVB/runtime constraints, security differences and precise blocker classification.
4. Require **separate explicit owner authorization** for device inspection and any one-shot mode-aware Titan 2 flash/restore procedure. No `fastboot flashall`, implicit slot/mode assumptions, OEM signature bypass or automatic retry. Keep C3A and N1F independently boot-qualified as rollback/reference images.

## PR and ownership ledger

- [PR #343](https://github.com/aimindseye/sableos/pull/343): Track A historical source work; **CLOSED UNMERGED**. Reference only, not active source authority.
- [PR #342](https://github.com/aimindseye/sableos/pull/342): Oct 11/13 N1F-M4 IMS evidence and recovery diagnosis; **OPEN DRAFT**, not a new Track B build or flash authorization.
- `sableos-project/platform_sable`: shared design/portability/interaction contracts, not owner of Titan 2 OEM partition source, vendor IMS or flash tooling.
- Panther frozen touch-first acceptance, Q25 and other R8 applications remain unaffected.

**Guardrails:** `TRACK_A_BUILD=NOT_RUN`, `TRACK_B_BUILD=NOT_RUN`, `SOURCE_SYNC=NOT_RUN`, `DEVICE_CONTACT=NO`, `FLASH=NO`, `PRODUCTION_SIGNING=NOT_AUTHORIZED`.
