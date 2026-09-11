#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/build/config/panther-grapheneos-2026081300.env"

APP_DIR="${APP_DIR:-$SABLEOS_UPSTREAM/packages/apps/SableStart}"
SRC="${SRC:-$REPO_ROOT/src/android/packages/apps/SableStart}"
TS="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLESTART_PORTABLE_VERIFY_${TS}}"
mkdir -p "$EVIDENCE_DIR"

python3 - "$APP_DIR" "$SRC" "$EVIDENCE_DIR" <<'PY'
import hashlib
import pathlib
import sys

up = pathlib.Path(sys.argv[1]).resolve()
repo = pathlib.Path(sys.argv[2]).resolve()
out = pathlib.Path(sys.argv[3])

skip_dirs = {'.git', 'out', 'build', '.gradle', 'target'}
repo_only = {'PORTABILITY_STATUS.md', 'SHA256SUMS.txt'}

def files(root, repo_side=False):
    result = {}
    for p in root.rglob('*'):
        if not p.is_file():
            continue
        rel = p.relative_to(root)
        if any(part in skip_dirs for part in rel.parts):
            continue
        if repo_side and rel.as_posix() in repo_only:
            continue
        result[rel.as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    return result

u = files(up)
r = files(repo, repo_side=True)

(out / 'upstream.txt').write_text(''.join(f'{u[k]}  {k}\n' for k in sorted(u)))
(out / 'repository.txt').write_text(''.join(f'{r[k]}  {k}\n' for k in sorted(r)))

missing = sorted(set(u) - set(r))
extra = sorted(set(r) - set(u))
mismatch = sorted(k for k in set(u) & set(r) if u[k] != r[k])

(out / 'missing.txt').write_text('\n'.join(missing) + ('\n' if missing else ''))
(out / 'extra.txt').write_text('\n'.join(extra) + ('\n' if extra else ''))
(out / 'mismatch.txt').write_text('\n'.join(f'{k} upstream={u[k]} repo={r[k]}' for k in mismatch) + ('\n' if mismatch else ''))

print(f'SABLESTART_UPSTREAM_FILE_COUNT={len(u)}')
print(f'SABLESTART_REPOSITORY_FILE_COUNT={len(r)}')
print(f'SABLESTART_MISSING_COUNT={len(missing)}')
print(f'SABLESTART_EXTRA_COUNT={len(extra)}')
print(f'SABLESTART_MISMATCH_COUNT={len(mismatch)}')
if missing or extra or mismatch:
    print('SABLESTART_PORTABLE_SNAPSHOT=FAIL')
    raise SystemExit(1)
print('SABLESTART_PORTABLE_SNAPSHOT=PASS')
PY

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
)
sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt"
echo "Evidence: $EVIDENCE_DIR"
