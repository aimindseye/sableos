#!/usr/bin/env bash
# SableOS PR 207 — N1B2 cellular / telephony static composition audit.
#
# Compares the telephony stack of:
#   stock   (known-good reference)
#   n1b1    (failing sample 1: connects, then disconnects)
#   n1b2    (failing sample 2: same symptom)
# and optionally RestlessOS and AOSP/Treble GSI as candidate module sources.
#
# Titan 2 N1 images are a GSI system.img running over the STOCK vendor
# partitions. The audit therefore separates:
#   SYSTEM side     GSI vs stock framework (large, often expected differences)
#   INTERFACE side  radio HAL versions, SELinux mapping, vendor props/rc,
#                   vendor IMS packages the GSI framework must cooperate with
# The primary signal is: present in stock, absent/different in BOTH n1b1 and n1b2.
#
# READ-ONLY CONTRACT
#   - Never writes to any input path. Everything goes under --out.
#   - Never contacts a device. Never builds, never flashes.
#   - Partition images are opened read-only (debugfs without -w, fsck.erofs --extract).
#
# Input forms accepted for --stock/--n1b1/--n1b2/--restless/--aosp:
#   1. Directory of extracted partitions   (system/ vendor/ product/ system_ext/ odm/)
#   2. Directory of partition images       (system.img vendor.img ... or super.img)
#   3. A single super.img or system.img, raw or sparse (sparse images are expanded
#      with simg2img first, then detected as super / ext4 / EROFS; a sparse super needs
#      its full raw size, ~9.7 GB on Titan 2, of free space under --out while extracting)
#   4. Android build out dir               (out/target/product/<name>, has system/)
#   5. Source tree (--restless / --aosp only; detected by .repo/ or build/make/)
#      -> module availability only, used to name candidate sources.
#
# n1b1/n1b2 images without their own vendor/odm inherit the stock vendor/odm,
# which matches how the GSI actually runs on device. This is recorded in the report.
#
# Output (under --out, default ./out/n1b2-cellular-audit-<timestamp>):
#   N1B2_CELLULAR_STATIC_SUMMARY.env   KEY=VALUE, consumed by the PR 207 gate
#   N1B2_CELLULAR_STATIC_REPORT.md     human report, prioritised findings
#   findings.tsv                       every classified difference
#   inventory/<label>/*.tsv            raw per-image inventories
#   work/                              extracted trees (delete with --clean-work)
#
# Exit codes: 0 audit completed (findings are data, not failure)
#             2 usage error   3 missing tool for a given input   4 extraction failure

set -euo pipefail

SCRIPT_VERSION="1.2.0"

usage() {
  cat <<'EOF'
Usage:
  audit-n1b2-cellular-stack.sh --stock PATH --n1b1 PATH --n1b2 PATH
                               [--restless PATH] [--aosp PATH]
                               [--slot a|b] [--mccmnc 310260,311480]
                               [--out DIR] [--clean-work]

  --stock      Stock firmware (known-good). Required.
  --n1b1       N1B1 image. Required.
  --n1b2       N1B2 candidate image. Required.
  --restless   RestlessOS image or source tree. Optional candidate source.
  --aosp       AOSP / Treble GSI image or source tree. Optional candidate source.
  --slot       Slot to take from a super.img on virtual A/B devices (default: a).
  --mccmnc     Comma-separated MCC+MNC of the test SIM(s); APN entries for these
               are itemised (default, mms, ia, ims, supl types).
  --out        Output directory.
  --clean-work Delete extracted trees after the report is written.
EOF
}

die()  { echo "ERROR: $1" >&2; exit "${2:-1}"; }
log()  { echo "[$(date +%H:%M:%S)] $*" >&2; }

STOCK="" N1B1="" N1B2="" RESTLESS="" AOSP="" SLOT="a" MCCMNC="" OUT="" CLEAN_WORK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stock)      STOCK="${2:-}"; shift 2 ;;
    --n1b1)       N1B1="${2:-}"; shift 2 ;;
    --n1b2)       N1B2="${2:-}"; shift 2 ;;
    --restless)   RESTLESS="${2:-}"; shift 2 ;;
    --aosp)       AOSP="${2:-}"; shift 2 ;;
    --slot)       SLOT="${2:-}"; shift 2 ;;
    --mccmnc)     MCCMNC="${2:-}"; shift 2 ;;
    --out)        OUT="${2:-}"; shift 2 ;;
    --clean-work) CLEAN_WORK=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" 2 ;;
  esac
done

[[ -n "$STOCK" && -n "$N1B1" && -n "$N1B2" ]] || { usage >&2; die "--stock, --n1b1 and --n1b2 are required" 2; }
[[ "$SLOT" == "a" || "$SLOT" == "b" ]] || die "--slot must be a or b" 2
command -v python3 >/dev/null || die "python3 is required" 3
for p in "$STOCK" "$N1B1" "$N1B2" ${RESTLESS:+"$RESTLESS"} ${AOSP:+"$AOSP"}; do
  [[ -e "$p" ]] || die "input not found: $p" 2
done

OUT="${OUT:-./out/n1b2-cellular-audit-$(date +%Y%m%d-%H%M%S)}"
abspath() { python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }

# Refuse to place output inside an input (would violate read-only contract).
# Checked before anything is created.
OUT="$(abspath "$OUT")"
[[ "$OUT" != "/" ]] || die "--out must not be /" 2
for p in "$STOCK" "$N1B1" "$N1B2" ${RESTLESS:+"$RESTLESS"} ${AOSP:+"$AOSP"}; do
  ap="$(abspath "$p")"
  case "$OUT/" in "$ap"/*) die "--out must not be inside input $p" 2 ;; esac
  # And no input inside --out: the cleanup below deletes temporaries under --out/work.
  case "$ap/" in "$OUT"/*) die "input $p must not be inside --out" 2 ;; esac
done

mkdir -p "$OUT"
WORK="$OUT/work"
mkdir -p "$WORK" "$OUT/inventory"

# ---------------------------------------------------------------- cleanup
# Temporaries (all named *.raw.img, or the _lp/ lpunpack directory) can be many GB.
# They are removed on EVERY exit: success, die(), tool failure, python failure, Ctrl-C/TERM.
# On failure the whole work tree goes too (partial extractions are not trustworthy);
# extraction logs are kept under failure-logs/ and a FAILED summary is written.
# find runs without -L and rm -rf does not follow symlinks, so links to inputs are only unlinked.
AUDIT_OK=0
TOOL_PID=""
# Heavy tools run as a tracked child so INT/TERM interrupt `wait` immediately
# (bash defers traps until a foreground command ends) and cleanup can stop the
# writer before deleting what it is writing.
run_tool() {
  "$@" &
  TOOL_PID=$!
  local rc=0
  wait "$TOOL_PID" || rc=$?
  TOOL_PID=""
  return "$rc"
}
temp_sweep() {
  [[ -d "$WORK" ]] || return 0
  local bytes
  bytes="$(find "$WORK" \( -name '*.raw.img' -o -path '*/_lp/*' \) -type f -printf '%s\n' 2>/dev/null | awk '{s += $1} END {print s + 0}')"
  find "$WORK" -depth \( -name '*.raw.img' -o -name '_lp' \) -exec rm -rf {} + 2>/dev/null || true
  echo "$bytes"
}
cleanup() {
  local rc=$? removed
  trap - EXIT INT TERM
  if [[ -n "$TOOL_PID" ]]; then
    kill "$TOOL_PID" 2>/dev/null || true
    wait "$TOOL_PID" 2>/dev/null || true
  fi
  if [[ -n "${WORK:-}" && "$WORK" == "$OUT/work" && -d "$WORK" ]]; then
    removed="$(temp_sweep)"
    if [[ "$AUDIT_OK" -ne 1 ]]; then
      mkdir -p "$OUT/failure-logs"
      find "$WORK" -type f \( -name '*.debugfs.log' -o -name '*.erofs.log' -o -name '*.7z.log' \) -print0 2>/dev/null |
        while IFS= read -r -d '' f; do cp -- "$f" "$OUT/failure-logs/$(echo "${f#"$WORK"/}" | tr '/' '_')"; done
      rm -rf "$WORK"
      {
        echo "N1B2_CELLULAR_STATIC_AUDIT=FAILED"
        echo "AUDIT_SCRIPT_VERSION=$SCRIPT_VERSION"
        echo "EXIT_CODE=$rc"
        echo "TEMP_ARTIFACT_BYTES_REMOVED=$removed"
        echo "WORK_TREE_REMOVED=YES"
        echo "FAILURE_LOGS=$OUT/failure-logs"
      } > "$OUT/N1B2_CELLULAR_STATIC_SUMMARY.env"
      echo "audit failed (exit $rc): removed $removed bytes of temporary images and the work tree; logs in $OUT/failure-logs" >&2
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

PARTS=(system system_ext product vendor odm)

# ---------------------------------------------------------------- detection

# Print hex of N bytes at OFFSET of FILE.
hexat() { od -An -tx1 -j "$2" -N "$3" "$1" 2>/dev/null | tr -d ' \n'; }

image_type() {
  local f="$1"
  [[ -f "$f" ]] || { echo "none"; return; }
  if [[ "$(hexat "$f" 0 4)" == "3aff26ed" ]]; then echo "sparse"; return; fi
  if [[ "$(hexat "$f" 4096 4)" == "67446c61" ]]; then echo "super"; return; fi
  if [[ "$(hexat "$f" 1080 2)" == "53ef" ]]; then echo "ext4"; return; fi
  if [[ "$(hexat "$f" 1024 4)" == "e2e1f5e0" ]]; then echo "erofs"; return; fi
  echo "unknown"
}

need() { command -v "$1" >/dev/null || die "tool '$1' needed to read $2 (install it or provide an extracted directory)" 3; }

# Extract one filesystem image into DEST (read-only on the source).
# Extraction tools are not trusted to report failure through their exit code:
# debugfs exits 0 after "Filesystem revision too high while trying to open" and
# extracts nothing. Every extraction is therefore checked for error text and for
# producing at least one entry, so a corrupt image can never yield a COMPLETE audit.
verify_extraction() {
  local img="$1" dest="$2" log="$3"
  if [[ -s "$log" ]] && grep -qiE 'while trying to open|filesystem not open|bad magic|corrupt|short read|cannot open|can.t open|not a valid|i/o error|error:' "$log"; then
    die "extraction of $img reported errors (see $log): $(grep -iE 'while trying|not open|bad magic|corrupt|short read|cannot open|can.t open|not a valid|i/o error|error:' "$log" | head -1)" 4
  fi
  if [[ -z "$(find "$dest" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    die "extraction of $img produced no files (see $log)" 4
  fi
}

extract_fs() {
  local img="$1" dest="$2" t log=""
  t="$(image_type "$img")"
  mkdir -p "$dest"
  case "$t" in
    sparse)
      need simg2img "$img"
      local raw="$dest.raw.img"
      run_tool simg2img "$img" "$raw" >/dev/null || die "simg2img failed: $img" 4
      if [[ "$(image_type "$raw")" == "super" ]]; then
        rm -f "$raw"
        die "$img is a sparse super image, not a single filesystem; pass it as the input itself or name it super.img" 4
      fi
      extract_fs "$raw" "$dest"
      rm -f "$raw" ;;
    ext4)
      if command -v debugfs >/dev/null; then
        # debugfs opens read-only unless -w is given.
        log="$dest.debugfs.log"
        run_tool debugfs -R "rdump / $dest" "$img" >/dev/null 2>"$log" \
          || die "debugfs extraction failed: $img (see $log)" 4
      elif command -v 7z >/dev/null; then
        log="$dest.7z.log"
        run_tool 7z x -y -o"$dest" "$img" >/dev/null 2>"$log" || die "7z extraction failed: $img (see $log)" 4
      else
        die "need debugfs (e2fsprogs) or 7z to read ext4 image $img" 3
      fi ;;
    erofs)
      if command -v fsck.erofs >/dev/null; then
        log="$dest.erofs.log"
        run_tool fsck.erofs --extract="$dest" "$img" >/dev/null 2>"$log" \
          || die "fsck.erofs extraction failed: $img (see $log)" 4
      elif command -v extract.erofs >/dev/null; then
        log="$dest.erofs.log"
        run_tool extract.erofs -i "$img" -o "$dest" -x >/dev/null 2>"$log" || die "extract.erofs failed: $img (see $log)" 4
      else
        die "need fsck.erofs (erofs-utils >= 1.6) or extract.erofs to read EROFS image $img" 3
      fi ;;
    super) die "$img is a super image, not a single filesystem; pass it as the input itself or name it super.img" 4 ;;
    *) die "unsupported image type '$t' for $img" 4 ;;
  esac
  if [[ "$t" == "ext4" || "$t" == "erofs" ]]; then verify_extraction "$img" "$dest" "$log"; fi
}

# Unpack super.img, then extract the wanted logical partitions for SLOT.
extract_super() {
  local img="$1" dest="$2"
  local raw="$img" lp="$dest/_lp"
  mkdir -p "$lp"
  if [[ "$(image_type "$img")" == "sparse" ]]; then
    need simg2img "$img"
    raw="$dest/_super.raw.img"
    run_tool simg2img "$img" "$raw" >/dev/null || die "simg2img failed: $img" 4
  fi
  [[ "$(image_type "$raw")" == "super" ]] || die "$img is not a super image (no LP metadata at 4096)" 4
  need lpunpack "$img"
  run_tool lpunpack "$raw" "$lp" >/dev/null || die "lpunpack failed: $img" 4
  if [[ "$raw" != "$img" ]]; then rm -f "$raw"; fi
  local p f
  for p in "${PARTS[@]}"; do
    [[ -e "$dest/$p" ]] && continue      # already supplied as its own image or directory
    for f in "$lp/${p}_${SLOT}.img" "$lp/${p}.img"; do
      if [[ -s "$f" ]]; then extract_fs "$f" "$dest/$p"; break; fi
    done
  done
  rm -rf "$lp"
}

# Normalise an input into WORK/<label>/<partition>/ ; prints the mode.
# Sets NORM_MODE (image|source). Deliberately not called via $(...): tool output on stdout
# must never be able to corrupt the result, and die() must stop the whole script.
NORM_MODE=""
normalise() {
  local label="$1" src="$2"
  local dest="$WORK/$label"
  NORM_MODE=""
  mkdir -p "$dest"
  if [[ -d "$src" && ( -d "$src/.repo" || -d "$src/build/make" ) ]]; then
    NORM_MODE="source"; return
  fi
  if [[ -f "$src" ]]; then
    local img="$src" t expanded=""
    t="$(image_type "$src")"
    if [[ "$t" == "sparse" ]]; then
      expanded=" after sparse expansion"
      # Expand first, then decide by what the raw image actually is (super, ext4 or EROFS).
      need simg2img "$src"
      img="$dest/_input.raw.img"
      log "expanding sparse image $src (a sparse super expands to its full raw size)"
      run_tool simg2img "$src" "$img" >/dev/null || die "simg2img failed: $src" 4
      t="$(image_type "$img")"
    fi
    case "$t" in
      super) extract_super "$img" "$dest" ;;
      ext4|erofs) extract_fs "$img" "$dest/system" ;;
      *) die "cannot identify image $src (type '$t'$expanded)" 4 ;;
    esac
    if [[ "$img" != "$src" ]]; then rm -f "$img"; fi
  else
    local p
    for p in "${PARTS[@]}"; do
      if [[ -d "$src/$p" ]]; then
        ln -sfn "$(cd "$src/$p" && pwd)" "$dest/$p"
      elif [[ -f "$src/$p.img" ]]; then
        extract_fs "$src/$p.img" "$dest/$p"
      fi
    done
    if [[ ! -e "$dest/system" && -f "$src/super.img" ]]; then
      extract_super "$src/super.img" "$dest"
    fi
  fi
  # System-as-root layout: system partition root contains system/build.prop.
  if [[ -d "$dest/system/system" && -f "$dest/system/system/build.prop" ]]; then
    mv "$dest/system" "$dest/_system_root"          # moves our extraction or our symlink, never the input
    ln -sfn "$(cd "$dest/_system_root/system" && pwd)" "$dest/system"
  fi
  # GSI: product and system_ext live inside the system image.
  for p in product system_ext; do
    if [[ ! -e "$dest/$p" && -d "$dest/system/$p" ]]; then
      ln -sfn "$(cd "$dest/system/$p" && pwd)" "$dest/$p"
    fi
  done
  [[ -e "$dest/system" ]] || die "no system partition found in $src" 4
  [[ -f "$dest/system/build.prop" ]] || die "system partition from $src has no build.prop; not a usable system image" 4
  NORM_MODE="image"
}

# ------------------------------------------------------------------- main

declare -A MODE VENDOR_SRC
LABELS=(stock n1b1 n1b2)
declare -A SRC=([stock]="$STOCK" [n1b1]="$N1B1" [n1b2]="$N1B2")
[[ -n "$RESTLESS" ]] && { LABELS+=(restless); SRC[restless]="$RESTLESS"; }
[[ -n "$AOSP"     ]] && { LABELS+=(aosp);     SRC[aosp]="$AOSP"; }

for l in "${LABELS[@]}"; do
  log "normalising $l from ${SRC[$l]}"
  normalise "$l" "${SRC[$l]}"
  MODE[$l]="$NORM_MODE"
  VENDOR_SRC[$l]="own"
done

[[ "${MODE[stock]}" == "image" && -e "$WORK/stock/vendor" ]] \
  || die "stock input must contain a vendor partition (it is the known-good reference)" 2

# N1 images run on stock vendor/odm: inherit when not supplied.
for l in n1b1 n1b2; do
  for p in vendor odm; do
    if [[ ! -e "$WORK/$l/$p" && -e "$WORK/stock/$p" ]]; then
      ln -sfn "$(cd "$WORK/stock/$p" && pwd)" "$WORK/$l/$p"
      VENDOR_SRC[$l]="inherited-from-stock"
    fi
  done
done

META=()
for l in "${LABELS[@]}"; do META+=("$l" "${MODE[$l]}" "${VENDOR_SRC[$l]}" "${SRC[$l]}"); done
ARGS_JSON="$(python3 -c '
import json, sys
a = sys.argv[1:]; d = {"labels": [], "mode": {}, "vendor_src": {}, "src": {}}
for i in range(0, len(a), 4):
    l, m, v, s = a[i:i + 4]
    d["labels"].append(l); d["mode"][l] = m; d["vendor_src"][l] = v; d["src"][l] = s
print(json.dumps(d))' "${META[@]}")"

log "building inventories and comparing"
python3 - "$WORK" "$OUT" "$MCCMNC" "$ARGS_JSON" "$SCRIPT_VERSION" <<'PYEOF'
import hashlib, json, os, re, shutil, subprocess, sys
import xml.etree.ElementTree as ET
from collections import defaultdict

WORK, OUT, MCCMNC, ARGS, VERSION = sys.argv[1], sys.argv[2], sys.argv[3], json.loads(sys.argv[4]), sys.argv[5]
LABELS, MODE, VSRC, SRC = ARGS["labels"], ARGS["mode"], ARGS["vendor_src"], ARGS["src"]
PARTS = ["system", "system_ext", "product", "vendor", "odm"]
VENDOR_SIDE = {"vendor", "odm"}
MCCMNC = [m.strip() for m in MCCMNC.split(",") if m.strip()]

# Anything matching this is "telephony relevant" and goes into the main report.
TEL = re.compile(
    r"(teleservice|telephony|telecom|carrierconfig|carrier_config|cellbroadcast|"
    r"\bstk\b|simapp|mmsservice|\bmms\b|euicc|\blpa\b|esim|\bims|imsservice|volte|vowifi|"
    r"\brcs|mbms|\bril\b|rild|radio|modem|ccci|mdinit|\bmd\d|fusionril|mtkril|"
    r"\bsim\b|apn|dataconnection|qti.*data|netmgr|wfca|wfc|\bepdg|nr5g|\b5g\b|"
    r"mediatek.*(tele|ims|radio)|mtk.*(tele|ims|radio)|phh|trebledroid)",
    re.I)
PROP_KEEP = re.compile(
    r"^(ro\.telephony\.|persist\.radio\.|persist\.vendor\.radio\.|ro\.vendor\.radio\.|"
    r"ro\.vendor\.(mtk_|md|ims)|persist\.vendor\.(ims|mtk_|md)|ro\.vendor\.mtk|"
    r"telephony\.|ril\.|vendor\.ril\.|persist\.ril|ro\.ril\.|persist\.dbg\.(volte|wfc|vt|ims)|"
    r"persist\.sys\.phh|ro\.boot\.hardware|ro\.hardware|ro\.board\.platform|"
    r"ro\.build\.version\.(release|sdk|security_patch)|ro\.vendor\.build\.version|"
    r"ro\.product\.first_api_level|ro\.vndk\.version|ro\.board\.(api_level|first_api_level)|"
    r"ro\.build\.fingerprint|ro\.vendor\.build\.fingerprint|keyguard\.no_require_sim|"
    r"ro\.com\.android\.dataroaming|ro\.carrier|persist\.data|ro\.config\.(ims|volte)|"
    r"ro\.debuggable|ro\.treble\.enabled)")
PROP_CONTEXT = re.compile(r"^(ro\.build\.|ro\.vendor\.build\.|ro\.product\.first_api_level|ro\.debuggable)")
OVERLAY_RES = re.compile(r"(config_telephony|config_mobile|config_.*[Ii]ms|config_.*[Dd]ata|"
                         r"config_.*[Cc]arrier|config_.*[Ss]im|config_.*[Rr]adio|config_.*[Nn]etwork)")

def root(label, part): return os.path.join(WORK, label, part)

def sha256(path):
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""): h.update(chunk)
        return h.hexdigest()
    except OSError:
        return "-"

NESTED = {"product", "system_ext", "vendor", "odm"}
def walk_files(base, exts=None, prune_nested=False):
    """prune_nested: when walking a system root, skip nested partitions (GSI system/product etc.),
    which are scanned under their own partition name."""
    if not os.path.isdir(base): return
    for dp, dns, fns in os.walk(base, followlinks=True):
        if prune_nested and os.path.normpath(dp) == os.path.normpath(base):
            dns[:] = [d for d in dns if d not in NESTED]
        for fn in fns:
            if exts is None or fn.endswith(exts): yield os.path.join(dp, fn)

def parse_xml(path):
    try: return ET.parse(path).getroot()
    except Exception: return None

AAPT = shutil.which("aapt2") or shutil.which("aapt")
def apk_package(path):
    if not AAPT: return "-"
    try:
        out = subprocess.run([AAPT, "dump", "badging", path], capture_output=True, text=True, timeout=60).stdout
        m = re.search(r"package: name='([^']+)'", out)
        return m.group(1) if m else "-"
    except Exception:
        return "-"

def overlay_values(path):
    if not shutil.which("aapt2"): return []
    try:
        out = subprocess.run(["aapt2", "dump", "resources", path], capture_output=True, text=True, timeout=120).stdout
    except Exception:
        return []
    vals, cur = [], None
    for line in out.splitlines():
        m = re.search(r"resource 0x[0-9a-f]+ \S+/(\S+)", line)
        if m:
            cur = m.group(1) if OVERLAY_RES.search(m.group(1)) else None
            continue
        if cur and line.strip().startswith("("):
            vals.append((cur, line.strip()[:300])); cur = None
    return vals

# ----------------------------------------------------------- image inventory
def inventory(label):
    inv = defaultdict(dict)   # category -> key -> {"part":..., "value":..., "tel":bool}
    def add(cat, key, part, value="present", tel=None):
        if tel is None: tel = bool(TEL.search(key)) or bool(TEL.search(str(value)))
        inv[cat][key] = {"part": part, "value": value, "tel": tel}

    for part in PARTS:
        r = root(label, part)
        if not os.path.isdir(r): continue
        side = "vendor" if part in VENDOR_SIDE else "system"
        # apps / priv-apps / overlays / apex. Keyed without partition so a move between
        # system/product is not reported as missing+added; app vs priv-app is kept in the key
        # because losing privileged status matters for telephony.
        for sub in ("app", "priv-app", "overlay"):
            for apk in walk_files(os.path.join(r, sub), (".apk",)):
                name = os.path.splitext(os.path.basename(apk))[0]
                pkg = apk_package(apk)
                add("app", f"{sub}/{name}", part,
                    f"{part} pkg={pkg} sha256={sha256(apk)[:16]}",
                    tel=bool(TEL.search(name) or TEL.search(pkg)))
                if sub == "overlay":
                    for res, val in overlay_values(apk):
                        add("overlay_config", f"{name}:{res}", part, val, tel=True)
        for apex in walk_files(os.path.join(r, "apex")):
            if apex.endswith((".apex", ".capex")):
                add("apex", os.path.basename(apex), part, part)
        # framework jars
        for jar in walk_files(os.path.join(r, "framework"), (".jar",)):
            add("framework_jar", os.path.basename(jar), part, f"{part} {sha256(jar)[:16]}")
        # features + privapp permissions + sysconfig
        for d in ("etc/permissions", "etc/sysconfig"):
            for x in walk_files(os.path.join(r, d), (".xml",)):
                rt = parse_xml(x)
                if rt is None: continue
                for el in rt.iter():
                    tag = el.tag
                    if tag in ("feature", "unavailable-feature"):
                        n = el.get("name", "")
                        add("feature", f"{tag}:{n}", part, os.path.basename(x),
                            tel=bool(re.search(r"telephony|euicc|ims|radio|5g|nr", n, re.I)))
                    elif tag == "privapp-permissions":
                        pkg = el.get("package", "")
                        for p in el:
                            kind = "deny" if p.tag == "deny-permission" else "grant"
                            add("privapp_permission", f"{pkg}|{kind}|{p.get('name','')}", part,
                                os.path.basename(x), tel=bool(TEL.search(pkg)))
                    elif tag in ("allow-in-power-save", "allow-in-data-usage-save",
                                 "system-user-whitelisted-app", "hidden-api-whitelisted-app"):
                        pkg = el.get("package", "")
                        add("sysconfig", f"{tag}:{pkg}", part, os.path.basename(x))
        # build props
        for pf in ("build.prop", "etc/build.prop", "default.prop", "prop.default", "etc/prop.default",
                   "odm/etc/build.prop"):
            p = os.path.join(r, pf)
            if not os.path.isfile(p): continue
            with open(p, errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line: continue
                    k, v = line.split("=", 1)
                    if PROP_KEEP.match(k):
                        # Build identity always differs on a GSI: keep for context, not as a finding.
                        add("property", k, part, v, tel=not PROP_CONTEXT.match(k))
        # init services
        for rc in walk_files(os.path.join(r, "etc/init"), (".rc",)):
            with open(rc, errors="replace") as f:
                lines = f.read().splitlines()
            for i, line in enumerate(lines):
                m = re.match(r"\s*service\s+(\S+)\s+(\S+)", line)
                if not m: continue
                opts = []
                for nxt in lines[i + 1:i + 12]:
                    if re.match(r"\s*(service|on)\s", nxt): break
                    s = nxt.strip()
                    if re.match(r"(class|user|group|disabled|oneshot|interface)\b", s): opts.append(s)
                add("init_service", m.group(1), part,
                    f"{m.group(2)} [{'; '.join(opts)}] ({os.path.basename(rc)})",
                    tel=bool(TEL.search(m.group(1)) or TEL.search(m.group(2))))
        # VINTF: manifests and compatibility matrices
        vdir = os.path.join(r, "etc/vintf")
        for x in walk_files(vdir, (".xml",)):
            rt = parse_xml(x)
            if rt is None: continue
            kind = "matrix" if rt.tag == "compatibility-matrix" else "manifest"
            for hal in rt.findall("hal"):
                name = (hal.findtext("name") or "").strip()
                vers = sorted({(v.text or "").strip() for v in hal.findall("version")}) or ["-"]
                fq = sorted({(v.text or "").strip() for v in hal.findall("fqname")})
                inst = sorted({(i.text or "").strip() for i in hal.iter("instance")})
                optional = hal.get("optional", "")
                add(f"vintf_{kind}", f"{side}:{name}", part,
                    f"fmt={hal.get('format','hidl')} ver={','.join(vers)} fq={','.join(fq)} "
                    f"inst={','.join(inst)}{' optional='+optional if optional else ''}",
                    tel=bool(re.search(r"radio|ims|ril|telephony|mtkradio|mediatek.*(ims|radio)|"
                                       r"secure_element|data|sim|modem", name, re.I)))
        # SELinux versions / mapping
        sel = os.path.join(r, "etc/selinux")
        if os.path.isdir(sel):
            for fn in sorted(os.listdir(sel)):
                p = os.path.join(sel, fn)
                if os.path.isfile(p):
                    is_ver = fn.endswith(("vers.txt", ".sha256"))
                    val = open(p, errors="replace").read().strip()[:80] if is_ver else sha256(p)[:16]
                    # Policy hashes always differ between a GSI and stock; only versions are signal.
                    add("selinux", f"{part}:{fn}", part, val, tel=is_ver)
            mp = os.path.join(sel, "mapping")
            if os.path.isdir(mp):
                for fn in sorted(os.listdir(mp)):
                    add("selinux_mapping", f"{part}:mapping/{fn}", part, "present", tel=True)
        # APN and carrier config (keyed by file name so a system<->product move is not a diff)
        for x in walk_files(r, prune_nested=(part == "system")):
            b = os.path.basename(x)
            if re.match(r"apns-conf.*\.xml$", b):
                add("apn_file", b, part, f"{part}:{os.path.relpath(x, r)} {sha256(x)[:16]}", tel=True)
                rt = parse_xml(x)
                if rt is not None:
                    apns = rt.findall("apn")
                    add("apn_count", b, part, str(len(apns)), tel=True)
                    for a in apns:
                        mm = (a.get("mcc", "") + a.get("mnc", ""))
                        if mm in MCCMNC:
                            key = f"{mm}|{a.get('apn','')}|{a.get('type','')}"
                            add("apn_sim", key, part,
                                " ".join(f"{k}={a.get(k)}" for k in
                                         ("carrier", "protocol", "roaming_protocol", "mmsc", "mmsproxy",
                                          "mmsport", "network_type_bitmask", "carrier_enabled") if a.get(k)),
                                tel=True)
            elif re.search(r"carrier_?config", x, re.I) and b.endswith(".xml"):
                add("carrier_config_file", f"{part}:{os.path.relpath(x, r)}", part, sha256(x)[:16], tel=True)
    return inv

# ---------------------------------------------------------- source inventory
def source_modules(src):
    """Module names defined in a source tree: used only to say where a module could come from."""
    names = set()
    subdirs = ["packages", "frameworks/opt/telephony", "frameworks/base/telephony", "vendor", "device",
               "hardware", "external", "system"]
    for sd in subdirs:
        base = os.path.join(src, sd)
        for f in walk_files(base, ("Android.bp", "Android.mk")):
            if "/out/" in f or "/.repo/" in f: continue
            try: txt = open(f, errors="replace").read()
            except OSError: continue
            names.update(re.findall(r'\bname:\s*"([^"]+)"', txt))
            names.update(re.findall(r"LOCAL_(?:PACKAGE_NAME|MODULE)\s*:?=\s*(\S+)", txt))
    return names

# ------------------------------------------------------------------ collect
invs, srcmods = {}, {}
for l in LABELS:
    if MODE[l] == "image":
        invs[l] = inventory(l)
    else:
        srcmods[l] = source_modules(SRC[l])

for l, inv in invs.items():
    d = os.path.join(OUT, "inventory", l); os.makedirs(d, exist_ok=True)
    for cat, items in inv.items():
        with open(os.path.join(d, f"{cat}.tsv"), "w") as f:
            f.write("key\tpartition\ttelephony\tvalue\n")
            for k in sorted(items):
                it = items[k]; f.write(f"{k}\t{it['part']}\t{int(it['tel'])}\t{it['value']}\n")
for l, mods in srcmods.items():
    d = os.path.join(OUT, "inventory", l); os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "source_modules.txt"), "w") as f: f.write("\n".join(sorted(mods)) + "\n")

# ------------------------------------------------------------------ compare
def item_name(cat, key):
    """Best-effort module name for candidate-source lookup."""
    if cat == "app": return key.rsplit("/", 1)[-1]
    if cat == "framework_jar": return key.split(":", 1)[-1].rsplit(".", 1)[0]
    if cat == "init_service": return key
    return key

def candidates(cat, key):
    out = []
    name = item_name(cat, key)
    for l in ("restless", "aosp"):
        if l in invs:
            if key in invs[l].get(cat, {}): out.append(l)
        elif l in srcmods and name in srcmods[l]:
            out.append(f"{l}(src)")
    return ",".join(out) or "-"

VALUE_CATS = {"property", "overlay_config", "vintf_manifest", "vintf_matrix", "selinux",
              "apn_count", "apn_sim", "init_service", "privapp_permission"}
findings = []
S, A, B = invs["stock"], invs["n1b1"], invs["n1b2"]
cats = sorted(set(S) | set(A) | set(B))
for cat in cats:
    s, a, b = S.get(cat, {}), A.get(cat, {}), B.get(cat, {})
    for key in sorted(set(s) | set(a) | set(b)):
        ins, ina, inb = key in s, key in a, key in b
        ref = s.get(key) or a.get(key) or b.get(key)
        tel, part = ref["tel"], ref["part"]
        side = "vendor" if part in VENDOR_SIDE else "system"
        sv = s.get(key, {}).get("value", "ABSENT"); av = a.get(key, {}).get("value", "ABSENT"); bv = b.get(key, {}).get("value", "ABSENT")
        cls = None
        if ins and not ina and not inb:                          cls = ("P1", "STOCK_ONLY_MISSING_IN_BOTH_N1")
        elif not ins and ina and inb:                            cls = ("P2", "N1_ONLY_ADDED_IN_BOTH")
        elif ins and ina and inb and cat in VALUE_CATS and sv != av and sv != bv and av == bv:
                                                                 cls = ("P1", "VALUE_DIFFERS_FROM_STOCK_IN_BOTH_N1")
        elif ins and (ina != inb):                               cls = ("P2", "MISSING_IN_ONE_N1_ONLY")
        elif ins and ina and inb and cat in VALUE_CATS and (sv != av or sv != bv):
                                                                 cls = ("P2", "VALUE_DIFFERS_IN_ONE_N1")
        elif not ins and (ina != inb):                           cls = ("P3", "N1B1_N1B2_DIFFER_NOT_IN_STOCK")
        if not cls: continue
        # System-side stock-only items are expected on a GSI (different framework); demote non-telephony.
        prio = cls[0]
        if not tel: prio = "P3"
        findings.append({"prio": prio, "class": cls[1], "category": cat, "key": key, "side": side,
                         "telephony": tel, "stock": sv, "n1b1": av, "n1b2": bv,
                         "candidate_source": candidates(cat, key) if cls[1] in ("STOCK_ONLY_MISSING_IN_BOTH_N1", "MISSING_IN_ONE_N1_ONLY") else "-"})

# Interface checks specific to GSI-on-stock-vendor.
checks = []
def chk(key, status, detail): checks.append((key, status, detail))

def vendor_hals(inv):  return {k.split(":", 1)[1]: v["value"] for k, v in inv.get("vintf_manifest", {}).items() if k.startswith("vendor:")}
def system_matrix(inv): return {k.split(":", 1)[1]: v["value"] for k, v in inv.get("vintf_matrix", {}).items() if k.startswith("system:")}

for l in ("n1b1", "n1b2"):
    inv = invs[l]
    vh, sm = vendor_hals(inv), system_matrix(inv)
    radio_vendor = sorted(k for k in vh if re.search(r"radio|ims", k, re.I))
    radio_matrix = sorted(k for k in sm if re.search(r"android\.hardware\.radio", k))
    not_provided = [k for k in radio_matrix if k not in vh]
    required = [k for k in not_provided if "optional=false" in sm[k]]
    unknown = [k for k in radio_vendor if k.startswith("android.hardware.radio") and k not in sm]
    chk(f"{l.upper()}_RADIO_HALS_FROM_VENDOR", "INFO", " ".join(radio_vendor) or "none found")
    chk(f"{l.upper()}_RADIO_HALS_REQUIRED_NOT_PROVIDED", "FAIL" if required else "PASS", " ".join(required) or "-")
    chk(f"{l.upper()}_RADIO_HALS_IN_MATRIX_NOT_PROVIDED", "INFO", " ".join(not_provided) or "-")
    chk(f"{l.upper()}_RADIO_HALS_PROVIDED_NOT_IN_FRAMEWORK_MATRIX", "WARN" if unknown else "PASS", " ".join(unknown) or "-")
    # Version check: vendor radio HAL versions must fall inside framework matrix ranges.
    for k in sorted(set(vh) & set(sm)):
        if not re.search(r"android\.hardware\.radio", k): continue
        vv = re.search(r"ver=(\S+)", vh[k]); mv = re.search(r"ver=(\S+)", sm[k])
        chk(f"{l.upper()}_RADIO_HAL_VERSION_{k.split('.')[-1].upper()}", "INFO",
            f"{k} vendor={vv.group(1) if vv else '-'} framework_matrix={mv.group(1) if mv else '-'}")
    # SELinux: framework must ship mapping for vendor's plat_sepolicy_vers.
    vers = [v["value"] for k, v in inv.get("selinux", {}).items() if k.startswith("vendor:plat_sepolicy_vers")]
    maps = {k.split("mapping/", 1)[1] for k in inv.get("selinux_mapping", {}) if k.startswith("system:")}
    if vers:
        v = vers[0].strip()
        ok = any(m.startswith(v + ".") or m == v + ".cil" for m in maps)
        chk(f"{l.upper()}_SEPOLICY_MAPPING_FOR_VENDOR_{v.replace('.', '_')}", "PASS" if ok else "FAIL",
            f"vendor plat_sepolicy_vers={v}; system mapping files={','.join(sorted(maps)) or 'none'}")
    else:
        chk(f"{l.upper()}_SEPOLICY_VENDOR_VERSION", "WARN", "vendor plat_sepolicy_vers.txt not found")
    # Telephony features the vendor/stock declares that the N1 system does not.
    sf = {k for k, v in S.get("feature", {}).items() if v["tel"] and k.startswith("feature:")}
    nf = {k for k, v in inv.get("feature", {}).items() if k.startswith("feature:")}
    miss = sorted(sf - nf)
    chk(f"{l.upper()}_TELEPHONY_FEATURES_MISSING_VS_STOCK", "FAIL" if miss else "PASS",
        " ".join(m.split(":", 1)[1] for m in miss) or "-")
    # Vendor IMS/radio apps present on vendor side need matching system-side privapp allowlist.
    vapps = [k for k, v in inv.get("app", {}).items() if v["part"] in VENDOR_SIDE and v["tel"]]
    chk(f"{l.upper()}_VENDOR_TELEPHONY_APPS", "INFO", " ".join(vapps) or "none")
    # Core AOSP telephony components must exist in the system image (as app or apex).
    core = {"TeleService": r"^TeleService", "Telecom": r"^Telecom", "TelephonyProvider": r"^TelephonyProvider",
            "CarrierConfig": r"^CarrierConfig", "CellBroadcast": r"cellbroadcast", "MmsService": r"^MmsService",
            "Stk": r"^Stk"}
    names = {k.rsplit("/", 1)[-1] for k in inv.get("app", {})} | set(inv.get("apex", {}))
    lacking = sorted(c for c, rx in core.items() if not any(re.search(rx, n, re.I) for n in names))
    chk(f"{l.upper()}_CORE_TELEPHONY_APPS_MISSING", "WARN" if lacking else "PASS", " ".join(lacking) or "-")
    # eSIM stack
    has_euicc_feature = any("euicc" in k for k in nf)
    has_euicc_app = any(re.search(r"euicc|lpa", k, re.I) for k in inv.get("app", {}))
    chk(f"{l.upper()}_ESIM_STACK", "PASS" if (has_euicc_feature and has_euicc_app) else "WARN",
        f"feature={'yes' if has_euicc_feature else 'no'} lpa_or_euicc_app={'yes' if has_euicc_app else 'no'}")
    # APN: MMS entries for the test SIM
    if MCCMNC:
        for mm in MCCMNC:
            types = [k.split("|")[2] for k in inv.get("apn_sim", {}) if k.startswith(mm + "|")]
            stypes = [k.split("|")[2] for k in S.get("apn_sim", {}) if k.startswith(mm + "|")]
            has = lambda ts, t: any(t in x.split(",") or x == "*" for x in ts)
            for t in ("default", "mms", "ia", "ims"):
                st = "PASS" if has(types, t) else ("FAIL" if has(stypes, t) else "WARN")
                chk(f"{l.upper()}_APN_{mm}_{t.upper()}", st,
                    f"n1={'yes' if has(types, t) else 'no'} stock={'yes' if has(stypes, t) else 'no'}")

# vendor identity: did any n1 ship its own vendor?
for l in ("n1b1", "n1b2"):
    chk(f"{l.upper()}_VENDOR_SOURCE", "INFO", VSRC[l])

# ------------------------------------------------------------------ write
findings.sort(key=lambda f: (f["prio"], not f["telephony"], f["category"], f["key"]))
with open(os.path.join(OUT, "findings.tsv"), "w") as f:
    cols = ["prio", "class", "category", "side", "telephony", "key", "stock", "n1b1", "n1b2", "candidate_source"]
    f.write("\t".join(cols) + "\n")
    for x in findings:
        f.write("\t".join(str(x[c]).replace("\t", " ") for c in cols) + "\n")

cnt = defaultdict(int)
for x in findings:
    if x["telephony"]: cnt[x["prio"]] += 1
fails = [c for c in checks if c[1] == "FAIL"]
warns = [c for c in checks if c[1] == "WARN"]

with open(os.path.join(OUT, "N1B2_CELLULAR_STATIC_SUMMARY.env"), "w") as f:
    f.write(f"N1B2_CELLULAR_STATIC_AUDIT=COMPLETE\nAUDIT_SCRIPT_VERSION={VERSION}\n")
    f.write("READ_ONLY=YES\nDEVICE_CONTACT=NO\nIMAGE_BUILD=NO\nFLASH=NO\n")
    for l in LABELS:
        f.write(f"INPUT_{l.upper()}_MODE={MODE[l]}\n")
    for l in ("n1b1", "n1b2"):
        f.write(f"INPUT_{l.upper()}_VENDOR={VSRC[l]}\n")
    f.write(f"TELEPHONY_FINDINGS_P1={cnt['P1']}\nTELEPHONY_FINDINGS_P2={cnt['P2']}\nTELEPHONY_FINDINGS_P3={cnt['P3']}\n")
    f.write(f"INTERFACE_CHECKS_FAIL={len(fails)}\nINTERFACE_CHECKS_WARN={len(warns)}\n")
    for k, st, _ in checks: f.write(f"{k}={st}\n")
    f.write("ROOT_CAUSE_CONCLUDED=NO\nRUNTIME_EVIDENCE_REQUIRED=YES\n")

def md_table(rows, cols):
    out = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for r in rows:
        out.append("| " + " | ".join(str(v).replace("|", "\\|")[:160] for v in r) + " |")
    return "\n".join(out)

tel = [x for x in findings if x["telephony"]]
with open(os.path.join(OUT, "N1B2_CELLULAR_STATIC_REPORT.md"), "w") as f:
    f.write("# N1B2 cellular static composition audit\n\n")
    f.write(f"Generated by `{os.path.basename(sys.argv[0]) if sys.argv[0] != '-' else 'audit-n1b2-cellular-stack.sh'}` v{VERSION}. "
            "Read-only; no device contact; no build; no flash.\n\n")
    f.write("## Inputs\n\n")
    f.write(md_table([(l, MODE[l], VSRC.get(l, "own"), SRC[l]) for l in LABELS],
                     ["label", "mode", "vendor", "path"]) + "\n\n")
    f.write("Stock is the known-good reference. N1B1 and N1B2 both connect and then disconnect. "
            "Items present in stock but absent or different in **both** N1 images are priority 1.\n\n"
            "System-side differences between a GSI and the stock framework are expected in volume; "
            "a P1 system-side item is a *candidate*, not a confirmed cause. Interface checks below "
            "are the higher-signal items for a GSI running on stock vendor.\n\n")
    f.write("## Interface checks (GSI system ↔ stock vendor)\n\n")
    f.write(md_table(checks, ["check", "status", "detail"]) + "\n\n")
    f.write("## Telephony findings summary\n\n")
    f.write(md_table([(p, cnt[p]) for p in ("P1", "P2", "P3")], ["priority", "count"]) + "\n\n")
    for p, title in (("P1", "Priority 1 — stock has it, both N1 images lack it or differ"),
                     ("P2", "Priority 2 — added by N1, or differs in only one N1 image")):
        rows = [x for x in tel if x["prio"] == p]
        f.write(f"## {title}\n\n")
        if not rows:
            f.write("None.\n\n"); continue
        for side in ("vendor", "system"):
            sr = [x for x in rows if x["side"] == side]
            if not sr: continue
            f.write(f"### {side} side ({len(sr)})\n\n")
            f.write(md_table([(x["category"], x["key"], x["class"], x["stock"], x["n1b1"], x["n1b2"], x["candidate_source"])
                              for x in sr[:150]],
                             ["category", "key", "class", "stock", "n1b1", "n1b2", "candidate source"]) + "\n\n")
            if len(sr) > 150: f.write(f"_{len(sr) - 150} more in findings.tsv._\n\n")
    f.write("## Next step\n\n"
            "Correlate these findings with the runtime capture (`capture-n1b2-cellular-runtime.sh`) "
            "around the disconnect timestamp before choosing AOSP, RestlessOS or stock modules. "
            "This report does not conclude a root cause.\n")
print(os.path.join(OUT, "N1B2_CELLULAR_STATIC_REPORT.md"))
PYEOF

AUDIT_OK=1
if [[ "$CLEAN_WORK" -eq 1 ]]; then
  log "removing extracted trees"
  # rm -rf unlinks symlinks to inputs without following them.
  rm -rf "$WORK"
fi

log "done: $OUT"
echo "SUMMARY=$OUT/N1B2_CELLULAR_STATIC_SUMMARY.env"
echo "REPORT=$OUT/N1B2_CELLULAR_STATIC_REPORT.md"
