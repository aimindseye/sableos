#!/usr/bin/env python3
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import pathlib
import re
import subprocess
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCK = ROOT / "build" / "supply-chain-lock.json"
WORKFLOWS = ROOT / ".github" / "workflows"

USES = re.compile(r"^\s*-?\s*uses:\s*([^\s#]+)")
PLUGIN = re.compile(r'id\("([^"]+)"\)\s+version\s+"([^"]+)"')
COORD = re.compile(
    r'(?:"|\()([A-Za-z0-9_.-]+):([A-Za-z0-9_.-]+):([A-Za-z0-9_.+:-]+)(?:"|\))'
)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), *args],
        text=True,
    ).strip()


def parse_cargo_lock(path: pathlib.Path) -> list[dict]:
    packages: list[dict] = []
    current: dict | None = None

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line == "[[package]]":
            if current:
                packages.append(current)
            current = {}
            continue

        if current is None or "=" not in line:
            continue

        key, value = [x.strip() for x in line.split("=", 1)]
        if key not in {"name", "version", "source", "checksum"}:
            continue
        if not value.startswith('"'):
            continue
        current[key] = json.loads(value)

    if current:
        packages.append(current)

    for item in packages:
        if "name" not in item or "version" not in item:
            raise SystemExit(f"invalid Cargo.lock package block: {item}")

    return packages


def cargo_sbom(commit: str, tree: str) -> dict:
    packages = parse_cargo_lock(ROOT / "apps/r8/rust/Cargo.lock")
    components = []
    seen = set()

    for pkg in sorted(
        packages,
        key=lambda p: (p["name"], p["version"], p.get("source", "")),
    ):
        key = (pkg["name"], pkg["version"], pkg.get("source", ""))
        if key in seen:
            continue
        seen.add(key)

        name = pkg["name"]
        version = pkg["version"]
        purl = (
            "pkg:cargo/"
            + urllib.parse.quote(name, safe="-._~")
            + "@"
            + urllib.parse.quote(version, safe="-._~+")
        )

        component = {
            "type": "library",
            "bom-ref": f"{purl}#{len(components)+1}",
            "name": name,
            "version": version,
            "purl": purl,
        }
        if pkg.get("checksum"):
            component["hashes"] = [
                {"alg": "SHA-256", "content": pkg["checksum"]}
            ]
        props = []
        if pkg.get("source"):
            props.append({"name": "sableos:cargo-source", "value": pkg["source"]})
        if props:
            component["properties"] = props
        components.append(component)

    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {
            "component": {
                "type": "application",
                "name": "sableos-r8-rust-workspace",
                "version": commit,
                "properties": [
                    {"name": "sableos:git-tree", "value": tree},
                    {
                        "name": "sableos:cargo-lock-sha256",
                        "value": sha256(ROOT / "apps/r8/rust/Cargo.lock"),
                    },
                ],
            }
        },
        "components": components,
    }


def action_inventory() -> list[dict]:
    out = []
    for path in sorted(WORKFLOWS.glob("*.y*ml")):
        for lineno, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), 1
        ):
            m = USES.match(line)
            if not m:
                continue
            ref = m.group(1)
            out.append(
                {
                    "workflow": str(path.relative_to(ROOT)),
                    "line": lineno,
                    "uses": ref,
                }
            )
    return out


def android_inventory() -> tuple[list[dict], list[dict]]:
    plugins = set()
    coordinates = set()
    root = ROOT / "apps/r8/android"

    for path in sorted(root.rglob("*.gradle.kts")):
        text = path.read_text(encoding="utf-8")
        for name, version in PLUGIN.findall(text):
            plugins.add((name, version))
        for group, artifact, version in COORD.findall(text):
            coordinates.add((group, artifact, version))

    return (
        [
            {"id": name, "version": version}
            for name, version in sorted(plugins)
        ],
        [
            {"group": g, "artifact": a, "version": v}
            for g, a, v in sorted(coordinates)
        ],
    )


def critical_inputs() -> list[dict]:
    fixed = [
        "apps/r8/rust/Cargo.lock",
        "apps/r8/rust/rust-toolchain.toml",
        "apps/r8/android/build.gradle.kts",
        "apps/r8/android/settings.gradle.kts",
        "build/supply-chain-lock.json",
        "build/install-pinned-tool.py",
        "build/generate-supply-chain-evidence.py",
        "build/check-ci-policy.py",
        "build/check-runner-policy.py",
        "build/trusted-runner-policy.json",
        "build/audit-trusted-runner-host.py",
        "build/check-gradle-supply-chain.py",
        "apps/r8/android/calculator/gradle.lockfile",
        "apps/r8/android/convert/gradle.lockfile",
        "apps/r8/android/design/gradle.lockfile",
        "apps/r8/android/games/gradle.lockfile",
        "apps/r8/android/media/gradle.lockfile",
        "apps/r8/android/gradle/verification-metadata.xml",
    ]
    fixed.extend(
        str(p.relative_to(ROOT)) for p in sorted(WORKFLOWS.glob("*.y*ml"))
    )
    result = []
    for rel in sorted(set(fixed)):
        path = ROOT / rel
        if not path.is_file():
            raise SystemExit(f"critical supply-chain input missing: {rel}")
        result.append(
            {
                "path": rel,
                "sha256": sha256(path),
                "size": path.stat().st_size,
            }
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--rust-sbom", required=True)
    parser.add_argument("--artifact-glob", action="append", default=[])
    args = parser.parse_args()

    commit = git("rev-parse", "HEAD")
    tree = git("rev-parse", "HEAD^{tree}")
    tool_lock = json.loads(LOCK.read_text(encoding="utf-8"))
    plugins, coords = android_inventory()

    artifacts = []
    seen = set()
    for pattern in args.artifact_glob:
        for raw in sorted(glob.glob(str(ROOT / pattern))):
            path = pathlib.Path(raw)
            if not path.is_file():
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            artifacts.append(
                {
                    "path": str(path.relative_to(ROOT)),
                    "sha256": sha256(path),
                    "size": path.stat().st_size,
                }
            )

    manifest = {
        "schema": "sableos-supply-chain-evidence-v1",
        "source": {"commit": commit, "tree": tree},
        "critical_inputs": critical_inputs(),
        "actions": action_inventory(),
        "pinned_tools": tool_lock,
        "android_declared_plugins": plugins,
        "android_declared_coordinates": coords,
        "artifacts": artifacts,
        "android_resolution_status": (
            "committed Gradle lockfiles and SHA-256 verification metadata "
            "are enforced by .github/workflows/supply-chain.yml"
        ),
    }

    out = pathlib.Path(args.out)
    sbom = pathlib.Path(args.rust_sbom)
    out.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    sbom.write_text(
        json.dumps(cargo_sbom(commit, tree), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"SUPPLY_CHAIN_MANIFEST={out}")
    print(f"SUPPLY_CHAIN_MANIFEST_SHA256={sha256(out)}")
    print(f"RUST_CYCLONEDX_SBOM={sbom}")
    print(f"RUST_CYCLONEDX_SBOM_SHA256={sha256(sbom)}")
    print("SABLE_SUPPLY_CHAIN_EVIDENCE=PASS")


if __name__ == "__main__":
    main()
