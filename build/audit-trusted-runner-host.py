#!/usr/bin/env python3
from __future__ import annotations

import argparse
import grp
import json
import os
import pathlib
import pwd
import shutil
import subprocess
from typing import Any

RUNNER_PATTERNS = (
    "Runner.Listener",
    "Runner.Worker",
    "actions-runner",
    "runsvc.sh",
)
SERVICE_PATTERNS = (
    "actions.runner",
    "github-runner",
    "github.actions.runner",
    "sable-runner",
)
PRIVILEGED_GROUPS = {
    "sudo",
    "wheel",
    "docker",
    "lxd",
    "libvirt",
    "libvirt-qemu",
}


def run(cmd: list[str]) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            cmd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=30,
        )
        return proc.returncode, proc.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        return 127, f"{type(exc).__name__}: {exc}"


def command_json(cmd: list[str]) -> Any:
    rc, out = run(cmd)
    if rc != 0:
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def flatten(nodes: list[dict[str, Any]], out: list[dict[str, Any]]) -> None:
    for node in nodes:
        out.append(node)
        children = node.get("children") or []
        if isinstance(children, list):
            flatten(children, out)


def mount_info(root: pathlib.Path) -> dict[str, Any]:
    data = command_json(["findmnt", "--json", "-T", str(root)])
    if not data or not data.get("filesystems"):
        return {"status": "UNKNOWN", "reason": "findmnt_failed"}
    fs = data["filesystems"][0]
    return {
        "status": "OK",
        "source": fs.get("source"),
        "target": fs.get("target"),
        "fstype": fs.get("fstype"),
        "options": fs.get("options"),
    }


def block_chain(source: str | None) -> tuple[list[dict[str, Any]], str, str]:
    if not source or not source.startswith("/dev/"):
        return [], "UNKNOWN", "mount_source_not_block_device"

    data = command_json([
        "lsblk", "--json", "-o",
        "NAME,KNAME,PATH,PKNAME,TYPE,FSTYPE,MOUNTPOINTS,UUID,PARTUUID",
    ])
    if not data or not isinstance(data.get("blockdevices"), list):
        return [], "UNKNOWN", "lsblk_failed"

    flat: list[dict[str, Any]] = []
    flatten(data["blockdevices"], flat)

    by_path = {x.get("path"): x for x in flat if x.get("path")}
    by_name: dict[str, dict[str, Any]] = {}
    for item in flat:
        for key in ("name", "kname"):
            value = item.get(key)
            if value:
                by_name[str(value)] = item

    current = by_path.get(source)
    if current is None:
        real = os.path.realpath(source)
        current = by_path.get(real)
    if current is None:
        current = by_name.get(pathlib.Path(os.path.realpath(source)).name)
    if current is None:
        return [], "UNKNOWN", "source_not_found_in_lsblk"

    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    while current is not None:
        ident = str(current.get("path") or current.get("name") or current.get("kname"))
        if ident in seen:
            break
        seen.add(ident)
        result.append({
            "name": current.get("name"),
            "kname": current.get("kname"),
            "path": current.get("path"),
            "pkname": current.get("pkname"),
            "type": current.get("type"),
            "fstype": current.get("fstype"),
        })
        parent = current.get("pkname")
        current = by_name.get(str(parent)) if parent else None

    encrypted = any(
        str(x.get("type") or "").lower() == "crypt"
        or str(x.get("fstype") or "").lower() == "crypto_luks"
        for x in result
    )
    if encrypted:
        return result, "PASS_ENCRYPTED", "dm_crypt_or_luks_in_block_ancestry"
    return result, "FAIL_UNENCRYPTED", "no_dm_crypt_or_luks_in_block_ancestry"


def runner_processes() -> list[str]:
    rc, out = run(["ps", "-eo", "pid=,user=,comm=,args="])
    if rc != 0:
        return []
    result = []
    for line in out.splitlines():
        low = line.lower()
        if any(p.lower() in low for p in RUNNER_PATTERNS):
            if "sable_infra4_host_audit.py" not in low:
                result.append(line.strip())
    return result


def runner_services(user: bool) -> list[str]:
    cmd = ["systemctl"]
    if user:
        cmd.append("--user")
    cmd += ["list-unit-files", "--type=service", "--all", "--no-legend", "--no-pager"]
    rc, out = run(cmd)
    if rc != 0:
        return []
    return [
        line.strip()
        for line in out.splitlines()
        if any(p in line.lower() for p in SERVICE_PATTERNS)
    ]


def runner_user(name: str) -> dict[str, Any]:
    try:
        p = pwd.getpwnam(name)
    except KeyError:
        return {"exists": False}

    gids = {p.pw_gid}
    for g in grp.getgrall():
        if name in g.gr_mem:
            gids.add(g.gr_gid)
    groups = sorted({grp.getgrgid(gid).gr_name for gid in gids})
    privileged = sorted(PRIVILEGED_GROUPS.intersection(groups))
    return {
        "exists": True,
        "uid": p.pw_uid,
        "gid": p.pw_gid,
        "home": p.pw_dir,
        "shell": p.pw_shell,
        "groups": groups,
        "privileged_groups": privileged,
    }


def runner_inventory(root: pathlib.Path) -> list[str]:
    if not root.exists():
        return []
    interesting = {
        ".runner",
        ".credentials",
        ".credentials_rsaparams",
        "Runner.Listener",
        "Runner.Worker",
        "config.sh",
        "run.sh",
        "runsvc.sh",
        "svc.sh",
    }
    result: list[str] = []
    base_depth = len(root.resolve().parts)
    for current, dirs, files in os.walk(root):
        p = pathlib.Path(current)
        depth = len(p.resolve().parts) - base_depth
        if depth >= 4:
            dirs[:] = []
        for name in files:
            if name in interesting:
                result.append(str((p / name).relative_to(root)))
    return sorted(result)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="/srv/data/sable-build")
    parser.add_argument("--runner-dir", default="/srv/data/sable-build/sableos/runner")
    parser.add_argument("--runner-user", default="sable-runner")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    root = pathlib.Path(args.root).resolve()
    runner_dir = pathlib.Path(args.runner_dir).resolve()

    mount = mount_info(root)
    chain, enc_status, enc_reason = block_chain(
        mount.get("source") if mount.get("status") == "OK" else None
    )
    processes = runner_processes()
    system_services = runner_services(False)
    user_services = runner_services(True)
    user = runner_user(args.runner_user)
    inventory = runner_inventory(runner_dir)

    active_or_configured = bool(
        processes or system_services or user_services or inventory
    )
    privileged = bool(user.get("exists") and user.get("privileged_groups"))

    doc = {
        "schema": "sableos-infra4-host-audit-v1",
        "root": str(root),
        "runner_dir": str(runner_dir),
        "mount": mount,
        "block_chain": chain,
        "encryption_status": enc_status,
        "encryption_reason": enc_reason,
        "runner_processes": processes,
        "runner_system_services": system_services,
        "runner_user_services": user_services,
        "runner_installation_inventory": inventory,
        "runner_user": user,
        "runner_active_or_configured": active_or_configured,
        "runner_user_privileged": privileged,
        "commands": {
            "findmnt": shutil.which("findmnt"),
            "lsblk": shutil.which("lsblk"),
            "systemctl": shutil.which("systemctl"),
            "ps": shutil.which("ps"),
        },
    }

    pathlib.Path(args.out).write_text(
        json.dumps(doc, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"INFRA4_SOURCE_ROOT={root}")
    print(f"INFRA4_MOUNT_SOURCE={mount.get('source', 'UNKNOWN')}")
    print(f"INFRA4_MOUNT_TARGET={mount.get('target', 'UNKNOWN')}")
    print(f"INFRA4_MOUNT_FSTYPE={mount.get('fstype', 'UNKNOWN')}")
    print(f"INFRA4_BLOCK_ANCESTRY_COUNT={len(chain)}")
    print(f"INFRA4_AT_REST_ENCRYPTION={enc_status}")
    print(f"INFRA4_AT_REST_ENCRYPTION_REASON={enc_reason}")
    print(f"INFRA4_RUNNER_PROCESS_COUNT={len(processes)}")
    print(f"INFRA4_RUNNER_SYSTEM_SERVICE_COUNT={len(system_services)}")
    print(f"INFRA4_RUNNER_USER_SERVICE_COUNT={len(user_services)}")
    print(f"INFRA4_RUNNER_INSTALLATION_MARKER_COUNT={len(inventory)}")
    print(f"INFRA4_RUNNER_USER_EXISTS={'YES' if user.get('exists') else 'NO'}")
    print(f"INFRA4_RUNNER_USER_PRIVILEGED={'YES' if privileged else 'NO'}")
    print(
        "INFRA4_EXISTING_RUNNER_STATE="
        + ("ACTIVE_OR_CONFIGURED" if active_or_configured else "ABSENT_OR_INACTIVE")
    )
    print("SABLE_INFRA4_HOST_AUDIT=PASS")


if __name__ == "__main__":
    main()
