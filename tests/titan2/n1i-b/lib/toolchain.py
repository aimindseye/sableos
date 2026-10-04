#!/usr/bin/env python3
"""Deterministic offline host-tool discovery for N1I-B synthetic fixture tests.

No network, package installation, source mutation or device contact. Search order:
1. explicit N1I_TOOL_<NAME> environment override;
2. canonical Sable host-tool profile paths;
3. current PATH;
4. Debian Android SDK build-tools compatibility path.

The official acceptance path is build/sable.sh, which supplies explicit canonical
tool overrides. Historical Android workspaces and OUT directories are never searched.
DEX fixture compilation prefers dx only when explicitly/canonically available,
otherwise modern D8.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Iterable

def _env_key(name: str) -> str:
    return "N1I_TOOL_" + "".join(c if c.isalnum() else "_" for c in name.upper())


def _canonical_candidates(name: str) -> list[Path]:
    out: list[Path] = []
    build_tools = os.environ.get("SABLE_ANDROID_BUILD_TOOLS", "").strip()
    if build_tools:
        out.append(Path(build_tools) / name)

    ndk = os.environ.get("SABLE_ANDROID_NDK", "").strip()
    if ndk:
        out.append(Path(ndk) / "toolchains/llvm/prebuilt/linux-x86_64/bin" / name)

    jdk17 = os.environ.get("SABLE_JDK17", "").strip()
    if jdk17 and name in ("java", "javac"):
        out.append(Path(jdk17) / "bin" / name)

    return out


def _sdk_compat_candidates(name: str) -> list[Path]:
    out = [Path("/usr/lib/android-sdk/build-tools/debian") / name]
    for env in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        root = os.environ.get(env, "").strip()
        if root:
            out.extend(sorted((Path(root) / "build-tools").glob(f"*/{name}"), reverse=True))
    out.extend(sorted(Path("/usr/lib/android-sdk/build-tools").glob(f"*/{name}"), reverse=True))
    return out


def find_tool(name: str) -> str | None:
    override = os.environ.get(_env_key(name), "").strip()
    if override:
        p = Path(override)
        return str(p) if p.is_file() and os.access(p, os.X_OK) else None
    for p in _canonical_candidates(name):
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    hit = shutil.which(name)
    if hit:
        return hit
    for p in _sdk_compat_candidates(name):
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None


def prepare_tool_path(names: Iterable[str]) -> dict[str, str | None]:
    found = {name: find_tool(name) for name in names}
    dirs: list[str] = []
    for path in found.values():
        if path:
            parent = str(Path(path).parent)
            if parent not in dirs:
                dirs.append(parent)
    if dirs:
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = os.pathsep.join(dirs + ([old] if old else []))
    return found


def find_dex_compiler() -> tuple[str, list[str]] | None:
    dx = find_tool("dx")
    if dx:
        return "dx", [dx]
    d8 = find_tool("d8")
    if d8:
        return "d8", [d8]
    return None


def compile_dex(
    compiler: tuple[str, list[str]],
    source: Path,
    output: Path,
    *,
    min_api: int = 26,
    core_library: bool = False,
) -> subprocess.CompletedProcess:
    kind, command = compiler
    if kind == "dx":
        args = [
            *command,
            "--dex",
            f"--min-sdk-version={min_api}",
            *(["--core-library"] if core_library else []),
            f"--output={output}",
            str(source),
        ]
        return subprocess.run(args, capture_output=True, text=True)

    inputs = sorted(source.rglob("*.class")) if source.is_dir() else [source]
    if not inputs:
        return subprocess.CompletedProcess(command, 2, "", f"no class inputs under {source}")
    with tempfile.TemporaryDirectory(prefix="n1i-d8-") as td:
        out_dir = Path(td)
        args = [*command, "--min-api", str(min_api), "--output", str(out_dir), *map(str, inputs)]
        result = subprocess.run(args, capture_output=True, text=True)
        if result.returncode:
            return result
        produced = out_dir / "classes.dex"
        if not produced.is_file():
            return subprocess.CompletedProcess(args, 2, result.stdout, result.stderr + "\nd8 produced no classes.dex")
        output.write_bytes(produced.read_bytes())
        return result


def tool_summary() -> dict[str, str]:
    names = ("java", "javac", "d8", "dx", "dexdump", "clang", "ld.lld", "llvm-objcopy", "gcc", "readelf")
    found = prepare_tool_path(names)
    compiler = find_dex_compiler()
    out = {name: (found[name] or "MISSING") for name in names}
    out["dex_compiler"] = " ".join(compiler[1]) if compiler else "MISSING"
    out["dex_compiler_kind"] = compiler[0] if compiler else "MISSING"
    out["historical_workspace_discovery"] = "NO"
    return out


if __name__ == "__main__":
    summary = tool_summary()
    for key in sorted(summary):
        marker = "".join(ch if ch.isalnum() else "_" for ch in key.upper())
        print(f"N1I_B_TOOL_{marker}={summary[key]}")
