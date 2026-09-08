from __future__ import annotations

import hashlib
import importlib.util
import os
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from unittest import mock

import pytest

SCRIPT = Path(__file__).with_name("SABLE_R1_R0_RELEASE_PREFLIGHT.py")
spec = importlib.util.spec_from_file_location("r1preflight", SCRIPT)
assert spec and spec.loader
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)


def make_fixture(root: Path, *, malformed_zip: bool = False) -> tuple[Path, Path, Path]:
    ws = root / "ws"
    ws.mkdir()
    for rel in m.REQUIRED_RELEASE_FILES:
        p = ws / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("x\n", encoding="utf-8")
    (ws / "script/common.sh").write_text(
        "readonly signing_keys=(\n" + "".join(f"    {k}\n" for k in m.SIGNING_KEYS_2026081300) + ")\n",
        encoding="utf-8",
    )
    (ws / "script/generate-keys").write_text("#!/bin/bash\nCN=GrapheneOS\n", encoding="utf-8")
    (ws / "script/generate-release.sh").write_text(
        "panther sign_target_files_apks ota_from_target_files img_from_target_files avb_pkmd.bin id_ed25519\n",
        encoding="utf-8",
    )
    updater = ws / "packages/apps/Updater/res/values/config.xml"
    updater.write_text(
        '<?xml version="1.0"?><resources><string name="url" translatable="false">https://releases.grapheneos.org/</string></resources>\n',
        encoding="utf-8",
    )

    lock = root / "BASELINE.lock"
    lock.write_text(
        "\n".join(
            [
                f"SABLE_BASE={m.EXPECTED_BASE}",
                f"DEVICE={m.EXPECTED_DEVICE}",
                f"GRAPHENE_MANIFEST_TAG={m.EXPECTED_GRAPHENE_TAG}",
                f"PINNED_REPO_MANIFEST_SHA256={m.EXPECTED_MANIFEST_SHA256}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    tf = root / "panther-target_files.zip"
    bm = b"fake-buildmanifest"
    if malformed_zip:
        tf.write_bytes(b"not-a-zip")
    else:
        with zipfile.ZipFile(tf, "w", compression=zipfile.ZIP_STORED) as z:
            z.writestr(
                "SYSTEM/build.prop",
                "\n".join(
                    [
                        "ro.build.type=userdebug",
                        "ro.build.tags=test-keys",
                        "ro.product.device=panther",
                        "ro.build.version.incremental=2026090500",
                        "ro.build.fingerprint=google/panther/test",
                    ]
                ),
            )
            z.writestr("SYSTEM/etc/security/fsverity/BuildManifest.apk", bm)
            z.writestr("META/apkcerts.txt", 'name="X" certificate="build/make/target/product/security/platform.x509.pem"\n')
            z.writestr("META/apexkeys.txt", 'name="x" private_key="build/make/target/product/security/testkey.pem"\n')
            z.writestr("META/otakeys.txt", "build/make/target/product/security/testkey.x509.pem\n")
            z.writestr("META/misc_info.txt", "default_system_dev_certificate=build/make/target/product/security/testkey\n")
            z.writestr("META/ab_partitions.txt", "boot\nsystem\nproduct\n")
    return ws, tf, lock


def fake_cp(stdout: str = "", rc: int = 0, stderr: str = ""):
    return subprocess.CompletedProcess(["fake"], rc, stdout, stderr)


def test_authorization_fails_before_workspace_access(tmp_path: Path, capsys):
    missing = tmp_path / "missing"
    with mock.patch.dict(os.environ, {"BUILD_AUTHORIZED": "YES"}, clear=True):
        rc = m.main(["--workspace", str(missing), "--target-files", str(missing), "--baseline-lock", str(missing)])
    assert rc == 2
    out = capsys.readouterr().out
    assert "authorization.read_only_boundary" in out
    assert "R1_R0_PREFLIGHT_EXECUTION=ERROR" in out


def test_updater_parser():
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "config.xml"
        p.write_text('<resources><string name="url">https://updates.example/</string></resources>', encoding="utf-8")
        assert m.parse_updater_url(p) == "https://updates.example/"


def test_test_key_ref_detection():
    assert m.count_test_key_refs('certificate="build/make/target/product/security/platform.x509.pem"') > 0
    assert m.count_test_key_refs('certificate="keys/panther/platform.x509.pem"') == 0


def test_evidence_directories_do_not_collide(tmp_path: Path):
    pf = m.Preflight()
    pf.add("x", "PASS", 1, 1)
    a = m.write_evidence(tmp_path, pf, {"a": 1})
    b = m.write_evidence(tmp_path, pf, {"a": 1})
    assert a != b
    assert (a / "SHA256SUMS").is_file()
    assert (b / "SHA256SUMS").is_file()


def test_default_path_does_not_run_full_crc_scan(tmp_path: Path, monkeypatch):
    ws, tf, lock = make_fixture(tmp_path)
    bm = b"fake-buildmanifest"
    monkeypatch.setattr(m, "EXPECTED_B2_BUILDMANIFEST_SHA256", hashlib.sha256(bm).hexdigest())
    monkeypatch.setattr(m, "EXPECTED_B2_TARGET_FILES_SIZE", tf.stat().st_size)
    monkeypatch.setattr(m.shutil, "which", lambda name: f"/usr/bin/{name}")
    monkeypatch.setattr(m, "git_head", lambda path: (0, m.EXPECTED_SCRIPT_HEAD if path.name == "script" else m.EXPECTED_UPDATER_HEAD))
    monkeypatch.setattr(m, "run_readonly", lambda *a, **k: fake_cp("manifest"))
    monkeypatch.setattr(m, "EXPECTED_MANIFEST_SHA256", hashlib.sha256(b"manifest").hexdigest())
    lock.write_text(
        f"SABLE_BASE={m.EXPECTED_BASE}\nDEVICE=panther\nGRAPHENE_MANIFEST_TAG={m.EXPECTED_GRAPHENE_TAG}\nPINNED_REPO_MANIFEST_SHA256={m.EXPECTED_MANIFEST_SHA256}\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(zipfile.ZipFile, "testzip", lambda self: (_ for _ in ()).throw(AssertionError("testzip must not run")))
    with mock.patch.dict(os.environ, {}, clear=True):
        rc = m.main([
            "--workspace", str(ws),
            "--target-files", str(tf),
            "--baseline-lock", str(lock),
            "--evidence-root", str(tmp_path / "evidence"),
        ])
    assert rc == 3


def test_development_artifact_is_bounded_release_blocker(tmp_path: Path, monkeypatch, capsys):
    ws, tf, lock = make_fixture(tmp_path)
    bm = b"fake-buildmanifest"
    monkeypatch.setattr(m, "EXPECTED_B2_BUILDMANIFEST_SHA256", hashlib.sha256(bm).hexdigest())
    monkeypatch.setattr(m, "EXPECTED_B2_TARGET_FILES_SIZE", tf.stat().st_size)
    manifest = "manifest"
    monkeypatch.setattr(m, "EXPECTED_MANIFEST_SHA256", hashlib.sha256(manifest.encode()).hexdigest())
    # lock needs the patched value
    lock.write_text(
        f"SABLE_BASE={m.EXPECTED_BASE}\nDEVICE=panther\nGRAPHENE_MANIFEST_TAG={m.EXPECTED_GRAPHENE_TAG}\nPINNED_REPO_MANIFEST_SHA256={m.EXPECTED_MANIFEST_SHA256}\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(m.shutil, "which", lambda name: f"/usr/bin/{name}")
    monkeypatch.setattr(m, "run_readonly", lambda *a, **k: fake_cp(manifest))
    monkeypatch.setattr(m, "git_head", lambda path: (0, m.EXPECTED_SCRIPT_HEAD if path.name == "script" else m.EXPECTED_UPDATER_HEAD))
    with mock.patch.dict(os.environ, {}, clear=True):
        rc = m.main([
            "--workspace", str(ws),
            "--target-files", str(tf),
            "--baseline-lock", str(lock),
            "--evidence-root", str(tmp_path / "evidence"),
        ])
    assert rc == 3
    out = capsys.readouterr().out
    assert "artifact.build_type" in out and "BLOCKER" in out
    assert "artifact.build_tags" in out
    assert "updater.url" in out
    assert "R1_R0_PREFLIGHT_EXECUTION=PASS" in out
    assert "R1_RELEASE_READINESS=BLOCKED_" in out


def test_malformed_target_files_is_error(tmp_path: Path, monkeypatch, capsys):
    ws, tf, lock = make_fixture(tmp_path, malformed_zip=True)
    monkeypatch.setattr(m, "EXPECTED_B2_TARGET_FILES_SIZE", tf.stat().st_size)
    monkeypatch.setattr(m.shutil, "which", lambda name: f"/usr/bin/{name}")
    monkeypatch.setattr(m, "run_readonly", lambda *a, **k: fake_cp("manifest"))
    monkeypatch.setattr(m, "EXPECTED_MANIFEST_SHA256", hashlib.sha256(b"manifest").hexdigest())
    lock.write_text(
        f"SABLE_BASE={m.EXPECTED_BASE}\nDEVICE=panther\nGRAPHENE_MANIFEST_TAG={m.EXPECTED_GRAPHENE_TAG}\nPINNED_REPO_MANIFEST_SHA256={m.EXPECTED_MANIFEST_SHA256}\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(m, "git_head", lambda path: (0, m.EXPECTED_SCRIPT_HEAD if path.name == "script" else m.EXPECTED_UPDATER_HEAD))
    with mock.patch.dict(os.environ, {}, clear=True):
        rc = m.main([
            "--workspace", str(ws),
            "--target-files", str(tf),
            "--baseline-lock", str(lock),
            "--evidence-root", str(tmp_path / "evidence"),
        ])
    assert rc == 2
    assert "R1_R0_PREFLIGHT_EXECUTION=ERROR" in capsys.readouterr().out


def test_subprocess_surface_is_read_only(monkeypatch):
    calls = []
    def capture(argv, **kwargs):
        calls.append(argv)
        return fake_cp("deadbeef\n")
    monkeypatch.setattr(subprocess, "run", capture)
    m.git_head(Path("/tmp/repo"))
    assert calls == [["git", "-C", "/tmp/repo", "rev-parse", "HEAD"]]


def test_source_has_no_mutating_device_or_release_execution(monkeypatch):
    calls = []

    def capture(argv, **kwargs):
        calls.append(tuple(argv))
        if argv[:2] == ["repo", "manifest"]:
            return fake_cp("manifest")
        if argv[0] == "git":
            return fake_cp(m.EXPECTED_SCRIPT_HEAD + "\n")
        raise AssertionError(f"unexpected subprocess execution: {argv}")

    monkeypatch.setattr(subprocess, "run", capture)
    # Exercise the only helpers which reach subprocess.
    m.run_readonly(["repo", "manifest", "-r"], cwd=Path("/tmp"))
    m.git_head(Path("/tmp/repo"))
    assert all(call[0] in {"repo", "git"} for call in calls)
    assert not any(any(token in arg for token in ("adb", "fastboot", "make_key", "sign_target_files_apks", "ota_from_target_files", "generate-release.sh")) for call in calls for arg in call)

    text = SCRIPT.read_text(encoding="utf-8")
    for token in ("flashing lock", "flashall", " fastboot flash ", " fastboot erase ", " adb reboot "):
        assert token not in text
