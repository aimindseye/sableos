# PR #342 — A1G operator PASS, image-build authorization and A1H exact source integration handoff

Date: 2026-10-13. Scope = isolated Android16 A1 **host-only** image build authorization received, subject to technical source and product checks. No device, super/LP/AVB assembly, recovery, reboot, fastboot or flash authorization. **Neither A1H nor an Android image build has run on ai-g732.**

## Actual selected A1 source qualification — accepted

- Operator's `N1F_P342_A1G_SELECTED_SOURCE_PREBUILD_V1.zip` outer and 9/9 internal member SHA256 PASS, local regressions **88/88 PASS 0.113s**, plan `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO` PASS.
- Actual readonly A1G `PASS_A1G_SELECTED_A1_EXACT_SOURCE_STATES_NOT_BUILD_READY` at `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android`.
- A1F eleven archived Oct03 repo-manifest-managed destinations retained: 10 exact linkfile literals + 1 regular `lk_inc.mk`, rehashed 652 bytes SHA256 `083778590fe579ecc6b484cb6381c7b09649397bde9665c089d83e45774108d4`, mode `0o444`.
- **New selected source exact PRE/PRE**: R1 `frameworks/base/core/res/AndroidManifest.xml` 541677 bytes SHA256 **`2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c`**. B1 `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java` 2274 bytes Git blob SHA1 **`27638e5be9c008101c2f9b8f1e7a9af49d94f838`**. Neither R1 nor B1 has been integrated into selected A1 yet.
- `.repo` absent, `.A1_INCOMPLETE_DO_NOT_BUILD` present, `out-a1` absent. Four Git alternative samples: `device/phh/treble` one textual reference to protected donor; other three sampled alternates absent, **NOT independent object-store closure**. No new IMS/C1/CW1/native source integrated.

## Existing authoritative source reuse — avoid duplicates

- Main `patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch` already exists (Git blob SHA1 **`ee353caded6dd07318991eb52d66687e06034c30`**). Official B1 desired output Git blob `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`. Do not invent alternative TelephonyMetrics behavior.
- Original archived [PR339 R1 exact one-line source preview](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497610584), selected M4 B1 integration [review](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497674970), historic C1 six modules/two boot Jar/two override product owner already in `product/titan2/n1i-c1`, original `run-n1f-c3a-derived-c3b5-r2.sh` is **combined build+flash** and cannot be used to build new isolated A1.
- Previously qualified M11 signed IMS APK, R2 five ELF identities, 56 direct dependencies, 19 Bionic, 4 GNU, historical M4 G1/G2/G3 scoped passes **remain prior evidence only**; the physical M4 `system_a` Recovery failure cannot be projected as the new A1 result or treated as solved.

## Prepared next deliverable A1H — two-file source integration only

Externally distributed ZIP `N1F_P342_A1H_EXACT_R1_B1_BUILD_PREP_V1.zip` SHA256 **`2601af3a5f3422d37093c60183507fb88373f5a77f5df2145e350707f248966e`**, 29,622 bytes. Main Python SHA256 **`d7d3f044ffeb994420253f53bad0d8479d60a7f1385eec40d7814aade1f2d2e1`**. Bundled A1D and A1G source files retain exact historical SHA pins `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777` and `9fb76d6dfedc2675a76da84f6b5c4d1e8fa64e9a0c90f41dcebc72c4b7aeca6b`. ZIP CRC PASS, **11/11 inner SHA256SUMS PASS**, Python AST/bytecode 6/6 PASS, Bash syntax PASS, inherited A1D+A1G + new A1H **128/128 synthetic tests PASS (0.234s)**. 1000 synthetic *tiny-content* R1/B1 preview operations median 0.003635ms/p95 0.003846ms, not real 541KB input timing or actual ai-g732 build.

Modes:
- Default `plan` zero host-evidence I/O.
- `inspect --authorize-a1h-two-source-readonly`: full frozen A1G check and predicts R1 +102-byte POST raw SHA `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`, B1 +273-byte official overload POST blob SHA `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`. **NO source write unless both computed POST values match**; refuses source format/drift, extra symlink or absent guard.
- `apply --authorize-exact-a1-r1-b1-source-replay`: separately explicit, previously operator-authorized A1-only source preparation, only after exact PRE/PRE and both exact POST preview gates. Creates an A1-container evidence directory (no overwrite) containing original source bytes, replaces only the two A1 target leaves with nofollow/capped staging/fsync. **No rollback, no cleanup and no automatic resume** on partial failure; marker preserved and output absent. No `.repo` recreation, donor edit, compiler invocation or device action.

This package does **not** automatically start Android build. A1 currently lacks `.repo`, effective product/Soong/Kati admission and verified staged C1 IMS payload, original Oct03 TrebleApp post residue provenance and complete 369-patch/source semantics; R1/B1 only are insufficient. A new A1-specific build-only executor (explicit fresh OUT_DIR, never original combined build+flash) must subsequently require source POST, qualified C1 app/JAR/XML and PHH marker, preserved embedded `skip_mount.cfg`, actual resolved product variables, native G3 admission, and an explicit no-build marker retirement authority once all technical gates closed. **Image build authorization recorded; build technical admission not yet PASS.**

```text
A1F_MANIFEST_11=PASS_ACTUAL
A1G_OPERATOR_SELECTED_A1=PASS_88_TESTS_R1_PRE_B1_PRE
A1_REPO_METADATA=ABSENT
A1_GIT_OBJECT_INDEPENDENCE=UNBOUND
HOST_ONLY_IMAGE_BUILD_AUTHORIZED=YES
A1H_ASSISTANT_ZIP_TESTS=PASS_128
A1H_AI_G732_PREVIEW=NOT_EXECUTED
A1H_AI_G732_SOURCE_WRITE=NOT_EXECUTED
A1_PRODUCT_IMS_GRAPH_ADMISSION=OPEN
A1_NO_BUILD_MARKER=PRESERVE
OUT_A1=ABSENT
HOST_ANDROID_IMAGE_BUILT=NO
SUPER=NO DEVICE=NO FLASH=NO
```

Keep PR #342 open, draft, unmerged and documentation-only.