# Titan 2 N1F — October 11 hybrid-derived image, evidence reconciliation and architecture gate

Date: 2026-10-13. Status: **DRAFT ENGINEERING AUTHORITY — HOST READ-ONLY RECONCILIATION ONLY**. Supersedes PR #339 as the *active queue*, not its raw historical findings. **No source mutation, build, partition extraction/mount, network fetch, device contact, reboot, flash, slot/AVB change, erase, factory reset, restore, merge, or release authority is conveyed.** Any bounded host operation requires exact existing paths, inputs and a separately agreed scope.

## Source of decision / cross-reference

- Retired research: [PR #339](https://github.com/aimindseye/sableos/pull/339), including `CURRENT_ENGINEERING_STATE.md`, `EVIDENCE_INDEX.md`, `N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md`, `N1F_M4_EXACT_MUTATION_AND_BUILD_AUTHORIZATION_PLAN_20261012.md`, `N1F_IMS01_C1_SOURCE_REUSE_PINS_20261012.md`, `N1F_M3_R2_PRIOR_EVIDENCE_REUSE_MATRIX_20261012.md`, and the two operator-supplied 2026-10-12 M4 integration and minimal R1/R2 decisions.
- Build engineer final response: `ACCEPT_WITH_EXACT_CHANGES`, explicitly **retaining a complete hybrid `super.img` as an offline LP metadata/partition-byte control** while placing the OEM IMS island exclusively inside embedded `/system/system_ext` of the derived `system.img`. The engineer's initial suggestion to abandon hybrid super was retracted.
- PR #340 D7: exact artifact identities only, *not* runtime classloader/ABI or Oct 11 flash lineage. Historical C1/C2/D1R2 PRs are evidence, not blanket installation authority.

## Current operator-selected parent — 2026-10-13 (supersedes earlier pending-selection text)

**APPROVED_FOR_OFFLINE_PLANNING_ONLY:** the operator has explicitly selected the **October 3 physically boot-qualified N1F C3A-derived C3B5 `system.img`**, exact SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, 3,200,540,672 bytes, as a **new distinct offline engineering parent**. This does *not* bind or relabel the actually flashed October 11 experimental hybrid; its exact SHA/journal remains `UNBOUND`. It also does not bind the matching physical/stock whole-super LP input set, source checkout to the selected artifact, AVB/Virtual A/B rules or restore plan. Those are the next **host-evidence planning matrix** questions. See [operator parent-selection decision](N1F_OCT03_PARENT_SELECTION_DECISION_20261013.md) for exact scope and NO BUILD/FLASH controls.

```text
CURRENT_SELECTED_PARENT=OCT03_N1F_SYSTEM_IMG_OFFLINE_PLANNING_ONLY
PARENT_SELECTION=OPERATOR_APPROVED_2026-10-13
OCT03_N1F_SYSTEM_SHA256=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a
OCT11_ACTUAL_FLASH_PARENT=UNBOUND_NOT_INHERITED
MATCHED_SUPER_LP_PARTITIONS=NOT_BOUND
SOURCE_MUTATION_AUTHORIZED=NO
IMAGE_BUILD_AUTHORIZED=NO
SUPER_REPACK_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

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

**2026-10-13 source/staging byte-equivalence closure (operator ai-g732):** Both `build/make/target/product/gsi/gsi_skip_mount.cfg` and the M4 staged embedded `system/system_ext/etc/init/config/skip_mount.cfg` SHA-256 are `0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e`; `cmp` reports `SOURCE_VS_STAGING=PASS_EXACT_BYTES`. Actual file rules include `/oem`, `/product`, `/system_ext`, their subtree exclusions, and the recorded OPlus `my_manifest` mountpoints. Thus the **M4 skip-mount source/staging path, wiring, and content checks are CLOSED/PASS**; the old `system/etc/init/config/skip_mount.cfg` missing-file claim is withdrawn. This is **not** proof of the bytes in the *flashed* M4 `system.img`, runtime mount behavior, or equality with the still-unbound October 11 parent. Do not repeat these closed source/staging checks. Overall G1 remains OPEN_FINAL_IMAGE_COMPOSITION.

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

## Historical V2 journal-search outcome before parent selection (2026-10-13)

PR #339's **V17** already searched the R3 control directory and its parent without identifying a physical write journal. PR #342 V2 has now run on ai-g732: ZIP and checksum manifest PASS; 16/16 operator unittest cases PASS; nonrecursive filename-only inspection of **367 immediate entries under `~/Downloads`** returned `names=[]`, `truncated=false`, `oct11_binding=UNBOUND_NOT_A_JOURNAL_PROOF`. No content read, output write, subprocess, network, device or flash. Negative evidence is specific to the directory searched, **not a claim of global absence**. Do not prolong journal searches without a newly supplied exact candidate. The governing handoff and operator output interpretation are in [N1F_OCT11_PARENT_CANDIDATE_HANDOFF_V2_20261013.md](N1F_OCT11_PARENT_CANDIDATE_HANDOFF_V2_20261013.md).

```text
PARENT_CANDIDATE_V2_AI_G732=PASS_NO_DOWNLOADS_CANDIDATES
V2_TESTS=PASS_16_OF_16
V2_NAMES_EXAMINED=367
OCT11_FLASH_ARTIFACT_SHA_JOURNAL=UNBOUND
JOURNAL_SEARCH=STOP_PENDING_NEW_EXPLICIT_CANDIDATE
OCT03_N1F_FALLBACK=AVAILABLE_NOT_SELECTED
NEXT=REQUIRE_OPERATOR_PARENT_DECISION
```

The V2-stage recommendation, now **approved for planning only**, was **explicitly selecting Oct03 N1F as a different offline parent**, not relabeling it Oct11; doing so by itself authorizes no build, image extraction or packaging. A complete hybrid `super.img` would still need a separately proven LP/AVB/restore composition, with exact source/unchanged partitions and effective embedded `system_ext` and `product` qualified. G1 final-image, G2 and G3 remain open.

## Sealed historical C3A LP evidence reuse (2026-10-13, V1 pending operator execution)

The matched-super LP/AVB authority question was **partly addressed already** by sealed C3A fastboot-entry preflight evidence from 2026-10-03 20:30:47Z (`SHA256SUMS.txt` pin `47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893`) and the earlier E5B `main_a` group baseline JSON from 05:34:41Z (SHA256 `74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926`). The original preflight checked slot A, fastbootd, snapshot `none`, no active COW and capacity; N1F's historical 22:13:50Z `system_a` flash/Android boot markers are already verified separately. A new bounded Python 3 **receipt join V1** inspects only these exact small textual artifacts, their hash seals, LP group maximum and any recorded companion partition **sizes**, without reading an image or contacting the Titan 2. [Scope, 23/23 local tests, checksum-sealed downloadable tool and run instructions](N1F_OCT03_C3A_LP_AVB_RECEIPT_JOIN_V1_20261013.md). **Operator ai-g732 run pending.**

This can close **pre-C3A historical geometry provenance** at best. It cannot recover October 3 N1F **postflash** LP/snapshot state, seven companion partition *byte* identities or exact matched AVB descriptors. These remain **NOT_BOUND**; complete hybrid-super assembly/flash remains BLOCKED. No repeated 991-project census, old R2/native/IMS static work, journal search, Oct03 run-log scan, `lpdump` or device probes.

## Actual C3A/E5B LP receipt join PASS (ai-g732, 2026-10-13)

The operator validated V1 ZIP+manifest and completed **23/23 Python tests** (0.007 s reported). The original pre-C3A preflight manifest, its exact JSON member and earlier E5B JSON all satisfy the historical SHA-256 pins. Reused **pre-C3A** LP group `main_a` max **9,661,579,264** bytes, `super` **9,663,676,416** bytes, snapshot `none` and zero active COWs; six of seven companion partition **sizes** appear in the preflight, while `odm_a` is `NOT_BOUND_OR_NOT_RECORDED` (not `ABSENT`). **All seven companion content hashes are UNBOUND to the Oct03 N1F boot session**, and N1F postflash LP/snapshot state, AVB chain and matched restore are NOT_QUALIFIED. See [V1 actual operator outcome](N1F_OCT03_C3A_LP_AVB_RECEIPT_JOIN_V1_20261013.md).

```text
PRE_C3A_LP_GEOMETRY_HISTORICAL_SEALED=PASS_RECEIPT_LEVEL
PRE_C3A_COMPANION_RECORDED_SIZES=6_OF_7
OCT03_N1F_COMPANION_PARTITION_HASHES=UNBOUND_7_OF_7
OCT03_N1F_POSTBOOT_LP_STATE=UNBOUND
MATCHED_AVB_CHAIN=NOT_QUALIFIED
MATCHED_RESTORE=NOT_QUALIFIED
COMPLETE_HYBRID_SUPER=HOLD_MATCHED_INPUTS
```

Do **not** repeat the old C3A/E5B metadata join or substitute the Oct11 R3 offline LP recipe for an Oct03-matched whole-super provenance. Progress needs a distinct narrowly scoped authorization for actual matched LP/partition/AVB **image evidence**, followed by separate approval for any build/repack or device action; no such authority is granted here.

## Matched-image verification plan approved (host-only Stage A, 2026-10-13)

The operator explicitly authorized preparing the **host-only matched-image verification plan from explicitly identified inputs**. This is **not blanket authority** to read/hash image bytes, extract partitions, run LP/AVB binary tools, construct a hybrid super, build, contact the device or flash.

**New [exact-input Stage A preflight and B1–B4 stage plan](N1F_OCT03_MATCHED_IMAGE_VERIFICATION_PLAN_V1_20261013.md)** uses the operator-approved physically booted **Oct03 N1F** `system.img` identity and the existing **TEE14 large-reference** stock candidate root from the N1C checkpoint. The N1C reference includes six recorded stock partition SHA-256 pins, **none** proving those partitions' bytes were present in the Oct03 N1F boot session. `odm_a` has no historical pin; do not classify it ABSENT merely because the reference or preflight did not record it. Pre-C3A main_a group geometry and V1 receipt-chain integrity already passed and should not be repeated.

Current Stage A executable: **fixed-path `lstat` metadata** for one Oct03 system image, seven stock companion image candidates, stock `super.img`, seven boot/AVB files and two known restore evidence directories; reads at most one **128 KiB** already-qualified C3A JSON. No image bytes, no new checksum claims, no directory scans, output writes, external tools or device. Python AST syntax PASS, local **30/30 regression tests PASS**, synthetic median 0.341ms/p95 0.508ms; ZIP checksum-pinned in linked plan. **AI_G732_V1=EXECUTED — 30/30 tests PASS; input-path exceptions still open**.

```text
OCT03_SELECTED_PARENT=OFFLINE_PLANNING_ONLY
STAGE_A_EXACT_INPUT_METADATA_PREFLIGHT=AUTHORIZED_HOST_ONLY
STAGE_A_RUN_AI_G732=PASS_EXECUTION_WITH_INPUT_PATH_GAPS
STAGE_B1_CANDIDATE_IMAGE_HASHES=NOT_AUTHORIZED
STAGE_B2_LP_METADATA_BINARY_INSPECTION=NOT_AUTHORIZED
STAGE_B3_AVB_BINARY_INSPECTION=NOT_AUTHORIZED
STAGE_B4_MATCHED_RESTORE_REVIEW=NOT_AUTHORIZED
STAGE_C_BUILD_REPACK_DEVICE_FLASH=NOT_AUTHORIZED
OCT03_MATCHED_SEVEN_COMPANION_PARTITION_BYTES=UNBOUND_7_OF_7
OCT03_N1F_POSTFLASH_LP_METADATA=UNBOUND
AVB_AND_RESTORE=NOT_QUALIFIED
G1_FINAL_IMAGE=OPEN G2_EFFECTIVE_AUTHORITY=OPEN G3_IMS_NATIVE_NAMESPACE=OPEN
```

Existing C0 LP/AVB tools and `build/config/host-tools.env` will be reused **only if B stages are separately approved**; no unreviewed `lpdump`, `simg2img`, `lpunpack`, `avbtool`, massive hashing, or generic host tool discovery is introduced by Stage A.

### Stage A actual ai-g732 execution, 2026-10-13 (supersedes pre-run text)

The operator supplied complete stdout from `N1F_P342_OCT03_MATCHED_IMAGE_V1.zip`: outer ZIP and six internal checksums PASS; script/test exact hashes PASS; AST PASS both files; 30/30 Python regression tests PASS (0.017 s), 0.029 s inspect wall time. This only verifies the preflight code and bounded metadata checks; it **does not** perform or qualify image-byte hashing.

**Important:** selected Oct03 parent `system.img` returned `REFUSED_SYMLINK_COMPONENT`, therefore no fresh leaf metadata or SHA. Six N1C TEE14 reference companion file paths returned `PRESENT_REGULAR_FILE`, `odm.img` not present at checked path. Stock-root `super.img` and seven boot/AVB names not present **at those exact paths**; both historical restore evidence directories exist, but directory presence is not restore qualification. All seven Oct03 companion image identities and matched post-N1F LP/AVB/restore remain unbound. The narrow next handoff is *parent path-component symlink target metadata only*, not bypassing the guard; B1–B4/C remain unauthorized. See [actual operator Stage A findings and six sizes](N1F_OCT03_MATCHED_IMAGE_VERIFICATION_PLAN_V1_20261013.md).

### Stage A source-path symlink identity, host-only operator result

Original selected Oct03 `/srv/sable-build/artifacts/titan2/...` fails the strict no-symlink guard because **`/srv/sable-build/artifacts/titan2` is a symlink** with readlink *literal* `/srv/data/sable-build/titan2/artifacts`. Operator's exact parent-path probe returned `STOP_SYMLINK_COMPONENT` and `authority_to_rebind_parent=false`; it did not follow the link or read any image. Only the explicit resulting candidate path `/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img` may receive **separate fixed-path metadata verification** next. Do not assert this target exists, has the Oct03 3,200,540,672 size, or hashes to the historical `dc1f917d...` merely from readlink. The [matched-image Stage A plan](N1F_OCT03_MATCHED_IMAGE_VERIFICATION_PLAN_V1_20261013.md) binds this exact observed status, the bounded syntax/test-validated helper and held B1–B4 authorities. No source/build/device/flash escalation.

### Actual canonical-parent metadata PASS; B1-PARENT authorization pending

The operator ran the checksum-pinned canonical parent helper on **ai-g732**: source/test hashes PASS, **11/11 regression tests PASS**, `status=CANDIDATE_REGULAR_FILE_SIZE_MATCH_METADATA_ONLY`. Exact no-extra-symlink regular-file canonical candidate `/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img` is **3,200,540,672 bytes**—equal to historical N1F parent size. This supersedes the preceding paragraph's *pre-run uncertainty*, **but not** the historical SHA qualification: `candidate_sha256_verified=false`, `authority_to_rebind_parent=false`. The original `/srv/sable-build/artifacts/titan2` symlink refusal is still correct.

**B1-PARENT is proposed, NOT AUTHORIZED**: precisely one full SHA256 hash of that 3,200,540,672-byte canonical image, comparing only to historical `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`. A separate optional review-only distribution ZIP `N1F_P342_OCT03_PARENT_B1_V1.zip` (SHA256 `48a2b08bd53cd2e8d4cfd393e9ac21e1b558245ed27e1a38e4721ec68626b91c`) has a safe default metadata-only mode and a separate explicit parent-hash option; local AST PASS and 16/16 synthetic tests PASS, actual ai-g732 B1 image-byte run NOT EXECUTED. [Details, exact scope and remaining evidence limitations](N1F_OCT03_MATCHED_IMAGE_VERIFICATION_PLAN_V1_20261013.md). No companion hash/LP/AVB/restore/build/device authority. Oct03 seven companion byte identities, postflash LP/VAB/AVB/restore, G1/G2/G3 remain UNBOUND/OPEN.

```text
OCT03_CANONICAL_PARENT_METADATA=PASS_REGULAR_FILE_3200540672_BYTES
OCT03_CANONICAL_PARENT_SHA256=UNVERIFIED_REFERENCE_ONLY
STAGE_B1_PARENT_ONLY_HASH=PROPOSED_NOT_AUTHORIZED
STAGE_B1_STOCK_COMPANION_HASHES=NOT_AUTHORIZED
STAGE_B2_B3_B4=NOT_AUTHORIZED
BUILD_REPACK_DEVICE_FLASH=NOT_AUTHORIZED
```

### Actual B1 review-package metadata-only ai-g732 result — HASH NOT EXECUTED

The operator ran the checksum-pinned `N1F_P342_OCT03_PARENT_B1_V1.zip` **without** the image-hash authorization flag: outer ZIP and all three internal hashes PASS, 16/16 regression tests PASS (0.005s), and the default Python probe reported `status=METADATA_PASS_ONLY`, `mode=METADATA_ONLY_DEFAULT`, `observed_bytes=3200540672`. The literal original alias symlink matched the pinned canonical target; the JSON reports `no_image_read=true`, `no_image_hash=true`, and `authority_to_rebind_parent=false`. This supersedes the previous review package's `ai-g732 NOT EXECUTED` note **for review-only mode only**. The full B1 3,200,540,672-byte image SHA-256 **remains NOT EXECUTED and NOT AUTHORIZED**. A matching canonical file size and safe program test do not prove image content. No changes to G1/G2/G3, Oct03 7/7 companion matching, post-N1F LP/AVB, matched restore or physical permissions. See [matched-image verification plan](N1F_OCT03_MATCHED_IMAGE_VERIFICATION_PLAN_V1_20261013.md).

```text
B1_REVIEW_PACKAGE_AI_G732=PASS_16_OF_16
B1_DEFAULT_METADATA_PROBE_AI_G732=PASS
B1_PARENT_3200540672_BYTE_HASH=NOT_EXECUTED_NOT_AUTHORIZED
B1_COMPANION_IMAGE_HASH=NOT_AUTHORIZED
B2_B3_B4_BUILD_DEVICE_FLASH=NOT_AUTHORIZED
```

### B1-PARENT explicit authorization received — actual full hash pending

The operator responded **“i authorize”** directly to the explicit B1-PARENT ONLY request after actual ai-g732 16/16 review-only tests and the canonical 3,200,540,672-byte metadata check passed. This authorizes **one read-only streaming SHA256 pass** on the single fixed canonical `/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img` using the already independently reviewed `N1F_P342_OCT03_PARENT_B1_V1.zip` verifier with `--authorize-parent-image-hash`, comparing the result to historical `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`. ZIP and internal manifest hash pins must PASS before invocation; stop on any failure. The operator has NOT yet supplied the actual B1 hash result, so image-byte identity stays `UNVERIFIED`. See the [precise new authority and exact command](N1F_OCT03_MATCHED_IMAGE_VERIFICATION_PLAN_V1_20261013.md).

Earlier statements that B1-PARENT had **not** been authorized reflect the state at the time of the review-only execution, and are superseded **for this one exact parent hash only** by this section. No other image hash, LP/AVB, restore, source mutation, build, repack, network, device or flash authority. G1/G2/G3, Oct03 physical companion 7/7 SHA, postflash LP/VAB, AVB and matched restore remain UNBOUND/OPEN.

```text
B1_PARENT_3200540672_BYTE_HASH=AUTHORIZED_NOT_YET_EXECUTED
B1_OTHER_IMAGE_HASHES=NOT_AUTHORIZED
B2_LP=NOT_AUTHORIZED B3_AVB=NOT_AUTHORIZED B4_RESTORE=NOT_AUTHORIZED
SOURCE_MUTATION=NO BUILD=NO REPACK=NO NETWORK=NO DEVICE=NO FLASH=NO
```

### B1-PARENT actual ai-g732 full hash PASS — historical parent artifact bound

The operator provided the complete **actually authorized B1-PARENT** verifier JSON after package ZIP and **all three** internal SHA256SUMS checks passed. On the **one exact canonical** `/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img`, the program streamed **3,200,540,672 bytes** and returned `status=HASH_MATCH_HISTORICAL_REFERENCE_ONLY`, with identical `actual_sha256` and `expected_sha256` **`dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`**. Explicit mode `EXPLICIT_B1_PARENT_IMAGE_HASH`; no output write, subprocess, network, build, device or flash. This consumes the granted one-pass B1 parent-hash permission; prior authorization-pending and no-result claims remain only *historical* and are superseded for the **host parent artifact** by this PASS.

**Do not promote this to physical Oct03 flashed `system_a` cryptographic identity**: actual device readback remains unbound; the tool reported `physically_flashed_oct03_image_proven=false` and `authority_to_rebind_parent=false`. Same-session seven companion bytes, post-N1F LP/VAB, actual Oct11 written super, matched AVB/restore, G1/G2/G3 and Oct13 M4 recovery cause remain unresolved. No extra image hash, stock-root scan/extraction, LP/AVB, build/repack/phone/flash was or is authorized. [Exact outcome and next proposed constrained provenance decision](N1F_OCT03_MATCHED_IMAGE_VERIFICATION_PLAN_V1_20261013.md).

```text
OCT03_N1F_PARENT_HOST_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
OCT03_N1F_PARENT_HOST_BYTES=3200540672
OCT03_N1F_PARENT_HOST_SHA256=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a
OCT03_PHYSICAL_SYSTEM_A_BYTE_READBACK=UNBOUND
OCT03_PARENT_REBIND_AUTHORITY=NO
B1_PARENT_ONE_PASS=COMPLETE
B1_COMPANION_HASHES=NOT_AUTHORIZED
OCT03_COMPANION_CONTENT_SHA256=UNBOUND_7_OF_7
B2_LP_B3_AVB_B4_RESTORE=NOT_AUTHORIZED
G1_G2_G3=OPEN
BUILD_REPACK_NETWORK_DEVICE_FLASH=NO
```

### N1C stock-restoration receipt provenance R0 — prepared, operator run pending

As requested by the operator, the next bounded **host-only read-only restoration-evidence verification plan** is documented in [N1F_P342_N1C_RESTORE_RECEIPT_PROVENANCE_PLAN_V1_20261013.md](N1F_P342_N1C_RESTORE_RECEIPT_PROVENANCE_PLAN_V1_20261013.md). Prior project chats and GitHub audit show N1C stock super + TEE14 boot/AVB restore already succeeded historically, and **merged PR #218/#250/#251** already fixed C0/E4 stock image discovery; repeating these full drivers would redundantly read/hash images, recursively search and write reports. The older Titan 2 Tier2 stock E0 restorer hashes **V01.00.13/TEE13** and cannot substitute for N1C **V01.00.14/TEE14** provenance.

The new R0 package N1F_P342_N1C_RESTORE_RECEIPTS_V1.zip has SHA256 `1995f01afd5e362d36eb7a307efcd45fc0a2bb30a42a05562f9448ea89e847dd`; script AST PASS, synthetic **22/22 tests PASS**, 1,000 synthetic bounded checks median 0.0245 ms / p95 0.0506 ms. It inventories only **immediate names and file metadata** for at most **64 children each** under the **two already-known** N1C super-restore and TEE14 boot/AVB evidence directories, and only after explicit `inspect --authorize-two-root-metadata`. Default `plan` mode does not inspect directories. No receipt contents, image byte/hash, recursion, symlink following, subprocess, output write, network or phone. `R0_AI_G732=NOT_EXECUTED`; do not claim exact manifest leaf names or stock firmware same-session association yet. An R1 exact bounded text-receipt review is a **future separate scope**, not authorized by the operator's plan-preparation request.

```text
OCT03_N1F_PARENT_HOST_B1_HASH=PASS_HISTORICAL_REFERENCE_ONLY
N1C_HISTORICAL_SUPER_BOOT_AVB_RESTORE=PASS_PREVIOUS_N1C_SCOPE_ONLY
N1C_RESTORE_RECEIPT_R0=PLAN_PREPARED_AI_G732_NOT_EXECUTED
N1C_RESTORE_RECEIPT_R1=NOT_AUTHORIZED
OCT03_COMPANION_SHA256=UNBOUND_7_OF_7
OCT03_POSTFLASH_LP_AVB_RESTORE=NOT_QUALIFIED
B1_OTHER_IMAGES_B2_B3_B4=NOT_AUTHORIZED
BUILD_REPACK_NETWORK_DEVICE_FLASH=NO
```

### Actual N1C R0 operator result, R0B exact-leaf handoff

Operator actually ran `N1F_P342_N1C_RESTORE_RECEIPTS_V1.zip`: outer ZIP + four manifest entries PASS, synthetic **22/22 tests PASS** (0.004s), plan no FS access. Explicit R0 inspect correctly returned overall `INCOMPLETE_OR_REFUSED`: first stock-super restore root qualified **18 immediate metadata entries**; second TEE14 boot/AVB evidence root returned `REFUSED_ENTRY_CAP` at 64. Its `entries=[]` is **suppressed due to cap**, not proof of an empty directory. The first root includes a **4,189,766,872-byte regular-file candidate** `titan2-stock-v010014-super-restore-r1c.sparse.img`, without image-byte hash, sparse format parse, LP/AVB check or qualified restore. Existing N1C historical device recovery remains a separate prior receipt, not proof of Oct03 N1F matched companion bytes.

Known **small** historical stock-super text leaves (content NOT read) include `N1C_STOCK_SUPER_RESTORE_ARTIFACT_LEDGER.md` (1267 B), `source-partition-hashes.sha256` (542 B), `source-partition-map.txt` (1105 B), `source-partition-sizes.tsv` (1625 B), `partition-compare.txt` (1328 B). R1 leaf-text analysis requires separate authority; do not publish raw log files or sensitive identifiers.

**New R0B** [exact seven TEE14 boot/AVB basename metadata plan](N1F_P342_N1C_RESTORE_R0B_EXACT_LEAVES_PLAN_V1_20261013.md): avoid the 64-entry directory entirely. Only seven named immediate leaves are checked with no-follow metadata stats in the same fixed TEE14 root (`boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`), based on merged #251 E4 six names + N1C postmortem `dtbo`. No directory enumeration, wildcard find, nested paths, image or receipt bytes, writes, LP/AVB tool, network, device or flash. Prepared checksum-pinned ZIP `N1F_P342_N1C_R0B_EXACT_LEAVES_V1.zip` SHA256 `d9ceb7ce62ce76d2296c8944f31fd7f874064037615f3db41f225eeb834d7564`. Python AST PASS both scripts, local **20/20 synthetic tests PASS** (0.007s), 1000 seven-leaf metadata sample median **0.0135ms**/p95 **0.0190ms**. **Actual R0B ai-g732 not yet run**. This does not change the R0 cap, and is within prior metadata-only scope. Existing main C0/E4 tools and their image hashes should not be repeated. Missing direct leaves do not imply absence from all N1C evidence.

```text
R0_SUPER_ROOT=PASS_18_IMMEDIATE_METADATA_ROWS
R0_SUPER_SPARSE_CANDIDATE=PRESENT_REGULAR_4189766872_BYTES_ONLY
R0_TEE14_ROOT=REFUSED_ENTRY_CAP_64
R0_OVERALL=INCOMPLETE_OR_REFUSED
R0B_EXACT_SEVEN_NAMES=PREPARED_NOT_RUN
R1_TEXT_RECEIPT_READ=NOT_AUTHORIZED
OCT03_PARENT_HOST_B1_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
OCT03_PHYSICAL_COMPANION_SHA256=UNBOUND_7_OF_7
G1_G2_G3=OPEN
B1_OTHER_IMAGES_B2_B3_B4_BUILD_DEVICE_FLASH=NOT_AUTHORIZED
```

### Actual R0B seven direct leaves absent; proposed R0C strictly gated

The operator's actual checksum-pinned R0B package run: SHA manifests PASS; **20/20 tests PASS (0.005s)**; default plan PASS, explicit exact-seven-name metadata inspection PASS. The TEE14 restoration evidence root `/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335` had **no direct** `boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`; all seven returned `NOT_PRESENT_AT_THIS_EXACT_ROOT`, not a global absence. The old R0 TEE14 directory refused a **64-entry** limit; its `entries=[]` was suppressed output, not empty. Earlier historic N1C restore PASS remains historic and does not certify same-session Oct03 companion bytes.

Do **not** run the old merged C0/E4 discovery drivers (#218/#250/#251) here: those use recursive search, image SHA and file writes; nor rerun Oct03 B1 SHA, older C3A geometry, 991 census or R2 linkage investigations. First root already supplied N1C stock-super artifact **regular file size 4,189,766,872 bytes**, content unqualified, plus small exact receipt basenames. `R1_RECEIPT_CONTENT=NOT_AUTHORIZED`.

The [new R0C proposal and build-roadmap matrix](N1F_P342_N1C_R0C_TEE14_PROVENANCE_AND_NEXT_IMAGE_GATES_V1_20261013.md) prepares a single exact-root one-level **filtered** metadata inventory capped at **256 total immediate names / 96 matched entries**, not recursive and not a receipt reader. This **increases the old cap** and therefore `R0C_CAP_EXPANSION=NOT_AUTHORIZED` until separate explicit operator permission. The packaged `N1F_P342_R0C_TEE14_INVENTORY_V1.zip` is SHA256 `3989e5b1aeabe140e95c9b3ea15b5ac8b706a90458c7610e89b80b0ae2df6e68`; Python source/test syntax PASS, synthetic **22/22 PASS**, 1000 synthetic 150-leaf checks median 0.1884ms/p95 0.2096ms; `R0C_AI_G732=NOT_EXECUTED`. Default `plan` does not access the host filesystem; inspect requires a new exact-purpose flag **and operator approval**. Only stdlib Python3.10+, unzip and sha256sum; no LP/AVB/AOSP tools or installation.

**Next-image engineering status:** Oct03 N1F retained host SHA **PASS** (physical Oct03 readback unbound); Oct03 7/7 physical companion byte identities, postflash LP/VAB and matched AVB/restore **UNBOUND**; final G1 embedded IMS composition, G2 effective signing/classpath/SELinux, G3 recursive IMS-native namespace **OPEN**. No new IMS-enabled system image, qualified hybrid super, build, repack, device, reboot or flash permission. The proposed workstreams can be prepared in parallel, but gates cannot be declared passed by plan-only metadata.

```text
R0B_OPERATOR_AI_G732=PASS_20_TESTS_AND_SEVEN_ABSENT_DIRECT_LEAVES
R0C_CAP_256=PROPOSED_NOT_AUTHORIZED
R0C_AI_G732=NOT_EXECUTED
OCT03_PARENT_HOST_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
OCT03_SAME_SESSION_COMPANION_SHA256=UNBOUND_7_OF_7
OCT03_POSTFLASH_LP_AVB_RESTORE=NOT_QUALIFIED
G1=OPEN G2=OPEN G3=OPEN
SOURCE_MUTATION=NO BUILD=NO SUPER_REPACK=NO DEVICE=NO FLASH=NO
```

### Corrected G1/G2/G3 status — completed scoped PASS, new-image admission delta only

The operator flagged that the previous simplistic table marked **all three gates “open” as if earlier work had not been completed**. Review of archived PR #339 operator results confirms this framing was misleading. **New [scope-qualified G1/G2/G3 reuse and next-image delta audit](N1F_P342_G123_PRIOR_PASS_REUSE_AND_NEXT_IMAGE_DELTA_V1_20261013.md)** is controlling for inherited evidence: G1 M4 selected product graph/source/capture and embedded 11/11 image-member hashes **PASS_PRIOR_SCOPE**, with `skip_mount.cfg` byte matching; G2 M11 cryptographic SableOS platform cert, APK manifest sharedUID declaration and M4 API36 two semantic bootclasspath records **PASS_PRIOR_SCOPE**, with XML/policy-file hashes; G3 five R2 inputs/56 direct NEEDED/19 Bionic/four unversioned symbol bindings and six M4 provider ELFs **PASS_PRIOR_SCOPE**. Do **not** rerun M11 14,094 targeted build, M4 full system image SHA, classpath, prior ELF/symbol static work or flashing regressions to re-establish these receipts.

**Open is exact *new Oct03-derived target admission***, not an absence of M4 engineering: G1 selected new-source-to-final effective embedded image (M4 physically FAIL_RECOVERY); G2 effective merged SELinux/privapp/UID/classloader/mount precedence in that new final image; G3 full recursive versions and actually available IMS process linker namespace/installed R2 path. These cannot transfer by assertion. PR #339 build engineer reviewed same boundaries; no source/build/image/device permission implied by a catalog PASS. Seven Oct03 physical companion bytes, postflash LP/VAB/AVB, matched restore and Oct11 physical super remain unbound.

New checksum-sealed **report-only** `N1F_P342_G123_REUSE_V1.zip` SHA256 `ad7ffeea5d5fbd00d256946d3b86136d326227c632a4aba7aaf4a391a4486850` contains historical operator-source ledger and Python validator; two AST PASS, **20/20 synthetic tests PASS**, 1.38s full test process / 98,696 KiB peak, 1000 in-memory classification median 0.00199ms/p95 0.00215ms; ZIP/internal checksum PASS. It reads no ai-g732 host evidence or image and performs no build/source/device/network operations; output `PASS_CATALOG_INTEGRITY_ONLY_NO_NEW_ENGINEERING_ADMISSION` must not be mistaken for G1/G2/G3 PASS_NEW_TARGET.

Actual operator R0C so far: archive integrity and **22/22 tests PASS**, `PLAN_ONLY_NO_FILESYSTEM_ACCESS` only; `R0C_256_INSPECT=NOT_AUTHORIZED`. Do not raise R0=64 entry cap or enumerate the TEE14 evidence root without separate user approval.

```text
G1_M4_GRAPH_CONTENT_SKIP_MOUNT=PASS_PRIOR_SCOPE
G2_M11_SIGNER_MANIFEST_M4_API36_BCP=PASS_PRIOR_SCOPE
G3_R2_5_ELF_56_NEEDED_19_BIONIC_4_GNU_M4_6_ELF=PASS_PRIOR_SCOPE
G1_G2_G3_NEW_IMAGE_ADMISSION=OPEN_EXACT_DELTA
R0C_OPERATOR=PLAN_AND_22_TESTS_ONLY
R0C_256_IMMEDIATE_NAMES_INSPECT=NOT_AUTHORIZED
BUILD_REPACK_NETWORK_DEVICE_FLASH=NOT_AUTHORIZED
```

### Actual G123 catalog on ai-g732 complete; next image has two build choices

The operator's **actual** `N1F_P342_G123_REUSE_V1.zip` SHA and internal five-file SHA manifest PASS, **20/20 tests PASS (0.031s)**, and report `PASS_CATALOG_INTEGRITY_ONLY_NO_NEW_ENGINEERING_ADMISSION` (zero image reads, no host evidence revalidation, build, network or device). Negative argparse `inspect` output inside test 12 was **expected**. The prior reviewed **G1 M4 product/embedded + skip_mount**, **G2 M11 platform APK signer/manifest + M4 two API36 boot jars**, **G3 five R2 inputs / 56 DT_NEEDED / 19 Bionic / four direct symbols / six M4 ELF** checks remain **PASS_PRIOR_SCOPE**. This is NOT a new full-image G1/G2/G3 PASS and does not repair failed M4 boot.

The [new Oct03-derived next-image decision](N1F_OCT03_NEXT_IMAGE_BUILD_DECISION_V1_20261013.md) reuses the existing [archived PR #339 exact source mutation plan](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1F_M4_EXACT_MUTATION_AND_BUILD_AUTHORIZATION_PLAN_20261012.md) and existing C1 product modules. **No new implementation script was written because existing owner modules, exact source patch plans and built-in host tools already cover the work.** New proposals distinguish **A** — R1+B1+C1 **host-only build to inspect image G1/G2**, with R2 excluded and **no physical flash** due historically observed VT risk — from **B** — full IMS R1+B1+C1+R2 **after G3 runtime namespace closure**. Both require separate exact source/revision binding and new source/build permission. Complete super repack/LP/AVB/matched restore and physical flash still distinct, unapproved gates. Existing old combined N1F/C1 build-flash drivers must NOT run.

Current R0C on ai-g732 is **checksum/tests/PLAN ONLY** (22/22) with no directory inspection; new 256-entry cap remains **NOT_AUTHORIZED**. Seven Oct03 physical companion hashes and LP/AVB/restore remain unbound. Avoid repeating the already-passed large-image hash, 991 census, M11 build, M4 file/BCP checks, 56-edge crawl, seven-directory restore searches or G123 catalog.

```text
G123_AI_G732=PASS_CATALOG_ONLY_20_OF_20
G1_G2_G3_HISTORICAL_M4_COMPONENTS=PASS_PRIOR_SCOPE
G1_G2_G3_SELECTED_NEXT_IMAGE=OPEN_TARGET_DELTA
OCT03_PARENT_HOST_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
NEXT_IMAGE_OPTION_A_HOST_BUILD=PLAN_ONLY_NOT_AUTHORIZED
NEXT_IMAGE_OPTION_B_R2_INTEGRATION=BLOCKED_PENDING_G3
R0C_256_IMMEDIATE_NAME_INSPECTION=NOT_AUTHORIZED
OCT03_PHYSICAL_COMPANIONS=UNBOUND_7_OF_7
BUILD=NO SOURCE_MUTATION=NO REPACK=NO DEVICE=NO FLASH=NO
```

### Five-R2 native qualification: direct and version subsets PASSED, effective namespace status sourced

Following the operator's R2 challenge, a second review of original archived PR #339 V19–V36, the C2 integration closure **requirements** (B4/B5), PR #334 Gate G/G2, current main B2 code and PR #342 confirmed **all five R2 SHA/ELF, 56 direct DT_NEEDED, 19 Bionic test subset, six Android16 provider export-name parity and V28 four direct unversioned symbol/version edges are ALREADY PASS**. Do **not** repeat or call these unknown. However the C2 closure document lists `B4_JNI_NATIVE_DT_NEEDED_CLOSURE=PASS`, `B5_NATIVE_SEARCH_PATH_AND_NAMESPACE=PASS` as *required evidence* under its planning checklist; it does not contain a corresponding actual operator PASS of the **specific Oct03-derived five-library privileged IMS process namespace**. Existing B2 labels vendor-only candidates `FILE_PRESENT_NAMESPACE_UNPROVEN`, and PR #334 itself documents GNU version and complete namespace limitations. PR #339 V33 mapped original Oct03 `linker.config.pb` as **build-time** schema and explicitly retained `GENERATED_RUNTIME_LINKERCONFIG=NOT_PROVEN`, `IMS_APP_NAMESPACE=UNQUALIFIED`, `R2_RECURSIVE_ABI=UNQUALIFIED`; V34 did not find the generated config in its bounded paths, V36 five-file bytes were exact, not runtime closure, and later build engineer retained this precise delta.

**Precise status:** `R2_STATIC_DIRECT_DEPENDENCIES_AND_BOUNDED_SYMBOL_CHECKS=PASS_PRIOR_SCOPE`; `G3_COMPLETE_TARGET_IMS_NAMESPACE=NOT_PROVEN_BY_CURRENT_REVIEWED_RECEIPTS`, **not a demonstrated incompatibility**. An already-existing *fully qualified* transcript may supersede this if it is exact-five-library, selected-image and process namespace bound; link its SHA/path/actual outcome instead of re-running large checks. Detailed [receipt-by-receipt reconciliation](N1F_OCT03_NEXT_IMAGE_BUILD_DECISION_V1_20261013.md). No source/image build, phone contact or flash authority is added.

### Earlier complete N1I-A A4 native host audit PASS recovered from SableOS history

A second project-history/GitHub check recovered **additional genuinely executed host native-closure evidence** from the earlier C0/C2 lane, distinct from PR #339 M4 direct native checks: [N1I-A V01.00.14 OEM IMS closure](https://github.com/aimindseye/sableos/blob/main/docs/titan2/N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE.md) records a corrected **actual host run** `N1I_A_NATIVE_DEPENDENCY_CLOSURE=PASS`, `N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS` on 2026-10-05, at **`/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z`**; report SHA `08e6dbec6586352589e65f38c5e1e4394c6d0cfc58c762646a8ea9d5d5e6b68c`, env SHA `a7135f5802db40835b8b4563f43ea57d4ddee1da1b37c2b58c0ad77ff47b4de8`. Its A4 33-path broad reference set includes the five R2 ViLTE names, and corrected platform/APEX classification prevented four false 'missing library' errors. Merged PR #319 accepted this host audit. Merged PR #326 real V5 relied on **A4 accepted superset** to report `N1I_C2_MANIFEST_NATIVE_CLOSURE=PASS_FINITE` (41 finite mutations) because its then-checked Titan evidence root **lacked a retained exact B2 stock/C3A pair**; PR #326 did not claim a whole new runtime namespace proof. The archived B2 code and proposed PR #334 state complete GNU symbols/versions and generated effective IMS process namespace cannot be inferred from static A4/B2 alone.

Thus the historical native work is **even more complete than earlier wording suggested**: `N1I_A_A4_NATIVE_DEPENDENCY_CLOSURE=PASS_ACTUAL_HOST`, `N1I_C2_A4_FINITE_NATIVE_SET=PASS_MANIFEST`, `R2_FIVE_STATIC_IDENTITY_DIRECT_SYM=PASS_PRIOR_SCOPE`. However no reviewed chat-indexed attachment/repo PR discussion supplied a distinct exact-Oct03 N1F five-R2 **full recursive symbol/version + effective IMS app runtime namespace** PASS receipt. Classify this final specific claim **NOT_EVIDENCED_IN_AVAILABLE_SOURCES** (not demonstrated incompatible or universally unresolved). Its possible preexisting report should be *reused rather than rerun* if later found. Details: [build-decision recovered A4 evidence](N1F_OCT03_NEXT_IMAGE_BUILD_DECISION_V1_20261013.md). No R0C, new host file reads, image checks, mutation, build or device activities.

### Exact archived N1I-A A4 two-receipt validation plan — prepared, not run

Historical N1I-A corrected host A4 native dependency audit `PASS` is already established by the main [source audit](https://github.com/aimindseye/sableos/blob/main/docs/titan2/N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE.md), merged PR #319 and PR #326 accepted A4 finite manifest. The **only** next narrow scope is to pin/review the two known existing **text receipt leaves**, not rerun its image/APK/ELF-probing audit; see [N1F P342 exact two-receipt plan](N1F_P342_A4_TWO_RECEIPT_VERIFICATION_PLAN_V1_20261013.md).

Retained root `/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z`. Exact `N1I_A_V010014_OEM_IMS_REPORT.md` SHA256 `08e6dbec6586352589e65f38c5e1e4394c6d0cfc58c762646a8ea9d5d5e6b68c` cap 131072 bytes, and `n1i-a-v010014-oem-ims.env` SHA256 `a7135f5802db40835b8b4563f43ea57d4ddee1da1b37c2b58c0ad77ff47b4de8` cap 32768 bytes. The actual operator **has not authorized or executed** these new text content reads. A correct checksum plus two old `PASS` markers would certify historical A4 receipt provenance only; `G3_FULL_SELECTED_N1F_IMS_RUNTIME_NAMESPACE` remains **NOT_EVIDENCED** (not ABI failure or proof impossible).

Distribution-only ZIP `N1F_P342_A4_TWO_RECEIPT_V1.zip` SHA256 `abbc406742f34d670fbf8ab806e93213773679ea598b3b36f544aa43f8ecdaf7`; Python source SHA `97d4f39ba863f3db7b6090777f20b0477a07debddb29648d0009cbe1b9c45027`, test SHA `25dd31504e56d3ac427684f5c0137404eefd799b5fed141f3f342cc0fb25e03d`; ZIP + 4/4 internal checks PASS, AST both PASS, **30/30 synthetic tests PASS**, README shell syntax PASS. Synthetic two-file 1500-run median/p95 `0.025799ms/0.033191ms`, 110KiB 300-run `0.561032ms/0.691213ms`; max RSS 99092 KiB, not host runtime. Default `plan` no evidence access; actual inspect needs separate opt-in and permission, read-only nofollow exact-two-text, SHA-before-output, no directory listing/file echoes/ELF/images/writes/subprocess/device/build/flash. Python3.10+ stdlib, unzip/sha256sum only. Do not run B2/A4/C0/E4 or repeated parent/R2 scans.

```text
A4_HOST_NATIVE_PASS=REUSED_PRIOR_EXECUTED
A4_TWO_RECEIPT_PLAN_PACKAGE=VALIDATED_30_OF_30
A4_TWO_RECEIPT_AI_G732=NOT_EXECUTED
A4_TWO_RECEIPT_CONTENT_READ=NOT_AUTHORIZED
R2_DIRECT_SHA_NEEDED_BIONIC_SYMBOLS=PASS_PRIOR_SCOPE
R2_FULL_N1F_RUNTIME_NAMESPACE=NOT_EVIDENCED
OCT03_PARENT_HOST_B1=PASS_HISTORICAL_REFERENCE_ONLY
R0C_256_INSPECT=NOT_AUTHORIZED
NEW_IMAGE_BUILD_DEVICE_FLASH=NOT_AUTHORIZED
```

### Explicit operator grant to read exactly two N1I-A A4 text receipts

The operator's actual host run of `N1F_P342_A4_TWO_RECEIPT_V1.zip` **PASSED ZIP outer/inner hashes, 30/30 synthetic tests (0.007s), and PLAN_ONLY**. Operator then **explicitly authorized one bounded read-only inspection** of exactly the previously-pinned `N1I_A_V010014_OEM_IMS_REPORT.md` (cap 128KiB, SHA `08e6dbec6586352589e65f38c5e1e4394c6d0cfc58c762646a8ea9d5d5e6b68c`) and `n1i-a-v010014-oem-ims.env` (cap 32KiB, SHA `a7135f5802db40835b8b4563f43ea57d4ddee1da1b37c2b58c0ad77ff47b4de8`) under `/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z`. Existing tool's `inspect --authorize-two-pinned-a4-text-receipts` is the **only approved evidence-content read**. **Actual ai-g732 inspect not yet executed**; neither files' contents have been delivered in this checkpoint. Fail-closed on nofollow/root/leaf errors or SHA/size mismatch without changing paths or elevating authority.

No redundant new script: exact two-leaf verifier already tested, syntactically checked and frozen (outer ZIP `abbc406742f34d670fbf8ab806e93213773679ea598b3b36f544aa43f8ecdaf7`, assistant reran local 30/30 tests in 0.012s, and classifier microbenchmark median/p95 0.0035/0.0041ms in 1500 in-memory samples). Historical executed A4 + C2 compatibility-manifest + five R2 static direct/name/limited GNU checks remain **PASS_PRIOR_SCOPE** regardless of this verification. If two-receipt hash/marker results PASS, classify only **`PASS_HISTORICAL_A4_RECEIPTS_NOT_RUNTIME_NAMESPACE`**, *not* recursive complete ABI or selected N1F effective IMS runtime G3 PASS. Full three-gate next-image admission, 7 Oct03 companions, LP/AVB/restore, R0C 256-name TEE14 enumeration, source/build, device and flash still separately held.

```text
A4_EXACT_TWO_RECEIPT_OPERATOR_AUTHORIZATION=YES_ONE_TIME
A4_EXACT_TWO_RECEIPT_AI_G732_INSPECTION=NOT_YET_RUN
A4_PRIOR_NATIVE_AUDIT=PASS_ACTUAL_HISTORICAL_SCOPE
R2_FIVE_PREVIOUS_STATIC_DEPENDENCIES=PASS_PRIOR_SCOPE
G3_SELECTED_N1F_FULL_RUNTIME_NAMESPACE=NOT_EVIDENCED
R0C_256_ENTRY_INSPECT=NOT_AUTHORIZED
BUILD=NO NETWORK=NO DEVICE=NO FLASH=NO
```

### Actual October 5 A4 receipts rebound PASS; new R1/B1 source-state next step

The operator's **actual** previously authorized ai-g732 two-text inspector returned `PASS_HISTORICAL_A4_RECEIPTS_NOT_RUNTIME_NAMESPACE`: exact historical report 25,683 bytes SHA MATCH and env 6,678 bytes SHA MATCH; **32,361 bytes** total, both `N1I_A_NATIVE_DEPENDENCY_CLOSURE` and `N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE` true, `native_unresolved_none=true`. Neither report mentions verified GNU version/VERNEED/linker namespace labels; the script reports only word-presence, **not semantic proof of their absence**. Directory enumeration=false, file contents echoed=false, image/ELF bytes read=0, filesystem mutation/network/build/device/flash=false. The one-time A4 exact-two-receipt scope **was consumed**; historical A4 native dependency host PASS provenance now VERIFIED, **no rerun** of A4/B2/R2 required. [Sealed executed A4 result](N1F_P342_A4_TWO_RECEIPT_VERIFICATION_PLAN_V1_20261013.md).

To progress toward the next *distinct* Oct03-derived host-only image without repeating A4, M11, R2 five identity/56 direct/19 Bionic/V28 four direct GNU probes, the Oct03 image SHA, 991 heads or R1 already-PASS patch preview, a **new report-only exact two-file source-state preflight** is prepared: [N1F P342 R1/B1 exact source-state plan](N1F_P342_R1B1_EXACT_SOURCE_STATE_PLAN_V1_20261013.md). It reuses the archived PR339 **R1 Manifest PRE and POST SHA256** and **B1 TelephonyMetrics PRE and POST Git blobs**, compares only two source files in a future separately selected approved Android16 checkout, and outputs exact PRE/POST or BLOCK. ZIP `N1F_P342_R1B1_SOURCE_V1.zip` SHA256 `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b`, script SHA `14f03c679a9483aa5f306b5420028ade34edbd391c398699f3d9a358986c8e56`, test SHA `bc337e61085574e80b3f6099d85f587524cc8c77054644104066d0b07fa09ad0`. Python AST both PASS, 34/34 synthetic unit tests PASS (0.030s; whole process 0.72s/100,364KiB max RSS), synthetic 589,824-byte two-file check 400 iterations median **0.635ms**/p95 **0.846ms**, all local assistant host. ZIP/in-manifest PASS. Default `plan` no host file reads; **ai-g732 R1/B1 source content not authorized or executed**. Explicit selected actual workspace root still UNBOUND; no symlink or guessed path substitutions permitted.

This does not imply full `G1/G2/G3` admission, approve any R1/B1 mutation, C1 native integration, isolated Android build, super repack, seven Oct03 companion evidence, R0C 256-entry TEE14 scan or device operation. Full selected privileged IMS process namespace/recursive GNU-version R2 closure remains **NOT_EVIDENCED**, not FAIL_ABI. The previously executed PR339 R1 no-write preview and actual M4 C1 content remain PASSED at original scope.

```text
A4_AI_G732_TWO_RECEIPTS=PASS_PINNED_SHA_2_OF_2
A4_HISTORIC_NATIVE_CLOSURE=PASS_OPERATOR_VERIFIED_PROVENANCE
A4_ONE_TIME_CONTENT_SCOPE=CONSUMED
R1_B1_NEXT_SOURCE_STATE_PREFLIGHT=READY_PLAN_ONLY_34_TESTS
R1_B1_REAL_SELECTED_SOURCE=UNBOUND
R1_B1_CONTENT_READ_AUTHORIZED=NO
G1_G2_G3_NEW_SELECTED_IMAGE=NOT_YET_ADMITTED
R2_FULL_EFFECTIVE_IMS_NAMESPACE=NOT_EVIDENCED
R0C_256_ENTRY_TEE14_INSPECT=NOT_AUTHORIZED
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

### Operator-authorized R1/B1 source read: prior V38 and M4 work already qualified, new checkout not bound

Operator actual R1/B1 package ZIP/in-manifest **PASS**, 34/34 synthetic regression **PASS 0.021s**, default plan **`PLAN_ONLY_NO_HOST_FILESYSTEM_ACCESS`**. The operator explicitly authorized read-only inspection of **two** exact files `frameworks/base/core/res/AndroidManifest.xml`, `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java` in **the selected** Android16 workspace (<=2 MiB each). This authority is **not generic project/checkout enumeration or permission to inspect multiple candidate roots**, and not source-mutation/build authority. Actual new selected-workspace bytes **NOT_READ**.

Crucial prior GitHub history recovered while selecting scope: [PR339 executed V38 original checkout](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497214527) `/srv/data/sable-build/workspaces/titan2-n1d/android` R1 exact PRE, B1 Git PRE **PASS**; separate reconstructed M4 `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android` had R1 exact POST and later official B1 exact PRE→POST **PASS** [PR339 B1 integration](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497674970). The isolated partial R1 tree `/srv/data/sable-build/workspaces/n1f-m4-ims01/android/frameworks/base` had R1 POST (not a complete new Android root). **Do not rerun these already qualified source states or promote failed-recovery M4 to next boot-qualified parent.** The specifically selected *new Oct03-derived* source-root and full source lineage are not yet bound by the user-provided evidence. Only once a distinct exact already-existing new isolated checkout is selected should the one approved source pair be inspected; fail closed on absence/symlink/unknown PRE/POST. No worktree creation, git/repo recensus or image read authorized. [Source selection/no-repeat decision](N1F_P342_R1B1_PRIOR_WORKSPACE_DECISION_V1_20261013.md).

Same frozen V1 script checksum `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b` and tests were locally reverified ZIP SHA, inner 4/4, Python AST PASS and 34/34 local repeat PASS (0.032s). Original synthetic 589824-byte two-file inspect median 0.635ms/p95 0.846ms, not host evidence execution. **Do not invent additional R1/B1 implementation tools.**

```text
R1B1_TESTS_OPERATOR=PASS_34_OF_34_AND_PLAN
R1B1_AUTHORITY=READ_TWO_FIXED_FILES_IN_ONE_SELECTED_NEW_ANDROID16_ROOT
R1B1_NEXT_IMAGE_SOURCE_ROOT=UNBOUND
R1B1_NEW_ROOT_INSPECT=NOT_EXECUTED
V38_ORIGINAL_R1_B1=PRE_PRE_QUALIFIED_PRIOR
M4_FAILED_IMAGE_SOURCE_R1_B1=POST_POST_QUALIFIED_PRIOR
OCT03_HOST_PARENT_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
G1_G2_G3_NEW_IMAGE=NOT_ADMITTED
SOURCE_MUTATION=NO BUILD=NO REPACK=NO DEVICE=NO FLASH=NO
```

### Recovered exact Android16 source-root paths and scope

Operator had no `SELECTED_ANDROID_ROOT`; historic N1F Oct12 workstreams, PR #339 and main `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh`/source env confirm **original N1F Oct03 build source root** `/srv/data/sable-build/workspaces/titan2-n1d/android` and **separate isolated 991/991 C3A-derived M4 source reconstruction root** `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`. The one-project R1 tree `/srv/data/sable-build/workspaces/n1f-m4-ims01/android/frameworks/base` is not a complete Android root. V38 original PRE/PRE and later M4 POST/POST are **PASS_PRIOR_SCOPE**, not to be repeated for history alone. Source-root identity is now **KNOWN_FOR_THOSE_TWO_HISTORICAL_TREES**; **the source-to-new-Oct03 boot-qualified image lineage remains UNBOUND**. The M4 checkout is the best existing isolated *integration source candidate* for an optional current byte-state recheck under the user's previously authorized exactly-one-root two-file read, **not a certified bootable image parent or a new build approval**. Distinct `/srv/sable-build` and `/srv/data/sable-build` mount/alias relationship remains unverified; no auto-canonicalization or follow-symlink workaround. The existing frozen R1/B1 script ZIP hash/inner 4/4, AST, 34/34 synthetic tests **re-PASS** in assistant container; **no ai-g732 real file bytes read this turn**.

[Exact original-versus-isolated root decision](N1F_P342_R1B1_PRIOR_WORKSPACE_DECISION_V1_20261013.md). No new scanner, no AOSP tool installation, image/ELF reads, G1/G2/G3 promotion, source mutation, build, device or flash. The already-verified October 3 `system.img` SHA is a distinct historical host-image reference. Never repoint an `--android-root` to the **partial** R1-only tree or use M4 Recovery image as an approved parent.

```text
OCT03_ORIGINAL_SOURCE_ROOT=HISTORIC_PATH_KNOWN
ISOLATED_M4_RECONSTRUCTION_ROOT=HISTORIC_PATH_KNOWN_991_OF_991
CURRENT_SOURCE_ROOT_METADATA_AND_R1B1_BYTES=NOT_RECHECKED
SELECTED_NEW_BOOTING_PARENT_SOURCE_LINEAGE=UNBOUND
READ_ONLY_EXACT_R1_B1=AUTHORIZED_ON_ONE_SELECTED_ROOT
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

### R1/B1 final selected M4 source PASS — consumed exact two-file authority

**Actual ai-g732 operator execution:** SHA-verified frozen R1/B1 source inspector read exactly two fixed files under `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`, **544326 total bytes**, no enumeration/images/writes/build/network/device/flash. `frameworks/base/core/res/AndroidManifest.xml` 541779 bytes SHA256 `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca` = **R1 POST_EXACT**; `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java` 2547 bytes proper Git blob `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`, raw SHA256 `2bc30b0df7c12eed9157aad57682562a4a0b928794ac55a8b650fa927d2fce1e` = **B1 POST_EXACT**. `PASS_TWO_SOURCE_STATES_IDENTIFIED_NOT_SOURCE_LINEAGE`; patch reapplications **NO/NO**, one-time source-file read permission **CONSUMED**. Supersedes earlier R1/B1 source INSPECT_NOT_EXECUTED. This is **PASS_M4_SOURCE_TWO_FILES**, not complete 991 source-to-Oct03-image provenance or final G1/G2/G3 image admission. [Detailed PASS and next source/parent hold](N1F_P342_M4_R1B1_OPERATOR_PASS_SOURCE_PARENT_HOLD_V1_20261013.md).

**Next nonduplicative engineering handoff:** Review exact *already retained* M4 final build source-manifest/exec-receipt linkage and boot-critical differences from separate physically booted Oct03 image. No named final `repo manifest -r` / source-build receipt cryptographically linked to M4 image is established by available PR records; do not infer absent on host or rerun 991 source census, M11, full image hash, 11/11 members, API36 BCP, historic A4/C2 or R2 static analysis. Known source deltas include C3B TrebleApp removal, PHH guard/marker, root-folder packaging, R1/B1; compiled `skip_mount` and embedded classpath tests passed prior bounded scope, but M4 Android still **FAIL_RECOVERY** with unknown root cause. The Oct03 `dc1f917d...` booted parent and M4 `261ee714...` failed image remain separate. Any next host-only R1+B1+C1 build, additional exact small-host-receipt read, image work, source edit, full super or device flash requires separate new authorization and explicit artifact/input binding. Seven Oct03 physical companions/LP/AVB/restore and G3 selected IMS runtime namespaces remain unbound; R0C 256 one-level TEE14 inventory unapproved.

Review-only distribution ZIP `N1F_P342_SOURCE_TO_PARENT_DECISION_V1.zip` outer SHA256 `cedada92caab92b130268b477bac2aed31a95b17011948a824a795dc4997cf5d`, inner checks 3/3 PASS, decision JSON invariants 8 PASS. **No new script**: original R1/B1 verifier outer+inner checksum AST syntax and 34/34 local tests PASS (0.034s core, 0.81s wall, 100488 KiB max RSS), synthetic 400 × 589866-byte classifier median **0.5179ms**, p95 **0.7166ms** (assistant host), not ai-g732 actual source-read latency.

```text
R1B1_SELECTED_M4_AI_G732=PASS_POST_POST_EXACT
R1B1_REAPPLY=NO
R1B1_READ_AUTHORITY=CONSUMED
SOURCE_TO_OCT03_BOOT_PARENT_LINEAGE=NOT_YET_BOUND_FULL
M4_PHYSICAL_ANDROID_BOOT=FAIL_RECOVERY_CAUSE_UNPROVEN
R2_PRIOR_STATIC_AND_A4_NATIVE_AUDIT=PASS_PRIOR_SCOPE
G1_G2_G3_NEW_SELECTED_IMAGE=NOT_ADMITTED
SOURCE_MUTATION=NO BUILD=NO REPACK=NO DEVICE=NO FLASH=NO
```

### Existing M4 postbuild receipt reviewed; hybrid-super M4 boot remains unproven

Operator explicitly authorized the **narrow review of an identified existing build receipt** and continued interpretation of previously documented source differences. [M4 operator final postbuild receipt PR339 review #5502246106](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502246106) is the **identified and now reviewed** source: two complete `out-m4-g2-fullimage-01`/intermediate system images each 3194466304 bytes, identical SHA256 `261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce`, Ninja `build completed successfully`; old V1.1 wrapper `SYSTEMIMAGE=FAIL_MISSING` is **contradicted on image-existence**, with cause of wrapper observation unknown (do not invent a race). Prior [11/11 embedded content and API36 bootclasspath](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502638731) PASS scoped; M4 physical `system_a` write then Android **FAIL_RECOVERY** root cause unbound; there is no boot/early-init/AVB crash receipt bound to this failure. No exact actual M4 final project-head manifest/exec log file is identified in reviewed repository/PR discussions; **no new ai-g732 host file content was accessed**, do not infer lack of such a file.

**Counterfactual:** Would the identical M4 `system.img` packaged into an entire hybrid `super.img` have booted? **UNKNOWN_NOT_TESTED**, not PASS. If effective companion bytes, AVB, LP/snapshot state and first-stage mapping were identical to M4 failed system_a trial, repacking alone cannot repair intrinsic M4 init/framework/SELinux/boot defects. A **different explicitly matched** hybrid partition set could potentially change boot behavior if the failure came from partition composition/snapshot/AVB, but actual Oct11 flashed super SHA/journal and Oct03 seven same-session companions are UNBOUND; Oct11 Android boot with its N1F-based system does not certify M4 system boot. More detail: [narrow reviewed receipt and hybrid-super counterfactual analysis](N1F_P342_M4_SUPER_COUNTERFACTUAL_AND_RECEIPT_REVIEW_V1_20261013.md).

**Source differences considered without rerun:** Exact current R1/B1 POST/POST are closed; M4 C3B legacy TrebleApp removal, PHH marker/mtkmal gate, generated root folders, retained `skip_mount.cfg`, embedded C1 IMS payload, JAR API36 classpath and still unqualified effective policy/native runtime require boot-critical delta interpretation. Five R2 native inputs absent from M4 image is **not** a demonstrated cause of Recovery. Do not replace known-good Oct03 with failed M4 as default derived parent or propose unsanctioned whole-super flashing. No new script, A4/native census, source scan, build or image hash is justified by this textual receipt review.

```text
M4_BUILD_RECEIPT_PR339_5502246106=REVIEWED
M4_COMPLETE_IMAGE_PRODUCED_HASHED=PASS_HISTORICAL
M4_WRAPPER_FAIL_MISSING=UNEXPLAINED_OBSERVATION_CONFLICT
M4_PHYSICAL_ANDROID_BOOT=FAIL_RECOVERY
M4_AS_HYBRID_SUPER_BOOT=UNKNOWN_NOT_TESTED
M4_FATAL_CAUSE_IMAGE_VS_COMPANIONS=UNBOUND
OCT11_ACTUAL_FLASHED_HYBRID_SHA=UNBOUND
OCT03_SEVEN_COMPANIONS_LP_AVB_ROLLBACK=UNBOUND
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

### Oct03 versus M4 offline first-stage / PHH / SELinux / LP delta — completed evidence review

**User approved** an offline boot-critical-delta comparison of retained Oct03 N1F and M4 evidence only, explicitly including first-stage mounts, PHH source, effective SELinux and partition assumptions. Review **COMPLETE at existing evidence scope**; see [new detailed ten-row differential/decision](N1F_P342_OFFLINE_BOOT_CRITICAL_DELTA_V1_20261013.md). Distribution-only `N1F_P342_OFFLINE_BOOT_DELTA_V1.zip` outer SHA256 `278a9c56da39ad4e07c601f1409e62c4195db0f75c06f50fe17c1017a2691059`; four internal SHA members PASS, deterministic ZIP validation 2/2 byte-identical, JSON negative permission invariant PASS, 10 x 9 populated source-bounded comparison matrix rows PASS. **No new executable script, image, source or host file reads**; no build/device/flash.

**Delta findings:** original Oct03 system image physically booted, Oct11 separately observed N1F-based hybrid runtime booted with embedded symlinks but flashed super SHA/journal **UNBOUND**, M4 different source/image SHA built and flashed `system_a` **12/12 OKAY but FAIL_RECOVERY**. Distinct dates and partition environments are not a controlled same-byte/same-AVB A/B. The earlier alleged M4 missing `skip_mount.cfg` was **refuted** by source + embedded staged file same SHA `0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e`, expected absolute compatibility symlink and frozen-image member hash; **effective failed-boot first-stage mount/init execution still UNKNOWN**. Prior M4 PHH `mtkmal` source guard/marker and C3B TrebleApp/obsolete root cleanup source states PASS at original scope; no actual M4 init/property crash/reboot log. M4 final `plat_sepolicy.cil` and `plat_file_contexts` content hashes PASS as bounded members, but **vendor policy interoperability, merged effective SELinux, AVC and first-stage policy load not established**. IMS signer, exact API36 two boot JARs, R1/B1 current POST/POST, and R2 bounded native/A4 PASS all preserved; no causal inference of Rescue Party or missing ViLTE library from static membership.

**Hybrid-super counterfactual remains** `M4_HYBRID_SUPER_ANDROID_BOOT=UNKNOWN_NOT_TESTED`. Same M4 bytes and genuinely equivalent companions/LP/AVB would not repair proven image-intrinsic changes; a *different specifically matched* hybrid composition could in principle change an otherwise cross-partition failure but is not evidenced and is a distinct experiment. Full hybrid super as **offline byte/LP control only** remains accepted by archived build-engineer, not approved for assembly or physical writing. Seven Oct03 physical companion exact SHA/LP/AVB and Oct11 actual written super SHA/journal remain UNBOUND. Need already-recorded M4 Recovery/first-stage logs to identify mechanism; archived recovery logs reportedly unavailable; do not request device under this authorization. No repeated 991/M11/M4 image/skip_mount/A4/R2 tests.

```text
OFFLINE_BOOT_CRITICAL_DELTA_REVIEW=COMPLETE_RETAINED_EVIDENCE
COMPARISON_MATRIX=PASS_10_ROWS_CLAIM_SCOPED
M4_SKIPMOUNT_MISSING=REJECTED_BY_PRIOR_STATIC_BYTES
M4_FIRST_STAGE_MOUNT_EFFECTIVE=NOT_EVIDENCED
M4_COMPILED_POLICY_FILES=PASS_EXISTING_M4_MEMBER_CHECK
M4_EFFECTIVE_SELINUX=NOT_EVIDENCED
M4_PHYSICAL_BOOT=FAIL_RECOVERY_NO_ROOT_CAUSE
M4_AS_HYBRID_SUPER_BOOT=UNKNOWN_NOT_TESTED
OCT11_ACTUAL_SUPER_JOURNAL=UNBOUND
OCT03_MATCHED_COMPANIONS_LP_AVB=UNBOUND
SOURCE_MUTATION=NO BUILD=NO LPDUMP=NO LPMAKE=NO IMAGE_READ=NO DEVICE=NO FLASH=NO
```

### Further source-lineage forensic finding: Oct03 C3A apps overlay versus partial M4 C3B policy peel

A post-comparison review of the **actual original N1F build driver** and archived [M4 C3B two-block repair operator receipt](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497900692) reveals a specific nonduplicate boot-critical source delta. [Oct03 N1F source runner](https://github.com/aimindseye/sableos/blob/main/build/titan2/run-n1f-c3a-derived-c3b5-r2.sh) explicitly verifies exact **C3A 369-patch/991-project source**, then applies only **7 staged app files and one `rom.mk` inheritance**, reporting `N1F_R2_COMPATIBILITY_PATCH_DELTA=0`. **C3B5 means five Sable apps here, not automatic application of the separate Oct02 C3B hardening source**.

Isolated M4 source was reconstructed from C3A but an additional exact two-block TrebleApp/C3B repair removed **`SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/phh/treble/sepolicy`** and the old external overlay inheritance plus TrebleApp privilege XMLs. M4 operator **explicitly states remaining full C3B PHH transformations were not replayed**. The separate Oct02 C3B hardener removes additional PHH on-boot/data hooks, neverallow bypass and permissions, and **was not the source provenance of the Oct03 booted N1F just from its date/name**. Crucially M4 full-image build itself encountered `e2fsdroid` **unlabeled `/bt_firmware`** after policy removal; earlier Oct02 C3B had the same build-class failure and exact repair. M4 removed only two generated empty `bt_firmware`/`sec_storage` dirs, preserved `efs`/`persist`, and built/hashed a final image. This **build-time root-folder label-owner incompatibility is observed**; a runtime M4 AVC/SELinux cause of Recovery **is NOT observed**. No evidence the M4 `phh-on-boot.sh` installed runtime hook matched the fully hardened C3B omission; the partial two-block repair does not establish either hook execution or removal. The original October 3 archived C3A manifest/head ledger and saved `rom.mk` do not independently pin the contemporaneous `device/phh/treble/base.mk` byte hash, so the exact Oct03-vs-M4 **merged** policy diff remains unbound. [Detailed three-lane PHH policy source lineage](N1F_P342_C3A_C3B_M4_PHH_SEPOLICY_PROVENANCE_V1_20261013.md).

**Prioritize a single exact retained PHH policy-owner/boot-hook source comparison if and only if a genuinely frozen Oct03 base.mk leaf and its SHA are identified.** Do not use present mutable original checkout as a purported Oct03 frozen copy; do not rerun C3B hardening, 991-head census, M4 build or root-folder correction. Existing boot-critical delta report and no-build/no-flash hold remain unchanged; this is sharper source-differential evidence, not a diagnosis or authority to inspect a new file.

```text
OCT03_N1F_SOURCE=EXACT_C3A_PLUS_7_FILES_AND_ONE_INHERIT
M4_PHH_POLICY_REMOVAL=PASS_PRIOR_TWO_BLOCK_MUTATION
M4_POST_POLICY_E2FSDROID_BT_FIRMWARE_FAILURE=CONFIRMED_BUILD_ONLY_THEN_FIXED
OCT03_EFFECTIVE_PHH_POLICY_LEAF_SHA=UNBOUND
M4_EFFECTIVE_MERGED_POLICY_AND_PHH_BOOT_HOOK=NOT_EVIDENCED
M4_ANDROID_RECOVERY_ROOT_CAUSE=NOT_PROVEN
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

### Recovered C3A exact PHH base Git blob: next one-file provenance gate

The existing C3A preparation [`prepare-n1d-c3-trebledroid.sh`](https://github.com/aimindseye/sableos/blob/main/build/titan2/prepare-n1d-c3-trebledroid.sh) verifies generated PHH project dirty scope permits **`AndroidProducts.mk`, `rom.mk`, `treble_*.mk` only** — not `base.mk`. Main `n1d-c3-trebledroid.env` pins the PHH project to `39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed`; full C3B hardener separately asserts **that commit's `HEAD:base.mk` Git blob `a29e402009d449150f1216e5d517ec0c9b36bfbd`**. Original Oct03 N1F runner archives **`/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z/dirty-project-state.txt` before its seven-file + one-rom delta**, but its final gate checks only dirty project names (not every changed filename). This existing small exact archived text is the smallest remaining necessary provenance evidence to verify no later PHH `base.mk` mutation at Oct03 archive time, before confidently equating the Git HEAD `base.mk` with the Oct03 actual build-source leaf. The file is **PRESENT_PRIOR_METADATA**, its **contents NOT_READ** under this GitHub-only comparison. No file-byte hash or SELinux policy parity inferred. [Three-lane C3A/C3B/M4 PHH comparison and baseline pins](N1F_P342_C3A_C3B_M4_PHH_SEPOLICY_PROVENANCE_V1_20261013.md).

M4 source partial C3B private-policy removal remains a concrete build-time delta; `/bt_firmware` label error and exact scaffold cleanup are already historically evidenced and need no rerun. M4 merged SELinux execution and PHH guard activation in failed boot remain UNPROVEN. Any separate exact one-file text read should be confined to that archived C3A dirty-state leaf, symlink/size-safe, and never expanded into a 991-project rescan, full Android source diff, image extraction, policy build, device or flash.

### Oct03 archived PHH status and final M4 installed hook/platform policy comparison prepared

Operator explicitly requested to confirm original Oct03 PHH source state and determine whether M4 final build changed installed PHH boot-hook or static SELinux members. GitHub history pins Oct03 C3A PHH HEAD 39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed and HEAD:base.mk blob a29e402009d449150f1216e5d517ec0c9b36bfbd. Original Oct03 archive has SHA256SUMS-sealed dirty-project-state.txt and captures original source BEFORE product's seven-file+one-rom inheritance. Contents of that one existing text leaf still **NOT READ**; a clean result is needed to bind HEAD:base.mk to the final archived source state.

Prepared [exact no-write host verifier plan](N1F_P342_OCT03_M4_PHH_POLICY_EXACT_HOST_CHECK_V1_20261013.md), separate distribution ZIP N1F_P342_PHH_POLICY_EXACT_V1.zip SHA256 c923fe6b92fedafd0a302590dea28f052390988d4aa316b2ad3170c56330f358. Default plan zero file I/O; authorized inspect opens exactly archival SHA256SUMS.txt and dirty-project-state.txt, plus the Oct03/M4 previously pinned raw ext4 image paths with exact byte-size guard. Via prior qualified ai-g732 /usr/sbin/debugfs, read-only and fd-bound, probes only three member names in each: /system/bin/phh-on-boot.sh, /system/etc/selinux/plat_sepolicy.cil and /system/etc/selinux/plat_file_contexts; fixed 512KiB/8MiB/512KiB limits, outputs only SHA/membership, and enforces prior M4 CIL/context SHA pins. Whole-image multi-gigabyte SHA NOT repeated, no mount, no source edit, build, network, device or flash.

QA assistant-local: ZIP/in-manifest 4/4 PASS, Python AST PASS, README Bash syntax PASS, **30/30 synthetic tests PASS**, fixture parser 4000 runs median/p95 0.00442/0.00463 ms (not debugfs real-file performance). The assistant environment does NOT have /usr/sbin/debugfs, so **actual on-host image member reads NOT executed yet** and host integration requires an operator receipt. Relative /srv path aliases/symlink fallbacks forbidden.

**Scope of eventual result:** show archived PHH base.mk dirty state, actual installed script presence/static byte hashes and whether platform CIL/file_contexts differ. This can **never** by itself establish whether PHH script executed at boot, vendor/odm merged SELinux succeeded or an AVC caused M4 Recovery. Frozen R1/B1, A4/R2 and historic whole-image hashes are prior PASS and must not be rerun.

```text
OCT03_DIRTY_SOURCE_RECEIPT=NOT_EXECUTED_NEW_TOOL
M4_INSTALLED_PHH_HOOK_AND_POLICY=NOT_EXECUTED_NEW_TOOL
EXACT_READONLY_TOOL_QA=PASS_30_TESTS
M4_RUNTIME_FIRST_STAGE_AND_MERGED_SELINUX=NOT_PROVEN
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

### Actual Oct03/M4 PHH exact-image probe refused on host ancestor, prior 30 tests PASS

Operator ai-g732 actual frozen V1: outer checksum PASS, four inner checks PASS, **30/30 synthetic regression PASS (0.002s)**, plan mode PASS; actual inspect returned `REFUSED_NO_PARTIAL_EVIDENCE`, `[Errno 20] Not a directory: 'titan2'`. The code first opens the **exact Oct03 historical archive manifest** `/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z/SHA256SUMS.txt` through per-component `O_DIRECTORY|O_NOFOLLOW`; at its `titan2` ancestor it encounters a non-directory or a symlink (Linux `ENOTDIR` for symlink/no-follow). **It did not reach manifest/dirty file content, Oct03 or M4 system.img, or /usr/sbin/debugfs**. Source read=0, image read=0, no proof about PHH or SELinux members. SSH exit followed `set -e` on intentional refusal, no host failure evidence.

Fail closed: do not weaken symlink/dir restrictions or auto-promote `/srv/data/sable-build` alias. [Detailed result and metadata-only next check](N1F_P342_OCT03_M4_PHH_POLICY_EXACT_HOST_CHECK_V1_20261013.md). Prepared non-content metadata helper `N1F_P342_OCT03_PATH_METADATA_V1.py` SHA256 `bff8cb5f26c25a49a9f409eb36ce3ed387a62799d6c8bcd2ce88f0d45fc9c8a4` walks **only literal ancestor components of the already-pinned Oct03 manifest** using os.lstat, stops at first symlink/non-directory and reports link text with os.readlink (does **not** resolve or follow). Assistant Python syntax PASS; 4/4 synthetic path conditions PASS, 1000 synthetic symlink fixture iterations median 0.0099ms/p95 0.0109ms (not ai-g732). **No new evidence bytes have been read** and no exact canonical replacement root has yet been approved.

```text
PHH_STATIC_COMPARISON_PACKAGE_AND_TESTS=PASS_OPERATOR_30_OF_30
PHH_REAL_IMAGE_AND_ARCHIVE_INSPECTION=REFUSED_ON_ANCESTOR_ENOTDIR
PHH_HOST_PATH_CANONICAL_AUTHORITY=UNBOUND
OCT03_ARCHIVED_BASE_MK_DIRTY_STATE=NOT_READ
M4_INSTALLED_PHH_AND_SELINUX_POLICY_DELTA=NOT_READ
BUILD=NO SOURCE_MUTATION=NO DEVICE=NO FLASH=NO
```

### Operator confirms legacy Oct03 artifact symlink; exact physical-path PHH V1.1 prepared

**Actual checksum-pinned operator metadata** identifies the first V1 ENOTDIR component as **SYMLINK** `/srv/sable-build/artifacts/titan2 -> /srv/data/sable-build/titan2/artifacts`. Its three ancestors `/srv`, `/srv/sable-build`, `/srv/sable-build/artifacts` are regular directories at the observation. This **explains V1's fail-closed refusal**, not a missing archive or SELinux failure; no evidence bytes were read. Do not use alternate similar `/srv/data/sable-build/artifacts/titan2` root or `realpath` to silently change source identity.

**New frozen V1.1** reuses V1's three ext4 member paths, image byte-size pins, archived SHA-bound dirty receipt parser, historical M4 platform CIL/context hashes and nofollow read-only behavior. It first rechecks exact operator-observed legacy symlink text through nofollow dirfds, then changes ONLY the Oct03 archive and Oct03 image paths to **literal physical** `/srv/data/sable-build/titan2/artifacts/{c3a-boot-qualified,n1f-c3a-derived-c3b5}/...`, still rejecting all symlinks along actual physical paths. M4 path unchanged. [Exact V1.1 archive alias contract and tested handoff](N1F_P342_OCT03_PHH_ALIAS_PHYSICAL_V11_20261013.md). Outer ZIP `N1F_P342_PHH_POLICY_ALIAS_V1_1.zip` SHA256 `ae2763fe15895a0ed2d29b691d5cd845b7d4fe8020de3dcbf8677c019cf78a7f`; ZIP/inner 4/4 SHA PASS, source/test AST PASS, README `bash -n` PASS, **44/44 synthetic tests PASS** including full synthetic two-image comparison and negative SHA gate, default plan no evidence I/O. 1500 synthetic symlink metadata probes median 0.00593ms/p95 0.00672ms assistant-host only. **Real ai-g732 V1.1 archive/image/debugfs not yet executed**, no PHH or SELinux result admitted. Read-only exact scope unchanged, no build/device/flash.

```text
OCT03_LEGACY_ARTIFACT_ALIAS=CONFIRMED_LITERAL_SYMLINK
OCT03_LEGACY_ARTIFACT_TARGET=/srv/data/sable-build/titan2/artifacts
PHH_V1_REAL_INSPECT=REFUSED_EXPECTED_NOFOLLOW
PHH_V11_PACKAGE_QA=PASS_44_OF_44
PHH_V11_HOST_READ=NOT_YET_EXECUTED
OCT03_ARCHIVED_BASE_MK=NOT_CLASSIFIED
OCT03_M4_INSTALLED_PHH_POLICY=NOT_COMPARED
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

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
OCT03_PARENT=SELECTED_OFFLINE_PLANNING_ONLY
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
