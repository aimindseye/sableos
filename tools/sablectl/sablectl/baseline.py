from __future__ import annotations

import hashlib
import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .adb import AdbClient


CAPTURE_COMMANDS: list[tuple[str, list[str]]] = [
    ("getprop", ["getprop"]),
    ("packages", ["pm", "list", "packages"]),
    ("packages-third-party", ["pm", "list", "packages", "-3"]),
    ("features", ["pm", "list", "features"]),
    ("users", ["cmd", "user", "list"]),
    ("battery", ["dumpsys", "battery"]),
    ("wifi", ["dumpsys", "wifi"]),
    ("connectivity", ["dumpsys", "connectivity"]),
    ("telephony-registry", ["dumpsys", "telephony.registry"]),
    ("bluetooth-manager", ["dumpsys", "bluetooth_manager"]),
    ("location", ["dumpsys", "location"]),
    ("getenforce", ["getenforce"]),
]


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture_baseline(adb: AdbClient, out_root: str | Path) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    root = Path(out_root) / stamp
    root.mkdir(parents=True, exist_ok=False)

    snapshot = adb.snapshot()
    manifest: dict[str, object] = {
        "schema": 1,
        "captured_at": stamp,
        "device": asdict(snapshot),
        "commands": {},
    }

    for name, args in CAPTURE_COMMANDS:
        result = adb.shell(args, timeout=120)
        path = root / f"{name}.txt"
        content = result.stdout
        if result.stderr:
            content += ("\n[stderr]\n" + result.stderr)
        path.write_text(content, encoding="utf-8")
        manifest["commands"][name] = {
            "returncode": result.returncode,
            "sha256": _sha256(path),
            "file": path.name,
        }

    baseline_path = root / "baseline.json"
    baseline_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return baseline_path


def load_baseline(path: str | Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))
