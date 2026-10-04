#!/usr/bin/env bash
# Product-lane source qualification for the C3B parallel product lane.
#   build/titan2/qualify-c3b-product-source.sh --static [--base <rev>] [--platform-sable <dir>] [--allow-dirty]
#   build/titan2/qualify-c3b-product-source.sh --full   [--base <rev>]
#
# Both modes run `git diff --check <base>...HEAD` (default base origin/main) and fail if the base cannot be resolved.
# --static : developer-runnable. No Android SDK build, no Gradle, no network, no device, no adb/fastboot, no signing keys.
#            Terminal marker on full pass: C3B_PRODUCT_SOURCE_STATIC_QUALIFICATION=PASS
# --full   : operator-runnable (ai-g732). Runs --static, then the repository-local Android build/test/lint checks when the
#            deliverable changes Android/Kotlin/Java source or build composition (fail-closed if the base cannot be resolved).
#            Gradle runs --offline against a pre-existing GRADLE_USER_HOME wrapper cache; a missing distribution fails closed.
#            Terminal marker on full pass: C3B_PRODUCT_SOURCE_QUALIFICATION=PASS   (never printed by --static)
# This is not canonical SableOS CI (`bash build/sable.sh titan2 N1D ci full`), which stays operator-owned.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
MODE=""; PSDIR=""; ALLOW_DIRTY=NO; BASE="origin/main"
while [[ $# -gt 0 ]]; do case "$1" in
    --static) MODE=static; shift;; --full) MODE=full; shift;;
    --platform-sable) PSDIR="$2"; shift 2;; --allow-dirty) ALLOW_DIRTY=YES; shift;;
    --base) BASE="$2"; shift 2;; *) echo "unknown argument: $1" >&2; exit 2;; esac; done
[[ -n "$MODE" ]] || { echo "usage: $0 --static|--full" >&2; exit 2; }
fail(){ echo "C3B_PRODUCT_SOURCE_QUALIFICATION_FAIL=$1" >&2; exit 1; }

run_static() {
    # --- dirty-source policy ---
    if [[ -n "$(git status --porcelain)" ]]; then
        git status --short >&2
        [[ "$ALLOW_DIRTY" == YES ]] || fail "DIRTY_SOURCE"
        echo "WARN dirty source allowed by --allow-dirty; no PASS marker will be printed" >&2
    fi
    # --- diff integrity against the selected base (fail-closed if the base cannot be resolved) ---
    git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "BASE_UNRESOLVABLE $BASE (use --base <rev>; the diff-integrity check is never skipped)"
    git diff --check "$BASE"...HEAD || fail "DIFF_CHECK $BASE...HEAD"
    git diff --check HEAD || fail "DIFF_CHECK_WORKTREE"
    # --- shell and Python syntax ---
    while IFS= read -r f; do bash -n "$f" || fail "SHELL_SYNTAX $f"; done < <(git ls-files '*.sh')
    while IFS= read -r f; do python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$f" || fail "PYTHON_SYNTAX $f"; done < <(git ls-files '*.py')
    # --- structure, ownership, forbidden content ---
    python3 - "$ROOT" "$PSDIR" <<'PY' || fail "STATIC_CHECKS"
import csv, fnmatch, os, re, subprocess, sys
root, psdir = sys.argv[1], sys.argv[2]
os.chdir(root)
errs = []
def err(m): errs.append(m)
def files(): return subprocess.check_output(["git", "ls-files"], text=True).splitlines()
ALL = files()

def tsv(path, cols):
    if not os.path.isfile(path): err(f"missing {path}"); return []
    rows = list(csv.reader(open(path, newline=""), delimiter="\t"))
    if not rows or rows[0] != cols: err(f"{path}: header mismatch"); return []
    out = []
    for i, r in enumerate(rows[1:], 2):
        if len(r) != len(cols): err(f"{path}:{i}: {len(r)} columns, expected {len(cols)}"); continue
        if any(c.strip() == "" for c in r): err(f"{path}:{i}: empty cell (use NONE or n/a; empty final fields leave trailing whitespace)")
        if any(c != c.strip() for c in r): err(f"{path}:{i}: cell with leading/trailing whitespace")
        out.append(dict(zip(cols, r)))
    return out

MATRIX_COLS = "surface_id provider module_or_platform_path status ux_doc visual_confirmation_doc artifact platform_dependency privilege_requirement runtime_evidence_required c3b_first_engineering_required c3b_integrated_candidate_blocking notes".split()
IR_COLS = "request_id consumer_module capability reason current_fallback privileged_api_needed system_component_owner security_impact blocking status".split()
MOD_COLS = "module_id source_path application_id module_type prototype_status requested_partition privilege_requirement platform_dependency canonical_integration_status notes".split()
OWN_COLS = "source_path owner canonical_target_or_interface collision_status handoff_action notes".split()
STATUSES = {"PRODUCTION_MODULE_SOURCE","AOSP_UNMODIFIED_TEMPORARY","PROTOTYPE_ONLY","PLATFORM_CHANGE_REQUIRED","DEFERRED_NON_BLOCKING","EVIDENCE_REQUIRED","BLOCKED"}

matrix = tsv("docs/C3B_PRODUCT_SURFACE_MATRIX.tsv", MATRIX_COLS)
irs = tsv("docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv", IR_COLS)
mods = tsv("docs/C3B_PRODUCT_SOURCE_MODULES.tsv", MOD_COLS)
own = tsv("docs/C3B_PRODUCT_PATH_OWNERSHIP.tsv", OWN_COLS)

ids = [r["surface_id"] for r in matrix]
if len(ids) != len(set(ids)): err("surface matrix: duplicate surface_id")
for r in matrix:
    if r["status"] not in STATUSES: err(f"surface {r['surface_id']}: status {r['status']} not allowed (no generic DONE)")
    for k in ("c3b_first_engineering_required", "c3b_integrated_candidate_blocking"):
        if r[k] not in ("YES", "NO"): err(f"surface {r['surface_id']}: {k} must be YES or NO")
rids = [r["request_id"] for r in irs]
if len(rids) != len(set(rids)): err("interface requests: duplicate request_id")
known = set(rids)
refs = " ".join(r["platform_dependency"] for r in matrix) + " " + " ".join(r["platform_dependency"] for r in mods) + " " + " ".join(r["module_or_platform_path"] for r in matrix)
for ref in set(re.findall(r"IR-\d+", refs)):
    if ref not in known: err(f"reference to unknown interface request {ref}")
for r in irs:
    if r["blocking"] not in ("YES", "NO"): err(f"{r['request_id']}: blocking must be YES or NO")
mids = [r["module_id"] for r in mods]
if len(mids) != len(set(mids)): err("source modules: duplicate module_id")
for r in mods:
    if r["prototype_status"] == "RETIRED_REMOVED_IN_D1B":
        if r["source_path"] != "NONE (path retired)": err(f"module {r['module_id']}: retired module must not name a source path")
    elif r["prototype_status"] == "CANONICAL_OWNED_NOT_IMPORTED" and r["source_path"].startswith("sableos:"): pass
    elif not os.path.isdir(r["source_path"]): err(f"module {r['module_id']}: source_path missing {r['source_path']}")
    if r["module_type"].startswith("android_app") and r["prototype_status"] != "RETIRED_REMOVED_IN_D1B" and r["canonical_integration_status"] != "NOT_ADMITTED":
        err(f"module {r['module_id']}: must be NOT_ADMITTED")
if any(r["module_id"] == "SableTitan2Home" and r["prototype_status"] != "RETIRED_REMOVED_IN_D1B" for r in mods): err("SableTitan2Home must be RETIRED_REMOVED_IN_D1B")

# --- path ownership: every tracked file is declared ---
def covers(pat, f):
    if pat.endswith("/"): return f.startswith(pat)
    if "*" in pat: return fnmatch.fnmatch(f, pat)
    return f == pat
rules = []
for r in own:
    for p in r["source_path"].split(";"):
        rules.append((p, r))
for f in ALL:
    if not any(covers(p, f) for p, _ in rules): err(f"path not declared in ownership manifest: {f}")

# --- every ownership rule must still match a tracked file (no stale rows) ---
for p_, r in rules:
    if not any(covers(p_, f) for f in ALL): err(f"stale ownership rule (matches no tracked file): {p_}")
RETIRED_ACTIONS = {"REMOVE_IN_D1B", "CONVERT_TO_INTERFACE_REQUEST_IN_D1B", "RENAME_OR_REPLACE_IN_D1B"}
for _, r in rules:
    if r["handoff_action"] in RETIRED_ACTIONS: err(f"ownership row still carries a D1b pending action: {r['source_path']}")

# --- retired paths must stay absent (tracked or on disk) ---
ret = tsv("docs/C3B_PRODUCT_RETIRED_PATHS.tsv", ["path", "reason", "retired_in"])
if not ret: err("retired paths manifest empty")
for r in ret:
    pth = r["path"]
    if any(covers(pth, f) for f in ALL) or os.path.exists(pth): err(f"retired path reappeared: {pth}")
for f in ALL:
    if re.search(r"(^|/)(stage-sablescreens|audit-sable-image|audit-sablescreens-source)\.sh$", f): err(f"retired staging/image-audit script: {f}")
    if f.startswith("product/") or "vendor/sable/titan2" in f: err(f"retired product tree / vendor/sable/titan2 path: {f}")
    if f.endswith(".mk") or f.endswith("Android.bp") or f.endswith(".bp"): err(f"product makefile/Soong file tracked (product authority is canonical): {f}")
for d in ("apps/titan2/platform/home",):
    if os.path.exists(d): err(f"standalone HOME module present: {d}")
for f in ALL:
    if f.startswith("apps/titan2/platform/") and "/home/" in f: err(f"standalone HOME runtime source: {f}")
gs = open("apps/titan2/platform/settings.gradle.kts").read()
if re.search(r':home\b', gs): err("settings.gradle.kts includes :home")

# --- forbidden: signing material, presigned APKs ---
for f in ALL:
    if re.search(r"\.(jks|keystore|pk8|pem|p12|pfx|x509\.pem)$", f, re.I): err(f"forbidden signing material tracked: {f}")
    if f.lower().endswith(".apk"): err(f"forbidden presigned/prebuilt APK tracked: {f}")
    if f.startswith("product/titan2/prebuilt/"): err(f"forbidden prebuilt directory content: {f}")

# --- forbidden product authority / properties / prebuilt model (all non-doc files, including Kotlin) ---
SELF = "build/titan2/qualify-c3b-product-source.sh"
AUTH = [r"sable_titan2_n1d_arm64", r"vendor/sable/titan2", r"ro\.sable\.(profile\.assurance|image\.composition|profile\.validated)", r"persist\.sable\.displaycompat\.mini_size", r"org\.sableos\.titan2\.home\b",
        r"PRODUCT_COPY_FILES", r"PRODUCT_PACKAGES", r"LOCAL_PREBUILT|BUILD_PREBUILT|android_app_import|LOCAL_CERTIFICATE\s*:=\s*PRESIGNED|certificate:\s*\"PRESIGNED\""]
for f in ALL:
    if f == SELF or f == "docs/C3B_PRODUCT_RETIRED_PATHS.tsv" or f.startswith("docs/") or f.endswith((".png", ".jar", ".tsv", ".md")): continue
    if not os.path.isfile(f): continue
    t = open(f, errors="ignore").read()
    for a in AUTH:
        if re.search(a, t): err(f"forbidden product authority pattern /{a}/ in {f}")

# --- forbidden radio/network mutation in product code and scripts ---
MUT = [r"\bsetprop\b", r"settings\s+put\b", r"\bsvc\s+(data|wifi)\b", r"cmd\s+phone\b", r"setPreferredNetworkType", r"setDataEnabled\(", r"setRadioPower", r"iccTransmit", r"setNetworkSelection", r"Settings\.(Global|Secure|System)\.put", r"Runtime\.getRuntime\(\)\.exec", r"ProcessBuilder"]
for f in ALL:
    if f == SELF or not re.search(r"\.(kt|java|sh)$", f): continue
    t = open(f, errors="ignore").read()
    for m in MUT:
        if re.search(m, t): err(f"forbidden radio/system mutation pattern /{m}/ in {f}")

# --- reference-only capture marking ---
cap = "build/titan2/capture-c3b-cellular-runtime-reference.sh"
if not os.path.isfile(cap): err("reference capture script missing")
else:
    t = open(cap).read()
    if "REFERENCE_ONLY_NOT_CANONICAL_CAPTURE" not in t: err("reference capture not marked REFERENCE_ONLY_NOT_CANONICAL_CAPTURE")
    if re.search(r"(?<!REFERENCE_)CELLULAR_RUNTIME_SUMMARY\.env", t): err("reference capture writes a canonical-named summary file")
if "build/titan2/capture-n1b2-cellular-runtime.sh" in ALL: err("colliding capture-n1b2-cellular-runtime.sh still tracked")

# --- HOME ownership: no HOME intent-filter anywhere in the parallel lane ---
import xml.etree.ElementTree as ET
NS = "{http://schemas.android.com/apk/res/android}name"
def manifest(f):
    try: return ET.parse(f).getroot()
    except Exception as e: err(f"manifest parse error {f}: {e}"); return None
for f in ALL:
    if f.endswith("AndroidManifest.xml"):
        r_ = manifest(f)
        if r_ is None: continue
        if any(c.get(NS) == "android.intent.category.HOME" for fl in r_.iter("intent-filter") for c in fl.iter("category")):
            err(f"HOME intent-filter in the parallel lane: {f}")

# --- source audit (folded in from the retired audit-sablescreens-source.sh) ---
APPNS = "{http://schemas.android.com/apk/res/android}"
PERMS = {"camera": {"android.permission.CAMERA", "android.permission.RECORD_AUDIO"}, "radiodiag": {"android.permission.READ_BASIC_PHONE_STATE"}}
def audit_manifest(path, allowed):
    r_ = manifest(path)
    if r_ is None: return
    uses = {e.get(APPNS + "name") for e in r_.iter("uses-permission")}
    if uses - allowed: err(f"{path}: unexpected permissions {sorted(uses - allowed)}")
    app = r_.find("application")
    if app is None or app.get(APPNS + "allowBackup") != "false": err(f"{path}: android:allowBackup must be false")
    if r_.get(APPNS + "sharedUserId"): err(f"{path}: sharedUserId forbidden (platform certificate/shared UID is an interface request)")
for m in ("displaycompat", "keyboard", "camera", "setup", "radiodiag"):
    mf = f"apps/titan2/platform/{m}/src/main/AndroidManifest.xml"
    if not os.path.isfile(mf): err(f"missing {mf}")
    else: audit_manifest(mf, PERMS.get(m, set()))
smf = "apps/titan2/screens/app/src/main/AndroidManifest.xml"
if not os.path.isfile(smf): err(f"missing {smf}")
else: audit_manifest(smf, set())
# radiodiag permission regression: READ_BASIC_PHONE_STATE present, dangerous READ_PHONE_STATE absent, no runtime permission plumbing
_rm = "apps/titan2/platform/radiodiag/src/main/AndroidManifest.xml"
if os.path.isfile(_rm):
    _t = open(_rm).read(); _uses = re.findall(r'<uses-permission[^>]*android:name="([^"]+)"', re.sub(r"(?s)<!--.*?-->", "", _t))
    if "android.permission.READ_BASIC_PHONE_STATE" not in _uses: err("radiodiag must declare READ_BASIC_PHONE_STATE")
    if "android.permission.READ_PHONE_STATE" in _uses: err("radiodiag must not declare the dangerous READ_PHONE_STATE")
for _f in ALL:
    if _f.startswith("apps/titan2/platform/radiodiag/src/main/") and _f.endswith((".kt", ".java")):
        if re.search(r"READ_PHONE_STATE|requestPermissions\(|onRequestPermissionsResult|SuppressLint\(\"MissingPermission\"\)", open(_f, errors="ignore").read()): err(f"radiodiag runtime phone-permission plumbing or MissingPermission suppression: {_f}")
        _src = open(_f, errors="ignore").read()
        _code = re.sub(r"(?s)/\*.*?\*/", "", re.sub(r"(?m)//.*$", "", _src))
        for _api in ("dataNetworkType", "isDataEnabled"):
            for _m in re.finditer(r"(?<![\w])\.?" + _api + r"\b", _code):
                _pre = _code[:_m.start()]
                _funs = list(re.finditer(r"\bfun\s+(?:<[^>]*>\s*)?\w+", _pre))
                _seg = _pre[_funs[-1].start():] if _funs else ""
                if re.search(r"\bsafe\s*\{[^{}]*$", _seg): err(f"{_f}: {_api} is inside a safe{{}} lambda; Lint cannot see the permission guard")
                if not re.search(r"checkSelfPermission\(\s*Manifest\.permission\.READ_BASIC_PHONE_STATE\s*\)", _seg): err(f"{_f}: {_api} not preceded by an explicit READ_BASIC_PHONE_STATE check in the same function")
SRC = [f for f in ALL if f.endswith((".kt", ".java")) and f.startswith("apps/titan2/") and "/src/main/" in f]
def has(pat, f): return re.search(pat, open(f, errors="ignore").read())
ime = "apps/titan2/platform/keyboard/src/main/java/org/sableos/titan2/keyboard/android/SableImeService.kt"
if ime in ALL and "currentInputMethodSubtype" in open(ime).read() and "InputMethodManager::class.java" not in open(ime).read(): err("SableImeService.kt must resolve the subtype via getSystemService(InputMethodManager::class.java)")
# --- screens (Compose) compile-API regressions ---
SCR = [f for f in ALL if f.startswith("apps/titan2/screens/") and f.endswith(".kt")]
for f in SCR:
    t = open(f, errors="ignore").read(); code = re.sub(r"(?m)//.*$", "", t)
    if re.search(r"androidx\.compose\.foundation\.lazy\.itemsIndexed\s*\(", code): err(f"{f}: fully-qualified itemsIndexed(...) call; import it and call it inside the LazyListScope")
    if re.search(r"(?<![\w.])itemsIndexed\s*\(", code) and not re.search(r"(?m)^import androidx\.compose\.foundation\.lazy\.(itemsIndexed|\*)\s*$", t): err(f"{f}: itemsIndexed used without its import")
    if re.search(r"\.focusRequester\s*\(", code) and not re.search(r"(?m)^import androidx\.compose\.ui\.focus\.(focusRequester|\*)\s*$", t): err(f"{f}: .focusRequester(...) without import androidx.compose.ui.focus.focusRequester")
    if re.search(r"(?m)^import androidx\.compose\.ui\.input\.key\.nativeKeyEvent\s*$", t): err(f"{f}: invalid import androidx.compose.ui.input.key.nativeKeyEvent (nativeKeyEvent is a member of KeyEvent)")
for f in SRC:
    if has(r"java\.net\.|okhttp|HttpURLConnection|URLConnection", f): err(f"network API in {f}")
    if has(r"Build\.(MODEL|DEVICE|PRODUCT|BOARD)\b", f): err(f"device-identity gating via Build.* in {f}")
    if has(r"Settings\.Secure\.putString|WRITE_SECURE_SETTINGS", f): err(f"secure settings write in {f}")
    if has(r'Class\.forName\(\s*"android\.os\.SystemProperties"', f) and not f.endswith("/SysProps.kt"): err(f"SystemProperties reflection outside SysProps.kt: {f}")
    if has(r"setUserMinAspectRatio", f) and not f.endswith("/GatedPlatformBackend.kt"): err(f"setUserMinAspectRatio outside GatedPlatformBackend.kt: {f}")
    # currentInputMethodSubtype belongs to InputMethodManager; a bare (unqualified) reference means InputMethodService, which has no such property.
    if re.search(r"(?<![.\w])currentInputMethodSubtype\b", re.sub(r"(?m)//.*$", "", open(f, errors="ignore").read())): err(f"unqualified currentInputMethodSubtype (resolve via InputMethodManager): {f}")
    if has(r"isFunctionPressed", f) and not f.endswith("/DeviceKeyAdapter.kt"): err(f"Fn isFunctionPressed outside DeviceKeyAdapter.kt: {f}")
    if "/core/" in f and re.search(r"(?m)^\s*import\s+(android|androidx)\.", open(f, errors="ignore").read()): err(f"Android import inside core package: {f}")

# --- handoff env structure ---
REQ = {"C3B_PRODUCT_HANDOFF_VERSION":"2","C3B_PRODUCT_SOURCE_IDENTITY_MODE":"RUNTIME_GIT_HEAD","C3B_RELEASE_TRACK":"N1D","C3B_BASELINE_PHASE":"C3B",
       "C3B_PRODUCT_RELEASE_ELIGIBLE":"NO","C3B_PRODUCT_FLASH_AUTHORIZED":"NO","C3B_PRODUCT_PRODUCTION_SIGNING_AUTHORIZED":"NO",
       "C3B_PRODUCT_DEVICE_CONTACT_AUTHORIZED":"NO","C3B_PRODUCT_RADIO_CHANGES_ALLOWED":"NO","C3B_PRODUCT_FRAGMENT_SUPPLIED":"NO",
       "C3B_PRODUCT_PRESIGNED_PREBUILT_APK_MODEL":"NO","C3B_PRODUCT_STANDALONE_HOME_APP":"NO","C3B_PRODUCT_HOME_OWNER":"Launcher3QuickStep"}
def env(path):
    d = {}
    if not os.path.isfile(path): err(f"missing {path}"); return d
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1); d[k] = v
    return d
h = env("docs/C3B_PRODUCT_HANDOFF.env")
for k, v in REQ.items():
    if h.get(k) != v: err(f"handoff env: {k} must be {v}, found {h.get(k)}")
if os.path.isfile("docs/C3B_PRODUCT_HANDOFF.env") and re.search(r"\b[0-9a-f]{40}\b", open("docs/C3B_PRODUCT_HANDOFF.env").read()):
    err("handoff env embeds a 40-char SHA (forbidden: source identity is the runtime git HEAD)")
for k in ("C3B_PRODUCT_SURFACE_MATRIX","C3B_PRODUCT_INTERFACE_REQUESTS","C3B_PRODUCT_SOURCE_MODULES","C3B_PRODUCT_PATH_OWNERSHIP","C3B_PRODUCT_KNOWN_LIMITATIONS"):
    if h.get(k) and not os.path.isfile(h[k]): err(f"handoff env: {k} points to missing {h[k]}")

# --- platform_sable binding ---
b = env("docs/C3B_PLATFORM_SABLE_BINDING.env")
ph = b.get("C3B_PLATFORM_SABLE_HEAD", "")
if not re.fullmatch(r"[0-9a-f]{40}", ph): err("platform_sable binding: head is not a 40-char sha")
if psdir:
    try:
        head = subprocess.check_output(["git", "-C", psdir, "rev-parse", "HEAD"], text=True).strip()
        if head != ph: err(f"platform_sable checkout head {head} != bound head {ph}")
    except Exception as e: err(f"platform_sable checkout unreadable: {e}")
    for r in matrix:
        for k in ("ux_doc", "visual_confirmation_doc", "artifact"):
            if r[k] != "NONE" and not os.path.isfile(os.path.join(psdir, r[k])): err(f"surface {r['surface_id']}: {k} missing in platform_sable: {r[k]}")

# --- dependency declarations ---
for f in ("docs/C3B_PRODUCT_DEPENDENCY_DELTA_TEMPLATE.md", "docs/C3B_PRODUCT_QUALITY_POLICY.md", "docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md", "docs/C3B_PRODUCT_COLLISION_INVENTORY.md"):
    if not os.path.isfile(f): err(f"missing {f}")
# --- D2 quality and supply-chain enforcement ---
import hashlib
def blob_sha(path):
    data = open(path, "rb").read()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()
CANON = {"DETEKT_CONFIG_SOURCE_REPO": "aimindseye/sableos", "DETEKT_CONFIG_SOURCE_COMMIT": "e97ea89cbd77a53390df8a14d93eb1a36531178c",
         "DETEKT_CONFIG_SOURCE_PATH": "apps/r8/android/config/detekt.yml", "DETEKT_CONFIG_GIT_BLOB": "46ec82af4af1b79a4357bf0a8608538a549b1aaf",
         "DETEKT_GRADLE_PLUGIN_VERSION": "1.23.8", "KTLINT_GRADLE_PLUGIN_VERSION": "14.2.0", "KTLINT_ENGINE_VERSION": "1.8.0", "QUALITY_EXEMPTION": "NO"}
prov = env("config/DETEKT_PROVENANCE.env")
for k, v in CANON.items():
    if prov.get(k) != v: err(f"config/DETEKT_PROVENANCE.env: {k} must be {v}, found {prov.get(k)}")
if not os.path.isfile("config/detekt.yml"): err("missing config/detekt.yml")
elif blob_sha("config/detekt.yml") != CANON["DETEKT_CONFIG_GIT_BLOB"]: err("config/detekt.yml is not the byte-exact canonical copy (git blob mismatch)")
ed = open(".editorconfig").read() if os.path.isfile(".editorconfig") else ""
if not re.search(r"(?m)^ktlint_code_style\s*=\s*android_studio\s*$", ed): err(".editorconfig must set ktlint_code_style = android_studio")
GRADLE_ROOTS = ("apps/titan2/platform", "apps/titan2/screens")
for ws in GRADLE_ROOTS:
    toml = open(f"{ws}/gradle/libs.versions.toml").read()
    if not re.search(r'(?m)^detekt\s*=\s*"1\.23\.8"\s*$', toml): err(f"{ws}: Detekt plugin version must be exactly 1.23.8")
    if not re.search(r'(?m)^ktlintGradle\s*=\s*"14\.2\.0"\s*$', toml): err(f"{ws}: Ktlint Gradle plugin version must be exactly 14.2.0")
    if "io.gitlab.arturbosch.detekt" not in toml or "org.jlleitschuh.gradle.ktlint" not in toml: err(f"{ws}: detekt/ktlint plugin ids missing from the version catalog")
    bg = re.sub(r"(?m)//.*$", "", open(f"{ws}/build.gradle.kts").read())
    for need, why in ((r"buildUponDefaultConfig\s*=\s*true", "Detekt buildUponDefaultConfig=true"), (r"parallel\s*=\s*true", "Detekt parallel=true"),
                      (r"config\.setFrom\(\s*detektConfigFile\s*\)", "Detekt config from config/detekt.yml"), (r'rootProject\.file\("\.\./\.\./\.\./config/detekt\.yml"\)', "config path ../../../config/detekt.yml"),
                      (r'version\.set\("1\.8\.0"\)', "Ktlint engine 1.8.0"), (r"android\.set\(true\)", "Ktlint android=true"), (r"outputToConsole\.set\(true\)", "Ktlint outputToConsole"),
                      (r"(?m)^\s*ignoreFailures\s*=\s*false\s*$", "Detekt ignoreFailures=false"), (r"ignoreFailures\.set\(false\)", "Ktlint ignoreFailures=false"),
                      (r'pluginManager\.apply\("io\.gitlab\.arturbosch\.detekt"\)', "Detekt applied to subprojects"), (r'pluginManager\.apply\("org\.jlleitschuh\.gradle\.ktlint"\)', "Ktlint applied to subprojects")):
        if not re.search(need, bg): err(f"{ws}/build.gradle.kts: missing {why}")
for f in ALL:
    if f.endswith((".gradle.kts", ".gradle", ".toml", ".properties")):
        t = open(f, errors="ignore").read()
        if re.search(r"ignoreFailures(\s*=\s*true|\.set\(\s*true\s*\))|isIgnoreFailures\s*=\s*true|\bbaseline\b|allRules\s*=\s*false|ignoreFailures\s*=\s*providers", t): err(f"report-only/baseline/ignoreFailures in {f}")
    if re.search(r"baseline.*\.xml$", f, re.I) and "detekt" in f.lower(): err(f"Detekt baseline file tracked: {f}")
# suppression budget
budget = {r["rule"]: int(r["max_count"]) for r in tsv("config/QUALITY_SUPPRESSION_BUDGET.tsv", ["rule", "max_count", "scope", "reason"]) if r["max_count"].isdigit()}
counts = {}
for f in ALL:
    if not f.endswith(".kt") or not f.startswith("apps/"): continue
    t = open(f, errors="ignore").read()
    if re.search(r"ktlint-disable|@(file:)?Suppress\([^)]*ktlint", t): err(f"ktlint suppression forbidden: {f}")
    if re.search(r"(?m)^\s*//\s*noinspection|detekt:suppress|@file:Suppress\(\"[^\"]*\",\s*\"ALL", t): err(f"blanket suppression forbidden: {f}")
    for m in re.finditer(r"@(?:file:)?Suppress\(([^)]*)\)", t):
        for rule in re.findall(r'"([A-Za-z]+)"', m.group(1)): counts[rule] = counts.get(rule, 0) + 1
for rule, n in sorted(counts.items()):
    if n > budget.get(rule, 0): err(f"suppression budget exceeded: {rule} used {n} > {budget.get(rule, 0)} (config/QUALITY_SUPPRESSION_BUDGET.tsv)")
# dependency-verification metadata (developer lane may not be able to generate it)
VER = {}
for ws in GRADLE_ROOTS:
    vm = f"{ws}/gradle/verification-metadata.xml"
    if os.path.isfile(vm):
        try:
            vr = ET.parse(vm).getroot()
            txt = open(vm).read()
            if "verify-metadata" in txt and re.search(r"<verify-metadata>\s*false", txt): err(f"{vm}: verification disabled")
            if "io.gitlab.arturbosch.detekt" not in txt or "org.jlleitschuh.gradle.ktlint" not in txt: err(f"{vm}: does not cover the Detekt/Ktlint plugin graph")
            VER[ws] = "PASS"
        except Exception as e: err(f"{vm}: parse error {e}")
    else: VER[ws] = "OPERATOR_BOOTSTRAP_REQUIRED"
print("DETEKT_CONFIG_CANONICAL_BINDING=PASS\nDETEKT_PLUGIN_VERSION=PASS value=1.23.8\nKTLINT_PLUGIN_VERSION=PASS value=14.2.0\nKTLINT_ENGINE_VERSION=PASS value=1.8.0\nQUALITY_EXEMPTION=NO")
print("DETEKT_ENFORCEMENT=PASS_SOURCE_CONFIG_ENFORCED_OPERATOR_RUN_REQUIRED\nKTLINT_ENFORCEMENT=PASS_SOURCE_CONFIG_ENFORCED_OPERATOR_RUN_REQUIRED")
print("DEPENDENCY_VERIFICATION_METADATA=" + ("PASS" if all(v == "PASS" for v in VER.values()) else "OPERATOR_BOOTSTRAP_REQUIRED") + " " + " ".join(f"{k}={v}" for k, v in VER.items()))

# --- D3 critical text entry hardening ---
import subprocess, tempfile
KB = "apps/titan2/platform/keyboard"
KBMAIN = f"{KB}/src/main"
def _strip(src): return re.sub(r"(?s)/\*.*?\*/", "", re.sub(r"(?m)//.*$", "", src))
def _rd(p): return open(p, errors="ignore").read() if os.path.isfile(p) else ""
# direct boot (source storage requirement; device runtime evidence is separate and pending)
_mf = _rd(f"{KBMAIN}/AndroidManifest.xml"); _mfx = None
try: _mfx = ET.fromstring(_mf)
except Exception: err("keyboard AndroidManifest.xml unparsable")
DB = {"KEYBOARD_DIRECT_BOOT_APP": "FAIL", "KEYBOARD_DIRECT_BOOT_IME_SERVICE": "FAIL", "KEYBOARD_DEVICE_PROTECTED_PREFS": "FAIL"}
if _mfx is not None:
    _app = _mfx.find("application")
    if _app is not None and _app.get(APPNS + "directBootAware") == "true": DB["KEYBOARD_DIRECT_BOOT_APP"] = "PASS"
    else: err("keyboard <application> must be android:directBootAware=\"true\"")
    _svc = [s for s in (_app.iter("service") if _app is not None else []) if s.get(APPNS + "name", "").endswith("SableImeService")]
    if len(_svc) == 1 and _svc[0].get(APPNS + "directBootAware") == "true": DB["KEYBOARD_DIRECT_BOOT_IME_SERVICE"] = "PASS"
    else: err("SableImeService <service> must be android:directBootAware=\"true\"")
_kp = _strip(_rd(f"{KBMAIN}/java/org/sableos/titan2/keyboard/android/KeyboardPrefs.kt"))
if re.search(r"createDeviceProtectedStorageContext\(\)\s*\.getSharedPreferences\(\s*\"sable_keyboard\"", _kp): DB["KEYBOARD_DEVICE_PROTECTED_PREFS"] = "PASS"
else: err("KeyboardPrefs must read sable_keyboard via createDeviceProtectedStorageContext().getSharedPreferences")
for _f in ALL:
    if _f.startswith(KBMAIN + "/java/") and _f.endswith(".kt") and not _f.endswith("/KeyboardPrefs.kt"):
        if re.search(r"getSharedPreferences\(|PreferenceManager|\bfilesDir\b|\bcacheDir\b|openFileOutput|openFileInput|getExternalFilesDir|\bgetDatabasePath\b|\bSQLiteOpenHelper\b", _strip(_rd(_f))):
            err(f"{_f}: credential-protected storage access in the keyboard module (direct boot); use KeyboardPrefs (device-protected)")
for k, v in DB.items(): print(f"{k}={v}")
# Pinyin provenance: clean-corpus allowlist (CC-CEDICT + Unihan only), offline deterministic regeneration
PV = env("third_party/pinyin_zh/PROVENANCE.env") if os.path.isfile("third_party/pinyin_zh/PROVENANCE.env") else {}
if not PV: err("missing third_party/pinyin_zh/PROVENANCE.env")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
_pol_ok = _inp_ok = _unv_ok = _py_ok = _net_ok = _regen_ok = _prov_ok = _lic_ok = True
def _flag(name, msg):
    err("pinyin corpus: " + msg); return False
BANNED = ("pypinyin", "pinyin-data", "pinyin_data", "phrase-pinyin-data", "jieba", "zdic", "zisea", "guoxuedashi", "hydcd", "hotoo")
_expect = {"PINYIN_CORPUS_POLICY": "CLEAR_REDISTRIBUTION_INPUTS_ONLY", "CC_CEDICT_LICENSE": "CC-BY-SA-4.0", "UNIHAN_LICENSE": "Unicode-3.0",
           "PINYIN_UNVERIFIED_SOURCE_COUNT": "0", "PINYIN_CORPUS_SOURCE_COUNT": "2", "PINYIN_LICENSE_REVIEW": "CLOSED_REGENERATED_FROM_APPROVED_INPUTS",
           "PINYIN_GENERATED_CORPUS_LICENSE": "CC-BY-SA-4.0_DERIVED", "NUMERIC_WEIGHT_IS_CORPUS_FREQUENCY": "NO", "RANKING_ALGORITHM": "DETERMINISTIC",
           "PINYIN_GENERATOR_NETWORK_ACCESS": "FORBIDDEN"}
for k, v in _expect.items():
    if PV.get(k) != v: _pol_ok = _flag(0, f"PROVENANCE.env {k} must be {v}, found {PV.get(k)}")
if PV.get("PINYIN_UNVERIFIED_SOURCE_COUNT") != "0": _unv_ok = False
# any key naming a non-approved input family is a failure
_allowed_prefix = ("PINYIN_", "CC_CEDICT_", "UNIHAN_", "LICENSE_TEXT_SOURCE", "RANKING_", "NUMERIC_WEIGHT")
for k in PV:
    if not k.startswith(_allowed_prefix): _inp_ok = _flag(0, f"unexpected provenance key {k} (only CC-CEDICT and Unihan inputs are allowed)")
_pt = open("third_party/pinyin_zh/PROVENANCE.env", encoding="utf8").read().lower()
_bundle_files = [f"{KBMAIN}/assets/pinyin_zh.NOTICE.txt", f"{KBMAIN}/assets/pinyin_zh.LICENSES.txt", "tools/gen_pinyin_dict.py", "tools/gen_pinyin_license_bundle.py"]
for _f in ["third_party/pinyin_zh/PROVENANCE.env"] + _bundle_files:
    _tt = _rd(_f).lower()
    for b in BANNED:
        if b in _tt: _pol_ok = _flag(0, f"{_f} references banned input '{b}'")
for _f in ALL:
    if _f.startswith("third_party/pinyin_zh/") and _f != "third_party/pinyin_zh/PROVENANCE.env" and _f.lower().endswith((".txt", ".md", ".env")) and "/inputs/" not in _f:
        if not re.search(r"licen[sc]e\.(cc-by-sa-4\.0|unicode-3\.0)\.txt$", _f.lower()): _pol_ok = _flag(0, f"stale or unapproved corpus file tracked: {_f}")
    for b in BANNED:
        if _f.startswith("third_party/pinyin_zh/") and b in _f.lower(): _pol_ok = _flag(0, f"tracked path names banned input: {_f}")
if any(re.search(r"/latest/|latest\.zip", PV.get(k, ""), re.I) for k in ("CC_CEDICT_SOURCE", "UNIHAN_SOURCE")): _inp_ok = _flag(0, "a source URL is 'latest'; pin a numbered release")
if not re.match(r"^\d+\.\d+\.\d+$", PV.get("UNIHAN_VERSION", "")) or PV.get("UNIHAN_VERSION", "") not in PV.get("UNIHAN_SOURCE", ""): _inp_ok = _flag(0, "UNIHAN_VERSION must be a numbered release contained in UNIHAN_SOURCE")
for k in ("CC_CEDICT_SNAPSHOT", "CC_CEDICT_SOURCE", "CC_CEDICT_ARTIFACT", "UNIHAN_SOURCE", "UNIHAN_ARTIFACT", "UNIHAN_READINGS_PATH", "UNIHAN_ADMITTED_PROPERTIES"):
    if not PV.get(k): _inp_ok = _flag(0, f"{k} missing")
if PV.get("UNIHAN_ADMITTED_PROPERTIES") != "kMandarin,kTGHZ2013": _inp_ok = _flag(0, "UNIHAN_ADMITTED_PROPERTIES must be exactly kMandarin,kTGHZ2013")
for pre in ("CC_CEDICT", "UNIHAN"):
    for k in (pre + "_ZIP_SHA256", pre + "_LICENSE_SHA256") + ((pre + "_MEMBER_SHA256",) if pre == "CC_CEDICT" else ("UNIHAN_READINGS_SHA256",)):
        if not HEX64.match(PV.get(k, "")): _inp_ok = _flag(0, f"{k} missing or not a sha256")
    zp = PV.get(pre + "_ARTIFACT_PATH", "")
    if not os.path.isfile(zp): _inp_ok = _flag(0, f"{pre} vendored input missing: {zp}")
    elif hashlib.sha256(open(zp, "rb").read()).hexdigest() != PV.get(pre + "_ZIP_SHA256"): _inp_ok = _flag(0, f"{pre} vendored input differs from its pinned sha256")
    lf = PV.get(pre + "_LICENSE_FILE", "")
    if not os.path.isfile(lf): _lic_ok = _flag(0, f"{pre} licence file missing: {lf}")
    elif hashlib.sha256(open(lf, "rb").read()).hexdigest() != PV.get(pre + "_LICENSE_SHA256"): _lic_ok = _flag(0, f"{pre} licence text differs from its pinned sha256")
    elif len(open(lf, errors="ignore").read().strip()) < 1500: _lic_ok = _flag(0, f"{pre} licence text implausibly short")
    if pre + "_OFFICIAL_ORIGIN_VERIFIED" not in PV: _inp_ok = _flag(0, f"{pre}_OFFICIAL_ORIGIN_VERIFIED must be recorded (PENDING_OPERATOR_HASH_COMPARISON or PASS)")
# generator: no pypinyin, no network, no override
_gen = _rd("tools/gen_pinyin_dict.py"); _gcode = _strip(re.sub(r'(?s)""".*?"""', "", _gen))
if re.search(r"(?m)^\s*(import|from)\s+pypinyin\b", _gen) or "pypinyin" in _gen.lower(): _py_ok = _flag(0, "generator must not depend on pypinyin")
if re.search(r"(?m)^\s*(import|from)\s+(requests|urllib|http|socket|ftplib|subprocess|httpx|aiohttp)\b|urlopen|urlretrieve|\bcurl\b|\bwget\b|os\.system|Popen", _gcode): _net_ok = _flag(0, "generator must not perform network access or spawn fetch processes")
if not re.search(r"(?m)^import zipfile", _gen) or "PROVENANCE" not in _gen: _net_ok = _flag(0, "generator must read the vendored archives and provenance only")
for _s in ("tools/gen_pinyin_license_bundle.py",):
    if re.search(r"(?m)^\s*(import|from)\s+(requests|urllib|http|socket|subprocess)\b|urlopen|\bcurl\b|\bwget\b", _rd(_s)): _net_ok = _flag(0, f"{_s} must not perform network access")
# output pins, deterministic regeneration of asset, NOTICE and LICENSES
_asset = PV.get("PINYIN_OUTPUT_ASSET", "")
if os.path.isfile(_asset):
    _ab = open(_asset, "rb").read()
    if hashlib.sha256(_ab).hexdigest() != PV.get("PINYIN_OUTPUT_SHA256"): _prov_ok = _flag(0, "pinyin_zh.tsv sha256 differs from PINYIN_OUTPUT_SHA256")
    if len(_ab) != int(PV.get("PINYIN_OUTPUT_BYTES", "-1")): _prov_ok = _flag(0, "pinyin_zh.tsv byte size differs from provenance")
    if _ab.count(b"\n") != int(PV.get("PINYIN_OUTPUT_ENTRIES", "-1")): _prov_ok = _flag(0, "pinyin_zh.tsv entry count differs from provenance")
    if b"\r" in _ab: _prov_ok = _flag(0, "pinyin_zh.tsv must use LF newlines only")
else: _prov_ok = _flag(0, f"asset missing {_asset}")
with tempfile.TemporaryDirectory() as _td:
    _o1, _o2 = os.path.join(_td, "a.tsv"), os.path.join(_td, "b.tsv"); _n1, _l1 = os.path.join(_td, "n.txt"), os.path.join(_td, "l.txt")
    _r1 = subprocess.run([sys.executable, "tools/gen_pinyin_dict.py", _o1], capture_output=True, text=True)
    _r2 = subprocess.run([sys.executable, "tools/gen_pinyin_dict.py", _o2], capture_output=True, text=True)
    _r3 = subprocess.run([sys.executable, "tools/gen_pinyin_license_bundle.py", _n1, _l1], capture_output=True, text=True)
    if _r1.returncode or _r2.returncode: _regen_ok = _flag(0, "generator failed: " + (_r1.stderr + _r2.stderr).strip())
    elif open(_o1, "rb").read() != open(_o2, "rb").read(): _regen_ok = _flag(0, "generator is not deterministic (two runs differ)")
    elif not os.path.isfile(_asset) or open(_o1, "rb").read() != open(_asset, "rb").read(): _regen_ok = _flag(0, "checked-in pinyin_zh.tsv is not the byte-identical regeneration from the pinned inputs")
    if _r3.returncode: _lic_ok = _flag(0, "licence bundle generator failed: " + _r3.stderr.strip())
    else:
        if _rd(f"{KBMAIN}/assets/pinyin_zh.NOTICE.txt") != open(_n1, encoding="utf8").read(): _regen_ok = _flag(0, "assets/pinyin_zh.NOTICE.txt is not the deterministic generator output")
        if _rd(f"{KBMAIN}/assets/pinyin_zh.LICENSES.txt") != open(_l1, encoding="utf8").read(): _regen_ok = _flag(0, "assets/pinyin_zh.LICENSES.txt is not the deterministic generator output")
_nt = _rd(f"{KBMAIN}/assets/pinyin_zh.NOTICE.txt")
for must in ("CC-CEDICT", "CC BY-SA 4.0", "Unicode", "Unihan", PV.get("CC_CEDICT_ZIP_SHA256", "x"), PV.get("UNIHAN_ZIP_SHA256", "x"), "Modifications by Sable", "NOT a word", "tones", "deduplicates", "sorts"):
    if must not in _nt: _lic_ok = _flag(0, f"NOTICE must state: {must}")
_lt = _rd(f"{KBMAIN}/assets/pinyin_zh.LICENSES.txt")
if "Creative Commons Attribution-ShareAlike 4.0" not in _lt or "UNICODE LICENSE V3" not in _lt.upper(): _lic_ok = _flag(0, "LICENSES bundle must contain the CC BY-SA 4.0 and Unicode-3.0 texts")
# unit tests of the normalization rules
_ut = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tools", "-p", "test_gen_pinyin_dict.py"], capture_output=True, text=True, cwd=".")
if _ut.returncode != 0: _regen_ok = _flag(0, "tools/test_gen_pinyin_dict.py failed: " + _ut.stderr.strip()[-300:])
print("PINYIN_CORPUS_INPUT_POLICY=" + ("PASS_CLEAR_REDISTRIBUTION_ONLY" if _pol_ok and _inp_ok else "FAIL"))
print("PINYIN_CORPUS_APPROVED_INPUTS=" + ("PASS count=2" if _inp_ok and PV.get("PINYIN_CORPUS_SOURCE_COUNT") == "2" else "FAIL"))
print("PINYIN_CORPUS_UNVERIFIED_INPUTS=" + ("PASS_ZERO" if _unv_ok and _pol_ok else "FAIL"))
print("PINYIN_GENERATOR_PYPINYIN_DEPENDENCY=" + ("PASS_ABSENT" if _py_ok else "FAIL"))
print("PINYIN_GENERATOR_NETWORK_ACCESS=" + ("PASS_FORBIDDEN" if _net_ok else "FAIL"))
print("PINYIN_CORPUS_REGENERATION=" + ("PASS_BYTE_IDENTICAL" if _regen_ok and _prov_ok else "FAIL"))
print("PINYIN_CORPUS_LICENSE_BUNDLE=" + ("PASS_ACTUAL_INPUTS_ONLY" if _lic_ok and _regen_ok else "FAIL"))
print("PINYIN_DICTIONARY_PROVENANCE=" + ("PASS" if _prov_ok and _inp_ok and _pol_ok else "FAIL"))
print("PINYIN_DICTIONARY_LICENSES=" + ("PASS" if _lic_ok else "FAIL") + " PINYIN_LICENSE_REVIEW=" + PV.get("PINYIN_LICENSE_REVIEW", "MISSING"))
print("PINYIN_CORPUS_OFFICIAL_ORIGIN_VERIFIED=" + ",".join(f"{p}:{PV.get(p + '_OFFICIAL_ORIGIN_VERIFIED', 'MISSING')}" for p in ("CC_CEDICT", "UNIHAN")))
_prov_ok = _prov_ok and _inp_ok and _pol_ok
# size bound derived from the accepted corpus
_sz_ok = True
try:
    _n, _b = int(PV["PINYIN_OUTPUT_ENTRIES"]), int(PV["PINYIN_OUTPUT_BYTES"]); _mn, _mb = int(PV["PINYIN_SIZE_MAX_ENTRIES"]), int(PV["PINYIN_SIZE_MAX_BYTES"])
    if not (_n <= _mn <= int(_n * 1.5) and _b <= _mb <= int(_b * 1.5)): _sz_ok = False; err("pinyin size bound must be >= accepted corpus and at most +50% headroom")
    if os.path.isfile(_asset) and (len(_ab) > _mb or _ab.count(b"\n") > _mn): _sz_ok = False; err("pinyin_zh.tsv exceeds its size bound")
    if "headroom" not in open("third_party/pinyin_zh/PROVENANCE.env").read(): _sz_ok = False; err("size bound needs a recorded rationale")
except (KeyError, ValueError): _sz_ok = False; err("pinyin size bound keys missing or malformed")
print("PINYIN_DICTIONARY_SIZE_BOUNDED=" + ("PASS" if _sz_ok else "FAIL"))
# load policy: background thread once; never on main thread; never re-parsed per keystroke
_svc_p = f"{KBMAIN}/java/org/sableos/titan2/keyboard/android/SableImeService.kt"
_svc_src = _strip(_rd(_svc_p))
_main_kt = [f for f in ALL if f.startswith(KBMAIN + "/java/") and f.endswith(".kt")]
_parse_calls = [(f, m.start()) for f in _main_kt for m in re.finditer(r"PinyinDict\.parse\(", _strip(_rd(f)))]
_asset_opens = [f for f in _main_kt for m in re.finditer(r"assets\.open\(\s*\"pinyin_zh\.tsv\"", _strip(_rd(f)))]
_mt_ok = True; _rp_ok = True
if len(_parse_calls) != 1 or _parse_calls[0][0] != _svc_p: _mt_ok = _rp_ok = False; err(f"PinyinDict.parse must be called exactly once, from SableImeService.loadPinyinOnce (found {len(_parse_calls)})")
if _asset_opens != [_svc_p]: _mt_ok = _rp_ok = False; err("pinyin_zh.tsv must be opened exactly once, in SableImeService")
_m = re.search(r"private fun loadPinyinOnce\(\)\s*\{", _svc_src)
if not _m: _mt_ok = _rp_ok = False; err("SableImeService.loadPinyinOnce missing")
else:
    _depth, _i = 1, _m.end()
    while _i < len(_svc_src) and _depth: _depth += {"{": 1, "}": -1}.get(_svc_src[_i], 0); _i += 1
    _body = _svc_src[_m.end():_i]
    if not re.search(r"\bThread\s*\{|\bThread\(", _body) or _body.find("Thread") > _body.find("PinyinDict.parse("): _mt_ok = False; err("PinyinDict.parse must run inside a background Thread in loadPinyinOnce")
    if not re.search(r"if\s*\(\s*pinyinDict\s*!=\s*null\s*\|\|\s*pinyinLoading\s*\)\s*return", _body): _rp_ok = False; err("loadPinyinOnce must return early when the dictionary is loaded or loading")
    if not re.search(r"ui\.post\s*\{", _body): _mt_ok = False; err("loadPinyinOnce must hand the result back via the main-thread handler (ui.post)")
for _mm in re.finditer(r"\bloadPinyinOnce\(\)", _svc_src):
    if _svc_src[max(0, _mm.start() - 4):_mm.start()] == "fun ": continue
    _funs = list(re.finditer(r"\bfun\s+(\w+)", _svc_src[:_mm.start()]))
    if _funs and _funs[-1].group(1) not in ("applyLanguage", "loadPinyinOnce"): _rp_ok = False; err(f"loadPinyinOnce called from {_funs[-1].group(1)} (only applyLanguage may trigger the one-time load)")
_comp = _strip(_rd(f"{KB}/src/main/java/org/sableos/titan2/keyboard/core/Composer.kt"))
if re.search(r"\.parse\(|\bFile\(|readLines|bufferedReader|assets", _comp): _rp_ok = False; err("Composer.kt must not read or parse the dictionary (no per-keystroke reparse)")
for _f in _main_kt:
    if _f.endswith("/KeyboardPrefs.kt"): continue
    if "/android/" in _f and re.search(r"\b(onKeyDown|onKeyUp|softKey)\b[^{]*\{[^}]*PinyinDict\.parse", _strip(_rd(_f))): _rp_ok = False; err(f"{_f}: dictionary parse in a key handler")
print("PINYIN_DICTIONARY_MAIN_THREAD_LOAD=" + ("PASS_FORBIDDEN" if _mt_ok else "FAIL"))
print("PINYIN_DICTIONARY_PER_KEYSTROKE_FULL_REPARSE=" + ("PASS_FORBIDDEN" if _rp_ok else "FAIL"))
# JVM load benchmark evidence (evidence only: never an on-device claim, never a timing threshold)
_ev = env("docs/evidence/pinyin_dictionary_jvm_load_benchmark.env") if os.path.isfile("docs/evidence/pinyin_dictionary_jvm_load_benchmark.env") else {}
_bm_ok = bool(_ev)
for k in ("PINYIN_DICTIONARY_ASSET_BYTES", "PINYIN_DICTIONARY_ENTRY_COUNT", "PINYIN_DICTIONARY_PARSE_MS_MEDIAN", "PINYIN_DICTIONARY_HEAP_DELTA_KIB", "EVIDENCE_HOST_OS", "EVIDENCE_JVM"):
    if not _ev.get(k): _bm_ok = False; err(f"benchmark evidence missing {k}")
if _ev.get("PINYIN_DICTIONARY_ASSET_BYTES") != PV.get("PINYIN_OUTPUT_BYTES") or _ev.get("PINYIN_DICTIONARY_ENTRY_COUNT") != PV.get("PINYIN_OUTPUT_ENTRIES"):
    _bm_ok = False; err("benchmark evidence was captured for a different dictionary than the pinned asset; re-run PinyinDictionaryLoadEvidenceTest")
if _ev.get("ON_DEVICE_LATENCY_CLAIM") != "NO" or _ev.get("THRESHOLD_ASSERTED") != "NO": _bm_ok = False; err("benchmark evidence must state ON_DEVICE_LATENCY_CLAIM=NO and THRESHOLD_ASSERTED=NO")
_bt = _rd(f"{KB}/src/test/java/org/sableos/titan2/keyboard/core/PinyinDictionaryLoadEvidenceTest.kt")
if "PINYIN_DICTIONARY_JVM_LOAD_BENCHMARK=PASS_EVIDENCE_CAPTURED" not in _bt: _bm_ok = False; err("PinyinDictionaryLoadEvidenceTest missing")
if re.search(r"(?m)^\s*assert\w*\(.*(nanoTime|elapsed|\btimes\b|\bsorted\b|lookupUs)", _bt): _bm_ok = False; err("benchmark test must not assert on timings")
print("PINYIN_DICTIONARY_JVM_LOAD_BENCHMARK=" + ("PASS_EVIDENCE_CAPTURED" if _bm_ok else "FAIL"))
# critical-field JVM test coverage (presence; the tests themselves run in the JVM shim / Gradle)
_ct = _rd(f"{KB}/src/test/java/org/sableos/titan2/keyboard/core/CriticalTextEntryTest.kt")
_need = {"text": r"fun textField\w+", "password": r"fun password\w+", "number": r"fun numberField\w+", "numeric password": r"fun numericPassword\w+",
         "phone": r"fun phoneField\w+", "software fallback policy": r"fun softFallback\w+", "composition flush": r"fun flush\w+", "composition backspace": r"fun backspace\w+",
         "alt state": r"fun alt\w+", "sym state": r"fun \w*[Ss]ym\w+"}
_ct_ok = True
for k, pat in _need.items():
    if not re.search(pat, _ct): _ct_ok = False; err(f"CriticalTextEntryTest missing coverage: {k}")
if len(re.findall(r"@Test", _ct)) < 25: _ct_ok = False; err("CriticalTextEntryTest unexpectedly small")
print("CRITICAL_TEXT_ENTRY_TEST_COVERAGE=" + ("PASS" if _ct_ok else "FAIL"))
print("CRITICAL_TEXT_ENTRY_DEVICE_RUNTIME_VALIDATED=NO")
_kl = _rd("docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md")
_k10 = [l for l in _kl.split("\n") if l.startswith("| KL-010 |")]
if not _k10 or "SOURCE_STORAGE_REQUIREMENT=PASS" not in _k10[0] or "DEVICE_RUNTIME_EVIDENCE=PENDING" not in _k10[0]: err("KL-010 must read SOURCE_STORAGE_REQUIREMENT=PASS and DEVICE_RUNTIME_EVIDENCE=PENDING (not deleted)")
for _kid in ("KL-027", "KL-028", "KL-029"):
    if f"| {_kid} |" not in _kl: err(f"{_kid} missing from the known-limitations ledger")
_irl = [l.split("\t") for l in _rd("docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv").split("\n") if l]
_irh = _irl[0]; _irs = {r[0]: dict(zip(_irh, r)) for r in _irl[1:]}
def _ir(i): return "OPEN" if i in _irs and _irs[i].get("status", "").upper().startswith("OPEN") else "NOT_OPEN:" + _irs.get(i, {}).get("status", "MISSING")
for _i in ("IR-004", "IR-005"):
    if _ir(_i) != "OPEN": err(f"{_i} must stay OPEN in D3 (found {_ir(_i)})")
print("IR_004_STATUS=" + _ir("IR-004") + " IR_005_STATUS=" + _ir("IR-005"))

# --- D4: Sable Messages reconciliation (canonical-owned; provider ownership retained; no independent messaging stack) ---
_d4_errs0 = len(errs)
_MB = "docs/C3B_MESSAGES_CANONICAL_BINDING.env"
_mb = {}
for _l in _rd(_MB).split("\n"):
    _l = _l.strip()
    if _l and not _l.startswith("#") and "=" in _l:
        _k, _v = _l.split("=", 1); _mb[_k] = _v
if not _mb: err(f"{_MB} missing or empty")
_MB_REQ = {"C3B_MESSAGES_CANONICAL_REPO": "aimindseye/sableos", "C3B_MESSAGES_CANONICAL_SOURCE_PATH": "apps/r8/android/messages",
           "C3B_MESSAGES_APPLICATION_ID": "org.sableos.messages", "C3B_MESSAGES_PRODUCT_OWNER": "CANONICAL_SABLEOS",
           "C3B_MESSAGES_SOURCE_IMPORTED_INTO_THIS_REPO": "NO", "C3B_MESSAGES_PROVIDER_OWNERSHIP_RETAINED": "YES",
           "C3B_MESSAGES_PROVIDER_SAFE_HANDOFF": "ACTION_SENDTO_smsto", "C3B_MESSAGES_DEFAULT_SMS_ROLE_REQUESTED": "NO",
           "C3B_MESSAGES_SMS_PERMISSIONS_REQUESTED": "NONE", "CUSTOM_SMS_STACK": "NO", "CUSTOM_RCS_STACK": "NO", "CUSTOM_MMS_STACK": "NO",
           "CUSTOM_CARRIER_STACK": "NO", "C3B_MESSAGES_STOCK_MESSAGING_ROLE": "TEMPORARY_RADIO_ENGINEERING_FALLBACK_ONLY",
           "C3B_MESSAGES_STOCK_MESSAGING_IS_FINAL_PRODUCT_DECISION": "NO", "C3B_MESSAGES_DEPENDENCY_DELTA": "NONE",
           "C3B_MESSAGES_DEVICE_RUNTIME_VALIDATED": "NO",
           "C3B_MESSAGES_RUNTIME_DATA_SOURCE": "STATIC_SAMPLE_THREADS", "C3B_MESSAGES_LIVE_THREAD_DATA": "NO",
           "C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH": "NOT_IMPLEMENTED_IN_CANONICAL_MODULE",
           "C3B_MESSAGES_SEND_PATH": "EXTERNAL_PROVIDER_ACTION_SENDTO_SMSTO",
           "C3B_MESSAGES_PRODUCT_STATUS": "UX_HANDOFF_SOURCE_RECONCILED_RUNTIME_DATA_PATH_OPEN"}
_RT_MARKS = ["C3B_MESSAGES_RUNTIME_DATA_SOURCE=STATIC_SAMPLE_THREADS", "C3B_MESSAGES_LIVE_THREAD_DATA=NO",
             "C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH=NOT_IMPLEMENTED_IN_CANONICAL_MODULE", "C3B_MESSAGES_SEND_PATH=EXTERNAL_PROVIDER_ACTION_SENDTO_SMSTO",
             "C3B_MESSAGES_PRODUCT_STATUS=UX_HANDOFF_SOURCE_RECONCILED_RUNTIME_DATA_PATH_OPEN"]
if _mb.get("C3B_MESSAGES_RUNTIME_DATA_REVERIFIED_AT_COMMIT") != _mb.get("C3B_MESSAGES_CANONICAL_COMMIT"):
    err("Messages binding: runtime-data markers are valid only for the commit they were verified at; re-verify and set C3B_MESSAGES_RUNTIME_DATA_REVERIFIED_AT_COMMIT")
for _k, _v in _MB_REQ.items():
    if _mb.get(_k) != _v: err(f"Messages binding: {_k} must be {_v} (found {_mb.get(_k)})")
for _k in ("C3B_MESSAGES_CANONICAL_COMMIT", "C3B_MESSAGES_CANONICAL_LAST_MESSAGES_COMMIT", "C3B_MESSAGES_CANONICAL_PRIOR_PIN"):
    if not re.fullmatch(r"[0-9a-f]{40}", _mb.get(_k, "")): err(f"Messages binding: {_k} must be an exact 40-hex commit")
_blobs = {k: v for k, v in _mb.items() if k.startswith("C3B_MESSAGES_CANONICAL_BLOB_")}
_BLOB_NEED = ["build.gradle.kts", "src/main/AndroidManifest.xml", "src/main/java/org/sableos/messages/MainActivity.kt",
              "src/main/java/org/sableos/messages/MessagesInteractionModel.kt", "src/main/res/drawable/ic_sable_messages.xml"]
for _b in _BLOB_NEED:
    if not re.fullmatch(r"[0-9a-f]{40}", _blobs.get("C3B_MESSAGES_CANONICAL_BLOB_" + _b, "")): err(f"Messages binding: blob id missing or malformed for {_b}")
_msg_row = [r for r in matrix if r["surface_id"] == "messages"]
if len(_msg_row) != 1: err("surface matrix: exactly one messages row required")
else:
    _m = _msg_row[0]
    if _m["provider"] != "CANONICAL_SABLEOS" or _m["module_or_platform_path"] != "sableos:apps/r8/android/messages": err("messages surface must be CANONICAL_SABLEOS sableos:apps/r8/android/messages")
    if "IR-012" not in _m["platform_dependency"]: err("messages surface must reference IR-012")
    if not _m["privilege_requirement"].startswith("none"): err("messages surface must request no privilege")
    for _t in ("648aec14", "CUSTOM_SMS_STACK=NO", "CUSTOM_RCS_STACK=NO", "CUSTOM_MMS_STACK=NO", "temporary radio-focused engineering fallback", "not the integrated-product decision"):
        if _t not in _m["notes"]: err(f"messages surface notes must contain: {_t}")
    if _m["c3b_integrated_candidate_blocking"] != "YES": err("messages surface must stay blocking for the integrated candidate")
    for _t in _RT_MARKS:
        if _t not in _m["notes"]: err(f"messages surface notes must state the runtime data truth: {_t}")
    if _m["notes"].find("648aec14") >= 0 and not _mb.get("C3B_MESSAGES_CANONICAL_COMMIT", "").startswith("648aec14"): err("messages surface notes cite a different canonical commit than the binding")
_mm = [r for r in mods if r["module_id"] == "SableMessages"]
if len(_mm) != 1: err("source modules: exactly one SableMessages row required")
else:
    _r = _mm[0]
    if _r["application_id"] != "org.sableos.messages" or _r["canonical_integration_status"] != "CANONICAL_OWNED_SOURCE_NOT_IMPORTED" or _r["prototype_status"] != "CANONICAL_OWNED_NOT_IMPORTED": err("SableMessages module row must be canonical-owned and not imported")
    if not _r["source_path"].startswith("sableos:"): err("SableMessages source_path must name the canonical repository, not a local path")
    if not _r["privilege_requirement"].startswith("none"): err("SableMessages must request no privilege")
    if "IR-012" not in _r["platform_dependency"]: err("SableMessages must reference IR-012")
    if "C3B_MESSAGES_LIVE_THREAD_DATA=NO" not in _r["notes"]: err("SableMessages module notes must state C3B_MESSAGES_LIVE_THREAD_DATA=NO")
if any(r["source_path"].startswith("sableos:") and r["module_id"] != "SableMessages" for r in mods): err("only SableMessages may use a canonical (sableos:) source path in the modules manifest")
if _ir("IR-012") != "OPEN": err(f"IR-012 must be OPEN (found {_ir('IR-012')})")
_i12 = _irs.get("IR-012", {})
if _i12.get("blocking") != "YES": err("IR-012 must stay blocking")
if "STATIC_SAMPLE_THREADS" not in _i12.get("reason", "") or "runtime data" not in _i12.get("capability", "").lower() or "provider integration" not in _i12.get("capability", "").lower(): err("IR-012 must name the unresolved canonical runtime data and provider integration")
if "SMS" in _i12.get("privileged_api_needed", "") or not _i12.get("privileged_api_needed", "").startswith("none"): err("IR-012 must not request a privileged API")
_k8 = [l for l in _kl.split("\n") if l.startswith("| KL-008 |")]
if len(_k8) != 1 or "CANONICAL_SABLEOS" not in _k8[0] or "temporary radio-focused engineering fallback" not in _k8[0] or "C3B_MESSAGES_DEVICE_RUNTIME_VALIDATED=NO" not in _k8[0]: err("KL-008 must state the canonical Sable Messages ownership, the temporary fallback wording and device validation NO")
if _k8 and _k8[0].split("|")[4].strip() != "yes": err("KL-008 must stay blocking")
for _t in _RT_MARKS:
    if _k8 and _t not in _k8[0]: err(f"KL-008 must state the runtime data truth: {_t}")
if _k8 and re.search(r"temporary default|until Sable Messages is reconciled", _k8[0]): err("KL-008 still describes stock Messaging as the default / Sable Messages as unreconciled")
_PROD_DOCS = [f for f in ALL if re.match(r"docs/C3B_(PRODUCT_|MESSAGES_|PLATFORM_|HUB_|D6_)", f) or f == "README.md"]
_STOCK_FINAL = re.compile(r"stock\s+(AOSP\s+)?Messaging[^.\n|]{0,60}\b(is|as|remains|stays)\b[^.\n|]{0,20}\b(the\s+)?(final|default|selected|chosen|intended|integrated)\b", re.I)
for _f in _PROD_DOCS:
    _t = _rd(_f)
    for _m2 in _STOCK_FINAL.finditer(_t):
        _ctx = _t[max(0, _m2.start() - 40):_m2.end() + 10]
        if not re.search(r"\b(not|never|no)\b", _t[max(0, _m2.start() - 30):_m2.end()], re.I): err(f"{_f}: stock Messaging described as the final/default product choice: {_m2.group(0)[:80]}")
    if re.search(r"STOCK_MESSAGING_IS_FINAL_PRODUCT_DECISION=YES|FINAL_MESSAGING=stock|MESSAGES_PRODUCT_OWNER=(?!CANONICAL_SABLEOS)\w+", _t): err(f"{_f}: stock Messaging selected as final product decision")
_RT_BAD = re.compile(r"C3B_MESSAGES_LIVE_THREAD_DATA=(?!NO\b)|C3B_MESSAGES_RUNTIME_DATA_SOURCE=(?!STATIC_SAMPLE_THREADS\b)|C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH=(?!NOT_IMPLEMENTED_IN_CANONICAL_MODULE\b)|C3B_MESSAGES_SEND_PATH=(?!EXTERNAL_PROVIDER_ACTION_SENDTO_SMSTO\b)|C3B_MESSAGES_PRODUCT_STATUS=(?!UX_HANDOFF_SOURCE_RECONCILED_RUNTIME_DATA_PATH_OPEN\b)")
_LIVE_CLAIM = re.compile(r"\b(live\s+(SMS|MMS|RCS|conversations?|threads?|messages?|messaging)|real[- ]time\s+(conversations?|threads?|messages?)|"
    r"(receives?|receiving|displays?|shows?|lists?|syncs?|imports?|reads?|loads?)\s+(real|incoming|live|actual|provider|stored)\b[\w\s-]{0,25}(SMS|MMS|messages?|threads?|conversations?)|"
    r"incoming[- ]messages?\s+(support|delivery|handling|receiv\w*|reception|path)|(supports?|provides?|implements?|has)\s+(live|incoming)\b|"
    r"(fully\s+)?(functional|usable|working)\s+(SMS|MMS|messaging|conversation)\w*)", re.I)
_LIVE_NEG = re.compile(r"\b(no|not|nothing|never|without|until|cannot|can't|open|unresolved|pending|needed|needs?|requires?|required|must|future|once|none|nor|before|unless|neither|instead of|rather than|turns?|into)\b|=NO\b|NOT_IMPLEMENTED|STATIC_SAMPLE", re.I)
for _f in _PROD_DOCS:
    _t = _rd(_f)
    for _mk in _RT_BAD.finditer(_t): err(f"{_f}: Messages runtime-data marker contradicts the pinned canonical source: {_mk.group(0)}")
    for _sent in re.split(r"(?<=[.|])\s+|\t|\n\s*\n", _t):
        _cm = _LIVE_CLAIM.search(_sent)
        if _cm and not _LIVE_NEG.search(_sent): err(f"{_f}: Messages live-conversation / incoming-message claim while the pinned canonical module uses STATIC_SAMPLE_THREADS: {_sent.strip()[:90]}")
_IMPORTED = [f for f in ALL if re.search(r"(^|/)org/sableos/hub/|^apps/[^/]+/(android/)?hub/|(^|/)org/sableos/messages/|^apps/[^/]+/(android/)?messages/|(^|/)MessagesInteractionModel", f)]
for _f in _IMPORTED: err(f"canonical Sable Messages source must not be copied into this repository: {_f}")
_SCAN = [f for f in ALL if re.search(r"\.(kt|java|xml|bp|mk|kts|gradle|toml|sh|py|properties)$", f) and not re.match(r"(docs/|build/titan2/|third_party/|tools/)", f)]
_FORBID = re.compile(
    r"android\.permission\.(SEND_SMS|READ_SMS|RECEIVE_SMS|WRITE_SMS|RECEIVE_MMS|RECEIVE_WAP_PUSH|BROADCAST_SMS|BROADCAST_WAP_PUSH|SEND_RESPOND_VIA_MESSAGE|"
    r"SEND_SMS_NO_CONFIRMATION|BIND_CARRIER_SERVICES|BIND_CARRIER_MESSAGING_SERVICE|BIND_CARRIER_MESSAGING_CLIENT_SERVICE|MODIFY_PHONE_STATE|"
    r"READ_PRIVILEGED_PHONE_STATE|WRITE_APN_SETTINGS|BIND_IMS_SERVICE|BIND_TELEPHONY_NETWORK_SERVICE|PERFORM_IMS_SINGLE_REGISTRATION|MANAGE_ROLE_HOLDERS)"
    r"|\bSmsManager\b|\bSmsMessage\b|\bMmsManager\b|\bSmsCbMessage\b|\bCarrierMessagingService\b|\bCarrierMessagingServiceWrapper\b|android\.service\.carrier"
    r"|android\.telephony\.ims|\bImsMmTelManager\b|\bImsManager\b|\bImsRcsManager\b|\bRcsManager\b|\bApnSetting\b|Telephony\.Carriers|\bTelephonyManager\.(setDataEnabled|setPreferredNetworkType)"
    r"|content://(sms|mms|mms-sms)|Telephony\.(Mms|Threads)\b|Telephony\.Sms\.(CONTENT_URI|Inbox|Sent|Outbox|Draft|Conversations)|Telephony\.Sms\.Intents"
    r"|android\.provider\.Telephony\.(SMS_DELIVER|SMS_RECEIVED|WAP_PUSH_DELIVER|WAP_PUSH_RECEIVED)|android\.intent\.action\.RESPOND_VIA_MESSAGE|android\.telephony\.(SmsManager|mbms)"
    r"|RoleManager\.ROLE_SMS|android\.app\.role\.SMS")
for _f in _SCAN:
    _t = _rd(_f)
    _mt = _FORBID.search(_t)
    if _mt: err(f"{_f}: SMS/MMS/RCS/telephony/carrier/IMS/APN transport, privileged permission or role use is outside the product lane: {_mt.group(0)}")
    if re.search(r"PRODUCT_PACKAGES[^\n]*\b(Messaging|MmsService|messaging|Mms)\b", _t): err(f"{_f}: product package list selects stock Messaging/MmsService")
    if re.search(r"(implementation|api|compileOnly|runtimeOnly|kapt|ksp|testImplementation)\s*\(?[^\n]*(\bsms\b|\bmms\b|telephony|messaging|libphonenumber|klinker|:messages\b)", _t, re.I) and _f.endswith((".kts", ".gradle", ".toml", ".bp", ".mk")):
        err(f"{_f}: messaging/telephony dependency is not declared in the D4 dependency delta (NONE)")
print("C3B_MESSAGES_PRODUCT_OWNER=" + _mb.get("C3B_MESSAGES_PRODUCT_OWNER", "MISSING") + " C3B_MESSAGES_CANONICAL_COMMIT=" + _mb.get("C3B_MESSAGES_CANONICAL_COMMIT", "MISSING"))
print("C3B_MESSAGES_SOURCE_IMPORTED=" + ("YES" if _IMPORTED else "NO") + " C3B_MESSAGES_DEPENDENCY_DELTA=" + _mb.get("C3B_MESSAGES_DEPENDENCY_DELTA", "MISSING") + " CUSTOM_SMS_STACK=NO CUSTOM_RCS_STACK=NO CUSTOM_MMS_STACK=NO")
print("C3B_MESSAGES_RECONCILIATION_SOURCE_CONTRACT=" + ("PASS" if len(errs) == _d4_errs0 else "FAIL"))
print("C3B_MESSAGES_RUNTIME_DATA_SOURCE=" + _mb.get("C3B_MESSAGES_RUNTIME_DATA_SOURCE", "MISSING") + " C3B_MESSAGES_LIVE_THREAD_DATA=" + _mb.get("C3B_MESSAGES_LIVE_THREAD_DATA", "MISSING"))
print("C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH=" + _mb.get("C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH", "MISSING") + " C3B_MESSAGES_SEND_PATH=" + _mb.get("C3B_MESSAGES_SEND_PATH", "MISSING"))
print("C3B_MESSAGES_PRODUCT_STATUS=" + _mb.get("C3B_MESSAGES_PRODUCT_STATUS", "MISSING"))
print("C3B_MESSAGES_DEVICE_RUNTIME_VALIDATED=NO")

# --- D4: Sable Hub / Connected Apps parity contract (canonical-owned; contract only) ---
_d4h_errs0 = len(errs)
_HB = "docs/C3B_HUB_PARITY.env"
_hb = {}
for _l in _rd(_HB).split("\n"):
    _l = _l.strip()
    if _l and not _l.startswith("#") and "=" in _l:
        _k, _v = _l.split("=", 1); _hb[_k] = _v
if not _hb: err(f"{_HB} missing or empty")
_HB_REQ = {"C3B_HUB_CANONICAL_REPO": "aimindseye/sableos", "C3B_HUB_CANONICAL_PATH": "apps/r8/android/hub", "C3B_HUB_CANONICAL_OWNER": "CANONICAL_SABLEOS",
           "C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED": "YES", "C3B_HUB_CONNECTED_APPS": "REQUIRED", "C3B_HUB_GENERIC_NOTIFICATION_ADAPTER": "REQUIRED",
           "C3B_HUB_REMOTEINPUT_REPLY": "REQUIRED", "C3B_HUB_OPEN_APP_FALLBACK": "REQUIRED", "C3B_HUB_PACKAGE_USER_POLICY": "REQUIRED",
           "C3B_HUB_LOCAL_BOUNDED_HISTORY": "REQUIRED", "C3B_HUB_DYNAMIC_PROVIDER_DISCOVERY": "REQUIRED", "C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST": "NO",
           "C3B_HUB_PRIVATE_PROVIDER_PROTOCOLS": "NO", "C3B_HUB_PROVIDER_CREDENTIALS": "NO", "C3B_HUB_PRIVATE_DATABASE_SCRAPING": "NO", "C3B_HUB_PROVIDER_WEBVIEWS": "NO",
           "C3B_HUB_SOURCE_IMPORTED_INTO_THIS_REPO": "NO", "SABLE_MESSAGES_AND_SABLE_HUB_ARE_SEPARATE_PRODUCT_SURFACES": "YES", "D4_MESSAGES_REPLACES_SABLE_HUB": "NO",
           "D4_MESSAGES_WEAKENS_CONNECTED_APPS": "NO", "C3B_HUB_DEVICE_RUNTIME_VALIDATED": "NO",
           "C3B_HUB_EVIDENCE_SIGNAL": "NOTIFICATION_INGESTION_CONVERSATION_RENDERING_SOURCE_AUTHORIZED_REMOTEINPUT_REPLY_PHYSICALLY_WORKED",
           "C3B_HUB_EVIDENCE_WHATSAPP": "NOTIFICATION_INGESTION_RENDERING_PHYSICALLY_WORKED_REPLY_HANDLE_RETENTION_REMEDIATION_FINAL_QUALIFICATION_PENDING",
           "C3B_HUB_EVIDENCE_LINKEDIN": "NOTIFICATION_INGESTION_OPEN_APP_FALLBACK_PHYSICALLY_WORKED_NO_QUICK_REPLY_SURFACE_EXPOSED",
           "C3B_HUB_EVIDENCE_TELEGRAM": "INSTALLATION_WORKED_ACCOUNT_RUNTIME_CONVERSATION_QUALIFICATION_NOT_COMPLETED"}
for _k, _v in _HB_REQ.items():
    if _hb.get(_k) != _v: err(f"Hub parity: {_k} must be {_v} (found {_hb.get(_k)})")
if not re.fullmatch(r"[0-9a-f]{40}", _hb.get("C3B_HUB_CANONICAL_COMMIT", "")): err("Hub parity: C3B_HUB_CANONICAL_COMMIT must be an exact 40-hex commit")
_HUB_BLOB_NEED = ["ConnectedAppsInventory.kt", "ConnectedAppsRepository.kt", "ConnectedNotificationHistoryStore.kt", "notifications/ConnectedNotificationNormalizer.kt",
                  "notifications/ConnectedReplyRegistry.kt", "notifications/SableNotificationListenerService.kt"]
for _b in _HUB_BLOB_NEED:
    if not re.fullmatch(r"[0-9a-f]{40}", _hb.get("C3B_HUB_CANONICAL_BLOB_src/main/java/org/sableos/hub/" + _b, "")): err(f"Hub parity: canonical blob id missing or malformed for {_b}")
_hub_row = [r for r in matrix if r["surface_id"] == "sable_hub"]
if len(_hub_row) != 1: err("surface matrix: exactly one sable_hub row required")
else:
    _h = _hub_row[0]
    if _h["provider"] != "CANONICAL_SABLEOS" or _h["module_or_platform_path"] != "sableos:apps/r8/android/hub": err("sable_hub surface must be CANONICAL_SABLEOS sableos:apps/r8/android/hub")
    if _h["c3b_integrated_candidate_blocking"] != "YES": err("sable_hub must be blocking for the integrated candidate")
    if "IR-013" not in _h["platform_dependency"]: err("sable_hub surface must reference IR-013")
    for _t in ("C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED=YES", "device runtime validation pending", "C3B_HUB_DEVICE_RUNTIME_VALIDATED=NO", "Sable Messages does not replace, subsume, disable or weaken Sable Hub"):
        if _t not in _h["notes"]: err(f"sable_hub surface notes must contain: {_t}")
    if "makes no claim" in _h["notes"]: err("sable_hub surface must not say the product lane makes no claim")
_i13 = _irs.get("IR-013", {})
if _ir("IR-013") != "OPEN": err(f"IR-013 must be OPEN (found {_ir('IR-013')})")
if _i13.get("blocking") != "YES": err("IR-013 must be blocking")
if "Connected Apps" not in _i13.get("capability", "") or "Panther V1" not in _i13.get("capability", ""): err("IR-013 must own canonical Hub admission and Panther V1 Connected Apps semantics")
if not _i13.get("privileged_api_needed", "").startswith("none") or re.search(r"credential|private", _i13.get("privileged_api_needed", "").replace("no provider-specific private API", "").replace("no provider credentials", ""), re.I): err("IR-013 must not request a provider-specific private API, broader Hub privilege or credentials")
_k30 = [l for l in _kl.split("\n") if l.startswith("| KL-030 |")]
if len(_k30) != 1: err("KL-030 (Hub parity) missing")
else:
    if _k30[0].split("|")[4].strip() != "yes": err("KL-030 must stay blocking")
    for _t in ("C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED=YES", "C3B_HUB_DEVICE_RUNTIME_VALIDATED=NO", "IR-013"):
        if _t not in _k30[0]: err(f"KL-030 must contain: {_t}")
_hubdoc = _rd("docs/C3B_HUB_PARITY.md"); _recon = _rd("docs/C3B_MESSAGES_RECONCILIATION.md")
for _k, _v in _HB_REQ.items():
    if _k.startswith(("C3B_HUB_", "SABLE_MESSAGES_AND", "D4_MESSAGES")) and not _k.startswith(("C3B_HUB_CANONICAL_REPO", "C3B_HUB_CANONICAL_PATH", "C3B_HUB_SOURCE_IMPORTED", "C3B_HUB_EVIDENCE")) and f"{_k}={_v}" not in _hubdoc: err(f"docs/C3B_HUB_PARITY.md must state {_k}={_v}")
for _k in ("SABLE_MESSAGES_AND_SABLE_HUB_ARE_SEPARATE_PRODUCT_SURFACES=YES", "D4_MESSAGES_REPLACES_SABLE_HUB=NO", "D4_MESSAGES_WEAKENS_CONNECTED_APPS=NO"):
    if _k not in _recon: err(f"docs/C3B_MESSAGES_RECONCILIATION.md must state {_k}")
for _ev in ("Signal", "WhatsApp", "LinkedIn", "Telegram"):
    if _ev not in _hubdoc: err(f"docs/C3B_HUB_PARITY.md must record the Panther evidence level for {_ev}")
_HUB_MARK = re.compile(r"\b(C3B_HUB_(?!CANONICAL_REPO|CANONICAL_PATH)[A-Z0-9_]+|SABLE_MESSAGES_AND_SABLE_HUB_ARE_SEPARATE_PRODUCT_SURFACES|D4_MESSAGES_[A-Z_]+)=([A-Za-z0-9_]+)")
_HUB_REPL = re.compile(r"\b(Sable\s+)?Messages?\b[^.|\n]{0,60}\b(replaces?|replacing|subsum\w+|disables?|disabling|supersedes?|superseding|weakens?|obsoletes?|retires?|removes?|takes?\s+over|instead\s+of)\b[^.|\n]{0,40}\b(Sable\s+)?(Hub|Connected\s+Apps)\b"
                       r"|\b(Sable\s+)?(Hub|Connected\s+Apps)\b[^.|\n]{0,40}\b(is|are|was|were|becomes?|gets?)\s+(replaced|subsumed|superseded|disabled|retired|obsolete|weakened|removed)\b", re.I)
_HUB_NEG = re.compile(r"\b(no|not|never|without|nor|neither|cannot|can't|nothing|unaffected)\b|=NO\b", re.I)
_PROV_EV = [(re.compile(r"Telegram", re.I), re.compile(r"physically|qualified|validated|verified|conversations?\s+(worked|render)|reply\s+(worked|supported)|ingestion\s+worked", re.I), re.compile(r"\b(not|never|incomplete|pending|no|without)\b|NOT_COMPLETED", re.I)),
            (re.compile(r"WhatsApp", re.I), re.compile(r"(reply|RemoteInput)[^\n]{0,60}(worked|validated|qualified|verified|supported|retained)|(worked|validated|qualified|verified|supported)[^\n]{0,60}(reply|RemoteInput)", re.I), re.compile(r"remediation|pending|\b(not|never|until)\b", re.I)),
            (re.compile(r"LinkedIn", re.I), re.compile(r"(quick[- ]reply|RemoteInput|reply)[^\n]{0,40}(worked|supported|available|exposed|validated)|(worked|supported|available|validated)[^\n]{0,40}(quick[- ]reply|RemoteInput)", re.I), re.compile(r"\b(no|not|never|without)\b", re.I)),
            (re.compile(r"Signal|WhatsApp|LinkedIn|Telegram", re.I), re.compile(r"Titan[^\n]{0,80}(physically|validated|qualified|worked|verified)|(physically|validated|qualified|worked|verified)[^\n]{0,80}Titan", re.I), re.compile(r"\b(not|never|no|pending|unqualified|until|without|remains?)\b|=NO\b|Panther", re.I))]
for _f in _PROD_DOCS:
    _t = _rd(_f)
    for _mk in _HUB_MARK.finditer(_t):
        _exp = _hb.get(_mk.group(1), _HB_REQ.get(_mk.group(1)))
        if _exp is not None and _mk.group(2) != _exp: err(f"{_f}: Hub marker contradicts the recorded contract: {_mk.group(0)[:90]}")
    for _sent in re.split(r"(?<=[.])\s+|\t|\n\s*\n", _t):
        if _HUB_REPL.search(_sent) and not _HUB_NEG.search(_sent): err(f"{_f}: claims Sable Messages replaces/subsumes/disables/weakens Sable Hub or Connected Apps: {_sent.strip()[:90]}")
    for _line in re.split(r"\t|\n", re.sub(r"C3B_HUB_EVIDENCE_[A-Z]+=[A-Z_]+", "", _t)):
        for _pn, _cl, _ng in _PROV_EV:
            if _pn.search(_line) and _cl.search(_line) and not _ng.search(_line): err(f"{_f}: Hub provider evidence inflated beyond the recorded Panther state: {_line.strip()[:90]}")
for _f in _SCAN:
    _mt = re.search(r"com\.whatsapp|org\.thoughtcrime\.securesms|org\.telegram\.messenger|com\.linkedin\.android|org\.signal\b", _rd(_f))
    if _mt: err(f"{_f}: hard-coded provider package handling is forbidden (Connected Apps must stay provider-generic): {_mt.group(0)}")
print("C3B_HUB_CANONICAL_OWNER=" + _hb.get("C3B_HUB_CANONICAL_OWNER", "MISSING") + " C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED=" + _hb.get("C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED", "MISSING") + " C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST=" + _hb.get("C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST", "MISSING"))
print("C3B_HUB_SOURCE_IMPORTED=" + ("YES" if _hb.get("C3B_HUB_SOURCE_IMPORTED_INTO_THIS_REPO") != "NO" or any(re.search(r"(^|/)org/sableos/hub/|^apps/[^/]+/(android/)?hub/", f) for f in ALL) else "NO"))
print("C3B_HUB_PARITY_CONTRACT=" + ("PASS" if len(errs) == _d4h_errs0 else "FAIL"))
print("C3B_HUB_DEVICE_RUNTIME_VALIDATED=" + _hb.get("C3B_HUB_DEVICE_RUNTIME_VALIDATED", "MISSING"))

# --- D5 first-party icons (source/provenance evidence; canonical gate is not touched) ---
PHD = "third_party/phosphor-icons"
ICON_MODULES = {"setup": "ic_sable_setup", "radiodiag": "ic_sable_radiodiag", "keyboard": "ic_sable_keyboard", "camera": "ic_sable_camera", "displaycompat": "ic_sable_displaycompat"}
_src_ok = _lang_ok = _wire_ok = _prov_ok2 = True
def _ierr(flag, msg):
    err("icons: " + msg); return False
_pm = _rd(f"{PHD}/PROVENANCE.md"); _lic = _rd(f"{PHD}/LICENSE")
if "2b75f3ad12b420c9504ef05df8d2564a28f8500e" not in _pm or "https://github.com/phosphor-icons/core" not in _pm: _src_ok = _ierr(0, "Phosphor repo URL/commit pin missing from PROVENANCE.md")
if "MIT" not in _pm or not _lic.startswith("MIT License") or "Phosphor Icons" not in _lic: _src_ok = _ierr(0, "Phosphor MIT licence text/provenance missing")
if hashlib.sha256(_lic.encode()).hexdigest() != "b5b1f1da112d18ea2147decfd48ddc1bf2b5aeb6c265381579340e95b15a2bb2": _src_ok = _ierr(0, "Phosphor LICENSE differs from the pinned upstream text")
if "0fb3505bcb69b9ee5ba2bfc88cbb724148947291" not in _pm: _prov_ok2 = _ierr(0, "canonical contract blob not recorded in PROVENANCE.md")
_man = [l.split("\t") for l in _rd(f"{PHD}/ICON_MANIFEST.tsv").strip().split("\n") if l]
_mh = _man[0] if _man else []; _mrows = {r[0]: dict(zip(_mh, r)) for r in _man[1:]}
if set(_mrows) != set(ICON_MODULES): _prov_ok2 = _ierr(0, f"ICON_MANIFEST.tsv modules {sorted(_mrows)} != required {sorted(ICON_MODULES)}")
for _m, _d in ICON_MODULES.items():
    _r = _mrows.get(_m)
    if not _r: continue
    if _r.get("drawable") != _d: _prov_ok2 = _ierr(0, f"{_m}: manifest drawable must be {_d}")
    _g = f"{PHD}/glyphs/{_r.get('glyph')}.svg"
    if not os.path.isfile(_g): _prov_ok2 = _ierr(0, f"{_m}: pinned glyph file missing {_g}")
    elif hashlib.sha256(open(_g, "rb").read()).hexdigest() != _r.get("glyph_svg_sha256"): _prov_ok2 = _ierr(0, f"{_m}: glyph sha256 differs from manifest")
    if not re.match(r"^#[0-9A-F]{6}$", _r.get("accent", "")): _prov_ok2 = _ierr(0, f"{_m}: accent must be #RRGGBB")
    if _r.get("origin") not in ("NEW_TITAN_GLYPH_PHOSPHOR_REGULAR", "PORTED_PANTHER_IDENTITY"): _prov_ok2 = _ierr(0, f"{_m}: origin not recorded")
_accents = [r.get("accent") for r in _mrows.values()]
if len(set(_accents)) != len(_accents): _lang_ok = _ierr(0, "per-app accents must be distinct")
_g_run = subprocess.run([sys.executable, "tools/gen_first_party_icons.py", "--check"], capture_output=True, text=True)
if _g_run.returncode != 0: _lang_ok = _ierr(0, "drawables differ from tools/gen_first_party_icons.py output: " + (_g_run.stdout + _g_run.stderr).strip().replace("\n", "; "))
for _m, _d in ICON_MODULES.items():
    _mp = f"apps/titan2/platform/{_m}/src/main/AndroidManifest.xml"; _dp = f"apps/titan2/platform/{_m}/src/main/res/drawable/{_d}.xml"
    _mt = re.sub(r"(?s)<!--.*?-->", "", _rd(_mp))
    if f'android:icon="@drawable/{_d}"' not in _mt: _wire_ok = _ierr(0, f"{_m}: manifest missing android:icon=@drawable/{_d}")
    if f'android:roundIcon="@drawable/{_d}"' not in _mt: _wire_ok = _ierr(0, f"{_m}: manifest missing android:roundIcon=@drawable/{_d}")
    if not os.path.isfile(_dp): _wire_ok = _ierr(0, f"{_m}: icon asset missing {_dp}"); continue
    _x = _rd(_dp)
    for _tok in ('android:viewportWidth="256"', 'android:viewportHeight="256"', 'android:fillColor="#161C24"', 'android:fillColor="#F7F9FC"', 'android:pathData="M28,226h200v6H28z"', 'android:scaleX="0.70"'):
        if _tok not in _x: _lang_ok = _ierr(0, f"{_m}: viewport/language contract violated, missing {_tok}")
    _acc = _mrows.get(_m, {}).get("accent", "")
    if _acc and f'android:fillColor="{_acc}"' not in _x: _lang_ok = _ierr(0, f"{_m}: accent rail colour {_acc} missing")
_smf = _rd("apps/titan2/screens/app/src/main/AndroidManifest.xml")
if re.search(r"android:(icon|roundIcon)=\"@drawable/ic_sable_", _smf): _wire_ok = _ierr(0, "SableScreens (PROTOTYPE_ONLY) must not reuse a product icon; its catalog icon is not a product icon")
_irl2 = [l.split("\t") for l in _rd("docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv").split("\n") if l]
_ir10 = [dict(zip(_irl2[0], r)) for r in _irl2[1:] if r[0] == "IR-010"]
_ir10_ok = bool(_ir10) and _ir10[0].get("status", "").upper().startswith("OPEN")
if not _ir10_ok: err("IR-010 must stay OPEN (canonical gate wiring pending)")
if not os.path.isfile("docs/C3B_PRODUCT_ICON_CONTRACT.md") or "SOURCE_READY_CANONICAL_GATE_PENDING" not in _rd("docs/C3B_PRODUCT_ICON_CONTRACT.md"): err("docs/C3B_PRODUCT_ICON_CONTRACT.md missing or wrong status")
print("C3B_FIRST_PARTY_ICON_SOURCE=" + ("PASS_PHOSPHOR_PINNED_MIT" if _src_ok else "FAIL"))
print("C3B_FIRST_PARTY_ICON_LANGUAGE=" + ("PASS" if _lang_ok else "FAIL"))
print("C3B_PRODUCT_ICON_MANIFEST_WIRING=" + ("PASS_5" if _wire_ok else "FAIL"))
print("C3B_PRODUCT_ICON_PROVENANCE=" + ("PASS" if _prov_ok2 and _src_ok else "FAIL"))
print("C3B_TITAN_SPECIFIC_REPLACEMENT_ICON_FAMILY_ALLOWED=NO")
print("C3B_PRODUCT_ICON_CONTRACT_STATUS=SOURCE_READY_CANONICAL_GATE_PENDING")
print("IR_010_STATUS=" + ("OPEN_CANONICAL_GATE_PENDING" if _ir10_ok else "NOT_OPEN"))

# --- D6: RadioDiag + DisplayCompat source hardening (read-only radio; fail-closed enforcement reporting) ---
_d6_errs0 = len(errs)
_D6 = "docs/C3B_D6_HARDENING.md"
_d6t = _rd(_D6)
_D6_REQ = {"D6_RADIODIAG_READ_ONLY": "YES", "D6_RADIODIAG_IMS_REGISTRATION": "NOT_VISIBLE", "D6_RADIODIAG_PRIVILEGED_PERMISSIONS": "NONE",
           "D6_RADIODIAG_EVIDENCE_LEVEL": "PUBLIC_READ_ONLY_APP_STATE", "D6_DISPLAYCOMPAT_FAIL_CLOSED": "YES",
           "D6_DISPLAYCOMPAT_STORED_IS_NOT_ENFORCED": "YES", "D6_DISPLAYCOMPAT_STRONGEST_CLAIM": "PLATFORM_CALL_ACCEPTED_UNVERIFIED",
           "D6_DISPLAYCOMPAT_MINI_MODE_IMPLEMENTED": "NO", "D6_DISPLAYCOMPAT_NEW_HIDDEN_API": "NO", "D6_DEPENDENCY_DELTA": "NONE",
           "D6_DEVICE_RUNTIME_VALIDATED": "NO", "IR_006_STATUS": "OPEN_CANONICAL", "IR_007_STATUS": "OPEN_CANONICAL",
           "KL_013_STATUS": "OPEN_CANONICAL", "KL_015_STATUS": "OPEN_CANONICAL", "KL_023_STATUS": "OPEN_CANONICAL"}
if not _d6t: err(f"{_D6} missing")
for _k, _v in _D6_REQ.items():
    if f"{_k}={_v}" not in _d6t: err(f"{_D6} must state {_k}={_v}")
for _f in _PROD_DOCS + [_D6]:
    for _mk in re.finditer(r"\b(D6_[A-Z0-9_]+|IR_00[67]_STATUS|KL_0(?:13|15|23)_STATUS)=([A-Za-z0-9_]+)", _rd(_f)):
        if _mk.group(1) in _D6_REQ and _mk.group(2) != _D6_REQ[_mk.group(1)]: err(f"{_f}: D6 marker contradicts the contract: {_mk.group(0)}")
for _i, _tag in (("IR-006", "IR-006"), ("IR-007", "IR-007")):
    if _ir(_i) != "OPEN": err(f"{_i} must stay OPEN and canonical-owned in D6 (found {_ir(_i)})")
    if "canonical" not in _irs.get(_i, {}).get("system_component_owner", "").lower(): err(f"{_i} must stay canonical-owned")
for _kid in ("KL-013", "KL-015", "KL-023", "KL-031"):
    if f"| {_kid} |" not in _kl: err(f"{_kid} missing from the known-limitations ledger")
for _kid in ("KL-013", "KL-015", "KL-023"):
    _kr = [l for l in _kl.split("\n") if l.startswith(f"| {_kid} |")]
    if _kr and "canonical lane" not in _kr[0]: err(f"{_kid} must stay canonical-owned")
_PL = "apps/titan2/platform"
_RD, _DC = f"{_PL}/radiodiag/src", f"{_PL}/displaycompat/src"
def _d6_perms(manifest): return sorted(re.findall(r'<uses-permission[^>]*android:name="([^"]+)"', _rd(manifest)))
if _d6_perms(f"{_RD}/main/AndroidManifest.xml") != ["android.permission.READ_BASIC_PHONE_STATE"]: err("RadioDiag must request exactly READ_BASIC_PHONE_STATE and no privileged permission")
if _d6_perms(f"{_DC}/main/AndroidManifest.xml"): err("DisplayCompat must request no permission")
_RDK = f"{_RD}/main/java/org/sableos/titan2/radiodiag"
_rr, _rg, _ra = _rd(f"{_RDK}/core/RadioReport.kt"), _rd(f"{_RDK}/core/Reading.kt"), _rd(f"{_RDK}/android/RadioActivity.kt")
for _s in ("NeedsPermission", "Unavailable", "NotSupported", "Unknown", "Value"):
    if not re.search(r"\b" + _s + r"\b", _rg): err(f"RadioDiag Reading must model the state {_s}")
for _s in ("PUBLIC_READ_ONLY_APP_STATE", "NOT_VISIBLE", "IR-007", "NOT_PROVIDED_BY_THIS_APP"):
    if _s not in _rr: err(f"RadioReport must always state {_s}")
if "limits()" not in _rr.split("fun render", 1)[-1]: err("RadioReport.render must always append the limits block")
if "!!" in _strip(_ra): err("RadioActivity must not use the non-null assertion (a missing TelephonyManager must be a reported state)")
if "Reading.Unavailable" not in _ra or "readDataNetworkType" not in _ra: err("RadioActivity must report unavailable states through Reading")
if re.search(r"\.(setDataEnabled|setPreferredNetworkType|setNetworkSelection\w*|setRadioPower|iccTransmit\w*|sendEnvelopeWithStatus)\s*\(", _strip(_ra)): err("RadioActivity must not change radio or telephony state")
for _f in [x for x in ALL if x.startswith(f"{_RD}/main/")]:
    if re.search(r"\bImsMmTelManager\b|registerImsRegistrationCallback|Telephony\.Carriers|\bApnSetting\b|CarrierConfigManager|\bsetForced", _rd(_f)): err(f"{_f}: IMS/APN/CarrierConfig access is outside RadioDiag (IR-007 stays canonical)")
    if re.search(r"\.(so|jar|apk)\b", _rd(_f)) and not _f.endswith(".xml"): err(f"{_f}: vendor or stock binary reference is not allowed in RadioDiag")
_DCK = f"{_DC}/main/java/org/sableos/titan2/displaycompat"
_de, _dp, _dg = _rd(f"{_DCK}/core/Enforcement.kt"), _rd(f"{_DCK}/core/ProfileStore.kt"), _rd(f"{_DCK}/android/GatedPlatformBackend.kt")
if re.search(r"\b(ENFORCED|APPLIED|ENFORCEMENT_CONFIRMED|VERIFIED_ENFORCED)\b[,;(\s]", _de.split("enum class BackendAvailability")[0]): err("DisplayCompat EnforcementState must have no enforced/applied state")
for _s in ("NOT_ENFORCED_BACKEND_CLOSED", "NOT_ENFORCED_UNSUPPORTED", "PLATFORM_CALL_ACCEPTED_UNVERIFIED", "NOT_APPLICABLE_NATIVE"):
    if _s not in _de: err(f"DisplayCompat EnforcementState must keep {_s}")
if "NOT enforced" not in _de or "not verified" not in _de: err("DisplayCompat enforcement wording must say NOT enforced and not verified")
if re.search(r'"[^"\n]*\b(Applied|Enforced)\b[^"\n]*"', "\n".join(_strip(_rd(f)) for f in ALL if f.startswith(f"{_DCK}/ui/") or f.endswith("core/Enforcement.kt") or f.endswith("core/ProfileStore.kt"))): err("DisplayCompat UI/messages must not word a stored profile as Applied or Enforced")
if "persist.sable.displaycompat.backend" not in _dg or '== "validated"' not in _dg: err("GatedPlatformBackend must stay gated on persist.sable.displaycompat.backend=validated")
if not re.search(r"!open\(\)\s*->\s*ApplyResult\.NoOp", _dg) or "if (!open()) ApplyResult.NoOp" not in _dg: err("GatedPlatformBackend must stay fail-closed (apply and clear are no-ops while the gate is closed)")
if re.search(r"AspectProfile\.MiniMode\s*->\s*(ASPECT|\d)", _dg): err("DisplayCompat must not map Mini Mode to a platform value")
_methods = sorted(set(re.findall(r'get(?:Declared)?Method\(\s*"([^"]+)"', "\n".join(_rd(f) for f in ALL if f.startswith(f"{_DC}/main/") and f.endswith(".kt")))))
if _methods != ["get", "setUserMinAspectRatio"]: err(f"DisplayCompat must not add reflective platform calls beyond the gated setUserMinAspectRatio (found {_methods})")
for _f in [x for x in ALL if x.startswith(f"{_DC}/main/") and x.endswith(".kt")]:
    if re.search(r"\bIWindowManager\b|WindowManagerGlobal|setForcedDisplay|\bwm size\b|ServiceManager|Settings\.(Global|Secure|System)\.put", _strip(_rd(_f))): err(f"{_f}: hidden/private enforcement or settings write is outside DisplayCompat (IR-006 stays canonical)")
_n = lambda p, pat: len(re.findall(pat, _rd(p)))
if _n(f"{_RD}/test/java/org/sableos/titan2/radiodiag/RadioHardeningTest.kt", r"@Test") < 15: err("RadioHardeningTest must keep at least 15 tests")
if _n(f"{_DC}/test/java/org/sableos/titan2/displaycompat/core/DisplayCompatHardeningTest.kt", r"@Test") < 20: err("DisplayCompatHardeningTest must keep at least 20 tests")
for _f, _need in ((f"{_DC}/test/java/org/sableos/titan2/displaycompat/core/DisplayCompatHardeningTest.kt", ("closedBackendNeverClaimsEnforcement", "aStoreThatForgetsAWriteIsReportedAndNothingIsApplied", "aThrowingBackendIsReportedAsNotEnforced", "resetReportsAPlatformOverrideThatCouldNotBeCleared", "aStoredProfileThatBecameForbiddenIsNotEffective")),
                  (f"{_RD}/test/java/org/sableos/titan2/radiodiag/RadioHardeningTest.kt", ("reportAlwaysCarriesTheLimitsBlock", "unavailableIsNeverRenderedAsOffOrFalse", "reportMasksEveryValueNotOnlyProperties"))):
    for _t in _need:
        if f"fun {_t}" not in _rd(_f): err(f"{_f}: missing required test {_t}")
print("D6_RADIODIAG_READ_ONLY=YES D6_RADIODIAG_IMS_REGISTRATION=NOT_VISIBLE D6_RADIODIAG_PRIVILEGED_PERMISSIONS=NONE")
print("D6_DISPLAYCOMPAT_FAIL_CLOSED=YES D6_DISPLAYCOMPAT_STRONGEST_CLAIM=PLATFORM_CALL_ACCEPTED_UNVERIFIED D6_DISPLAYCOMPAT_MINI_MODE_IMPLEMENTED=NO")
print("D6_HARDENING_SOURCE_CONTRACT=" + ("PASS" if len(errs) == _d6_errs0 else "FAIL") + " IR_006_STATUS=" + _ir("IR-006") + " IR_007_STATUS=" + _ir("IR-007"))
print("D6_DEVICE_RUNTIME_VALIDATED=NO")


# --- D7A: Camera Control Deck source architecture (docs/SABLE_CAMERA_CONTROL_DECK_SOURCE.md); source only, no device evidence ---
_CAM = "apps/titan2/platform/camera"
_CK = f"{_CAM}/src/main/java/org/sableos/titan2/camera"
_CT = f"{_CAM}/src/test/java/org/sableos/titan2/camera/core"
_D7A = "docs/SABLE_CAMERA_CONTROL_DECK_SOURCE.md"
_d7t = _rd(_D7A)
_D7A_REQ = {"SABLE_CAMERA_CONTROL_DECK_MODEL": "PASS", "SABLE_CAMERA_FIXED_CONTROL_MAP": "PASS", "SABLE_CAMERA_TOUCH_FALLBACK": "PASS",
            "SABLE_CAMERA_TRANSIENT_PARAMETER_UI": "PASS", "SABLE_CAMERA_CONTROL_LEGEND": "PASS", "SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK": "PASS_ABSENT",
            "D7A_DEVICE_RUNTIME_VALIDATED": "NO", "D7A_DEPENDENCY_DELTA": "NONE", "D7A_NEW_CAPTURE_MODES": "NO", "D7A_FUNC_KEYS_BOUND": "NO",
            "D7A_FOCUS_POINT_RUNTIME_VALIDATED": "NO", "D7A_AF_AE_LOCK_RUNTIME_VALIDATED": "NO", "D7A_ORIENTATION_RUNTIME_VALIDATED": "NO",
            "D7A_PHYSICAL_KEY_RUNTIME_VALIDATED": "NO"}
if not _d7t: err(f"{_D7A} missing")
for _k, _v in _D7A_REQ.items():
    if f"{_k}={_v}" not in _d7t: err(f"{_D7A} must state {_k}={_v}")
for _f in ["docs/SABLE_CAMERA_CONTROL_DECK.md", _D7A]:
    for _mk in re.finditer(r"\b(SABLE_CAMERA_[A-Z0-9_]+_(?:TITAN2|ELITE))=([A-Za-z0-9_]+)", _rd(_f)):
        if _mk.group(2).startswith("PASS") and _f == _D7A: err(f"{_f}: runtime camera marker must not be claimed from source: {_mk.group(0)}")
    if re.search(r"\b(?:SABLE_CAMERA_[A-Z0-9_]+_(?:TITAN2|ELITE))=PASS\b", _rd(_f)) and _f == _D7A: err(f"{_f}: runtime camera marker must not be claimed from source")
_cm = {n: _rd(f"{_CK}/core/{n}.kt") for n in ("ControlDeck", "ControlLegend", "RawKeys", "KeyMap", "ActionRouter", "DeviceProfile")}
_ma = _rd(f"{_CK}/ui/MainActivity.kt"); _ui = _ma
_ctest = _rd(f"{_CT}/ControlDeckTest.kt")
_cmain = [f for f in ALL if f.startswith(f"{_CAM}/src/main/") and f.endswith(".kt")]
# model: semantic layers exist and the activity dispatches through them
_d7_model = all(_cm[n] for n in ("ControlDeck", "ControlLegend", "RawKeys"))
for _n in ("ControlDeck", "ControlLegend", "RawKeys"):
    if not _cm[_n]: err(f"Camera Control Deck source file core/{_n}.kt is missing")
for _s in ("object ControlGate", "object ControlDeck", "data class DeckState", "object ParameterStrips", "object DeckOrientation", "object DeckPolicy", "fun dispatch("):
    if _s not in _cm["ControlDeck"]: _d7_model = False; err(f"Camera Control Deck model must define {_s}")
if "ControlDeck.dispatch(" not in _ma: _d7_model = False; err("MainActivity.act must route every control through ControlDeck.dispatch (key and touch share one path)")
if "RawKeys.nameOf(" not in _ma: _d7_model = False; err("MainActivity must resolve key codes through RawKeys, not a local key table")
if re.search(r"KeyEvent\.KEYCODE_", _strip(_ma) + _strip(_ui)): _d7_model = False; err("raw Android key codes belong only in core/RawKeys.kt")
if re.search(r"\bandroid\.view\.KeyEvent\b|KEYCODE_", "".join(_strip(_cm[n]) for n in ("ControlDeck", "ControlLegend", "KeyMap", "ActionRouter"))): _d7_model = False; err("camera action/map/deck core must not reference Android key codes")
# fixed map: the document's standard layout, no per-key customization surface, no Func1/Func2
_d7_map = True
for _b in ("space", "enter", "camera", "f", "e", "i", "w", "s", "plus", "minus", "left", "right", "up", "down", "c", "b", "g", "a", "h", "slash"):
    if f'Binding("{_b}")' not in _cm["KeyMap"]: _d7_map = False; err(f"fixed Sable camera map must bind {_b}")
if 'Binding("e", alt = true)' not in _cm["KeyMap"]: _d7_map = False; err("fixed Sable camera map must keep Alt+E exposure down")
if 'Binding("f") to CameraAction.Autofocus' not in _cm["KeyMap"]: _d7_map = False; err("F must be the single-press Autofocus action (AF lock stays deferred)")
if re.search(r"\bFocusLock\b", "\n".join(_rd(f) for f in ALL if f.startswith(f"{_CAM}/src/") and f.endswith(".kt"))): _d7_map = False; err("stale FocusLock action name: the single-press F action is Autofocus (no AF-lock claim)")
if "ToggleLegend" not in _cm["KeyMap"]: _d7_map = False; err("CameraAction.ToggleLegend must exist and be bound")
if len(re.findall(r"val standard\s*:\s*Map<Binding, CameraAction>", _cm["KeyMap"])) != 1: _d7_map = False; err("exactly one fixed standard camera map is allowed")
if re.search(r"(?i)\bfunc[_ ]?[12]\b|KEYCODE_FUNCTION|KEYCODE_F[12]\b", "\n".join(_strip(_rd(f)) for f in _cmain)): _d7_map = False; err("Func1/Func2 must stay unbound in camera source (vendor framework intercepts them)")
if re.search(r"(?i)keyOverrides\s*=\s*\w*(?:load|read|parse|store|prefs)", "\n".join(_strip(_rd(f)) for f in _cmain)) or re.search(r"(?i)SharedPreferences|DataStore|remap", "\n".join(_strip(_rd(f)) for f in _cmain)): _d7_map = False; err("camera key bindings must be fixed: no user remapping or stored bindings in D7A")
# touch fallback: every action has a touch control; touch and keys call the same handler
_d7_touch = True
if not re.search(r"systemProvided\s*:\s*Set<CameraAction>\s*=\s*setOf\(CameraAction\.Back\)", _cm["ControlLegend"]): _d7_touch = False; err("TouchFallback may exempt only the system Back action")
if "TouchControlBar(TouchFallback.controls(" not in _ma or "::act" not in _ma: _d7_touch = False; err("MainActivity must render TouchControlBar wired to the same act() as key presses")
if "onAction(c.action)" not in _ui: _d7_touch = False; err("TouchControlBar buttons must invoke the shared action handler")
if "act(action)" not in _ma and "act(it)" not in _ma: _d7_touch = False; err("physical keys must reach act()")
if "DeckOrientation.touchChromeVisible(" not in _ma: _d7_touch = False; err("touch chrome visibility must come from DeckOrientation")
if "fun touchChromeVisible" not in _cm["ControlDeck"] or "p == DeckPresentation.Portrait" not in _cm["ControlDeck"]: _d7_touch = False; err("portrait must always show touch controls")
# transient parameter UI
_d7_strip = True
if "const val STRIP_TIMEOUT_MS" not in _cm["ControlDeck"] or "fun tick(" not in _cm["ControlDeck"]: _d7_strip = False; err("parameter strips must expire (DeckPolicy.STRIP_TIMEOUT_MS and ControlDeck.tick)")
if "ParameterStripOverlay" not in _ui or "StripExpiry" not in _ui or not re.search(r"(?m)^\s+DeckOverlays\(", _ma) or not re.search(r"(?m)^\s+StripExpiry\(deck\)", _ma): _d7_strip = False; err("MainActivity must show the transient strip overlay and its expiry")
if re.search(r"fun\s+ProStrip\s*\(", _ma): _d7_strip = False; err("the permanent Pro strip must stay removed (strips are transient)")
if "ParameterStrips.after(" not in _ma: _d7_strip = False; err("MainActivity must show the strip a command adjusted")
if not re.search(r"fun forField\(f: ProField, s: ProState, l: ProLimits\)", _cm["ControlDeck"]) or "if (!l.offers(f)) return null" not in _cm["ControlDeck"]: _d7_strip = False; err("strips must be capability-gated (null when the camera does not offer the field)")
# legend
_d7_legend = True
if "ControlLegend.entries(" not in _ui or "ControlLegendOverlay" not in _ui: _d7_legend = False; err("the control legend overlay must be generated from ControlLegend.entries")
if "legendVisible" not in _cm["ControlDeck"] or "fun onBack(" not in _cm["ControlDeck"] or "dismissLegend" not in _ui + _ma: _d7_legend = False; err("the legend must be dismissible by keyboard (Back/help) and touch")
if not re.search(r"CameraAction\.ToggleLegend,\s*CameraAction\.Back\s*\)", _cm["ControlLegend"]): _d7_legend = False; err("the legend must list its own help action")
# orientation: AUTO, no global lock
_d7_orient = True
_cmf = _rd(f"{_CAM}/src/main/AndroidManifest.xml")
for _m in re.findall(r'android:(?:screenOrientation|requestedOrientation)="([^"]+)"', _cmf):
    if _m not in ("unspecified", "fullSensor", "sensor", "user", "fullUser"): _d7_orient = False; err(f"camera manifest must not lock orientation (found {_m})")
if re.search(r"requestedOrientation|SCREEN_ORIENTATION_|OrientationEventListener\b.*lock", "\n".join(_strip(_rd(f)) for f in _cmain)): _d7_orient = False; err("camera source must not set or lock the activity orientation")
if 'ORIENTATION_POLICY = "AUTO"' not in _cm["ControlDeck"] or "GLOBAL_LANDSCAPE_LOCK = false" not in _cm["ControlDeck"]: _d7_orient = False; err("DeckPolicy must keep ORIENTATION_POLICY=AUTO and GLOBAL_LANDSCAPE_LOCK=false")
# scope: no new modes, no vendor/proprietary camera, no new dependency
if sorted(re.findall(r"\b([A-Z][a-z]+)\(\"", _rd(f"{_CK}/core/ActionRouter.kt").split("enum class UiMode", 1)[-1].split("\n", 1)[0])) != ["Photo", "Pro", "Video"]: err("UiMode must stay exactly Video, Photo, Pro (D7A adds no capture mode)")
if sorted(re.findall(r"\b([A-Z]\w+)\b", re.search(r"enum class CaptureMode \{([^}]*)\}", _rd(f"{_CK}/core/Model.kt")).group(1) if re.search(r"enum class CaptureMode \{([^}]*)\}", _rd(f"{_CK}/core/Model.kt")) else "")) != ["Auto", "HighRes", "Pro", "Raw", "Tele"]: err("CaptureMode must stay Auto, HighRes, Raw, Pro, Tele (no new capture mode)")
_cs = "\n".join(_strip(_rd(f)) for f in _cmain)
if re.search(r"android\.permission\.SYSTEM_CAMERA|\bGcam\b|GoogleCamera|libmmcamera|vendor\.qti\.camera|\bCaptureModes?\.(Timelapse|Burst)\b", _cs): err("camera source must not use SYSTEM_CAMERA, GCam or vendor camera code")
if re.search(r"(?i)\b(timelapse|burst|computational|hdr)\w*\s*(\(|=|->|:)", _cs.replace("TimelapseNotBuilt", "")) and not re.search(r"(?i)minus Timelapse", _cs): err("camera source must not add timelapse, burst or computational HDR")
_cg = _rd(f"{_CAM}/build.gradle.kts")
_cdeps = sorted(re.findall(r"implementation\((?:composeBom|libs\.[\w.]+)\)|testImplementation\(libs\.[\w.]+\)", _cg))
if _cdeps != sorted(["implementation(libs.androidx.core.ktx)", "implementation(composeBom)", "implementation(libs.androidx.activity.compose)", "implementation(libs.androidx.compose.ui)", "implementation(libs.androidx.compose.foundation)", "implementation(libs.androidx.compose.material3)", "testImplementation(libs.junit)"]): err(f"camera module dependencies changed (D7A_DEPENDENCY_DELTA=NONE; a new dependency needs its own reviewed dependency delta): {_cdeps}")
# tests
if len(re.findall(r"@Test", _ctest)) < 40: err("ControlDeckTest must keep at least 40 tests")
for _t in ("touchCoversEveryActionExceptSystemBack", "touchAndKeyRouteIdentically", "func1AndFunc2StayUnboundEverywhere", "fixedMapMatchesTheControlDeckDocument", "proControlsAreOpenOnlyInProAndOnlyWhenOffered", "stripIsTransientAndExpires", "legendKeysAllResolveBackToTheirAction", "backClosesLegendThenStripThenLeaves", "orientationPolicyIsAutoAndNeverLocked", "deckAddsNoCaptureModes", "dispatchRefusesAClosedActionAndSaysWhy", "rawKeyCodesMapToCoreNamesOnly"):
    if f"fun {_t}(" not in _ctest: err(f"ControlDeckTest is missing required test {_t}")
print("SABLE_CAMERA_CONTROL_DECK_MODEL=" + ("PASS" if _d7_model else "FAIL"))
print("SABLE_CAMERA_FIXED_CONTROL_MAP=" + ("PASS" if _d7_map else "FAIL"))
print("SABLE_CAMERA_TOUCH_FALLBACK=" + ("PASS" if _d7_touch else "FAIL"))
print("SABLE_CAMERA_TRANSIENT_PARAMETER_UI=" + ("PASS" if _d7_strip else "FAIL"))
print("SABLE_CAMERA_CONTROL_LEGEND=" + ("PASS" if _d7_legend else "FAIL"))
print("SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK=" + ("PASS_ABSENT" if _d7_orient else "FAIL"))
print("D7A_CONTROL_DECK_SOURCE_CONTRACT=" + ("PASS" if all([_d7_model, _d7_map, _d7_touch, _d7_strip, _d7_legend, _d7_orient]) else "FAIL"))

# --- D7B: Keyboard compact input strip (docs/SABLE_KEYBOARD_COMPACT_INPUT_STRIP.md); source only, no device evidence ---
_KB = "apps/titan2/platform/keyboard"
_KK = f"{_KB}/src/main/java/org/sableos/titan2/keyboard"
_KT = f"{_KB}/src/test/java/org/sableos/titan2/keyboard/core"
_D7B = "docs/SABLE_KEYBOARD_COMPACT_INPUT_STRIP.md"
_d7bt = _rd(_D7B)
_D7B_REQ = {"SABLE_KEYBOARD_COMPACT_STRIP_MODEL": "PASS", "SABLE_KEYBOARD_COMPACT_STRIP_STATE": "PASS", "SABLE_KEYBOARD_COMPACT_STRIP_SAFE_AREA": "PASS",
            "SABLE_KEYBOARD_COMPACT_STRIP_HEIGHT": "PASS", "SABLE_KEYBOARD_COMPACT_STRIP_PRIVACY": "PASS", "SABLE_KEYBOARD_COMPACT_STRIP_SCOPE": "PASS_EXCLUSIONS_ABSENT",
            "D7B_DEVICE_RUNTIME_VALIDATED": "NO", "D7B_CRITICAL_TEXT_ENTRY_DEVICE_RUNTIME_VALIDATED": "NO", "D7B_DEPENDENCY_DELTA": "NONE",
            "D7B_PASTIERA_SOURCE_IMPORTED": "NO", "D7B_PLEKTRA_SOURCE_IMPORTED": "NO", "D7B_GPL_CODE_COPIED": "NO", "D7B_EMOJI_DATA": "NONE",
            "D7B_SNIPPETS": "NO", "D7B_LEARNED_PREDICTION": "NO", "D7B_KEY_REMAPPING": "NO", "D7B_NEW_LANGUAGES": "NO", "D7B_SHIZUKU": "NO",
            "D7B_CLIPBOARD_HISTORY": "NO", "D7B_NETWORK_ACCESS": "NO", "D7B_ONLINE_REPOSITORIES": "NO", "IR_004_STATUS": "OPEN_CANONICAL", "IR_005_STATUS": "OPEN_CANONICAL"}
if not _d7bt: err(f"{_D7B} missing")
for _k, _v in _D7B_REQ.items():
    if f"{_k}={_v}" not in _d7bt: err(f"{_D7B} must state {_k}={_v}")
for _mk in re.finditer(r"\b(D7B_[A-Z0-9_]+|IR_00[45]_STATUS)=([A-Za-z0-9_]+)", _d7bt):
    if _mk.group(1) in _D7B_REQ and _mk.group(2) != _D7B_REQ[_mk.group(1)]: err(f"{_D7B}: D7B marker contradicts the contract: {_mk.group(0)}")
for _i in ("IR-004", "IR-005"):
    if _ir(_i) != "OPEN": err(f"{_i} must stay OPEN and canonical-owned in D7B (found {_ir(_i)})")
    if "canonical" not in _irs.get(_i, {}).get("system_component_owner", "").lower(): err(f"{_i} must stay canonical-owned")
if "| KL-032 |" not in _kl or "D7B_DEVICE_RUNTIME_VALIDATED=NO" not in _kl: err("KL-032 (D7B compact strip, device runtime not validated) must be in the known-limitations ledger")
_cs = _rd(f"{_KK}/core/CompactStrip.kt")
_cv = _rd(f"{_KK}/android/CompactStripView.kt")
_sv = _rd(f"{_KK}/android/SableImeService.kt")
_sk = _rd(f"{_KK}/android/SoftKeyboardView.kt")
_kp = _rd(f"{_KK}/android/KeyboardPrefs.kt")
_ks = _rd(f"{_KK}/android/KeyboardSettingsActivity.kt")
_rs = _rd(f"{_KK}/core/Resolver.kt")
_kst = _rd(f"{_KT}/CompactStripTest.kt")
_kmain = [f for f in ALL if f.startswith(f"{_KB}/src/main/") and f.endswith((".kt", ".xml"))]
_kmain_kt = "\n".join(_strip(_rd(f)) for f in _kmain if f.endswith(".kt"))
# model
_d7b_model = bool(_cs and _cv)
for _s in ("object CompactStrip", "object StripGeometry", "object StripPolicy", "object SoftKeyboardGeometry", "enum class StripMode", "fun build(", "fun mode(", "data class StripInputs"):
    if not re.search(re.escape(_s) + (r"(?!\w)" if _s[-1].isalnum() else ""), _cs): _d7b_model = False; err(f"compact input strip model must define {_s}")
for _m in ("Hidden", "CandidatesOnly", "Compact"):
    if not re.search(r"enum class StripMode \{[^}]*\b" + _m + r"\b", _cs): _d7b_model = False; err(f"StripMode must keep {_m}")
if "CompactStrip.build(" not in _sv or "fun refreshStrip(" not in _sv or "CompactStripView(" not in _sv: _d7b_model = False; err("SableImeService must render the compact strip through CompactStrip.build and CompactStripView")
if "runCatching { CompactStrip.build(" not in _sv: _d7b_model = False; err("a failed strip refresh must never reach the key path (runCatching around CompactStrip.build)")
if "prefs.compactStrip" not in _sv or 'getBoolean("compactStrip", true)' not in _kp or '"compactStrip"' not in _ks: _d7b_model = False; err("the compact strip must be a stored setting (default on) with a settings switch")
if "StripMode.CandidatesOnly" not in _cs or "softKeyboardShown || !i.enabled" not in _cs: _d7b_model = False; err("with the full keyboard up or the strip off, only the previous candidates-only behaviour is allowed")
# state shown: language, Shift/Alt/Sym/Nav, candidates, variation
_d7b_state = True
for _f in ("language: Language", "shift: ModState", "alt: ModState", "sym: ModState", "navOn: Boolean", "navEffective: Boolean", "candidates: List<Cand>", "variation: VariationInfo?"):
    if _f not in _cs: _d7b_state = False; err(f"StripInputs must carry {_f}")
for _id in ('"shift"', '"alt"', '"sym"', '"nav"'):
    if f"ModChip({_id}" not in _cs: _d7b_state = False; err(f"the strip must show the {_id} modifier chip")
if "ChipState.Suspended" not in _cs or "i.navEffective -> ChipState.Active" not in _cs: _d7b_state = False; err("Nav must be shown Active only when effective and Suspended when the field class suspends it")
if "fun variation()" not in _rs or "fun navEffective(" not in _rs or "fun clearVariation(" not in _rs: _d7b_state = False; err("Resolver must expose read-only variation()/navEffective() for the strip")
if "VARIATION_TTL_MS" not in _cs or "v != null && liveVariation(v, i.nowMs)" not in _cs: _d7b_state = False; err("variation state must be short-lived (StripPolicy.VARIATION_TTL_MS)")
# safe area: live insets only, no device geometry
_d7b_safe = True
for _s in ("fun cornerInset(", "fun contentPadding("):
    if _s not in _cs: _d7b_safe = False; err(f"StripGeometry must define {_s}")
for _s in ("StripGeometry.contentPadding(", "getRoundedCorner(", "WindowInsets.Type.displayCutout()", "WindowInsets.Type.navigationBars()"):
    if _s not in _cv: _d7b_safe = False; err(f"CompactStripView must derive safe areas from live insets ({_s})")
if re.search(r"(?i)\"titan2\"|\"elite\"|(?<![\w.])titan ?2(?![\w.])|zinwa|q27|ro\.sable\.profile", _strip(_cs) + _strip(_cv)): _d7b_safe = False; err("compact strip geometry must not hard-code any device profile (Elite inherits no Titan 2 geometry)")
# height: strip is at most a quarter of the smallest full keyboard, single-sourced with the soft keyboard
def _const(txt, name):
    _m = re.search(r"const val " + name + r"\s*=\s*(\d+)", txt)
    return int(_m.group(1)) if _m else None
_chip, _padv = _const(_cs, "CHIP_HEIGHT_DP"), _const(_cs, "PAD_V_DP")
_row, _rows = _const(_cs, "ROW_HEIGHT_DP"), _const(_cs, "MIN_ROWS")
_d7b_height = True
if None in (_chip, _padv, _row, _rows) or "const val HEIGHT_DP = CHIP_HEIGHT_DP + 2 * PAD_V_DP" not in _cs:
    _d7b_height = False; err("StripGeometry/SoftKeyboardGeometry height constants must be declared (HEIGHT_DP = CHIP_HEIGHT_DP + 2 * PAD_V_DP)")
else:
    _kbpad = re.findall(r"const val PAD_V_DP\s*=\s*(\d+)", _cs)
    _kbmin = _rows * _row + 2 * int(_kbpad[-1])
    if (_chip + 2 * _padv) * 4 > _kbmin: _d7b_height = False; err(f"compact strip height {_chip + 2 * _padv}dp must be at most a quarter of the minimum full keyboard height {_kbmin}dp")
if "SoftKeyboardGeometry.ROW_HEIGHT_DP" not in _sk: _d7b_height = False; err("SoftKeyboardView must take its row height from SoftKeyboardGeometry (single source)")
# privacy: secret/numeric fields show state only; bounded content
_d7b_priv = True
if "i.field != InputClass.Text -> StripContent.None" not in _cs: _d7b_priv = False; err("candidates/variation/symbols must appear only in ordinary text fields")
if "take(StripPolicy.MAX_CANDIDATES)" not in _cs or "take(StripPolicy.MAX_SYMBOLS)" not in _cs: _d7b_priv = False; err("candidate and symbol content must be bounded")
if "table.values.distinct()" not in _cs or "i.layout.sym" not in _cs or "i.layout.alt" not in _cs: _d7b_priv = False; err("symbols must come only from the existing layout tables")
if re.search(r"SharedPreferences|\.edit\(\)|Log\.[dievw]\(|println\(|File(Output|Writer)", _strip(_cs) + _strip(_cv)): _d7b_priv = False; err("the compact strip must not store or log anything")
# scope exclusions
_d7b_scope = True
_ex = (
    (r"(?i)shizuku", "Shizuku"), (r"ClipboardManager|ClipData|OnPrimaryClipChangedListener", "clipboard access or history"),
    (r"(?i)snippet", "snippets"), (r"(?i)remap|KeyRemap", "key remapping"), (r"(?i)predict|nextWord|userDictionary|learn(ed|ing)\w*", "learned prediction"),
    (r"java\.net\.|HttpURLConnection|okhttp|retrofit|WebView|Socket\(", "network access"), (r"(?i)palsoftware|pastiera|plektra|pkb-rocks", "Pastiera/Plektra code"),
    (r"[\U0001F300-\U0001FAFF]", "emoji data"),
)
for _pat, _what in _ex:
    if re.search(_pat, _kmain_kt): _d7b_scope = False; err(f"keyboard source must not contain {_what} (outside D7B scope)")
_kassets = sorted(f for f in ALL if f.startswith(f"{_KB}/src/main/assets/"))
if _kassets != [f"{_KB}/src/main/assets/pinyin_zh.LICENSES.txt", f"{_KB}/src/main/assets/pinyin_zh.NOTICE.txt", f"{_KB}/src/main/assets/pinyin_zh.tsv"]: _d7b_scope = False; err(f"keyboard assets must stay the pinyin corpus only (no emoji or other bundled data without provenance): {_kassets}")
_kg = _rd(f"{_KB}/build.gradle.kts")
_kdeps = sorted(re.findall(r"(?:test)?[iI]mplementation\([^)]*\)", _kg))
if _kdeps != ["implementation(libs.androidx.core.ktx)", "testImplementation(libs.junit)"]: _d7b_scope = False; err(f"keyboard module dependencies changed (D7B_DEPENDENCY_DELTA=NONE): {_kdeps}")
# tests
if len(re.findall(r"@Test", _kst)) < 25: err("CompactStripTest must keep at least 25 tests")
for _t in ("hiddenSoftKeyboardShowsTheCompactStrip", "softKeyboardShownKeepsTheOldCandidatesOnlyBehaviour", "navShowsActiveOrSuspendedHonestly", "variationIsShortLived", "anUnconfirmedSymLayerIsNeverGuessed", "noEmojiIsOfferedBecauseNoProvenancedEmojiDataExists", "secretAndNumericFieldsShowNoCandidatesVariationOrSymbols", "stripUsesSubstantiallyLessHeightThanTheFullKeyboard", "cornerInsetFollowsTheCircleAndVanishesAboveIt", "eachDeviceGetsItsOwnInsetsNoProfileGeometryIsHardCoded"):
    if f"fun {_t}(" not in _kst: err(f"CompactStripTest is missing required test {_t}")
print("SABLE_KEYBOARD_COMPACT_STRIP_MODEL=" + ("PASS" if _d7b_model else "FAIL"))
print("SABLE_KEYBOARD_COMPACT_STRIP_STATE=" + ("PASS" if _d7b_state else "FAIL"))
print("SABLE_KEYBOARD_COMPACT_STRIP_SAFE_AREA=" + ("PASS" if _d7b_safe else "FAIL"))
print("SABLE_KEYBOARD_COMPACT_STRIP_HEIGHT=" + ("PASS" if _d7b_height else "FAIL"))
print("SABLE_KEYBOARD_COMPACT_STRIP_PRIVACY=" + ("PASS" if _d7b_priv else "FAIL"))
print("SABLE_KEYBOARD_COMPACT_STRIP_SCOPE=" + ("PASS_EXCLUSIONS_ABSENT" if _d7b_scope else "FAIL"))
print("D7B_COMPACT_STRIP_SOURCE_CONTRACT=" + ("PASS" if all([_d7b_model, _d7b_state, _d7b_safe, _d7b_height, _d7b_priv, _d7b_scope]) else "FAIL"))

# --- D8: Setup helper readiness/truthfulness hardening (docs/C3B_D8_SETUP_HELPER_HARDENING.md); source only, no device evidence ---
_SB = "apps/titan2/platform/setup"
_SK = f"{_SB}/src/main/java/org/sableos/titan2/setup"
_ST = f"{_SB}/src/test/java/org/sableos/titan2/setup"
_D8 = "docs/C3B_D8_SETUP_HELPER_HARDENING.md"
_d8t = _rd(_D8)
_D8_REQ = {"SABLE_SETUP_READINESS_MODEL": "PASS", "SABLE_SETUP_LAUNCH_SAFETY": "PASS", "SABLE_SETUP_WORDING": "PASS",
           "SABLE_SETUP_DEFAULT_APP_TRUTHFULNESS": "PASS", "SABLE_SETUP_PROFILE_UNKNOWN": "PASS", "SABLE_SETUP_SCOPE": "PASS_EXCLUSIONS_ABSENT",
           "D8_DEVICE_RUNTIME_VALIDATED": "NO", "D8_DEPENDENCY_DELTA": "NONE", "D8_SETUP_WIZARD_CLAIMED": "NO", "D8_SETTING_MUTATION": "NO",
           "D8_ROLE_MUTATION": "NO", "D8_NEW_PERMISSIONS": "NONE", "D8_HIDDEN_PROPERTY_EXPANSION": "NO", "IR_001_STATUS": "OPEN_CANONICAL",
           "IR_003_STATUS": "OPEN_CANONICAL", "IR_005_STATUS": "OPEN_CANONICAL", "KL_005_STATUS": "OPEN_CANONICAL"}
if not _d8t: err(f"{_D8} missing")
for _k, _v in _D8_REQ.items():
    if f"{_k}={_v}" not in _d8t: err(f"{_D8} must state {_k}={_v}")
for _mk in re.finditer(r"\b(D8_[A-Z0-9_]+|IR_00[135]_STATUS|KL_005_STATUS)=([A-Za-z0-9_]+)", _d8t):
    if _mk.group(1) in _D8_REQ and _mk.group(2) != _D8_REQ[_mk.group(1)]: err(f"{_D8}: D8 marker contradicts the contract: {_mk.group(0)}")
for _i in ("IR-001", "IR-003", "IR-005"):
    if _ir(_i) != "OPEN": err(f"{_i} must stay OPEN and canonical-owned in D8 (found {_ir(_i)})")
    if "canonical" not in _irs.get(_i, {}).get("system_component_owner", "").lower(): err(f"{_i} must stay canonical-owned")
if not re.search(r"\| KL-005 \|[^\n]*canonical lane", _kl): err("KL-005 (Setup helper is not the Setup Wizard) must stay open and canonical-owned in the known-limitations ledger")
if "| KL-033 |" not in _kl or "D8_DEVICE_RUNTIME_VALIDATED=NO" not in _kl: err("KL-033 (D8 Setup helper, device runtime not validated) must be in the known-limitations ledger")
_su_files = [f for f in ALL if f.startswith(f"{_SB}/src/main/") and f.endswith(".kt")]
_su_main = "\n".join(_strip(_rd(f)) for f in _su_files)
_rdn = _rd(f"{_SK}/core/Readiness.kt")
_rows = _strip(_rd(f"{_SK}/core/SetupRows.kt"))
_smod = _strip(_rd(f"{_SK}/core/SetupModel.kt"))
_lrep = _strip(_rd(f"{_SK}/core/LaunchReport.kt"))
_laun = _strip(_rd(f"{_SK}/android/Launcher.kt"))
_sact = _strip(_rd(f"{_SK}/android/SetupActivity.kt"))
_srd = _strip(_rd(f"{_SK}/android/SetupReader.kt"))
_sman = _rd(f"{_SB}/src/main/AndroidManifest.xml")
_sht = _rd(f"{_ST}/SetupHardeningTest.kt")
# readiness model
_d8_model = bool(_rdn and _rows and _smod)
for _s in ("Satisfied", "ActionRequired", "Informational", "Unavailable", "Unknown"):
    if not re.search(r"enum class Readiness \{[^}]*\b" + _s + r"\b", _rdn): _d8_model = False; err(f"Readiness must keep the {_s} state")
for _s in ("data class Value", "object Absent", "object Failed"):
    if _s not in _rdn: _d8_model = False; err(f"Observed must keep {_s} (a failed read is its own case)")
if re.search(r"enum class State\b|\bState\.(Done|Todo|Info)\b", _su_main): _d8_model = False; err("the Done/Todo/Info state model must not return in the Setup helper")
if len(re.findall(r"Observed\.Failed\s*->\s*Item\([^)]*?Readiness\.Unknown", _rows, re.S)) < 3: _d8_model = False; err("every failed read in SetupRows must become Readiness.Unknown (never satisfied, action required or not configured)")
if '"unavailable"' not in _smod or '"unknown"' not in _smod or "Readiness.Unavailable" not in _smod or "Readiness.Unknown" not in _smod: _d8_model = False; err("summary and isReady must account for unavailable and unknown rows")
if not re.search(r"fun isReady\([^)]*\)[^{]*\{?[^}]*ActionRequired[^}]*Unavailable[^}]*Unknown", _smod, re.S): _d8_model = False; err("isReady must be false for action-required, unavailable and unknown rows")
if "SetupRows.build(" not in _sact or "SetupModel.summary(" not in _sact or "SetupModel.isReady(" not in _sact or "SetupReader(this).snapshot()" not in _sact: _d8_model = False; err("SetupActivity must render from SetupReader, SetupRows.build, SetupModel.summary and SetupModel.isReady")
# launch safety
_d8_launch = bool(_laun and _lrep)
for _s in ("ActivityNotFoundException", "SecurityException", "resolveActivity(", "TargetStatus.Missing", "TargetStatus.Unverifiable", "LaunchOutcome.TargetMissing", "LaunchOutcome.Denied"):
    if _s not in _laun: _d8_launch = False; err(f"Launcher must handle {_s}")
if "fun applyTarget(" not in _rows or ".map { applyTarget(" not in _rows: _d8_launch = False; err("SetupRows.build must apply the resolved target status to every row (applyTarget)")
_unverifiable = re.search(
    r"status == TargetStatus\.Unverifiable\s*->\s*item\.copy\((.*?)\)\s*\n\s*item\.state",
    _rows,
    re.S,
)
if (
    "status == TargetStatus.Resolvable -> item" not in _rows
    or not _unverifiable
    or "could not verify that this screen is available" not in _unverifiable.group(1)
    or "action = Action.None" not in _unverifiable.group(1)
):
    _d8_launch = False; err("unverifiable launch targets must fail closed with no usable button")
if "launcher::resolve" not in _sact or "launcher.run(" not in _sact or "LaunchReport.message(" not in _sact: _d8_launch = False; err("SetupActivity must resolve targets through Launcher and surface LaunchReport.message")
if re.search(r"runCatching|\?\.let\s*\{\s*startActivity", _su_main): _d8_launch = False; err("Setup helper launches must not be silently swallowed (no runCatching or ?.let { startActivity })")
if "startActivity(" in _sact: _d8_launch = False; err("SetupActivity must launch only through Launcher")
if "const val MAX_MESSAGE" not in _lrep or ".take(MAX_MESSAGE)" not in _lrep or re.search(r"Throwable|Exception", _lrep): _d8_launch = False; err("LaunchReport must bound the message and never carry exception text")
for _a in ("android.settings.HOME_SETTINGS", "android.settings.MANAGE_DEFAULT_APPS_SETTINGS", "android.settings.WIRELESS_SETTINGS"):
    if _a not in _sman: _d8_launch = False; err(f"Setup manifest must declare a queries entry for {_a} so the resolve check can work")
# wording
_d8_wording = True
if 'const val RADIO_DETAIL =' not in _rows or "IMS registration visibility requires canonical IR-007" not in _rows or "Read-only SIM and network diagnostics" not in _rows: _d8_wording = False; err("the RadioDiag row must say IMS registration visibility requires canonical IR-007")
if re.search(r"(?i)IMS status|Radio and IMS|ims (is )?registered|ims registration (is |state )?(visible|shown|observed)", _su_main): _d8_wording = False; err("the Setup helper must not imply that IMS registration is visible")
if "Not the Android Setup Wizard" not in _smod or "Post-provisioning" not in _smod: _d8_wording = False; err("the Setup helper must describe itself as a post-provisioning helper that is not the Android Setup Wizard")
if re.search(r"(?i)first[- ]?(boot|run)|provision(ing complete|ed)\b", _su_main): _d8_wording = False; err("the Setup helper must not claim first-boot or provisioning authority")
if "SetupModel.SELF_DESCRIPTION" not in _sact: _d8_wording = False; err("SetupActivity must show the helper self-description")
# default-app truthfulness: observation only
_d8_default = True
if "A default app is configured" not in _rows or "not checked against a specific app" not in _rows: _d8_default = False; err("Phone/Messages rows must say only that a default app is configured")
if re.search(r"(?i)correct|doneIf\(", _rows): _d8_default = False; err("default-app rows must not call a state correct or derive success from any non-null default")
if 'startsWith("$SABLE_KEYBOARD_PACKAGE/")' not in _rows: _d8_default = False; err("the keyboard row must test the Sable keyboard package explicitly")
_hm = re.search(r"private fun home\(.*?\n    \}\n", _rows, re.S)
if not _hm or re.search(r"Satisfied|ActionRequired", _hm.group(0)): _d8_default = False; err("the HOME row must stay informational (canonical-owned, IR-003)")
if re.search(r"RoleManager|requestRole|ACTION_REQUEST_ROLE|ACTION_CHANGE_DEFAULT|Settings\.\w+\.put\w*\(|setDefault\w*\(|setDataEnabled|setInputMethod", _su_main): _d8_default = False; err("the Setup helper must not mutate roles or settings")
# profile identity
_d8_profile = True
if "fun profileLine(id: String?)" not in _smod or "Profile unknown (not reported by this build)" not in _smod: _d8_profile = False; err("a blank or unreadable profile id must be an explicit unknown")
if 'SetupModel.profileLine(SysProps.get("ro.sable.profile.id"))' not in _sact: _d8_profile = False; err("SetupActivity must keep the single provisional ro.sable.profile.id read")
if sorted(set(re.findall(r"\bro\.[a-z0-9_.]+", _su_main + _rd(f"{_SK}/android/SysProps.kt")))) != ["ro.sable.profile.id"]: _d8_profile = False; err("the Setup helper must not read any property other than ro.sable.profile.id")
if re.search(r"Build\.(MODEL|DEVICE|PRODUCT|MANUFACTURER|BRAND|HARDWARE)|(?i:zinwa|q27)", _su_main): _d8_profile = False; err("the Setup helper must not branch on a device name")
if any("Class.forName" in _strip(_rd(f)) for f in _su_files if not f.endswith("/SysProps.kt")): _d8_profile = False; err("hidden-API reflection must stay limited to SysProps")
# scope
_d8_scope = True
_sg = _rd(f"{_SB}/build.gradle.kts")
_sdeps = sorted(re.findall(r"(?:test)?[iI]mplementation\([^)]*\)", _sg))
if _sdeps != ["implementation(libs.androidx.core.ktx)", "testImplementation(libs.junit)"]: _d8_scope = False; err(f"setup module dependencies changed (D8_DEPENDENCY_DELTA=NONE): {_sdeps}")
if "uses-permission" in _sman: _d8_scope = False; err("the Setup helper must declare no permission (D8_NEW_PERMISSIONS=NONE)")
if re.search(r"(?i)setupwizard|SetupWizard|DeviceProvisioning|DevicePolicyManager|ProvisioningState|USER_SETUP_COMPLETE|DEVICE_PROVISIONED", _su_main): _d8_scope = False; err("the Setup helper must not take on Setup Wizard or provisioning-state ownership")
if re.search(r"java\.net\.|HttpURLConnection|okhttp|WebView|Socket\(", _su_main): _d8_scope = False; err("the Setup helper must not use the network")
# tests
if len(re.findall(r"@Test", _sht)) < 30: err("SetupHardeningTest must keep at least 30 tests")
for _t in ("failedReadsAreUnknownNeverSatisfiedOrActionRequired", "summaryNamesUnavailableAndUnknownRows", "unverifiableTargetIsNotOfferedAsUsable", "unverifiableFixTargetKeepsTheEvidenceButRemovesTheButton", "missingTargetOnInformationalRowIsVisibleAsUnavailable",
           "anAbsurdlyLongLabelCannotUnboundTheMessage", "everyImsMentionIsTheIr007Qualifier", "noTextClaimsWizardFirstBootOrProvisioningAuthority",
           "dialerAndSmsOnlyClaimThatADefaultAppIsConfigured", "blankNullAndWhitespaceProfilesAreExplicitUnknown", "unavailableOrUnknownRowsBlockReady"):
    if f"fun {_t}(" not in _sht: err(f"SetupHardeningTest is missing required test {_t}")
print("SABLE_SETUP_READINESS_MODEL=" + ("PASS" if _d8_model else "FAIL"))
print("SABLE_SETUP_LAUNCH_SAFETY=" + ("PASS" if _d8_launch else "FAIL"))
print("SABLE_SETUP_WORDING=" + ("PASS" if _d8_wording else "FAIL"))
print("SABLE_SETUP_DEFAULT_APP_TRUTHFULNESS=" + ("PASS" if _d8_default else "FAIL"))
print("SABLE_SETUP_PROFILE_UNKNOWN=" + ("PASS" if _d8_profile else "FAIL"))
print("SABLE_SETUP_SCOPE=" + ("PASS_EXCLUSIONS_ABSENT" if _d8_scope else "FAIL"))
print("D8_SETUP_HELPER_SOURCE_CONTRACT=" + ("PASS" if all([_d8_model, _d8_launch, _d8_wording, _d8_default, _d8_profile, _d8_scope]) else "FAIL"))
if errs:
    for e in errs: print("STATIC_FAIL:", e, file=sys.stderr)
    sys.exit(1)
print("static checks ok: %d tracked files, %d surfaces, %d interface requests, %d modules, %d ownership rows" % (len(ALL), len(matrix), len(irs), len(mods), len(own)))
PY
}

case "$MODE" in
static)
    run_static
    if [[ -n "$(git status --porcelain)" ]]; then echo "C3B_PRODUCT_SOURCE_STATIC_QUALIFICATION=DIRTY_NOT_QUALIFIED"; exit 1; fi
    echo "C3B_PRODUCT_SOURCE_STATIC_QUALIFICATION=PASS"
    ;;
full)
    run_static
    changed=""; android=YES
    changed="$(git diff --name-only "$BASE"...HEAD)"
    if ! grep -E '\.(kt|java)$|AndroidManifest\.xml$|\.gradle(\.kts)?$|\.toml$|/res/|/assets/|\.bp$|\.mk$|^\.editorconfig$|^config/' <<<"$changed" >/dev/null; then android=NO; fi
    if [[ "$android" == NO ]]; then
        echo "C3B_PRODUCT_FULL_ANDROID_CHECKS=NOT_APPLICABLE_NO_ANDROID_SOURCE_CHANGE"
    else
        # Offline operator gate: the Gradle distribution cache and a committed, reviewed verification-metadata.xml must already exist.
        # (D2: the one-time online bootstrap is build/titan2/bootstrap-gradle-verification.sh, never run from here.)
        GUH="${GRADLE_USER_HOME:-$HOME/.gradle}"
        for ws in apps/titan2/platform apps/titan2/screens; do
            [[ -s "$ws/gradle/verification-metadata.xml" ]] || fail "DEPENDENCY_VERIFICATION_METADATA_MISSING workspace=$ws (OPERATOR_BOOTSTRAP_REQUIRED)"
            [[ -x "$ws/gradlew" ]] || fail "NO_GRADLEW $ws"
            ver="$(sed -n 's#^distributionUrl=.*/gradle-\([0-9][0-9.]*\)-bin\.zip#\1#p' "$ws/gradle/wrapper/gradle-wrapper.properties")"
            [[ -n "$ver" ]] || fail "GRADLE_VERSION_UNREADABLE workspace=$ws"
            # Same location the Gradle wrapper itself uses: wrapper/dists/<name>/<base36 md5 of distributionUrl>/ plus the .ok marker.
            dist="$(python3 - "$ws/gradle/wrapper/gradle-wrapper.properties" "$GUH" <<'PY2'
import hashlib, sys
url = [l.split("=", 1)[1].strip().replace("\\:", ":") for l in open(sys.argv[1]) if l.startswith("distributionUrl=")][0]
n = int(hashlib.md5(url.encode()).hexdigest(), 16); d = ""
while n: n, r = divmod(n, 36); d = "0123456789abcdefghijklmnopqrstuvwxyz"[r] + d
name = url.rsplit("/", 1)[1][:-4]
print("%s/wrapper/dists/%s/%s" % (sys.argv[2], name, d or "0"))
PY2
)"
            [[ -x "$dist/gradle-$ver/bin/gradle" && -e "$dist/gradle-$ver-bin.zip.ok" ]] \
                || fail "GRADLE_DISTRIBUTION_CACHE_MISSING workspace=$ws version=$ver gradle_user_home=$GUH"
        done
        for ws in apps/titan2/platform apps/titan2/screens; do
            ( cd "$ws" && ./gradlew --offline --dependency-verification=strict assembleRelease test lint detekt ktlintCheck --stacktrace --console=plain --no-daemon ) || fail "GRADLE_OFFLINE $ws"
        done
        echo "C3B_PRODUCT_FULL_QUALITY_TASKS=detekt,ktlintCheck"
        echo "C3B_PRODUCT_FULL_ANDROID_CHECKS=PASS"
    fi
    echo "C3B_PRODUCT_SOURCE_QUALIFICATION=PASS"
    ;;
esac
