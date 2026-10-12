# Titan 2 N1F M4 — exact mutation and isolated build authorization plan
Date: 2026-10-12. **PROPOSED CHANGESET ONLY — NOT EXECUTION AUTHORITY**.

Supersedes no prior raw evidence. Read [current state](CURRENT_ENGINEERING_STATE.md), [IMS01 embedded contract](N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md), [C1 source reuse](N1F_IMS01_C1_SOURCE_REUSE_PINS_20261012.md), and [R2 reuse matrix](N1F_M3_R2_PRIOR_EVIDENCE_REUSE_MATRIX_20261012.md) first. All modifications belong to an isolated N1F source worktree after operator approval; the existing dirty SableOS checkout and Oct 11 physical device remain untouched.

## Immutable control and exclusions

- Parent is the preserved N1F C3A-derived, five-app Android 16 source/image lineage, **not** historical C1/D1R2 as an entire replacement image. N1F known-good `system.img` SHA-256: `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, 3200540672 bytes.
- October 11 operator-reported hybrid flash is retained as an observed booting experiment. Exact written super/image journal not yet SHA-bound; do not misrepresent offline R3 composition as the cryptographically confirmed live image.
- Preserve `/system/etc/init/config/skip_mount.cfg`: standalone Android 14 `system_ext_a` and `product_a` remain bypassed; install into **embedded** `/system/system_ext` under the N1F-derived `system.img`.
- Exclude D1R2 seven-JAR and 33-native blanket imports, MtkTeleService APK, broad property forcing, AtlasOS healing loops, vendor/boot/vendor_boot/vbmeta/slot changes, factory reset.
- October 11 ADB cellular activation was temporary diagnostic only; the later recurrent disablement is an independent known FAIL, **not** an IMS fix verification.

## Exact source mutation allowlist — proposed

| ID | Source authority / path | Allowed change | Exact gate |
|---|---|---|---|
| R1 | `frameworks/base/core/res/AndroidManifest.xml` in the selected N1F platform source | Add one `<protected-broadcast android:name="com.mediatek.common.carrierexpress.operator_config_changed" />` | pre SHA `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c`, pre Git blob `a7675341e1575039845d09c64fa22006612cca4a`; post SHA `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`; Oct 12 preview PASS_NO_WRITE |
| IMS01-BP | existing `product/titan2/n1i-c1/Android.bp` and selected N1F product package inclusion | Reuse `ImsService`, `SableN1IC1MediatekCommon`, `SableN1IC1MediatekImsBase`, `SableN1IC1SystemExtPermissionsMediatek`, `SableN1IC1ImsSysconfig`, `SableN1IC1PrivappPermissionsMediatek` without duplicate modules | Stage existing C1 exact APK/JAR/XML payload and check platform signing, classpath installed stems / configured jar overrides |
| IMS01-T | `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java` | Reuse existing `writeRilAnswer(II)V` no-op compatibility overload **only if absent** | old Git blob `27638e5be9c008101c2f9b8f1e7a9af49d94f838` → post `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`; any third state BLOCK |
| IMS01-P | previously reviewed minimal C1 SELinux/privapp and PHH `mtkmal` gate | Reuse only previously source-pinned lines strictly needed by embedded IMS | Obtain source file and exact prior pins before allowing patch; no broad C2 integration/healing |
| R2 | existing approved exact stock materialization module(s), destination embedded `/system/system_ext/lib64` | Add exactly five pinned ELF64 AArch64 files, no broader copyout | Full recursive provider/SYMBOL_VERSION/IMS namespace reachability decision must PASS before these entries can be admitted |

Five immutable R2 file identities:
```text
libmtk_vt_wrapper.so 558a986533cd16dbb0ce8d4fb4e22fc56c13cf63394cce8610a285c7c32b9693
libvcodec_cap.so 9f021676c84eb0a081e23e5741a84bbe4ca856d6ff71e72e5d453da084596ca7
libvcodec_capenc.so e7c53409aaefc3c9d1db9041527eafce9d835e033b4cdb4f4c2562c1e664b0fd
vendor.mediatek.hardware.videotelephony@1.0.so a13b98d8dfa595d0721e49c0b9e4dcff94fadaeb3beef2728e4fe51842da0de6
vendor.mediatek.hardware.videotelephony-V1-ndk.so 3b5c5355f0fc91683c8f1ea0ee6168ba8bfd62ec35d6a9aceaab6d944783ad70
```

## Staging contract

All selected product install outputs must be verified in **embedded `system.img`** after compilation, independently of module flags (`system_ext_specific` alone does not prove physical target); effective paths must include `/system/system_ext/priv-app/ImsService/ImsService.apk`, `/system/system_ext/framework/mediatek-common.jar`, `/system/system_ext/framework/mediatek-ims-base.jar`, configured XML and, conditional on admission, five files under `/system/system_ext/lib64`. Preserve the original `skip_mount.cfg` byte identity.

No changing standalone stock `system_ext.img` or `product.img` to smuggle in invisible fixes. Do not silently substitute stock V01.00.14 platform framework components or downgrade target Android.

## Narrow gates remaining before authorizing source mutation

1. **Select exact isolated N1F source revision and product config:** confirm physical-Oct11 experiment relation; preserve original known-good `system.img`, and prove target source clean/detached (without touching canonical dirty checkout).
2. **C1 island source reuse:** capture exact existing staged APK/JAR/config source pins; confirm only six existing modules and strictly relevant SELinux/PHH gate wiring. Check JAR location override and original C1 bootclasspath regression. Nothing to discover again about APK absence from N1F runtime: `skip_mount.cfg` already explains it.
3. **R2 prior evidence reuse:** carry forward 5 SHA, 56 direct NEEDED and Bionic 19/19 subset; inspect only still-unclosed recursive symbol/provider/namespace deltas. Missing in R2 v2 stock-only lookup is input-coverage `UNKNOWN`, not a new missing-device result. Reject unsafe vendor-private dependencies unless explicitly accessible from IMS process.
4. **R1:** source SHA/one-line preview already PASS; no new source discovery. Retain post-build final `framework-res.apk` protected broadcast inspection.

## Isolated build sequence — DESIGN, NOT A COMMAND TO RUN

After explicit written authorization for exact mutation allowlist:
1. Create a new isolated worktree/branch from exact sealed N1F-relevant source commit; do not stage changes in `/srv/data/sable-build/sableos/repo` or historical C1/C2 worktrees.
2. Apply exact R1 single-line patch, existing C1 modules and approved compatibility pieces, plus exactly five R2 inputs **only after its own linker admission passes**.
3. Run static negative regression tests: no extra APK/JAR/.so imports, no unrelated properties/healers, no missing `skip_mount.cfg`, no unexpected Android platform manifest or telephony edits.
4. Run incremental Android 16 compile and systemimage build with no clean/clobber, only after **separate build authorization**. Inspect effective `framework-res.apk`, bootclasspath JAR paths, SELinux policy and all required embedded `system_ext` files.
5. Seal final `system.img` (SHA-256/bytes), capture partition geometry/AVB and mode-aware Titan preflight; compare exact approved delta against N1F. No automatic reboot, device command, whole-super write or flash authority.

## Go/no-go and next handoff

```text
CURRENT_DELIVERABLE=M4_EXACT_MUTATION_AND_BUILD_AUTHORIZATION_PLAN
PATCH_PREVIEW_R1=PASS_NO_WRITE
IMS01_EXISTING_C1_MODULES=IDENTIFIED_REUSE
R2_FIVE_IDENTITIES=PASS_REUSE
R2_COMPLETE_NAMESPACE_AND_SYMBOL_ABI=NOT_QUALIFIED
EXACT_OCT11_FLASH_ARTIFACT_HASH=UNBOUND
SKIP_MOUNT_CFG=MANDATORY_PRESERVED
CELLULAR_ADB_TOGGLE=DIAGNOSTIC_TEMPORARY_FAILED_STABILITY
M4_SOURCE_MUTATION_GO=NO
M4_BUILD_GO=NO
DEVICE_OR_FLASH_GO=NO
```

**Next deliverable:** exact isolated source patch *only after* the C1 source binding and R2 namespace gate are closed, and the user explicitly authorizes that small mutation scope. Do not invent a substitute script that broadly probes known history again.
