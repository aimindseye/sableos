#!/usr/bin/env python3
"""Read-only SableOS R1-R1 release-policy and custody preflight.

R1-R1 validates policy/configuration required before any production signing key
is generated. It does not generate keys, build Android, sign artifacts, create
OTAs, contact a device, reboot, flash, change slots, lock/unlock a bootloader,
or wipe data.

Exit codes:
  0  policy/config complete; eligible to REQUEST separate keygen authorization
  2  audit incomplete / ERROR
  3  audit complete; one or more policy BLOCKERs remain
"""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import re
import subprocess
import tempfile
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from urllib.parse import urlsplit

EXPECTED_DEVICE = "panther"
EXPECTED_GRAPHENE_TAG = "2026081300"
EXPECTED_MANIFEST_SHA256 = "c50f0096f538e604aa008e8ab4e3f1a3739f142c60c878a32f402c11eb406572"
EXPECTED_SCRIPT_HEAD = "b54206456a15f1c1ef5776b752d2705fe75f1b0a"
EXPECTED_UPDATER_HEAD = "d7e29f110890de68b63bb8c256b4d249a2d29cf9"

EXPECTED_BLOBS = {
    "script/common.sh": "19438ba98adeeab5176cb02f20e194f9da1f90e6",
    "script/generate-keys": "5c38a53eeda4eb16c55bd3a3ad776a3cb1d6349e",
    "script/encrypt-keys": "90ab9b0cda1fbbd81e9fbbd48d352ab2e3edc3ad",
    "script/decrypt-keys": "b621d1e02c1091089bd8e0d09c227d8f8e5006b5",
    "script/generate-release.sh": "736dfd1d3b2924a632c74db0dc940a8e0cb4d58d",
    "packages/apps/Updater/res/values/config.xml": "b3804bbeb82f3f6abda53f6401f8d1119dd5416d",
}

SIGNING_KEYS = (
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

EXPECTED_MUTATION_PATHS = (
    "script/generate-keys",
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

REQUIRED_CUSTODY_TRUE = (
    "unique_per_device_variant",
    "private_keys_outside_git",
    "encrypted_at_rest",
    "offline_backup_count_at_least_2",
    "backups_physically_separated",
    "operator_authorization_required",
    "signing_session_audit_required",
    "decrypted_workdir_tmpfs",
    "passphrase_not_in_argv",
    "passphrase_not_in_repo",
    "private_key_material_not_in_public_evidence",
    "private_key_hashes_not_in_public_evidence",
)

SOURCE_SEAL_REQUIRED_FIELDS = (
    "schema_version",
    "device",
    "graphene_manifest_tag",
    "pinned_manifest_sha256",
    "pinned_repo_manifest",
    "sable_tools_commit",
    "sable_delta_commits",
    "release_policy_sha256",
    "updater_config_sha256",
    "release_tooling_heads",
    "vendor_state_commit",
    "build_number",
    "build_variant",
    "official_build",
    "build_datetime_policy",
    "host_tool_hashes",
)

FORBIDDEN_EXECUTABLES = {
    "adb",
    "fastboot",
    "m",
    "make",
    "ninja",
    "soong_ui",
    "make_key",
    "sign_target_files_apks",
    "ota_from_target_files",
    "img_from_target_files",
    "avbtool",
    "openssl",
    "ssh-keygen",
}


@dataclass(frozen=True)
class Check:
    id: str
    status: str
    expected: object
    actual: object
    detail: str = ""


class Audit:
    def __init__(self) -> None:
        self.checks: list[Check] = []

    def add(self, ident: str, status: str, expected: object, actual: object, detail: str = "") -> None:
        self.checks.append(Check(ident, status, expected, actual, detail))

    def count(self, status: str) -> int:
        return sum(c.status == status for c in self.checks)


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


def run_readonly(argv: list[str], cwd: Path | None = None, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    if not argv or argv[0] not in {"git", "repo"}:
        raise RuntimeError(f"R1-R1 subprocess not allowlisted: {argv!r}")
    if argv[0] in FORBIDDEN_EXECUTABLES:
        raise RuntimeError(f"forbidden executable: {argv[0]}")
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


def ensure_read_only_authorization(audit: Audit) -> bool:
    bad = []
    for name in FORBIDDEN_AUTH:
        value = os.environ.get(name, "NO")
        if value != "NO":
            bad.append(f"{name}={value}")
    if bad:
        audit.add(
            "authorization.read_only_boundary",
            "ERROR",
            "all mutation/device authorizations NO",
            ", ".join(bad),
            "R1-R1 only validates policy/configuration and refuses a mutating authorization context.",
        )
        return False
    audit.add("authorization.read_only_boundary", "PASS", "all mutation/device authorizations NO", "all NO")
    return True


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_signing_keys(path: Path) -> tuple[str, ...]:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"readonly\s+signing_keys=\((.*?)\n\)", text, re.S)
    if not match:
        return ()
    out = []
    for raw in match.group(1).splitlines():
        item = raw.strip()
        if item and not item.startswith("#"):
            out.append(item)
    return tuple(out)


def parse_generator_subject(path: Path) -> str | None:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        r"^\s*CN\s*=\s*(?:\"([^\"]+)\"|'([^']+)'|([^\s#]+))\s*(?:#.*)?$",
        text,
        re.M,
    )
    if not match:
        return None
    return next(group.strip() for group in match.groups() if group is not None)


def parse_updater_url(path: Path) -> str | None:
    text = path.read_text(encoding="utf-8")
    match = re.search(r'<string\s+name="url"[^>]*>([^<]+)</string>', text)
    return match.group(1).strip() if match else None


def validate_update_endpoint(policy: dict, audit: Audit) -> None:
    ep = policy.get("update_endpoint")
    if not isinstance(ep, dict):
        audit.add("policy.update_endpoint", "ERROR", "object", type(ep).__name__)
        return

    url = ep.get("url")
    owner = ep.get("owner")
    ownership = ep.get("ownership_status")

    if url in (None, "", "UNSET"):
        audit.add(
            "policy.update_endpoint",
            "BLOCKER",
            "operator-selected Sable-owned HTTPS base URL",
            "UNSET",
            "No hostname is invented. Supply a real endpoint only after ownership/control is established.",
        )
        return

    if not isinstance(url, str):
        audit.add("policy.update_endpoint", "ERROR", "string URL", type(url).__name__)
        return

    parsed = urlsplit(url)
    host = (parsed.hostname or "").lower()
    bad = []
    if parsed.scheme != "https":
        bad.append("scheme_not_https")
    if not host:
        bad.append("hostname_missing")
    if host == "releases.grapheneos.org" or host.endswith(".grapheneos.org"):
        bad.append("grapheneos_host_forbidden")
    if host in {"localhost"} or host.endswith((".localhost", ".local", ".invalid", ".test", ".example")):
        bad.append("nonproduction_hostname_forbidden")
    try:
        ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        bad.append("ip_literal_forbidden")
    if parsed.username or parsed.password:
        bad.append("userinfo_forbidden")
    if parsed.query or parsed.fragment:
        bad.append("query_or_fragment_forbidden")
    if not url.endswith("/"):
        bad.append("base_url_must_end_slash")
    if owner != "SableOS":
        bad.append("owner_not_SableOS")
    if ownership != "OPERATOR_VERIFIED":
        bad.append("ownership_not_operator_verified")

    if bad:
        audit.add("policy.update_endpoint", "BLOCKER", "owned Sable HTTPS base URL", url, ",".join(bad))
    else:
        audit.add("policy.update_endpoint", "PASS", "owned Sable HTTPS base URL", url)


def validate_policy(policy: object, schema: object, audit: Audit) -> None:
    if not isinstance(policy, dict):
        audit.add("policy.object", "ERROR", "JSON object", type(policy).__name__)
        return
    audit.add("policy.object", "PASS", "JSON object", "object")

    audit.add(
        "policy.schema_version",
        "PASS" if policy.get("schema_version") == 1 else "ERROR",
        1,
        policy.get("schema_version"),
    )
    audit.add(
        "policy.device",
        "PASS" if policy.get("device") == EXPECTED_DEVICE else "ERROR",
        EXPECTED_DEVICE,
        policy.get("device"),
    )

    substrate = policy.get("substrate")
    if not isinstance(substrate, dict):
        audit.add("policy.substrate", "ERROR", "object", type(substrate).__name__)
    else:
        for ident, expected, actual in (
            ("policy.graphene_tag", EXPECTED_GRAPHENE_TAG, substrate.get("graphene_manifest_tag")),
            ("policy.manifest_sha256", EXPECTED_MANIFEST_SHA256, substrate.get("pinned_manifest_sha256")),
        ):
            audit.add(ident, "PASS" if actual == expected else "ERROR", expected, actual)

    subject = policy.get("certificate_subject")
    audit.add(
        "policy.certificate_subject",
        "PASS" if subject == "CN=SableOS" else "BLOCKER",
        "CN=SableOS",
        subject,
        "R1-R1 adopts a Sable-owned certificate identity instead of upstream CN=GrapheneOS.",
    )

    domains = policy.get("signing_key_domains")
    expected_domains = list(SIGNING_KEYS)
    audit.add(
        "policy.signing_key_domains",
        "PASS" if domains == expected_domains else "ERROR",
        expected_domains,
        domains,
    )

    custody = policy.get("key_custody")
    if not isinstance(custody, dict):
        audit.add("policy.key_custody", "ERROR", "object", type(custody).__name__)
    else:
        for key in REQUIRED_CUSTODY_TRUE:
            actual = custody.get(key)
            audit.add(f"custody.{key}", "PASS" if actual is True else "ERROR", True, actual)
        for ident, expected, actual in (
            (
                "custody.persistent_store_class",
                "OFFLINE_ENCRYPTED_EXTERNAL_TO_WORKSPACE",
                custody.get("persistent_store_class"),
            ),
            (
                "custody.signing_workspace_binding",
                "EPHEMERAL_KEYS_PANTHER_BINDING_ONLY_DURING_AUTHORIZED_SIGNING",
                custody.get("signing_workspace_binding"),
            ),
        ):
            audit.add(ident, "PASS" if actual == expected else "ERROR", expected, actual)

    build = policy.get("build_policy")
    if not isinstance(build, dict):
        audit.add("policy.build_policy", "ERROR", "object", type(build).__name__)
    else:
        for ident, expected, actual in (
            ("build.variant", "user", build.get("variant")),
            ("build.official_build", True, build.get("official_build")),
            ("build.build_number_scheme", "YYYYMMDDRR", build.get("build_number_scheme")),
            ("build.build_number_reuse", False, build.get("build_number_reuse")),
            ("build.testing_channel_first", True, build.get("testing_channel_first")),
            ("build.future_update_path_test", True, build.get("future_update_path_test")),
        ):
            audit.add(ident, "PASS" if actual == expected else "ERROR", expected, actual)

    mutation_plan = policy.get("planned_source_mutations")
    expected_mutations = [
        {
            "path": "script/generate-keys",
            "preimage": "CN=GrapheneOS",
            "postimage": "CN=SableOS",
            "authorization_required": "SOURCE_MUTATION_AUTHORIZED=YES",
        },
        {
            "path": "packages/apps/Updater/res/values/config.xml",
            "preimage": "https://releases.grapheneos.org/",
            "postimage_from": "update_endpoint.url",
            "authorization_required": "SOURCE_MUTATION_AUTHORIZED=YES",
        },
    ]
    if not isinstance(mutation_plan, list):
        audit.add("policy.planned_source_mutations", "ERROR", expected_mutations, type(mutation_plan).__name__)
    else:
        audit.add(
            "policy.planned_source_mutations",
            "PASS" if mutation_plan == expected_mutations else "ERROR",
            expected_mutations,
            mutation_plan,
            "R1-R1 validates the exact two-file plan only and applies neither mutation.",
        )

    inventory = policy.get("future_key_inventory")
    if not isinstance(inventory, dict):
        audit.add("policy.future_key_inventory", "ERROR", "object", type(inventory).__name__)
    else:
        for ident, expected, actual in (
            ("key_inventory.apk_certificate_pairs", list(SIGNING_KEYS), inventory.get("apk_certificate_pairs")),
            ("key_inventory.avb_private_key", "avb.pem", inventory.get("avb_private_key")),
            ("key_inventory.avb_public_metadata", "avb_pkmd.bin", inventory.get("avb_public_metadata")),
            ("key_inventory.factory_archive_signing_key", "id_ed25519", inventory.get("factory_archive_signing_key")),
        ):
            audit.add(ident, "PASS" if actual == expected else "ERROR", expected, actual)

    audit.add(
        "policy.source_seal_schema_path",
        "PASS" if policy.get("source_seal_schema") == "release/r1/release-source-seal-v1.schema.json" else "ERROR",
        "release/r1/release-source-seal-v1.schema.json",
        policy.get("source_seal_schema"),
    )

    validate_update_endpoint(policy, audit)

    if not isinstance(schema, dict):
        audit.add("source_seal.schema", "ERROR", "JSON object", type(schema).__name__)
    else:
        audit.add(
            "source_seal.schema_version",
            "PASS" if schema.get("schema_version") == 1 else "ERROR",
            1,
            schema.get("schema_version"),
        )
        actual_required = schema.get("required")
        audit.add(
            "source_seal.required_fields",
            "PASS" if actual_required == list(SOURCE_SEAL_REQUIRED_FIELDS) else "ERROR",
            list(SOURCE_SEAL_REQUIRED_FIELDS),
            actual_required,
        )
        rules = schema.get("rules")
        expected_rules = {
            "device": "panther",
            "build_variant": "user",
            "official_build": True,
            "build_number_format": "^[0-9]{10}$",
            "build_number_semantics": "YYYYMMDDRR and never reused",
            "private_key_material": "MUST_NOT_APPEAR",
            "private_key_hashes": "MUST_NOT_APPEAR",
        }
        audit.add(
            "source_seal.rules",
            "PASS" if rules == expected_rules else "ERROR",
            expected_rules,
            rules,
        )


def git_head(repo: Path) -> tuple[int, str]:
    cp = run_readonly(["git", "-C", str(repo), "rev-parse", "HEAD"])
    return cp.returncode, cp.stdout.strip()


def git_blob(repo: Path, rel: str) -> tuple[int, str]:
    cp = run_readonly(["git", "-C", str(repo), "hash-object", rel])
    return cp.returncode, cp.stdout.strip()


def validate_source_contract(workspace: Path, audit: Audit) -> None:
    script_repo = workspace / "script"
    updater_repo = workspace / "packages/apps/Updater"

    for ident, repo, expected in (
        ("source.script_head", script_repo, EXPECTED_SCRIPT_HEAD),
        ("source.updater_head", updater_repo, EXPECTED_UPDATER_HEAD),
    ):
        rc, actual = git_head(repo)
        audit.add(ident, "PASS" if rc == 0 and actual == expected else "ERROR", expected, actual if rc == 0 else f"rc={rc}")

    for rel, expected_blob in EXPECTED_BLOBS.items():
        if rel.startswith("script/"):
            repo = script_repo
            local_rel = rel.split("/", 1)[1]
        else:
            repo = updater_repo
            local_rel = "res/values/config.xml"
        rc, actual = git_blob(repo, local_rel)
        audit.add(
            "source.blob." + rel.replace("/", "."),
            "PASS" if rc == 0 and actual == expected_blob else "ERROR",
            expected_blob,
            actual if rc == 0 else f"rc={rc}",
        )

    common = workspace / "script/common.sh"
    generate_keys = workspace / "script/generate-keys"
    generate_release = workspace / "script/generate-release.sh"
    encrypt_keys = workspace / "script/encrypt-keys"
    decrypt_keys = workspace / "script/decrypt-keys"
    updater = workspace / "packages/apps/Updater/res/values/config.xml"

    actual_domains = parse_signing_keys(common)
    audit.add(
        "source.signing_key_domains",
        "PASS" if actual_domains == SIGNING_KEYS else "ERROR",
        list(SIGNING_KEYS),
        list(actual_domains),
    )

    current_subject = parse_generator_subject(generate_keys)
    audit.add(
        "source.current_generator_subject",
        "PASS" if current_subject == "GrapheneOS" else "ERROR",
        "GrapheneOS",
        current_subject,
        "PASS binds the known upstream preimage; the future authorized mutation changes it to SableOS.",
    )

    current_url = parse_updater_url(updater)
    audit.add(
        "source.current_updater_url",
        "PASS" if current_url == "https://releases.grapheneos.org/" else "ERROR",
        "https://releases.grapheneos.org/",
        current_url,
        "PASS binds the known upstream preimage; the future authorized mutation replaces it with the Sable endpoint.",
    )

    release_text = generate_release.read_text(encoding="utf-8")
    release_tokens = (
        "PERSISTENT_KEY_DIR=keys/$DEVICE",
        "mktemp -d /dev/shm/generate-release.",
        'script/decrypt-keys "$KEY_DIR"',
        "sign_target_files_apks",
        "ota_from_target_files",
        "img_from_target_files",
        'if [[ -f "$KEY_DIR/id_ed25519" ]]',
    )
    missing = [token for token in release_tokens if token not in release_text]
    audit.add(
        "source.release_flow_contract",
        "PASS" if not missing else "ERROR",
        "all pinned release-flow tokens",
        "bound" if not missing else missing,
    )

    for ident, path, token in (
        ("source.encrypt_tmpfs", encrypt_keys, "/dev/shm/encrypt-keys."),
        ("source.decrypt_tmpfs", decrypt_keys, "/dev/shm/decrypt-keys."),
    ):
        text = path.read_text(encoding="utf-8")
        audit.add(ident, "PASS" if token in text else "ERROR", token, token if token in text else "missing")


def write_evidence(root: Path, audit: Audit, context: dict[str, object]) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    out = Path(tempfile.mkdtemp(prefix=f"SABLE_R1_R1_POLICY_PREFLIGHT_{ts}_", dir=str(root)))
    os.chmod(out, 0o700)
    payload = {
        "schema_version": 1,
        "context": context,
        "checks": [asdict(c) for c in audit.checks],
        "summary": {status.lower(): audit.count(status) for status in ("PASS", "BLOCKER", "INFO", "SKIP", "ERROR")},
    }
    report = out / "report.json"
    report.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out / "SHA256SUMS").write_text(f"{sha256_file(report)}  report.json\n", encoding="utf-8")
    return out


def build_parser() -> argparse.ArgumentParser:
    repo_root = Path(__file__).resolve().parents[3]
    workspace = Path("/srv/data/sableos_panther_graphene_2026081300_workspace")
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--workspace", type=Path, default=workspace)
    p.add_argument("--policy", type=Path, default=repo_root / "release/r1/panther-release-policy-v1.json")
    p.add_argument("--source-seal-schema", type=Path, default=repo_root / "release/r1/release-source-seal-v1.schema.json")
    p.add_argument("--evidence-root", type=Path, default=Path("/tmp"))
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    audit = Audit()

    if not ensure_read_only_authorization(audit):
        print("[ERROR  ] authorization.read_only_boundary")
        print("R1_R1_POLICY_EXECUTION=ERROR")
        print("R1_R1_POLICY_READINESS=UNKNOWN")
        return 2

    workspace = args.workspace.resolve()
    policy_path = args.policy.resolve()
    schema_path = args.source_seal_schema.resolve()

    for ident, path, kind in (
        ("workspace.exists", workspace, "dir"),
        ("policy.exists", policy_path, "file"),
        ("source_seal_schema.exists", schema_path, "file"),
    ):
        ok = path.is_dir() if kind == "dir" else path.is_file()
        audit.add(ident, "PASS" if ok else "ERROR", True, ok, str(path))

    policy: object = {}
    schema: object = {}
    if audit.count("ERROR") == 0:
        try:
            policy = load_json(policy_path)
            schema = load_json(schema_path)
        except (OSError, json.JSONDecodeError) as exc:
            audit.add("input.json_parse", "ERROR", "valid JSON", str(exc))

    if audit.count("ERROR") == 0:
        validate_policy(policy, schema, audit)
        validate_source_contract(workspace, audit)

    for ident in (
        "key_generation",
        "source_mutation",
        "user_release_build",
        "sign_target_files",
        "ota_generation",
        "factory_image_generation",
        "device_contact",
        "device_install",
        "bootloader_lock",
    ):
        audit.add(f"action.{ident}", "INFO", "NOT_RUN", "NOT_RUN")

    context = {
        "workspace": str(workspace),
        "policy": str(policy_path),
        "policy_sha256": sha256_file(policy_path) if policy_path.is_file() else None,
        "source_seal_schema": str(schema_path),
        "source_seal_schema_sha256": sha256_file(schema_path) if schema_path.is_file() else None,
        "script_sha256": sha256_file(Path(__file__)),
        "expected_device": EXPECTED_DEVICE,
        "expected_graphene_tag": EXPECTED_GRAPHENE_TAG,
    }
    evidence_dir = write_evidence(args.evidence_root, audit, context)

    for check in audit.checks:
        detail = f" ({check.detail})" if check.detail else ""
        print(f"[{check.status:<7}] {check.id}: expected={check.expected!r} actual={check.actual!r}{detail}")

    print()
    print(
        f"PASS={audit.count('PASS')} BLOCKER={audit.count('BLOCKER')} "
        f"INFO={audit.count('INFO')} SKIP={audit.count('SKIP')} ERROR={audit.count('ERROR')}"
    )
    print(f"EVIDENCE_DIR={evidence_dir}")

    if audit.count("ERROR"):
        print("R1_R1_POLICY_EXECUTION=ERROR")
        print("R1_R1_POLICY_READINESS=UNKNOWN")
        return 2

    print("R1_R1_POLICY_EXECUTION=PASS")
    if audit.count("BLOCKER"):
        print(f"R1_R1_POLICY_READINESS=BLOCKED_{audit.count('BLOCKER')}")
        return 3

    print("R1_R1_POLICY_READINESS=READY_TO_REQUEST_KEYGEN_AUTHORIZATION")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
