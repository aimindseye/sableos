# TB2 Android 14 OEM delta baseline — governing plan

Status: **Phase 1 planned and tool qualification in progress; comparison not yet accepted**.
Scope: Titan 2 V01.00.14 Android 14 stock against a pinned *standard* Android 14 reference, then later reconcile against the exact PR347 Android 16 product and the physically booted C3A control.

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
