#!/usr/bin/env python3
"""Read-only SableOS R1-R0 release-engineering preflight.

This tool does not generate keys, build, sign, create OTAs, contact a device, or
modify the Android workspace. It inventories the current Panther development
artifact and the exact GrapheneOS release-tooling substrate, then reports the
blockers that must be resolved before production release signing is authorized.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

EXPECTED_BASE = "GrapheneOS-2026081300"
EXPECTED_DEVICE = "panther"
EXPECTED_GRAPHENE_TAG = "2026081300"
EXPECTED_MANIFEST_SHA256 = "c50f0096f538e604aa008e8ab4e3f1a3739f142c60c878a32f402c11eb406572"
EXPECTED_SCRIPT_HEAD = "b54206456a15f1c1ef5776b752d2705fe75f1b0a"
EXPECTED_UPDATER_HEAD = "d7e29f110890de68b63bb8c256b4d249a2d29cf9"
EXPECTED_B2_TARGET_FILES_SHA256 = "b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78"
EXPECTED_B2_TARGET_FILES_SIZE = 3650769747
EXPECTED_B2_BUILDMANIFEST_SHA256 = "8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec"
GRAPHENE_UPDATER_URL = "https://releases.grapheneos.org/"

SIGNING_KEYS_2026081300 = (
    "bluetooth",
    "gmscompat_lib",
    "media",
    "networkstack",
    "nfc",
    "platform",
    "releasekey",
    "sdk_sandbox",
    "shared",
)

REQUIRED_RELEASE_FILES = (
    "script/common.sh",
    "script/decrypt-keys",
    "script/encrypt-keys",
    "script/finalize.sh",
    "script/generate-delta.sh",
    "script/generate-keys",
    "script/generate-metadata",
    "script/generate-release.sh",
    "development/tools/make_key",
    "external/avb/avbtool.py",
    "packages/apps/Updater/res/values/config.xml",
)

FORBIDDEN_AUTH = (
    "SOURCE_MUTATION_AUTHORIZED",
    "WORKSPACE_OUTPUT_MUTATION_AUTHORIZED",
    "BUILD_AUTHORIZED",
    "KEY_GENERATION_AUTHORIZED",
    "SIGNING_AUTHORIZED",
    "OTA_GENERATION_AUTHORIZED",
    "DEVICE_CONTACT_AUTHORIZED",
    "DEVICE_REBOOT_AUTHORIZED",
    "FLASH_AUTHORIZED",
    "SLOT_CHANGE_AUTHORIZED",
    "USERDATA_OR_METADATA_WIPE_AUTHORIZED",
)


@dataclass(frozen=True)
class Check:
    id: str
    status: str
    expected: object
    actual: object
    detail: str = ""


class Preflight:
    def __init__(self) -> None:
        self.checks: list[Check] = []

    def add(self, ident: str, status: str, expected: object, actual: object, detail: str = "") -> None:
        self.checks.append(Check(ident, status, expected, actual, detail))

    def count(self, status: str) -> int:
        return sum(c.status == status for c in self.checks)


def sha256_file(path: Path, chunk_size: int = 8 * 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_lock(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        values[k] = v
    return values


def run_readonly(argv: list[str], cwd: Path | None = None, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        argv,
        cwd=str(cwd) if cwd else None,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
        check=False,
    )


def git_head(path: Path) -> tuple[int, str]:
    cp = run_readonly(["git", "-C", str(path), "rev-parse", "HEAD"])
    return cp.returncode, cp.stdout.strip()


def parse_signing_keys_from_common(path: Path) -> tuple[str, ...]:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"readonly\s+signing_keys=\((.*?)\n\)", text, re.S)
    if not match:
        return ()
    keys = []
    for raw in match.group(1).splitlines():
        key = raw.strip()
        if key and not key.startswith("#"):
            keys.append(key)
    return tuple(keys)


def parse_key_generator_subject(path: Path) -> str | None:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^CN=(.+)$", text, re.M)
    return match.group(1).strip() if match else None


def parse_updater_url(path: Path) -> str | None:
    try:
        root = ET.fromstring(path.read_text(encoding="utf-8"))
    except (OSError, ET.ParseError):
        return None
    for node in root.findall("string"):
        if node.attrib.get("name") == "url":
            return (node.text or "").strip()
    return None


def parse_properties(text: str) -> dict[str, str]:
    props: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        props[k.strip()] = v.strip()
    return props


def find_build_properties(zf: zipfile.ZipFile) -> tuple[dict[str, str], list[str]]:
    interesting = {
        "ro.build.type",
        "ro.build.tags",
        "ro.build.version.incremental",
        "ro.build.fingerprint",
        "ro.product.device",
        "ro.product.system.device",
    }
    merged: dict[str, str] = {}
    sources: list[str] = []
    candidates = [n for n in zf.namelist() if n.endswith("build.prop")]
    priority = sorted(candidates, key=lambda n: (0 if n in {"SYSTEM/build.prop", "SYSTEM/system/build.prop"} else 1, n))
    for name in priority:
        try:
            text = zf.read(name).decode("utf-8", errors="replace")
        except KeyError:
            continue
        props = parse_properties(text)
        picked = False
        for key in interesting:
            if key in props and key not in merged:
                merged[key] = props[key]
                picked = True
        if picked:
            sources.append(name)
    return merged, sources


def first_existing(zf: zipfile.ZipFile, names: Iterable[str]) -> tuple[str | None, bytes | None]:
    members = set(zf.namelist())
    for name in names:
        if name in members:
            return name, zf.read(name)
    return None, None


def count_test_key_refs(text: str) -> int:
    patterns = (
        "build/make/target/product/security/",
        "build/target/product/security/",
        "/testkey",
        "testkey.x509.pem",
        "testkey.pk8",
    )
    return sum(line.count(p) for line in text.splitlines() for p in patterns)


def redact_path(path: Path) -> str:
    # Paths are project state rather than secrets; normalize only redundant slashes.
    return str(path.resolve())


def ensure_authorization_boundary(pf: Preflight) -> bool:
    bad: list[str] = []
    for name in FORBIDDEN_AUTH:
        value = os.environ.get(name, "NO")
        if value != "NO":
            bad.append(f"{name}={value}")
    if bad:
        pf.add(
            "authorization.read_only_boundary",
            "ERROR",
            "all mutation/device authorizations NO",
            ", ".join(bad),
            "R1-R0 is intentionally read-only; refuse to run under a mutating authorization context.",
        )
        return False
    pf.add(
        "authorization.read_only_boundary",
        "PASS",
        "all mutation/device authorizations NO",
        "all NO",
    )
    return True


def write_evidence(evidence_root: Path, pf: Preflight, context: dict[str, object]) -> Path:
    evidence_root.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    evidence_dir = Path(tempfile.mkdtemp(prefix=f"SABLE_R1_R0_RELEASE_PREFLIGHT_{ts}_", dir=str(evidence_root)))
    os.chmod(evidence_dir, 0o700)

    payload = {
        "schema_version": 1,
        "context": context,
        "checks": [asdict(c) for c in pf.checks],
        "summary": {
            "pass": pf.count("PASS"),
            "blocker": pf.count("BLOCKER"),
            "info": pf.count("INFO"),
            "skip": pf.count("SKIP"),
            "error": pf.count("ERROR"),
        },
    }
    json_path = evidence_dir / "report.json"
    json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    lines = [
        "# SableOS R1-R0 release-engineering preflight",
        "",
        f"Generated: {ts}",
        "",
        "| Status | Check | Expected | Actual |",
        "| --- | --- | --- | --- |",
    ]
    for c in pf.checks:
        exp = str(c.expected).replace("|", "\\|")
        act = str(c.actual).replace("|", "\\|")
        lines.append(f"| {c.status} | `{c.id}` | {exp} | {act} |")
        if c.detail:
            lines.append(f"\n> {c.id}: {c.detail}\n")
    md_path = evidence_dir / "report.md"
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    sums = []
    for p in (json_path, md_path):
        sums.append(f"{sha256_file(p)}  {p.name}")
    (evidence_dir / "SHA256SUMS").write_text("\n".join(sums) + "\n", encoding="utf-8")
    return evidence_dir


def build_parser() -> argparse.ArgumentParser:
    repo_root = Path(__file__).resolve().parents[3]
    workspace = Path("/srv/data/sableos_panther_graphene_2026081300_workspace")
    target_files = workspace / "out_d4_b2_final/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target_files.zip"
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--workspace", type=Path, default=workspace)
    p.add_argument("--target-files", type=Path, default=target_files)
    p.add_argument(
        "--baseline-lock",
        type=Path,
        default=repo_root / "patches/android-17-grapheneos-2026081300/BASELINE.lock",
    )
    p.add_argument("--expected-device", default=EXPECTED_DEVICE)
    p.add_argument("--expected-target-files-sha256", default=EXPECTED_B2_TARGET_FILES_SHA256)
    p.add_argument("--hash-container", action="store_true", help="Recompute the full target-files SHA-256 (off by default; D4 already sealed it).")
    p.add_argument("--full-zip-crc", action="store_true", help="Read every ZIP member and verify CRCs (off by default to keep R1-R0 bounded).")
    p.add_argument("--evidence-root", type=Path, default=Path("/tmp"))
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    pf = Preflight()

    if not ensure_authorization_boundary(pf):
        print("[ERROR] authorization.read_only_boundary")
        print("R1_R0_PREFLIGHT_EXECUTION=ERROR")
        print("R1_RELEASE_READINESS=UNKNOWN")
        return 2

    workspace = args.workspace.resolve()
    target_files = args.target_files.resolve()
    baseline_lock = args.baseline_lock.resolve()

    pf.add("workspace.exists", "PASS" if workspace.is_dir() else "ERROR", True, workspace.is_dir(), redact_path(workspace))
    pf.add("target_files.exists", "PASS" if target_files.is_file() else "ERROR", True, target_files.is_file(), redact_path(target_files))
    pf.add("baseline_lock.exists", "PASS" if baseline_lock.is_file() else "ERROR", True, baseline_lock.is_file(), redact_path(baseline_lock))

    if pf.count("ERROR"):
        evidence_dir = write_evidence(args.evidence_root, pf, {"workspace": str(workspace), "target_files": str(target_files)})
        for c in pf.checks:
            print(f"[{c.status:<7}] {c.id}: expected={c.expected!r} actual={c.actual!r}")
        print(f"EVIDENCE_DIR={evidence_dir}")
        print("R1_R0_PREFLIGHT_EXECUTION=ERROR")
        print("R1_RELEASE_READINESS=UNKNOWN")
        return 2

    # Baseline lock binding.
    try:
        lock = parse_lock(baseline_lock)
    except OSError as exc:
        pf.add("baseline_lock.parse", "ERROR", "readable key=value lock", str(exc))
        lock = {}
    if lock:
        pf.add("baseline.base", "PASS" if lock.get("SABLE_BASE") == EXPECTED_BASE else "ERROR", EXPECTED_BASE, lock.get("SABLE_BASE"))
        pf.add("baseline.device", "PASS" if lock.get("DEVICE") == args.expected_device else "ERROR", args.expected_device, lock.get("DEVICE"))
        pf.add("baseline.graphene_tag", "PASS" if lock.get("GRAPHENE_MANIFEST_TAG") == EXPECTED_GRAPHENE_TAG else "ERROR", EXPECTED_GRAPHENE_TAG, lock.get("GRAPHENE_MANIFEST_TAG"))
        pf.add("baseline.manifest_sha256", "PASS" if lock.get("PINNED_REPO_MANIFEST_SHA256") == EXPECTED_MANIFEST_SHA256 else "ERROR", EXPECTED_MANIFEST_SHA256, lock.get("PINNED_REPO_MANIFEST_SHA256"))

    # Exact pinned manifest and source-tooling revision binding.
    if shutil.which("repo"):
        cp = run_readonly(["repo", "manifest", "-r"], cwd=workspace, timeout=60)
        if cp.returncode == 0:
            manifest_sha = sha256_bytes(cp.stdout.encode("utf-8"))
            pf.add("source.pinned_manifest", "PASS" if manifest_sha == EXPECTED_MANIFEST_SHA256 else "BLOCKER", EXPECTED_MANIFEST_SHA256, manifest_sha, "A mismatch means the checked-out source revisions are not the validated GrapheneOS 2026081300 manifest closure.")
        else:
            pf.add("source.pinned_manifest", "ERROR", "repo manifest -r succeeds", f"rc={cp.returncode}", cp.stderr.strip())
    else:
        pf.add("host.repo", "ERROR", "repo available", "missing")

    if shutil.which("git"):
        for ident, rel, expected in (
            ("source.script_head", "script", EXPECTED_SCRIPT_HEAD),
            ("source.updater_head", "packages/apps/Updater", EXPECTED_UPDATER_HEAD),
        ):
            rc, head = git_head(workspace / rel)
            status = "PASS" if rc == 0 and head == expected else "ERROR"
            pf.add(ident, status, expected, head if rc == 0 else f"git_rc={rc}")
    else:
        pf.add("host.git", "ERROR", "git available", "missing")

    # Release tool inventory.
    missing_release_files = [rel for rel in REQUIRED_RELEASE_FILES if not (workspace / rel).is_file()]
    pf.add(
        "release_tools.required_files",
        "PASS" if not missing_release_files else "ERROR",
        "all required release-tool inputs present",
        "all present" if not missing_release_files else ",".join(missing_release_files),
    )

    if not missing_release_files:
        common_keys = parse_signing_keys_from_common(workspace / "script/common.sh")
        pf.add(
            "release_tools.signing_key_domains",
            "PASS" if common_keys == SIGNING_KEYS_2026081300 else "ERROR",
            ",".join(SIGNING_KEYS_2026081300),
            ",".join(common_keys) or "unparseable",
            "This binds the exact signing-domain inventory used by GrapheneOS 2026081300.",
        )

        key_subject = parse_key_generator_subject(workspace / "script/generate-keys")
        if key_subject == "GrapheneOS":
            pf.add(
                "signing.generator_subject",
                "BLOCKER",
                "Sable-owned certificate subject",
                "GrapheneOS",
                "The pinned upstream generator hardcodes CN=GrapheneOS. Do not run it unchanged for Sable production keys.",
            )
        elif key_subject:
            pf.add("signing.generator_subject", "INFO", "Sable-owned certificate subject", key_subject)
        else:
            pf.add("signing.generator_subject", "ERROR", "parseable CN assignment", "unparseable")

        release_text = (workspace / "script/generate-release.sh").read_text(encoding="utf-8")
        required_flow_tokens = (
            "panther",
            "sign_target_files_apks",
            "ota_from_target_files",
            "img_from_target_files",
            "avb_pkmd.bin",
            "id_ed25519",
        )
        missing_flow = [token for token in required_flow_tokens if token not in release_text]
        pf.add(
            "release_tools.generate_release_flow",
            "PASS" if not missing_flow else "ERROR",
            "panther signing + OTA + image + AVB + factory signature flow",
            "bound" if not missing_flow else "missing:" + ",".join(missing_flow),
        )

    # Updater source endpoint. This MUST move away from GrapheneOS before an official Sable build.
    updater_path = workspace / "packages/apps/Updater/res/values/config.xml"
    updater_url = parse_updater_url(updater_path)
    if updater_url is None:
        pf.add("updater.url", "ERROR", "parseable Updater URL", "unparseable")
    elif updater_url == GRAPHENE_UPDATER_URL:
        pf.add(
            "updater.url",
            "BLOCKER",
            "Sable-owned HTTPS update endpoint",
            updater_url,
            "GrapheneOS explicitly requires derivatives to use their own update server before OFFICIAL_BUILD=true.",
        )
    elif updater_url.startswith("https://"):
        pf.add("updater.url", "PASS", "Sable-owned HTTPS update endpoint", updater_url)
    else:
        pf.add("updater.url", "BLOCKER", "HTTPS update endpoint", updater_url)

    # Key custody readiness: do not read or hash private key material.
    key_dir = workspace / "keys" / args.expected_device
    if key_dir.exists():
        pf.add(
            "signing.key_dir",
            "BLOCKER",
            "final per-device key set with separately validated custody manifest",
            "present but intentionally uninspected",
            "R1-R0 never reads private key bytes. A later authorized custody gate must validate the key inventory and public fingerprints before signing.",
        )
    else:
        pf.add(
            "signing.key_dir",
            "BLOCKER",
            "final per-device key set provisioned under R1-R1 custody procedure",
            "absent",
            "Expected at R1-R0. Do not generate keys until the key-custody design is approved and key generation is separately authorized.",
        )
    pf.add(
        "release.source_seal_policy",
        "BLOCKER",
        "Sable release source identity committed/pinned and independently sealable",
        "R1 production source seal not yet defined",
        "D4 proves the development B2 population; R1 must define the exact source/config identity used for a production user/release-key build.",
    )
    pf.add(
        "signing.key_inventory",
        "INFO",
        "GrapheneOS 2026081300 signing domains",
        ",".join(SIGNING_KEYS_2026081300) + ",avb.pem,avb_pkmd.bin,id_ed25519",
    )

    # Current D4 target-files artifact inventory.
    stat = target_files.stat()
    pf.add("target_files.size", "PASS" if stat.st_size == EXPECTED_B2_TARGET_FILES_SIZE else "ERROR", EXPECTED_B2_TARGET_FILES_SIZE, stat.st_size)
    if args.hash_container:
        actual_tf_sha = sha256_file(target_files)
        pf.add("target_files.sha256", "PASS" if actual_tf_sha == args.expected_target_files_sha256 else "ERROR", args.expected_target_files_sha256, actual_tf_sha)
    else:
        pf.add(
            "target_files.sha256",
            "SKIP",
            args.expected_target_files_sha256,
            "not recomputed",
            "D4 already sealed the 3.65 GB container; pass --hash-container to independently recompute it.",
        )

    try:
        with zipfile.ZipFile(target_files) as zf:
            if args.full_zip_crc:
                bad = zf.testzip()
                pf.add("target_files.zip_integrity", "PASS" if bad is None else "ERROR", "all members CRC-valid", bad or "all valid")
            else:
                pf.add("target_files.zip_integrity", "SKIP", "full CRC scan optional", "not run", "The central directory and required metadata entries are read below; use --full-zip-crc for an O(container-size) member scan.")

            props, prop_sources = find_build_properties(zf)
            build_type = props.get("ro.build.type")
            build_tags = props.get("ro.build.tags")
            device = props.get("ro.product.device") or props.get("ro.product.system.device")
            pf.add("artifact.device", "PASS" if device == args.expected_device else "ERROR", args.expected_device, device or "unavailable")
            pf.add(
                "artifact.build_type",
                "BLOCKER" if build_type != "user" else "PASS",
                "user",
                build_type or "unavailable",
                "The D4 B2 artifact is expected to remain a development userdebug build; production R1 requires a fresh user build.",
            )
            tags_ok = bool(build_tags) and "test-keys" not in build_tags and "release-keys" in build_tags
            pf.add(
                "artifact.build_tags",
                "PASS" if tags_ok else "BLOCKER",
                "release-keys without test-keys",
                build_tags or "unavailable",
                "Public AOSP test keys are not acceptable for a release image.",
            )
            pf.add("artifact.build_prop_sources", "INFO", "build.prop source entries", ",".join(prop_sources) or "none")
            if "ro.build.version.incremental" in props:
                pf.add("artifact.build_number", "INFO", "current development build number", props["ro.build.version.incremental"])
            if "ro.build.fingerprint" in props:
                pf.add("artifact.fingerprint", "INFO", "current development fingerprint", props["ro.build.fingerprint"])

            members = zf.namelist()
            updater_members = [n for n in members if re.search(r"(^|/)Updater(?:/|\.apk$)", n)]
            pf.add(
                "artifact.updater_included",
                "PASS" if updater_members else "BLOCKER",
                True,
                bool(updater_members),
                "GrapheneOS includes the Updater app for OFFICIAL_BUILD=true; the current D4 development artifact may legitimately omit it.",
            )

            bm_name, bm_data = first_existing(
                zf,
                (
                    "SYSTEM/etc/security/fsverity/BuildManifest.apk",
                    "SYSTEM/system/etc/security/fsverity/BuildManifest.apk",
                ),
            )
            if bm_data is None:
                pf.add("artifact.buildmanifest", "ERROR", EXPECTED_B2_BUILDMANIFEST_SHA256, "missing")
            else:
                bm_sha = sha256_bytes(bm_data)
                pf.add("artifact.buildmanifest", "PASS" if bm_sha == EXPECTED_B2_BUILDMANIFEST_SHA256 else "ERROR", EXPECTED_B2_BUILDMANIFEST_SHA256, bm_sha, bm_name or "")

            meta_results: dict[str, object] = {}
            for meta in ("META/apkcerts.txt", "META/apexkeys.txt", "META/otakeys.txt", "META/misc_info.txt", "META/ab_partitions.txt"):
                if meta not in members:
                    meta_results[meta] = "missing"
                    continue
                text = zf.read(meta).decode("utf-8", errors="replace")
                if meta in {"META/apkcerts.txt", "META/apexkeys.txt", "META/otakeys.txt", "META/misc_info.txt"}:
                    meta_results[meta] = {"test_key_refs": count_test_key_refs(text), "lines": len(text.splitlines())}
                else:
                    parts = [line.strip() for line in text.splitlines() if line.strip()]
                    meta_results[meta] = {"partition_count": len(parts), "partitions": parts}

            for meta in ("META/apkcerts.txt", "META/apexkeys.txt", "META/otakeys.txt", "META/misc_info.txt"):
                value = meta_results.get(meta)
                if value == "missing":
                    pf.add(f"signing_meta.{Path(meta).stem}", "INFO", "present when applicable", "missing")
                else:
                    refs = int(value["test_key_refs"])  # type: ignore[index]
                    pf.add(
                        f"signing_meta.{Path(meta).stem}",
                        "BLOCKER" if refs else "PASS",
                        0,
                        refs,
                        "Count of references to standard AOSP/Android test-key paths in current target-files metadata.",
                    )

            ab = meta_results.get("META/ab_partitions.txt")
            if isinstance(ab, dict):
                pf.add("ota.ab_partitions", "PASS" if int(ab["partition_count"]) > 0 else "ERROR", ">0", ab["partition_count"])
                pf.add("ota.ab_partition_inventory", "INFO", "A/B partition names", ",".join(ab["partitions"]))
            else:
                pf.add("ota.ab_partitions", "ERROR", "META/ab_partitions.txt present", "missing")

    except (OSError, zipfile.BadZipFile) as exc:
        pf.add("target_files.open", "ERROR", "readable target-files zip", str(exc))

    # Production actions intentionally not performed by R1-R0.
    for ident, actual in (
        ("action.key_generation", "NOT_RUN"),
        ("action.user_release_build", "NOT_RUN"),
        ("action.sign_target_files", "NOT_RUN"),
        ("action.ota_generation", "NOT_RUN"),
        ("action.factory_image_generation", "NOT_RUN"),
        ("action.device_install", "NOT_RUN"),
        ("action.bootloader_lock", "NOT_RUN"),
    ):
        pf.add(ident, "INFO", "deferred beyond R1-R0", actual)

    context = {
        "workspace": str(workspace),
        "target_files": str(target_files),
        "baseline_lock": str(baseline_lock),
        "script_sha256": sha256_file(Path(__file__)),
        "hash_container": bool(args.hash_container),
        "full_zip_crc": bool(args.full_zip_crc),
        "expected_device": args.expected_device,
        "expected_graphene_tag": EXPECTED_GRAPHENE_TAG,
    }
    evidence_dir = write_evidence(args.evidence_root, pf, context)

    for c in pf.checks:
        detail = f" ({c.detail})" if c.detail else ""
        print(f"[{c.status:<7}] {c.id}: expected={c.expected!r} actual={c.actual!r}{detail}")

    print()
    print(f"PASS={pf.count('PASS')} BLOCKER={pf.count('BLOCKER')} INFO={pf.count('INFO')} SKIP={pf.count('SKIP')} ERROR={pf.count('ERROR')}")
    print(f"EVIDENCE_DIR={evidence_dir}")
    if pf.count("ERROR"):
        print("R1_R0_PREFLIGHT_EXECUTION=ERROR")
        print("R1_RELEASE_READINESS=UNKNOWN")
        return 2
    print("R1_R0_PREFLIGHT_EXECUTION=PASS")
    if pf.count("BLOCKER"):
        print(f"R1_RELEASE_READINESS=BLOCKED_{pf.count('BLOCKER')}")
        return 3
    print("R1_RELEASE_READINESS=READY_FOR_AUTHORIZED_R1_R1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
