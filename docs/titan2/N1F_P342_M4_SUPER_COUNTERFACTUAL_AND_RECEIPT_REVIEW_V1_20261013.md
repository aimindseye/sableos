# PR #342 — M4 existing build-receipt review and hybrid-super boot counterfactual V1

Date: 2026-10-13. **Existing evidence review only**, performed after operator's explicit authorization for a narrowly scoped review of an *identified* existing build receipt and previously documented source differences. No new host file content was accessed: the identified existing evidence reviewed here is the actual archived PR #339 GitHub **operator build/postbuild receipt** ([review #5502246106](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502246106)), supported by the related **full image/member/BCP receipts** ([review #5502638731](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502638731), [review #5502520401](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502520401)) and **physical Recovery report** ([review #5508369358](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5508369358)). A standalone exact file *on ai-g732* containing the terminal M4 build process log or complete final project manifest has **not** been identified in the reviewed records, so none is invented, accessed or asserted absent.

## 1. Existing named operator receipt — what it proves

[PR339 actual M4 operator postbuild result, 2026-10-13](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502246106):

- Explicit output family: isolated Android source root `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`, `out-m4-g2-fullimage-01/target/product/tdgsi_arm64_ab/system.img`; paired `obj/PACKAGING/system_intermediates/system.img`.
- Two **regular** complete image files both **3,194,466,304 bytes** and both exact SHA256 **`261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce`**, previously measured by the operator. Do not rehash them.
- Operator's terminal Ninja result **`build completed successfully`**, while original V1.1 wrapper recorded **`SYSTEMIMAGE=FAIL_MISSING`**. Since both postbuild image files were present and hash matched, the contradictory wrapper result is **an unresolved timing/observation discrepancy, not evidence that system.img was never produced**. Neither receipt proves a race or the exact exit-path root cause.
- Retained output staging `/efs`, `/persist` present; two obsolete `/bt_firmware` and `/sec_storage` directories removed under separately authorized exact empty-directory cleanup. Not a complete init/root filesystem parity proof.
- Prior frozen image checker confirmed **11/11 selected embedded member hashes**, including `ImsService.apk`, two IMS JARs, PHH marker, `skip_mount.cfg`, `bootclasspath.pb`, three C1 XMLs and policy/context outputs; a separate API36 protobuf semantic gate established **one enabled boot entry for each required MediaTek JAR**. Those PASS conditions cover file presence/selected bytes/classpath subsets, **not effective init mount execution, merged SELinux, app process linker namespace, or actual boot**.
- Actual M4 `system_a` flash transport succeeded, but **Android boot entered Recovery**. Root cause **not proven** from this receipt; no definitive retained crash/init/AVB/bootloader/Recovery reason is bound to this exact failed attempt.

**Admission:** `M4_COMPLETE_IMAGE_PRODUCED_AND_HASHED=PASS_HISTORICAL_OPERATOR_RECEIPT`; `M4_BUILD_WRAPPER_OBSERVATION=CONFLICT_UNEXPLAINED_BUT_ARTIFACT_PRESENT`; `M4_11_EMBEDDED_MEMBERS_AND_BCP=PASS_PRIOR_SCOPE`; `M4_ANDROID_BOOT=FAIL_RECOVERY`; `M4_BOOT_ROOT_CAUSE=UNBOUND`; `M4_FULL_SOURCE_MANIFEST_BOUND_TO_IMAGE=UNBOUND`.

## 2. Actual distinct experiment identities

| Experiment | System bytes | Device/partition operation | Outcome |
|---|---|---|---|
| 2026-10-03 N1F five-app | SHA `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, 3,200,540,672 bytes | Original special N1F runner flashed **system_a only**, exact success-status run.log markers rechecked in PR342; seven companion partition bytes not tied to this same physical session | Android boot **PASS** |
| 2026-10-11 Atlas-inspired hybrid | Operator reports entire hybrid-super experiment flashed, Android runtime `sys.boot_completed=1`, `/system_ext -> /system/system_ext`, `/product -> /system/product`; separate offline R3 control has **Oct03 N1F system input** | Actual written hybrid-super SHA/journal, active companion LP bytes, effective slot/snapshot mapping not bound; **do not promote offline R3 source-sha table into physical flash evidence** | Android boot **PASS_OBSERVED**, sustained cellular **FAIL** |
| 2026-10-13 M4 | SHA `261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce`, 3,194,466,304 bytes | Exact frozen independently compiled **system_a write** PASS, not an entire-super write | Android **FAIL_RECOVERY**; no proven failure reason |

Note physical predecessor partition state changed across dates; none is a controlled A/B experiment where **only packaging method** varied and all seven dynamic companion bytes, AVB, userdata, boot/vbmeta, snapshot and slot state were exactly identical.

## 3. Would packaging M4 as a hybrid super have succeeded?

**Counterfactual answer: UNKNOWN; no existing PASS proves it.** AOSP [dynamic-partition implementation](https://source.android.com/docs/core/ota/dynamic_partitions/implement) explains that `super` holds LP partition extents and metadata and first-stage init maps logical system/vendor/product/other partitions; packaging is not itself a fix for image-internal bytes. [AVB](https://source.android.com/docs/security/features/verifiedboot/avb) and Virtual A/B snapshot/mount/slot considerations remain separate qualification requirements.

Distinguish two very different 'hybrid super' proposals:

**A. Identical composition repack:** If the `system_a` logical partition contains *the exact M4 SHA*, all seven companions contain *the same effective bytes as the failed trial*, and LP slot metadata/mount/fstab/AVB behavior is equivalent, whole-super packaging alone offers **no identified mechanism** to repair a fault intrinsic to M4. In principle distinct LP/snapshot state can itself change outcome, but no captured evidence proves such a layout-only fix. **Cannot claim it would boot.**

**B. Different matched hybrid partition set:** If an exactly source-pinned hybrid includes a **different compatible vendor/product/system_ext/odm/boot/mount/AVB arrangement**, it *might* avoid a cross-partition or update-snapshot failure in a system_a-only attempt. However, that is a **different device state and counterfactual**, not evidence that M4's `system.img` is safe. `skip_mount.cfg` in observed N1F runtime deliberately redirects `/system_ext` and `/product` to embedded `/system/system_ext` and `/system/product`; simply including standalone stock Android14 `system_ext_a` and `product_a` does not make their contents effective or admit absent IMS services. Physical AVB and LP geometry may also prohibit a naive whole-super replay. Five R2 libraries were **absent from the failed M4 staging**; no causal link to early Recovery is established and simply repacking would not add them.

**Evidence-driven disposition:** A matched hybrid-super counterfactual is a legitimate **offline design hypothesis**, but **NOT_AUTHORIZED_FOR_BUILD_OR_PHYSICAL_TEST**. Preserve original Oct03 boot-qualified `system.img` bytes and original existing evidence; no whole-super construction/flash. Do **not** interpret Oct11 successful Android boot as M4-hybrid boot PASS. No reasonable probability of success can be assigned from available observations.

## 4. Source and boot-critical deltas worth examining, without requalification

| Area | Already completed evidence | Remaining discriminatory question |
|---|---|---|
| R1/B1 | Operator current isolated M4 root exact R1 **POST** and B1 **POST**, SHA/Git blob pinned | **CLOSED.** No reapply, no rebuild for these two changes |
| C3B TrebleApp/PHH overlays | Earlier missing `treble_app/TrebleApp.apk` Ninja input repaired by exact C3B `device/phh/treble/base.mk` removal; post hash `9e197a490a61a5721b8bb881e93acbc451104957a9599895bc724cfb5768820b` | Which init/boot behavior changed in final M4 versus *booted Oct03 system*, independently of intermediate failed build |
| PHH marker/mtkmal and root dirs | Exact PHH source/copy-rule/marker/board-base pins PASS at source; prior generated `bt_firmware`/`sec_storage` exact two directories cleaned | Effective init service/prop handling, marker accessibility and final first-stage tree/SELinux compatibility (not proven by source or member hash) |
| `skip_mount.cfg` and embedded system_ext | Historical source/staging SHA and final M4 member verified; Oct11 runtime symlink to embedded paths observed | Is skip-mount semantics/ordering identical at boot with failed M4? Content hash does not prove init execution or fstab AVB acceptance |
| C1 IMS APK, JAR, privilege and policy | 11/11 image members and API36 boot jar entry PASS; M11 signer+manifest PASS | Effective merged SELinux, package UID, classloader and process runtime, not proven simply by installed paths |
| Five R2 natives | Exact five SHA, 56 direct NEEDED, 19 Bionic subset, four GNU symbol edges, A4 native audit PASS historic | Full recursive symbol/version and *effective final N1F privileged IMS app namespace* still **NOT_EVIDENCED**; they were **not in M4 staged image** and absence alone is not a proven early Recovery cause |
| LP/AVB/slot baseline | Oct03 historical `system_a` run status PASS; Oct11 running hybrid observed; M4 `system_a` write transport PASS | Exact as-written same-session seven companions, LP/snapshots/AVB/rollback and first boot-failure reason required to separate image-intrinsic from mismatched-partition hypotheses |

**Next minimum permitted read**: The operator authorized a *narrow review of an identified existing build receipt*, satisfied here by the already-identifiable archived PR339 operator build/postbuild record; the records **do not establish a named exact small ai-g732 final build manifest/log leaf** suitable for a further host file read. Do not treat this as authority for broad log or project enumeration. If exact retained final source/exec build receipt leaf is supplied or identified in a future tool result, scope one regular text file, byte cap, SHA/time provenance and no image or source reads *before* opening it. No runtime bootloop cause is established from build success alone.

## Status and holds

```text
REVIEWED_EXISTING_RECEIPT=PR339_OPERATOR_M4_POSTBUILD_5502246106
RECEIPT_REVIEW=COMPLETE_PUBLIC_GITHUB_TEXT_ONLY
AI_G732_NEW_BUILD_RECEIPT_BYTES_READ=0
M4_SYSTEMIMAGE_PRODUCED_SHA_PIN=PASS_HISTORICAL
M4_NINJA_COMPLETION=PASS_REPORTED
M4_WRAPPER_FAIL_MISSING=CONTRADICTED_BY_PRESENT_IMAGE_CAUSE_UNKNOWN
M4_EMBEDDED_11_AND_BCP=PASS_PRIOR_SCOPE
M4_PHYSICAL_ANDROID_BOOT=FAIL_RECOVERY
M4_HYBRID_SUPER_BOOT_COUNTERFACTUAL=UNKNOWN_NOT_TESTED
OCT03_BOOTED_SYSTEM_PARENT=PASS_HISTORICAL_DIFFERENT_IMAGE
OCT11_ACTUAL_HYBRID_LAYOUT=UNBOUND_FLASH_JOURNAL
G3_SELECTED_IMS_NAMESPACE=NOT_EVIDENCED
SOURCE_MUTATION=NO BUILD=NO SUPER_REPACK=NO NETWORK=NO DEVICE=NO FLASH=NO
```

## 5. Explicit build-engineer hybrid-super decision and physical Recovery symptom

The [2026-10-13 actual physical attempt receipt](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5505341540) records **12/12 sparse sends/writes OKAY over 79.351s**, then controlled fastboot reboot OKAY, followed by stock Recovery UI **“Can't load Android system. Your data may be corrupt”** with Try again / Factory data reset. This is an **observed generic Recovery symptom**, **not** proof that userdata was corrupt or that M4's APK or native stack crashed. The user later reported that a factory-reset attempt failed, and recovery logs were unavailable. Do not suggest another reset. Image transport success is not Android boot success.

The [archived build-engineer revised decision](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5508562816) is particularly controlling: the engineer **retracted** an initial recommendation to abandon hybrid super, and **accepted a complete derived hybrid super as an OFFLINE byte/LP metadata comparison control** and *possible later separately reviewed deployment artifact*. All functional IMS content must still reside in embedded `/system/system_ext` in the derived `system.img`; physical stock system_ext_a/product_a content is hidden by N1F `skip_mount.cfg`. G1 image contents, G2 actual classpath/privileged UID/SELinux and G3 transitive symbol/version/effective namespace remain separate gates, not removed by hybrid repackaging. AVB and LP metadata constraints apply even in an offline full-super design. The engineer **explicitly rejected** a confident Rescue Party or `libmtk_vt_wrapper.so` bootloop attribution absent actual supporting logs. A previous isolated `n1f_oct13_p342_host_reconcile_v1.py` packet has already captured named R3/R8 evidence; do not redo.

**Reconciled answer:** A separately authorized **offline hybrid-super design/control** remains a technically sensible *analysis approach*. **Physical M4-as-hybrid boot success is unproven**; no claim of “would have succeeded,” no implicit change to boot, AVB, slot/Virtual A/B/snapshot, fstab or exact seven companion bytes, and **NO** permission to compile, assemble or flash a hybrid. Comparing the controlled LP/AVB metadata and source images may eventually distinguish partition mismatch from image-intrinsic defects, but only with exact retained parent identity and approved inputs.
