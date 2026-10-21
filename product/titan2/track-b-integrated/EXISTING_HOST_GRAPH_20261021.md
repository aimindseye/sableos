# Reuse the selected ai-g732 Track B product graph (2026-10-21)

The owner's actual `vendor/sable/tb2-rebuilt/tb2-apps.mk` output reports SHA256 `8264edf7985b9aa1f62e36acbdd0d07767834705c6aee8680cd733e9232c6e7f` and a `PRODUCT_PACKAGES` continuation listing exactly **13** `TB2Sable*` modules. The actual bytes of this last makefile have not been uploaded (only printed), so this checksum is owner-reported, not independently rehashed here. The trailing `\` after `TB2SableWeather` parses as 13 words in GNU Make when tested with the pasted selection, but should be removed in a future source-managed replacement.

The previously uploaded archive `TB2_EXISTING_PRODUCT_SOURCE_20261021.tar.gz`, SHA256 `098971e05962206179b095602e2d3257a40ae37afd35b999ab28896aca2937ef`, contains `vendor/sable/tb2-rebuilt/Android.bp` with exactly the same 13 imported module names. Programmatic comparison of the pasted makefile selections against these Soong import names yielded **13/13 set equality**. The AOSP `rom.mk` already inherits `tb2-rebuilt/tb2-product.mk`, which includes `tb2-apps.mk`: do not add PR346's alternative `SableTB2*` import graph on top.

| Existing module | Soong signing |
|---|---|
| TB2SableCalculator | presigned |
| TB2SableCalendar | presigned |
| TB2SableCamera | default_dev_cert |
| TB2SableDisplayCompat | default_dev_cert |
| TB2SableHub | presigned |
| TB2SableKeyboard | default_dev_cert |
| TB2SableMail | default_dev_cert |
| TB2SableMedia | presigned |
| TB2SableReader | presigned |
| TB2SableSetup | default_dev_cert |
| TB2SableTextReader | presigned |
| TB2SableTools | default_dev_cert |
| TB2SableWeather | presigned |

**Signing matters:** six of these imports require unsigned APK inputs to be signed by Android Soong's development certificate; seven expect APKs already signed. PR346's original hypothetical `selected-apps.tsv` used presigned debug APKs for **all ten direct Gradle apps**, and must **not** be used as an AOSP source replacement without reconciling those signing classes and building correct inputs. Its malformed literal `\t` separators in the first ten rows have now been corrected to real TSV tabs, but that file remains a **reference/candidate**, not the active installation graph. Copying or re-signing existing host APK files is not part of this change.

The previously supplied `vendor/sable/trackb13ims/track-b.mk` selects `PhhIms`, `PhhImsOverlay`, `Iwlan`, and `QualifiedNetworksService` and removes the MTK IMS overlay. Its separate `TrackBSable*` Soong definitions are **not** in that makefile's `PRODUCT_PACKAGES`. Thus one selected FLOSS IMS *source graph* and 13 rebuilt app selections are known. IMS actual provider runtime, signer/UID/classpath, SELinux G1–G3 and dual-SIM VoLTE are still unproven; do not switch to OEM via an extra import.

**Disposition:** `ACTIVE_APP_MODULE_SELECTION_RESOLVED_13`, `EXISTING_FLOSS_SOURCE_SELECTED`, `PRODUCT_STAGE_PR346_RECONCILIATION_OPEN`. The current PR346 product stage intentionally halts before mutating this active product, pending safe reuse of these existing Soong imports and the correct source APK provenance/signing. Do not redo app builds as independent gates; integrate into one canonical `sable.sh` workflow after source reconciliation.

**Next narrow host file evidence (read-only):** the inventory and receipt metadata for `android/vendor/sable/tb2-rebuilt/prebuilt/` (filenames, byte sizes, SHA256, build-source/unsigned status; no APK uploads), `android/vendor/sable/trackb13ims/` text permissions and effective package/IMS source owner, and `bb10-module-trials/` source filenames if more Q25 work exists there. No large `out-integrated-13-floss-ims` image upload is needed.
