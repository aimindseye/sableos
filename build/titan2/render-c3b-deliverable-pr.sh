#!/usr/bin/env bash
# Deterministic PR-body renderer for a C3B product-lane deliverable.
#   build/titan2/render-c3b-deliverable-pr.sh --deliverable D1a --pr 2 \
#       --scope "..." --non-goals "..." [--syntax PASS] [--tests PASS] [--perf NOT_APPLICABLE_NO_PERFORMANCE_CHANGE] \
#       [--compile NOT_APPLICABLE_NO_ANDROID_SOURCE_CHANGE] [--dependency-delta NONE] [--gradle-plugins NONE] [--base-head <40-hex>] [--extra KEY=VALUE ...] [--init NO] [--limitations "..."] [--out file]
# Binds PRODUCT_HEAD to the current `git rev-parse HEAD`, fails on a dirty tree, and always renders
# AI_G732_CI_STATUS=NOT_RUN. It never prints an operator PASS and never merges a PR. Re-run after every push.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
DELIV=""; PR=""; SCOPE=""; NONGOALS=""; SYN=NOT_RUN; TESTS=NOT_RUN_WITH_REASON; PERF=NOT_APPLICABLE_WITH_REASON; COMPILE=NOT_RUN_TOOLCHAIN_UNAVAILABLE
DEP=NONE; INIT=NO; LIMITS="See docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md"; OUT=""; STATIC_MARKER=NOT_RUN
BASE_HEAD=""; HOSTPKG=NO; NETFETCH=NO; MVN=NONE; GPLUG=NONE; RUST=NONE; NATIVE=NONE; SDK=NONE; ALLOW_DIRTY=NO; EXTRA=()
fail(){ echo "RENDER_FAIL=$1" >&2; exit 1; }
while [[ $# -gt 0 ]]; do case "$1" in
    --deliverable) DELIV="$2"; shift 2;; --pr) PR="$2"; shift 2;; --scope) SCOPE="$2"; shift 2;; --non-goals) NONGOALS="$2"; shift 2;;
    --syntax) SYN="$2"; shift 2;; --tests) TESTS="$2"; shift 2;; --perf) PERF="$2"; shift 2;; --compile) COMPILE="$2"; shift 2;;
    --dependency-delta) DEP="$2"; shift 2;; --init) INIT="$2"; shift 2;; --limitations) LIMITS="$2"; shift 2;;
    --host-package-install) HOSTPKG="$2"; shift 2;; --network-fetch) NETFETCH="$2"; shift 2;; --maven) MVN="$2"; shift 2;;
    --rust-crates) RUST="$2"; shift 2;; --native-libs) NATIVE="$2"; shift 2;; --sdk-components) SDK="$2"; shift 2;;
    --gradle-plugins) GPLUG="$2"; shift 2;; --base-head) [[ "$2" =~ ^[0-9a-f]{40}$ ]] || fail "--base-head must be a 40-hex commit"; BASE_HEAD="$2"; shift 2;; --extra) [[ "$2" =~ ^[A-Z][A-Z0-9_]*=[^[:space:]]+$ ]] || fail "--extra must be KEY=VALUE (no spaces)"; EXTRA+=("$2"); shift 2;;
    --static-marker) STATIC_MARKER="$2"; shift 2;; --out) OUT="$2"; shift 2;; --allow-dirty) ALLOW_DIRTY=YES; shift;;
    *) fail "unknown argument $1";; esac; done
[[ -n "$DELIV" && -n "$PR" && -n "$SCOPE" && -n "$NONGOALS" ]] || fail "need --deliverable --pr --scope --non-goals"
[[ "$PR" =~ ^[0-9]+$ ]] || fail "--pr must be a number (open the PR first)"
[[ "$ALLOW_DIRTY" == YES || -z "$(git status --porcelain)" ]] || fail "DIRTY_SOURCE (commit or stash; the body must describe an exact HEAD)"
case "$SYN" in PASS|FAIL|NOT_RUN) ;; *) fail "--syntax must be PASS|FAIL|NOT_RUN";; esac
case "$STATIC_MARKER" in PASS|FAIL|NOT_RUN) ;; *) fail "--static-marker must be PASS|FAIL|NOT_RUN";; esac
HEAD_SHA="$(git rev-parse HEAD)"
BASE_REF="${BASE_HEAD:-origin/main}"
BIND="docs/C3B_PLATFORM_SABLE_BINDING.env"
PS_HEAD="$(sed -n 's/^C3B_PLATFORM_SABLE_HEAD=//p' "$BIND")"
[[ "$PS_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "platform_sable head not bound in $BIND"
REPO_URL="git@github.com:aimindseye/titan2-temp.git"
render() {
cat <<EOF
## ${DELIV}

\`\`\`text
DELIVERABLE_ID=${DELIV}
PRODUCT_REPO=aimindseye/titan2-temp
PRODUCT_PR=${PR}
PRODUCT_HEAD=${HEAD_SHA}
$(if [[ -n "$BASE_HEAD" ]]; then printf 'BASE_HEAD=%s' "$BASE_HEAD"; fi)
PLATFORM_SABLE_HEAD=${PS_HEAD}

SCOPE=${SCOPE}
NON_GOALS=${NONGOALS}

DEVELOPER_SYNTAX_VALIDATION=${SYN}
DEVELOPER_TEST_VALIDATION=${TESTS}
DEVELOPER_PERFORMANCE_VALIDATION=${PERF}
C3B_PRODUCT_DEVELOPER_ANDROID_COMPILE=${COMPILE}
C3B_PRODUCT_SOURCE_STATIC_QUALIFICATION=${STATIC_MARKER}
TEST_FRAMEWORK=LOCAL_JUNIT_COMPAT_SHIM
GRADLE_JUNIT_TESTS=NOT_RUN_TOOLCHAIN_UNAVAILABLE

DEPENDENCY_DELTA=${DEP}
HOST_PACKAGE_INSTALL_REQUIRED=${HOSTPKG}
NETWORK_FETCH_REQUIRED=${NETFETCH}
NEW_MAVEN_DEPENDENCIES=${MVN}
NEW_GRADLE_PLUGINS=${GPLUG}
NEW_RUST_CRATES=${RUST}
NEW_NATIVE_LIBRARIES=${NATIVE}
NEW_ANDROID_SDK_COMPONENTS=${SDK}

INITIALIZATION_REQUIRED=${INIT}
$(for e in "${EXTRA[@]+"${EXTRA[@]}"}"; do printf '%s\n' "$e"; done)

AI_G732_CI_STATUS=NOT_RUN
\`\`\`

Operator-owned fields (\`C3B_PRODUCT_AI_G732_*\`) are intentionally not rendered. Any push changes \`PRODUCT_HEAD\` and invalidates a previous operator PASS; re-render this body after every push.

### Exact ai-g732 fetch commands

\`\`\`bash
set -euo pipefail
PR=${PR}
PRODUCT_REPO=/srv/sable-build/workspaces/titan2-c3b-product/titan2-temp
PRODUCT_REVIEW_ROOT=/srv/sable-build/workspaces/titan2-c3b-product-review
PRODUCT_REVIEW_TREE="\$PRODUCT_REVIEW_ROOT/pr-\$PR"
test -d "\$PRODUCT_REPO/.git" || git clone ${REPO_URL} "\$PRODUCT_REPO"
git -C "\$PRODUCT_REPO" fetch origin
git -C "\$PRODUCT_REPO" fetch origin "pull/\$PR/head:refs/heads/review/pr-\$PR"
mkdir -p "\$PRODUCT_REVIEW_ROOT"
test ! -e "\$PRODUCT_REVIEW_TREE" || { echo "PRODUCT_REVIEW_TREE_ALREADY_EXISTS=\$PRODUCT_REVIEW_TREE"; exit 1; }
git -C "\$PRODUCT_REPO" worktree add --detach "\$PRODUCT_REVIEW_TREE" "review/pr-\$PR"
test "\$(git -C "\$PRODUCT_REVIEW_TREE" rev-parse HEAD)" = "${HEAD_SHA}" || { echo "PRODUCT_HEAD_MISMATCH"; exit 1; }
git -C "\$PRODUCT_REVIEW_TREE" status --short
\`\`\`

### Initialization

\`INITIALIZATION_REQUIRED=${INIT}\` (no host package install, no sudo, no adb/fastboot, no signing keys, no network fetch beyond what is declared above).

### Validation commands (operator)

\`\`\`bash
cd "\$PRODUCT_REVIEW_TREE"
bash build/titan2/qualify-c3b-product-source.sh --static --base ${BASE_REF} --platform-sable <platform_sable checkout at ${PS_HEAD}>
# For deliverables that change Android/Kotlin/Java source or build composition, load the host tool profile first:
#   source /srv/sable-build/sableos/repo/build/config/host-tools.env  (then the ANDROID_HOME/JAVA_HOME/GRADLE_USER_HOME exports from the delivery contract)
bash build/titan2/qualify-c3b-product-source.sh --full --base ${BASE_REF}
\`\`\`

### Expected PASS markers

\`\`\`text
C3B_PRODUCT_SOURCE_STATIC_QUALIFICATION=PASS
C3B_PRODUCT_SOURCE_QUALIFICATION=PASS
\`\`\`

Canonical SableOS CI (\`bash build/sable.sh titan2 N1D ci full\`) is operator-owned and not run by the developer.

### Known limitations

${LIMITS}
EOF
}
if [[ -n "$OUT" ]]; then render > "$OUT"; echo "RENDERED=$OUT PRODUCT_HEAD=${HEAD_SHA}"; else render; fi
