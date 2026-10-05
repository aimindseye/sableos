#!/usr/bin/env bash
# Shared N1I-C1 Titan 2 flash helpers.
# No command in this file runs until one of these functions is explicitly called.

n1i_c1_env_value() {
  local file="$1" key="$2" out count
  out="$(sed -n "s/^${key}=//p" "$file")"
  count="$(printf '%s\n' "$out" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$count" == 1 ]] || return 1
  printf '%s\n' "$out"
}

n1i_c1_manifest_safe() {
  local file="$1" line path
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[0-9a-f]{64}[[:space:]][[:space:]][^[:space:]]+$ ]] || return 1
    path="${line#*  }"
    [[ "$path" != /* && "$path" != ".." && "$path" != ../* && "$path" != *"/../"* ]] ||
      return 1
  done < "$file"
}

n1i_c1_verify_artifact() {
  local artifact_dir="$1" expected_source="$2" expected_sha="$3"
  local expected_bytes="$4" expected_role="$5"
  local env_file="$artifact_dir/artifact.env"
  local sums="$artifact_dir/SHA256SUMS.txt"
  local system="$artifact_dir/system.img"
  local role mode source platform sha bytes contact flash manifest_sha manifest_count

  for file in "$env_file" "$sums" "$system" "$artifact_dir/system-image-info.txt"; do
    [[ -f "$file" ]] || {
      echo "N1I_C1_FLASH_ARTIFACT=FAIL_MISSING file=$file"
      return 1
    }
  done

  n1i_c1_manifest_safe "$sums" || {
    echo "N1I_C1_FLASH_ARTIFACT=FAIL_UNSAFE_MANIFEST"
    return 1
  }
  (
    cd "$artifact_dir" &&
      sha256sum -c SHA256SUMS.txt
  ) >/dev/null 2>&1 || {
    echo "N1I_C1_FLASH_ARTIFACT=FAIL_SEAL"
    return 1
  }

  role="$(n1i_c1_env_value "$env_file" ROLE)" || return 1
  mode="$(n1i_c1_env_value "$env_file" QUALIFICATION_MODE)" || return 1
  source="$(n1i_c1_env_value "$env_file" SOURCE_COMMIT)" || return 1
  platform="$(n1i_c1_env_value "$env_file" ANDROID_PLATFORM)" || return 1
  sha="$(n1i_c1_env_value "$env_file" SYSTEM_SHA256)" || return 1
  bytes="$(n1i_c1_env_value "$env_file" SYSTEM_BYTES)" || return 1
  contact="$(n1i_c1_env_value "$env_file" DEVICE_CONTACT)" || return 1
  flash="$(n1i_c1_env_value "$env_file" FLASH)" || return 1

  [[ "$role" == "$expected_role" ]] || return 1
  [[ "$mode" == POSTBUILD_READONLY ]] || return 1
  [[ "$source" == "$expected_source" ]] || return 1
  [[ "$platform" == 16 ]] || return 1
  [[ "$sha" == "$expected_sha" ]] || return 1
  [[ "$bytes" == "$expected_bytes" ]] || return 1
  [[ "$contact" == NONE && "$flash" == NONE ]] || return 1

  manifest_count="$(awk -v n="./system.img" '$2 == n || $2 == "system.img" {count++} END {print count+0}' "$sums")"
  [[ "$manifest_count" == 1 ]] || {
    echo "N1I_C1_FLASH_ARTIFACT=FAIL_SYSTEM_MANIFEST_COUNT count=$manifest_count"
    return 1
  }
  manifest_sha="$(awk '$2 == "./system.img" || $2 == "system.img" {print $1}' "$sums")"
  [[ "$manifest_sha" == "$expected_sha" ]] || {
    echo "N1I_C1_FLASH_ARTIFACT=FAIL_SYSTEM_MANIFEST_SHA"
    return 1
  }

  grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$artifact_dir/system-image-info.txt" || return 1
  grep -Fxq "GSI_IMAGE_FILE_BYTES=$expected_bytes" "$artifact_dir/system-image-info.txt" || return 1
  grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$expected_bytes" "$artifact_dir/system-image-info.txt" || return 1
  grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$artifact_dir/system-image-info.txt" || return 1

  echo "N1I_C1_FLASH_ARTIFACT=PASS"
}

n1i_c1_adb_listing() {
  "$ADB_BIN" devices 2>/dev/null
}

n1i_c1_fastboot_listing() {
  "$FASTBOOT_BIN" devices 2>/dev/null
}

n1i_c1_adb_state() {
  local count
  count="$(n1i_c1_adb_listing | awk -v s="$SERIAL" 'NR>1 && $1==s {n++} END {print n+0}')"
  [[ "$count" -le 1 ]] || {
    printf '%s\n' DUPLICATE
    return 0
  }
  [[ "$count" -eq 1 ]] || {
    printf '%s\n' ABSENT
    return 0
  }
  n1i_c1_adb_listing | awk -v s="$SERIAL" 'NR>1 && $1==s {print $2; exit}'
}

n1i_c1_fastboot_count() {
  n1i_c1_fastboot_listing |
    awk -v s="$SERIAL" '$1==s {n++} END {print n+0}'
}

n1i_c1_fastboot_getvar() {
  local key="$1" output
  output="$("$FASTBOOT_BIN" -s "$SERIAL" getvar "$key" 2>&1 || true)"
  if grep -Fq "FAILED (remote:" <<<"$output"; then
    return 1
  fi
  printf '%s\n' "$output" |
    sed -n "s/.*${key}: //p" |
    tail -n1 |
    tr -d '\r'
}

n1i_c1_probe_mode() {
  local adb_list fastboot_list adb_count adb_state fastboot_count userspace
  adb_list="$(n1i_c1_adb_listing)"
  fastboot_list="$(n1i_c1_fastboot_listing)"

  adb_count="$(
    awk -v s="$SERIAL" 'NR>1 && $1==s {n++} END {print n+0}' <<<"$adb_list"
  )"
  fastboot_count="$(
    awk -v s="$SERIAL" '$1==s {n++} END {print n+0}' <<<"$fastboot_list"
  )"

  if [[ "$adb_count" -gt 1 || "$fastboot_count" -gt 1 ]]; then
    printf '%s\n' AMBIGUOUS
    return 0
  fi
  if [[ "$adb_count" -eq 1 && "$fastboot_count" -eq 1 ]]; then
    printf '%s\n' AMBIGUOUS
    return 0
  fi
  if [[ "$adb_count" -eq 1 ]]; then
    adb_state="$(
      awk -v s="$SERIAL" 'NR>1 && $1==s {print $2; exit}' <<<"$adb_list"
    )"
    if [[ "$adb_state" == device ]]; then
      printf '%s\n' ANDROID_ADB
    else
      printf '%s\n' "ADB_UNREADY:${adb_state:-UNKNOWN}"
    fi
    return 0
  fi
  if [[ "$fastboot_count" -eq 1 ]]; then
    userspace="$(n1i_c1_fastboot_getvar is-userspace || true)"
    if [[ "${userspace,,}" == yes ]]; then
      printf '%s\n' FASTBOOTD
    elif [[ -n "$userspace" ]]; then
      printf '%s\n' FASTBOOT
    else
      printf '%s\n' FASTBOOT_UNKNOWN
    fi
    return 0
  fi
  printf '%s\n' ABSENT
}

n1i_c1_wait_fastboot_transport() {
  local timeout="$1" start now count
  start="$(date +%s)"
  while :; do
    count="$(n1i_c1_fastboot_count)"
    [[ "$count" -eq 1 ]] && return 0
    [[ "$count" -gt 1 ]] && return 2
    now="$(date +%s)"
    (( now - start >= timeout )) && return 1
    sleep 1
  done
}

n1i_c1_wait_fastbootd() {
  local timeout="$1" start now mode
  start="$(date +%s)"
  while :; do
    mode="$(n1i_c1_probe_mode)"
    [[ "$mode" == FASTBOOTD ]] && return 0
    [[ "$mode" == AMBIGUOUS || "$mode" == ADB_UNREADY:* ]] && return 2
    now="$(date +%s)"
    (( now - start >= timeout )) && return 1
    sleep 1
  done
}

n1i_c1_enter_fastbootd() {
  local mode
  mode="$(n1i_c1_probe_mode)"
  echo "N1I_C1_FLASH_INITIAL_MODE=$mode"

  case "$mode" in
    ANDROID_ADB)
      "$ADB_BIN" -s "$SERIAL" reboot bootloader </dev/null || return 1
      echo "N1I_C1_FLASH_MODE_TRANSITION=ANDROID_ADB_TO_FASTBOOT"
      n1i_c1_wait_fastboot_transport 90 || return 1
      mode="$(n1i_c1_probe_mode)"
      case "$mode" in
        FASTBOOTD)
          ;;
        FASTBOOT)
          "$FASTBOOT_BIN" -s "$SERIAL" reboot fastboot </dev/null || return 1
          echo "N1I_C1_FLASH_MODE_TRANSITION=FASTBOOT_TO_FASTBOOTD"
          n1i_c1_wait_fastbootd 90 || return 1
          ;;
        *)
          echo "N1I_C1_FLASH_MODE_TRANSITION=FAIL_AFTER_ADB mode=$mode"
          return 1
          ;;
      esac
      ;;
    FASTBOOT)
      "$FASTBOOT_BIN" -s "$SERIAL" reboot fastboot </dev/null || return 1
      echo "N1I_C1_FLASH_MODE_TRANSITION=FASTBOOT_TO_FASTBOOTD"
      n1i_c1_wait_fastbootd 90 || return 1
      ;;
    FASTBOOTD)
      echo "N1I_C1_FLASH_MODE_TRANSITION=NOT_REQUIRED_ALREADY_FASTBOOTD"
      ;;
    *)
      echo "N1I_C1_FLASH_MODE_TRANSITION=REFUSED mode=$mode"
      return 1
      ;;
  esac

  mode="$(n1i_c1_probe_mode)"
  [[ "$mode" == FASTBOOTD ]] || {
    echo "N1I_C1_FLASH_FINAL_MODE=FAIL mode=$mode"
    return 1
  }
  echo "N1I_C1_FLASH_FINAL_MODE=PASS_FASTBOOTD"
}

n1i_c1_wait_android_boot() {
  local timeout="$1" start now mode completed bootmode
  start="$(date +%s)"
  while :; do
    mode="$(n1i_c1_probe_mode)"
    if [[ "$mode" == ANDROID_ADB ]]; then
      completed="$("$ADB_BIN" -s "$SERIAL" shell getprop sys.boot_completed </dev/null 2>/dev/null | tr -d '\r')"
      bootmode="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.bootmode </dev/null 2>/dev/null | tr -d '\r')"
      [[ "${bootmode,,}" != *recovery* ]] || return 3
      [[ "$completed" == 1 ]] && return 0
    elif [[ "$mode" == FASTBOOT || "$mode" == FASTBOOTD ]]; then
      return 4
    elif [[ "$mode" == AMBIGUOUS || "$mode" == ADB_UNREADY:* ]]; then
      return 2
    fi
    now="$(date +%s)"
    (( now - start >= timeout )) && return 1
    sleep 2
  done
}
