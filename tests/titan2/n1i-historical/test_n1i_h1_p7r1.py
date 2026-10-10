import json
import os
import tempfile
import unittest
from pathlib import Path
import n1i_h1_evidence_manifest as M
import n1i_h1c2 as C2

class P7R1Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.evidence = self.root / 'evidence'
        self.evidence.mkdir()
        self.fixture = self.evidence / 'radio.txt'
        self.fixture.write_text('synthetic')
        self.manifest = self.root / 'manifest.json'
        self.payload = dict(version=1,
            radio_logs={k: str(self.fixture) for k in M.RADIOS},
            n1h_snapshots={k: str(self.fixture) for k in C2.SNAPSHOTS})
        self.manifest.write_text(json.dumps(self.payload))
        self.manifest.chmod(0o600)

    def test_mode_0600_valid_but_duplicate_paths_rejected(self):
        with self.assertRaisesRegex(ValueError, 'REPEATED_EVIDENCE_PATH'):
            M.load(str(self.manifest), C2.SNAPSHOTS)

    def test_mode_0644_rejected(self):
        self.manifest.chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'MANIFEST_MODE_NOT_0600'):
            M.load(str(self.manifest), C2.SNAPSHOTS)

    def test_mode_0640_rejected(self):
        self.manifest.chmod(0o640)
        with self.assertRaisesRegex(ValueError, 'MANIFEST_MODE_NOT_0600'):
            M.load(str(self.manifest), C2.SNAPSHOTS)

    def test_manifest_symlink_parent_rejected(self):
        alias = self.root / 'alias'
        alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'MANIFEST_SYMLINK_COMPONENT'):
            M.load(str(alias / 'manifest.json'), C2.SNAPSHOTS)

    def test_evidence_symlink_parent_rejected(self):
        alias = self.root / 'alias'
        alias.symlink_to(self.evidence, target_is_directory=True)
        self.payload['radio_logs'][M.RADIOS[0]] = str(alias / 'radio.txt')
        self.manifest.write_text(json.dumps(self.payload));self.manifest.chmod(0o600)
        with self.assertRaisesRegex(ValueError, 'EVIDENCE_SYMLINK_COMPONENT'):
            M.load(str(self.manifest), C2.SNAPSHOTS)

    def test_evidence_final_symlink_rejected(self):
        alias = self.evidence / 'link.txt'
        alias.symlink_to(self.fixture)
        self.payload['radio_logs'][M.RADIOS[0]] = str(alias)
        self.manifest.write_text(json.dumps(self.payload));self.manifest.chmod(0o600)
        with self.assertRaisesRegex(ValueError, 'EVIDENCE_SYMLINK_COMPONENT'):
            M.load(str(self.manifest), C2.SNAPSHOTS)

    def test_missing_manifest_rejected(self):
        self.manifest.unlink()
        with self.assertRaises(ValueError):
            M.load(str(self.manifest), C2.SNAPSHOTS)

    def test_path_traversal_rejected(self):
        with self.assertRaisesRegex(ValueError, 'PATH_TRAVERSAL'):
            M._regular_without_symlinks(str(self.root / '..' / self.root.name / 'manifest.json'), 'MANIFEST', True)

if __name__ == '__main__': unittest.main()
