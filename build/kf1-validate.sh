#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/out/kf1/$STAMP"
REPORT="$OUT/REPORT-${STAMP}-kf1-device-profile-validation.txt"
mkdir -p "$OUT"

status=0
{
  echo "SableOS KF1 Device Profile validation"
  echo "timestamp_utc=$STAMP"
  echo "source=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
  echo
  echo "===== PROFILE VALIDATOR ====="
  if python3 "$ROOT/build/validate_kf1_device_profile.py"       "$ROOT/product/keyboard-first/titan2.device-profile.json"; then
    echo "PROFILE_VALIDATOR=PASS"
  else
    echo "PROFILE_VALIDATOR=FAIL"
    status=1
  fi

  echo
  echo "===== TITAN 2 PROFILE TESTS ====="
  if python3 "$ROOT/tests/kf1/test_device_profile.py"; then
    echo "TITAN2_PROFILE_TESTS=PASS"
  else
    echo "TITAN2_PROFILE_TESTS=FAIL"
    status=1
  fi

  echo
  echo "===== KF1 RESULT ====="
  if (( status == 0 )); then
    echo "KF1_DEVICE_PROFILE_VALIDATION=PASS"
  else
    echo "KF1_DEVICE_PROFILE_VALIDATION=FAIL"
  fi
} > "$REPORT" 2>&1

(
  cd "$OUT"
  sha256sum "$(basename "$REPORT")" > SHA256SUMS
)

echo "KF1 validation report written:"
echo "  $REPORT"
echo "  result=$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
