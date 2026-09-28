#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DEFAULT_LUNCH_TARGET="treble_arm64_bvN-bp4a-userdebug"
DEFAULT_ACTIVE_PRODUCT_MK="device/phh/treble/treble_arm64_bvN.mk"
DEFAULT_PRODUCT_OUT_REL="target/product/tdgsi_arm64_ab"

ANDROID_SRC=""
OUT_DIR=""
FULL_CI_EVIDENCE_DIR=""
LUNCH_TARGET="$DEFAULT_LUNCH_TARGET"
JOBS="$(nproc --all)"
REGISTER_ARTIFACT=YES

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/build-n1b-phase-08-image-candidate.sh \
    --android-src <restless/android source tree> \
    --full-ci-evidence-dir <local-ci evidence dir for current source commit> \
    [--out-dir <absolute out dir>] \
    [--jobs <n>] \
    [--no-register]

This builds and optionally registers the Titan2/N1B system.img candidate only.
It does not contact devices, does not run bootloader tooling, does not flash,
does not erase userdata, and does not make a public-release or production-signing
claim.
EOF
}

while (($#)); do
  case "$1" in
    --android-src) ANDROID_SRC="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --full-ci-evidence-dir) FULL_CI_EVIDENCE_DIR="$2"; shift 2 ;;
    --lunch-target) LUNCH_TARGET="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --no-register) REGISTER_ARTIFACT=NO; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ -n "$ANDROID_SRC" ]] || { echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_ANDROID_SRC_REQUIRED"; usage; exit 64; }
[[ -n "$FULL_CI_EVIDENCE_DIR" ]] || { echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FULL_CI_EVIDENCE_REQUIRED"; usage; exit 64; }
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_JOBS value=$JOBS"; exit 64; }

ANDROID_SRC="$(cd "$ANDROID_SRC" && pwd)"
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(cd "$ANDROID_SRC/.." && pwd)/out_sable_t2_n1_sable_gsi"
fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
FULL_CI_EVIDENCE_DIR="$(cd "$FULL_CI_EVIDENCE_DIR" && pwd)"

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
SOURCE_DIRTY="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=normal)"
if [[ -n "$SOURCE_DIRTY" ]]; then
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_DIRTY_SABLE_SOURCE"
  printf '%s\n' "$SOURCE_DIRTY"
  exit 2
fi

FULL_CI_LOG="$FULL_CI_EVIDENCE_DIR/local-ci.log"
[[ -f "$FULL_CI_LOG" ]] || { echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FULL_CI_LOG path=$FULL_CI_LOG"; exit 65; }

grep -Fq "SABLE_LOCAL_CI=PASS" "$FULL_CI_LOG" || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FULL_CI_PASS_MARKER"
  exit 65
}
grep -Fq "PROFILE=full" "$FULL_CI_LOG" || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FULL_CI_PROFILE"
  exit 65
}
grep -Fq "SABLEOS_DEVICE=titan2" "$FULL_CI_LOG" || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FULL_CI_DEVICE"
  exit 65
}
grep -Fq "SABLEOS_RELEASE_VERSION=N1B" "$FULL_CI_LOG" || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FULL_CI_RELEASE"
  exit 65
}
grep -Fq "SOURCE_COMMIT=$SOURCE_COMMIT" "$FULL_CI_LOG" || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FULL_CI_SOURCE_COMMIT expected=$SOURCE_COMMIT"
  exit 65
}

ACTIVE_PRODUCT_MK="$ANDROID_SRC/$DEFAULT_ACTIVE_PRODUCT_MK"
[[ -f "$ACTIVE_PRODUCT_MK" ]] || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_ACTIVE_PRODUCT_MK path=$ACTIVE_PRODUCT_MK"
  exit 66
}
grep -Fq 'vendor/sable/' "$ACTIVE_PRODUCT_MK" || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_ACTIVE_PRODUCT_GRAPH_MISSING_SABLE_INHERIT path=$DEFAULT_ACTIVE_PRODUCT_MK"
  exit 66
}

for forbidden in titan2-touchpadd 'uinput' 'SELINUX_IGNORE_NEVERALLOWS := true' 'BOARD_KERNEL_CMDLINE'; do
  if grep -Fq "$forbidden" "$ACTIVE_PRODUCT_MK"; then
    echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_FORBIDDEN_ACTIVE_PRODUCT_TOKEN token=$forbidden"
    exit 66
  fi
done

[[ -f "$ANDROID_SRC/build/envsetup.sh" ]] || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_ENVSETUP path=$ANDROID_SRC/build/envsetup.sh"
  exit 66
}

STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_08_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-08-image-build-candidate}"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/build.log") 2>&1

echo "===== N1B PHASE 08 IMAGE BUILD CANDIDATE ====="
echo "ROOT=$ROOT"
echo "ANDROID_SRC=$ANDROID_SRC"
echo "OUT_DIR=$OUT_DIR"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "FULL_CI_EVIDENCE_DIR=$FULL_CI_EVIDENCE_DIR"
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=YES_N1B_IMAGE_ONLY"
echo "IMAGE_BUILD_AUTHORIZED=YES_N1B_CANDIDATE_ONLY"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "ARTIFACT_KIND=gsi-system-image"
echo "PRIMARY_ARTIFACT=system"
echo "LUNCH_TARGET=$LUNCH_TARGET"
echo "ACTIVE_PRODUCT_MK=$DEFAULT_ACTIVE_PRODUCT_MK"
echo "REGISTER_ARTIFACT=$REGISTER_ARTIFACT"

bash "$ROOT/build/gates/n1b-phase-08-image-build-candidate-contract.sh" "$ROOT"
bash "$ROOT/build/titan2/qualify-n1b-phase-08-image-build-candidate-readiness.sh" "$ROOT"

(
  cd "$ANDROID_SRC"
  if command -v repo >/dev/null 2>&1 && [[ -d .repo ]]; then
    repo manifest -r > "$EVIDENCE_DIR/repo-manifest-r.xml"
    echo "N1B_PHASE_08_REPO_MANIFEST_R=PASS path=$EVIDENCE_DIR/repo-manifest-r.xml"
  else
    echo "N1B_PHASE_08_REPO_MANIFEST_R=SKIP_REPO_TOOL_OR_METADATA_ABSENT"
  fi

  export OUT_DIR="$OUT_DIR"
  # AOSP/Restless envsetup.sh is not nounset-safe. Keep the driver strict, but
  # source envsetup with nounset disabled, then restore strict mode before lunch.
  set +e +u
  # shellcheck source=/dev/null
  source build/envsetup.sh
  envsetup_rc=$?
  set -euo pipefail
  if [[ "$envsetup_rc" -ne 0 ]]; then
    echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_ENVSETUP_SOURCE rc=$envsetup_rc"
    exit "$envsetup_rc"
  fi
  echo "N1B_PHASE_08_ENVSETUP_SOURCE=PASS_NOUNSET_COMPAT"

  lunch "$LUNCH_TARGET"

  echo "N1B_PHASE_08_BUILD_GOALS=systemimage,target-files-package,otatools"
  m -j"$JOBS" systemimage target-files-package otatools
)

PRODUCT_OUT="$OUT_DIR/$DEFAULT_PRODUCT_OUT_REL"
SYSTEM_IMG="$PRODUCT_OUT/system.img"
TARGET_FILES_DIR="$PRODUCT_OUT/obj/PACKAGING/target_files_intermediates"

[[ -f "$SYSTEM_IMG" ]] || {
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_SYSTEM_IMG path=$SYSTEM_IMG"
  exit 67
}

mapfile -t TARGET_FILES < <(find "$TARGET_FILES_DIR" -type f -name '*target_files*.zip' -print 2>/dev/null | sort)
if [[ "${#TARGET_FILES[@]}" -ne 1 ]]; then
  echo "N1B_PHASE_08_IMAGE_BUILD=FAIL_TARGET_FILES_COUNT count=${#TARGET_FILES[@]}"
  printf 'TARGET_FILES_CANDIDATE=%s\n' "${TARGET_FILES[@]:-}"
  exit 67
fi
TARGET_FILES_ZIP="${TARGET_FILES[0]}"

SYSTEM_SHA256="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
TARGET_FILES_SHA256="$(sha256sum "$TARGET_FILES_ZIP" | awk '{print $1}')"
SYSTEM_BYTES="$(stat -c%s "$SYSTEM_IMG")"
TARGET_FILES_BYTES="$(stat -c%s "$TARGET_FILES_ZIP")"
SYSTEM_FILE_TYPE="$(file -b "$SYSTEM_IMG" 2>/dev/null || true)"

compute_logical_bytes() {
  local image="$1"
  local host_simg2img="$OUT_DIR/host/linux-x86/bin/simg2img"
  local raw
  raw="$(mktemp "$EVIDENCE_DIR/system.raw.XXXXXX")"
  if [[ -x "$host_simg2img" ]] && "$host_simg2img" "$image" "$raw" >/dev/null 2>&1; then
    stat -c%s "$raw"
    rm -f "$raw"
    return 0
  fi
  rm -f "$raw"
  stat -c%s "$image"
}

SYSTEM_LOGICAL_BYTES="$(compute_logical_bytes "$SYSTEM_IMG")"

python3 - "$TARGET_FILES_ZIP" <<'PY'
from __future__ import annotations
import sys
import zipfile

target_files = sys.argv[1]
required = {
    "SYSTEM/product/etc/sableos/n1-substrate.env",
}
with zipfile.ZipFile(target_files) as zf:
    names = set(zf.namelist())

missing = sorted(required - names)
if missing:
    print("N1B_PHASE_08_TARGET_FILES_SABLE_MARKER=FAIL")
    for item in missing:
        print(f"N1B_PHASE_08_TARGET_FILES_MISSING={item}")
    raise SystemExit(1)

print("N1B_PHASE_08_TARGET_FILES_SABLE_MARKER=PASS")
PY

cat > "$EVIDENCE_DIR/n1b-phase-08-image-build.env" <<EOF
N1B_PHASE_08_IMAGE_BUILD=PASS
DEVICE=titan2
RELEASE=N1B
SOURCE_COMMIT=$SOURCE_COMMIT
ANDROID_SRC=$ANDROID_SRC
OUT_DIR=$OUT_DIR
PRODUCT_OUT=$PRODUCT_OUT
LUNCH_TARGET=$LUNCH_TARGET
ACTIVE_PRODUCT_MK=$DEFAULT_ACTIVE_PRODUCT_MK
FULL_CI_EVIDENCE_DIR=$FULL_CI_EVIDENCE_DIR
SYSTEM_IMG=$SYSTEM_IMG
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
SYSTEM_LOGICAL_BYTES=$SYSTEM_LOGICAL_BYTES
SYSTEM_FILE_TYPE=$SYSTEM_FILE_TYPE
TARGET_FILES_ZIP=$TARGET_FILES_ZIP
TARGET_FILES_SHA256=$TARGET_FILES_SHA256
TARGET_FILES_BYTES=$TARGET_FILES_BYTES
ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "SYSTEM_SHA256=$SYSTEM_SHA256"
echo "SYSTEM_BYTES=$SYSTEM_BYTES"
echo "SYSTEM_LOGICAL_BYTES=$SYSTEM_LOGICAL_BYTES"
echo "TARGET_FILES_ZIP=$TARGET_FILES_ZIP"
echo "TARGET_FILES_SHA256=$TARGET_FILES_SHA256"
echo "TARGET_FILES_BYTES=$TARGET_FILES_BYTES"
echo "N1B_PHASE_08_IMAGE_BUILD_EVIDENCE=$EVIDENCE_DIR"

if [[ "$REGISTER_ARTIFACT" == YES ]]; then
  bash "$ROOT/build/sable.sh" titan2 N1B register-artifact \
    --build-source "$SOURCE_COMMIT" \
    --artifact-kind gsi-system-image \
    --primary-artifact system \
    --artifact "system=$SYSTEM_IMG" \
    --expected-sha256 "system=$SYSTEM_SHA256" \
    --out-dir "$OUT_DIR" \
    --build-evidence-dir "$EVIDENCE_DIR" \
    --metadata "artifact_logical_bytes=$SYSTEM_LOGICAL_BYTES" \
    --metadata "n1b_phase_08_image_build_evidence_dir=$EVIDENCE_DIR" \
    --metadata "n1b_full_local_ci_evidence_dir=$FULL_CI_EVIDENCE_DIR" \
    --metadata "n1b_full_local_ci_profile=full" \
    --metadata "active_product_mk=$DEFAULT_ACTIVE_PRODUCT_MK" \
    --metadata "lunch_target=$LUNCH_TARGET" \
    --metadata "device_contact_authorized=NO" \
    --metadata "flash_authorized=NO" \
    --metadata "public_release=NO" \
    --metadata "production_signing=NO"

  echo "N1B_PHASE_08_ARTIFACT_REGISTRATION=PASS"
else
  echo "N1B_PHASE_08_ARTIFACT_REGISTRATION=SKIP_NO_REGISTER"
fi

echo "===== N1B PHASE 08 IMAGE BUILD CANDIDATE RESULT ====="
echo "FAILURES=0"
echo "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE=PASS"
