#!/usr/bin/env bash

sable_die() {
  local marker="$1"
  local message="$2"
  local rc="${3:-1}"
  echo "${marker}=FAIL"
  echo "GATE_ERROR=${message}"
  exit "$rc"
}

sable_sha256() {
  sha256sum -- "$1" | awk '{print $1}'
}

sable_mask_serial() {
  local s="$1"
  local n="${#s}"
  if (( n <= 4 )); then
    printf '%s\n' "****"
  else
    printf '%*s%s\n' "$((n - 4))" '' "${s: -4}" | tr ' ' '*'
  fi
}

sable_git_clean_or_die() {
  local repo="$1"
  local dirty
  dirty="$(git -C "$repo" status --porcelain=v1 --untracked-files=normal)"
  if [[ -n "$dirty" ]]; then
    echo "$dirty"
    sable_die "SABLE_TOOL_SOURCE_CLEAN" "tooling checkout is dirty" 20
  fi
  echo "SABLE_TOOL_SOURCE_CLEAN=PASS"
}

sable_fastboot_getvar() {
  local fb="$1"
  local serial="$2"
  local key="$3"
  "$fb" -s "$serial" getvar "$key" </dev/null 2>&1 \
    | sed -n -E "s/^(\(bootloader\)[[:space:]]*)?${key}:[[:space:]]*//p" \
    | tail -n 1
}

sable_wait_fastboot_ready() {
  local fb="$1"
  local serial="$2"
  local expected_product="$3"
  local timeout_s="${4:-120}"
  local start now product
  start="$(date +%s)"
  while :; do
    product="$(sable_fastboot_getvar "$fb" "$serial" product || true)"
    if [[ "$product" == "$expected_product" ]]; then
      echo "FASTBOOT_GETVAR_READY=PASS"
      echo "FASTBOOT_PRODUCT=$product"
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout_s )); then
      echo "FASTBOOT_GETVAR_READY=FAIL"
      echo "FASTBOOT_LAST_PRODUCT=${product:-UNOBSERVABLE}"
      return 1
    fi
    sleep 2
  done
}

sable_wait_adb_boot_completed() {
  local adb_bin="$1"
  local serial="$2"
  local timeout_s="${3:-420}"
  local start now state boot
  start="$(date +%s)"
  while :; do
    state="$("$adb_bin" -s "$serial" get-state </dev/null 2>/dev/null || true)"
    if [[ "$state" == "device" ]]; then
      boot="$("$adb_bin" -s "$serial" shell getprop sys.boot_completed </dev/null 2>/dev/null | tr -d '\r')"
      if [[ "$boot" == "1" ]]; then
        echo "ADB_BOOT_COMPLETED=PASS"
        return 0
      fi
    fi
    now="$(date +%s)"
    if (( now - start >= timeout_s )); then
      echo "ADB_BOOT_COMPLETED=FAIL"
      return 1
    fi
    sleep 2
  done
}

sable_seal_evidence_dir() {
  local dir="$1"
  (
    cd "$dir"
    find . -type f ! -name SHA256SUMS.txt -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 sha256sum > SHA256SUMS.txt
  )
  echo "EVIDENCE_SEAL_SHA256=$(sable_sha256 "$dir/SHA256SUMS.txt")"
}

sable_run_sablectl() {
  local root="$1"
  shift
  PYTHONPATH="$root/tools/sablectl" python3 -m sablectl.cli "$@"
}


sable_artifact_kind_supported() {
  local kind="$1"
  local supported="${SABLE_DEVICE_ARTIFACT_KINDS:-}"
  local candidate
  for candidate in $supported; do
    [[ "$candidate" == "$kind" ]] && return 0
  done
  return 1
}

sable_require_adb_serial_exact_once() {
  local adb_bin="$1"
  local serial="$2"
  local -a ready=()
  local match_count=0
  local ready_serial

  mapfile -t ready < <("$adb_bin" devices </dev/null | awk 'NR>1 && $2=="device" {print $1}')
  for ready_serial in "${ready[@]}"; do
    [[ "$ready_serial" == "$serial" ]] && match_count=$((match_count + 1))
  done
  [[ "$match_count" -eq 1 ]] || {
    echo "SABLE_ADB_TARGET_SERIAL=FAIL"
    echo "SABLE_ADB_TARGET_MATCHES=$match_count"
    return 1
  }
  echo "SABLE_ADB_TARGET_SERIAL=PASS"
  echo "SABLE_ADB_OTHER_READY_COUNT=$(( ${#ready[@]} - match_count ))"
}

sable_require_fastboot_serial_exact_once() {
  local fastboot_bin="$1"
  local serial="$2"
  local -a ready=()
  local match_count=0
  local ready_serial

  mapfile -t ready < <("$fastboot_bin" devices </dev/null | awk 'NF>=1 {print $1}')
  for ready_serial in "${ready[@]}"; do
    [[ "$ready_serial" == "$serial" ]] && match_count=$((match_count + 1))
  done
  [[ "$match_count" -eq 1 ]] || {
    echo "SABLE_FASTBOOT_TARGET_SERIAL=FAIL"
    echo "SABLE_FASTBOOT_TARGET_MATCHES=$match_count"
    return 1
  }
  echo "SABLE_FASTBOOT_TARGET_SERIAL=PASS"
  echo "SABLE_FASTBOOT_OTHER_READY_COUNT=$(( ${#ready[@]} - match_count ))"
}
