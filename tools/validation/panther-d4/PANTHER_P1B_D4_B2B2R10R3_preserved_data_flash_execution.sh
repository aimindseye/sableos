#!/usr/bin/env bash
set -uo pipefail
umask 077

# PANTHER P1B-D4-B2B2R10R3 / STAGED EXACT PRESERVED-DATA FLASH + BOOT PROOF
#
# R10R3 supersedes R10's product-out-completeness assumption.
#
# ALL fastboot image bytes are materialized byte-for-byte from the already-bound
# B2 target-files IMAGES/ namespace into EVIDENCE_DIR/flash_payload. Product-out
# images are never used. No build is invoked and no workspace output is modified.
#
# Required runtime authorizations:
#   DEVICE_CONTACT_AUTHORIZED=YES
#   DEVICE_REBOOT_AUTHORIZED=YES
#   FLASH_AUTHORIZED=YES
#   SLOT_REASSERTION_AUTHORIZED=YES
#
# Hard prohibitions:
#   SLOT_CHANGE_AUTHORIZED=NO
#   BOOTLOADER_UNLOCK_AUTHORIZED=NO
#   USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
#   INACTIVE_SLOT_FLASH_AUTHORIZED=NO
#
# R10R3 rejects:
#   - any unconditional userdata / metadata flash or erase task
#   - any fastboot-info --slot-other directive
#   - any unknown fastboot-info directive
#   - any required image absent from both product-out and target-files/IMAGES
#
# Flash command has NO -w and uses the sealed staged payload:
#   ANDROID_PRODUCT_OUT=$FLASH_PAYLOAD_DIR
#   fastboot --slot b --set-active=b --skip-secondary --skip-reboot flashall
#
# On flash failure, final reboot is suppressed.

WS="${WS:-/srv/data/sableos_panther_graphene_2026081300_workspace}"
PRODUCT="${PRODUCT:-panther}"

B2_OUT="${B2_OUT:-$WS/out_d4_b2_final}"
B2_PRODUCT_OUT="${B2_PRODUCT_OUT:-$B2_OUT/target/product/$PRODUCT}"
B2_TARGET_FILES="${B2_TARGET_FILES:-$B2_PRODUCT_OUT/obj/PACKAGING/target_files_intermediates/panther-target_files.zip}"

R9_EVIDENCE_DIR="${R9_EVIDENCE_DIR:-/tmp/PANTHER_P1B_D4_B2B2R9_PRESERVED_DATA_FLASH_PREFLIGHT_20260908_121602}"
EXPECTED_R9_EVIDENCE_SEAL_SHA256="3bc7a8b18787c661ffa5a5def5e0dadc1e0f7593505e388791420d98bb823a76"

R10R2_EVIDENCE_DIR="${R10R2_EVIDENCE_DIR:-/tmp/PANTHER_P1B_D4_B2B2R10R2_PRESERVED_DATA_FLASH_20260908_123356}"
EXPECTED_R10R2_EVIDENCE_SEAL_SHA256="001cc65c00758f69e0e8bfdb6022d2e313b6a573d94705004228b9695c905cdd"
EXPECTED_R10R2_FAILURE_MARKER="GATE_ERROR=PRODUCT_OUT_TARGET_FILES_IMAGE_MISMATCH"

EXPECTED_B2_MANIFEST_PB_SHA256="c006f36d2181e9a302c275d3d8dfeb8c3ef88ac126738fe05f33736dc9b2f429"
EXPECTED_B2_ANDROID_INFO_SHA256="33a1248ba54417ee8afc375bbf4da30382e13d6c81b430f3254ee11a44c8f5dd"
EXPECTED_B2_FASTBOOT_INFO_SHA256="42a270c4d51ca3e1e62b073bf4d2aa88617580a4a6517bb7607b2d2b4ac9ebac"
EXPECTED_PRE_SLOT="b"

DEVICE_CONTACT_AUTHORIZED="${DEVICE_CONTACT_AUTHORIZED:-NO}"
DEVICE_REBOOT_AUTHORIZED="${DEVICE_REBOOT_AUTHORIZED:-NO}"
FLASH_AUTHORIZED="${FLASH_AUTHORIZED:-NO}"
SLOT_REASSERTION_AUTHORIZED="${SLOT_REASSERTION_AUTHORIZED:-NO}"

STAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/PANTHER_P1B_D4_B2B2R10R3_PRESERVED_DATA_FLASH_${STAMP}}"
LOG="$EVIDENCE_DIR/r10r1_preserved_data_flash.log"
FLASH_PAYLOAD_DIR="$EVIDENCE_DIR/flash_payload"

if [[ -e "$EVIDENCE_DIR" ]]; then
  echo "GATE_ERROR=EVIDENCE_DIR_ALREADY_EXISTS path=$EVIDENCE_DIR" >&2
  exit 90
fi
mkdir "$EVIDENCE_DIR" || exit 90

sha256_file() {
  sha256sum -- "$1" | awk '{print $1}'
}

fail() {
  echo "GATE_ERROR=$1"
}

adb_getprop() {
  local adb_bin="$1"
  local serial="$2"
  local key="$3"
  "$adb_bin" -s "$serial" shell getprop "$key" 2>/dev/null | tr -d '\r' | tail -n 1
}

fastboot_getvar() {
  local fb="$1"
  local serial="$2"
  local key="$3"
  "$fb" -s "$serial" getvar "$key" 2>&1 \
    | sed -n -E "s/^(\(bootloader\)[[:space:]]*)?${key}:[[:space:]]*//p" \
    | tail -n 1
}

wait_for_fastboot() {
  local fb="$1"
  local serial="$2"
  local timeout_s="${3:-90}"
  local start now
  start="$(date +%s)"
  while :; do
    if "$fb" -s "$serial" devices 2>/dev/null | awk 'NF>=1 {print $1}' | grep -Fxq "$serial"; then
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout_s )); then
      return 1
    fi
    sleep 2
  done
}

wait_for_adb_device() {
  local adb_bin="$1"
  local serial="$2"
  local timeout_s="${3:-300}"
  local start now state
  start="$(date +%s)"
  while :; do
    state="$("$adb_bin" -s "$serial" get-state 2>/dev/null || true)"
    if [[ "$state" == "device" ]]; then
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout_s )); then
      return 1
    fi
    sleep 2
  done
}

verify_sealed_dir() {
  local label="$1"
  local dir="$2"
  local expected_seal="$3"

  [[ -d "$dir" ]] || { fail "${label}_EVIDENCE_DIR_MISSING"; return 33; }
  [[ -f "$dir/evidence.sha256" ]] || { fail "${label}_EVIDENCE_SEAL_MISSING"; return 33; }

  local actual
  actual="$(sha256_file "$dir/evidence.sha256")" || return 33
  echo "${label}_EVIDENCE_SEAL_SHA256=$actual"
  [[ "$actual" == "$expected_seal" ]] || {
    fail "${label}_EVIDENCE_SEAL_HASH_MISMATCH expected=$expected_seal actual=$actual"
    return 33
  }

  (
    cd "$dir" || exit 1
    sha256sum -c evidence.sha256
  ) > "$EVIDENCE_DIR/${label,,}_seal_verify.txt" 2>&1
  local rc=$?
  echo "${label}_EVIDENCE_MEMBER_VERIFY_RC=$rc"
  [[ "$rc" -eq 0 ]] || { fail "${label}_EVIDENCE_MEMBER_VERIFY_FAILED"; return 33; }

  echo "${label}_EVIDENCE_MEMBER_VERIFY=PASS"
  return 0
}

bind_prior_evidence() {
  echo "===== BIND R9 + R10 BOUNDED EVIDENCE ====="

  echo "R9_EVIDENCE_DIR=$R9_EVIDENCE_DIR"
  verify_sealed_dir "R9" "$R9_EVIDENCE_DIR" "$EXPECTED_R9_EVIDENCE_SEAL_SHA256" || return $?

  grep -R -Fq 'R9_PRESERVED_DATA_FLASH_PREFLIGHT=PASS' "$R9_EVIDENCE_DIR"/*.log 2>/dev/null || {
    fail "R9_PASS_MARKER_MISSING"
    return 33
  }
  grep -R -Fq 'BOOTLOADER_UNLOCK_STATE=UNLOCKED' "$R9_EVIDENCE_DIR"/*.log 2>/dev/null || {
    fail "R9_UNLOCKED_MARKER_MISSING"
    return 33
  }
  grep -R -Fq 'CURRENT_SLOT_SUFFIX=_b' "$R9_EVIDENCE_DIR"/*.log 2>/dev/null || {
    fail "R9_EXPECTED_SLOT_B_MARKER_MISSING"
    return 33
  }

  local serial
  serial="$(awk 'NR>1 && $2=="device" {print $1; exit}' "$R9_EVIDENCE_DIR/adb_devices.txt" 2>/dev/null || true)"
  [[ -n "$serial" ]] || { fail "R9_DEVICE_SERIAL_NOT_RECOVERABLE"; return 33; }
  printf '%s\n' "$serial" > "$EVIDENCE_DIR/expected_device_serial.txt"

  echo "R10R2_EVIDENCE_DIR=$R10R2_EVIDENCE_DIR"
  verify_sealed_dir "R10R2" "$R10R2_EVIDENCE_DIR" "$EXPECTED_R10R2_EVIDENCE_SEAL_SHA256" || return $?
  grep -R -Fq "$EXPECTED_R10R2_FAILURE_MARKER" "$R10R2_EVIDENCE_DIR"/*.log 2>/dev/null || {
    fail "R10R2_EXPECTED_MIXED_IMAGE_SOURCE_FAILURE_NOT_BOUND"
    return 33
  }

  echo "R9_BINDING=PASS"
  echo "R10R2_BOUNDED_FAILURE_BINDING=PASS"
  return 0
}

stage_exact_payload() {
  echo "===== STAGE COMPLETE B2 FASTBOOT PAYLOAD FROM TARGET-FILES ONLY ====="

  local android_info="$B2_PRODUCT_OUT/android-info.txt"
  local product_fastboot_info="$B2_PRODUCT_OUT/fastboot-info.txt"

  [[ -f "$B2_TARGET_FILES" ]] || { fail "B2_TARGET_FILES_MISSING"; return 33; }
  [[ -f "$android_info" ]] || { fail "B2_ANDROID_INFO_MISSING"; return 33; }
  [[ -f "$product_fastboot_info" ]] || { fail "B2_PRODUCT_FASTBOOT_INFO_MISSING"; return 33; }

  local android_sha product_fastboot_sha
  android_sha="$(sha256_file "$android_info")" || return 33
  product_fastboot_sha="$(sha256_file "$product_fastboot_info")" || return 33
  echo "B2_ANDROID_INFO_SHA256=$android_sha"
  echo "B2_PRODUCT_FASTBOOT_INFO_SHA256=$product_fastboot_sha"

  [[ "$android_sha" == "$EXPECTED_B2_ANDROID_INFO_SHA256" ]] || {
    fail "B2_ANDROID_INFO_DRIFT expected=$EXPECTED_B2_ANDROID_INFO_SHA256 actual=$android_sha"
    return 33
  }
  [[ "$product_fastboot_sha" == "$EXPECTED_B2_FASTBOOT_INFO_SHA256" ]] || {
    fail "B2_PRODUCT_FASTBOOT_INFO_DRIFT expected=$EXPECTED_B2_FASTBOOT_INFO_SHA256 actual=$product_fastboot_sha"
    return 33
  }

  mkdir "$FLASH_PAYLOAD_DIR" || return 33

  python3 -u - \
    "$B2_TARGET_FILES" \
    "$EXPECTED_B2_MANIFEST_PB_SHA256" \
    "$EXPECTED_B2_FASTBOOT_INFO_SHA256" \
    "$android_info" \
    "$FLASH_PAYLOAD_DIR" \
    "$EVIDENCE_DIR" <<'PY'
import csv
import hashlib
import io
import pathlib
import shlex
import shutil
import sys
import zipfile

target_files = pathlib.Path(sys.argv[1])
expected_pb = sys.argv[2]
expected_fastboot_info_sha = sys.argv[3]
android_info = pathlib.Path(sys.argv[4])
payload = pathlib.Path(sys.argv[5])
evidence = pathlib.Path(sys.argv[6])

ART_KEYS = [
    "system/framework/oat/arm64/apex@com.android.appsearch@javalib@service-appsearch.jar@classes.art",
    "system/framework/oat/arm64/apex@com.android.art@javalib@service-art.jar@classes.art",
    "system/framework/oat/arm64/apex@com.android.telephonycore@javalib@service-telecom.jar@classes.art",
    "system/framework/oat/arm64/apex@com.android.tethering@javalib@service-connectivity.jar@classes.art",
    "system/framework/oat/arm64/services.art",
]
CHUNK = 4 * 1024 * 1024
ARCHIVE_PROGRESS = 512 * 1024 * 1024

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

def sha256_file(path):
    h = hashlib.sha256()
    total = 0
    with path.open("rb") as f:
        while True:
            chunk = f.read(CHUNK)
            if not chunk:
                break
            h.update(chunk)
            total += len(chunk)
    return h.hexdigest(), total

def tf_member(installed):
    head, rest = installed.split("/", 1)
    return head.upper() + "/" + rest((
# First seal the exact target-files container now being used for device mutation.
archive_size = target_files.stat().st_size
archive_h = hashlib.sha256()
done = 0
next_progress = ARCHIVE_PROGRESS
print(f"B2_TARGET_FILES_SIZE={archive_size}", flush=True)
print("B2_TARGET_FILES_SHA256_START=YES", flush=True)
with target_files.open("rb") as f:
    while True:
        chunk = f.read(CHUNK)
        if not chunk:
            break
        archive_h.update(chunk)
        done += len(chunk)
        if done >= next_progress:
            print(
                f"B2_TARGET_FILES_SHA256_PROGRESS bytes={done} total={archive_size}",
                flush=True,
            )
            next_progress += ARCHIVE_PROGRESS
archive_sha = archive_h.hexdigest()
(evidence / "B2_target_files.sha256").write_text(
    f"{archive_sha}  {target_files}\n", encoding="utf-8"
)
print(f"B2_TARGET_FILES_SHA256={archive_sha}", flush=True)

with zipfile.ZipFile(target_files, "r") as zf:
    names = set(zf.namelist())

    # Population identity.
    bm_apk = zf.read("SYSTEM/etc/security/fsverity/BuildManifest.apk")
    with zipfile.ZipFile(io.BytesIO(bm_apk), "r") as az:
        pb = az.read("assets/build_manifest.pb")
    pb_sha = sha256_bytes(pb)
    bm_sha = sha256_bytes(bm_apk)
    print(f"B2_MANIFEST_PB_SHA256={pb_sha}")
    print(f"B2_BUILDMANIFEST_APK_SHA256={bm_sha}")
    if pb_sha != expected_pb:
        print(f"GATE_ERROR=B2_MANIFEST_IDENTITY_MISMATCH expected={expected_pb} actual={pb_sha}")
        raise SystemExit(33)

    # The task definition itself must come from the same target-files container.
    if "META/fastboot-info.txt" not in names:
        print("GATE_ERROR=TARGET_FILES_FASTBOOT_INFO_MISSING")
        raise SystemExit(33)
    fastboot_info_bytes = zf.read("META/fastboot-info.txt")
    fastboot_info_sha = sha256_bytes(fastboot_info_bytes)
    print(f"TARGET_FILES_FASTBOOT_INFO_SHA256={fastboot_info_sha}")
    if fastboot_info_sha != expected_fastboot_info_sha:
        print(
            f"GATE_ERROR=TARGET_FILES_FASTBOOT_INFO_DRIFT "
            f"expected={expected_fastboot_info_sha} actual={fastboot_info_sha}"
        )
        raise SystemExit(33)
    fastboot_text = fastboot_info_bytes.decode("utf-8", "strict")

    # Post-boot exact B2 expectations.
    art_rows = []
    for key in ART_KEYS:
        data = zf.read(tf_member(key))
        art_rows.append((key, len(data), sha256_bytes(data)))

    (evidence / "expected_buildmanifest_apk_sha256.txt").write_text(
        bm_sha + "\n", encoding="utf-8"
    )
    with (evidence / "expected_b2_art_sha256.tsv").open(
        "w", newline="", encoding="utf-8"
    ) as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["installed_path", "size", "sha256"])
        w.writerows(art_rows)

    # Parse and enforce the exact packaged task set.
    unsafe = []
    required = {}  # filename -> set(partitions/reasons)
    need_super_empty = False
    noncomment = 0
    if_wipe_count = 0

    for lineno, raw in enumerate(fastboot_text.splitlines(), 1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        noncomment += 1
        try:
            tok = shlex.split(stripped)
        except ValueError as e:
            unsafe.append((lineno, stripped, f"parse_error:{e}"))
            continue
        if not tok:
            continue

        cmd = tok[0]

        if cmd == "version":
            if len(tok) != 2 or not tok[1].isdigit():
                unsafe.append((lineno, stripped, "invalid_version"))
            continue

        if cmd == "if-wpe":
            # Allowed only in the canonical conditional form. R10R3 never passes -w.
            if len(tok) != 3 or tok[1] != "erase":
                unsafe.append((lineno, stripped, "unexpected_if_wipe_form"))
            else:
                if_wipe_count += 1
            continue

        if cmd == "update-super":
            if len(tok) != 1:
                unsafe.append((lineno, stripped, "invalid_update_super"))
            else:
                need_super_empty = True
                required.setdefault("super_empty.img", set()).add("__update_super__")
            continue

        if cmd == "reboot":
            if len(tok) != 2 or tok[1] not in ("bootloader", "fastboot"):
                unsafe.append((lineno, stripped, "unexpected_reboot_target"))
            continue

        if cmd == "erase":
            unsafe.append((lineno, stripped, "unconditional_erase_forbidden"))
            continue

        if cmd != "flash":
            unsafe.append((lineno, stripped, f"unsupported_command:{cmd}"))
            continue

        args = tok[1:]
        if "--slot-other" in args:
            unsafe.append((lineno, stripped, "inactive_slot_directive_forbidden"))
            continue

        positional = []
        for a in args:
            if a == "--apply-vbmeta":
                continue
            if a.startswith("--"):
                unsafe.append((lineno, stripped, f"unsupported_flash_option:{a}"))
                continue
            positional.append(a)

        if len(positional) not in (1, 2):
            unsafe.append((lineno, stripped, "invalid_flash_arity"))
            continue

        partition = positional[0]
        filename = positional[1] if len(positional) == 2 else partition + ".img"

        if partition.lower() in ("userdata", "metadata"):
            unsafe.append((lineno, stripped, f"forbidden_partition:{partition}"))
            continue

        required.setdefault(filename, set()).add(partition)

    print(f"FASTBOOT_INFO_NONCOMMENT_LINE_COUNT={noncomment}")
    print(f"FASTBOOT_INFO_IF_WIPE_DIRECTIVE_COUNT={if_wipe_count}")
    print(f"FASTBOOT_INFO_REQUIRED_SOURCE_FILE_COUNT={len(required)}")
    print(f"FASTBOOT_INFO_UNSAFE_DIRECTIVE_COUNT={len(unsafe)}")
    if unsafe:
        for lineno, text, reason in unsafe:
            print(
                f"FASTBOOT_INFO_UNSAFE line={lineno} "
                f"reason={reason} text={text!r}"
            )
        print("GATE_ERROR=FASTBOOT_INFO_POLICY_REJECTED")
        raise SystemExit(33)

    # Every image must come from this archive's IMAGES/ namespace.
    plan = []
    staged_total = 0
    for filename in sorted(required):
        member = "IMAGES/" + filename
        if member not in names:
            print(
                f"GATE_ERROR=TARGET_FILES_REQUIRED_IMAGE_MISSING "
                f"filename={filename} member={member}"
            )
            raise SystemExit(33)
        info = zf.getinfo(member)
        staged_total += info.file_size
        plan.append((filename, member, info.file_size, sorted(required[filename])))

    free = shutil.disk_usage(payload).free
    reserve = max(512 * 1024 * 1024, staged_total // 10)
    print(f"FLASH_PAYLOAD_STAGE_REQUIRED_BYTES={staged_total}")
    print(f"FLASH_PAYLOAD_FILESYSTEM_FREE_BYTES={free}")
    print(f"FLASH_PAYLOAD_REQUIRED_RESERVE_BYTES={reserve}")
    if free < staged_total + reserve:
        print(
            f"GATE_ERROR=INSUFFICIENT_TMP_SPACE "
            f"required={staged_total + reserve} free={free}"
        )
        raise SystemExit(33)

    # Controls: android-info is separately SHA-bound product metadata;
    # fastboot-info is the exact copy from this target-files container.
    shutil.copyfile(android_info, payload / "android-info.txt")
    (payload / "fastboot-info.txt").write_bytes(fastboot_info_bytes)

    stage_rows = []
    for index, (filename, member, expected_size, reasons) in enumerate(plan, 1):
        dest = payload / filename
        print(
            f"FLASH_PAYLOAD_STAGE_START index={index}/{len(plan)} "
            f"filename={filename} source=TARGET_FILES_IMAGES size={expected_size}",
            flush=True,
        )
        h = hashlib.sha256()
        total = 0
        with zf.open(member, "r") as src, dest.open("xb") as out:
            while True:
                chunk = src.read(CHUNK)
                if not chunk:
                    break
                out.write(chunk)
                h.update(chunk)
                total += len(chunk)

        # ZipExtFile verifies member CRC when consumed to EOF.
        if total != expected_size:
            print(
                f"GATE_ERROR=TARGET_FILES_EXTRACTION_SIZE_MISMATCH "
                f"filename={filename} expected={expected_size} actual={total}"
            )
            raise SystemExit(33)

        sha = h.hexdigest()
        stage_rows.append([
            filename,
            ",".join(reasons),
            "TARGET_FILES_IMAGES",
            f"{target_files}!{member}",
            str(dest),
            total,
            sha,
            "EXTRACTED_BYTE_FOR_BYTE_TO_EVIDENCE_DIR",
        ])
        print(
            f"FLASH_PAYLOAD_STAGE_DONE filename={filename} sha256={sha} "
            f"materialization=EXTRACTED_BYTE_FOR_BYTE_TO_EVIDENCE_DIR",
            flush=True,
        )

with (evidence / "staged_flash_payload.tsv").open(
    "w", newline="", encoding="utf-8"
) as f:
    w = csv.writer(f, delimiter="\t", lineterminator="\n")
    w.writerow([
        "filename", "partitions_or_reason", "source_kind", "provenance",
        "staged_path", "size", "sha256", "materialization",
    ])
    w.writerows(stage_rows)

control_rows = []
for name in ("android-info.txt", "fastboot-info.txt"):
    p = payload / name
    sha, size = sha256_file(p)
    control_rows.append([name, size, sha])
with (evidence / "staged_flash_control_files.tsv").open(
    "w", newline="", encoding="utf-8"
) as f:
    w = csv.writer(f, delimiter="\t", lineterminator="\n")
    w.writerow(["filename", "size", "sha256"])
    w.writerows(control_rows)

print(f"FLASH_PAYLOAD_STAGED_IMAGE_COUNT={len(stage_rows)}")
print(f"FLASH_PAYLOAD_PRODUCT_OUT_IMAGE_COUNT=0")
print(f"FLASH_PAYLOAD_TARGET_FILES_IMAGE_COUNT={len(stage_rows)}")
print(f"FLASH_PAYLOAD_UPDATE_SUPER_REQUIRED={'YES' if need_super_empty else 'NO'}")
print("TARGET_FILES_SOLE_IMAGE_SOURCE=PASS")
print("FASTBOOT_INFO_PRESERVED_DATA_POLICY=PASS")
print("FASTBOOT_INFO_INACTIVE_SLOT_POLICY=PASS")
print("B2_COMPLETE_STAGED_FLASH_PAYLOAD=PASS")
PY
  local py_rc=$?
  [[ "$py_rc" -eq 0 ]] || return "$py_rc"

  echo "===== STAGED PAYLOAD SEAL ====="
  local seal="$EVIDENCE_DIR/staged_flash_payload.sha256"
  : > "$seal"

  local first=1 filename reasons source_kind provenance staged size sha materialization
  while IFS=$'\t' read -r filename reasons source_kind provenance staged size sha materialization; do
    if (( first )); then
      first=0
      continue
    fi
    [[ "$source_kind" == "TARGET_FILES_IMAGES" ]] || {
      fail "NON_TARGET_FILES_IMAGE_SOURCE_DETECTED file=$filename source=$source_kind"
      return 33
    }
    [[ -f "$staged" ]] || {
      fail "STAGED_PAYLOAD_FILE_MISSING path=$staged"
      return 33
    }
    local actual
    actual="$(sha256_file "$staged")" || return 33
    [[ "$actual" == "$sha" ]] || {
      fail "STAGED_PAYLOAD_HASH_MISMATCH file=$filename expected=$sha actual=$actual"
      return 33
    }
    printf '%s  %s\n' "$sha" "$staged" >> "$seal"
  done < "$EVIDENCE_DIR/staged_flash_payload.tsv"

  local staged actual
  for staged in "$FLASH_PAYLOAD_DIR/android-info.txt" "$FLASH_PAYLOAD_DIR/fastboot-info.txt"; do
    actual="$(sha256_file "$staged")" || return 33
    printf '%s  %s\n' "$actual" "$staged" >> "$seal"
  done

  echo "STAGED_FLASH_PAYLOAD_SEAL=$seal"
  echo "STAGED_FLASH_PAYLOAD_SEAL_SHA256=$(sha256_file "$seal")"
  echo "B2_STAGED_FLASH_PAYLOAD_BINDING=PASS"
  return 0
}

select_tools_and_validate_host() {
  echo "===== HOST TOOL GATE ====="
  local adb_bin fb_bin
  adb_bin="$(command -v adb 2>/dev/null || true)"

  if [[ -x "$B2_OUT/host/linux-x86/bin/fastboot" ]]; then
    fb_bin="$B2_OUT/host/linux-x86/bin/fastboot"
  else
    fb_bin="$(command -v fastboot 2>/dev/null || true)"
  fi

  [[ -n "$adb_bin" ]] || { fail "ADB_NOT_FOUND"; return 33; }
  [[ -n "$fb_bin" ]] || { fail "FASTBOOT_NOT_FOUND"; return 33; }

  printf '%s\n' "$adb_bin" > "$EVIDENCE_DIR/adb_path.txt"
  printf '%s\n' "$fb_bin" > "$EVIDENCE_DIR/fastboot_path.txt"

  echo "ADB_PATH=$adb_bin"
  echo "ADB_SHA256=$(sha256_file "$adb_bin")"
  echo "FASTBOOT_PATH=$fb_bin"
  echo "FASTBOOT_SHA256=$(sha256_file "$fb_bin")"

  "$fb_bin" --help > "$EVIDENCE_DIR/fastboot_help.txt" 2>&1
  local help_rc=$?
  [[ "$help_rc" -eq 0 ]] || { fail "FASTBOOT_HELP_FAILED rc=$help_rc"; return 33; }

  for opt in "--slot" "--set-active" "--skip-secondary" "--skip-reboot"; do
    grep -Fq -- "$opt" "$EVIDENCE_DIR/fastboot_help.txt" || {
      fail "FASTBOOT_REQUIRED_OPTION_MISSING option=$opt"
      return 33
    }
  done

  echo "HOST_FASTBOOT_REQUIRED_OPTIONS=PASS"
  return 0
}

device_contact_gate() {
  echo "===== READ-ONLY DEVICE CONTACT AUTHORIZATION GATE ====="
  echo "DEVICE_CONTACT_AUTHORIZED=$DEVICE_CONTACT_AUTHORIZED"
  [[ "$DEVICE_CONTACT_AUTHORIZED" == "YES" ]] || {
    fail "DEVICE_CONTACT_NOT_AUTHORIZED"
    return 34
  }
  echo "R10R3_DEVICE_CONTACT_AUTHORIZATION=PASS"
  return 0
}

capture_preflash_state() {
  echo "===== PRE-FLASH DEVICE + PRESERVED-DATA BASELINE ====="
  local adb_bin serial
  adb_bin="$(cat "$EVIDENCE_DIR/adb_path.txt")"
  serial="$(cat "$EVIDENCE_DIR/expected_device_serial.txt")"

  local current_serial state product slot unlocked
  current_serial="$("$adb_bin" devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  [[ "$current_serial" == "$serial" ]] || {
    fail "DEVICE_SERIAL_MISMATCH expected_bound_serial_present=YES"
    return 33
  }

  state="$("$adb_bin" -s "$serial" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || { fail "ADB_DEVICE_NOT_READY state=$state"; return 33; }

  product="$(adb_getprop "$adb_bin" "$serial" ro.product.device)"
  slot="$(adb_getprop "$adb_bin" "$serial" ro.boot.slot_suffix)"
  unlocked="$(adb_getprop "$adb_bin" "$serial" ro.boot.flash.locked)"

  echo "PRE_DEVICE_PRODUCT=$product"
  echo "PRE_SLOT_SUFFIX=$slot"
  echo "PRE_FLASH_LOCKED=$unlocked"
  echo "PRE_BUILD_FINGERPRINT=$(adb_getprop "$adb_bin" "$serial" ro.build.fingerprint)"
  echo "PRE_VERIFIED_BOOT_STATE=$(adb_getprop "$adb_bin" "$serial" ro.boot.verifiedbootstate)"
  echo "PRE_CRYPTO_STATE=$(adb_getprop "$adb_bin" "$serial" ro.crypto.state)"
  echo "PRE_CRYPTO_TYPE=$(adb_getprop "$adb_bin" "$serial" ro.crypto.type)"

  [[ "$product" == "$PRODUCT" ]] || { fail "PRE_DEVICE_PRODUCT_MISMATCH"; return 33; }
  [[ "$slot" == "_$EXPECTED_PRE_SLOT" ]] || {
    fail "PRE_SLOT_MISMATCH expected=_$EXPECTED_PRE_SLOT actual=$slot"
    return 33
  }
  [[ "$unlocked" == "0" ]] || { fail "PRE_BOOTLOADER_NOT_UNLOCKED"; return 33; }

  local third_party_count user_count
  third_party_count="$("$adb_bin" -s "$serial" shell 'pm list packages -3 2>/dev/null | wc -l' | tr -d '\r ')"
  user_count="$("$adb_bin" -s "$serial" shell 'cmd user list 2>/dev/null | grep -c "UserInfo{"' | tr -d '\r ')"

  echo "PRE_THIRD_PARTY_PACKAGE_COUNT=$third_party_count"
  echo "PRE_USER_COUNT=$user_count"
  printf '%s\n' "$third_party_count" > "$EVIDENCE_DIR/pre_third_party_package_count.txt"
  printf '%s\n' "$user_count" > "$EVIDENCE_DIR/pre_user_count.txt"

  echo "PRE_FLASH_DEVICE_AND_DATA_BASELINE=PASS"
  return 0
}

verify_staged_payload_before_flash() {
  echo "===== JUST-IN-TIME STAGED PAYLOAD VERIFY ====="
  local seal="$EVIDENCE_DIR/staged_flash_payload.sha256"
  [[ -f "$seal" ]] || { fail "STAGED_FLASH_PAYLOAD_SEAL_MISSING"; return 33; }

  sha256sum -c "$seal" > "$EVIDENCE_DIR/preflash_staged_payload_verify.txt" 2>&1
  local rc=$?
  echo "PREFLASH_STAGED_PAYLOAD_VERIFY_RC=$rc"
  [[ "$rc" -eq 0 ]] || {
    fail "STAGED_FLASH_PAYLOAD_CHANGED_AFTER_BINDING"
    return 33
  }
  echo "PREFLASH_STAGED_PAYLOAD_VERIFY=PASS"
  return 0
}

authorization_gate() {
  echo "===== MUTATING AUTHORIZATION GATE ====="
  echo "DEVICE_CONTACT_AUTHORIZED=$DEVICE_CONTACT_AUTHORIZED"
  echo "DEVICE_REBOOT_AUTHORIZED=$DEVICE_REBOOT_AUTHORIZED"
  echo "FLASH_AUTHORIZED=$FLASH_AUTHORIZED"
  echo "SLOT_REASSERTION_AUTHORIZED=$SLOT_REASSERTION_AUTHORIZED"
  echo "SLOT_CHANGE_AUTHORIZED=NO"
  echo "BOOTLOADER_UNLOCK_AUTHORIZED=NO"
  echo "USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO"
  echo "INACTIVE_SLOT_FLASH_AUTHORIZED=NO"
  echo "FASTBOOT_WIPE_FLAG=ABSENT"

  [[ "$DEVICE_CONTACT_AUTHORIZED" == "YES" ]] || { fail "DEVICE_CONTACT_NOT_AUTHORIZED"; return 34; }
  [[ "$DEVICE_REBOOT_AUTHORIZED" == "YES" ]] || { fail "DEVICE_REBOOT_NOT_AUTHORIZED"; return 34; }
  [[ "$FLASH_AUTHORIZED" == "YES" ]] || { fail "FLASH_NOT_AUTHORIZED"; return 34; }
  [[ "$SLOT_REASSERTION_AUTHORIZED" == "YES" ]] || { fail "SLOT_REASSERTION_NOT_AUTHORIZED"; return 34; }

  echo "R10R3_MUTATING_AUTHORIZATION=PASS"
  return 0
}

execute_flash() {
  echo "===== CONTROLLED STAGED B2 FLASH EXECUTION ====="
  local adb_bin fb serial slot unlocked product
  adb_bin="$(cat "$EVIDENCE_DIR/adb_path.txt")"
  fb="$(cat "$EVIDENCE_DIR/fastboot_path.txt")"
  serial="$(cat "$EVIDENCE_DIR/expected_device_serial.txt")"

  echo "ADB_REBOOT_BOOTLOADER_BEGIN"
  "$adb_bin" -s "$serial" reboot bootloader
  local adb_reboot_rc=$?
  echo "ADB_REBOOT_BOOTLOADER_RC=$adb_reboot_rc"
  [[ "$adb_reboot_rc" -eq 0 ]] || { fail "ADB_REBOOT_BOOTLOADER_FAILED"; return 33; }

  wait_for_fastboot "$fb" "$serial" 90 || {
    fail "FASTBOOT_DEVICE_DID_NOT_APPEAR_AFTER_REBOOT"
    return 33
  }
  echo "FASTBOOT_TRANSPORT_AFTER_REBOOT=PASS"

  product="$(fastboot_getvar "$fb" "$serial" product)"
  slot="$(fastboot_getvar "$fb" "$serial" current-slot)"
  unlocked="$(fastboot_getvar "$fb" "$serial" unlocked)"

  echo "PRE_FLASH_FASTBOOT_PRODUCT=$product"
  echo "PRE_FLASH_FASTBOOT_SLOT=$slot"
  echo "PRE_FLASH_FASTBOOT_UNLOCKED=$unlocked"

  [[ "$product" == "$PRODUCT" ]] || { fail "FASTBOOT_PRODUCT_MISMATCH"; return 33; }
  [[ "$slot" == "$EXPECTED_PRE_SLOT" ]] || {
    fail "FASTBOOT_SLOT_MISMATCH expected=$EXPECTED_PRE_SLOT actual=$slot"
    return 33
  }
  case "$unlocked" in

    yes|true|1) ;;
    *) fail "FASTBOOT_BOOTLOADER_NOT_UNLOCKED value=$unlocked"; return 33 ;;
  esac

  echo "FLASH_METHOD=FASTBOOT_FLASHALL_STAGED_CURRENT_SLOT"
  echo "FLASH_TARGET_SLOT=$EXPECTED_PRE_SLOT"
  echo "FLASH_SKIP_SECONDARY=YES"
  echo "FLASH_SKIP_REBOOT=YES"
  echo "FLASH_WIPE=NO"
  echo "FLASH_ANDROID_PRODUCT_OUT=$FLASH_PAYLOAD_DIR"

  ANDROID_PRODUCT_OUT="$FLASH_PAYLOAD_DIR" \
    "$fb" -s "$serial" \
      --slot "$EXPECTED_PRE_SLOT" \
      --set-active="$EXPECTED_PRE_SLOT" \
      --skip-secondary \
      --skip-reboot \
      flashall \
      2>&1 | tee "$EVIDENCE_DIR/fastboot_flashall.txt"
  local flash_rc=${PIPESTATUS[0]}

  echo "FASTBOOT_FLASHALL_RC=$flash_rc"
  if [[ "$flash_rc" -ne 0 ]]; then
    echo "FINAL_REBOOT_SUPPRESSED_DUE_TO_FLASH_FAILURE=YES"
    fail "FASTBOOT_FLASHALL_FAILED rc=$flash_rc"
    return 35
  fi

  wait_for_fastboot "$fb" "$serial" 60 || {
    fail "FASTBOOT_TRANSPORT_MISSING_AFTER_FLASH"
    return 33
  }

  slot="$(fastboot_getvar "$fb" "$serial" current-slot)"
  echo "POST_FLASH_PRE_REBOOT_SLOT=$slot"
  [[ "$slot" == "$EXPECTED_PRE_SLOT" ]] || {
    echo "FINAL_REBOOT_SUPPRESSED_DUE_TO_SLOT_MISMATCH=YES"
    fail "POST_FLASH_SLOT_CHANGED expected=$EXPECTED_PRE_SLOT actual=$slot"
    return 35
  }

  echo "FASTBOOT_FLASH_PAYLOAD_EXECUTION=PASS"
  echo "POST_FLASH_PRE_REBOOT_SLOT_PRESERVED=PASS"

  "$fb" -s "$serial" reboot
  local reboot_rc=$?
  echo "FINAL_FASTBOOT_REBOOT_RC=$reboot_rc"
  [[ "$reboot_rc" -eq 0 ]] || { fail "FINAL_FASTBOOT_REBOOT_FAILED"; return 35; }

  echo "CONTROLLED_B2_FLASH_EXECUTION=PASS"
  return 0
}

postboot_proof() {
  echo "===== POST-FLASH EXACT B2 BOOT + PRESERVED-DATA PROOF ====="
  local adb_bin serial
  adb_bin="$(cat "$EVIDENCE_DIR/adb_path.txt")"
  serial="$(cat "$EVIDENCE_DIR/expected_device_serial.txt")"

  wait_for_adb_device "$adb_bin" "$serial" 300 || {
    fail "ADB_DID_NOT_RETURN_AFTER_FLASH timeout=300"
    return 36
  }

  local start now boot_completed
  start="$(date +%s)"
  while :; do
    boot_completed="$(adb_getprop "$adb_bin" "$serial" sys.boot_completed)"
    [[ "$boot_completed" == "1" ]] && break
    now="$(date +%s)"
    if (( now - start >= 300 )); then
      fail "ANDROID_BOOT_NOT_COMPLETED timeout=300"
      return 36
    fi
    sleep 2
  done

  echo "POST_SYS_BOOT_COMPLETED=1"
  echo "POST_DEVICE_PRODUCT=$(adb_getprop "$adb_bin" "$serial" ro.product.device)"
  echo "POST_SLOT_SUFFIX=$(adb_getprop "$adb_bin" "$serial" ro.boot.slot_suffix)"
  echo "POST_FLASH_LOCKED=$(adb_getprop "$adb_bin" "$serial" ro.boot.flash.locked)"
  echo "POST_VERIFIED_BOOT_STATE=$(adb_getprop "$adb_bin" "$serial" ro.boot.verifiedbootstate)"
  echo "POST_BUILD_FINGERPRINT=$(adb_getprop "$adb_bin" "$serial" ro.build.fingerprint)"
  echo "POST_CRYPTO_STATE=$(adb_getprop "$adb_bin" "$serial" ro.crypto.state)"
  echo "POST_CRYPTO_TYPE=$(adb_getprop "$adb_bin" "$serial" ro.crypto.type)"

  [[ "$(adb_getprop "$adb_bin" "$serial" ro.product.device)" == "$PRODUCT" ]] || {
    fail "POST_DEVICE_PRODUCT_MISMATCH"
    return 36
  }
  [[ "$(adb_getprop "$adb_bin" "$serial" ro.boot.slot_suffix)" == "_$EXPECTED_PRE_SLOT" ]] || {
    fail "POST_BOOT_SLOT_MISMATCH"
    return 36
  }

  echo "===== POST-FLASH EXACT B2 FILE IDENTITY ====="
  local expected_bm actual_bm
  expected_bm="$(cat "$EVIDENCE_DIR/expected_buildmanifest_apk_sha256.txt")"
  actual_bm="$("$adb_bin" -s "$serial" shell 'sha256sum /system/etc/security/fsverity/BuildManifest.apk 2>/dev/null' \
    | tr -d '\r\' | awk '{print $1}')"
  echo "POST_BUILDMANIFEST_APK_SHA256=$actual_bm"
  [[ "$actual_bm" == "$expected_bm" ]] || {
    fail "POST_BUILDMANIFEST_NOT_B2 expected=$expected_bm actual=$actual_bm"
    return 36
  }
  echo "POST_BUILDMANIFEST_EXACT_B2_MATCH=PASS"

  local first=1 path size expected actual art_match=0
  while IFS=$'\t' read -r path size expected; do
    if (( first )); then
      first=0
      continue
    fi
    actual="$("$adb_bin" -s "$serial" shell "sha256sum '/$path' 2>/dev/null" \
      | tr -d '\r\' | awk '{print $1}')"
    echo "POST_B2_ART_SHA256 path=$path actual=$actual expected=$expected"
    [[ "$actual" == "$expected" ]] || {
      fail "POST_B2_ART_MISMATCH path=$path"
      return 36
    }
    art_match=$((art_match + 1))
  done < "$EVIDENCE_DIR/expected_b2_art_sha256.tsv"

  echo "POST_B2_ART_EXACT_MATCH_COUNT=$art_match"
  [[ "$art_match" -eq 5 ]] || { fail "POST_B2_ART_MATCH_COUNT_INVALID"; return 36; }
  echo "POST_EXACT_B2_SYSTEM_ARTIFACT_IDENTITY=PASS"

  echo "USER_ACTION=UNLOCK_DEVICE_WITH_EXISTING_CREDENTIAL_IF_NEEDED_FOR_CE_DATA_CHECK"
  start="$(date +%s)"
  local ce
  while :; do
    ce="$(adb_getprop "$adb_bin" "$serial" sys.user.0.ce_available)"
    if [[ "$ce" == "true" || "$ce" == "1" ]]; then
      break
    fi
    now="$(date +%s)"
    if (( now - start >= 300 )); then
      echo "POST_CE_AVAILABLE=$ce"
      fail "CREDENTIAL_ENCRYPTED_DATA_NOT_CONFIRMED timeout=300"
      return 37
    fi
    sleep 2
  done
  echo "POST_CE_AVAILABLE=$ce"

  local pre_pkg pre_users post_pkg post_users
  pre_pkg="$(cat "$EVIDENCE_DIR/pre_third_party_package_count.txt")"
  pre_users="$(cat "$EVIDENCE_DIR/pre_user_count.txt")"
  post_pkg="$("$adb_bin" -s "$serial" shell 'pm list packages -3 2>/dev/null | wc -l' | tr -d '\r\ '))"
  post_users="$("$adb_bin" -s "$serial" shell 'cmd user list 2>/dev/null | grep -c "UserInfo{"' | tr -d '\r\ '))"

  echo "PRE_THIRD_PARTY_PACKAGE_COUNT=$pre_pkg"
  echo "POST_THIRD_PARTY_PACKAGE_COUNT=$post_pkg"
  echo "PRE_USER_COUNT=$pre_users"
  echo "POST_USER_COUNT=$post_users"

  [[ "$post_pkg" == "$pre_pkg" ]] || {
    fail "THIRD_PARTY_PACKAGE_COUNT_CHANGED pre=$pre_pkg post=$post_pkg"
    return 37
  }
  [[ "$post_users" == "$pre_users" ]] || {
    fail "USER_COUNT_CHANGED pre=$pre_users post=$post_users"
    return 37
  }

  echo "POST_PRESERVED_CE_DATA_ACCESS=PASS"
  echo "POST_THIRD_PARTY_PACKAGE_COUNT_PRESERVED=PASS"
  echo "POST_USER_COUNT_PRESERVED=PASS"
  echo "POST_B2_BOOT_PROOF=PASS"
  echo "R10R3_PRESERVED_DATA_FUNCTIONAL_VALIDATION=PASS"
  return 0
}

run_core() {
  echo "===== PANTHER P1B-D4-B2B2R10R3 / STAGED EXACT PRESERVED-DATA FLASH + BOOT PROOF ====="
  echo "SOURCE_MUTATION_AUTHORIZED=NO"
  echo "WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO"
  echo "BUILD_AUTHORIZED=NO"
  echo "CLEAN_OR_CLOBBER_AUTHORIZED=NO"
  echo "DELETE_AUTHORIZED=NO"
  echo "DEVICE_CONTACT_AUTHORIZED=$DEVICE_CONTACT_AUTHORIZED"
  echo "DEVICE_REBOOT_AUTHORIZED=$DEY%}I	==Q}UQ!=I%ià(ÄÅïç°ºÄâ1M!}UQ!=I%iÙë1M!}UQ!=I%ià(ÄÅïç°ºÄâM1=Q}IMMIQ%=9}UQ!=I%iÙëM1=Q}IMMIQ%=9}UQ!=I%ià(ÄÅïç°ºÄâM1=Q}!9}UQ!=I%iı9<à(ÄÅïç°ºÄâ	==Q1=I}U91=-}UQ!=I%iı9<à(ÄÅïç°ºÄâUMIQ}=I}5QQ}]%A}UQ!=I%iı9<à(ÄÅïç°ºÄâ%9Q%Y}M1=Q}1M!}UQ!=I%iı9<à(ÄÅïç°ºÄâQ5A}Y%9}5UQQ%=8ıeM}Y%9}%I}=91dà(ÄÅïç°ºÄâïŸ•ëïπçï}ë•»ÙëY%9}%Hà((ÄÅâ•πë}¡…•Ω…}ïŸ•ëïπçîÅÒÅ…ï—’…∏Äê¸(ÄÅÕ—Öùï}ï·Öç—}¡ÖÂ±ΩÖêÅÒÅ…ï—’…∏Äê¸(ÄÅÕï±ïç—}—ΩΩ±Õ}Öπë}ŸÖ±•ëÖ—ï}°ΩÕ–ÅÒÅ…ï—’…∏Äê¸(ÄÅëïŸ•çï}çΩπ—Öç—}ùÖ—îÅÒÅ…ï—’…∏Äê¸(ÄÅçÖ¡—’…ï}¡…ïô±ÖÕ°}Õ—Ö—îÅÒÅ…ï—’…∏Äê¸(ÄÅÖ’—°Ω…•ÈÖ—•Ωπ}ùÖ—îÅÒÅ…ï—’…∏Äê¸(ÄÅŸï…•ôÂ}Õ—Öùïë}¡ÖÂ±ΩÖë}âïôΩ…ï}ô±ÖÕ†ÅÒÅ…ï—’…∏Äê¸(ÄÅï·ïç’—ï}ô±ÖÕ†ÅÒÅ…ï—’…∏Äê¸(ÄÅ¡ΩÕ—âΩΩ—}¡…ΩΩòÅÒÅ…ï—’…∏Äê¸((ÄÅïç°ºÄâHƒ¡HÕ}HÂ}	%9%9ıAMLà(ÄÅïç°ºÄâHƒ¡HÕ}Hƒ¡H…}	=U9}%1UI}	%9%9ıAMLà(ÄÅïç°ºÄâHƒ¡HÕ}=5A1Q}MQ}…}Ae1=ıAMLà(ÄÅïç°ºÄâHƒ¡HÕ}=9QI=11}1M!}aUQ%=8ıAMLà(ÄÅïç°ºÄâHƒ¡HÕ}aQ}…}A=MQ	==Q}%9Q%QdıAMLà(ÄÅïç°ºÄâHƒ¡HÕ}AIMIY}Q}Y1%Q%=8ıAMLà(ÄÅïç°ºÄâA9Q!I}@≈	}—}……Hƒ¡HÕ}IMU1PıAMLà(ÄÅ…ï—’…∏Ä¿)Ù()…’π}çΩ…îÄ»¯òƒÅÅ—ïîÄàë1=à)…åÙëÌA%AMQQUMl¡uÙ()•òÅmlÄàë…åàÄµïƒÄ¿ÅutÏÅ—°ï∏(ÄÅ¡…•π—òÄúïÕq∏úÅp(ÄÄÄÄâ—}……Hƒ¡HÕ}ùÖ—ï}…åÙ¿àÅp(ÄÄÄÄâA9Q!I}@≈	}—}……Hƒ¡HÕ}IMU1PıAMLàÄ¯ÄàëY%9}%HΩ…ïÕ’±–π—·–à)ï±Õî(ÄÅ¡…•π—òÄúïÕq∏úÅp(ÄÄÄÄâ—}……Hƒ¡HÕ}ùÖ—ï}…åÙë…åàÅp(ÄÄÄÄâA9Q!I}@≈	}—}……Hƒ¡HÕ}IMU1Pı	=U9}%0àÄ¯ÄàëY%9}%HΩ…ïÕ’±–π—·–à)ô§((†(ÄÅçêÄàëY%9}%HàÅÒÅï·•–Äƒ(ÄÅô•πêÄ∏Äµ—Â¡îÅòÄÑÄµπÖµîÅïŸ•ëïπçîπÕ°Ñ»‘ÿÄÑÄµ¡Ö—†Äú∏Ωô±ÖÕ°}¡ÖÂ±ΩÖêº®úÄµ¡…•π–¿Åp(ÄÄÄÅÅ1}10ıÅÕΩ…–ÄµËÅp(ÄÄÄÅÅ·Ö…ùÃÄ¥¿ÅÕ°Ñ»‘ŸÕ’¥(§Ä¯ÄàëY%9}%HΩïŸ•ëïπçîπÕ°Ñ»‘ÿà)ÕïÖ±}…åÙê¸()•òÅmlÄàëÕïÖ±}…åàÄµπîÄ¿ÅutÏÅ—°ï∏(ÄÅïç°ºÄâQ}II=HıY%9}M1}9IQ%=9}%1Å…åÙëÕïÖ±}…åà(ÄÅï·•–Ä‰ƒ)ô§()Y%9}M1}M!»‘ÿÙàê°Õ°Ñ»‘Ÿ}ô•±îÄàëY%9}%HΩïŸ•ëïπçîπÕ°Ñ»‘ÿà§àÅÒÅï·•–Ä‰ƒ)ïç°ºÄàÙÙÙÙÙÅY%9ÅM0ÄÙÙÙÙÙà)ïç°ºÄâY%9}M0ÙëY%9}%HΩïŸ•ëïπçîπÕ°Ñ»‘ÿà)ïç°ºÄâY%9}M1}M!»‘ÿÙëY%9}M1}M!»‘ÿà)•òÅmlÄàë…åàÄµïƒÄ¿ÅutÏÅ—°ï∏(ÄÅïç°ºÄâA9Q!I}@≈	}—}……Hƒ¡HÕ}IMU1PıAMLà)ï±Õî(ÄÅïç°ºÄâA9Q!I}@≈	}—}……Hƒ¡HÕ}IMU1Pı	=U9}%0à)ô§)ï·•–Äàë…åà(