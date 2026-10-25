#!/usr/bin/env python3
"""Host-only regression checks for nextbuild readiness gate; never mutates source."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest

GATE_FILE = pathlib.Path(__file__).with_name("check-ready.py")
SPEC = importlib.util.spec_from_file_location("q25_nextbuild_ready", GATE_FILE)
assert SPEC is not None and SPEC.loader is not None
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)


class NextbuildReadinessTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.manifest = self.root / "build/titan2/nextbuild/Q25_SOURCE_READINESS.json"
        self.manifest.parent.mkdir(parents=True)
        original = json.loads(gate.MANIFEST.read_text(encoding="utf-8"))
        self.doc = original
        self.old_root, self.old_manifest = gate.ROOT, gate.MANIFEST
        gate.ROOT, gate.MANIFEST = self.root, self.manifest
        self.addCleanup(self.restore)
        self.save()

    def restore(self):
        gate.ROOT, gate.MANIFEST = self.old_root, self.old_manifest

    def save(self):
        self.manifest.write_text(json.dumps(self.doc), encoding="utf-8")

    def test_exact_twenty_three_rows(self):
        self.assertEqual(len(self.doc["items"]), 23)
        self.assertEqual(len(self.doc["requirements"]), 8)
        self.assertEqual(gate.check("report"), 0)

    def test_incomplete_never_admitted(self):
        self.assertEqual(gate.check("require-ready"), 78)

    def test_reordered_rows_hold(self):
        self.doc["items"][0], self.doc["items"][1] = self.doc["items"][1], self.doc["items"][0]
        self.save()
        self.assertEqual(gate.check("require-ready"), 78)

    def test_fabricated_complete_without_receipt_hold(self):
        self.doc["items"][0]["status"] = "complete"
        self.save()
        self.assertEqual(gate.check("require-ready"), 78)

    def test_not_applicable_only_for_subscreen(self):
        self.doc["items"][0]["status"] = "not_applicable"
        self.save()
        self.assertEqual(gate.check("report"), 78)

    def test_valid_receipt_hash_and_single_remaining_open(self):
        row = self.doc["items"][0]
        row["status"] = "complete"
        row["evidence_file"] = "build/titan2/nextbuild/receipt.txt"
        data = b"local, reviewed source test receipt"
        path = self.root / row["evidence_file"]
        path.write_bytes(data)
        row["evidence_sha256"] = hashlib.sha256(data).hexdigest()
        self.save()
        self.assertEqual(gate.check("report"), 0)
        self.assertEqual(gate.check("require-ready"), 78)
        path.write_bytes(b"changed")
        self.assertEqual(gate.check("report"), 78)

    def test_symlink_receipt_hold(self):
        row = self.doc["items"][0]
        row["status"] = "complete"
        row["evidence_file"] = "build/titan2/nextbuild/receipt-link"
        outside = self.root / "safe.txt"
        outside.write_bytes(b"outside")
        (self.manifest.parent / "receipt-link").symlink_to(outside)
        row["evidence_sha256"] = hashlib.sha256(b"outside").hexdigest()
        self.save()
        self.assertEqual(gate.check("report"), 78)

    def test_path_escape_hold(self):
        row = self.doc["items"][0]
        row["status"] = "complete"
        row["evidence_file"] = "../other-file"
        row["evidence_sha256"] = "0" * 64
        self.save()
        self.assertEqual(gate.check("report"), 78)

    def test_invalid_ims_status_hold(self):
        self.doc["requirements"][0]["status"] = "not_applicable"
        self.save()
        self.assertEqual(gate.check("report"), 78)

    def test_source_driver_requires_gate(self):
        driver = gate.ROOT
        # Inspect original repo script, not the disposable fake root.
        source = self.old_root / "build/titan2/run-track-b-integrated.sh"
        content = source.read_text(encoding="utf-8")
        self.assertIn('check-ready.py" --require-ready', content)
        self.assertIn("TB2_BUILD=HOLD_Q25_IMS_SOURCE_COMPLETION_BEFORE_COMPILATION", content)


if __name__ == "__main__":
    unittest.main()
