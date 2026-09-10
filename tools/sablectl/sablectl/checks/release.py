from __future__ import annotations

import json
import re
from pathlib import Path

from ..adb import AdbClient
from ..types import CheckResult, Status

_REQUIRED_PHYSICAL = {
    "voice_out": "outgoing voice call",
    "voice_in": "incoming voice call",
    "sms_out": "outgoing SMS",
    "sms_in": "incoming SMS",
    "mms_out": "outgoing MMS",
    "mms_in": "incoming MMS",
    "hotspot": "hotspot client internet",
    "bluetooth_audio": "Bluetooth pair/reconnect/audio",
    "camera": "front/rear photo and video sanity",
    "location": "ordinary app location fix",
    "biometrics": "fingerprint enrollment/unlock",
}
_NFC_ALLOWED = {"PASS", "NOT_TESTED_NO_HARDWARE"}
_ROLE_COMMANDS = {
    "home": "android.app.role.HOME",
    "browser": "android.app.role.BROWSER",
    "dialer": "android.app.role.DIALER",
    "sms": "android.app.role.SMS",
}


def _text(result) -> str:
    return (result.stdout or "").replace("\r", "").strip()


def _stderr(result) -> str:
    return (result.stderr or "").replace("\r", "").strip()


def _slot_index(slot: str) -> int:
    normalized = slot.strip().lower().removeprefix("_")
    if normalized == "a":
        return 0
    if normalized == "b":
        return 1
    raise ValueError(f"unsupported A/B slot: {slot!r}")


def _slot_suffix(slot: str) -> str:
    return "_a" if _slot_index(slot) == 0 else "_b"


def _bootctl_boolean_result(
    *,
    check_id: str,
    summary: str,
    result,
) -> CheckResult:
    """Interpret bootctl boolean commands without conflating false with RPC failure.

    Current AOSP bootctl returns EX_SOFTWARE (70) both when a boolean query is
    false and when the boot-control RPC failed. A false result is printed as
    literal `0`; an RPC/module failure has no boolean stdout and normally emits
    an error on stderr. Preserve that distinction.
    """
    stdout = _text(result)
    stderr = _stderr(result)
    if result.returncode == 0 and stdout in {"", "1"}:
        return CheckResult(
            id=check_id,
            status=Status.PASS,
            summary=summary,
            expected=True,
            actual=True,
            details={"bootctl_rc": result.returncode, "stdout": stdout, "stderr": stderr},
        )
    if stdout == "0":
        return CheckResult(
            id=check_id,
            status=Status.FAIL,
            summary=summary,
            expected=True,
            actual=False,
            details={"bootctl_rc": result.returncode, "stdout": stdout, "stderr": stderr},
        )
    return CheckResult(
        id=check_id,
        status=Status.SKIP,
        summary=summary,
        expected="observable boot-control boolean",
        actual=f"unobservable rc={result.returncode}",
        details={"bootctl_rc": result.returncode, "stdout": stdout, "stderr": stderr},
    )


def verify_slot_release_health(adb: AdbClient, expected_slot: str) -> list[CheckResult]:
    """Read-only release-slot validation with bounded bootctl fallback semantics.

    `ro.boot.slot_suffix` proves the runtime slot without requiring boot_control
    HAL access. Pixel bootloaders may also expose `ro.boot.slot_successful`,
    which is useful positive evidence when it is `yes`, but a boot-time `no`
    cannot prove that Android did not mark the slot successful later in boot.

    If `bootctl get-current-slot` itself is unavailable, subsequent bootctl
    metadata is classified SKIP rather than FAIL. This is fail-closed: the gate
    never fabricates successful/bootable metadata that ordinary ADB shell could
    not observe.
    """
    expected_index = _slot_index(expected_slot)
    expected_suffix = _slot_suffix(expected_slot)
    runtime_suffix = adb.getprop("ro.boot.slot_suffix")
    results: list[CheckResult] = [
        CheckResult(
            id="release.slot_runtime",
            status=Status.PASS if runtime_suffix == expected_suffix else Status.FAIL,
            summary="runtime slot suffix matches expected release slot",
            expected=expected_suffix,
            actual=runtime_suffix,
        )
    ]

    boot_success_prop = adb.getprop("ro.boot.slot_successful").strip().lower()
    if boot_success_prop in {"yes", "true", "1"}:
        prop_status = Status.PASS
        prop_actual = True
    elif boot_success_prop in {"no", "false", "0"}:
        prop_status = Status.SKIP
        prop_actual = False
    else:
        prop_status = Status.SKIP
        prop_actual = boot_success_prop or "unavailable"
    results.append(
        CheckResult(
            id="release.slot_successful_boot_property",
            status=prop_status,
            summary="bootloader-reported slot-success state at boot time",
            expected=True,
            actual=prop_actual,
            details={
                "property": "ro.boot.slot_successful",
                "raw": boot_success_prop,
                "semantics": "positive value is proof; negative value is only a boot-time snapshot",
            },
        )
    )

    current = adb.shell(["bootctl", "get-current-slot"], timeout=15)
    current_stdout = _text(current)
    current_stderr = _stderr(current)
    if current.returncode != 0:
        results.extend(
            [
                CheckResult(
                    id="release.boot_control_observable",
                    status=Status.SKIP,
                    summary="boot_control metadata observable from ordinary ADB shell",
                    expected="bootctl get-current-slot rc=0",
                    actual=f"rc={current.returncode}",
                    details={"stdout": current_stdout, "stderr": current_stderr},
                ),
                CheckResult(
                    id="release.slot_index",
                    status=Status.SKIP,
                    summary="boot_control current slot matches expected release slot",
                    expected=expected_index,
                    actual=f"unobservable rc={current.returncode}; runtime={runtime_suffix}",
                ),
                CheckResult(
                    id="release.slot_bootable",
                    status=Status.SKIP,
                    summary="expected release slot is bootable",
                    expected="observable boot_control metadata",
                    actual="not queried because boot_control client is unavailable",
                ),
                CheckResult(
                    id="release.slot_successful",
                    status=Status.SKIP,
                    summary="expected release slot is marked successful",
                    expected="observable boot_control metadata",
                    actual="not queried because boot_control client is unavailable",
                ),
            ]
        )
        return results

    try:
        current_index = int(current_stdout)
    except ValueError:
        current_index = -1
    results.extend(
        [
            CheckResult(
                id="release.boot_control_observable",
                status=Status.PASS,
                summary="boot_control metadata observable from ordinary ADB shell",
                expected="bootctl get-current-slot rc=0",
                actual=f"rc={current.returncode}",
            ),
            CheckResult(
                id="release.slot_index",
                status=Status.PASS if current_index == expected_index else Status.FAIL,
                summary="boot_control current slot matches expected release slot",
                expected=expected_index,
                actual=current_stdout,
            ),
        ]
    )

    bootable = adb.shell(["bootctl", "is-slot-bootable", str(expected_index)], timeout=15)
    successful = adb.shell(["bootctl", "is-slot-marked-successful", str(expected_index)], timeout=15)
    results.append(
        _bootctl_boolean_result(
            check_id="release.slot_bootable",
            summary="expected release slot is bootable",
            result=bootable,
        )
    )
    results.append(
        _bootctl_boolean_result(
            check_id="release.slot_successful",
            summary="expected release slot is marked successful",
            result=successful,
        )
    )
    return results


def load_manual_d4_evidence(path: str | Path) -> dict:
    raw = Path(path).read_text(encoding="utf-8")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError("manual evidence must be a JSON object")
    if data.get("schema_version") != 1:
        raise ValueError("manual evidence schema_version must be 1")
    return data


def verify_manual_d4_evidence(
    data: dict,
    *,
    expected_device: str,
    expected_buildmanifest_sha256: str,
    actual_build_fingerprint: str,
) -> list[CheckResult]:
    results: list[CheckResult] = []

    evidence_device = data.get("device")
    evidence_manifest = str(data.get("buildmanifest_sha256", "")).lower()
    evidence_fingerprint = data.get("build_fingerprint")
    expected_manifest = expected_buildmanifest_sha256.lower()
    identity_ok = (
        evidence_device == expected_device
        and re.fullmatch(r"[0-9a-f]{64}", evidence_manifest) is not None
        and evidence_manifest == expected_manifest
        and evidence_fingerprint == actual_build_fingerprint
    )
    results.append(
        CheckResult(
            id="release.manual_evidence_identity",
            status=Status.PASS if identity_ok else Status.FAIL,
            summary="manual physical evidence is bound to this device/build identity",
            expected=f"device={expected_device}; buildmanifest={expected_manifest}; fingerprint={actual_build_fingerprint}",
            actual=f"device={evidence_device}; buildmanifest={evidence_manifest}; fingerprint={evidence_fingerprint}",
        )
    )

    tests = data.get("tests")
    if not isinstance(tests, dict):
        return results + [
            CheckResult(
                id="release.manual_evidence_tests",
                status=Status.ERROR,
                summary="manual physical evidence contains a tests object",
                expected="object",
                actual=type(tests).__name__,
            )
        ]

    for key, summary in _REQUIRED_PHYSICAL.items():
        entry = tests.get(key)
        status_text = entry.get("status") if isinstance(entry, dict) else None
        results.append(
            CheckResult(
                id=f"physical.{key}",
                status=Status.PASS if status_text == "PASS" else Status.FAIL,
                summary=summary,
                expected="PASS",
                actual=status_text or "MISSING",
                details={"note": entry.get("note", "") if isinstance(entry, dict) else ""},
            )
        )

    nfc = tests.get("nfc_rf")
    nfc_status = nfc.get("status") if isinstance(nfc, dict) else None
    if nfc_status == "PASS":
        mapped = Status.PASS
    elif nfc_status == "NOT_TESTED_NO_HARDWARE":
        mapped = Status.SKIP
    else:
        mapped = Status.FAIL
    results.append(
        CheckResult(
            id="physical.nfc_rf",
            status=mapped,
            summary="physical NFC RF/tag interaction",
            expected="PASS or explicit NOT_TESTED_NO_HARDWARE",
            actual=nfc_status or "MISSING",
            details={"note": nfc.get("note", "") if isinstance(nfc, dict) else ""},
        )
    )
    return results


def verify_default_app_set(adb: AdbClient, data: dict) -> list[CheckResult]:
    policy = data.get("default_app_set")
    if not isinstance(policy, dict):
        return [
            CheckResult(
                id="release.default_app_set_documented",
                status=Status.ERROR,
                summary="default app set is documented in release evidence",
                expected="object",
                actual=type(policy).__name__,
            )
        ]

    results: list[CheckResult] = [
        CheckResult(
            id="release.default_app_set_documented",
            status=Status.PASS,
            summary="default app set is documented in release evidence",
            expected="home/browser/dialer/sms",
            actual=",".join(sorted(policy)),
        )
    ]
    for key, role in _ROLE_COMMANDS.items():
        expected_holder = policy.get(key)
        result = adb.shell(["cmd", "role", "get-role-holders", "--user", "0", role], timeout=30)
        holders = [line.strip() for line in _text(result).splitlines() if line.strip()]
        ok = result.returncode == 0 and isinstance(expected_holder, str) and expected_holder in holders
        results.append(
            CheckResult(
                id=f"release.default_app.{key}",
                status=Status.PASS if ok else Status.FAIL,
                summary=f"documented {key} default is active",
                expected=expected_holder or "documented package",
                actual=",".join(holders) if holders else f"rc={result.returncode}",
            )
        )
    return results
