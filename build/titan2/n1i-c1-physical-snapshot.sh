#!/usr/bin/env bash
# Device-side read-only C1 snapshot helpers. Requires ADB, SERIAL, fail() and guard lib.

n1i_c1_adb_ro_value() {
  local cmd="$1" out rc
  n1i_c1_guard_ok "$cmd" || fail "readonly_guard_refused=$cmd" 5
  out="$($ADB -s "$SERIAL" shell "$cmd" 2>/dev/null)"
  rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  printf '%s' "${out//$'\r'/}"
}

n1i_c1_verify_runtime_identity() {
  RUNTIME_SERIAL="$(n1i_c1_adb_ro_value 'getprop ro.serialno')" || fail runtime_serial_unreadable 3
  [[ "$RUNTIME_SERIAL" == "$SERIAL" ]] || fail runtime_serial_mismatch 3
  DEVICE="$(n1i_c1_adb_ro_value 'getprop ro.product.device')" || fail runtime_device_unreadable 3
  MODEL="$(n1i_c1_adb_ro_value 'getprop ro.product.model')" || fail runtime_model_unreadable 3
  MANUFACTURER="$(n1i_c1_adb_ro_value 'getprop ro.product.manufacturer')" || fail runtime_manufacturer_unreadable 3
  ANDROID_RELEASE="$(n1i_c1_adb_ro_value 'getprop ro.build.version.release')" || fail runtime_android_release_unreadable 3
  ANDROID_SDK="$(n1i_c1_adb_ro_value 'getprop ro.build.version.sdk')" || fail runtime_android_sdk_unreadable 3
  BOOT_COMPLETED="$(n1i_c1_adb_ro_value 'getprop sys.boot_completed')" || fail runtime_boot_completed_unreadable 3
  VENDOR_FP="$(n1i_c1_adb_ro_value 'getprop ro.vendor.build.fingerprint')" || fail runtime_vendor_fingerprint_unreadable 3
  [[ "$DEVICE" == Titan_2 ]] || fail "runtime_device=$DEVICE" 6
  [[ "$MODEL" == "Titan 2" || "$MODEL" == "SableOS Titan 2" ]] || fail "runtime_model=$MODEL" 6
  [[ "$MANUFACTURER" == Unihertz ]] || fail "runtime_manufacturer=$MANUFACTURER" 6
  [[ "$ANDROID_RELEASE" == 16 && "$ANDROID_SDK" == 36 ]] || fail "runtime_android=$ANDROID_RELEASE sdk=$ANDROID_SDK" 6
  [[ "$BOOT_COMPLETED" == 1 ]] || fail "runtime_boot_completed=$BOOT_COMPLETED" 6
  [[ "$VENDOR_FP" == Unihertz/Titan_2/Titan_2:14/*:user/release-keys ]] || fail runtime_vendor_fingerprint 6
}

n1i_c1_adb_ro_capture() {
  local cmd="$1" base="$2" rc
  n1i_c1_guard_ok "$cmd" || fail "readonly_guard_refused=$cmd" 5
  "$ADB" -s "$SERIAL" shell "$cmd" > "${base}.txt" 2> "${base}.err"
  rc=$?
  printf '%s\n' "$rc" > "${base}.rc"
  return 0
}

n1i_c1_snapshot() {
  local dir="$1"
  n1i_c1_adb_ro_capture "getprop" "$dir/getprop"
  n1i_c1_adb_ro_capture "dumpsys telephony.registry" "$dir/telephony_registry"
  n1i_c1_adb_ro_capture "dumpsys phone" "$dir/phone"
  n1i_c1_adb_ro_capture "dumpsys connectivity" "$dir/connectivity"
  n1i_c1_adb_ro_capture "dumpsys carrier_config" "$dir/carrier_config"
  n1i_c1_adb_ro_capture "dumpsys package com.mediatek.ims" "$dir/mediatek_ims_package"
  n1i_c1_adb_ro_capture "pm path com.mediatek.ims" "$dir/mediatek_ims_path"
  n1i_c1_adb_ro_capture "dumpsys activity services com.mediatek.ims" "$dir/mediatek_ims_services"
  n1i_c1_adb_ro_capture "cmd phone ims get-ims-service -s 0 -d -f 1" "$dir/ims_slot0_device"
  n1i_c1_adb_ro_capture "cmd phone ims get-ims-service -s 0 -c -f 1" "$dir/ims_slot0_carrier"
  n1i_c1_adb_ro_capture "cmd phone ims get-ims-service -s 1 -d -f 1" "$dir/ims_slot1_device"
  n1i_c1_adb_ro_capture "cmd phone ims get-ims-service -s 1 -c -f 1" "$dir/ims_slot1_carrier"
  n1i_c1_adb_ro_capture "content query --uri content://telephony/carriers/preferapn" "$dir/preferred_apn"
  n1i_c1_adb_ro_capture "content query --uri content://telephony/siminfo" "$dir/siminfo"
  n1i_c1_adb_ro_capture "settings get global mobile_data" "$dir/mobile_data"
  n1i_c1_adb_ro_capture "settings get global airplane_mode_on" "$dir/airplane_mode"
  n1i_c1_adb_ro_capture "settings get global multi_sim_data_call" "$dir/multi_sim_data_call"
  n1i_c1_adb_ro_capture "cat /proc/uptime" "$dir/uptime"
  n1i_c1_adb_ro_capture "cat /proc/sys/kernel/random/boot_id" "$dir/boot_id"
  n1i_c1_adb_ro_capture "date +%s" "$dir/device_epoch"
}
