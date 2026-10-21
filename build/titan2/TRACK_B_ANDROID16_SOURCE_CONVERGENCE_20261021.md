# Titan 2 Track B — exact Android 16 source convergence (source-only deliverable)

**Status:** `SOURCE_CONVERGENCE_TOOLING_COMMITTED`; `AOSP_HOST_COMMITS=PENDING_AI_G732_EXECUTION`; `Q25_PRIVILEGED_AND_IMS_RUNTIME=OPEN`; `IMAGE_FLASH=NOT_AUTHORIZED`.

This implementation supersedes the older duplicate-import proposal in `product/titan2/track-b-integrated/{selected-apps.tsv,sable-track-b.mk}`. These remain **nonactive historic candidates**. The **actual** Track B device product already inherits:

```make
$(call inherit-product, vendor/sable/trackb13ims/track-b.mk)
$(call inherit-product, vendor/sable/tb2-rebuilt/tb2-product.mk)
```

The latter selects 13 `TB2Sable*` app imports, whose existing prebuilt files are present. The former selects `PhhIms`, `PhhImsOverlay`, `Iwlan`, `QualifiedNetworksService` and installs the PHH IMS privileged-permissions XML. There is **no** evidence requiring an OEM provider switch or another `SableTB2*` app install set. Service registration, G1–G3, physical SIM/VoLTE and actual APK package/signature validations are not implied by makefile/source names.

## One coordinated source-only workflow

The canonical PR346 source now contains:

- `build/titan2/stage-track-b-product.sh`: `--plan` reads and SHA-binds the real existing product (`tb2-apps.mk`, `tb2-rebuilt/Android.bp`, FLOSS `track-b.mk`, PHH XML, initial ROM and Launcher3 manifest) and all 13 existing APK filenames. `--apply` copies already-committed `SableStart` + `sabledesign` source into previously missing or byte-identical Android16 paths, removes one Launcher3 HOME category with the **exact original source patch**, and adds only `PRODUCT_PACKAGES += SableLauncher` to active `rom.mk`. **Never** imports duplicate 13 apps, OEM C1, additional FLOSS provider or changes the existing stock/IMS makefile includes.
- `build/titan2/commit-exact-aosp-projects.sh`: exact **Phase13 compiled seven-file hashes**, exact pinned four AOSP Git HEADs, no staged index changes and unused new branch names verified before commits. Commits **three** SystemUI source paths in `frameworks/base`, **four** Dialer paths in `packages/apps/Dialer`, **one** Launcher3 manifest in `packages/apps/Launcher3`, and the **one** new Treble product `rom.mk` in `device/phh/treble`, on distinct local `tb2-20261021-*` branches. `git commit --only` limits each commit to the selected paths. It does not reset or clean any existing work. No GitHub push or repo sync. Host-specific new commit IDs cannot be known until ai-g732 executes it.
- `build/titan2/converge-track-b-source.sh`: single `--plan` or explicitly acknowledged `--commit CONVERGE_TB2_EXACT_A16_PROJECTS` entrypoint. The commit path checks product source and **all seven native source hashes plus all four base HEADs before AOSP mutation**, stages SableLauncher HOME, verifies all nine post-convergence file hashes, then commits the exact four project paths. No rebuilding Phase12/13 modules or standalone quality operators.

`build/titan2/run-track-b-integrated.sh` is now **build-only**: it calls the product stage in `--plan` mode, and refuses to start AOSP image build unless the separate source-only convergence has already installed the SableLauncher HOME source and product inclusion. CI still runs once and can fail; this is not an image-ready assertion.

## Exact project base HEADs (owner's Oct 21 source handoff)

| AOSP project | Original HEAD | Intended new local branch | Source changes |
|---|---|---|---|
| `frameworks/base` | `68987f742a5c810a418465610ae6be8f789d6451` | `tb2-20261021-native-systemui` | 3 existing Phase13 SystemUI compiled sources |
| `packages/apps/Dialer` | `6420032cfcab41a1547bcabb0da73bb0894d2c21` | `tb2-20261021-native-dialer` | 4 existing Phase13 Dialer compiled sources |
| `packages/apps/Launcher3` | `a22dcd457286f15f1ab1733bd3eb14a9386e0be4` | `tb2-20261021-launcher-recents` | 1 HOME intent category removed |
| `device/phh/treble` | `0a74b582f445afc68fbc1f24280c514354601a54` | `tb2-20261021-product-graph` | 1 `rom.mk` adds SableLauncher, retains both older app+FLOSS inherits |

Original 7 Phase13 contents were in the owner handoff snapshot ZIP SHA256 `ee7453e5c23194968b80ff82cfdc0d34464bfc8c2443b47a5e69917466a84da2`, compiled for `SystemUI Dialer` PASS in 362.602s. This source-convergence workflow **does not reapply or rebuild those seven files**.

## ai-g732 source-only execution (no build)

Use an **independent fresh checkout** of PR346, not the owner's dirty canonical N1I checkout or pinned older detached quality checkout:

```bash
SRC=/srv/sable-build/workspaces/titan2-track-b/tb2-pr346-converged-source
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
# Get this exact PR346 branch at its latest commit into SRC with normal Git,
# only if SRC does not already exist. Do not reset existing workspaces.
export SABLE_TB2_ANDROID_ROOT="$ANDROID"
cd "$SRC"
bash build/titan2/converge-track-b-source.sh --plan
bash build/titan2/converge-track-b-source.sh --commit CONVERGE_TB2_EXACT_A16_PROJECTS
```

The second command performs **source mutations and four local AOSP project commits**; it does not build, network-fetch, flash, sign, or contact a device. Its stdout must report four `TB2_AOSP_PROJECT_COMMIT` IDs. If source HEAD/files drift, hold and review; do not reset checkout to force it. The operation is designed for a one-time source promotion. A repeat `--commit` after success is rejected by HEAD/branch pins; it does **not** replay the commits.

## Validation

Source-matched remote Git blobs:
- `stage-track-b-product.sh`: `398cd2e8c9705ddafbda1754d6af26fe6d34ed6a`
- `commit-exact-aosp-projects.sh`: `2de267d5720ff61f7d81ed99616bb154c5561e78`
- `converge-track-b-source.sh`: `604ab7af2bbf798f3aa5f6a70d56a9397e8388f1`

Local `bash -n` PASS for all three. Six hermetic regression cases passed using original uploaded Android16 manifest/product text, original Phase13 seven-file source snapshot, and real *disposable* Git repositories: read-only preflight, exact source stage, idempotence, 13 APK-only graph preservation, missing APK refusal, existing AOSP source drift hold, explicit authorization hold, and four exact project Git commits. Latest six-test total approximately 6.65 seconds including fixture creation, not real AOSP/Gradle performance. Expected host preflight cost is bounded hashing/text parsing of 13 APK filenames + small source/config files, no scanning large AOSP output directories or hashing APK payloads. Actual build/Soong performance **not measured** in this change.

## Unfinished implementations (do not promote as PASS)

- 18 historical Q25 Partial design artifacts and 26 Q25 source patch candidates need exact Android16 owner adaptations. Z/R Camera bindings and verified Phase13 native PIN/Dialer source already exist and must not be redone. SableStart current screen model does not yet prove the Q25 Glance/Home/Hub three-page parity.
- Privileged AppLock/Freezer/Vault/Private/Dual and hardRestricted `READ_SMS` require real supported platform/profile enforcement. Selected 13 app presence is not privilege/role grant. Setup checklist is not privileged full SetupWizard.
- Native Launcher HOME intent removal and SableLauncher product staging after host execution are not proof that Android resolved default HOME/Recents correctly in its installed image. PHH IMS source/permission XML are not effective signer/UID, classpath, SELinux/linker G1–G3, device registration or dual-SIM VoLTE proof.
- Q25 Browser/Files/Calendar/Hub visual/interaction gaps, Phone/Contacts and first boot remain source functional issues; single canonical `sable.sh` full quality + image build **not run**.
- No production signing/AVB/restore/flash authorized.

**Disposition:** source and four-project commit implementation delivered **on PR346**, actual ai-g732 AOSP commit identities **pending** the source-only host invocation; not `FULL_Q25_PRODUCT_COMPLETE`.
