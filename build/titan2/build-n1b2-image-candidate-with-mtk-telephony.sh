#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_SRC=""
STOCK_ROOT=""
FULL_CI_EVIDENCE_DIR=""
OUT_DIR=""
LUNCH_TARGET="treble_arm64_bvN-bp4a-userdebug"
JOBS="$(nproc --all)"
REGISTER_ARTIFACT="NO"

usage() {
  cat >&2 <<'EOF'
Usage:
  build/titan2/build-n1b2-image-candidate-with-mtk-telephony.sh \
    --android-src DIR \
    --stock-root DIR \
    --full-ci-evidence-dir DIR \
    [--out-dir DIR] \
    [--jobs N] \
    [--register-artifact YES|NO]

Runs the implemented PR208 flow:
  1. stage stock-derived Titan 2 MTK telephony/IMS payload locally
  2. generate a product makefile using PRODUCT_COPY_FILES
  3. inject the generated makefile into vendor/sable/n1b2/sable_n1b2_product_profile.mk
  4. build the N1B2 GSI image using the existing N1B2 build entrypoint
  5. verify the payload exists in target_files with matching SHA-256 values

This wrapper does not flash, does not use adb, and does not use fastboot.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-src) ANDROID_SRC="$2"; shift 2 ;;
    --android-src=*) ANDROID_SRC="${1#*=}"; shift ;;
    --stock-root) STOCK_ROOT="$2"; shift 2 ;;
    --stock-root=*) STOCK_ROOT="${1#*=}"; shift ;;
    --full-ci-evidence-dir) FULL_CI_EVIDENCE_DIR="$2"; shift 2 ;;
    --full-ci-evidence-dir=*) FULL_CI_EVIDENCE_DIR="${1#*=}"; shift ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --out-dir=*) OUT_DIR="${1#*=}"; shift ;;
    --lunch-target) LUNCH_TARGET="$2"; shift 2 ;;
    --lunch-target=*) LUNCH_TARGET="${1#*=}"; shift ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --jobs=*) JOBS="${1#*=}"; shift ;;
    --register-artifact) REGISTER_ARTIFACT="$2"; shift 2 ;;
    --register-artifact=*) REGISTER_ARTIFACT="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B2_MTK_IMAGE_BUILD=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ -n "$ANDROID_SRC" && -d "$ANDROID_SRC" ]] || { echo "N1B2_MTK_IMAGE_BUILD=FAIL_ANDROID_SRC_REQUIRED path=$ANDROID_SRC"; exit 64; }
[[ -n "$STOCK_ROOT" && -d "$STOCK_ROOT" ]] || { echo "N1B2_MTK_IMAGE_BUILD=FAIL_STOCK_ROOT_REQUIRED path=$STOCK_ROOT"; exit 64; }
[[ -n "$FULL_CI_EVIDENCE_DIR" && -d "$FULL_CI_EVIDENCE_DIR" ]] || { echo "N1B2_MTK_IMAGE_BUILD=FAIL_FULL_CI_EVIDENCE_DIR_REQUIRED path=$FULL_CI_EVIDENCE_DIR"; exit 64; }
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "N1B2_MTK_IMAGE_BUILD=FAIL_JOBS value=$JOBS"; exit 64; }
case "$REGISTER_ARTIFACT" in YES|NO) ;; *) echo "N1B2_MTK_IMAGE_BUILD=FAIL_REGISTER_ARTIFACT value=$REGISTER_ARTIFACT"; exit 64 ;; esac

ANDROID_SRC="$(cd "$ANDROID_SRC" && pwd)"
STOCK_ROOT="$(cd "$STOCK_ROOT" && pwd)"
FULL_CI_EVIDENCE_DIR="$(cd "$FULL_CI_EVIDENCE_DIR" && pwd)"
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(cd "$ANDROID_SRC/.." && pwd)/out_sable_t2_n1b2_sable_gsi_mtk_telephony"
fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_ROOT="${SABLE_N1B2_MTK_IMAGE_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b2-mtk-telephony-image}"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/build-with-mtk-telephony.log") 2>&1

echo "===== N1B2 MTK TELEPHONY IMAGE BUILD ====="
echo "ANDROID_SRC=$ANDROID_SRC"
echo "STOCK_ROOT=$STOCK_ROOT"
echo "OUT_DIR=$OUT_DIR"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "FULL_CI_EVIDENCE_DIR=$FULL_CI_EVIDENCE_DIR"
echo "BUILD_AUTHORIZED=YES_N1B2_MTK_TELEPHONY_IMAGE_ONLY"
echo "LOCAL_ANDROID_SOURCE_MUTATION=YES_GENERATED_VENDOR_SABLE_PAYLOAD_ONLY"
echo "SABLE_REPO_SOURCE_MUTATION=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PROPRIETARY_PAYLOAD_COMMITTED_TO_GIT=NO"
echo "VENDOR_PARTITION_COPY=NO"

PREP_EVIDENCE="$EVIDENCE_DIR/payload-prepare"
bash "$ROOT/build/titan2/prepare-n1b2-mtk-telephony-build-payload.sh" \
  --android-src "$ANDROID_SRC" \
  --stock-root "$STOCK_ROOT" \
  --evidence-dir "$PREP_EVIDENCE"

MANIFEST="$PREP_EVIDENCE/stage/pr208-stock-mtk-telephony-payload-manifest.tsv"
[[ -f "$MANIFEST" ]] || { echo "N1B2_MTK_IMAGE_BUILD=FAIL_PAYLOAD_MANIFEST path=$MANIFEST"; exit 67; }

BUILD_ARGS=(
  --android-src "$ANDROID_SRC"
  --full-ci-evidence-dir "$FULL_CI_EVIDENCE_DIR"
  --out-dir "$OUT_DIR"
  --lunch-target "$LUNCH_TARGET"
  --jobs "$JOBS"
)
if [[ "$REGISTER_ARTIFACT" == "NO" ]]; then
  BUILD_ARGS+=(--no-register)
fi

bash "$ROOT/build/titan2/build-n1b2-image-candidate.sh" "${BUILD_ARGS[@]}"

PRODUCT_OUT="$OUT_DIR/target/product/tdgsi_arm64_ab"
TARGET_FILES_DIR="$PRODUCT_OUT/obj/PACKAGING/target_files_intermediates"
mapfile -t TARGET_FILES < <(find "$TARGET_FILES_DIR" -type f -name '*target_files*.zip' -print 2>/dev/null | sort)
if [[ "${#TARGET_FILES[@]}" -ne 1 ]]; then
  echo "N1B2_MTK_IMAGE_BUILD=FAIL_TARGET_FILES_COUNT count=${#TARGET_FILES[@]}"
  printf 'TARGET_FILES_CANDIDATE=%s\n' "${TARGET_FILES[@]:-}"
  exit 67
fi
TARGET_FILES_ZIP="${TARGET_FILES[0]}"

VERIFY_EVIDENCE="$EVIDENCE_DIR/target-files-verify"
bash "$ROOT/build/titan2/verify-n1b2-mtk-telephony-target-files.sh" \
  --target-files "$TARGET_FILES_ZIP" \
  --manifest "$MANIFEST" \
  --evidence-dir "$VERIFY_EVIDENCE"

cat > "$EVIDENCE_DIR/n1b2-mtk-telephony-image.env" <<EOF
N1B2_MTK_TELEPHONY_IMAGE_BUILD=PASS
ANDROID_SRC=$ANDROID_SRC
STOCK_ROOT=$STOCK_ROOT
OUT_DIR=$OUT_DIR
FULL_CI_EVIDENCE_DIR=$FULL_CI_EVIDENCE_DIR
PAYLOAD_MANIFEST=$MANIFEST
TARGET_FILES_ZIP=$TARGET_FILES_ZIP
TARGET_FILES_VERIFY_EVIDENCE=$VERIFY_EVIDENCE
PROPRIETARY_PAYLOAD_COMMITTED_TO_GIT=NO
VENDOR_PARTITION_COPY=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
EOF

echo "N1B2_MTK_TELEPHONY_TARGET_FILES_VERIFY=PASS evidence_dir=$VERIFY_EVIDENCE"
echo "N1B2_MTK_TELEPHONY_IMAGE_BUILD_EVIDENCE=$EVIDENCE_DIR"
echo "N1B2_MTK_TELEPHONY_IMAGE_BUILD=PASS"
