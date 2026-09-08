from __future__ import annotations

import argparse
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

from .adb import AdbClient
from .baseline import capture_baseline, load_baseline
from .checks import (
    load_manual_d4_evidence,
    manual_d4_gates,
    verify_boot,
    verify_d4_host_acceptance,
    verify_default_app_set,
    verify_manual_d4_evidence,
    verify_preserved_data,
    verify_slot_release_health,
    verify_smoke_health,
)
from .report import RunReport, print_report
from .runner import CommandRunner
from .target_files import inspect_target_files
from .types import CheckResult, Status


def _timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _output_dir(root: str | Path, suite: str) -> Path:
    return Path(root) / suite / _timestamp()


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="sablectl")
    p.add_argument("--adb", default="adb")
    p.add_argument("--serial")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--output-root", default=".sablectl/runs")
    sub = p.add_subparsers(dest="command", required=True)

    sub.add_parser("doctor")

    device = sub.add_parser("device")
    dsub = device.add_subparsers(dest="device_command", required=True)
    wait = dsub.add_parser("wait")
    wait.add_argument("--timeout", type=int, default=180)

    baseline = sub.add_parser("baseline")
    bsub = baseline.add_subparsers(dest="baseline_command", required=True)
    capture = bsub.add_parser("capture")
    capture.add_argument("--out-root", default=".sablectl/baselines")

    verify = sub.add_parser("verify")
    vsub = verify.add_subparsers(dest="verify_command", required=True)
    boot = vsub.add_parser("boot")
    boot.add_argument("--target-files", required=True)
    boot.add_argument("--expected-device", default="panther")
    boot.add_argument("--expected-slot")
    boot.add_argument("--hash-container", action="store_true")
    preserved = vsub.add_parser("preserved-data")
    preserved.add_argument("--baseline", required=True)

    smoke = sub.add_parser("smoke")
    smoke.add_argument("--target-files", required=True)
    smoke.add_argument("--baseline")
    smoke.add_argument("--expected-device", default="panther")
    smoke.add_argument("--expected-slot")
    smoke.add_argument("--hash-container", action="store_true")

    acceptance = sub.add_parser("acceptance")
    asub = acceptance.add_subparsers(dest="acceptance_command", required=True)
    d4 = asub.add_parser("d4")
    d4.add_argument("--target-files", required=True)
    d4.add_argument("--baseline", required=True)
    d4.add_argument("--expected-device", default="panther")
    d4.add_argument("--expected-slot", required=True)
    d4.add_argument("--hash-container", action="store_true")
    d4.add_argument(
        "--require-complete",
        action="store_true",
        help="return exit 4 while any MANUAL D4 gates remain",
    )

    release = sub.add_parser("release")
    rsub = release.add_subparsers(dest="release_command", required=True)
    rd4 = rsub.add_parser("d4")
    rd4.add_argument("--target-files", required=True)
    rd4.add_argument("--baseline", required=True)
    rd4.add_argument("--manual-evidence", required=True)
    rd4.add_argument("--expected-device", default="panther")
    rd4.add_argument("--expected-slot", required=True)
    rd4.add_argument("--hash-container", action="store_true")

    return p


def _client(args) -> AdbClient:
    return AdbClient(
        CommandRunner(dry_run=args.dry_run, verbose=args.verbose),
        adb_path=args.adb,
        serial=args.serial,
    )


def _run_report(
    args,
    suite: str,
    results: list[CheckResult],
    serial: str | None,
    metadata: dict,
    *,
    require_complete: bool = False,
) -> int:
    report = RunReport(suite=suite, results=results, serial=serial, metadata=metadata)
    out = _output_dir(args.output_root, suite)
    report.write(out)
    print_report(report)
    print(f"REPORT_DIR={out}")
    if report.failed:
        return 2
    if require_complete and report.has_manual:
        return 4
    return 0


def cmd_doctor(args) -> int:
    results: list[CheckResult] = []
    adb_path = shutil.which(args.adb)
    results.append(
        CheckResult(
            "host.adb",
            Status.PASS if adb_path else Status.FAIL,
            "adb executable available",
            expected="present",
            actual=adb_path or "missing",
        )
    )
    client = _client(args)
    devices = client.list_devices() if adb_path else []
    ready = [d for d in devices if d.state == "device"]
    results.append(
        CheckResult(
            "device.authorized_count",
            Status.PASS if len(ready) == 1 else Status.FAIL,
            "exactly one authorized ADB device",
            expected=1,
            actual=len(ready),
            details={"states": [{"serial": "masked", "state": d.state} for d in devices]},
        )
    )
    serial = ready[0].serial if len(ready) == 1 else None
    return _run_report(args, "doctor", results, serial, {})


def cmd_wait(args) -> int:
    client = _client(args)
    serial = client.wait(args.timeout)
    print(f"ADB_DEVICE_READY={serial[-4:].rjust(len(serial), '*')}")
    return 0


def cmd_baseline(args) -> int:
    client = _client(args)
    client.wait(30)
    path = capture_baseline(client, args.out_root)
    print(f"BASELINE={path}")
    return 0


def cmd_verify_boot(args) -> int:
    client = _client(args)
    serial = client.wait(30)
    expected = inspect_target_files(args.target_files, hash_container=args.hash_container)
    results = verify_boot(client, expected, expected_device=args.expected_device, expected_slot=args.expected_slot)
    metadata = {
        "target_files": str(expected.path),
        "target_files_size": expected.size,
        "target_files_sha256": expected.container_sha256,
        "manifest_pb_sha256": expected.manifest_pb_sha256,
        "buildmanifest_apk_sha256": expected.buildmanifest_apk_sha256,
    }
    return _run_report(args, "verify-boot", results, serial, metadata)


def cmd_verify_preserved(args) -> int:
    client = _client(args)
    serial = client.wait(30)
    baseline = load_baseline(args.baseline)
    results = verify_preserved_data(client, baseline)
    return _run_report(args, "verify-preserved-data", results, serial, {"baseline": args.baseline})


def cmd_smoke(args) -> int:
    client = _client(args)
    serial = client.wait(30)
    expected = inspect_target_files(args.target_files, hash_container=args.hash_container)
    results = verify_boot(client, expected, expected_device=args.expected_device, expected_slot=args.expected_slot)
    results.extend(verify_smoke_health(client))
    if args.baseline:
        results.extend(verify_preserved_data(client, load_baseline(args.baseline)))
    metadata = {
        "target_files": str(expected.path),
        "target_files_size": expected.size,
        "target_files_sha256": expected.container_sha256,
        "manifest_pb_sha256": expected.manifest_pb_sha256,
        "buildmanifest_apk_sha256": expected.buildmanifest_apk_sha256,
        "baseline": args.baseline,
    }
    return _run_report(args, "smoke", results, serial, metadata)


def cmd_acceptance_d4(args) -> int:
    client = _client(args)
    serial = client.wait(30)
    expected = inspect_target_files(args.target_files, hash_container=args.hash_container)
    baseline = load_baseline(args.baseline)

    results = verify_boot(
        client,
        expected,
        expected_device=args.expected_device,
        expected_slot=args.expected_slot,
    )
    results.extend(verify_smoke_health(client))
    results.extend(verify_preserved_data(client, baseline))
    results.extend(verify_d4_host_acceptance(client))
    results.extend(manual_d4_gates())

    metadata = {
        "target_files": str(expected.path),
        "target_files_size": expected.size,
        "target_files_sha256": expected.container_sha256,
        "manifest_pb_sha256": expected.manifest_pb_sha256,
        "buildmanifest_apk_sha256": expected.buildmanifest_apk_sha256,
        "baseline": args.baseline,
        "acceptance": "d4",
        "manual_gate_policy": "explicit MANUAL results retained",
    }
    return _run_report(
        args,
        "acceptance-d4",
        results,
        serial,
        metadata,
        require_complete=args.require_complete,
    )


def cmd_release_d4(args) -> int:
    client = _client(args)
    serial = client.wait(30)
    expected = inspect_target_files(args.target_files, hash_container=args.hash_container)
    baseline = load_baseline(args.baseline)
    manual = load_manual_d4_evidence(args.manual_evidence)

    results = verify_boot(
        client,
        expected,
        expected_device=args.expected_device,
        expected_slot=args.expected_slot,
    )
    results.extend(verify_smoke_health(client))
    results.extend(verify_preserved_data(client, baseline))
    results.extend(verify_d4_host_acceptance(client))
    results.extend(verify_slot_release_health(client, args.expected_slot))

    fingerprint = client.getprop("ro.build.fingerprint")
    results.extend(
        verify_manual_d4_evidence(
            manual,
            expected_device=args.expected_device,
            expected_buildmanifest_sha256=expected.buildmanifest_apk_sha256,
            actual_build_fingerprint=fingerprint,
        )
    )
    results.extend(verify_default_app_set(client, manual))

    metadata = {
        "target_files": str(expected.path),
        "target_files_size": expected.size,
        "target_files_sha256": expected.container_sha256,
        "manifest_pb_sha256": expected.manifest_pb_sha256,
        "buildmanifest_apk_sha256": expected.buildmanifest_apk_sha256,
        "baseline": args.baseline,
        "manual_evidence": args.manual_evidence,
        "release_gate": "d4",
        "nfc_rf_policy": "NOT_TESTED_NO_HARDWARE is explicit non-blocking SKIP",
    }
    return _run_report(args, "release-d4", results, serial, metadata)


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "doctor":
            return cmd_doctor(args)
        if args.command == "device" and args.device_command == "wait":
            return cmd_wait(args)
        if args.command == "baseline" and args.baseline_command == "capture":
            return cmd_baseline(args)
        if args.command == "verify" and args.verify_command == "boot":
            return cmd_verify_boot(args)
        if args.command == "verify" and args.verify_command == "preserved-data":
            return cmd_verify_preserved(args)
        if args.command == "smoke":
            return cmd_smoke(args)
        if args.command == "acceptance" and args.acceptance_command == "d4":
            return cmd_acceptance_d4(args)
        if args.command == "release" and args.release_command == "d4":
            return cmd_release_d4(args)
        raise RuntimeError("unhandled command")
    except Exception as exc:
        print(f"sablectl: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
