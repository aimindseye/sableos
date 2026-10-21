# Titan 2 Track B: actual A16 31-minute module build, warning census, and narrowly corrected Dialer source

**Date:** 2026-10-20 (ai-g732 source receipts provided by user). This is an actual full build-log diagnosis rather than another synthetic Android stub success claim.

## Verified actual results

User's uploaded `native-modules.log`: **38,022 lines**, `RESULT.json`: **1,872.994 seconds** elapsed, `m -j4 SystemUI Dialer` exit code 1; `rollback=PASS`, empty rollback errors, `source_mutation=false`. All seven original source files were restored; no image/device/flash.

**Exactly one fatal compiler error / one failed Ninja action** in entire provided log:

```
[ 93% 16052/17083] //packages/apps/Dialer:Dialer javac [common]
FAILED: out/soong/.intermediates/packages/apps/Dialer/Dialer/android_common/javac/Dialer.jar ...
packages/apps/Dialer/java/com/android/incallui/InCallActivity.java:138:
  error: package androidx.preference does not exist
  boolean spaceAnswers = androidx.preference.PreferenceManager
```

This means Soong, Kati, significant ART/native/systemui dependency work actually ran. **It does not mean either complete SystemUI or Dialer target succeeded.** The compiler stopped in Dialer; it is not a lunch-target problem (correct `treble_arm64_bvN-bp4a-userdebug` selected this time).

## Correct source change

The Q25 native owner merger previously generated the AndroidX call although the Dialer Java module does not have an AndroidX PreferenceManager dependency. Do not modify Dialer `Android.bp` by pulling in arbitrary AndroidX classpath. Both AOSP platform and AndroidX standard preference storage use `<packageName>_preferences`, private mode. Replace only

```java
boolean spaceAnswers = androidx.preference.PreferenceManager
        .getDefaultSharedPreferences(this).getBoolean("sable_space_answers", true);
```

with

```java
boolean spaceAnswers = getSharedPreferences(getPackageName() + "_preferences",
        android.content.Context.MODE_PRIVATE).getBoolean("sable_space_answers", true);
```

No import, extra dependency or deprecated framework API is needed. The existing on-disk preference key and default behavior are retained. Note user still must qualify actual Dialer preference screen lifecycle and calls at runtime.

Original operator's seven pinned staged files are **not rewritten**. Sealed replacement Phase12 V1.1 operator reads and verifies those exact seven SHA256 stage files, then performs one deterministic exact-anchor transformation **in memory**, producing changed Dialer `after_sha256` and `DIALER_PREFERENCE_FIX.patch` under the new receipt directory. Its source promotion and on-build-failure rollback checks use the *corrected post-fix* hash, restoring all seven original before-hash blobs. Duplicate/missing source anchor and stage/source drift fail closed; no new Git checkout or host compiler installation. Source review diffs: [Phase12 script delta](./SOURCE_DIFF_FROM_V1.patch) and [original generator correction](./NATIVE_GENERATOR_CORRECTION.patch). The sealed ZIP contains the exact generated diff and full tested operator source.

**Sealed output** `TB2_A16_PHASE12_INTEGRATE_COMPILE_V1_1.zip`, SHA256 **`9d9744d797c5e1f975d321be47a908f13918fddb8578e8d18af51f683eb6eb72`**. Complete `integrate_compile.py`, tests, original-version delta, warning analyzer, single-pass actual-log classification report and README. 18/18 tests PASS (~1.2s; Kotlin/Android dependency not invented); Java stub with no AndroidX compiles and runs exact new preference read; 250 seven-file hash validations ~0.57s; 4.5MB warning scan ~0.17s average. Python AST and Bash syntax PASS; archive CRC + member checksums PASS. This is **not** a real post-fix SystemUI/Dialer compile.

## Actual warning audit disposition

| Group | Actual count | Required action |
|---|---:|---|
| Fatal Java errors | **1** | **FIX NOW** in native Dialog: missing AndroidX class, replacement above |
| Failed Ninja actions | **1** | Correlates with same Dialer Java error |
| `warning:` diagnostic occurrences | **5,801** | Mostly duplicated generated AOSP sources, **not** 5,801 unique defects |
| Existing Kotlin-source warnings | ~3,913 occurrences | Record baseline; not a reason to edit AOSP-wide Kotlin now |
| Metalava API warnings | ~1,444 occurrences | Generated/SDK metadata warnings, no tie to Dialer failure |
| Javac configuration warnings | ~135 occurrences | Toolchain/API-generator backlog |
| `Build sandboxing disabled due to nsjail error` | **2** | Investigate before release/CI reproducibility; do not silently disable security sandbox |
| `mkdir: '/system': Permission denied` | **6** | Investigate emitting host rule and unwanted host-root writes; do not `sudo mkdir /system` |
| Missing installed kernel/boot image for OTA/VINTF | **1** | Explicit pre-OTA/product packaging gate, not necessary for module-only compile |

No warnings were suppressed, no global compiler flags changed, and no unrelated Android framework or kernel sources were edited. The current product is a GSI/Treble engineering target; the kernel/boot warning cannot be casually dismissed for signed final OTA because metadata completeness depends on the final boot chain.

## Follow-up on ai-g732

Use the new package with `sha256sum -c` and `bash operator.sh test`. Perform one read-only `operator.sh plan` using unchanged `TB2_A16_NATIVE_OWNER_STAGE_V1_1_20261020`, inspect `DIALER_PREFERENCE_FIX.patch` and new digest; then one acknowledged `operator.sh run` with explicit `treble_arm64_bvN-bp4a-userdebug` and fresh output directory. It will reuse existing `out/` compile intermediates without deleting them. Do not try the old V1 operator again. Success of this module build is not Q25 full product completion.

PR #342 historic IMS qualification remains independent, PR #344 custody is source of Track B readiness, PR #345 Sonar static checks independent, PR #346 actual portable-Q25 source remains draft. Real new image/IMS, Launcher3QuickStep HOME, privileged AppLock and selected READ_SMS admission still OPEN. No image/flash authorization inferred.
