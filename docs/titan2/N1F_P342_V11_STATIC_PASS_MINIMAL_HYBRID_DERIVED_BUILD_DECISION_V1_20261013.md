# PR #342 — actual PHH V1.1 PASS and decision: minimal Oct03-derived host image, not blind M4 hybrid super

Date 2026-10-13. **Evidence review and planning only. No new source mutations, Android build, image repack, device contact or flash performed.**

## Actual ai-g732 Oct03 vs M4 result accepted

User performed SHA-verified N1F_P342_PHH_POLICY_ALIAS_V1_1.zip, inner SHA 4/4 PASS, 44/44 tests PASS (0.005 seconds), plan with no reads PASS, and authorized inspect returned **PASS_STATIC_OCT03_M4_EXACT_MEMBERS_NOT_RUNTIME_POLICY**. Archive manifest SHA PASS. The nofollow legacy artifact symlink was verified as /srv/sable-build/artifacts/titan2 pointing EXACTLY to /srv/data/sable-build/titan2/artifacts; content was read only from the physical target. The sealed Oct03 dirty-state receipt contains PHH section with one dirty entry **and base.mk_dirty=false**. Coupled to original C3A PHH project HEAD 39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed, this supports HEAD:base.mk Git blob a29e402009d449150f1216e5d517ec0c9b36bfbd as the archived original source state. It does not certify a live current checkout.

Image-effective selected static comparison:

| Exact ext4 member | Oct03 bytes/SHA | M4 bytes/SHA | Result |
| --- | --- | --- | --- |
| /system/bin/phh-on-boot.sh | 8326; 18f4425e38510690fb06fbe9a95cfdc2239541c4f997297880026335402fc63f | 8387; ab3369f6b06b751ecd59d43368daef0057470674cc233c0d468a84b7d465386e | **CONTENT_CHANGED** |
| /system/etc/selinux/plat_sepolicy.cil | 3148067; a7805083d63a0fda11ce7943c0c4ee90954c44971d7b85897504d64421eab758 | same | **SAME_CONTENT** |
| /system/etc/selinux/plat_file_contexts | 48918; ac2ba2392c7bcdb9e75f6add88841b4d216159c6ede0e673f881aaf6b4737ff9 | same | **SAME_CONTENT** |

**Guard attribution now unusually strong**: archived [PR339 actual exact PHH guard preview](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497568321) recorded source pre SHA 18f4425e... and Titan NOT-marker guard exact post SHA ab3369f6...; [operator applied guard and marker](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497610584) confirmed precisely that POST source SHA and marker source SHA 13ea9199448fb91a85b6fb5806090c6bb7a1201dfb93ae5342c8aa0488551d2f. Those two SHA values now independently match Oct03/M4 **installed** script bytes. This establishes the selected boot script change corresponds to the already-qualified guard intervention (the generic mtkmal branch otherwise disables IMS and ePDG properties and reboots). A script's presence/hash and marker member presence do **not** prove runtime invocation, first-stage import timing, marker visibility or cause of M4 Recovery.

**Important policy refinement**: previous M4 two-block source removal of PHH private-policy and overlay wiring did NOT produce a byte difference in these two specific final **platform** CIL and file-contexts members. It does NOT prove no difference in system_ext/vendor/odm policy components, complete merged device policy, privileged IMS process policy, init/AVC or Recovery. Do not call M4 SELinux entirely identical. Neither 3.2GB image SHA was rehashed; image binding is the operator's exact path/size and prior image seal.

## Answer to operator's proposal to add M4 changes to Oct11 hybrid and build

**Feasible in principle as a NEW SOURCE-BUILT, ISOLATED, HOST-ONLY candidate; not a direct copy of the complete failed M4 image into an unknown Oct11 super image.**

The Oct11 Atlas-derived hybrid Android runtime booted historically, but its **as-flashed super SHA/LP journal is still unbound** after bounded searches. It cannot safely be treated as a byte-identified modifiable binary parent. The user previously selected the **distinct, physically Android-booted Oct03 N1F** system image as an **OFFLINE PLANNING parent only** (historical SHA256 dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a). M4 complete system image SHA261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce had system_a flash transport PASS but **FAIL_RECOVERY**, so it is a data donor/comparison, not a known-good boot parent. Super repackaging alone has no demonstrated mechanism to fix image-internal boot faults.

### Narrow source integration plan and exclusion list

| Slice | Minimal new host candidate | Existing evidence / hold |
| --- | --- | --- |
| Source parent | Original C3A/Oct03 N1F with seven app staged files + one rom.mk inheritance | 991-project/369-patch C3A archive and Oct03 booting system SHA; select a NEW isolated checkout and unique OUT, do not overwrite original or failed M4 |
| R1 AndroidManifest.xml | One original PRE -> POST protected broadcast declaration | Oct03 V38 PRE; M4 POST exact SHA 2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca; apply only if exact original PRE with separate mutation authority |
| B1 TelephonyMetrics.java | One exact compatibility overload PRE -> POST | Oct03 PRE; M4 POST Git blob 9d5108e0ddb8d4960d21cda021813b53dbbf4da8; no duplicate patch |
| C1 IMS island | Reuse six exact product packages (ImsService APK, two JARs, three permission/config XMLs), 2 boot JARs, 2 configured overrides, rom.mk C1 inheritance | Already authored, M11 compiled and M4 11/11 content and BCP API36 PASS bounded. Bind installed final embedded /system/system_ext and SELinux/privapp/classpath for NEW candidate |
| PHH boot guard | Copy ONLY previously qualified exact guard/marker integration, resulting installed script SHA ab3369f6..., keep all unrelated C3A PHH rules intact | V1.1 proves archived Oct03 PRE 18f4425e... and M4 guard POST ab3369f6...; marker source SHA and final M4 image member prior PASS. Confirm effective marker timing remains separate G2 |
| PHH private sepolicy / legacy overlay removal | **DO NOT CARRY AS AN AUTOMATIC M4 IMPORT** | Oct03 booted base was clean; CIL/file-context members identical; M4 partial source removal caused historical e2fsdroid label-owner packaging issue. If unchanged base causes precise TrebleApp Ninja graph failure, fix exact source owner separately rather than broad hardening |
| PHH root board/staging | Preserve original root layout, no stale generated root folder copying | Historical M4 root /bt_firmware failure resolved only after source/staging surgery; never repeat broad clobber |
| GSI skip_mount | Preserve source SHA 0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e and embedded system_ext/product layout | Do not write standalone Android14 system_ext_a/product_a or assume stock bytes are effective |
| R2 five ViLTE native ELF | **HOLD** from initial build | Five SHA/56 direct deps/19 Bionic/four GNU/six provider checks PASS historical scope; full recursive GNU namespace G3 NOT EVIDENCED. New C1+no-R2 candidate is strictly NON-FLASHABLE |

### Build checkpoints; no execution under this documentation task

A0: select and seal one exact **isolated clean Oct03-derived Android16 source checkout** and unique fresh OUT path; verify exact old source and target SHA pins WITHOUT rescanning 991 rows or rehashing historical multi-GB images. If a clean isolated checkout already exists, reuse only if its manifest/heads and dirty provenance truly equal the archived C3A source. Neither original Oct03 output nor failed M4 output may be overwritten.

A1: exact R1/B1 + PHH Titan marker/guard source integration, independently gated and approved if mutation actually needed. No blind M4 filesystem or partial C3B policy copy.

A2: C1 source/package incorporation with exact product wiring; after separate **source mutation AND host-only build authorization**, run bounded incremental Android16 systemimage (historic isolated M4 host build used m systemimage -j4; this is a design reference, **not an executable command or host tool identity assurance**). Preserve compiled logs/evidence; pin new system.img SHA and relevant embedded members, bootclasspath, policy, skip_mount and actual C1 marker. This is a **host-only non-flashable** G1/G2 specimen.

A3: separately consider full IMS R2 once G3 recursive ABI/provider/APEX/privileged app namespace passes for the selected final process, and host-only hybrid super assembly only after verified LP/VAB geometry, exact seven companions, AVB/restore and independent authorizations. Physically writing whole super or system_a remains FORBIDDEN. Oct11 successful hybrid observation alone does NOT certify any new candidate boot.

### Why a direct M4 overlay on Oct11 binary is unsafe

The actual Oct11 super is not SHA-bound; separate GSI filesystem edits can change Android build outputs and classpath, permissions, SELinux/contexts, AVB, ext4/sparse image packing, mount/partition precedence and LP metadata. Simply substituting M4 system bytes reproduces the **same failed system payload**, not a supported isolate-the-delta build. Preserve stock companion/boot partitions and skip_mount semantics, and never imply a systemimage success is device-boot PASS.

**No additional executable was written or tested for this decision**, so there is no new syntax/performance benchmark or host build log. All completed V1.1, R1/B1, M4 M11/full-build, A4/R2 and flash regression scopes are reused without rerunning. No host connection is available in this chat to run Android build. Before proposing an actual compile, independently bind exact checkout, disk/OUT, tools and source/build permission and use a newly reviewed fail-closed host-only build gate. Existing original Oct03 runner includes flash modes and cannot be reused unchanged.

**Current status**: OCT03_BASE_MK_ARCHIVED=PASS_CLEAN; OCT03_M4_PLATFORM_CIL_AND_CONTEXTS=PASS_SAME_CONTENT; PHH_GUARD_INSTALLED_M4=PASS_EXACT_SHA; M4_ANDROID_BOOT=FAIL_RECOVERY_CAUSE_UNKNOWN; OCT11_ACTUAL_SUPER_IMAGE=UNBOUND; NEXT_HOST_IMAGE=DESIGN_ONLY_NOT_BUILT; R2_G3=NOT_EVIDENCED; SOURCE_MUTATION=NO BUILD=NO SUPER_REPACK=NO DEVICE=NO FLASH=NO.
