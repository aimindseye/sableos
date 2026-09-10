from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
from unittest import mock

import pytest

SCRIPT = Path(__file__).with_name("SABLE_R1_R1_POLICY_PREFLIGHT.py")
spec = importlib.util.spec_from_file_location("r1r1", SCRIPT)
assert spec and spec.loader
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)

REPO_ROOT = Path(__file__).resolve().parents[3]
POLICY = REPO_ROOT / "release/r1/panther-release-policy-v1.json"
SCHEMA = REPO_ROOT / "release/r1/release-source-seal-v1.schema.json"


def git(cwd: Path, *args: str) -> str:
    cp = subprocess.run(["git", *args], cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return cp.stdout.strip()


def write_sources(ws: Path) -> tuple[Path, Path]:
    script = ws / "script"
    updater = ws / "packages/apps/Updater"
    script.mkdir(parents=True)
    updater.mkdir(parents=True)

    (script / "common.sh").write_text(
        "readonly signing_keys=(\n" + "".join(f"    {x}\n" for x in m.SIGNING_KEYS) + ")\n",
        encoding="utf-8",
    )
    (script / "generate-keys").write_text(
        "#!/bin/bash\n    CN=GrapheneOS\n../../development/tools/make_key x \"/CN=$CN/\"\n",
        encoding="utf-8",
    )
    (script / "encrypt-keys").write_text("tmp=$(mktemp -d /dev/shm/encrypt-keys.XXXXXXXXXX)\n", encoding="utf-8")
    (script / "decrypt-keys").write_text("tmp=$(mktemp -d /dev/shm/decrypt-keys.XXXXXXXXXX)\n", encoding="utf-8")
    (script / "generate-release.sh").write_text(
        "\n".join(
            [
                "PERSISTENT_KEY_DIR=keys/$DEVICE",
                "KEY_DIR=$(mktemp -d /dev/shm/generate-release.XXXXXXXXXX)",
                'script/decrypt-keys "$KEY_DIR"',
                "sign_target_files_apks x",
                "ota_from_target_files x",
                "img_from_target_files x",
                'if [[ -f "$KEY_DIR/id_ed25519" ]]; then echo yes; fi',
            ]
        ) + "\n",
        encoding="utf-8",
    )
    config = updater / "res/values/config.xml"
    config.parent.mkdir(parents=True)
    config.write_text(
        '<resources><string name="url" translatable="false">https://releases.grapheneos.org/</string></resources>\n',
        encoding="utf-8",
    )

    for repo in (script, updater):
        git(repo, "init", "-q")
        git(repo, "config", "user.email", "test@example.invalid")
        git(repo, "config", "user.name", "test")
        git(repo, "add", ".")
        git(repo, "commit", "-q", "-m", "fixture")
    return script, updater


def bind_fixture(monkeypatch, ws: Path) -> None:
    script, updater = write_sources(ws)
    monkeypatch.setattr(m, "EXPECTED_SCRIPT_HEAD", git(script, "rev-parse", "HEAD"))
    monkeypatch.setattr(m, "EXPECTED_UPDATER_HEAD", git(updater, "rev-parse", "HEAD"))
    blobs = {
        "script/common.sh": git(script, "hash-object", "common.sh"),
        "script/generate-keys": git(script, "hash-object", "generate-keys"),
        "script/encrypt-keys": git(script, "hash-object", "encrypt-keys"),
        "script/decrypt-keys": git(script, "hash-object", "decrypt-keys"),
        "script/generate-release.sh": git(script, "hash-object", "generate-release.sh"),
        "packages/apps/Updater/res/values/config.xml": git(updater, "hash-object", "res/values/config.xml"),
    }
    monkeypatch.setattr(m, "EXPECTED_BLOBS", blobs)


def load_policy() -> dict:
    return json.loads(POLICY.read_text(encoding="utf-8"))


def load_schema() -> dict:
    return json.loads(SCHEMA.read_text(encoding="utf-8"))


def write_json(path: Path, obj: object) -> None:
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def test_policy_and_schema_json_parse():
    assert load_policy()["schema_version"] == 1
    assert load_schema()["schema_version"] == 1


def test_generator_subject_parser_handles_upstream_indentation(tmp_path: Path):
    p = tmp_path / "generate-keys"
    p.write_text("    CN=GrapheneOS\n", encoding="utf-8")
    assert m.parse_generator_subject(p) == "GrapheneOS"


def test_unset_update_endpoint_is_single_blocker():
    audit = m.Audit()
    m.validate_update_endpoint(load_policy(), audit)
    assert audit.count("BLOCKER") == 1
    assert audit.count("ERROR") == 0


def test_valid_owned_https_endpoint_passes():
    policy = load_policy()
    policy["update_endpoint"] = {
        "url": "https://updates.sableos.invalid-real-domain.example.org/",
        "owner": "SableOS",
        "ownership_status": "OPERATOR_VERIFIED",
    }
    audit = m.Audit()
    m.validate_update_endpoint(policy, audit)
    assert audit.count("PASS") == 1


@pytest.mark.parametrize(
    "url,owner,status",
    [
        ("https://releases.grapheneos.org/", "SableOS", "OPERATOR_VERIFIED"),
        ("http://updates.sable.example/", "SableOS", "OPERATOR_VERIFIED"),
        ("https://updates.sable.example", "SableOS", "OPERATOR_VERIFIED"),
        ("https://user:pass@updates.sable.example/", "SableOS", "OPERATOR_VERIFIED"),
        ("https://updates.sable.example/?x=1", "SableOS", "OPERATOR_VERIFIED"),
        ("https://updates.sable.example/", "Other", "OPERATOR_VERIFIED"),
        ("https://updates.sable.example/", "SableOS", "UNVERIFIED"),
        ("https://localhost/", "SableOS", "OPERATOR_VERIFIED"),
        ("https://127.0.0.1/", "SableOS", "OPERATOR_VERIFIED"),
    ],
)
def test_bad_update_endpoints_block(url: str, owner: str, status: str):
    policy = load_policy()
    policy["update_endpoint"] = {"url": url, "owner": owner, "ownership_status": status}
    audit = m.Audit()
    m.validate_update_endpoint(policy, audit)
    assert audit.count("BLOCKER") == 1


def test_certificate_subject_wrong_is_blocker_not_error():
    policy = load_policy()
    policy["certificate_subject"] = "CN=GrapheneOS"
    audit = m.Audit()
    m.validate_policy(policy, load_schema(), audit)
    got = [c for c in audit.checks if c.id == "policy.certificate_subject"]
    assert len(got) == 1 and got[0].status == "BLOCKER"


def test_signing_domain_drift_is_error():
    policy = load_policy()
    policy["signing_key_domains"] = policy["signing_key_domains"][:-1]
    audit = m.Audit()
    m.validate_policy(policy, load_schema(), audit)
    assert any(c.id == "policy.signing_key_domains" and c.status == "ERROR" for c in audit.checks)


def test_custody_false_is_error():
    policy = load_policy()
    policy["key_custody"]["encrypted_at_rest"] = False
    audit = m.Audit()
    m.validate_policy(policy, load_schema(), audit)
    assert any(c.id == "custody.encrypted_at_rest" and c.status == "ERROR" for c in audit.checks)


def test_build_policy_drift_is_error():
    policy = load_policy()
    policy["build_policy"]["variant"] = "userdebug"
    audit = m.Audit()
    m.validate_policy(policy, load_schema(), audit)
    assert any(c.id == "build.variant" and c.status == "ERROR" for c in audit.checks)


def test_mutation_scope_drift_is_error():
    policy = load_policy()
    policy["planned_source_mutations"].append({"path": "frameworks/base/Android.bp"})
    audit = m.Audit()
    m.validate_policy(policy, load_schema(), audit)
    assert any(c.id == "policy.planned_source_mutations" and c.status == "ERROR" for c in audit.checks)


def test_source_seal_required_field_drift_is_error():
    schema = load_schema()
    schema["required"] = schema["required"][:-1]
    audit = m.Audit()
    m.validate_policy(load_policy(), schema, audit)
    assert any(c.id == "source_seal.required_fields" and c.status == "ERROR" for c in audit.checks)




def test_mutation_semantics_drift_is_error():
    policy = load_policy()
    policy["planned_source_mutations"][0]["postimage"] = "CN=Wrong"
    audit = m.Audit()
    m.validate_policy(policy, load_schema(), audit)
    assert any(c.id == "policy.planned_source_mutations" and c.status == "ERROR" for c in audit.checks)


def test_future_key_inventory_drift_is_error():
    policy = load_policy()
    policy["future_key_inventory"]["factory_archive_signing_key"] = "wrong"
    audit = m.Audit()
    m.validate_policy(policy, load_schema(), audit)
    assert any(c.id == "key_inventory.factory_archive_signing_key" and c.status == "ERROR" for c in audit.checks)


def test_source_seal_rule_drift_is_error():
    schema = load_schema()
    schema["rules"]["official_build"] = False
    audit = m.Audit()
    m.validate_policy(load_policy(), schema, audit)
    assert any(c.id == "source_seal.rules" and c.status == "ERROR" for c in audit.checks)

def test_readonly_subprocess_allowlist_rejects_device_and_build_tools():
    for exe in ("adb", "fastboot", "make", "openssl", "ota_from_target_files"):
        with pytest.raises(RuntimeError, match="not allowlisted"):
            m.run_readonly([exe, "--version"])


def test_source_contract_binds_fixture(monkeypatch, tmp_path: Path):
    ws = tmp_path / "ws"
    bind_fixture(monkeypatch, ws)
    audit = m.Audit()
    m.validate_source_contract(ws, audit)
    assert audit.count("ERROR") == 0
    assert any(c.id == "source.release_flow_contract" and c.status == "PASS" for c in audit.checks)


def test_source_blob_drift_fails_closed(monkeypatch, tmp_path: Path):
    ws = tmp_path / "ws"
    bind_fixture(monkeypatch, ws)
    (ws / "script/generate-keys").write_text("CN=Changed\n", encoding="utf-8")
    audit = m.Audit()
    m.validate_source_contract(ws, audit)
    assert any(c.id == "source.blob.script.generate-keys" and c.status == "ERROR" for c in audit.checks)


def test_release_flow_contract_missing_token_errors(monkeypatch, tmp_path: Path):
    ws = tmp_path / "ws"
    bind_fixture(monkeypatch, ws)
    p = ws / "script/generate-release.sh"
    p.write_text(p.read_text().replace("ota_from_target_files x\n", ""), encoding="utf-8")
    monkeypatch.setitem(m.EXPECTED_BLOBS, "script/generate-release.sh", git(ws / "script", "hash-object", "generate-release.sh"))
    audit = m.Audit()
    m.validate_source_contract(ws, audit)
    assert any(c.id == "source.release_flow_contract" and c.status == "ERROR" for c in audit.checks)


def test_evidence_directories_do_not_collide(tmp_path: Path):
    audit = m.Audit()
    audit.add("x", "PASS", 1, 1)
    a = m.write_evidence(tmp_path, audit, {"n": 1})
    b = m.write_evidence(tmp_path, audit, {"n": 2})
    assert a != b
    assert (a / "SHA256SUMS").is_file()
    assert (b / "SHA256SUMS").is_file()


def test_authorization_rejects_before_workspace_access(tmp_path: Path, monkeypatch, capsys):
    missing = tmp_path / "missing"
    with mock.patch.dict(os.environ, {"KEY_GENERATION_AUTHORIZED": "YES"}, clear=True):
        rc = m.main(["--workspace", str(missing), "--policy", str(missing), "--source-seal-schema", str(missing)])
    assert rc == 2
    assert "R1_R1_POLICY_EXECUTION=ERROR" in capsys.readouterr().out


def test_main_unresolved_endpoint_returns_3(monkeypatch, tmp_path: Path, capsys):
    ws = tmp_path / "ws"
    bind_fixture(monkeypatch, ws)
    policy = tmp_path / "policy.json"
    schema = tmp_path / "schema.json"
    write_json(policy, load_policy())
    write_json(schema, load_schema())
    with mock.patch.dict(os.environ, {}, clear=True):
        rc = m.main([
            "--workspace", str(ws),
            "--policy", str(policy),
            "--source-seal-schema", str(schema),
            "--evidence-root", str(tmp_path / "evidence"),
        ])
    out = capsys.readouterr().out
    assert rc == 3
    assert "ERROR=0" in out
    assert "R1_R1_POLICY_EXECUTION=PASS" in out
    assert "R1_R1_POLICY_READINESS=BLOCKED_1" in out


def test_main_fully_specified_policy_returns_0(monkeypatch, tmp_path: Path, capsys):
    ws = tmp_path / "ws"
    bind_fixture(monkeypatch, ws)
    p = load_policy()
    p["update_endpoint"] = {
        "url": "https://updates.sableos.invalid-real-domain.example.org/",
        "owner": "SableOS",
        "ownership_status": "OPERATOR_VERIFIED",
    }
    policy = tmp_path / "policy.json"
    schema = tmp_path / "schema.json"
    write_json(policy, p)
    write_json(schema, load_schema())
    with mock.patch.dict(os.environ, {}, clear=True):
        rc = m.main([
            "--workspace", str(ws),
            "--policy", str(policy),
            "--source-seal-schema", str(schema),
            "--evidence-root", str(tmp_path / "evidence"),
        ])
    out = capsys.readouterr().out
    assert rc == 0
    assert "ERROR=0" in out
    assert "BLOCKER=0" in out
    assert "READY_TO_REQUEST_KEYGEN_AUTHORIZATION" in out


def test_repeated_main_25_has_stable_blocker_semantics(monkeypatch, tmp_path: Path):
    ws = tmp_path / "ws"
    bind_fixture(monkeypatch, ws)
    policy = tmp_path / "policy.json"
    schema = tmp_path / "schema.json"
    write_json(policy, load_policy())
    write_json(schema, load_schema())
    evidence_root = tmp_path / "evidence"
    with mock.patch.dict(os.environ, {}, clear=True):
        for _ in range(25):
            assert m.main([
                "--workspace", str(ws),
                "--policy", str(policy),
                "--source-seal-schema", str(schema),
                "--evidence-root", str(evidence_root),
            ]) == 3
    dirs = [x for x in evidence_root.iterdir() if x.is_dir()]
    assert len(dirs) == 25


def test_script_has_no_mutating_execution_surface():
    text = SCRIPT.read_text(encoding="utf-8")
    forbidden_literals = (
        "adb reboot",
        "fastboot flash",
        "fastboot erase",
        "flashing unlock",
        "flashing lock",
        "subprocess.Popen",
        "os.system",
        "shell=True",
    )
    for token in forbidden_literals:
        assert token not in text
    # All subprocess execution routes through run_readonly and its git/repo allowlist.
    assert text.count("subprocess.run(") == 1


def test_policy_contains_no_private_material_or_secret_values():
    text = POLICY.read_text(encoding="utf-8")
    policy = load_policy()
    assert "BEGIN PRIVATE KEY" not in text
    assert "BEGIN OPENSSH PRIVATE KEY" not in text
    assert "pkcs8:" not in text.lower()
    # Policy names may mention password/passphrase rules, but no secret value fields are permitted.
    forbidden_keys = {"password", "passphrase", "secret", "private_key_value", "private_key_bytes"}
    def walk(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                assert k.lower() not in forbidden_keys
                walk(v)
        elif isinstance(obj, list):
            for v in obj:
                walk(v)
    walk(policy)


def test_fresh_process_help_path():
    cp = subprocess.run(
        [sys.executable, str(SCRIPT), "--help"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    assert cp.returncode == 0
    assert "release-policy and custody preflight" in cp.stdout
