from __future__ import annotations

from ..adb import AdbClient
from ..types import CheckResult, Status
from .acceptance import _text


def verify_adb_usb_health(adb: AdbClient) -> list[CheckResult]:
    """Separate ADB transport health from optional USB-function observability.

    A live authorized ADB transport is proven with `adb get-state`. Android USB
    function properties are supplemental evidence only: some builds/transports
    may expose them as empty, and ADB may also be carried over TCP/wireless.
    Empty or non-ADB USB function properties therefore do not contradict a
    healthy ADB transport.
    """
    transport = adb.run(["get-state"], timeout=15)
    transport_state = _text(transport)
    results = [
        CheckResult(
            id="adb.transport",
            status=(
                Status.PASS
                if transport.returncode == 0 and transport_state == "device"
                else Status.FAIL
            ),
            summary="authorized ADB transport is healthy",
            expected="device",
            actual=transport_state or f"rc={transport.returncode}",
        )
    ]

    props = {
        "sys.usb.state": adb.getprop("sys.usb.state"),
        "sys.usb.config": adb.getprop("sys.usb.config"),
        "persist.sys.usb.config": adb.getprop("persist.sys.usb.config"),
    }
    exposed = {key: value for key, value in props.items() if value}
    functions: set[str] = set()
    for value in exposed.values():
        functions.update(item.strip() for item in value.split(",") if item.strip())

    if not exposed:
        status = Status.SKIP
        actual = "USB function properties unavailable/empty"
    elif "adb" in functions:
        status = Status.PASS
        actual = ", ".join(f"{key}={value}" for key, value in exposed.items())
    else:
        status = Status.SKIP
        actual = ", ".join(f"{key}={value}" for key, value in exposed.items())

    results.append(
        CheckResult(
            id="usb.function_state",
            status=status,
            summary="USB function state exposes adb when observable",
            expected="adb when USB function properties expose the active transport",
            actual=actual,
            details={"properties": props},
        )
    )
    return results
