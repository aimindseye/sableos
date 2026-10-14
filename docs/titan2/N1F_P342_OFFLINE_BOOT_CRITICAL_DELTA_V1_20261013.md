# PR #342 — Oct03 versus M4 offline boot-critical delta V1

Date: 2026-10-13. **Operator explicitly authorized an offline boot-critical comparison from retained October 3 and M4 evidence** focusing on first-stage mounts, PHH changes, effective SELinux and partition-set assumptions. This is **report-only**, not a direct image-byte diff or read of any new ai-g732 host files. The source basis is previously recorded operator results in PR #339, the controlling PR #342 reconciliation, and the archived IMS-01 contract. **No source/image/policy/log/partition bytes were opened on ai-g732 in this turn.** No new executable is needed; preserve earlier 991-project/M11/A4/R2/R1/B1 and image-hash regression outcomes.

## Selected controls: three separate experiments, not a controlled A/B comparison

| Experiment | Recorded image/operation | Observation | Limit |
|---|---|---|---|
| Oct03 N1F Android16 C3A-derived five-app | Exact retained system.img SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, 3200540672 bytes; original runner `system_a` write and boot-result markers | **PASS Android boot** | The seven companion partition bytes and same-session LP/AVB/Virtual A/B state are not bound |
| Oct11 Atlas-inspired hybrid | Operator-reported whole-super flash; runtime symlinks `/system_ext -> /system/system_ext`, `/product -> /system/product` | **PASS observed Android boot; FAIL sustained LTE registration** | Actual written super SHA, command journal, snapshot and partition map unbound; offline R3 is NOT the actual flashed super |
| Oct13 M4 isolated integration | `out-m4-g2-fullimage-01` system.img SHA256 `261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce`, 3194466304 bytes; `system_a` only, 12/12 writes OKAY in 79.351s | **FAIL_RECOVERY**, stock screen “Can't load Android system. Your data may be corrupt” | No logs establish init/SELinux/AVB/zygote/Rescue Party/userdata or specific OEM library root cause |

[Original bounded Oct03 run evidence](N1F_OCT03_RUN_SOURCE_LP_AUTHORITY_V2_20261013.md), [M4 actual Recovery](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5505341540), [M4 postbuild dual-image SHA](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502246106). Dates/device states differ, so packaging was **not** the only experimental variable.

## 1. First-stage mounting / skip_mount — static preservation PASS, execution unknown

- Oct11 N1F-based live symlinks prove **that separate running session** used embedded system_ext/product; they do **not** show M4's failed first-stage sequence.
- The first M4 host check of `system/etc/init/config/skip_mount.cfg` mistakenly diagnosed absence. This path includes a compatibility **absolute directory symlink**; actual GSI source declares `gsi_skip_mount.cfg` as `system_ext_specific: true` and installs at **`system/system_ext/etc/init/config/skip_mount.cfg`**. Selected M4 stage had a regular file there and `system/etc/init/config` symlink to `/system/system_ext/etc/init/config`. The bounded source and staging copies matched exact SHA256 **`0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e`**; final M4 frozen image was previously SHA-qualified among 11 members. Includes `/product`/`/system_ext` and subtree skip rules. [Actual corrected operator result](https://github.com/aimindseye/sableos/pull/339#issuecomment-6154056789).
- **Finding:** `M4_SKIPMOUNT_MISSING=REFUTED_IN_PREVIOUS_STATIC_CHECK`. **Still unknown:** first-stage init import order, runtime fstab/AVB/DM behavior, successful effective embedded mounts when M4 entered Recovery, and Oct03 exact corresponding member parity. **Do not repeat staged source SHA checks or turn this into an unsupported missing-config theory.**

## 2. PHH, mtkmal, C3B overlay and generated-root deltas — source-side repair PASS, early-boot effects unknown

- Archived source context before PHH Titan gate included `/vendor/bin/mtkmal` branch checking `persist.mtk_ims_support`/`persist.mtk_epdg_support`, setting both to `0`, then calling `reboot`. This was an **unprotected prior source branch**, not an observed M4 runtime reboot. A reviewed Titan marker/guard and final image marker member later passed bounded source/artifact checks. **No archived M4 failed-boot property/reboot trace proves the later guard executed.** [Original PHH context](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497544162).
- The first M4 full build failed a missing TrebleApp Android Make prerequisite; an exact C3B `device/phh/treble/base.mk` delta removed legacy `vendor/hardware_overlay/overlay.mk` and TrebleApp config inheritance (POST SHA `9e197a490a61a5721b8bb881e93acbc451104957a9599895bc724cfb5768820b`), and subsequent build produced an exact hashed image. That resolved a **build prerequisite**, not a demonstrated boot crash. [C3B source repair](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497900692).
- Two previously generated empty staging paths `root/bt_firmware` and `root/sec_storage` were removed by an explicit `rmdir`-only cleanup; `/efs` and `/persist` retained. **Do not** classify removed stale directories as boot failure or assume exact Oct03 root-image parity. [Prior cleanup receipt](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502194257).
- **Finding:** `M4_PHH_C3B_REPAIR=PASS_SOURCE_PRIOR`; `EFFECTIVE_INIT_PROPERTY_ROOT_DELTA=UNKNOWN`. Historical Oct03 vs M4 effective root/init member content has not been independently diffed here.

## 3. Effective SELinux — hashed compiled outputs are not policy-admission evidence

- M4 final image 11/11 selected embedded SHA checks included **`plat_sepolicy.cil` and `plat_file_contexts`**; this supports *existence and exact selected member bytes*, not successful policy loading, correct file labels, complete policy compatibility with unchanged vendor/odm, runtime service domains, app privilege or AVC behavior. [Frozen M4 gate](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502638731).
- No exact Oct03 **effective merged** SELinux policy receipt was compared with the M4 one in the current authorization, and no failed-boot AVC/policy-load log is bound to M4. **Cannot** assert either parity or an SELinux-specific mismatch. M11 platform APK signer and declared `android.uid.phone` are bounded PASS, not process UID admission.
- **Finding:** `M4_COMPILED_POLICY_MEMBERS=PASS_PRIOR_BOUNDED`; `EFFECTIVE_MERGED_SELINUX_AND_BOOT_DENIAL=NOT_ESTABLISHED`.

## 4. IMS bootclasspath and native load — distinct from boot-cause identification

- M4 `ImsService.apk`, `mediatek-common.jar`, `mediatek-ims-base.jar`, the C1 XMLs and compiled `bootclasspath.pb` were previously sealed as selected final members. Independent API36 semantic protobuf decode qualified one enabled BOOTCLASSPATH entry for each MediaTek JAR; runtime classloader/service/privileged-package behavior is **unproven**. [API36 semantic receipt](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502520401).
- R1 and B1 currently are **POST_EXACT/POST_EXACT** in selected M4 source (actual ai-g732 544326-byte authorized two-file receipt), so **NO REPATCH**. Historical Oct03 source V38 PRE/PRE is not final M4 image behavior and not an instruction to revert patches. [Source receipt](https://github.com/aimindseye/sableos/pull/342#issuecomment-6157621921).
- All five R2 ViLTE binaries/56 direct NEEDED/19 Bionic/four GNU binding subsets and prior A4 audit are **PASS at bounded historic static scope**. M4 checked staging lacked those five, with an IMS DEX `loadLibrary("libmtk_vt_wrapper.so")` reference; **no observed M4 JNI crash or Rescue Party chain**. Do not assign Recovery to an absent native library without logs. [M4 native-gap review](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5503107709).

## 5. LP, AVB, Virtual A/B and derived hybrid-super counterfactual

- Oct03 `system_a` boot PASS, Oct11 operator-reported hybrid Android boot PASS, and M4 `system_a` write PASS + Android FAIL are **not a trial with matched same-session companion and boot partition bytes**. All seven Oct03 physical dynamic companions, Oct03 LP groups/snapshots and AVB/restore matching remain UNBOUND; Oct11 actual super SHA/journal UNBOUND. Offline R3 source manifests cannot be promoted to as-written runtime bytes.
- **Same effective bytes + same LP/AVB/slot state:** merely repackaging the exact M4 system bytes into super has **no evidenced mechanism** to fix an image-internal init/framework/SELinux crash. **Different matched companions/metadata:** could change outcome *if* failure was partition/snapshot/cross-OS mismatch, but neither the mismatch nor repair is proven.
- The archived build engineer **explicitly retracted abandoning the hybrid idea** and retained a *complete derived hybrid super as an offline byte/LP metadata control*, with IMS contents only in embedded `/system/system_ext`, skip-mount preserved, and distinct G1/G2/G3, AVB/rollback and deployment approval. That is **not** hybrid-M4 physical boot evidence or permission to run `lpmake`. [Engineer decision](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5508562816).
- **Finding:** `M4_HYBRID_BOOT=UNKNOWN_NOT_TESTED`. Do **not** assert a success probability, change slot, wipe/reset or initiate whole-super flashing.

## Priority of *existing evidence* to resolve remaining ambiguity

1. A **previously recorded M4 failed-boot reason**, specific Recovery/reboot cause, pstore/console/AVB/init/zygote/AVC or verified system_server crash, *if available and bound to that exact attempt*. PR339 archival review says Recovery logs unavailable. Do not authorize new device contact implicitly.
2. Existing exact, small **Oct03-versus-M4 image-effective** first-stage init/fstab/embedded `skip_mount` and PHH marker/property semantics, if previously extracted and SHA-bound to each distinct image. No rescanning/re-extraction.
3. Exact selected **Oct03 matched companions + LP/Virtual A/B/AVB** and a separately bound Oct11 physical journal if ever recovered; existing historical stock controls cannot stand in for same-session measurements.
4. Existing full M4 final build-head/exec-receipt join if a named pinned small receipt is independently identified; 991-row C3A head ledger is an earlier parent, not the post-repair final M4 source manifest.

Until these exist, **no causality claim and no new image admission**. Preserve Oct03 as offline planning parent and M4 as failed immutable source/image comparison. New output report: distribution `N1F_P342_OFFLINE_BOOT_DELTA_V1.zip` SHA256 **`278a9c56da39ad4e07c601f1409e62c4195db0f75c06f50fe17c1017a2691059`**. ZIP stores report Markdown, 10-row x 9-field structured TSV, JSON status, README and SHA256SUMS. Deterministic timestamped ZIP serialization **repeated byte-identical**, archive CRC PASS, four inner SHA PASS, JSON invariants PASS, all 10 rows fields populated and distinct, source URLs grounded in PR339/342, negative build/device/flash status asserts PASS. **No new executable created**, so no Python/shell runtime tool to qualify and no fictitious benchmark; the only local Python was development/validation of the report packaging and is **not distributed**.

```text
OFFLINE_BOOT_DELTA_COMPARISON=COMPLETE_RETAINED_EVIDENCE_SCOPE
NEW_HOST_IMAGE_OR_SOURCE_OR_POLICY_OR_LOG_BYTES_READ=0
OCT03_ANDROID_BOOT=PASS_HISTORICAL
OCT11_HYBRID_ANDROID_BOOT=PASS_OBSERVED_ACTUAL_SUPER_UNBOUND
M4_COMPLETE_SYSTEMIMAGE_SHA=PASS_PRIOR_HISTORICAL
M4_ANDROID_BOOT=FAIL_RECOVERY_CAUSE_UNBOUND
M4_SKIP_MOUNT_SOURCE_STAGE_AND_MEMBER=PASS_PRIOR_NOT_RUNTIME
M4_COMPILED_SELINUX_MEMBERS=PASS_PRIOR_NOT_EFFECTIVE
M4_R1_B1=PASS_POST_POST_NO_REPATCH
M4_AS_HYBRID_SUPER_PHYSICAL_BOOT=UNKNOWN_NOT_TESTED
G1_G2_G3_NEW_TARGET=NOT_ADMITTED
OCT03_SEVEN_COMPANIONS_LP_AVB_RESTORE=UNBOUND
OCT11_AS_FLASHED_SUPER_SHA_AND_JOURNAL=UNBOUND
SOURCE_MUTATION=NO BUILD=NO IMAGE_EXTRACTION_OR_HASH=NO
LPDUMP=NO LPMAKE=NO NETWORK=NO DEVICE=NO FLASH=NO
```
