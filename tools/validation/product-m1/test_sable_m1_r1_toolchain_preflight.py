#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import stat
import sys
import tempfile
import unittest
from contextlib import contextmanager
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).with_name("SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.py")
SPEC = importlib.util.spec_from_file_location("sable_m1_r1_preflight", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MOD = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MOD
SPEC.loader.exec_module(MOD)


def git_blob(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}\0".encode("ascii") + data).hexdigest()


def make_exec(path: Path, data: bytes = b"tool\n") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    path.chmod(0o755)


def make_file(path: Path, data: bytes = b"x\n") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def load_base_contract() -> dict:
    path = Path(__file__).parents[3] / "product/m1/sable-m1-r1-toolchain-contract-v1.json"
    return json.loads(path.read_text(encoding="utf-8"))


def build_fixture(root: Path) -> tuple[Path, Path, dict]:
    repo = root / "repo"
    ws = root / "workspace"
    repo.mkdir()
    ws.mkdir()
    make_file(ws / ".repo/manifest.xml", b"<manifest/>\n")

    prior_contract = repo / "product/m1/sable-start-engineering-contract-v1.json"
    prior_closure = repo / "docs/SABLE_M1_R0_ENGINEERING_GATE_20260909.md"
    make_file(prior_contract, b'{"fixture":"m1-r0"}\n')
    make_file(prior_closure, b"# fixture closure\n")

    contract = load_base_contract()
    contract["workspace_expected"] = str(ws)
    contract["prior_m1_contract"]["git_blob_sha1"] = git_blob(prior_contract.read_bytes())
    contract["prior_m1_r0_closure"]["git_blob_sha1"] = git_blob(prior_closure.read_bytes())

    rust_version = ws / "prebuilts/rust/linux-x86/1.99.0"
    rust_version.mkdir(parents=True)
    current = ws / "prebuilts/rust/linux-x86/current"
    current.symlink_to("1.99.0", target_is_directory=True)
    for name in ("rustc", "cargo", "rustfmt", "clippy-driver"):
        make_exec(rust_version / "bin" / name, f"{name}\n".encode())

    clang_version = ws / "prebuilts/clang/host/linux-x86/clang-r999999"
    clang_version.mkdir(parents=True)
    stable = ws / "prebuilts/clang/host/linux-x86/clang-stable"
    stable.symlink_to("clang-r999999", target_is_directory=True)
    for name in ("clang", "clang++"):
        make_exec(clang_version / "bin" / name, f"{name}\n".encode())

    make_exec(ws / "build/soong/soong_ui.bash")
    make_exec(ws / "prebuilts/jdk/jdk21/linux-x86/bin/java")
    make_exec(ws / "prebuilts/build-tools/linux-x86/bin/ninja")

    make_file(ws / "frameworks/native/libs/nativewindow/include/android/native_window.h")
    make_file(ws / "frameworks/base/core/java/android/view/Surface.java")
    make_file(ws / "frameworks/base/core/java/android/view/Window.java")
    make_file(ws / "frameworks/base/core/java/android/view/accessibility/AccessibilityNodeInfo.java")
    make_file(ws / "frameworks/base/core/java/android/view/inputmethod/InputMethodManager.java")

    contract_path = repo / "product/m1/sable-m1-r1-toolchain-contract-v1.json"
    make_file(contract_path, (json.dumps(contract, indent=2, sort_keys=True) + "\n").encode())
    return repo, ws, contract


@contextmanager
def clean_auth_env(contract: dict):
    patch = {name: "NO" for name in contract["authorization_policy"]["required_no"]}
    with mock.patch.dict(os.environ, patch, clear=False):
        yield


class ContractTests(unittest.TestCase):
    def test_contract_valid(self):
        MOD.validate_contract(load_base_contract())

    def test_renderer_selection_must_be_forbidden(self):
        c = load_base_contract()
        c["qualification_policy"]["renderer_selection_at_static_gate"] = "ALLOWED"
        with self.assertRaises(ValueError):
            MOD.validate_contract(c)

    def test_network_fetch_must_be_forbidden(self):
        c = load_base_contract()
        c["qualification_policy"]["network_fetch"] = "ALLOWED"
        with self.assertRaises(ValueError):
            MOD.validate_contract(c)

    def test_build_execution_must_be_forbidden(self):
        c = load_base_contract()
        c["qualification_policy"]["build_execution"] = "ALLOWED"
        with self.assertRaises(ValueError):
            MOD.validate_contract(c)

    def test_relative_path_escape_rejected(self):
        c = load_base_contract()
        c["toolchain"]["soong_ui"] = "../evil"
        with self.assertRaises(ValueError):
            MOD.validate_contract(c)

    def test_duplicate_authorization_names_rejected(self):
        c = load_base_contract()
        c["authorization_policy"]["required_no"].append(
            c["authorization_policy"]["required_no"][0]
        )
        with self.assertRaises(ValueError):
            MOD.validate_contract(c)


class BindingAndToolchainTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir="/tmp")
        self.root = Path(self.tmp.name)
        self.repo, self.ws, self.contract = build_fixture(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def test_repo_binding_passes(self):
        result = MOD.Result()
        MOD.validate_repo_binding(self.repo, self.contract, result)
        self.assertEqual([], result.blockers)
        self.assertIn("M1_R0_CONTRACT_BINDING=PASS", result.passes)
        self.assertIn("M1_R0_CLOSURE_BINDING=PASS", result.passes)

    def test_repo_blob_mismatch_blocks(self):
        self.contract["prior_m1_contract"]["git_blob_sha1"] = "0" * 40
        result = MOD.Result()
        MOD.validate_repo_binding(self.repo, self.contract, result)
        self.assertIn("M1_R0_CONTRACT_BINDING=FAIL_GIT_BLOB", result.blockers)

    def test_workspace_manifest_required(self):
        (self.ws / ".repo/manifest.xml").unlink()
        result = MOD.Result()
        value = MOD.validate_workspace(
            self.ws, str(self.ws), result, enforce_exact_path=True
        )
        self.assertIsNone(value)
        self.assertIn("M1_R1_WORKSPACE=FAIL_NO_REPO_MANIFEST", result.blockers)

    def test_workspace_path_mismatch_blocks(self):
        result = MOD.Result()
        value = MOD.validate_workspace(
            self.ws, "/different/workspace", result, enforce_exact_path=True
        )
        self.assertIsNone(value)
        self.assertIn("M1_R1_WORKSPACE=FAIL_UNEXPECTED_PATH", result.blockers)

    def test_toolchain_fixture_passes(self):
        result = MOD.Result()
        inventory = MOD.inspect_toolchain(self.ws, self.contract, result)
        self.assertEqual([], result.blockers)
        self.assertEqual("1.99.0", inventory["rust_version_hint"])
        self.assertEqual("clang-r999999", inventory["clang_version_hint"])

    def test_missing_cargo_blocks(self):
        (self.ws / "prebuilts/rust/linux-x86/1.99.0/bin/cargo").unlink()
        result = MOD.Result()
        MOD.inspect_toolchain(self.ws, self.contract, result)
        self.assertTrue(
            any(x.startswith("M1_R1_RUST_CARGO_BINDING=FAIL") for x in result.blockers)
        )

    def test_non_executable_rustc_blocks(self):
        rustc = self.ws / "prebuilts/rust/linux-x86/1.99.0/bin/rustc"
        rustc.chmod(0o644)
        result = MOD.Result()
        MOD.inspect_toolchain(self.ws, self.contract, result)
        self.assertIn("M1_R1_RUST_RUSTC_BINDING=FAIL:PermissionError", result.blockers)

    def test_symlink_escape_blocks(self):
        current = self.ws / "prebuilts/rust/linux-x86/current"
        current.unlink()
        outside = self.root / "outside"
        outside.mkdir()
        current.symlink_to(outside, target_is_directory=True)
        result = MOD.Result()
        MOD.inspect_toolchain(self.ws, self.contract, result)
        self.assertIn("M1_R1_RUST_CURRENT_BINDING=FAIL:ValueError", result.blockers)

    def test_platform_interfaces_pass(self):
        result = MOD.Result()
        found = MOD.inspect_platform_interfaces(self.ws, self.contract, result)
        self.assertEqual([], result.blockers)
        self.assertEqual(
            set(x["name"] for x in self.contract["platform_interfaces"]["required_any_groups"]),
            set(found.keys()),
        )

    def test_missing_accessibility_interface_blocks(self):
        (self.ws / "frameworks/base/core/java/android/view/accessibility/AccessibilityNodeInfo.java").unlink()
        result = MOD.Result()
        MOD.inspect_platform_interfaces(self.ws, self.contract, result)
        self.assertIn("M1_R1_PLATFORM_ACCESSIBILITY_PLATFORM=FAIL_MISSING", result.blockers)

    def test_renderer_absence_nonblocking(self):
        result = MOD.Result()
        out = MOD.inspect_renderer_candidates(self.ws, self.contract, result)
        self.assertEqual([], result.blockers)
        self.assertIn("M1_R1_RENDERER_SELECTION=PASS_NOT_SELECTED", result.passes)
        slint = next(x for x in out if x["id"] == "slint")
        self.assertEqual(
            "LOCAL_SOURCE_NOT_PRESENT_IMPORT_REVIEW_REQUIRED",
            slint["classification"],
        )

    def test_renderer_presence_detected_without_selection(self):
        (self.ws / "external/slint").mkdir(parents=True)
        result = MOD.Result()
        out = MOD.inspect_renderer_candidates(self.ws, self.contract, result)
        slint = next(x for x in out if x["id"] == "slint")
        self.assertEqual(
            "LOCAL_SOURCE_PRESENT_REQUIRES_BUILD_QUALIFICATION",
            slint["classification"],
        )
        self.assertIn("M1_R1_RENDERER_SELECTION=PASS_NOT_SELECTED", result.passes)

    def test_renderer_symlink_escape_blocks(self):
        outside = self.root / "slint-outside"
        outside.mkdir()
        path = self.ws / "external/slint"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(outside, target_is_directory=True)
        result = MOD.Result()
        MOD.inspect_renderer_candidates(self.ws, self.contract, result)
        self.assertIn("M1_R1_RENDERER_SLINT=FAIL_LOCAL_SOURCE_PATH", result.blockers)


class AuthorizationAndEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir="/tmp")
        self.root = Path(self.tmp.name)
        self.repo, self.ws, self.contract = build_fixture(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def test_all_no_authorization_passes(self):
        result = MOD.Result()
        with clean_auth_env(self.contract):
            MOD.validate_authorization(self.contract, result)
        self.assertEqual([], result.blockers)
        self.assertIn("AUTHORIZATION_BOUNDARY=PASS_ALL_NO", result.passes)

    def test_yes_authorization_blocks(self):
        result = MOD.Result()
        with clean_auth_env(self.contract):
            with mock.patch.dict(os.environ, {"BUILD_AUTHORIZED": "YES"}, clear=False):
                MOD.validate_authorization(self.contract, result)
        self.assertIn("AUTHORIZATION_BOUNDARY=FAIL:BUILD_AUTHORIZED", result.blockers)

    def test_evidence_dir_outside_tmp_rejected(self):
        with self.assertRaises(ValueError):
            MOD.make_evidence_dir("/var/tmp/SABLE_M1_R1_TEST")

    def test_existing_evidence_dir_rejected(self):
        existing = Path(tempfile.mkdtemp(prefix="m1r1-existing-", dir="/tmp"))
        try:
            with self.assertRaises(ValueError):
                MOD.make_evidence_dir(str(existing))
        finally:
            existing.rmdir()

    def test_evidence_report_mode_0600(self):
        evid = MOD.make_evidence_dir(None)
        try:
            report = MOD.write_evidence(evid, {"x": 1})
            mode = stat.S_IMODE(report.stat().st_mode)
            self.assertEqual(0o600, mode)
        finally:
            for p in evid.iterdir():
                p.unlink()
            evid.rmdir()

    def test_full_synthetic_preflight_passes(self):
        contract_path = self.repo / "product/m1/sable-m1-r1-toolchain-contract-v1.json"
        with clean_auth_env(self.contract):
            rc, payload, evid = MOD.run_preflight(
                repo_root=self.repo,
                workspace=self.ws,
                contract_path=contract_path,
                evidence_dir=None,
                enforce_exact_workspace_path=True,
            )
        try:
            self.assertEqual(0, rc)
            self.assertEqual(
                "READY_FOR_RENDERER_IMPORT_AND_BUILD_QUALIFICATION_PLAN",
                payload["readiness"],
            )
            self.assertEqual(0, payload["build_actions"])
            self.assertEqual(0, payload["build_tool_execution_actions"])
            self.assertIsNone(payload["renderer_selected"])
        finally:
            for p in evid.iterdir():
                p.unlink()
            evid.rmdir()

    def test_full_preflight_blocks_missing_tool(self):
        (self.ws / "prebuilts/build-tools/linux-x86/bin/ninja").unlink()
        contract_path = self.repo / "product/m1/sable-m1-r1-toolchain-contract-v1.json"
        with clean_auth_env(self.contract):
            rc, payload, evid = MOD.run_preflight(
                repo_root=self.repo,
                workspace=self.ws,
                contract_path=contract_path,
                evidence_dir=None,
                enforce_exact_workspace_path=True,
            )
        try:
            self.assertEqual(3, rc)
            self.assertEqual("BLOCKED_STATIC_PREFLIGHT", payload["readiness"])
        finally:
            for p in evid.iterdir():
                p.unlink()
            evid.rmdir()


class StaticSafetyTests(unittest.TestCase):
    def test_no_subprocess_import(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("import subprocess", source)
        self.assertNotIn("from subprocess", source)

    def test_no_network_modules(self):
        source = SCRIPT.read_text(encoding="utf-8")
        for token in ("urllib", "requests", "http.client", "socket", "aiohttp"):
            self.assertNotIn(token, source)

    def test_no_process_execution_calls(self):
        source = SCRIPT.read_text(encoding="utf-8")
        for token in ("os.system(", "os.popen(", "execv(", "spawn", "Popen("):
            self.assertNotIn(token, source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
