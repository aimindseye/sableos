# Titan 2 N1I cellular evidence and JADX path registry (2026-10-11)

**Purpose:** Stable pointer registry for SableOS N1I/CW1/IMS1. Use before running a new `find` or audit. No OEM binary is committed here. Paths are **on ai-g732**, not portable filesystem URIs. `/srv/data/sable-build` and `/srv/sable-build` have been observed as aliases for particular workspace trees; avoid assuming all directories are duplicated.

## Authority and confidence
- **OPERATOR_LISTED**: path and exact size came from the 2026-10-11 `ls -l` supplied by operator; not independently opened here.
- **OPERATOR_EXECUTED**: path backed by run output; preserve accompanying log/result hashes.
- **PRIOR_EVIDENCE**: known from earlier SableOS project engineering conversations; verify existence before automation.
- **GITHUB_VERIFIED**: code/document path inspected in `aimindseye/sableos` or AtlasOS via GitHub.
- **UNRESOLVED**: analysis output location unknown. Do not fabricate paths or repeat expensive scans to conceal this.

## OEM firmware root and stock Java libraries
`STOCK_ROOT=/srv/data/sable-build/evidence/titan2/n1b2-cellular-static/20260929T131259Z/stock-2026041315-root`
`STOCK_SYSTEM_EXT_FRAMEWORK=$STOCK_ROOT/system_ext/framework`

The following files are explicitly present in the operator's directory listing (JAR size in bytes, metadata files omitted). Do not silently downcase `OPCommonTelephony.jar`: Linux filenames are case-sensitive.

| Filename | Bytes | Confidence | Canonical path expression |
|---|---:|---|---|
| `CapCtrlInterface.jar` | 13198 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/CapCtrlInterface.jar` |
| `CustomPropInterface.jar` | 3738 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/CustomPropInterface.jar` |
| `DataChannelApi.jar` | 35074 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/DataChannelApi.jar` |
| `OPCommonTelephony.jar` | 74289 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/OPCommonTelephony.jar` |
| `SatelliteClient.jar` | 111118 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/SatelliteClient.jar` |
| `agui-framework.jar` | 26613 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/agui-framework.jar` |
| `agui-services.jar` | 2867133 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/agui-services.jar` |
| `androidx.window.extensions.jar` | 273218 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/androidx.window.extensions.jar` |
| `androidx.window.sidecar.jar` | 34064 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/androidx.window.sidecar.jar` |
| `com.android.extensions.appfunctions.jar` | 5531 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/com.android.extensions.appfunctions.jar` |
| `log-handler.jar` | 104302 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/log-handler.jar` |
| `mediatek-carrier-config-manager.jar` | 13201 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-carrier-config-manager.jar` |
| `mediatek-common.jar` | 88613 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-common.jar` |
| `mediatek-framework.jar` | 826957 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-framework.jar` |
| `mediatek-ims-base.jar` | 89785 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-ims-base.jar` |
| `mediatek-ims-common.jar` | 75377 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-ims-common.jar` |
| `mediatek-ims-extension-plugin.jar` | 12517 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-ims-extension-plugin.jar` |
| `mediatek-services.jar` | 471982 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-services.jar` |
| `mediatek-telecom-common.jar` | 30941 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-telecom-common.jar` |
| `mediatek-telephony-base.jar` | 265981 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-telephony-base.jar` |
| `mediatek-telephony-common.jar` | 2134341 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/mediatek-telephony-common.jar` |
| `verizon.net.sip.jar` | 117529 | OPERATOR_LISTED | `$STOCK_SYSTEM_EXT_FRAMEWORK/verizon.net.sip.jar` |

These jars coexist with `.fsv_meta` entries and an `oat/` directory. Metadata is not itself a DEX-bearing JAR. The prior search that failed to find `opcommontelephony.jar` used the wrong case; `OPCommonTelephony.jar` is present here. Likewise `agui-framework.jar` is present in this stock root. Prefer these exact paths for renewed IMS/provider analysis.

## CW1 compiled and static-linkage evidence

| Role | ai-g732 path | Confidence |
|---|---|---|
| Stock telephony-common provider | `/srv/data/sable-build/evidence/titan2/n1b2-cellular-static/20260929T131259Z/stock-2026041315-root/system/system/framework/telephony-common.jar` | PRIOR_EVIDENCE (SHA-256 `6f0f9b1963d2562c5ff87810e7545407d5a1abe8c9230516321050265a1259be`) |
| Stock MediaTek consumer | `/srv/data/sable-build/evidence/titan2/n1b2-cellular-static/20260929T131259Z/stock-2026041315-root/system_ext/framework/mediatek-telephony-common.jar` | OPERATOR_LISTED + OPERATOR_EXECUTED |
| Full 172-gap ABI inventory | `/srv/data/sable-build/evidence/titan2/n1i-c2r2-d1r2-final-cellular-abi-closure/20261007T221836Z/FINAL_GAP_SET.tsv` | PRIOR_EVIDENCE (SHA-256 `0a391fa3e836dc1722a1a43dd28ade3b51e0cac7449100741bad89f178871c3c`) |
| Native calls density evidence | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-native-callsites-v3/20261011T044049Z-2178381/` | PRIOR_EVIDENCE |
| Exact map | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-exact-map/20261011T041512Z-2177874/` | PRIOR_EVIDENCE |
| CW1 patch | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-callwaiting-preview-v2/D1R4_CALLWAITING_SOURCE_PREVIEW.patch` | OPERATOR_EXECUTED (SHA-256 `4d2ad6b567ca725e8cc45c0362cdd788e3425c668592241aa4da007aa019635d`) |
| CW1 staged patched Java | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-handoff-v1/patched-source-only/` | OPERATOR_EXECUTED |
| CW1 standalone Android tree | `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android` | OPERATOR_EXECUTED |
| CW1 warm output | `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android/out_cw1` | OPERATOR_EXECUTED; **PRESERVE** |
| CW1 compiled DEX JAR | `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android/out_cw1/soong/.intermediates/frameworks/opt/telephony/telephony-common/android_common/dex/telephony-common.jar` | OPERATOR_EXECUTED (SHA-256 `76b335c3114c55f166edeef392889e4c908aceab9a9e92dec64f5f90c690af9f`) |
| CW1 build log and JSON | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-v2/BUILD.log`, `BUILD_RESULT.json` | OPERATOR_EXECUTED |
| CW1 DEX definition report | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-v2/dex-verify/SUMMARY.json` | OPERATOR_EXECUTED |
| CW1 verified manifest | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-v2/github-checkpoint-manifest-v1/` | OPERATOR_EXECUTED; mirrored as text metadata in PR #339 |
| CW1 stock consumer linkage | `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-consumer-linkage-v1/SUMMARY.json` | OPERATOR_EXECUTED, result `PASS_EXACT_SUPER_LINKAGE_STATIC_ONLY` |

## Retained Android and SableOS checkouts

| Role | ai-g732 path |
|---|---|
| Protected N1D Android checkout | `/srv/sable-build/workspaces/titan2-n1d/android` |
| Protected C3B Android checkout | `/srv/sable-build/workspaces/titan2-n1d-c3b/android` |
| SableOS canonical repository | `/srv/sable-build/sableos/repo` |
| Two affected telephony sources (relative to Android checkout) | `frameworks/opt/telephony/src/java/com/android/internal/telephony/GsmCdmaCallTracker.java`; `GsmCdmaConnection.java` |

N1D and C3B are distinct inode-backed workspaces. Their alternate `/srv/data/sable-build/workspaces/...` paths were reported as aliases, not independent copies.

## Source / JADX / extracted-code leads

Earlier N1I work reports JADX decompilation of nine priority components and decompilation of `mediatek-framework.jar` (142 Java sources). **The exact JADX output directories were not present in the retained user-facing evidence here and are UNRESOLVED.** Do not claim a guessed directory is authoritative or rerun broad scans automatically. When the precise JADX path is observed, add it as a new row in this registry with DEX input SHA and decompiler tool version.

Stock OEM APK names previously analyzed include `MtkTeleService.apk` and `ImsService.apk`, but their precise extracted absolute APK paths in this root have not been reconfirmed here. Use the stock-root relative search only when needed.

Previously identified crucial Java/DEX owners:
- `com.android.internal.telephony.GsmCdmaCallTracker`
- `com.android.internal.telephony.GsmCdmaConnection`
- `com.mediatek.internal.telephony.MtkGsmCdmaCallTracker` (verify exact DEX descriptor from consumer report)
- `com.android.internal.telephony.subscription.SubscriptionManagerService`
- `com.android.internal.telephony.imsphone.ImsPhoneCallTracker`

## Existing source tools / reference docs

- `build/titan2/n1i_static.py`: validated DEX/instruction decoder.
- `build/titan2/n1i-b2-members.py`: runtime-classpath-aware ABI resolver with protected access/superclass analysis.
- `build/titan2/run-n1i-d1r2-cellular-image.sh`: retained D1R2 integration entrypoint, **not authorization to build or flash**.
- `build/titan2/build-n1d-c3b-systemimage.sh`: existing C3B build infrastructure.
- `build/titan2/n1d-c3-trebledroid.env`: GSI product authority.
- `build/titan2/n1d-c3b-e2-product-composition.env`: engineering lunch authority `sable_titan2-bp4a-userdebug`.
- `docs/titan2/N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE.md`
- `docs/titan2/N1I_B_TREBLEDROID_MTK_IMS_CAPABILITY_ANALYSIS.md`
- `docs/titan2/N1I_D1R4_CW1_COMPILED_CHECKPOINT_20261011.md`
- `docs/titan2/N1I_D1R4_ATLASOS_IMS_REFERENCE_20261011.md`
- [AtlasOS Titan 2](https://github.com/Abyss-c0re/atlasos), especially `patches/gsi_source/0096-telephony-ims-follows-settings-calls-sim.patch` and `0210-telephony-incoming-binder-thread-both-phones.patch`.

## Usage rules for next engineering deliverables
1. Read this registry first and use the exact case-sensitive relative paths; verify an individual target `test -f` and hash if mutation or reliance is safety-critical, rather than issuing broad `find`.
2. Distinguish stock APK/JAR inputs, JADX decompilation output, patched Android source, and built SableOS DEX output.
3. Retain the original SHA-256 and observation source with each new entry.
4. Never add OEM proprietary JAR/APK bytes to GitHub by default. Record paths/sizes/hash manifests instead.
5. Only append VERIFIED paths when confirmed by operator output or tool inspection; unknown JADX paths remain UNRESOLVED until supplied.
6. The registry documents provenance; it does not approve source mutation, builds, device contact, or flashing.
