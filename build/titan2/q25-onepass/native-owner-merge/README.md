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
