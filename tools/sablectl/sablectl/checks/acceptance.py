from __future__ import annotations

import re

from ..adb import AdbClient
from ..types import CheckResult, Status


def _text(result) -> str:
    return (result.stdout or "").replace("\r", "").strip()


def _manual(check_id: str, summary: str, *, details: dict | None = None) -> CheckResult:
    return CheckResult(
        id=check_id,
        status=Status.MANUAL,
        summary=summary,
        expected="manual physical validation",
        actual="pending",
        details=details or {},
    )


def _command_observation(
    adb: AdbClient,
    *,
    check_id: str,
    summary: str,
    args: list[str],
    timeout: int = 30,
) -> tuple[CheckResult, str]:
    result = adb.shell(args, timeout=timeout)
    output = _text(result)
    ok = result.returncode == 0 and bool(output)
    return (
        CheckResult(
            id=check_id,
            status=Status.PASS if ok else Status.SKIP,
            summary=summary,
            expected="command available with output",
            actual=f"rc={result.returncode} bytes={len(output)}",
        ),
        output,
    )


def _parse_battery(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip().lower()] = value.strip()
    return values


def _count_since_boot_crash_markers(log_text: str, *, boot_epoch: float) -> int:
    count = 0
    for line in log_text.splitlines():
        match = re.match(r"\s*(\d+\.\d+)", line)
        if not match:
            continue
        if float(match.group(1)) < boot_epoch:
            continue
        if "FATAL EXCEPTION" in line or "*** *** *** *** *** *** *** ***" in line:
            count += 1
    return count


def verify_crash_health(adb: AdbClient) -> list[CheckResult]:
    now_result = adb.shell(["date", "+%s"], timeout=15)
    uptime_result = adb.shell(["cat", "/proc/uptime"], timeout=15)
    log_result = adb.run(["logcat", "-b", "crash", "-d", "-v", "epoch", "-t", "400"], timeout=45)

    if now_result.returncode != 0 or uptime_result.returncode != 0 or log_result.returncode != 0:
        return [
            CheckResult(
                id="crash.since_boot",
                status=Status.SKIP,
                summary="crash-buffer audit since current boot",
                expected="observable",
                actual=(
                    f"date_rc={now_result.returncode} "
                    f"uptime_rc={uptime_result.returncode} "
                    f"logcat_rc={log_result.returncode}"
                ),
            )
        ]

    try:
        now_epoch = float(_text(now_result).splitlines()[-1])
        uptime = float(_text(uptime_result).split()[0])
    except (ValueError, IndexError):
        return [
            CheckResult(
                id="crash.since_boot",
                status=Status.ERROR,
                summary="parse device boot time for crash audit",
                expected="numeric date/uptime",
                actual=f"date={_text(now_result)!r} uptime={_text(uptime_result)!r}",
            )
        ]

    boot_epoch = now_epoch - uptime
    markers = _count_since_boot_crash_markers(log_result.stdout or "", boot_epoch=boot_epoch)
    return [
        CheckResult(
            id="crash.since_boot",
            status=Status.PASS if markers == 0 else Status.FAIL,
            summary="no fatal Java/native crash markers in crash buffer since current boot",
            expected=0,
            actual=markers,
            details={"boot_epoch": int(boot_epoch), "log_lines": len((log_result.stdout or "").splitlines())},
        )
    ]


def verify_connectivity(adb: AdbClient) -> list[CheckResult]:
    results: list[CheckResult] = []
    wifi_obs, wifi = _command_observation(
        adb,
        check_id="wifi.status_command",
        summary="Wi-Fi framework status observable",
        args=["cmd", "wifi", "status"],
    )
    results.append(wifi_obs)
    if wifi_obs.status is Status.PASS:
        lowered = wifi.lower()
        enabled = "enabled" in lowered and "disabled" not in lowered
        results.append(
            CheckResult(
                id="wifi.enabled",
                status=Status.PASS if enabled else Status.MANUAL,
                summary="Wi-Fi enabled for D4 acceptance",
                expected=True,
                actual=enabled,
            )
        )

    conn_obs, conn = _command_observation(
        adb,
        check_id="connectivity.dumpsys",
        summary="ConnectivityService state observable",
        args=["dumpsys", "connectivity"],
        timeout=45,
    )
    results.append(conn_obs)
    if conn_obs.status is Status.PASS:
        upper = conn.upper()
        default_match = re.search(r"ACTIVE DEFAULT NETWORK\s*:\s*(\d+)", upper)
        validated = bool(default_match) and "VALIDATED" in upper
        results.append(
            CheckResult(
                id="connectivity.validated_network",
                status=Status.PASS if validated else Status.MANUAL,
                summary="active default network is present and a validated network is visible",
                expected=True,
                actual=validated,
                details={"active_default_network": default_match.group(1) if default_match else None},
            )
        )
    return results


def verify_telephony(adb: AdbClient) -> list[CheckResult]:
    results: list[CheckResult] = []
    obs, text = _command_observation(
        adb,
        check_id="telephony.registry",
        summary="telephony registry observable",
        args=["dumpsys", "telephony.registry"],
        timeout=45,
    )
    results.append(obs)
    if obs.status is Status.PASS:
        registered = bool(
            re.search(r"(?:mServiceState|voiceRegState|dataRegState).*?(?:=0\b|IN_SERVICE)", text, re.I)
        )
        data_connected = bool(
            re.search(r"(?:mDataConnectionState|dataConnectionState)\s*=\s*2\b", text)
        )
        results.append(
            CheckResult(
                id="telephony.registered",
                status=Status.PASS if registered else Status.MANUAL,
                summary="cellular service registration observed",
                expected=True,
                actual=registered,
            )
        )
        results.append(
            CheckResult(
                id="telephony.data_connected",
                status=Status.PASS if data_connected else Status.MANUAL,
                summary="cellular data connected when exposed by TelephonyRegistry",
                expected=True,
                actual=data_connected,
            )
        )

    ims_result = adb.shell(["dumpsys", "ims"], timeout=30)
    ims_text = _text(ims_result)
    results.append(
        CheckResult(
            id="telephony.ims_observable",
            status=Status.PASS if ims_result.returncode == 0 and bool(ims_text) else Status.SKIP,
            summary="IMS state observable through dumpsys",
            expected="observable when platform/carrier exposes it",
            actual=f"rc={ims_result.returncode} bytes={len(ims_text)}",
        )
    )
    return results


def verify_bluetooth(adb: AdbClient) -> list[CheckResult]:
    obs, text = _command_observation(
        adb,
        check_id="bluetooth.manager",
        summary="Bluetooth manager observable",
        args=["dumpsys", "bluetooth_manager"],
        timeout=45,
    )
    results = [obs]
    if obs.status is Status.PASS:
        enabled_match = re.search(r"(?:enabled|mEnabled)\s*[:=]\s*(true|false)", text, re.I)
        if enabled_match:
            enabled = enabled_match.group(1).lower() == "true"
            results.append(
                CheckResult(
                    id="bluetooth.enabled",
                    status=Status.PASS if enabled else Status.MANUAL,
                    summary="Bluetooth enabled for D4 acceptance",
                    expected=True,
                    actual=enabled,
                )
            )
        else:
            results.append(
                CheckResult(
                    id="bluetooth.enabled",
                    status=Status.SKIP,
                    summary="Bluetooth enabled state parse",
                    expected="parseable boolean",
                    actual="not found",
                )
            )
    return results


def verify_usb(adb: AdbClient) -> list[CheckResult]:
    state = adb.getprop("sys.usb.state")
    functions = {item.strip() for item in state.split(",") if item.strip()}
    return [
        CheckResult(
            id="usb.adb",
            status=Status.PASS if "adb" in functions else Status.FAIL,
            summary="USB function set includes adb",
            expected="adb",
            actual=state,
        )
    ]


def verify_power(adb: AdbClient) -> list[CheckResult]:
    obs, text = _command_observation(
        adb,
        check_id="power.battery_service",
        summary="battery service observable",
        args=["dumpsys", "battery"],
    )
    results = [obs]
    if obs.status is Status.PASS:
        values = _parse_battery(text)
        try:
            level = int(values.get("level", "-1"))
        except ValueError:
            level = -1
        results.append(
            CheckResult(
                id="power.battery_level",
                status=Status.PASS if 0 <= level <= 100 else Status.FAIL,
                summary="battery level is sane",
                expected="0..100",
                actual=level,
                details={"status": values.get("status"), "powered": values.get("powered")},
            )
        )

    service = adb.shell(["service", "check", "com.sableos.power.IPowerService/default"], timeout=15)
    service_text = _text(service)
    present = service.returncode == 0 and "not found" not in service_text.lower()
    results.append(
        CheckResult(
            id="power.sable_service",
            status=Status.PASS if present else Status.SKIP,
            summary="Sable power semantic service present on this product stage",
            expected="present only after Panther S1.7 service port",
            actual=service_text or f"rc={service.returncode}",
        )
    )
    return results


def verify_webview_and_roles(adb: AdbClient) -> list[CheckResult]:
    results: list[CheckResult] = []
    webview = adb.shell(["dumpsys", "webviewupdate"], timeout=30)
    webview_text = _text(webview)
    provider_match = re.search(
        r"(?:Current WebView package|Current WebView package \(name, version\))\s*[:=]\s*([^\n]+)",
        webview_text,
        re.I,
    )
    provider = provider_match.group(1).strip() if provider_match else ""
    results.append(
        CheckResult(
            id="webview.provider",
            status=Status.PASS if webview.returncode == 0 and bool(provider) else Status.MANUAL,
            summary="current WebView provider observable",
            expected="current provider in dumpsys webviewupdate",
            actual=provider or f"rc={webview.returncode}",
        )
    )

    for role, suffix in [
        ("android.app.role.HOME", "home"),
        ("android.app.role.BROWSER", "browser"),
        ("android.app.role.DIALER", "dialer"),
        ("android.app.role.SMS", "sms"),
    ]:
        result = adb.shell(["cmd", "role", "get-role-holders", "--user", "0", role], timeout=30)
        holders = [line.strip() for line in _text(result).splitlines() if line.strip()]
        results.append(
            CheckResult(
                id=f"role.{suffix}",
                status=Status.PASS if result.returncode == 0 and bool(holders) else Status.MANUAL,
                summary=f"default {suffix} role holder",
                expected=">=1 holder",
                actual=",".join(holders) if holders else f"rc={result.returncode}",
                details={"holders": holders},
            )
        )
    return results


def manual_d4_gates() -> list[CheckResult]:
    return [
        _manual("manual.voice_out", "outgoing voice call, earpiece/mic/speaker sanity"),
        _manual("manual.voice_in", "incoming voice call sanity"),
        _manual("manual.sms_out", "outgoing SMS"),
        _manual("manual.sms_in", "incoming SMS"),
        _manual("manual.mms", "MMS send/receive where carrier/APN supports it"),
        _manual("manual.hotspot", "hotspot client obtains internet"),
        _manual("manual.bluetooth_audio", "Bluetooth pair/reconnect/audio with test hardware"),
        _manual("manual.camera_quality", "front/rear photo and video visual sanity"),
        _manual("manual.location_fix", "ordinary app obtains a location fix"),
        _manual("manual.biometrics", "fingerprint enrollment/unlock when configured"),
        _manual("manual.nfc", "physical NFC tag/read where hardware is available"),
    ]


def verify_d4_host_acceptance(adb: AdbClient) -> list[CheckResult]:
    results: list[CheckResult] = []
    results.extend(verify_crash_health(adb))
    results.extend(verify_connectivity(adb))
    results.extend(verify_telephony(adb))
    results.extend(verify_bluetooth(adb))
    results.extend(verify_usb(adb))
    results.extend(verify_power(adb))
    results.extend(verify_webview_and_roles(adb))
    return results
