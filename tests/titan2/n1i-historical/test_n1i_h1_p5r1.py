import json
import tempfile
import unittest
from pathlib import Path
import n1i_h1_evidence_manifest as M
import n1i_h1b2 as B2
import n1i_h1c2 as C2

class P5R1Tests(unittest.TestCase):
    def test_manifest_required(self):
        with self.assertRaisesRegex(ValueError,'REQUIRED'): M.load(None,C2.SNAPSHOTS)
    def test_empty_manifest_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            f=Path(tmp)/'m.json';f.write_text('{}');f.chmod(0o600)
            with self.assertRaises(ValueError): M.load(str(f),C2.SNAPSHOTS)
    def test_unknown_radio_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            f=Path(tmp)/'m.json';f.write_text(json.dumps({'version':1,'radio_logs':{'OTHER':'/dev/null'},'n1h_snapshots':{}}));f.chmod(0o600)
            with self.assertRaisesRegex(ValueError,'RADIO_SET'):M.load(str(f),C2.SNAPSHOTS)
    def test_missing_snapshot_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            f=Path(tmp)/'m.json';f.write_text(json.dumps({'version':1,'radio_logs':{k:'/dev/null' for k in M.RADIOS},'n1h_snapshots':{}}));f.chmod(0o600)
            with self.assertRaisesRegex(ValueError,'SNAPSHOT_SET'):M.load(str(f),C2.SNAPSHOTS)
    def test_paths_no_longer_embedded(self):
        self.assertTrue(all(not spec[0] for spec in B2.SOURCES.values()))
        self.assertIsNone(C2.N1H)
    def test_symlink_manifest_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'real').write_text('{}');(root/'link').symlink_to(root/'real')
            with self.assertRaisesRegex(ValueError,'MANIFEST_SYMLINK_COMPONENT'):M.load(str(root/'link'),C2.SNAPSHOTS)
    def test_relative_evidence_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);f=root/'m.json'
            f.write_text(json.dumps({'version':1,'radio_logs':{k:'relative' for k in M.RADIOS},'n1h_snapshots':{k:'/dev/null' for k in C2.SNAPSHOTS}}))
            f.chmod(0o600)
            with self.assertRaisesRegex(ValueError,'NONABSOLUTE'):M.load(str(f),C2.SNAPSHOTS)
    def test_unknown_schema_field_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            f=Path(tmp)/'m.json';f.write_text(json.dumps({'version':1,'radio_logs':{},'n1h_snapshots':{},'bonus':1}));f.chmod(0o600)
            with self.assertRaisesRegex(ValueError,'MANIFEST_SCHEMA'):M.load(str(f),C2.SNAPSHOTS)

if __name__ == '__main__':unittest.main()
