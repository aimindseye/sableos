#!/usr/bin/env python3
"""N1I-B2 native rederivation / JNI attribution self-test (synthetic fixtures built at test time).

Prints CASE<TAB>native<TAB>id<TAB>PASS|FAIL<TAB>detail ; exit 0 only if every case passes.
Missing javac / dx-or-d8 / dexdump / clang+lld / gcc is a FAIL, never a skip.
"""
from __future__ import annotations

import hashlib
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
sys.path.insert(0, str(HERE / "lib"))
from toolchain import compile_dex, find_dex_compiler, prepare_tool_path  # noqa: E402

prepare_tool_path(("java", "javac", "d8", "dx", "dexdump", "clang", "ld.lld", "gcc", "readelf"))
sys.path.insert(0, str(ROOT / "build/titan2"))
import n1i_static as S  # noqa: E402

TOOL = ROOT / "build/titan2/n1i-b2-native.py"
FX = HERE / "fixtures"
NAT = FX / "native"
FAILS = 0


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    print(f"CASE\tnative\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " ")[:500])
    FAILS += 0 if ok else 1


def sh(cmd) -> subprocess.CompletedProcess:
    return subprocess.run([str(c) for c in cmd], capture_output=True, text=True)


def refix(data: bytearray) -> bytes:
    data[12:32] = hashlib.sha1(bytes(data[32:])).digest()
    struct.pack_into("<I", data, 8, zlib.adler32(bytes(data[12:])) & 0xFFFFFFFF)
    return bytes(data)


def craft_moved(dex_path: Path) -> bytes:
    """Replace Loaders.moved() with two crafted chains:
         A: const-string v1,"vend" ; move-object/from16 v2,v1 ; move-object v0,v2 ; invoke-static {v0} loadLibrary
         B: const-string v4,"vend" ; const-wide/16 v3,#1 (writes v3,v4) ; invoke-static {v4} loadLibrary
         C: const-string v5,"vend" ; return-void ; invoke-static {v5} loadLibrary   (dead code after return)"""
    data = bytearray(dex_path.read_bytes())
    dex = S.DexFile(bytes(data))
    m = next(m for c in dex.classes if c.descriptor == "Lp/Loaders;" for m in c.methods if m.ref.name == "moved")
    sidx = dex.strings.index("vend")
    midx = dex.method_ids.index(S.MethodRef("Ljava/lang/System;", "loadLibrary", "(Ljava/lang/String;)V"))
    u = [0x011a, sidx, 0x0208, 0x0001, 0x2007, 0x1071, midx, 0x0000,
         0x041a, sidx, 0x0316, 0x0001, 0x1071, midx, 0x0004, 0x000e,
         0x051a, sidx, 0x000e, 0x1071, midx, 0x0005, 0x000e]
    if len(u) > m.code.insns_units:
        raise RuntimeError(f"crafted body {len(u)} > {m.code.insns_units}")
    u += [0] * (m.code.insns_units - len(u))
    struct.pack_into(f"<{len(u)}H", data, m.code.insns_off, *u)
    return refix(data)


def build(td: Path) -> dict:
    compiler = find_dex_compiler()
    need = {"javac": shutil.which("javac"), "dex_compiler": compiler, "dexdump": shutil.which("dexdump"),
            "clang": shutil.which("clang"), "ld.lld": shutil.which("ld.lld"), "gcc": shutil.which("gcc")}
    if not all(need.values()):
        raise RuntimeError(f"missing tools {[k for k, v in need.items() if not v]}")
    core = td / "coresrc"
    shutil.copytree(FX / "members/core", core)
    shutil.copytree(NAT / "java/java", core / "java", dirs_exist_ok=True)
    jc = ["javac", "-nowarn", "-source", "8", "-target", "8"]
    r = sh(jc + ["-bootclasspath", core, "-sourcepath", core, "-d", td / "core"] + sorted(core.rglob("*.java")))
    if r.returncode:
        raise RuntimeError("javac core: " + r.stderr[-300:])
    r = sh(jc + ["-bootclasspath", td / "core", "-d", td / "app"] + sorted((NAT / "java/app").rglob("*.java")))
    if r.returncode:
        raise RuntimeError("javac app: " + r.stderr[-300:])
    r = compile_dex(compiler, td / "app", td / "app.dex", min_api=26)
    if r.returncode:
        raise RuntimeError(f"{compiler[0]}: " + r.stderr[-300:])
    (td / "app-crafted.dex").write_bytes(craft_moved(td / "app.dex"))

    cc = ["clang", "--target=aarch64-linux-gnu", "-fuse-ld=lld", "-shared", "-fPIC", "-nostdlib"]
    dirs = {k: td / k for k in ("system", "apex", "vendor", "link", "apklib")}
    for d in dirs.values():
        d.mkdir()

    def so(src: Path, out: Path, soname: str, libs=(), extra=()):
        r = sh(cc + [f"-Wl,-soname,{soname}", f"-L{dirs['link']}", "-o", out, src, *extra, *[f"-l{l}" for l in libs]])
        if r.returncode:
            raise RuntimeError(f"clang {src.name}: {r.stderr[-300:]}")

    so(FX / "elf/dep.c", dirs["link"] / "libdep.so", "libdep.so")
    so(NAT / "elf/vendoronly.c", dirs["link"] / "libvendoronly.so", "libvendoronly.so")
    so(NAT / "elf/gone.c", dirs["link"] / "libgone.so", "libgone.so")
    so(FX / "elf/synth.c", dirs["apklib"] / "libsynth.so", "libsynth.so", ["dep"])
    so(NAT / "elf/vend.c", dirs["apklib"] / "libvend.so", "libvend.so", ["vendoronly", "gone"])
    shutil.copy(dirs["link"] / "libdep.so", dirs["apex"] / "libdep.so")           # explicitly public in tests
    shutil.copy(dirs["link"] / "libgone.so", dirs["system"] / "libprivate.so")     # present but not namespace-public
    shutil.copy(dirs["link"] / "libvendoronly.so", dirs["vendor"] / "libvendoronly.so")  # present, visibility unproven
    r = sh(["gcc", "-shared", "-fPIC", "-nostdlib", "-o", td / "libsynth-x86_64.so", NAT / "elf/gone.c"])
    if r.returncode:
        raise RuntimeError("gcc: " + r.stderr[-200:])

    def apk(name: str, dex: Path, extra_entries: dict | None = None) -> Path:
        p = td / name
        with zipfile.ZipFile(p, "w") as z:
            z.write(dex, "classes.dex")
            z.write(dirs["apklib"] / "libsynth.so", "lib/arm64-v8a/libsynth.so")
            z.write(dirs["apklib"] / "libvend.so", "lib/arm64-v8a/libvend.so")
            z.write(td / "libsynth-x86_64.so", "lib/x86_64/libsynth.so")
            for k, v in (extra_entries or {}).items():
                z.writestr(k, v)
        return p

    return {"apk": apk("app.apk", td / "app-crafted.dex"),
            "badapk": apk("bad.apk", td / "app-crafted.dex", {"lib/arm64-v8a/libbroken.so": b"\x7fELF\x02\x01\x01" + b"\0" * 20}),
            **dirs}


def run(f: dict, td: Path, name: str, extra=()) -> tuple[subprocess.CompletedProcess, dict]:
    r = sh([sys.executable, TOOL, "--side", "c3a", "--apk", f["apk"], "--lib-dir", f"system={f['system']}",
            "--lib-dir", f"apex={f['apex']}", "--lib-dir", f"vendor={f['vendor']}",
            "--namespace-visible-library", "libdep.so", "--badging", NAT / "badging.txt",
            "--search-superset", NAT / "n1i-a-superset.txt", "--out", td / name, *extra])
    out = {}
    if r.returncode == 0:
        for n in ("LOAD_SITES", "NATIVE_CLOSURE", "JNI_ATTRIBUTION", "NATIVE_ROOTS", "SEARCH_SUPERSET"):
            lines = (td / name / f"{n}.tsv").read_text().splitlines()
            head = lines[0].split("\t")
            out[n] = [dict(zip(head, l.split("\t"))) for l in lines[1:]]
        out["env"] = dict(l.split("=", 1) for l in (td / name / "NATIVE_SUMMARY.env").read_text().splitlines())
    return r, out


def site(rows: list, method: str, nth: int = 0) -> dict:
    hits = [r for r in rows if f"->{method}(" in r["site"]]
    return hits[nth] if len(hits) > nth else {}


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        try:
            f = build(td / "b")
            case("fixture_build", True, "javac+dx, clang aarch64+lld, gcc x86_64")
        except RuntimeError as e:
            case("fixture_build", False, str(e))
            return 1
        r, o = run(f, td, "main")
        case("derive_exit0", r.returncode == 0, r.stderr[-300:])
        if r.returncode:
            return 1
        ls, env = o["LOAD_SITES"], o["env"]

        c = site(ls, "constant")
        case("true_constant_loader", c.get("status") == "CONSTANT" and c.get("value") == "synth", str(c.get("value")))
        u = site(ls, "unrelatedString")
        case("unrelated_string_in_same_method_not_used", u.get("status") == "DYNAMIC_LOAD_UNRESOLVED"
             and "move-result-object" in u.get("reason", ""), u.get("reason", "-"))
        w = site(ls, "overwritten")
        case("register_overwrite_before_call", w.get("status") == "DYNAMIC_LOAD_UNRESOLVED"
             and "computed by move-result-object" in w.get("reason", ""), w.get("reason", "-"))
        p = site(ls, "parameter")
        case("parameter_argument_unresolved", p.get("status") == "DYNAMIC_LOAD_UNRESOLVED"
             and "parameter" in p.get("reason", ""), p.get("reason", "-"))
        b = site(ls, "branch")
        case("computed_by_control_flow_join_unresolved", b.get("status") == "DYNAMIC_LOAD_UNRESOLVED"
             and "block boundary" in b.get("reason", ""), b.get("reason", "-"))
        rt = site(ls, "runtime")
        case("runtime_loadlibrary_uses_second_register", rt.get("status") == "CONSTANT" and rt.get("value") == "rtlib", "")
        ab = site(ls, "absolute")
        case("system_load_absolute_path", ab.get("status") == "CONSTANT" and ab.get("api") == "load"
             and ab.get("value") == "/system/lib64/libabs.so", "")
        mv = site(ls, "moved", 0)
        case("simple_move_const_propagation", mv.get("status") == "CONSTANT" and mv.get("value") == "vend"
             and "move-object/from16" in mv.get("proof_chain", "") and "move-object" in mv.get("proof_chain", ""),
             mv.get("proof_chain", "-"))
        wd = site(ls, "moved", 1)
        case("wide_write_clobbers_argument", wd.get("status") == "DYNAMIC_LOAD_UNRESOLVED"
             and "wide" in wd.get("reason", ""), wd.get("reason", "-"))
        dd = site(ls, "moved", 2)
        case("dead_code_after_return_unresolved", dd.get("status") == "DYNAMIC_LOAD_UNRESOLVED"
             and "after return-void" in dd.get("reason", ""), dd.get("reason", "-"))
        case("load_site_strength_dex_callsite", all(x["evidence_strength"] == "DEX_CALLSITE" for x in ls), "")
        case("unresolved_count", env.get("N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED") == "6",
             env.get("N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED", "-"))

        lib = {x["library"]: x for x in o["NATIVE_CLOSURE"]}
        case("decoy_string_never_admitted", "libdecoylib.so" not in lib, "")
        case("apk_packaged_root", lib.get("libsynth.so", {}).get("status") == "FOUND"
             and lib["libsynth.so"]["provider_class"] == "APK_PACKAGED", "")
        case("dt_needed_platform_apex_provider", lib.get("libdep.so", {}).get("partition") == "apex"
             and lib["libdep.so"]["provider_class"] == "PLATFORM_OR_APEX"
             and lib["libdep.so"]["namespace_visibility"] == "EXPLICIT"
             and "DT_NEEDED:libsynth.so" in lib["libdep.so"]["admitted_by"]
             and "USES_NATIVE_LIBRARY:required" in lib["libdep.so"]["admitted_by"], lib.get("libdep.so", {}).get("admitted_by", "-"))
        case("vendor_file_namespace_unproven", lib.get("libvendoronly.so", {}).get("status")
             == "FILE_PRESENT_NAMESPACE_UNPROVEN"
             and lib["libvendoronly.so"].get("namespace_visibility") == "UNPROVEN"
             and env.get("N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN") == "libvendoronly.so"
             and env.get("N1I_B2_NATIVE_NAMESPACE_VISIBILITY_INFERRED") == "NO", "")
        case("dt_needed_missing_reported", lib.get("libgone.so", {}).get("status") == "NOT_FOUND", "")
        r, op = run(f, td, "private", ["--uses-native-library", "libprivate.so:required"])
        plib = {x["library"]: x for x in op.get("NATIVE_CLOSURE", [])}
        case("system_file_presence_not_namespace_proof",
             plib.get("libprivate.so", {}).get("status") == "FILE_PRESENT_NAMESPACE_UNPROVEN"
             and plib.get("libprivate.so", {}).get("namespace_visibility") == "UNPROVEN"
             and op.get("env", {}).get("N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING") == "libprivate.so", "")
        r, ov = run(f, td, "vendor-visible", ["--namespace-visible-library", "libvendoronly.so"])
        vlib = {x["library"]: x for x in ov.get("NATIVE_CLOSURE", [])}
        case("explicit_vendor_namespace_visibility_can_admit",
             vlib.get("libvendoronly.so", {}).get("status") == "FOUND"
             and vlib["libvendoronly.so"].get("partition") == "vendor"
             and vlib["libvendoronly.so"].get("namespace_visibility") == "EXPLICIT", "")
        case("constant_load_roots_resolved_or_reported", lib.get("librtlib.so", {}).get("status") == "NOT_FOUND"
             and lib.get("libabs.so", {}).get("status") == "NOT_FOUND"
             and "LOADLIBRARY:" in lib.get("libvend.so", {}).get("admitted_by", ""), "")
        case("optional_uses_native_library_absent_not_required_missing",
             lib.get("libnotthere.so", {}).get("status") == "NOT_FOUND"
             and env.get("N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING") == "NONE", "")
        case("file_backed_sha256_recorded", len(lib.get("libsynth.so", {}).get("sha256", "")) == 64
             and lib.get("libgone.so", {}).get("sha256") == "-", "")
        case("other_abi_ignored", env.get("N1I_B2_NATIVE_APK_LIBS_OTHER_ABI_IGNORED") == "1", "")
        case("evidence_candidates_exclude_platform", env.get("N1I_B2_NATIVE_EVIDENCE_CANDIDATES") == "libsynth.so,libvend.so"
             and env.get("N1I_B2_NATIVE_EVIDENCE_CANDIDATE_COUNT") == "2", env.get("N1I_B2_NATIVE_EVIDENCE_CANDIDATES", "-"))
        sup = {x["library"]: x["admitted_by_evidence"] for x in o["SEARCH_SUPERSET"]}
        case("search_superset_compared_not_rooted", sup.get("libkeyword_ims_only.so") == "NO_SEARCH_SUPERSET_ONLY"
             and sup.get("libsynth.so") == "YES" and env.get("N1I_B2_NATIVE_SEARCH_SUPERSET_COUNT") == "3"
             and env.get("N1I_B2_NATIVE_KEYWORD_ROOTS_USED") == "NO", "")

        jni = {(x["class"], x["method"], x["proto"]): x for x in o["JNI_ATTRIBUTION"]}
        a = jni.get(("Lp/Ops;", "nativeInstance", "(I)I"), {})
        case("java_export_mapping", a.get("attribution") == "CONFIRMED_JAVA_EXPORT" and a.get("libraries") == "libsynth.so"
             and a.get("evidence_strength") == "ELF_REFERENCE", a.get("symbols", "-"))
        a = jni.get(("Lcom/example/Foo_Bar;", "over", "(ILjava/lang/String;)I"), {})
        case("java_export_long_name_overload", a.get("attribution") == "CONFIRMED_JAVA_EXPORT"
             and a.get("symbols") == "Java_com_example_Foo_1Bar_over__ILjava_lang_String_2", a.get("symbols", "-"))
        a = jni.get(("Lcom/example/Foo_Bar;", "over", "(J)I"), {})
        case("other_overload_without_export_unresolved", a.get("attribution") == "UNRESOLVED", a.get("attribution", "-"))
        a = jni.get(("Lcom/example/synth/NativeBridge;", "nativeRegistered", "(ILjava/lang/String;)V"), {})
        case("registernatives_string_is_candidate_only", a.get("attribution") == "CANDIDATE_ONLY"
             and a.get("evidence_strength") == "STRING_ONLY", a.get("attribution", "-"))
        a = jni.get(("Lp/Ops;", "nativeUnmapped", "()V"), {})
        case("unmapped_native_unresolved", a.get("attribution") == "UNRESOLVED", "")
        case("dexdump_oracle_on_app", env.get("N1I_B2_NATIVE_DEXDUMP_ORACLE") == "PASS(app:1)",
             env.get("N1I_B2_NATIVE_DEXDUMP_ORACLE", "-"))

        reg = td / "registrations.tsv"
        reg.write_text("Lcom/example/synth/NativeBridge;\tnativeRegistered\t(ILjava/lang/String;)V\tlibsynth.so\n")
        r, o2 = run(f, td, "rt", ["--runtime-registrations", reg])
        a = {(x["class"], x["method"]): x for x in o2.get("JNI_ATTRIBUTION", [])}.get(
            ("Lcom/example/synth/NativeBridge;", "nativeRegistered"), {})
        case("registernatives_confirmed_only_by_runtime_evidence", a.get("attribution") == "CONFIRMED_REGISTERNATIVES"
             and a.get("evidence_strength") == "RUNTIME_OBSERVED", a.get("attribution", "-"))
        r, o3 = run(f, td, "req", ["--uses-native-library", "libmust.so:required"])
        case("required_uses_native_library_missing_flagged",
             o3.get("env", {}).get("N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING") == "libmust.so", "")

        r = sh([sys.executable, TOOL, "--side", "c3a", "--apk", f["apk"], "--abi", "mips", "--out", td / "badabi"])
        case("unknown_abi_refused", r.returncode == 2 and not (td / "badabi").exists(), f"rc={r.returncode}")
        r = sh([sys.executable, TOOL, "--side", "c3a", "--apk", f["apk"], "--lib-dir", "data=/tmp", "--out", td / "baddir"])
        case("unknown_partition_refused", r.returncode == 2 and not (td / "baddir").exists(), f"rc={r.returncode}")
        r = sh([sys.executable, TOOL, "--side", "c3a", "--apk", f["badapk"], "--out", td / "badelf"])
        case("malformed_elf_fails_closed", r.returncode == 2 and not (td / "badelf").exists(), r.stderr[-160:])
        r, _ = run(f, td, "main")
        case("nonempty_output_refused", r.returncode == 2, f"rc={r.returncode}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
