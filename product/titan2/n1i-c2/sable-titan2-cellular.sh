#!/system/bin/sh
# SableOS Titan 2 Cellular MVP integration probe and bounded healer.
#
# First physical candidate behavior:
#   - probe automatically once after boot_completed;
#   - observe stock vendor-UA readiness;
#   - verify MMTEL/IMS provider binding;
#   - never force-start vendor UA;
#   - healer is disabled unless HEALER_ENABLE_FILE exists.
#
# Explicitly forbidden here: generic RIL restart, airplane-mode toggling,
# SELinux permissive fallback, reboot-as-healing, and periodic property loops.

TAG="SableTitanCellular"
CONFIG="/system_ext/etc/sable/titan2-cellular.conf"
STATE_DIR="/data/local/tmp/sable-titan2-cellular"
LATEST="$STATE_DIR/latest.env"
LAST_HEAL="$STATE_DIR/last-heal-epoch"
HEALER_ENABLE_FILE="/data/local/tmp/sable-titan2-cellular-healer.enable"
DEFAULT_SLOT=0
WAIT_STEPS=12
WAIT_SECONDS=5
COOLDOWN_SECONDS=300

logi() {
    /system/bin/log -t "$TAG" "$*" 2>/dev/null || true
    echo "$*"
}

safe_value() {
    printf '%s' "$1" | tr '\n\r\t ' '____'
}

if [ -r "$CONFIG" ]; then
    # Generated at build time from the sealed N1I-C2 manifest.
    # shellcheck disable=SC1090
    . "$CONFIG"
fi

IMS_PACKAGE="${SABLE_TITAN2_IMS_PACKAGE:-com.mediatek.ims}"
SLOT="${SABLE_TITAN2_SLOT:-$DEFAULT_SLOT}"
VENDOR_UA_SERVICE="${SABLE_TITAN2_VENDOR_UA_SERVICE:-}"
VENDOR_UA_DECISION="${SABLE_TITAN2_VENDOR_UA_DECISION:-OBSERVE_READINESS}"
VENDOR_UA_START_MODE="${SABLE_TITAN2_VENDOR_UA_START_MODE:-unknown}"

mkdir -p "$STATE_DIR" 2>/dev/null || true

ims_service() {
    mode="$1"
    /system/bin/cmd phone ims get-ims-service -s "$SLOT" "$mode" 2>/dev/null |
        tail -n 1 |
        tr -d '\r'
}

ua_state() {
    if [ -z "$VENDOR_UA_SERVICE" ]; then
        echo NOT_CONFIGURED
    else
        getprop "init.svc.$VENDOR_UA_SERVICE"
    fi
}

overlay_state() {
    /system/bin/cmd overlay list --user 0 2>/dev/null |
        grep 'me.phh.treble.overlay.mtkims_telephony' |
        head -n 1 |
        tr -d '\r'
}

write_state() {
    device_ims="$1"
    carrier_ims="$2"
    ua="$3"
    overlay="$4"
    result="$5"
    {
        echo "SABLE_TITAN2_CELLULAR_SLOT=$(safe_value "$SLOT")"
        echo "SABLE_TITAN2_CELLULAR_IMS_PACKAGE=$(safe_value "$IMS_PACKAGE")"
        echo "SABLE_TITAN2_CELLULAR_DEVICE_IMS=$(safe_value "$device_ims")"
        echo "SABLE_TITAN2_CELLULAR_CARRIER_IMS=$(safe_value "$carrier_ims")"
        echo "SABLE_TITAN2_CELLULAR_VENDOR_UA_SERVICE=$(safe_value "$VENDOR_UA_SERVICE")"
        echo "SABLE_TITAN2_CELLULAR_VENDOR_UA_DECISION=$(safe_value "$VENDOR_UA_DECISION")"
        echo "SABLE_TITAN2_CELLULAR_VENDOR_UA_START_MODE=$(safe_value "$VENDOR_UA_START_MODE")"
        echo "SABLE_TITAN2_CELLULAR_VENDOR_UA_STATE=$(safe_value "$ua")"
        echo "SABLE_TITAN2_CELLULAR_MTK_IMS_OVERLAY=$(safe_value "$overlay")"
        echo "SABLE_TITAN2_CELLULAR_RESULT=$(safe_value "$result")"
        echo "SABLE_TITAN2_CELLULAR_HEALER_ENABLED=$([ -f "$HEALER_ENABLE_FILE" ] && echo YES || echo NO)"
    } > "$LATEST" 2>/dev/null || true
}

probe_once() {
    DEVICE_IMS="$(ims_service -d)"
    CARRIER_IMS="$(ims_service -c)"
    UA="$(ua_state)"
    OVERLAY="$(overlay_state)"

    PROVIDER_OK=NO
    if [ "$DEVICE_IMS" = "$IMS_PACKAGE" ] || [ "$CARRIER_IMS" = "$IMS_PACKAGE" ]; then
        PROVIDER_OK=YES
    fi

    OVERLAY_OK=NO
    case "$OVERLAY" in
        *'[x]'*|*'[X]'*) OVERLAY_OK=YES ;;
        *) ;;
    esac

    UA_OK=YES
    if [ -n "$VENDOR_UA_SERVICE" ] && [ "$VENDOR_UA_START_MODE" != "disabled" ]; then
        [ "$UA" = "running" ] || UA_OK=NO
    fi

    logi "slot=$SLOT device_ims=$DEVICE_IMS carrier_ims=$CARRIER_IMS ua_service=$VENDOR_UA_SERVICE ua_state=$UA ua_start_mode=$VENDOR_UA_START_MODE ua_decision=$VENDOR_UA_DECISION overlay=$OVERLAY provider_ok=$PROVIDER_OK ua_ok=$UA_OK overlay_ok=$OVERLAY_OK"

    if [ "$PROVIDER_OK" = YES ] && [ "$UA_OK" = YES ]; then
        write_state "$DEVICE_IMS" "$CARRIER_IMS" "$UA" "$OVERLAY" PASS_PROVIDER_BOUND
        return 0
    fi

    write_state "$DEVICE_IMS" "$CARRIER_IMS" "$UA" "$OVERLAY" WAIT_PROVIDER
    return 1
}

call_safe_for_heal() {
    TELECOM="$(/system/bin/dumpsys telecom 2>/dev/null)" || {
        logi "healer=skip reason=telecom_state_unavailable"
        return 1
    }
    if printf '%s\n' "$TELECOM" |
        grep -Eq 'state=(ACTIVE|DIALING|RINGING|HOLDING|CONNECTING)|mIsEmergencyCall=true|isEmergencyCall=true'; then
        logi "healer=skip reason=active_or_emergency_call"
        return 1
    fi
    return 0
}

cooldown_ok() {
    NOW="$(date +%s 2>/dev/null)" || return 1
    if [ -r "$LAST_HEAL" ]; then
        LAST="$(cat "$LAST_HEAL" 2>/dev/null)"
        case "$LAST" in
            ''|*[!0-9]*) LAST=0 ;;
        esac
        AGE=$((NOW - LAST))
        if [ "$AGE" -lt "$COOLDOWN_SECONDS" ]; then
            logi "healer=skip reason=cooldown age=$AGE required=$COOLDOWN_SECONDS"
            return 1
        fi
    fi
    printf '%s\n' "$NOW" > "$LAST_HEAL" 2>/dev/null || return 1
    return 0
}

bounded_heal() {
    [ -f "$HEALER_ENABLE_FILE" ] || {
        logi "healer=disabled"
        return 1
    }

    call_safe_for_heal || return 1
    cooldown_ok || return 1

    CURRENT="$(ims_service -d)"
    if [ "$CURRENT" != "$IMS_PACKAGE" ]; then
        logi "healer=set_device_ims slot=$SLOT package=$IMS_PACKAGE"
        /system/bin/cmd phone ims set-ims-service -s "$SLOT" -d "$IMS_PACKAGE" >/dev/null 2>&1 || {
            logi "healer=fail action=set_device_ims"
            return 1
        }
    fi

    logi "healer=enable_ims slot=$SLOT"
    /system/bin/cmd phone ims enable -s "$SLOT" >/dev/null 2>&1 || {
        logi "healer=fail action=enable_ims"
        return 1
    }

    sleep 10
    if probe_once; then
        logi "healer=pass"
        return 0
    fi
    logi "healer=fail reason=provider_still_unbound"
    return 1
}

probe() {
    STEP=0
    while [ "$STEP" -lt "$WAIT_STEPS" ]; do
        if probe_once; then
            logi "probe=pass step=$STEP"
            return 0
        fi
        STEP=$((STEP + 1))
        sleep "$WAIT_SECONDS"
    done

    logi "probe=timeout steps=$WAIT_STEPS"
    if [ -f "$HEALER_ENABLE_FILE" ]; then
        bounded_heal
        return $?
    fi
    return 1
}

case "${1:-probe}" in
    probe)
        probe
        ;;
    status)
        probe_once
        ;;
    heal)
        bounded_heal
        ;;
    *)
        echo "usage: sable-titan2-cellular {probe|status|heal}" >&2
        exit 64
        ;;
esac
