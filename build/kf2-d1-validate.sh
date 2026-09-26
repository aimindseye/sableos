#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/out/kf2-d1/$STAMP"
REPORT="$OUT/REPORT-${STAMP}-kf2-d1-titan2-defaults-validation.txt"
mkdir -p "$OUT"

status=0
{
  echo "SableOS KF2-D1 Titan 2 default-policy validation"
  echo "timestamp_utc=$STAMP"
  echo "source=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
  echo

  echo "===== KF2 POLICY VALIDATOR ====="
  if python3 "$ROOT/build/validate_kf2_keyboard_policy.py"       --profile "$ROOT/product/keyboard-first/titan2.device-profile.json"       --policy "$ROOT/product/keyboard-first/titan2.keyboard-policy.json"; then
    echo "POLICY_VALIDATOR=PASS"
  else
    echo "POLICY_VALIDATOR=FAIL"
    status=1
  fi

  echo
  echo "===== KF2 CORE TESTS ====="
  if python3 "$ROOT/tests/kf2/test_keyboard_policy.py"; then
    echo "KF2_CORE_TESTS=PASS"
  else
    echo "KF2_CORE_TESTS=FAIL"
    status=1
  fi

  echo
  echo "===== KF2-D1 TITAN 2 DEFAULT TESTS ====="
  if python3 "$ROOT/tests/kf2/test_titan2_defaults.py"; then
    echo "KF2_D1_DEFAULTS_TESTS=PASS"
  else
    echo "KF2_D1_DEFAULTS_TESTS=FAIL"
    status=1
  fi

  echo
  echo "===== KF2-D1 RESULT ====="
  if (( status == 0 )); then
    echo "KF2_D1_TITAN2_DEFAULTS_VALIDATION=PASS"
  else
    echo "KF2_D1_TITAN2_DEFAULTS_VALIDATION=FAIL"
  fi
} > "$REPORT" 2>&1

(
  cd "$OUT"
  sha256sum "$(basename "$REPORT")" > SHA256SUMS
)

echo "KF2-D1 validation report written:"
echo "  $REPORT"
echo "  result=$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
