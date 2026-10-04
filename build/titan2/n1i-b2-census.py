#!/usr/bin/env python3
"""Titan 2 N1I-B2 interface census and reverse vendor->system census. Offline only.

Detects edges of the form "vendor expects X, stock system provides X, C3A does not", even when the
OEM IMS APK never references X. Evidence sources are kept apart and never conflated:

  VINTF device manifest (vendor/odm)        what the VENDOR PROVIDES        -> VINTF_PROVIDED.tsv, never an edge
  VINTF device compatibility matrix         what the VENDOR REQUIRES from the framework -> VINTF_REQUIREMENT edges
  VINTF framework compatibility matrix      what the FRAMEWORK requires from the vendor -> context only
  VINTF framework manifest (system side)    what each SYSTEM image provides -> producer evidence
  init .rc / build.prop                     property triggers (consumers) and setprop/prop files (producers)
  vendor SELinux policy (cil)               service_manager / hwservice_manager `find` permissions -> consumers,
                                            mapped to names through each side's service_contexts
  vendor binaries                           exact strings equal to a known system service name -> STRING_ONLY
  runtime                                   `service list` / `lshal` per side, and vendor-process waits in
                                            logcat attributed through `ps` -> RUNTIME_OBSERVED

Edge status (exactly one per edge):
  VENDOR_SELF_PROVIDED                 the vendor produces/registers it itself: not a system edge
  NO_SYSTEM_PRODUCER_ON_STOCK          no stock system-side producer found (static or runtime)
  SATISFIED_ON_C3A                     C3A provides it
  MISSING_ON_C3A_OPTIONAL              VINTF requirement marked optional, absent on C3A (not counted)
  MISSING_ON_C3A_STRING_ONLY_CANDIDATE consumer evidence is STRING_ONLY: never counted, never proven
  MISSING_ON_C3A_CANDIDATE             non-string consumer evidence, absence on C3A is static only
  MISSING_ON_C3A_RUNTIME_CONFIRMED     non-string consumer evidence and runtime absent on C3A / present on stock
  MTK_SYSTEM_EDGE_PROVEN               a vendor process was observed waiting for it on C3A (runtime), stock
                                       provides it, and the C3A vendor tree is byte-identical to the stock vendor
                                       tree. STRING_ONLY evidence can never reach this state on its own.

N1I_B2_VENDOR_EXPECTED_SYSTEM_EDGE_COUNT counts the last three only.

Exit codes: 0 completed   2 input error (nothing written)
"""
from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

TOOL_VERSION = "1.0.0"
SYSTEM_PARTS = ("system", "system_ext", "product")
VENDOR_PARTS = ("vendor", "odm")
STRENGTH_ORDER = ("RUNTIME_OBSERVED", "PARSED_DECLARATION", "ELF_REFERENCE", "DEX_CALLSITE", "STRING_ONLY")
COUNTED = ("MISSING_ON_C3A_CANDIDATE", "MISSING_ON_C3A_RUNTIME_CONFIRMED", "MTK_SYSTEM_EDGE_PROVEN")
STATUSES = ("VENDOR_SELF_PROVIDED", "NO_SYSTEM_PRODUCER_ON_STOCK", "SATISFIED_ON_C3A", "MISSING_ON_C3A_OPTIONAL",
            "MISSING_ON_C3A_STRING_ONLY_CANDIDATE") + COUNTED
MAX_SCAN_BYTES = 64 << 20


class InputError(Exception):
    pass


@dataclass
class Ev:
    source: str      # e.g. vendor_init_trigger, vendor_policy_find, vendor_binary_string, runtime_wait
    ref: str         # path:line or path
    strength: str


@dataclass
class Edge:
    kind: str        # PROPERTY | BINDER_SERVICE | AIDL_HIDL_INTERFACE | VINTF_REQUIREMENT
    name: str
    consumers: list = field(default_factory=list)
    stock_producers: list = field(default_factory=list)
    c3a_producers: list = field(default_factory=list)
    vendor_producers: list = field(default_factory=list)
    stock_runtime: str = "NOT_PROVIDED"   # PRESENT | ABSENT | NOT_PROVIDED
    c3a_runtime: str = "NOT_PROVIDED"
    vendor_waits: list = field(default_factory=list)
    optional: bool = False
    status: str = ""

    @property
    def edge_id(self) -> str:
        return f"{self.kind}:{self.name}"

    def consumer_strength(self) -> str:
        s = {e.strength for e in self.consumers}
        return next((x for x in STRENGTH_ORDER if x in s), "-")


def rel(root: Path, p: Path) -> str:
    return f"{root.name}/{p.relative_to(root).as_posix()}"


def files(root: Path, parts: tuple, sub: str, pattern: str) -> list[Path]:
    out = []
    for part in parts:
        d = root / part / sub
        if d.is_dir():
            out += sorted(p for p in d.rglob(pattern) if p.is_file())
    return out


def text(p: Path) -> list[str]:
    data = p.read_bytes()
    if b"\0" in data[:4096]:
        raise InputError(f"binary file where text was expected: {p}")
    return data.decode("utf-8", "replace").splitlines()


# =============================================================================
# init / properties
# =============================================================================
TRIGGER = re.compile(r"property:([A-Za-z0-9_.\-]+)=")
SETPROP = re.compile(r"^\s*setprop\s+([A-Za-z0-9_.\-]+)\s+\S")
SERVICE = re.compile(r"^\s*service\s+(\S+)\s+(\S+)")


def init_scan(root: Path, parts: tuple):
    triggers, setprops, services = [], [], []
    for p in files(root, parts, "etc/init", "*.rc"):
        for no, line in enumerate(text(p), 1):
            s = line.split("#", 1)[0]
            if s.strip().startswith("on "):
                for name in TRIGGER.findall(s):
                    triggers.append((name, f"{rel(root, p)}:{no}"))
            m = SETPROP.match(s)
            if m:
                setprops.append((m.group(1), f"{rel(root, p)}:{no}"))
            m = SERVICE.match(s)
            if m:
                services.append((m.group(1), m.group(2), f"{rel(root, p)}:{no}"))
    return triggers, setprops, services


def prop_files(root: Path, parts: tuple) -> list[tuple[str, str]]:
    out = []
    for part in parts:
        for cand in (root / part / "build.prop", root / part / "etc/build.prop", root / part / "default.prop"):
            if cand.is_file():
                for no, line in enumerate(text(cand), 1):
                    s = line.strip()
                    if s and not s.startswith("#") and "=" in s and not s.startswith("import "):
                        out.append((s.split("=", 1)[0].strip(), f"{rel(root, cand)}:{no}"))
    return out


# =============================================================================
# VINTF
# =============================================================================
def parse_vintf(p: Path) -> tuple[str, str, list[dict]]:
    raw = "\n".join(text(p))
    if re.search(r"<!DOCTYPE|<!ENTITY", raw, re.I):
        raise InputError(f"DOCTYPE/ENTITY refused in {p}")
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as e:
        raise InputError(f"VINTF parse error in {p}: {e}") from e
    if root.tag not in ("manifest", "compatibility-matrix"):
        raise InputError(f"{p}: not a VINTF manifest or compatibility matrix")
    typ = root.get("type", "")
    if typ not in ("device", "framework"):
        raise InputError(f"{p}: VINTF type must be device or framework, got {typ!r}")
    hals = []
    for hal in root.findall("hal"):
        name = (hal.findtext("name") or "").strip()
        if not name:
            raise InputError(f"{p}: <hal> without <name>")
        ifaces = []
        for i in hal.findall("interface"):
            iname = (i.findtext("name") or "").strip()
            for inst in i.findall("instance") or [None]:
                ifaces.append(f"{iname}/{(inst.text or '').strip() if inst is not None else '*'}")
        for fq in hal.findall("fqname"):
            v = (fq.text or "").strip()
            ifaces.append(v.split("::")[-1] if "::" in v else v)
        hals.append({"name": name, "format": hal.get("format", "hidl"), "optional": hal.get("optional") == "true",
                     "interfaces": sorted(set(ifaces)) or ["*"]})
    return root.tag, typ, hals


def vintf_files(root: Path, parts: tuple) -> list[Path]:
    out = []
    for part in parts:
        d = root / part / "etc/vintf"
        if d.is_dir():
            out += sorted(p for p in d.rglob("*.xml") if p.is_file())
    return out


def vintf_index(root: Path, parts: tuple):
    """Returns provided {(hal, iface)} for manifests and requirement list for matrices, with refs."""
    provided, matrices = {}, []
    for p in vintf_files(root, parts):
        tag, typ, hals = parse_vintf(p)
        for h in hals:
            for i in h["interfaces"]:
                if tag == "manifest":
                    provided.setdefault((h["name"], i), []).append(rel(root, p))
                else:
                    matrices.append((typ, h["name"], i, h["optional"], h["format"], rel(root, p)))
    return provided, matrices


# =============================================================================
# SELinux service mapping
# =============================================================================
CIL_FIND = re.compile(r"^\(allow\s+(\S+)\s+(\S+)\s+\((service_manager|hwservice_manager)\s+\(([^)]*)\)\)\)")


def policy_finds(root: Path) -> list[tuple[str, str, str, str]]:
    out = []
    for p in files(root, VENDOR_PARTS, "etc/selinux", "*.cil"):
        for no, line in enumerate(text(p), 1):
            m = CIL_FIND.match(line.strip())
            if m and "find" in m.group(4).split():
                out.append((m.group(1), m.group(2), m.group(3), f"{rel(root, p)}:{no}"))
    return out


def contexts(root: Path, parts: tuple, kind: str) -> dict[str, list[tuple[str, str]]]:
    """type -> [(service name, ref)] from *service_contexts or *hwservice_contexts files."""
    suffix = "hwservice_contexts" if kind == "hwservice_manager" else "service_contexts"
    out: dict[str, list] = {}
    for p in files(root, parts, "etc/selinux", "*"):
        n = p.name
        if not n.endswith(suffix) or (suffix == "service_contexts" and n.endswith("hwservice_contexts")):
            continue
        for no, line in enumerate(text(p), 1):
            s = line.split("#", 1)[0].split()
            if len(s) >= 2 and s[1].startswith("u:object_r:"):
                typ = s[1].split(":")[2]
                out.setdefault(typ, []).append((s[0], f"{rel(root, p)}:{no}"))
    return out


def names_in(ctx: dict) -> dict[str, str]:
    return {n: ref for lst in ctx.values() for n, ref in lst}


# =============================================================================
# Runtime evidence
# =============================================================================
def service_list(p: Path | None) -> set[str] | None:
    if p is None:
        return None
    out = set()
    for line in text(p):
        m = re.match(r"^\s*\d+\s+([^:\s]+):", line)
        if m:
            out.add(m.group(1))
    return out


def lshal_names(p: Path | None) -> set[str] | None:
    if p is None:
        return None
    out = set()
    for line in text(p):
        for pkg, iface in re.findall(r"([A-Za-z0-9_.]+)@\d+\.\d+::(\w+)/\S+", line):
            out.add(f"{pkg}::{iface}")
    return out


WAIT_PATTERNS = (
    re.compile(r"Waiting for service '([^']+)'"),
    re.compile(r"Waited one second for ([A-Za-z0-9_.@:/]+)"),
    re.compile(r"Service ([A-Za-z0-9_.]+) didn't start"),
    re.compile(r"getService\(([^)]+)\) failed"),
)


def vendor_waits(logs: list[Path], ps: Path | None, vendor_names: set[str]) -> tuple[list, int]:
    """[(name, ref)] for waits whose pid belongs to a vendor process; plus count of unattributed waits."""
    if not logs:
        return [], 0
    pid_name = {}
    if ps is not None:
        for line in text(ps):
            cols = line.split()
            if len(cols) >= 2 and cols[0].isdigit():
                pid_name[cols[0]] = cols[-1].rsplit("/", 1)[-1]
    out, unattributed = [], 0
    for lp in logs:
        for no, line in enumerate(text(lp), 1):
            for rx in WAIT_PATTERNS:
                m = rx.search(line)
                if not m:
                    continue
                name = m.group(1)
                if "@" in name:     # HIDL fqinstance -> pkg::IFace
                    mm = re.match(r"([A-Za-z0-9_.]+)@\d+\.\d+::(\w+)", name)
                    name = f"{mm.group(1)}::{mm.group(2)}" if mm else name
                cols = line.split()
                pid = ""
                # B1 capture uses: logcat -v threadtime,uid,year
                #   YYYY-MM-DD HH:MM:SS.mmm UID PID TID P ...
                # Also accept year+threadtime without uid:
                #   YYYY-MM-DD HH:MM:SS.mmm PID TID P ...
                priorities = {"V", "D", "I", "W", "E", "A", "F", "S"}
                if len(cols) > 5 and re.fullmatch(r"\d{4}-\d{2}-\d{2}", cols[0]) and cols[5] in priorities:
                    pid = cols[3] if cols[3].isdigit() else ""
                elif len(cols) > 4 and re.fullmatch(r"\d{4}-\d{2}-\d{2}", cols[0]) and cols[4] in priorities:
                    pid = cols[2] if cols[2].isdigit() else ""
                elif len(cols) > 4 and re.fullmatch(r"\d{2}-\d{2}", cols[0]) and cols[4] in priorities:
                    pid = cols[2] if cols[2].isdigit() else ""
                proc = pid_name.get(pid)
                if proc and proc in vendor_names:
                    out.append((name, f"{lp.name}:{no}"))
                else:
                    unattributed += 1
    return out, unattributed


def vendor_strings(root: Path, wanted: set[str]) -> dict[str, list[str]]:
    """Exact NUL/space-delimited strings in vendor binaries that equal a known service name."""
    hits: dict[str, list[str]] = {}
    if not wanted:
        return hits
    for part in VENDOR_PARTS:
        for sub in ("bin", "lib", "lib64"):
            d = root / part / sub
            if not d.is_dir():
                continue
            for p in sorted(x for x in d.rglob("*") if x.is_file()):
                data = p.read_bytes()[:MAX_SCAN_BYTES]
                for tok in set(re.findall(rb"[\x21-\x7e]{3,}", data)):
                    s = tok.decode()
                    if s in wanted:
                        hits.setdefault(s, []).append(rel(root, p))
    return hits


def tree_hash(d: Path) -> str:
    if not d.is_dir():
        return "ABSENT"
    h = hashlib.sha256()
    for p in sorted(x for x in d.rglob("*") if x.is_file()):
        h.update(p.relative_to(d).as_posix().encode() + b"\0" + hashlib.sha256(p.read_bytes()).digest())
    return h.hexdigest()


# =============================================================================
# Census
# =============================================================================
def classify(e: Edge, vendor_identity_proven: bool) -> str:
    if e.vendor_producers:
        return "VENDOR_SELF_PROVIDED"
    # Runtime lists, when provided, are authoritative for presence; otherwise static producers are used.
    stock_has = (e.stock_runtime == "PRESENT") if e.stock_runtime != "NOT_PROVIDED" else bool(e.stock_producers)
    if not stock_has:
        return "NO_SYSTEM_PRODUCER_ON_STOCK"
    c3a_has = (e.c3a_runtime == "PRESENT") if e.c3a_runtime != "NOT_PROVIDED" else bool(e.c3a_producers)
    if c3a_has:
        return "SATISFIED_ON_C3A"
    if e.optional:
        return "MISSING_ON_C3A_OPTIONAL"
    if e.consumer_strength() in ("STRING_ONLY", "-"):
        return "MISSING_ON_C3A_STRING_ONLY_CANDIDATE"
    if e.vendor_waits and vendor_identity_proven:
        return "MTK_SYSTEM_EDGE_PROVEN"
    if e.c3a_runtime == "ABSENT" and e.stock_runtime == "PRESENT":
        return "MISSING_ON_C3A_RUNTIME_CONFIRMED"
    return "MISSING_ON_C3A_CANDIDATE"


def census(a) -> tuple[dict, list, list, dict]:
    stock, c3a = a.stock_root.resolve(), a.c3a_root.resolve()
    for r in (stock, c3a):
        if not (r / "system").is_dir():
            raise InputError(f"{r}: no system/ partition directory")
    if not (stock / "vendor").is_dir():
        raise InputError(f"{stock}: no vendor/ partition directory")
    edges: dict[str, Edge] = {}

    def edge(kind: str, name: str) -> Edge:
        e = edges.get(f"{kind}:{name}")
        if e is None:
            e = edges[f"{kind}:{name}"] = Edge(kind, name)
        return e

    # ---- properties
    v_trig, v_set, v_svcs = init_scan(stock, VENDOR_PARTS)
    s_trig, s_set, _ = init_scan(stock, SYSTEM_PARTS)
    c_trig, c_set, _ = init_scan(c3a, SYSTEM_PARTS)
    v_props = prop_files(stock, VENDOR_PARTS)
    s_props, c_props = prop_files(stock, SYSTEM_PARTS), prop_files(c3a, SYSTEM_PARTS)
    for name, ref in v_trig:
        edge("PROPERTY", name).consumers.append(Ev("vendor_init_trigger", ref, "PARSED_DECLARATION"))
    for e in [x for x in edges.values() if x.kind == "PROPERTY"]:
        e.vendor_producers += [r for n, r in v_set + v_props if n == e.name]
        e.stock_producers += [r for n, r in s_set + s_props if n == e.name]
        e.c3a_producers += [r for n, r in c_set + c_props if n == e.name]

    # ---- VINTF
    s_prov, s_mat = vintf_index(stock, SYSTEM_PARTS)
    c_prov, _ = vintf_index(c3a, SYSTEM_PARTS)
    v_prov, v_mat = vintf_index(stock, VENDOR_PARTS)
    vendor_provided = sorted((h, i, ";".join(refs)) for (h, i), refs in v_prov.items())
    framework_requires = sorted((h, i, "optional" if opt else "required", ref)
                                for typ, h, i, opt, fmt, ref in s_mat if typ == "framework")
    for typ, h, i, opt, fmt, ref in v_mat:
        if typ != "device":
            continue
        e = edge("VINTF_REQUIREMENT", f"{h}/{i}")
        e.optional = opt
        e.consumers.append(Ev("vendor_device_compatibility_matrix", ref, "PARSED_DECLARATION"))
        e.stock_producers += s_prov.get((h, i), [])
        e.c3a_producers += c_prov.get((h, i), [])
        e.vendor_producers += v_prov.get((h, i), [])

    # ---- SELinux find -> service names
    finds = policy_finds(stock)
    v_ctx = {k: contexts(stock, VENDOR_PARTS, k) for k in ("service_manager", "hwservice_manager")}
    s_ctx = {k: contexts(stock, SYSTEM_PARTS, k) for k in ("service_manager", "hwservice_manager")}
    c_ctx = {k: contexts(c3a, SYSTEM_PARTS, k) for k in ("service_manager", "hwservice_manager")}
    unmapped = []
    for dom, typ, mgr, ref in finds:
        kind = "BINDER_SERVICE" if mgr == "service_manager" else "AIDL_HIDL_INTERFACE"
        names = [n for n, _ in s_ctx[mgr].get(typ, [])] + [n for n, _ in v_ctx[mgr].get(typ, [])]
        if not names:
            unmapped.append((dom, typ, mgr, ref))
            continue
        for n in sorted(set(names)):
            edge(kind, n).consumers.append(Ev(f"vendor_policy_{mgr}_find:{dom}", ref, "PARSED_DECLARATION"))
    for kind, mgr in (("BINDER_SERVICE", "service_manager"), ("AIDL_HIDL_INTERFACE", "hwservice_manager")):
        sv, ss, cs = names_in(v_ctx[mgr]), names_in(s_ctx[mgr]), names_in(c_ctx[mgr])
        for e in [x for x in edges.values() if x.kind == kind]:
            if e.name in sv:
                e.vendor_producers.append(sv[e.name])
            if e.name in ss:
                e.stock_producers.append(ss[e.name])
            if e.name in cs:
                e.c3a_producers.append(cs[e.name])

    # ---- runtime service presence
    srt, crt = service_list(a.stock_service_list), service_list(a.c3a_service_list)
    shal, chal = lshal_names(a.stock_lshal), lshal_names(a.c3a_lshal)

    # ---- vendor binary strings: only names known as SYSTEM services (stock contexts or runtime)
    known = set(names_in(s_ctx["service_manager"])) | (srt or set())
    known -= set(names_in(v_ctx["service_manager"]))
    for name, refs in vendor_strings(stock, known).items():
        for r in refs:
            edge("BINDER_SERVICE", name).consumers.append(Ev("vendor_binary_string", r, "STRING_ONLY"))
    for e in [x for x in edges.values() if x.kind == "BINDER_SERVICE"]:
        if e.name in names_in(s_ctx["service_manager"]) and not e.stock_producers:
            e.stock_producers.append(names_in(s_ctx["service_manager"])[e.name])

    for e in edges.values():
        if e.kind == "BINDER_SERVICE":
            rs, rc = srt, crt
        elif e.kind == "AIDL_HIDL_INTERFACE":
            rs, rc = shal, chal
        else:
            continue
        if rs is not None:
            e.stock_runtime = "PRESENT" if e.name in rs else "ABSENT"
        if rc is not None:
            e.c3a_runtime = "PRESENT" if e.name in rc else "ABSENT"

    # ---- vendor waits on C3A (runtime consumer evidence)
    vnames = {n for n, _, _ in v_svcs} | {Path(x).name for _, x, _ in v_svcs}
    waits, unattributed = vendor_waits(a.c3a_log or [], a.c3a_ps, vnames)
    for name, ref in waits:
        for kind in ("BINDER_SERVICE", "AIDL_HIDL_INTERFACE"):
            e = edges.get(f"{kind}:{name}")
            if e is not None:
                e.vendor_waits.append(ref)
                e.consumers.append(Ev("runtime_vendor_wait_on_c3a", ref, "RUNTIME_OBSERVED"))
                break
        else:
            e = edge("BINDER_SERVICE", name)
            e.vendor_waits.append(ref)
            e.consumers.append(Ev("runtime_vendor_wait_on_c3a", ref, "RUNTIME_OBSERVED"))
            if srt is not None:
                e.stock_runtime = "PRESENT" if name in srt else "ABSENT"
            if crt is not None:
                e.c3a_runtime = "PRESENT" if name in crt else "ABSENT"

    vendor_tree_stock = tree_hash(stock / "vendor")
    vendor_tree_c3a = tree_hash(c3a / "vendor")
    vendor_identity_proven = vendor_tree_c3a != "ABSENT" and vendor_tree_c3a == vendor_tree_stock
    for e in edges.values():
        e.status = classify(e, vendor_identity_proven)
    meta = {"vendor_tree_stock": vendor_tree_stock, "vendor_tree_c3a": vendor_tree_c3a,
            "vendor_identity_proven": vendor_identity_proven,
            "unattributed_waits": unattributed, "unmapped_policy": unmapped,
            "vendor_provided": vendor_provided, "framework_requires": framework_requires,
            "runtime": {"stock_service_list": srt is not None, "c3a_service_list": crt is not None,
                        "stock_lshal": shal is not None, "c3a_lshal": chal is not None}}
    return edges, vendor_provided, framework_requires, meta


def clean(v) -> str:
    return str(v).replace("\t", " ").replace("\n", " ")


def write_out(final: Path, out: dict[str, str]) -> None:
    final = final.resolve()
    if final.exists() and any(final.iterdir()):
        raise InputError(f"output directory must be empty or absent: {final}")
    tmp = Path(tempfile.mkdtemp(prefix=".n1ib2c-"))
    try:
        for n, t in out.items():
            (tmp / n).write_text(t)
        final.parent.mkdir(parents=True, exist_ok=True)
        if final.exists():
            final.rmdir()
        shutil.move(str(tmp), str(final))
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--stock-root", type=Path, required=True, help="stock tree with system/ system_ext/ product/ vendor/ odm/")
    p.add_argument("--c3a-root", type=Path, required=True, help="C3A tree with system/ (vendor is the preserved stock vendor)")
    p.add_argument("--stock-service-list", type=Path)
    p.add_argument("--c3a-service-list", type=Path)
    p.add_argument("--stock-lshal", type=Path)
    p.add_argument("--c3a-lshal", type=Path)
    p.add_argument("--c3a-log", type=Path, action="append", help="C3A logcat (threadtime) for vendor wait evidence")
    p.add_argument("--c3a-ps", type=Path, help="C3A `ps -A -o PID,PPID,USER,NAME` to attribute waits to vendor processes")
    p.add_argument("--out", type=Path, required=True)
    a = p.parse_args(argv)
    try:
        for opt in ("stock_service_list", "c3a_service_list", "stock_lshal", "c3a_lshal", "c3a_ps"):
            v = getattr(a, opt)
            if v is not None and not v.is_file():
                raise InputError(f"missing --{opt.replace('_', '-')} {v}")
        for v in a.c3a_log or []:
            if not v.is_file():
                raise InputError(f"missing --c3a-log {v}")
        edges, vprov, freq, meta = census(a)
        rows = ["edge_id\tcomponent_kind\tname\tstatus\tcounted_as_vendor_expected_system_edge\tconsumer_evidence_strength\t"
                "consumer_evidence\tstock_producer\tc3a_producer\tvendor_producer\tstock_runtime\tc3a_runtime\t"
                "vendor_wait_on_c3a\toptional"]
        for k in sorted(edges):
            e = edges[k]
            rows.append("\t".join(clean(x) for x in (
                e.edge_id, e.kind, e.name, e.status, "YES" if e.status in COUNTED else "NO", e.consumer_strength(),
                ";".join(f"{c.source}@{c.ref}[{c.strength}]" for c in e.consumers) or "-",
                ";".join(e.stock_producers) or "-", ";".join(e.c3a_producers) or "-",
                ";".join(e.vendor_producers) or "-", e.stock_runtime, e.c3a_runtime,
                ";".join(e.vendor_waits) or "-", "YES" if e.optional else "NO")))
        counts = {s: sum(1 for e in edges.values() if e.status == s) for s in STATUSES}
        env = [("N1I_B2_CENSUS_TOOL_VERSION", TOOL_VERSION),
               ("N1I_B2_CENSUS_EDGES", str(len(edges)))]
        env += [(f"N1I_B2_CENSUS_{s}", str(n)) for s, n in counts.items()]
        env += [("N1I_B2_VENDOR_EXPECTED_SYSTEM_EDGE_COUNT", str(sum(counts[s] for s in COUNTED))),
                ("N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT", str(counts["MTK_SYSTEM_EDGE_PROVEN"])),
                ("N1I_B2_CENSUS_STRING_ONLY_CAN_PROVE", "NO"),
                ("N1I_B2_CENSUS_VENDOR_PROVIDED_INTERFACES", str(len(vprov))),
                ("N1I_B2_CENSUS_FRAMEWORK_REQUIRES_FROM_VENDOR_CONTEXT_ONLY", str(len(freq))),
                ("N1I_B2_CENSUS_VENDOR_TREE_STOCK_SHA256", meta["vendor_tree_stock"]),
                ("N1I_B2_CENSUS_VENDOR_TREE_C3A_SHA256", meta["vendor_tree_c3a"]),
                ("N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL",
                 "C3A_VENDOR_NOT_PROVIDED" if meta["vendor_tree_c3a"] == "ABSENT"
                 else ("YES" if meta["vendor_tree_c3a"] == meta["vendor_tree_stock"] else "NO")),
                ("N1I_B2_CENSUS_RUNTIME_PROOF_VENDOR_IDENTITY_REQUIRED", "YES"),
                ("N1I_B2_CENSUS_UNMAPPED_POLICY_FINDS", str(len(meta["unmapped_policy"]))),
                ("N1I_B2_CENSUS_UNATTRIBUTED_WAITS_IGNORED", str(meta["unattributed_waits"])),
                ("N1I_B2_CENSUS_RUNTIME_INPUTS", ",".join(k for k, v in meta["runtime"].items() if v) or "NONE"),
                ("N1I_B2_CENSUS_DEVICE_CONTACT", "NO")]
        out = {
            "CENSUS_EDGES.tsv": "\n".join(rows) + "\n",
            "VINTF_PROVIDED_BY_VENDOR.tsv": "hal\tinterface\tsource\n" + "".join(
                "\t".join(clean(x) for x in r) + "\n" for r in vprov),
            "FRAMEWORK_REQUIRES_FROM_VENDOR.tsv": "hal\tinterface\trequirement\tsource\n" + "".join(
                "\t".join(clean(x) for x in r) + "\n" for r in freq),
            "UNMAPPED_POLICY_FINDS.tsv": "domain\ttype\tmanager\tsource\n" + "".join(
                "\t".join(clean(x) for x in r) + "\n" for r in meta["unmapped_policy"]),
            "CENSUS_SUMMARY.env": "".join(f"{k}={clean(v)}\n" for k, v in env),
        }
        write_out(a.out, out)
    except InputError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    print(f"N1I_B2_VENDOR_EXPECTED_SYSTEM_EDGE_COUNT={dict(env)['N1I_B2_VENDOR_EXPECTED_SYSTEM_EDGE_COUNT']}")
    print(f"N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT={dict(env)['N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT']}")
    print(f"OUTPUT={a.out.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
