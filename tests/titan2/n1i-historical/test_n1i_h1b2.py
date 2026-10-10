#!/usr/bin/env python3
"""Synthetic, filesystem-temporary regression tests; no host device interaction."""
import hashlib
import tempfile
import unittest
from pathlib import Path
import n1i_h1b2 as n

class H1B2Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'synthetic.log'
        self.raw = (b'--------- beginning of radio\n'
                    b'10-09 21:28:00.000 123 456 I TAG: onInternetValidationStatusChanged INVALID\n'
                    b'10-09 21:28:53.124 123 456 I TAG: DATA_DEACT_CALL_IND\n')
        self.path.write_bytes(self.raw)
        self.sha = hashlib.sha256(self.raw).hexdigest()
    def test_candidate_not_root_cause(self):
        r = n.read_source('SYNTHETIC', self.path, self.sha, 3)
        self.assertEqual(r['root_cause'], 'UNKNOWN')
        self.assertEqual(r['validation_vs_bearer_order'], 'NOT_ESTABLISHED')
        self.assertEqual(r['candidate_count'], 2)
        self.assertTrue(all(x['semantic_event'] == 'NOT_ESTABLISHED' for x in r['candidate_events']))
        self.assertNotIn('INVALID', str(r['candidate_events']))
    def test_hash_mutation_holds(self):
        self.path.write_bytes(self.raw + b'x')
        with self.assertRaisesRegex(n.IntegrityError, 'SHA256_MISMATCH'):
            n.read_source('SYNTHETIC', self.path, self.sha, 3)
    def test_nonmatching_line_not_dropped(self):
        r = n.read_source('SYNTHETIC', self.path, self.sha, 3)
        self.assertEqual(r['counts']['unparsed_timestamp_lines'], 1)
    def test_timestamp_regression_flagged(self):
        raw = self.raw.replace(b'21:28:53.124', b'21:27:53.124')
        self.path.write_bytes(raw)
        r = n.read_source('SYNTHETIC', self.path, hashlib.sha256(raw).hexdigest(), 3)
        self.assertEqual(r['counts']['timestamp_regressions'], 1)
    def test_symlink_rejected(self):
        link = Path(self.temp.name) / 'link.log'
        link.symlink_to(self.path)
        with self.assertRaises(n.IntegrityError):
            n.read_source('SYNTHETIC', link, self.sha, 3)

if __name__ == '__main__':
    unittest.main()
