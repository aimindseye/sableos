# N1F October 11 experimental image — R1/R2 minimal change handoff (2026-10-12)

**Status: DESIGN_READY; IMPLEMENTATION_NOT_AUTHORIZED.** This is the next engineering work package, not another general provenance audit. Read [current state](CURRENT_ENGINEERING_STATE.md) and [evidence index](EVIDENCE_INDEX.md) before acting.

## Correct runtime interpretation

- Operator reports a hybrid image was flashed October 11, followed by Android boot and ADB diagnostics. The actual flashed-image journal/hash is not yet paired with the runtime record; do not invent it or treat historical offline R3 construction as equivalent.
- ADB scripts **temporarily activated cellular only for diagnosis**. Cellular subsequently became disabled / out of service again. **No stable cellular-enablement workaround exists or is accepted.**
- Telephony registry showed transient voice/data `IN_SERVICE` followed by `OUT_OF_SERVICE` around 20:01:02. RIL `mtkNetworkIndication == NULL` is a separate unresolved lead. IMS R1/R2 remediation must not be described as proven to fix LTE/RIL stability.
- R8Q3 runtime filesystem lists `/system_ext -> /system/system_ext` with OEM ImsService APK `NOT_LISTED` at checked paths; this differs from **offline** R3's seven-partition stock-image input list. Do not infer where to copy new binaries from either view alone.

## One bounded candidate, two separate failure paths

**R1 — Android receiver policy**
- Consumer: `com.mediatek.wfo.impl.WfcHandler.registerForBroadcast()` in pinned `ImsService.apk`.
- Failure: flagless `Context.registerReceiver` applied to an `IntentFilter` with five actions, one custom action not protected in failing GSI.
- Candidate: platform-owned `<protected-broadcast android:name="com.mediatek.common.carrierexpress.operator_config_changed" />` in effective scanned manifest. Verify ownership, merged artifact, stock sender permission/security behavior. No OEM APK repacking, ContextImpl bypass, target SDK downgrade.

**R2 — ViLTE native loader**
- Exact SHA-pinned candidate imports (do not broaden without a proven missing edge):
  - `libmtk_vt_wrapper.so`: `558a986533cd16dbb0ce8d4fb4e22fc56c13cf63394cce8610a285c7c32b9693`
  - `libvcodec_cap.so`: `9f021676c84eb0a081e23e5741a84bbe4ca856d6ff71e72e5d453da084596ca7`
  - `libvcodec_capenc.so`: `e7c53409aaefc3c9d1db9041527eafce9d835e033b4cdb4f4c2562c1e664b0fd`
  - `vendor.mediatek.hardware.videotelephony@1.0.so`: `a13b98d8dfa595d0721e49c0b9e4dcff94fadaeb3beef2728e4fe51842da0de6`
  - `vendor.mediatek.hardware.videotelephony-V1-ndk.so`: `3b5c5355f0fc91683c8f1ea0ee6168ba8bfd62ec35d6a9aceaab6d944783ad70`
- P0-AV host identity: PASS all five ELF64 AArch64 SHA pins; `DT_NEEDED` direct counts 20,15,6,8,7. P0-AO Bionic version subset: 19/19. **No full recursive or namespace symbol pass.**
- Before copyout: bind exact **observed runtime installed** system/system_ext/product/vendor/APEX paths and the intended *derived candidate* partition layout. The historic D1R2 embedded copyout and offline R3 standalone system_ext source cannot be conflated.
- Native gate: recursively traverse all five DT_NEEDED trees; resolve provider order and every strong UND + symbol-version requirement in the relevant IMS classloader namespace (HIDL `libhidlbase`, possible `libhidltransport`; NDK `libbinder_ndk`; APEX vs system vs vendor). Classify absent authority BLOCKED, proven incompatible REJECT; no global-symbol-pool shortcuts.
- No runtime libc/libdl/libm replacement; no automatic ViLTE disablement.

## Immediate developer handoff — work on the actual flashed image

1. **Use existing evidence, not broad rediscovery:** R8Q3 `live_paths.tsv`, `mounts_full.txt`, `classpath_env.txt`; R8R `live_components.tsv`; R8M radio timeline; operator's existing ADB cellular diagnostic script and exact flash journal if already retained. First distinguish observed running layout from offline R3 reference composition.
2. **Define precise target files, no modifications yet:** effective platform manifest R1 owner, OEM IMS package intended location, five `.so` candidate staging paths and source provenance. Do not import historical D1R2 seven-JAR bootclasspath or `MtkTeleService.apk`; preserve known working N1F/Atlas substrate and actual vendor/boot conditions.
3. **Reuse existing analyzers where possible:** qualify R2 recursive DT_NEEDED, symbol versions and app namespace against the selected parent. Keep the scope to the five pinned libraries.
4. **Produce an exact patch plan:** changed-file allowlist, expected before/after hashes, proposed build/repack driver entry point, target partition-size/AVB implications, rollback reference, all Titan-specific regression checks. A new branch/worktree only after approved mutation authority; preserve dirty canonical worktree.
5. **Only after separate authorization:** stage and build an isolated candidate, seal its bytes and follow the canonical mode-aware Titan deployment process. No implicit whole-super flash or factory reset. Evaluate cellular stability separately from IMS startup.

## Acceptance contract for handoff to implementation

```text
ACTIVE_EXPERIMENT=OCT11_HYBRID_RUNTIME
ADB_CELLULAR_TOGGLE=TEMPORARY_DIAGNOSTIC_ONLY
CELLULAR_STABILITY=FAIL_RECURRENT_DISABLEMENT
R1=PASS_STATIC_REMEDIATION_CANDIDATE
FIVE_NATIVE_SHA_AND_ELF=PASS
R2_TRANSITIVE_AND_SYMBOL_SCOPE=BLOCKED_PENDING_EXACT_RUNTIME_TARGET
OCT11_HYBRID_IMAGE_FLASH_JOURNAL=UNBOUND
RUNTIME_IMS_APK_TESTED_PATHS=NOT_LISTED
IMPLEMENTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

**No extra audit sequence is implied.** The next engineering action is a focused source/partition placement review from retained data and a draft minimal patch plan; do not collect the same evidence again.
