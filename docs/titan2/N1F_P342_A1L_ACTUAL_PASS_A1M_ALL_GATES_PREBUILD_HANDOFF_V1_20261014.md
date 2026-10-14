# PR342 — A1L source PASS, all remaining prebuild technical gates consolidated into A1M V1

Date: 2026-10-14 US/Eastern engineering lane. Operator instruction: **COMPLETE ALL GATES BEFORE BUILD.** Host-only image build authorization is on record; technical source/stock/image admission remains NO. This document is a status report and an external offline package handoff, not a source patch or build execution.

## Actual A1L ai-g732 POST

User final JSON `PASS_A1L_ROM_INHERIT_AND_C1_PROPERTY_CONTEXTS_SOURCE_ONLY_NOT_BUILD_READY`: isolated A1 `device/phh/treble/rom.mk` POST SHA256 `8be9e9f6a6ea41cfe875e30e328dbdb6cfd6b015d11fe60cde0317295c119193`; `vendor/sable/titan2/n1i-c1/sepolicy/system_ext/private/property_contexts` SHA256 `4cfacd72dfc9e87353ae40bd969ed4a8c9e5948fd7ac1a5e77add6ab39f4c591`. Three exact SELinux parent directories created; evidence `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/.A1L_ROM_POLICY_SOURCE_ONLY_NO_BUILD_V1`. `property.te`, six stock-derived IMS APK/JAR/XML, five Sable app APKs NOT STAGED, resolved graph NOT EVALUATED. Source mutation true, image build/network/super/device/flash false. **A1L complete: do not rerun.** Earlier A1F/A1H/A1J/A1K POST states retained, avoid redundant audits.

## Evidence discovered and explicit limits

- Existing retained M4 C1 files from actual A1L read-only preview: OEM stock IMS APK SHA256 `30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539` (9,560,691B); `mediatek-common.jar` `511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549` (88,613B); `mediatek-ims-base.jar` `bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab` (89,785B). These match three canonical content pins, **but origin not re-bound to exact retained stock extraction receipt**.
- Three M4 observed XML SHA256 values: `ade8d01d2a28484cb9080c5e73f16307d2eb5fdb3b427c4c5224aa20a858f36e`, `36ccc511e64e44ffef43136f983fd466fdc0c915187bc78aba9f24b370ef4040`, `1334c08d6eb68c560907b213c026431d1ecc0d101f841ffd44413411946b8f16`. Observed content only, **not stock pins**.
- Five M4 candidate C3B APKs exist but retained app-bundle `manifest.tsv`/`SHA256SUMS.txt`/source import commit seal **not yet identified**. Canonical builder is `build/titan2/build-n1d-c3b-e2-product-apps.sh`, exactly 5 unsigned release APKs from pinned commit `aafb543565c9d59ed5e0d9cda876aabb4967f8aa`; signedness needs independent verification or trusted build logs.
- C1 `property.te` candidate exists in M4 but is not yet re-derived from an explicitly stock-attributed `system_ext_sepolicy.cil` with source receipt; SELinux compiled policy not qualified.
- Isolated A1 has no `.repo`, no `out-a1`, no independent full 991 Git object-store closure, and no Kati/Soong resolved Android16 product graph. Original Oct03 369-patch/TrebleApp and G1/G2/G3 system-image semantics remain unqualified; PHH skip_mount and cellular marker present in source do not prove installed/boot-time effective meaning.

## Consolidated external operator package A1M

`N1F_P342_A1M_ALL_GATES_READONLY_V1.zip` SHA256 **`16838f67d08828188193c0da8092785c67b18775a58aa7aafda0f3575bcd971b`**, **24,562 bytes**. Main Python SHA256 **`00fd3edd2b5b842bbb24a8fab9838063846e962464f14c69ba4bf591186da544`**. Reuses unchanged nofollow/bounded A1D helper SHA `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`.

QA performed in assistant local container: ZIP CRC PASS, **9/9 inner SHA256 PASS**, four Python AST/compile PASS, wrapper `bash -n` PASS; **103/103 synthetic tests PASS under umask 077 (0.074s) and 022 (0.079s)**; fresh-extracted ZIP both umasks **103/103 PASS** (0.076s and 0.077s). A1M actual operator ai-g732 NOT EXECUTED; local synthetic tests do not prove build/source gating on the host.

Runtime A1M `plan` zero host I/O; `inspect --authorize-a1m-all-gates-readonly` has exact named paths, nofollow/size bounded reads only. Revalidates all A1H/J/K/L known exact POST files and evidence + no-build guard/out-A1 `.repo` states; reads exactly six M4 C1 candidate files with 3 canonical and 3 M4-observed SHA pins, 5 retained C3B APKs, five N1I-A audit receipts using official SHA pins. **Optional** `--app-bundle-dir ABSOLUTE` verifies canonical 5-row app manifest/sha/sealed payloads and M4 equality; **optional** `--stock-cil ABSOLUTE` derives 5 property macros and compares exact M4 property.te, but even matches do not independently qualify stock origin. No file staging/No stock image bytes read/No repo/Git/Kati/Soong/Gradle/network/device/flash. The explicit normal result is `HOLD_A1M_ALL_PREBUILD_GATES_NOT_COMPLETE` with per-gate evidence/remaining blockers. Refusal on unexpected A1 source/safety drift.

Operator: verify outer ZIP, unzip fresh, run `bash ./n1f_p342_a1m_validate_and_inspect_v1.sh`; return real JSON. Do not select arbitrary newest app bundle or CIL path. After concrete receipt paths are resolved, feed them with exact `--app-bundle-dir`/`--stock-cil` for this same *read-only* gate, then implement verified provenance and staged payloads plus `.repo` closure and evaluated product graph. **Do not remove `.A1_INCOMPLETE_DO_NOT_BUILD`, create `out-a1`, begin image build or use historic combined build+flash until all technical gates pass**. A1M itself intentionally does not authorize or perform staging/build.

```text
A1L_OPERATOR=PASS_EXACT_POST_SOURCE_ONLY
A1M_LOCAL_QA=PASS_ZIP_INNER9_PY4_BASH_TEST103_BOTH_UMASKS
A1M_OPERATOR=NOT_EXECUTED
C1_PAYLOAD_PROVENANCE=OPEN
C3B_FIVE_APK_BUILD_RECEIPT=OPEN
C1_GENERATED_SELINUX_POLICY=OPEN
A1_REPO_GIT_OBJECT_CLOSURE=OPEN
A1_EVALUATED_KATI_SOONG_PRODUCT_GRAPH=OPEN
A1_FINAL_IMAGE_G1_G2_G3=NOT_BUILDABLE_YET
IMAGE_BUILD_AUTHORIZED_HOST_ONLY=YES
BUILD_TECHNICALLY_READY=NO
IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 remains open, draft and unmerged.