#!/usr/bin/env bash
# Titan 2 N1I-D0 host-only boot-compatibility closure.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 64
source "$ROOT/build/config/storage.env" || exit 64
source "$ROOT/build/config/host-tools.env" || exit 64
source "$ROOT/build/titan2/n1d-fresh-source.env" || exit 64

N1F_SHA="dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a"
N1F_BYTES="3200540672"
C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
C1_BYTES="3210661888"
C2_SHA="630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50"
C2_BYTES="3218440192"
B2_PIN="1697f21989b8ed6f1db90f8886952894592c7d0f"
STOCK_SYSTEM_SHA="b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd"
STOCK_SYSTEM_BYTES="757059584"
STOCK_SYSTEM_EXT_SHA="1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170"
STOCK_PRODUCT_SHA="de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37"
STOCK_VENDOR_SHA="cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada"

N1F_IMAGE="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img"
C3A_HISTORY="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/20261003T221350Z"
N1F_PRODUCT_OUT="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td/target/product/tdgsi_arm64_ab"
C1_ARTIFACT_DIR="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-cellular-isolation/20261005T133622Z-a745c7daa082-postbuild"
C1_PRODUCT_OUT="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-n1i-c1-a745c7daa082/target/product/tdgsi_arm64_ab"
C2_ARTIFACT_DIR="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c2-cellular-mvp/20261006T112224Z"
C2_PRODUCT_OUT="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-n1i-c2-27d671b004f5/target/product/tdgsi_arm64_ab"
C2_POSTBUILD="$SABLE_EVIDENCE_ROOT/titan2/n1i-c2-postbuild-linkage/20261006T142300Z-27d671b004f5"
C2_LINKAGE="$C2_POSTBUILD/runtime-linkage"
REPLAY="$C2_LINKAGE/n1i-a-replay"
STOCK_REF="$SABLE_TITAN2_ROOT/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference"
ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
APEX_MATERIALIZER="$ROOT/build/titan2/materialize-n1i-d0-apex.py"
DEX_PREPARER="$ROOT/build/titan2/prepare-n1i-d0-dex-container.py"
PROPERTY_INFO_CHECKER="$SABLE_AOSP_HOST_BIN/property_info_checker"
OUT=""

fail() {
  echo "N1I_D0_HOST_CLOSURE=FAIL reason=$1" >&2
  exit "${2:-1}"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --out)
      [[ "$#" -ge 2 ]] || fail missing_out 64
      OUT="$2"; shift 2 ;;
    -h|--help)
      echo "usage: $0 [--out DIR]"
      exit 0 ;;
    *)
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ -n "$OUT" ]] ||
  OUT="$SABLE_EVIDENCE_ROOT/titan2/n1i-d0-host-closure/$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$(realpath -m "$OUT")"
case "$OUT/" in "$ROOT"/*) fail output_must_be_outside_repo 64 ;; esac
[[ ! -e "$OUT" ]] || fail "output_exists=$OUT" 64

adb() { fail adb_invoked 90; }
fastboot() { fail fastboot_invoked 90; }
export -f adb fastboot fail

for tool in git sha256sum stat python3 debugfs fsck.erofs od grep awk sed find sort xargs realpath; do
  command -v "$tool" >/dev/null 2>&1 || fail "required_tool_missing=$tool" 64
done
[[ -x "$SABLE_SIMG2IMG" ]] || fail "simg2img_missing=$SABLE_SIMG2IMG" 64
[[ -x "$SABLE_SECILC" ]] || fail "secilc_missing=$SABLE_SECILC" 64
[[ -f "$APEX_MATERIALIZER" ]] || fail "apex_materializer_missing=$APEX_MATERIALIZER" 64
[[ -f "$DEX_PREPARER" ]] || fail "dex_preparer_missing=$DEX_PREPARER" 64
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
[[ -x "$AAPT2" ]] || fail "aapt2_missing=$AAPT2" 64
[[ -x "$APKSIGNER" ]] || fail "apksigner_missing=$APKSIGNER" 64
[[ -d "$ANDROID_ROOT" ]] || fail "android_root_missing=$ANDROID_ROOT" 64

REPO_HEAD="$(git -C "$ROOT" rev-parse HEAD)" ||
  fail source_head_unavailable 64
REPO_STATUS="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail source_status_unavailable 64
[[ -z "$REPO_STATUS" ]] || fail source_worktree_dirty 64
git -C "$ROOT" merge-base --is-ancestor "$B2_PIN" "$REPO_HEAD" ||
  fail b2_pin_not_ancestor 64
for rel in build/titan2/n1i-b2-members.py build/titan2/n1i-b2-native.py; do
  [[ "$(git -C "$ROOT" rev-parse "$B2_PIN:$rel")" == \
     "$(git -C "$ROOT" hash-object "$ROOT/$rel")" ]] ||
    fail "b2_analyzer_drift=$rel" 64
done

# Bind Gate A semantics to the source state that produced the physically
# boot-qualified C3A/N1F control. Verify only the small source-state authority
# files here; do not re-hash the archived multi-gigabyte C3A image.
C3A_HEADS="$C3A_HISTORY/all-project-heads.tsv"
C3A_SUMS="$C3A_HISTORY/SHA256SUMS.txt"
[[ -f "$C3A_HEADS" && -f "$C3A_SUMS" ]] ||
  fail c3a_source_authority_missing 64
C3A_HEADS_EXPECTED="$(
  awk '$2 == "./all-project-heads.tsv" || $2 == "all-project-heads.tsv" {print $1}' "$C3A_SUMS"
)"
[[ "$C3A_HEADS_EXPECTED" =~ ^[0-9a-f]{64}$ ]] ||
  fail c3a_source_heads_manifest_missing 64
[[ "$(sha256sum "$C3A_HEADS" | awk '{print $1}')" == "$C3A_HEADS_EXPECTED" ]] ||
  fail c3a_source_heads_seal_invalid 64

for project in system/core system/sepolicy; do
  expected_head="$(awk -F '\t' -v p="$project" '$1 == p {print $2}' "$C3A_HEADS")"
  [[ "$expected_head" =~ ^[0-9a-f]{40}$ ]] ||
    fail "c3a_project_head_missing=$project" 64
  actual_head="$(git -C "$ANDROID_ROOT/$project" rev-parse HEAD 2>/dev/null)" ||
    fail "android_project_head_unavailable=$project" 64
  [[ "$actual_head" == "$expected_head" ]] ||
    fail "android_project_head_mismatch=$project:expected=$expected_head:actual=$actual_head" 64
  [[ -z "$(git -C "$ANDROID_ROOT/$project" status --porcelain=v1 --untracked-files=all)" ]] ||
    fail "android_project_dirty=$project" 64
done

mkdir -p "$OUT/work" "$OUT/gates" ||
  fail output_create_failed 64
exec > >(tee "$OUT/run.log") 2>&1

echo "===== TITAN 2 N1I-D0 HOST BOOT-COMPATIBILITY CLOSURE ====="
echo "TOOL_SOURCE_COMMIT=$REPO_HEAD"
echo "B2_ANALYZER_PIN=$B2_PIN"
echo "SOURCE_MUTATION_AUTHORIZED=YES_D0_TOOLING_ONLY"
echo "BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "MODE_TRANSITION_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

printf 'input\tpath\tsha256\tbytes\n' > "$OUT/INPUT_AUTHORITY.tsv"
hash_exact() {
  local label="$1" path="$2" expected_sha="$3" expected_bytes="$4"
  [[ -f "$path" ]] || fail "input_missing=$label:$path" 65
  local got_sha got_bytes
  got_sha="$(sha256sum "$path" | awk '{print $1}')" ||
    fail "input_hash_failed=$label" 65
  got_bytes="$(stat -c '%s' "$path")" ||
    fail "input_stat_failed=$label" 65
  [[ "$got_sha" == "$expected_sha" ]] ||
    fail "input_sha_mismatch=$label:expected=$expected_sha:actual=$got_sha" 65
  [[ "$got_bytes" == "$expected_bytes" ]] ||
    fail "input_bytes_mismatch=$label:expected=$expected_bytes:actual=$got_bytes" 65
  printf '%s\t%s\t%s\t%s\n' "$label" "$path" "$got_sha" "$got_bytes" >> "$OUT/INPUT_AUTHORITY.tsv"
}
hash_exact N1F_SYSTEM "$N1F_IMAGE" "$N1F_SHA" "$N1F_BYTES"
hash_exact C2_SYSTEM "$C2_ARTIFACT_DIR/system.img" "$C2_SHA" "$C2_BYTES"

hash_pin() {
  local label="$1" path="$2" expected_sha="$3"
  [[ -f "$path" ]] || fail "input_missing=$label:$path" 65
  local got_sha got_bytes
  got_sha="$(sha256sum "$path" | awk '{print $1}')" ||
    fail "input_hash_failed=$label" 65
  got_bytes="$(stat -c '%s' "$path")" ||
    fail "input_stat_failed=$label" 65
  [[ "$got_sha" == "$expected_sha" ]] ||
    fail "input_sha_mismatch=$label:expected=$expected_sha:actual=$got_sha" 65
  printf '%s\t%s\t%s\t%s\n' "$label" "$path" "$got_sha" "$got_bytes" >> "$OUT/INPUT_AUTHORITY.tsv"
}

[[ -d "$STOCK_REF" ]] || fail "stock_ref_missing=$STOCK_REF" 65
hash_exact STOCK_SYSTEM "$STOCK_REF/system.img" "$STOCK_SYSTEM_SHA" "$STOCK_SYSTEM_BYTES"
hash_pin STOCK_SYSTEM_EXT "$STOCK_REF/system_ext.img" "$STOCK_SYSTEM_EXT_SHA"
hash_pin STOCK_PRODUCT "$STOCK_REF/product.img" "$STOCK_PRODUCT_SHA"
hash_pin STOCK_VENDOR "$STOCK_REF/vendor.img" "$STOCK_VENDOR_SHA"

STOCK_ODM_PIN_STATE=ABSENT
if [[ -f "$STOCK_REF/odm.img" ]]; then
  STOCK_ODM_PIN_STATE=UNKNOWN_UNPINNED
  printf 'STOCK_ODM\t%s\t%s\t%s\n' \
    "$STOCK_REF/odm.img" \
    "$(sha256sum "$STOCK_REF/odm.img" | awk '{print $1}')" \
    "$(stat -c '%s' "$STOCK_REF/odm.img")" >> "$OUT/INPUT_AUTHORITY.tsv"
fi

C1_AVAILABLE=NO
if [[ -f "$C1_ARTIFACT_DIR/system.img" ]]; then
  hash_exact C1_SYSTEM "$C1_ARTIFACT_DIR/system.img" "$C1_SHA" "$C1_BYTES"
  C1_AVAILABLE=YES
fi

image_type() {
  local image="$1" sparse ext4 erofs
  sparse="$(od -An -tx1 -j 0 -N 4 "$image" 2>/dev/null | tr -d ' \n')"
  ext4="$(od -An -tx1 -j 1080 -N 2 "$image" 2>/dev/null | tr -d ' \n')"
  erofs="$(od -An -tx1 -j 1024 -N 4 "$image" 2>/dev/null | tr -d ' \n')"
  if [[ "$sparse" == 3aff26ed ]]; then echo sparse
  elif [[ "$ext4" == 53ef ]]; then echo ext4
  elif [[ "$erofs" == e2e1f5e0 ]]; then echo erofs
  else echo unknown; fi
}

extract_image() {
  local image="$1" dest="$2" label="$3" type raw log
  type="$(image_type "$image")"
  mkdir -p "$dest"
  case "$type" in
    sparse)
      raw="$OUT/work/$label.raw.img"
      "$SABLE_SIMG2IMG" "$image" "$raw" >/dev/null || fail "simg2img_failed=$label" 65
      extract_image "$raw" "$dest" "$label-raw"
      rm -f "$raw"
      return ;;
    ext4)
      log="$OUT/work/$label.debugfs.log"
      debugfs -R "rdump / $dest" "$image" >/dev/null 2>"$log" || fail "debugfs_extract_failed=$label" 65 ;;
    erofs)
      log="$OUT/work/$label.erofs.log"
      fsck.erofs --extract="$dest" "$image" >/dev/null 2>"$log" || fail "erofs_extract_failed=$label" 65 ;;
    *) fail "unsupported_image_type=$label:$type" 65 ;;
  esac
  [[ -n "$(find "$dest" -mindepth 1 -print -quit)" ]] || fail "image_extract_empty=$label" 65
}

runtime_root() {
  local label="$1" image="$2" product_out="$3" expected_sha="$4"
  local po_sha extracted nested
  if [[ -f "$product_out/system.img" && -d "$product_out/system" ]]; then
    po_sha="$(sha256sum "$product_out/system.img" | awk '{print $1}')"
    if [[ "$po_sha" == "$expected_sha" ]]; then
      echo "N1I_D0_${label}_RUNTIME_ROOT_MODE=EXACT_PRODUCT_OUT" >&2
      printf '%s\n' "$product_out/system"
      return
    fi
  fi
  extracted="$OUT/work/${label,,}-system"
  extract_image "$image" "$extracted" "$label"
  nested="$extracted/system"
  [[ -f "$nested/build.prop" ]] && extracted="$nested"
  echo "N1I_D0_${label}_RUNTIME_ROOT_MODE=EXTRACTED_SEALED_IMAGE" >&2
  printf '%s\n' "$extracted"
}

echo "===== MATERIALIZE EXACT RUNTIME ROOTS ====="
N1F_ROOT="$(runtime_root N1F "$N1F_IMAGE" "$N1F_PRODUCT_OUT" "$N1F_SHA")" ||
  fail n1f_runtime_root_failed 65
C2_ROOT="$(runtime_root C2 "$C2_ARTIFACT_DIR/system.img" "$C2_PRODUCT_OUT" "$C2_SHA")" ||
  fail c2_runtime_root_failed 65
C1_ROOT=""
if [[ "$C1_AVAILABLE" == YES ]]; then
  C1_ROOT="$(runtime_root C1 "$C1_ARTIFACT_DIR/system.img" "$C1_PRODUCT_OUT" "$C1_SHA")" ||
    fail c1_runtime_root_failed 65
fi

echo "N1I_D0_N1F_RUNTIME_ROOT=$N1F_ROOT"
echo "N1I_D0_C2_RUNTIME_ROOT=$C2_ROOT"
if [[ -n "$C1_ROOT" ]]; then
  echo "N1I_D0_C1_BINARY_CONTROL=AVAILABLE"
else
  echo "N1I_D0_C1_BINARY_CONTROL=UNKNOWN_NOT_RETAINED"
fi

echo "===== MATERIALIZE PINNED STOCK AUTHORITY ====="
[[ -f "$C2_POSTBUILD/SHA256SUMS.txt" ]] ||
  fail c2_postbuild_seal_missing 65
(
  cd "$C2_POSTBUILD"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail c2_postbuild_seal_invalid 65
echo "N1I_D0_C2_POSTBUILD_EVIDENCE=PASS_SEALED"

STOCK_SYSTEM_RAW="$OUT/work/stock-system"
STOCK_SYSTEM_EXT="$OUT/work/stock-system-ext"
STOCK_PRODUCT="$OUT/work/stock-product"
STOCK_VENDOR="$OUT/work/stock-vendor"
STOCK_ODM=""
extract_image "$STOCK_REF/system.img" "$STOCK_SYSTEM_RAW" STOCK_SYSTEM
extract_image "$STOCK_REF/system_ext.img" "$STOCK_SYSTEM_EXT" STOCK_SYSTEM_EXT
extract_image "$STOCK_REF/product.img" "$STOCK_PRODUCT" STOCK_PRODUCT
extract_image "$STOCK_REF/vendor.img" "$STOCK_VENDOR" STOCK_VENDOR
STOCK_SYSTEM="$STOCK_SYSTEM_RAW"
[[ -f "$STOCK_SYSTEM_RAW/system/build.prop" ]] &&
  STOCK_SYSTEM="$STOCK_SYSTEM_RAW/system"

if [[ "$STOCK_ODM_PIN_STATE" == UNKNOWN_UNPINNED ]]; then
  echo "N1I_D0_STOCK_ODM_AUTHORITY=UNKNOWN_UNPINNED"
else
  echo "N1I_D0_STOCK_ODM_AUTHORITY=ABSENT_STANDALONE_IMAGE"
fi
echo "N1I_D0_STOCK_AUTHORITY=PASS_FRESH_EXTRACTION_PINNED_SYSTEM_SYSTEM_EXT_PRODUCT_VENDOR"

echo "===== MATERIALIZE PINNED APEX RUNTIME ROOTS ====="
STOCK_APEX_ROOT="$OUT/work/stock-apex"
N1F_APEX_ROOT="$OUT/work/n1f-apex"
C2_APEX_ROOT="$OUT/work/c2-apex"
"$SABLE_PYTHON" "$APEX_MATERIALIZER" \
  --system-root "$STOCK_SYSTEM" \
  --out "$STOCK_APEX_ROOT" \
  --debugfs "$(command -v debugfs)" \
  --fsck-erofs "$(command -v fsck.erofs)" ||
  fail stock_apex_materialization_failed 65
"$SABLE_PYTHON" "$APEX_MATERIALIZER" \
  --system-root "$N1F_ROOT" \
  --out "$N1F_APEX_ROOT" \
  --debugfs "$(command -v debugfs)" \
  --fsck-erofs "$(command -v fsck.erofs)" ||
  fail n1f_apex_materialization_failed 65
"$SABLE_PYTHON" "$APEX_MATERIALIZER" \
  --system-root "$C2_ROOT" \
  --out "$C2_APEX_ROOT" \
  --debugfs "$(command -v debugfs)" \
  --fsck-erofs "$(command -v fsck.erofs)" ||
  fail c2_apex_materialization_failed 65
(
  cd "$STOCK_APEX_ROOT" || exit 1
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail stock_apex_seal_invalid 65
(
  cd "$N1F_APEX_ROOT" || exit 1
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail n1f_apex_seal_invalid 65
(
  cd "$C2_APEX_ROOT" || exit 1
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail c2_apex_seal_invalid 65
echo "N1I_D0_STOCK_APEX_AUTHORITY=PASS_FRESH_FROM_PINNED_STOCK_IMAGE"
echo "N1I_D0_N1F_APEX_AUTHORITY=PASS_FRESH_FROM_PINNED_N1F_IMAGE"
echo "N1I_D0_C2_APEX_AUTHORITY=PASS_FRESH_FROM_PINNED_C2_IMAGE"

{
  printf 'tool\tpath\tsha256\n'
  for pair in \
    "secilc:$SABLE_SECILC" \
    "property_info_checker:$PROPERTY_INFO_CHECKER" \
    "simg2img:$SABLE_SIMG2IMG" \
    "aapt2:$AAPT2" \
    "apksigner:$APKSIGNER" \
    "python:$SABLE_PYTHON" \
    "init_selinux_source:$ANDROID_ROOT/system/core/init/selinux.cpp" \
    "sepolicy_android_bp:$ANDROID_ROOT/system/sepolicy/Android.bp" \
    "b2_members_source:$ROOT/build/titan2/n1i-b2-members.py" \
    "b2_native_source:$ROOT/build/titan2/n1i-b2-native.py" \
    "runtime_classpath_deriver_source:$ROOT/build/titan2/derive-n1i-c1-runtime-classpath.py"
  do
    name="${pair%%:*}"
    path="${pair#*:}"
    if [[ -f "$path" ]]; then
      printf '%s\t%s\t%s\n' "$name" "$path" "$(sha256sum "$path" | awk '{print $1}')"
    else
      printf '%s\t%s\t%s\n' "$name" "$path" "UNKNOWN_NOT_AVAILABLE"
    fi
  done
} > "$OUT/TOOL_AUTHORITY.tsv"

echo "===== D0-B0 / GATES A-F ====="
PY_ARGS=(
  "$SABLE_PYTHON" "$ROOT/build/titan2/audit-n1i-d0-host.py"
  --repo "$ROOT"
  --android-root "$ANDROID_ROOT"
  --n1f-root "$N1F_ROOT"
  --c2-root "$C2_ROOT"
  --n1f-apex-root "$N1F_APEX_ROOT"
  --c2-apex-root "$C2_APEX_ROOT"
  --stock-apex-root "$STOCK_APEX_ROOT"
  --c2-linkage-evidence "$C2_LINKAGE"
  --stock-system "$STOCK_SYSTEM"
  --stock-system-ext "$STOCK_SYSTEM_EXT"
  --stock-product "$STOCK_PRODUCT"
  --stock-vendor "$STOCK_VENDOR"
  --secilc "$SABLE_SECILC"
  --property-info-checker "$PROPERTY_INFO_CHECKER"
  --aapt2 "$AAPT2"
  --apksigner "$APKSIGNER"
  --out "$OUT/gates"
)
[[ -n "$C1_ROOT" ]] && PY_ARGS+=(--c1-root "$C1_ROOT")
[[ -n "$STOCK_ODM" ]] && PY_ARGS+=(--stock-odm "$STOCK_ODM")
if [[ "$STOCK_ODM_PIN_STATE" == UNKNOWN_UNPINNED ]]; then
  PY_ARGS+=(--stock-odm-unpinned)
fi
"${PY_ARGS[@]}" ||
  fail d0_host_analyzer_failed 66

echo "===== GATE G: B2 NATIVE REDERIVATION ====="
IMS="$C2_ROOT/system_ext/priv-app/ImsService/ImsService.apk"
COMMON="$C2_ROOT/system_ext/framework/mediatek-common.jar"
IMS_BASE="$C2_ROOT/system_ext/framework/mediatek-ims-base.jar"
for path in "$IMS" "$COMMON" "$IMS_BASE"; do [[ -f "$path" ]] || fail "gate_g_input_missing=$path" 66; done

BADGING="$OUT/gates/gate-g-ims-badging.txt"
"$AAPT2" dump badging "$IMS" > "$BADGING" || fail gate_g_badging_failed 66

LIB_ARGS=()
for spec in \
  "system=$C2_ROOT/lib64" \
  "system_ext=$C2_ROOT/system_ext/lib64" \
  "product=$C2_ROOT/product/lib64" \
  "vendor=$STOCK_VENDOR/lib64"
do
  dir="${spec#*=}"
  [[ -d "$dir" ]] && LIB_ARGS+=(--lib-dir "$spec")
done
[[ -n "$STOCK_ODM" && -d "$STOCK_ODM/lib64" ]] &&
  LIB_ARGS+=(--lib-dir "odm=$STOCK_ODM/lib64")
while IFS= read -r apex_libdir; do
  [[ -d "$apex_libdir" ]] &&
    LIB_ARGS+=(--lib-dir "apex=$apex_libdir")
done < <(
  find "$C2_APEX_ROOT" -mindepth 2 -maxdepth 3 -type d -name lib64 -print |
    LC_ALL=C sort
)

VISIBLE_ARGS=()
while IFS= read -r list; do
  VISIBLE_ARGS+=(--namespace-visible-list "$list")
done < <(
  find \
    "$C2_ROOT/etc" \
    "$C2_ROOT/system_ext/etc" \
    "$C2_ROOT/product/etc" \
    -maxdepth 2 -type f -name 'public.libraries*.txt' -print 2>/dev/null |
    LC_ALL=C sort -u
)

run_native() {
  local label="$1" container="$2"
  local target="$OUT/gates/gate-g-$label"
  local extra=()
  [[ "$label" == ims ]] && extra+=(--badging "$BADGING")
  "$SABLE_PYTHON" "$ROOT/build/titan2/n1i-b2-native.py" \
    --side c3a \
    --apk "$container" \
    --abi arm64-v8a \
    "${LIB_ARGS[@]}" \
    "${VISIBLE_ARGS[@]}" \
    "${extra[@]}" \
    --search-superset "$ROOT/product/titan2/n1i-c1/a4-native-superset.txt" \
    --out "$target"
}
GATE_G_FAILURES=0
GATE_G_INPUT_DIR="$OUT/gates/gate-g-inputs"
mkdir -p "$GATE_G_INPUT_DIR" || fail gate_g_input_dir_failed 66
for spec in \
  "ims:$IMS" \
  "mediatek-common:$COMMON" \
  "mediatek-ims-base:$IMS_BASE"
do
  label="${spec%%:*}"
  source_container="${spec#*:}"
  analysis_container="$GATE_G_INPUT_DIR/$label.zip"
  analysis_env="$GATE_G_INPUT_DIR/$label.env"
  if ! "$SABLE_PYTHON" "$DEX_PREPARER" \
      --input "$source_container" \
      --out "$analysis_container" \
      --env "$analysis_env"
  then
    echo "N1I_D0_GATE_G_INPUT_PREPARATION=UNKNOWN label=$label"
    GATE_G_FAILURES=$((GATE_G_FAILURES + 1))
    continue
  fi
  if ! run_native "$label" "$analysis_container"; then
    echo "N1I_D0_GATE_G_ANALYZER_FAILURE=$label"
    GATE_G_FAILURES=$((GATE_G_FAILURES + 1))
  fi
done

if [[ "$GATE_G_FAILURES" -eq 0 ]]; then
  if ! "$SABLE_PYTHON" "$ROOT/build/titan2/summarize-n1i-d0-native.py" \
    --gates "$OUT/gates" \
    --a4 "$ROOT/product/titan2/n1i-c1/a4-native-superset.txt"
  then
    GATE_G_FAILURES=1
  fi
fi

if [[ "$GATE_G_FAILURES" -ne 0 ]]; then
  {
    echo "N1I_D0_GATE_G=UNKNOWN_ANALYZER_UNCLOSED"
    echo "N1I_D0_GATE_G_ANALYZER_FAILURE_COUNT=$GATE_G_FAILURES"
    echo "N1I_D0_GATE_G_A4_IMPORT_AUTHORITY=RETIRED"
    echo "N1I_D0_GATE_G_N1F=NOT_APPLICABLE"
  } > "$OUT/gates/GATE_G.env"
  {
    echo "N1I_D0_GATE_G2=UNKNOWN_GATE_G_UNCLOSED"
    echo "N1I_D0_GATE_G2_SYMBOL_VERSION_PROOF=UNKNOWN_GATE_G_UNCLOSED"
    echo "N1I_D0_GATE_G2_LINKER_NAMESPACE_MODEL=UNKNOWN_GATE_G_UNCLOSED"
  } > "$OUT/gates/GATE_G2.env"
fi

cat "$OUT/gates/GATE_G.env"
cat "$OUT/gates/GATE_G2.env"

D0_VERDICT="$(sed -n 's/^N1I_D0_0H=//p' "$OUT/gates/N1I_D0_HOST_SUMMARY.env")"
C1J_PRE_NATIVE_READY="$(
  sed -n 's/^N1I_D0_C1J_PRE_NATIVE_READY=//p' "$OUT/gates/N1I_D0_HOST_SUMMARY.env"
)"
G2_STATE="$(sed -n 's/^N1I_D0_GATE_G2=//p' "$OUT/gates/GATE_G2.env")"
C1J_READY=NO
case "$G2_STATE" in
  NOT_APPLICABLE_NO_B2_NATIVE_ADMISSION)
    [[ "$C1J_PRE_NATIVE_READY" == YES ]] && C1J_READY=YES
    ;;
  PASS*)
    [[ "$C1J_PRE_NATIVE_READY" == YES ]] && C1J_READY=YES
    ;;
  *)
    C1J_READY=NO
    ;;
esac

{
  echo "TOOL_SOURCE_COMMIT=$REPO_HEAD"
  echo "N1I_D0_0H=$D0_VERDICT"
  echo "N1I_D0_C1J_COMPOSITION_READY=$C1J_READY"
  echo "N1I_D0_A4_IMPORT_AUTHORITY=RETIRED"
  echo "N1I_D0_NEXT_BUILD_AUTHORIZED=NO"
  echo "N1I_D0_DEVICE_CONTACT=NONE"
  echo "N1I_D0_MODE_TRANSITION=NONE"
  echo "N1I_D0_REBOOT=NONE"
  echo "N1I_D0_FLASH=NONE"
} > "$OUT/N1I_D0_SUMMARY.env"

REPO_STATUS_AFTER="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail source_status_after_unavailable 70
[[ -z "$REPO_STATUS_AFTER" ]] || fail source_mutated_during_d0 70
(
  cd "$OUT" || exit 1
  find . -type f ! -name SHA256SUMS.txt ! -name run.log -print0 \
    > .seal-files || exit 1
  LC_ALL=C sort -z .seal-files -o .seal-files || exit 1
  xargs -0 sha256sum < .seal-files > SHA256SUMS.txt || exit 1
  rm -f .seal-files || exit 1
  sha256sum -c SHA256SUMS.txt >/dev/null || exit 1
) || fail evidence_seal_invalid 70

cat "$OUT/N1I_D0_SUMMARY.env"
echo "N1I_D0_EVIDENCE_SEAL=PASS_EXCLUDES_RUN_LOG"
echo "N1I_D0_HOST_CLOSURE=PASS_EXECUTED"
echo "N1I_D0_EVIDENCE_DIR=$OUT"
