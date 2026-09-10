from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from .types import CheckResult, Status


@dataclass(slots=True)
class RunReport:
    suite: str
    results: list[CheckResult]
    serial: str | None = None
    metadata: dict[str, object] = field(default_factory=dict)

    @property
    def failed(self) -> bool:
        return any(r.status in {Status.FAIL, Status.ERROR} for r in self.results)

    @property
    def has_manual(self) -> bool:
        return any(r.status is Status.MANUAL for r in self.results)

    @property
    def overall(self) -> str:
        if self.failed:
            return "FAIL"
        if self.has_manual:
            return "PASS_WITH_MANUAL"
        return "PASS"

    def counts(self) -> dict[str, int]:
        return {status.value: sum(1 for r in self.results if r.status is status) for status in Status}

    def to_dict(self) -> dict:
        return {
            "schema": 1,
            "suite": self.suite,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "serial": mask_serial(self.serial),
            "metadata": self.metadata,
            "counts": self.counts(),
            "failed": self.failed,
            "complete": not self.failed and not self.has_manual,
            "overall": self.overall,
            "results": [r.to_dict() for r in self.results],
        }

    def write(self, out_dir: str | Path) -> Path:
        root = Path(out_dir)
        root.mkdir(parents=True, exist_ok=True)
        data = self.to_dict()
        (root / "report.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (root / "report.md").write_text(self.to_markdown(), encoding="utf-8")
        ET.ElementTree(self.to_junit()).write(root / "junit.xml", encoding="utf-8", xml_declaration=True)
        return root

    def to_markdown(self) -> str:
        counts = self.counts()
        lines = [
            f"# sablectl report — {self.suite}",
            "",
            f"Overall: **{self.overall}**",
            "",
            "| Status | Count |",
            "| --- | ---: |",
        ]
        lines += [f"| {k} | {v} |" for k, v in counts.items()]
        lines += ["", "| Check | Status | Expected | Actual | Summary |", "| --- | --- | --- | --- | --- |"]
        for r in self.results:
            lines.append(
                f"| `{r.id}` | {r.status.value} | {safe(r.expected)} | {safe(r.actual)} | {safe(r.summary)} |"
            )
        return "\n".join(lines) + "\n"

    def to_junit(self) -> ET.Element:
        counts = self.counts()
        suite = ET.Element(
            "testsuite",
            {
                "name": self.suite,
                "tests": str(len(self.results)),
                "failures": str(counts[Status.FAIL.value]),
                "errors": str(counts[Status.ERROR.value]),
                "skipped": str(counts[Status.SKIP.value] + counts[Status.MANUAL.value]),
            },
        )
        for r in self.results:
            case = ET.SubElement(suite, "testcase", {"name": r.id, "time": f"{r.duration_ms / 1000:.3f}"})
            if r.status is Status.FAIL:
                node = ET.SubElement(case, "failure", {"message": r.summary})
                node.text = f"expected={r.expected!r} actual={r.actual!r}"
            elif r.status is Status.ERROR:
                node = ET.SubElement(case, "error", {"message": r.summary})
                node.text = f"expected={r.expected!r} actual={r.actual!r}"
            elif r.status in {Status.SKIP, Status.MANUAL}:
                ET.SubElement(case, "skipped", {"message": r.status.value})
        return suite


def mask_serial(serial: str | None) -> str | None:
    if not serial:
        return None
    if len(serial) <= 4:
        return "*" * len(serial)
    return "*" * (len(serial) - 4) + serial[-4:]


def safe(value) -> str:
    if value is None:
        return ""
    return str(value).replace("|", "\\|").replace("\n", " ")


def print_report(report: RunReport) -> None:
    for r in report.results:
        print(f"[{r.status.value:6}] {r.id}: {r.summary} (expected={r.expected!r} actual={r.actual!r})")
    counts = report.counts()
    print("\n" + " ".join(f"{k}={v}" for k, v in counts.items()))
    print(f"OVERALL={report.overall}")
