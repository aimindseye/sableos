# IMS1-D12 handoff and P0/P1 qualification board (2026-10-11)

## D12 exact invokes
Read-only bundle `N1I_IMS1D12_TWO_PAIR_INVOKES_V1.zip` SHA-256 `d90f9ffe89001c65d2c086010baec4f41205f12857f829f75b8eb96f34cf699e`. Local Python syntax, synthetic negative selftest and ZIP integrity PASS; ai-g732 execution not yet confirmed. Uses frozen D11 242 external **symbolic** leads but scans actual DEX invokes in only `mediatek-services.jar` -> `mediatek-framework.jar` and `agui-services.jar` -> `agui-framework.jar`, using existing host `build/titan2/n1i_static.py`. Outputs exact callers, target prototypes, opcodes, offsets. All input files remain read-only; D1R2 image bytes/classloader and method-definition linkage NOT resolved.

## P0 IMS registration
Stock and Sable `ImsService.apk`, `MtkTeleService.apk` frozen, IMS-C 7,078 exact callsites, D8 four manifests parsed; stock system-fragment classpath schema-decoded and D1R2 fragment differences quantified. IMS service loading/MMTEL binding and uses-library linkage **not proven**, IMS registration lifecycle **not tested**. No IMS-specific AOSP patch approved by verified method-level ABI evidence.

## P0 incoming calls / call waiting
CW1 changed `GsmCdmaCallTracker.java` and `GsmCdmaConnection.java`; isolated Android 16 `telephony-common.jar` compiled, four DEX definitions verified; stock MediaTek invoke-super linkage **PASS_STATIC_ONLY**, 5 regression negatives. No complete image with CW1 proven, no IMS callback sequence or incoming-call dispatch runtime observations; prior AtlasOS dual-phone/binder-thread idea remains a candidate, not verified source remediation.

## P1 SIM switching
Existing analysis identified `SubscriptionManagerService`, `ImsPhoneCallTracker` and MediaTek subscription/slot/phone identity interactions as review targets. There is no qualified slot/phone/subscription mapping matrix, property ownership proof, IMS reinitialization runtime trace or validated source change yet.

## D9-D11 actual narrowed findings
D9.8 six STOCK_ONLY fragment rows = three distinct missing D1R2 bootclasspath provider names: `OPCommonTelephony.jar`, `agui-framework.jar`, `mediatek-framework.jar` each duplicated in BOOTCLASSPATH and DEX2OATBOOTCLASSPATH. D10 50 owner matched calls all internal to OPCommonTelephony, not external IMS ABI failures. D11 242 *symbolic method_id* leads: 240 `mediatek-services.jar` -> `mediatek-framework.jar`, 2 `agui-services.jar` -> `agui-framework.jar`, zero direct external IMS APK symbolic refs in this scoped set. No AOSP patch or proprietary classpath restoration inferred.

## Authority
Continue draft PR #339 `n1i-d1r4-cw1-compiled-checkpoint-20261011` and protected existing `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android` and `out_cw1`. Host canonical SableOS repository is dirty on a different branch and MUST NOT be switched/cleaned. No new workspace, repo sync, download, image extraction, build, source mutation, device contact, reboot or flash.
