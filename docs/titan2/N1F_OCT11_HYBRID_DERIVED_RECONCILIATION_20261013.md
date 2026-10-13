# Titan 2 N1F — October 11 hybrid-derived image, evidence reconciliation and architecture gate

Date: 2026-10-13. Status: **DRAFT ENGINEERING AUTHORITY — HOST READ-ONLY RECONCILIATION ONLY**. Supersedes PR #339 as the *active queue*, not its raw historical findings. **No source mutation, build, partition extraction/mount, network fetch, device contact, reboot, flash, slot/AVB change, erase, factory reset, restore, merge, or release authority is conveyed.** Any bounded host operation requires exact existing paths, inputs and a separately agreed scope.

## Source of decision / cross-reference

- Retired research: [PR #339](https://github.com/aimindseye/sableos/pull/339), including `CURRENT_ENGINEERING_STATE.md`, `EVIDENCE_INDEX.md`, `N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md`, `N1F_M4_EXACT_MUTATION_AND_BUILD_AUTHORIZATION_PLAN_20261012.md`, `N1F_IMS01_C1_SOURCE_REUSE_PINS_20261012.md`, `N1F_M3_R2_PRIOR_EVIDENCE_REUSE_MATRIX_20261012.md`, and the two operator-supplied 2026-10-12 M4 integration and minimal R1/R2 decisions.
- Build engineer final response: `ACCEPT_WITH_EXACT_CHANGES`, explicitly **retaining a complete hybrid `super.img` as an offline LP metadata/partition-byte control** while placing the OEM IMS island exclusively inside embedded `/system/system_ext` of the derived `system.img`. The engineer's initial suggestion to abandon hybrid super was retracted.
- PR #340 D7: exact artifact identities only, *not* runtime classloader/ABI or Oct 11 flash lineage. Historical C1/C2/D1R2 PRs are evidence, not blanket installation authority.

## Verified physical evidence (keep claims separated)

| Event | Accepted evidence | Limit |
|---|---|---|
| 2026-10-03 N1F C3A-derived five-app | Physically booted; sealed `system.img` SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, 3,200,540,672 bytes | Proven *October 3* `system_a` parent, not automatically Oct 11 hybrid |
| 2026-10-11 Atlas-inspired experimental runtime | Android `sys.boot_completed=1`, SIM present, briefly voice/data IN_SERVICE then OUT_OF_SERVICE; `/system_ext -> /system/system_ext` and `/product -> /system/product` | Exact physically flashed `super.img` SHA, command receipt, source ref **UNBOUND**; offline R3 seven-partition composition NOT flash proof |
| 2026-10-12 | 991/991 pinned Android project heads reconstructed in isolated `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`; source-only R1 patch PASS; M11 14,094-action *targeted* compile PASS; C1 six module definitions identified | Targeted build != unified complete image/physical boot |
| 2026-10-13 M4 | Frozen `out-m4-g2-fullimage-01/target/product/tdgsi_arm64_ab/system.img` SHA256 `261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce`. Manual fastbootd `system_a` 12/12 chunk writes `OKAY`, 79.351 s; reboot command `OKAY`, then Android Recovery "Can't load Android system. Your data may be corrupt" | **PHYSICAL_BOOT=FAIL_RECOVERY**, mobile/IMS NOT TESTED; successful transport is not boot/readiness evidence |
| 2026-10-13 recovery follow-up | Operator attempted factory reset, which FAILED; then navigated "No command" recovery to fastbootd | **Current mode FASTBOOTD**, recovery/Rescue Party logs **UNAVAILABLE**. Do not request recovery log capture in current plan; do not claim a successful wipe or intact userdata |

Rescue Party/persistent app crash, missing `libmtk_vt_wrapper.so`, init/SELinux failure, AVB, mount, or userdata incompatibility are **competing hypotheses**. Neither Recovery screen nor historical D1R1 crash proves which caused this M4 failure. Verify M4 installed bytes and retained host artifacts before asserting causation. A compiled full systemimage is not itself evidence of a `property.te` compilation failure.

## Controlling architecture

1. Bind the physically booted Oct 11 hybrid SHA/journal/build lineage to R8Q3/R8R/R8M **if retained**. The offline R3 manifest and `lpmake-command.txt` are reference-only until independently linked. If not bound, STOP claiming "Oct 11-derived": choose the sealed Oct 03 N1F control explicitly as a **different** parent, with Oct 11 runtime/cellular properties unproven.
2. Preserve the selected parent's effective GSI `gsi_skip_mount.cfg` bytes **at its primary embedded location** `/system/system_ext/etc/init/config/skip_mount.cfg`, the relevant `/system/etc/init/config` compatibility symlink if present, and init/mount order. AOSP's `target/product/gsi/Android.bp` installs this module with `system_ext_specific: true`; absence of a regular file at `/system/etc/init/config/skip_mount.cfg` alone is **not** a missing-config finding. Physical stock `system_ext_a` and `product_a` are bypassed in the observed N1F runtime. Their mere presence inside `super` does not expose APKs. Never install IMS fixes exclusively into standalone `system_ext.img` or alter stock Android 14 mounts.
3. Only admitted IMS island goes into derived `system.img` embedded `/system/system_ext`: pre-existing exact C1 modules (`ImsService` platform-resigned privileged APK; `mediatek-common.jar`, `mediatek-ims-base.jar`; three XML policy/config modules), necessary pinned C1 SELinux/PHH `mtkmal` and `writeRilAnswer(II)V` compatibility, plus exact R1 single protected broadcast; R2 five pinned ViLTE ELF64 libraries only after native G3 closure.
4. **Output complete hybrid `super.img` OFFLINE** using selected parent-matched logical images and LP metadata/Virtual A/B group rules, retaining unchanged partition payload hashes. The hybrid is a deterministic composition/metadata *control*; offline assembly alone does not prove it should be flashed, nor that AVB descriptors/signatures match.
5. No D1R2 seven-JAR/33-native bulk import, `MtkTeleService.apk`, stock system_ext mount replacement, property forcing, radio healers, CW1 semantic port, boot/vendor/vbmeta change, unapproved userdata action or production claim. LTE registration collapse is P0 and separate from IMS/calls.

## October 13 host receipt results — bounded V1 findings and correction

The ai-g732 operator sealed an exact six-file evidence set under `/srv/data/sable-build/evidence/titan2/n1f-p342-reconcile-20261013-v1`. V1 inspect-only results: Oct11 SHA/journal NOT_SUPPLIED / PARENT UNBOUND; Oct03 N1F retained as a separate booted alternative; final G1/G2/G3 OPEN; offline hybrid NOT BUILT. M4 failed-candidate *staging*, not image-effectiveness: `ImsService.apk`, `mediatek-common.jar`, `mediatek-ims-base.jar` PRESENT; five R2 native libraries ABSENT at proposed embedded `lib64` paths; no Recovery logs. These are actionable *image-delta candidates*, not confirmed crash causes.

**G1 checker correction:** V1 checked `system/etc/init/config/skip_mount.cfg` and reported ABSENT. That path can be a compatibility symlink. The primary AOSP `gsi_skip_mount.cfg` installation is `system/system_ext/etc/init/config/skip_mount.cfg`; AOSP also provides a compatibility directory symlink under `system/etc/init/config`. The V1 ABSENT result is **INCOMPLETE_PATH_COVERAGE**, not evidence that mount-skip semantics were removed. Determine from retained M4 staged files and source build rules whether the primary file and compatibility symlink exist. This targeted host-only check must not read/extract the 3.19 GB image, touch the phone or introduce another generic census.

**2026-10-13 exact-path closure (operator ai-g732 read-only):** M4 failed-candidate staged `system/system_ext/etc/init/config/skip_mount.cfg` is a **REGULAR_FILE**, and `system/etc/init/config` is a **SYMLINK** to `/system/system_ext/etc/init/config`. At build source `build/make/target/product/gsi/Android.bp`, `gsi_skip_mount.cfg` has `system_ext_specific: true`, `relative_install_path: "init/config"`, and explicitly requires `gsi_skip_mount_compat_symlink`, whose target is `/system/system_ext/etc/init/config`; `gsi_release.mk` lists `gsi_skip_mount.cfg` in PRODUCT_PACKAGES. The earlier `system/etc/init/config/skip_mount.cfg` host-level `NOT_PRESENT_AT_CHECKED_PATH` is an **absolute-symlink host resolution artifact** and is not a missing-file finding. **G1_SKIP_MOUNT_STAGING_PATH=PASS**, **G1_SKIP_MOUNT_SOURCE_WIRING=PASS**, **G1_SKIP_MOUNT_CONTENT_EQUALS_PARENT=NOT_CHECKED**, **G1_FINAL_IMAGE_EFFECTIVE=OPEN**. Do not carry a 'missing skip_mount.cfg' root-cause hypothesis forward. These facts do not prove successful first-stage runtime mounts or the final flashed image contents. Next smallest read-only check: compare the existing bounded source `gsi_skip_mount.cfg` to M4 staged payload by SHA/cmp, read only bounded file contents and verify `/product` and `/system_ext` skip rules. Do not rebuild or read/extract image.

**Other retained input coverage:** R8Q3 `mounts_relevant.txt` grep has only vendor entries, so it does not independently prove `/system_ext` mounting; separate R8Q3 `live_paths.tsv` records the embedded symlink. Do not conflate presence in R8R evidence with IMS APK installation on Oct11.

## Reuse already qualified evidence — DO NOT rerun

- 991/991 source checkout project identities; R1 `frameworks/base/core/res/AndroidManifest.xml` pre/post SHA256 `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c` / `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`.
- Six C1 `product/titan2/n1i-c1/Android.bp` module definitions; M11 targeted build; immutable C1 telephony patch pre/post Git blobs `27638e5be9c008101c2f9b8f1e7a9af49d94f838` / `9d5108e0ddb8d4960d21cda021813b53dbbf4da8` (third-state BLOCK); earlier configured-JAR location regression.
- Five R2 native SHA/ELF identities, 56 direct DT_NEEDED references (20/15/6/8/7), prior 19/19 Bionic subset and four targeted GNU bindings. The 1,192-byte Oct 03 linker.config.pb SHA256 `201fddcd321f6de502bea10a72aa6e2108b3a0f448702250d08006ea1b6b2701` is **build-time**, not effective IMS runtime namespace. Historical unresolved libraries with missing runtime root mean `UNKNOWN_INPUT_COVERAGE`, not device ABSENT.
- R8Q3 mount/APK evidence, R8R OEM presence, R8M radio transition, N1C failed whole-super/stock-system mismatches, exact Titan mode/one-shot policies, Oct 13 M4 physical write receipt.
- **No** new broad inventories, no 991-project resync, M11 rebuild, repeated image geometry, native SHA census, 56-edge reparse or device tests.

## Host-only next deliverable (existing artifacts, read-only)

Required separate receipts and refusal classification:

| Receipt | Minimum assertion; fail-closed state |
|---|---|
| `OCT11_PARENT_BINDING.env` | Exact SHA-256 of physical Oct11 write, source/partition/recovery journal and R8 timeline if provable; else `UNBOUND`, explicitly select Oct03 fallback (never relabel R3) |
| `M4_BOOT_FAILURE_TRIAGE.tsv` | Effective M4 APK, five R2 libs, mount/init, policy and available host logs; hypotheses ranked `EVIDENCED/HYPOTHESIS/UNKNOWN`. Phone logs UNAVAILABLE |
| `G1_EMBEDDED_TARGET.txt` | **Final image-effective** `/system/system_ext/priv-app/ImsService/ImsService.apk`, two framework JARs, three XMLs, exact conditional five native `lib64` paths; not merely Soong module names or staging directories |
| `G2_COMPILED_AUTHORITY.env` | Actual signed APK cert identity/UID, final `bootclasspath.pb` and configured JAR stems, effective privapp/XML/SELinux/secilc output in selected image; `NOT_BUILT` if not produced |
| `G3_NAMESPACE_CLOSURE.tsv` | Only remaining recursive strong-symbol/required-version/proven accessible provider/IMS classloader namespace decisions from inherited 56-edge graph. No assumption vendor file presence means namespace reachability |
| `HYBRID_SUPER_REPACK_PLAN.env` | Parent LP group and all logical partition file hashes, unchanged partition policy, `lpmake` rules, snapshot/COW and Virtual A/B metadata, separately verified AVB chain/descriptor and matched restore plan; NO WRITE |

Each receipt must cite exact input evidence path and outcome. **No invented PASS** where an actual effective image/classpath/policy or October 11 journal is absent. The engineer's 15-minute/<1 GiB estimate is for bounded evidence-only review, NOT full compile or LP repack. Source edits, compilation, image extraction/mounts, new images, any device action each need separate authorization.

## Operator SHA-256 seals — 2026-10-13

Operator confirmed `RECEIPT_FILE_SET=PASS_EXACT_SIX` and SHA256 of all six files, from `/srv/data/sable-build/evidence/titan2/n1f-p342-reconcile-20261013-v1` on ai-g732. These hashes identify V1 **read-only classification receipts**, not pass status for parent identity, G1/G2/G3 or physical image.

```text
003f5879694ca52a4d7e955c0d0c2f372b20b76b2c7c1efbf61e643d91130e33  OCT11_PARENT_BINDING.env
305ed94f18f149cf42e9d91822661a2e349a0c90870d16533d669ff842e2e567  M4_BOOT_FAILURE_TRIAGE.tsv
3e7e6fbad8a0858df4468a8ff03ec1dd27df178645504eb5fe9a39fd46d1cda3  G1_EMBEDDED_TARGET.txt
69845f7ae39a3145c38f97d86f6d2a85d41f967ac96d53c056fa5309d0b48821  G2_COMPILED_AUTHORITY.env
89112df1aa424ab3dfe739ad4370af6a953a137c2ac9149cf9a7215a7ef62fca  G3_NAMESPACE_CLOSURE.tsv
7c16f18f13d9ce55720f5986b436b78e368ffdf2e15a6c472530d5ba704a75da  HYBRID_SUPER_REPACK_PLAN.env
```

The receipts report: parent journal/SHA NOT_SUPPLIED; Oct03 sealed alternate awaiting explicit selection; M4 *staging* ImsService and two JARs PRESENT but five R2 native libraries ABSENT at proposed paths; `system/etc/init/config/skip_mount.cfg` absence **requires GSI primary installed-path check** (compatibility location may be symlink), bootclasspath protobuf PRESENT but effective JARs/unified SELinux/privapp still unqualified, and no complete R2 recursive provider/IMS classloader namespace evidence. M4 Recovery log unavailable. User showed the exact six texts; no image was read by V1.

## Decision gates / physical stop

- `PARENT=BOUND_OCT11` or `FALLBACK_EXPLICIT_OCT03`; never silently switch.
- `G1=PASS_FINAL_EMBEDDED_COMPOSITION` and `G2=PASS_FINAL_SIGNING_CLASSPATH_SELINUX` required to admit an IMS candidate; historical static PASS does not close G2.
- `G3=PASS_RECURSIVE_LINKER_NAMESPACE` required before importing five R2 ELF files or approving any IMS-enabled physical trial. R1+C1-only **offline analysis** permitted under separate scope, not automatic physical flash; absence of R2 does not itself prove an inevitable system bootloop.
- After separate build permission: isolated exact-parent source patch, no bulk imports, incremental unified graph build, qualify *actual* compiled image, offline super repack and exact partition bytes/LP metadata; no implied AVB PASS.
- **Before any physical write**: matched restore/stock-firmware version authority, flash transport and one-attempt semantics, boot-path proof and operator-specific authorization. Device currently fastbootd; **FLASH/REBOOT/FACTORY_RESET/AVB/SLOT/RESTORE=NO**.
- Runtime if later authorized: Android twice, service stability, SIM and mobile data, RIL LTE cause 13 independent, per-slot IMS/VoLTE/voice/SMS and DSDS. No ADB airplane-cycle/property-hold as claimed fix.

## Repository governance

This PR replaces draft PR #339 as the engineering queue, preserving #339 closed and UNMERGED for historical research. Do not cherry-pick its 39-file unadmitted research wholesale into main. Private integration repository owns image/source/IMS and authorization; public SableOS repositories carry bounded *documentation-only* status, not source, blobs, physical commands, production promises or publicly exposed device records. Preserve Panther R9 frozen and Titan 2 Elite independently unqualified. No repo may infer public build/flash authority from this document.

## Immediate status

```text
BE_REVIEW=ACCEPT_WITH_EXACT_CHANGES
RESEARCH_PR_339=HISTORICAL_CLOSE_UNMERGED
OCT11_PARENT=UNBOUND
OCT03_PARENT=SEALED_BOOTED_ALTERNATE
M4_FASTBOOT_WRITE=PASS
M4_ANDROID_BOOT=FAIL_RECOVERY
RECOVERY_FACTORY_RESET=ATTEMPT_FAILED
CURRENT_DEVICE_MODE=FASTBOOTD
RECOVERY_LOG=UNAVAILABLE
G1=OPEN_SPECIFIC_DELTA
G2=STATIC_SCOPE_PASS_FINAL_IMAGE_OPEN
G3=OPEN_SPECIFIC_DELTA
HYBRID_SUPER_BUILD=NOT_AUTHORIZED_OFFLINE_ONLY_WHEN_APPROVED
DEVICE_CONTACT=NO
SOURCE_MUTATION=NO
BUILD=NO
FLASH=NO
```
