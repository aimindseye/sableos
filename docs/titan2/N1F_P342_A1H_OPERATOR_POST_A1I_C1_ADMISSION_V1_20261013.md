# PR342 A1H operator PASS and A1I source/C1 build-admission handoff V1

Date: 2026-10-13 US/Eastern operator lane. **This is documentation/evidence only.** Operator has previously explicitly authorized **host-only Android image build**, not device, super, reboot, or flashing. **Actual compilation has NOT started**; technical admission of A1 source/product graph remains held.

## A1H V1.1 — actual operator completed

Actual ai-g732 operator result:
```json
{
  "status":"PASS_EXACT_A1_R1_B1_POST_SOURCE_ONLY_NOT_BUILD_READY",
  "source_paths_modified":[
    "frameworks/base/core/res/AndroidManifest.xml",
    "frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java"
  ],
  "r1_post_sha256":"2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca",
  "b1_post_git_blob_sha1":"9d5108e0ddb8d4960d21cda021813b53dbbf4da8",
  "evidence_dir":"/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/.A1H_EXACT_R1_B1_NO_BUILD_V1",
  "marker":"PRESERVED","out_a1":"ABSENT",
  "build_ready":false,"build":false,"super":false,"device":false,"flash":false,"network":false
}
```
The earlier A1H V1.1 package checksum/11 internal receipts, 132/132 tests and read-only PRE→POST preview had PASS on Ubuntu. **A1H application is CLOSED, do not rerun.** Parent A1F 11/11 archived manifest destinations and A1G selected source read remain accepted. The old source PRE identities are superseded **only in isolated A1**; original protected donor remains preserved.

## Reuse original SableOS C1 build definitions rather than run old driver

Reviewed exact `aimindseye/sableos` main source:
- `product/titan2/n1i-c1/Android.bp` Git blob `5b68bdde3a158a38fc7532abb571de88d2688649` defines six OEM IMS modules; no stock native in first candidate.
- `product/titan2/n1i-c1/sable-titan2-n1i-c1.mk` Git blob `56f7d1fdca8427b4e1d64376c8e18ad19b49c82c` declares six PRODUCT_PACKAGES, **two** PRODUCT_BOOT_JARS_EXTRA and **two** PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES.
- `product/titan2/n1i-c1/config-paths.txt` Git blob `9629e4f82db855f25ac995b3e71314b2ac1070cc`: three exact permission/sysconfig XMLs.
- `build/titan2/n1i-c-oem-ims-admission.env` Git blob `b627e9a800756d7cd20956927330b508dc5e9153` pins stock IMS APK SHA256 `30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539`, JAR `mediatek-common` SHA256 `511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549` and JAR `mediatek-ims-base` SHA256 `bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab`, initial native import count zero.
- Main C3B five-app BP/mk owner blobs `82a702a8d4863aa5c0b314e04563b3b28ae77a06` and `482d24509530d94375f47f5cd3b63f15e2340ba4`.
- Historic `build/titan2/run-n1i-c1-cellular-isolation.sh` builds C3B apps offline, extracts two huge TEE14 stock images, stages payload/source, executes systemimage in **historical donor** workspace. The older `run-n1f-c3a-derived-c3b5-r2.sh` additionally **requires and executes physical flash**. Neither is a selected-A1 build-only entrypoint. No reuse in `run` mode.

## External A1I V1 read-only operator package

`N1F_P342_A1I_C1_BUILD_ADMISSION_READONLY_V1.zip` SHA256 **`12a8d0fa7a8eb6d93ee4402e34bd6402dfa9d6ee69e689fc9a5462f050090eb0`**, **22,409 bytes**. Main Python `n1f_p342_a1i_c1_build_admission_v1.py` SHA256 **`06a744800818abf7f38ae29fd05cb2c9264b219074c450b54837a4b2b7d2840b`**; frozen A1D module and 48 tests copied unchanged. ZIP CRC PASS; **9/9 inner SHA256 manifest entries PASS**; Python AST/compile 4/4 PASS; Bash wrapper syntax PASS. Fresh unzip regression **92/92 PASS under restrictive `umask 077` (0.031s)** and `umask 022` (0.030s). **These are assistant synthetic fixtures, NOT ai-g732 or Android performance.** Real ai-g732 A1I inspect **NOT EXECUTED**.

A1I inputs (all bounded, source nofollow):
- Reuse Oct03 SHA-pinned archived manifest XML and 11 A1F post-manifest leaves (<=4MiB archive, <=256 rules), rehash A1F `lk_inc.mk`, and only selected A1 R1/B1 **exact POST** source leaves.
- Selected A1 original `device/phh/treble/rom.mk` exact pre-staging SHA `ab0ec737342d41d562816fce73e8694e35ce32e09db74c12ea115efa3619d592`; selected PHH `phh-on-boot.sh` and physical GSI `gsi_skip_mount.cfg` source only (NOT runtime semantic proof).
- Only exact 7 C1/C3B SableOS template files from locally dirty canonical `/srv/data/sable-build/sableos/repo`, Git blob content matching main; **no Git/repo command or source changes**. Dirty template drift causes refusal, not a reset.
- Only metadata type for original stock TEE14 system.img and system_ext.img at the already recorded source path; **no images read, extracted, mounted or decompressed**.
- Exact A1H evidence directory, persistent no-build marker, absent `out-a1`, absent `.repo` and still-not-staged C1+C3B roots.

It prints an explicit `HOLD_A1I_...`/bounded PASS owner summary **always `build_ready=false`**: missing actual C1 APK/JAR/XML payloads, five app artifacts, source-to-payload stage, compiled/evaluated product graph, PHH Titan-specific guard/marker semantics, repo namespace, Git alternates self-containment/369 patch verification. Even a static-owner PASS is not a build admission. It never starts Python code from inspected repo, external builds, Gradle, Soong, Kati, Java, Android build commands, network, USB/device/flash, or writes into any workspace.

Exact on-host launcher, after external ZIP SHA and unzip: `bash ./n1f_p342_a1i_validate_then_inspect_v1.sh`. That verifies 9 internal SHA/tests (92), plan with zero host evidence IO and explicitly authorized bounded inspection. No new user source/build permission is required for the previously authorized pre-build engineering lane; no image build command is enabled by A1I.

## Next after A1I host report

Design one **build-only** isolated A1 staging and executor from exact input hashes, without source cleaning/rollback, preserving the five C3B apps/skip_mount and adding only the six C1 modules, existing approved PHH guard/marker with exact source pins, and conditional G3 native only after complete selected-process admission. Treat absent `.repo` as a source graph/driver compatibility question, not grounds to synthesize metadata. Keep `.A1_INCOMPLETE_DO_NOT_BUILD` until staged payload/product, PHH init/SELinux and noflash build-only safety are established. New OUT_DIR only after technical admission; no super/LP/AVB or device/flash.

```
A1F_OPERATOR=PASS_11_ARCHIVED_DESTINATIONS
A1G_OPERATOR=PASS_SOURCE_PRE_PRE_PRIOR
A1H_OPERATOR=PASS_EXACT_R1_B1_POST_NOW_APPLIED
HOST_IMAGE_BUILD_AUTHORIZED=YES
A1I_ASSISTANT_PACKAGE=PASS_CRC_INNER9_AST4_BASH_TEST92
A1I_OPERATOR=NOT_EXECUTED
BUILD_TECHNICAL_READY=NO BUILD_NOT_STARTED
SUPER=NO DEVICE=NO FLASH=NO
```
PR342 remains OPEN/DRAFT/UNMERGED; current user consent for image build should not be interpreted as permission to flash or alter recovery/bootchain.