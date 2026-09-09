#!/usr/bin/env python3
"""SableOS R1-R2 static source-mutation and keygen-contract preflight.

This executable is intentionally non-mutating with respect to the Android
workspace. It verifies the exact two-file future source mutation, materializes
candidate postimages only under a /tmp evidence directory, validates the
R1-R1 policy binding, and checks the static production key-generation contract.

Exit codes:
  0  static preparation complete; ready to request a separate source-mutation authorization
  2  audit ERROR; state is not trustworthy
  3  audit complete but one or more BLOCKERs remain
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DEFAULT_WORKSPACE = Path("/srv/data/sableos_panther_graphene_2026081300_workspace")
DEFAULT_PLAN = Path("release/r1/r1-r2-source-mutation-plan-v1.json")
DEFAULT_KEYGEN = Path("release/r1/r1-r2-keygen-contract-v1.json")
DEFAULT_POLICY = Path("release/r1/panther-release-policy-v1.json")
MAX_TEXT = 1024 * 1024
EXPECTED_PLAN_SHA256 = "596b0d7964bdbddd4a6d0813cdb55e39367ede30c5d65e25f49b15bde687e05b"
EXPECTED_KEYGEN_CONTRACT_SHA256 = "eda47fa72e0048ee1dbcc3da26c87a6cad7533741e59de2e50a6d7d459dad996"

AUTH_VARS = (
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

SIGNING_DOMAINS = [
    "bluetooth",
    "gmscompat_lib",
    "media",
    "networkstack",
    "nfc",
    "platform",
    "releasekey",
    "sdk_sandbox",
    "shared",
]


@dataclass(frozen=True)
class Check:
    id: str
    status: str
    expected: Any
    actual: Any
    detail: str = ""


class Audit:
    def __init__(self) -> None:
        self.checks: list[Check] = []

    def add(self, ident: str, status: str, expected: Any, actual: Any, detail: str = "") -> None:
        self.checks.append(Check(ident, status, expected, actual, detail))

    def count(self, status: str) -> int:
        return sum(c.status == status for c in self.checks)

    def emit(self) -> None:
        for c in self.checks:
            suffix = f" ({c.detail})" if c.detail else ""
            print(f"[{c.status:<7}] {c.id}: expected={c.expected!r} actual={c.actual!r}{suffix}")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob_bytes(data: bytes) -> str:
    hdr = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(hdr + data).hexdigest()


def read_bounded(path: Path) -> bytes:
    st = path.stat()
    if st.st_size > MAX_TEXT:
        raise ValueError(f"file exceeds {MAX_TEXT} bytes: {path}")
    return path.read_bytes()


def load_json(path: Path) -> dict[str, Any]:
    obj = json.loads(read_bounded(path).decode("utf-8"))
    if not isinstance(obj, dict):
        raise ValueError(f"expected JSON object: {path}")
    return obj


def run_git(repo: Path, *args: str) -> str:
    allowed = {
        ("rev-parse", "HEAD"),
    }
    if tuple(args) not in allowed and not (len(args) == 2 and args[0] == "hash-object"):
        raise RuntimeError(f"git operation not allowlisted: {args!r}")
    cp = subprocess.run(
        ["git", *args],
        cwd=repo,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    )
    return cp.stdout.strip()


def check_authorizations(audit: Audit) -> bool:
    bad: dict[str, str] = {}
    for name in AUTH_VARS:
        value = os.environ.get(name, "NO")
        if value != "NO":
            bad[name] = value
    if bad:
        audit.add("authorization.read_only_boundary", "ERROR", "all mutation/device authorizations NO", bad)
        return False
    audit.add("authorization.read_only_boundary", "PASS", "all mutation/device authorizations NO", "all NO")
    return True


def validate_policy(policy_path: Path, plan: dict[str, Any], audit: Audit) -> None:
    expected = plan["r1_r1_policy"]
    data = read_bounded(policy_path)
    actual_sha = sha256_bytes(data)
    actual_blob = git_blob_bytes(data)
    audit.add("policy.sha256", "PASS" if actual_sha == expected["sha256"] else "ERROR", expected["sha256"], actual_sha)
    audit.add("policy.git_blob", "PASS" if actual_blob == expected["git_blob"] else "ERROR", expected["git_blob"], actual_blob)

    policy = json.loads(data.decode("utf-8"))
    ep = policy.get("update_endpoint", {})
    endpoint_ok = (
        ep.get("url") == "https://updates.sableos.org/"
        and ep.get("owner") == "SableOS"
        and ep.get("ownership_status") == "OPERATOR_VERIFIED"
    )
    audit.add(
        "policy.update_endpoint",
        "PASS" if endpoint_ok else "ERROR",
        {"url": "https://updates.sableos.org/", "owner": "SableOS", "ownership_status": "OPERATOR_VERIFIED"},
        {"url": ep.get("url"), "owner": ep.get("owner"), "ownership_status": ep.get("ownership_status")},
    )


def validate_source_and_materialize(
    workspace: Path,
    plan: dict[str, Any],
    evidence: Path,
    audit: Audit,
) -> list[dict[str, str]]:
    repos = plan["source_repositories"]
    repo_paths = {name: workspace / spec["path"] for name, spec in repos.items()}

    for name, spec in repos.items():
        repo = repo_paths[name]
        if not repo.is_dir():
            audit.add(f"source.repo.{name}.exists", "ERROR", True, False, str(repo))
            continue
        actual_head = run_git(repo, "rev-parse", "HEAD")
        audit.add(f"source.repo.{name}.head", "PASS" if actual_head == spec["head"] else "ERROR", spec["head"], actual_head)

    results: list[dict[str, str]] = []
    diff_chunks: list[str] = []

    for mutation in plan["mutations"]:
        ident = mutation["id"]
        repo = repo_paths[mutation["repo"]]
        source = workspace / mutation["workspace_path"]
        if not source.is_file():
            audit.add(f"mutation.{ident}.source_exists", "ERROR", True, False, str(source))
            continue

        before = read_bounded(source)
        before_text = before.decode("utf-8")
        actual_blob = run_git(repo, "hash-object", mutation["repo_relative_path"])
        actual_sha = sha256_bytes(before)
        audit.add(
            f"mutation.{ident}.preimage_blob",
            "PASS" if actual_blob == mutation["preimage_git_blob"] else "ERROR",
            mutation["preimage_git_blob"],
            actual_blob,
        )
        audit.add(
            f"mutation.{ident}.preimage_sha256",
            "PASS" if actual_sha == mutation["preimage_sha256"] else "ERROR",
            mutation["preimage_sha256"],
            actual_sha,
        )

        count = before_text.count(mutation["old"])
        audit.add(
            f"mutation.{ident}.replacement_count",
            "PASS" if count == mutation["replacement_count"] else "ERROR",
            mutation["replacement_count"],
            count,
        )
        if count != mutation["replacement_count"]:
            continue

        after_text = before_text.replace(mutation["old"], mutation["new"], mutation["replacement_count"])
        after = after_text.encode("utf-8")
        if after == before:
            audit.add(f"mutation.{ident}.postimage_differs", "ERROR", True, False)
            continue

        # Exact delta invariant: reverting new->old once must reproduce the byte-identical preimage.
        reverted = after_text.replace(mutation["new"], mutation["old"], mutation["replacement_count"]).encode("utf-8")
        audit.add(
            f"mutation.{ident}.exact_delta",
            "PASS" if reverted == before else "ERROR",
            "single exact replacement only",
            "single exact replacement only" if reverted == before else "additional drift",
        )

        rel = Path(mutation["workspace_path"])
        out = evidence / "candidates" / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(after)

        post_sha = sha256_bytes(after)
        post_blob = git_blob_bytes(after)
        audit.add(f"mutation.{ident}.candidate_written", "PASS", str(out), str(out))
        audit.add(
            f"mutation.{ident}.postimage_sha256",
            "PASS" if post_sha == mutation["postimage_sha256"] else "ERROR",
            mutation["postimage_sha256"],
            post_sha,
        )
        audit.add(
            f"mutation.{ident}.postimage_git_blob",
            "PASS" if post_blob == mutation["postimage_git_blob"] else "ERROR",
            mutation["postimage_git_blob"],
            post_blob,
        )

        diff = "".join(
            difflib.unified_diff(
                before_text.splitlines(keepends=True),
                after_text.splitlines(keepends=True),
                fromfile=mutation["workspace_path"],
                tofile=mutation["workspace_path"] + ".candidate",
            )
        )
        diff_chunks.append(diff)
        results.append({
            "id": ident,
            "source": mutation["workspace_path"],
            "preimage_sha256": sha256_bytes(before),
            "preimage_git_blob": actual_blob,
            "postimage_sha256": post_sha,
            "postimage_git_blob": post_blob,
        })

        # Source immutability after candidate materialization.
        after_source = read_bounded(source)
        audit.add(
            f"mutation.{ident}.workspace_unchanged",
            "PASS" if after_source == before else "ERROR",
            sha256_bytes(before),
            sha256_bytes(after_source),
        )

    (evidence / "SOURCE_MUTATION.patch").write_text("\n".join(diff_chunks), encoding="utf-8")
    audit.add("mutation.plan.cardinality", "PASS" if len(results) == 2 else "ERROR", 2, len(results))
    return results


def validate_keygen_contract(workspace: Path, contract: dict[str, Any], audit: Audit) -> None:
    audit.add("keygen.schema_version", "PASS" if contract.get("schema_version") == 1 else "ERROR", 1, contract.get("schema_version"))
    audit.add("keygen.device", "PASS" if contract.get("device") == "panther" else "ERROR", "panther", contract.get("device"))
    audit.add("keygen.status", "PASS" if contract.get("status") == "STATIC_CONTRACT_ONLY_NO_KEY_GENERATION" else "ERROR", "STATIC_CONTRACT_ONLY_NO_KEY_GENERATION", contract.get("status"))
    audit.add("keygen.certificate_subject", "PASS" if contract.get("certificate_subject") == "CN=SableOS" else "ERROR", "CN=SableOS", contract.get("certificate_subject"))
    audit.add("keygen.signing_domains", "PASS" if contract.get("signing_key_domains") == SIGNING_DOMAINS else "ERROR", SIGNING_DOMAINS, contract.get("signing_key_domains"))

    req = contract.get("production_harness_requirements", {})
    expected_req = {
        "sable_owned_harness": True,
        "raw_private_key_staging": "TMPFS_ONLY",
        "persistent_key_store": "OFFLINE_ENCRYPTED_EXTERNAL_TO_ANDROID_WORKSPACE",
        "persistent_workspace_key_material": False,
        "passphrase_prompt_hidden": True,
        "passphrase_in_argv": False,
        "passphrase_in_environment": False,
        "passphrase_in_logs": False,
        "passphrase_child_transport": "INHERITED_FILE_DESCRIPTOR_OR_EQUIVALENT_NON_ARGV_NON_ENV_CHANNEL",
        "apk_key_algorithm": "RSA_4096",
        "apk_cert_digest": "SHA256",
        "apk_cert_validity_days": 10000,
        "apk_private_format": "PKCS8_DER_SCRYPT_ENCRYPTED",
        "avb_algorithm": "SHA256_RSA4096",
        "atomic_external_publish_after_complete_inventory": True,
        "refuse_existing_destination": True,
        "operator_authorization_required": True,
        "signing_session_audit_required": True,
    }
    for key, expected in expected_req.items():
        actual = req.get(key)
        audit.add(f"keygen.requirement.{key}", "PASS" if actual == expected else "ERROR", expected, actual)

    upstream = contract.get("upstream_make_key", {})
    make_key = workspace / upstream.get("workspace_path", "")
    if not make_key.is_file():
        audit.add("keygen.upstream_make_key.exists", "ERROR", True, False, str(make_key))
    else:
        data = read_bounded(make_key)
        blob = git_blob_bytes(data)
        audit.add("keygen.upstream_make_key.git_blob", "PASS" if blob == upstream.get("git_blob") else "ERROR", upstream.get("git_blob"), blob)
        text = data.decode("utf-8", errors="strict")
        visible_prompt = "password will be visible" in text
        echo_secret = "creating ${1}.pk8 with password [${password}]" in text
        named_pipe = "named pipes" in text and "mknod ${one} p" in text and "mknod ${two} p" in text
        audit.add("keygen.upstream_make_key.visible_password_prompt", "PASS" if visible_prompt else "ERROR", True, visible_prompt, "Known upstream safety finding; production use with a password is forbidden by contract.")
        audit.add("keygen.upstream_make_key.password_echo", "PASS" if echo_secret else "ERROR", True, echo_secret, "Known upstream safety finding; production harness must not call this path with a production passphrase.")
        audit.add("keygen.upstream_make_key.raw_key_named_pipes", "PASS" if named_pipe else "ERROR", True, named_pipe)

    forbidden_workspace_keys = workspace / "keys" / "panther"
    audit.add(
        "keygen.workspace_panther_keydir_absent",
        "PASS" if not forbidden_workspace_keys.exists() else "ERROR",
        False,
        forbidden_workspace_keys.exists(),
        str(forbidden_workspace_keys),
    )

    priv = contract.get("expected_private_inventory", [])
    pub = contract.get("expected_public_inventory", [])
    audit.add("keygen.inventory.private_count", "PASS" if len(priv) == 11 and len(set(priv)) == len(priv) else "ERROR", 11, len(priv))
    audit.add("keygen.inventory.public_count", "PASS" if len(pub) == 11 and len(set(pub)) == len(pub) else "ERROR", 11, len(pub))
    audit.add("keygen.execution_authorized", "PASS" if contract.get("execution_authorized") is False else "ERROR", False, contract.get("execution_authorized"))


def write_evidence(evidence_root: Path, audit: Audit, metadata: dict[str, Any]) -> Path:
    evidence_root.mkdir(parents=True, exist_ok=True)
    evidence = Path(tempfile.mkdtemp(prefix="SABLE_R1_R2_STATIC_PREFLIGHT_", dir=evidence_root))
    # Caller may already have created an evidence dir for candidates. This helper is for tests only.
    payload = {
        "metadata": metadata,
        "checks": [c.__dict__ for c in audit.checks],
    }
    (evidence / "audit.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return evidence


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="SableOS R1-R2 static source-mutation/keygen-contract preflight")
    p.add_argument("--workspace", type=Path, default=DEFAULT_WORKSPACE)
    p.add_argument("--plan", type=Path, default=DEFAULT_PLAN)
    p.add_argument("--keygen-contract", type=Path, default=DEFAULT_KEYGEN)
    p.add_argument("--policy", type=Path, default=DEFAULT_POLICY)
    p.add_argument("--evidence-root", type=Path, default=Path("/tmp"))
    ns = p.parse_args(argv)

    audit = Audit()
    if not check_authorizations(audit):
        audit.emit()
        print("PASS=0 BLOCKER=0 INFO=0 SKIP=0 ERROR=1")
        print("R1_R2_STATIC_PREFLIGHT_EXECUTION=ERROR")
        print("R1_R2_STATIC_READINESS=UNKNOWN")
        return 2

    try:
        workspace = ns.workspace.resolve()
        audit.add("workspace.exists", "PASS" if workspace.is_dir() else "ERROR", True, workspace.is_dir(), str(workspace))
        audit.add("plan.exists", "PASS" if ns.plan.is_file() else "ERROR", True, ns.plan.is_file(), str(ns.plan))
        audit.add("keygen_contract.exists", "PASS" if ns.keygen_contract.is_file() else "ERROR", True, ns.keygen_contract.is_file(), str(ns.keygen_contract))
        audit.add("policy.exists", "PASS" if ns.policy.is_file() else "ERROR", True, ns.policy.is_file(), str(ns.policy))
        if audit.count("ERROR"):
            raise RuntimeError("required input missing")

        plan_bytes = read_bounded(ns.plan)
        keygen_bytes = read_bounded(ns.keygen_contract)
        plan_sha = sha256_bytes(plan_bytes)
        keygen_sha = sha256_bytes(keygen_bytes)
        audit.add("plan.sha256", "PASS" if plan_sha == EXPECTED_PLAN_SHA256 else "ERROR", EXPECTED_PLAN_SHA256, plan_sha)
        audit.add("keygen_contract.sha256", "PASS" if keygen_sha == EXPECTED_KEYGEN_CONTRACT_SHA256 else "ERROR", EXPECTED_KEYGEN_CONTRACT_SHA256, keygen_sha)
        plan = json.loads(plan_bytes.decode("utf-8"))
        keygen = json.loads(keygen_bytes.decode("utf-8"))
        if not isinstance(plan, dict) or not isinstance(keygen, dict):
            raise ValueError("plan/keygen contract must be JSON objects")
        validate_policy(ns.policy, plan, audit)

        ns.evidence_root.mkdir(parents=True, exist_ok=True)
        evidence = Path(tempfile.mkdtemp(prefix="SABLE_R1_R2_STATIC_PREFLIGHT_", dir=ns.evidence_root))
        results = validate_source_and_materialize(workspace, plan, evidence, audit)
        validate_keygen_contract(workspace, keygen, audit)

        for action in (
            "source_mutation",
            "key_generation",
            "user_release_build",
            "sign_target_files",
            "ota_generation",
            "factory_image_generation",
            "device_contact",
        ):
            audit.add(f"action.{action}", "INFO", "NOT_RUN", "NOT_RUN")

        metadata = {
            "workspace": str(workspace),
            "plan": str(ns.plan),
            "keygen_contract": str(ns.keygen_contract),
            "policy": str(ns.policy),
            "candidates": results,
        }
        (evidence / "audit.json").write_text(
            json.dumps({"metadata": metadata, "checks": [c.__dict__ for c in audit.checks]}, indent=2) + "\n",
            encoding="utf-8",
        )
        sums: list[str] = []
        for path in sorted(p for p in evidence.rglob("*") if p.is_file()):
            sums.append(f"{sha256_bytes(path.read_bytes())}  {path.relative_to(evidence)}")
        (evidence / "SHA256SUMS").write_text("\n".join(sums) + "\n", encoding="utf-8")

        audit.emit()
        passes = audit.count("PASS")
        blockers = audit.count("BLOCKER")
        infos = audit.count("INFO")
        errors = audit.count("ERROR")
        print(f"PASS={passes} BLOCKER={blockers} INFO={infos} SKIP=0 ERROR={errors}")
        print(f"EVIDENCE_DIR={evidence}")
        if errors:
            print("R1_R2_STATIC_PREFLIGHT_EXECUTION=ERROR")
            print("R1_R2_STATIC_READINESS=UNKNOWN")
            return 2
        print("R1_R2_STATIC_PREFLIGHT_EXECUTION=PASS")
        if blockers:
            print(f"R1_R2_STATIC_READINESS=BLOCKED_{blockers}")
            return 3
        print("R1_R2_STATIC_READINESS=READY_TO_REQUEST_SOURCE_MUTATION_AUTHORIZATION")
        return 0
    except Exception as exc:
        if not any(c.id == "runtime.exception" for c in audit.checks):
            audit.add("runtime.exception", "ERROR", "no exception", f"{type(exc).__name__}: {exc}")
        audit.emit()
        print(f"PASS={audit.count('PASS')} BLOCKER={audit.count('BLOCKER')} INFO={audit.count('INFO')} SKIP=0 ERROR={audit.count('ERROR')}")
        print("R1_R2_STATIC_PREFLIGHT_EXECUTION=ERROR")
        print("R1_R2_STATIC_READINESS=UNKNOWN")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
