# IMS1-D9.8 — exact stock versus D1R2 schema classpath delta (2026-10-11)

## Result
Operator-provided `SUMMARY.json`, `CLASSPATH_DELTA.tsv`, `CLASSPATH_ORDERED.tsv` from `/srv/data/sable-build/evidence/titan2/n1i-ims1d98-stock-d1r2-schema-delta-v1/20261011T150939Z-2516005` reviewed on 2026-10-11. Result `PASS_PINNED_SCHEMA_FRAGMENT_DELTA_NOT_RUNTIME_ABI_QUALIFIED`, 40 distinct delta-key rows, 74 ordered records total, 34 unchanged and **6 STOCK_ONLY**. No D1R2-only rows; zero errors.

## Exact six differences = three distinct bootclasspath providers
Each stock-only JAR occurs once in `BOOTCLASSPATH` and once in `DEX2OATBOOTCLASSPATH`, accounting for six rows. D1R2 has zero for each:
- `/system_ext/framework/OPCommonTelephony.jar`
- `/system_ext/framework/agui-framework.jar`
- `/system_ext/framework/mediatek-framework.jar`

Other MediaTek entries (`mediatek-telephony-common.jar`, `mediatek-telephony-base.jar`, `mediatek-ims-base.jar`, `mediatek-ims-common.jar`, `mediatek-carrier-config-manager.jar`, `mediatek-common.jar`, `mediatek-telecom-common.jar`) and standard `telephony-common.jar` / `ims-common.jar` are present in both **configuration fragments**. Both system-server entries are unchanged. **Classpath listing does not prove provider file is present or that its methods link.**

## Pinned inputs
- Schema `packages/modules/common/proto/classpaths.proto` SHA-256 `679c488b19754766b351fa1002a688db4b6009f8e34531b55bf7216de08f984b` (existing CW1 Android checkout).
- Stock `bootclasspath.pb` SHA-256 `0ab2e6fab051fb27f6d3320417f0ccc808540967eaf1fd320615adfeca58765b`, 38 decoded records.
- D1R2 `D1R2/classpaths/bootclasspath.pb` SHA-256 `fd01d8189cc665e11a386d8d04f8111db5b3fb3a5542a4c31ac8fa24394f51b6`, 32 decoded records.
- Stock/D1R2 `systemserverclasspath.pb` identical SHA-256 `4c93144d7ee0d12a19dd9ffbdebe5a4cd9e816ccf401225b8ad378a91dddc494`, 2 decoded each.
- D1R2 previously retained `D1R2/classpath-and-libraries.txt` SHA-256 `87008243814bd7ca93f9c7c75659cc43f0f6bec4a854891bcdfc73c57bec6869`.

## Required next work — narrow remediation, not another global census
1. Check exact three paths against retained D1R2 filesystem manifest or extracted image tree and compare their stock D7 pinned providers; missing filesystem bytes versus missing classpath registration must be distinguished.
2. Inspect the existing D1R2 classpath-and-libraries report and prior resolved/symbolic reports; confirm source ownership/intent before any changes.
3. Cross-reference exact DEX callsites dependent on those providers via IMS1-C and existing `n1i-b2-members.py` where classloader authority is sufficient. Emit named AOSP/source remediation candidates with confidence and method signatures.
4. Preserve min/max SDK conditions, APEX/non-system fragments and APK-specific uses-library visibility as separate unresolved gates. No new source workspace, repo sync, extraction, build, or device/flash; no source mutation authorized.

## Limitation
These are **six classpath configuration discrepancies, not six confirmed ABI defects**. D1R2 image artifact SHA is not yet bound in this checkpoint; full runtime classpath, APK visibility, ABI and telephony behavior are not qualified. PR #339 remains draft.
