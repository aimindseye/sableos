#!/usr/bin/env bash
# Operator-run (network + authenticated gh). Confirms the canonical Sable Messages files at the pinned sableos commit
# still have the Git blob ids recorded in docs/C3B_MESSAGES_CANONICAL_BINDING.env. Read-only; touches nothing.
#   build/titan2/verify-c3b-messages-canonical-pin.sh
# Marker on success: C3B_MESSAGES_CANONICAL_PIN_VERIFIED=PASS
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVF="$ROOT/docs/C3B_MESSAGES_CANONICAL_BINDING.env"
get() { grep -E "^$1=" "$ENVF" | head -n1 | cut -d= -f2-; }
REPO="$(get C3B_MESSAGES_CANONICAL_REPO)"; COMMIT="$(get C3B_MESSAGES_CANONICAL_COMMIT)"; SRC="$(get C3B_MESSAGES_CANONICAL_SOURCE_PATH)"
[[ -n "$REPO" && -n "$COMMIT" && -n "$SRC" ]] || { echo "C3B_MESSAGES_CANONICAL_PIN_VERIFIED=FAIL_BINDING_INCOMPLETE" >&2; exit 1; }

# Git transport authentication and GitHub CLI API authentication are separate.
# Fail before blob comparison so an unauthenticated/private-repo lookup is never
# misreported as a canonical blob mismatch.
command -v gh >/dev/null 2>&1 || {
    echo "C3B_MESSAGES_CANONICAL_PIN_VERIFIED=NOT_RUN_GH_CLI_UNAVAILABLE" >&2
    exit 3
}
gh auth status --hostname github.com >/dev/null 2>&1 || {
    echo "C3B_MESSAGES_CANONICAL_PIN_VERIFIED=NOT_RUN_GH_AUTH_REQUIRED" >&2
    exit 3
}
gh api "repos/$REPO" --silent >/dev/null 2>&1 || {
    echo "C3B_MESSAGES_CANONICAL_PIN_VERIFIED=NOT_RUN_CANONICAL_REPO_ACCESS_REQUIRED repo=$REPO" >&2
    exit 3
}

bad=0
while IFS='=' read -r key want; do
    rel="${key#C3B_MESSAGES_CANONICAL_BLOB_}"
    have="$(gh api "repos/$REPO/contents/$SRC/$rel?ref=$COMMIT" --jq .sha 2>/dev/null || echo MISSING)"
    if [[ "$have" == "$want" ]]; then echo "OK   $rel $have"; else echo "FAIL $rel pinned=$want canonical=$have" >&2; bad=1; fi
done < <(grep -E '^C3B_MESSAGES_CANONICAL_BLOB_' "$ENVF")
# Sable Hub / Connected Apps source (D4 parity contract): pinned canonical files must still exist with the recorded blob ids.
HENV="$ROOT/docs/C3B_HUB_PARITY.env"; HCOMMIT="$(grep -E '^C3B_HUB_CANONICAL_COMMIT=' "$HENV" | cut -d= -f2-)"; HPATH="$(grep -E '^C3B_HUB_CANONICAL_PATH=' "$HENV" | cut -d= -f2-)"
while IFS='=' read -r key want; do
    rel="${key#C3B_HUB_CANONICAL_BLOB_}"
    have="$(gh api "repos/$REPO/contents/$HPATH/$rel?ref=$HCOMMIT" --jq .sha 2>/dev/null || echo MISSING)"
    if [[ "$have" == "$want" ]]; then echo "OK   hub:$rel $have"; else echo "FAIL hub:$rel pinned=$want canonical=$have" >&2; bad=1; fi
done < <(grep -E '^C3B_HUB_CANONICAL_BLOB_' "$HENV")
# Runtime-data truth recorded in the binding must still hold at the pinned commit (content, not just blob ids).
raw() { gh api "repos/$REPO/contents/$SRC/$1?ref=$COMMIT" -H "Accept: application/vnd.github.raw"; }
MODEL="$(raw src/main/java/org/sableos/messages/MessagesInteractionModel.kt)"; ACT="$(raw src/main/java/org/sableos/messages/MainActivity.kt)"
MANI="$(raw src/main/AndroidManifest.xml)"; APP="${MANI#*<application}"
chk() { if eval "$2"; then echo "OK   $1"; else echo "FAIL $1" >&2; bad=1; fi; }
chk "STATIC_SAMPLE_THREADS: model defines sampleThreads" 'grep -q "^val sampleThreads" <<<"$MODEL"'
chk "STATIC_SAMPLE_THREADS: activity renders sampleThreads" 'grep -q "latestFirstThreads(sampleThreads)" <<<"$ACT"'
chk "SEND_PATH: ACTION_SENDTO smsto handoff" 'grep -q "Intent.ACTION_SENDTO" <<<"$ACT" && grep -q "smsto:" <<<"$ACT"'
chk "no uses-permission in manifest" '! grep -q "uses-permission" <<<"$MANI"'
chk "no receiver/service/provider in application" '! grep -Eq "<(receiver|service|provider)" <<<"$APP"'
chk "no default-SMS role request in activity" '! grep -Eq "RoleManager|ROLE_SMS|SmsManager|content://(sms|mms)" <<<"$ACT$MODEL"'
(( bad == 0 )) || { echo "C3B_MESSAGES_CANONICAL_PIN_VERIFIED=FAIL" >&2; exit 1; }
echo "C3B_MESSAGES_CANONICAL_PIN_VERIFIED=PASS repo=$REPO commit=$COMMIT"
