# N1F October 11 — minimal R1/R2 implementation specification
Date: 2026-10-12
Status: **PATCH SPECIFICATION ONLY / NOT AUTHORIZED TO MODIFY IMAGE**

**Entry point:** [CURRENT_ENGINEERING_STATE](CURRENT_ENGINEERING_STATE.md) → [EVIDENCE_INDEX](EVIDENCE_INDEX.md) → [R1/R2 handoff](N1F_OCT11_R1_R2_MINIMAL_CHANGE_HANDOFF_20261012.md). Continue draft PR #339 research; do not create another broad census track.

## Critical distinction: running image vs offline hybrid-super input

Observed on October 11 after operator-reported flash: `/system_ext -> /system/system_ext`, `/product -> /system/product`, and OEM `ImsService.apk` not listed at tested runtime locations. The separate *offline* R3 super manifest includes stock `system_ext.img` and `product.img`. These observations cannot be simultaneously treated as proof of one mounted composition without reconciling the actual flashed artifact. **Select a real running-image branch/reproducible build as target, not a made-up R3+C1 image.**

The temporary ADB enablement was diagnostic only; cellular subsequently became disabled again. Any proposed IMS startup fix has **zero established causal effect** on RIL registration collapse.

## Minimal edit manifest — gated and intentionally incomplete

| ID | Proposed edit | Decision | Evidence gate |
|---|---|---|---|
| R1-01 | Add `<protected-broadcast android:name="com.mediatek.common.carrierexpress.operator_config_changed" />` in the Android platform manifest owner of the **selected image** | **STATIC_CANDIDATE_ONLY** | Resolve exact git owner and merge location; check already present; run merge/security negative tests |
| R2-01 | Stage *only* five pinned stock ELF64/AArch64 libraries | **PROVISIONAL** | Actual OEM IMS APK installed? Namespace can reach selected mount path? Recursive DT_NEEDED / strong symbols / versions all pass |
| R2-02 | Wire five libraries through selected image's own product/build/staging mechanism | **NOT YET SELECTED** | Must resolve whether output is embedded `/system/system_ext/lib64`, independent `system_ext.img`, or another tested and accessible path. Historical D1R2 assumption prohibited |
| R2-03 | Add exact SHA-256 allowlist, no alternative stock-lineage substitution | **REQUIRED** | Source provenance `/srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp-stock/20261005T231205Z/files/system_ext/lib64/` checked before copy |
| IMS-01 | Add/preserve OEM `ImsService.apk` and any required service declarations | **NOT ADMITTED** | Not listed on observed runtime; stock APK inventory alone does not authorize injecting new APK, boot JARs or broad C2 composition |

Five immutable library pins:
```text
libmtk_vt_wrapper.so 558a986533cd16dbb0ce8d4fb4e22fc56c13cf63394cce8610a285c7c32b9693
libvcodec_cap.so 9f021676c84eb0a081e23e5741a84bbe4ca856d6ff71e72e5d453da084596ca7
libvcodec_capenc.so e7c53409aaefc3c9d1db9041527eafce9d835e033b4cdb4f4c2562c1e664b0fd
vendor.mediatek.hardware.videotelephony@1.0.so a13b98d8dfa595d0721e49c0b9e4dcff94fadaeb3beef2728e4fe51842da0de6
vendor.mediatek.hardware.videotelephony-V1-ndk.so 3b5c5355f0fc91683c8f1ea0ee6168ba8bfd62ec35d6a9aceaab6d944783ad70
```

## Actionable targeted engineering tasks

**Task A: R1 manifest owner.** In the *specific source tree used to produce the current running image*, locate framework manifest and any product overlays that generate protected-broadcast declarations; record path, source SHA, commit and effective final manifest before choosing the one-line edit. Rule out duplicate declarations. Do **not** modify APK, ContextImpl, receiver registration API, target SDK, or unrelated broadcasts. This is an implementation location check, not a broad artifact census.

**Task B: IMS runtime installation prerequisite.** Reuse R8Q3 `pm_all.txt`, `live_paths.tsv`, full mounts and R8R evidence already captured. Determine why OEM IMS was not listed, and whether it is embedded in the prospective chosen parent. The five native libraries are not sufficient to make absent OEM IMS APK operational. If absent, stop R1/R2 implementation and write a separately reviewed minimal OEM IMS inclusion contract—not the retired D1R2 broad stack.

**Task C: R2 native admission.** Reuse exact five hashed ELF files and on-hand `readelf`/existing B2 analyzers; recursively map NEEDED with dependency identity and provider location, inspect GNU versions and strong undefined symbols, then apply effective linker namespace for the IMS app. A check against the stock vendor namespace *alone*, or a global ELF symbol union, is not acceptance. Block on missing source image/APEX/provider/namespace facts; preserve results as concise TSV with `dependency,provider,namespace,symbol_version,decision,evidence`.

**Task D: derived image build planning.** Once A-C close and an exact running-image source commit/image lineage is selected, produce only:
- precise changed-file list and one-line R1 diff;
- five-library copyout/build definitions, with SHA hash checks before staging;
- module/package prerequisites explicitly admitted;
- incremental image build in isolated clean worktree (do not modify current dirty SableOS checkout);
- image size/partition geometry and AVB tests;
- regression checks: manifest effective action, no extra protected actions, unchanged OEM APK hashes, exact five .so pins, unchanged C3A/N1F baseline except approved delta, and separate RIL stability flag.

No flash invocation is part of D. If using a hybrid-super rebuild, whole-super deployment is **not** silently authorized; Titan2 regression policy still holds.

## What not to repeat
- No P0-AZ/P0-BB image surveys or another all-tree hash census.
- No C1 APEX parity 15-mismatch proof as shorthand for R3 ABI failure.
- No D1R2 product graph, broad 33-native fallback, additional boot JARs, MtkTeleService, or AtlasOS healing loops by default.
- No assumption that ADB cellular toggles are a durable solution.

## Single blocking decision for the first patch

**Can the candidate target prove a working or intentionally staged OEM ImsService.apk and exact accessible `system_ext` native library path?**

Until the answer is YES with exact installed path/image layout, **R2 file-copy implementation is blocked**; R1 owner location can be reviewed in parallel.

```text
MILESTONE=M3_TO_M4_MINIMAL_PATCH_SPEC
STATUS=READY_FOR_TARGETED_SOURCE_REVIEW
R1_PROPOSED_SOURCE_MUTATION=ONE_PLATFORM_PROTECTED_BROADCAST
R2_PROPOSED_BINARY_MUTATION=FIVE_PINNED_LIBRARIES_ONLY
IMS_APK_PRESENT_IN_OBSERVED_RUNTIME=NOT_LISTED_AT_TESTED_PATHS
R2_FULL_ABI_AND_NAMESPACE=NOT_QUALIFIED
CELLULAR_ADB_WORKAROUND=NONE_TEMPORARY_DIAGNOSTIC_ONLY
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## 2026-10-12 IMS-01 architecture clarification (approved review feedback)

**Do not repeat the OEM APK location investigation.** Previously identified `/system/etc/init/config/skip_mount.cfg` suppresses physical stock `system_ext_a` and `product_a`; running `/system_ext` and `/product` refer to embedded `/system/system_ext` and `/system/product`. This explains the absence of stock OEM IMS from the October 11 N1F-based runtime. The proposed **IMS-01** inclusion path is embedded `/system/system_ext` within the derived **system.img**, not standalone stock `system_ext.img`. Re-enabling Android 14 stock partition mounts is not an approved solution. Read [IMS-01 embedded island contract](N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md). The contract limits additions to the prior C1 minimal IMS island plus R1 one-action broadcast and five R2 pins; D1R2 broad stack and MtkTeleService remain excluded. The precise prior C1 bytes and native namespace still require gate closure; no build or flash authority.
