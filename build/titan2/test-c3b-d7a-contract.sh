#!/usr/bin/env bash
# Mutation tests for the D7A Camera Control Deck source contract in the static qualification gate.
# Developer-runnable, offline, no Gradle. Copies the tracked tree into a throw-away git repo, proves the baseline passes,
# then injects one violation at a time and requires the gate to fail with the matching STATIC_FAIL message.
#   build/titan2/test-c3b-d7a-contract.sh            (ONLY=<case-name> runs a single case)
# Marker on success: C3B_D7A_CONTRACT_MUTATION_TESTS=PASS count=N
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
grep -q '^D7A_CONTROL_DECK_SOURCE_CONTRACT=PASS' <<<"$out" || { echo "$out" | grep STATIC_FAIL | head; echo "C3B_D7A_CONTRACT_MUTATION_TESTS=FAIL_BASELINE" >&2; exit 1; }
for m in SABLE_CAMERA_CONTROL_DECK_MODEL=PASS SABLE_CAMERA_FIXED_CONTROL_MAP=PASS SABLE_CAMERA_TOUCH_FALLBACK=PASS SABLE_CAMERA_TRANSIENT_PARAMETER_UI=PASS SABLE_CAMERA_CONTROL_LEGEND=PASS SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK=PASS_ABSENT; do
    grep -q "^$m\$" <<<"$out" || { echo "C3B_D7A_CONTRACT_MUTATION_TESTS=FAIL_BASELINE_MARKER $m" >&2; exit 1; }
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
CK=apps/titan2/platform/camera/src/main/java/org/sableos/titan2/camera
CT=apps/titan2/platform/camera/src/test/java/org/sableos/titan2/camera/core
CM=apps/titan2/platform/camera/src/main/AndroidManifest.xml
CG=apps/titan2/platform/camera/build.gradle.kts
DOC=docs/SABLE_CAMERA_CONTROL_DECK_SOURCE.md
TST=$CT/ControlDeckTest.kt
# --- documented contract ---
mutate doc-missing "docs/SABLE_CAMERA_CONTROL_DECK_SOURCE.md missing" "git rm -q $DOC"
mutate doc-model-marker "must state SABLE_CAMERA_CONTROL_DECK_MODEL=PASS" "rp $DOC SABLE_CAMERA_CONTROL_DECK_MODEL=PASS SABLE_CAMERA_CONTROL_DECK_MODEL=SKIPPED"
mutate doc-landscape-marker "must state SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK=PASS_ABSENT" "rp $DOC SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK=PASS_ABSENT SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK=PASS"
mutate doc-runtime-validated "must state D7A_DEVICE_RUNTIME_VALIDATED=NO" "rp $DOC D7A_DEVICE_RUNTIME_VALIDATED=NO D7A_DEVICE_RUNTIME_VALIDATED=YES"
mutate doc-func-keys "must state D7A_FUNC_KEYS_BOUND=NO" "rp $DOC D7A_FUNC_KEYS_BOUND=NO D7A_FUNC_KEYS_BOUND=YES"
mutate doc-dependency-delta "must state D7A_DEPENDENCY_DELTA=NONE" "rp $DOC D7A_DEPENDENCY_DELTA=NONE D7A_DEPENDENCY_DELTA=ADDED"
mutate doc-new-modes "must state D7A_NEW_CAPTURE_MODES=NO" "rp $DOC D7A_NEW_CAPTURE_MODES=NO D7A_NEW_CAPTURE_MODES=YES"
mutate doc-af-lock-runtime "must state D7A_AF_AE_LOCK_RUNTIME_VALIDATED=NO" "rp $DOC D7A_AF_AE_LOCK_RUNTIME_VALIDATED=NO D7A_AF_AE_LOCK_RUNTIME_VALIDATED=YES"
mutate doc-runtime-marker-claimed "runtime camera marker must not be claimed" "printf 'SABLE_CAMERA_CONTROL_DECK_TITAN2=PASS\n' >> $DOC"
# --- semantic model / raw key separation ---
mutate model-dispatch-bypassed "must route every control through ControlDeck.dispatch" "rp $CK/ui/MainActivity.kt 'ControlDeck.dispatch(' 'ControlDeck.onAction('"
mutate model-local-key-table "must resolve key codes through RawKeys" "rp $CK/ui/MainActivity.kt 'RawKeys.nameOf(' 'localKeyName('"
mutate model-keycode-in-activity "raw Android key codes belong only in core/RawKeys.kt" "printf 'private val raw = KeyEvent.KEYCODE_SPACE\n' >> $CK/ui/MainActivity.kt"
mutate model-keycode-in-keymap "must not reference Android key codes" "rp $CK/core/KeyMap.kt 'object CameraKeyMap {' 'object CameraKeyMap {
    private const val RAW = KEYCODE_SPACE'"
mutate model-gate-removed "must define object ControlGate" "rp $CK/core/ControlDeck.kt 'object ControlGate' 'object ControlGat3'"
mutate model-state-removed "must define data class DeckState" "rp $CK/core/ControlDeck.kt 'data class DeckState' 'data class DeckStat3'"
mutate model-dispatch-fn-removed "must define fun dispatch(" "rp $CK/core/ControlDeck.kt 'fun dispatch(' 'fun dispatchX('"
mutate model-legend-file-removed "core/ControlLegend.kt is missing" "git rm -q $CK/core/ControlLegend.kt"
# --- fixed map ---
mutate map-focus-unbound "must bind f" "dl $CK/core/KeyMap.kt 'Binding(\"f\") to CameraAction.Autofocus'"
mutate map-focus-lock-name "stale FocusLock action name" "printf 'private val old = CameraAction.FocusLock\n' >> $CK/core/ActionRouter.kt"
mutate map-focus-not-autofocus "F must be the single-press Autofocus" "rp $CK/core/KeyMap.kt 'Binding(\"f\") to CameraAction.Autofocus' 'Binding(\"f\") to CameraAction.ZoomIn'"
mutate map-iso-unbound "must bind i" "rp $CK/core/KeyMap.kt ' Binding(\"i\") to CameraAction.SelectIso,' ''"
mutate map-help-unbound "must bind h" "dl $CK/core/KeyMap.kt 'Binding(\"h\") to CameraAction.ToggleLegend'"
mutate map-alt-e-removed "must keep Alt+E" "rp $CK/core/KeyMap.kt 'Binding(\"e\", alt = true)' 'Binding(\"x\", alt = true)'"
mutate map-func1-bound "Func1/Func2 must stay unbound" "rp $CK/core/KeyMap.kt 'Binding(\"escape\") to CameraAction.Back,' 'Binding(\"func1\") to CameraAction.Shutter, Binding(\"escape\") to CameraAction.Back,'"
mutate map-func2-keycode "Func1/Func2 must stay unbound" "rp $CK/core/RawKeys.kt 'KEYCODE_SLASH to \"slash\"' 'KEYCODE_SLASH to \"slash\", 132 to \"func2\"'"
mutate map-user-remapping "must be fixed: no user remapping" "printf 'private val prefs: SharedPreferences? = null\n' >> $CK/core/KeyMap.kt"
mutate map-second-standard "exactly one fixed standard camera map" "printf 'val standard: Map<Binding, CameraAction> = emptyMap()\n' >> $CK/core/KeyMap.kt"
# --- touch fallback ---
mutate touch-exempts-shutter "may exempt only the system Back action" "rp $CK/core/ControlLegend.kt 'setOf(CameraAction.Back)' 'setOf(CameraAction.Back, CameraAction.Shutter)'"
mutate touch-bar-removed "must render TouchControlBar" "rp $CK/ui/MainActivity.kt 'TouchControlBar(TouchFallback' 'Unit; TouchFallback'"
mutate touch-separate-handler "must invoke the shared action handler" "rp $CK/ui/MainActivity.kt 'onAction(c.action)' 'run {}'"
mutate touch-keys-skip-act "physical keys must reach act()" "rp $CK/ui/MainActivity.kt 'if (!ignoredRepeat) act(action)' 'if (!ignoredRepeat) Unit'"
mutate touch-portrait-hides-chrome "portrait must always show touch controls" "rp $CK/core/ControlDeck.kt 'p == DeckPresentation.Portrait ||' 'false ||'"
mutate touch-chrome-not-from-model "touch chrome visibility must come from DeckOrientation" "rp $CK/ui/MainActivity.kt 'DeckOrientation.touchChromeVisible(' 'visibleChrome('"
# --- transient parameter UI ---
mutate strip-no-timeout "parameter strips must expire" "rp $CK/core/ControlDeck.kt 'const val STRIP_TIMEOUT_MS' 'const val STRIP_TIMEOUT_X'"
mutate strip-no-tick "parameter strips must expire" "rp $CK/core/ControlDeck.kt 'fun tick(' 'fun tickX('"
mutate strip-overlay-removed "must show the transient strip overlay" "rp $CK/ui/MainActivity.kt '            DeckOverlays(' '            DeckOverlaysX('"
mutate strip-expiry-removed "must show the transient strip overlay" "rp $CK/ui/MainActivity.kt 'StripExpiry(deck)' 'Unit.let(deck)'"
mutate strip-permanent-pro-row "permanent Pro strip must stay removed" "printf '@androidx.compose.runtime.Composable\nfun ProStrip() {}\n' >> $CK/ui/MainActivity.kt"
mutate strip-not-shown-after-command "must show the strip a command adjusted" "rp $CK/ui/MainActivity.kt 'ParameterStrips.after(' 'ParameterStrips.afterX('"
mutate strip-not-capability-gated "strips must be capability-gated" "dl $CK/core/ControlDeck.kt 'if (!l.offers(f)) return null'"
# --- legend ---
mutate legend-not-generated "must be generated from ControlLegend.entries" "rp $CK/ui/MainActivity.kt 'ControlLegend.entries(' 'ControlLegendX.entries('"
mutate legend-no-back-dismiss "must be dismissible by keyboard" "rp $CK/core/ControlDeck.kt 'fun onBack(' 'fun onBackX('"
mutate legend-no-touch-dismiss "must be dismissible by keyboard" "python3 - $CK/ui/MainActivity.kt <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read(); s=s.replace('dismissLegend','dismissX'); open(p,'w').write(s)
PY"
mutate legend-no-help-entry "must list its own help action" "rp $CK/core/ControlLegend.kt 'CameraAction.ToggleLegend,' 'CameraAction.Back,'"
# --- orientation ---
mutate orient-manifest-landscape "must not lock orientation" "rp $CM 'android:screenOrientation=\"unspecified\"' 'android:screenOrientation=\"sensorLandscape\"'"
mutate orient-manifest-portrait "must not lock orientation" "rp $CM 'android:screenOrientation=\"unspecified\"' 'android:screenOrientation=\"portrait\"'"
mutate orient-requested "must not set or lock the activity orientation" "printf 'fun lock(a: Any) { a.requestedOrientation = 0 }\n' >> $CK/ui/MainActivity.kt"
mutate orient-constant "must not set or lock the activity orientation" "printf 'val o = SCREEN_ORIENTATION_LANDSCAPE\n' >> $CK/ui/MainActivity.kt"
mutate orient-policy-flag "must keep ORIENTATION_POLICY=AUTO" "rp $CK/core/ControlDeck.kt 'GLOBAL_LANDSCAPE_LOCK = false' 'GLOBAL_LANDSCAPE_LOCK = true'"
mutate orient-policy-value "must keep ORIENTATION_POLICY=AUTO" "rp $CK/core/ControlDeck.kt 'ORIENTATION_POLICY = \"AUTO\"' 'ORIENTATION_POLICY = \"LANDSCAPE\"'"
# --- scope: no new modes, no vendor/privileged camera, no new dependency ---
mutate scope-new-ui-mode "UiMode must stay exactly Video, Photo, Pro" "rp $CK/core/ActionRouter.kt 'Pro(\"Pro\") }' 'Pro(\"Pro\"), Night(\"Night\") }'"
mutate scope-new-capture-mode "CaptureMode must stay" "rp $CK/core/Model.kt 'enum class CaptureMode { Auto, HighRes, Raw, Pro, Tele }' 'enum class CaptureMode { Auto, HighRes, Raw, Pro, Tele, Burst }'"
mutate scope-system-camera "unexpected permissions" "rp $CM '<uses-permission android:name=\"android.permission.CAMERA\" />' '<uses-permission android:name=\"android.permission.CAMERA\" /><uses-permission android:name=\"android.permission.SYSTEM_CAMERA\" />'"
mutate scope-gcam "must not use SYSTEM_CAMERA, GCam or vendor camera code" "printf 'val g = \"GoogleCamera\"\n' >> $CK/android/SysProps.kt"
mutate scope-timelapse "must not add timelapse, burst or computational HDR" "printf 'fun burst() = Unit\n' >> $CK/android/SysProps.kt"
mutate scope-new-dependency "camera module dependencies changed" "rp $CG 'testImplementation(libs.junit)' 'testImplementation(libs.junit)
    implementation(libs.androidx.compose.ui.tooling)'"
# --- tests ---
mutate tests-too-few "ControlDeckTest must keep at least 40 tests" "python3 - $TST <<'PY'
import sys
p=sys.argv[1]; s=open(p).read(); s=s.replace('@Test fun','fun',30); open(p,'w').write(s)
PY"
mutate tests-touch-parity-removed "missing required test touchCoversEveryActionExceptSystemBack" "rp $TST 'fun touchCoversEveryActionExceptSystemBack' 'fun renamedOne'"
mutate tests-func-keys-removed "missing required test func1AndFunc2StayUnboundEverywhere" "rp $TST 'fun func1AndFunc2StayUnboundEverywhere' 'fun renamedTwo'"
mutate tests-expiry-removed "missing required test stripIsTransientAndExpires" "rp $TST 'fun stripIsTransientAndExpires' 'fun renamedThree'"
mutate tests-orientation-removed "missing required test orientationPolicyIsAutoAndNeverLocked" "rp $TST 'fun orientationPolicyIsAutoAndNeverLocked' 'fun renamedFour'"
mutate tests-no-new-modes-removed "missing required test deckAddsNoCaptureModes" "rp $TST 'fun deckAddsNoCaptureModes' 'fun renamedFive'"
echo "C3B_D7A_CONTRACT_MUTATION_TESTS=$([[ $fail -eq 0 ]] && echo PASS || echo FAIL) count=$pass"
exit $((fail > 0))
