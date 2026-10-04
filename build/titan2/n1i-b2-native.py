#!/usr/bin/env python3
"""Titan 2 N1I-B2 native dependency rederivation and JNI attribution. Offline only.

Replaces the N1I-A keyword heuristic. A native library becomes a candidate only through:
  1. APK-packaged libraries for the selected ABI (lib/<abi>/*.so)
  2. uses-native-library declarations (required / optional)
  3. System.load / System.loadLibrary / Runtime.load / Runtime.loadLibrary call sites whose
     ACTUAL argument register is proven to hold a constant string at the invocation
  4. DT_NEEDED closure of the admitted roots

Argument data-flow (rule 3) is intra-procedural and fails closed: starting at the invoke, the
argument register is followed backwards inside the basic block. const-string (and /jumbo)
proves a constant; move-object (/from16, /16) continues with the source register; any other
write, a parameter register, a block boundary (branch target, switch case, catch handler, or a
preceding goto/return/throw) makes the site DYNAMIC_LOAD_UNRESOLVED. A string elsewhere in the
method never counts.

JNI attribution per app native method:
  CONFIRMED_JAVA_EXPORT       an admitted library exports the matching Java_* symbol (ELF_REFERENCE)
  CONFIRMED_REGISTERNATIVES   only from declared runtime evidence (--runtime-registrations, RUNTIME_OBSERVED)
  CANDIDATE_ONLY              an admitted library has JNI_OnLoad and contains the class, method name and
                              signature strings (STRING_ONLY: never proof)
  UNRESOLVED                  none of the above

Library lookup models the app (system-side) linker namespace: APK libs, then system / system_ext /
product / apex directories as given. A library present only under vendor/odm is recorded as
FILE_PRESENT_NAMESPACE_UNPROVEN, never as satisfied.

Exit codes: 0 completed   2 input error or decoder/oracle disagreement (nothing written)
"""
from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import struct
import sys
import tempfile
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import n1i_static as S  # noqa: E402

TOOL_VERSION = "1.0.0"
ABI_MACHINE = {"arm64-v8a": "aarch64", "armeabi-v7a": "arm", "x86_64": "x86_64", "x86": "x86"}
PARTITIONS = ("system", "system_ext", "product", "apex", "vendor", "odm")
PROVIDER_CLASS = {"apk": "APK_PACKAGED", "system": "PLATFORM_OR_APEX", "apex": "PLATFORM_OR_APEX",
                  "system_ext": "SYSTEM_EXT_OR_PRODUCT", "product": "SYSTEM_EXT_OR_PRODUCT",
                  "vendor": "VENDOR", "odm": "VENDOR"}
LOADERS = {
    ("Ljava/lang/System;", "loadLibrary", "(Ljava/lang/String;)V"): ("loadLibrary", 0),
    ("Ljava/lang/System;", "load", "(Ljava/lang/String;)V"): ("load", 0),
    ("Ljava/lang/Runtime;", "loadLibrary", "(Ljava/lang/String;)V"): ("loadLibrary", 1),
    ("Ljava/lang/Runtime;", "load", "(Ljava/lang/String;)V"): ("load", 1),
}
MOVE_OBJECT = {0x07, 0x08, 0x09}
CONST_STRING = {0x1a, 0x1b}
BLOCK_ENDERS = {0x0e, 0x0f, 0x10, 0x11, 0x27, 0x28, 0x29, 0x2a}   # return*, throw, goto*
# Opcodes that never write a register (so cannot clobber the tracked one).
NON_WRITING = ({0x00, 0x0e, 0x0f, 0x10, 0x11, 0x1d, 0x1e, 0x1f, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c}
               | set(range(0x32, 0x3e)) | set(range(0x4b, 0x52)) | set(range(0x59, 0x60)) | set(range(0x67, 0x6e))
               | set(range(0x6e, 0x79)) | {0xfa, 0xfb, 0xfc, 0xfd})


class InputError(Exception):
    pass


# =============================================================================
# Control-flow boundaries inside one method
# =============================================================================
def block_starts(dex: S.DexFile, code: S.Code, items: list) -> set[int]:
    starts = {0}
    insns = [i for i in items if isinstance(i, S.Insn)]
    payload_at = {p.offset: p for p in items if isinstance(p, S.Payload)}
    for i in insns:
        if i.target is None:
            continue
        if i.op in (0x2b, 0x2c):                          # switch: case targets come from the payload
            p = payload_at.get(i.target)
            if p is None:
                raise S.DexError(f"{dex.name}: switch at {i.offset:#x} without payload")
            base = code.insns_off + 2 * p.offset
            size = struct.unpack_from("<H", dex.data, base + 2)[0]
            if i.op == 0x2b:
                rel = struct.unpack_from(f"<{size}i", dex.data, base + 8)
            else:
                rel = struct.unpack_from(f"<{size}i", dex.data, base + 4 + 4 * size)
            starts.update(i.offset + r for r in rel)
            starts.add(i.offset + i.width)
        elif i.op == 0x26:                                  # fill-array-data: payload, not control flow
            continue
        else:
            starts.add(i.target)
            starts.add(i.offset + i.width)                  # fall-through after a conditional/goto
    if code.tries:
        r = dex.r
        toff = code.insns_off + 2 * code.insns_units + (2 if code.insns_units % 2 else 0)
        hl = toff + 8 * code.tries
        for k in range(code.tries):
            start, count, hoff = struct.unpack_from("<IHH", dex.data, toff + 8 * k)
            starts.update((start, start + count))
            o = hl + hoff
            n, o = r.sleb(o)
            for _ in range(abs(n)):
                _t, o = r.uleb(o)
                addr, o = r.uleb(o)
                starts.add(addr)
            if n <= 0:
                addr, o = r.uleb(o)
                starts.add(addr)
    return starts


@dataclass
class LoadSite:
    caller: str
    site: str
    api: str               # loadLibrary | load
    status: str            # CONSTANT | DYNAMIC_LOAD_UNRESOLVED
    value: str
    reason: str
    chain: str             # instruction offsets used to prove the value


WIDE_RESULT = re.compile(r"-wide(/from16|/16|/32|/high16)?$|^(add|sub|mul|div|rem|and|or|xor|shl|shr|ushr)-(long|double)"
                         r"(/2addr)?$|^(add|sub|mul|div|rem)-double(/2addr)?$|^(int|float|double|long)-to-(long|double)$|"
                         r"^(neg|not)-long$|^neg-double$")


def writes_wide(i: S.Insn) -> bool:
    """True when the instruction writes a register PAIR (vA, vA+1)."""
    return bool(WIDE_RESULT.search(i.name))


def trace_argument(dex: S.DexFile, m: S.EncodedMethod, items: list, idx: int, reg: int,
                   starts: set[int]) -> tuple[str, str, str, str]:
    """Follow `reg` backwards from instruction index idx. Returns (status, value, reason, chain)."""
    insns = [i for i in items if isinstance(i, S.Insn)]
    pos = next(k for k, i in enumerate(insns) if i is items[idx])
    chain = []
    params_from = m.code.registers - m.code.ins
    while True:
        if pos > 0 and insns[pos].offset in starts:
            return "DYNAMIC_LOAD_UNRESOLVED", "-", f"block boundary at {insns[pos].offset:#06x}", "->".join(chain)
        if pos == 0:
            if reg >= params_from:
                return "DYNAMIC_LOAD_UNRESOLVED", "-", f"argument is method parameter v{reg}", "->".join(chain)
            return "DYNAMIC_LOAD_UNRESOLVED", "-", f"v{reg} not defined before use", "->".join(chain)
        prev = insns[pos - 1]
        if prev.op in BLOCK_ENDERS:
            return "DYNAMIC_LOAD_UNRESOLVED", "-", f"only reachable by a jump (after {prev.name})", "->".join(chain)
        pos -= 1
        i = prev
        if i.op in NON_WRITING or not i.regs:
            continue
        dest = i.regs[0]
        if dest == reg:
            chain.append(f"{i.offset:#06x}:{i.name}")
            if i.op in CONST_STRING:
                return "CONSTANT", i.ref, "const-string reaches the argument register", "->".join(chain)
            if i.op in MOVE_OBJECT:
                reg = i.regs[1]
                continue
            return "DYNAMIC_LOAD_UNRESOLVED", "-", f"v{reg} computed by {i.name}", "->".join(chain)
        if dest == reg - 1 and writes_wide(i):
            chain.append(f"{i.offset:#06x}:{i.name}")
            return "DYNAMIC_LOAD_UNRESOLVED", "-", f"v{reg} clobbered by wide write {i.name}", "->".join(chain)


def load_sites(dex: S.DexFile, entry: str) -> list[LoadSite]:
    out = []
    for cd in dex.classes:
        for m in cd.methods:
            if m.code is None:
                continue
            items = S.decode_code(dex, m.code, f"{cd.descriptor}->{m.ref.name}{m.ref.proto}")
            starts = None
            for idx, it in enumerate(items):
                if not isinstance(it, S.Insn) or it.ref_kind != "method":
                    continue
                key = (it.ref.cls, it.ref.name, it.ref.proto)
                if key not in LOADERS:
                    continue
                api, argi = LOADERS[key]
                if starts is None:
                    starts = block_starts(dex, m.code, items)
                site = f"{entry}:{cd.descriptor}->{m.ref.name}{m.ref.proto}@{it.offset:#06x}"
                if argi >= len(it.regs):
                    out.append(LoadSite(cd.descriptor, site, api, "DYNAMIC_LOAD_UNRESOLVED", "-", "argument register absent", ""))
                    continue
                st, val, why, chain = trace_argument(dex, m, items, idx, it.regs[argi], starts)
                out.append(LoadSite(cd.descriptor, site, api, st, val, why, chain))
    return out


# =============================================================================
# Library lookup and DT_NEEDED closure
# =============================================================================
@dataclass
class Lib:
    name: str
    path: Path | None
    partition: str           # apk | system | ... | NOT_FOUND
    status: str              # FOUND | FILE_PRESENT_NAMESPACE_UNPROVEN | NOT_FOUND | WRONG_ABI
    namespace_visibility: str = "-"  # APK_PACKAGED | EXPLICIT | UNPROVEN | -
    info: S.ElfInfo | None = None
    sha256: str = "-"
    reasons: list = field(default_factory=list)   # how it was admitted


class Finder:
    def __init__(
        self,
        apk_libs: dict[str, tuple[bytes, str]],
        dirs: list[tuple[str, Path]],
        machine: str,
        tmp: Path,
        namespace_visible: set[str],
    ):
        self.apk = apk_libs
        self.dirs = dirs
        self.machine = machine
        self.tmp = tmp
        self.namespace_visible = namespace_visible

    def _elf(self, path: Path) -> S.ElfInfo:
        return S.load_elf(path)

    def find(self, name: str, partition_hint: str | None = None) -> Lib:
        if partition_hint is None and name in self.apk:
            data, _entry = self.apk[name]
            p = self.tmp / f"apk-{name}"
            p.write_bytes(data)
            return self._admit(name, p, "apk", "APK_PACKAGED")

        present: list[tuple[str, Path]] = []
        for k, d in self.dirs:
            if partition_hint is not None and k != partition_hint:
                continue
            p = d / name
            if p.is_file():
                present.append((k, p))
        if not present:
            return Lib(name, None, "NOT_FOUND", "NOT_FOUND")

        k, p = present[0]
        if name not in self.namespace_visible:
            return Lib(
                name,
                p,
                k,
                "FILE_PRESENT_NAMESPACE_UNPROVEN",
                "UNPROVEN",
                sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
            )
        return self._admit(name, p, k, "EXPLICIT")

    def _admit(self, name: str, p: Path, part: str, visibility: str) -> Lib:
        info = self._elf(p)
        if info.machine != self.machine:
            return Lib(
                name,
                p,
                part,
                "WRONG_ABI",
                visibility,
                info,
                hashlib.sha256(p.read_bytes()).hexdigest(),
            )
        return Lib(
            name,
            p,
            part,
            "FOUND",
            visibility,
            info,
            hashlib.sha256(p.read_bytes()).hexdigest(),
        )


def closure(finder: Finder, roots: list[tuple[str, str, str | None]]) -> dict[str, Lib]:
    """roots: (soname, reason, partition_hint). Returns name -> Lib for roots and their DT_NEEDED closure."""
    libs: dict[str, Lib] = {}
    queue = list(roots)
    while queue:
        name, why, hint = queue.pop(0)
        if name in libs:
            libs[name].reasons.append(why)
            continue
        lib = finder.find(name, hint)
        lib.reasons.append(why)
        libs[name] = lib
        if lib.status == "FOUND":
            for n in lib.info.needed:
                queue.append((n, f"DT_NEEDED:{name}", None))
    return libs


# =============================================================================
# JNI attribution
# =============================================================================
def jni_mangle(s: str) -> str:
    """JNI name mangling (JNI spec, "Resolving Native Method Names")."""
    out = []
    for ch in s:
        if ch == "/":
            out.append("_")
        elif ch == "_":
            out.append("_1")
        elif ch == ";":
            out.append("_2")
        elif ch == "[":
            out.append("_3")
        elif ch.isascii() and ch.isalnum():
            out.append(ch)
        else:
            out.append(f"_0{ord(ch):04x}")
    return "".join(out)


def jni_names(cls: str, name: str, proto: str) -> tuple[str, str]:
    """(short name, long name with mangled argument signature) for a native method."""
    short = "Java_" + jni_mangle(cls[1:-1]) + "_" + jni_mangle(name)
    return short, short + "__" + jni_mangle(proto[1:proto.index(")")])


@dataclass
class Attribution:
    cls: str
    name: str
    proto: str
    result: str
    libs: str
    symbol: str
    strength: str


def attribute(natives: list[tuple[str, str, str]], libs: dict[str, Lib], runtime: set[tuple]) -> list[Attribution]:
    admitted = [l for l in libs.values() if l.status == "FOUND"]
    exports = {l.name: set(l.info.exports) for l in admitted}
    strings = {}
    for l in admitted:
        data = l.path.read_bytes()
        strings[l.name] = ({m.group().decode() for m in re.finditer(rb"[\x20-\x7e]{2,}", data)},
                           "JNI_OnLoad" in exports[l.name])
    out = []
    for cls, name, proto in natives:
        short, long_ = jni_names(cls, name, proto)
        hits = sorted(f"{ln}:{sym}" for ln, ex in exports.items() for sym in (short, long_) if sym in ex)
        rt = sorted(l for (c, n, p, l) in runtime if (c, n, p) == (cls, name, proto))
        if hits:
            out.append(Attribution(cls, name, proto, "CONFIRMED_JAVA_EXPORT", ",".join(h.split(":")[0] for h in hits),
                                   ",".join(h.split(":")[1] for h in hits), "ELF_REFERENCE"))
        elif rt:
            out.append(Attribution(cls, name, proto, "CONFIRMED_REGISTERNATIVES", ",".join(rt), "-", "RUNTIME_OBSERVED"))
        else:
            internal = cls[1:-1]
            cand = sorted(ln for ln, (ss, onload) in strings.items()
                          if onload and internal in ss and name in ss and proto in ss)
            if cand:
                out.append(Attribution(cls, name, proto, "CANDIDATE_ONLY", ",".join(cand), "-", "STRING_ONLY"))
            else:
                out.append(Attribution(cls, name, proto, "UNRESOLVED", "-", "-", "-"))
    return out


# =============================================================================
# Driver
# =============================================================================
def parse_badging_native(path: Path) -> list[tuple[str, bool]]:
    out = []
    for line in path.read_text(errors="replace").splitlines():
        m = re.match(r"^uses-native-library(-not-required)?:'([^']+)'", line)
        if m:
            out.append((m.group(2), m.group(1) is None))
    return out


def clean(v) -> str:
    return str(v).replace("\t", " ").replace("\n", " ")


def write_out(final: Path, files: dict[str, str]) -> None:
    final = final.resolve()
    if final.exists() and any(final.iterdir()):
        raise InputError(f"output directory must be empty or absent: {final}")
    tmp = Path(tempfile.mkdtemp(prefix=".n1ib2n-"))
    try:
        for n, t in files.items():
            (tmp / n).write_text(t)
        final.parent.mkdir(parents=True, exist_ok=True)
        if final.exists():
            final.rmdir()
        shutil.move(str(tmp), str(final))
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def cmd_derive(a) -> int:
    if a.abi not in ABI_MACHINE:
        raise InputError(f"--abi must be one of {sorted(ABI_MACHINE)}")
    if not a.apk.is_file():
        raise InputError(f"missing {a.apk}")
    dirs = []
    for d in a.lib_dir or []:
        k, _, p = d.partition("=")
        if k not in PARTITIONS or not p:
            raise InputError(f"--lib-dir must be PARTITION=DIR with PARTITION in {PARTITIONS}, got {d!r}")
        if not Path(p).is_dir():
            raise InputError(f"--lib-dir {p} is not a directory")
        dirs.append((k, Path(p)))
    namespace_visible = set(a.namespace_visible_library or [])
    for name in namespace_visible:
        if not re.fullmatch(r"[A-Za-z0-9_.+-]+\\.so", name):
            raise InputError(f"--namespace-visible-library must be NAME.so, got {name!r}")
    for p in a.namespace_visible_list or []:
        if not p.is_file():
            raise InputError(f"missing --namespace-visible-list {p}")
        for line in p.read_text(errors="replace").splitlines():
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            name = line.split()[0]
            if name.endswith(".so"):
                namespace_visible.add(name)

    uses_native = []
    for u in a.uses_native_library or []:
        m = re.fullmatch(r"([A-Za-z0-9_.+-]+\.so):(required|optional)", u)
        if not m:
            raise InputError(f"--uses-native-library must be NAME.so:required|optional, got {u!r}")
        uses_native.append((m.group(1), m.group(2) == "required"))
    if a.badging:
        uses_native += parse_badging_native(a.badging)
    runtime = set()
    if a.runtime_registrations:
        for line in a.runtime_registrations.read_text().splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 4:
                raise InputError("--runtime-registrations lines are: class<TAB>method<TAB>proto<TAB>library")
            runtime.add(tuple(parts))

    container = S.load_container(a.apk)
    if not container.dexes:
        raise InputError(f"{a.apk}: no classes.dex")
    oracle = "NOT_RUN"
    if a.oracle:
        for _, d in container.dexes:
            S.oracle_check_dex(d)
        oracle = f"PASS(app:{len(container.dexes)})"

    apk_libs, other_abi = {}, []
    with zipfile.ZipFile(a.apk) as z:
        for info in z.infolist():
            m = re.fullmatch(r"lib/([^/]+)/([^/]+\.so)", info.filename)
            if not m:
                continue
            if m.group(1) == a.abi:
                apk_libs[m.group(2)] = (z.read(info), info.filename)
            else:
                other_abi.append(info.filename)

    sites = []
    natives = []
    for entry, dex in container.dexes:
        sites += load_sites(dex, entry)
        for cd in dex.classes:
            for mth in cd.methods:
                if mth.access & S.ACC_NATIVE:
                    natives.append((cd.descriptor, mth.ref.name, mth.ref.proto))

    roots: list[tuple[str, str, str | None]] = []
    root_rows = []
    for name in sorted(apk_libs):
        roots.append((name, "APK_PACKAGED", None))
        root_rows.append(("APK_PACKAGED", name, apk_libs[name][1], "PARSED_DECLARATION"))
    for name, required in uses_native:
        roots.append((name, f"USES_NATIVE_LIBRARY:{'required' if required else 'optional'}", None))
        root_rows.append((f"USES_NATIVE_LIBRARY_{'REQUIRED' if required else 'OPTIONAL'}", name, "manifest", "PARSED_DECLARATION"))
    for s in sites:
        if s.status != "CONSTANT":
            continue
        if s.api == "loadLibrary":
            if "/" in s.value:
                root_rows.append(("LOAD_SITE_INVALID", s.value, s.site, "DEX_CALLSITE"))
                continue
            so = f"lib{s.value}.so"
            roots.append((so, f"LOADLIBRARY:{s.site}", None))
            root_rows.append(("LOADLIBRARY_CONSTANT", so, s.site, "DEX_CALLSITE"))
        else:
            parts = s.value.split("/")
            hint = parts[1] if s.value.startswith("/") and len(parts) > 2 and parts[1] in PARTITIONS else None
            if hint is None:
                root_rows.append(("LOAD_PATH_OUTSIDE_PARTITIONS", s.value, s.site, "DEX_CALLSITE"))
                continue
            roots.append((parts[-1], f"LOAD:{s.site}", hint))
            root_rows.append(("LOAD_CONSTANT_PATH", s.value, s.site, "DEX_CALLSITE"))

    with tempfile.TemporaryDirectory() as td:
        finder = Finder(apk_libs, dirs, ABI_MACHINE[a.abi], Path(td), namespace_visible)
        libs = closure(finder, roots)
        attrs = attribute(natives, libs, runtime)

    superset = []
    if a.search_superset:
        superset = [l.strip() for l in a.search_superset.read_text().splitlines() if l.strip() and not l.startswith("#")]
    admitted = {n for n, l in libs.items() if l.status == "FOUND"}
    evidence_candidates = sorted(n for n, l in libs.items()
                                 if l.status == "FOUND" and PROVIDER_CLASS[l.partition] != "PLATFORM_OR_APEX")
    req_missing = sorted(n for n, r in uses_native if r and libs.get(n) and libs[n].status != "FOUND")
    unresolved_sites = [s for s in sites if s.status != "CONSTANT"]

    files = {}
    files["NATIVE_ROOTS.tsv"] = "root_kind\tname\tevidence\tevidence_strength\n" + "".join(
        "\t".join(clean(x) for x in r) + "\n" for r in root_rows)
    files["LOAD_SITES.tsv"] = "caller\tsite\tapi\tstatus\tvalue\treason\tproof_chain\tevidence_strength\n" + "".join(
        "\t".join(clean(x) for x in (s.caller, s.site, s.api, s.status, s.value, s.reason, s.chain or "-",
                                     "DEX_CALLSITE")) + "\n" for s in sites)
    files["NATIVE_CLOSURE.tsv"] = (
        "library\tstatus\tpartition\tprovider_class\tpath\tsha256\tneeded\tadmitted_by\t"
        "namespace_visibility\tevidence_strength\n"
    ) + "".join(
        "\t".join(clean(x) for x in (
            l.name, l.status, l.partition, PROVIDER_CLASS.get(l.partition, "-"), l.path or "-", l.sha256,
            ",".join(l.info.needed) if l.info else "-", ";".join(l.reasons), l.namespace_visibility,
            "ELF_REFERENCE" if any(r.startswith("DT_NEEDED") for r in l.reasons) else "PARSED_DECLARATION"
            if any(r.startswith(("APK", "USES")) for r in l.reasons) else "DEX_CALLSITE")) + "\n"
        for l in sorted(libs.values(), key=lambda l: l.name))
    files["JNI_ATTRIBUTION.tsv"] = "class\tmethod\tproto\tattribution\tlibraries\tsymbols\tevidence_strength\n" + "".join(
        "\t".join(clean(x) for x in (t.cls, t.name, t.proto, t.result, t.libs, t.symbol, t.strength)) + "\n" for t in attrs)
    if superset:
        files["SEARCH_SUPERSET.tsv"] = "library\tadmitted_by_evidence\n" + "".join(
            f"{n}\t{'YES' if n in admitted else 'NO_SEARCH_SUPERSET_ONLY'}\n" for n in superset)
    count = lambda r: sum(1 for t in attrs if t.result == r)  # noqa: E731
    env = [("N1I_B2_NATIVE_TOOL_VERSION", TOOL_VERSION),
           ("N1I_B2_NATIVE_SIDE", a.side),
           ("N1I_B2_NATIVE_APK_SHA256", hashlib.sha256(a.apk.read_bytes()).hexdigest()),
           ("N1I_B2_NATIVE_ABI", a.abi),
           ("N1I_B2_NATIVE_APK_LIBS_OTHER_ABI_IGNORED", str(len(other_abi))),
           ("N1I_B2_NATIVE_LOAD_SITES", str(len(sites))),
           ("N1I_B2_NATIVE_LOAD_SITES_CONSTANT", str(len(sites) - len(unresolved_sites))),
           ("N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED", str(len(unresolved_sites))),
           ("N1I_B2_NATIVE_ADMITTED_LIBRARIES", str(len(admitted))),
           ("N1I_B2_NATIVE_NOT_FOUND", ",".join(sorted(n for n, l in libs.items() if l.status == "NOT_FOUND")) or "NONE"),
           ("N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN",
            ",".join(sorted(n for n, l in libs.items() if l.status == "FILE_PRESENT_NAMESPACE_UNPROVEN")) or "NONE"),
           ("N1I_B2_NATIVE_NAMESPACE_VISIBLE_LIBRARY_COUNT", str(len(namespace_visible))),
           ("N1I_B2_NATIVE_NAMESPACE_VISIBILITY_INFERRED", "NO"),
           ("N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING", ",".join(req_missing) or "NONE"),
           ("N1I_B2_NATIVE_SEARCH_SUPERSET_COUNT", str(len(superset)) if superset else "NOT_PROVIDED"),
           ("N1I_B2_NATIVE_EVIDENCE_CANDIDATE_COUNT", str(len(evidence_candidates))),
           ("N1I_B2_NATIVE_EVIDENCE_CANDIDATES", ",".join(evidence_candidates) or "NONE"),
           ("N1I_B2_NATIVE_JNI_CONFIRMED_JAVA_EXPORT", str(count("CONFIRMED_JAVA_EXPORT"))),
           ("N1I_B2_NATIVE_JNI_CONFIRMED_REGISTERNATIVES", str(count("CONFIRMED_REGISTERNATIVES"))),
           ("N1I_B2_NATIVE_JNI_CANDIDATE_ONLY", str(count("CANDIDATE_ONLY"))),
           ("N1I_B2_NATIVE_JNI_UNRESOLVED", str(count("UNRESOLVED"))),
           ("N1I_B2_NATIVE_DEXDUMP_ORACLE", oracle),
           ("N1I_B2_NATIVE_KEYWORD_ROOTS_USED", "NO"),
           ("N1I_B2_NATIVE_DEVICE_CONTACT", "NO")]
    files["NATIVE_SUMMARY.env"] = "".join(f"{k}={clean(v)}\n" for k, v in env)
    write_out(a.out, files)
    print(f"N1I_B2_NATIVE_EVIDENCE_CANDIDATE_COUNT={len(evidence_candidates)}")
    print(f"N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED={len(unresolved_sites)}")
    print(f"OUTPUT={a.out.resolve()}")
    return 0


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--side", required=True, choices=("stock", "c3a"))
    p.add_argument("--apk", type=Path, required=True)
    p.add_argument("--abi", default="arm64-v8a")
    p.add_argument("--lib-dir", action="append", help="PARTITION=DIR, searched in the order given")
    p.add_argument("--uses-native-library", action="append", help="NAME.so:required|optional")
    p.add_argument("--namespace-visible-library", action="append",
                   help="NAME.so explicitly proven visible in the app linker namespace")
    p.add_argument("--namespace-visible-list", type=Path, action="append",
                   help="public/shared native library list; first whitespace-delimited token is the SONAME")
    p.add_argument("--badging", type=Path, help="`aapt2 dump badging` output (uses-native-library lines)")
    p.add_argument("--runtime-registrations", type=Path,
                   help="RUNTIME_OBSERVED RegisterNatives evidence: class<TAB>method<TAB>proto<TAB>library")
    p.add_argument("--search-superset", type=Path, help="earlier keyword list (e.g. N1I-A), compared, never used as roots")
    p.add_argument("--no-oracle", dest="oracle", action="store_false", help="skip the dexdump cross-check")
    p.add_argument("--out", type=Path, required=True)
    a = p.parse_args(argv)
    try:
        return cmd_derive(a)
    except (InputError, S.DexError, S.ElfError, zipfile.BadZipFile) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
