from dataclasses import dataclass

from sablectl.checks.acceptance import (
    _count_since_boot_crash_markers,
    manual_d4_gates,
    verify_d4_host_acceptance,
)
from sablectl.types import Status


@dataclass
class Result:
    returncode: int = 0
    stdout: str = ""
    stderr: str = ""


class FakeAdb:
    def __init__(self):
        self.props = {"sys.usb.state": "mtp,adb"}

    def getprop(self, name):
        return self.props[name]

    def run(self, args, **kwargs):
        if args[:3] == ["logcat", "-b", "crash"]:
            return Result(stdout="")
        raise AssertionError(args)

    def shell(self, args, **kwargs):
        key = tuple(args)
        table = {
            ("date", "+%s"): Result(stdout="2000\n"),
            ("cat", "/proc/uptime"): Result(stdout="100.00 1.0\n"),
            ("cmd", "wifi", "status"): Result(stdout="Wifi is enabled\n"),
            ("dumpsys", "connectivity"): Result(stdout="Active default network: 105\nNetworkAgentInfo WIFI VALIDATED\n"),
            ("dumpsys", "telephony.registry"): Result(stdout="mServiceState=voiceRegState=0 dataRegState=0\nmDataConnectionState=2\n"),
            ("dumpsys", "ims"): Result(stdout="IMS registered\n"),
            ("dumpsys", "bluetooth_manager"): Result(stdout="enabled: true\n"),
            ("dumpsys", "battery"): Result(stdout="level: 75\nstatus: 3\npowered: false\n"),
            ("service", "check", "com.sableos.power.IPowerService/default"): Result(returncode=1, stdout="Service com.sableos.power.IPowerService/default: not found\n"),
            ("dumpsys", "webviewupdate"): Result(stdout="Current WebView package (name, version): com.android.webview 137\n"),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.HOME"): Result(stdout="com.android.launcher3\n"),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.BROWSER"): Result(stdout="com.android.browser\n"),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.DIALER"): Result(stdout="com.android.dialer\n"),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.SMS"): Result(stdout="com.android.messaging\n"),
        }
        if key not in table:
            raise AssertionError(key)
        return table[key]


def test_crash_marker_parser_scopes_to_current_boot():
    text = (
        "1800.000 FATAL EXCEPTION: old\n"
        "1901.000 normal line\n"
        "1950.000 FATAL EXCEPTION: current\n"
        "1960.000 *** *** *** *** *** *** *** *** native\n"
    )
    assert _count_since_boot_crash_markers(text, boot_epoch=1900.0) == 2


def test_d4_host_acceptance_happy_observable_path():
    results = verify_d4_host_acceptance(FakeAdb())
    by_id = {r.id: r for r in results}
    assert by_id["crash.since_boot"].status is Status.PASS
    assert by_id["wifi.enabled"].status is Status.PASS
    assert by_id["connectivity.validated_network"].status is Status.PASS
    assert by_id["telephony.registered"].status is Status.PASS
    assert by_id["telephony.data_connected"].status is Status.PASS
    assert by_id["bluetooth.enabled"].status is Status.PASS
    assert by_id["usb.adb"].status is Status.PASS
    assert by_id["power.battery_level"].status is Status.PASS
    assert by_id["power.sable_service"].status is Status.SKIP
    assert by_id["webview.provider"].status is Status.PASS
    assert by_id["role.home"].status is Status.PASS


def test_manual_d4_gates_remain_manual():
    results = manual_d4_gates()
    assert len(results) >= 8
    assert all(r.status is Status.MANUAL for r in results)
    assert {r.id for r in results} >= {
        "manual.voice_out",
        "manual.voice_in",
        "manual.sms_out",
        "manual.sms_in",
        "manual.camera_quality",
    }
