# PR #342 — forensic C3A/C3B/M4 PHH policy and boot-hook lineage V1

Date: 2026-10-13. **Existing GitHub code and actual PR #339 / #342 operator receipts only; no host source/image/policy access**. Operator requested continued investigation after the completed offline boot-critical comparison. This document isolates a **specific previously under-articulated compatibility change** and distinguishes three source-lineage concepts that have been confused by the `C3B` label. Does **not** claim it caused M4 Recovery or authorize mutation, build, repack, device or flash.

## Three distinct source paths — confirmed, not interchangeable

### A. October 3 physically booted N1F = original C3A build source + Sable *apps-only* overlay

[Existing exact N1F build/flash driver](https://github.com/aimindseye/sableos/blob/main/build/titan2/run-n1f-c3a-derived-c3b5-r2.sh) lines 41–51 selects `ANDROID_ROOT=$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL` (previous actual Oct03 workspace `/srv/data/sable-build/workspaces/titan2-n1d/android`), `OUT_C3A=.../out-c3a-td`, `ROM_MK=.../device/phh/treble/rom.mk`. Lines 76–125 require exact prior **C3A** 991-project `postpatch-project-heads.tsv` and bounded dirty-set `build/soong`, `device/phh/treble`, `treble_app`. Lines 135–161 independently bind historical **C3A** base image SHA and 369 patch control. Lines 259–293 add exactly **7** staged files (Android.bp, apps mk, five prebuilt APKs) plus exactly **one** `rom.mk` product inheritance and record `N1F_R2_COMPATIBILITY_PATCH_DELTA=0`; no `base.mk`/PHH policy source edit in this N1F driver. Lines 295–363 build using that Android source and bounded `systemimage` operation; later system_a flash and Android boot PASS.

**Strong conclusion:** Oct03 success belongs to the C3A-derived GSI runtime plus apps-only integration, **not automatic evidence that any separate fully hardened C3B E1 source was the source of the Oct03 booted image**. `C3B5` refers here to the five apps, not blanket import of all C3B hardening steps. Exact original Oct03 *effective* PHH `base.mk` bytes are **not bound in this comparison** (the C3A archive recorded `rom.mk`, manifest and project heads, but the driver did not independently hash the contemporaneous PHH `base.mk` leaf). No assumption about Oct03 compiled merged SELinux equality.

### B. Separate 2026-10-02 N1D C3B E1 engineering source is an unbooted comparison, not Oct03 source proof

Current [`build/titan2/apply-n1d-c3b-phh-base-hardening.py`](https://github.com/aimindseye/sableos/blob/main/build/titan2/apply-n1d-c3b-phh-base-hardening.py) is a **broader** expected pre-Git blob `a29e402...` → post `58edfb...` security transform. Its independent source transformation list removes:
- `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/phh/treble/sepolicy`, PHH overlay and `vendor/hardware_overlay/overlay.mk` inheritance;
- generic `phh-on-boot.sh`, `phh-on-data.sh`, `rw-system.sh`, `phh-prop-handler.sh` from product copy files;
- permissive neverallow-bypass, unsafe ADB settings, PHH/TrebleApp privileges and other generic boot helpers.

The [N1D C3B compatibility peel R2](https://github.com/aimindseye/sableos/blob/main/docs/titan2/N1D_C3B_COMPATIBILITY_PEEL_R2.md) documents an Oct02 **different** C3B engineering source/image `system.img` SHA `9ce0144220b3a5bf531a1b0da7ec97543a89c9181ab9d69b6390ea5a86ad45dd` and `N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO`. After PHH private sepolicy removal it hit unlabeled `/bt_firmware` root-folder packaging and required a narrow `BOARD_ROOT_EXTRA_FOLDERS` change from four entries to `efs persist`. This original Oct02 source build is **not** Oct03 physically booted N1F parent nor M4 current source.

### C. October 12–13 M4 = reconstructed C3A sources + **partial** C3B repair, not entire hardened C3B

Archived [PR #339 exact TrebleApp owner](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497883380) confirmed the selected M4 `device/phh/treble/base.mk` still inherited `vendor/hardware_overlay/overlay.mk` and copied TrebleApp permissions; the overlay Make owner required missing `treble_app/TrebleApp.apk`, causing the earlier Ninja failure.

The [exact M4 C3B repair operator PASS](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497900692) at isolated root `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android` removed **only two selected blocks**, yielding `base.mk` SHA256 `9e197a490a61a5721b8bb881e93acbc451104957a9599895bc724cfb5768820b`, Git blob `207c770034aa76c9cee873ecd0e4e184d4a3c014`. This removed the legacy PHH private policy declaration/external hardware-overlay inheritance block and TrebleApp privilege XML copy rules. **The operator explicitly states all other PHH hardening transforms were NOT asserted or replayed.** Thus *M4 partial C3B policy removal* must NOT be treated as equivalence to all C3B E1 changes; in particular the *PHH on-boot script inclusion/execution* is unqualified (the full hardening script would drop its product-copy line, but M4 selected two-block repair is not proof it did). Its separate Titan `mtkmal` guard and marker source passed bounded checks; successful guard execution during boot remains unknown.

**Concrete policy→packaging chain, observed before completed image:**
1. M4 full-image operator [failed at `e2fsdroid` root label lookup for `/bt_firmware`](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502058005) after 176411/177240 actions. This is real **image construction SELinux-label owner coverage**, not a *runtime* SELinux denial.
2. The same pre-existing [Oct02 C3B E1 fix](https://github.com/aimindseye/sableos/blob/main/docs/titan2/N1D_C3B_COMPATIBILITY_PEEL_R2.md) already explained the policy removal/root-folder mismatch; the operator reused the narrow board-base repair to keep `/efs` and `/persist`.
3. M4 [removed only two stale empty generated root directories](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502194257). Subsequent [postbuild M4 system.img SHA](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502246106) and [final M4 policy members](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502598278) PASS. Neither shows Oct03-vs-M4 merged policy equivalence or an M4 AVC/first-stage service failure.
4. M4 later reached stock Recovery after exact 12/12 system_a writes; no failure log binds Recovery to the PHH/private-policy edit, init hook, AVB or other mechanism.

## New forensic classification — what changed our priorities

| Claim | Conclusion |
|---|---|
| Oct03 C3B5 boot proves full C3B hardening boot-safe | **REJECTED_SOURCE_LINEAGE_CONFUSION**: Oct03 runner explicitly uses C3A stage and +7 files/+1 inheritance, compatibility delta 0 |
| M4 PHH private policy wiring removed in partial C3B repair | **PASS_PRIOR_SOURCE_MUTATION** per exact operator repair; this is a *real difference in build-source policy inputs from the C3A-style baseline* |
| Original Oct03 PHH `base.mk` exact private-policy line/merged policy bytes known from this record | **NO**: original archived C3A heads/dirty set and `rom.mk` do not provide an exact self-contained PHH `base.mk` leaf SHA |
| Build-time `/bt_firmware` label failure triggered by stale root folders after policy change | **PASS_PRIOR_OPERATOR_BUILD_FAILURE**; targeted repair then image-build success, no policy runtime inference |
| M4 full PHH hardening boot-script hooks removed | **NOT_PROVEN**: M4 repair explicitly only two blocks; a unique exact current installed `phh-on-boot.sh` + corresponding init service would need separate bounded evidence |
| M4 compiled `plat_sepolicy.cil`/contexts member hash vs effective merged vendor/odm policy | **PASS_STATIC_MEMBERS, UNKNOWN_EFFECTIVE_MERGE** |
| PHH policy/mtkmal differences caused M4 Recovery | **UNPROVEN_CAUSE**; retained Recovery log absent |
| M4 packaged as identical hybrid super would boot | **UNKNOWN_NOT_TESTED**, no new LP/AVB baseline |

**Recommended next strictly bounded evidence request (NOT auto-authorized/executed):** use already retained **one** exact archived Oct03 C3A `base.mk` if independently named and SHA-pinned, and **one** final M4 selected `base.mk` at its known root, plus *exact pre-existing final image's policy owner/boot-hook receipts* if identified, to classify the two full PHH policy/boot-hook scopes. Do NOT perform wildcard `find`, re-list 991 projects, rehash 3GB image, regenerate merged policy, run `secilc`, source/OUT rebuild, device, AVB, super repack or flash. If no exact original Oct03 PHH base leaf is retained, record **UNBOUND** rather than comparing a current mutable original checkout and falsely labeling it as the frozen Oct03 build.

The preceding ten-row [offline boot-delta analysis](N1F_P342_OFFLINE_BOOT_CRITICAL_DELTA_V1_20261013.md) remains valid, but must incorporate this **source lineage clarification**, because the same label “C3B hardening” could otherwise hide a substantive policy-owner delta.

```text
OCT03_PARENT_SOURCE_FLAVOR=C3A_369_PATCH_PLUS_7_FILES_1_ROM_INHERIT
OCT03_C3B_HARDENING_AS_PARENT_PROVEN=NO
OCT02_SEPARATE_C3B_HARDENED_IMAGE=PASS_BUILD_ONLY_NOT_PHYSICAL_BOOT
M4_PARTIAL_C3B_REMOVAL=PASS_EXACT_TWO_BLOCKS
M4_PRIVATE_PHH_POLICY_DECLARATION_REMOVED=PASS_SOURCE_PRIOR
M4_FULL_C3B_BASE_TRANSFORM=NOT_REPLAYED
M4_POST_REPAIR_E2FSDROID_BUILD_LABEL_FAILURE=HISTORIC_FAIL_THEN_REPAIRED
M4_FULL_SYSTEMIMAGE_BUILT=PASS_PRIOR
M4_PHYSICAL_BOOT=FAIL_RECOVERY_CAUSE_UNBOUND
EFFECTIVE_SELINUX_RUNTIME=NOT_EVIDENCED
HISTORICAL_OCT03_PHH_BASE_LEAF=UNBOUND_BYTES_IN_REVIEWED_RECORD
SOURCE_MUTATION=NO BUILD=NO HOST_CONTENT_READ=NO DEVICE=NO FLASH=NO
```

## Additional exact C3A PHH baseline commit/blob pin — newly recovered

The prior paragraph saying the frozen **October 3 actual `base.mk` leaf** remains unbound is still correct; however the **original C3A baseline blob/commit is now identified** more strongly than a generic unknown:

- Main `build/titan2/n1d-c3-trebledroid.env` pins `N1D_C3_TD_DEVICE_PHH_COMMIT=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed`.
- Main [C3A source preparation](https://github.com/aimindseye/sableos/blob/main/build/titan2/prepare-n1d-c3-trebledroid.sh) requires that same exact scaffold commit, and `verify_td_generated_dirty_scope` permits PHH project dirty paths **only** `AndroidProducts.mk`, `rom.mk` and `treble_*.mk`. A modified `base.mk` at the end of that particular qualified preparation would fail its gate.
- The separate [full C3B hardening tool](https://github.com/aimindseye/sableos/blob/main/build/titan2/apply-n1d-c3b-phh-base-hardening.py) explicitly pins **the same commit** as `EXPECTED_HEAD=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed` and its Git `HEAD:base.mk` to **`EXPECTED_BASE_BLOB=a29e402009d449150f1216e5d517ec0c9b36bfbd`**, a Git blob identity (not raw-file SHA256). It describes the exact original PHH private-policy/overlay block to remove, and separately the PHH boot-hook copy rules.
- Oct03 N1F runner itself checks the archived 991-project C3A heads and dirty-project **names**, but it **does not re-check every dirty *filename*** or the `base.mk` content hash during the final Oct03 N1F build. Thus the pinned C3A `HEAD:base.mk` **strongly identifies the source baseline** but is **not independent final Oct03 working-file byte proof**.
- The existing named archive is `/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z/dirty-project-state.txt`, whose presence was previously verified (not read in this follow-up). Reviewing this **one exact, size-capped historical text receipt** would distinguish whether `device/phh/treble/base.mk` was dirty at archive time; a clean status plus pinned project HEAD would support an original source-file identity. Dirty-state absence is a file-state claim, **not evidence of effective merged SELinux runtime behavior**. Its contents are **NOT YET EXAMINED**; no new host read is performed or implied.

**Updated precise classifications**:

```text
C3A_DEVICE_PHH_PINNED_PROJECT_HEAD=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed
C3A_HEAD_BASE_MK_GIT_BLOB=a29e402009d449150f1216e5d517ec0c9b36bfbd
C3A_STAGE_GENERATED_DIRTY_ALLOWLIST=EXCLUDES_BASE_MK
OCT03_FINAL_BASE_MK_FILE_BYTES=NOT_REBOUND_FROM_ARCHIVED_DIRTY_RECEIPT
M4_SELECTED_BASE_MK_POST_SHA256=9e197a490a61a5721b8bb881e93acbc451104957a9599895bc724cfb5768820b
M4_PHYSICAL_BOOT_RECOVERY_CAUSE=STILL_UNBOUND
NEW_HOST_FILE_READ=NO
```
