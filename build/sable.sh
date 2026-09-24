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
  qualify [suite]
  build [--tmux|--direct]
  register-artifact --build-source SHA [legacy target-files options | generic artifact options]
  show-artifact --build-source SHA
  flash-plan --build-source SHA
  flash --build-source SHA --serial SERIAL --preserve-data --authorize
  accept --serial SERIAL [--suite NAME]

examples:
  bash build/sable.sh panther R9 ci full
  bash build/sable.sh panther R9 qualify physical-ux
  bash build/sable.sh panther R9 build --tmux
  bash build/sable.sh panther R9 register-artifact --build-source <sha> --target-files <zip> --sha256 <sha256> --android-info <path>
  bash build/sable.sh titan2 R10 register-artifact --build-source <sha> --artifact-kind gsi-system-image --primary-artifact system --artifact system=<system.img> --expected-sha256 system=<sha256>
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

  qualify)
    SUITE="${1:-${SABLE_DEVICE_DEFAULT_QUALIFICATION_SUITE:-default}}"
    [[ "${SABLE_DEVICE_QUALIFY_SUPPORTED:-NO}" == YES ]] || {
      echo "SABLE_QUALIFY=BLOCKED_UNQUALIFIED device=$DEVICE"
      exit 78
    }
    declare -F sable_device_qualify >/dev/null 2>&1 || {
      echo "SABLE_QUALIFY=FAIL_ADAPTER_FUNCTION_MISSING device=$DEVICE"
      exit 78
    }
    sable_device_qualify "$RELEASE" "$SUITE"
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
    ARTIFACT_KIND=""
    PRIMARY_ARTIFACT=""
    TARGET_FILES=""
    SHA256=""
    ANDROID_INFO=""
    OUT_DIR=""
    BUILD_EVIDENCE_DIR=""
    REPLACE=NO
    ARTIFACT_ARGS=()
    EXPECTED_SHA_ARGS=()
    METADATA_ARGS=()
    while (($#)); do
      case "$1" in
        --build-source) BUILD_SOURCE="$2"; shift 2 ;;
        --artifact-kind) ARTIFACT_KIND="$2"; shift 2 ;;
        --primary-artifact) PRIMARY_ARTIFACT="$2"; shift 2 ;;
        --artifact) ARTIFACT_ARGS+=("$2"); shift 2 ;;
        --expected-sha256) EXPECTED_SHA_ARGS+=("$2"); shift 2 ;;
        --metadata) METADATA_ARGS+=("$2"); shift 2 ;;
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

    if [[ -n "$TARGET_FILES" ]]; then
      [[ -z "$ARTIFACT_KIND" || "$ARTIFACT_KIND" == target-files ]] || {
        echo "SABLE_ARTIFACT_REGISTER=FAIL_LEGACY_KIND_MISMATCH"
        exit 64
      }
      ARTIFACT_KIND=target-files
      PRIMARY_ARTIFACT=target_files
      PRIMARY_SHA="$SHA256"
    else
      [[ -n "$ARTIFACT_KIND" && -n "$PRIMARY_ARTIFACT" ]] || {
        echo "SABLE_ARTIFACT_REGISTER=FAIL_GENERIC_IDENTITY"
        exit 64
      }
      PRIMARY_SHA=""
      for item in "${EXPECTED_SHA_ARGS[@]}"; do
        if [[ "${item%%=*}" == "$PRIMARY_ARTIFACT" ]]; then
          PRIMARY_SHA="${item#*=}"
        fi
      done
    fi
    [[ "$PRIMARY_SHA" =~ ^[0-9a-f]{64}$ ]] || {
      echo "SABLE_ARTIFACT_REGISTER=FAIL_PRIMARY_SHA256"
      exit 64
    }

    if declare -F sable_device_artifact_gate >/dev/null 2>&1; then
      sable_device_artifact_gate         "$RELEASE" "$BUILD_SOURCE" "$ARTIFACT_KIND" "$PRIMARY_SHA" "$BUILD_EVIDENCE_DIR"         || exit 66
    fi

    ARGS=(
      --registry-root "$REGISTRY_ROOT" register
      --device "$DEVICE"
      --release "$RELEASE"
      --build-source "$BUILD_SOURCE"
      --tool-source "$TOOL_SOURCE_COMMIT"
      --artifact-kind "$ARTIFACT_KIND"
      --primary-artifact "$PRIMARY_ARTIFACT"
    )
    if [[ -n "$TARGET_FILES" ]]; then
      ARGS+=(
        --target-files "$TARGET_FILES"
        --sha256 "$SHA256"
        --android-info "$ANDROID_INFO"
      )
    fi
    for item in "${ARTIFACT_ARGS[@]}"; do ARGS+=(--artifact "$item"); done
    for item in "${EXPECTED_SHA_ARGS[@]}"; do ARGS+=(--expected-sha256 "$item"); done
    for item in "${METADATA_ARGS[@]}"; do ARGS+=(--metadata "$item"); done
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
    [[ "${SABLE_DEVICE_FLASH_PLAN_SUPPORTED:-NO}" == YES ]] || {
      echo "SABLE_FLASH_PLAN=BLOCKED_UNQUALIFIED device=$DEVICE"
      exit 78
    }
    declare -F sable_device_flash_plan >/dev/null 2>&1 || {
      echo "SABLE_FLASH_PLAN=FAIL_ADAPTER_FUNCTION_MISSING device=$DEVICE"
      exit 78
    }

    python3 "$REGISTRY" --registry-root "$REGISTRY_ROOT" verify       --device "$DEVICE" --release "$RELEASE" --build-source "$BUILD_SOURCE"

    STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
    EVIDENCE_DIR="$EVIDENCE_ROOT/$DEVICE/${RELEASE,,}-physical/${STAMP}_flash-plan"
    mkdir -p "$EVIDENCE_DIR"
    sable_device_flash_plan "$RELEASE" "$BUILD_SOURCE" "$REGISTRY_ROOT" "$EVIDENCE_DIR"
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
