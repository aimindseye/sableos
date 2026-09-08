import json
from dataclasses import dataclass
from pathlib import Path

from sablectl.checks.release import (
    load_manual_d4_evidence,
    verify_default_app_set,
    verify_manual_d4_evidence,
    verify_slot_release_health,
)
from sablectl.cli import build_parser
from sablectl.types import Status


@dataclass
class Result:
    returncode: int = 0
    stdout: str = ""
    stderr: str = ""


class FakeAdb:
    def __init__(self, successful: bool = True):
        self.successful = successful

    def shell(self, args, **kwargs):
        key = tuple(args)
        table = {
            ("bootctl", "get-current-slot"): Result(stdout="1\n"),
            ("bootctl", "is-slot-bootable", "1"): Result(returncode=0),
            ("bootctl", "is-slot-marked-successful", "1"): Result(
                returncode=0 if self.successful else 1
            ),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.HOME"): Result(
                stdout="com.android.launcher3\n"
            ),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.BROWSER"): Result(
                stdout="app.vanadium.browser\n"
            ),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.DIALER"): Result(
                stdout="com.android.dialer\n"
            ),
            ("cmd", "role", "get-role-holders", "--user", "0", "android.app.role.SMS"): Result(
                stdout="com.android.messaging\n"
            ),
        }
        return table[key]


def evidence() -> dict:
    tests = {
        key: {"status": "PASS"}
        for key in [
            "voice_out",
            "voice_in",
            "sms_out",
            "sms_in",
            "mms_out",
            "mms_in",
            "hotspot",
            "bluetooth_audio",
            "camera",
            "location",
            "biometrics",
        ]
    }
    tests["nfc_rf"] = {
        "status": "NOT_TESTED_NO_HARDWARE",
        "note": "No NFC tag available",
    }
    return {
        "schema_version": 1,
        "device": "panther",
        "buildmanifest_sha256": "a" * 64,
        "build_fingerprint": "fp",
        "tests": tests,
        "default_app_set": {
            "home": "com.android.launcher3",
            "browser": "app.vanadium.browser",
            "dialer": "com.android.dialer",
            "sms": "com.android.messaging",
        },
    }


def test_slot_successful_passes():
    results = {r.id: r for r in verify_slot_release_health(FakeAdb(), "b")}
    assert all(r.status is Status.PASS for r in results.values())


def test_slot_unsuccessful_fails():
    results = {r.id: r for r in verify_slot_release_health(FakeAdb(False), "_b")}
    assert results["release.slot_successful"].status is Status.FAIL


def test_manual_evidence_and_nfc_deferred():
    results = verify_manual_d4_evidence(
        evidence(),
        expected_device="panther",
        expected_buildmanifest_sha256="a" * 64,
        actual_build_fingerprint="fp",
    )
    by_id = {r.id: r for r in results}
    assert by_id["release.manual_evidence_identity"].status is Status.PASS
    assert by_id["physical.voice_out"].status is Status.PASS
    assert by_id["physical.nfc_rf"].status is Status.SKIP
    assert not any(r.status in {Status.FAIL, Status.ERROR} for r in results)


def test_manual_identity_mismatch_fails():
    data = evidence()
    data["build_fingerprint"] = "wrong"
    results = verify_manual_d4_evidence(
        data,
        expected_device="panther",
        expected_buildmanifest_sha256="a" * 64,
        actual_build_fingerprint="fp",
    )
    assert results[0].status is Status.FAIL


def test_default_app_set_matches():
    results = verify_default_app_set(FakeAdb(), evidence())
    assert all(r.status is Status.PASS for r in results)


def test_loader_rejects_wrong_schema(tmp_path: Path):
    path = tmp_path / "x.json"
    path.write_text(json.dumps({"schema_version": 2}), encoding="utf-8")
    try:
        load_manual_d4_evidence(path)
    except ValueError:
        pass
    else:
        raise AssertionError("expected ValueError")


def test_release_code_is_read_only():
    source = Path(__file__).parents[1] / "sablectl" / "checks" / "release.py"
    text = source.read_text(encoding="utf-8")
    forbidden = [
        'mark-boot-successful"',
        "set-active-boot-slot",
        "set-slot-as-unbootable",
        "fastboot",
        " reboot",
        " wipe",
        " erase",
    ]
    assert all(token not in text for token in forbidden)


def test_release_d4_cli_requires_evidence_and_parses():
    args = build_parser().parse_args(
        [
            "release",
            "d4",
            "--target-files",
            "/tmp/panther-target_files.zip",
            "--baseline",
            "/tmp/baseline.json",
            "--manual-evidence",
            "/tmp/manual.json",
            "--expected-slot",
            "b",
        ]
    )
    assert args.command == "release"
    assert args.release_command == "d4"
    assert args.manual_evidence == "/tmp/manual.json"
