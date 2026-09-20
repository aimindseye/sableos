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
