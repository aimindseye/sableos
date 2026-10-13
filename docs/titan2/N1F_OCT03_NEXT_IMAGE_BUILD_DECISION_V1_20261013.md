# Titan 2 N1F — next-image construction decision V1 (after G123 catalog ai-g732 PASS)
Date: 2026-10-13. **Decision / source-scope planning only**, no execution. Active PR #342 is DRAFT and unmerged.

## Latest actual operator checkpoint

The operator verified `N1F_P342_G123_REUSE_V1.zip` SHA256 `ad7ffeea5d5fbd00d256946d3b86136d326227c632a4aba7aaf4a391a4486850` **PASS** and all five internal payload SHA256SUMS **PASS**. The operator's **20/20 Python tests passed (0.031 seconds)**; the intentionally invalid `inspect` argument emitted argparse usage in test 12 and was correctly accepted as a **negative regression PASS**, not a runtime failure. Actual `report` status `PASS_CATALOG_INTEGRITY_ONLY_NO_NEW_ENGINEERING_ADMISSION`; `image_bytes_read=0`, `input_evidence_revalidated=false`, no build, network, device, output file, flash or mutation. Historical M4 G1/G2/G3 scoped PASS correctly retained, and new target deltas remain OPEN. **Do not rerun this catalog or its old 20 tests.**

This is a **ledger-integrity PASS only**, not a new SHA/signature/ABI verification of the ai-g732 artifacts.

## Existing implementation plan and source/tool reuse

Use archived [PR #339 exact M4 mutation/build plan](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1F_M4_EXACT_MUTATION_AND_BUILD_AUTHORIZATION_PLAN_20261012.md) and [embedded IMS contract](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md), **not their archived Oct11 parent assumptions or a write-capable script**. PR #339 is closed UNMERGED, so referenced documents may exist on that archival branch **but not on main**. Existing current main `product/titan2/n1i-c1/sable-titan2-n1i-c1.mk` already defines the **six C1 packages, two boot JARs and two configured-JAR overrides**; exact `Android.bp` defines C1 import owners. The historical Oct03 `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh` is a combined build/flash driver with `--authorize-build`/`--authorize-flash`; do NOT invoke it for static/source planning or for the next integration. C1 postbuild driver pins old C1 image and is not a valid next-image validator without explicit refactoring and tests. Main `build/config/host-tools.env` defines canonical SDK build tools 36.0.0, `secilc`, `lpdump`, `lpmake`, `avbtool` under `/srv/data/sable-host-tools`; this establishes configured paths, **not their actual present/executable status on ai-g732 today**. Host-only next-image design uses **no host binary/tool invocation**.

The original Oct03 N1F parent file `/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img`, **3,200,540,672 bytes**, SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, was SHA-verified once on ai-g732 in the separately authorized B1 scope. The retained historical physical boot is a distinct receipt; October 11 flash artifact lineage remains unbound. Do not rehash the parent or call the October 3 physical companion seven SHA-bound.

## Minimum *next source* allowlist to submit for separate approval

| Component | Exact source/path family and rule | Previously qualified | Required before new integration |
|---|---|---|---|
| **R1 protected broadcast** | Android 16 selected `frameworks/base/core/res/AndroidManifest.xml`; add only one protected declaration for `com.mediatek.common.carrierexpress.operator_config_changed` if absent | Earlier preview and selected M4 state in PR339 | Pin selected **Oct03-derived** source exact blob and post-state; do not blindly copy an M4 diff |
| **B1 TelephonyMetrics overload** | `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java`: prior one exact `writeRilAnswer(II)V` overload/no-op compat correction, only if PRE | M4 PRE `27638e5be9c008101c2f9b8f1e7a9af49d94f838` → POST `9d5108e0ddb8d4960d21cda021813b53dbbf4da8` recorded in PR339; selected M4 B1 already POST | If new source POST, **do not reapply**; if PRE, apply only under approval; any third blob **BLOCK** |
| **C1 IMS island** | Reuse existing `product/titan2/n1i-c1/Android.bp` and `sable-titan2-n1i-c1.mk`: ImsService, two MediaTek JARs, three XML packages, exact two boot JARs and configured location overrides | M11 APK platform signer/manifest PASS, M4 11/11 embedded-member content PASS and API36 exactly one enabled boot record each | Bind selected source manifest/product inheritance and final **embedded** `/system/system_ext` effective files; do not infer from module names alone |
| **PHH/marker and SELinux** | Reviewed Titan-specific mtkmal marker and C1 private system_ext sepolicy only | Bounded source/marker and M4 hashed compiled `plat_sepolicy.cil`/`plat_file_contexts` PASS | Effective merged SELinux, package UID/privapp and actual mount/init semantics remain admission gates |
| **skip_mount** | Preserve embedded `/system/system_ext/etc/init/config/skip_mount.cfg` and compatibility symlink `/system/etc/init/config` | M4 source-vs-stage exact bytes and symlink, SHA256 `0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e` PASS | In new image confirm byte identity/effect; no standalone stock `system_ext_a` or `product_a` content replacement |
| **R2 five native ELF candidates** | Five historically pinned AArch64 ViLTE files under candidate `/system/system_ext/lib64` | Five identities, 56 direct NEEDED, 19 Bionic, V28 four direct symbol bindings, six M4 ELF probes PASS at scoped inputs | **HOLD** copyout until full recursive GNU strong symbols/versions, APEX/vendor provider and actual IMS process namespace closure |

No broad D1R2 seven-JAR/33-native imports, `MtkTeleService.apk`, blanket property toggles, new system/vendor/boot/AVB/slot changes, direct firmware edits or C1 historically pinned flash scripts.

## Two distinct execution milestones — both NOT authorized

**A — isolated Oct03-derived R1+B1+C1 HOST BUILD ONLY (proposed).** This is a design option to obtain a final-image G1/G2 admission specimen without assuming G3. Reuse existing source/OUT where safely selected and exact pins reconcile; never reset, clean/clobber, overwrite, or resync a dirty 119GB worktree. Apply only the separate approved allowlist, build incremental `systemimage` with a separately approved invocation and output path, examine only *new* image-specific files/compiled authority. **No device contact, no super packaging, no physical flash**, because historical VT crashes with `ImsService` and missing R2 remain a material unresolved risk. Host-only build success alone cannot confer IMS runtime or boot safety.

**B — Oct03-derived R1+B1+C1+R2 next FULL IMS integration candidate (future).** Additional prerequisite **G3 effective recursive ELF and app namespace PASS** (not just direct V28); final image G1/G2 compiled/mount/classloader/policy PASS; exact final image seal. This is still **not** permission for a complete super repack or physical flash. Independent physical Oct03 companion SHA, postflash LP/Virtual A/B snapshot/COW/AVB chain, matched stock restore and whole-super assembly gates remain separate. LTE cause-13 instability remains independent.

### Release and test separation

Do not conflate: `HOST_BUILD_READY` vs `FULL_IMS_IMAGE_STAGED` vs `OFFLINE_SUPER_READY` vs `PHYSICAL_FLASH_READY`. Physical M4 `system_a` write succeeded at transport but Android landed in Recovery. It is **not** a parent that can be certified by the earlier static checks; failed reset and currently reported fastbootd mode do not themselves establish causal root or any new write authority.

## Immediate exact outstanding evidence (no scans or new execution)

1. Identify existing exact Oct03-relevant source/worktree/manifest revision against **selected** new source; determine how inherited R1/B1/C1 source/PRE/POST states reconcile, using retained Oct03 archive and PR339 M4 receipts before preparing a mutation script. No redoing 991/991 project census.
2. For building option A only, prepare an isolated mutation/build authorization request with paths, file SHA/Git blobs, expected deltas, no-clobber OUT, compiler tool pins and target rules. No source or build execution without explicit approval.
3. In parallel, assess remaining R2 **namespace-only** delta (not another five ELF hash/56-edge crawl), and Oct03 companion/restore provenance. The proposed R0C 256 immediate TEE14 name inventory has **not** been separately approved or run. Receipt file contents, additional image hashes, LP/AVB binary inspection remain prohibited.
4. Only after artifact exists and distinct authority, check new final-image content rather than copying all M4 PASS statuses across build identities.

```text
G123_CATALOG_AI_G732=PASS_20_OF_20_AND_REPORT
G123_CATALOG_STATUS=PASS_CATALOG_INTEGRITY_ONLY_NO_NEW_ENGINEERING_ADMISSION
PRIOR_M4_G1_G2_G3_SCOPED=PASS_REUSE
OCT03_PARENT_HOST_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
NEXT_IMAGE_SOURCE_BASE=NEEDS_EXACT_SELECTED_REVISION_BINDING
OPTION_A_R1_B1_C1_HOST_BUILD=PROPOSED_NOT_AUTHORIZED
OPTION_B_R1_B1_C1_R2_FULL_IMS=BLOCKED_G3_AND_FINAL_ARTIFACT
OCT03_PHYSICAL_COMPANIONS=UNBOUND_7_OF_7
R0C_256_NAME_INSPECTION=NOT_AUTHORIZED
R1_EXACT_RECEIPT_CONTENT=NOT_AUTHORIZED
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO IMAGE_EXTRACTION=NO SUPER_REPACK=NO DEVICE=NO FLASH=NO
```
