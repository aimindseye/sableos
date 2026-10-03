#!/usr/bin/env bash
# Mutation tests for the D6 RadioDiag and DisplayCompat hardening contract in the static qualification gate.
# Developer-runnable, offline, no Gradle. Copies the tracked tree into a throw-away git repo, proves the baseline passes,
# then injects one violation at a time and requires the gate to fail with the matching STATIC_FAIL message.
#   build/titan2/test-c3b-d6-contract.sh            (ONLY=<case-name> runs a single case)
# Marker on success: C3B_D6_CONTRACT_MUTATION_TESTS=PASS count=N
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
grep -q '^D6_HARDENING_SOURCE_CONTRACT=PASS' <<<"$out" || { echo "$out" | grep STATIC_FAIL | head; echo "C3B_D6_CONTRACT_MUTATION_TESTS=FAIL_BASELINE" >&2; exit 1; }
pass=0; fail=0
mutate() { # name expected-substring shell-snippet
    local name="$1" want="$2" snippet="$3"
    [[ -z "${ONLY:-}" || "$name" == "$ONLY" ]] || return 0
    git reset -q --hard HEAD; git clean -fdq
    eval "$snippet"
    git add -A
    local o rc; o="$(run_gate)"; rc=$?
    if (( rc != 0 )) && grep -q "STATIC_FAIL:.*$want" <<<"$o"; then pass=$((pass+1)); echo "OK   $name"; else fail=$((fail+1)); echo "MISS $name (rc=$rc, wanted STATIC_FAIL containing: $want)" >&2; grep STATIC_FAIL <<<"$o" >&2; fi
}
# Violation strings are assembled at run time so this test file does not itself contain the forbidden patterns.
SD="setDataEn""abled"
SG="Settings.Glo""bal.putInt"
RDK=apps/titan2/platform/radiodiag/src
DCK=apps/titan2/platform/displaycompat/src
RDM=$RDK/main/AndroidManifest.xml
DCM=$DCK/main/AndroidManifest.xml
RDP=$RDK/main/java/org/sableos/titan2/radiodiag
DCP=$DCK/main/java/org/sableos/titan2/displaycompat
D6=docs/C3B_D6_HARDENING.md
IRT=docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv
KLD=docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md
mutate radio-privileged-permission "RadioDiag must request exactly" "sed -i 's#<uses-permission android:name=\"android.permission.READ_BASIC_PHONE_STATE\" />#&<uses-permission android:name=\"android.permission.READ_PRIVILEGED_PHONE_STATE\" />#' $RDM"
mutate radio-permission-removed "RadioDiag must request exactly" "sed -i '/READ_BASIC_PHONE_STATE/d' $RDM"
mutate radio-extra-normal-permission "RadioDiag must request exactly" "sed -i 's#<uses-permission android:name=\"android.permission.READ_BASIC_PHONE_STATE\" />#&<uses-permission android:name=\"android.permission.READ_PHONE_STATE\" />#' $RDM"
mutate displaycompat-permission "DisplayCompat must request no permission" "sed -i 's#<queries>#<uses-permission android:name=\"android.permission.WRITE_SECURE_SETTINGS\" /><queries>#' $DCM"
mutate radio-limits-ims-wording "RadioReport must always state NOT_VISIBLE" "sed -i 's/NOT_VISIBLE/VISIBLE/' $RDP/core/RadioReport.kt"
mutate radio-limits-ir007 "RadioReport must always state IR-007" "sed -i 's/IR-007/IR-0/' $RDP/core/RadioReport.kt"
mutate radio-limits-evidence "RadioReport must always state PUBLIC_READ_ONLY_APP_STATE" "sed -i 's/PUBLIC_READ_ONLY_APP_STATE/OK/' $RDP/core/RadioReport.kt"
mutate radio-limits-not-appended "must always append the limits block" "sed -i '/appendSection(limits())/d' $RDP/core/RadioReport.kt"
mutate radio-reading-state-removed "must model the state NotSupported" "sed -i 's/NotSupported/Other/g' $RDP/core/Reading.kt"
mutate radio-reading-unknown-removed "must model the state Unknown" "sed -i 's/Unknown/Other/g' $RDP/core/Reading.kt"
mutate radio-non-null-assertion "non-null assertion" "sed -i 's/if (tm == null) {/if (tm!! == null) {/' $RDP/android/RadioActivity.kt"
mutate radio-sets-radio-state "must not change radio or telephony state" "sed -i 's/^\\( *\\)val tm = getSystemService(TelephonyManager::class.java)\$/&\\n\\1tm?.${SD}(true)/' $RDP/android/RadioActivity.kt"
mutate radio-ims-api "outside RadioDiag" "printf 'import android.telephony.ims.ImsMmTelManager\n' > $RDP/android/X.kt"
mutate radio-carrier-config "outside RadioDiag" "printf 'val c: CarrierConfigManager? = null\n' > $RDP/android/X.kt"
mutate radio-apn "outside RadioDiag" "printf 'val a: ApnSetting? = null\n' > $RDP/android/X.kt"
mutate display-enforced-state "no enforced/applied state" "sed -i 's/PLATFORM_CALL_ACCEPTED_UNVERIFIED;/PLATFORM_CALL_ACCEPTED_UNVERIFIED, ENFORCED;/' $DCP/core/Enforcement.kt"
mutate display-state-removed "must keep NOT_ENFORCED_BACKEND_CLOSED" "sed -i 's/NOT_ENFORCED_BACKEND_CLOSED/OTHER_STATE/g' $DCP/core/Enforcement.kt"
mutate display-wording-not-enforced "must say NOT enforced" "sed -i 's/NOT enforced/enforcement skipped/g' $DCP/core/Enforcement.kt"
mutate display-wording-unverified "must say NOT enforced and not verified" "sed -i 's/not verified/verified/g' $DCP/core/Enforcement.kt"
mutate display-ui-applied-claim "must not word a stored profile" "printf 'private val claim = \"Applied to the app window\"\n' >> $DCP/ui/AppListScreen.kt"
mutate display-message-enforced-claim "must not word a stored profile" "printf 'private val claim = \"Profile Enforced\"\n' >> $DCP/ui/EditorScreen.kt"
mutate display-gate-property "must stay gated" "sed -i 's/persist.sable.displaycompat.backend/persist.sable.displaycompat.other/' $DCP/android/GatedPlatformBackend.kt"
mutate display-gate-value "must stay gated" "sed -i 's/== \"validated\"/== \"always\"/' $DCP/android/GatedPlatformBackend.kt"
mutate display-clear-open "must stay fail-closed" "sed -i 's/if (!open()) ApplyResult.NoOp else set/if (false) ApplyResult.NoOp else set/' $DCP/android/GatedPlatformBackend.kt"
mutate display-apply-open "must stay fail-closed" "sed -i 's/!open() -> ApplyResult.NoOp/false -> ApplyResult.NoOp/' $DCP/android/GatedPlatformBackend.kt"
mutate display-mini-mode-mapped "Mini Mode to a platform value" "sed -i 's/AspectProfile.Ratio16x9Letterbox -> ASPECT_16_9/&\\n        AspectProfile.MiniMode -> ASPECT_16_9/' $DCP/android/GatedPlatformBackend.kt"
mutate display-new-reflective-call "reflective platform calls" "printf 'val m = Any::class.java.getMethod(\"setForcedDisplaySize\")\n' > $DCP/android/X.kt"
mutate display-window-manager "hidden/private enforcement" "printf 'val w: IWindowManager? = null\n' > $DCP/android/X.kt"
mutate display-settings-write "hidden/private enforcement" "printf 'fun f(c: Any) = ${SG}(c, 1)\n' > $DCP/android/X.kt"
mutate display-test-removed "missing required test closedBackendNeverClaimsEnforcement" "sed -i 's/fun closedBackendNeverClaimsEnforcement/fun renamed/' $DCK/test/java/org/sableos/titan2/displaycompat/core/DisplayCompatHardeningTest.kt"
mutate display-store-test-removed "aStoreThatForgetsAWriteIsReportedAndNothingIsApplied" "sed -i 's/fun aStoreThatForgetsAWriteIsReportedAndNothingIsApplied/fun renamed/' $DCK/test/java/org/sableos/titan2/displaycompat/core/DisplayCompatHardeningTest.kt"
mutate radio-tests-gutted "RadioHardeningTest must keep at least 15 tests" "sed -i 's/@Test//' $RDK/test/java/org/sableos/titan2/radiodiag/RadioHardeningTest.kt"
mutate radio-limits-test-removed "missing required test reportAlwaysCarriesTheLimitsBlock" "sed -i 's/fun reportAlwaysCarriesTheLimitsBlock/fun renamed/' $RDK/test/java/org/sableos/titan2/radiodiag/RadioHardeningTest.kt"
mutate ir006-closed "IR-006 must stay OPEN" "sed -i '/^IR-006\t/s/\tOPEN\$/\tCLOSED/' $IRT"
mutate ir007-closed "IR-007 must stay OPEN" "sed -i '/^IR-007\t/s/\tOPEN\$/\tCLOSED/' $IRT"
mutate ir007-owner "IR-007 must stay canonical-owned" "sed -i '/^IR-007\t/s/canonical C3B lane (radio)/product lane/' $IRT"
mutate kl013-removed "KL-013 missing" "sed -i '/^| KL-013 |/d' $KLD"
mutate kl015-removed "KL-015 missing" "sed -i '/^| KL-015 |/d' $KLD"
mutate kl023-removed "KL-023 missing" "sed -i '/^| KL-023 |/d' $KLD"
mutate kl015-owner "KL-015 must stay canonical-owned" "sed -i '/^| KL-015 |/s/canonical lane (IR-006)/product lane/' $KLD"
mutate kl031-removed "KL-031 missing" "sed -i '/^| KL-031 |/d' $KLD"
mutate d6-doc-ims-visible "D6_RADIODIAG_IMS_REGISTRATION=NOT_VISIBLE" "sed -i 's/^D6_RADIODIAG_IMS_REGISTRATION=NOT_VISIBLE/D6_RADIODIAG_IMS_REGISTRATION=VISIBLE/' $D6"
mutate d6-doc-mini-mode "D6_DISPLAYCOMPAT_MINI_MODE_IMPLEMENTED=NO" "sed -i 's/^D6_DISPLAYCOMPAT_MINI_MODE_IMPLEMENTED=NO/D6_DISPLAYCOMPAT_MINI_MODE_IMPLEMENTED=YES/' $D6"
mutate d6-doc-claim "D6_DISPLAYCOMPAT_STRONGEST_CLAIM=PLATFORM_CALL_ACCEPTED_UNVERIFIED" "sed -i 's/^D6_DISPLAYCOMPAT_STRONGEST_CLAIM=.*/D6_DISPLAYCOMPAT_STRONGEST_CLAIM=ENFORCED/' $D6"
mutate d6-doc-device "D6_DEVICE_RUNTIME_VALIDATED=NO" "sed -i 's/^D6_DEVICE_RUNTIME_VALIDATED=NO/D6_DEVICE_RUNTIME_VALIDATED=YES/' $D6"
mutate d6-doc-ir-status "IR_006_STATUS=OPEN_CANONICAL" "sed -i 's/^IR_006_STATUS=OPEN_CANONICAL/IR_006_STATUS=CLOSED/' $D6"
mutate d6-marker-in-readme "D6 marker contradicts" "printf '\nD6_DEVICE_RUNTIME_VALIDATED=YES\n' >> README.md"
mutate d6-doc-missing "docs/C3B_D6_HARDENING.md missing" "git rm -q -f $D6"
(( fail == 0 )) || { echo "C3B_D6_CONTRACT_MUTATION_TESTS=FAIL passed=$pass missed=$fail" >&2; exit 1; }
echo "C3B_D6_CONTRACT_MUTATION_TESTS=PASS count=$pass"
