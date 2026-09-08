from dataclasses import dataclass

from sablectl.checks.usb import verify_adb_usb_health
from sablectl.types import Status


@dataclass
class Result:
    returncode: int = 0
    stdout: str = ""
    stderr: str = ""


class FakeAdb:
    def __init__(self, props):
        self.props = props

    def run(self, args, **kwargs):
        assert args == ["get-state"]
        return Result(stdout="device\n")

    def getprop(self, name):
        return self.props.get(name, "")


def test_empty_usb_properties_do_not_false_fail_healthy_adb():
    results = verify_adb_usb_health(FakeAdb({}))
    by_id = {r.id: r for r in results}
    assert by_id["adb.transport"].status is Status.PASS
    assert by_id["usb.function_state"].status is Status.SKIP
    assert not any(r.status is Status.FAIL for r in results)


def test_exposed_usb_adb_function_passes():
    results = verify_adb_usb_health(
        FakeAdb({"sys.usb.state": "mtp,adb", "sys.usb.config": "mtp,adb"})
    )
    by_id = {r.id: r for r in results}
    assert by_id["adb.transport"].status is Status.PASS
    assert by_id["usb.function_state"].status is Status.PASS


def test_unhealthy_adb_transport_still_fails():
    fake = FakeAdb({})
    fake.run = lambda args, **kwargs: Result(returncode=1, stdout="offline\n")
    results = verify_adb_usb_health(fake)
    by_id = {r.id: r for r in results}
    assert by_id["adb.transport"].status is Status.FAIL


def test_d4_wrapper_supersedes_legacy_usb_false_fail(monkeypatch):
    import sablectl.checks as checks
    from sablectl.types import CheckResult

    monkeypatch.setattr(
        checks,
        "_verify_d4_host_acceptance",
        lambda adb: [
            CheckResult("other", Status.PASS, "other"),
            CheckResult("usb.adb", Status.FAIL, "legacy false failure"),
        ],
    )
    results = checks.verify_d4_host_acceptance(FakeAdb({}))
    by_id = {r.id: r for r in results}
    assert "usb.adb" not in by_id
    assert by_id["other"].status is Status.PASS
    assert by_id["adb.transport"].status is Status.PASS
    assert by_id["usb.function_state"].status is Status.SKIP
    assert not any(r.status is Status.FAIL for r in results)
