# Track B retained product sources — actual owner inventory 2026-10-21

This records the **existing** Android16 checkout product and is not a second candidate product graph, a rebuilt APK, source-signing proof or installed-image pass.

## Product composition resolved

- The owner's `vendor/sable/tb2-rebuilt/tb2-apps.mk`, SHA256 as reported from ai-g732 `8264edf7985b9aa1f62e36acbdd0d07767834705c6aee8680cd733e9232c6e7f`, selects precisely 13 `TB2Sable*` imports. These are exactly the 13 names previously verified in the uploaded `tb2-rebuilt/Android.bp`.
- The active AOSP `rom.mk` inherits `tb2-rebuilt/tb2-product.mk` and `trackb13ims/track-b.mk`. The latter selects `PhhIms`, `PhhImsOverlay`, `Iwlan`, `QualifiedNetworksService`, and not the alternative 13 `TrackBSable*` app import definitions.
- The reported `tb2-rebuilt/prebuilt` inventory contains all 13 referenced APK filenames. Sizes below are **owner-reported metadata**, not verified cryptographic identity, package ID, actual APK signature, source revision, runtime inclusion or free image capacity.

| Existing AOSP module | Bytes | Soong signing declaration |
|---|---:|---|
| `TB2SableCalculator` | 30588263 | `presigned` |
| `TB2SableCalendar` | 30037601 | `presigned` |
| `TB2SableCamera` | 1780027 | `default_dev_cert` |
| `TB2SableDisplayCompat` | 2074839 | `default_dev_cert` |
| `TB2SableHub` | 30759873 | `presigned` |
| `TB2SableKeyboard` | 1212184 | `default_dev_cert` |
| `TB2SableMail` | 10713207 | `default_dev_cert` |
| `TB2SableMedia` | 37958047 | `presigned` |
| `TB2SableReader` | 103404930 | `presigned` |
| `TB2SableSetup` | 149406 | `default_dev_cert` |
| `TB2SableTextReader` | 108773891 | `presigned` |
| `TB2SableTools` | 324266 | `default_dev_cert` |
| `TB2SableWeather` | 30419384 | `presigned` |

Count **13**, combined APK bytes **388195918** (370.21 MiB), with seven `presigned: true` and six `default_dev_cert: true`. No need for another 13-module `SableTB2*` set. PR346's older hypothetical proposed importer is **not** the active selected graph and must not overwrite these.

## Existing selected FLOSS IMS policy source

The existing `trackb13ims/privapp-permissions-me.phh.ims.xml` is 273 bytes, with owner-reported SHA256 `6ccb15dcc39495a2c2688871f84d7368871805e08b1d02823c77af09720bcba7`. It grants `android.permission.READ_PRIVILEGED_PHONE_STATE` and `android.permission.MODIFY_PHONE_STATE` to **`me.phh.ims`**. The active makefile copies it to `system/etc/permissions`. These are *declarations*, not proof of successful privileged permission grant, selected package identity, service registration, SELinux/linker namespace closure or dual-SIM VoLTE. OEM IMS should not be appended without a proven provider switch.

## Remaining source/evidence tasks — no repeated individual build gates

1. Reuse the **existing** 13 imported APK artifacts and owner receipt metadata in one canonical `sable.sh` product path; avoid the duplicate PR346 candidate importer. The present stage still deliberately reports `HOLD_EXISTING_GRAPH_RECONCILIATION` if the old graph is active; do not misstate the branch as end-to-end build-ready.
2. Export the two **existing** small `q25-ims-conformance-receipts/*/TB2_Q25_IMS_ADMISSION.json` files, dated 20261020T163227Z and 20261020T163425Z, to evaluate the previously completed IMS/Q25 findings. Do not run their operators again.
3. Existing `bb10-module-trials` is only five `out-*` AOSP build-output directories (confirmed from earlier broad inventory); their `ninja`, Kati and `.path` artifacts are *not* additional source implementations. Preserve outputs; don't scan or transfer them wholesale.
4. Existing Launcher3 main manifest still contains HOME; a source patch is in PR346 but **has not been applied** on ai-g732. SableLauncher source/role, 26 Q25 owner adaptations, real privileged security enforcement and valid selected-image IMS G1–G3 remain incomplete.
5. Preserve compiled seven native source files/Phase12-13 and Native34/NextSlice receipts; no rerun for evidence custody.

**Validation:** The module-name reconciliation is exact for all thirteen from user-provided `tb2-apps.mk` against previously uploaded `Android.bp`. The byte total is integer-summed from the owner list. This is evidence documentation only, not a build/test benchmark. No host source mutation, image, device or flash action is performed by this commit.

**Disposition:** `EXISTING_13_APP_PREBUILT_INVENTORY_IDENTIFIED`, `PHH_IMS_PRIVAPP_XML_PRESENT`, `FULL_Q25_IMS_BUILD_AND_RUNTIME_UNQUALIFIED`.
