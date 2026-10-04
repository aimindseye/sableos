#!/usr/bin/env python3
"""Canonical synthetic DEX compiler helper for N1I-B self-tests.

Prefer legacy dx only when explicitly available for compatibility with the
original fixtures. Otherwise use the pinned Android SDK D8 exposed by the
Sable host-tool profile. No network access or device contact is performed.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


class DexCompilerError(RuntimeError):
    pass


def _executable(*candidates: str | None) -> str | None:
    for candidate in candidates:
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return str(Path(candidate))
    return None


def dexdump() -> str | None:
    build_tools = os.environ.get("SABLE_ANDROID_BUILD_TOOLS")
    return _executable(
        os.environ.get("SABLE_DEXDUMP"),
        str(Path(build_tools) / "dexdump") if build_tools else None,
        shutil.which("dexdump"),
    )


def compiler() -> tuple[str, str] | None:
    dx = _executable(
        os.environ.get("N1I_DX"),
        shutil.which("dx"),
        "/usr/lib/android-sdk/build-tools/debian/dx",
    )
    if dx:
        return "dx", dx

    build_tools = os.environ.get("SABLE_ANDROID_BUILD_TOOLS")
    d8 = _executable(
        os.environ.get("SABLE_D8"),
        str(Path(build_tools) / "d8") if build_tools else None,
        shutil.which("d8"),
    )
    if d8:
        return "d8", d8
    return None


def _class_files(path: Path) -> list[str]:
    if path.is_dir():
        files = sorted(str(p) for p in path.rglob("*.class"))
        if not files:
            raise DexCompilerError(f"no .class files under {path}")
        return files
    if not path.is_file():
        raise DexCompilerError(f"missing dex input {path}")
    return [str(path)]


def compile_to_dex(source: Path, output: Path, *, min_api: int = 26, core: bool = False) -> str:
    selected = compiler()
    if selected is None:
        raise DexCompilerError("missing DEX compiler: neither dx nor canonical D8 is executable")
    kind, tool = selected

    output.parent.mkdir(parents=True, exist_ok=True)
    if kind == "dx":
        cmd = [
            tool,
            "--dex",
            f"--min-sdk-version={min_api}",
            *(["--core-library"] if core else []),
            f"--output={output}",
            str(source),
        ]
        run = subprocess.run(cmd, capture_output=True, text=True)
        if run.returncode:
            raise DexCompilerError(f"dx failed for {source}: {run.stderr[-500:]}")
        return "dx"

    with tempfile.TemporaryDirectory(prefix="n1i-d8-", dir=output.parent) as tmp:
        out_dir = Path(tmp) / "out"
        out_dir.mkdir()
        cmd = [
            tool,
            "--min-api",
            str(min_api),
            "--output",
            str(out_dir),
            *_class_files(source),
        ]
        run = subprocess.run(cmd, capture_output=True, text=True)
        if run.returncode:
            raise DexCompilerError(f"D8 failed for {source}: {run.stderr[-500:]}")
        dexes = sorted(out_dir.glob("classes*.dex"))
        if len(dexes) != 1:
            raise DexCompilerError(
                f"D8 produced {len(dexes)} dex files for one synthetic fixture: "
                + ",".join(p.name for p in dexes)
            )
        shutil.copyfile(dexes[0], output)
    return "d8"
