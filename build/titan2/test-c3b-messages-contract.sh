#!/usr/bin/env bash
# Mutation tests for the D4 Sable Messages and Sable Hub parity contracts in the static qualification gate. Developer-runnable, offline, no Gradle.
# Copies the tracked tree into a throw-away git repo, proves the baseline passes, then injects one violation at a time and
# requires the gate to fail with the matching STATIC_FAIL message. Never touches the working tree.
#   build/titan2/test-c3b-messages-contract.sh
# Marker on success: C3B_MESSAGES_CONTRACT_MUTATION_TESTS=PASS count=N
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
grep -q '^C3B_MESSAGES_RECONCILIATION_SOURCE_CONTRACT=PASS' <<<"$out" || { echo "$out" | tail -20; echo "C3B_MESSAGES_CONTRACT_MUTATION_TESTS=FAIL_BASELINE" >&2; exit 1; }
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
B=docs/C3B_MESSAGES_CANONICAL_BINDING.env
M=docs/C3B_PRODUCT_SURFACE_MATRIX.tsv
mutate matrix-stock-path "messages surface must be CANONICAL_SABLEOS" "sed -i 's#sableos:apps/r8/android/messages#packages/apps/Messaging#' $M"
mutate matrix-fallback-wording "messages surface notes must contain: temporary radio-focused" "sed -i 's/temporary radio-focused engineering fallback/default engineering choice/' $M"
mutate matrix-privilege "messages surface must request no privilege" "sed -i 's/none (provider-safe smsto/READ_SMS (provider-safe smsto/' $M"
mutate kl008-temporary-default "KL-008 still describes stock Messaging" "sed -i '/^| KL-008 |/s/| yes |/temporary default until Sable Messages is reconciled | yes |/' docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md"
mutate kl008-deleted "KL-008 must state" "sed -i '/^| KL-008 |/d' docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md"
mutate binding-stock-final "STOCK_MESSAGING_IS_FINAL_PRODUCT_DECISION must be NO" "sed -i 's/STOCK_MESSAGING_IS_FINAL_PRODUCT_DECISION=NO/STOCK_MESSAGING_IS_FINAL_PRODUCT_DECISION=YES/' $B"
mutate binding-custom-sms "CUSTOM_SMS_STACK must be NO" "sed -i 's/^CUSTOM_SMS_STACK=NO/CUSTOM_SMS_STACK=YES/' $B"
mutate binding-custom-mms "CUSTOM_MMS_STACK must be NO" "sed -i 's/^CUSTOM_MMS_STACK=NO/CUSTOM_MMS_STACK=YES/' $B"
mutate binding-imported "SOURCE_IMPORTED_INTO_THIS_REPO must be NO" "sed -i 's/SOURCE_IMPORTED_INTO_THIS_REPO=NO/SOURCE_IMPORTED_INTO_THIS_REPO=YES/' $B"
mutate binding-dependency-delta "DEPENDENCY_DELTA must be NONE" "sed -i 's/DEPENDENCY_DELTA=NONE/DEPENDENCY_DELTA=ADDED/' $B"
mutate binding-bad-commit "must be an exact 40-hex commit" "sed -i 's/^C3B_MESSAGES_CANONICAL_COMMIT=.*/C3B_MESSAGES_CANONICAL_COMMIT=main/' $B"
mutate binding-bad-blob "blob id missing or malformed" "sed -i '/BLOB_src\\/main\\/AndroidManifest.xml/d' $B"
mutate binding-device-claim "DEVICE_RUNTIME_VALIDATED must be NO" "sed -i 's/MESSAGES_DEVICE_RUNTIME_VALIDATED=NO/MESSAGES_DEVICE_RUNTIME_VALIDATED=YES/' $B"
mutate readme-stock-final "stock Messaging described as the final" "printf '\nstock Messaging is the final product choice for messages.\n' >> README.md"
mutate doc-stock-selected "stock Messaging described as the final" "printf '\nstock AOSP Messaging remains the selected messaging app.\n' >> docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md"
mutate module-row-removed "exactly one SableMessages row" "sed -i '/^SableMessages\t/d' docs/C3B_PRODUCT_SOURCE_MODULES.tsv"
mutate module-local-path "SableMessages source_path must name the canonical" "sed -i 's#^SableMessages\tsableos:apps/r8/android/messages#SableMessages\tapps/titan2/platform/setup#' docs/C3B_PRODUCT_SOURCE_MODULES.tsv"
mutate ir012-closed "IR-012 must be OPEN" "sed -i '/^IR-012\t/s/\tOPEN\$/\tCLOSED/' docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv"
mutate ir012-privileged "IR-012 must not request a privileged API" "sed -i '/^IR-012\t/s/none requested by this lane/SEND_SMS role/' docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv"
S=apps/titan2/platform/setup
mutate imported-module "must not be copied into this repository" "mkdir -p apps/r8/android/messages/src/main/java/org/sableos/messages && printf 'package org.sableos.messages\n' > apps/r8/android/messages/src/main/java/org/sableos/messages/MainActivity.kt"
mutate sms-manager "SmsManager" "printf 'val m = android.telephony.SmsManager.getDefault()\n' > $S/src/main/java/X.kt"
mutate sms-permission "android.permission.SEND_SMS" "printf '<manifest><uses-permission android:name=\"android.permission.SEND_SMS\"/></manifest>\n' > $S/extra.xml"
mutate read-sms-permission "android.permission.READ_SMS" "printf '<manifest><uses-permission android:name=\"android.permission.READ_SMS\"/></manifest>\n' > $S/extra.xml"
mutate receive-mms-permission "android.permission.RECEIVE_MMS" "printf '<manifest><uses-permission android:name=\"android.permission.RECEIVE_MMS\"/></manifest>\n' > $S/extra.xml"
mutate sms-receiver "SMS_DELIVER" "printf '<receiver><intent-filter><action android:name=\"android.provider.Telephony.SMS_DELIVER\"/></intent-filter></receiver>\n' > $S/extra.xml"
mutate sms-provider-uri "content://sms" "printf 'val u = \"content://sms/inbox\"\n' > $S/src/main/java/X.kt"
mutate default-sms-role "RoleManager.ROLE_SMS" "printf 'val r = RoleManager.ROLE_SMS\n' > $S/src/main/java/X.kt"
mutate carrier-messaging-service "CarrierMessagingService" "printf 'class X : CarrierMessagingService()\n' > $S/src/main/java/X.kt"
mutate ims-api "android.telephony.ims" "printf 'import android.telephony.ims.ImsMmTelManager\n' > $S/src/main/java/X.kt"
mutate apn-api "ApnSetting" "printf 'val a: ApnSetting? = null\n' > $S/src/main/java/X.kt"
mutate rcs-api "RcsManager" "printf 'val r: RcsManager? = null\n' > $S/src/main/java/X.kt"
mutate privileged-modem-permission "MODIFY_PHONE_STATE" "printf '<manifest><uses-permission android:name=\"android.permission.MODIFY_PHONE_STATE\"/></manifest>\n' > $S/extra.xml"
mutate product-packages-messaging "selects stock Messaging" "printf '%s += Messaging MmsService\n' "PRODUCT_PACK"AGES > $S/product.mk"
mutate gradle-sms-dependency "not declared in the D4 dependency delta" "printf 'dependencies {\n    implementation(\"com.klinker.android:android-smsmms:5.2\")\n}\n' > $S/extra.gradle.kts"
mutate gradle-messages-project "not declared in the D4 dependency delta" "printf 'dependencies {\n    implementation(project(\":messages\"))\n}\n' > $S/extra.gradle.kts"
R=docs/C3B_MESSAGES_RECONCILIATION.md
mutate rt-live-thread-yes "C3B_MESSAGES_LIVE_THREAD_DATA" "sed -i 's/^C3B_MESSAGES_LIVE_THREAD_DATA=NO/C3B_MESSAGES_LIVE_THREAD_DATA=YES/' $B"
mutate rt-incoming-implemented "C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH" "sed -i 's/^C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH=.*/C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH=IMPLEMENTED/' $B"
mutate rt-source-live "C3B_MESSAGES_RUNTIME_DATA_SOURCE" "sed -i 's/^C3B_MESSAGES_RUNTIME_DATA_SOURCE=.*/C3B_MESSAGES_RUNTIME_DATA_SOURCE=PROVIDER_LIVE_THREADS/' $B"
mutate rt-send-path-custom "C3B_MESSAGES_SEND_PATH" "sed -i 's/^C3B_MESSAGES_SEND_PATH=.*/C3B_MESSAGES_SEND_PATH=SABLE_DIRECT_SMS/' $B"
mutate rt-product-status-complete "C3B_MESSAGES_PRODUCT_STATUS" "sed -i 's/^C3B_MESSAGES_PRODUCT_STATUS=.*/C3B_MESSAGES_PRODUCT_STATUS=COMPLETE/' $B"
mutate rt-marker-removed "C3B_MESSAGES_LIVE_THREAD_DATA must be NO" "sed -i '/^C3B_MESSAGES_LIVE_THREAD_DATA=/d' $B"
mutate rt-commit-bumped "valid only for the commit they were verified at" "sed -i 's/^C3B_MESSAGES_CANONICAL_COMMIT=.*/C3B_MESSAGES_CANONICAL_COMMIT=0000000000000000000000000000000000000001/' $B"
mutate rt-matrix-marker-removed "messages surface notes must state the runtime data truth" "sed -i 's/C3B_MESSAGES_LIVE_THREAD_DATA=NO//' $M"
mutate rt-matrix-markers-all-removed "messages surface notes must state the runtime data truth" "sed -i 's/STATIC_SAMPLE_THREADS//g' $M"
mutate rt-kl008-marker-removed "KL-008 must state the runtime data truth" "sed -i '/^| KL-008 |/s/C3B_MESSAGES_PRODUCT_STATUS=[A-Z_]*//' docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md"
mutate rt-kl008-nonblocking "KL-008 must stay blocking" "sed -i '/^| KL-008 |/s/| yes | stock Messaging/| no | stock Messaging/' docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md"
mutate rt-ir012-nonblocking "IR-012 must stay blocking" "sed -i '/^IR-012\t/s/\tYES\tOPEN\$/\tNO\tOPEN/' docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv"
mutate rt-ir012-data-path-dropped "IR-012 must name the unresolved canonical runtime data" "sed -i '/^IR-012\t/s/runtime data and provider integration/messaging admission/' docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv"
mutate rt-module-note-dropped "SableMessages module notes must state" "sed -i 's/(C3B_MESSAGES_LIVE_THREAD_DATA=NO)//' docs/C3B_PRODUCT_SOURCE_MODULES.tsv"
mutate rt-claim-readme-live "live-conversation / incoming-message claim" "printf '\nSable Messages shows live SMS conversations on the Titan 2.\n' >> README.md"
mutate rt-claim-incoming "live-conversation / incoming-message claim" "printf '\nSable Messages receives incoming messages from the provider.\n' >> $R"
mutate rt-claim-kl "live-conversation / incoming-message claim" "printf '\nIncoming-message support is implemented in Sable Messages.\n' >> docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md"
mutate rt-claim-usable "live-conversation / incoming-message claim" "printf '\nSable Messages is a fully functional SMS client.\n' >> README.md"
mutate rt-claim-matrix-note "live-conversation / incoming-message claim" "sed -i 's/Canonical runtime data and provider integration is open (IR-012)./Real-time threads are supported./' $M"
mutate rt-marker-wrong-in-readme "contradicts the pinned canonical source" "printf '\nC3B_MESSAGES_LIVE_THREAD_DATA=YES\n' >> README.md"
H=docs/C3B_HUB_PARITY.env
HD=docs/C3B_HUB_PARITY.md
KLD=docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md
IRT=docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv
mutate hub-owner-matrix "sable_hub surface must be CANONICAL_SABLEOS" "sed -i 's/^sable_hub\tCANONICAL_SABLEOS/sable_hub\tCANONICAL_PLATFORM/' $M"
mutate hub-owner-env "C3B_HUB_CANONICAL_OWNER must be" "sed -i 's/^C3B_HUB_CANONICAL_OWNER=.*/C3B_HUB_CANONICAL_OWNER=CANONICAL_PLATFORM/' $H"
mutate hub-path-matrix "sable_hub surface must be CANONICAL_SABLEOS" "sed -i 's#sableos:apps/r8/android/hub#apps/titan2/hub#' $M"
mutate hub-path-env "C3B_HUB_CANONICAL_PATH must be" "sed -i 's#^C3B_HUB_CANONICAL_PATH=.*#C3B_HUB_CANONICAL_PATH=apps/titan2/hub#' $H"
mutate hub-blocking-no "sable_hub must be blocking" "sed -i 's/\tNO\tYES\tCanonical Sable Hub owns/\tNO\tNO\tCanonical Sable Hub owns/' $M"
mutate hub-ir013-ref-dropped "sable_hub surface must reference IR-013" "sed -i 's/^\(sable_hub\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\)IR-013/\1none/' $M"
mutate hub-no-claim-wording "sable_hub surface must not say" "sed -i 's/Canonical Sable Hub owns Connected Apps:/Exists canonically; product lane makes no claim. Connected Apps:/' $M"
mutate hub-pending-wording "sable_hub surface notes must contain: device runtime validation pending" "sed -i 's/device runtime validation pending/validated/' $M"
mutate hub-messages-boundary-wording "sable_hub surface notes must contain: Sable Messages does not replace" "sed -i 's/Sable Messages does not replace, subsume, disable or weaken Sable Hub/Sable Hub is separate/' $M"
for K in CONNECTED_APPS GENERIC_NOTIFICATION_ADAPTER REMOTEINPUT_REPLY OPEN_APP_FALLBACK PACKAGE_USER_POLICY LOCAL_BOUNDED_HISTORY DYNAMIC_PROVIDER_DISCOVERY; do
    mutate "hub-env-$K-removed" "C3B_HUB_$K must be REQUIRED" "sed -i '/^C3B_HUB_$K=/d' $H"
    mutate "hub-doc-$K-removed" "C3B_HUB_$K=REQUIRED" "sed -i '/^C3B_HUB_$K=REQUIRED/d' $HD"
done
mutate hub-semantics-no "C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED must be YES" "sed -i 's/^C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED=YES/C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED=NO/' $H"
mutate hub-allowlist-yes "C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST must be NO" "sed -i 's/^C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST=NO/C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST=YES/' $H"
mutate hub-allowlist-yes-in-doc "Hub marker contradicts" "printf '\nC3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST=YES\n' >> README.md"
mutate hub-private-protocols-yes "C3B_HUB_PRIVATE_PROVIDER_PROTOCOLS must be NO" "sed -i 's/^C3B_HUB_PRIVATE_PROVIDER_PROTOCOLS=NO/C3B_HUB_PRIVATE_PROVIDER_PROTOCOLS=YES/' $H"
mutate hub-credentials-yes "C3B_HUB_PROVIDER_CREDENTIALS must be NO" "sed -i 's/^C3B_HUB_PROVIDER_CREDENTIALS=NO/C3B_HUB_PROVIDER_CREDENTIALS=YES/' $H"
mutate hub-webviews-yes "C3B_HUB_PROVIDER_WEBVIEWS must be NO" "sed -i 's/^C3B_HUB_PROVIDER_WEBVIEWS=NO/C3B_HUB_PROVIDER_WEBVIEWS=YES/' $H"
mutate hub-scraping-yes "C3B_HUB_PRIVATE_DATABASE_SCRAPING must be NO" "sed -i 's/^C3B_HUB_PRIVATE_DATABASE_SCRAPING=NO/C3B_HUB_PRIVATE_DATABASE_SCRAPING=YES/' $H"
mutate hub-device-validated-yes "C3B_HUB_DEVICE_RUNTIME_VALIDATED must be NO" "sed -i 's/^C3B_HUB_DEVICE_RUNTIME_VALIDATED=NO/C3B_HUB_DEVICE_RUNTIME_VALIDATED=YES/' $H"
mutate hub-imported-flag "C3B_HUB_SOURCE_IMPORTED_INTO_THIS_REPO must be NO" "sed -i 's/^C3B_HUB_SOURCE_IMPORTED_INTO_THIS_REPO=NO/C3B_HUB_SOURCE_IMPORTED_INTO_THIS_REPO=YES/' $H"
mutate hub-blob-removed "canonical blob id missing" "sed -i '/BLOB_src\/main\/java\/org\/sableos\/hub\/notifications\/ConnectedReplyRegistry.kt/d' $H"
mutate hub-ir013-closed "IR-013 must be OPEN" "sed -i '/^IR-013\t/s/\tOPEN\$/\tCLOSED/' $IRT"
mutate hub-ir013-nonblocking "IR-013 must be blocking" "sed -i '/^IR-013\t/s/\tYES\tOPEN\$/\tNO\tOPEN/' $IRT"
mutate hub-ir013-missing "IR-013 must be OPEN" "sed -i '/^IR-013\t/d' $IRT"
mutate hub-ir013-privileged "IR-013 must not request" "sed -i '/^IR-013\t/s/none requested (no provider-specific private API, no broader Hub privilege, no provider credentials)/provider credentials and private API/' $IRT"
mutate hub-ir013-scope-dropped "IR-013 must own canonical Hub admission" "sed -i '/^IR-013\t/s/Panther V1 Connected Apps semantics/semantics/' $IRT"
mutate hub-kl030-nonblocking "KL-030 must stay blocking" "sed -i '/^| KL-030 |/s/| yes | none/| no | none/' $KLD"
mutate hub-kl030-missing "KL-030 (Hub parity) missing" "sed -i '/^| KL-030 |/d' $KLD"
mutate hub-kl030-marker-dropped "KL-030 must contain" "sed -i '/^| KL-030 |/s/(IR-013)/(none)/; /^| KL-030 |/s/IR-013/IR-0/g' $KLD"
mutate hub-boundary-removed "D4_MESSAGES_REPLACES_SABLE_HUB=NO" "sed -i '/^D4_MESSAGES_REPLACES_SABLE_HUB=NO/d' $R"
mutate hub-boundary-yes "D4_MESSAGES_REPLACES_SABLE_HUB must be NO" "sed -i 's/^D4_MESSAGES_REPLACES_SABLE_HUB=NO/D4_MESSAGES_REPLACES_SABLE_HUB=YES/' $H"
mutate hub-weakens-yes "D4_MESSAGES_WEAKENS_CONNECTED_APPS must be NO" "sed -i 's/^D4_MESSAGES_WEAKENS_CONNECTED_APPS=NO/D4_MESSAGES_WEAKENS_CONNECTED_APPS=YES/' $H"
mutate hub-claim-replaces "claims Sable Messages replaces" "printf '\nSable Messages replaces Sable Hub on Titan 2.\n' >> README.md"
mutate hub-claim-subsumes "claims Sable Messages replaces" "printf '\nSable Messages subsumes Connected Apps.\n' >> $R"
mutate hub-claim-disables "claims Sable Messages replaces" "printf '\nSable Messages disables Sable Hub notifications.\n' >> $KLD"
mutate hub-claim-hub-retired "claims Sable Messages replaces" "printf '\nSable Hub is retired in favour of Messages.\n' >> README.md"
mutate hub-evidence-telegram-env "C3B_HUB_EVIDENCE_TELEGRAM must be" "sed -i 's/^C3B_HUB_EVIDENCE_TELEGRAM=.*/C3B_HUB_EVIDENCE_TELEGRAM=CONVERSATION_PHYSICALLY_QUALIFIED/' $H"
mutate hub-evidence-whatsapp-env "C3B_HUB_EVIDENCE_WHATSAPP must be" "sed -i 's/^C3B_HUB_EVIDENCE_WHATSAPP=.*/C3B_HUB_EVIDENCE_WHATSAPP=REPLY_PHYSICALLY_QUALIFIED/' $H"
mutate hub-evidence-linkedin-env "C3B_HUB_EVIDENCE_LINKEDIN must be" "sed -i 's/^C3B_HUB_EVIDENCE_LINKEDIN=.*/C3B_HUB_EVIDENCE_LINKEDIN=QUICK_REPLY_WORKED/' $H"
mutate hub-evidence-signal-env "C3B_HUB_EVIDENCE_SIGNAL must be" "sed -i 's/^C3B_HUB_EVIDENCE_SIGNAL=.*/C3B_HUB_EVIDENCE_SIGNAL=TITAN_VALIDATED/' $H"
mutate hub-evidence-telegram-doc "evidence inflated" "printf '\nTelegram conversations were physically qualified on Panther.\n' >> $HD"
mutate hub-evidence-whatsapp-doc "evidence inflated" "printf '\nWhatsApp reply handle retention was validated.\n' >> $HD"
mutate hub-evidence-linkedin-doc "evidence inflated" "printf '\nLinkedIn quick-reply is supported through RemoteInput.\n' >> $HD"
mutate hub-evidence-titan-doc "evidence inflated" "printf '\nSignal reply was physically validated on Titan 2.\n' >> README.md"
mutate hub-hardcoded-whatsapp "hard-coded provider package" "printf 'val p = \"com.whatsapp\"\n' > $S/src/main/java/X.kt"
mutate hub-hardcoded-signal "hard-coded provider package" "printf 'val p = \"org.thoughtcrime.securesms\"\n' > $S/src/main/java/X.kt"
mutate hub-hardcoded-telegram "hard-coded provider package" "printf 'val p = \"org.telegram.messenger\"\n' > $S/src/main/java/X.kt"
mutate hub-hardcoded-linkedin "hard-coded provider package" "printf 'val p = \"com.linkedin.android\"\n' > $S/src/main/java/X.kt"
mutate hub-imported-source "must not be copied into this repository" "mkdir -p apps/r8/android/hub/src/main/java/org/sableos/hub && printf 'package org.sableos.hub\n' > apps/r8/android/hub/src/main/java/org/sableos/hub/ConnectedAppsRepository.kt"
(( fail == 0 )) || { echo "C3B_MESSAGES_CONTRACT_MUTATION_TESTS=FAIL passed=$pass missed=$fail" >&2; exit 1; }
echo "C3B_MESSAGES_CONTRACT_MUTATION_TESTS=PASS count=$pass"
