#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEVICE="${1:-}"
RELEASE="${2:-}"
FUNCTION="${3:-}"
shift "$(( $# >= 3 ? 3 : $# ))"

usage() {
  cat >&2 <<'EOF'
SableOS canonical engineering entry point

usage:
  bash build/sable.sh <device> <release> <function> [options]

functions:
  ci [core|full|release]
  build [--tmux|--direct]
  register-artifact --build-source SHA --target-files PATH --sha256 SHA256 --android-info PATH [--out-dir PATH] [--build-evidence-dir PATH]
  show-artifact --build-source SHA
  flash-plan --build-source SHA
  flash --build-source SHA --serial SERIAL --preserve-data --authorize
  accept --serial SERIAL [--suite NAME]

examples:
  bash build/sable.sh panther R9 ci full
  bash build/sable.sh panther R9 build --tmux
  bash build/sable.sh panther R9 flash --build-source <sha> --serial <serial> --preserve-data --authorize
  bash build/sable.sh panther R9 accept --serial <serial> --suite launcher
EOF
}

[[ -n "$DEVICE" && -n "$RELEASE" && -n "$FUNCTION" ]] || {
  usage
  exit 64
}
[[ "$DEVICE" =~ ^[a-z0-9._-]+$ ]] || { echo "SABLE_ENTRYPOINT=FAIL_DEVICE"; exit 64; }
[[ "$RELEASE" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "SABLE_ENTRYPOINT=FAIL_RELEASE"; exit 64; }

case "$DEVICE" in
  pixel7|pixel-7) DEVICE=panther ;;
  titan-2) DEVICE=titan2 ;;
  titan-2-elite|elite) DEVICE=titan2-elite ;;
esac

ADAPTER="$ROOT/build/devices/$DEVICE.sh"
[[ -f "$ADAPTER" ]] || {
  echo "SABLE_ENTRYPOINT=FAIL_DEVICE_ADAPTER device=$DEVICE path=$ADAPTER"
  exit 64
}
# shellcheck source=/dev/null
source "$ADAPTER"

TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
echo "===== SABLEOS CANONICAL ENGINEERING ENTRY POINT ====="
echo "DEVICE=$DEVICE"
echo "RELEASE=$RELEASE"
echo "FUNCTION=$FUNCTION"
echo "TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT"
echo "ENTRYPOINT=build/sable.sh"
echo "DEVICE_SPECIFIC_ENTRYPOINT=NO"
echo "RELEASE_SPECIFIC_ENTRYPOINT=NO"

REGISTRY_ROOT="${SABLE_RELEASE_REGISTRY_ROOT:-/srv/data/sable-build/release-registry}"
EVIDENCE_ROOT="${SABLE_DEVICE_EVIDENCE_ROOT:-/srv/data/sable-build/evidence}"
REGISTRY="$ROOT/build/deploy/artifact_registry.py"
PLAN="$ROOT/build/deploy/target_files_plan.py"

case "$FUNCTION" in
  ci)
    PROFILE="${1:-core}"
    case "$PROFILE" in core|full|release) ;; *) echo "SABLE_CI=FAIL_PROFILE value=$PROFILE"; exit 64 ;; esac
    if [[ "$PROFILE" == release && "$DEVICE" != panther ]]; then
      echo "SABLE_CI=BLOCKED_RELEASE_PROFILE_UNQUALIFIED_DEVICE device=$DEVICE"
      exit 78
    fi
    echo "CI_PROFILE=$PROFILE"
    SABLEOS_DEVICE="$DEVICE" \
    SABLEOS_RELEASE_VERSION="$RELEASE" \
      bash "$ROOT/build/local-ci/run.sh" "$PROFILE"
    ;;

  build)
    MODE="${1:---tmux}"
    case "$MODE" in --tmux|--direct) ;; *) usage; exit 64 ;; esac
    [[ "${SABLE_DEVICE_BUILD_SUPPORTED:-NO}" == YES ]] || {
      echo "SABLE_BUILD=BLOCKED_UNQUALIFIED device=$DEVICE"
      exit 78
    }
    sable_device_build "$RELEASE" "$MODE"
    ;;

  register-artifact)
    BUILD_SOURCE=""
    TARGET_FILES=""
    SHA256=""
    ANDROID_INFO=""
    OUT_DIR=""
    BUILD_EVIDENCE_DIR=""
    REPLACE=NO
    while (($#)); do
      case "$1" in
        --build-source) BUILD_SOURCE="$2"; shift 2 ;;
        --target-files) TARGET_FILES="$2"; shift 2 ;;
        --sha256) SHA256="$2"; shift 2 ;;
        --android-info) ANDROID_INFO="$2"; shift 2 ;;
        --out-dir) OUT_DIR="$2"; shift 2 ;;
        --build-evidence-dir) BUILD_EVIDENCE_DIR="$2"; shift 2 ;;
        --replace) REPLACE=YES; shift ;;
        *) echo "unknown register-artifact option: $1" >&2; exit 64 ;;
      esac
    done
    [[ "$BUILD_SOURCE" =~ ^[0-9a-f]{40}$ ]] || { echo "SABLE_ARTIFACT_REGISTER=FAIL_BUILD_SOURCE"; exit 64; }
    git -C "$ROOT" cat-file -e "$BUILD_SOURCE^{commit}" 2>/dev/null || {
      echo "SABLE_ARTIFACT_REGISTER=FAIL_BUILD_SOURCE_NOT_IN_REPOSITORY"
      exit 65
    }
    if declare -F sable_device_artifact_gate >/dev/null 2>&1; then
      sable_device_artifact_gate "$RELEASE" "$BUILD_SOURCE" "$SHA256" "$BUILD_EVIDENCE_DIR" || exit 66
    fi
    ARGS=(
      --registry-root "$REGISTRY_ROOT" register
      --device "$DEVICE"
      --release "$RELEASE"
      --build-source "$BUILD_SOURCE"
      --target-files "$TARGET_FILES"
      --sha256 "$SHA256"
      --android-info "$ANDROID_INFO"
    )
    [[ -n "$OUT_DIR" ]] && ARGS+=(--out-dir "$OUT_DIR")
    [[ -n "$BUILD_EVIDENCE_DIR" ]] && ARGS+=(--build-evidence-dir "$BUILD_EVIDENCE_DIR")
    [[ "$REPLACE" == YES ]] && ARGS+=(--replace)
    python3 "$REGISTRY" "${ARGS[@]}"
    ;;

  show-artifact)
    BUILD_SOURCE=""
    while (($#)); do
      case "$1" in
        --build-source) BUILD_SOURCE="$2"; shift 2 ;;
        *) echo "unknown show-artifact option: $1" >&2; exit 64 ;;
      esac
    done
    [[ "$BUILD_SOURCE" =~ ^[0-9a-f]{40}$ ]] || { echo "SABLE_ARTIFACT_SHOW=FAIL_BUILD_SOURCE"; exit 64; }
    python3 "$REGISTRY" --registry-root "$REGISTRY_ROOT" show \
      --device "$DEVICE" --release "$RELEASE" --build-source "$BUILD_SOURCE"
    ;;

  flash-plan)
    BUILD_SOURCE=""
    while (($#)); do
      case "$1" in
        --build-source) BUILD_SOURCE="$2"; shift 2 ;;
        *) echo "unknown flash-plan option: $1" >&2; exit 64 ;;
      esac
    done
    [[ "$BUILD_SOURCE" =~ ^[0-9a-f]{40}$ ]] || { echo "SABLE_FLASH_PLAN=FAIL_BUILD_SOURCE"; exit 64; }

    field() {
      python3 "$REGISTRY" --registry-root "$REGISTRY_ROOT" field \
        --device "$DEVICE" --release "$RELEASE" --build-source "$BUILD_SOURCE" --field "$1"
    }
    TF="$(field target_files)"
    TF_SHA="$(field target_files_sha256)"
    ANDROID_INFO="$(field android_info)"
    STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
    EVIDENCE_DIR="$EVIDENCE_ROOT/$DEVICE/${RELEASE,,}-physical/${STAMP}_flash-plan"
    mkdir -p "$EVIDENCE_DIR"
    python3 "$PLAN" \
      --target-files "$TF" \
      --expected-sha256 "$TF_SHA" \
      --evidence-dir "$EVIDENCE_DIR" \
      --android-info "$ANDROID_INFO"
    (
      cd "$EVIDENCE_DIR"
      find . -type f ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt
    )
    echo "EVIDENCE_DIR=$EVIDENCE_DIR"
    echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
    echo "SABLE_FLASH_PLAN=PASS"
    ;;

  flash)
    exec bash "$ROOT/build/deploy/flash.sh" \
      --device "$DEVICE" \
      --release "$RELEASE" \
      --registry-root "$REGISTRY_ROOT" \
      --evidence-root "$EVIDENCE_ROOT" \
      "$@"
    ;;

  accept)
    SERIAL=""
    SUITE="${SABLE_DEVICE_DEFAULT_ACCEPTANCE_SUITE:-none}"
    while (($#)); do
      case "$1" in
        --serial) SERIAL="$2"; shift 2 ;;
        --suite) SUITE="$2"; shift 2 ;;
        *) echo "unknown accept option: $1" >&2; exit 64 ;;
      esac
    done
    [[ -n "$SERIAL" ]] || { echo "SABLE_ACCEPT=FAIL_SERIAL_REQUIRED"; exit 64; }
    sable_device_accept "$RELEASE" "$SUITE" "$SERIAL" "$EVIDENCE_ROOT"
    ;;

  *)
    echo "SABLE_ENTRYPOINT=FAIL_FUNCTION value=$FUNCTION" >&2
    usage
    exit 64
    ;;
esac
