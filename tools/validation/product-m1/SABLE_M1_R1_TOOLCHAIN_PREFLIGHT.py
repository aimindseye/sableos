#!/usr/bin/env python3
"""Sable M1-R1 static, read-only toolchain and renderer qualification preflight.

This gate intentionally executes no build tools, performs no network access,
does not import renderer source, and writes only bounded evidence under /tmp.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

EXPECTED_MILESTONE = "SABLE_M1_R1"
EXPECTED_MODE = "STATIC_READ_ONLY_TOOLCHAIN_AND_RENDERER_PREFLIGHT"
EXPECTED_TARGET = "panther"


@dataclass
class Result:
    passes: list[str] = field(default_factory=list)
    blockers: list[str] = field(default_factory=list)
    info: list[str] = field(default_factory=list)

    def passed(self, marker: str) -> None:
        self.passes.append(marker)

    def block(self, marker: str) -> None:
        self.blockers.append(marker)

    def note(self, marker: str) -> None:
        self.info.append(marker)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git_blob_sha1_file(path: Path) -> str:
    data = path.read_bytes()
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    obj = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        raise ValueError(f"{path}: top-level JSON must be an object")
    return obj


def require_keys(obj: dict[str, Any], keys: Iterable[str], where: str) -> None:
    missing = [k for k in keys if k not in obj]
    if missing:
        raise ValueError(f"{where}: missing keys: {', '.join(missing)}")


def is_beneath(child: Path, parent: Path) -> bool:
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


def validated_relative_path(value: str, where: str) -> Path:
    p = Path(value)
    if not value or p.is_absolute() or ".." in p.parts:
        raise ValueError(f"{where}: expected non-empty relative path without '..'")
    return p


def validate_contract(contract: dict[str, Any]) -> None:
    require_keys(
        contract,
        [
            "schema_version",
            "milestone",
            "mode",
            "target_device",
            "workspace_expected",
            "prior_m1_contract",
            "prior_m1_r0_closure",
            "authorization_policy",
            "toolchain",
            "platform_interfaces",
            "renderer_candidates",
            "qualification_policy",
        ],
        "contract",
    )
    if contract["schema_version"] != 1:
        raise ValueError("unsupported schema_version")
    if contract["milestone"] != EXPECTED_MILESTONE:
        raise ValueError("unexpected milestone")
    if contract["mode"] != EXPECTED_MODE:
        raise ValueError("unexpected mode")
    if contract["target_device"] != EXPECTED_TARGET:
        raise ValueError("unexpected target_device")

    workspace_expected = contract["workspace_expected"]
    if not isinstance(workspace_expected, str) or not workspace_expected.startswith("/"):
        raise ValueError("workspace_expected must be an absolute path")

    for key in ("prior_m1_contract", "prior_m1_r0_closure"):
        spec = contract[key]
        require_keys(spec, ["path", "git_blob_sha1"], key)
        validated_relative_path(spec["path"], f"{key}.path")
        blob = spec["git_blob_sha1"]
        if not isinstance(blob, str) or len(blob) != 40 or any(c not in "0123456789abcdef" for c in blob):
            raise ValueError(f"{key}.git_blob_sha1 must be lowercase SHA-1")

    auth = contract["authorization_policy"]
    require_keys(auth, ["required_no"], "authorization_policy")
    required_no = auth["required_no"]
    if not isinstance(required_no, list) or not required_no or not all(isinstance(x, str) for x in required_no):
        raise ValueError("authorization_policy.required_no must be a non-empty list of strings")
    if len(required_no) != len(set(required_no)):
        raise ValueError("authorization_policy.required_no contains duplicates")

    tool = contract["toolchain"]
    require_keys(
        tool,
        [
            "rust_root",
            "rust_current",
            "required_rust_binaries",
            "clang_root",
            "clang_stable",
            "required_clang_binaries",
            "soong_ui",
            "jdk21_java",
            "ninja",
        ],
        "toolchain",
    )
    for key in ("rust_root", "rust_current", "clang_root", "clang_stable", "soong_ui", "jdk21_java", "ninja"):
        validated_relative_path(tool[key], f"toolchain.{key}")
    for key in ("required_rust_binaries", "required_clang_binaries"):
        value = tool[key]
        if not isinstance(value, list) or not value or not all(isinstance(x, str) and "/" not in x for x in value):
            raise ValueError(f"toolchain.{key} must be a non-empty basename list")

    platform = contract["platform_interfaces"]
    require_keys(platform, ["required_any_groups"], "platform_interfaces")
    groups = platform["required_any_groups"]
    if not isinstance(groups, list) or not groups:
        raise ValueError("platform_interfaces.required_any_groups must be non-empty")
    names: set[str] = set()
    for index, group in enumerate(groups):
        require_keys(group, ["name", "paths"], f"platform group {index}")
        name = group["name"]
        paths = group["paths"]
        if not isinstance(name, str) or not name or name in names:
            raise ValueError("platform group names must be unique non-empty strings")
        names.add(name)
        if not isinstance(paths, list) or not paths:
            raise ValueError(f"platform group {name} must have paths")
        for p in paths:
            validated_relative_path(p, f"platform group {name}")

    candidates = contract["renderer_candidates"]
    if not isinstance(candidates, list) or not candidates:
        raise ValueError("renderer_candidates must be non-empty")
    ids: set[str] = set()
    for index, candidate in enumerate(candidates):
        require_keys(candidate, ["id", "display_name", "local_source_paths"], f"renderer candidate {index}")
        cid = candidate["id"]
        if not isinstance(cid, str) or not cid or cid in ids:
            raise ValueError("renderer candidate IDs must be unique non-empty strings")
        ids.add(cid)
        paths = candidate["local_source_paths"]
        if not isinstance(paths, list) or not all(isinstance(x, str) for x in paths):
            raise ValueError(f"renderer candidate {cid}: local_source_paths must be a list")
        for p in paths:
            validated_relative_path(p, f"renderer candidate {cid}")

    qualification = contract["qualification_policy"]
    require_keys(
        qualification,
        [
            "renderer_selection_at_static_gate",
            "network_fetch",
            "source_import",
            "build_execution",
            "device_execution",
            "missing_renderer_source_is_blocker",
            "required_next_phase_evidence",
        ],
        "qualification_policy",
    )
    if qualification["renderer_selection_at_static_gate"] != "FORBIDDEN":
        raise ValueError("renderer selection must be forbidden at M1-R1 static gate")
    for key in ("network_fetch", "source_import", "build_execution", "device_execution"):
        if qualification[key] != "FORBIDDEN":
            raise ValueError(f"qualification_policy.{key} must be FORBIDDEN")
    if qualification["missing_renderer_source_is_blocker"] is not False:
        raise ValueError("missing renderer source must remain non-blocking at this static gate")


def validate_authorization(contract: dict[str, Any], result: Result) -> None:
    for name in contract["authorization_policy"]["required_no"]:
        value = os.environ.get(name, "NO")
        result.note(f"{name}={value}")
        if value != "NO":
            result.block(f"AUTHORIZATION_BOUNDARY=FAIL:{name}")
    if not result.blockers:
        result.passed("AUTHORIZATION_BOUNDARY=PASS_ALL_NO")


def validate_repo_binding(repo_root: Path, contract: dict[str, Any], result: Result) -> None:
    if not repo_root.is_absolute():
        raise ValueError("repo_root must be absolute")
    if not repo_root.exists() or not repo_root.is_dir():
        result.block("M1_R1_REPO_ROOT=FAIL_NOT_DIRECTORY")
        return
    if repo_root.is_symlink():
        result.block("M1_R1_REPO_ROOT=FAIL_SYMLINK")
        return
    real_root = repo_root.resolve(strict=True)

    for label, key in (
        ("M1_R0_CONTRACT", "prior_m1_contract"),
        ("M1_R0_CLOSURE", "prior_m1_r0_closure"),
    ):
        spec = contract[key]
        rel = validated_relative_path(spec["path"], f"{key}.path")
        path = real_root / rel
        if not path.exists() or not path.is_file() or path.is_symlink():
            result.block(f"{label}_BINDING=FAIL_FILE")
            continue
        resolved = path.resolve(strict=True)
        if not is_beneath(resolved, real_root):
            result.block(f"{label}_BINDING=FAIL_PATH_ESCAPE")
            continue
        actual = git_blob_sha1_file(resolved)
        result.note(f"{label}_GIT_BLOB={actual}")
        if actual != spec["git_blob_sha1"]:
            result.block(f"{label}_BINDING=FAIL_GIT_BLOB")
        else:
            result.passed(f"{label}_BINDING=PASS")


def resolve_in_workspace(workspace: Path, relative: str) -> tuple[Path, Path]:
    rel = validated_relative_path(relative, "workspace relative path")
    lexical = workspace / rel
    if not lexical.exists() and not lexical.is_symlink():
        raise FileNotFoundError(str(lexical))
    resolved = lexical.resolve(strict=True)
    workspace_real = workspace.resolve(strict=True)
    if not is_beneath(resolved, workspace_real):
        raise ValueError(f"path escapes workspace: {lexical} -> {resolved}")
    return lexical, resolved


def file_record(workspace: Path, relative: str, *, require_executable: bool) -> dict[str, Any]:
    lexical, resolved = resolve_in_workspace(workspace, relative)
    st = resolved.stat()
    if not stat.S_ISREG(st.st_mode):
        raise ValueError(f"not a regular file: {lexical}")
    executable = bool(st.st_mode & 0o111)
    if require_executable and not executable:
        raise PermissionError(f"not executable: {lexical}")
    return {
        "relative_path": relative,
        "lexical_path": str(lexical),
        "resolved_path": str(resolved),
        "is_symlink": lexical.is_symlink(),
        "size_bytes": st.st_size,
        "executable": executable,
        "sha256": sha256_file(resolved),
    }


def directory_record(workspace: Path, relative: str) -> dict[str, Any]:
    lexical, resolved = resolve_in_workspace(workspace, relative)
    if not resolved.is_dir():
        raise ValueError(f"not a directory: {lexical}")
    return {
        "relative_path": relative,
        "lexical_path": str(lexical),
        "resolved_path": str(resolved),
        "is_symlink": lexical.is_symlink(),
    }


def version_hint_from_tool_path(record: dict[str, Any], anchor: str) -> str:
    resolved = Path(record["resolved_path"])
    parts = resolved.parts
    try:
        anchor_index = parts.index(anchor)
    except ValueError:
        return "UNRESOLVED_STATICALLY"
    if anchor == "linux-x86":
        tail = parts[anchor_index + 1 :]
        if len(tail) >= 2:
            return tail[0]
    return "UNRESOLVED_STATICALLY"


def inspect_toolchain(workspace: Path, contract: dict[str, Any], result: Result) -> dict[str, Any]:
    tool = contract["toolchain"]
    inventory: dict[str, Any] = {}

    try:
        rust_root = directory_record(workspace, tool["rust_root"])
        inventory["rust_root"] = rust_root
        result.passed("M1_R1_RUST_ROOT=PASS")
    except Exception as exc:
        result.block(f"M1_R1_RUST_ROOT=FAIL:{type(exc).__name__}")
        return inventory

    try:
        rust_current = directory_record(workspace, tool["rust_current"])
        inventory["rust_current"] = rust_current
        result.note(f"RUST_CURRENT_RESOLVED_PATH={rust_current['resolved_path']}")
        result.passed("M1_R1_RUST_CURRENT_BINDING=PASS")
    except Exception as exc:
        result.block(f"M1_R1_RUST_CURRENT_BINDING=FAIL:{type(exc).__name__}")
        rust_current = None

    rust_bins: dict[str, Any] = {}
    if rust_current is not None:
        current_rel = Path(tool["rust_current"])
        for name in tool["required_rust_binaries"]:
            rel = (current_rel / "bin" / name).as_posix()
            try:
                rec = file_record(workspace, rel, require_executable=True)
                rust_bins[name] = rec
                result.note(f"RUST_{name.upper().replace('-', '_')}_SHA256={rec['sha256']}")
                result.passed(f"M1_R1_RUST_{name.upper().replace('-', '_')}_BINDING=PASS")
            except Exception as exc:
                result.block(f"M1_R1_RUST_{name.upper().replace('-', '_')}_BINDING=FAIL:{type(exc).__name__}")
    inventory["rust_binaries"] = rust_bins
    if "rustc" in rust_bins:
        inventory["rust_version_hint"] = version_hint_from_tool_path(rust_bins["rustc"], "linux-x86")
        result.note(f"RUST_TOOLCHAIN_VERSION_HINT={inventory['rust_version_hint']}")

    try:
        clang_root = directory_record(workspace, tool["clang_root"])
        inventory["clang_root"] = clang_root
        result.passed("M1_R1_CLANG_ROOT=PASS")
    except Exception as exc:
        result.block(f"M1_R1_CLANG_ROOT=FAIL:{type(exc).__name__}")
        return inventory

    try:
        clang_stable = directory_record(workspace, tool["clang_stable"])
        inventory["clang_stable"] = clang_stable
        result.note(f"CLANG_STABLE_RESOLVED_PATH={clang_stable['resolved_path']}")
        result.passed("M1_R1_CLANG_STABLE_BINDING=PASS")
    except Exception as exc:
        result.block(f"M1_R1_CLANG_STABLE_BINDING=FAIL:{type(exc).__name__}")
        clang_stable = None

    clang_bins: dict[str, Any] = {}
    if clang_stable is not None:
        stable_rel = Path(tool["clang_stable"])
        for name in tool["required_clang_binaries"]:
            rel = (stable_rel / "bin" / name).as_posix()
            try:
                rec = file_record(workspace, rel, require_executable=True)
                clang_bins[name] = rec
                key = name.replace("+", "X").replace("-", "_").upper()
                result.note(f"CLANG_{key}_SHA256={rec['sha256']}")
                result.passed(f"M1_R1_CLANG_{key}_BINDING=PASS")
            except Exception as exc:
                key = name.replace("+", "X").replace("-", "_").upper()
                result.block(f"M1_R1_CLANG_{key}_BINDING=FAIL:{type(exc).__name__}")
    inventory["clang_binaries"] = clang_bins
    if "clang" in clang_bins:
        inventory["clang_version_hint"] = version_hint_from_tool_path(clang_bins["clang"], "linux-x86")
        result.note(f"CLANG_TOOLCHAIN_VERSION_HINT={inventory['clang_version_hint']}")

    for key, marker in (
        ("soong_ui", "SOONG_UI"),
        ("jdk21_java", "JDK21_JAVA"),
        ("ninja", "NINJA"),
    ):
        try:
            rec = file_record(workspace, tool[key], require_executable=True)
            inventory[key] = rec
            result.note(f"{marker}_SHA256={rec['sha256']}")
            result.passed(f"M1_R1_{marker}_BINDING=PASS")
        except Exception as exc:
            result.block(f"M1_R1_{marker}_BINDING=FAIL:{type(exc).__name__}")

    return inventory


def inspect_platform_interfaces(workspace: Path, contract: dict[str, Any], result: Result) -> dict[str, Any]:
    found: dict[str, Any] = {}
    for group in contract["platform_interfaces"]["required_any_groups"]:
        name = group["name"]
        hits: list[dict[str, Any]] = []
        for rel in group["paths"]:
            try:
                rec = file_record(workspace, rel, require_executable=False)
            except FileNotFoundError:
                continue
            except Exception as exc:
                result.block(f"M1_R1_PLATFORM_{name}=FAIL:{type(exc).__name__}")
                hits = []
                break
            hits.append(rec)
        if hits:
            found[name] = hits
            result.note(f"PLATFORM_{name}_PATH={hits[0]['relative_path']}")
            result.note(f"PLATFORM_{name}_SHA256={hits[0]['sha256']}")
            result.passed(f"M1_R1_PLATFORM_{name}=PASS")
        elif not any(b.startswith(f"M1_R1_PLATFORM_{name}=FAIL") for b in result.blockers):
            result.block(f"M1_R1_PLATFORM_{name}=FAIL_MISSING")
    return found


def inspect_renderer_candidates(workspace: Path, contract: dict[str, Any], result: Result) -> list[dict[str, Any]]:
    candidates_out: list[dict[str, Any]] = []
    missing_is_blocker = contract["qualification_policy"]["missing_renderer_source_is_blocker"]

    for candidate in contract["renderer_candidates"]:
        cid = candidate["id"]
        display = candidate["display_name"]
        hits: list[dict[str, Any]] = []
        path_errors: list[str] = []

        for rel in candidate["local_source_paths"]:
            lexical = workspace / validated_relative_path(rel, f"renderer candidate {cid}")
            if not lexical.exists() and not lexical.is_symlink():
                continue
            try:
                rec = directory_record(workspace, rel)
                hits.append(rec)
            except Exception as exc:
                path_errors.append(f"{rel}:{type(exc).__name__}")

        if path_errors:
            classification = "BLOCKED_LOCAL_SOURCE_PATH_ERROR"
            result.block(f"M1_R1_RENDERER_{cid.upper()}=FAIL_LOCAL_SOURCE_PATH")
        elif hits:
            classification = "LOCAL_SOURCE_PRESENT_REQUIRES_BUILD_QUALIFICATION"
            result.passed(f"M1_R1_RENDERER_{cid.upper()}_LOCAL_SOURCE=PASS_PRESENT")
        elif candidate["local_source_paths"]:
            classification = "LOCAL_SOURCE_NOT_PRESENT_IMPORT_REVIEW_REQUIRED"
            marker = f"M1_R1_RENDERER_{cid.upper()}_LOCAL_SOURCE=INFO_ABSENT"
            if missing_is_blocker:
                result.block(marker.replace("INFO_", "FAIL_"))
            else:
                result.note(marker)
        else:
            classification = "DESIGN_OPTION_ONLY_NO_PRECOMMITTED_SOURCE"
            result.note(f"M1_R1_RENDERER_{cid.upper()}=INFO_DESIGN_OPTION_ONLY")

        candidates_out.append(
            {
                "id": cid,
                "display_name": display,
                "classification": classification,
                "local_source_hits": hits,
                "path_errors": path_errors,
            }
        )

    result.passed("M1_R1_RENDERER_SELECTION=PASS_NOT_SELECTED")
    return candidates_out


def validate_workspace(workspace: Path, expected: str, result: Result, *, enforce_exact_path: bool = True) -> Path | None:
    if not workspace.is_absolute():
        result.block("M1_R1_WORKSPACE=FAIL_NOT_ABSOLUTE")
        return None
    if enforce_exact_path and str(workspace) != expected:
        result.block("M1_R1_WORKSPACE=FAIL_UNEXPECTED_PATH")
        return None
    if not workspace.exists() or not workspace.is_dir():
        result.block("M1_R1_WORKSPACE=FAIL_NOT_DIRECTORY")
        return None
    if workspace.is_symlink():
        result.block("M1_R1_WORKSPACE=FAIL_SYMLINK")
        return None
    real = workspace.resolve(strict=True)
    if real != workspace:
        result.block("M1_R1_WORKSPACE=FAIL_NONCANONICAL")
        return None
    manifest = workspace / ".repo" / "manifest.xml"
    if not manifest.exists() or not manifest.is_file():
        result.block("M1_R1_WORKSPACE=FAIL_NO_REPO_MANIFEST")
        return None
    result.note(f"WORKSPACE_MANIFEST_SHA256={sha256_file(manifest)}")
    result.passed("M1_R1_WORKSPACE_BINDING=PASS")
    return real


def make_evidence_dir(explicit: str | None) -> Path:
    tmp_root = Path("/tmp").resolve(strict=True)
    if explicit is None:
        path = Path(tempfile.mkdtemp(prefix="SABLE_M1_R1_TOOLCHAIN_PREFLIGHT_", dir="/tmp"))
        os.chmod(path, 0o700)
        return path

    path = Path(explicit)
    if not path.is_absolute():
        raise ValueError("evidence directory must be absolute")
    if path.exists() or path.is_symlink():
        raise ValueError("evidence directory must not already exist")
    parent = path.parent.resolve(strict=True)
    if parent != tmp_root:
        raise ValueError("evidence directory must be a direct child of /tmp")
    path.mkdir(mode=0o700)
    return path


def write_evidence(path: Path, payload: dict[str, Any]) -> Path:
    report = path / "report.json"
    fd = os.open(report, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        data = (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode("utf-8")
        view = memoryview(data)
        while view:
            n = os.write(fd, view)
            if n <= 0:
                raise OSError("short evidence write")
            view = view[n:]
        os.fsync(fd)
    finally:
        os.close(fd)
    dir_fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(dir_fd)
    finally:
        os.close(dir_fd)
    return report


def default_repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def run_preflight(
    *,
    repo_root: Path,
    workspace: Path,
    contract_path: Path,
    evidence_dir: str | None,
    enforce_exact_workspace_path: bool = True,
) -> tuple[int, dict[str, Any], Path]:
    result = Result()
    contract = load_json(contract_path)
    validate_contract(contract)
    validate_authorization(contract, result)

    contract_sha256 = sha256_file(contract_path)
    result.note(f"M1_R1_CONTRACT_SHA256={contract_sha256}")
    result.note(f"M1_R1_SCRIPT_SHA256={sha256_file(Path(__file__).resolve())}")

    validate_repo_binding(repo_root, contract, result)
    workspace_real = validate_workspace(
        workspace,
        contract["workspace_expected"],
        result,
        enforce_exact_path=enforce_exact_workspace_path,
    )

    toolchain: dict[str, Any] = {}
    platform: dict[str, Any] = {}
    renderers: list[dict[str, Any]] = []

    if workspace_real is not None and not result.blockers:
        toolchain = inspect_toolchain(workspace_real, contract, result)
        platform = inspect_platform_interfaces(workspace_real, contract, result)
        renderers = inspect_renderer_candidates(workspace_real, contract, result)

    if result.blockers:
        readiness = "BLOCKED_STATIC_PREFLIGHT"
        rc = 3
    else:
        readiness = "READY_FOR_RENDERER_IMPORT_AND_BUILD_QUALIFICATION_PLAN"
        rc = 0
        result.passed("SABLE_M1_R1_STATIC_TOOLCHAIN_PREFLIGHT=PASS")
        result.passed("M1_R1_READINESS=READY_FOR_RENDERER_IMPORT_AND_BUILD_QUALIFICATION_PLAN")

    evidence = make_evidence_dir(evidence_dir)
    payload = {
        "schema_version": 1,
        "operation": "SABLE_M1_R1_STATIC_TOOLCHAIN_AND_RENDERER_PREFLIGHT",
        "contract_sha256": contract_sha256,
        "repo_root": str(repo_root),
        "workspace": str(workspace),
        "passes": result.passes,
        "blockers": result.blockers,
        "info": result.info,
        "toolchain": toolchain,
        "platform_interfaces": platform,
        "renderer_candidates": renderers,
        "renderer_selected": None,
        "network_actions": 0,
        "source_import_actions": 0,
        "source_mutation_actions": 0,
        "workspace_output_mutation_actions": 0,
        "build_actions": 0,
        "build_tool_execution_actions": 0,
        "device_actions": 0,
        "readiness": readiness,
        "rc": rc,
    }
    report = write_evidence(evidence, payload)

    for marker in result.info:
        print(marker)
    for marker in result.passes:
        print(marker)
    for marker in result.blockers:
        print(marker)

    print(f"PASS={len(result.passes)}")
    print(f"BLOCKER={len(result.blockers)}")
    print(f"INFO={len(result.info)}")
    print("RENDERER_SELECTED=NONE")
    print("NETWORK_ACTIONS=NONE")
    print("SOURCE_IMPORT_ACTIONS=NONE")
    print("SOURCE_MUTATION_ACTIONS=NONE")
    print("WORKSPACE_OUTPUT_MUTATION_ACTIONS=NONE")
    print("BUILD_ACTIONS=NONE")
    print("BUILD_TOOL_EXECUTION_ACTIONS=NONE")
    print("DEVICE_ACTIONS=NONE")
    print(f"M1_R1_READINESS={readiness}")
    print(f"REPORT_SHA256={sha256_file(report)}")
    print(f"EVIDENCE_DIR={evidence}")
    print(f"SABLE_M1_R1_RC={rc}")

    return rc, payload, evidence


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root",
        default=str(default_repo_root()),
        help="SableOS tools/documentation repository root",
    )
    parser.add_argument(
        "--workspace",
        default="/srv/data/sableos_panther_graphene_2026081300_workspace",
        help="canonical Panther Android workspace",
    )
    parser.add_argument(
        "--contract",
        default=None,
        help="M1-R1 contract path; defaults under repo root",
    )
    parser.add_argument(
        "--evidence-dir",
        default=None,
        help="optional nonexistent direct child of /tmp",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = Path(args.repo_root)
    contract_path = (
        Path(args.contract)
        if args.contract is not None
        else repo_root / "product/m1/sable-m1-r1-toolchain-contract-v1.json"
    )
    try:
        rc, _, _ = run_preflight(
            repo_root=repo_root,
            workspace=Path(args.workspace),
            contract_path=contract_path,
            evidence_dir=args.evidence_dir,
            enforce_exact_workspace_path=True,
        )
        return rc
    except Exception as exc:
        print(f"SABLE_M1_R1_PREFLIGHT_ERROR={type(exc).__name__}:{exc}")
        print("NETWORK_ACTIONS=NONE")
        print("SOURCE_IMPORT_ACTIONS=NONE")
        print("SOURCE_MUTATION_ACTIONS=NONE")
        print("WORKSPACE_OUTPUT_MUTATION_ACTIONS=NONE")
        print("BUILD_ACTIONS=NONE")
        print("BUILD_TOOL_EXECUTION_ACTIONS=NONE")
        print("DEVICE_ACTIONS=NONE")
        print("SABLE_M1_R1_RC=4")
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
