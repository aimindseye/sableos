# Android 16 Titan 2 native SystemUI/Dialer owner merge (source candidate)

**Code added to this branch:** `systemui/SableTitanPinKeys.java` (Git blob `5b6f1ac749a19a297bd8460b7dbbd6c94ea4e7b4`) and `dialer/SableTitanInCallKeys.java` (`b03d1183b160623db567f9dd9c10a20dec3a6909`); these implement pure physical PIN and call-key policies adapted from existing Q25 patch intent while preserving Android Keyguard authentication and Telecom call/audio ownership. **They are not compiled modules by merely residing under build/titan2.**

The **source integration handoff** `TB2_A16_NATIVE_OWNER_SOURCE_MERGE_V1.zip`, SHA256 `c00c2e0acf1dca1486918ccb0675609dabc7f9d4f024e180d67281de5ed9a913`, contains `native_merge.py` that reads actual ai-g732 Android16 owners and produces fully modified source and a unified review patch for exactly these seven target paths:

1. `frameworks/base/packages/SystemUI/src/com/android/keyguard/KeyguardPinBasedInputView.java`
2. `frameworks/base/packages/SystemUI/src/com/android/keyguard/KeyguardPinBasedInputViewController.java`
3. `frameworks/base/packages/SystemUI/src/com/android/keyguard/sable/SableTitanPinKeys.java` (new)
4. `packages/apps/Dialer/java/com/android/incallui/InCallActivity.java`
5. `packages/apps/Dialer/java/com/android/dialer/sable/SableTitanInCallKeys.java` (new)
6. `packages/apps/Dialer/java/com/android/dialer/app/res/xml/sound_settings.xml`
7. `packages/apps/Dialer/java/com/android/dialer/app/res/values/sable_strings.xml` (new or extended)

The integration is **semantic anchor aware** rather than falsely applying the older Q25 full-context patch: no duplicate dispatchKeyEvent, no absent focus callbacks, no unsafe symlink paths, no guessed class identity. It is **fail-closed** if the actual selected Android16 source has diverged beyond the reviewable anchors. Default `stage` writes ONLY outside the Android checkout and preserves byte-identical originals, candidates, diff, receipt. Explicit `apply` demands `--ack APPLY_Q25_A16_PIN_AND_DIALER_SOURCE_ONLY`, preserves backups and limits edits to these exact seven paths. It never builds, flashes, switches git branches, touches native HOME, modem/IMS, SMS permissions, AVB, or installed image.

**Local authoring validation**: eight integration tests PASS in 0.65s, including genuine `javac` compilation of transformed PIN view/controller, Dialer InCallActivity and both helpers against *synthetic Android API stubs*, deterministic stage, acknowledged source apply, duplicate/source-drift/symlink refusal, XML parse and a 1,000-generation benchmark ~0.04s. Pure Java key policies compiled and passed 20 assertions; 600K policy decisions ~7.2 ms locally. ZIP/manifest SHA, CRC, `python3 -m py_compile`, `bash -n` all PASS. These are **not** real Android16 Soong/Dialer Gradle or device tests.

**Scope limits:** This adds direct physical PIN numeric entry and keyboard focus guarding, not all Q25 secure type-ahead/hints/password controllers (Q25 0304 remains only partially adapted). Dialer now includes M/S/D, guarded single ringing-call Space answer and preference source, but must compile against the exact InCallActivity API on ai-g732 before promotion. Browser/first-boot wizard actual selected-image identity is still pending; previous PR346 Setup app reads actual runtime owner intent handlers but is not the first-boot wizard. The preexisting Titan2 Keyboard Settings is registered as the IME settings activity; native framework Settings hierarchy injection still requires host source. **Q25 full completion remains OPEN.**

Preserve PR342 historical IMS constraints, PR344 custody, PR345 CI Sonar, PR346 native/portable Q25 source, and existing dirty ai-g732 canonical source. No `sable.sh` full build or device action took place.

## 2026-10-20 actual ai-g732 V1 Dialer staging failure and corrected V1.1

Actual user command: `bash operator.sh test` passed 8/8 tests (1000 synthetic transforms in 0.032s). The following **real** `bash operator.sh stage` failed with `SOURCE_HOLD: INCALL_PREFERENCE_CATEGORY: expected one anchor, found 0`. The test-suite's printed `APPLIED_UNCOMMITTED_ANDROID_NATIVE_SOURCE_NOT_COMPILED` record refers to its **temporary synthetic fixture**, not the user's actual Android checkout; the real stage **did not modify Android source or produce candidate `RESULT.json`**. User SSH session closed because the shell used `set -e` and stage returned a nonzero exit code.

**True root cause**: V1 assumed the Dialer `sound_settings.xml` necessarily contained `<PreferenceCategory android:title="@string/incall_category_title">`. The selected A16 target does not have that exact group. This is a legacy XML-grouping assumption, not evidence that the PIN/Dialer Java source could not be merged.

**Source-level correction is committed as an exact verified patch** [`SOURCE_DIFF_V1_TO_V1_1.patch`](./SOURCE_DIFF_V1_TO_V1_1.patch), Git blob `e4cb772de26afd0e0f7b52db4c22beed66e1aed3`. New `port_sound_xml` validates a proper `PreferenceScreen` using ElementTree and retains the existing in-call category if uniquely found; otherwise it inserts the opt-in switch as an ordinary direct child of the existing screen. It preserves other preference groups/settings, prefers an already used switch widget class, and rejects malformed or unsupported XML, duplicate preferences, and ambiguous categories. **All Keyguard, Telecom and source-mutation guards remain unchanged.** This patch applies to `native_merge.py` in the original standalone V1 package, not to an Android source file.

**Corrected verified V1.1 package:** `TB2_A16_NATIVE_OWNER_SOURCE_MERGE_V1_1.zip`, SHA256 `42c0d4a325985ed8c8f752487d01ff17975ae83833b17ef2f836337b63e36ade`. Includes full updated `native_merge.py`, source patch, operator, existing Java helpers, tests/reports, and SHA256SUMS. Local real `javac` synthetic Android API fixture compilation PASS, **12/12** Python integration tests PASS in 0.638s, stage-without-legacy-category PASS with `source_mutation=false`, 1000 transformations ~0.073s, Bash/Python syntax, ZIP CRC/SHA PASS. **V1.1 has not yet run against the actual ai-g732 source or built real A16 SystemUI/Dialer**.

One corrected stage only (using already qualified host tools and current Android checkout; out path must not exist):
```bash
cd "$HOME/Downloads"
sha256sum -c TB2_A16_NATIVE_OWNER_SOURCE_MERGE_V1_1.zip.sha256
unzip -q TB2_A16_NATIVE_OWNER_SOURCE_MERGE_V1_1.zip
cd TB2_A16_NATIVE_OWNER_SOURCE_MERGE_V1_1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
bash operator.sh stage \
  --android /srv/sable-build/workspaces/titan2-track-b/android \
  --out "$HOME/Downloads/TB2_A16_NATIVE_OWNER_STAGE_V1_1_20261020"
```

Do NOT run `apply` or `sable.sh` based only on a stage result; full Android16 API/source review, module compile, runtime tests and privileged product admissions remain separate.

