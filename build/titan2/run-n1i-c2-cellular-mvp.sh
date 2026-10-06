#!/usr/bin/env bash
# Titan 2 N1I-C2 Cellular MVP one-candidate implementation/build driver.
#
# Deliberately does not use top-level errexit/pipefail. Child return codes are
# captured explicitly so an operator shell is never terminated by a sourced or
# pasted strict-mode fragment.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
source "$ROOT/build/titan2/n1d-fresh-source.env"
source "$ROOT/build/titan2/n1d-c3-trebledroid.env"
source "$ROOT/build/titan2/n1d-c3a-control-evidence.env"
source "$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
source "$ROOT/build/titan2/n1i-c-oem-ims-admission.env"

MODE=--direct
JOBS="${SABLE_BUILD_JOBS:-$(nproc --all)}"
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO

fail() {
    echo "N1I_C2_BUILD=FAIL reason=$1" >&2
    return "${2:-1}"
}

usage() {
    cat <<'EOF'
Usage:
  run-n1i-c2-cellular-mvp.sh [--direct|--tmux] \
    --authorize-source-mutation --authorize-build [--jobs N]

The driver mutates only the exact reviewed Android-source files and temporary
vendor/sable staging tree, builds one system.img, then restores source.
It never contacts a device, reboots, flashes, or fetches from the network.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --direct) MODE=--direct; shift ;;
        --tmux) MODE=--tmux; shift ;;
        --authorize-source-mutation) SOURCE_MUTATION_AUTHORIZED=YES; shift ;;
        --authorize-build) BUILD_AUTHORIZED=YES; shift ;;
        --jobs)
            [[ $# -ge 2 ]] || { fail missing_jobs_value 64; exit $?; }
            JOBS="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown_argument=$1" 64; exit $? ;;
    esac
done

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { fail "invalid_jobs=$JOBS" 64; exit $?; }
[[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] ||
    { fail source_mutation_requires_authorization 64; exit $?; }
[[ "$BUILD_AUTHORIZED" == YES ]] ||
    { fail build_requires_authorization 64; exit $?; }

SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
    { fail "bad_source_commit=$SOURCE_COMMIT" 64; exit $?; }

if [[ "$MODE" == --tmux ]]; then
    SESSION="${SABLE_TMUX_SESSION:-sable-titan2-n1i-c2-${SOURCE_COMMIT:0:12}}"
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        fail "tmux_session_exists=$SESSION" 5
        exit $?
    fi
    self="$ROOT/build/titan2/run-n1i-c2-cellular-mvp.sh"
    tmux new-session -d -s "$SESSION" \
        "EXPECTED_SOURCE_COMMIT='$SOURCE_COMMIT' SABLE_BUILD_JOBS='$JOBS' bash '$self' --direct --authorize-source-mutation --authorize-build; rc=\$?; echo; echo N1I_C2_BUILD_RC=\$rc; echo BUILD_DRIVER_EXITED=YES; exit \$rc" ||
        { fail "tmux_new_session_failed=$SESSION"; exit $?; }
    tmux set-window-option -t "$SESSION" remain-on-exit on >/dev/null ||
        { fail "tmux_remain_on_exit_failed=$SESSION"; exit $?; }
    echo "N1I_C2_BUILD=PASS_STARTED"
    echo "SESSION=$SESSION"
    echo "SESSION_RETENTION=remain-on-exit"
    echo "ATTACH=tmux attach -t $SESSION"
    exit 0
fi

[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$SOURCE_COMMIT" ]] ||
    { fail source_identity; exit $?; }
[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] ||
    { fail sable_repo_dirty; git -C "$ROOT" status --short >&2; exit 65; }

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_DIR_C2="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-n1i-c2-${SOURCE_COMMIT:0:12}"
PRODUCT_OUT="$OUT_DIR_C2/target/product/tdgsi_arm64_ab"
ROM_MK="$ANDROID_ROOT/device/phh/treble/rom.mk"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"
C3B_STAGE="$STAGE_ROOT/c3b"
C1_STAGE="$STAGE_ROOT/n1i-c1"
C2_STAGE="$STAGE_ROOT/n1i-c2"

C3A_CONTROL="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/20261003T221350Z/system.img"
N1F_CONTROL="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img"
C3A_SHA="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
N1F_SHA="dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a"
N1F_BYTES=3200540672
C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
C1_BYTES=3210661888
C1_CONTROL_DIR="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-cellular-isolation/20261005T133622Z-a745c7daa082-postbuild"
C1_CONTROL="$C1_CONTROL_DIR/system.img"
PRIOR_FAILED_SOURCE_COMMIT="36b53950faebc954cadb30756833ae5ec857f054"
PRIOR_FAILED_OUT="$SABLE_WORKSPACES_ROOT/titan2-n1d/out-n1i-c2-36b53950faeb"
PRIOR_FAILED_PRODUCT_OUT="$PRIOR_FAILED_OUT/target/product/tdgsi_arm64_ab"
PRIOR_FAILED_INSTALLS="$PRIOR_FAILED_OUT/soong/installs-treble_arm64_bvN.mk"
KNOWN_KATI_COLLISION_TARGET="/system/lib64/android.hardware.drm-V1-ndk.so"
SYSTEM_GROUP_SAFE_CEILING=3263168512

MATERIALIZED="/srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp-stock/20261005T231205Z"
MATERIALIZATION_EVIDENCE="/srv/sable-build/evidence/titan2/n1i-c2-cellular-mvp-materialization/20261005T231205Z"
MANIFEST_EVIDENCE="/srv/sable-build/evidence/titan2/n1i-c2-cellular-mvp-manifest/20261005T215928Z-8ebeebdb"
MATERIALIZATION_SOURCE_COMMIT="adb57fa5bffb24e2fe24f4f0afc6b5550bb570f3"

STOCK_REF="$SABLE_TITAN2_ROOT/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference"
STOCK_SYSTEM="$STOCK_REF/system.img"
STOCK_SYSTEM_EXT="$STOCK_REF/system_ext.img"
STOCK_SYSTEM_SHA="b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd"
STOCK_SYSTEM_EXT_SHA="1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170"

APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
C3B_TEMPLATE="$ROOT/product/titan2/c3b"
C1_TEMPLATE="$ROOT/product/titan2/n1i-c1"
C2_TEMPLATE="$ROOT/product/titan2/n1i-c2"
TMETRICS_QUALIFIER="$ROOT/build/titan2/qualify-n1i-c1-telephonymetrics-compat.sh"
PHH_PATCH="$ROOT/patches/android-16-n1i-c2/phh/0001-phh-preserve-mtk-ims-for-titan2-cellular-mvp.patch"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"
IMPLEMENTATION_CONTRACT="$ROOT/build/gates/n1i-c2-cellular-mvp-implementation-contract.sh"
BUILD_REGRESSION_CONTRACT="$ROOT/build/gates/build-regression-contract.py"
INSTALL_COLLISION_AUDIT="$ROOT/build/titan2/audit-n1i-c2-install-collisions.py"
NATIVE_INSTALL_PLANNER="$ROOT/build/titan2/plan-n1i-c2-native-install.py"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"

TMETRICS_BASE_BLOB="27638e5be9c008101c2f9b8f1e7a9af49d94f838"
TMETRICS_POST_BLOB="9d5108e0ddb8d4960d21cda021813b53dbbf4da8"
INCOMING_TRACKER_BLOB="5f97183b6f8c80859adf3f4922b3f9f56687bab5"
PHH_BASE_BLOB="9f65610762fec239638bb269b8c72d6cabfc6d7e"
PHH_PATCH_BLOB="d78f41da30514920ff2165d8fe6dea15d0bb5d76"

TMETRICS_REL="src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java"
INCOMING_REL="src/java/com/android/internal/telephony/imsphone/ImsPhoneCallTracker.java"
PHH_REL="phh-on-boot.sh"
MTK_MMTEL_OVERLAY_MODULE="treble-overlay-telephony-mtk-ims"
MTK_MMTEL_OVERLAY_PACKAGE="me.phh.treble.overlay.mtkims_telephony"

MODULES=(SableTitan2Keyboard SableTitan2Camera SableTitan2DisplayCompat SableTitan2Setup SableTitan2RadioDiag)

latest_c3a_stage() {
    find "$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-prep" \
        -mindepth 1 -maxdepth 1 -type d -name '*-trebledroid-stage' -print 2>/dev/null |
        LC_ALL=C sort | tail -1
}

verify_c3a_source() {
    local stage tmp count
    stage="$(latest_c3a_stage)"
    [[ -n "$stage" && -f "$stage/SHA256SUMS.txt" && -f "$stage/postpatch-project-heads.tsv" ]] ||
        { fail c3a_stage_evidence_missing; return $?; }
    (cd "$stage"; sha256sum -c SHA256SUMS.txt >/dev/null) ||
        { fail c3a_stage_seal; return $?; }

    tmp="$(mktemp -d)"
    (
        cd "$ANDROID_ROOT" || exit 1
        "$SABLE_REPO_TOOL" forall -c 'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"' |
            LC_ALL=C sort > "$tmp/current.tsv"
        "$SABLE_REPO_TOOL" forall -c 's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "%s\n" "$REPO_PATH"; fi' |
            LC_ALL=C sort > "$tmp/dirty.tsv"
    ) || { rm -rf "$tmp"; fail c3a_repo_state_capture; return $?; }

    count="$(grep -cve '^$' "$tmp/current.tsv" || true)"
    [[ "$count" == "$N1D_C3A_MANAGED_PROJECT_COUNT" ]] ||
        { rm -rf "$tmp"; fail "c3a_project_count=$count"; return $?; }

    LC_ALL=C sort "$stage/postpatch-project-heads.tsv" > "$tmp/expected.tsv"
    cmp -s "$tmp/expected.tsv" "$tmp/current.tsv" ||
        { diff -u "$tmp/expected.tsv" "$tmp/current.tsv" >&2 || true; rm -rf "$tmp"; fail c3a_heads; return $?; }

    printf '%s\n' build/soong device/phh/treble treble_app | LC_ALL=C sort > "$tmp/expected-dirty.tsv"
    cmp -s "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" ||
        { diff -u "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" >&2 || true; rm -rf "$tmp"; fail c3a_dirty_set; return $?; }

    rm -rf "$tmp"
    echo "N1I_C2_C3A_SOURCE=PASS projects=$count dirty=3"
}

verify_audit() {
    local e="$N1I_C_AUDIT_EVIDENCE_DIR"
    [[ "$(sha256sum "$e/N1I_A_V010014_OEM_IMS_REPORT.md" | awk '{print $1}')" == "$N1I_C_AUDIT_REPORT_SHA256" ]] ||
        { fail audit_report_hash; return $?; }
    [[ "$(sha256sum "$e/n1i-a-v010014-oem-ims.env" | awk '{print $1}')" == "$N1I_C_AUDIT_ENV_SHA256" ]] ||
        { fail audit_env_hash; return $?; }
    grep -Fxq 'N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS' "$e/n1i-a-v010014-oem-ims.env" ||
        { fail audit_not_pass; return $?; }
    echo "N1I_C2_AUDIT_INPUTS=PASS_EXACT"
}

verify_materialization() {
    for dir in "$MATERIALIZED" "$MATERIALIZATION_EVIDENCE" "$MANIFEST_EVIDENCE"; do
        [[ -d "$dir" && -f "$dir/SHA256SUMS.txt" ]] ||
            { fail "sealed_dir_missing=$dir"; return $?; }
        (cd "$dir"; sha256sum -c SHA256SUMS.txt >/dev/null) ||
            { fail "seal_invalid=$dir"; return $?; }
    done

    grep -Fxq 'N1I_C2_MATERIALIZATION_STOCK_FILE_COUNT=36' "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
        { fail materialized_stock_count; return $?; }
    grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT=33' "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
        { fail materialized_native_count; return $?; }
    grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_HASH_COUNT=33' "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
        { fail materialized_native_hash_count; return $?; }
    grep -Fxq 'N1I_C2_MATERIALIZATION_MUTATION_COUNT=41' "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
        { fail materialized_mutation_count; return $?; }
    grep -Fxq 'N1I_C2_CELLULAR_MVP_STOCK_MATERIALIZATION=PASS' "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
        { fail materialization_not_pass; return $?; }
    grep -Fxq "N1I_C2_MATERIALIZATION_SOURCE_COMMIT=$MATERIALIZATION_SOURCE_COMMIT" "$MATERIALIZATION_EVIDENCE/materialization-driver.env" ||
        { fail materialization_source_commit; return $?; }

    echo "N1I_C2_MATERIALIZATION_AUTHORITY=PASS_EXACT"
}

image_type() {
    local img="$1"
    if [[ "$(od -An -tx1 -j 0 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == 3aff26ed ]]; then
        echo sparse
    elif [[ "$(od -An -tx1 -j 1080 -N 2 "$img" 2>/dev/null | tr -d ' \n')" == 53ef ]]; then
        echo ext4
    elif [[ "$(od -An -tx1 -j 1024 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == e2e1f5e0 ]]; then
        echo erofs
    else
        echo unknown
    fi
}

extract_fs() {
    local img="$1" dest="$2" kind raw
    kind="$(image_type "$img")"
    mkdir -p "$dest" || return 1
    case "$kind" in
        sparse)
            raw="$dest.raw.img"
            "$SABLE_SIMG2IMG" "$img" "$raw" >/dev/null || return 1
            extract_fs "$raw" "$dest" || return 1
            rm -f "$raw"
            ;;
        ext4)
            debugfs -R "rdump / $dest" "$img" >/dev/null 2>"$dest.debugfs.log" || return 1
            ;;
        erofs)
            fsck.erofs --extract="$dest" "$img" >/dev/null 2>"$dest.erofs.log" || return 1
            ;;
        *)
            return 1
            ;;
    esac
}

stock_system_root() {
    [[ -f "$1/system/build.prop" ]] && printf '%s\n' "$1/system" || printf '%s\n' "$1"
}

copy_stock_config_path() {
    local p="$1" sys="$2" ext="$3" src dest rel
    case "$p" in
        /system_ext/*) rel="${p#/system_ext/}"; src="$ext/$rel" ;;
        /system/*) rel="${p#/system/}"; src="$sys/$rel" ;;
        *) fail "unsupported_config_payload=$p"; return $? ;;
    esac
    [[ -f "$src" ]] || { fail "config_payload_missing=$p"; return $?; }
    dest="$C1_STAGE/prebuilt$p"
    mkdir -p "$(dirname "$dest")" || return 1
    install -m 0644 "$src" "$dest" || return 1
}

generate_property_policy() {
    local stock_cil="$1" contexts="$2" output="$3"
    [[ -f "$stock_cil" && -f "$contexts" ]] || return 1
    python3 - "$stock_cil" "$contexts" "$output" <<'PY'
import re
import sys
from pathlib import Path

cil_path = Path(sys.argv[1])
contexts_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])
cil = cil_path.read_text(encoding="utf-8", errors="replace")

types = []
for raw in contexts_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    match = re.search(r":([A-Za-z0-9_]+):s0$", line.split()[-1])
    if not match:
        raise SystemExit(f"N1I_C2_PROPERTY_POLICY=FAIL_CONTEXT_PARSE line={line}")
    types.append(match.group(1))

if not types:
    raise SystemExit("N1I_C2_PROPERTY_POLICY=FAIL_TYPE_SET")

unique_types = sorted(set(types))
if len(types) != 9 or len(unique_types) != 5:
    raise SystemExit(
        "N1I_C2_PROPERTY_POLICY=FAIL_TYPE_SET "
        f"contexts={len(types)} unique_types={len(unique_types)}"
    )

classes = {
    "system_internal_property_type": "system_internal_prop",
    "system_restricted_property_type": "system_restricted_prop",
    "system_public_property_type": "system_public_prop",
}
members = {}
for attr, macro in classes.items():
    match = re.search(
        rf"\(typeattributeset\s+{re.escape(attr)}\s+\((.*?)\)\)",
        cil,
        re.S,
    )
    if not match:
        raise SystemExit(f"N1I_C2_PROPERTY_POLICY=FAIL_ATTRIBUTE_MISSING attr={attr}")
    members[attr] = set(re.findall(r"[A-Za-z0-9_]+", match.group(1)))

lines = [
    "# Generated at build time from pinned V01.00.14 system_ext_sepolicy.cil.",
    "# Classification is stock-derived; no property ownership class is guessed.",
]
for typ in unique_types:
    if not re.search(rf"\(type\s+{re.escape(typ)}\)", cil):
        raise SystemExit(f"N1I_C2_PROPERTY_POLICY=FAIL_TYPE_MISSING type={typ}")
    hits = [(attr, macro) for attr, macro in classes.items() if typ in members[attr]]
    if len(hits) != 1:
        raise SystemExit(
            f"N1I_C2_PROPERTY_POLICY=FAIL_CLASS_AMBIGUOUS type={typ} "
            f"classes={','.join(x[0] for x in hits) or 'none'}"
        )
    _attr, macro = hits[0]
    lines.append(f"{macro}({typ})")

out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"N1I_C2_PROPERTY_CONTEXT_COUNT={len(types)}")
print(f"N1I_C2_PROPERTY_TYPE_COUNT={len(unique_types)}")
print("N1I_C2_PROPERTY_POLICY=PASS_STOCK_DERIVED")
PY
}

apk_package_name() {
    local apk="$1" out package
    out="$("$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump badging "$apk")" || return 1
    package="$(sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" <<<"$out" | sed -n '1p')"
    [[ -n "$package" ]] || return 1
    printf '%s\n' "$package"
}

apk_shared_uid() {
    local apk="$1" out uid
    out="$("$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$apk")" || return 1
    uid="$(sed -n 's/.*sharedUserId[^=]*="\([^"]*\)".*/\1/p' <<<"$out" | sed -n '1p')"
    [[ -n "$uid" ]] || return 1
    printf '%s\n' "$uid"
}

built_target_path() {
    local target="$1"
    case "$target" in
        /system_ext/*) printf '%s/system/system_ext/%s\n' "$PRODUCT_OUT" "${target#/system_ext/}" ;;
        /system/*) printf '%s/system/%s\n' "$PRODUCT_OUT" "${target#/system/}" ;;
        /product/*) printf '%s/system/product/%s\n' "$PRODUCT_OUT" "${target#/product/}" ;;
        *) return 1 ;;
    esac
}

prepare_stock_map() {
    local out="$1"
    python3 - "$MATERIALIZED" "$C1_TEMPLATE/a4-native-superset.txt" "$out" <<'PY'
import csv
import hashlib
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
a4 = pathlib.Path(sys.argv[2])
out = pathlib.Path(sys.argv[3])
manifest = root / "CELLULAR_MVP_FROZEN_MUTATION_MANIFEST.tsv"

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

with manifest.open(encoding="utf-8", newline="") as fp:
    rows = list(csv.DictReader(fp, delimiter="\t"))

expected = {"M001", "M002", "M003"} | {f"M{i:03d}" for i in range(7, 40)}
selected = [r for r in rows if r["id"] in expected]
if {r["id"] for r in selected} != expected or len(selected) != 36:
    raise SystemExit("N1I_C2_STOCK_MAP=FAIL_ID_SET")

native = 0
lines = []
for row in sorted(selected, key=lambda r: r["id"]):
    if row["status"] != "MATERIALIZED_VERIFIED":
        raise SystemExit(f"N1I_C2_STOCK_MAP=FAIL_STATUS id={row['id']}")
    prefix = "SEALED_STOCK_BUNDLE:"
    if not row["source"].startswith(prefix):
        raise SystemExit(f"N1I_C2_STOCK_MAP=FAIL_SOURCE id={row['id']}")
    rel = row["source"][len(prefix):]
    src = root / rel
    if not src.is_file():
        raise SystemExit(f"N1I_C2_STOCK_MAP=FAIL_FILE id={row['id']} path={src}")
    digest = sha256(src)
    if digest != row["sha256_or_blob"]:
        raise SystemExit(
            f"N1I_C2_STOCK_MAP=FAIL_HASH id={row['id']} "
            f"expected={row['sha256_or_blob']} actual={digest}"
        )
    kind = "NATIVE" if row["domain"] == "NATIVE" else row["domain"]
    if kind == "NATIVE":
        native += 1
    lines.append("\t".join((row["id"], kind, row["target"], rel, digest)))

if native != 33:
    raise SystemExit(f"N1I_C2_STOCK_MAP=FAIL_NATIVE_COUNT count={native}")

a4_targets = {
    line.strip()
    for line in a4.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
}
native_targets = {row["target"] for row in selected if row["domain"] == "NATIVE"}
if len(a4_targets) != 33 or native_targets != a4_targets:
    raise SystemExit(
        "N1I_C2_STOCK_MAP=FAIL_A4_TARGET_SET "
        f"expected={len(a4_targets)} actual={len(native_targets)}"
    )

out.write_text(
    "id\tkind\ttarget\tbundle_rel\tsha256\n" + "\n".join(lines) + "\n",
    encoding="utf-8",
)
print("N1I_C2_STOCK_MAP=PASS files=36 natives=33 exact_a4_targets=YES")
PY
}

generate_vendor_ua_config() {
    local output="$1"
    python3 - "$MANIFEST_EVIDENCE/CELLULAR_MVP_VENDOR_UA.tsv" "$output" <<'PY'
import csv
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
with src.open(encoding="utf-8", newline="") as fp:
    rows = list(csv.DictReader(fp, delimiter="\t"))

if len(rows) != 1:
    raise SystemExit(f"N1I_C2_VENDOR_UA_CONFIG=FAIL_COUNT count={len(rows)}")

row = rows[0]
service = row.get("service", "")
decision = row.get("decision", "")
start_mode = row.get("start_mode", "")
if not re.fullmatch(r"[A-Za-z0-9_.-]+", service):
    raise SystemExit(f"N1I_C2_VENDOR_UA_CONFIG=FAIL_SERVICE value={service!r}")
if decision != "OBSERVE_READINESS":
    raise SystemExit(f"N1I_C2_VENDOR_UA_CONFIG=FAIL_DECISION value={decision!r}")
if not re.fullmatch(r"[A-Za-z0-9_.-]+", start_mode):
    raise SystemExit(f"N1I_C2_VENDOR_UA_CONFIG=FAIL_START_MODE value={start_mode!r}")

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(
    "SABLE_TITAN2_IMS_PACKAGE=com.mediatek.ims\n"
    "SABLE_TITAN2_SLOT=0\n"
    f"SABLE_TITAN2_VENDOR_UA_SERVICE={service}\n"
    f"SABLE_TITAN2_VENDOR_UA_DECISION={decision}\n"
    f"SABLE_TITAN2_VENDOR_UA_START_MODE={start_mode}\n",
    encoding="utf-8",
)
print(
    "N1I_C2_VENDOR_UA_CONFIG=PASS "
    f"service={service} decision={decision} start_mode={start_mode}"
)
PY
}

generate_implementation_receipt() {
    local output="$1"
    python3 - \
        "$MATERIALIZED/CELLULAR_MVP_FROZEN_MUTATION_MANIFEST.tsv" \
        "$output" \
        "$TMETRICS_POST_BLOB" \
        "$PHH_POST_BLOB" \
        "$NEW_SHA" \
        "$NEW_BYTES" <<'PY'
import csv
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
tmetrics_post = sys.argv[3]
phh_post = sys.argv[4]
system_sha = sys.argv[5]
system_bytes = sys.argv[6]

with manifest.open(encoding="utf-8", newline="") as fp:
    rows = list(csv.DictReader(fp, delimiter="\t"))

expected_ids = [f"M{i:03d}" for i in range(1, 42)]
if [row.get("id") for row in rows] != expected_ids:
    raise SystemExit("N1I_C2_IMPLEMENTATION_RECEIPT=FAIL_ID_ORDER")

status = {}
evidence = {}

for mid in ("M001", "M002", "M003"):
    status[mid] = "IMPLEMENTED_BUILT"
    evidence[mid] = "PRODUCT_OUT_AND_FINAL_SYSTEMIMAGE"
for i in range(7, 40):
    mid = f"M{i:03d}"
    status[mid] = "IMPLEMENTED_EXACT_FROZEN_HASH"
    evidence[mid] = "PRODUCT_OUT_HASH_EQUALS_MATERIALIZATION"

status["M004"] = "IMPLEMENTED_EXACT_PATCH"
evidence["M004"] = f"TelephonyMetrics_post_blob={tmetrics_post}"
status["M005"] = "IMPLEMENTED_PRODUCT_PROPERTY"
evidence["M005"] = "ro.telephony.block_binder_thread_on_incoming_calls=false"
status["M006"] = "IMPLEMENTED_EXACT_PATCH"
evidence["M006"] = f"phh_on_boot_post_blob={phh_post}"
status["M040"] = "IMPLEMENTED_BUILT"
evidence["M040"] = "SableTitan2Cellular+init+config+marker"
status["M041"] = "IMPLEMENTED_DISABLED_BY_DEFAULT"
evidence["M041"] = "HEALER_DEFAULT=DISABLED"

fields = [
    "id", "domain", "action", "target", "authority_sha_or_blob",
    "implementation_status", "implementation_evidence",
    "system_sha256", "system_bytes",
]
out.parent.mkdir(parents=True, exist_ok=True)
with out.open("w", encoding="utf-8", newline="") as fp:
    writer = csv.DictWriter(fp, fieldnames=fields, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    for row in rows:
        mid = row["id"]
        if mid not in status:
            raise SystemExit(f"N1I_C2_IMPLEMENTATION_RECEIPT=FAIL_UNCLASSIFIED id={mid}")
        writer.writerow({
            "id": mid,
            "domain": row["domain"],
            "action": row["action"],
            "target": row["target"],
            "authority_sha_or_blob": row["sha256_or_blob"],
            "implementation_status": status[mid],
            "implementation_evidence": evidence[mid],
            "system_sha256": system_sha,
            "system_bytes": system_bytes,
        })

print("N1I_C2_IMPLEMENTATION_RECEIPT=PASS rows=41")
PY
}

selfcheck() {
    [[ "$N1D_AOSP_REVISION" == android-16.0.0_r4 ]] || { fail "aosp_revision=$N1D_AOSP_REVISION"; return $?; }
    [[ "$N1D_C3_GRAPHENEOS_TAG" == 2026061600 ]] || { fail "graphene_tag=$N1D_C3_GRAPHENEOS_TAG"; return $?; }
    [[ "$N1D_C3_RESTLESS_TAG" == 16.0.0-* ]] || { fail "restless_tag=$N1D_C3_RESTLESS_TAG"; return $?; }
    [[ "$N1D_C3_CONTROL_PATCH_COUNT" == 369 ]] || { fail "c3a_patch_count=$N1D_C3_CONTROL_PATCH_COUNT"; return $?; }

    [[ -d "$ANDROID_ROOT/.repo" && -f "$ROM_MK" ]] || { fail android_workspace; return $?; }
    [[ ! -e "$STAGE_ROOT" ]] || { fail stage_root_present; return $?; }
    [[ ! -e "$OUT_DIR_C2" ]] || { fail "fresh_out_required=$OUT_DIR_C2"; return $?; }

    [[ -f "$C3A_CONTROL" && "$(sha256sum "$C3A_CONTROL" | awk '{print $1}')" == "$C3A_SHA" ]] ||
        { fail c3a_control; return $?; }
    [[ -f "$N1F_CONTROL" && "$(sha256sum "$N1F_CONTROL" | awk '{print $1}')" == "$N1F_SHA" ]] ||
        { fail n1f_control; return $?; }

    [[ -f "$STOCK_SYSTEM" && "$(sha256sum "$STOCK_SYSTEM" | awk '{print $1}')" == "$STOCK_SYSTEM_SHA" ]] ||
        { fail stock_system; return $?; }
    [[ -f "$STOCK_SYSTEM_EXT" && "$(sha256sum "$STOCK_SYSTEM_EXT" | awk '{print $1}')" == "$STOCK_SYSTEM_EXT_SHA" ]] ||
        { fail stock_system_ext; return $?; }

    bash -n "$0" || { fail driver_syntax; return $?; }
    bash "$IMPLEMENTATION_CONTRACT" || { fail implementation_contract; return $?; }
    bash "$ROOT/build/host/verify-host-tools.sh" aosp-host >/dev/null ||
        { fail host_tools; return $?; }

    [[ -x "$APKSIGNER" ]] || { fail "apksigner_missing=$APKSIGNER"; return $?; }

    verify_c3a_source || return $?
    verify_audit || return $?
    verify_materialization || return $?

    local opt phh tmetrics incoming phh_blob patch_blob
    opt="$ANDROID_ROOT/frameworks/opt/telephony"
    phh="$ANDROID_ROOT/device/phh/treble"

    tmetrics="$(git -C "$opt" hash-object "$TMETRICS_REL")"
    incoming="$(git -C "$opt" hash-object "$INCOMING_REL")"
    phh_blob="$(git -C "$phh" hash-object "$PHH_REL")"
    patch_blob="$(git -C "$ROOT" hash-object "$PHH_PATCH")"

    [[ "$tmetrics" == "$TMETRICS_BASE_BLOB" ]] || { fail "telephonymetrics_base_blob=$tmetrics"; return $?; }
    [[ "$incoming" == "$INCOMING_TRACKER_BLOB" ]] || { fail "incoming_tracker_blob=$incoming"; return $?; }
    [[ "$phh_blob" == "$PHH_BASE_BLOB" ]] || { fail "phh_base_blob=$phh_blob"; return $?; }
    [[ "$patch_blob" == "$PHH_PATCH_BLOB" ]] || { fail "phh_patch_blob=$patch_blob"; return $?; }

    git -C "$phh" apply --check "$PHH_PATCH" >/dev/null 2>&1 ||
        { fail phh_patch_apply_check; return $?; }

    echo "N1I_C2_EXACT_SOURCE_BASELINES=PASS"
    echo "N1I_C2_SELFTEST=PASS"
}

selfcheck || exit $?

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-c2-cellular-mvp-build/$STAMP"
ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c2-cellular-mvp/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c2-five-app-bundle/$STAMP"
WORK="$EVIDENCE/work"
mkdir -p "$EVIDENCE" "$ARTIFACT" "$WORK" || { fail evidence_dirs; exit $?; }
exec > >(tee "$EVIDENCE/build.log") 2>&1

echo "===== TITAN 2 N1I-C2 CELLULAR MVP ====="
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "SOURCE_MUTATION_AUTHORIZED=YES_EXACT_C2_SET"
echo "BUILD_AUTHORIZED=YES_ONE_CELLULAR_MVP_SYSTEMIMAGE"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "MATERIALIZATION_ARTIFACT=$MATERIALIZED"
echo "MUTATION_COUNT=41"
echo "FROZEN_STOCK_FILE_COUNT=36"
echo "FROZEN_NATIVE_COUNT=33"
echo "HEALER_DEFAULT=DISABLED"

echo "===== BUILD FIVE N1F APPS OFFLINE ====="
bash "$APP_BUILD" --authorize-app-build --output-dir "$APP_BUNDLE"
APP_RC=$?
[[ "$APP_RC" -eq 0 ]] || { fail "app_build_rc=$APP_RC"; exit $?; }
(cd "$APP_BUNDLE/prebuilt"; sha256sum -c ../SHA256SUMS.txt >/dev/null) ||
    { fail app_bundle_seal; exit $?; }

echo "===== EXTRACT PINNED STOCK CONFIG INPUTS ====="
extract_fs "$STOCK_SYSTEM" "$WORK/stock-system" ||
    { fail extract_stock_system; exit $?; }
extract_fs "$STOCK_SYSTEM_EXT" "$WORK/stock-system-ext" ||
    { fail extract_stock_system_ext; exit $?; }
SYSROOT="$(stock_system_root "$WORK/stock-system")"
EXTROOT="$WORK/stock-system-ext"

echo "===== PREPARE FROZEN STOCK MAP ====="
prepare_stock_map "$EVIDENCE/stock-map.tsv" || { fail stock_map; exit $?; }

ROM_BACKUP="$EVIDENCE/rom.mk.c3a"
cp "$ROM_MK" "$ROM_BACKUP" || { fail rom_backup; exit $?; }
ROM_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"
TMETRICS_APPLIED=NO
PHH_APPLIED=NO

cleanup_source() {
    local rc=0
    if [[ "$PHH_APPLIED" == YES ]]; then
        git -C "$ANDROID_ROOT/device/phh/treble" apply --reverse "$PHH_PATCH" >/dev/null 2>&1 || rc=1
        PHH_APPLIED=NO
    fi
    if [[ "$TMETRICS_APPLIED" == YES ]]; then
        bash "$TMETRICS_QUALIFIER" \
            --opt-telephony "$ANDROID_ROOT/frameworks/opt/telephony" \
            --revert --authorize-source-mutation >/dev/null 2>&1 || rc=1
        TMETRICS_APPLIED=NO
    fi
    if [[ -f "$ROM_BACKUP" ]]; then
        cp "$ROM_BACKUP" "$ROM_MK" >/dev/null 2>&1 || rc=1
    fi
    if [[ -d "$STAGE_ROOT" ]]; then
        find "$STAGE_ROOT" -depth -mindepth 1 -delete >/dev/null 2>&1 || rc=1
        rmdir "$STAGE_ROOT" >/dev/null 2>&1 || true
    fi
    return "$rc"
}
cleanup_on_exit() {
    local original_rc=$?
    local cleanup_rc=0
    trap - EXIT
    cleanup_source || cleanup_rc=$?
    if [[ "$original_rc" -ne 0 ]]; then
        if [[ "$cleanup_rc" -eq 0 ]]; then
            echo "N1I_C2_EMERGENCY_SOURCE_RESTORE=PASS" >&2
        else
            echo "N1I_C2_EMERGENCY_SOURCE_RESTORE=FAIL rc=$cleanup_rc" >&2
        fi
    fi
    if [[ "$cleanup_rc" -ne 0 && "$original_rc" -eq 0 ]]; then
        exit "$cleanup_rc"
    fi
    exit "$original_rc"
}
trap cleanup_on_exit EXIT

echo "===== STAGE C3B + C1 + FROZEN C2 BUNDLE ====="
mkdir -p "$C3B_STAGE/prebuilt" "$C1_STAGE" "$C2_STAGE/prebuilt" ||
    { fail stage_dirs; exit $?; }

install -m 0644 "$C3B_TEMPLATE/Android.bp" "$C3B_STAGE/Android.bp" ||
    { fail stage_c3b_bp; exit $?; }
install -m 0644 "$C3B_TEMPLATE/sable-titan2-apps.mk" "$C3B_STAGE/sable-titan2-apps.mk" ||
    { fail stage_c3b_mk; exit $?; }
for module in "${MODULES[@]}"; do
    install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$C3B_STAGE/prebuilt/$module.apk" ||
        { fail "stage_app=$module"; exit $?; }
done

install -m 0644 "$C1_TEMPLATE/Android.bp" "$C1_STAGE/Android.bp" ||
    { fail stage_c1_bp; exit $?; }
install -m 0644 "$C1_TEMPLATE/sable-titan2-n1i-c1.mk" "$C1_STAGE/sable-titan2-n1i-c1.mk" ||
    { fail stage_c1_mk; exit $?; }
cp -a "$C1_TEMPLATE/sepolicy" "$C1_STAGE/" || { fail stage_c1_sepolicy; exit $?; }

generate_property_policy \
    "$EXTROOT/etc/selinux/system_ext_sepolicy.cil" \
    "$C1_STAGE/sepolicy/system_ext/private/property_contexts" \
    "$C1_STAGE/sepolicy/system_ext/private/property.te" ||
    { fail property_policy; exit $?; }

while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    copy_stock_config_path "$p" "$SYSROOT" "$EXTROOT" ||
        { fail "stage_config=$p"; exit $?; }
done < "$C1_TEMPLATE/config-paths.txt"

install -m 0644 "$C2_TEMPLATE/Android.bp" "$C2_STAGE/Android.bp" ||
    { fail stage_c2_bp; exit $?; }
install -m 0644 "$C2_TEMPLATE/sable-titan2-n1i-c2.mk" "$C2_STAGE/sable-titan2-n1i-c2.mk" ||
    { fail stage_c2_mk; exit $?; }
install -m 0755 "$C2_TEMPLATE/sable-titan2-cellular.sh" "$C2_STAGE/sable-titan2-cellular.sh" ||
    { fail stage_c2_script; exit $?; }
install -m 0644 "$C2_TEMPLATE/sable-titan2-cellular.rc" "$C2_STAGE/sable-titan2-cellular.rc" ||
    { fail stage_c2_rc; exit $?; }
install -m 0644 "$C2_TEMPLATE/titan2-cellular-mvp" "$C2_STAGE/titan2-cellular-mvp" ||
    { fail stage_c2_marker; exit $?; }

generate_vendor_ua_config "$C2_STAGE/prebuilt/system_ext/etc/sable/titan2-cellular.conf" ||
    { fail vendor_ua_config; exit $?; }

STAGED_COUNT=0
STAGED_NATIVE_COUNT=0
{
    IFS= read -r _header
    while IFS=$'\t' read -r id kind target bundle_rel digest; do
        [[ -n "$id" ]] || continue
        src="$MATERIALIZED/$bundle_rel"
        case "$id" in
            M001|M002|M003) dest="$C1_STAGE/prebuilt$target" ;;
            M0*)
                if [[ "$kind" != NATIVE ]]; then
                    fail "unexpected_stock_row=$id:$kind"
                    exit $?
                fi
                dest="$C2_STAGE/prebuilt$target"
                STAGED_NATIVE_COUNT=$((STAGED_NATIVE_COUNT + 1))
                ;;
            *)
                fail "unexpected_stock_id=$id"
                exit $?
                ;;
        esac
        mkdir -p "$(dirname "$dest")" || exit 1
        install -m 0644 "$src" "$dest" || exit 1
        [[ "$(sha256sum "$dest" | awk '{print $1}')" == "$digest" ]] || exit 1
        STAGED_COUNT=$((STAGED_COUNT + 1))
    done
} < "$EVIDENCE/stock-map.tsv" || { fail stage_frozen_stock; exit $?; }

[[ "$STAGED_COUNT" -eq 36 ]] || { fail "staged_stock_count=$STAGED_COUNT"; exit $?; }
[[ "$STAGED_NATIVE_COUNT" -eq 33 ]] || { fail "staged_native_count=$STAGED_NATIVE_COUNT"; exit $?; }

STAGED_IMS="$C1_STAGE/prebuilt/system_ext/priv-app/ImsService/ImsService.apk"
STAGED_IMS_PACKAGE="$(apk_package_name "$STAGED_IMS")" ||
    { fail staged_ims_package_parse; exit $?; }
STAGED_IMS_UID="$(apk_shared_uid "$STAGED_IMS")" ||
    { fail staged_ims_shared_uid_parse; exit $?; }
[[ "$STAGED_IMS_PACKAGE" == "$N1I_C_OEM_IMS_PACKAGE" ]] ||
    { fail "staged_ims_package=$STAGED_IMS_PACKAGE"; exit $?; }
[[ "$STAGED_IMS_UID" == "$N1I_C_OEM_IMS_SHARED_UID" ]] ||
    { fail "staged_ims_shared_uid=$STAGED_IMS_UID"; exit $?; }

echo "N1I_C2_STAGED_STOCK=PASS files=$STAGED_COUNT natives=$STAGED_NATIVE_COUNT"
echo "N1I_C2_STAGED_IMS_IDENTITY=PASS package=$STAGED_IMS_PACKAGE shared_uid=$STAGED_IMS_UID"

echo "===== APPLY EXACT C2 SOURCE DELTA ====="
bash "$TMETRICS_QUALIFIER" \
    --opt-telephony "$ANDROID_ROOT/frameworks/opt/telephony" \
    --apply --authorize-source-mutation
TM_RC=$?
[[ "$TM_RC" -eq 0 ]] || { fail "telephonymetrics_apply_rc=$TM_RC"; exit $?; }
TMETRICS_APPLIED=YES
[[ "$(git -C "$ANDROID_ROOT/frameworks/opt/telephony" hash-object "$TMETRICS_REL")" == "$TMETRICS_POST_BLOB" ]] ||
    { fail telephonymetrics_post_blob; exit $?; }

git -C "$ANDROID_ROOT/device/phh/treble" apply "$PHH_PATCH"
PHH_RC=$?
[[ "$PHH_RC" -eq 0 ]] || { fail "phh_patch_rc=$PHH_RC"; exit $?; }
PHH_APPLIED=YES
grep -Fq '/system_ext/etc/sable/titan2-cellular-mvp' "$ANDROID_ROOT/device/phh/treble/$PHH_REL" ||
    { fail phh_guard_marker; exit $?; }
git -C "$ANDROID_ROOT/device/phh/treble" apply --reverse --check "$PHH_PATCH" >/dev/null 2>&1 ||
    { fail phh_reverse_check; exit $?; }

[[ "$(git -C "$ANDROID_ROOT/frameworks/opt/telephony" hash-object "$INCOMING_REL")" == "$INCOMING_TRACKER_BLOB" ]] ||
    { fail incoming_tracker_changed; exit $?; }

grep -Fq 'vendor/sable/titan2/n1i-c2/sable-titan2-n1i-c2.mk' "$ROM_MK" &&
    { fail c2_already_in_rom; exit $?; }
cat >> "$ROM_MK" <<'EOF'

# SABLE_N1I_C2_CELLULAR_MVP
$(call inherit-product, vendor/sable/titan2/n1i-c2/sable-titan2-n1i-c2.mk)
EOF

git -C "$ANDROID_ROOT/frameworks/opt/telephony" diff --check -- "$TMETRICS_REL" ||
    { fail telephony_diff_check; exit $?; }
git -C "$ANDROID_ROOT/device/phh/treble" diff --check -- "$PHH_REL" ||
    { fail phh_diff_check; exit $?; }

PHH_POST_BLOB="$(git -C "$ANDROID_ROOT/device/phh/treble" hash-object "$PHH_REL")"

git -C "$ANDROID_ROOT/frameworks/opt/telephony" diff -- "$TMETRICS_REL" > "$EVIDENCE/telephonymetrics.diff"
git -C "$ANDROID_ROOT/device/phh/treble" diff -- "$PHH_REL" > "$EVIDENCE/phh-on-boot.diff"
diff -u "$ROM_BACKUP" "$ROM_MK" > "$EVIDENCE/rom-mk.diff" || true
cp "$C2_STAGE/prebuilt/system_ext/etc/sable/titan2-cellular.conf" "$EVIDENCE/titan2-cellular.conf"

echo "N1I_C2_TMETRICS_POST_BLOB=$TMETRICS_POST_BLOB"
echo "N1I_C2_PHH_BASE_BLOB=$PHH_BASE_BLOB"
echo "N1I_C2_PHH_POST_BLOB=$PHH_POST_BLOB"
echo "N1I_C2_SOURCE_MUTATION=PASS_EXACT_THREE_SURFACES tmetrics=patch incoming=product_property phh=guard"

echo "===== BUILD ONE ANDROID 16 CELLULAR MVP SYSTEMIMAGE ====="
mkdir -p "$OUT_DIR_C2" || { fail out_dir; exit $?; }

(
    cd "$ANDROID_ROOT" || exit 1
    export OUT_DIR="$OUT_DIR_C2"
    set +u
    source build/envsetup.sh
    lunch treble_arm64_bvN-bp4a-user
    lunch_rc=$?
    set -u
    [[ "$lunch_rc" -eq 0 ]] || exit "$lunch_rc"

    [[ "$(get_build_var TARGET_PRODUCT)" == treble_arm64_bvN ]] || exit 71
    [[ "$(get_build_var TARGET_BUILD_VARIANT)" == user ]] || exit 72
    [[ "$(get_build_var BUILD_ID)" == BP4A.251205.006 ]] || exit 73
    [[ "$(get_build_var PLATFORM_VERSION)" == 16 ]] || exit 74
    [[ "$(get_build_var TARGET_COPY_OUT_PRODUCT)" == system/product ]] || exit 75
    get_build_var TARGET_COPY_OUT_SYSTEM_EXT > "$EVIDENCE/system-ext-copyout.txt"

    pp="$(get_build_var PRODUCT_PACKAGES)"
    for module in "${MODULES[@]}" \
        ImsService SableN1IC1MediatekCommon SableN1IC1MediatekImsBase \
        SableTitan2Cellular SableTitan2CellularInit SableTitan2CellularConfig SableTitan2CellularMarker \
        "$MTK_MMTEL_OVERLAY_MODULE"
    do
        grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" <<<"$pp" || exit 76
    done
    for n in $(seq -w 7 39); do
        module="SableN1IC2NativeM0$n"
        grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" <<<"$pp" || exit 77
    done

    props="$(get_build_var PRODUCT_SYSTEM_PROPERTIES)"
    grep -Eq '(^|[[:space:]])ro\.telephony\.block_binder_thread_on_incoming_calls=false([[:space:]]|$)' <<<"$props" ||
        exit 78

    make systemimage -j"$JOBS" > >(tee "$EVIDENCE/systemimage.log") 2>&1
    exit $?
)
BUILD_RC=$?
[[ "$BUILD_RC" -eq 0 ]] || { fail "systemimage_rc=$BUILD_RC"; exit $?; }

NEW="$PRODUCT_OUT/system.img"
[[ -f "$NEW" ]] || { fail system_image_missing; exit $?; }
NEW_SHA="$(sha256sum "$NEW" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$NEW")"
[[ "$NEW_SHA" != "$N1F_SHA" ]] || { fail unchanged_from_n1f; exit $?; }
[[ "$NEW_SHA" != "$C1_SHA" ]] || { fail unchanged_from_c1; exit $?; }
[[ "$NEW_BYTES" -ge "$C1_BYTES" && "$NEW_BYTES" -le "$SYSTEM_GROUP_SAFE_CEILING" ]] ||
    { fail "image_size=$NEW_BYTES ceiling=$SYSTEM_GROUP_SAFE_CEILING"; exit $?; }

python3 "$GSI_INFO" --image "$NEW" | tee "$EVIDENCE/system-image-info.txt"
GSI_RC=${PIPESTATUS[0]}
[[ "$GSI_RC" -eq 0 ]] || { fail "gsi_info_rc=$GSI_RC"; exit $?; }
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$EVIDENCE/system-image-info.txt" ||
    { fail gsi_image_info; exit $?; }

COPYOUT="$(cat "$EVIDENCE/system-ext-copyout.txt")"
[[ "$COPYOUT" == system/system_ext ]] || { fail "system_ext_copyout=$COPYOUT"; exit $?; }

echo "===== VERIFY BUILT CELLULAR MVP CONTENT ====="
BUILT_NATIVE_COUNT=0
{
    IFS= read -r _header
    while IFS=$'\t' read -r id kind target bundle_rel digest; do
        [[ -n "$id" ]] || continue
        built="$(built_target_path "$target")" || exit 1
        [[ -f "$built" ]] || { echo "missing built target $target -> $built" >&2; exit 1; }

        if [[ "$id" == M001 ]]; then
            continue
        fi
        actual="$(sha256sum "$built" | awk '{print $1}')"
        [[ "$actual" == "$digest" ]] || {
            echo "built hash mismatch id=$id target=$target expected=$digest actual=$actual" >&2
            exit 1
        }
        if [[ "$kind" == NATIVE ]]; then
            BUILT_NATIVE_COUNT=$((BUILT_NATIVE_COUNT + 1))
        fi
    done
} < "$EVIDENCE/stock-map.tsv" || { fail built_payload_verification; exit $?; }

[[ "$BUILT_NATIVE_COUNT" -eq 33 ]] || { fail "built_native_count=$BUILT_NATIVE_COUNT"; exit $?; }

IMS_OUT="$PRODUCT_OUT/$COPYOUT/priv-app/ImsService/ImsService.apk"
[[ -f "$IMS_OUT" ]] || { fail ims_out; exit $?; }
BUILT_IMS_PACKAGE="$(apk_package_name "$IMS_OUT")" || { fail ims_package_parse; exit $?; }
BUILT_IMS_UID="$(apk_shared_uid "$IMS_OUT")" || { fail ims_shared_uid_parse; exit $?; }
[[ "$BUILT_IMS_PACKAGE" == "$N1I_C_OEM_IMS_PACKAGE" ]] || { fail "ims_package=$BUILT_IMS_PACKAGE"; exit $?; }
[[ "$BUILT_IMS_UID" == "$N1I_C_OEM_IMS_SHARED_UID" ]] || { fail "ims_shared_uid=$BUILT_IMS_UID"; exit $?; }

"$APKSIGNER" verify "$IMS_OUT" >/dev/null 2>&1 || { fail ims_signature; exit $?; }
FRAMEWORK_RES="$PRODUCT_OUT/system/framework/framework-res.apk"
[[ -f "$FRAMEWORK_RES" ]] || { fail framework_res; exit $?; }
IMS_CERT_OUT="$("$APKSIGNER" verify --print-certs "$IMS_OUT")" ||
    { fail ims_cert_read; exit $?; }
PLATFORM_CERT_OUT="$("$APKSIGNER" verify --print-certs "$FRAMEWORK_RES")" ||
    { fail platform_cert_read; exit $?; }
IMS_CERT="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$IMS_CERT_OUT" | sed -n '1p')"
PLATFORM_CERT="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$PLATFORM_CERT_OUT" | sed -n '1p')"
[[ -n "$IMS_CERT" && "$IMS_CERT" == "$PLATFORM_CERT" ]] ||
    { fail platform_resign; exit $?; }
echo "N1I_C2_OEM_IMS_PLATFORM_RESIGN=PASS cert=$IMS_CERT"

for jar in mediatek-common.jar mediatek-ims-base.jar; do
    [[ -f "$PRODUCT_OUT/$COPYOUT/framework/$jar" ]] || { fail "jar=$jar"; exit $?; }
done

BOOTPB="$PRODUCT_OUT/system/etc/classpaths/bootclasspath.pb"
[[ -f "$BOOTPB" ]] || { fail bootclasspath_pb; exit $?; }
grep -aFq '/system_ext/framework/mediatek-common.jar' "$BOOTPB" || { fail bootclasspath_common; exit $?; }
grep -aFq '/system_ext/framework/mediatek-ims-base.jar' "$BOOTPB" || { fail bootclasspath_ims; exit $?; }

BUILD_PROP="$PRODUCT_OUT/system/build.prop"
[[ -f "$BUILD_PROP" ]] || { fail system_build_prop; exit $?; }
grep -Fxq 'ro.telephony.block_binder_thread_on_incoming_calls=false' "$BUILD_PROP" ||
    { fail incoming_call_property; exit $?; }

for p in \
    "$PRODUCT_OUT/$COPYOUT/bin/sable-titan2-cellular" \
    "$PRODUCT_OUT/$COPYOUT/etc/init/sable-titan2-cellular.rc" \
    "$PRODUCT_OUT/$COPYOUT/etc/sable/titan2-cellular.conf" \
    "$PRODUCT_OUT/$COPYOUT/etc/sable/titan2-cellular-mvp"
do
    [[ -f "$p" ]] || { fail "integration_output_missing=$p"; exit $?; }
done

BUILT_PHH="$PRODUCT_OUT/system/bin/phh-on-boot.sh"
[[ -f "$BUILT_PHH" ]] || { fail built_phh_on_boot; exit $?; }
grep -Fq '/system_ext/etc/sable/titan2-cellular-mvp' "$BUILT_PHH" ||
    { fail built_phh_guard; exit $?; }
grep -Fq 'setprop persist.mtk_ims_support 0' "$BUILT_PHH" ||
    { fail built_phh_non_titan_behavior_removed; exit $?; }

MTK_OVERLAY_SRC="$ANDROID_ROOT/vendor/hardware_overlay/Telephony/MTK-IMS/res/values/config.xml"
[[ -f "$MTK_OVERLAY_SRC" ]] || { fail mtk_overlay_source; exit $?; }
grep -Fq 'config_ims_mmtel_package">com.mediatek.ims' "$MTK_OVERLAY_SRC" ||
    { fail mtk_overlay_provider; exit $?; }

MTK_OVERLAY_APK="$PRODUCT_OUT/system/product/overlay/$MTK_MMTEL_OVERLAY_MODULE.apk"
[[ -f "$MTK_OVERLAY_APK" ]] || { fail "mtk_overlay_apk=$MTK_OVERLAY_APK"; exit $?; }
MTK_OVERLAY_PACKAGE="$(apk_package_name "$MTK_OVERLAY_APK")" ||
    { fail mtk_overlay_package_parse; exit $?; }
[[ "$MTK_OVERLAY_PACKAGE" == "$MTK_MMTEL_OVERLAY_PACKAGE" ]] ||
    { fail "mtk_overlay_package=$MTK_OVERLAY_PACKAGE"; exit $?; }

echo "N1I_C2_BUILT_NATIVE_SET=PASS count=$BUILT_NATIVE_COUNT exact_hashes=YES"
echo "N1I_C2_INCOMING_CALL_COMPAT=PASS_PROPERTY_FALSE"
echo "N1I_C2_PHH_MTKMAL_GUARD=PASS_MARKER_SCOPED"
echo "N1I_C2_INTEGRATION_PACKAGE=PASS_HEALER_DISABLED_BY_DEFAULT"
echo "N1I_C2_MMTEL_PROVIDER_SOURCE=PASS_COM_MEDIATEK_IMS"
echo "N1I_C2_MMTEL_OVERLAY_APK=PASS package=$MTK_OVERLAY_PACKAGE"
echo "N1I_C2_SYSTEMIMAGE=PASS sha256=$NEW_SHA bytes=$NEW_BYTES"

echo "===== FREEZE IMPLEMENTATION RECEIPT ====="
generate_implementation_receipt "$EVIDENCE/CELLULAR_MVP_IMPLEMENTATION_RECEIPT.tsv" ||
    { fail implementation_receipt; exit $?; }

echo "===== RESTORE ANDROID SOURCE ====="
cleanup_source
CLEANUP_RC=$?
trap - EXIT
[[ "$CLEANUP_RC" -eq 0 ]] || { fail cleanup_source; exit $?; }

[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_SHA" ]] ||
    { fail rom_restore; exit $?; }
[[ ! -e "$STAGE_ROOT" ]] || { fail stage_restore; exit $?; }
[[ "$(git -C "$ANDROID_ROOT/frameworks/opt/telephony" hash-object "$TMETRICS_REL")" == "$TMETRICS_BASE_BLOB" ]] ||
    { fail tmetrics_restore; exit $?; }
[[ "$(git -C "$ANDROID_ROOT/frameworks/opt/telephony" hash-object "$INCOMING_REL")" == "$INCOMING_TRACKER_BLOB" ]] ||
    { fail incoming_restore; exit $?; }
[[ "$(git -C "$ANDROID_ROOT/device/phh/treble" hash-object "$PHH_REL")" == "$PHH_BASE_BLOB" ]] ||
    { fail phh_restore; exit $?; }

verify_c3a_source || { fail c3a_source_restore; exit $?; }
echo "N1I_C2_C3A_SOURCE_RESTORE=PASS_EXACT"
echo "N1I_C2_SOURCE_RESTORE=PASS"

rm -rf --one-file-system "$WORK"
echo "N1I_C2_TEMP_EXTRACTION=PASS_REMOVED"

cp --reflink=auto --sparse=always "$NEW" "$ARTIFACT/system.img" ||
    { fail artifact_system_copy; exit $?; }
cp "$EVIDENCE/system-image-info.txt" "$ARTIFACT/" ||
    { fail artifact_info_copy; exit $?; }
cp "$EVIDENCE/stock-map.tsv" "$ARTIFACT/" ||
    { fail artifact_stock_map_copy; exit $?; }
cp "$MATERIALIZED/CELLULAR_MVP_FROZEN_MUTATION_MANIFEST.tsv" "$ARTIFACT/" ||
    { fail artifact_manifest_copy; exit $?; }
cp "$EVIDENCE/CELLULAR_MVP_IMPLEMENTATION_RECEIPT.tsv" "$ARTIFACT/" ||
    { fail artifact_receipt_copy; exit $?; }

cat > "$ARTIFACT/artifact.env" <<EOF
ROLE=N1I_C2_CELLULAR_MVP
SOURCE_COMMIT=$SOURCE_COMMIT
ANDROID_PLATFORM=16
AOSP_REVISION=$N1D_AOSP_REVISION
GRAPHENEOS_TAG=$N1D_C3_GRAPHENEOS_TAG
RESTLESS_TAG=$N1D_C3_RESTLESS_TAG
BASE_C3A_SHA256=$C3A_SHA
BASE_N1F_SHA256=$N1F_SHA
MATERIALIZATION_ARTIFACT=$MATERIALIZED
MATERIALIZATION_SOURCE_COMMIT=$MATERIALIZATION_SOURCE_COMMIT
FROZEN_MUTATION_COUNT=41
FROZEN_STOCK_FILE_COUNT=36
FROZEN_NATIVE_COUNT=33
IMPLEMENTATION_RECEIPT_ROWS=41
TELEPHONYMETRICS_POST_BLOB=$TMETRICS_POST_BLOB
PHH_BASE_BLOB=$PHH_BASE_BLOB
PHH_POST_BLOB=$PHH_POST_BLOB
INCOMING_CALL_COMPAT_PROPERTY=false
HEALER_DEFAULT=DISABLED
OEM_IMS_PLATFORM_RESIGNED=YES
OEM_IMS_PLATFORM_CERT_SHA256=$IMS_CERT
SYSTEM_SHA256=$NEW_SHA
SYSTEM_BYTES=$NEW_BYTES
DEVICE_CONTACT=NONE
FLASH=NONE
EOF

(
    cd "$ARTIFACT" || exit 1
    find . -type f ! -name system.img ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    printf '%s  ./system.img\n' "$NEW_SHA" >> SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)
SEAL_RC=$?
[[ "$SEAL_RC" -eq 0 ]] || { fail artifact_seal; exit $?; }

(
    cd "$EVIDENCE" || exit 1
    find . -type f ! -name build.log ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)
EVIDENCE_SEAL_RC=$?
[[ "$EVIDENCE_SEAL_RC" -eq 0 ]] || { fail evidence_seal; exit $?; }
echo "N1I_C2_EVIDENCE_SEAL=PASS_EXCLUDES_BUILD_LOG"

echo "N1I_C2_BUILD=PASS"
echo "N1I_C2_DEVICE_CONTACT=NONE"
echo "N1I_C2_FLASH=NONE"
echo "N1I_C2_READY_FOR_POSTBUILD_LINKAGE=YES"
echo "N1I_C2_ARTIFACT_DIR=$ARTIFACT"
echo "N1I_C2_EVIDENCE_DIR=$EVIDENCE"
