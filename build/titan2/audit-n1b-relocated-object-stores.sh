#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/storage.env"
# shellcheck source=/dev/null
source "$ROOT/build/config/host-tools.env"

PHASE08_MANIFEST="${SABLE_EVIDENCE_ROOT}/titan2/n1b-phase-08-image-build-candidate/20260928_190313/repo-manifest-r.xml"
EXPECTED_MANIFEST_SHA="2ce10689772b122b1cd8810a302735a67826753e819e17ca35a576aaff6c21cc"
EXPECTED_TREBLE_REV="70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93"
EXPECTED_VNDK29_REV="16d658458c18835392bd4f2101eb28ba2e7b9e6f"

fail() {
  echo "N1B_RELOCATED_OBJECT_STORE_AUDIT=FAIL reason=$*" >&2
  exit 1
}

[[ -f "$PHASE08_MANIFEST" ]] || fail "phase08_manifest_missing path=$PHASE08_MANIFEST"
[[ "$(sha256sum "$PHASE08_MANIFEST" | awk '{print $1}')" == "$EXPECTED_MANIFEST_SHA" ]] ||
  fail phase08_manifest_sha_mismatch
command -v git >/dev/null 2>&1 || fail git_missing
command -v python3 >/dev/null 2>&1 || fail python3_missing

echo "===== N1B RELOCATED SOURCE / REPO OBJECT-STORE AUDIT ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_AUTHORIZED=NO"
echo "ANDROID_BUILD_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "ARTIFACT_MUTATION_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"

echo
echo "===== STANDARDIZED STORAGE / TOOLCHAIN ====="
echo "SABLE_BUILD_ROOT=$SABLE_BUILD_ROOT"
echo "SABLE_BUILD_LEGACY_ROOT=$SABLE_BUILD_LEGACY_ROOT"
echo "SABLE_WORKSPACES_ROOT=$SABLE_WORKSPACES_ROOT"
echo "SABLE_HOST_TOOLS_ROOT=$SABLE_HOST_TOOLS_ROOT"
echo "SABLE_ANDROID_SDK=$SABLE_ANDROID_SDK"

if [[ -e "$SABLE_BUILD_ROOT" && -e "$SABLE_BUILD_LEGACY_ROOT" ]]; then
  root_dev_inode="$(stat -Lc '%d:%i' "$SABLE_BUILD_ROOT")"
  legacy_dev_inode="$(stat -Lc '%d:%i' "$SABLE_BUILD_LEGACY_ROOT")"
  echo "SABLE_BUILD_ROOT_DEV_INODE=$root_dev_inode"
  echo "SABLE_BUILD_LEGACY_ROOT_DEV_INODE=$legacy_dev_inode"
  if [[ "$root_dev_inode" == "$legacy_dev_inode" ]]; then
    echo "SABLE_STORAGE_ALIAS=PASS_SAME_OBJECT"
  else
    echo "SABLE_STORAGE_ALIAS=REVIEW_DIFFERENT_OBJECT"
  fi
else
  echo "SABLE_STORAGE_ALIAS=REVIEW_MISSING_PATH"
fi

if [[ -d "$SABLE_ANDROID_SDK" ]]; then
  echo "STANDARDIZED_ANDROID_SDK_PRESENT=YES"
else
  echo "STANDARDIZED_ANDROID_SDK_PRESENT=NO"
fi
if [[ -x "$SABLE_REPO_TOOL" ]]; then
  echo "STANDARDIZED_REPO_TOOL_PRESENT=YES"
else
  echo "STANDARDIZED_REPO_TOOL_PRESENT=NO"
fi

echo
echo "===== CRITICAL N1B MANIFEST PROJECTS ====="
PROJECTS_TSV="$(mktemp)"
REPO_ROOTS="$(mktemp)"
trap 'rm -f "$PROJECTS_TSV" "$REPO_ROOTS"' EXIT

python3 - "$PHASE08_MANIFEST" > "$PROJECTS_TSV" <<'PY'
from __future__ import annotations
import sys
import xml.etree.ElementTree as ET

wanted = {"device/phh/treble", "prebuilts/vndk/v29"}
root = ET.parse(sys.argv[1]).getroot()

default_remote = ""
for child in root:
    if child.tag == "default":
        default_remote = child.attrib.get("remote", "")
        break

remotes = {}
for remote in root.iter("remote"):
    remotes[remote.attrib.get("name", "")] = remote.attrib.get("fetch", "")

rows = []
for project in root.iter("project"):
    path = project.attrib.get("path", project.attrib.get("name", ""))
    if path not in wanted:
        continue
    name = project.attrib.get("name", "")
    revision = project.attrib.get("revision", "")
    remote = project.attrib.get("remote", default_remote)
    fetch = remotes.get(remote, "")
    upstream = project.attrib.get("upstream", "")
    rows.append((path, name, revision, remote, fetch, upstream))

for row in sorted(rows):
    print("\t".join(row))
PY

cat "$PROJECTS_TSV"
[[ "$(wc -l < "$PROJECTS_TSV")" -eq 2 ]] || fail critical_project_count
grep -Fq $'device/phh/treble\t' "$PROJECTS_TSV" || fail treble_project_missing
grep -Fq $'prebuilts/vndk/v29\t' "$PROJECTS_TSV" || fail vndk29_project_missing
grep -Fq "$EXPECTED_TREBLE_REV" "$PROJECTS_TSV" || fail treble_revision_mismatch
grep -Fq "$EXPECTED_VNDK29_REV" "$PROJECTS_TSV" || fail vndk29_revision_mismatch

echo
echo "===== STANDARDIZED / SURVIVING REPO CHECKOUTS ====="
if [[ -d "$SABLE_WORKSPACES_ROOT" ]]; then
  find "$SABLE_WORKSPACES_ROOT" -maxdepth 6 -type d -name .repo -print 2>/dev/null |
    LC_ALL=C sort -u > "$REPO_ROOTS"
fi
echo "REPO_ROOT_COUNT=$(wc -l < "$REPO_ROOTS")"
sed 's#/.repo$##; s#^#REPO_ROOT=#' "$REPO_ROOTS"

probe_git_dir() {
  local label="$1"
  local project_path="$2"
  local revision="$3"
  local target="$4"
  local mode="$5"

  [[ -e "$target" ]] || return 1
  if [[ "$mode" == worktree ]]; then
    if git -C "$target" cat-file -e "$revision^{commit}" 2>/dev/null; then
      echo "N1B_REVISION_OBJECT_FOUND=YES project=$project_path revision=$revision via=$label path=$target"
      return 0
    fi
  else
    if git --git-dir="$target" cat-file -e "$revision^{commit}" 2>/dev/null; then
      echo "N1B_REVISION_OBJECT_FOUND=YES project=$project_path revision=$revision via=$label path=$target"
      return 0
    fi
  fi
  return 1
}

FOUND_ALL=YES
while IFS=$'\t' read -r project_path project_name revision remote fetch upstream; do
  echo
  echo "PROJECT_PATH=$project_path"
  echo "PROJECT_NAME=$project_name"
  echo "PROJECT_REVISION=$revision"
  echo "PROJECT_REMOTE=$remote"
  echo "PROJECT_REMOTE_FETCH=$fetch"
  echo "PROJECT_UPSTREAM=$upstream"

  found=NO
  while IFS= read -r repo_dir; do
    [[ -d "$repo_dir" ]] || continue
    checkout_root="${repo_dir%/.repo}"

    candidates=(
      "worktree|$checkout_root/$project_path"
      "project-object-name|$repo_dir/project-objects/$project_name.git"
      "project-object-path|$repo_dir/project-objects/$project_path.git"
      "project-git|$repo_dir/projects/$project_path.git"
    )

    for item in "${candidates[@]}"; do
      label="${item%%|*}"
      target="${item#*|}"
      mode=gitdir
      [[ "$label" == worktree ]] && mode=worktree
      if probe_git_dir "$label" "$project_path" "$revision" "$target" "$mode"; then
        found=YES
      fi
    done
  done < "$REPO_ROOTS"

  # Historical non-workspace / repo caches occasionally survive under the build
  # root. Search only exact repo-object suffixes derived from the pinned manifest.
  while IFS= read -r target; do
    [[ -e "$target" ]] || continue
    if git --git-dir="$target" cat-file -e "$revision^{commit}" 2>/dev/null; then
      echo "N1B_REVISION_OBJECT_FOUND=YES project=$project_path revision=$revision via=global-object-store path=$target"
      found=YES
    fi
  done < <(
    {
      find "$SABLE_BUILD_ROOT" -type d -path "*/.repo/project-objects/$project_name.git" -print 2>/dev/null || true
      find "$SABLE_BUILD_ROOT" -type d -path "*/.repo/project-objects/$project_path.git" -print 2>/dev/null || true
      find "$SABLE_BUILD_ROOT" -type d -path "*/.repo/projects/$project_path.git" -print 2>/dev/null || true
    } | LC_ALL=C sort -u
  )

  if [[ "$found" == YES ]]; then
    echo "N1B_CRITICAL_REVISION_RELOCATED_STATUS=FOUND project=$project_path revision=$revision"
  else
    echo "N1B_CRITICAL_REVISION_RELOCATED_STATUS=NOT_FOUND project=$project_path revision=$revision"
    FOUND_ALL=NO
  fi
done < "$PROJECTS_TSV"

echo
echo "===== PRE-CLEANUP SOURCE-STATE SEALS ====="
PRE="$SABLE_EVIDENCE_ROOT/titan2/n1d-precleanup-source-state-20261001T022132Z"
if [[ -d "$PRE" ]]; then
  echo "N1D_PRECLEANUP_SOURCE_STATE_PRESENT=YES path=$PRE"
  find "$PRE" -maxdepth 3 -type f -printf '%P\t%s\n' 2>/dev/null |
    LC_ALL=C sort | sed -n '1,200p'
else
  echo "N1D_PRECLEANUP_SOURCE_STATE_PRESENT=NO path=$PRE"
fi

echo
echo "===== RELOCATION-AWARE DECISION ====="
if [[ "$FOUND_ALL" == YES ]]; then
  echo "N1B_PINNED_SOURCE_OBJECTS_LOCAL=PASS_ALL_FOUND"
  echo "N1B_NEXT_STEP=OFFLINE_PINNED_SOURCE_REMATERIALIZATION_DESIGN"
else
  echo "N1B_PINNED_SOURCE_OBJECTS_LOCAL=FAIL_ONE_OR_MORE_MISSING"
  echo "N1B_NEXT_STEP=BOUNDED_REMOTE_AVAILABILITY_PREFLIGHT_BEFORE_ANY_SYNC"
fi

echo "N1B_EXACT_REBUILD_AUTHORIZED=NO"
echo "N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"
echo "N1B_RELOCATED_OBJECT_STORE_AUDIT=PASS_READ_ONLY"
