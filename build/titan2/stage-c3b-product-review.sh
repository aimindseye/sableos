#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
ACTIVE_REPO="/srv/sable-build/sableos/repo"
PRODUCT_SOURCE=""
PRODUCT_HEAD=""
PRODUCT_PR=""
DO_STAGE=NO
SOURCE_MUTATION_AUTHORIZED=NO

usage() {
    cat <<'USAGE'
usage: build/titan2/stage-c3b-product-review.sh \
  --product-source <titan2-temp review worktree> \
  --product-head <40-char sha> \
  [--product-pr <number>] \
  --stage \
  --authorize-source-mutation
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --product-source)
            [[ $# -ge 2 ]] || { echo "C3B_PRODUCT_STAGE_ARGS=FAIL missing_product_source"; exit 2; }
            PRODUCT_SOURCE="$2"
            shift 2
            ;;
        --product-head)
            [[ $# -ge 2 ]] || { echo "C3B_PRODUCT_STAGE_ARGS=FAIL missing_product_head"; exit 2; }
            PRODUCT_HEAD="$2"
            shift 2
            ;;
        --product-pr)
            [[ $# -ge 2 ]] || { echo "C3B_PRODUCT_STAGE_ARGS=FAIL missing_product_pr"; exit 2; }
            PRODUCT_PR="$2"
            shift 2
            ;;
        --stage)
            DO_STAGE=YES
            shift
            ;;
        --authorize-source-mutation)
            SOURCE_MUTATION_AUTHORIZED=YES
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "C3B_PRODUCT_STAGE_ARGS=FAIL unknown_arg=$1"
            usage
            exit 2
            ;;
    esac
done

[[ -n "$ROOT" && -d "$ROOT/.git" || -f "$ROOT/.git" ]] || {
    echo "C3B_PRODUCT_STAGE_TARGET=FAIL not_git_worktree"
    exit 1
}
ROOT="$(realpath "$ROOT")"
[[ "$ROOT" != "$ACTIVE_REPO" ]] || {
    echo "C3B_PRODUCT_STAGE_TARGET=FAIL active_repo_forbidden=$ROOT"
    exit 1
}
[[ -n "$PRODUCT_SOURCE" && -d "$PRODUCT_SOURCE" ]] || {
    echo "C3B_PRODUCT_STAGE_SOURCE=FAIL missing_product_source=$PRODUCT_SOURCE"
    exit 1
}
PRODUCT_SOURCE="$(realpath "$PRODUCT_SOURCE")"
[[ "$PRODUCT_SOURCE" != "$ROOT" ]] || {
    echo "C3B_PRODUCT_STAGE_SOURCE=FAIL source_equals_target"
    exit 1
}
[[ "$PRODUCT_HEAD" =~ ^[0-9a-f]{40}$ ]] || {
    echo "C3B_PRODUCT_STAGE_HEAD=FAIL invalid_sha=$PRODUCT_HEAD"
    exit 1
}
if [[ -n "$PRODUCT_PR" && ! "$PRODUCT_PR" =~ ^[0-9]+$ ]]; then
    echo "C3B_PRODUCT_STAGE_ARGS=FAIL invalid_product_pr=$PRODUCT_PR"
    exit 2
fi
[[ "$DO_STAGE" == YES ]] || {
    echo "C3B_PRODUCT_STAGE_AUTH=FAIL stage_flag_required"
    exit 1
}
[[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] || {
    echo "C3B_PRODUCT_STAGE_AUTH=FAIL authorize_source_mutation_required"
    exit 1
}

git -C "$PRODUCT_SOURCE" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "C3B_PRODUCT_STAGE_SOURCE=FAIL not_git_worktree=$PRODUCT_SOURCE"
    exit 1
}
ACTUAL_PRODUCT_HEAD="$(git -C "$PRODUCT_SOURCE" rev-parse HEAD)"
[[ "$ACTUAL_PRODUCT_HEAD" == "$PRODUCT_HEAD" ]] || {
    echo "C3B_PRODUCT_STAGE_HEAD=FAIL expected=$PRODUCT_HEAD actual=$ACTUAL_PRODUCT_HEAD"
    exit 1
}
[[ -z "$(git -C "$PRODUCT_SOURCE" status --porcelain)" ]] || {
    echo "C3B_PRODUCT_STAGE_SOURCE=FAIL dirty_product_source"
    git -C "$PRODUCT_SOURCE" status --short
    exit 1
}
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || {
    echo "C3B_PRODUCT_STAGE_TARGET=FAIL target_not_clean"
    git -C "$ROOT" status --short
    exit 1
}

HANDOFF="$PRODUCT_SOURCE/docs/C3B_PRODUCT_HANDOFF.env"
OWNERSHIP="$PRODUCT_SOURCE/docs/C3B_PRODUCT_PATH_OWNERSHIP.tsv"
[[ -f "$HANDOFF" ]] || { echo "C3B_PRODUCT_STAGE_HANDOFF=FAIL missing=$HANDOFF"; exit 1; }
[[ -f "$OWNERSHIP" ]] || { echo "C3B_PRODUCT_STAGE_OWNERSHIP=FAIL missing=$OWNERSHIP"; exit 1; }
grep -Fxq 'C3B_PRODUCT_SOURCE_REPO=aimindseye/titan2-temp' "$HANDOFF" || {
    echo "C3B_PRODUCT_STAGE_HANDOFF=FAIL source_repo"
    exit 1
}
grep -Fxq 'C3B_RELEASE_TRACK=N1D' "$HANDOFF" || {
    echo "C3B_PRODUCT_STAGE_HANDOFF=FAIL release_track"
    exit 1
}
grep -Fxq 'C3B_BASELINE_PHASE=C3B' "$HANDOFF" || {
    echo "C3B_PRODUCT_STAGE_HANDOFF=FAIL baseline_phase"
    exit 1
}
grep -Fxq 'C3B_PRODUCT_SOURCE_IDENTITY_MODE=RUNTIME_GIT_HEAD' "$HANDOFF" || {
    echo "C3B_PRODUCT_STAGE_HANDOFF=FAIL identity_mode"
    exit 1
}

EVIDENCE_ROOT="${SABLE_EVIDENCE_ROOT:-/srv/sable-build/evidence}"
PR_TOKEN="${PRODUCT_PR:-unbound-pr}"
EVIDENCE_DIR="$EVIDENCE_ROOT/titan2/n1d-c3b-product-review/$PR_TOKEN/$PRODUCT_HEAD"
mkdir -p "$EVIDENCE_DIR"
PLAN_TSV="$EVIDENCE_DIR/stage-plan.tsv"
PLAN_NUL="$EVIDENCE_DIR/stage-paths.nul"
COPIED_NUL="$EVIDENCE_DIR/copied-paths.nul"
INVENTORY="$EVIDENCE_DIR/staged-file-inventory.tsv"
STATE="$EVIDENCE_DIR/staging-state.env"

python3 - "$PRODUCT_SOURCE" "$ROOT" "$OWNERSHIP" "$PLAN_TSV" "$PLAN_NUL" <<'PY'
from __future__ import annotations
import csv
import fnmatch
import hashlib
import os
import pathlib
import subprocess
import sys

source = pathlib.Path(sys.argv[1]).resolve()
target = pathlib.Path(sys.argv[2]).resolve()
ownership = pathlib.Path(sys.argv[3])
plan_tsv = pathlib.Path(sys.argv[4])
plan_nul = pathlib.Path(sys.argv[5])

stage_actions = {
    "HANDOFF_AS_SOURCE_MODULE",
    "HANDOFF_AS_BUILD_METADATA",
    "HANDOFF_AS_REFERENCE_SOURCE",
    "HANDOFF_AS_TOOLING",
    "HANDOFF_AS_DOCS",
    "HANDOFF_AS_GATE",
    "HANDOFF_AS_PROVENANCE",
    "HANDOFF_AS_EVIDENCE",
}
skip_actions = {"DO_NOT_STAGE", "KEEP_AS_PROTOTYPE", "KEEP_REFERENCE_ONLY"}
known_actions = stage_actions | skip_actions

with ownership.open(encoding="utf-8", newline="") as fh:
    rows = list(csv.DictReader(fh, delimiter="\t"))
required = {"source_path", "collision_status", "handoff_action"}
if not rows or not required.issubset(rows[0]):
    raise SystemExit("C3B_PRODUCT_STAGE_OWNERSHIP=FAIL malformed_tsv")

rules = []
for row in rows:
    action = row["handoff_action"].strip()
    if action not in known_actions:
        raise SystemExit(f"C3B_PRODUCT_STAGE_OWNERSHIP=FAIL unknown_action={action}")
    collision = row["collision_status"].strip()
    for raw in row["source_path"].split(";"):
        pat = raw.strip()
        if pat:
            rules.append((pat, action, collision))

def matches(path: str, pat: str) -> bool:
    if pat.endswith("/"):
        return path.startswith(pat)
    if any(ch in pat for ch in "*?["):
        return fnmatch.fnmatchcase(path, pat)
    return path == pat

raw = subprocess.check_output(["git", "-C", str(source), "ls-files", "-s", "-z"])
entries = []
for item in raw.split(b"\0"):
    if not item:
        continue
    meta, pathb = item.split(b"\t", 1)
    mode, blob, stage = meta.decode().split()
    path = pathb.decode("utf-8", "strict")
    if stage != "0":
        raise SystemExit(f"C3B_PRODUCT_STAGE_SOURCE=FAIL unmerged_index_path={path}")
    entries.append((path, mode, blob))

undeclared = []
conflicts = []
selected = []
for path, mode, blob in entries:
    hits = [(pat, action, collision) for pat, action, collision in rules if matches(path, pat)]
    if not hits:
        undeclared.append(path)
        continue
    actions = {h[1] for h in hits}
    if len(actions) != 1:
        conflicts.append((path, sorted(actions)))
        continue
    action = next(iter(actions))
    collision_states = {h[2] for h in hits}
    if action in stage_actions:
        if collision_states != {"NO_COLLISION"}:
            conflicts.append((path, sorted(collision_states)))
            continue
        selected.append((path, mode, blob, action))

if undeclared:
    print("C3B_PRODUCT_STAGE_OWNERSHIP=FAIL undeclared_tracked_files", file=sys.stderr)
    for path in undeclared:
        print(f"UNDECLARED_PRODUCT_PATH={path}", file=sys.stderr)
    raise SystemExit(1)
if conflicts:
    print("C3B_PRODUCT_STAGE_OWNERSHIP=FAIL ambiguous_or_colliding_rules", file=sys.stderr)
    for path, details in conflicts:
        print(f"OWNERSHIP_RULE_CONFLICT={path}:{','.join(details)}", file=sys.stderr)
    raise SystemExit(1)
if not selected:
    raise SystemExit("C3B_PRODUCT_STAGE_PLAN=FAIL no_stageable_files")

root_prefix = str(target) + os.sep
with plan_tsv.open("w", encoding="utf-8", newline="\n") as tsv, plan_nul.open("wb") as nul:
    tsv.write("path\tgit_mode\tgit_blob\taction\tsha256\tbytes\n")
    for path, mode, blob, action in sorted(selected):
        src = source / path
        if src.is_symlink() or not src.is_file():
            raise SystemExit(f"C3B_PRODUCT_STAGE_SOURCE=FAIL unsupported_file_type={path}")
        dst = target / path
        resolved = dst.resolve(strict=False)
        if str(resolved) != str(target) and not str(resolved).startswith(root_prefix):
            raise SystemExit(f"C3B_PRODUCT_STAGE_TARGET=FAIL path_escape={path}")
        if dst.exists():
            if dst.is_symlink() or not dst.is_file():
                raise SystemExit(f"C3B_PRODUCT_STAGE_COLLISION=FAIL non_regular_target={path}")
            if hashlib.sha256(src.read_bytes()).digest() != hashlib.sha256(dst.read_bytes()).digest():
                raise SystemExit(f"C3B_PRODUCT_STAGE_COLLISION=FAIL differing_existing_path={path}")
        body = src.read_bytes()
        sha = hashlib.sha256(body).hexdigest()
        tsv.write(f"{path}\t{mode}\t{blob}\t{action}\t{sha}\t{len(body)}\n")
        nul.write(path.encode("utf-8") + b"\0")
print(f"C3B_PRODUCT_STAGE_PLAN=PASS files={len(selected)}")
PY

: > "$COPIED_NUL"
python3 - "$PRODUCT_SOURCE" "$ROOT" "$PLAN_TSV" "$COPIED_NUL" <<'PY'
from __future__ import annotations
import csv
import hashlib
import pathlib
import shutil
import sys

source = pathlib.Path(sys.argv[1]).resolve()
target = pathlib.Path(sys.argv[2]).resolve()
plan = pathlib.Path(sys.argv[3])
copied_nul = pathlib.Path(sys.argv[4])

copied = []
identical = 0
with plan.open(encoding="utf-8", newline="") as fh:
    rows = list(csv.DictReader(fh, delimiter="\t"))
for row in rows:
    path = row["path"]
    src = source / path
    dst = target / path
    if dst.exists():
        if hashlib.sha256(src.read_bytes()).hexdigest() != row["sha256"]:
            raise SystemExit(f"C3B_PRODUCT_STAGE_COPY=FAIL source_changed_after_plan={path}")
        identical += 1
        continue
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst, follow_symlinks=False)
    if hashlib.sha256(dst.read_bytes()).hexdigest() != row["sha256"]:
        raise SystemExit(f"C3B_PRODUCT_STAGE_COPY=FAIL copied_hash_mismatch={path}")
    copied.append(path)
with copied_nul.open("wb") as fh:
    for path in copied:
        fh.write(path.encode("utf-8") + b"\0")
print(f"C3B_PRODUCT_STAGE_COPY=PASS copied={len(copied)} identical={identical}")
PY

if [[ -s "$COPIED_NUL" ]]; then
    xargs -0 -r git -C "$ROOT" add -- < "$COPIED_NUL"
fi

git -C "$ROOT" diff --cached --check

python3 - "$ROOT" "$PLAN_TSV" "$COPIED_NUL" "$INVENTORY" <<'PY'
from __future__ import annotations
import csv
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
plan = pathlib.Path(sys.argv[2])
copied_nul = pathlib.Path(sys.argv[3])
inventory = pathlib.Path(sys.argv[4])
with plan.open(encoding="utf-8", newline="") as fh:
    rows = list(csv.DictReader(fh, delimiter="\t"))
planned = {r["path"]: r for r in rows}
copied = {p.decode("utf-8") for p in copied_nul.read_bytes().split(b"\0") if p}
staged = {p.decode("utf-8") for p in subprocess.check_output(["git", "-C", str(root), "diff", "--cached", "--name-only", "-z"]).split(b"\0") if p}
if staged != copied:
    print(f"C3B_PRODUCT_STAGE_INDEX=FAIL staged={sorted(staged)} copied={sorted(copied)}", file=sys.stderr)
    raise SystemExit(1)
with inventory.open("w", encoding="utf-8", newline="\n") as fh:
    fh.write("path\tgit_mode\tgit_blob\taction\tsha256\tbytes\tstage_result\n")
    for path in sorted(planned):
        r = planned[path]
        result = "STAGED" if path in staged else "IDENTICAL_PRESENT"
        fh.write("\t".join([path, r["git_mode"], r["git_blob"], r["action"], r["sha256"], r["bytes"], result]) + "\n")
print(f"C3B_PRODUCT_STAGE_INDEX=PASS staged={len(staged)}")
PY

BASE_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
PLAN_COUNT="$(( $(wc -l < "$PLAN_TSV") - 1 ))"
STAGED_COUNT="$(git -C "$ROOT" diff --cached --name-only | wc -l)"
IDENTICAL_COUNT="$(( PLAN_COUNT - STAGED_COUNT ))"
{
    echo "C3B_PRODUCT_SOURCE_REPO=aimindseye/titan2-temp"
    echo "C3B_PRODUCT_PR=${PRODUCT_PR:-UNBOUND}"
    echo "C3B_PRODUCT_HEAD=$PRODUCT_HEAD"
    echo "C3B_CANONICAL_BASE_HEAD=$BASE_HEAD"
    echo "C3B_PRODUCT_STAGE_FILE_COUNT=$PLAN_COUNT"
    echo "C3B_PRODUCT_STAGE_STAGED_COUNT=$STAGED_COUNT"
    echo "C3B_PRODUCT_STAGE_IDENTICAL_COUNT=$IDENTICAL_COUNT"
    echo "C3B_PRODUCT_STAGE_INVENTORY=$INVENTORY"
    echo "C3B_PRODUCT_STAGING=PASS"
} > "$STATE"

cat "$STATE"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
