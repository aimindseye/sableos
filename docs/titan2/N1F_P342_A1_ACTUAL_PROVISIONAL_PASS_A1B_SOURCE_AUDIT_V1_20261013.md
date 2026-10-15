# PR #342 — actual A1 991-project provisional source PASS; A1B historical dirty-file and scaffold read-only audit V1

Date: 2026-10-13 operator host session. **A1 real operator source-only creation complete, not build ready. A1B package locally validated, NOT executed on ai-g732.** No source integration, host Android build, super, network, device or flash authorized as a consequence.

## Actual A1 ai-g732 results

Operator ran frozen `N1F_P342_A1_LOCAL_SOURCE_CREATOR_V1.zip` on ai-g732: outer ZIP SHA PASS, 6/6 inner integrity PASS, **36/36 regressions PASS in 0.187s**, plan no evidence IO. Actual read-only preflight checked **991/991 current donor Git revisions and exact three archived dirty project path/status sets**, resulting in `PASS_DONOR_CURRENT_REVISIONS_DIRTY_PATHS_ONLY_NOT_SOURCE_BUILD_READY`; destination still absent before creation. Authorized `create` repeated the donor check, locally cloned and checked out **991 projects** with progress 50..950, then separately verified all 991 new project revisions/statuses. Result:
```text
A1_CREATION_STATUS=PASS_PROVISIONAL_LOCAL_CLONE_NOT_OCT03_DIRTY_BYTE_PROVENANCE_NOT_BUILD_READY
NEW_ANDROID_ROOT=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android
PROJECTS=991
PINNED_HEADS_SHA256=10658753bbb947a848369b0c248fca824def491e03287012ef031910542908f4
DIRTY_PROJECTS=build/soong,device/phh/treble,treble_app
DIRTY_FILE_1=build/soong/ci_tests/ci_test_package_zip.go
DIRTY_FILE_1_SHA=66ac23858a2c619ca87bd991fdf163af10882f40923c9d5183824c17c12759e3
DIRTY_FILE_2=build/soong/dexpreopt/dexpreopt_gen/dexpreopt_gen.go
DIRTY_FILE_2_SHA=6ec897e575940956701a862274e3cfe08a7fe9dc71578543b70529d483d7b6e2
DIRTY_FILE_3=device/phh/treble/rom.mk
DIRTY_FILE_3_SHA=ab0ec737342d41d562816fce73e8694e35ce32e09db74c12ea115efa3619d592
DIRTY_FILE_4=treble_app/sdk/.knownPackages
DIRTY_FILE_4_SHA=8382e417241589dbc171d32954cc77c98a96d2ec7609bdcdf09594398d8b5966
SOURCE_DIRTY_PATHS_MATCH_OCT03_ARCHIVED=true
SOURCE_DIRTY_BYTES_MATCH_ORIGINAL_OCT03_ARCHIVE=false
LOCAL_ALTERNATES_DEPEND_ON_PRESERVED_DONOR_OBJECT_STORES=true
OUT_A1_CREATED=false
PRODUCT_SCAFFOLD_COMPLETE=false
A1_NO_BUILD_GUARD=PRESERVED_EXPECTED
BUILD=NO NETWORK=NO DEVICE=NO FLASH=NO
```
The actual 991-project operation was performed by the operator, **not by ChatGPT**. No clone throughput or disk utilization was measured. This closes **A1 provisional creation**, not historical dirty BYTE identity or Android build readiness. The permanent `.A1_INCOMPLETE_DO_NOT_BUILD` marker must not be removed on the basis of these results.

## Prior GitHub authority recovered, no redundant 991-project audit

The original [C3A TrebleDroid config](https://github.com/aimindseye/sableos/blob/main/build/titan2/n1d-c3-trebledroid.env) pins post-build Git blob SHA1 for exactly TWO C3A host layout patched files:
- `build/soong/ci_tests/ci_test_package_zip.go` **post Git blob `b9bc7009d822dd811c0338c5595d14f0617d1392`**, original A1 SHA256 above; the control source `patches/android-16-n1d-trebledroid/host-layout/0001-soong-ci-tests-skip-out-of-tree-host-paths.patch` is already authored.
- `build/soong/dexpreopt/dexpreopt_gen/dexpreopt_gen.go` **post Git blob `7024841edac715a9bd3a81af92c42da0b302e1f0`**, original A1 SHA256 above; exact `0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch` previously pinned.
The original [October 3 N1F runner](https://github.com/aimindseye/sableos/blob/main/build/titan2/run-n1f-c3a-derived-c3b5-r2.sh) copied **original** `device/phh/treble/rom.mk` to Oct03 sealed `device-phh-treble-rom.mk` *before* any seven-app source integration, with manifest SHA256SUMS. Historical M4 pilot pins C3A `rom.mk` SHA256 `ab0ec737342d41d562816fce73e8694e35ce32e09db74c12ea115efa3619d592`.
The [C3A source stage](https://github.com/aimindseye/sableos/blob/main/build/titan2/prepare-n1d-c3-trebledroid.sh) accepts **modified** `treble_app/sdk/.knownPackages` as managed JDK build residue and pins its **BASE HEAD blob `7b27183be84845e00318dbbd3aeb60b5d291216b`**, but the accessible original source configuration does **NOT** pin the post-run October 3 *bytes* of that file. Do not misstate original knownPackages post SHA as proven by A1's same-donor receipt.

## New A1B strictly read-only source byte + scaffold inspection

Distribution **`N1F_P342_A1B_SOURCE_AUDIT_V1.zip`**, SHA256 **`987a51c7b20d4d16775ac03142cc47992558b09caaddd4db5dfb81d3b5cf5b85`**, 11,860 bytes; main script `n1f_p342_a1b_source_audit_v1.py` SHA256 `5c7de96b12234669f6f1b75cdaf4c10921c6110a3bafedaab4ef74f5a286afbd`, tests `test_n1f_p342_a1b_source_audit_v1.py` SHA256 `aab090675a6c1a3f4c985e03c1db83d53fd3b0daf1d20238a2aa6b5d008ad0c8`. Contains README/plan/engineering review/five-entry SHA256SUMS. ZIP CRC PASS, all 5 internal checksum entries PASS, Python AST+compile 2/2 PASS, README Bash syntax PASS, **44/44 synthetic tests PASS (0.072s)**. Local 600 synthetic fixture inspections median/p95 **0.34670 / 0.56264 ms** with peak 99,336 KiB RSS; not actual ai-g732 filesystem or Android compile timing.

A1B `plan` accesses **zero host evidence**. Explicit `inspect --authorize-a1b-readonly` uses dirfd `O_NOFOLLOW` at all ancestor+leaf components, exact bounded read-only files:
1. The FOUR new A1 dirty files only, check SHA against A1 receipt and exact observed new SHA; separately compute SHA1 Git blobs for TWO Soong post sources and compare original C3A profile pins.
2. Original Oct03 archive `device-phh-treble-rom.mk` exact regular bytes (<=128KiB) and its physical archive SHA256SUMS (<=512KiB). Require unique member SHA equals actual archive bytes, known independent historical SHA and A1 new rom bytes.
3. The original A1 JSON receipt (<=64KiB), persistent no-build marker (<=4KiB), no `.repo`, no `out-a1`. Exact six Android16 build-entrypoint types *metadata only*: `build/envsetup.sh`, `build/soong/soong_ui.bash`, `build/make/core/main.mk`, `build/make/target/product/gsi/Android.bp`, `build/make/target/product/gsi/gsi_skip_mount.cfg`, `device/phh/treble/generate.sh`.

No Git/Repo/Java/Ninja subprocess, no entire 991 HEAD scan, no build, network, directory enumeration, output writes, image file access, device or flash. Hard STOP on symlink, FIFO, wrong cap, unexpected scaffold path, receipt/membership/hash/blob mismatch or missing no-build marker. A1B positive maximum classification **`PASS_A1B_THREE_OF_FOUR_DIRTY_FILE_AUTHORITIES_FOURTH_UNBOUND_NOT_BUILD_READY`**, requiring exact original C3A Soong post blob and Oct03 original rom bytes. This is NOT yet observed on ai-g732. Even on PASS: `treble_app/sdk/.knownPackages` remains **HOLD original Oct03 post-byte authority**, plus unresolved original 369-patch replay attestation, `.repo` + Soong/product graph functionality, retained git-object alternates and future C1/C2/CW1/IMS integration and native G3. The `.A1_INCOMPLETE_DO_NOT_BUILD` must remain intact; no app/native changes, build or LP/AVB deployment authorized.

```text
A1_AI_G732_CREATED_991=PASS_PROVISIONAL_SOURCE_ONLY
A1_FOUR_DIRTY_FILE_SHA_FROM_DONOR=CAPTURED
A1B_AST_BASH_ZIP_SHA_AND_44_TESTS=PASS_ASSISTANT_FIXTURE
A1B_AI_G732_SOURCE_BYTES_SCAFFOLD_CHECK=NOT_EXECUTED
A1B_EXPECTED_BEST=THREE_OF_FOUR_HISTORIC_AUTHORITY_NOT_BUILD_READY
A1_TREBLE_APP_ORIGINAL_POST_SHA=NOT_BOUND
A1_NEW_OUT=NOT_CREATED
BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```
