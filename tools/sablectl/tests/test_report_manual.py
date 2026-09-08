from sablectl.report import RunReport
from sablectl.types import CheckResult, Status


def test_report_exposes_pass_with_manual():
    report = RunReport(
        suite="acceptance-d4",
        results=[
            CheckResult("a", Status.PASS, "automated"),
            CheckResult("m", Status.MANUAL, "physical"),
        ],
    )
    assert report.failed is False
    assert report.has_manual is True
    assert report.overall == "PASS_WITH_MANUAL"
    data = report.to_dict()
    assert data["overall"] == "PASS_WITH_MANUAL"
    assert data["complete"] is False
