from __future__ import annotations

import time

from ..adb import AdbClient
from ..target_files import TargetFilesExpectation
from ..types import CheckResult, Status


def _check(check_id: str, summary: str, expected, actual) -> CheckResult:
    return CheckResult(
        id=check_id,
        status=Status.PASS if actual == expected else Status.FAIL,
        summary=summary,
        expected=expected,
        actual=actual,
    )


def verify_boot(
    adb: AdbClient,
    expected: TargetFilesExpectation,
    *,
    expected_device: str = "panther",
    expected_slot: str | None = None,
) -> list[CheckResult]:
    results: list[CheckResult] = []
    t0 = time.monotonic()

    product = adb.getprop("ro.product.device")
    results.append(_check("boot.device", "device codename", expected_device, product))

    boot_completed = adb.getprop("sys.boot_completed")
    results.append(_check("boot.completed", "Android boot completed", "1", boot_completed))

    if expected_slot is not None:
        slot = adb.getprop("ro.boot.slot_suffix")
        wanted = expected_slot if expected_slot.startswith("_") else f"_{expected_slot}"
        results.append(_check("boot.slot", "active slot", wanted, slot))

    crypto = adb.getprop("ro.crypto.state")
    results.append(_check("boot.crypto", "file/data encryption active", "encrypted", crypto))

    bm_actual = adb.sha256("/system/etc/security/fsverity/BuildManifest.apk")
    results.append(
        _check(
            "artifact.buildmanifest",
            "installed BuildManifest.apk matches target-files",
            expected.buildmanifest_apk_sha256,
            bm_actual,
        )
    )

    art_pass = 0
    for item in expected.art:
        actual = adb.sha256("/" + item.installed_path)
        status = Status.PASS if actual == item.sha256 else Status.FAIL
        if status is Status.PASS:
            art_pass += 1
        results.append(
            CheckResult(
                id=f"artifact.art.{item.installed_path}",
                status=status,
                summary="installed ART image matches target-files",
                expected=item.sha256,
                actual=actual,
                details={"size": item.size},
            )
        )

    results.append(
        CheckResult(
            id="artifact.art.count",
            status=Status.PASS if art_pass == len(expected.art) else Status.FAIL,
            summary="all expected ART images matched",
            expected=len(expected.art),
            actual=art_pass,
        )
    )

    elapsed = int((time.monotonic() - t0) * 1000)
    for result in results:
        result.duration_ms = elapsed
    return results
