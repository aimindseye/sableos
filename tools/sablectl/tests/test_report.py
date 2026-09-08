from sablectl.report import RunReport
from sablectl.types import CheckResult, Status


def test_report_writes_json_markdown_junit(tmp_path):
    report = RunReport(
        suite="smoke",
        serial="2C160DLH20007H",
        results=[CheckResult("x", Status.PASS, "ok", expected=1, actual=1)],
    )
    report.write(tmp_path)
    assert (tmp_path / "report.json").is_file()
    assert (tmp_path / "report.md").is_file()
    assert (tmp_path / "junit.xml").is_file()
    assert "2C160DLH20007H" not in (tmp_path / "report.json").read_text()
