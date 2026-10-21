# Track B actual ai-g732 handoff reconciliation — 2026-10-21

**Owner archive:** `TB2_SOURCE_HANDOFF_20261021T132915Z.tar.gz`; SHA256 `274fab4b937623abe8af0a557ffa537c0121fba930afa83bacf63fd683e82295`. The handoff completed **read-only**, no build/device/flash. Local archive extraction checked safe entries, all `SHA256SUMS.txt` members PASS and embedded Phase13 ZIP CRC PASS.

## Proven reuse — do not repeat

- Phase12/Phase13: embedded seven-file snapshot ZIP SHA256 `ee7453e5c23194968b80ff82cfdc0d34464bfc8c2443b47a5e69917466a84da2`, 7/7 native A16 files; prior real `m -j4 SystemUI Dialer` exit=0 in 362.602s (lunch `treble_arm64_bvN-bp4a-userdebug`). Native log hash `8472ebaf144512b6133dd44b489f91fae2b21138acaf7eb9155cd4b3738fdc46`. Uncommitted host AOSP changes already present; do **not** replay them simply for a new gate.
- Recovered native snapshot paths: `frameworks/base/packages/SystemUI/src/com/android/keyguard/KeyguardPinBasedInputView.java`, `.../KeyguardPinBasedInputViewController.java`, `.../sable/SableTitanPinKeys.java`, `packages/apps/Dialer/java/com/android/dialer/app/res/values/sable_strings.xml`, `.../res/xml/sound_settings.xml`, `.../sable/SableTitanInCallKeys.java`, `.../incallui/InCallActivity.java`. Only frameworks/base and Dialer tracked diffs are nonempty; new files exist as untracked source (including in compiled snapshot). A self-contained root-relative patch was reconstructed from these source bytes; reversed and reapplied in a throwaway AOSP-shaped sandbox and **all 7 final SHA256 bytes matched**. This confirms patch construction, **not** a new native compile.
- Native34 postbuild receipt: `Launcher3QuickStep.apk` SHA256 `5d97ac40e8d62e03ed81bf85acc4d0359359ecad577ce90732c7e64fb10f137b`, 18,061,116 bytes, result `PASS_HOST_APK_STRUCTURAL_AUDIT_ONLY` (no image/runtime admission).
- Manifest link repair `PASS_PINNED_MANIFEST_LINKS_RESTORED`: all 11 recognized existing links already present; do not rerun repair/sync for no reason.
- Detached PR346 Camera/Keyboard source patch was present in the archive, but the **four files are already byte-exact committed on PR346** (do not recommit). `tb2-sable/` does **not** resolve as a Git checkout; `q25-app-quality-pr346-257a037e88f2` was detached at pinned commit `257a037e88f20d5f998c89c5047f9d903640c4f1` with the uncommitted four-file changes. Canonical `/srv/sable-build/sableos/repo` was still on older `n1i-c2r2-cellular-closure-host-r2-20261007` branch with legacy N1I_D1R2 modifications — do not reset it or conflate with PR346.

## Newly confirmed blocking product graph conflict

The **actual ai-g732** `device/phh/treble/rom.mk` SHA256 `0c654060c57fc1b639d670164055aeffa231441a595310b2f45f7badb0ba66cb` contains BOTH existing active product inclusions:

```make
$(call inherit-product, vendor/sable/trackb13ims/track-b.mk)
$(call inherit-product, vendor/sable/tb2-rebuilt/tb2-product.mk)
```

The exported `vendor/sable/trackb13ims/Android.bp` SHA256 `7da608a563997ec0e52a9756add9ff127f0c1fcf1c27c6e7f451f3d7753d75ec` is **13 nonprivileged app imports** named `TrackBSable*`, **not** proof of a FLOSS IMS provider. The export lacks the source contents of the actual `track-b.mk` and `tb2-product.mk`. The existing product may already install the same 13 Sable package IDs as PR346's generated `SableTB2*` modules. Appending PR346's 13-module product import would risk a duplicate-app package graph, and adding `OEM` IMS imports alongside a retained FLOSS stack could create conflicting providers. The active `vendor/sable/titan2` product directory was marked **MISSING** by the host project inventory, so the current PR346 OEM-only slice cannot be assumed ready.

**Code correction committed to PR346:** `build/titan2/stage-track-b-product.sh` now detects those two exact legacy includes and fails closed as `HOLD_LEGACY_TRACKB_GRAPH_CONFLICT` **before modifying Android source or product files**, instead of layering a new product graph on top. Its Git blob is `74b8c2a4336094caee8257e347259ec3f8c842fe`; Bash `-n` PASS; existing 13-app synthetic stage tests PASS (~0.96s), and input ROM has both matching includes. This is correct preservation, **not full conflict resolution**.

## Missing actual host inputs for complete source reconciliation

These existing, readable **text-only** files, not images or proprietary blobs:

1. `android/vendor/sable/trackb13ims/track-b.mk` and any referenced exact *text* .mk/config files
2. `android/vendor/sable/tb2-rebuilt/tb2-product.mk`, `Android.bp`, and relative APK install module list; **do not upload prebuilt APKs**
3. The selected `android/packages/apps/Launcher3/AndroidManifest.xml` and overlay/manifest text that controls Launcher3QuickStep HOME/RECENTS, plus `packages/apps/SableStart` if already staged
4. IMS-specific source/Soong/make/init/permission declarations (paths and text, with secret values removed) and selected `vendor/sable/trackb13ims` subtree inventory, so OEM-vs-FLOSS can be reconciled accurately
5. Android16 target owner files for first-boot, Settings, Browser and privileged profile enforcement if present; Q25 Lineage SetupWizard/Jelly are absent, not an excuse to invent those A16 owners

The initial handoff captured only the old `Android.bp` for `trackb13ims`; product includes are visible but the inherited makefiles themselves were not included. It captured no private IMS libraries or vendor stock ROM contents, appropriately. The `q25-ims-conformance-receipts/` folder contributed no source proof in this export. `workspace-source/sableos` contains existing Android17/GrapheneOS patch experiments, reference files and a Git source listing, not proof of applicable Android16 native source. Do not import these wholesale.

## Cross-repository status

PR342 historical IMS/AVB/debug evidence only; PR344 Track B custody; PR345 Sonar source CI; PR346 actual 13-app engineering source staging and build-only `sable.sh` path, now guarded against the retained active Track B graph. Closed PR343 Track A app file overlap does not authorize importing stock OEM manifest into a GSI. `platform_sable` and Q25 design prescribe **SableLauncher HOME + Quickstep Recents-only**, but native A16 HOME selection remains unimplemented. All 26 retained Q25 framework patch candidates, real privileged AppLock/Vault/Freezer/Dual/Private enforcement, restricted SMS role, effective selected-image IMS G1/G2/G3 and SIM1/SIM2 VoLTE remain OPEN.

**Disposition:** `HOST_SOURCE_SNAPSHOT_RECOVERED_AND_VERIFIED`; `LEGACY_PRODUCT_GRAPH_CONFLICT_FOUND_AND_GUARDED`; `FULL_Q25_IMS_SOURCE_MERGE_NOT_COMPLETE`; `IMAGE_FLASH_NOT_QUALIFIED`. No separate module gate, no source reset, no new AOSP native build or device action.
