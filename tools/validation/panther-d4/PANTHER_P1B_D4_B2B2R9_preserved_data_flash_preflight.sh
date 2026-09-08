#!/usr/bin/env bash
set -uo pipefail
umask 077

# PANTHER P1B-D4-B2B2R9 / PRESERVED-DATA DEVICE + FLASH READINESS PREFLIGHT
#
# Purpose:
#   Transition from offline artifact causality to empirical device validation
#   WITHOUT flashing, rebooting, changing slots, unlocking, erasing, or wiping.
#
# Device contact is opt-in:
#   DEVICE_CONTACT_AUTHORIZED=YES ./this_script.sh
#
# R9 never performs mutating fastboot/adb operations. A locked bootloader fails
# closed because unlocking would wipe userdata and defeat the preserved-data test.

WS="${WS:-/srv/data/sableos_panther_graphene_2026081300_workspace}"
PRODUCT="${PRODUCT:-panther}"

B2_OUT="${B2_OUT:-$WS/out_d4_b2_final}"
B2_PRODUCT_OUT="${B2_PRODUCT_OUT:-$B2_OUT/target/product/$PRODUCT}"
B2_TARGET_FILES="${B2_TARGET_FILES:-$B2_PRODUCT_OUT/obj/PACKAGING/target_files_intermediates/panther-target_files.zip}"

R7_EVIDENCE_DIR="${R7_EVIDENCE_DIR:-/tmp/PANTHER_P1B_D4_B2B2R7R7_FSVERITY_FIDELITY_20260908_111825}"
EXPECTED_R7_EVIDENCE_SEAL_SHA256="d591fdd43c96e2a7ccee296203654794a8a0b3c3a89ae9bf73121296100ff884"

R8_EVIDENCE_DIR="${R8_EVIDENCE_DIR:-/tmp/PANTHER_P1B_D4_B2B2R8R4_ART_PRODUCER_CAUSALITY_20260908_120719}"
EXPECTED_R8_EVIDENCE_SEAL_SHA256="e447caff4548a71094d0f47442e00fe9e58558bf951b63b4d753f75985938c50"

EXPECTED_B2_MANIFEST_PB_SHA256="c006f36d2181e9a302c275d3d8dfeb8c3ef88ac126738fe05f33736dc9b2f429"

DEVICE_CONTACT_AUTHORIZED="${DEVICE_CONTACT_AUTHORIZED:-NO}"

STAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/PANTHER_P1B_D4_B2B2R9_PRESERVED_DATA_FLASH_PREFLIGHT_${STAMP}}"
LOG="$EVIDENCE_DIR/r9_preserved_data_flash_preflight.log"

if [[ -e "$EVIDENCE_DIR" ]]; then
  echo "GATE_ERROR=EVIDENCE_DIR_ALREADY_EXISTS path=$EVIDENCE_DIR" >&2
  exit 90
fi
mkdir "$EVIDENCE_DIR" || exit 90

sha256_file() {
  sha256sum -- "$1" | awk '{print $1}'
}

fail() {
  echo "GATE_ERROR=$1"
}

verify_evidence_dir() {
  local label="$1"
  local dir="$2"
  local expected_seal_sha="$3"
  local result_marker="$4"
  local log_pattern="$5"

  echo "===== BIND $label EVIDENCE ====="
  echo "${label}_EVIDENCE_DIR=$dir"

  local seal="$dir/evidence.sha256"
  [[ -d "$dir" ]] || { echo "${label}_BINDING=FAIL reason=evidence_dir_missing"; return 1; }
  [[ -f "$seal" ]] || { echo "${label}_BINDING=FAIL reason=evidence_seal_missing"; return 1; }

  local seal_sha
  seal_sha="$(sha256_file "$seal")" || return 1
  echo "${label}_EVIDENCE_SEAL=$seal"
  echo "${label}_EVIDENCE_SEAL_SHA256=$seal_sha"
  if [[ "$seal_sha" != "$expected_seal_sha" ]]; then
    echo "${label}_BINDING=FAIL reason=seal_hash_mismatch expected=$expected_seal_sha actual=$seal_sha"
    return 1
  fi

  (
    cd "$dir" || exit 1
    sha256sum -c evidence.sha256
  ) > "$EVIDENCE_DIR/${label,,}_seal_verify.txt" 2>&1
  local verify_rc=$?
  echo "${label}_EVIDENCE_MEMBER_VERIFY_RC=$verify_rc"
  [[ "$verify_rc" -eq 0 ]] || {
    echo "${label}_BINDING=FAIL reason=member_hash_verify_failed"
    return 1
  }

  if [[ -n "$result_marker" ]]; then
    grep -R -Fq -- "$result_marker" "$dir"/*.txt "$dir"/*.log 2>/dev/null || {
      echo "${label}_BINDING=FAIL reason=required_result_marker_missing marker=$result_marker"
      return 1
    }
  fi
  if [[ -n "$log_pattern" ]]; then
    grep -R -Fq -- "$log_pattern" "$dir"/*.log 2>/dev/null || {
      echo "${label}_BINDING=FAIL reason=required_evidence_marker_missing marker=$log_pattern"
      return 1
    }
  fi

  echo "${label}_EVIDENCE_MEMBER_VERIFY=PASS"
  echo "${label}_BINDING=PASS"
  return 0
}

inventory_b2() {
  echo "===== B2 FLASH-ARTIFACT READINESS ====="
  echo "B2_OUT=$B2_OUT"
  echo "B2_PRODUCT_OUT=$B2_PRODUCT_OUT"
  echo "B2_TARGET_FILES=$B2_TARGET_FILES"

  [[ -d "$B2_OUT" ]] || { fail "B2_OUT_MISSING"; return 33; }
  [[ -d "$B2_PRODUCT_OUT" ]] || { fail "B2_PRODUCT_OUT_MISSING"; return 33; }
  [[ -f "$B2_TARGET_FILES" ]] || { fail "B2_TARGET_FILES_MISSING"; return 33; }

  python3 -u - "$B2_TARGET_FILES" "$EXPECTED_B2_MANIFEST_PB_SHA256" "$EVIDENCE_DIR" <<'PY'
import hashlib, io, pathlib, sys, zipfile

tf = pathlib.Path(sys.argv[1])
expected = sys.argv[2]
evidence = pathlib.Path(sys.argv[3])

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

with zipfile.ZipFile(tf, "r") as zf:
    apk = zf.read("SYSTEM/etc/security/fsverity/BuildManifest.apk")
    with zipfile.ZipFile(io.BytesIO(apk), "r") as az:
        pb = az.read("assets/build_manifest.pb")
    got = sha256_bytes(pb)
    print(f"B2_MANIFEST_PB_SHA256={got}")
    if got != expected:
        print(f"GATE_ERROR=B2_MANIFEST_POPULATION_MISMATCH expected={expected} actual={got}")
        raise SystemExit(33)

    misc = ""
    try:
        misc = zf.read("META/misc_info.txt").decode("utf-8", "replace")
    except KeyError:
        pass

    ab = ""
    try:
        ab = zf.read("META/ab_partitions.txt").decode("utf-8", "replace")
    except KeyError:
        pass

(evidence / "B2_misc_info.txt").write_text(misc, encoding="utf-8")
(evidence / "B2_ab_partitions.txt").write_text(ab, encoding="utf-8")

interesting = {}
for raw in misc.splitlines():
    if "=" not in raw:
        continue
    k, v = raw.split("=", 1)
    if k in {
        "ab_update",
        "avb_enable",
        "dynamic_partition_list",
        "super_partition_groups",
        "virtual_ab",
        "virtual_ab_retrofit",
        "use_dynamic_partitions",
        "building_system_other_image",
    }:
        interesting[k] = v

for k in sorted(interesting):
    print(f"B2_META_{k}={interesting[k]}")
print(f"B2_AB_PARTITION_COUNT={len([x for x in ab.splitlines() if x.strip()])}")
print("B2_TARGET_FILES_POPULATION_BINDING=PASS")
PY
  local py_rc=$?
  [[ "$py_rc" -eq 0 ]] || return "$py_rc"

  local inv="$EVIDENCE_DIR/b2_flash_artifact_inventory.tsv"
  printf 'kind\tpath\tsize\tsha256_or_status\n' > "$inv"

  local found_critical=0
  local name path size sha
  for name in \
    boot.img \
    init_boot.img \
    vendor_boot.img \
    vendor_kernel_boot.img \
    dtbo.img \
    vbmeta.img \
    vbmeta_system.img \
    vbmeta_vendor.img
  do
    path="$B2_PRODUCT_OUT/$name"
    if [[ -f "$path" ]]; then
      size="$(stat -c '%s' -- "$path")"
      sha="$(sha256_file "$path")" || return 33
      printf 'critical_image\t%s\t%s\t%s\n' "$path" "$size" "$sha" >> "$inv"
      echo "B2_CRITICAL_IMAGE_PRESENT=PASS name=$name size=$size sha256=$sha"
      found_critical=$((found_critical + 1))
    else
      printf 'critical_image\t%s\t0\tABSENT\n' "$path" >> "$inv"
      echo "B2_CRITICAL_IMAGE_PRESENT=ABSENT name=$name"
    fi
  done
  echo "B2_CRITICAL_IMAGE_PRESENT_COUNT=$found_critical"

  for path in \
    "$B2_PRODUCT_OUT/super.img" \
    "$B2_PRODUCT_OUT/system.img" \
    "$B2_PRODUCT_OUT/product.img" \
    "$B2_PRODUCT_OUT/vendor.img"
  do
    if [[ -f "$path" ]]; then
      size="$(stat -c '%s' -- "$path")"
      printf 'large_image\t%s\t%s\tSHA256_SKIPPED_PREFLIGHT_PERFORMANCE_BOUND\n' "$path" "$size" >> "$inv"
      echo "B2_LARGE_IMAGE_PRESENT=PASS path=$path size=$size"
    fi
  done

  local d
  for d in "$B2_PRODUCT_OUT" "$B2_OUT/dist"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r -d '' path; do
      size="$(stat -c '%s' -- "$path")"
      printf 'archive_candidate\t%s\t%s\tSHA256_DEFERRED_UNTIL_EXACT_FLASH_PACKAGE_SELECTION\n' "$path" "$size" >> "$inv"
      echo "B2_FLASH_ARCHIVE_CANDIDATE path=$path size=$size"
    done < <(
      find "$d" -maxdepth 1 -type f \
        \( -name '*.zip' -o -name '*.img' \) \
        -print0 2>/dev/null | LC_ALL=C sort -z
    )
  done

  echo "B2_FLASH_ARTIFACT_INVENTORY=$inv"

  local avbtool="$B2_OUT/host/linux-x86/bin/avbtool"
  if [[ -x "$avbtool" ]]; then
    echo "AVBTOOL_PATH=$avbtool"
    echo "AVBTOOL_SHA256=$(sha256_file "$avbtool")"
    : > "$EVIDENCE_DIR/avb_image_info.txt"
    for name in vbmeta.img vbmeta_system.img vbmeta_vendor.img boot.img init_boot.img vendor_boot.img; do
      path="$B2_PRODUCT_OUT/$name"
      [[ -f "$path" ]] || continue
      {
        echo "===== $path ====="
        "$avbtool" info_image --image "$path"
        echo
      } >> "$EVIDENCE_DIR/avb_image_info.txt" 2>&1
      local avb_rc=$?
      echo "AVBTOOL_INFO_IMAGE_RC=$avb_rc image=$name"
      [[ "$avb_rc" -eq 0 ]] || {
        fail "AVB_IMAGE_INFO_FAILED image=$name rc=$avb_rc"
        return 33
      }
    done
    echo "B2_AVB_IMAGE_METADATA_CAPTURE=PASS"
  else
    echo "AVBTOOL_PATH=NOT_FOUND"
    echo "B2_AVB_IMAGE_METADATA_CAPTURE=NOT_AVAILABLE"
  fi

  echo "B2_FLASH_ARTIFACT_READINESS=PASS"
  return 0
}

adb_getprop() {
  local key="$1"
  adb shell getprop "$key" 2>/dev/null | tr -d '\r' | tail -n 1
}

fastboot_getvar() {
  local key="$1"
  fastboot getvar "$key" 2>&1 \
    | sed -n -E "s/^(\(bootloader\)[[:space:]]*)?${key}:[[:space:]]*//p" \
    | tail -n 1
}

device_preflight() {
  echo "===== DEVICE CONTACT AUTHORIZATION GATE ====="
  echo "DEVICE_CONTACT_AUTHORIZED=$DEVICE_CONTACT_AUTHORIZED"
  echo "DEVICE_REBOOT_AUTHORIZED=NO"
  echo "FLASH_AUTHORIZED=NO"
  echo "SLOT_CHANGE_AUTHORIZED=NO"
  echo "BOOTLOADER_UNLOCK_AUTHORIZED=NO"
  echo "USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO"

  if [[ "$DEVICE_CONTACT_AUTHORIZED" != "YES" ]]; then
    fail "DEVICE_CONTACT_NOT_AUTHORIZED run_with_DEVICE_CONTACT_AUTHORIZED=YES"
    return 34
  fi

  local adb_path fastboot_path
  adb_path="$(command -v adb 2>/dev/null || true)"
  fastboot_path="$(command -v fastboot 2>/dev/null || true)"

  [[ -n "$adb_path" ]] || { fail "ADB_NOT_FOUND"; return 33; }
  [[ -n "$fastboot_path" ]] || { fail "FASTBOOT_NOT_FOUND"; return 33; }

  echo "ADB_PATH=$adb_path"
  echo "ADB_SHA256=$(sha256_file "$adb_path")"
  echo "FASTBOOT_PATH=$fastboot_path"
  echo "FASTBOOT_SHA256=$(sha256_file "$fastboot_path")"

  adb devices > "$EVIDENCE_DIR/adb_devices.txt" 2>&1
  fastboot devices > "$EVIDENCE_DIR/fastboot_devices.txt" 2>&1

  local adb_count fastboot_count
  adb_count="$(awk 'NR>1 && NF>=2 {c++} END{print c+0}' "$EVIDENCE_DIR/adb_devices.txt")"
  fastboot_count="$(awk 'NF>=1 {c++} END{print c+0}' "$EVIDENCE_DIR/fastboot_devices.txt")"
  echo "ADB_DEVICE_COUNT=$adb_count"
  echo "FASTBOOT_DEVICE_COUNT=$fastboot_count"

  if (( adb_count > 1 || fastboot_count > 1 )); then
    fail "MULTIPLE_DEVICES_PRESENT"
    return 33
  fi
  if (( adb_count == 0 && fastboot_count == 0 )); then
    fail "DEVICE_NOT_PRESENT"
    return 33
  fi
  if (( adb_count == 1 && fastboot_count == 1 )); then
    fail "AMBIGUOUS_DEVICE_TRANSPORT_BOTH_ADB_AND_FASTBOOT"
    return 33
  fi

  local mode product_device flash_locked vbmeta_state unlocked current_slot
  if (( adb_count == 1 )); then
    mode="ADB"
    local adb_state
    adb_state="$(awk 'NR>1 && NF>=2 {print $2; exit}' "$EVIDENCE_DIR/adb_devices.txt")"
    echo "DEVICE_TRANSPORT_MODE=$mode"
    echo "ADB_STATE=$adb_state"
    [[ "$adb_state" == "device" ]] || {
      fail "ADB_DEVICE_NOT_AUTHORIZED_OR_READY state=$adb_state"
      return 33
    }

    product_device="$(adb_getprop ro.product.device)"
    current_slot="$(adb_getprop ro.boot.slot_suffix)"
    flash_locked="$(adb_getprop ro.boot.flash.locked)"
    vbmeta_state="$(adb_getprop ro.boot.vbmeta.device_state)"

    echo "DEVICE_PRODUCT=$product_device"
    echo "CURRENT_SLOT_SUFFIX=$current_slot"
    echo "RO_BOOT_FLASH_LOCKED=$flash_locked"
    echo "RO_BOOT_VBMETA_DEVICE_STATE=$vbmeta_state"
    echo "VERIFIED_BOOT_STATE=$(adb_getprop ro.boot.verifiedbootstate)"
    echo "BUILD_FINGERPRINT=$(adb_getprop ro.build.fingerprint)"
    echo "BUILD_ID=$(adb_getprop ro.build.id)"
    echo "SDK=$(adb_getprop ro.build.version.sdk)"

    if [[ "$product_device" != "$PRODUCT" ]]; then
      fail "DEVICE_PRODUCT_MISMATCH expected=$PRODUCT actual=$product_device"
      return 33
    fi

    if [[ "$flash_locked" == "1" || "$vbmeta_state" == "locked" ]]; then
      echo "BOOTLOADER_UNLOCK_STATE=LOCKED"
      fail "BOOTLOADER_LOCKED_UNLOCK_WOULD_WIPE_PRESERVED_DATA"
      return 33
    fi
    if [[ "$flash_locked" == "0" || "$vbmeta_state" == "unlocked" ]]; then
      echo "BOOTLOADER_UNLOCK_STATE=UNLOCKED"
    else
      echo "BOOTLOADER_UNLOCK_STATE=UNKNOWN"
      fail "BOOTLOADER_UNLOCK_STATE_UNKNOWN"
      return 33
    fi

    echo "FLASH_TRANSPORT_READY=NO_DEVICE_CURRENTLY_IN_ADB"
    echo "DEVICE_IDENTITY_PREFLIGHT=PASS"
    echo "PRESERVED_DATA_FLASH_READINESS=PASS_REQUIRES_SEPARATE_REBOOT_AUTHORIZATION"
    return 0
  fi

  mode="FASTBOOT"
  echo "DEVICE_TRANSPORT_MODE=$mode"
  product_device="$(fastboot_getvar product)"
  current_slot="$(fastboot_getvar current-slot)"
  unlocked="$(fastboot_getvar unlocked)"

  echo "DEVICE_PRODUCT=$product_device"
  echo "CURRENT_SLOT=$current_slot"
  echo "FASTBOOT_UNLOCKED=$unlocked"
  echo "FASTBOOT_SECURE=$(fastboot_getvar secure)"
  echo "FASTBOOT_IS_USERSPACE=$(fastboot_getvar is-userspace)"
  echo "FASTBOOT_SLOT_COUNT=$(fastboot_getvar slot-count)"

  if [[ "$product_device" != "$PRODUCT" ]]; then
    fail "DEVICE_PRODUCT_MISMATCH expected=$PRODUCT actual=$product_device"
    return 33
  fi

  case "$unlocked" in
    yes|true|1)
      echo "BOOTLOADER_UNLOCK_STATE=UNLOCKED"
      ;;
    no|false|0)
      echo "BOOTLOADER_UNLOCK_STATE=LOCKED"
      fail "BOOTLOADER_LOCKED_UNLOCK_WOULD_WIPE_PRESERVED_DATA"
      return 33
      ;;
    *)
      echo "BOOTLOADER_UNLOCK_STATE=UNKNOWN"
      fail "BOOTLOADER_UNLOCK_STATE_UNKNOWN value=$unlocked"
      return 33
      ;;
  esac

  echo "FLASH_TRANSPORT_READY=YES_FASTBOOT_PRESENT"
  echo "DEVICE_IDENTITY_PREFLIGHT=PASS"
  echo "PRESERVED_DATA_FLASH_READINESS=PASS"
  return 0
}

run_core() {
  echo "===== PANTHER P1B-D4-B2B2R9 / PRESERVED-DATA DEVICE + FLASH READINESS PREFLIGHT ====="
  echo "SOURCE_MUTATION_AUTHORIZED=NO"
  echo "WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO"
  echo "BUILD_AUTHORIZED=NO"
  echo "CLEAN_OR_CLOBBER_AUTHORIZED=NO"
  echo "DELETE_AUTHORIZED=NO"
  echo "DEVICE_CONTACT_AUTHORIZED=$DEVICE_CONTACT_AUTHORIZED"
  echo "DEVICE_REBOOT_AUTHORIZED=NO"
  echo "FLASH_AUTHORIZED=NO"
  echo "SLOT_CHANGE_AUTHORIZED=NO"
  echo "BOOTLOADER_UNLOCK_AUTHORIZED=NO"
  echo "USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO"
  echo "TMP_EVIDENCE_MUTATION=YES_EVIDENCE_DIR_ONLY"
  echo "evidence_dir=$EVIDENCE_DIR"

  verify_evidence_dir \
    "R7" \
    "$R7_EVIDENCE_DIR" \
    "$EXPECTED_R7_EVIDENCE_SEAL_SHA256" \
    "PANTHER_P1B_D4_B2B2R7R7_RESULT=PASS" \
    "FSVERITY_MANIFEST_INPUT_FIDELITY=PASS" \
    || { fail "R7_BINDING_FAILED"; return 33; }

  verify_evidence_dir \
    "R8" \
    "$R8_EVIDENCE_DIR" \
    "$EXPECTED_R8_EVIDENCE_SEAL_SHA256" \
    "PANTHER_P1B_D4_B2B2R8R4_RESULT=BOUNDED_FAIL" \
    "R8R4_FIVE_ART_BYTE_DIVERGENCE_REBOUND=PASS" \
    || { fail "R8_BINDING_FAILED"; return 33; }

  local art_only_count
  art_only_count="$(
    grep -R -F \
      'B2_VS_B1=ART_ONLY B2_VS_C2=ART_ONLY' \
      "$R8_EVIDENCE_DIR"/*.log 2>/dev/null \
      | wc -l | tr -d ' '
  )"
  echo "R8_ART_ONLY_BOTH_COMPARISONS_COUNT=$art_only_count"
  if [[ "$art_only_count" != "5" ]]; then
    fail "R8_ART_ONLY_CLAIM_SET_NOT_BOUND expected=5 actual=$art_only_count"
    return 33
  fi
  grep -R -Fq 'GATE_ERROR=C2_NINJA_EVIDENCE_MISSING' "$R8_EVIDENCE_DIR"/*.log 2>/dev/null || {
    fail "R8_EXPECTED_C2_PRODUCER_EVIDENCE_BOUNDARY_MISSING"
    return 33
  }
  echo "R8_SUBSTANTIVE_ART_ONLY_FINDING_BOUND=PASS"
  echo "R8_C2_PRODUCER_EVIDENCE_BOUNDARY_BOUND=PASS"

  inventory_b2 || return $?
  device_preflight || return $?

  echo "R9_OFFLINE_EVIDENCE_BINDING=PASS"
  echo "R9_B2_FLASH_ARTIFACT_READINESS=PASS"
  echo "R9_DEVICE_IDENTITY_AND_UNLOCK_PREFLIGHT=PASS"
  echo "R9_PRESERVED_DATA_FLASH_PREFLIGHT=PASS"
  echo "PANTHER_P1B_D4_B2B2R9_RESULT=PASS"
  return 0
}

set +e
run_core 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e

if [[ "$rc" -eq 0 ]]; then
  printf '%s\n' \
    "D4_B2B2R9_gate_rc=0" \
    "PANTHER_P1B_D4_B2B2R9_RESULT=PASS" > "$EVIDENCE_DIR/result.txt"
else
  printf '%s\n' \
    "D4_B2B2R9_gate_rc=$rc" \
    "PANTHER_P1B_D4_B2B2R9_RESULT=BOUNDED_FAIL" > "$EVIDENCE_DIR/result.txt"
fi

set +e
(
  cd "$EVIDENCE_DIR" || exit 1
  find . -type f ! -name evidence.sha256 -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum
) > "$EVIDENCE_DIR/evidence.sha256"
seal_rc=$?
set -e

if [[ "$seal_rc" -ne 0 ]]; then
  echo "GATE_ERROR=EVIDENCE_SEAL_GENERATION_FAILED rc=$seal_rc"
  exit 91
fi

EVIDENCE_SEAL_SHA256="$(sha256_file "$EVIDENCE_DIR/evidence.sha256")" || exit 91
echo "===== EVIDENCE SEAL ====="
echo "EVIDENCE_SEAL=$EVIDENCE_DIR/evidence.sha256"
echo "EVIDENCE_SEAL_SHA256=$EVIDENCE_SEAL_SHA256"
if [[ "$rc" -eq 0 ]]; then
  echo "PANTHER_P1B_D4_B2B2R9_RESULT=PASS"
else
  echo "PANTHER_P1B_D4_B2B2R9_RESULT=BOUNDED_FAIL"
fi
exit "$rc"
