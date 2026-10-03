#!/usr/bin/env bash
# Mutation tests for the D8 Setup helper source contract in the static qualification gate.
# Developer-runnable, offline, no Gradle. Copies the tracked tree into a throw-away git repo, proves the baseline passes,
# then injects one violation at a time and requires the gate to fail with the matching STATIC_FAIL message.
#   build/titan2/test-c3b-d8-contract.sh            (ONLY=<case-name> runs a single case)
# Marker on success: C3B_D8_CONTRACT_MUTATION_TESTS=PASS count=N
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
grep -q '^D8_SETUP_HELPER_SOURCE_CONTRACT=PASS' <<<"$out" || { echo "$out" | grep STATIC_FAIL | head; echo "C3B_D8_CONTRACT_MUTATION_TESTS=FAIL_BASELINE" >&2; exit 1; }
grep -q "^STATIC_FAIL:" <<<"$out" && { grep "^STATIC_FAIL:" <<<"$out" | head -3; echo "C3B_D8_CONTRACT_MUTATION_TESTS=FAIL_BASELINE_STATIC" >&2; exit 1; }
for m in SABLE_SETUP_READINESS_MODEL=PASS SABLE_SETUP_LAUNCH_SAFETY=PASS SABLE_SETUP_WORDING=PASS SABLE_SETUP_DEFAULT_APP_TRUTHFULNESS=PASS SABLE_SETUP_PROFILE_UNKNOWN=PASS SABLE_SETUP_SCOPE=PASS_EXCLUSIONS_ABSENT; do
    grep -q "^$m\$" <<<"$out" || { echo "C3B_D8_CONTRACT_MUTATION_TESTS=FAIL_BASELINE_MARKER $m" >&2; exit 1; }
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
lines = open(p).read().split("\n")
kept = [line for line in lines if pat not in line]
if len(kept) == len(lines):
    sys.exit("MUTATION_TARGET_MISSING: " + pat)
open(p, "w").write("\n".join(kept))
PY
}
# rpa FILE OLD NEW: replace every occurrence (for names that appear in an import and in use).
rpa() { python3 - "$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if old not in s:
    sys.exit("MUTATION_TARGET_MISSING: " + old)
open(p, "w").write(s.replace(old, new))
PY
}
irclose() { python3 - docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv "$1" <<'PY'
import sys
p, rid = sys.argv[1:3]
L = open(p).read().split("\n"); h = L[0].split("\t")
for i, l in enumerate(L):
    if l.startswith(rid + "\t"):
        c = l.split("\t"); c[h.index("status")] = "CLOSED"; L[i] = "\t".join(c)
open(p, "w").write("\n".join(L))
PY
}
PUT_="p""ut"
SK=apps/titan2/platform/setup/src/main/java/org/sableos/titan2/setup
ST=apps/titan2/platform/setup/src/test/java/org/sableos/titan2/setup
SM=apps/titan2/platform/setup/src/main/AndroidManifest.xml
SG=apps/titan2/platform/setup/build.gradle.kts
DOC=docs/C3B_D8_SETUP_HELPER_HARDENING.md
KLD=docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md
RDN=$SK/core/Readiness.kt; ROWS=$SK/core/SetupRows.kt; SMOD=$SK/core/SetupModel.kt; LREP=$SK/core/LaunchReport.kt
LAUN=$SK/android/Launcher.kt; SACT=$SK/android/SetupActivity.kt; SRD=$SK/android/SetupReader.kt; SYS=$SK/android/SysProps.kt; TST=$ST/SetupHardeningTest.kt
mutate doc-missing 'docs/C3B_D8_SETUP_HELPER_HARDENING.md missing' 'git rm -q $DOC'
mutate doc-sable-setup-readiness-model 'must state SABLE_SETUP_READINESS_MODEL=PASS' 'rp $DOC SABLE_SETUP_READINESS_MODEL=PASS SABLE_SETUP_READINESS_MODEL=SKIPPED'
mutate doc-sable-setup-launch-safety 'must state SABLE_SETUP_LAUNCH_SAFETY=PASS' 'rp $DOC SABLE_SETUP_LAUNCH_SAFETY=PASS SABLE_SETUP_LAUNCH_SAFETY=SKIPPED'
mutate doc-sable-setup-wording 'must state SABLE_SETUP_WORDING=PASS' 'rp $DOC SABLE_SETUP_WORDING=PASS SABLE_SETUP_WORDING=SKIPPED'
mutate doc-sable-setup-default-app-truthfulness 'must state SABLE_SETUP_DEFAULT_APP_TRUTHFULNESS=PASS' 'rp $DOC SABLE_SETUP_DEFAULT_APP_TRUTHFULNESS=PASS SABLE_SETUP_DEFAULT_APP_TRUTHFULNESS=SKIPPED'
mutate doc-sable-setup-profile-unknown 'must state SABLE_SETUP_PROFILE_UNKNOWN=PASS' 'rp $DOC SABLE_SETUP_PROFILE_UNKNOWN=PASS SABLE_SETUP_PROFILE_UNKNOWN=SKIPPED'
mutate doc-sable-setup-scope 'must state SABLE_SETUP_SCOPE=PASS_EXCLUSIONS_ABSENT' 'rp $DOC SABLE_SETUP_SCOPE=PASS_EXCLUSIONS_ABSENT SABLE_SETUP_SCOPE=PASS'
mutate doc-d8-device-runtime-validated 'must state D8_DEVICE_RUNTIME_VALIDATED=NO' 'rp $DOC D8_DEVICE_RUNTIME_VALIDATED=NO D8_DEVICE_RUNTIME_VALIDATED=YES'
mutate doc-d8-dependency-delta 'must state D8_DEPENDENCY_DELTA=NONE' 'rp $DOC D8_DEPENDENCY_DELTA=NONE D8_DEPENDENCY_DELTA=ADDED'
mutate doc-d8-setup-wizard-claimed 'must state D8_SETUP_WIZARD_CLAIMED=NO' 'rp $DOC D8_SETUP_WIZARD_CLAIMED=NO D8_SETUP_WIZARD_CLAIMED=YES'
mutate doc-d8-setting-mutation 'must state D8_SETTING_MUTATION=NO' 'rp $DOC D8_SETTING_MUTATION=NO D8_SETTING_MUTATION=YES'
mutate doc-d8-role-mutation 'must state D8_ROLE_MUTATION=NO' 'rp $DOC D8_ROLE_MUTATION=NO D8_ROLE_MUTATION=YES'
mutate doc-d8-new-permissions 'must state D8_NEW_PERMISSIONS=NONE' 'rp $DOC D8_NEW_PERMISSIONS=NONE D8_NEW_PERMISSIONS=READ_PHONE_STATE'
mutate doc-d8-hidden-property-expansion 'must state D8_HIDDEN_PROPERTY_EXPANSION=NO' 'rp $DOC D8_HIDDEN_PROPERTY_EXPANSION=NO D8_HIDDEN_PROPERTY_EXPANSION=YES'
mutate doc-ir-001-status 'must state IR_001_STATUS=OPEN_CANONICAL' 'rp $DOC IR_001_STATUS=OPEN_CANONICAL IR_001_STATUS=CLOSED'
mutate doc-ir-003-status 'must state IR_003_STATUS=OPEN_CANONICAL' 'rp $DOC IR_003_STATUS=OPEN_CANONICAL IR_003_STATUS=CLOSED'
mutate doc-ir-005-status 'must state IR_005_STATUS=OPEN_CANONICAL' 'rp $DOC IR_005_STATUS=OPEN_CANONICAL IR_005_STATUS=CLOSED'
mutate doc-kl-005-status 'must state KL_005_STATUS=OPEN_CANONICAL' 'rp $DOC KL_005_STATUS=OPEN_CANONICAL KL_005_STATUS=CLOSED'
mutate ledger-ir001-closed 'IR-001 must stay OPEN' 'irclose IR-001'
mutate ledger-ir003-closed 'IR-003 must stay OPEN' 'irclose IR-003'
mutate ledger-ir005-closed 'IR-005 must stay OPEN' 'irclose IR-005'
mutate ledger-kl033-removed 'KL-033 (D8 Setup helper' 'dl $KLD '"'"'| KL-033 |'"'"''
mutate ledger-kl005-removed 'KL-005 (Setup helper is not the Setup Wizard) must stay open' 'dl $KLD '"'"'| KL-005 |'"'"''
mutate model-state-satisfied-removed 'Readiness must keep the Satisfied state' 'rp $RDN '"'"'    Satisfied,'"'"' '"'"'    Satisfied3,'"'"''
mutate model-state-actionrequired-removed 'Readiness must keep the ActionRequired state' 'rp $RDN '"'"'    ActionRequired,'"'"' '"'"'    ActionRequired3,'"'"''
mutate model-state-informational-removed 'Readiness must keep the Informational state' 'rp $RDN '"'"'    Informational,'"'"' '"'"'    Informational3,'"'"''
mutate model-state-unavailable-removed 'Readiness must keep the Unavailable state' 'rp $RDN '"'"'    Unavailable,'"'"' '"'"'    Unavailable3,'"'"''
mutate model-state-unknown-removed 'Readiness must keep the Unknown state' 'rp $RDN '"'"'    Unknown
}'"'"' '"'"'    Unsure
}'"'"''
mutate model-observed-failed-removed 'Observed must keep object Failed' 'rp $RDN '"'"'object Failed'"'"' '"'"'object Broke'"'"''
mutate model-observed-absent-removed 'Observed must keep object Absent' 'rp $RDN '"'"'object Absent'"'"' '"'"'object Nothing'"'"''
mutate model-legacy-state-returns 'Done/Todo/Info state model must not return' 'rp $ROWS '"'"'object SetupRows {'"'"' '"'"'enum class State { Done, Todo, Info }

object SetupRows {'"'"''
mutate model-failed-home-informational 'every failed read in SetupRows must become Readiness.Unknown' 'rp $ROWS '"'"'"Could not read the home app",
                Readiness.Unknown'"'"' '"'"'"Could not read the home app",
                Readiness.Informational'"'"''
mutate model-failed-keyboard-action-required 'every failed read in SetupRows must become Readiness.Unknown' 'rp $ROWS '"'"'"Could not read the keyboard setting",
                    Readiness.Unknown'"'"' '"'"'"Could not read the keyboard setting",
                    Readiness.ActionRequired'"'"''
mutate model-failed-default-satisfied 'every failed read in SetupRows must become Readiness.Unknown' 'rp $ROWS '"'"'"Could not read the default app",
                Readiness.Unknown'"'"' '"'"'"Could not read the default app",
                Readiness.Satisfied'"'"''
mutate model-summary-drops-unknown 'summary and isReady must account for unavailable and unknown' 'rp $SMOD '"'"'Readiness.Unknown to "unknown"'"'"' '"'"'Readiness.Unknown to "unk"'"'"''
mutate model-summary-drops-unavailable 'summary and isReady must account for unavailable and unknown' 'rp $SMOD '"'"'Readiness.Unavailable to "unavailable"'"'"' '"'"'Readiness.Unavailable to "unavail"'"'"''
mutate model-isready-ignores-unknown 'isReady must be false for action-required, unavailable and unknown' 'rp $SMOD '"'"'
            it.state == Readiness.Unknown
'"'"' '"'"'
            false
'"'"''
mutate model-isready-ignores-unavailable 'isReady must be false for action-required, unavailable and unknown' 'rp $SMOD '"'"'it.state == Readiness.Unavailable ||'"'"' '"'"'false ||'"'"''
mutate model-activity-not-using-rows 'SetupActivity must render from SetupReader' 'rp $SACT '"'"'SetupRows.build('"'"' '"'"'SetupRows3.build('"'"''
mutate model-activity-not-using-reader 'SetupActivity must render from SetupReader' 'rp $SACT '"'"'SetupReader(this).snapshot()'"'"' '"'"'Snapshot3()'"'"''
mutate model-activity-not-using-summary 'SetupActivity must render from SetupReader' 'rp $SACT '"'"'SetupModel.summary('"'"' '"'"'SetupModel.summary3('"'"''
mutate model-activity-not-using-isready 'SetupActivity must render from SetupReader' 'rp $SACT '"'"'SetupModel.isReady('"'"' '"'"'SetupModel.isReady3('"'"''
mutate launch-no-not-found-handler 'Launcher must handle ActivityNotFoundException' 'rpa $LAUN ActivityNotFoundException ActivityNotFound3'
mutate launch-no-security-handler 'Launcher must handle SecurityException' 'rpa $LAUN SecurityException SecurityExcept3'
mutate launch-no-resolve 'Launcher must handle resolveActivity(' 'rpa $LAUN '"'"'resolveActivity('"'"' '"'"'resolveActivity3('"'"''
mutate launch-denied-merged 'Launcher must handle LaunchOutcome.Denied' 'rpa $LAUN LaunchOutcome.Denied LaunchOutcome.Failed'
mutate launch-apply-target-removed 'SetupRows.build must apply the resolved target status' 'rp $ROWS '"'"'.map { applyTarget('"'"' '"'"'.map { keep('"'"''
mutate launch-unverifiable-treated-usable 'unverifiable launch targets must fail closed' 'rp $ROWS '"'"'status == TargetStatus.Unverifiable ->'"'"' '"'"'status == TargetStatus.Missing ->'"'"''
mutate launch-unverifiable-action-restored 'unverifiable launch targets must fail closed' 'rpa $ROWS '"'"'action = Action.None'"'"' '"'"'action = item.action'"'"''
mutate launch-activity-skips-resolve 'SetupActivity must resolve targets through Launcher' 'rp $SACT launcher::resolve '"'"'{ _ -> TargetStatus.Resolvable }'"'"''
mutate launch-activity-skips-report 'SetupActivity must resolve targets through Launcher' 'rp $SACT '"'"'LaunchReport.message('"'"' '"'"'LaunchReport.message3('"'"''
mutate launch-silent-runcatching 'must not be silently swallowed' 'rp $SACT '"'"'        super.onResume()'"'"' '"'"'        super.onResume()
        runCatching { render(null) }'"'"''
mutate launch-silent-let-start 'must not be silently swallowed' 'rp $SACT '"'"'        super.onResume()'"'"' '"'"'        super.onResume()
        intent?.let { startActivity(it) }'"'"''
mutate launch-direct-start-activity 'SetupActivity must launch only through Launcher' 'rp $SACT '"'"'        super.onResume()'"'"' '"'"'        super.onResume()
        startActivity(android.content.Intent())'"'"''
mutate launch-report-carries-exception 'must bound the message and never carry exception text' 'rp $LREP '"'"'        val name = '"'"' '"'"'        val cause: Throwable? = null
        val name = '"'"''
mutate launch-report-unbounded 'must bound the message and never carry exception text' 'rp $LREP '"'"'return text.take(MAX_MESSAGE)'"'"' '"'"'return text'"'"''
mutate launch-manifest-query-home_settings 'queries entry for android.settings.HOME_SETTINGS' 'dl $SM '"'"'android.settings.HOME_SETTINGS'"'"''
mutate launch-manifest-query-manage_default_apps_settings 'queries entry for android.settings.MANAGE_DEFAULT_APPS_SETTINGS' 'dl $SM '"'"'android.settings.MANAGE_DEFAULT_APPS_SETTINGS'"'"''
mutate launch-manifest-query-wireless_settings 'queries entry for android.settings.WIRELESS_SETTINGS' 'dl $SM '"'"'android.settings.WIRELESS_SETTINGS'"'"''
mutate wording-radio-ims-status 'RadioDiag row must say IMS registration visibility requires canonical IR-007' 'rp $ROWS '"'"'Read-only SIM and network diagnostics; IMS registration visibility requires canonical IR-007'"'"' '"'"'Read-only SIM, network and IMS status'"'"''
mutate wording-radio-ir007-dropped 'RadioDiag row must say IMS registration visibility requires canonical IR-007' 'rp $ROWS '"'"'requires canonical IR-007'"'"' '"'"'is available'"'"''
mutate wording-radio-title-claims-ims 'must not imply that IMS registration is visible' 'rp $ROWS '"'"'"radio",
            "Radio diagnostics"'"'"' '"'"'"radio",
            "Radio and IMS diagnostics"'"'"''
mutate wording-ims-registered 'must not imply that IMS registration is visible' 'rp $ROWS '"'"'"Opens Android Settings"'"'"' '"'"'"IMS registered"'"'"''
mutate wording-wizard-disclaimer-removed 'must describe itself as a post-provisioning helper' 'rp $SMOD '"'"'Not the Android Setup Wizard'"'"' '"'"'The Android Setup Wizard'"'"''
mutate wording-post-provisioning-removed 'must describe itself as a post-provisioning helper' 'rp $SMOD '"'"'Post-provisioning readiness helper.'"'"' '"'"'Readiness helper.'"'"''
mutate wording-first-boot-claim 'must not claim first-boot or provisioning authority' 'rp $SMOD '"'"'Post-provisioning readiness helper.'"'"' '"'"'Post-provisioning first-boot helper.'"'"''
mutate wording-provisioned-claim 'must not claim first-boot or provisioning authority' 'rp $ROWS '"'"'"Opens Android Settings"'"'"' '"'"'"Device provisioned"'"'"''
mutate wording-self-description-hidden 'SetupActivity must show the helper self-description' 'rp $SACT SetupModel.SELF_DESCRIPTION SetupModel.TITLE'
mutate default-claim-dropped 'Phone/Messages rows must say only that a default app is configured' 'rp $ROWS '"'"'A default app is configured'"'"' '"'"'The default app is set'"'"''
mutate default-scope-note-dropped 'Phone/Messages rows must say only that a default app is configured' 'rp $ROWS '"'"'(not checked against a specific app)'"'"' '"'"'(verified)'"'"''
mutate default-called-correct 'must not call a state correct or derive success' 'rp $ROWS '"'"'No default app is configured'"'"' '"'"'The correct default app'"'"''
mutate default-doneif-returns 'must not call a state correct or derive success' 'rp $ROWS '"'"'object SetupRows {'"'"' '"'"'object SetupRows {
    fun doneIf(b: Boolean) = b'"'"''
mutate default-keyboard-any-package 'the keyboard row must test the Sable keyboard package explicitly' 'rp $ROWS '"'"'startsWith("$SABLE_KEYBOARD_PACKAGE/")'"'"' '"'"'isNotEmpty()'"'"''
mutate default-home-judged 'the HOME row must stay informational' 'rp $ROWS '"'"'Item("home", "Home screen", o.text, Readiness.Informational,'"'"' '"'"'Item("home", "Home screen", o.text, Readiness.Satisfied,'"'"''
mutate default-role-mutation 'must not mutate roles or settings' 'rp $SACT '"'"'        super.onResume()'"'"' '"'"'        super.onResume()
        getSystemService(android.app.role.RoleManager::class.java)'"'"''
mutate default-setting-write 'must not mutate roles or settings' "rp \$SRD 'fun snapshot(): Snapshot' 'fun poke() { Settings.Secure.${PUT_}String(context.contentResolver, \"k\", \"v\") }
    fun snapshot(): Snapshot'"
mutate profile-blank-not-unknown 'a blank or unreadable profile id must be an explicit unknown' 'rp $SMOD '"'"'Profile unknown (not reported by this build)'"'"' '"'"'Unknown profile'"'"''
mutate profile-nullable-dropped 'a blank or unreadable profile id must be an explicit unknown' 'rp $SMOD '"'"'fun profileLine(id: String?)'"'"' '"'"'fun profileLine(id: String)'"'"''
mutate profile-read-removed 'must keep the single provisional ro.sable.profile.id read' 'rp $SACT '"'"'SysProps.get("ro.sable.profile.id")'"'"' '"'"'SysProps.get("ro.sable.profile")'"'"''
mutate profile-extra-property 'must not read any property other than ro.sable.profile.id' 'rp $SRD '"'"'fun snapshot(): Snapshot'"'"' '"'"'fun extra() = SysProps.get("ro.product.device")
    fun snapshot(): Snapshot'"'"''
mutate profile-device-name-branch 'must not branch on a device name' 'rp $SMOD '"'"'        val clean = id?.trim().orEmpty()'"'"' '"'"'        val clean = id?.trim().orEmpty() + android.os.Build.MODEL'"'"''
mutate profile-reflection-elsewhere 'hidden-API reflection must stay limited to SysProps' 'rp $SRD '"'"'fun snapshot(): Snapshot'"'"' '"'"'fun hid() = Class.forName("x")
    fun snapshot(): Snapshot'"'"''
mutate scope-dependency-added 'setup module dependencies changed' 'rp $SG '"'"'    testImplementation(libs.junit)'"'"' '"'"'    implementation(libs.androidx.appcompat)
    testImplementation(libs.junit)'"'"''
mutate scope-permission-added 'must declare no permission' 'rp $SM '"'"'<uses-feature'"'"' '"'"'<uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-feature'"'"''
mutate scope-wizard-ownership 'must not take on Setup Wizard or provisioning-state ownership' 'rp $SRD '"'"'fun snapshot(): Snapshot'"'"' '"'"'fun p() = Settings.Secure.getInt(context.contentResolver, "user_setup_complete")
    fun snapshot(): Snapshot'"'"''
mutate scope-network 'must not use the network' 'rp $SRD '"'"'fun snapshot(): Snapshot'"'"' '"'"'fun n() = java.net.URL("x")
    fun snapshot(): Snapshot'"'"''
mutate tests-too-few 'SetupHardeningTest must keep at least 30 tests' 'python3 - $TST <<'"'"'PY'"'"'
import sys
p=sys.argv[1]; s=open(p).read(); s=s.replace('"'"'@Test fun'"'"','"'"'fun'"'"',10); open(p,'"'"'w'"'"').write(s)
PY'
mutate tests-failed-reads-are-unknown-never-satisfied-or-acti-removed 'missing required test failedReadsAreUnknownNeverSatisfiedOrActionRequired' 'rp $TST '"'"'fun failedReadsAreUnknownNeverSatisfiedOrActionRequired'"'"' '"'"'fun renamedfai'"'"''
mutate tests-summary-names-unavailable-and-unknown-rows-removed 'missing required test summaryNamesUnavailableAndUnknownRows' 'rp $TST '"'"'fun summaryNamesUnavailableAndUnknownRows'"'"' '"'"'fun renamedsum'"'"''
mutate tests-missing-target-on-informational-row-is-visible-a-removed 'missing required test missingTargetOnInformationalRowIsVisibleAsUnavailable' 'rp $TST '"'"'fun missingTargetOnInformationalRowIsVisibleAsUnavailable'"'"' '"'"'fun renamedmis'"'"''
mutate tests-an-absurdly-long-label-cannot-unbound-the-messag-removed 'missing required test anAbsurdlyLongLabelCannotUnboundTheMessage' 'rp $TST '"'"'fun anAbsurdlyLongLabelCannotUnboundTheMessage'"'"' '"'"'fun renamedanA'"'"''
mutate tests-every-ims-mention-is-the-ir007-qualifier-removed 'missing required test everyImsMentionIsTheIr007Qualifier' 'rp $TST '"'"'fun everyImsMentionIsTheIr007Qualifier'"'"' '"'"'fun renamedeve'"'"''
mutate tests-no-text-claims-wizard-first-boot-or-provisioning-removed 'missing required test noTextClaimsWizardFirstBootOrProvisioningAuthority' 'rp $TST '"'"'fun noTextClaimsWizardFirstBootOrProvisioningAuthority'"'"' '"'"'fun renamednoT'"'"''
mutate tests-dialer-and-sms-only-claim-that-a-default-app-is--removed 'missing required test dialerAndSmsOnlyClaimThatADefaultAppIsConfigured' 'rp $TST '"'"'fun dialerAndSmsOnlyClaimThatADefaultAppIsConfigured'"'"' '"'"'fun renameddia'"'"''
mutate tests-blank-null-and-whitespace-profiles-are-explicit--removed 'missing required test blankNullAndWhitespaceProfilesAreExplicitUnknown' 'rp $TST '"'"'fun blankNullAndWhitespaceProfilesAreExplicitUnknown'"'"' '"'"'fun renamedbla'"'"''
mutate tests-unavailable-or-unknown-rows-block-ready-removed 'missing required test unavailableOrUnknownRowsBlockReady' 'rp $TST '"'"'fun unavailableOrUnknownRowsBlockReady'"'"' '"'"'fun renameduna'"'"''
mutate tests-unverifiable-target-is-not-offered-as-usable-removed 'missing required test unverifiableTargetIsNotOfferedAsUsable' 'rp $TST '"'"'fun unverifiableTargetIsNotOfferedAsUsable'"'"' '"'"'fun renamedunv'"'"''
mutate tests-unverifiable-fix-target-keeps-evidence-removed 'missing required test unverifiableFixTargetKeepsTheEvidenceButRemovesTheButton' 'rp $TST '"'"'fun unverifiableFixTargetKeepsTheEvidenceButRemovesTheButton'"'"' '"'"'fun renamedunf'"'"''
echo "C3B_D8_CONTRACT_MUTATION_TESTS=$([[ $fail -eq 0 ]] && echo PASS || echo FAIL) count=$pass"
exit $((fail > 0))
