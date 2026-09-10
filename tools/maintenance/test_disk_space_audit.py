from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).with_name("SABLE_DISK_SPACE_AUDIT.py")
spec = importlib.util.spec_from_file_location("disk_audit", SCRIPT)
assert spec and spec.loader
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)


def build_tree(tmp_path: Path):
    ws = tmp_path / "ws"
    repo = tmp_path / "repo"
    home = tmp_path / "home"
    troot = tmp_path / "tmp"
    for p in (ws, repo, home, troot):
        p.mkdir(parents=True)
    for name in ("out_d4_b2_final", "out_graphene_control", "out_c2r32_sable_fresh"):
        d = ws / name
        d.mkdir()
        (d / "payload.bin").write_bytes(b"x" * 128)
    (home / ".ccache").mkdir()
    (home / ".ccache/a").write_bytes(b"a" * 64)
    (home / ".cache").mkdir()
    (home / ".cache/b").write_bytes(b"b" * 32)
    (troot / "SABLE_ONE").mkdir()
    (troot / "SABLE_ONE/e").write_bytes(b"e" * 50)
    (troot / "PANTHER_TWO").mkdir()
    (troot / "PANTHER_TWO/e").write_bytes(b"e" * 70)
    (troot / "UNRELATED").mkdir()
    (troot / "UNRELATED/e").write_bytes(b"e" * 999)
    return ws, repo, home, troot


def test_human():
    assert m.human(0).endswith("B")
    assert "KiB" in m.human(2048)


def test_tmp_scan_is_prefix_bounded(tmp_path: Path):
    _, _, _, root = build_tree(tmp_path)
    names = [p.name for p in m.tmp_evidence_dirs(root)]
    assert names == ["PANTHER_TWO", "SABLE_ONE"]


def test_main_is_read_only_and_reports_known_paths(tmp_path: Path, capsys):
    ws, repo, home, root = build_tree(tmp_path)
    sentinel = ws / "out_graphene_control/payload.bin"
    before = sentinel.read_bytes()
    rc = m.main(["--workspace", str(ws), "--repo", str(repo), "--home", str(home), "--tmp-root", str(root), "--evidence-root", str(root)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "SABLE_DISK_SPACE_AUDIT_MODE=READ_ONLY_NO_DELETE" in out
    assert "DELETE_ACTIONS=NONE" in out
    assert "REVIEW_RECLAIM" in out
    assert sentinel.read_bytes() == before
    assert (ws / "out_d4_b2_final").is_dir()


def test_report_json_and_sums(tmp_path: Path, capsys):
    ws, repo, home, root = build_tree(tmp_path)
    assert m.main(["--workspace", str(ws), "--repo", str(repo), "--home", str(home), "--tmp-root", str(root), "--evidence-root", str(root)]) == 0
    out = capsys.readouterr().out
    evidence = Path(next(x.split("=", 1)[1] for x in out.splitlines() if x.startswith("EVIDENCE_DIR=")))
    payload = json.loads((evidence / "disk_space_audit.json").read_text())
    assert payload["mode"] == "READ_ONLY_NO_DELETE"
    assert payload["cleanup_policy"]["automatic_deletion"] is False
    assert payload["tmp_evidence"]["count"] == 2
    line = (evidence / "SHA256SUMS").read_text().strip()
    expected = hashlib.sha256((evidence / "disk_space_audit.json").read_bytes()).hexdigest()
    assert line == f"{expected}  disk_space_audit.json"


def test_hash_target_files_only_when_requested(tmp_path: Path, capsys):
    ws, repo, home, root = build_tree(tmp_path)
    tf = ws / "out_d4_b2_final/target/product/panther/obj/PACKAGING/target_files_intermediates"
    tf.mkdir(parents=True)
    target = tf / "panther-target_files.zip"
    target.write_bytes(b"target-files")
    assert m.main(["--workspace", str(ws), "--repo", str(repo), "--home", str(home), "--tmp-root", str(root), "--evidence-root", str(root), "--hash-target-files"]) == 0
    out = capsys.readouterr().out
    assert hashlib.sha256(b"target-files").hexdigest() in out


def test_no_delete_execution_surface():
    text = SCRIPT.read_text(encoding="utf-8")
    for token in ("rm -rf", "shutil.rmtree", ".unlink(", "os.remove", "os.rmdir", "subprocess.Popen", "shell=True"):
        assert token not in text
    assert text.count("subprocess.run(") == 1
    assert '["du", "-sx", "--block-size=1"' in text


def test_fresh_process_help():
    cp = subprocess.run([sys.executable, str(SCRIPT), "--help"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
    assert cp.returncode == 0
    assert "Read-only bounded SableOS disk-space audit" in cp.stdout
