#!/usr/bin/env python3
"""Hermetic negative/positive source-snapshot regression tests (no Android host)."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).with_name("a16_owner_snapshot.py")
SPEC = importlib.util.spec_from_file_location("tb2_a16_owner_snapshot", MODULE)
assert SPEC is not None and SPEC.loader is not None
snapshot = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(snapshot)


class SourceSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.patches = self.root / "patches"
        self.android = self.root / "android"
        self.patches.mkdir()
        self.android.mkdir()
        self.manifest = self.root / "Q25_PATCHES.json"

    def seed(self):
        entries = []
        for i in range(26):
            rel = f"frameworks/base/{i:04d}.patch"
            dest = self.patches / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(
                "diff --git a/services/core/java/com/android/server/policy/PhoneWindowManager.java "
                "b/services/core/java/com/android/server/policy/PhoneWindowManager.java\n",
                encoding="utf-8",
            )
            entries.append({"module": "frameworks/base", "file": rel})
        self.manifest.write_text(json.dumps({"patches": entries}))
        owner = self.android / snapshot.EXTRA[0]
        owner.parent.mkdir(parents=True, exist_ok=True)
        owner.write_text("owner source\n")
        return owner

    def test_exact_patches_and_owner_identity(self):
        owner = self.seed()
        wanted = snapshot.requested_paths(self.patches, self.manifest)
        self.assertEqual(wanted, [snapshot.EXTRA[0]])
        present, missing = snapshot.scan(self.android, wanted)
        self.assertEqual(missing, [])
        self.assertEqual(present[0]["sha256"], hashlib.sha256(owner.read_bytes()).hexdigest())

    def test_missing_owner_is_reported_without_mutation(self):
        self.seed()
        owner = self.android / snapshot.EXTRA[0]
        owner.unlink()
        found, missing = snapshot.scan(self.android, [snapshot.EXTRA[0]])
        self.assertEqual(found, [])
        self.assertEqual(missing, [snapshot.EXTRA[0]])

    def test_parent_symlink_is_rejected(self):
        self.seed()
        path = self.android / "frameworks"
        target = self.root / "outside"
        path.rename(target)
        path.symlink_to(target)
        with self.assertRaises(ValueError):
            snapshot.scan(self.android, [snapshot.EXTRA[0]])

    def test_parent_escape_is_rejected(self):
        self.seed()
        with self.assertRaises(ValueError):
            snapshot.scan(self.android, ["frameworks/base/../../etc/passwd"])

    def test_unknown_owner_is_rejected(self):
        self.seed()
        with self.assertRaises(ValueError):
            snapshot.scan(self.android, ["vendor/unknown/private.txt"])

    def test_max_file_is_enforced_before_read(self):
        owner = self.seed()
        with owner.open("wb") as f:
            f.truncate(snapshot.MAX_MEMBER + 1)
        with self.assertRaises(ValueError):
            snapshot.scan(self.android, [snapshot.EXTRA[0]])

    def test_wrong_patch_count_is_rejected(self):
        self.seed()
        doc = json.loads(self.manifest.read_text())
        doc["patches"].pop()
        self.manifest.write_text(json.dumps(doc))
        with self.assertRaises(ValueError):
            snapshot.requested_paths(self.patches, self.manifest)

    def test_module_drift_is_rejected(self):
        self.seed()
        doc = json.loads(self.manifest.read_text())
        doc["patches"][0]["module"] = "vendor/unknown"
        self.manifest.write_text(json.dumps(doc))
        with self.assertRaises(ValueError):
            snapshot.requested_paths(self.patches, self.manifest)


if __name__ == "__main__":
    unittest.main()
