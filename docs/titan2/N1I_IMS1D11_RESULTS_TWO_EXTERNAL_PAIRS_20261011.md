# IMS1-D11 measured results — two exact external symbolic provider pairs (2026-10-11)

Host result `PASS_FROZEN_CORPUS_EXTERNAL_METHOD_ID_LEADS_NOT_INVOKE_OR_ABI_QUALIFIED`; retained evidence `/srv/data/sable-build/evidence/titan2/n1i-ims1d11-external-symbolic-references-v1/20261011T155424Z-2516558`. Uploaded `SUMMARY.json` and `EXTERNAL_METHOD_ID_REFERENCES.tsv` reviewed.

- 7,078 sealed IMS1-C callsites; **zero external direct owner calls in this selected callsite table**; 50 D10 owner matches are all internal to `OPCommonTelephony.jar`.
- 26 non-provider frozen consumer APK/JAR files inspected using symbolic DEX `method_ids`.
- **242 external symbolic reference rows**: 240 from stock `mediatek-services.jar` targeting classes in stock `mediatek-framework.jar`; 2 from stock `agui-services.jar` targeting stock `agui-framework.jar`; **0** targeting `OPCommonTelephony.jar` among the scanned consumers.
- Stock and D1R2 `ImsService.apk`/`MtkTeleService.apk`, stock and CW1 `telephony-common.jar`: 0 direct symbolic references to any of the three selected providers.
- Frozen D7 registry SHA-256 `2b073db090d4f0f039b7e1502061abd994e517ed3fa3094e138d898901aa6317`; pinned D10 summary SHA-256 `26d84a1b4655e2f608c064fb14fc2c506ba3a55016d140c6899d74881e727804`.

**Strict limitation:** `method_ids` need not correspond to `invoke` instructions; not proof of method definition/inheritance, D1R2 file absence, classloader visibility, device/runtime failure or safe proprietary redistribution. Zero symbolic matches in this frozen set is not a global absence claim.

**Next bounded objective:** verify actual DEX invoke sites and exact descriptor/prototype for these **two** concrete stock consumer-to-provider relationships using the retained DEX parser `build/titan2/n1i_static.py`, and separately determine whether the consumers themselves are in D1R2 image before proposing configuration changes. Do not repeat broad stock inventory or create new Android source workspace; preserve CW1 warm output. No source mutation/build/network/device/flash authorized. PR #339 remains draft.
