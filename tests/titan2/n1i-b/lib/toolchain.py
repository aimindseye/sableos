#!/usr/bin/env python3
"""Deterministic offline host-tool discovery for N1I-B synthetic fixture tests.

No network, package installation, source mutation or device contact. Search order:
1. explicit N1I_TOOL_<NAME> environment override;
2. current PATH;
3. Debian/Android SDK build-tools locations;
4. known N1I_AOSP_ROOT / canonical Titan Android workspaces;
5. AOSP out/host and clang-stable prebuilts.

DEX fixture compilation prefers legacy dx when available, otherwise modern d8.
AOSP prebuilts/r8/{d8,r8}.jar are accepted through the local Java runtime.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Iterable

CANONICAL_AOSP_ROOTS = (
    Path("/srv/sable-build/workspaces/titan2-n1d-c3b/android"),
    Path("/srv/sable-build/workspaces/titan2-n1d/android"),
    Path("/srv/data/sable-build/workspaces/titan2-n1d-c3b/android"),
    Path("/srv/data/sable-build/workspaces/titan2-n1d/android"),
)


def _env_key(name: str) -> str:
    return "N1I_TOOL_" + "".join(c if c.isalnum() else "_" for c in name.upper())


def aosp_roots() -> list[Path]:
    roots: list[Path] = []
    explicit = os.environ.get("N1I_AOSP_ROOT", "").strip()
    if explicit:
        roots.append(Path(explicit))
    roots.extend(CANONICAL_AOSP_ROOTS)
    out: list[Path] = []
    seen: set[str] = set()
    for root in roots:
        key = str(root)
        if key not in seen and root.is_dir():
            seen.add(key)
            out.append(root)
    return out


def _sdk_candidates(name: str) -> list[Path]:
    out = [Path("/usr/lib/android-sdk/build-tools/debian") / name]
    for env in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        root = os.environ.get(env, "").strip()
        if root:
            out.extend(sorted((Path(root) / "build-tools").glob(f"*/{name}"), reverse=True))
    out.extend(sorted(Path("/usr/lib/android-sdk/build-tools").glob(f"*/{name}"), reverse=True))
    return out


def _aosp_candidates(name: str) -> list[Path]:
    out: list[Path] = []
    for root in aosp_roots():
        out += [
            root / "out/host/linux-x86/bin" / name,
            root / "prebuilts/clang/host/linux-x86/clang-stable/bin" / name,
            root / "prebuilts/build-tools/linux-x86/bin" / name,
        ]
        clang_root = root / "prebuilts/clang/host/linux-x86"
        out.extend(sorted(clang_root.glob(f"clang-r*/bin/{name}"), reverse=True))
    return out


def find_tool(name: str) -> str | None:
    override = os.environ.get(_env_key(name), "").strip()
    if override:
        p = Path(override)
        return str(p) if p.is_file() and os.access(p, os.X_OK) else None
    hit = shutil.which(name)
    if hit:
        return hit
    for p in _sdk_candidates(name) + _aosp_candidates(name):
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
    java = find_tool("java")
    if not java:
        return None
    for root in aosp_roots():
        for jar in (root / "prebuilts/r8/d8.jar", root / "prebuilts/r8/r8.jar"):
            if jar.is_file():
                return "d8", [java, "-cp", str(jar), "com.android.tools.r8.D8"]
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
    out["aosp_roots"] = ",".join(map(str, aosp_roots())) or "NONE"
    return out
