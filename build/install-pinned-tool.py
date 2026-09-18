#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import tarfile
import tempfile
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCK_PATH = ROOT / "build" / "supply-chain-lock.json"


def load_lock() -> dict:
    doc = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    if doc.get("schema") != "sableos-pinned-tool-lock-v1":
        raise SystemExit("unexpected pinned-tool lock schema")
    if doc.get("platform") != "x86_64-linux":
        raise SystemExit("unexpected pinned-tool lock platform")

    tools = doc.get("tools")
    if not isinstance(tools, dict) or not tools:
        raise SystemExit("pinned-tool lock has no tools")

    for name, item in sorted(tools.items()):
        if not isinstance(item, dict):
            raise SystemExit(f"invalid tool entry: {name}")
        for key in ("version", "url", "sha256", "binary", "version_contains"):
            if not isinstance(item.get(key), str) or not item[key]:
                raise SystemExit(f"missing {name}.{key}")
        version_args = item.get("version_args")
        if (
            not isinstance(version_args, list)
            or not version_args
            or any(not isinstance(arg, str) or not arg for arg in version_args)
        ):
            raise SystemExit(f"invalid {name}.version_args")
        parsed = urllib.parse.urlparse(item["url"])
        if parsed.scheme != "https" or parsed.netloc.lower() != "github.com":
            raise SystemExit(f"non-GitHub HTTPS tool URL: {name}")
        digest = item["sha256"]
        if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise SystemExit(f"invalid SHA-256 for {name}")
        if pathlib.PurePosixPath(item["binary"]).name != item["binary"]:
            raise SystemExit(f"invalid binary basename for {name}")
    return doc


def download(url: str, expected_sha256: str, destination: pathlib.Path) -> None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "SableOS-INFRA3-pinned-tool-installer/1"},
    )
    digest = hashlib.sha256()
    with urllib.request.urlopen(request, timeout=120) as response:
        with destination.open("wb") as f:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
                f.write(chunk)
    actual = digest.hexdigest()
    if actual != expected_sha256:
        raise SystemExit(
            f"tool archive SHA-256 mismatch: expected={expected_sha256} actual={actual}"
        )


def extract_binary(archive: pathlib.Path, binary: str, destination: pathlib.Path) -> None:
    with tarfile.open(archive, "r:*") as tf:
        candidates = []
        for member in tf.getmembers():
            pure = pathlib.PurePosixPath(member.name)
            if pure.is_absolute() or ".." in pure.parts:
                raise SystemExit(f"unsafe archive member: {member.name}")
            if member.issym() or member.islnk():
                continue
            if member.isfile() and pure.name == binary:
                candidates.append(member)

        if len(candidates) != 1:
            raise SystemExit(
                f"expected exactly one {binary} in archive, found {len(candidates)}"
            )

        source = tf.extractfile(candidates[0])
        if source is None:
            raise SystemExit(f"unable to read {binary} from archive")

        tmp = destination.with_suffix(destination.suffix + ".tmp")
        with tmp.open("wb") as out:
            shutil.copyfileobj(source, out)
        os.chmod(tmp, 0o755)
        os.replace(tmp, destination)


def install_tool(name: str, item: dict, dest: pathlib.Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    binary_path = dest / item["binary"]

    with tempfile.NamedTemporaryFile(
        prefix=f"sable-{name}-",
        suffix=".archive",
        dir=dest,
        delete=False,
    ) as tmp:
        archive = pathlib.Path(tmp.name)

    try:
        download(item["url"], item["sha256"], archive)
        extract_binary(archive, item["binary"], binary_path)
    finally:
        archive.unlink(missing_ok=True)

    output = subprocess.check_output(
        [str(binary_path), *item["version_args"]],
        text=True,
        stderr=subprocess.STDOUT,
    ).strip()
    if item["version_contains"] not in output:
        raise SystemExit(
            f"unexpected {name} version output: {output!r}; "
            f"expected substring {item['version_contains']!r}"
        )

    print(f"PINNED_TOOL={name}")
    print(f"PINNED_TOOL_VERSION={item['version']}")
    print(f"PINNED_TOOL_ARCHIVE_SHA256={item['sha256']}")
    print(f"PINNED_TOOL_BINARY={binary_path}")
    print(f"PINNED_TOOL_VERSION_OUTPUT={output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--tool")
    group.add_argument("--all", action="store_true")
    parser.add_argument("--dest")
    parser.add_argument("--validate-lock", action="store_true")
    args = parser.parse_args()

    doc = load_lock()
    tools = doc["tools"]

    if args.validate_lock:
        print(f"PINNED_TOOL_LOCK={LOCK_PATH}")
        print(f"PINNED_TOOL_COUNT={len(tools)}")
        print("SABLE_PINNED_TOOL_LOCK=PASS")
        if not args.tool and not args.all:
            return

    if not args.tool and not args.all:
        raise SystemExit("select --tool NAME or --all")
    if not args.dest:
        raise SystemExit("--dest is required for installation")

    if args.tool:
        if args.tool not in tools:
            raise SystemExit(f"unknown tool: {args.tool}")
        selected = [(args.tool, tools[args.tool])]
    else:
        selected = sorted(tools.items())

    dest = pathlib.Path(args.dest).resolve()
    for name, item in selected:
        install_tool(name, item, dest)

    print("SABLE_PINNED_TOOL_INSTALL=PASS")


if __name__ == "__main__":
    main()
