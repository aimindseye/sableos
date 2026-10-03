#!/usr/bin/env bash
# Mutation tests for the D7B keyboard compact input strip source contract in the static qualification gate.
# Developer-runnable, offline, no Gradle. Copies the tracked tree into a throw-away git repo, proves the baseline passes,
# then injects one violation at a time and requires the gate to fail with the matching STATIC_FAIL message.
#   build/titan2/test-c3b-d7b-contract.sh            (ONLY=<case-name> runs a single case)
# Marker on success: C3B_D7B_CONTRACT_MUTATION_TESTS=PASS count=N
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"
git ls-files -z | while IFS= read -r -d '' f; do [[ -e "$f" ]] && { mkdir -p "$T/$(dirname "$f")"; cp -p "$f" "$T/$f"; }; done
cd "$T"
git init -q . && git config user.email t@example.invalid && git config user.name t && git add -A && git commit -q -m base
GATE="build/titan2/qualify-c3b-product-source.sh"
run_gate() { bash "$GATE" --static --base HEAD --allow-dirty 2>&1; }
out="$(run_gate)"
grep -q '^D7B_COMPACT_STRIP_SOURCE_CONTRACT=PASS' <<<"$out" || { echo "$out" | grep STATIC_FAIL | head; echo "C3B_D7B_CONTRACT_MUTATION_TESTS=FAIL_BASELINE" >&2; exit 1; }
for m in SABLE_KEYBOARD_COMPACT_STRIP_MODEL=PASS SABLE_KEYBOARD_COMPACT_STRIP_STATE=PASS SABLE_KEYBOARD_COMPACT_STRIP_SAFE_AREA=PASS SABLE_KEYBOARD_COMPACT_STRIP_HEIGHT=PASS SABLE_KEYBOARD_COMPACT_STRIP_PRIVACY=PASS SABLE_KEYBOARD_COMPACT_STRIP_SCOPE=PASS_EXCLUSIONS_ABSENT; do
    grep -q "^$m\$" <<<"$out" || { echo "C3B_D7B_CONTRACT_MUTATION_TESTS=FAIL_BASELINE_MARKER $m" >&2; exit 1; }
done
pass=0; fail=0
mutate() { # name expected-substring shell-snippet
    local name="$1" want="$2" snippet="$3"
    [[ -z "${ONLY:-}" || "$name" == "$ONLY" ]] || return 0
    git reset -q --hard HEAD; git clean -fdq
    eval "$snippet"
    git add -A
    local o rc; o="$(run_gate)"; rc=$?
    if (( rc != 0 )) && grep -q "STATIC_FAIL:.*$want" <<<"$o"; then pass=$((pass+1)); echo "OK   $name"; else fail=$((fail+1)); echo "MISS $name (rc=$rc, wanted STATIC_FAIL containing: $want)" >&2; grep STATIC_FAIL <<<"$o" >&2; grep -q STATIC_FAIL <<<"$o" || tail -3 <<<"$o" >&2; fi
}
# rp FILE OLD NEW: exact, single replacement; fails loudly if OLD is absent so a stale case cannot pass silently.
rp() { python3 - "$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if old not in s: sys.exit("MUTATION_TARGET_MISSING: " + old)
open(p, "w").write(s.replace(old, new, 1))
PY
}
# dl FILE PATTERN: delete every line containing PATTERN (no trailing-whitespace residue).
dl() { python3 - "$1" "$2" <<'PY'
import sys
p, pat = sys.argv[1:3]
L = open(p).read().split("\n")
K = [l for l in L if pat not in l]
if len(K) == len(L): sys.exit("MUTATION_TARGET_MISSING: " + pat)
open(p, "w").write("\n".join(K))
PY
}
KK=apps/titan2/platform/keyboard/src/main/java/org/sableos/titan2/keyboard
KT=apps/titan2/platform/keyboard/src/test/java/org/sableos/titan2/keyboard/core
KG=apps/titan2/platform/keyboard/build.gradle.kts
KM=apps/titan2/platform/keyboard/src/main/AndroidManifest.xml
CS=$KK/core/CompactStrip.kt
CV=$KK/android/CompactStripView.kt
SV=$KK/android/SableImeService.kt
DOC=docs/SABLE_KEYBOARD_COMPACT_INPUT_STRIP.md
IRT=docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv
KLD=docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md
TST=$KT/CompactStripTest.kt
# irstat ID: set the status column of an interface request to CLOSED
irclose() { python3 - "$IRT" "$1" <<'PY'
import sys
p, rid = sys.argv[1:3]
L = open(p).read().split("\n"); h = L[0].split("\t")
for i, l in enumerate(L):
    if l.startswith(rid + "\t"):
        c = l.split("\t"); c[h.index("status")] = "CLOSED"; L[i] = "\t".join(c)
open(p, "w").write("\n".join(L))
PY
}
# --- documented contract ---
mutate doc-missing "docs/SABLE_KEYBOARD_COMPACT_INPUT_STRIP.md missing" "git rm -q $DOC"
mutate doc-model-marker "must state SABLE_KEYBOARD_COMPACT_STRIP_MODEL=PASS" "rp $DOC SABLE_KEYBOARD_COMPACT_STRIP_MODEL=PASS SABLE_KEYBOARD_COMPACT_STRIP_MODEL=SKIPPED"
mutate doc-scope-marker "must state SABLE_KEYBOARD_COMPACT_STRIP_SCOPE=PASS_EXCLUSIONS_ABSENT" "rp $DOC SABLE_KEYBOARD_COMPACT_STRIP_SCOPE=PASS_EXCLUSIONS_ABSENT SABLE_KEYBOARD_COMPACT_STRIP_SCOPE=PASS"
mutate doc-runtime-validated "must state D7B_DEVICE_RUNTIME_VALIDATED=NO" "rp $DOC D7B_DEVICE_RUNTIME_VALIDATED=NO D7B_DEVICE_RUNTIME_VALIDATED=YES"
mutate doc-critical-runtime "must state D7B_CRITICAL_TEXT_ENTRY_DEVICE_RUNTIME_VALIDATED=NO" "rp $DOC D7B_CRITICAL_TEXT_ENTRY_DEVICE_RUNTIME_VALIDATED=NO D7B_CRITICAL_TEXT_ENTRY_DEVICE_RUNTIME_VALIDATED=YES"
mutate doc-pastiera-imported "must state D7B_PASTIERA_SOURCE_IMPORTED=NO" "rp $DOC D7B_PASTIERA_SOURCE_IMPORTED=NO D7B_PASTIERA_SOURCE_IMPORTED=YES"
mutate doc-gpl-copied "must state D7B_GPL_CODE_COPIED=NO" "rp $DOC D7B_GPL_CODE_COPIED=NO D7B_GPL_CODE_COPIED=YES"
mutate doc-emoji-data "D7B_EMOJI_DATA" "rp $DOC D7B_EMOJI_DATA=NONE D7B_EMOJI_DATA=BUNDLED"
mutate doc-snippets "must state D7B_SNIPPETS=NO" "rp $DOC D7B_SNIPPETS=NO D7B_SNIPPETS=YES"
mutate doc-shizuku "must state D7B_SHIZUKU=NO" "rp $DOC D7B_SHIZUKU=NO D7B_SHIZUKU=YES"
mutate doc-clipboard "must state D7B_CLIPBOARD_HISTORY=NO" "rp $DOC D7B_CLIPBOARD_HISTORY=NO D7B_CLIPBOARD_HISTORY=YES"
mutate doc-dependency-delta "must state D7B_DEPENDENCY_DELTA=NONE" "rp $DOC D7B_DEPENDENCY_DELTA=NONE D7B_DEPENDENCY_DELTA=ADDED"
mutate doc-ir004-claim "must state IR_004_STATUS=OPEN_CANONICAL" "rp $DOC IR_004_STATUS=OPEN_CANONICAL IR_004_STATUS=CLOSED"
mutate doc-ir005-claim "must state IR_005_STATUS=OPEN_CANONICAL" "rp $DOC IR_005_STATUS=OPEN_CANONICAL IR_005_STATUS=CLOSED"
mutate ledger-ir004-closed "IR-004 must stay OPEN" "irclose IR-004"
mutate ledger-ir005-closed "IR-005 must stay OPEN" "irclose IR-005"
mutate ledger-kl032-removed "KL-032 (D7B compact strip" "dl $KLD '| KL-032 |'"
# --- model ---
mutate model-object-removed "must define object CompactStrip" "rp $CS 'object CompactStrip' 'object CompactStrip3'"
mutate model-geometry-removed "must define object StripGeometry" "rp $CS 'object StripGeometry' 'object StripGeometry3'"
mutate model-mode-hidden-removed "StripMode must keep Hidden" "rp $CS '    Hidden,' '    Gone,'"
mutate model-mode-candidates-only-removed "StripMode must keep CandidatesOnly" "rp $CS '    CandidatesOnly,' '    CandsOnly,'"
mutate model-service-not-using-model "must render the compact strip through CompactStrip.build" "rp $SV 'CompactStrip.build(' 'CompactStrip3.build('"
mutate model-refresh-can-throw "a failed strip refresh must never reach the key path" "rp $SV 'runCatching { CompactStrip.build(' 'run { CompactStrip.build('"
mutate model-no-setting "must be a stored setting" "rp $KK/android/KeyboardPrefs.kt 'getBoolean(\"compactStrip\", true)' 'getBoolean(\"compactStrip\", false)'"
mutate model-no-settings-switch "must be a stored setting" "dl $KK/android/KeyboardSettingsActivity.kt 'compactStrip'"
mutate model-softkeyboard-uses-compact "only the previous candidates-only behaviour" "rp $CS 'softKeyboardShown || !i.enabled' 'false'"
# --- state ---
mutate state-navon-removed "StripInputs must carry navOn: Boolean" "rp $CS 'navOn: Boolean' 'navOn3: Boolean'"
mutate state-variation-removed "StripInputs must carry variation: VariationInfo?" "rp $CS 'variation: VariationInfo?,' 'variation3: VariationInfo?,'"
mutate state-sym-chip-removed "the strip must show the \"sym\" modifier chip" "rp $CS 'ModChip(\"sym\"' 'ModChip(\"sy\"'"
mutate state-nav-overclaims "Nav must be shown Active only when effective" "rp $CS 'i.navEffective -> ChipState.Active' 'i.navOn -> ChipState.Active'"
mutate state-resolver-variation-removed "Resolver must expose read-only variation" "rp $KK/core/Resolver.kt 'fun variation()' 'fun variation3()'"
mutate state-resolver-nav-removed "Resolver must expose read-only variation" "rp $KK/core/Resolver.kt 'fun navEffective(' 'fun navEffective3('"
mutate state-variation-forever "variation state must be short-lived" "rp $CS 'liveVariation' 'liveVar'"
# --- safe area ---
mutate safe-corner-fn-removed "StripGeometry must define fun cornerInset(" "rp $CS 'fun cornerInset(' 'fun cornerInset3('"
mutate safe-view-no-padding "must derive safe areas from live insets" "rp $CV 'StripGeometry.contentPadding(' 'StripGeometry.contentPadding3('"
mutate safe-view-no-corners "must derive safe areas from live insets" "rp $CV 'getRoundedCorner(' 'getRoundedCorner3('"
mutate safe-view-no-cutout "must derive safe areas from live insets" "rp $CV 'WindowInsets.Type.displayCutout()' 'WindowInsets.Type.statusBars()'"
mutate safe-view-no-navbar "must derive safe areas from live insets" "rp $CV 'WindowInsets.Type.navigationBars()' 'WindowInsets.Type.statusBars()'"
mutate safe-hardcoded-profile "must not hard-code any device profile" "printf 'private val special = \"titan2\"\n' >> $CS"
mutate safe-hardcoded-elite "must not hard-code any device profile" "printf 'private val special = \"elite\"\n' >> $CV"
# --- height ---
mutate height-too-tall "must be at most a quarter" "rp $CS 'const val CHIP_HEIGHT_DP = 40' 'const val CHIP_HEIGHT_DP = 70'"
mutate height-formula-changed "height constants must be declared" "rp $CS 'const val HEIGHT_DP = CHIP_HEIGHT_DP + 2 * PAD_V_DP' 'const val HEIGHT_DP = 20'"
mutate height-keyboard-not-single-sourced "must take its row height from SoftKeyboardGeometry" "rp $KK/android/SoftKeyboardView.kt 'SoftKeyboardGeometry.ROW_HEIGHT_DP' '52'"
# --- privacy ---
mutate privacy-secret-fields-show-content "only in ordinary text fields" "rp $CS 'i.field != InputClass.Text -> StripContent.None' 'i.field == InputClass.None -> StripContent.None'"
mutate privacy-unbounded-candidates "content must be bounded" "rp $CS 'take(StripPolicy.MAX_CANDIDATES)' 'take(1000)'"
mutate privacy-unbounded-symbols "content must be bounded" "rp $CS 'take(StripPolicy.MAX_SYMBOLS)' 'take(1000)'"
mutate privacy-symbols-from-elsewhere "symbols must come only from the existing layout tables" "rp $CS 'table.values.distinct()' 'extraTable.values.distinct()'"
mutate privacy-logs "must not store or log anything" "printf 'private fun trace(x: String) { Log.d(\"s\", x) }\n' >> $CV"
mutate privacy-prefs-in-model "must not store or log anything" "printf 'private val p: SharedPreferences? = null\n' >> $CS"
# --- scope exclusions ---
mutate scope-shizuku "must not contain Shizuku" "printf 'val s = \"rikka.shizuku\"\n' >> $CS"
mutate scope-clipboard "must not contain clipboard access or history" "printf 'fun c(x: ClipboardManager) = Unit\n' >> $CV"
mutate scope-snippets "must not contain snippets" "printf 'val snippets = emptyList<String>()\n' >> $CS"
mutate scope-remapping "must not contain key remapping" "printf 'fun remapKey() = Unit\n' >> $KK/core/Resolver.kt"
mutate scope-learned-prediction "must not contain learned prediction" "printf 'val learnedWords = emptyList<String>()\n' >> $CS"
mutate scope-network "must not contain network access" "printf 'import java.net.URL\n' >> $CV"
mutate scope-pastiera-code "must not contain Pastiera/Plektra code" "printf 'import it.palsoftware.pastiera.Foo\n' >> $CS"
mutate scope-emoji-literal "must not contain emoji data" "python3 -c \"import sys; open('$CS','a').write('val e = \\\"' + chr(0x1F600) + '\\\"\\n')\""
mutate scope-emoji-asset "assets must stay the pinyin corpus only" "printf 'x\n' > apps/titan2/platform/keyboard/src/main/assets/emoji.tsv"
mutate scope-dependency "keyboard module dependencies changed" "rp $KG 'testImplementation(libs.junit)' 'testImplementation(libs.junit)
    implementation(libs.androidx.compose.ui)'"
mutate scope-permission "unexpected permissions" "rp $KM '<application' '<uses-permission android:name=\"android.permission.INTERNET\" /><application'"
# --- tests ---
mutate tests-too-few "CompactStripTest must keep at least 25 tests" "python3 - $TST <<'PY'
import sys
p=sys.argv[1]; s=open(p).read(); s=s.replace('@Test fun','fun',20); open(p,'w').write(s)
PY"
mutate tests-privacy-removed "missing required test secretAndNumericFieldsShowNoCandidatesVariationOrSymbols" "rp $TST 'fun secretAndNumericFieldsShowNoCandidatesVariationOrSymbols' 'fun renamedOne'"
mutate tests-nav-removed "missing required test navShowsActiveOrSuspendedHonestly" "rp $TST 'fun navShowsActiveOrSuspendedHonestly' 'fun renamedTwo'"
mutate tests-height-removed "missing required test stripUsesSubstantiallyLessHeightThanTheFullKeyboard" "rp $TST 'fun stripUsesSubstantiallyLessHeightThanTheFullKeyboard' 'fun renamedThree'"
mutate tests-emoji-removed "missing required test noEmojiIsOfferedBecauseNoProvenancedEmojiDataExists" "rp $TST 'fun noEmojiIsOfferedBecauseNoProvenancedEmojiDataExists' 'fun renamedFour'"
mutate tests-variation-removed "missing required test variationIsShortLived" "rp $TST 'fun variationIsShortLived' 'fun renamedFive'"
mutate tests-corner-removed "missing required test cornerInsetFollowsTheCircleAndVanishesAboveIt" "rp $TST 'fun cornerInsetFollowsTheCircleAndVanishesAboveIt' 'fun renamedSix'"
echo "C3B_D7B_CONTRACT_MUTATION_TESTS=$([[ $fail -eq 0 ]] && echo PASS || echo FAIL) count=$pass"
exit $((fail > 0))
