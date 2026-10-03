#!/usr/bin/env bash
# SableOS Titan 2 N1I-A — V01.00.14 OEM IMS dependency-closure audit.
#
# Determines, from the exact retained stock V01.00.14 (TEE14) partition images,
# the minimum OEM MediaTek IMS payload a Titan-specific SableOS system image would
# have to supply if the GSI-native IMS path proves insufficient.
#
# CONTRACT
#   OFFLINE_ONLY=YES  DEVICE_CONTACT=NO  BUILD=NO  FLASH=NO
#   SOURCE_MUTATION_OUTSIDE_REPORT_OUTPUT=NO  STOCK_BLOB_IMPORT_TO_GIT=NO
#   - Input images are only read (sha256sum, debugfs without -w, fsck.erofs --extract).
#   - Everything is written under --out, which must be outside the git repository.
#   - adb and fastboot are shadowed by functions that abort the run.
#   - Nothing is copied into the repository; the run fails if the repo gains changes.
#
# INPUTS
#   --stock-ref-dir DIR   V01.00.14 TEE14 reference directory with product.img,
#                         system_ext.img, vendor.img (pinned SHA-256 below). If omitted,
#                         resolved from the repository's configured STOCK_REF_DIR values;
#                         exactly one existing (by realpath) candidate is required.
#   --stock-system IMG    Stock V01.00.14 system.img. Default: <stock-ref-dir>/system.img.
#                         Required for bootclasspath membership, the stock platform
#                         certificate and MTK framework-modification detection.
#                         Its SHA-256 is recorded (not pinned in the repository).
#   --c3a-system IMG      C3A system.img (pinned SHA-256 below). Required for
#                         "already present in C3A" classification.
#   --out DIR             Output directory outside the repo.
#                         Default: /srv/sable-build/evidence/titan2/n1i-a-oem-ims/<UTC>
#   --tools-dir DIR       Prefer aapt2/apksigner from here (e.g. out/host/linux-x86/bin).
#   --expected-sha256-file FILE
#                         Replace the built-in pins ('<sha256>  <name>' lines). Used only by
#                         fixtures; forces N1I_A_V010014_STOCK_SOURCE=FAIL_NONCANONICAL_PINS.
#
# OUTPUT (under --out)
#   N1I_A_V010014_OEM_IMS_REPORT.md    findings + final 8-part dependency table
#   n1i-a-v010014-oem-ims.env          KEY=VALUE results and acceptance markers
#   *.tsv                              per-scope inventories
#   work/                              extracted partitions (removed with --clean-work)
#
# Exit: 0 all acceptance markers PASS; 1 any marker not PASS; 2 usage; 3 tool; 4 input.

set -euo pipefail

adb()      { echo "N1I_A_NO_DEVICE_CONTACT=FAIL adb invoked" >&2; exit 1; }
fastboot() { echo "N1I_A_NO_DEVICE_CONTACT=FAIL fastboot invoked" >&2; exit 1; }
export -f adb fastboot

die() { echo "N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=FAIL $1" >&2; exit "${2:-4}"; }

# Pinned canonical inputs (docs/titan2/SABLEOS_N1C_HYBRID_SUPER_CHECKPOINT.md and
# docs/titan2/N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md / C3A baseline).
PINS_BUILTIN='de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37  product.img
1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170  system_ext.img
cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada  vendor.img
4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16  c3a-system.img'

STOCK_REF_DIR="" STOCK_SYSTEM="" C3A_SYSTEM="" OUT="" TOOLS_DIR="" PIN_FILE="" CLEAN_WORK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stock-ref-dir) STOCK_REF_DIR=$2; shift 2 ;;
    --stock-system) STOCK_SYSTEM=$2; shift 2 ;;
    --c3a-system) C3A_SYSTEM=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --tools-dir) TOOLS_DIR=$2; shift 2 ;;
    --expected-sha256-file) PIN_FILE=$2; shift 2 ;;
    --clean-work) CLEAN_WORK=1; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

REPO=$(cd "$(dirname "$0")/../.." && pwd)
[[ -n "$TOOLS_DIR" ]] && export PATH="$TOOLS_DIR:$PATH"
for t in python3 sha256sum aapt2 debugfs fsck.erofs simg2img openssl; do
  command -v "$t" >/dev/null || die "required tool missing: $t" 3
done
command -v apksigner >/dev/null || echo "note: apksigner not found; v1 (META-INF) certificate fallback only" >&2

# ---- stock source resolution -----------------------------------------------------
if [[ -z "$STOCK_REF_DIR" ]]; then
  mapfile -t cands < <(grep -rhoE 'STOCK_REF_DIR[:=]*"?(/srv/[^"}[:space:]]+TEE14-large-reference)' \
      "$REPO/build/titan2" 2>/dev/null | sed -E 's/.*(\/srv\/.*)/\1/' | sort -u)
  declare -A seen=()
  for c in "${cands[@]}"; do [[ -d "$c" ]] && seen["$(realpath "$c")"]=$c; done
  [[ ${#seen[@]} -eq 1 ]] || die "cannot resolve a unique existing STOCK_REF_DIR from repo config (candidates: ${cands[*]:-none}; existing: ${!seen[*]:-none}); pass --stock-ref-dir" 4
  STOCK_REF_DIR=${!seen[*]}
fi
STOCK_REF_DIR=$(realpath "$STOCK_REF_DIR")
[[ -n "$STOCK_SYSTEM" ]] || STOCK_SYSTEM="$STOCK_REF_DIR/system.img"
[[ -n "$C3A_SYSTEM" ]] || die "--c3a-system is required (C3A system.img, sha256 4c292b98...)" 2
for f in "$STOCK_REF_DIR/product.img" "$STOCK_REF_DIR/system_ext.img" "$STOCK_REF_DIR/vendor.img" "$C3A_SYSTEM"; do
  [[ -f "$f" ]] || die "missing input $f" 4
done

[[ -n "$OUT" ]] || OUT="/srv/sable-build/evidence/titan2/n1i-a-oem-ims/$(date -u +%Y%m%dT%H%M%SZ)"
OUT=$(realpath -m "$OUT")
case "$OUT/" in "$REPO"/*) die "--out must be outside the repository ($REPO)" 2 ;; esac
mkdir -p "$OUT" || die "cannot create $OUT" 4
WORK="$OUT/work"; mkdir -p "$WORK"
REPO_STATUS_BEFORE=$(git -C "$REPO" status --porcelain 2>/dev/null || echo NO_GIT)

# ---- pins ------------------------------------------------------------------------
PINS_SRC=builtin
if [[ -n "$PIN_FILE" ]]; then PINS=$(cat "$PIN_FILE"); PINS_SRC=override; else PINS=$PINS_BUILTIN; fi
pin_of() { awk -v n="$1" '$2==n{print $1}' <<<"$PINS"; }
: > "$OUT/inputs.tsv"; printf 'input\tpath\tsha256\tpinned\tmatch\n' > "$OUT/inputs.tsv"
STOCK_SOURCE=PASS
hash_input() { # name path required_pin(1/0)
  local name=$1 p=$2 want got m
  got=$(sha256sum "$p" | cut -d' ' -f1); want=$(pin_of "$name")
  if [[ -n "$want" ]]; then [[ "$got" == "$want" ]] && m=YES || { m=NO; STOCK_SOURCE=FAIL_SHA256_MISMATCH; }
  else m=UNPINNED; [[ "$3" == 1 ]] && STOCK_SOURCE=FAIL_UNPINNED; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$p" "$got" "${want:--}" "$m" >> "$OUT/inputs.tsv"
}
hash_input product.img "$STOCK_REF_DIR/product.img" 1
hash_input system_ext.img "$STOCK_REF_DIR/system_ext.img" 1
hash_input vendor.img "$STOCK_REF_DIR/vendor.img" 1
hash_input c3a-system.img "$C3A_SYSTEM" 1
HAVE_STOCK_SYSTEM=0
if [[ -f "$STOCK_SYSTEM" ]]; then hash_input stock-system.img "$STOCK_SYSTEM" 0; HAVE_STOCK_SYSTEM=1; fi
for o in odm.img; do [[ -f "$STOCK_REF_DIR/$o" ]] && hash_input "$o" "$STOCK_REF_DIR/$o" 0; done
[[ "$PINS_SRC" == override && "$STOCK_SOURCE" == PASS ]] && STOCK_SOURCE=FAIL_NONCANONICAL_PINS

# ---- read-only extraction ----------------------------------------------------------
hexat() { od -An -tx1 -j "$2" -N "$3" "$1" 2>/dev/null | tr -d ' \n'; }
image_type() {
  if [[ "$(hexat "$1" 0 4)" == "3aff26ed" ]]; then echo sparse
  elif [[ "$(hexat "$1" 1080 2)" == "53ef" ]]; then echo ext4
  elif [[ "$(hexat "$1" 1024 4)" == "e2e1f5e0" ]]; then echo erofs
  else echo unknown; fi
}
extract_fs() {
  local img=$1 dest=$2 t log
  t=$(image_type "$img"); mkdir -p "$dest"
  case "$t" in
    sparse) simg2img "$img" "$dest.raw.img" >/dev/null || die "simg2img failed: $img"
            extract_fs "$dest.raw.img" "$dest"; rm -f "$dest.raw.img"; return ;;
    ext4)   log="$dest.debugfs.log"; debugfs -R "rdump / $dest" "$img" >/dev/null 2>"$log" || die "debugfs failed: $img" ;;
    erofs)  log="$dest.erofs.log"; fsck.erofs --extract="$dest" "$img" >/dev/null 2>"$log" || die "fsck.erofs failed: $img" ;;
    *) die "unsupported image type for $img" ;;
  esac
  if grep -qiE 'while trying to open|filesystem not open|bad magic|corrupt|short read|cannot open|not a valid|i/o error|error:' "$log" 2>/dev/null; then
    die "extraction of $img reported errors (see $log)"
  fi
  [[ -n "$(find "$dest" -mindepth 1 -print -quit)" ]] || die "extraction of $img produced no files"
}
extract_fs "$STOCK_REF_DIR/product.img" "$WORK/stock/product"
extract_fs "$STOCK_REF_DIR/system_ext.img" "$WORK/stock/system_ext"
extract_fs "$STOCK_REF_DIR/vendor.img" "$WORK/stock/vendor"
[[ -f "$STOCK_REF_DIR/odm.img" ]] && extract_fs "$STOCK_REF_DIR/odm.img" "$WORK/stock/odm"
[[ $HAVE_STOCK_SYSTEM == 1 ]] && extract_fs "$STOCK_SYSTEM" "$WORK/stock/system_img"
extract_fs "$C3A_SYSTEM" "$WORK/c3a/system_img"

# ---- analysis ----------------------------------------------------------------------
export OUT WORK STOCK_SOURCE HAVE_STOCK_SYSTEM
set +e
python3 - <<'PYEOF'
import os, re, sys, io, json, struct, zipfile, hashlib, subprocess, xml.etree.ElementTree as ET
OUT, WORK = os.environ["OUT"], os.environ["WORK"]
HAVE_SYS = os.environ["HAVE_STOCK_SYSTEM"] == "1"
MARK = {}
ENV = {}
REPORT = []
def md(s=""): REPORT.append(s)
def tsv(name, header, rows):
    with open(os.path.join(OUT, name), "w") as f:
        f.write("\t".join(header) + "\n")
        for r in rows: f.write("\t".join(str(x) for x in r) + "\n")
def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""): h.update(c)
    return h.hexdigest()
def run(*a):
    r = subprocess.run(list(a), capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr

# ---------- partition roots ----------
def sysroot(tree):
    return os.path.join(tree, "system") if os.path.isfile(os.path.join(tree, "system", "build.prop")) else tree
S = {}
S["system_ext"] = f"{WORK}/stock/system_ext"; S["product"] = f"{WORK}/stock/product"; S["vendor"] = f"{WORK}/stock/vendor"
if os.path.isdir(f"{WORK}/stock/odm"): S["odm"] = f"{WORK}/stock/odm"
elif os.path.isdir(f"{WORK}/stock/vendor/odm"): S["odm"] = f"{WORK}/stock/vendor/odm"
if HAVE_SYS: S["system"] = sysroot(f"{WORK}/stock/system_img")
c3a_sys = sysroot(f"{WORK}/c3a/system_img")
C = {"system": c3a_sys, "system_ext": os.path.join(c3a_sys, "system_ext"), "product": os.path.join(c3a_sys, "product")}
SYSTEM_SIDE = ("system", "system_ext", "product")
VENDOR_SIDE = ("vendor", "odm")
def files(root):
    for dp, dn, fn in os.walk(root):
        for f in fn:
            p = os.path.join(dp, f)
            if not os.path.islink(p): yield p
def devpath(part, p): return f"/{part}/" + os.path.relpath(p, S[part])
INDEX = {part: list(files(root)) for part, root in S.items()}
KW = re.compile(r"mtkims|imsservice|com\.mediatek\.ims|mediatek.*ims|volte|wfc|epdg|mmtel|mtkradioex|imcb|clientapi", re.I)

# ---------- dex ----------
def uleb(d, o):
    r = s = 0
    while True:
        b = d[o]; o += 1; r |= (b & 0x7f) << s; s += 7
        if b < 0x80: return r, o
def parse_dex(d):
    if d[:4] != b"dex\n": return None
    sz, so = struct.unpack_from("<II", d, 0x38); tz, to = struct.unpack_from("<II", d, 0x40)
    cz, co = struct.unpack_from("<II", d, 0x60)
    strs = []
    for i in range(sz):
        off = struct.unpack_from("<I", d, so + 4 * i)[0]; _, o = uleb(d, off); e = d.index(b"\0", o)
        strs.append(d[o:e].decode("utf-8", "replace"))
    types = [strs[struct.unpack_from("<I", d, to + 4 * i)[0]] for i in range(tz)]
    defined = [types[struct.unpack_from("<I", d, co + 32 * i)[0]] for i in range(cz)]
    return {"strings": strs, "types": types, "defined": defined}
def dexes_of(path):
    """dex images of an APK/JAR; falls back to an oat/<arch>/<name>.vdex next to it."""
    out, note = [], ""
    try:
        with zipfile.ZipFile(path) as z:
            for n in sorted(z.namelist()):
                if re.fullmatch(r"classes\d*\.dex", n): out.append(z.read(n))
    except zipfile.BadZipFile:
        return [], "BAD_ZIP"
    if not out:
        base = os.path.splitext(os.path.basename(path))[0]; d = os.path.dirname(path)
        for arch in ("arm64", "arm"):
            v = os.path.join(d, "oat", arch, base + ".vdex")
            if os.path.isfile(v):
                data = open(v, "rb").read()
                for m in re.finditer(rb"dex\n0[0-9]{2}\0", data):
                    size = struct.unpack_from("<I", data, m.start() + 0x20)[0]
                    out.append(data[m.start():m.start() + size])
                note = "FROM_VDEX" if out else ("CDEX_UNPARSED" if b"cdex" in data else "VDEX_EMPTY")
                break
        if not out and not note: note = "NO_DEX"
    return out, note
def dexinfo(path):
    imgs, note = dexes_of(path); info = {"strings": set(), "types": set(), "defined": set(), "note": note, "ndex": len(imgs)}
    for d in imgs:
        try:
            r = parse_dex(d)
        except Exception as ex:
            info["note"] = f"DEX_PARSE_ERROR:{ex}"; continue
        if r:
            info["strings"].update(r["strings"]); info["types"].update(r["types"]); info["defined"].update(r["defined"])
    return info

# ---------- aapt2 / manifest ----------
def badging(apk):
    rc, o, e = run("aapt2", "dump", "badging", apk)
    return o if rc == 0 else ""
def xmltree(apk):
    for args in (["aapt2", "dump", "xmltree", "--file", "AndroidManifest.xml", apk], ["aapt2", "dump", "xmltree", apk, "--file", "AndroidManifest.xml"]):
        rc, o, e = run(*args)
        if rc == 0 and "E: manifest" in o: return o
    return ""
def parse_tree(txt):
    root = {"tag": "#root", "attrs": {}, "kids": []}; stack = [(-1, root)]
    for line in txt.splitlines():
        ind = len(line) - len(line.lstrip()); s = line.strip()
        if s.startswith("E: "):
            node = {"tag": s[3:].split(" (")[0], "attrs": {}, "kids": []}
            while stack[-1][0] >= ind: stack.pop()
            stack[-1][1]["kids"].append(node); stack.append((ind, node))
        elif s.startswith("A: "):
            m = re.match(r"A: (?:[^=]*:)?([A-Za-z_]+)(?:\(0x[0-9a-f]+\))?=(.*)$", s)
            if m:
                k, v = m.group(1), m.group(2)
                mm = re.match(r'"(.*?)"', v)
                if mm: v = mm.group(1)
                elif "0xffffffff" in v: v = "true"
                elif re.search(r"\(type 0x12\)0x0\b", v): v = "false"
                stack[-1][1]["attrs"][k] = v
    return root
def walk(n):
    yield n
    for k in n["kids"]: yield from walk(k)
def manifest(apk):
    t = parse_tree(xmltree(apk)); man = next((n for n in walk(t) if n["tag"] == "manifest"), None)
    if not man: return None
    app = next((n for n in man["kids"] if n["tag"] == "application"), {"attrs": {}, "kids": []})
    comps = []
    for c in app["kids"]:
        if c["tag"] in ("service", "receiver", "provider", "activity", "activity-alias"):
            actions = [a["attrs"].get("name", "") for f in c["kids"] if f["tag"] == "intent-filter" for a in f["kids"] if a["tag"] == "action"]
            comps.append({"type": c["tag"], "name": c["attrs"].get("name", ""), "permission": c["attrs"].get("permission", ""),
                          "exported": c["attrs"].get("exported", ""), "process": c["attrs"].get("process", ""),
                          "directBootAware": c["attrs"].get("directBootAware", ""), "actions": actions})
    return {"package": man["attrs"].get("package", ""), "sharedUserId": man["attrs"].get("sharedUserId", ""),
            "versionCode": man["attrs"].get("versionCode", ""), "versionName": man["attrs"].get("versionName", ""),
            "app": app["attrs"], "components": comps,
            "declared_permissions": [n["attrs"].get("name", "") for n in man["kids"] if n["tag"] == "permission"],
            "uses_library": [(n["attrs"].get("name", ""), n["attrs"].get("required", "true")) for n in app["kids"] if n["tag"] in ("uses-library", "uses-static-library")]}
def cert_sha256(apk):
    if subprocess.run(["sh", "-c", "command -v apksigner"], capture_output=True).returncode == 0:
        rc, o, e = run("apksigner", "verify", "--print-certs", apk)
        m = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-f]{64})", o)
        if m: return m.group(1), "apksigner"
    try:
        with zipfile.ZipFile(apk) as z:
            sig = next((n for n in z.namelist() if re.fullmatch(r"META-INF/[^/]+\.(RSA|DSA|EC)", n)), None)
            if sig:
                p = subprocess.run(["openssl", "pkcs7", "-inform", "DER", "-print_certs"], input=z.read(sig), capture_output=True)
                pem = p.stdout.split(b"-----END CERTIFICATE-----")[0] + b"-----END CERTIFICATE-----\n"
                q = subprocess.run(["openssl", "x509", "-noout", "-fingerprint", "-sha256"], input=pem, capture_output=True, text=True)
                m = re.search(r"=([0-9A-F:]+)", q.stdout)
                if m: return m.group(1).replace(":", "").lower(), "v1-META-INF"
    except Exception:
        pass
    return "", "UNKNOWN"

# =================== A1: locate IMS implementation ===================
apks = [(part, p) for part in S for p in INDEX[part] if p.endswith(".apk")]
cand = []
for part, p in apks:
    rel = devpath(part, p)
    pathhit = bool(KW.search(rel))
    m = manifest(p) if pathhit or part in SYSTEM_SIDE or part in VENDOR_SIDE else None
    if not m: continue
    imssvc = [c for c in m["components"] if c["type"] == "service" and ("android.telephony.ims.ImsService" in c["actions"] or c["permission"] == "android.permission.BIND_IMS_SERVICE")]
    if pathhit or imssvc or KW.search(m["package"]):
        role = "IMS_SERVICE_PROVIDER" if imssvc else "IMS_RELATED_OTHER"
        cand.append({"part": part, "path": p, "dev": rel, "m": m, "imssvc": imssvc, "role": role})
providers = [c for c in cand if c["role"] == "IMS_SERVICE_PROVIDER"]
mtk = [c for c in providers if c["m"]["package"] == "com.mediatek.ims"] or providers
primary = mtk[0] if len(mtk) == 1 else None
rows = []
for c in cand:
    b = badging(c["path"])
    c["badging"] = b
    c["sha"] = sha(c["path"])
    rows.append((c["role"], c["m"]["package"], c["m"]["versionName"], c["m"]["versionCode"], c["part"], c["dev"], c["sha"]))
tsv("a1-ims-packages.tsv", ["role", "package", "versionName", "versionCode", "partition", "path", "sha256"], rows)
MARK["N1I_A_OEM_IMS_PACKAGE"] = "PASS" if primary else ("FAIL_AMBIGUOUS" if len(mtk) > 1 else "FAIL_NOT_FOUND")
md("# N1I-A V01.00.14 OEM IMS dependency closure — generated report\n")
md("## A1 OEM IMS implementation\n")
if primary:
    P = primary
    ENV.update(OEM_IMS_PACKAGE_PATH=P["dev"], OEM_IMS_PACKAGE_NAME=P["m"]["package"],
               OEM_IMS_VERSION=f'{P["m"]["versionName"]} ({P["m"]["versionCode"]})', OEM_IMS_PARTITION=P["part"], OEM_IMS_APK_SHA256=P["sha"])
for k in ("OEM_IMS_PACKAGE_PATH", "OEM_IMS_PACKAGE_NAME", "OEM_IMS_VERSION", "OEM_IMS_PARTITION", "OEM_IMS_APK_SHA256"):
    md(f"    {k}={ENV.get(k, 'NOT_FOUND')}")
md("\nAll IMS-related APKs (role per manifest; only IMS_SERVICE_PROVIDER binds as the MMTEL ImsService):\n")
md("| role | package | version | partition | path |\n|---|---|---|---|---|")
for r in rows: md(f"| {r[0]} | {r[1]} | {r[2]} ({r[3]}) | {r[4]} | `{r[5]}` |")

# =================== A2: manifest + signing ===================
md("\n## A2 Manifest and signing identity\n")
def stock_platform_cert():
    for part in ("system",):
        if part in S:
            fr = os.path.join(S[part], "framework", "framework-res.apk")
            if os.path.isfile(fr): return cert_sha256(fr)[0]
    return ""
def c3a_platform_cert():
    fr = os.path.join(C["system"], "framework", "framework-res.apk")
    return cert_sha256(fr)[0] if os.path.isfile(fr) else ""
SPC, CPC = stock_platform_cert(), c3a_platform_cert()
if primary:
    P = primary; m = P["m"]; b = P["badging"]
    cert, how = cert_sha256(P["path"])
    shared = m["sharedUserId"]
    perms_req = sorted(set(re.findall(r"^uses-permission(?:-sdk-23)?: name='([^']+)'", b, re.M)))
    sdk = re.search(r"^sdkVersion:'(\d+)'", b, re.M); tsdk = re.search(r"^targetSdkVersion:'(\d+)'", b, re.M)
    privileged = "/priv-app/" in P["dev"]
    md(f"    package={m['package']} versionCode={m['versionCode']} versionName={m['versionName']}")
    md(f"    minSdk={sdk.group(1) if sdk else '?'} targetSdk={tsdk.group(1) if tsdk else '?'}")
    md(f"    sharedUserId={shared or 'NONE'}  privileged_location={'YES' if privileged else 'NO'}  persistent={m['app'].get('persistent','false')}")
    md(f"    application.directBootAware={m['app'].get('directBootAware','')} defaultToDeviceProtectedStorage={m['app'].get('defaultToDeviceProtectedStorage','')} process={m['app'].get('process','')}")
    md(f"    uses-library={m['uses_library'] or 'NONE'}")
    md(f"    declared_permissions={m['declared_permissions'] or 'NONE'}")
    md(f"    requested_permissions ({len(perms_req)}): " + ", ".join(perms_req))
    md("\n| type | name | permission | process | directBoot | actions |\n|---|---|---|---|---|---|")
    for c in m["components"]:
        md(f"| {c['type']} | {c['name']} | {c['permission']} | {c['process']} | {c['directBootAware']} | {', '.join(c['actions'])} |")
    bind = any(c["permission"] == "android.permission.BIND_IMS_SERVICE" for c in m["components"])
    uidclass = {"android.uid.phone": "android.uid.phone", "android.uid.system": "android.uid.system", "": "no shared UID"}.get(shared, f"another shared UID ({shared})")
    resign = "YES" if shared in ("android.uid.phone", "android.uid.system") else ("UNKNOWN" if (SPC and cert == SPC) or not SPC else "NO")
    if shared and shared not in ("android.uid.phone", "android.uid.system"): resign = "UNKNOWN"
    ENV.update(CERT_SHA256=cert or "UNKNOWN", CERT_SOURCE=how, STOCK_PLATFORM_CERT_SHA256=SPC or "UNKNOWN_NO_STOCK_SYSTEM",
               C3A_PLATFORM_CERT_SHA256=CPC or "UNKNOWN", OEM_IMS_SHARED_UID=uidclass,
               OEM_IMS_SIGNED_WITH_STOCK_PLATFORM_KEY=("YES" if SPC and cert == SPC else ("NO" if SPC else "UNKNOWN")),
               BIND_IMS_SERVICE_USED="YES" if bind else "NO",
               PLATFORM_RESIGN_REQUIRED=resign,
               CAN_USE_STOCK_SIGNATURE_UNCHANGED={"YES": "NO", "NO": "YES"}.get(resign, "UNKNOWN"),
               SHARED_UID_SIGNATURE_RISK="YES" if shared else "NO")
    for k in ("CERT_SHA256", "CERT_SOURCE", "STOCK_PLATFORM_CERT_SHA256", "C3A_PLATFORM_CERT_SHA256", "OEM_IMS_SHARED_UID",
              "OEM_IMS_SIGNED_WITH_STOCK_PLATFORM_KEY", "BIND_IMS_SERVICE_USED", "CAN_USE_STOCK_SIGNATURE_UNCHANGED",
              "PLATFORM_RESIGN_REQUIRED", "SHARED_UID_SIGNATURE_RISK"):
        md(f"    {k}={ENV[k]}")
    MARK["N1I_A_OEM_IMS_SIGNATURE"] = "PASS" if cert else "FAIL_NO_CERT"
else:
    MARK["N1I_A_OEM_IMS_SIGNATURE"] = "FAIL_NO_PACKAGE"

# =================== A3: framework JAR closure ===================
md("\n## A3 Framework JAR dependency closure\n")
libdecl = {}   # library name -> device path, decl file
for part in S:
    for p in INDEX[part]:
        if "/etc/permissions/" in p and p.endswith(".xml"):
            try:
                for lib in ET.parse(p).getroot().iter("library"):
                    libdecl[lib.get("name")] = (lib.get("file", ""), devpath(part, p))
            except ET.ParseError:
                pass
cp = {}  # device jar path -> classpath file(s)
for part in S:
    for p in INDEX[part]:
        if "/etc/classpaths/" in p and p.endswith(".pb"):
            for j in set(re.findall(rb"/[A-Za-z0-9_./-]+\.jar", open(p, "rb").read())):
                cp.setdefault(j.decode(), []).append(os.path.basename(p))
def jars(tree_parts):
    for part, root in tree_parts.items():
        if part in SYSTEM_SIDE and os.path.isdir(root):
            for p in files(root):
                if p.endswith(".jar") and "/framework/" in p: yield part, p
JAR = {}
for part, p in jars(S):
    JAR[f"/{part}/" + os.path.relpath(p, S[part])] = {"part": part, "path": p}
c3a_classes = set()
for part, p in jars(C):
    c3a_classes |= dexinfo(p)["defined"]
def apex_jars(apexdir, tag):
    """javalib jars inside APEX payloads (.apex, or .capex -> original_apex), extracted read-only."""
    out = []
    if not os.path.isdir(apexdir): return out
    for a in sorted(os.listdir(apexdir)):
        if not a.endswith((".apex", ".capex")): continue
        base = os.path.join(WORK, "apex", tag, a); os.makedirs(base, exist_ok=True)
        try:
            z = zipfile.ZipFile(os.path.join(apexdir, a))
            if "original_apex" in z.namelist():
                open(base + ".inner", "wb").write(z.read("original_apex")); z = zipfile.ZipFile(base + ".inner")
            if "apex_payload.img" not in z.namelist(): continue
            img = base + ".payload.img"; open(img, "wb").write(z.read("apex_payload.img"))
        except (zipfile.BadZipFile, KeyError):
            continue
        hdr = open(img, "rb").read(1084)
        if hdr[1080:1082] == b"\x53\xef": run("debugfs", "-R", f"rdump / {base}", img)
        elif hdr[1024:1028] == b"\xe2\xe1\xf5\xe0": run("fsck.erofs", f"--extract={base}", img)
        os.remove(img)
        jl = os.path.join(base, "javalib")
        if os.path.isdir(jl): out += [os.path.join(jl, j) for j in sorted(os.listdir(jl)) if j.endswith(".jar")]
    return out
C3A_APEX_JARS = apex_jars(os.path.join(C["system"], "apex"), "c3a")
for p in C3A_APEX_JARS: c3a_classes |= dexinfo(p)["defined"]
ENV["C3A_APEX_JAVALIB_JARS_INDEXED"] = str(len(C3A_APEX_JARS))
for k, j in JAR.items(): j["info"] = dexinfo(j["path"])
AOSP_PREFIX = re.compile(r"^L(java|javax|dalvik|kotlin|kotlinx|sun|libcore|org/json|org/xml|org/w3c|junit)/")
if primary:
    ap = dexinfo(primary["path"]); ENV["OEM_IMS_DEX_SOURCE"] = ap["note"] or f"APK({ap['ndex']} dex)"
    refs = {t for t in ap["types"] if t.startswith("L") and t not in ap["defined"] and not AOSP_PREFIX.match(t)}
else:
    ap, refs = {"strings": set()}, set()
owner = {}
for k, j in JAR.items():
    for t in j["info"]["defined"]: owner.setdefault(t, k)
uses = {n: r for n, r in (primary["m"]["uses_library"] if primary else [])}
declname = {v[0]: n for n, v in libdecl.items()}
mtkjar = re.compile(r"mediatek|mtk|ims", re.I)
def is_candidate(k): return bool(mtkjar.search(os.path.basename(k))) or k in declname or any(t.startswith("Lcom/mediatek/") for t in JAR[k]["info"]["defined"])
direct = {}
for t in refs:
    k = owner.get(t)
    if k: direct.setdefault(k, set()).add(t)
required, optional = set(), set()
for k, ts in direct.items():
    if ts - c3a_classes: required.add(k)
for n, req in uses.items():
    f = libdecl.get(n, ("", ""))[0]
    if f in JAR: (required if req != "false" else optional).add(f)
frontier = set(required)
while frontier:          # transitive: classes referenced by required jars, defined in other stock jars, absent in C3A
    k = frontier.pop()
    for t in JAR[k]["info"]["types"]:
        o = owner.get(t)
        if o and o not in required and t not in c3a_classes and t not in JAR[k]["info"]["defined"]:
            required.add(o); frontier.add(o)
optional -= required
# references to MTK-owned or non-AOSP classes that are not satisfied by any jar nor C3A
unresolved = sorted(t for t in refs if t not in owner and t not in c3a_classes)
mtk_in_aosp_jars = sorted({(t, k) for t in refs for k in [owner.get(t)] if k and os.path.basename(k) in ("framework.jar", "telephony-common.jar", "ims-common.jar", "voip-common.jar", "services.jar") and t not in c3a_classes})
rows = []
for k in sorted(JAR):
    if not (is_candidate(k) or k in required or k in optional or k in direct): continue
    j = JAR[k]; d = direct.get(k, set())
    cls = "REQUIRED" if k in required else ("OPTIONAL" if k in optional else "NOT_REQUIRED")
    present = len([t for t in d if t in c3a_classes])
    rows.append((cls, k, sha(j["path"]), declname.get(k, "-"), ",".join(cp.get(k, [])) or ("-" if HAVE_SYS else "UNKNOWN_NO_STOCK_SYSTEM"),
                 "YES" if declname.get(k) in uses else "NO", len(d), f"{present}/{len(d)}", j["info"]["note"] or "dex"))
tsv("a3-framework-jars.tsv", ["class", "jar", "sha256", "declared_library", "classpath_membership", "apk_uses_library", "apk_referenced_classes", "referenced_present_in_c3a", "dex"], rows)
tsv("a3-unresolved-references.tsv", ["type"], [(t,) for t in unresolved])
tsv("a3-mtk-modified-aosp-framework-refs.tsv", ["type", "stock_jar"], mtk_in_aosp_jars)
ENV["REQUIRED_JARS"] = " ".join(sorted(required)) or "NONE"
ENV["OPTIONAL_JARS"] = " ".join(sorted(optional)) or "NONE"
ENV["NOT_REQUIRED_JARS"] = " ".join(r[1] for r in rows if r[0] == "NOT_REQUIRED") or "NONE"
unres_mtk = [t for t in unresolved if t.startswith("Lcom/mediatek/")]
ENV["APK_REFS_UNRESOLVED_COUNT"] = str(len(unresolved))
ENV["APK_REFS_UNRESOLVED_MEDIATEK_COUNT"] = str(len(unres_mtk))
ENV["APK_REFS_INTO_STOCK_AOSP_FRAMEWORK_JARS_NOT_IN_C3A"] = str(len(mtk_in_aosp_jars))
md("| class | jar | declared lib | classpath | uses-library | APK refs (in C3A) |\n|---|---|---|---|---|---|")
for r in rows: md(f"| {r[0]} | `{r[1]}` | {r[3]} | {r[4]} | {r[5]} | {r[6]} ({r[7]}) |")
md(f"\n    REQUIRED_JARS={ENV['REQUIRED_JARS']}\n    OPTIONAL_JARS={ENV['OPTIONAL_JARS']}\n    NOT_REQUIRED_JARS={ENV['NOT_REQUIRED_JARS']}")
md(f"    C3A APEX javalib jars indexed: {ENV['C3A_APEX_JAVALIB_JARS_INDEXED']}")
md(f"    APK references not defined in any stock jar nor in C3A: {len(unresolved)}, of which com.mediatek: {len(unres_mtk)} (a3-unresolved-references.tsv)")
md(f"    APK references into stock AOSP-named framework jars, absent from C3A (MTK framework modifications): {len(mtk_in_aosp_jars)}")
fw_ok = bool(primary) and HAVE_SYS and "DEX_PARSE_ERROR" not in ENV.get("OEM_IMS_DEX_SOURCE", "") and ENV.get("OEM_IMS_DEX_SOURCE") not in ("NO_DEX", "CDEX_UNPARSED", "VDEX_EMPTY", "BAD_ZIP")
MARK["N1I_A_FRAMEWORK_DEPENDENCY_CLOSURE"] = "PASS" if fw_ok else ("INCOMPLETE_NO_STOCK_SYSTEM" if primary and not HAVE_SYS else "FAIL_" + ENV.get("OEM_IMS_DEX_SOURCE", "NO_PACKAGE"))

# =================== A4: native closure ===================
md("\n## A4 Native dependency closure\n")
def elf_info(p):
    try:
        d = open(p, "rb").read()
    except OSError:
        return None
    if d[:4] != b"\x7fELF": return None
    c64 = d[4] == 2; e = "<" if d[5] == 1 else ">"
    if c64:
        phoff, = struct.unpack_from(e + "Q", d, 0x20); phentsize, phnum = struct.unpack_from(e + "HH", d, 0x36)
    else:
        phoff, = struct.unpack_from(e + "I", d, 0x1c); phentsize, phnum = struct.unpack_from(e + "HH", d, 0x2a)
    mach, = struct.unpack_from(e + "H", d, 0x12)
    loads, dyn = [], None
    for i in range(phnum):
        o = phoff + i * phentsize
        if c64:
            pt, _, off, va, _, fsz = struct.unpack_from(e + "IIQQQQ", d, o)
        else:
            pt, off, va, _, fsz = struct.unpack_from(e + "IIIII", d, o)
        if pt == 1: loads.append((va, off, fsz))
        if pt == 2: dyn = (off, fsz)
    needed, strtab = [], None
    if dyn:
        ent = 16 if c64 else 8; fmt = e + ("qQ" if c64 else "iI")
        tags = [struct.unpack_from(fmt, d, dyn[0] + i * ent) for i in range(dyn[1] // ent)]
        for t, v in tags:
            if t == 5:
                strtab = next((off + v - va for va, off, fsz in loads if va <= v < va + fsz), None)
        if strtab is not None:
            for t, v in tags:
                if t == 1:
                    s = strtab + v; needed.append(d[s:d.index(b"\0", s)].decode())
    return {"bits": 64 if c64 else 32, "machine": {183: "aarch64", 40: "arm", 62: "x86_64", 3: "x86"}.get(mach, str(mach)), "needed": needed}
def lib_dirs(parts, roots, bits):
    sub = "lib64" if bits == 64 else "lib"
    return [os.path.join(roots[p], sub) for p in parts if p in roots] + [os.path.join(roots[p], sub, "hw") for p in parts if p in roots]
PLATFORM = re.compile(r"^lib(c|m|dl|log|c\+\+|binder|binder_ndk|utils|cutils|hidlbase|base|vndksupport|z|ssl|crypto|android|nativewindow|sync|ui|hardware|fmq|jsoncpp|xml2|protobuf-cpp-lite|protobuf-cpp-full|selinux|sqlite|stdc\+\+|clang_rt\..*|hidl.*|android\.hidl\..*)\.so$")
def resolve(name, side, bits):
    if side == "vendor":
        for d in lib_dirs(VENDOR_SIDE, S, bits):
            if os.path.isfile(os.path.join(d, name)): return "vendor", os.path.join(d, name)
        for d in lib_dirs(SYSTEM_SIDE, C, bits):
            if os.path.isfile(os.path.join(d, name)): return "system(LLNDK/VNDK via C3A)", os.path.join(d, name)
    else:
        for d in lib_dirs(SYSTEM_SIDE, S, bits):
            if os.path.isfile(os.path.join(d, name)): return "stock-system-side", os.path.join(d, name)
    if PLATFORM.match(name): return "platform/apex", ""
    return "MISSING", ""
roots = []
if primary:
    try:
        with zipfile.ZipFile(primary["path"]) as z:
            for n in z.namelist():
                if n.startswith("lib/") and n.endswith(".so"):
                    tmp = os.path.join(WORK, "apklib", n); os.makedirs(os.path.dirname(tmp), exist_ok=True)
                    open(tmp, "wb").write(z.read(n)); roots.append(("system", tmp, f"{primary['dev']}!/{n}"))
    except zipfile.BadZipFile:
        pass
    apkdir = os.path.dirname(primary["path"])
    for p in files(apkdir):
        if p.endswith(".so"): roots.append(("system", p, devpath(primary["part"], p)))
    loadlib = {s for s in ap["strings"] if re.fullmatch(r"[A-Za-z0-9_\-]{3,64}", s)}
    for part in SYSTEM_SIDE:
        if part in S:
            for p in INDEX[part]:
                b = os.path.basename(p)
                if b.endswith(".so") and b[3:-3] in loadlib and "/lib" in p: roots.append(("system", p, devpath(part, p)))
for part in S:
    for p in INDEX[part]:
        if KW.search(os.path.basename(p)) and (re.search(r"/(lib|lib64|bin)/", p)) and not p.endswith((".rc", ".xml", ".apk", ".jar")):
            roots.append(("vendor" if part in VENDOR_SIDE else "system", p, devpath(part, p)))
seen, nrows, queue = set(), [], list(roots)
while queue:
    side, p, dev = queue.pop()
    if dev in seen: continue
    seen.add(dev)
    info = elf_info(p)
    if not info: continue
    present_c3a = "-"
    if side == "system":
        present_c3a = "YES" if any(os.path.isfile(os.path.join(d, os.path.basename(p))) for d in lib_dirs(SYSTEM_SIDE, C, info["bits"])) else "NO"
    nrows.append((dev, side, info["bits"], info["machine"], " ".join(info["needed"]), present_c3a))
    for n in info["needed"]:
        where, q = resolve(n, side, info["bits"])
        if q:
            part = next((pp for pp in S if q.startswith(S[pp] + "/")), None)
            if part: queue.append((side, q, devpath(part, q)))
        elif where == "MISSING":
            nrows.append((f"(needed) {n}", side, info["bits"], "-", f"UNRESOLVED from {dev}", "-"))
tsv("a4-native-closure.tsv", ["binary", "side", "bits", "machine", "DT_NEEDED", "present_in_c3a"], nrows)
already = sorted(r[0] for r in nrows if r[1] == "vendor" and not r[0].startswith("(needed)"))
must = sorted(r[0] for r in nrows if r[1] == "system" and r[5] == "NO")
unres = sorted({r[0] for r in nrows if r[0].startswith("(needed)")})
ENV["ALREADY_PRESENT_IN_PRESERVED_VENDOR"] = " ".join(already) or "NONE"
ENV["MUST_BE_SUPPLIED_BY_SABLE_SYSTEM_IMAGE"] = " ".join(must) or "NONE"
ENV["NATIVE_UNRESOLVED"] = " ".join(unres) or "NONE"
md(f"    ALREADY_PRESENT_IN_PRESERVED_VENDOR ({len(already)}): {ENV['ALREADY_PRESENT_IN_PRESERVED_VENDOR']}")
md(f"    MUST_BE_SUPPLIED_BY_SABLE_SYSTEM_IMAGE ({len(must)}): {ENV['MUST_BE_SUPPLIED_BY_SABLE_SYSTEM_IMAGE']}")
md(f"    UNRESOLVED DT_NEEDED: {ENV['NATIVE_UNRESOLVED']}")
md("    (full closure with DT_NEEDED and bitness: a4-native-closure.tsv)")
MARK["N1I_A_NATIVE_DEPENDENCY_CLOSURE"] = "PASS" if primary and not unres else ("FAIL_UNRESOLVED_NEEDED" if unres else "FAIL_NO_PACKAGE")

# =================== A5: init / activation ===================
md("\n## A5 Init and service activation\n")
svcs, triggers, setprops = {}, [], []
for part in S:
    for p in INDEX[part]:
        if not p.endswith(".rc"): continue
        cur, block = None, None
        for raw in open(p, errors="replace"):
            line = raw.strip()
            if not line or line.startswith("#"): continue
            if raw[0] not in " \t":
                cur = block = None
                if line.startswith("service "):
                    f = line.split(); cur = {"name": f[1], "exec": f[2] if len(f) > 2 else "", "file": devpath(part, p), "part": part,
                                             "user": "", "group": "", "seclabel": "", "class": "", "disabled": False, "oneshot": False, "socket": []}
                    svcs[f[1]] = cur
                elif line.startswith("on "):
                    block = {"trigger": line[3:], "file": devpath(part, p), "cmds": []}; triggers.append(block)
                continue
            if cur is not None:
                k = line.split()[0]; rest = line[len(k):].strip()
                if k in ("user", "group", "seclabel", "class"): cur[k] = rest
                elif k == "disabled": cur["disabled"] = True
                elif k == "oneshot": cur["oneshot"] = True
                elif k == "socket": cur["socket"].append(rest.split()[0])
            elif block is not None:
                block["cmds"].append(line)
                if line.startswith("setprop "):
                    f2 = line.split(None, 2); setprops.append((f2[1], devpath(part, p), f2[2] if len(f2) > 2 else "", block["trigger"]))
ims_svcs = {n: s for n, s in svcs.items() if KW.search(n) or KW.search(s["exec"]) or re.search(r"mims|ims", n, re.I)}
start_of = {}
for t in triggers:
    for c in t["cmds"]:
        m = re.match(r"(start|restart|stop|setprop ctl\.(?:start|restart|stop))\s+(\S+)", c)
        if m and m.group(2) in ims_svcs: start_of.setdefault(m.group(2), []).append((m.group(1), t["trigger"], t["file"]))
props_needed = sorted({pp for v in start_of.values() for _, trig, _ in v for pp in re.findall(r"property:([\w.\-]+)", trig)})
system_strings = set(ap["strings"])
for k in required | optional: system_strings |= JAR[k]["info"]["strings"]
vendor_rc_set = {sp[0] for sp in setprops}
def vendor_binary_sets(prop):
    pb = prop.encode()
    for part in VENDOR_SIDE:
        for p in INDEX.get(part, []):
            if "/bin/" in p or "/lib64/" in p:
                try:
                    if pb in open(p, "rb").read(): return devpath(part, p)
                except OSError:
                    pass
    return ""
prow, setter = [], {}
for pr in props_needed:
    who = []
    if pr in system_strings: who.append("SYSTEM_SIDE_OEM_IMS_CODE")
    if pr in vendor_rc_set: who.append("VENDOR_OR_SYSTEM_RC")
    vb = vendor_binary_sets(pr)
    if vb: who.append(f"VENDOR_BINARY:{vb}")
    setter[pr] = who; prow.append((pr, " ".join(who) or "UNKNOWN"))
rows = []
for n, s in sorted(ims_svcs.items()):
    st = start_of.get(n, [])
    rows.append((n, s["exec"], s["part"], s["user"], s["group"], s["seclabel"], s["class"], "disabled" if s["disabled"] else "class-start",
                 "oneshot" if s["oneshot"] else "restart", ",".join(s["socket"]) or "-", " | ".join(f"{a} on {t}" for a, t, _ in st) or "-",
                 "YES" if any("boot_completed" in t for _, t, _ in st) else "NO",
                 "YES" if any(re.search(r"sim|nvram|md_|modem|ril", t, re.I) for _, t, _ in st) else "NO"))
tsv("a5-init-services.tsv", ["service", "exec", "partition", "user", "group", "seclabel", "class", "start_mode", "restart", "sockets", "triggers", "boot_completed_dep", "sim_nvram_modem_dep"], rows)
tsv("a5-trigger-property-setters.tsv", ["property", "set_by"], prow)
volte = [r for r in rows if re.search(r"volte|imcb|clientapi|ua", r[0], re.I)]
fw_only = [r for r in volte if r[7] == "disabled" and any(
    setter.get(pp) == ["SYSTEM_SIDE_OEM_IMS_CODE"] for pp in re.findall(r"property:([\w.\-]+)", r[10]))]
vendor_driven = [r for r in volte if r[7] == "class-start" or any(
    any(w.startswith(("VENDOR", "VENDOR_OR")) for w in setter.get(pp, [])) for pp in re.findall(r"property:([\w.\-]+)", r[10]))]
ENV["STOCK_FRAMEWORK_NORMALLY_STARTS_VENDOR_VOLTE_STACK"] = "YES" if fw_only else ("NO" if volte and len(vendor_driven) == len(volte) else "UNKNOWN")
ENV["MANUAL_VENDOR_SERVICE_START_REQUIRED_ON_GSI"] = "LIKELY" if fw_only else "UNPROVEN"
md("| service | exec | part | user | seclabel | start | triggers | boot_completed | SIM/NVRAM/modem |\n|---|---|---|---|---|---|---|---|---|")
for r in rows: md(f"| {r[0]} | `{r[1]}` | {r[2]} | {r[3]} | {r[5]} | {r[7]} | {r[10]} | {r[11]} | {r[12]} |")
md("\nTrigger properties and who sets them (static evidence):\n")
for pr, w in prow: md(f"    {pr}: {w}")
md(f"\n    STOCK_FRAMEWORK_NORMALLY_STARTS_VENDOR_VOLTE_STACK={ENV['STOCK_FRAMEWORK_NORMALLY_STARTS_VENDOR_VOLTE_STACK']}")
md(f"    MANUAL_VENDOR_SERVICE_START_REQUIRED_ON_GSI={ENV['MANUAL_VENDOR_SERVICE_START_REQUIRED_ON_GSI']}  (PROVEN requires a runtime test; static analysis never emits PROVEN)")
MARK["N1I_A_INIT_SERVICE_INVENTORY"] = "PASS" if ims_svcs else "FAIL_NO_IMS_SERVICES_FOUND"

# =================== A6: permissions / sysconfig / overlays ===================
md("\n## A6 Permissions, sysconfig, overlays\n")
pkgs = {c["m"]["package"] for c in cand}
primary_pkg = primary["m"]["package"] if primary else "<none>"
reqlibs = {declname[k] for k in required if k in declname}; optlibs = {declname[k] for k in optional if k in declname}
rows = []
for part in S:
    for p in INDEX[part]:
        if not p.endswith(".xml") or not re.search(r"/etc/(permissions|sysconfig|default-permissions)/", p): continue
        txt = open(p, errors="replace").read()
        try:
            ET.fromstring(txt)
        except ET.ParseError:
            rows.append(("UNPARSEABLE", devpath(part, p), part, "")); continue
        why, cls = [], None
        if re.search(rf'privapp-permissions[^>]*package="{re.escape(primary_pkg)}"', txt): cls = "REQUIRED"; why.append("privapp allowlist for OEM IMS package")
        if any(re.search(rf'<library[^>]*name="{re.escape(l)}"', txt) for l in reqlibs): cls = "REQUIRED"; why.append("declares required library")
        if cls is None and re.search(rf'package="{re.escape(primary_pkg)}"', txt): cls = "LIKELY_REQUIRED"; why.append("sysconfig entry for OEM IMS package")
        if cls is None and re.search(r'<feature[^>]*name="[^"]*ims', txt, re.I): cls = "LIKELY_REQUIRED"; why.append("IMS feature declaration")
        if cls is None and (any(re.search(rf'<library[^>]*name="{re.escape(l)}"', txt) for l in optlibs) or any(f'"{q}"' in txt for q in pkgs - {primary_pkg})): cls = "OPTIONAL"; why.append("optional library / other IMS package")
        if cls is None and KW.search(txt): cls = "OPTIONAL"; why.append("IMS keyword")
        if cls: rows.append((cls, devpath(part, p), part, "; ".join(why)))
for part in S:
    for p in INDEX[part]:
        if p.endswith(".apk") and "/overlay/" in p:
            m = manifest(p)
            tgt = ""
            if m:
                tx = xmltree(p); mm = re.search(r'targetPackage\(0x[0-9a-f]+\)="([^"]+)"', tx) or re.search(r'targetPackage="([^"]+)"', tx); tgt = mm.group(1) if mm else ""
            if tgt in ("android", "com.android.phone", "com.android.carrierconfig", "com.android.systemui", primary_pkg) or KW.search(p):
                rc, res, _ = run("aapt2", "dump", "resources", p)
                keys = sorted(set(re.findall(r"(?:bool|string|integer|array|string-array)/([A-Za-z0-9_]*(?:ims|volte|wfc|vt_|mmtel)[A-Za-z0-9_]*)", res, re.I)))
                if keys:
                    cls = "LIKELY_REQUIRED" if any(re.search(r"ims_package|mmtel|ims_service", k, re.I) for k in keys) else "OPTIONAL"
                    rows.append((cls, devpath(part, p), part, f"RRO target={tgt} keys={','.join(keys[:20])}"))
        if re.search(r"carrier", os.path.basename(p), re.I) and re.search(r"\.(xml|conf)$", p) and "/etc/" in p:
            rows.append(("OPTIONAL", devpath(part, p), part, "carrier configuration file (IMS-relevant per carrier; review)"))
tsv("a6-permissions-sysconfig-overlays.tsv", ["class", "file", "partition", "reason"], rows)
md("| class | file | reason |\n|---|---|---|")
for r in sorted(rows): md(f"| {r[0]} | `{r[1]}` | {r[3]} |")
MARK["N1I_A_PERMISSIONS_SYSCONFIG"] = "PASS" if primary and not any(r[0] == "UNPARSEABLE" for r in rows) else ("FAIL_UNPARSEABLE_XML" if primary else "FAIL_NO_PACKAGE")

# =================== A7: SELinux ===================
md("\n## A7 SELinux\n")
seapp_dom = []
selrows = []
pat = re.compile(rf"{KW.pattern}|{re.escape(primary_pkg)}|radio_prop|vendor_radio|ims", re.I)
for part in S:
    for p in INDEX[part]:
        if "/etc/selinux/" not in p: continue
        b = os.path.basename(p)
        kind = ("seapp" if "seapp_contexts" in b else "service" if b.endswith("service_contexts") and "hw" not in b else "hwservice" if "hwservice_contexts" in b
                else "property" if "property_contexts" in b else "file" if "file_contexts" in b else "cil" if b.endswith(".cil") else "other")
        for i, line in enumerate(open(p, errors="replace"), 1):
            if pat.search(line):
                l = line.strip()
                if kind == "seapp" and primary_pkg in l:
                    d = re.search(r"domain=(\S+)", l); seapp_dom.append((d.group(1) if d else "?", devpath(part, p)))
                selrows.append(("SYSTEM_SIDE_POLICY_MUST_BE_SUPPLIED" if part in SYSTEM_SIDE else "PRESERVED_VENDOR_POLICY", kind, devpath(part, p), i, l[:300]))
doms = {d for d, _ in seapp_dom}
for part in S:
    for p in INDEX[part]:
        if "/etc/selinux/" in p and p.endswith(".cil") and doms:
            for i, line in enumerate(open(p, errors="replace"), 1):
                if any(re.search(rf"\b{re.escape(d)}\b", line) for d in doms) and not pat.search(line):
                    selrows.append(("SYSTEM_SIDE_POLICY_MUST_BE_SUPPLIED" if part in SYSTEM_SIDE else "PRESERVED_VENDOR_POLICY", "cil(domain)", devpath(part, p), i, line.strip()[:300]))
tsv("a7-selinux.tsv", ["ownership", "kind", "file", "line", "entry"], selrows)
cnt = {}
for r in selrows: cnt[(r[0], r[1])] = cnt.get((r[0], r[1]), 0) + 1
ENV["OEM_IMS_SEAPP_DOMAIN"] = " ".join(sorted(doms)) or "NOT_FOUND"
md(f"    OEM IMS seapp domain: {ENV['OEM_IMS_SEAPP_DOMAIN']} ({', '.join(f for _, f in seapp_dom) or '-'})")
md("| ownership | kind | entries |\n|---|---|---|")
for (o, k), n in sorted(cnt.items()): md(f"| {o} | {k} | {n} |")
md("    Full entries: a7-selinux.tsv. Policy proposals are out of scope; no permissive or broad allow rule is proposed.")
MARK["N1I_A_SELINUX_INVENTORY"] = "PASS" if primary and selrows else ("FAIL_NO_ENTRIES" if primary else "FAIL_NO_PACKAGE")

# =================== A8: operator / modem profile ===================
md("\n## A8 Operator / modem profile inventory (for later stock-vs-GSI comparison; no causal claim)\n")
OPK = re.compile(r"sbp|usp_operator|operator|carrier|simswitch|c_capability_slot|mims|volte|ims_support|wfc|epdg|clientapi|dynamic_ims", re.I)
orows = []
for part in S:
    for p in INDEX[part]:
        b = os.path.basename(p)
        if b.endswith(".prop") or b == "build.prop":
            for line in open(p, errors="replace"):
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    if OPK.search(k): orows.append((k, v, devpath(part, p), "build/prop file"))
for pr, f, val, trig in setprops:
    if OPK.search(pr): orows.append((pr, val, f, f"init rc setprop on {trig}"))
def owner_of(k):
    if k.startswith("persist."): return "RUNTIME_PERSIST (may be rewritten by vendor RIL/NVRAM or framework)"
    if k.startswith("ro."): return "BUILD_TIME_READONLY"
    if k.startswith(("vendor.", "ril.", "gsm.")): return "RUNTIME_VENDOR"
    return "RUNTIME_OTHER"
orows = [(k, v, f, s, owner_of(k)) for k, v, f, s in orows]
tsv("a8-operator-profile.tsv", ["property", "stock_value", "source_file", "source_kind", "runtime_owner"], orows)
md("| property | stock value | source | owner |\n|---|---|---|---|")
for r in sorted(orows): md(f"| {r[0]} | {r[1]} | `{r[2]}` | {r[4]} |")
MARK["N1I_A_OPERATOR_PROFILE_INVENTORY"] = "PASS" if orows else "FAIL_NO_ENTRIES"

# =================== conclusion ===================
md("\n## Minimal dependency table\n")
sys_payload = [primary["dev"]] if primary else []
a6 = [l.rstrip("\n").split("\t") for l in open(os.path.join(OUT, "a6-permissions-sysconfig-overlays.tsv"))][1:]
perm_req = sorted(r[1] for r in a6 if r[0] in ("REQUIRED", "LIKELY_REQUIRED"))
sel_sys = sorted({r[2] for r in selrows if r[0] == "SYSTEM_SIDE_POLICY_MUST_BE_SUPPLIED"})
trig = [f"{pr} (set by {w})" for pr, w in prow if "SYSTEM_SIDE_OEM_IMS_CODE" in w]
unknown = []
if ENV.get("PLATFORM_RESIGN_REQUIRED") == "UNKNOWN": unknown.append("platform re-sign need")
if not HAVE_SYS: unknown.append("bootclasspath membership / MTK framework modifications (no stock system.img)")
if unresolved: unknown.append(f"{len(unresolved)} APK class references not found in stock jars or C3A (incl. {len(unres_mtk)} com.mediatek; a3-unresolved-references.tsv)")
if unres: unknown.append(f"unresolved DT_NEEDED: {' '.join(unres)}")
unknown.append("runtime: IMS registration, VoLTE UA start, MT call, slot-switch behaviour (static analysis cannot prove)")
md("1. REQUIRED_SYSTEM_PAYLOAD: " + (", ".join(f"`{x}`" for x in sys_payload) or "NONE_FOUND"))
md("2. REQUIRED_FRAMEWORK_JARS: " + ENV["REQUIRED_JARS"])
md("3. REQUIRED_NATIVE_LIBRARIES_NOT_ALREADY_IN_VENDOR: " + ENV["MUST_BE_SUPPLIED_BY_SABLE_SYSTEM_IMAGE"])
md("4. REQUIRED_PERMISSION_SYSCONFIG_FILES: " + (", ".join(f"`{x}`" for x in perm_req) or "NONE"))
md("5. REQUIRED_INIT_OR_PROPERTY_TRIGGERS: " + ("; ".join(trig) or "NONE_FROM_SYSTEM_SIDE"))
md("6. REQUIRED_SELINUX_CHANGES (system-side policy files carrying OEM IMS entries): " + (", ".join(f"`{x}`" for x in sel_sys) or "NONE"))
md("7. ALREADY_SATISFIED_BY_STOCK_VENDOR: vendor natives " + str(len(already)) + "; vendor VoLTE services " +
   str(len([r for r in volte if r[2] in VENDOR_SIDE])) + "; vendor policy entries " + str(sum(1 for r in selrows if r[0] == "PRESERVED_VENDOR_POLICY")))
md("8. UNKNOWN_DEPENDENCIES_REQUIRING_RUNTIME_TEST: " + "; ".join(unknown))
if not primary or not HAVE_SYS:
    feas, why = "NOT_CURRENTLY_FEASIBLE" if not primary else "UNDETERMINED_NO_STOCK_SYSTEM", "inputs insufficient"
elif mtk_in_aosp_jars or unres_mtk:
    feas, why = "LARGE_FRAMEWORK_PORT", f"{len(mtk_in_aosp_jars)} referenced classes live in MTK-modified AOSP framework jars and are absent from C3A; {len(unres_mtk)} com.mediatek references resolve nowhere"
elif ENV.get("SHARED_UID_SIGNATURE_RISK") == "YES" or required or must or trig:
    feas, why = "MODERATE_TITAN_SPECIFIC_LAYER", f"shared UID={ENV.get('OEM_IMS_SHARED_UID')}, {len(required)} required jars, {len(must)} system-side native libs, {len(trig)} system-driven triggers; no MTK framework-modification references"
else:
    feas, why = "MINIMAL_AND_REASONABLE", "APK-only payload with privapp/sysconfig entries"
ENV["OEM_MTKIMS_PORT_FEASIBILITY"] = feas
md(f"\n    OEM_MTKIMS_PORT_FEASIBILITY={feas}\n    BASIS: {why}\n    (Computed by a fixed rule; the reviewer confirms or overrides it in the committed doc.)")

MARK["N1I_A_V010014_STOCK_SOURCE"] = os.environ["STOCK_SOURCE"]
with open(os.path.join(OUT, "N1I_A_V010014_OEM_IMS_REPORT.md"), "w") as f: f.write("\n".join(REPORT) + "\n")
with open(os.path.join(OUT, "n1i-a-v010014-oem-ims.env"), "w") as f:
    for k, v in ENV.items(): f.write(f"{k}={json.dumps(v) if ' ' in v else v}\n")
    for k, v in MARK.items(): f.write(f"{k}={v}\n")
for k, v in MARK.items(): print(f"{k}={v}")
PYEOF
PYRC=$?
set -e
[[ $PYRC -eq 0 ]] || die "analysis failed (rc=$PYRC)" 4

# ---- contract markers ----------------------------------------------------------------
REPO_STATUS_AFTER=$(git -C "$REPO" status --porcelain 2>/dev/null || echo NO_GIT)
if [[ "$REPO_STATUS_AFTER" == "$REPO_STATUS_BEFORE" ]]; then NB=PASS; else NB=FAIL_REPO_CHANGED; fi
echo "N1I_A_NO_BLOB_IMPORT=$NB" | tee -a "$OUT/n1i-a-v010014-oem-ims.env"
echo "N1I_A_NO_DEVICE_CONTACT=PASS" | tee -a "$OUT/n1i-a-v010014-oem-ims.env"
[[ $CLEAN_WORK == 1 ]] && rm -rf "$WORK"
if grep -E '^N1I_A_[A-Z0-9_]+=' "$OUT/n1i-a-v010014-oem-ims.env" | grep -v '=PASS$' >/dev/null; then
  echo "N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=FAIL" | tee -a "$OUT/n1i-a-v010014-oem-ims.env"
  echo "REPORT=$OUT/N1I_A_V010014_OEM_IMS_REPORT.md"; exit 1
fi
echo "N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS" | tee -a "$OUT/n1i-a-v010014-oem-ims.env"
echo "REPORT=$OUT/N1I_A_V010014_OEM_IMS_REPORT.md"
