"""Operator-provided paths only; verified evidence pins remain in normalizers."""
import json
import os
import stat
from pathlib import Path

RADIOS = ('OCT03_N1H','OCT07_STOCK','OCT09_N1F_FAILURE','OCT09_POST_CYCLE')

def _regular_without_symlinks(raw_path, label, enforce_mode=False):
    """Reject symlinks in any component; allow read-only regular evidence files."""
    if not isinstance(raw_path, str) or not raw_path.startswith('/') or '\x00' in raw_path:
        raise ValueError('NONABSOLUTE_EVIDENCE_PATH')
    p = Path(raw_path)
    if '..' in p.parts:
        raise ValueError('PATH_TRAVERSAL')
    current = Path('/')
    parts = p.parts[1:]
    for component in parts:
        current = current / component
        try:
            info = current.lstat()
        except OSError as exc:
            raise ValueError(label + '_PATH_UNAVAILABLE') from exc
        if stat.S_ISLNK(info.st_mode):
            raise ValueError(label + '_SYMLINK_COMPONENT')
    if not stat.S_ISREG(info.st_mode):
        raise ValueError(label + '_NOT_REGULAR')
    if enforce_mode and stat.S_IMODE(info.st_mode) != 0o600:
        raise ValueError('MANIFEST_MODE_NOT_0600')
    return p, info


def load(path, snapshot_names):
    if not path:
        raise ValueError('EVIDENCE_MANIFEST_REQUIRED')
    p, info = _regular_without_symlinks(path, 'MANIFEST', enforce_mode=True)
    if info.st_size > 32768:
        raise ValueError('MANIFEST_TOO_LARGE')
    data = json.loads(p.read_text(encoding='utf8'))
    if not isinstance(data,dict) or set(data) != {'version','radio_logs','n1h_snapshots'} or data['version'] != 1:
        raise ValueError('MANIFEST_SCHEMA')
    radios, snaps = data['radio_logs'],data['n1h_snapshots']
    if not isinstance(radios,dict) or set(radios) != set(RADIOS):
        raise ValueError('RADIO_SET_MISMATCH')
    if not isinstance(snaps,dict) or set(snaps) != set(snapshot_names):
        raise ValueError('SNAPSHOT_SET_MISMATCH')
    paths = {}
    for kind, entries in [('radio',radios),('snapshot',snaps)]:
        for key,value in entries.items():
            q, _ = _regular_without_symlinks(value, 'EVIDENCE')
            paths[(kind,key)]=q
    if len(set(paths.values())) != len(paths):
        raise ValueError('REPEATED_EVIDENCE_PATH')
    return radios, snaps

def configure(path, b2, c2):
    radios,snaps=load(path,c2.SNAPSHOTS)
    for key, value in radios.items():
        _, sha, lines = b2.SOURCES[key]
        b2.SOURCES[key] = (value,sha,lines)
    c2.N1H = None  # The snapshot reader uses the explicit map instead of directory guessing.
    c2.OPERATOR_SNAPSHOTS = snaps
    return radios,snaps
