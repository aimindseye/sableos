#!/usr/bin/env python3
"""Review/verify/explicitly stage two PR347-owned AOSP source directories.

Not a standalone build path: the only build is build/sable.sh. Never touches
PR346 Git source, Android out/, system images, product setup, or devices.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile

BRANCH = 'titan2/nextbuild-q25-app-conformance-20261021'
PAIRS = (
    ('src/android/packages/apps/SableStart', 'packages/apps/SableStart'),
    ('src/android/shared/sabledesign', 'packages/apps/SableDesign'),
)
GSI_SOURCE = 'build/make/target/product/gsi_release.mk'
GSI_SHA = '34ba318c8c4bcbc0e3ddf3a72e3445ccc5c51438d8bc4e6b03444ee30df4dd10'
SCHEMA = 'PR347_CANONICAL_AOSP_SOURCE_CONVERGENCE_V1'
MAX_FILES = 360
MAX_FILE_BYTES = 2_000_000
MAX_TOTAL_BYTES = 28_000_000

class Hold(Exception):
    pass

def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def root(path: str, name: str) -> Path:
    p = Path(path).absolute()
    if not p.is_dir() or p.is_symlink():
        raise Hold(f'{name}_ROOT_MISSING_OR_SYMLINK')
    if str(p.resolve()) != str(p):
        raise Hold(f'{name}_ROOT_NONCANONICAL')
    return p

def safe_file(root_dir: Path, rel: str, required: bool = False):
    path = root_dir
    for part in Path(rel).parts:
        if part in ('..', '.'):
            raise Hold('ESCAPING_FILE_PATH')
        path = path / part
        if path.is_symlink():
            raise Hold('SOURCE_OR_DEST_SYMLINK:' + rel)
    if not path.exists():
        if required:
            raise Hold('REQUIRED_SOURCE_MISSING:' + rel)
        return None
    st = path.stat()
    if not stat.S_ISREG(st.st_mode) or st.st_nlink != 1 or st.st_size > MAX_FILE_BYTES:
        raise Hold('NONREGULAR_OR_HARDLINK_OR_LARGE:' + rel)
    return path

def git_branch(sable: Path):
    cmd = ['git', '-C', str(sable), 'branch', '--show-current']
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=8, check=False)
    if p.returncode != 0 or p.stdout.strip() != BRANCH:
        raise Hold('NOT_DEDICATED_PR347_BRANCH')
    p = subprocess.run(['git', '-C', str(sable), 'status', '--porcelain=v1', '--untracked-files=normal'],
                       capture_output=True, text=True, timeout=12, check=False)
    if p.returncode != 0:
        raise Hold('SOURCE_GIT_STATUS_FAILED')
    return bool(p.stdout.strip())

def inspect(sable: Path, android: Path) -> dict:
    if sable == android or sable in android.parents or android in sable.parents:
        raise Hold('ROOTS_OVERLAP')
    dirty = git_branch(sable)
    gsi = safe_file(android, GSI_SOURCE, True)
    if sha(gsi.read_bytes()) != GSI_SHA:
        raise Hold('PR347_GSI_PROMOTION_SOURCE_SHA_DRIFT')
    # Files remain in the Sable source checkout; no blind dir swap of native Android.
    entries = []
    total_bytes = 0
    for source_rel, target_rel in PAIRS:
        source_dir = sable / source_rel
        if not source_dir.is_dir() or source_dir.is_symlink():
            raise Hold('MISSING_SABLE_OWNER_DIR:' + source_rel)
        if (android / target_rel).is_symlink():
            raise Hold('TARGET_OWNER_ROOT_SYMLINK')
        files = sorted(source_dir.rglob('*'))
        if len(files) > MAX_FILES * 2:
            raise Hold('FILE_INVENTORY_TOO_LARGE')
        actual = 0
        for src in files:
            if src.is_symlink():
                raise Hold('SYMLINK_SOURCE_TREE')
            if src.is_dir():
                continue
            actual += 1
            if actual > MAX_FILES or len(entries) >= MAX_FILES:
                raise Hold('TOO_MANY_SOURCE_FILES')
            sr = source_rel + '/' + src.relative_to(source_dir).as_posix()
            tr = target_rel + '/' + src.relative_to(source_dir).as_posix()
            src = safe_file(sable, sr, True)
            data = src.read_bytes()
            total_bytes += len(data)
            if total_bytes > MAX_TOTAL_BYTES:
                raise Hold('TOTAL_SOURCE_BYTES_EXCEEDED')
            dest = safe_file(android, tr)
            old_sha = sha(dest.read_bytes()) if dest is not None else None
            entries.append({'source': sr, 'target': tr, 'bytes': len(data),
                            'source_sha256': sha(data), 'target_sha256_before': old_sha,
                            'action': 'MATCH' if old_sha == sha(data) else ('ADD' if dest is None else 'REPLACE')})
    if len(entries) < 15:
        raise Hold('SOURCE_INVENTORY_UNEXPECTEDLY_SMALL')
    return {'schema': SCHEMA, 'sable': str(sable), 'android': str(android),
            'dirty_source': dirty, 'gsi_sha256': GSI_SHA, 'files': entries,
            'file_count': len(entries), 'source_bytes': total_bytes,
            'matched': sum(x['action'] == 'MATCH' for x in entries),
            'add': sum(x['action'] == 'ADD' for x in entries),
            'replace': sum(x['action'] == 'REPLACE' for x in entries),
            'release_ready': False, 'full_image_build': False, 'device_contact': False}

def fresh_out(path: str, sable: Path, android: Path) -> Path:
    out = Path(path).absolute()
    if out in (sable, android) or sable in out.parents or android in out.parents:
        raise Hold('OUTPUT_INSIDE_SOURCE')
    if out.is_symlink() or out.exists():
        raise Hold('NEW_EXTERNAL_OUTPUT_REQUIRED')
    if not out.parent.is_dir() or out.parent.is_symlink():
        raise Hold('EXTERNAL_OUTPUT_PARENT_INVALID')
    return out

def write_json_create(path: Path, data: dict):
    with path.open('x', encoding='utf-8') as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write('\n')

def load_plan(path: str, sable: Path, android: Path) -> dict:
    p = Path(path).absolute()
    if p.is_symlink() or not p.is_file() or p.stat().st_size > 250_000:
        raise Hold('PLAN_MISSING_OR_OVERSIZE')
    if sable in p.parents or android in p.parents:
        raise Hold('PLAN_INSIDE_SOURCE')
    doc = json.loads(p.read_text(encoding='utf-8'))
    if doc.get('schema') != SCHEMA or doc.get('sable') != str(sable) or doc.get('android') != str(android):
        raise Hold('PLAN_IDENTITY_MISMATCH')
    return doc

def active_build() -> bool:
    # Best-effort guard, not a global lock. Owner quiescence ACK is additionally required.
    me = os.getpid()
    for path in list(Path('/proc').glob('[0-9]*/cmdline'))[:500]:
        if int(path.parent.name) == me:
            continue
        try:
            cmd = path.read_bytes().replace(b'\0', b' ').lower()
        except (OSError, ValueError):
            continue
        # Avoid matching the wrapper shell's literal source-script text.
        if b'soong_ui.bash' in cmd or b'build/soong/soong_ui' in cmd or b'/ninja ' in cmd or b'run-track-b-integrated.sh' in cmd:
            return True
    return False

def do_stage(doc: dict, sable: Path, android: Path, out: Path):
    if os.environ.get('PR347_CONVERGENCE_STAGE_ACK') != 'STAGE_REVIEWED_PR347_AOSP_SOURCE_ONLY':
        raise Hold('EXPLICIT_STAGE_ACK_REQUIRED')
    if os.environ.get('PR347_BUILD_QUIESCENT_ACK') != 'TRACK_B_ANDROID_BUILD_QUIESCENT_CONFIRMED':
        raise Hold('BUILD_QUIESCENCE_ACK_REQUIRED')
    if git_branch(sable):
        raise Hold('PR347_SABLE_SOURCE_DIRTY_COMMIT_FIRST')
    if active_build():
        raise Hold('ACTIVE_ANDROID_BUILD_DETECTED')
    # Re-evaluate every file/pin BEFORE any output/source mutation.
    now = inspect(sable, android)
    if now != doc:
        raise Hold('PLAN_DRIFT_REPLAN_REQUIRED')
    actions = [x for x in now['files'] if x['action'] != 'MATCH']
    if not actions:
        raise Hold('NO_CHANGES_TO_STAGE')
    out.mkdir(mode=0o700)
    (out / 'backups').mkdir()
    moved = []
    try:
        # Preserve all original bytes and modes before writing a single source file.
        for item in actions:
            old = safe_file(android, item['target'])
            if old is None:
                continue
            backup = out / 'backups' / item['target']
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(old, backup, follow_symlinks=False)
            if sha(backup.read_bytes()) != item['target_sha256_before']:
                raise Hold('BACKUP_HASH_MISMATCH')
        for item in actions:
            target = android / item['target']
            source = safe_file(sable, item['source'], True)
            old = safe_file(android, item['target'])
            current_hash = sha(old.read_bytes()) if old else None
            if current_hash != item['target_sha256_before']:
                raise Hold('CONCURRENT_DESTINATION_DRIFT')
            target.parent.mkdir(parents=True, exist_ok=True)
            # Detect parent symlink created during staging, before replacement.
            safe_file(android, item['target'])
            content = source.read_bytes()
            if sha(content) != item['source_sha256']:
                raise Hold('CONCURRENT_SOURCE_DRIFT')
            mode = (old.stat().st_mode & 0o777) if old else 0o644
            fd, name = tempfile.mkstemp(prefix='.pr347-converge-', dir=target.parent)
            try:
                with os.fdopen(fd, 'wb') as f:
                    f.write(content)
                    f.flush()
                    os.fsync(f.fileno())
                os.chmod(name, mode)
                os.replace(name, target)
            finally:
                if os.path.exists(name):
                    os.unlink(name)
            moved.append(item)
            if sha(safe_file(android, item['target'], True).read_bytes()) != item['source_sha256']:
                raise Hold('SOURCE_READBACK_MISMATCH')
        write_json_create(out / 'RESULT.json', {'status': 'PASS_PR347_AOSP_SELECTED_SOURCE_STAGED_NOT_BUILT',
            'schema': SCHEMA, 'changed': len(actions), 'source_mutation': True,
            'release_ready': False, 'no_image': True, 'no_device': True, 'no_flash': True,
            'source_plan_sha256': sha(json.dumps(doc, sort_keys=True).encode('utf-8'))})
    except Exception:
        # Never overwrite an independently modified post-stage file while rolling back.
        for item in reversed(moved):
            target = android / item['target']
            if target.is_symlink() or not target.is_file() or sha(target.read_bytes()) != item['source_sha256']:
                continue
            backup = out / 'backups' / item['target']
            if backup.is_file():
                shutil.copy2(backup, target)
            else:
                target.unlink()
        raise

def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('mode', choices=['plan', 'verify', 'stage'])
    ap.add_argument('--sable', required=True)
    ap.add_argument('--android', required=True)
    ap.add_argument('--out')
    ap.add_argument('--plan-file')
    args = ap.parse_args(argv)
    try:
        sable = root(args.sable, 'SABLE')
        android = root(args.android, 'ANDROID')
        if args.mode in ('plan', 'stage') and not args.out:
            raise Hold('MISSING_OUT')
        if args.mode == 'stage' and not args.plan_file:
            raise Hold('MISSING_REVIEW_PLAN')
        out = fresh_out(args.out, sable, android) if args.out else None
        if args.mode == 'stage':
            p = Path(args.plan_file).absolute()
            supplied_sha = os.environ.get('PR347_CONVERGENCE_REVIEW_SHA256', '')
            if not supplied_sha or supplied_sha != sha(p.read_bytes()):
                raise Hold('REVIEW_PLAN_SHA256_ACK_REQUIRED')
            do_stage(load_plan(args.plan_file, sable, android), sable, android, out)
            print('PR347_CONVERGENCE=PASS_EXACT_SOURCE_STAGED_NO_BUILD')
            return 0
        doc = inspect(sable, android)
        if args.mode == 'plan':
            out.mkdir(mode=0o700)
            write_json_create(out / 'PLAN.json', doc)
            print(json.dumps({'status': 'PLAN_REVIEW_ONLY_NO_MUTATION', 'report': str(out / 'PLAN.json'),
                              'match': doc['matched'], 'add': doc['add'], 'replace': doc['replace']}))
            return 0
        # Verify requires a clean Sable checkout (CI likewise requires no dirty files).
        if doc['dirty_source'] or doc['add'] or doc['replace']:
            raise Hold(f'SOURCE_NOT_CONVERGED_dirty={doc["dirty_source"]}_add={doc["add"]}_replace={doc["replace"]}')
        print('PR347_CONVERGENCE=PASS_SELECTED_SOURCE_MATCHES_PR347_RELEASE_HOLD')
        return 0
    except (Hold, OSError, ValueError, subprocess.TimeoutExpired, json.JSONDecodeError) as e:
        print('PR347_CONVERGENCE_HOLD=' + str(e).replace('\n', ' ')[:260], file=sys.stderr)
        return 78

if __name__ == '__main__':
    sys.exit(main())
