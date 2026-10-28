# TB2 stock OEM-versus-upstream framework delta — governing plan (mixed Android 16 system / Android 14 vendor)

> **2026-10-28 CRITICAL BASELINE CORRECTION — authoritative for all later phases.**  
> V01.00.14 is not demonstrated to be an Android 14 system-framework build. The recovered stock handset reported `ro.build.version.release=16`, system fingerprint `Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys`, and **vendor** fingerprint `Unihertz/Titan_2/Titan_2:14/UP1A.231005.007/V01.00.14:user/release-keys` (N1C 2026-09-30 postmortem). Official AOSP maps BP2A.250605.031.A3 to **`android-16.0.0_r2`**, and UP1A.231005.007 to **`android-14.0.0_r1`**. These build IDs identify candidate upstream comparisons, not exact OEM source provenance.  
> The owner-qualified Phase 1 archive and source custody **passed**: stock four pinned partitions; AOSP14 official GSI `68dd726a...`; 1,224-project `android-14.0.0_r1` manifest; 106 stock vs 124 AOSP14 JAR/APEX files; 190 path rows. **That is binary/source custody PASS, not a version-matched OEM-vs-AOSP framework-delta PASS.** Its `DIFFERENT_BYTES` and one-sided APEX records are cross-version/packaging evidence only.  
> **Revised baseline comparison:** stock V01.00.14 **Android 16 system/system_ext/product** versus version-matched standard AOSP 16 (initial candidate `android-16.0.0_r2` with matching official `aosp_arm64-exp-BP2A.250605.031.A3-13578795-82277143.zip`, published SHA256 `8227714351abe504eb27920d0e95c1b672722d2b7c9c9610dad2aee768624add`). Independently compare **Android 14 vendor interfaces and BSP behavior** against appropriate vendor-compatible references; standard GSI has no matching vendor partition and cannot prove OEM vendor deltas by itself. Retain already downloaded AOSP14 as legacy vendor/version reference, not the stock system's matched framework control.  
> **Immediate next gate:** read exact `BUILD_PROP_OBSERVATIONS.json` from the accepted Phase 1 receipt, reconcile system-vs-vendor evidence without re-extracting images, then admit only source/binary-matched AOSP16 framework comparison. Do not start Phase 2 ABI comparisons with mismatched releases, do not attribute 190 path rows to OEM mods, and preserve the independent C2 Zygote fatal hold.  
> **Correction reference:** [N1C stock build properties](https://github.com/aimindseye/sableos/blob/main/docs/titan2/N1C_FIRST_WRITE_POSTMORTEM_20260930.md); [official Android build numbers](https://source.android.com/docs/setup/reference/build-numbers); [official GSI checksum](https://developer.android.com/topic/generic-system-image/releases).

Status: **Phase 1 original AOSP14/stock binary and source custody passed; stock-system version-match rejected (A16 vs A14); corrected rebase V1.2 awaits owner replay**.
Scope: Titan 2 V01.00.14 Android 16 stock system versus a pinned standard AOSP 16 candidate, with its Android 14 vendor interfaces tracked in a separate lane; later reconcile with exact PR347 Android 16 and physically booted C3A.

## Why this track takes priority

Start with **AOSP Android 14 → OEM/MediaTek Android 14** before evaluating what is missing from Android 16. An Android 14 → Android 16 textual/JADX diff alone conflates upstream version evolution, OEM/vendor modifications, compiled optimization/decompiler artifacts, and runtime product selection. The output is an **OEM delta catalog**, not a patch list. Preserve the original 4,785-difference claim as *unrecovered/unverified*; do not treat it as 4,785 ABI failures.

## Governing comparisons

- **A — standard Android 14**: candidate tag `android-14.0.0_r1` because `UP1A.231005.007` maps to that AOSP release. This is **not** an assertion that the stock OEM build was based on precisely that source revision. Capture a complete, immutable `repo manifest -r` / project SHA set, and independently capture a comparable AOSP 14 GSI build's image provenance (prefer official ARM64 AOSP GSI from the same build ID). Distinguish *AOSP source* from a *prebuilt Google GSI image*; the latter is not bit-identical to a source-built product.
- **B — stock V01.00.14**: only the historical TEE14 bit-equivalence partition inputs, not a similarly named firmware corpus. The known stock `system.img` SHA-256 is `b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd` (retained N1I-A result, independently verify bytes). Existing exact pins: `system_ext.img` = `1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170`, `product.img` = `de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37`, `vendor.img` = `cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada`.
- **C — SableOS PR347**: exact branch / source commit, Android 16 source and compiled image, *selected* FLOSS `me.phh.ims` product graph; no automatic use of OEM `com.mediatek.ims` evidence.
- **D — C3A control**: physically booted public Restless/TrebleDroid compatibility-superset, not release authority. Its published 369 patches may explain already-repaired behavior.

## Phase 1 — exact provenance and binary/byte inventory

1. Verify read-only input hashes, file formats (raw ext4, EROFS, Android sparse), source tag versus resolved source commit/manifest, and image metadata: build ID, fingerprint, SDK, security patch, partition and product. Do **not** infer an OEM upstream revision solely from the stock fingerprint.
2. Extract only to an isolated fresh output under the evidence directory. Inventory **per-partition** `*.jar`, `*.apex`, `*.capex`, and `etc/boot-image.prof`/bootclasspath and related declarations as available. Record relative path, bytes, SHA-256, ZIP member counts, `classes*.dex` presence, compressed APEX payload presence, and unreadable/odex/vdex-only cases. Include `/system`, `/system_ext`, `/product`; distinguish vendor/odm, preserved device-specific payloads, and system-side framework modules.
3. Compare by **partition + exact installed path**, not just a basename. Record stock-only/AOSP-only/common with differing hashes and module packaging, but never call byte inequality a source-level behavior change. Track APEX Mainline module release drift and classpath ordering separately.
4. Require comparable AOSP14 system image and revision-pinned source manifest for **FULL_PHASE1_QUALIFIED**. If absent, emit a sealed partial stock inventory and `HOLD_AOSP14_REFERENCE`; if stock image hashes do not match, fail closed. AOSP14 GSI may not contain stock OEM system_ext/product partition counterparts; mark those as **NO_AOSP_COUNTERPART**, not OEM-added code.
5. Preserve the preexisting N1I-A report and N1I C1/C2 ABI evidence. No broad rerun of 11,072 V5 rows in Phase 1, no unbounded bytecode decompilation, no automatic source patches.

## Phase 2+ — do not skip

Phase 2: class, field, method, access flags, interface and classloader/bootclasspath ABI comparison on comparable DEX/code, with exact member ownership. Phase 3: targeted bytecode/control-flow and method behavior; Ghidra/JADX only for high-signal candidates. Phase 4: IMS/QNS/IWLAN, modem/RIL, SIM/DSDS, init/SELinux, permissions, properties, native/UA startup, overlays. Phase 5: reconcile each proven OEM delta with C3A and current PR347, classify `ALREADY_PRESENT`, `OEM_ONLY_NOT_SELECTED`, `AOSP14_GSI_VARIANT`, `UPSTREAM_VERSION_CHANGE`, `POTENTIALLY_REQUIRED`, `PROVEN_CURRENT_CALLER_PROVIDER_GAP`, or `UNPROVEN`.

Only `PROVEN_CURRENT_CALLER_PROVIDER_GAP`, backed by exact source image and direct DEX caller/provider evidence, can advance to a narrowly scoped Android 16 patch review. Patching the selected FLOSS stack based solely on stock OEM IMS calls is forbidden.

## Existing reuse and caution

- `build/titan2/audit-n1i-a-v010014-oem-ims.sh` has stock image pins, image-type detection, ext4/EROFS/sparse handling, and N1I-A dependency closure; reuse its input model and avoid re-extracting whole firmware unnecessarily.
- `docs/titan2/N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE.md` reports **zero** direct missing stock-AOSP-framework class references from the *examined OEM IMS APK* versus C3A, which is a limited static result, not an assertion that no stock OEM modifications exist.
- V3: 72,984 entries walked, no original structured 4,785 ledger recovered. V4: 180 candidates, 0 new current PR347 ABI gaps proven. V5: 11,072 historical rows; 3,891 unique exact member signatures; 0 new current PR347 ABI gaps proven.
- Known C1 OEM `TelephonyMetrics.writeRilAnswer(II)V` overload has an exact historical patch; the inspected PR347 A16 source remains at base blob `27638e5be9c008101c2f9b8f1e7a9af49d94f838`. The active product currently selects FLOSS `me.phh.ims`, so applying the OEM-only patch is **not** automatically authorized.
- PR347 C2 physical image reached Android 16 ADB but `init.svc.zygote=restarting` and `sys.boot_completed` never reached 1; sealed Zygote fatal evidence still missing. Keep that boot investigation **parallel**, not conflated with framework-delta analysis.

## Admission and stop conditions

`PHASE1=PASS` requires: verified stock pins; independently pinned AOSP14 source revision and binary reference; independently verified extraction-to-inventory provenance; complete JAR/APEX inventory for provided comparable partitions; explicit omitted/incomparable module coverage; reproducible inventory SHA seal; and no data/source/device writes. If a baseline is absent, status must be **HOLD**, never PASS.

`BUILD=NO`, `FLASH=NO`, `DEVICE_CONTACT=NO`, `SOURCE_PATCH=NO` throughout this forensic track. PR342/344/345/346/347 safeguards, signing/AVB, source convergence, and physical IMS gates remain authoritative.

## Next checkpoints (do not sidetrack)

1. Phase 1: qualify A14 stock + standard A14 with exact comparable JAR/APEX inventory.
2. Phase 2: derive stock-only ABI extensions versus AOSP 14; separate source/version/DEX provenance.
3. Phase 3: targeted bytecode behavior (IMS calls, SIM, radio and subscription).
4. Phase 4: cross-layer native/config/service closure.
5. Phase 5: current PR347 Android 16 gap admission; one reviewed finite patch set **only if proved**.

This plan does not replace the independent C2 Zygote fatal capture required for any further image acceptance.

## Reference links
- AOSP build IDs: https://source.android.com/docs/setup/reference/build-numbers
- AOSP 14 r1 manifest: https://android.googlesource.com/platform/manifest/+/refs/tags/android-14.0.0_r1
- OEM closure: https://github.com/aimindseye/sableos/blob/main/docs/titan2/N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE.md
- C3A booted control: https://github.com/aimindseye/sableos/blob/main/docs/titan2/N1D_C3A_CONTROL_R1.md
- PR347: https://github.com/aimindseye/sableos/pull/347

## Phase 1 execution checkpoint — 2026-10-28

Owner executed the Phase 1 stock/AOSP14 inventory and preserved its sealed result at `/srv/sable-build/evidence/titan2-a14-phase1-inventory-20261028T135100Z`. The **binary/source custody** check reported `PASS_PHASE1_BINARY_AND_SOURCE_CUSTODY`, 106 stock JAR/APEX, 124 AOSP14 JAR/APEX, 190 raw path comparisons, manifest `e3f9241982f55ef4cec97df0c55e9b87d37a5656` with 1,224 projects. Its extracted `BUILD_PROP_OBSERVATIONS.json` showed stock system Android 16 / SDK 36 / `BP2A.250605.031.A3` versus AOSP GSI Android 14 / SDK 34 / `UP1A.231005.007`; hence **version-match qualification HOLDS**. These 190 path rows are not OEM-change findings.

The Phase 1 Version Rebase V1 host run passed 15/15 regression tests but prematurely rejected `stock-product.erofs.log` as `EMPTY_FILE`: this **SHA-sealed zero-byte extractor diagnostic is valid**, because a successful EROFS extractor may produce no error text. A corrected **Version Rebase V1.1** makes only a narrow checksummed-extractor-log exception and keeps all required evidence nonempty; it locally passed 21/21 regressions, including 190-row receipt replay. The owner **has not yet run V1.1 on the real receipt**; report-only status remains pending that replay. Do not repeat image extraction and do not relax the source/hash/version checks.

The next matched framework control remains stock V01.00.14 A16 versus exact AOSP16 r2 candidate source/GSI; AOSP14 remains relevant to the separately analyzed vendor/compatibility lane. No PR347 build, source patch, device contact, flash, or cellular acceptance is authorized by this checkpoint.

## Phase 1 V1.2 consumer/producer label correction — 2026-10-28

Real owner execution of **Version Rebase V1.1** passed 21 unit tests but stopped at `PHASE1_VERSION_REBASE=HOLD INVENTORY_COUNT_DRIFT` before writing a report. Root cause established by inspecting the original Phase 1 inventory producer `qualify.py`: its `IMAGE_PROVENANCE.tsv` uses `side=AOSP14_GSI` for the archive, while its `ARTIFACT_INVENTORY.tsv` uses `side=AOSP14` for extracted JAR/APEX artifacts. The rebase V1.1 consumer and synthetic fixture incorrectly counted the archive-side label in the artifact inventory. This is a report-consumer/fixture defect, not image custody drift.

**V1.2 corrected deliverable** counts only `STOCK` and `AOSP14` artifact sides, explicitly rejects foreign/unknown sides, and preserves all 190-row/106+124 count checks, stock/GSI/source hashes and zero-byte checksummed extraction-log allowance. Locally verified: Python AST and Bash syntax PASS, 26/26 regression tests PASS, fresh ZIP extraction + SHA seals PASS; 10,000-row parser median 0.008321s (9 samples). **Owner real receipt rerun pending**. Expect `HOLD_CROSS_VERSION_FRAMEWORK_BASELINE`, `rows_reclassified=190`, `inventory_counts_verified={STOCK:106,AOSP14:124}`, `new_oem_abi_gaps_proven=0`, `a16_patch_admitted=false`.

No new image extraction, source edits, C2 boot/flash, or Android 16 ABI patch admission is permitted by the corrected report. Only after this baseline gate can we qualify a standard AOSP16 source/GSI reference against the V01.00.14 A16 stock **system**. Keep Android14 vendor separate. Do not mistake source-version changes or APEX packaging differences for OEM behavior modifications.

## Phase 1 V1.2 owner-confirmed replay — 2026-10-28

Owner completed V1.2 against the **actual sealed** prior Phase 1 receipt. Archive SHA-256 and all member hashes PASS; 26/26 unit tests PASS; original artifact side counts `STOCK=106` and `AOSP14=124` reconciled; `rows_reclassified=190`; final receipt SHA seal PASS at `/srv/sable-build/evidence/titan2-phase1-version-rebase-v1_2-20261028T142632Z`. Result: **`HOLD_CROSS_VERSION_FRAMEWORK_BASELINE`** with `new_oem_abi_gaps_proven=0`, `a16_patch_admitted=false`, no build, patch, device, or flash. This is now the **accepted V1.2 verdict**, not an outstanding V1.1/V1.2 validation blocker.

The **next active baseline is AOSP16 r2** for the stock V01.00.14 Android 16 **system**: AOSP16 manifest commit `6650f1e0458a5450156c0348fe0dc96acb958eb8` (tag `android-16.0.0_r2`), official ARM64 no-GMS GSI `aosp_arm64-exp-BP2A.250605.031.A3-13578795-82277143.zip` SHA-256 `8227714351abe504eb27920d0e95c1b672722d2b7c9c9610dad2aee768624add`. Preserve AOSP14 evidence for vendor compatibility only. Do not promote file-byte differences to OEM behavioral claims or auto-admit patches; the boot failure's Zygote fatal gate remains independent.

## Phase 1 matched AOSP16 qualifier package — 2026-10-28

The V1.2 **actual owner replay** is accepted at `/srv/sable-build/evidence/titan2-phase1-version-rebase-v1_2-20261028T142632Z`: all 26 unit tests passed, `STOCK=106` and `AOSP14=124` inventory counts verified, 190 path rows reclassified as cross-version/incomparable, complete result SHA seal PASS, zero ABI gaps and no A16 patches admitted. The cross-version HOLD is not a tool failure.

Next **host-only** deliverable: `TB2_A16_MATCHED_BASELINE_PHASE1_V1.zip` SHA-256 `da4e433899ddc51a01a755f8f57809214e044b0218178997c1859a86c09ebedb`. Read-only `qualify_a16.py` reuses the archived Phase1 `qualify.py` helper, validates the entire prior sealed receipt and the four stock partition image SHA pins, and reuses 106 prior stock JAR/APEX inventory rows without stock re-extraction. It checks a new source root at `android-16.0.0_r2` manifest commit `6650f1e0458a5450156c0348fe0dc96acb958eb8` with fully resolved revision SHAs, official AOSP ARM64 no-GMS GSI `aosp_arm64-exp-BP2A.250605.031.A3-13578795-82277143.zip` SHA-256 `8227714351abe504eb27920d0e95c1b672722d2b7c9c9610dad2aee768624add`, and `BP2A.250605.031.A3` SDK36 system build properties on **both** sides. It extracts only the new AOSP16 GSI's `system.img` and records JAR/APEX path/byte inventory, with `NO_AOSP_GSI_PARTITION_COUNTERPART` for stock system_ext/product.

Archive fresh extraction SHA seals PASS, Python AST/Bash syntax PASS, 26/26 local tests PASS, 10,000-row synthetic performance measured; **real ai-g732 AOSP16 inventory not yet executed**. This version-matched first-pass custody result is an ABI-discovery starting gate, not direct proof of OEM patches: the stock March 2026 security patch vs AOSP16 r2 June 2025 may include ordinary backports; APEX container packaging/signature differences are not behavioral evidence. User must obtain source and GSI separately (follow download terms). **No PR347 build, patch, device, flash or C2 boot acceptance**.

## Owner-accepted matched A16 Phase 1 result — 2026-10-28

Owner ran `TB2_A16_MATCHED_BASELINE_PHASE1_V1.zip` on ai-g732 and returned the exact sealed receipt: `/srv/sable-build/evidence/titan2-phase1-a16-matched-20261028T152221Z`. Archive member SHA verification PASS, 26/26 regression tests PASS, result `PASS_PHASE1_A16_MATCHED_CUSTODY_AND_INVENTORY`. Reused 106 verified V01.00.14 stock JAR/APEX entries; AOSP16 r2 inventory 83; file-path comparison 145 rows; `prior_sealed_members_checked=12` and stock image SHA reverified, no image build or device contact. Matched AOSP16 GSI SHA `8227714351abe504eb27920d0e95c1b672722d2b7c9c9610dad2aee768624add`, extracted `system.img` SHA `cdb1186306bb24e1fd4c2fa5d19fd36d66efddb9eebf4ed5837f7b044de2ec2d`; source `android-16.0.0_r2` manifest commit `6650f1e0458a5450156c0348fe0dc96acb958eb8`, resolved manifest SHA `1bc1eaf4246292748dc883b5d86ad38678b4765c81d597e3a4a8e6fe5a0f49a4`, 987 projects. This is the first **matched Android major-version** binary/source custody control, but stock's security patch level (2026-03-05) differs from reference r2's 2025 vintage; it does NOT establish byte-identical upstream source, OEM authorship, or confirmed ABI gaps. New current ABI gaps proven=0; A16 patches/build not admitted.

**Next authorized work: Phase 2 exact DEX-member definitions**, focusing on *shared* system framework JARs (e.g. framework/telephony-common/ims-common/services/voip-common), not simplistic container SHA differences; report stock-only/provider-only member definitions, access flags, superclass and interfaces, and unresolved/no-dex cases. APEX module internals and system_ext/vendor require separate provenance-aware lanes. Findings remain candidates until source revision and caller/reachability proof. Reuse historical V3/V4/V5 ledgers as context, not conclusive evidence. Keep PR347 C2 boot fatal gate independent.

## Phase 2 V1 operator qualification — 2026-10-28

Exact owner-reported Phase1 A16 system match PASSED; next scoped read-only deliverable is `TB2_A16_OEM_EXACT_ABI_PHASE2_V1.zip`, SHA-256 `ce5ebd4e43c70aad43dcfed255e971ce50df9aa515c1afff9667620e5fac5dd0`, size 31,146 bytes. The standalone archive contains pinned copies of previously tested Phase1 readers and a DEX *class_data_off* defined-member parser, synthetic fixtures, 28 tests (PASS, including fresh-ZIP), Bash/Python syntax validation, and 10,000-member performance check median ~0.003349 seconds (local parser only; not a full image benchmark). No user host execution yet.

Scope: default system JARs `framework.jar`, `telephony-common.jar`, `ims-common.jar`, `services.jar`, `voip-common.jar`, `ext.jar`; preflight `plan` lists only exact shared paths, SHA-verified against sealed Phase1 A16 inventory. Full `compare` reads actual *defined* classes, fields and methods (not misleading DEX method-id references), access flags, superclass, interfaces. Every byte is compared against already sealed stock/AOSP16 SHA; new extraction occurs only to isolated temp work and is deleted by default. Archive, system_image and source manifest provenance reverified. Results are **ABI candidates**, not OEM-origin proof or active PR347 caller/provider gaps. APEX contents, vendor A14, security/backport source revision differences, method bodies and current PR347 product caller reachability stay for later phases. Source/firmware images are never imported into GitHub, flashed or patched.

**Owner next action**: run operator `plan` on `/srv/sable-build/evidence/titan2-phase1-a16-matched-20261028T152221Z`, check `TARGET_JAR_SELECTION.tsv`, then run `compare` with the shared JARs only. Stop if SHA/pin/source seal verification fails, and do not treat missing GSI counterpart as OEM modification. Preserve the C2 Zygote fatal hold.
