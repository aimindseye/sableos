# PR342 — A1U actual image-build PASS; A1V consolidated postbuild read-only qualification

**Date:** 2026-10-14 (America/New_York). **PR state:** Open/draft/unmerged. **Lane:** isolated Titan 2 A1 Android 16, user-authorized host-only image build. No device, super, fastboot, ADB, reboot, flash or production-release authorization.

## ACTUAL ai-g732 successful systemimage

The operator posted a genuine finished A1U result:

```text
[100% 180378/180378] //frameworks/base/api:system-api-stubs-docs-non-updatable check current API [common]

#### build completed successfully (02:37:15 (hh:mm:ss)) ####

A1U_IMAGE_BUILD=PASS_INCREMENTAL_SYSTEMIMAGE_HOST_ONLY
SYSTEM_IMG=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/.A1T_HOST_ONLY_SYSTEMIMAGE_V1/out/target/product/tdgsi_arm64_ab/system.img
SHA256=82ceeaf2a96ff4aaf29f684cf91e04a97e15d7ab1955d1e9c3394e244c116762
BYTES=3210473472
A1U_NEXT=POST_BUILD_IMAGE_QUALIFICATION_BEFORE_DEVICE
```

**This is a real build PASS, not a mock result.** 180,378 steps, 02:37:15, 3,210,473,472 bytes. User's previously authorized host-only build was completed after one exact historical TrebleApp prebuilt restored in A1U. A1T's original Ninja failure on missing `treble_app/TrebleApp.apk` and `BUILD_RC.txt=1` must stay **unchanged**; A1U's successful incremental resume recorded `RESUME_RC.txt=0` and `IMAGE_RESULT.txt`. No original A1F–A1S audit/staging or Android build rerun is needed. The image is not yet established safe to flash or boot.

## Why one read-only postbuild gate remains

Earlier SableOS `build/titan2/run-n1i-c1-cellular-isolation.sh` (on a historically different workspace) defines actual output checks for C1 APK identity, shared UID, platform signer, two Mediatek framework JAR paths, bootclasspath, three OEM XML copyouts and compiled SELinux contexts. Canonical `build/titan2/build-n1d-c3b-e3-systemimage.sh` defines five C3B packages/signatures. A1K stage defined exact 46-byte `titan2-cellular-mvp` marker. A1O independently tied six original OEM sources to SHA-pinned stock partitions. **These are postbuild checks, not reasons to restart A1T or A1U.** The build PASS alone doesn't prove that the final filesystem bytes match the output tree or that IMS platform signing/SELinux is correct.

## A1V V1 sealed external package

**Archive:** `N1F_P342_A1V_POSTBUILD_READONLY_V1.zip`, 14,283 bytes, outer **SHA256 `b26d5fbd22c316682184b7d61f8405263138b6fc4c704f28a4a9a8737b072681`**, 8 ZIP members (7 SHA-sealed members + `SHA256SUMS.txt`). Main `n1f_p342_a1v_postbuild_readonly_v1.py` SHA256 **`4f41d3544ac9dcbddc0409abaa9d4293be8bca0225db6ce66235bbb18696ece9`**. Wrapper `n1f_p342_a1v_one_command_v1.sh`, test source, README/PLAN/ENGINEERING_REVIEW and validation log are sealed in same archive.

The **single operator command**, after independently checking outer ZIP SHA and fresh unzip, is `bash ./n1f_p342_a1v_one_command_v1.sh`. There is no write authorization flag because this tool does **no A1 source/out/evidence mutations**. It checks member hashes, AST/Bash syntax, 17 hermetic tests and no-host-I/O plan before real inspection. It consumes the canonical trusted SableOS `build/config/host-tools.env` to find existing `aapt2` and `apksigner`; no installs/network.

Real operation pins exact `system.img` bytes and SHA to operator's successful receipt and independently hashes complete **3.21 GB** image, verifies A1U RESUME_RC=0 and preserves original A1T BUILD_RC=1; verifies 15 exact output tree files: five Sable APKs and package IDs/signatures, OEM `com.mediatek.ims` sharedUID `android.uid.phone` and **platform signer equality** to signed framework-res, original two Mediatek JAR and three XML SHA pins, exact 46-byte marker, protobuf bootclasspath strings, compiled property_contexts and two MTK IMS slot service_contexts. Then streams those same exact 15 members from the **actual completed image** using **read-only** `debugfs -R cat` on ext4 or `dump.erofs --cat` on EROFS, with inherited fd to protect against path swaps, consistent GSI namespace and SHA/byte matching against output-tree members. No mounts or scratch extraction; each selected file read is capped at 64 MiB, and tool execution is bounded to 60 seconds; the full image stream hash is performed once.

If all checks pass: `PASS_A1V_IMAGE_AND_TREE_READONLY_NOT_DEVICE_READY`. If any are missing, incompatible, unsigned, wrong cert, different/unsafe, or can't be read from the image: `HOLD_NOT_FULLY_VERIFIED` with specific reason, exit 1. This is intentionally fail-closed. The script has a diagnostic-only `--tree-only` mode which never returns full qualification (also exits nonzero). The full result is stdout JSON; it **does not alter existing A1T/A1U artifacts or one-use evidence**. No device operations are contained in the package.

## Independent validation and boundaries

- ZIP CRC PASS and all 7/7 inner SHA256 PASS.
- Python AST parse 2/2 PASS; Bash syntax PASS.
- **17/17 synthetic hermetic tests PASS** under both umask 077 and 022; **fresh extracted exact ZIP independently verified with 17/17 tests PASS under both umasks**, no-host-I/O `plan` PASS.
- Synthetic complete 15-file image-member mock success PASS, synthetic output-tree-only mode not promoted to full PASS, exact-image/hash, signer, shared UID, symlink, absent file, wrong image member and prior receipt-negative tests PASS.
- Hashing a synthetic 4 MiB byte file 18 times: median **2.881 ms**, p95 **4.025 ms** in assistant container. **Not** a real 3.21 GB ai-g732 disk-read or Android image-content performance measurement. The tool does not estimate host throughput.
- **Actual A1V ai-g732 NOT EXECUTED** as of this note. No claim that package outputs will PASS until ai-g732 reports real results.
- Existing ai-g732 `nsjail` and `mkdir: '/system': Permission denied` host diagnostics remain known nonblocking when exit code + artifact validations are good; no exception is made for real signature/policy/copyout errors.
- A1V is still not a production device release gate. Image boot/PHH behavior and G1/G2/G3 device/partition compatibility are separate and require explicit later permission.

```text
A1P_SOURCE_AND_POLICY=PASS_REAL
A1Q_GIT=PASS_REAL
A1R_ANDROID_PRODUCT_GRAPH=PASS_REAL
A1_RELEASE_PROBE=PASS_REAL
A1T_IMAGE_BUILD=ORIGINAL_FAIL_RC1_TREBLEAPP_PRESERVED
A1U_IMAGE_BUILD=PASS_REAL_SYSTEMIMG_SHA_82ceeaf2a96f_3210473472_BYTES
A1V_PACKAGE=PASS_ZIP_CRC_SHA7_AST2_BASH_TEST17_BOTH_UMASKS
A1V_REAL_HOST=NOT_EXECUTED
IMAGE_CONTENT_SIGNING_SELINUX=NOT_YET_VERIFIED
DEVICE=NO SUPER=NO FLASH=NO
```
