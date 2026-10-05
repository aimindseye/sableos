#!/usr/bin/env bash
# Host-only C1 artifact + flash-receipt binding helpers. No adb/fastboot calls.

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
    [[ "$path" != /* && "$path" != *"../"* && "$path" != ".." ]] || return 1
  done < "$file"
}

n1i_c1_verify_host_binding() {
  local artifact_dir="$1" receipt_dir="$2" serial="$3" system_sha="$4"
  local image_source="$5" expected_role="$6" expected_platform="$7"
  local artifact_env artifact_sums artifact_system receipt_env receipt_sums
  local a_role a_mode a_source a_platform a_sha actual_sha
  local r_version r_serial r_role r_source r_sha r_target r_result r_post_serial r_post_mode

  artifact_env="$artifact_dir/artifact.env"
  artifact_sums="$artifact_dir/SHA256SUMS.txt"
  artifact_system="$artifact_dir/system.img"
  receipt_env="$receipt_dir/TITAN2_FLASH_RECEIPT.env"
  receipt_sums="$receipt_dir/SHA256SUMS.txt"

  for f in "$artifact_env" "$artifact_sums" "$artifact_system" "$receipt_env" "$receipt_sums"; do
    [[ -f "$f" ]] || { echo "required_file_missing=$f"; return 1; }
  done
  command -v sha256sum >/dev/null 2>&1 || { echo sha256sum_missing; return 1; }

  n1i_c1_manifest_safe "$artifact_sums" || { echo artifact_manifest_unsafe; return 1; }
  n1i_c1_manifest_safe "$receipt_sums" || { echo flash_receipt_manifest_unsafe; return 1; }
  (cd "$artifact_dir" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1) || { echo artifact_seal_invalid; return 1; }
  (cd "$receipt_dir" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1) || { echo flash_receipt_seal_invalid; return 1; }

  a_role="$(n1i_c1_env_value "$artifact_env" ROLE)" || { echo artifact_role_missing; return 1; }
  a_mode="$(n1i_c1_env_value "$artifact_env" QUALIFICATION_MODE)" || { echo artifact_qualification_mode_missing; return 1; }
  a_source="$(n1i_c1_env_value "$artifact_env" SOURCE_COMMIT)" || { echo artifact_source_missing; return 1; }
  a_platform="$(n1i_c1_env_value "$artifact_env" ANDROID_PLATFORM)" || { echo artifact_platform_missing; return 1; }
  a_sha="$(n1i_c1_env_value "$artifact_env" SYSTEM_SHA256)" || { echo artifact_system_sha_missing; return 1; }
  [[ "$a_role" == "$expected_role" ]] || { echo "artifact_role=$a_role"; return 1; }
  [[ "$a_mode" == POSTBUILD_READONLY ]] || { echo "artifact_qualification_mode=$a_mode"; return 1; }
  [[ "$a_source" == "$image_source" ]] || { echo "artifact_source=$a_source"; return 1; }
  [[ "$a_platform" == "$expected_platform" ]] || { echo "artifact_platform=$a_platform"; return 1; }
  [[ "$a_sha" == "$system_sha" ]] || { echo artifact_cli_sha_mismatch; return 1; }
  actual_sha="$(sha256sum "$artifact_system" | awk '{print $1}')"
  [[ "$actual_sha" == "$system_sha" ]] || { echo artifact_file_sha_mismatch; return 1; }

  r_version="$(n1i_c1_env_value "$receipt_env" TITAN2_FLASH_RECEIPT_VERSION)" || { echo receipt_version_missing; return 1; }
  r_serial="$(n1i_c1_env_value "$receipt_env" DEVICE_SERIAL)" || { echo receipt_serial_missing; return 1; }
  r_role="$(n1i_c1_env_value "$receipt_env" ARTIFACT_ROLE)" || { echo receipt_role_missing; return 1; }
  r_source="$(n1i_c1_env_value "$receipt_env" IMAGE_SOURCE_COMMIT)" || { echo receipt_source_missing; return 1; }
  r_sha="$(n1i_c1_env_value "$receipt_env" SYSTEM_SHA256)" || { echo receipt_sha_missing; return 1; }
  r_target="$(n1i_c1_env_value "$receipt_env" TARGET_PARTITION)" || { echo receipt_target_missing; return 1; }
  r_result="$(n1i_c1_env_value "$receipt_env" FLASH_RESULT)" || { echo receipt_result_missing; return 1; }
  r_post_serial="$(n1i_c1_env_value "$receipt_env" POST_FLASH_DEVICE_SERIAL)" || { echo receipt_post_serial_missing; return 1; }
  r_post_mode="$(n1i_c1_env_value "$receipt_env" POST_FLASH_MODE)" || { echo receipt_post_mode_missing; return 1; }

  [[ "$r_version" == 1 ]] || { echo "receipt_version=$r_version"; return 1; }
  [[ "$r_serial" == "$serial" && "$r_post_serial" == "$serial" ]] || { echo flash_receipt_serial_mismatch; return 1; }
  [[ "$r_role" == "$expected_role" ]] || { echo "receipt_role=$r_role"; return 1; }
  [[ "$r_source" == "$image_source" ]] || { echo "receipt_source=$r_source"; return 1; }
  [[ "$r_sha" == "$system_sha" ]] || { echo flash_receipt_sha_mismatch; return 1; }
  [[ "$r_target" == system_a ]] || { echo "receipt_target=$r_target"; return 1; }
  [[ "$r_result" == PASS ]] || { echo "receipt_result=$r_result"; return 1; }
  [[ "$r_post_mode" == ANDROID_ADB ]] || { echo "receipt_post_mode=$r_post_mode"; return 1; }
  return 0
}
