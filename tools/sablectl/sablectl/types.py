from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum
from typing import Any


class Status(str, Enum):
    PASS = "PASS"
    FAIL = "FAIL"
    SKIP = "SKIP"
    MANUAL = "MANUAL"
    ERROR = "ERROR"


@dataclass(slots=True)
class CheckResult:
    id: str
    status: Status
    summary: str
    expected: str | int | bool | None = None
    actual: str | int | bool | None = None
    duration_ms: int = 0
    evidence: list[str] = field(default_factory=list)
    details: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["status"] = self.status.value
        return data


@dataclass(slots=True)
class CommandResult:
    cmd: list[str]
    returncode: int
    stdout: str = ""
    stderr: str = ""
    timed_out: bool = False


@dataclass(slots=True)
class DeviceSnapshot:
    serial: str
    product: str | None = None
    slot_suffix: str | None = None
    build_fingerprint: str | None = None
    boot_completed: str | None = None
    crypto_state: str | None = None
    crypto_type: str | None = None
    ce_available: str | None = None
    verified_boot_state: str | None = None
    selinux: str | None = None
    third_party_packages: list[str] = field(default_factory=list)
    users: list[str] = field(default_factory=list)
