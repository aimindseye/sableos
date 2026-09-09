#!/usr/bin/env python3
"""Read-only Sable M1 engineering-contract and source preflight.

The validator is intentionally stdlib-only, bounded, deterministic and fail-closed
for malformed contracts or present-but-nonconforming SableStart source.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
EXPECTED_MILESTONE = "SABLE_M1"
EXPECTED_COMPONENT = "SableStart"


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


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        obj = json.load(f)
    if not isinstance(obj, dict):
        raise ValueError("top-level JSON must be an object")
    return obj


def require_keys(obj: dict, keys: Iterable[str], where: str) -> None:
    missing = [k for k in keys if k not in obj]
    if missing:
        raise ValueError(f"{where}: missing keys: {', '.join(missing)}")


def validate_contract(contract: dict, result: Result) -> None:
    require_keys(
        contract,
        [
            "schema_version", "milestone", "component", "target_device",
            "source_root", "product_stage", "renderer_policy",
            "launcher3_fallback_required", "privilege_policy", "source_policy",
            "concurrency_policy", "data_policy", "rust_policy",
            "performance_policy", "supply_chain_policy", "test_policy",
        ],
        "contract",
    )
    if contract["schema_version"] != 1:
        raise ValueError("unsupported schema_version")
    if contract["milestone"] != EXPECTED_MILESTONE:
        raise ValueError("unexpected milestone")
    if contract["component"] != EXPECTED_COMPONENT:
        raise ValueError("unexpected component")
    if contract["target_device"] != "panther":
        raise ValueError("M1 target_device must be panther")
    source_root = contract["source_root"]
    if not isinstance(source_root, str) or not source_root or source_root.startswith("/"):
        raise ValueError("source_root must be a non-empty relative path")
    if ".." in Path(source_root).parts:
        raise ValueError("source_root may not contain '..'")
    if contract["renderer_policy"] != "QUALIFY_BEFORE_BINDING":
        raise ValueError("renderer must remain unbound at this gate")
    if contract["launcher3_fallback_required"] is not True:
        raise ValueError("Launcher3 fallback must remain required")

    priv = contract["privilege_policy"]
    require_keys(
        priv,
        [
            "allowed_permissions", "forbidden_permissions",
            "allow_exported_activity_count", "allow_exported_service_count",
            "allow_exported_receiver_count", "allow_exported_provider_count",
            "require_home_category_on_exported_activity", "allow_backup",
            "allow_cleartext_traffic", "allow_persistent_process",
            "allow_shared_user_id",
        ],
        "privilege_policy",
    )
    allowed = priv["allowed_permissions"]
    forbidden = priv["forbidden_permissions"]
    if not isinstance(allowed, list) or not all(isinstance(x, str) for x in allowed):
        raise ValueError("allowed_permissions must be a list of strings")
    if not isinstance(forbidden, list) or not all(isinstance(x, str) for x in forbidden):
        raise ValueError("forbidden_permissions must be a list of strings")
    overlap = sorted(set(allowed) & set(forbidden))
    if overlap:
        raise ValueError(f"permission allow/deny overlap: {overlap}")
    if "android.permission.INTERNET" not in forbidden:
        raise ValueError("M1 must explicitly forbid INTERNET")
    if priv["allow_backup"] is not False or priv["allow_cleartext_traffic"] is not False:
        raise ValueError("M1 must disable backup and cleartext traffic")

    source = contract["source_policy"]
    require_keys(
        source,
        [
            "max_files", "max_total_text_bytes", "max_individual_text_bytes",
            "scan_extensions", "excluded_path_fragments", "prohibited_fragments",
            "unsafe_rust_allowed_path_prefixes",
        ],
        "source_policy",
    )
    for key in ("max_files", "max_total_text_bytes", "max_individual_text_bytes"):
        if not isinstance(source[key], int) or source[key] <= 0:
            raise ValueError(f"{key} must be a positive integer")
    if source["max_files"] > 10000:
        raise ValueError("max_files is too broad for a bounded preflight")
    if source["max_total_text_bytes"] > 100 * 1024 * 1024:
        raise ValueError("max_total_text_bytes is too broad")
    if source["max_individual_text_bytes"] > 4 * 1024 * 1024:
        raise ValueError("max_individual_text_bytes is too broad")

    perf = contract["performance_policy"]
    require_keys(
        perf,
        [
            "measurement", "startup_hot_target_ms", "startup_warm_target_ms",
            "frame_deadline_p95_target", "p99_tracking",
            "startup_critical_path_network", "startup_critical_path_disk_io",
            "startup_critical_path_binder", "idle_cpu_regression", "rss_regression",
        ],
        "performance_policy",
    )
    if perf["startup_hot_target_ms"] > 150 or perf["startup_warm_target_ms"] > 200:
        raise ValueError("startup targets may not be relaxed above the M1 contract")

    result.passed("M1_ENGINEERING_CONTRACT_SCHEMA=PASS")
    result.passed("M1_RENDERER_PRECOMMIT_GUARD=PASS_UNBOUND")
    result.passed("M1_LAUNCHER3_FALLBACK_POLICY=PASS_REQUIRED")
    result.passed("M1_NETWORK_PERMISSION_POLICY=PASS_INTERNET_FORBIDDEN")
    result.passed("M1_BOUNDED_SCAN_POLICY=PASS")


def ensure_no_symlink_path(root: Path, target: Path) -> None:
    root = root.resolve(strict=True)
    current = root
    rel = target.relative_to(root)
    for part in rel.parts:
        current = current / part
        st = os.lstat(current)
        if stat.S_ISLNK(st.st_mode):
            raise ValueError(f"symlink path component rejected: {current}")


def is_excluded(rel_posix: str, fragments: list[str]) -> bool:
    wrapped = f"/{rel_posix.strip('/')}"
    return any(fragment in wrapped for fragment in fragments)


def bounded_source_files(source_root: Path, policy: dict) -> list[Path]:
    max_files = policy["max_files"]
    max_total = policy["max_total_text_bytes"]
    max_individual = policy["max_individual_text_bytes"]
    extensions = set(policy["scan_extensions"])
    excluded = policy["excluded_path_fragments"]

    files: list[Path] = []
    total = 0
    for dirpath, dirnames, filenames in os.walk(source_root, topdown=True, followlinks=False):
        base = Path(dirpath)
        kept_dirs: list[str] = []
        for name in sorted(dirnames):
            p = base / name
            if p.is_symlink():
                raise ValueError(f"symlink directory rejected: {p}")
            rel = p.relative_to(source_root).as_posix()
            if not is_excluded(rel, excluded):
                kept_dirs.append(name)
        dirnames[:] = kept_dirs

        for name in sorted(filenames):
            p = base / name
            if p.is_symlink():
                raise ValueError(f"symlink file rejected: {p}")
            rel = p.relative_to(source_root).as_posix()
            if is_excluded(rel, excluded) or p.suffix not in extensions:
                continue
            st = p.stat()
            if st.st_size > max_individual:
                raise ValueError(f"oversized text input rejected: {rel}")
            total += st.st_size
            if total > max_total:
                raise ValueError("bounded text-byte limit exceeded")
            files.append(p)
            if len(files) > max_files:
                raise ValueError("bounded file-count limit exceeded")
    return files


def text_without_comments(path: Path, text: str) -> str:
    if path.suffix == ".rs":
        text = re.sub(r"//.*?$", "", text, flags=re.MULTILINE)
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return text


def scan_source(source_root: Path, contract: dict, result: Result) -> None:
    policy = contract["source_policy"]
    files = bounded_source_files(source_root, policy)
    prohibited = policy["prohibited_fragments"]
    unsafe_prefixes = tuple(policy["unsafe_rust_allowed_path_prefixes"])
    unsafe_hits: list[str] = []
    prohibited_hits: list[str] = []

    for path in files:
        rel = path.relative_to(source_root).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError(f"non-UTF8 text input rejected: {rel}") from exc
        for fragment in prohibited:
            if fragment in text:
                prohibited_hits.append(f"{rel}:{fragment}")
        if path.suffix == ".rs":
            check = text_without_comments(path, text)
            if re.search(r"\bunsafe\b", check):
                if not any(rel.startswith(prefix) for prefix in unsafe_prefixes):
                    unsafe_hits.append(rel)

    if prohibited_hits:
        for hit in prohibited_hits[:20]:
            result.block(f"M1_PROHIBITED_SOURCE_FRAGMENT={hit}")
        if len(prohibited_hits) > 20:
            result.block(f"M1_PROHIBITED_SOURCE_FRAGMENT_TRUNCATED={len(prohibited_hits)-20}")
    else:
        result.passed("M1_PROHIBITED_SOURCE_SCAN=PASS_NONE")

    if unsafe_hits:
        for hit in unsafe_hits[:20]:
            result.block(f"M1_UNSAFE_RUST_OUTSIDE_ALLOWLIST={hit}")
        if len(unsafe_hits) > 20:
            result.block(f"M1_UNSAFE_RUST_HIT_TRUNCATED={len(unsafe_hits)-20}")
    else:
        result.passed("M1_UNSAFE_RUST_POLICY=PASS_NO_UNALLOWLISTED_UNSAFE")

    result.note(f"M1_SCANNED_TEXT_FILE_COUNT={len(files)}")


def bool_attr(elem: ET.Element, name: str, default: bool | None = None) -> bool | None:
    raw = elem.get(ANDROID_NS + name)
    if raw is None:
        return default
    if raw == "true":
        return True
    if raw == "false":
        return False
    return None


def validate_manifest(manifest: Path, contract: dict, result: Result) -> None:
    tree = ET.parse(manifest)
    root = tree.getroot()
    if root.tag != "manifest":
        raise ValueError("AndroidManifest.xml root is not <manifest>")
    priv = contract["privilege_policy"]

    if root.get(ANDROID_NS + "sharedUserId") is not None and not priv["allow_shared_user_id"]:
        result.block("M1_MANIFEST_SHARED_USER_ID=FAIL_PRESENT")
    else:
        result.passed("M1_MANIFEST_SHARED_USER_ID=PASS_ABSENT")

    permissions = sorted(
        {
            e.get(ANDROID_NS + "name")
            for e in root.findall("uses-permission")
            if e.get(ANDROID_NS + "name")
        }
    )
    allowed = set(priv["allowed_permissions"])
    forbidden = set(priv["forbidden_permissions"])
    unexpected = [p for p in permissions if p not in allowed]
    explicit_forbidden = [p for p in permissions if p in forbidden]
    if explicit_forbidden:
        result.block("M1_MANIFEST_FORBIDDEN_PERMISSIONS=" + ",".join(explicit_forbidden))
    if unexpected:
        result.block("M1_MANIFEST_UNREVIEWED_PERMISSIONS=" + ",".join(unexpected))
    if not explicit_forbidden and not unexpected:
        result.passed("M1_MANIFEST_PERMISSION_ALLOWLIST=PASS")
    result.note("M1_MANIFEST_PERMISSION_SET=" + (",".join(permissions) if permissions else "NONE"))

    app = root.find("application")
    if app is None:
        raise ValueError("AndroidManifest.xml has no <application>")
    if bool_attr(app, "debuggable", False) is True:
        result.block("M1_MANIFEST_DEBUGGABLE=FAIL_TRUE")
    else:
        result.passed("M1_MANIFEST_DEBUGGABLE=PASS_NOT_TRUE")
    if app.get(ANDROID_NS + "allowBackup") != "false" or priv["allow_backup"] is not False:
        result.block("M1_MANIFEST_ALLOW_BACKUP=FAIL_EXPLICIT_FALSE_REQUIRED")
    else:
        result.passed("M1_MANIFEST_ALLOW_BACKUP=PASS_EXPLICIT_FALSE")
    if app.get(ANDROID_NS + "usesCleartextTraffic") != "false" or priv["allow_cleartext_traffic"] is not False:
        result.block("M1_MANIFEST_CLEARTEXT=FAIL_EXPLICIT_FALSE_REQUIRED")
    else:
        result.passed("M1_MANIFEST_CLEARTEXT=PASS_EXPLICIT_FALSE")
    if bool_attr(app, "persistent", False) is True and not priv["allow_persistent_process"]:
        result.block("M1_MANIFEST_PERSISTENT_PROCESS=FAIL_TRUE")
    else:
        result.passed("M1_MANIFEST_PERSISTENT_PROCESS=PASS_NOT_TRUE")

    limits = {
        "activity": priv["allow_exported_activity_count"],
        "service": priv["allow_exported_service_count"],
        "receiver": priv["allow_exported_receiver_count"],
        "provider": priv["allow_exported_provider_count"],
    }
    exported_activities: list[ET.Element] = []
    for kind, limit in limits.items():
        elems = app.findall(kind) + app.findall(f"activity-alias" if kind == "activity" else "__none__")
        implicit = [e for e in elems if e.get(ANDROID_NS + "exported") is None]
        if implicit:
            result.block(f"M1_{kind.upper()}_EXPORTED_ATTRIBUTE=FAIL_IMPLICIT_{len(implicit)}")
        else:
            result.passed(f"M1_{kind.upper()}_EXPORTED_ATTRIBUTE=PASS_EXPLICIT")
        exported = [e for e in elems if bool_attr(e, "exported", False) is True]
        if kind == "activity":
            exported_activities.extend(exported)
        if len(exported) > limit:
            result.block(f"M1_EXPORTED_{kind.upper()}_COUNT=FAIL_{len(exported)}_GT_{limit}")
        else:
            result.passed(f"M1_EXPORTED_{kind.upper()}_COUNT=PASS_{len(exported)}")

    if priv["require_home_category_on_exported_activity"]:
        if len(exported_activities) != 1:
            result.block("M1_HOME_ACTIVITY_BINDING=FAIL_EXACTLY_ONE_EXPORTED_ACTIVITY_REQUIRED")
        else:
            cats = {
                c.get(ANDROID_NS + "name")
                for f in exported_activities[0].findall("intent-filter")
                for c in f.findall("category")
            }
            actions = {
                a.get(ANDROID_NS + "name")
                for f in exported_activities[0].findall("intent-filter")
                for a in f.findall("action")
            }
            if (
                "android.intent.category.HOME" not in cats
                or "android.intent.category.DEFAULT" not in cats
                or "android.intent.action.MAIN" not in actions
            ):
                result.block("M1_HOME_ACTIVITY_BINDING=FAIL_MAIN_HOME_DEFAULT_FILTER")
            else:
                result.passed("M1_HOME_ACTIVITY_BINDING=PASS_MAIN_HOME_DEFAULT")


def run(repo_root: Path, contract_path: Path) -> tuple[int, dict]:
    result = Result()
    repo_root = repo_root.resolve(strict=True)
    contract_path = contract_path.resolve(strict=True)

    contract = load_json(contract_path)
    validate_contract(contract, result)
    result.note(f"M1_CONTRACT_SHA256={sha256_file(contract_path)}")

    source_root = repo_root / contract["source_root"]
    if not source_root.exists():
        result.note("M1_SOURCE_PRESENT=NO")
        result.passed("M1_SOURCE_ABSENCE=PASS_IMPLEMENTATION_NOT_STARTED")
        readiness = "READY_TO_IMPLEMENT_UNDER_CONTRACT"
    else:
        if not source_root.is_dir():
            result.block("M1_SOURCE_ROOT=FAIL_NOT_DIRECTORY")
            readiness = "BLOCKED"
        else:
            ensure_no_symlink_path(repo_root, source_root)
            result.note("M1_SOURCE_PRESENT=YES")
            result.passed("M1_SOURCE_ROOT_BINDING=PASS")
            scan_source(source_root, contract, result)
            manifest = source_root / "AndroidManifest.xml"
            if not manifest.is_file() or manifest.is_symlink():
                result.block("M1_MANIFEST=FAIL_MISSING_OR_SYMLINK")
            else:
                validate_manifest(manifest, contract, result)
            readiness = "SOURCE_PREFLIGHT_PASS" if not result.blockers else "BLOCKED"

    report = {
        "schema_version": 1,
        "operation": "SABLE_M1_ENGINEERING_PREFLIGHT",
        "passes": result.passes,
        "blockers": result.blockers,
        "info": result.info,
        "readiness": readiness,
        "mutation_actions": 0,
    }
    rc = 0 if not result.blockers else 3
    return rc, report


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--repo-root", required=True, type=Path)
    p.add_argument("--contract", required=True, type=Path)
    p.add_argument("--json-report", type=Path)
    args = p.parse_args()

    print("SOURCE_MUTATION_AUTHORIZED=NO")
    print("WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("AUTHORIZATION_BOUNDARY=PASS_ALL_NO")
    try:
        rc, report = run(args.repo_root, args.contract)
    except Exception as exc:
        print(f"M1_PREFLIGHT_INTERNAL_ERROR={type(exc).__name__}:{exc}")
        print("SABLE_M1_ENGINEERING_PREFLIGHT=FAIL")
        print("SABLE_M1_ENGINEERING_PREFLIGHT_RC=2")
        return 2

    for marker in report["passes"]:
        print(marker)
    for marker in report["info"]:
        print(marker)
    for marker in report["blockers"][:50]:
        print(marker)
    if len(report["blockers"]) > 50:
        print(f"M1_BLOCKER_OUTPUT_TRUNCATED={len(report['blockers']) - 50}")

    print(f"M1_READINESS={report['readiness']}")
    print("M1_MUTATION_ACTIONS=NONE")
    print("SABLE_M1_ENGINEERING_PREFLIGHT=" + ("PASS" if rc == 0 else "FAIL"))
    print(f"SABLE_M1_ENGINEERING_PREFLIGHT_RC={rc}")

    if args.json_report is not None:
        target = args.json_report
        if not target.is_absolute():
            print("M1_JSON_REPORT=FAIL_NOT_ABSOLUTE")
            return 2
        try:
            target.relative_to(Path("/tmp"))
        except ValueError:
            print("M1_JSON_REPORT=FAIL_NOT_TMP")
            return 2
        if not target.parent.is_dir() or target.parent.is_symlink():
            print("M1_JSON_REPORT=FAIL_PARENT")
            return 2
        if target.exists() or target.is_symlink():
            print("M1_JSON_REPORT=FAIL_DESTINATION_EXISTS")
            return 2
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, sort_keys=True)
            f.write("\n")
        print(f"M1_JSON_REPORT={target}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
