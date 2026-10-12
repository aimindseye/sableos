# Titan 2 — current engineering state (2026-10-12)

**Read this before any new Titan 2 build, image integration, IMS patch or flash plan.** This document is a documentation-only reconciliation checkpoint in draft PR #339. It records observed results and unresolved provenance separately. It is not itself build, device or flashing authority.

## Active experiment

The operator reports that an Atlas-inspired hybrid-super image was successfully flashed on **2026-10-11** and then examined using ADB, including diagnostic ADB scripts that temporarily enabled cellular, followed by renewed cellular disablement / loss of registration. This was an investigation, NOT a successful or durable cellular-enablement procedure. The **specific write journal, actual flashed super SHA-256 and command sequence have not yet been supplied or tied cryptographically to that runtime session**. Do not call the October 11 physical outcome `NOT_PERFORMED`; equally, do not mark the local offline R3 artifact `PASS_PHYSICAL_BOOT` on this evidence alone.

The retained **offline R3 control** is `/srv/data/sable-build/evidence/titan2/n1f-atlas-hybrid-control-r3-virtual-ab-20261011/`. Its `authority.env` says `PHYSICAL_BOOT=NOT_QUALIFIED`, `CURRENT_DEVICE_MATCHED_FIRMWARE=NOT_QUALIFIED`, `LP_METADATA_INDEPENDENTLY_PARSED=NO`, and `FLASH_AUTHORIZED=NO`. These are the controls' **original offline authority**, not a retrospective verdict on all October 11 device activity.

Seven recorded R3 inputs, in source-sha256.tsv:
| Partition | SHA-256 | Bytes |
|---|---|---:|
| system | `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a` | 3200540672 |
| product | `de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37` | 1842647040 |
| system_ext | `1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170` | 704434176 |
| vendor | `cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada` | 873082880 |
| system_dlkm | `2752d357dc698db0967a3bbc9de2204127eab69fa28f7d3471d3e039e4a2946f` | 7487488 |
| vendor_dlkm | `1fc51fb7a2f089b3d9255d00944bda711e64b297daf2ecf687abeae17e0a4936` | 18366464 |
| odm_dlkm | `ebe714d1ed41742eeb87fa06674900703af97f90f729420fe37555bd02338723` | 348160 |

The system input is the N1F C3A-derived C3B5 image. Its **October 3 physical boot PASS** is separately documented in `docs/titan2/N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md`. That successful **system_a** flash is not evidence that the R3 **whole-super** was written on October 11.

## October 11 device runtime: observed

Host-retained evidence indexed in [the evidence index](EVIDENCE_INDEX.md):
- Android properties: `sys.boot_completed=1`, `dev.bootcomplete=1`; slot `_a`; stock-labelled V01.00.14 build/vendor fingerprints.
- R8Q3 live filesystem: `/system_ext -> /system/system_ext` and `/product -> /system/product`; `/vendor` mounted from dm-8 in captured mount table. **This runtime view is not proof that separate offline R3 stock system_ext/product images were mounted as distinct active partitions.** Inspect the live complete mount table and avoid projecting offline geometry onto runtime.
- R8Q3/R8R: `/system_ext/priv-app/ImsService/ImsService.apk` and its system alias `NOT_LISTED` / `NOT_ACCESSIBLE_OR_ABSENT` in observed paths. Stock reference contains the OEM APK. Absence from this listing is not absolute proof of package or feature absence elsewhere.
- SIM slot 1 reached READY and LOADED; voice/data briefly `IN_SERVICE` around 19:59:32 and 20:01:02, then `OUT_OF_SERVICE` at 20:01:02 on October 11. LTE/RIL root cause **not established**; separate from IMS native loading.
- Captured RIL `mtkNetworkIndication == NULL` diagnostic is a lead, not proof of cause.
- Operator clarifies ADB scripts were used **only to temporarily enable cellular for diagnosis**; cellular subsequently became disabled again. **This is a failed stability experiment, not a successful workaround.** Retain exact commands, timestamps and before/after evidence for root-cause analysis, not production reuse. Do not invent the command sequence from logs.
- The bridge report's `FLASH_EXECUTED=NO` means **the diagnostic script** did not perform a flash; it does not negate a prior device flash.

## Active proposed IMS delta (P0-AU design accepted; NOT implemented)

**R1:** add only the platform-protected broadcast `com.mediatek.common.carrierexpress.operator_config_changed` to address the specific WfcHandler flagless registerReceiver path. Verify effective manifest integration and stock sender policy. Do not repack the OEM IMS APK or bypass Android receiver security.

**R2:** five exact stock native candidates:
| Name | SHA-256 |
|---|---|
| `libmtk_vt_wrapper.so` | `558a986533cd16dbb0ce8d4fb4e22fc56c13cf63394cce8610a285c7c32b9693` |
| `libvcodec_cap.so` | `9f021676c84eb0a081e23e5741a84bbe4ca856d6ff71e72e5d453da084596ca7` |
| `libvcodec_capenc.so` | `e7c53409aaefc3c9d1db9041527eafce9d835e033b4cdb4f4c2562c1e664b0fd` |
| `vendor.mediatek.hardware.videotelephony@1.0.so` | `a13b98d8dfa595d0721e49c0b9e4dcff94fadaeb3beef2728e4fe51842da0de6` |
| `vendor.mediatek.hardware.videotelephony-V1-ndk.so` | `3b5c5355f0fc91683c8f1ea0ee6168ba8bfd62ec35d6a9aceaab6d944783ad70` |

Five ELF64/AArch64 inputs passed exact SHA verification in P0-AV; direct `DT_NEEDED` counts 20/15/6/8/7. P0-AO verified 19 Bionic symbols for a bounded subset; not global native admission. **Full recursive closure, namespace-reachable symbol/version resolution, exact target composition and selected image partition copyout are not yet qualified.** Historical D1R2 embedded `system/system_ext` layout is **not automatically** the R3 offline seven-partition layout. No change to OEM platform lib or automatic disablement of ViLTE.

## Priority and authority

1. Preserve October 11 flashed-image branch/artifact evidence and ADB cellular activation procedure; accept existing observed Android boot and radio loss without repeating tests.
2. Determine current **actual installed partition topology**, IMS APK presence and which prior flashing artifact/plan produced October 11 runtime. Use retained logs first, not a new device test.
3. Choose the verified running image as **working experimental parent**, recording unresolved provenance explicitly. Avoid returning to C1, C2, or D1R2 images without a new evidence-driven decision.
4. Perform targeted native compatibility and manifest admission against that parent. Only then authorize an isolated derived-image change.
5. Maintain complete Titan 2 flash-regression checks: mode-aware entry, exact artifact, no unreviewed whole-super write, no automatic retry/reset/slot/AVB changes.

```text
ACTIVE_TRACK=OCT11_HYBRID_SUPER_RUNTIME_PLUS_IMS_P0AU
ANDROID_RUNTIME_OBSERVED=PASS
CELLULAR_TEMPORARY_REGISTRATION=PASS_OBSERVED
CELLULAR_STABILITY=FAIL_REGISTRATION_LOST
OCT11_FLASH_REPORTED_BY_OPERATOR=YES
EXACT_FLASH_ARTIFACT_SHA_AND_JOURNAL=UNBOUND
OFFLINE_R3_PHYSICAL_QUALIFICATION=NOT_PROVEN
IMS_OEM_APK_AT_TESTED_PATHS=NOT_LISTED
R1=PASS_STATIC_REMEDIATION_CANDIDATE
R2=BLOCKED_FULL_NATIVE_CLOSURE_AND_TARGET
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

Historic C1/C2 and CW1/IMS1 evidence remains useful but does not supersede this active experiment. The C1 image SHA `137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160` was physically hashed on host in P0-AX; C1 APEX parity recorded 15 outer/inner/payload mismatches. Do not use C1 or D1R2 as the default target.

**Review history:** [Milestones](MILESTONES.md), [Evidence](EVIDENCE_INDEX.md), [PR #339](https://github.com/aimindseye/sableos/pull/339).

## 2026-10-12 IMS-01 architecture clarification (approved review feedback)

**Do not repeat the OEM APK location investigation.** Previously identified `/system/etc/init/config/skip_mount.cfg` suppresses physical stock `system_ext_a` and `product_a`; running `/system_ext` and `/product` refer to embedded `/system/system_ext` and `/system/product`. This explains the absence of stock OEM IMS from the October 11 N1F-based runtime. The proposed **IMS-01** inclusion path is embedded `/system/system_ext` within the derived **system.img**, not standalone stock `system_ext.img`. Re-enabling Android 14 stock partition mounts is not an approved solution. Read [IMS-01 embedded island contract](N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md). The contract limits additions to the prior C1 minimal IMS island plus R1 one-action broadcast and five R2 pins; D1R2 broad stack and MtkTeleService remain excluded. The precise prior C1 bytes and native namespace still require gate closure; no build or flash authority.
