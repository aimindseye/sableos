import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "SABLE_M1_ENGINEERING_PREFLIGHT.py"
CONTRACT = HERE.parents[2] / "product" / "m1" / "sable-start-engineering-contract-v1.json"

spec = importlib.util.spec_from_file_location("m1", SCRIPT)
m1 = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = m1
spec.loader.exec_module(m1)

GOOD_MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="org.sableos.start">
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
<application android:allowBackup="false" android:usesCleartextTraffic="false">
<activity android:name=".StartActivity" android:exported="true">
<intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.HOME"/><category android:name="android.intent.category.DEFAULT"/></intent-filter>
</activity>
</application></manifest>'''


class M1PreflightTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.contract = json.loads(CONTRACT.read_text())
        self.contract_path = self.root / "contract.json"
        self.contract_path.write_text(json.dumps(self.contract))

    def tearDown(self):
        self.tmp.cleanup()

    def source(self):
        p = self.root / "packages/apps/SableStart"
        p.mkdir(parents=True)
        (p / "AndroidManifest.xml").write_text(GOOD_MANIFEST)
        (p / "main.rs").write_text("pub fn reduce(x: u32) -> u32 { x + 1 }\n")
        return p

    def test_absent_source_is_ready_to_implement(self):
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 0)
        self.assertEqual(report["readiness"], "READY_TO_IMPLEMENT_UNDER_CONTRACT")

    def test_good_minimal_source_passes(self):
        self.source()
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 0, report)
        self.assertEqual(report["readiness"], "SOURCE_PREFLIGHT_PASS")

    def test_internet_permission_blocks(self):
        p = self.source()
        manifest = (p / "AndroidManifest.xml").read_text().replace(
            "<application", '<uses-permission android:name="android.permission.INTERNET" /><application'
        )
        (p / "AndroidManifest.xml").write_text(manifest)
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertTrue(any("FORBIDDEN_PERMISSIONS" in x for x in report["blockers"]))

    def test_unreviewed_permission_blocks(self):
        p = self.source()
        manifest = (p / "AndroidManifest.xml").read_text().replace(
            "<application", '<uses-permission android:name="android.permission.CAMERA" /><application'
        )
        (p / "AndroidManifest.xml").write_text(manifest)
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertTrue(any("UNREVIEWED_PERMISSIONS" in x for x in report["blockers"]))

    def test_exported_service_blocks(self):
        p = self.source()
        manifest = (p / "AndroidManifest.xml").read_text().replace(
            "</application>", '<service android:name=".Bad" android:exported="true" /></application>'
        )
        (p / "AndroidManifest.xml").write_text(manifest)
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertTrue(any("EXPORTED_SERVICE_COUNT=FAIL" in x for x in report["blockers"]))

    def test_home_filter_required(self):
        p = self.source()
        (p / "AndroidManifest.xml").write_text(GOOD_MANIFEST.replace("android.intent.category.HOME", "android.intent.category.LAUNCHER"))
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertIn("M1_HOME_ACTIVITY_BINDING=FAIL_MAIN_HOME_DEFAULT_FILTER", report["blockers"])

    def test_backup_true_blocks(self):
        p = self.source()
        (p / "AndroidManifest.xml").write_text(GOOD_MANIFEST.replace('android:allowBackup="false"', 'android:allowBackup="true"'))
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertIn("M1_MANIFEST_ALLOW_BACKUP=FAIL_EXPLICIT_FALSE_REQUIRED", report["blockers"])

    def test_process_execution_fragment_blocks(self):
        p = self.source()
        (p / "main.rs").write_text('fn bad() { let _ = std::process::Command::new("sh"); }\n')
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertTrue(any("std::process::Command" in x for x in report["blockers"]))

    def test_sysfs_fragment_blocks(self):
        p = self.source()
        (p / "main.rs").write_text('const P: &str = "/sys/class/power_supply/battery";\n')
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)

    def test_unsafe_rust_blocks(self):
        p = self.source()
        (p / "main.rs").write_text('pub fn x() { unsafe { core::arch::asm!("nop"); } }\n')
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertTrue(any("UNSAFE_RUST_OUTSIDE_ALLOWLIST" in x for x in report["blockers"]))

    def test_unsafe_word_in_comment_does_not_block(self):
        p = self.source()
        (p / "main.rs").write_text('// unsafe code is intentionally forbidden\npub fn x() {}\n')
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 0, report)

    def test_symlink_source_file_blocks(self):
        p = self.source()
        target = self.root / "outside.rs"
        target.write_text("pub fn x() {}\n")
        (p / "link.rs").symlink_to(target)
        with self.assertRaises(ValueError):
            m1.run(self.root, self.contract_path)

    def test_bounded_file_count_blocks(self):
        p = self.source()
        c = self.contract.copy()
        c["source_policy"] = dict(self.contract["source_policy"])
        c["source_policy"]["max_files"] = 1
        self.contract_path.write_text(json.dumps(c))
        with self.assertRaises(ValueError):
            m1.run(self.root, self.contract_path)

    def test_contract_rejects_internet_not_forbidden(self):
        c = json.loads(json.dumps(self.contract))
        c["privilege_policy"]["forbidden_permissions"].remove("android.permission.INTERNET")
        self.contract_path.write_text(json.dumps(c))
        with self.assertRaises(ValueError):
            m1.run(self.root, self.contract_path)

    def test_omitted_backup_attribute_blocks(self):
        p = self.source()
        (p / "AndroidManifest.xml").write_text(GOOD_MANIFEST.replace(' android:allowBackup="false"', ''))
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertIn("M1_MANIFEST_ALLOW_BACKUP=FAIL_EXPLICIT_FALSE_REQUIRED", report["blockers"])

    def test_implicit_exported_attribute_blocks(self):
        p = self.source()
        manifest = (p / "AndroidManifest.xml").read_text().replace(
            "</application>", '<service android:name=".Internal" /></application>'
        )
        (p / "AndroidManifest.xml").write_text(manifest)
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertTrue(any("SERVICE_EXPORTED_ATTRIBUTE=FAIL_IMPLICIT" in x for x in report["blockers"]))

    def test_shared_user_id_blocks(self):
        p = self.source()
        manifest = (p / "AndroidManifest.xml").read_text().replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android"',
            '<manifest android:sharedUserId="android.uid.system" xmlns:android="http://schemas.android.com/apk/res/android"'
        )
        (p / "AndroidManifest.xml").write_text(manifest)
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertIn("M1_MANIFEST_SHARED_USER_ID=FAIL_PRESENT", report["blockers"])

    def test_cleartext_true_blocks(self):
        p = self.source()
        (p / "AndroidManifest.xml").write_text(GOOD_MANIFEST.replace('android:usesCleartextTraffic="false"', 'android:usesCleartextTraffic="true"'))
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertIn("M1_MANIFEST_CLEARTEXT=FAIL_EXPLICIT_FALSE_REQUIRED", report["blockers"])

    def test_persistent_process_blocks(self):
        p = self.source()
        (p / "AndroidManifest.xml").write_text(GOOD_MANIFEST.replace('<application ', '<application android:persistent="true" '))
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertIn("M1_MANIFEST_PERSISTENT_PROCESS=FAIL_TRUE", report["blockers"])

    def test_exported_receiver_blocks(self):
        p = self.source()
        manifest = (p / "AndroidManifest.xml").read_text().replace(
            "</application>", '<receiver android:name=".BadReceiver" android:exported="true" /></application>'
        )
        (p / "AndroidManifest.xml").write_text(manifest)
        rc, report = m1.run(self.root, self.contract_path)
        self.assertEqual(rc, 3)
        self.assertTrue(any("EXPORTED_RECEIVER_COUNT=FAIL" in x for x in report["blockers"]))

    def test_source_root_symlink_blocks(self):
        real = self.root / "real"
        real.mkdir()
        (real / "AndroidManifest.xml").write_text(GOOD_MANIFEST)
        link_parent = self.root / "packages/apps"
        link_parent.mkdir(parents=True)
        (link_parent / "SableStart").symlink_to(real, target_is_directory=True)
        with self.assertRaises(ValueError):
            m1.run(self.root, self.contract_path)

    def test_contract_rejects_path_escape(self):
        c = json.loads(json.dumps(self.contract))
        c["source_root"] = "../outside"
        self.contract_path.write_text(json.dumps(c))
        with self.assertRaises(ValueError):
            m1.run(self.root, self.contract_path)

    def test_json_report_rejects_relative_path(self):
        proc = subprocess.run(
            [
                "python3", str(SCRIPT), "--repo-root", str(self.root),
                "--contract", str(self.contract_path), "--json-report", "report.json",
            ],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("M1_JSON_REPORT=FAIL_NOT_ABSOLUTE", proc.stdout)
        self.assertFalse((self.root / "report.json").exists())

    def test_json_report_rejects_non_tmp_path(self):
        target = Path("/var/tmp/sable_m1_forbidden_report_should_not_exist.json")
        self.assertFalse(target.exists(), "test sentinel path unexpectedly exists")
        proc = subprocess.run(
            [
                "python3", str(SCRIPT), "--repo-root", str(self.root),
                "--contract", str(self.contract_path), "--json-report", str(target),
            ],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("M1_JSON_REPORT=FAIL_NOT_TMP", proc.stdout)
        self.assertFalse(target.exists())

    def test_json_report_refuses_existing_destination(self):
        with tempfile.TemporaryDirectory(dir="/tmp") as d:
            target = Path(d) / "report.json"
            target.write_text("sentinel")
            proc = subprocess.run(
                [
                    "python3", str(SCRIPT), "--repo-root", str(self.root),
                    "--contract", str(self.contract_path), "--json-report", str(target),
                ],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(proc.returncode, 2)
            self.assertIn("M1_JSON_REPORT=FAIL_DESTINATION_EXISTS", proc.stdout)
            self.assertEqual(target.read_text(), "sentinel")

    def test_json_report_allows_new_tmp_destination(self):
        with tempfile.TemporaryDirectory(dir="/tmp") as d:
            target = Path(d) / "report.json"
            proc = subprocess.run(
                [
                    "python3", str(SCRIPT), "--repo-root", str(self.root),
                    "--contract", str(self.contract_path), "--json-report", str(target),
                ],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertTrue(target.is_file())
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            report = json.loads(target.read_text())
            self.assertEqual(report["mutation_actions"], 0)

    def test_contract_rejects_renderer_precommit(self):
        c = json.loads(json.dumps(self.contract))
        c["renderer_policy"] = "SLINT"
        self.contract_path.write_text(json.dumps(c))
        with self.assertRaises(ValueError):
            m1.run(self.root, self.contract_path)


if __name__ == "__main__":
    unittest.main()
