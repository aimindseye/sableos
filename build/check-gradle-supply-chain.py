#!/usr/bin/env python3
from __future__ import annotations
import argparse
import hashlib
import json
import pathlib
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
ANDROID = ROOT / "apps" / "r8" / "android"
EXPECTED_LOCKFILES = {
    "calculator/gradle.lockfile",
    "convert/gradle.lockfile",
    "design/gradle.lockfile",
    "games/gradle.lockfile",
    "media/gradle.lockfile",
}
VERIFICATION_REL = "gradle/verification-metadata.xml"
NS = {"v": "https://schema.gradle.org/dependency-verification"}

def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def fail(reason: str) -> None:
    raise SystemExit(f"SABLE_GRADLE_SUPPLY_CHAIN_FAIL={reason}")

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest")
    args = parser.parse_args()

    actual = {
        str(p.relative_to(ANDROID))
        for p in ANDROID.rglob("gradle.lockfile")
        if p.is_file()
    }
    if actual != EXPECTED_LOCKFILES:
        fail(f"LOCKFILE_SET_MISMATCH:actual={sorted(actual)}:expected={sorted(EXPECTED_LOCKFILES)}")

    files = []
    for rel in sorted(EXPECTED_LOCKFILES):
        path = ANDROID / rel
        text = path.read_text(encoding="utf-8")
        if not text.startswith("# This is a Gradle generated file for dependency locking."):
            fail(f"LOCKFILE_HEADER_INVALID:{rel}")
        if "/home/" in text or "/tmp/" in text:
            fail(f"LOCKFILE_VOLATILE_PATH:{rel}")
        files.append({"path": rel, "sha256": sha256(path), "size": path.stat().st_size})

    verification = ANDROID / VERIFICATION_REL
    if not verification.is_file() or verification.stat().st_size == 0:
        fail("VERIFICATION_METADATA_MISSING")
    raw = verification.read_text(encoding="utf-8")
    if "/home/" in raw or "/tmp/" in raw:
        fail("VERIFICATION_METADATA_VOLATILE_PATH")

    root = ET.parse(verification).getroot()
    config = root.find("v:configuration", NS)
    if config is None:
        fail("VERIFICATION_CONFIGURATION_MISSING")
    vm = config.find("v:verify-metadata", NS)
    vs = config.find("v:verify-signatures", NS)
    if vm is None or vm.text != "true":
        fail("VERIFY_METADATA_NOT_TRUE")
    if vs is None or vs.text != "false":
        fail("VERIFY_SIGNATURES_UNEXPECTED")

    components = root.findall(".//v:component", NS)
    hashes = root.findall(".//v:sha256", NS)
    if not components or not hashes:
        fail("VERIFICATION_CONTENT_EMPTY")

    files.append({
        "path": VERIFICATION_REL,
        "sha256": sha256(verification),
        "size": verification.stat().st_size,
    })

    manifest = {
        "schema": "sableos-gradle-supply-chain-state-v1",
        "lockfile_count": len(EXPECTED_LOCKFILES),
        "verification_component_count": len(components),
        "verification_sha256_count": len(hashes),
        "files": files,
    }
    if args.manifest:
        pathlib.Path(args.manifest).write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    print(f"GRADLE_LOCKFILE_COUNT={len(EXPECTED_LOCKFILES)}")
    print(f"GRADLE_VERIFICATION_COMPONENT_COUNT={len(components)}")
    print(f"GRADLE_VERIFICATION_SHA256_COUNT={len(hashes)}")
    print("GRADLE_VERIFY_METADATA=true")
    print("GRADLE_VERIFY_SIGNATURES=false")
    print("SABLE_GRADLE_SUPPLY_CHAIN_STATE=PASS")

if __name__ == "__main__":
    main()
