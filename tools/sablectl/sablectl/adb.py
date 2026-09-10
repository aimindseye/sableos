from __future__ import annotations

import re
import time
from dataclasses import dataclass

from .runner import CommandError, CommandRunner
from .types import DeviceSnapshot


@dataclass(slots=True)
class AdbDevice:
    serial: str
    state: str


class AdbClient:
    def __init__(self, runner: CommandRunner, *, adb_path: str = "adb", serial: str | None = None):
        self.runner = runner
        self.adb_path = adb_path
        self.serial = serial

    def list_devices(self) -> list[AdbDevice]:
        result = self.runner.run([self.adb_path, "devices"], timeout=15)
        if result.returncode != 0:
            return []
        out: list[AdbDevice] = []
        for line in result.stdout.splitlines():
            if not line.strip() or line.startswith("List of devices") or line.startswith("*"):
                continue
            parts = line.split()
            if len(parts) >= 2:
                out.append(AdbDevice(parts[0], parts[1]))
        return out

    def resolve_serial(self) -> str:
        devices = self.list_devices()
        if self.serial:
            matches = [d for d in devices if d.serial == self.serial]
            if not matches:
                raise RuntimeError("requested ADB serial is not present")
            if matches[0].state != "device":
                raise RuntimeError(f"ADB device {self.serial} state={matches[0].state}")
            return self.serial
        ready = [d for d in devices if d.state == "device"]
        if len(ready) != 1:
            raise RuntimeError(f"expected exactly one authorized ADB device, found {len(ready)}")
        self.serial = ready[0].serial
        return self.serial

    def wait(self, timeout: int = 180, poll: float = 2.0) -> str:
        deadline = time.monotonic() + timeout
        last_error = ""
        while time.monotonic() < deadline:
            try:
                return self.resolve_serial()
            except RuntimeError as exc:
                last_error = str(exc)
                time.sleep(poll)
        raise TimeoutError(last_error or "ADB device did not become ready")

    def run(self, args: list[str], *, timeout: int | None = None, check: bool = False):
        serial = self.resolve_serial()
        return self.runner.run([self.adb_path, "-s", serial, *args], timeout=timeout, check=check)

    def shell(self, args: list[str], *, timeout: int | None = None, check: bool = False):
        return self.run(["shell", *args], timeout=timeout, check=check)

    def getprop(self, name: str) -> str:
        result = self.shell(["getprop", name], timeout=15, check=True)
        return result.stdout.replace("\r", "").strip()

    def sha256(self, path: str) -> str:
        result = self.shell(["sha256sum", path], timeout=60, check=True)
        value = result.stdout.replace("\r", "").strip().split()
        if not value or not re.fullmatch(r"[0-9a-fA-F]{64}", value[0]):
            raise RuntimeError(f"invalid sha256sum output for {path}: {result.stdout!r}")
        return value[0].lower()

    def third_party_packages(self) -> list[str]:
        result = self.shell(["pm", "list", "packages", "-3"], timeout=60, check=True)
        packages = []
        for raw in result.stdout.replace("\r", "").splitlines():
            raw = raw.strip()
            if raw.startswith("package:"):
                packages.append(raw[len("package:"):])
        return sorted(set(packages))

    def users(self) -> list[str]:
        result = self.shell(["cmd", "user", "list"], timeout=30, check=True)
        rows = []
        for raw in result.stdout.replace("\r", "").splitlines():
            raw = raw.strip()
            if "UserInfo{" in raw:
                rows.append(raw)
        return rows

    def snapshot(self) -> DeviceSnapshot:
        serial = self.resolve_serial()
        def gp(name: str) -> str | None:
            try:
                return self.getprop(name) or None
            except (RuntimeError, CommandError):
                return None
        selinux = self.shell(["getenforce"], timeout=15).stdout.replace("\r", "").strip() or None
        try:
            third_party = self.third_party_packages()
        except Exception:
            third_party = []
        try:
            users = self.users()
        except Exception:
            users = []
        return DeviceSnapshot(
            serial=serial,
            product=gp("ro.product.device"),
            slot_suffix=gp("ro.boot.slot_suffix"),
            build_fingerprint=gp("ro.build.fingerprint"),
            boot_completed=gp("sys.boot_completed"),
            crypto_state=gp("ro.crypto.state"),
            crypto_type=gp("ro.crypto.type"),
            ce_available=gp("sys.user.0.ce_available"),
            verified_boot_state=gp("ro.boot.verifiedbootstate"),
            selinux=selinux,
            third_party_packages=third_party,
            users=users,
        )
