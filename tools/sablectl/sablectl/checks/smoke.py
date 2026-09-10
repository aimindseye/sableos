from __future__ import annotations

from ..adb import AdbClient
from ..types import CheckResult, Status


def verify_smoke_health(adb: AdbClient) -> list[CheckResult]:
    results: list[CheckResult] = []

    selinux = adb.shell(["getenforce"], timeout=15).stdout.replace("\r", "").strip()
    results.append(
        CheckResult(
            id="security.selinux",
            status=Status.PASS if selinux == "Enforcing" else Status.FAIL,
            summary="SELinux enforcing",
            expected="Enforcing",
            actual=selinux,
        )
    )

    for prop, check_id, summary in [
        ("init.svc.servicemanager", "service.servicemanager", "servicemanager running"),
        ("init.svc.surfaceflinger", "service.surfaceflinger", "surfaceflinger running"),
        ("init.svc.zygote", "service.zygote", "zygote running"),
    ]:
        actual = adb.getprop(prop)
        results.append(
            CheckResult(
                id=check_id,
                status=Status.PASS if actual == "running" else Status.FAIL,
                summary=summary,
                expected="running",
                actual=actual,
            )
        )

    package_result = adb.shell(["pm", "list", "packages"], timeout=60)
    package_count = sum(1 for line in package_result.stdout.splitlines() if line.startswith("package:"))
    results.append(
        CheckResult(
            id="service.package_manager",
            status=Status.PASS if package_result.returncode == 0 and package_count > 0 else Status.FAIL,
            summary="PackageManager responds with installed packages",
            expected=">0",
            actual=package_count,
        )
    )

    return results
