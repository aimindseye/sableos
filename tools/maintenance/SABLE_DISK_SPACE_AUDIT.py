#!/usr/bin/env python3
"""Read-only, bounded disk-space inventory for the SableOS ThinkPad workspace.

No files or directories are deleted, truncated, moved, compressed, or cleaned.
The script measures only an explicit allowlist of known paths plus Sable/Panther
evidence directories directly under /tmp.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

DEFAULT_WORKSPACE = Path("/srv/data/sableos_panther_graphene_2026081300_workspace")
DEFAULT_REPO = Path("/home/mindseye73/sableos-tools")
MAX_TMP_ENTRIES = 2000


@dataclass(frozen=True)
class Item:
    path: str
    exists: bool
    bytes: int | None
    disposition: str
    rationale: str


def human(n: int | None) -> str:
    if n is None:
        return "UNKNOWN"
    value = float(n)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if value < 1024 or unit == "TiB":
            return f"{value:.2f} {unit}"
        value /= 1024
    return f"{n} B"


def du_bytes(path: Path) -> int | None:
    if not path.exists():
        return None
    cp = subprocess.run(
        ["du", "-sx", "--block-size=1", "--", str(path)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if cp.returncode != 0:
        return None
    first = cp.stdout.splitlines()[0].split("\t", 1)[0].strip()
    return int(first)


def filesystem_info(path: Path) -> dict[str, int | str]:
    probe = path
    while not probe.exists() and probe != probe.parent:
        probe = probe.parent
    usage = shutil.disk_usage(probe)
    return {
        "probe": str(probe),
        "total_bytes": usage.total,
        "used_bytes": usage.used,
        "free_bytes": usage.free,
    }


def known_items(workspace: Path, repo: Path, home: Path) -> list[tuple[Path, str, str]]:
    return [
        (workspace / "out_d4_b2_final", "KEEP", "Canonical D4/B2 build output; retain until production release artifacts replace it."),
        (workspace / "out_graphene_control", "REVIEW_RECLAIM", "B1 Graphene control output; historical comparison population, potentially reclaimable after explicit deletion authorization."),
        (workspace / "out_c2r32_sable_fresh", "REVIEW_RECLAIM", "C2 comparison output; historical comparison population, potentially reclaimable after explicit deletion authorization."),
        (workspace, "KEEP_SOURCE_WORKSPACE", "Canonical GrapheneOS 2026081300 SableOS Android workspace."),
        (Path("/srv/data/aosp_panther17_workspace"), "REVIEW_RECLAIM_HIGH_VALUE", "Historical pure-AOSP Panther workspace; non-canonical for current SableOS, but delete only after explicit review."),
        (Path("/srv/data/aosp_bramble_workspace"), "DO_NOT_TOUCH_OTHER_DEVICE", "Separate Bramble workspace; outside Panther cleanup scope."),
        (repo, "KEEP_REPOSITORY", "Canonical SableOS tools/evidence repository checkout."),
        (home / ".ccache", "REVIEW_CACHE", "Compiler cache; rebuildable, often a useful reclaim target after size review."),
        (home / ".cache", "REVIEW_CACHE_BROAD", "Broad user cache; report only because it may contain unrelated applications."),
    ]


def target_files(workspace: Path) -> list[tuple[Path, str]]:
    return [
        (workspace / "out_graphene_control/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target_files.zip", "B1"),
        (workspace / "out_d4_b2_final/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target_files.zip", "B2_CANONICAL"),
        (workspace / "out_c2r32_sable_fresh/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target_files.zip", "C2"),
    ]


def tmp_evidence_dirs(tmp_root: Path) -> list[Path]:
    prefixes = ("SABLE_", "PANTHER_")
    result: list[Path] = []
    try:
        for i, entry in enumerate(tmp_root.iterdir()):
            if i >= MAX_TMP_ENTRIES:
                break
            if entry.is_dir() and entry.name.startswith(prefixes):
                result.append(entry)
    except FileNotFoundError:
        pass
    return sorted(result)


def sha256_file(path: Path, chunk: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            data = f.read(chunk)
            if not data:
                return h.hexdigest()
            h.update(data)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Read-only bounded SableOS disk-space audit")
    p.add_argument("--workspace", type=Path, default=DEFAULT_WORKSPACE)
    p.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    p.add_argument("--home", type=Path, default=Path.home())
    p.add_argument("--tmp-root", type=Path, default=Path("/tmp"))
    p.add_argument("--evidence-root", type=Path, default=Path("/tmp"))
    p.add_argument("--hash-target-files", action="store_true", help="Recompute target-files SHA-256; expensive for multi-GB archives")
    ns = p.parse_args(argv)

    workspace = ns.workspace.resolve()
    repo = ns.repo.resolve()
    home = ns.home.resolve()

    fs = {
        "workspace_filesystem": filesystem_info(workspace),
        "home_filesystem": filesystem_info(home),
        "tmp_filesystem": filesystem_info(ns.tmp_root),
    }

    items: list[Item] = []
    for path, disposition, rationale in known_items(workspace, repo, home):
        size = du_bytes(path)
        items.append(Item(str(path), path.exists(), size, disposition, rationale))

    tf: list[dict[str, object]] = []
    for path, role in target_files(workspace):
        row: dict[str, object] = {
            "role": role,
            "path": str(path),
            "exists": path.is_file(),
            "bytes": path.stat().st_size if path.is_file() else None,
        }
        if ns.hash_target_files and path.is_file():
            row["sha256"] = sha256_file(path)
        tf.append(row)

    tmp_rows: list[dict[str, object]] = []
    for path in tmp_evidence_dirs(ns.tmp_root):
        tmp_rows.append({"path": str(path), "bytes": du_bytes(path)})
    tmp_rows.sort(key=lambda x: (x["bytes"] is not None, x["bytes"] or -1), reverse=True)

    payload = {
        "mode": "READ_ONLY_NO_DELETE",
        "workspace": str(workspace),
        "filesystems": fs,
        "items": [asdict(x) for x in items],
        "target_files": tf,
        "tmp_evidence": {
            "count": len(tmp_rows),
            "total_bytes": sum(int(x["bytes"] or 0) for x in tmp_rows),
            "largest_25": tmp_rows[:25],
        },
        "cleanup_policy": {
            "automatic_deletion": False,
            "next_step": "Review measured sizes and issue a separate exact-path deletion authorization only for selected reclaim candidates.",
            "never_delete_without_review": [
                str(workspace / "out_d4_b2_final"),
                str(workspace),
                str(repo),
                "/srv/data/aosp_bramble_workspace",
            ],
        },
    }

    ns.evidence_root.mkdir(parents=True, exist_ok=True)
    evidence = Path(tempfile.mkdtemp(prefix="SABLE_DISK_SPACE_AUDIT_", dir=ns.evidence_root))
    report = evidence / "disk_space_audit.json"
    report.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    digest = sha256_file(report)
    (evidence / "SHA256SUMS").write_text(f"{digest}  disk_space_audit.json\n", encoding="utf-8")

    print("SABLE_DISK_SPACE_AUDIT_MODE=READ_ONLY_NO_DELETE")
    for name, info in fs.items():
        print(f"FS={name} PROBE={info['probe']} TOTAL={human(int(info['total_bytes']))} USED={human(int(info['used_bytes']))} FREE={human(int(info['free_bytes']))}")
    print("\n===== KNOWN PATHS =====")
    for item in items:
        print(f"{item.disposition}\t{human(item.bytes)}\t{item.path}")
    print("\n===== TARGET FILES =====")
    for row in tf:
        suffix = f" sha256={row['sha256']}" if "sha256" in row else ""
        print(f"{row['role']}\t{human(row['bytes'] if isinstance(row['bytes'], int) else None)}\t{row['path']}{suffix}")
    print("\n===== /tmp SABLE/PANTHER EVIDENCE =====")
    print(f"COUNT={len(tmp_rows)} TOTAL={human(payload['tmp_evidence']['total_bytes'])}")
    for row in tmp_rows[:25]:
        print(f"{human(row['bytes'] if isinstance(row['bytes'], int) else None)}\t{row['path']}")
    print(f"EVIDENCE_DIR={evidence}")
    print("DELETE_ACTIONS=NONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
