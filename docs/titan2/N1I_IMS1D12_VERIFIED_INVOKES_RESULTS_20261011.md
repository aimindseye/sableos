# IMS1-D12 measured exact invoke results (2026-10-11)

Operator run `PASS_TWO_PAIRS_EXACT_INVOKES_NOT_METHOD_OR_RUNTIME_QUALIFIED`. Evidence retained at `/srv/data/sable-build/evidence/titan2/n1i-ims1d12-exact-invokes-v1/20261011T160236Z-2517061`. Supplied `SUMMARY.json` and `EXACT_EXTERNAL_INVOKES.tsv` reviewed.

- 289 **actual DEX invoke instructions** from two stock consumer/provider relationships: 286 `mediatek-services.jar` -> `mediatek-framework.jar`; 3 `agui-services.jar` -> `agui-framework.jar`.
- `mediatek-services.jar`: 39 distinct calling classes, 30 target owner classes, 81 distinct target names (name-only count; exact method prototypes in TSV).
- `agui-services.jar`: 2 calling classes, 2 target classes, 2 distinct target names.
- Invocations by opcode: 225 invoke-virtual, 34 invoke-direct, 15 invoke-static, 10 invoke-interface, 5 invoke-virtual/range.
- D11 symbolic method_id leads count 242, not comparable 1:1 with invokes because multiple invoke instructions may reference one method_id. D10's 50 internal OPCommonTelephony calls remain separate.

**Gate limitation**: no target method-definition or inheritance resolution; no proof these two consumer JARs exist in D1R2 installed filesystem; no APK or system-server classloader visibility confirmation. Do not label these 289 defects or authorize classpath restoration, source patches, build or flash.

**Next focused step**: use retained D1R2 tree manifest or extracted image path to qualify consumer JAR presence; resolve exact D12 target signatures against verified provider DEX definitions and inheritance with existing n1i-b2-members.py where supported, and generate compact actionable remediation categories, keeping P0 IMS registration and P0 incoming-call/CW1 distinct from broader framework dependencies.

All work remains on PR #339, protected existing CW1 119GB Android source checkout and warm output, no new workspace/download/build/device.
