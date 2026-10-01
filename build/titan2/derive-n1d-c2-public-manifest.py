#!/usr/bin/env python3
"""Derive a pinned public C2 local manifest from sealed historical repo evidence."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PUBLIC_PROJECT_PATHS = (
    "device/phh/treble",
    "packages/apps/QcRilAm",
    "prebuilts/vndk/v28",
    "prebuilts/vndk/v29",
    "prebuilts/vndk/v30",
    "treble_app",
    "vendor/apn",
    "vendor/hardware_overlay",
    "vendor/interfaces",
    "vendor/lptools",
    "vendor/magisk",
    "vendor/pixel/gsans",
    "vendor/vndk-tests",
)

HEX40 = re.compile(r"^[0-9a-f]{40}$")


def die(message: str) -> "NoReturn":
    raise SystemExit(f"N1D_C2_PUBLIC_MANIFEST=FAIL {message}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def is_public_fetch(fetch: str) -> bool:
    lowered = fetch.lower()
    if "cawilliamson" in lowered or "git@" in lowered or lowered.startswith("ssh:"):
        return False
    return lowered.startswith("https://")


def main() -> int:
    args = parse_args()
    if not args.input.is_file():
        die(f"input_missing={args.input}")

    try:
        root = ET.parse(args.input).getroot()
    except ET.ParseError as exc:
        die(f"xml_parse_error={exc}")

    if root.tag != "manifest":
        die(f"unexpected_root={root.tag}")

    remotes: dict[str, ET.Element] = {}
    for remote in root.findall("remote"):
        name = remote.attrib.get("name", "")
        if not name:
            die("remote_without_name")
        remotes[name] = remote

    default = root.find("default")
    default_remote = ""
    if default is not None:
        default_remote = default.attrib.get("remote", "")

    projects_by_path: dict[str, list[ET.Element]] = {}
    for project in root.findall("project"):
        path = project.attrib.get("path") or project.attrib.get("name")
        if not path:
            continue
        projects_by_path.setdefault(path, []).append(project)

    selected: list[ET.Element] = []
    used_remotes: set[str] = set()

    for path in PUBLIC_PROJECT_PATHS:
        hits = projects_by_path.get(path, [])
        if len(hits) != 1:
            die(f"path={path} expected=1 actual={len(hits)}")

        project = hits[0]
        revision = project.attrib.get("revision", "")
        if not HEX40.fullmatch(revision):
            die(f"path={path} revision_not_pinned={revision or '-'}")

        remote_name = project.attrib.get("remote", "") or default_remote
        if not remote_name:
            die(f"path={path} remote_missing_no_default")

        remote = remotes.get(remote_name)
        if remote is None:
            die(f"path={path} remote_undefined={remote_name}")

        fetch = remote.attrib.get("fetch", "")
        if not is_public_fetch(fetch):
            die(f"path={path} non_public_remote={remote_name} fetch={fetch}")

        if "vendor/cawilliamson-priv" in path:
            die("private_vendor_selected")

        selected.append(project)
        used_remotes.add(remote_name)

    if len(selected) != len(PUBLIC_PROJECT_PATHS):
        die("selected_count_mismatch")

    out_root = ET.Element("manifest")
    out_root.append(
        ET.Comment(
            " Generated from sealed public Restless Android-16 repo manifest; "
            "all project revisions are exact commits. "
        )
    )

    for remote_name in sorted(used_remotes):
        remote = remotes[remote_name]
        attrs = {
            key: value
            for key, value in remote.attrib.items()
            if key in {"name", "fetch", "review"}
        }
        ET.SubElement(out_root, "remote", attrs)

    for project in sorted(selected, key=lambda item: item.attrib.get("path", "")):
        attrs = {
            key: value
            for key, value in project.attrib.items()
            if key
            in {
                "name",
                "path",
                "remote",
                "revision",
                "groups",
                "clone-depth",
            }
        }
        attrs["revision"] = project.attrib["revision"]
        ET.SubElement(out_root, "project", attrs)

    ET.indent(out_root, space="  ")
    xml = ET.tostring(out_root, encoding="unicode", xml_declaration=True) + "\n"

    lowered = xml.lower()
    for forbidden in ("cawilliamson", "ssh://", "git@", 'revision="main"', 'revision="master"'):
        if forbidden in lowered:
            die(f"forbidden_token={forbidden}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(xml, encoding="utf-8")

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(f"N1D_C2_PUBLIC_PROJECT_COUNT={len(selected)}")
    print(f"N1D_C2_PUBLIC_MANIFEST_SHA256={digest}")
    print(f"N1D_C2_PUBLIC_MANIFEST={args.output}")
    print("N1D_C2_PRIVATE_VENDOR=ABSENT")
    print("N1D_C2_MUTABLE_REVISIONS=ABSENT")
    print("N1D_C2_PUBLIC_MANIFEST=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
