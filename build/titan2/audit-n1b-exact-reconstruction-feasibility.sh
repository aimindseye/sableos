#!/usr/bin/env bash
set -euo pipefail
umask 077

BUILD_ROOT="${SABLE_BUILD_ROOT:-/srv/data/sable-build}"
EVID_ROOT="$BUILD_ROOT/evidence/titan2"
SABLE_REPO="${SABLE_REPO:-/srv/data/sable-build/sableos/repo}"

EXPECTED_SYSTEM_SHA="bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"
EXPECTED_SYSTEM_BYTES=3180666880
EXPECTED_TARGET_FILES_SHA="29d21d08ceb9c286e85ec52996dcc53a17fd0290cc979b5853709ef7357f2481"
EXPECTED_TARGET_FILES_BYTES=2806615483
EXPECTED_REGISTERED_BUILD_SOURCE="462839cfcc362e4f4ed93d8a8dabf059885452b1"
EXPECTED_PRIOR_IDENTICAL_BUILD_SOURCE="851b4ba50c1d9141d26afaa1432cbe7a416073a6"
EXPECTED_LEDGER_SOURCE="8dd06e77410fea131e4716447f7f05067e427654"
EXPECTED_LUNCH="treble_arm64_bvN-bp4a-userdebug"
EXPECTED_PRODUCT_MK="device/phh/treble/treble_arm64_bvN.mk"

KNOWN_C2_BLOCKED_TREBLE_REV="db688b38d729cf33e31baea47986c3fd210b671e"
KNOWN_C2_BLOCKED_VNDK29_REV="0062f4721125d68951fba37361c8204b929ae178"

fail() {
  echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY=FAIL reason=$*" >&2
  exit 1
}

[[ -d "$EVID_ROOT" ]] || fail "evidence root missing path=$EVID_ROOT"
[[ -d "$SABLE_REPO/.git" ]] || fail "sable repo missing path=$SABLE_REPO"
command -v python3 >/dev/null 2>&1 || fail python3_missing
command -v sha256sum >/dev/null 2>&1 || fail sha256sum_missing
command -v git >/dev/null 2>&1 || fail git_missing

echo "===== N1B EXACT-RECONSTRUCTION FEASIBILITY ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ANDROID_BUILD_AUTHORIZED=NO"
echo "NETWORK_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "ARTIFACT_MUTATION_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"

PHASE_ROOT="$EVID_ROOT/n1b-phase-08-image-build-candidate"
mapfile -t ENVS < <(
  find "$PHASE_ROOT" -type f -name n1b-phase-08-image-build.env -print 2>/dev/null |
    LC_ALL=C sort
)
[[ "${#ENVS[@]}" -eq 2 ]] || fail "expected exactly 2 Phase-08 envs count=${#ENVS[@]}"

declare -a MANIFESTS=()
declare -a SOURCE_COMMITS=()

echo
echo "===== PHASE-08 ARTIFACT IDENTITY ====="

for envf in "${ENVS[@]}"; do
  phase_dir="$(dirname "$envf")"
  manifest="$phase_dir/repo-manifest-r.xml"

  getv() {
    local key="$1"
    awk -F= -v k="$key" '$1==k {print substr($0,index($0,"=")+1); exit}' "$envf"
  }

  source_commit="$(getv SOURCE_COMMIT)"
  system_sha="$(getv SYSTEM_SHA256)"
  system_bytes="$(getv SYSTEM_BYTES)"
  target_sha="$(getv TARGET_FILES_SHA256)"
  target_bytes="$(getv TARGET_FILES_BYTES)"
  lunch="$(getv LUNCH_TARGET)"
  product_mk="$(getv ACTIVE_PRODUCT_MK)"

  echo "PHASE08_ENV=$envf"
  echo "PHASE08_SOURCE_COMMIT=$source_commit"
  echo "PHASE08_SYSTEM_SHA256=$system_sha"
  echo "PHASE08_SYSTEM_BYTES=$system_bytes"
  echo "PHASE08_TARGET_FILES_SHA256=$target_sha"
  echo "PHASE08_TARGET_FILES_BYTES=$target_bytes"
  echo "PHASE08_LUNCH=$lunch"
  echo "PHASE08_ACTIVE_PRODUCT_MK=$product_mk"

  [[ "$system_sha" == "$EXPECTED_SYSTEM_SHA" ]] || fail "system sha drift env=$envf"
  [[ "$system_bytes" == "$EXPECTED_SYSTEM_BYTES" ]] || fail "system bytes drift env=$envf"
  [[ "$target_sha" == "$EXPECTED_TARGET_FILES_SHA" ]] || fail "target-files sha drift env=$envf"
  [[ "$target_bytes" == "$EXPECTED_TARGET_FILES_BYTES" ]] || fail "target-files bytes drift env=$envf"
  [[ "$lunch" == "$EXPECTED_LUNCH" ]] || fail "lunch drift env=$envf"
  [[ "$product_mk" == "$EXPECTED_PRODUCT_MK" ]] || fail "product mk drift env=$envf"
  case "$source_commit" in
    "$EXPECTED_REGISTERED_BUILD_SOURCE"|"$EXPECTED_PRIOR_IDENTICAL_BUILD_SOURCE") ;;
    *) fail "unexpected Phase-08 source commit=$source_commit" ;;
  esac

  [[ -f "$manifest" ]] || fail "Phase-08 repo manifest missing path=$manifest"
  MANIFESTS+=("$manifest")
  SOURCE_COMMITS+=("$source_commit")
done

[[ "${SOURCE_COMMITS[0]}" != "${SOURCE_COMMITS[1]}" ]] ||
  fail "expected two distinct Sable source commits"
echo "N1B_PHASE08_ARTIFACT_IDENTITY=PASS_TWO_BUILDS_IDENTICAL"

echo
echo "===== PINNED ANDROID MANIFEST PARITY ====="

TMP_A="$(mktemp)"
TMP_B="$(mktemp)"
trap 'rm -f "$TMP_A" "$TMP_B"' EXIT

normalize_manifest() {
  python3 - "$1" <<'PY'
from __future__ import annotations
import sys
import xml.etree.ElementTree as ET

p = sys.argv[1]
root = ET.parse(p).getroot()
rows = []
for proj in root.iter("project"):
    name = proj.attrib.get("name", "")
    path = proj.attrib.get("path", name)
    rev = proj.attrib.get("revision", "")
    remote = proj.attrib.get("remote", "")
    upstream = proj.attrib.get("upstream", "")
    rows.append((path, name, rev, remote, upstream))
for row in sorted(rows):
    print("\t".join(row))
PY
}

normalize_manifest "${MANIFESTS[0]}" > "$TMP_A"
normalize_manifest "${MANIFESTS[1]}" > "$TMP_B"

count_a="$(wc -l < "$TMP_A")"
count_b="$(wc -l < "$TMP_B")"
sha_a="$(sha256sum "${MANIFESTS[0]}" | awk '{print $1}')"
sha_b="$(sha256sum "${MANIFESTS[1]}" | awk '{print $1}')"
norm_sha_a="$(sha256sum "$TMP_A" | awk '{print $1}')"
norm_sha_b="$(sha256sum "$TMP_B" | awk '{print $1}')"

echo "PHASE08_MANIFEST_A=${MANIFESTS[0]}"
echo "PHASE08_MANIFEST_A_SHA256=$sha_a"
echo "PHASE08_MANIFEST_A_PROJECTS=$count_a"
echo "PHASE08_MANIFEST_A_NORMALIZED_SHA256=$norm_sha_a"
echo "PHASE08_MANIFEST_B=${MANIFESTS[1]}"
echo "PHASE08_MANIFEST_B_SHA256=$sha_b"
echo "PHASE08_MANIFEST_B_PROJECTS=$count_b"
echo "PHASE08_MANIFEST_B_NORMALIZED_SHA256=$norm_sha_b"

if cmp -s "$TMP_A" "$TMP_B"; then
  echo "N1B_PHASE08_ANDROID_MANIFEST_PARITY=PASS_SEMANTIC_IDENTICAL"
else
  echo "N1B_PHASE08_ANDROID_MANIFEST_PARITY=FAIL_DIVERGENT"
  diff -u "$TMP_A" "$TMP_B" | sed -n '1,240p' || true
  fail phase08_manifest_divergence
fi

project_revision() {
  local path="$1"
  awk -F '\t' -v p="$path" '$1==p {print $3; exit}' "$TMP_A"
}

treble_rev="$(project_revision device/phh/treble)"
vndk29_rev="$(project_revision prebuilts/vndk/v29)"
echo "N1B_MANIFEST_DEVICE_PHH_TREBLE_REVISION=${treble_rev:-MISSING}"
echo "N1B_MANIFEST_PREBUILTS_VNDK_V29_REVISION=${vndk29_rev:-MISSING}"

if [[ "$treble_rev" == "$KNOWN_C2_BLOCKED_TREBLE_REV" &&
      "$vndk29_rev" == "$KNOWN_C2_BLOCKED_VNDK29_REV" ]]; then
  echo "N1B_MANIFEST_MATCHES_KNOWN_C2_BLOCKED_REVISIONS=YES"
else
  echo "N1B_MANIFEST_MATCHES_KNOWN_C2_BLOCKED_REVISIONS=NO"
fi

echo
echo "===== SABLE SOURCE PROVENANCE ====="

for commit in   "$EXPECTED_PRIOR_IDENTICAL_BUILD_SOURCE"   "$EXPECTED_REGISTERED_BUILD_SOURCE"   "$EXPECTED_LEDGER_SOURCE"
do
  if git -C "$SABLE_REPO" cat-file -e "$commit^{commit}" 2>/dev/null; then
    echo "SABLE_COMMIT_OBJECT_PRESENT=YES commit=$commit"
    git -C "$SABLE_REPO" show -s       --format='SABLE_COMMIT_INFO=%H|%cI|%s' "$commit"
  else
    echo "SABLE_COMMIT_OBJECT_PRESENT=NO commit=$commit"
  fi
done

REGISTRY="$BUILD_ROOT/release-registry/titan2/N1B/$EXPECTED_REGISTERED_BUILD_SOURCE.json"
if [[ -f "$REGISTRY" ]]; then
  echo "N1B_REGISTERED_ARTIFACT_MANIFEST_PRESENT=YES path=$REGISTRY"
  echo "N1B_REGISTERED_ARTIFACT_MANIFEST_SHA256=$(sha256sum "$REGISTRY" | awk '{print $1}')"
  python3 - "$REGISTRY" "$EXPECTED_SYSTEM_SHA" "$EXPECTED_REGISTERED_BUILD_SOURCE" <<'PY'
from __future__ import annotations
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8", errors="replace")
print("N1B_REGISTERED_MANIFEST_SYSTEM_SHA_MATCH=" + ("YES" if sys.argv[2] in txt else "NO"))
print("N1B_REGISTERED_MANIFEST_BUILD_SOURCE_MATCH=" + ("YES" if sys.argv[3] in txt else "NO"))
PY
else
  echo "N1B_REGISTERED_ARTIFACT_MANIFEST_PRESENT=NO path=$REGISTRY"
fi

echo
echo "===== LOCAL ANDROID SOURCE / CRITICAL OBJECT SURVIVAL ====="

android_src="$(awk -F= '$1=="ANDROID_SRC" {print substr($0,index($0,"=")+1); exit}' "${ENVS[0]}")"
echo "N1B_RECORDED_ANDROID_SRC=$android_src"
if [[ -d "$android_src/.repo" ]]; then
  echo "N1B_RECORDED_ANDROID_SRC_PRESENT=YES"
else
  echo "N1B_RECORDED_ANDROID_SRC_PRESENT=NO"
fi

find_revision() {
  local rel="$1"
  local rev="$2"
  local found=NO
  while IFS= read -r d; do
    [[ -d "$d" ]] || continue
    if git -C "$d" cat-file -e "$rev^{commit}" 2>/dev/null; then
      echo "N1B_CRITICAL_REVISION_LOCAL_OBJECT=YES project=$rel revision=$rev path=$d" >&2
      found=YES
      break
    fi
  done < <(
    find "$BUILD_ROOT/workspaces" -type d -path "*/$rel" -print 2>/dev/null |
      LC_ALL=C sort -u
  )
  if [[ "$found" == NO ]]; then
    echo "N1B_CRITICAL_REVISION_LOCAL_OBJECT=NO project=$rel revision=$rev" >&2
  fi
  printf '%s' "$found"
}

treble_local="$(find_revision device/phh/treble "$treble_rev")"
vndk29_local="$(find_revision prebuilts/vndk/v29 "$vndk29_rev")"

echo
echo "===== OLD N1B REFERENCE PACK SOURCE-CONTENT CHECK ====="

REF_ZIP="$EVID_ROOT/n1c-sable-build-mount-cleanup-20260930_143705/old-n1b-reference-pack.zip"
if [[ -f "$REF_ZIP" && "$(command -v unzip || true)" != "" ]]; then
  member_list="$(mktemp)"
  trap 'rm -f "$TMP_A" "$TMP_B" "$member_list"' EXIT
  unzip -Z1 "$REF_ZIP" > "$member_list"
  echo "OLD_N1B_REFERENCE_PACK_MEMBER_COUNT=$(wc -l < "$member_list")"
  for pattern in     '/\.repo/'     '/device/phh/treble/'     '/prebuilts/vndk/v29/'     '/vendor/sable/'     '/repo-manifest-r\.xml$'
  do
    count="$(grep -Ec "$pattern" "$member_list" || true)"
    echo "OLD_N1B_REFERENCE_PACK_SOURCE_PATTERN count=$count pattern=$pattern"
  done
else
  echo "OLD_N1B_REFERENCE_PACK_SOURCE_CHECK=UNAVAILABLE"
fi

echo
echo "===== FULL-CI EVIDENCE SURVIVAL ====="
for envf in "${ENVS[@]}"; do
  ci="$(awk -F= '$1=="FULL_CI_EVIDENCE_DIR" {print substr($0,index($0,"=")+1); exit}' "$envf")"
  if [[ -d "$ci" ]]; then
    echo "N1B_FULL_CI_EVIDENCE_PRESENT=YES path=$ci"
  else
    echo "N1B_FULL_CI_EVIDENCE_PRESENT=NO path=$ci"
  fi
done

echo
echo "===== FEASIBILITY RESULT ====="

matches_blocked=NO
if [[ "$treble_rev" == "$KNOWN_C2_BLOCKED_TREBLE_REV" &&
      "$vndk29_rev" == "$KNOWN_C2_BLOCKED_VNDK29_REV" ]]; then
  matches_blocked=YES
fi

if [[ "$matches_blocked" == YES &&
      "$treble_local" == NO &&
      "$vndk29_local" == NO ]]; then
  result="BLOCKED_PENDING_MISSING_SOURCE_OBJECT_RECOVERY"
else
  result="CANDIDATE_FOR_PINNED_RECONSTRUCTION_NOT_YET_AUTHORIZED"
fi

echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY=$result"
echo "N1B_EXACT_REBUILD_REQUIRES_HASH_MATCH=$EXPECTED_SYSTEM_SHA"
echo "N1B_EXACT_TARGET_FILES_REBUILD_REQUIRES_HASH_MATCH=$EXPECTED_TARGET_FILES_SHA"
echo "N1B_EXACT_REBUILD_AUTHORIZED=NO"
echo "N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"
echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY_AUDIT=PASS_READ_ONLY"
