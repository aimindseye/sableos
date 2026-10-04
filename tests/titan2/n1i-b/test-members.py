#!/usr/bin/env python3
"""N1I-B2 exact member resolver self-test (synthetic fixtures built at test time).

Prints CASE<TAB>members<TAB>id<TAB>PASS|FAIL<TAB>detail ; exit 0 only if every case passes.
Missing javac / dx-or-d8 / dexdump is a FAIL, never a skip.
"""
from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
sys.path.insert(0, str(HERE / "lib"))
from toolchain import compile_dex, find_dex_compiler, prepare_tool_path  # noqa: E402

prepare_tool_path(("java", "javac", "d8", "dx", "dexdump"))
TOOL = ROOT / "build/titan2/n1i-b2-members.py"
FX = HERE / "fixtures/members"
FAILS = 0

# (caller, ref_kind, owner, name) -> expected result on the STOCK side
EXPECT_STOCK = {
    ("Lapp/Main;", "invoke-direct", "Lfw/Base;", "<init>"): "RESOLVED",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Base;", "m"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Lfw/Base;", "sm"): "RESOLVED",
    ("Lapp/Main;", "sget", "Lfw/Base;", "sfield"): "RESOLVED",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Base;", "changed"): "DESCRIPTOR_MISMATCH",
    ("Lapp/Main;", "invoke-static", "Lfw/Base;", "flip"): "STATIC_INSTANCE_MISMATCH",
    ("Lapp/Main;", "sget", "Lfw/Base;", "fflip"): "STATIC_INSTANCE_MISMATCH",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Base;", "gone"): "METHOD_MISSING",
    ("Lapp/Main;", "iget", "Lfw/Base;", "goneField"): "FIELD_MISSING",
    ("Lapp/Main;", "invoke-static", "Lfw/Removed;", "r"): "CLASS_MISSING",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Base;", "wasPublic"): "ACCESS_VIOLATION",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Base;", "becameProtected"): "ACCESS_VIOLATION",
    ("Lapp/Main;", "iput", "Lfw/Base;", "fin2"): "ACCESS_VIOLATION",
    ("Lapp/Main;", "invoke-virtual", "Lfw/WasClass;", "w"): "ICCE_KIND",
    ("Lapp/Main;", "invoke-interface", "Lfw/WasIface;", "i"): "ICCE_KIND",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Child;", "m"): "RESOLVED",
    ("Lapp/Main;", "iget", "Lfw/Child;", "v"): "RESOLVED",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Child;", "d"): "RESOLVED",
    ("Lapp/Main;", "invoke-interface", "Lfw/Api;", "d"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Lfw/Api;", "st"): "RESOLVED",
    ("Lapp/Main;", "invoke-virtual", "Lfw/Base;", "mtkOnly"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Lfw/MtkThing;", "x"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Lax/ApexApi;", "call"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Lsvc/SystemThing;", "x"): "CLASS_MISSING",
    ("Lapp/Main;", "invoke-static", "Llr/ReqLib;", "r"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Llo/OptLib;", "o"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Lfw/Dup;", "who"): "RESOLVED",
    ("Lapp/Main;", "invoke-static", "Lfw/Dup;", "appOnly"): "METHOD_MISSING",
    ("Lapp/Main;", "invoke-static", "Lfw/AppPeer;", "peek"): "RESOLVED",
    ("Lfw/AppPeer;", "invoke-virtual", "Lfw/Base;", "pkgm"): "ACCESS_VIOLATION",
    ("Lapp/Sub;", "invoke-super", "Lfw/Base;", "m"): "RESOLVED",
    ("Lapp/Sub;", "invoke-super", "Lfw/Api;", "d"): "RESOLVED",
    ("Lapp/Sub;", "invoke-virtual", "Lapp/Sub;", "pm"): "RESOLVED",
    ("Lapp/Lam;", "invoke-polymorphic", "Ljava/lang/invoke/MethodHandle;", "invoke"): "RESOLVED",
    ("Lapp/Lam;", "invoke-custom-bootstrap/method-handle-invoke-static", "Ljava/lang/invoke/LambdaMetafactory;",
     "metafactory"): "RESOLVED",
    ("Lapp2/Second;", "invoke-virtual", "Lapp2/Second;", "m"): "RESOLVED",
}


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    print(f"CASE\tmembers\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " ")[:500])
    FAILS += 0 if ok else 1


def sh(cmd) -> subprocess.CompletedProcess:
    return subprocess.run([str(c) for c in cmd], capture_output=True, text=True)


def build(td: Path) -> dict:
    compiler = find_dex_compiler()
    if not (shutil.which("javac") and compiler and shutil.which("dexdump")):
        raise RuntimeError("javac, dx-or-d8 and dexdump are required")
    jc = ["javac", "-nowarn", "-source", "8", "-target", "8"]

    def javac(args, srcdir: Path):
        srcs = sorted(str(p) for p in srcdir.rglob("*.java"))
        r = sh(jc + args + srcs)
        if r.returncode:
            raise RuntimeError(f"javac {srcdir.name}: {r.stderr[-400:]}")

    def dex(clsdir: Path, out: Path, core=False):
        r = compile_dex(compiler, clsdir, out, min_api=26, core_library=core)
        if r.returncode:
            raise RuntimeError(f"{compiler[0]} {clsdir.name}: {r.stderr[-400:]}")

    c = {}
    javac(["-bootclasspath", FX / "core", "-sourcepath", FX / "core", "-d", td / "core"], FX / "core")
    # core2: the same core without LambdaMetafactory and without MethodHandle.invoke (negative runtime)
    core2src = td / "core2src"
    shutil.copytree(FX / "core", core2src)
    (core2src / "java/lang/invoke/LambdaMetafactory.java").unlink()
    mh = core2src / "java/lang/invoke/MethodHandle.java"
    # keep a method NAMED invoke, but not native/varargs: it must not count as signature-polymorphic
    mh.write_text("\n".join(l if "Object invoke(" not in l else "  public final Object invoke(String s) { return null; }"
                            for l in mh.read_text().splitlines()) + "\n")
    javac(["-bootclasspath", core2src, "-sourcepath", core2src, "-d", td / "core2"], core2src)
    for x in ("fw-compile", "fw-stock", "fw-c3a", "apex", "svc", "libreq", "libopt"):
        javac(["-bootclasspath", td / "core", "-d", td / x], FX / x)
    cp = ":".join(str(td / x) for x in ("fw-compile", "apex", "svc", "libreq", "libopt"))
    javac(["-bootclasspath", td / "core", "-cp", cp, "-d", td / "app"], FX / "app")
    javac(["-bootclasspath", td / "core", "-cp", f"{cp}:{td / 'app'}", "-d", td / "app2"], FX / "app2")
    dex(td / "core", td / "core.dex", core=True)
    dex(td / "core2", td / "core2.dex", core=True)
    for x in ("fw-stock", "fw-c3a", "apex", "svc", "libreq", "libopt", "app", "app2"):
        dex(td / x, td / f"{x}.dex")
    with zipfile.ZipFile(td / "app.apk", "w") as z:
        z.write(td / "app.dex", "classes.dex")
        z.write(td / "app2.dex", "classes2.dex")
    return {k: td / f"{k}.dex" for k in ("core", "core2", "fw-stock", "fw-c3a", "apex", "svc", "libreq", "libopt")} | {
        "apk": td / "app.apk"}


def resolve(f: dict, td: Path, name: str, side: str = "stock", core: str = "core", req=True, opt=True,
            non_visible=True, extra=()):
    args = [sys.executable, TOOL, "resolve", "--side", side, "--app", f["apk"],
            "--bootclasspath", f[core], "--bootclasspath", f[f"fw-{side}"], "--bootclasspath", f["apex"],
            "--apex-jar", f["apex"], "--badging", FX / "badging.txt", "--out", td / name, *extra]
    if req:
        args += ["--shared-lib", f"com.example.req={f['libreq']}"]
    if opt:
        args += ["--shared-lib", f"com.example.opt={f['libopt']}"]
    if non_visible:
        args += ["--non-visible", f["svc"]]
    r = sh(args)
    rows, env = {}, {}
    if (td / name / "MEMBERS.tsv").is_file():
        lines = (td / name / "MEMBERS.tsv").read_text().splitlines()
        head = lines[0].split("\t")
        for l in lines[1:]:
            d = dict(zip(head, l.split("\t")))
            rows[(d["caller"], d["ref_kind"], d["owner"], d["name"])] = d
        env = dict(l.split("=", 1) for l in (td / name / "MEMBERS_SUMMARY.env").read_text().splitlines())
    return r, rows, env


def load_member_tool():
    spec = importlib.util.spec_from_file_location("n1i_b2_members", TOOL)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load member resolver module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def semantic_rule_tests() -> None:
    m = load_member_tool()

    def klass(desc, *, superclass=None, interfaces=(), fields=(), access=0):
        cd = SimpleNamespace(
            descriptor=desc,
            superclass=superclass,
            interfaces=tuple(interfaces),
            fields=[
                SimpleNamespace(ref=SimpleNamespace(name=name, type=ftype), access=0)
                for name, ftype in fields
            ],
            methods=[],
            access=access,
        )
        return m.Klass(cd, "boot", "BOOT", desc)

    # JVMS field resolution: class -> direct superinterfaces recursively -> superclass recursively.
    # An interface inherited only through Base must not beat Base's own field.
    w = m.World()
    obj = klass("Ljava/lang/Object;", access=m.S.ACC_PUBLIC)
    iface = klass("Lfw/FieldCarrier;", interfaces=(), fields=(("order", "I"),),
                  access=m.S.ACC_PUBLIC | m.S.ACC_INTERFACE)
    base = klass("Lfw/Base;", superclass=obj.desc, interfaces=(iface.desc,), fields=(("order", "I"),),
                 access=m.S.ACC_PUBLIC)
    child = klass("Lfw/Child;", superclass=base.desc, access=m.S.ACC_PUBLIC)
    for k in (obj, iface, base, child):
        w.classes[k.desc] = k
    decl, field, missing = m.lookup_field(w, child, "order", "I")
    case("field_resolution_superclass_before_its_interfaces",
         decl is not None and decl.desc == base.desc and field is not None and missing is None,
         decl.desc if decl else str(missing))

    root_i = klass("Lfw/RootI;", access=m.S.ACC_PUBLIC | m.S.ACC_INTERFACE)
    left_i = klass("Lfw/LeftI;", interfaces=(root_i.desc,), access=m.S.ACC_PUBLIC | m.S.ACC_INTERFACE)
    right_i = klass("Lfw/RightI;", interfaces=(root_i.desc,), access=m.S.ACC_PUBLIC | m.S.ACC_INTERFACE)
    diamond_i = klass("Lfw/DiamondI;", interfaces=(left_i.desc, right_i.desc),
                      access=m.S.ACC_PUBLIC | m.S.ACC_INTERFACE)
    for k in (root_i, left_i, right_i, diamond_i):
        w.classes[k.desc] = k
    decl, field, missing = m.lookup_field(w, diamond_i, "absent", "I")
    case("field_resolution_diamond_not_cycle",
         decl is None and field is None and missing is None, str(missing))

    # Cross-package protected instance access also constrains the symbolic owner.
    caller = klass("Lapp/Sub;", superclass=base.desc, access=m.S.ACC_PUBLIC)
    sibling = klass("Lfw/Sibling;", superclass=base.desc, access=m.S.ACC_PUBLIC)
    for k in (caller, sibling):
        w.classes[k.desc] = k
    ok, why = m.member_accessible(w, caller, sibling, base, m.S.ACC_PROTECTED, False)
    case("protected_symbolic_owner_sibling_rejected", not ok and "symbolic owner" in why, why)
    ok, why = m.member_accessible(w, caller, base, base, m.S.ACC_PROTECTED, False)
    case("protected_symbolic_owner_superclass_allowed", ok, why)


def main() -> int:
    semantic_rule_tests()
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        try:
            f = build(td / "build")
            case("fixture_build", True, f"javac -source 8 + {find_dex_compiler()[0]}")
        except RuntimeError as e:
            case("fixture_build", False, str(e))
            return 1

        r, rows, env = resolve(f, td, "stock")
        case("resolve_stock_exit0", r.returncode == 0, r.stderr[-300:])
        for key, want in EXPECT_STOCK.items():
            got = rows.get(key, {}).get("result", "NOT_FOUND")
            case(f"stock:{want}:{key[0]}:{key[1]}:{key[2]}->{key[3]}", got == want, f"got={got}")
        for res in ("CLASS_MISSING", "METHOD_MISSING", "FIELD_MISSING", "DESCRIPTOR_MISMATCH",
                    "STATIC_INSTANCE_MISMATCH", "ACCESS_VIOLATION", "ICCE_KIND"):
            case(f"result_class_exercised:{res}", int(env.get(f"N1I_B2_MEMBERS_{res}", "0")) >= 1,
                 env.get(f"N1I_B2_MEMBERS_{res}", "-"))
        lines = (td / "stock/MEMBERS.tsv").read_text().splitlines()
        ctor_rows = [l.split("\t") for l in lines if "\tLfw/Child;\t<init>\t(I)V\t" in l]
        case("constructor_not_inherited", len(ctor_rows) == 1 and ctor_rows[0][6] == "METHOD_MISSING"
             and "not inherited" in ctor_rows[0][7], ctor_rows[0][7] if ctor_rows else "missing row")
        ok0 = [l.split("\t") for l in lines if "\tLfw/Child;\t<init>\t()V\t" in l]
        case("declared_constructor_resolves", len(ok0) == 1 and ok0[0][6] == "RESOLVED", "")
        inh = rows.get(("Lapp/Main;", "invoke-virtual", "Lfw/Child;", "m"), {})
        case("inherited_method_resolved_in_superclass", inh.get("resolved_in") == "Lfw/Base;", inh.get("resolved_in", "-"))
        dflt = rows.get(("Lapp/Main;", "invoke-virtual", "Lfw/Child;", "d"), {})
        case("interface_default_via_class", dflt.get("resolved_in") == "Lfw/Api;", dflt.get("resolved_in", "-"))
        apex = rows.get(("Lapp/Main;", "invoke-static", "Lax/ApexApi;", "call"), {})
        case("apex_provided_passes", apex.get("result") == "RESOLVED" and apex.get("provider") == "APEX", apex.get("provider", "-"))
        svc = rows.get(("Lapp/Main;", "invoke-static", "Lsvc/SystemThing;", "x"), {})
        case("services_jar_only_fails", svc.get("result") == "CLASS_MISSING" and "non-visible" in svc.get("detail", ""),
             svc.get("detail", "-"))
        req = rows.get(("Lapp/Main;", "invoke-static", "Llr/ReqLib;", "r"), {})
        case("required_uses_library_provider", req.get("provider") == "SHARED_LIB:com.example.req", req.get("provider", "-"))
        who = rows.get(("Lapp/Main;", "invoke-static", "Lfw/Dup;", "who"), {})
        case("boot_wins_over_app_duplicate", who.get("provider") == "BOOT"
             and env.get("N1I_B2_MEMBERS_APP_CLASSES_SHADOWED") == "1", who.get("provider", "-"))
        dups = (td / "stock/DUPLICATES.tsv").read_text()
        case("duplicate_recorded_with_winner", "Lfw/Dup;\tBOOT:" in dups and "\tAPP:" in dups, "")
        peer = rows.get(("Lfw/AppPeer;", "invoke-virtual", "Lfw/Base;", "pkgm"), {})
        case("package_private_across_loaders", "different class loader" in peer.get("detail", ""), peer.get("detail", "-"))
        sec = rows.get(("Lapp2/Second;", "invoke-virtual", "Lapp2/Second;", "m"), {})
        case("multidex_classes2_analysed", sec.get("resolved_in") == "Lfw/Base;", sec.get("resolved_in", "-"))
        cust = rows.get(("Lapp/Lam;", "invoke-custom-bootstrap/method-handle-invoke-static",
                         "Ljava/lang/invoke/LambdaMetafactory;", "metafactory"), {})
        case("invoke_custom_bootstrap_resolved_in_boot", cust.get("provider") == "BOOT", cust.get("provider", "-"))
        impl = [k for k in rows if k[1].startswith("invoke-custom-arg/") and k[2] == "Lapp/Lam;"]
        case("invoke_custom_impl_handle_resolved", len(impl) == 1 and rows[impl[0]]["result"] == "RESOLVED", str(impl))
        case("evidence_strength_dex_callsite", all(v["evidence_strength"] == "DEX_CALLSITE" for v in rows.values()), "")
        case("dexdump_oracle_on_app", env.get("N1I_B2_MEMBERS_DEXDUMP_ORACLE") == "PASS(app:2)",
             env.get("N1I_B2_MEMBERS_DEXDUMP_ORACLE", "-"))
        checks = (td / "stock/CLASS_CHECKS.tsv").read_text()
        case("class_checks_super_and_interfaces", "Lapp/Sub;\tsuperclass\tLfw/Base;\tRESOLVED" in checks
             and "Lapp/Sub;\tinterface\tLfw/Api;\tRESOLVED" in checks, "")

        # ---- C3A side and compare
        r, crow, cenv = resolve(f, td, "c3a", side="c3a")
        case("resolve_c3a_exit0", r.returncode == 0, r.stderr[-300:])
        case("c3a_mtk_member_missing", crow.get(("Lapp/Main;", "invoke-virtual", "Lfw/Base;", "mtkOnly"), {}).get("result")
             == "METHOD_MISSING", "")
        case("c3a_mtk_class_missing", crow.get(("Lapp/Main;", "invoke-static", "Lfw/MtkThing;", "x"), {}).get("result")
             == "CLASS_MISSING", "")
        r = sh([sys.executable, TOOL, "compare", "--stock", td / "stock", "--c3a", td / "c3a", "--out", td / "cmp"])
        cmp_env = dict(l.split("=", 1) for l in (td / "cmp/MEMBERS_COMPARE.env").read_text().splitlines()) if r.returncode == 0 else {}
        gaps = [l.split("\t") for l in (td / "cmp/BEHAVIOR_GAP_CANDIDATES.tsv").read_text().splitlines()[1:]
                if "STOCK_ONLY_RESOLVES" in l] if r.returncode == 0 else []
        case("compare_gap_candidates_exactly_mtk", sorted(g[3] for g in gaps) == ["mtkOnly", "x"]
             and cmp_env.get("N1I_B2_AOSP_BEHAVIOR_GAP_CANDIDATE_COUNT") == "2", str([g[3] for g in gaps]))
        case("compare_gap_is_candidate_not_authorization",
             all(g[8] == "AOSP_EQUIVALENT_WITH_BEHAVIOR_GAP(candidate)" for g in gaps)
             and cmp_env.get("N1I_B2_MEMBERS_GAP_IS_IMPORT_AUTHORIZATION") == "NO", "")
        case("compare_shared_failures_not_gaps", int(cmp_env.get("N1I_B2_MEMBERS_UNRESOLVED_ON_BOTH_COUNT", "0")) >= 10,
             cmp_env.get("N1I_B2_MEMBERS_UNRESOLVED_ON_BOTH_COUNT", "-"))

        # ---- uses-library variants
        r, orow, oenv = resolve(f, td, "noopt", opt=False)
        case("optional_uses_library_absent", r.returncode == 0
             and orow.get(("Lapp/Main;", "invoke-static", "Llo/OptLib;", "o"), {}).get("result") == "CLASS_MISSING"
             and "com.example.opt:optional:UNAVAILABLE_NOT_LOADED" in oenv.get("N1I_B2_MEMBERS_USES_LIBRARIES", "")
             and oenv.get("N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE") == "NONE", "")
        r, qrow, qenv = resolve(f, td, "noreq", req=False)
        case("required_uses_library_absent", r.returncode == 0
             and qrow.get(("Lapp/Main;", "invoke-static", "Llr/ReqLib;", "r"), {}).get("result") == "CLASS_MISSING"
             and qenv.get("N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE") == "com.example.req", "")
        r, nrow, _ = resolve(f, td, "nonv", non_visible=False)
        case("services_class_missing_without_diagnostic_jar",
             nrow.get(("Lapp/Main;", "invoke-static", "Lsvc/SystemThing;", "x"), {}).get("detail", "")
             .endswith("not on the visible classpath"), "")

        # ---- runtime core without LambdaMetafactory / MethodHandle.invoke
        r, krow, _ = resolve(f, td, "core2", core="core2")
        k = krow.get(("Lapp/Lam;", "invoke-custom-bootstrap/method-handle-invoke-static",
                      "Ljava/lang/invoke/LambdaMetafactory;", "metafactory"), {})
        case("invoke_custom_missing_bootstrap_detected", k.get("result") == "CLASS_MISSING", k.get("result", "-"))
        p = krow.get(("Lapp/Lam;", "invoke-polymorphic", "Ljava/lang/invoke/MethodHandle;", "invoke"), {})
        case("invoke_polymorphic_missing_target_detected", p.get("result") == "METHOD_MISSING", p.get("result", "-"))

        # ---- fail closed
        r = sh([sys.executable, TOOL, "resolve", "--side", "stock", "--app", f["apk"], "--bootclasspath", f["core"],
                "--shared-lib", f"com.example.unknown={f['libopt']}", "--out", td / "badlib"])
        case("undeclared_shared_lib_refused", r.returncode == 2 and not (td / "badlib").exists(), f"rc={r.returncode}")
        r, _, _ = resolve(f, td, "stock")
        case("nonempty_output_refused", r.returncode == 2, f"rc={r.returncode}")
        bad = td / "bad.apk"
        with zipfile.ZipFile(bad, "w") as z:
            z.writestr("classes.dex", f["core"].read_bytes()[:-50])
        r = sh([sys.executable, TOOL, "resolve", "--side", "stock", "--app", bad, "--bootclasspath", f["core"],
                "--out", td / "badapp"])
        case("corrupt_app_dex_refused", r.returncode == 2 and not (td / "badapp").exists(), f"rc={r.returncode}")
        (td / "fake").mkdir()
        (td / "fake/MEMBERS_SUMMARY.env").write_text("N1I_B2_MEMBERS_APP_SHA256=0\n")
        (td / "fake/MEMBERS.tsv").write_text("caller\n")
        r = sh([sys.executable, TOOL, "compare", "--stock", td / "stock", "--c3a", td / "fake", "--out", td / "cmpbad"])
        case("compare_refuses_different_app", r.returncode == 2 and not (td / "cmpbad").exists(), f"rc={r.returncode}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
