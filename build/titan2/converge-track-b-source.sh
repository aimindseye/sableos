#!/usr/bin/env bash
# Single source-only operation; no Gradle, Soong, network, device or flash.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:---plan}"
ACK="${2:-}"
case "$MODE" in
  --plan)
    bash "$ROOT/build/titan2/stage-track-b-product.sh" --plan
    bash "$ROOT/build/titan2/commit-exact-aosp-projects.sh" --preflight
    echo 'TB2_CONVERGE=PLAN_COMPLETE_NO_MUTATION'
    ;;
  --commit)
    [[ "$ACK" == CONVERGE_TB2_EXACT_A16_PROJECTS ]] || {
      echo 'TB2_CONVERGE=HOLD_EXPLICIT_ACK'; exit 78
    }
    # Never start from an AOSP checkout other than the pinned prior source.
    # The phase13 seven sources are already present; no reapplying or rebuilding.
    bash "$ROOT/build/titan2/stage-track-b-product.sh" --plan
    bash "$ROOT/build/titan2/commit-exact-aosp-projects.sh" --preflight
    bash "$ROOT/build/titan2/stage-track-b-product.sh" --apply
    bash "$ROOT/build/titan2/commit-exact-aosp-projects.sh" --plan
    bash "$ROOT/build/titan2/commit-exact-aosp-projects.sh" --commit COMMIT_EXACT_TB2_A16_SOURCE_ONLY
    echo 'TB2_CONVERGE=SOURCE_ONLY_4_AOSP_PROJECT_COMMITS_COMPLETE_NO_IMAGE'
    ;;
  *) echo 'TB2_CONVERGE=HOLD_MODE'; exit 64 ;;
esac
