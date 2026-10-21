#!/usr/bin/env python3
"""Hermetic tests for the release-specific TB2 static Hub source check."""
import importlib.util
import pathlib
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[2] / "build/gates/tb2-hub-source-contract.py"
SPEC = importlib.util.spec_from_file_location("tb2_hub_source_contract", SOURCE)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class HubSourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        for rel, tokens in MODULE.REQUIRED.items():
            target = self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("\n".join(tokens) + "\n", encoding="utf-8")

    def test_source_fixture_passes(self):
        self.assertEqual(MODULE.evaluate(self.root), [])

    def test_history_global_count_fails_closed(self):
        target = self.root / MODULE.KOTLIN / "policy/HubHistoryBounds.kt"
        target.write_text(target.read_text().replace("MAX_RECORDS_TOTAL = 1_200", "MAX_RECORDS_TOTAL = 10_000"))
        self.assertTrue(any("MAX_RECORDS_TOTAL" in x for x in MODULE.evaluate(self.root)))

    def test_no_profile_fallback_fails(self):
        target = self.root / MODULE.KOTLIN / "HubRepository.kt"
        target.write_text(target.read_text().replace("profileLocked = profile?.locked ?: true", "profileLocked = false"))
        self.assertTrue(any("profileLocked" in x for x in MODULE.evaluate(self.root)))

    def test_hardcoded_provider_rejected(self):
        target = self.root / MODULE.KOTLIN / "ProviderFilter.kt"
        target.write_text('const val ALLOW = "com.whatsapp"\n')
        self.assertTrue(any("provider_specific_package" in x for x in MODULE.evaluate(self.root)))

    def test_missing_owner_refused(self):
        (self.root / MODULE.KOTLIN / "ConnectedNotificationHistoryStore.kt").unlink()
        self.assertTrue(any("ConnectedNotificationHistoryStore" in x for x in MODULE.evaluate(self.root)))

    def test_oversized_or_symlink_refused(self):
        p = self.root / MODULE.KOTLIN / "HubRepository.kt"
        p.unlink()
        p.symlink_to(self.root / MODULE.KOTLIN / "ConnectedAppPolicy.kt")
        self.assertTrue(any("HubRepository" in x for x in MODULE.evaluate(self.root)))


if __name__ == "__main__":
    unittest.main()
