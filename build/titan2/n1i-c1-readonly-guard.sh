#!/usr/bin/env bash
# Pure command guard for N1I-C1 physical runtime evidence collection.
# This file performs no device contact by itself.

n1i_c1_guard_ok() {
  local c="${1:-}"

  [[ -n "$c" ]] || return 1

  # Shell/control operators are never accepted. Commands are passed as one argv
  # string to `adb shell`; refusing composition keeps the allowlist auditable.
  if [[ "$c" =~ [\;\|\&\`\>\<] || "$c" == *'$('* || "$c" == *'${'* ]]; then
    return 1
  fi

  # Hard mutation deny. Keep this before the positive allowlist so future
  # broadening cannot accidentally admit a write-capable family.
  if [[ "$c" =~ (^|[[:space:]])(setprop|reboot|stop|start|kill|killall|svc|am|input|monkey|wm|dd|rm|mv|cp|chmod|chown|touch|mkdir|rmdir|sync|mount|umount|resetprop|magisk|su|sh|bash)([[:space:]]|$) ]]; then
    return 1
  fi
  if [[ "$c" =~ ^settings[[:space:]]+(put|delete|reset)([[:space:]]|$) ]]; then
    return 1
  fi
  if [[ "$c" =~ ^pm[[:space:]]+(install|uninstall|clear|enable|disable|grant|revoke|hide|unhide|suspend)([[:space:]]|$) ]]; then
    return 1
  fi
  if [[ "$c" =~ ^content[[:space:]]+(insert|update|delete|call)([[:space:]]|$) ]]; then
    return 1
  fi

  # Exact C1 extras. `cmd phone` and `content` remain deny-by-default outside
  # these literal queries.
  case "$c" in
    "cmd phone ims get-ims-service -s 0 -d -f 1"|\
    "cmd phone ims get-ims-service -s 0 -c -f 1"|\
    "cmd phone ims get-ims-service -s 1 -d -f 1"|\
    "cmd phone ims get-ims-service -s 1 -c -f 1"|\
    "content query --uri content://telephony/carriers/preferapn"|\
    "content query --uri content://telephony/siminfo")
      return 0
      ;;
  esac
  [[ "$c" =~ ^cmd([[:space:]]|$) ]] && return 1
  [[ "$c" =~ ^content([[:space:]]|$) ]] && return 1

  # Fixed read-only families used by the collector.
  if [[ "$c" =~ ^getprop([[:space:]]+[A-Za-z0-9_.-]+)?$ ]]; then
    return 0
  fi
  if [[ "$c" =~ ^dumpsys[[:space:]]+(telephony\.registry|phone|connectivity|carrier_config|package[[:space:]]+com\.mediatek\.ims|activity[[:space:]]+services[[:space:]]+com\.mediatek\.ims)$ ]]; then
    return 0
  fi
  if [[ "$c" == "pm path com.mediatek.ims" ]]; then
    return 0
  fi
  if [[ "$c" =~ ^settings[[:space:]]+get[[:space:]]+(global|secure|system)[[:space:]]+[A-Za-z0-9_.-]+$ ]]; then
    return 0
  fi
  if [[ "$c" == "cat /proc/uptime" || "$c" == "cat /proc/sys/kernel/random/boot_id" || "$c" == "date +%s" ]]; then
    return 0
  fi

  return 1
}
