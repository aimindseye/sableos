# PR342 — Actual A1I host HOLD; bounded A1J PHH guard source reuse V1

Date: 2026-10-13 (operator Eastern time). Docs-only engineering checkpoint. Host-only image build is authorized by operator, not yet technically admitted or executed. No device/flash/super permission.

## Actual ai-g732 A1I result

Outer ZIP SHA + 9/9 inner checksums PASS; 92/92 regressions PASS in 0.020s. Printed `REFUSED_EXACT_READONLY_FLAG_REQUIRED` is an expected negative test. Zero host I/O plan PASS. Actual inspected status `HOLD_A1I_OPEN_C1_SOURCE_AND_PAYLOAD_GATES_NOT_BUILD_READY` with no write/build/device/flash.

Already qualified: exact 11 Oct03 manifest checkout artifacts (A1F), selected R1/B1 both POST_EXACT (A1H), original rom.mk SHA256 `ab0ec737342d41d562816fce73e8694e35ce32e09db74c12ea115efa3619d592`, source GSI skip_mount SHA256 `0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e`, 7 C1/C3B canonical template Git blobs, six OEM IMS module owners, five C3B modules, two boot JARs, two JAR-location overrides, three C1 XML target names, zero native imports admitted. Original TEE14 stock system/system_ext images are REGULAR metadata only, not read or extracted.

Open blockers: selected A1 `device/phh/treble/phh-on-boot.sh` SHA256 `18f4425e38510690fb06b9a95cfdc2239541c4f997297880026335402fc63f` still includes generic MediaTek IMS/ePDG disable branch but not Titan marker guard; C1 and C3B stages absent as expected; APK/two JARs/three XMLs and five app APKs not staged; no `.repo` or evaluated product graph; independent 991 Git object closure unbound. `.A1_INCOMPLETE_DO_NOT_BUILD` preserved, `out-a1` ABSENT.

## Historical PR339 source-only precedent

Historic isolated M4 exactly the same PHH PRE hash, and reviewed guard POST SHA256 `ab3369f6b06b751ecd59d43368daef0057470674cc233c0d468a84b7d465386e`. Historic C1 marker/product source hashes `13ea9199448fb91a85b6fb5806090c6bb7a1201dfb93ae5342c8aa0488551d2f` and `fb0d801edd470d13d68f4105586f8f18ac30c1255dd7fd1076bf02157c017c5e` are original M4 source-only evidence, not proof current A1 marker installed. M4 physical image entered Recovery. Never transplant its image or call the PHH guard boot-certified.

## A1J exact PHH source-reuse external package

`N1F_P342_A1J_PHH_GUARD_SOURCE_REUSE_V1.zip` SHA256 `b2fef9d00a5eefd6efb09b4e5cbbfad4f7a993805139ea493647205e2e0e1d35`, 21061 bytes. Main Python SHA256 `31334915f0f8994c633370d44a48507431a5b8dab0943693de92b592a9bdcf55`; original unchanged A1D helper SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`. ZIP CRC PASS, 9/9 internal SHA PASS, Python AST/bytecode 4/4, Bash syntax PASS; 88/88 synthetic tests (48 inherited +40 new) PASS both umask 077/022 and fresh extracted ZIP. 400 synthetic tiny diff scans median 0.0727ms, p95 0.1841ms, not ai-g732 throughput. Actual A1J operator host run NOT EXECUTED.

A1J default `plan` is zero host evidence IO. Explicit `inspect --authorize-a1j-exact-phh-readonly` reads exactly two PHH leaves (A1 selected PRE and retained M4 reviewed POST) each <=512KiB, fd O_NOFOLLOW, verifies both SHA256 pins, narrowly bounds every line change around the mtkmal branch, requires one added embedded-system_ext marker path `/system/system_ext/etc/sable/titan2-cellular-mvp`, preserves A1H evidence and no-build marker/out/repo/stage guards. Missing/changed M4 source yields STOP, no fallback or broad source search.

Only after operator reviews `PASS_EXACT_M4_GUARD_SOURCE_REUSE_PREVIEW_NOT_BUILD_READY`, distinct optional `apply --authorize-a1j-exact-a1-only-phh-write` requalifies, snapshots original/POST bytes into once-only A1 evidence, and replaces exactly ONE isolated A1 PHH file with preserved mode and posthash. No auto rollback/resume, no M4/canonical edits or build. A1J DOES NOT install actual C1 marker/product, app/JAR/XML payloads, evaluate Kati/Soong, close PHH early-boot semantics or make an image build ready.

Operator wrapper `bash ./n1f_p342_a1j_validate_then_inspect_v1.sh` after ZIP hash+unzip. No image build started. No super/device/flash. PR remains open draft unmerged.

```text
A1I_ACTUAL_HOST=HOLD_OPEN_C1_SOURCE_AND_PAYLOAD_GATES_NOT_BUILD_READY
A1I_REGRESSIONS=PASS_92
A1H_SOURCE=PASS_POST_EXACT
A1J_ASSISTANT_ZIP_AND_SYNTHETIC=PASS_INNER9_TESTS88
A1J_AI_G732=NOT_EXECUTED
BUILD_AUTHORIZED=YES BUILD_TECHNICALLY_READY=NO
IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```