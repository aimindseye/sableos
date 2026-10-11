# IMS1-D9.4 verified stock classpath finding and D9.5 bridge (2026-10-11)

## Status and exact provenance
Operator-provided D9.4 evidence: schema-aware decode `PASS_SCHEMA_DECODED_FRAGMENTS_ONLY`, 40 records, no errors. Decoded using existing CW1 119GB Android source checkout `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android`, schema `packages/modules/common/proto/classpaths.proto` SHA-256 `679c488b19754766b351fa1002a688db4b6009f8e34531b55bf7216de08f984b`.
Inputs: N1B2 stock analytical root `.../stock-2026041315-root/system/system/etc/classpaths/bootclasspath.pb` SHA-256 `0ab2e6fab051fb27f6d3320417f0ccc808540967eaf1fd320615adfeca58765b`, and `systemserverclasspath.pb` SHA-256 `4c93144d7ee0d12a19dd9ffbdebe5a4cd9e816ccf401225b8ad378a91dddc494`.
Operator-returned exported `SUMMARY.json` SHA-256 `e9869dde76b4c1f825c56fc807328ab1a597a7d435b55b717b103ac2c41e9cff`, and `CLASSPATH_FRAGMENTS.tsv` SHA-256 `68014b4eed6e50b6974a07ab934cdf54c46dc6256b348e7f4de8a3af396e6abf` (these hashes are of the received exported bytes). Full results retained at `/srv/data/sable-build/evidence/titan2/n1i-ims1d94-schema-classpath-v1/20261011T145107Z`.

## What decoded fragments establish
- 40 entries: 19 BOOTCLASSPATH, 19 DEX2OATBOOTCLASSPATH, 2 SYSTEMSERVERCLASSPATH; 19 distinct BOOTCLASSPATH JAR paths.
- Bootclasspath includes `/system/framework/telephony-common.jar`, `ims-common.jar`, `framework.jar`, plus **stock MediaTek** providers `/system_ext/framework/mediatek-telephony-base.jar`, `mediatek-telephony-common.jar`, `mediatek-carrier-config-manager.jar`, `mediatek-common.jar`, `mediatek-framework.jar`, `mediatek-ims-common.jar`, `mediatek-ims-base.jar`, `mediatek-telecom-common.jar`, `OPCommonTelephony.jar`, and `agui-framework.jar`.
- These are *schema-decoded stock system partition fragments*, not complete runtime merged classpath, and not proof SableOS uses same jars/order.

## Engineering limitations and AOSP status
- APEX and other partition fragments not merged; min/max SDK constraints retained but not evaluated; APK uses-library/shared-library/visible classloader contexts not bound; **SableOS D1R2 installed-image classpath not yet established**.
- IMS1-C 7,078 relevant callsites and 3,059 triage keys. Unresolved references under the partial candidate set are **not confirmed defects**.
- Existing isolated CW1 source compile of AOSP telephony-common was successful; four DEX definitions present; MediaTek stock-consumer invoke-super linkage passed static only. No full image with CW1, IMS registration, incoming call, SIM switch, runtime behavior or production compatibility is qualified.

## D9.5 next qualification
Local bundle `N1I_IMS1D95_PROVIDER_DELTA_V1.zip` SHA-256 `700599248e590269b2142c4b2644b6289bcbb7b1dc9498d5c402c245022b0b06`. A bounded read-only inventory correlation using the exact D9.4 exported summary and 40-row TSV; does **not** assert SableOS ABI or runtime visibility. Next definitive prerequisite is pinned retained D1R2 image classpath evidence; run existing `build/titan2/n1i-b2-members.py` only with genuine image- and APK-specific classloader authority.

## Workspace and source freeze
Continue PR #339 `n1i-d1r4-cw1-compiled-checkpoint-20261011`. Reuse `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android` and existing `out_cw1`. No new Android tree, downloads, repo sync, clean/clobber, rebuild, host Git checkout change, device contact or flash. Canonical `/srv/sable-build/sableos/repo` remains dirty on a different branch; do not touch. PR remains draft, not production-ready.
