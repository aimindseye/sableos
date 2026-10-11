# IMS1-D13 verified results and P0 priority handoff (2026-10-11)

Operator qualified `PASS_STOCK_METHOD_DEFINITIONS_ONLY_D1R2_RUNTIME_UNQUALIFIED`; evidence `/srv/data/sable-build/evidence/titan2/n1i-ims1d13-stock-method-presence-v1/20261011T160849Z-2517160`. Uploaded `SUMMARY.json`, `METHOD_RESOLUTION.tsv`, `CONSUMER_MANIFEST_LEADS.tsv` reviewed.

289 D12 actual invocation instructions: **263 EXACT_PROVIDER_DEFINITION** (260 `mediatek-services.jar` -> `mediatek-framework.jar`, 3 `agui-services.jar` -> `agui-framework.jar`), **26 NOT_DEFINED_IN_SELECTED_PROVIDER_INHERITANCE_UNQUALIFIED**, all in `mediatek-services.jar`. The 26 are concentrated on Binder-related `IMBrainJava`, `IMBrainCallbacks`, `IMBrain` stub/interface owners; `attachInterface`, `markVintfStability` among method names. Missing inside selected provider is **not** a missing-method failure because superclass and cross-JAR inheritance are out of scope.

D1R2 tree-manifest literal filename mentions: `agui-services.jar=0`, `mediatek-services.jar=0`. This is **not** definitive proof of absent bytes or absence from all partition manifests. No causal IMS service failure shown. D13 validates pinned stock bytes and stock provider methods, not D1R2 runtime.

**Decision**: Do not restore these proprietary classpath components or patch AOSP on D13 alone. Keep the 26 calls as a narrow Android framework inheritance follow-up but prioritize **P0 IMS registration exact MMTEL binding / required library / service load contract** using the frozen `ImsService.apk`, `MtkTeleService.apk`, D8 manifests and D1R2 APK-specific uses-libraries and classpath evidence. P0 calls/CW1 already compiled and static-invoke-super checked; callback ordering/dual-phone/binder-thread remains unqualified. P1 SIM subscription/phone/slot identity and MediaTek property authority remain unqualified.

Preserve draft PR #339, existing protected CW1 119 GB source and warm `out_cw1`. No source mutation, build, network, image extraction, device contact or flash.
