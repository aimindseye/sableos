#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
QUAL="$ROOT/build/titan2/qualify-n1i-c1-telephonymetrics-compat.sh"
PATCH="$ROOT/patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch"

fail() {
    echo "N1I_C1_TELEPHONY_METRICS_COMPAT_TEST=FAIL reason=$*" >&2
    exit 1
}

pass() {
    echo "N1I_C1_TELEPHONY_METRICS_COMPAT_TEST_$1=PASS"
}

[[ -f "$QUAL" ]] || fail qualifier_missing
[[ -f "$PATCH" ]] || fail patch_missing

bash -n "$QUAL"
pass QUALIFIER_SYNTAX

if grep -Eq -- '(^|[^A-Za-z_])(adb|fastboot)[[:space:](]' "$QUAL"; then
    fail qualifier_device_command_surface
fi
pass NO_DEVICE_COMMANDS

if grep -Eq -- 'curl|wget|requests|urllib|socket|git[[:space:]]+(fetch|pull|clone)|http://|https://' "$QUAL"; then
    fail qualifier_network_surface
fi
pass NO_NETWORK

if grep -Eq -- '(^|[[:space:]])(m|mm|mmm|make|ninja|soong_ui\.bash)([[:space:]]|$)' "$QUAL"; then
    fail qualifier_build_surface
fi
pass NO_BUILD

[[ "$(grep -Ec '^diff --git ' "$PATCH")" == 1 ]] ||
    fail patch_not_single_file
grep -Fq -- 'src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java' "$PATCH" ||
    fail patch_target_missing
grep -Fq -- '+    public void writeRilAnswer(int phoneId, int rilSerial) {' "$PATCH" ||
    fail two_arg_overload_missing
grep -Fq -- '     public void writeRilAnswer(int phoneId, int rilSerial, int rilError, int rilRequest) {' "$PATCH" ||
    fail four_arg_context_missing
if grep -Eq '^-[^-]' "$PATCH"; then
    fail patch_has_runtime_deletions
fi
pass PATCH_SHAPE

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OPT="$TMP/frameworks/opt/telephony"
TARGET="$OPT/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java"
mkdir -p "$(dirname "$TARGET")"

cat >"$TARGET" <<'EOF'
/*
 * Copyright (C) 2016 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.internal.telephony.metrics;

/**
 * Stub TelephonyMetrics class.
 *
 * The full implementation was removed in android-16.0.0_r4. This stub
 * exists solely to prevent NoSuchMethodError crashes in MediaTek IMS
 * vendor blobs (com.mediatek.ims) that invoke these methods.
 */
public class TelephonyMetrics {

    private static final TelephonyMetrics sInstance = new TelephonyMetrics();

    public TelephonyMetrics() {
    }

    public static TelephonyMetrics getInstance() {
        return sInstance;
    }

    public void writeRilSendSms(int phoneId, int rilSerial, int tech, int format) {
        // No-op stub for MediaTek IMS compatibility
    }

    public synchronized void writeRilSendSms(int phoneId, int rilSerial, int tech, int format,
            long messageId) {
        // No-op stub for MediaTek IMS compatibility
    }

    /**
     * No-op stub. Called by ImsRILAdapter.processResponseDoneInternal when
     * processing solicited RIL responses.
     */
    public void writeOnRilSolicitedResponse(int phoneId, int rilSerial, int rilError,
            int rilRequest, Object ret) {
        // No-op stub for MediaTek IMS compatibility
    }

    /**
     * No-op stub. Called by ImsRILAdapter when a RIL request times out.
     */
    public void writeOnRilTimeoutResponse(int phoneId, int rilSerial, int rilRequest) {
        // No-op stub for MediaTek IMS compatibility
    }

    /**
     * No-op stub. Called by ImsRILAdapter when answering a call.
     */
    public void writeRilAnswer(int phoneId, int rilSerial, int rilError, int rilRequest) {
        // No-op stub for MediaTek IMS compatibility
    }
}
EOF

git -C "$OPT" init -q
git -C "$OPT" config user.email fixture@example.invalid
git -C "$OPT" config user.name fixture
git -C "$OPT" add "$TARGET"
git -C "$OPT" commit -qm fixture-base

BASE_OUT="$TMP/base.out"
bash "$QUAL" --opt-telephony "$OPT" --verify >"$BASE_OUT"
grep -Fxq 'N1I_C1_TELEPHONY_METRICS_STATE=PASS_EXACT_BASE' "$BASE_OUT" ||
    fail base_state
grep -Fxq 'N1I_C1_TELEPHONY_METRICS_MUTATION=NOT_RUN' "$BASE_OUT" ||
    fail base_mutation
pass BASE_VERIFY

NOAUTH_APPLY="$TMP/noauth-apply.out"
if bash "$QUAL" --opt-telephony "$OPT" --apply >"$NOAUTH_APPLY" 2>&1; then
    fail apply_without_authority_succeeded
fi
grep -Fq -- 'apply_requires_--authorize-source-mutation' "$NOAUTH_APPLY" ||
    fail apply_without_authority_reason
pass APPLY_AUTH_REQUIRED

APPLY_OUT="$TMP/apply.out"
bash "$QUAL"     --opt-telephony "$OPT"     --apply     --authorize-source-mutation >"$APPLY_OUT"
grep -Fxq 'N1I_C1_TELEPHONY_METRICS_MUTATION=PASS_APPLIED' "$APPLY_OUT" ||
    fail apply_marker
grep -Fxq 'FINAL_TARGET_BLOB=9d5108e0ddb8d4960d21cda021813b53dbbf4da8' "$APPLY_OUT" ||
    fail apply_post_blob
pass APPLY_EXACT

POST_OUT="$TMP/post.out"
bash "$QUAL" --opt-telephony "$OPT" --verify >"$POST_OUT"
grep -Fxq 'N1I_C1_TELEPHONY_METRICS_STATE=PASS_EXACT_PATCHED' "$POST_OUT" ||
    fail post_state
pass POST_VERIFY

NOAUTH_REVERT="$TMP/noauth-revert.out"
if bash "$QUAL" --opt-telephony "$OPT" --revert >"$NOAUTH_REVERT" 2>&1; then
    fail revert_without_authority_succeeded
fi
grep -Fq -- 'revert_requires_--authorize-source-mutation' "$NOAUTH_REVERT" ||
    fail revert_without_authority_reason
pass REVERT_AUTH_REQUIRED

REVERT_OUT="$TMP/revert.out"
bash "$QUAL"     --opt-telephony "$OPT"     --revert     --authorize-source-mutation >"$REVERT_OUT"
grep -Fxq 'N1I_C1_TELEPHONY_METRICS_MUTATION=PASS_REVERTED' "$REVERT_OUT" ||
    fail revert_marker
grep -Fxq 'FINAL_TARGET_BLOB=27638e5be9c008101c2f9b8f1e7a9af49d94f838' "$REVERT_OUT" ||
    fail revert_base_blob
pass REVERT_EXACT

printf '\n// unexpected mutation\n' >>"$TARGET"
BAD_OUT="$TMP/bad.out"
if bash "$QUAL" --opt-telephony "$OPT" --verify >"$BAD_OUT" 2>&1; then
    fail unexpected_blob_succeeded
fi
grep -Fq -- 'unexpected_target_blob=' "$BAD_OUT" ||
    fail unexpected_blob_reason
pass UNEXPECTED_BLOB_REJECTED

MULTI_OUT="$TMP/multi.out"
if bash "$QUAL"     --opt-telephony "$OPT"     --verify     --apply >"$MULTI_OUT" 2>&1; then
    fail multiple_actions_succeeded
fi
grep -Fq -- 'multiple_actions' "$MULTI_OUT" ||
    fail multiple_actions_reason
pass MULTIPLE_ACTIONS_REJECTED

echo "N1I_C1_TELEPHONY_METRICS_COMPAT_TEST=PASS"
