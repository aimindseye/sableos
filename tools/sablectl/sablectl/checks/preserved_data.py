from __future__ import annotations

from ..adb import AdbClient
from ..types import CheckResult, Status


def _device_baseline(baseline: dict) -> dict:
    device = baseline.get("device")
    if not isinstance(device, dict):
        raise ValueError("baseline.json does not contain a device object")
    return device


def verify_preserved_data(adb: AdbClient, baseline: dict) -> list[CheckResult]:
    before = _device_baseline(baseline)
    results: list[CheckResult] = []

    ce = adb.getprop("sys.user.0.ce_available")
    ce_ok = ce in {"1", "true"}
    results.append(
        CheckResult(
            id="data.ce_available",
            status=Status.PASS if ce_ok else Status.FAIL,
            summary="credential-encrypted user 0 data available",
            expected="1|true",
            actual=ce,
        )
    )

    expected_packages = sorted(before.get("third_party_packages") or [])
    actual_packages = adb.third_party_packages()
    missing = sorted(set(expected_packages) - set(actual_packages))
    added = sorted(set(actual_packages) - set(expected_packages))
    results.append(
        CheckResult(
            id="data.third_party_packages",
            status=Status.PASS if actual_packages == expected_packages else Status.FAIL,
            summary="third-party package set preserved",
            expected=len(expected_packages),
            actual=len(actual_packages),
            details={"missing": missing, "added": added},
        )
    )

    expected_users = before.get("users") or []
    actual_users = adb.users()
    results.append(
        CheckResult(
            id="data.users",
            status=Status.PASS if len(actual_users) == len(expected_users) else Status.FAIL,
            summary="Android user count preserved",
            expected=len(expected_users),
            actual=len(actual_users),
            details={"before": expected_users, "after": actual_users},
        )
    )

    return results
