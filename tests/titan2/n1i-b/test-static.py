#!/usr/bin/env python3
"""N1I-B n1i_static.py self-test: DEX decoder vs dexdump oracle, ELF reader vs readelf oracle.

All fixtures are synthetic and built at test time (javac --release 8 + dx; gcc/clang+lld).
Missing tools are a FAIL, never a skip. Prints CASE lines; exit 0 only if all pass.
Optional: N1I_STATIC_EXTRA_CORPUS="a.jar:b.jar" adds oracle comparisons on extra jars (dexed with dx).
"""
from __future__ import annotations

import hashlib
import os
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
sys.path.insert(0, str(ROOT / "build/titan2"))
import n1i_static as S  # noqa: E402

FX = HERE / "fixtures"
FAILS = 0


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    print(f"CASE\tstatic\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " ")[:600])
    FAILS += 0 if ok else 1


def raises(fn, exc) -> tuple[bool, str]:
    try:
        fn()
    except exc as e:
        return True, str(e)[:160]
    except Exception as e:  # wrong exception type is a failure: callers rely on DexError/ElfError
        return False, f"unexpected {type(e).__name__}: {e}"[:160]
    return False, "no exception"


def find_dx() -> str | None:
    for c in (shutil.which("dx"), "/usr/lib/android-sdk/build-tools/debian/dx"):
        if c and Path(c).exists():
            return c
    return None


def sh(cmd: list, **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def build_dex(td: Path) -> dict:
    dx = find_dx()
    tools = {"javac": shutil.which("javac"), "dx": dx, "dexdump": shutil.which("dexdump")}
    missing = [k for k, v in tools.items() if not v]
    if missing:
        raise RuntimeError(f"missing tools {missing}")
    src = FX / "dex"
    c1, c2 = td / "c1", td / "c2"
    r = sh(["javac", "-nowarn", "--release", "8", "-d", str(c1), *map(str, sorted((src / "src/p").glob("*.java")))])
    if r.returncode:
        raise RuntimeError("javac p failed: " + r.stderr[-300:])
    r = sh(["javac", "-nowarn", "--release", "8", "-cp", str(c1), "-d", str(c2),
            *map(str, sorted((src / "src2/q").glob("*.java")))])
    if r.returncode:
        raise RuntimeError("javac q failed: " + r.stderr[-300:])
    out = {}
    for name, cls in (("a", c1), ("b", c2)):
        r = sh([dx, "--dex", "--min-sdk-version=26", f"--output={td / (name + '.dex')}", str(cls)])
        if r.returncode:
            raise RuntimeError(f"dx {name} failed: " + r.stderr[-300:])
        out[name] = td / f"{name}.dex"
    apk = td / "multi.apk"
    with zipfile.ZipFile(apk, "w") as z:
        z.write(out["a"], "classes.dex")
        z.write(out["b"], "classes2.dex")
        z.write(out["b"], "classes4.dex")          # after a gap: ART does not load it
        z.write(out["b"], "assets/extra.dex")      # not primary code
        z.writestr("AndroidManifest.xml", b"synthetic")
    out["apk"] = apk
    return out


def refix(data: bytearray) -> bytearray:
    data[12:32] = hashlib.sha1(bytes(data[32:])).digest()
    struct.pack_into("<I", data, 8, zlib.adler32(bytes(data[12:])) & 0xFFFFFFFF)
    return data


def patch_bulk(dex_path: Path, units: list[int]) -> bytes:
    data = bytearray(dex_path.read_bytes())
    dex = S.DexFile(bytes(data))
    m = next(m for c in dex.classes if c.descriptor == "Lp/Bulk;" for m in c.methods if m.ref.name == "bulk")
    if len(units) > m.code.insns_units:
        raise RuntimeError(f"crafted stream {len(units)} > bulk insns {m.code.insns_units}")
    units = units + [0] * (m.code.insns_units - len(units))
    struct.pack_into(f"<{len(units)}H", data, m.code.insns_off, *units)
    return bytes(refix(data))


def craft_all() -> list[int]:
    """Every defined opcode once, with in-range operands, plus the three payloads."""
    u: list[int] = []
    fix31t: list[tuple[int, int, int]] = []          # (pc, unit index, opcode)
    for op in sorted(S.OPCODES):
        name, fmt, ref = S.OPCODES[op]
        pc = len(u)
        if fmt == "10x": u += [op]
        elif fmt == "12x": u += [op | (1 << 12)]
        elif fmt == "11n": u += [op | (3 << 12)]
        elif fmt in ("11x", "10t"): u += [op]
        elif fmt in ("20t", "21t", "21c"): u += [op, 0]
        elif fmt == "22x": u += [op, 1]
        elif fmt == "21s": u += [op, 5]
        elif fmt == "21h": u += [op, 1]
        elif fmt == "23x": u += [op, 1 | (2 << 8)]
        elif fmt == "22b": u += [op, 1 | (5 << 8)]
        elif fmt in ("22t", "22c"): u += [op | (1 << 12), 0]
        elif fmt == "22s": u += [op | (1 << 12), 7]
        elif fmt == "30t": u += [op, 0, 0]
        elif fmt == "32x": u += [op, 0, 1]
        elif fmt == "31i": u += [op, 1, 0]
        elif fmt == "31t": u += [op, 0, 0]; fix31t.append((pc, pc + 1, op))
        elif fmt == "31c": u += [op, 0, 0]
        elif fmt == "35c": u += [op | (2 << 12), 0, 0x10]
        elif fmt == "3rc": u += [op | (2 << 8), 0, 0]
        elif fmt == "45cc": u += [op | (2 << 12), 0, 0x10, 0]
        elif fmt == "4rcc": u += [op | (2 << 8), 0, 0, 0]
        elif fmt == "51l": u += [op, 1, 0, 0, 0]
        else:
            raise AssertionError(fmt)
    if len(u) % 2:
        u.append(0)
    payload = {0x26: [0x0300, 4, 1, 0, 0x1234, 0x5678], 0x2b: [0x0100, 1, 0, 0, 0, 0],
               0x2c: [0x0200, 1, 0, 0, 0, 0]}
    for pc, idx, op in fix31t:
        rel = len(u) - pc
        u[idx], u[idx + 1] = rel & 0xFFFF, (rel >> 16) & 0xFFFF
        u += payload[op]
    return u


def dex_cases(td: Path) -> None:
    try:
        fx = build_dex(td)
    except RuntimeError as e:
        case("dex_fixture_build", False, str(e))
        return
    case("dex_fixture_build", True, "javac --release 8 + dx --min-sdk-version=26")
    a = S.DexFile(fx["a"].read_bytes(), "a.dex")
    b = S.DexFile(fx["b"].read_bytes(), "b.dex")
    covered = set()
    for name, dex in (("a", a), ("b", b)):
        ok, msg = True, ""
        try:
            r = S.oracle_check_dex(dex)
            covered |= r["opcodes"]
            msg = f"classes={r['classes']} insns={r['instructions']} opcodes={len(r['opcodes'])}"
        except S.DexError as e:
            ok, msg = False, str(e)
        case(f"dexdump_oracle_fixture_{name}", ok, msg)

    # exhaustive opcode table validation: crafted stream with every defined opcode
    stream = craft_all()
    crafted = S.DexFile(patch_bulk(fx["a"], stream), "crafted-all.dex")
    try:
        r = S.oracle_check_dex(crafted)
        covered |= r["opcodes"]
        case("dexdump_oracle_crafted_all_opcodes", True, f"insns={r['instructions']}")
    except S.DexError as e:
        case("dexdump_oracle_crafted_all_opcodes", False, str(e))
    missing = sorted(set(S.OPCODES) - covered)
    case("opcode_table_every_defined_opcode_oracle_validated", not missing,
         f"defined={len(S.OPCODES)} validated={len(covered & set(S.OPCODES))} missing={[hex(m) for m in missing]}")
    case("opcode_table_unused_count", len(S.UNUSED_OPCODES) == 32,
         f"unused={len(S.UNUSED_OPCODES)} (0x3e-0x43, 0x73, 0x79-0x7a, 0xe3-0xf9)")
    case("opcode_widths_derive_from_format_only",
         all(S.fmt_width(f) == int(f[0]) for _, f, _ in S.OPCODES.values()) and not hasattr(S, "WIDTHS"), "")

    extra = [p for p in os.environ.get("N1I_STATIC_EXTRA_CORPUS", "").split(":") if p]
    for j in extra:
        out = td / (Path(j).stem + ".dex")
        rr = sh([find_dx(), "--dex", "--min-sdk-version=26", f"--output={out}", j])
        if rr.returncode:
            case(f"extra_corpus_dx:{Path(j).name}", False, rr.stderr[-200:])
            continue
        try:
            r = S.oracle_check_dex(S.DexFile(out.read_bytes(), out.name))
            case(f"extra_corpus_oracle:{Path(j).name}", True, f"insns={r['instructions']}")
        except S.DexError as e:
            case(f"extra_corpus_oracle:{Path(j).name}", False, str(e))

    # ---- semantic checks on the parsed model (each also covered by the oracle above)
    cls = {c.descriptor: c for c in a.classes}
    ops = cls["Lp/Ops;"]
    case("superclass_and_interfaces", ops.superclass == "Lp/Base;" and ops.interfaces == ("Lp/Iface;",)
         and cls["Lp/Iface;"].access & S.ACC_INTERFACE, "")
    meths = {(m.ref.name, m.ref.proto): m for m in ops.methods}
    init = meths[("<init>", "()V")]
    case("constructor_flags", init.direct and init.access & S.ACC_CONSTRUCTOR and init.code is not None, "")
    ni, ns = meths[("nativeInstance", "(I)I")], meths[("nativeStatic", "(Ljava/lang/String;)Ljava/lang/String;")]
    case("native_declarations", ni.code is None and ni.access & S.ACC_NATIVE and not ni.access & S.ACC_STATIC
         and ns.access & S.ACC_NATIVE and ns.access & S.ACC_STATIC and not ni.direct, "")
    case("access_flags_private_protected", {f.ref.name: f.access for f in ops.fields}["priv"] & S.ACC_PRIVATE
         and {f.ref.name: f.access for f in ops.fields}["prot"] & S.ACC_PROTECTED, "")
    case("method_and_field_ids_resolve", all(isinstance(x, S.MethodRef) for x in a.method_ids)
         and S.FieldRef("Lp/Ops;", "ij", "J") in a.field_ids and S.MethodRef("Lp/Base;", "value", "(I)I") in a.method_ids, "")
    calls = S.instructions(a, meths[("calls", "(Lp/Iface;Lp/Base;)I")])
    kinds = {(i.name, getattr(i.ref, "cls", None), getattr(i.ref, "name", None)) for i in calls}
    case("invoke_super_target", ("invoke-super", "Lp/Base;", "value") in kinds, "")
    case("invoke_interface_and_virtual", ("invoke-interface", "Lp/Iface;", "value") in kinds
         and ("invoke-interface", "Lp/Iface;", "dflt") in kinds and ("invoke-virtual", "Lp/Base;", "value") in kinds, "")
    case("invoke_direct_range_and_static_range", ("invoke-direct/range", "Lp/Ops;", "many") in kinds
         and ("invoke-static/range", "Lp/Ops;", "staticMany") in kinds, "")
    ctor = S.instructions(a, init)
    case("invoke_direct_constructor", any(i.name == "invoke-direct" and i.ref == S.MethodRef("Lp/Base;", "<init>", "(I)V")
                                          for i in ctor), "")
    fk = {S.FIELD_KIND[i.op] + ":" + i.ref.type for i in S.instructions(a, meths[("fields", "()V")]) if i.op in S.FIELD_KIND}
    case("field_access_kinds", {"sget:Z", "sput:B", "iget:J", "iput:D", "sput:Ljava/lang/Object;"} <= fk, f"n={len(fk)}")
    lam = {(m.ref.name): m for m in cls["Lp/Lam;"].methods}
    li = S.instructions(a, lam["lambda"]) + S.instructions(a, lam["bigLambda"])
    cs = [i for i in li if i.name.startswith("invoke-custom")]
    case("invoke_custom_call_site", {i.name for i in cs} == {"invoke-custom", "invoke-custom/range"}
         and all(i.ref.bootstrap.kind == 4 and i.ref.bootstrap.target.cls == "Ljava/lang/invoke/LambdaMetafactory;"
                 and i.ref.name == "f" for i in cs), f"n={len(cs)}")
    pi = [i for i in S.instructions(a, lam["poly"]) + S.instructions(a, lam["polyRange"]) if i.name.startswith("invoke-polymorphic")]
    case("invoke_polymorphic_method_and_proto", {i.name for i in pi} == {"invoke-polymorphic", "invoke-polymorphic/range"}
         and all(i.ref.cls == "Ljava/lang/invoke/MethodHandle;" and i.proto and i.proto.endswith("Ljava/lang/Object;") for i in pi),
         f"protos={[i.proto for i in pi]}")
    cstr = [i for i in S.instructions(a, meths[("concat", "(Ljava/lang/String;I)Ljava/lang/String;")]) if i.name == "const-string"]
    case("const_string_register_and_value", any(i.ref == "s" and len(i.regs) == 1 for i in cstr), "")

    # ---- multidex
    c = S.load_container(fx["apk"])
    case("multidex_order_and_gap", [n for n, _ in c.dexes] == ["classes.dex", "classes2.dex"]
         and c.ignored_entries == ["assets/extra.dex", "classes4.dex"], f"{[n for n, _ in c.dexes]} {c.ignored_entries}")
    tab, dups = S.class_table([c])
    case("multidex_class_table", "Lq/Second;" in tab and tab["Lq/Second;"][1] == "classes2.dex" and not dups, "")
    boot = S.load_container(fx["a"])
    tab2, dups2 = S.class_table([boot, c])
    case("class_table_first_definition_wins", tab2["Lp/Ops;"][0] is boot and any(d[0] == "Lp/Ops;" for d in dups2),
         f"dups={len(dups2)}")

    # ---- fail closed on malformed input
    good = fx["a"].read_bytes()
    ok, msg = raises(lambda: S.DexFile(good[:-64]), S.DexError)
    case("malformed_truncated_file", ok, msg)
    ok, msg = raises(lambda: S.DexFile(good[:0x40]), S.DexError)
    case("malformed_truncated_header", ok, msg)
    bad = bytearray(good); bad[0x200] ^= 0xFF
    ok, msg = raises(lambda: S.DexFile(bytes(bad)), S.DexError)
    case("malformed_checksum", ok, msg)
    bad = bytearray(good); bad[0x200] ^= 0xFF; struct.pack_into("<I", bad, 8, zlib.adler32(bytes(bad[12:])) & 0xFFFFFFFF)
    ok, msg = raises(lambda: S.DexFile(bytes(bad)), S.DexError)
    case("malformed_sha1_signature", ok, msg)
    bad = bytearray(good); bad[4:7] = b"041"
    ok, msg = raises(lambda: S.DexFile(bytes(refix(bad))), S.DexError)
    case("unsupported_dex_041_container", ok and "041" in msg, msg)
    bad = bytearray(good); bad[0:4] = b"dey\n"
    ok, msg = raises(lambda: S.DexFile(bytes(bad)), S.DexError)
    case("malformed_magic", ok, msg)
    bad = bytearray(good); s_off = struct.unpack_from("<I", bad, 60)[0]; struct.pack_into("<I", bad, s_off, len(bad) + 10)
    ok, msg = raises(lambda: S.DexFile(bytes(refix(bad))), S.DexError)
    case("malformed_string_offset_out_of_range", ok, msg)
    bad = bytearray(good); m_off = struct.unpack_from("<I", bad, 92)[0]; struct.pack_into("<H", bad, m_off + 2, 0xFFFF)
    ok, msg = raises(lambda: S.DexFile(bytes(refix(bad))), S.DexError)
    case("malformed_proto_index_out_of_range", ok, msg)

    def neg(cid: str, units: list[int]) -> None:
        dex = S.DexFile(patch_bulk(fx["a"], units))
        ok, msg = raises(lambda: S.dex_model(dex), S.DexError)
        case(cid, ok, msg)

    neg("malformed_unused_opcode_3e", [0x003e])
    neg("malformed_unused_opcode_73", [0x0073])
    neg("malformed_unused_opcode_e3", [0x00e3])
    neg("malformed_unknown_nop_ident", [0x0400])
    neg("malformed_unreferenced_payload", [0x0000, 0x0000, 0x0100, 1, 0, 0, 0, 0])
    # goto/16 +3 at 0x0 targets 0x3, the second unit of the const/16 that starts at 0x2
    neg("malformed_branch_into_instruction_middle", [0x0029, 3, 0x0013, 0x0005])
    neg("malformed_invoke_35c_count_6", [0x606e, 0, 0x4321])
    neg("malformed_method_ref_out_of_range", [0x106e, 0xFFFF, 0x0000])
    neg("malformed_array_data_bad_width", [0x0026, 2, 0, 0x0300, 3, 1, 0, 0])
    dex = S.DexFile(fx["a"].read_bytes())
    m = next(m for cd in dex.classes if cd.descriptor == "Lp/Bulk;" for m in cd.methods if m.ref.name == "bulk")
    tail = [0x0000] * (m.code.insns_units - 2) + [0x0018, 0x0001]   # const-wide needs 5 units, only 2 left
    neg("malformed_instruction_runs_past_insns", tail)
    case("crafted_stream_fits", len(stream) < m.code.insns_units, f"stream={len(stream)} bulk={m.code.insns_units}")


SEPARATORS = {"U+0085": chr(0x85), "U+2028": chr(0x2028), "U+2029": chr(0x2029)}


def separator_cases(td: Path) -> None:
    """Regression: const-string literals containing splitlines()-only boundaries (FindAddress-style)."""
    dx = find_dx()
    if not (shutil.which("javac") and dx and shutil.which("dexdump")):
        case("dex_separator_fixture_build", False, "javac, dx and dexdump are required")
        return
    cls = td / "cls"
    r = sh(["javac", "-nowarn", "--release", "8", "-encoding", "US-ASCII", "-d", str(cls),
            str(FX / "dex/sep/p/Sep.java")])
    r2 = sh([dx, "--dex", "--min-sdk-version=26", f"--output={td / 'sep.dex'}", str(cls)]) if not r.returncode else r
    case("dex_separator_fixture_build", not (r.returncode or r2.returncode),
         "" if not (r.returncode or r2.returncode) else (r.stderr + r2.stderr)[-200:])
    if r.returncode or r2.returncode:
        return
    dex = S.DexFile((td / "sep.dex").read_bytes(), "sep.dex")
    strings = set(dex.strings)
    for label, ch in SEPARATORS.items():
        case(f"dex_separator_fixture_has_{label}", any(ch in s for s in strings), "")
    text = S.run_dexdump(dex.data)
    raw = [label for label, ch in SEPARATORS.items() if ch in text]
    # Non-vacuity: the oracle text itself must carry boundaries that splitlines() honours and split("\n") does not.
    case("dex_separator_dexdump_prints_raw_boundaries", len(raw) == len(SEPARATORS)
         and len(text.splitlines()) > len(text.split("\n")) - 1, f"raw={raw}")
    oracle = S.parse_dexdump(text)
    consts = [i for sec in ("direct", "virtual") for m in oracle.get("Lp/Sep;", {}).get(sec, [])
              for i in m.get("insns", []) if i[1].startswith("const-string")]
    case("dex_separator_oracle_keeps_every_string_ref", len(consts) == 6
         and all(len(i[2]) == 1 and i[2][0][0] == "string" for i in consts), f"const-strings={len(consts)} {consts}")
    ok, detail = True, ""
    try:
        detail = str(S.oracle_check_dex(dex)["instructions"]) + " instructions"
    except S.DexError as e:
        ok, detail = False, str(e)
    case("dex_separator_decoder_matches_dexdump", ok, detail)


def elf_cases(td: Path) -> None:
    need = {"gcc": shutil.which("gcc"), "clang": shutil.which("clang"), "ld.lld": shutil.which("ld.lld"),
            "llvm-objcopy": shutil.which("llvm-objcopy"), "readelf": shutil.which("readelf")}
    if not all(need.values()):
        case("elf_fixture_build", False, f"missing {[k for k, v in need.items() if not v]}")
        return
    src = FX / "elf"
    builds = {
        "x64": (["gcc"], ["-Wl,--hash-style=both"]),
        "a64": (["clang", "--target=aarch64-linux-gnu", "-fuse-ld=lld"], ["-Wl,--hash-style=gnu"]),
        "a32": (["clang", "--target=armv7a-linux-gnueabi", "-fuse-ld=lld"], ["-Wl,--hash-style=sysv"]),
    }
    libs = {}
    for arch, (cc, hs) in builds.items():
        d = td / arch
        d.mkdir()
        r1 = sh(cc + ["-shared", "-fPIC", "-nostdlib", "-Wl,-soname,libdep.so", "-o", str(d / "libdep.so"), str(src / "dep.c")])
        r2 = sh(cc + ["-shared", "-fPIC", "-nostdlib", "-Wl,-soname,libsynth.so", *hs, f"-L{d}", "-o",
                      str(d / "libsynth.so"), str(src / "synth.c"), "-ldep"])
        r3 = sh(["llvm-objcopy", "--strip-sections", str(d / "libsynth.so"), str(d / "libsynth.nosh.so")])
        ok = not (r1.returncode or r2.returncode or r3.returncode)
        case(f"elf_fixture_build_{arch}", ok, (r1.stderr + r2.stderr + r3.stderr)[-200:])
        if ok:
            libs[arch] = d
    want_exports = {"JNI_OnLoad", "Java_p_Ops_nativeInstance", "Java_p_Ops_nativeStatic",
                    "Java_com_example_Foo_1Bar_over__ILjava_lang_String_2", "weak_export"}
    want_src = {"x64": "DT_HASH", "a64": "DT_GNU_HASH", "a32": "DT_HASH"}
    for arch, d in libs.items():
        p = d / "libsynth.so"
        info = S.load_elf(p)
        o = S.readelf_oracle(p)
        case(f"elf_dt_needed_vs_readelf_{arch}", info.needed == o["needed"] == ("libdep.so",), f"{info.needed} {o['needed']}")
        case(f"elf_soname_vs_readelf_{arch}", info.soname == o["soname"] == "libsynth.so", "")
        ours = [(s.name, s.defined) for s in info.symbols if s.name]
        theirs = [(n, dfn) for n, dfn, _b, _v in o["symbols"] if n]
        case(f"elf_dynsym_vs_readelf_{arch}", ours == theirs, f"ours={len(ours)} readelf={len(theirs)}")
        case(f"elf_exports_{arch}", set(info.exports) == want_exports and "hidden_helper" not in info.exports, "")
        case(f"elf_imports_{arch}", "dep_function" in info.imports, "")
        case(f"elf_class_{arch}", info.elf_class == (32 if arch == "a32" else 64), f"{info.elf_class} {info.machine}")
        ns = S.load_elf(d / "libsynth.nosh.so")
        case(f"elf_no_section_headers_{arch}", ns.symbol_source == want_src[arch] and set(ns.exports) == want_exports
             and ns.needed == ("libdep.so",), ns.symbol_source)
        ev = S.jni_evidence(info, p.read_bytes())
        mapped = {n: dm for n, dm in ev["exported_java"]}
        case(f"jni_java_export_mapping_{arch}",
             mapped.get("Java_p_Ops_nativeInstance") == ("Lp/Ops;", "nativeInstance", None)
             and mapped.get("Java_com_example_Foo_1Bar_over__ILjava_lang_String_2")
             == ("Lcom/example/Foo_Bar;", "over", "(ILjava/lang/String;)"), "")
        case(f"jni_onload_and_registernatives_candidates_{arch}", ev["has_jni_onload"]
             and ev["registernatives_candidates"]["evidence_strength"] == "STRING_ONLY"
             and "com/example/synth/NativeBridge" in ev["registernatives_candidates"]["class_strings"]
             and "(ILjava/lang/String;)V" in ev["registernatives_candidates"]["signature_strings"]
             and "not/a class name" not in ev["registernatives_candidates"]["class_strings"], "")
    case("jni_demangle_rejects_non_jni", S.jni_demangle("Java_x") is None and S.jni_demangle("foo") is None
         and S.jni_demangle("Java_a_b$c") is None, "")
    case("jni_demangle_unicode_escape", S.jni_demangle("Java_p_Q_m_000e9") == ("Lp/Q;", "mé", None),
         str(S.jni_demangle("Java_p_Q_m_000e9")))
    if "x64" in libs:
        good = (libs["x64"] / "libsynth.so").read_bytes()
        ok, msg = raises(lambda: S.parse_elf(good[:200], "trunc"), S.ElfError)
        case("elf_malformed_truncated", ok, msg)
        be = bytearray(good); be[5] = 2
        ok, msg = raises(lambda: S.parse_elf(bytes(be), "be"), S.ElfError)
        case("elf_big_endian_refused", ok, msg)
        ok, msg = raises(lambda: S.parse_elf(b"\x7fELX" + good[4:], "magic"), S.ElfError)
        case("elf_bad_magic", ok, msg)
        st = td / "static"
        (td / "start.c").write_text("void _start(void) { for (;;) {} }\n")
        r = sh(["gcc", "-nostdlib", "-static", "-o", str(st), str(td / "start.c")])
        ok, msg = (raises(lambda: S.load_elf(st), S.ElfError) if not r.returncode else (False, r.stderr[-100:]))
        case("elf_static_without_dynamic_refused", ok, msg)


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        (td / "dex").mkdir()
        (td / "elf").mkdir()
        (td / "sep").mkdir()
        dex_cases(td / "dex")
        separator_cases(td / "sep")
        elf_cases(td / "elf")
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
