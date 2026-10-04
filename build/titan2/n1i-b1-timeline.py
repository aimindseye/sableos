#!/usr/bin/env python3
"""Titan 2 N1I-B0/B1 offline evidence tool. No device contact, no network.

Subcommands
  b0        Historical vendor-identity reconciliation (N1F/C3A boot capture vs N1D pre-flash).
  apn       Offline APN / carrier-ID FACT extraction from packaged databases, with a separate
            hypothesis file. Packaged data never proves a runtime cause.
  timeline  Normalize retained logs into the 13-step registration path, report coverage, and
            apply the pre-registered first-divergence rules. STOPs when retained evidence cannot
            support a defensible divergence (it never suggests flashing).

Evidence lines are referenced as file:line plus the SHA-256 of the STRICT-SANITIZED line.
Raw line text and raw-line hashes are never written.

Exit codes: 0 completed (including a STOP verdict, which is a valid result)
            2 usage / input error (fail closed, no partial output files are left behind)
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL_VERSION = "1.0.0"


class InputError(Exception):
    """Bad or unusable input. The caller exits 2 and writes nothing."""


def _load_sanitizer():
    path = HERE / "sanitize-n1i-stock-control.py"
    spec = importlib.util.spec_from_file_location("n1i_sanitizer", path)
    if spec is None or spec.loader is None:
        raise InputError(f"cannot load sanitizer {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


SAN = _load_sanitizer()


def sanitized_sha256(line: str) -> str:
    """Full SHA-256 of the strict-sanitized form of a line (amendment 8: never a raw-line hash)."""
    return hashlib.sha256(SAN.sanitize_strict(line.rstrip("\r\n")).encode()).hexdigest()


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_text(path: Path) -> list[str]:
    if not path.is_file():
        raise InputError(f"missing input file: {path}")
    data = path.read_bytes()
    if b"\x00" in data[:65536]:
        raise InputError(f"binary input refused: {path}")
    return data.decode("utf-8", errors="replace").splitlines()


def env_value(v: str) -> str:
    """Values written to .env files: single line, no tabs, sanitized."""
    v = SAN.sanitize_strict(str(v)).replace("\n", " ").replace("\t", " ").strip()
    return v or "-"


class Output:
    """Writes into a temp dir and moves it into place only on success (fail closed)."""

    def __init__(self, out: Path):
        self.final = out.resolve()
        if self.final.exists() and any(self.final.iterdir()):
            raise InputError(f"output directory must be empty or absent: {self.final}")
        self.tmp = Path(tempfile.mkdtemp(prefix=".n1ib-", dir=self.final.parent if self.final.parent.exists() else None))

    def path(self, name: str) -> Path:
        return self.tmp / name

    def env(self, name: str, rows: list[tuple[str, str]]) -> None:
        self.path(name).write_text("".join(f"{k}={env_value(v)}\n" for k, v in rows))

    def tsv(self, name: str, header: list[str], rows: list[list]) -> None:
        def cell(x) -> str:
            return str(x).replace("\t", " ").replace("\n", " ")
        self.path(name).write_text("\t".join(header) + "\n" + "".join("\t".join(cell(c) for c in r) + "\n" for r in rows))

    def commit(self) -> None:
        self.final.parent.mkdir(parents=True, exist_ok=True)
        if self.final.exists():
            self.final.rmdir()
        shutil.move(str(self.tmp), str(self.final))

    def abort(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)


# =============================================================================
# B0 — historical vendor identity reconciliation
# =============================================================================
B0_PROPS = (
    "ro.vendor.build.fingerprint",
    "ro.vendor_dlkm.build.fingerprint",
    "ro.bootimage.build.fingerprint",
    "ro.boot.slot_suffix",
    "ro.boot.verifiedbootstate",
    "ro.boot.vbmeta.digest",
)
# Identity keys decide the verdict. Context keys are reported only: a system_a flash can
# legitimately change vbmeta/verified-boot state without changing the vendor side.
B0_IDENTITY = B0_PROPS[:4]
B0_CONTEXT = B0_PROPS[4:]
B0_ALIASES = {
    "B1_DEVICE_VENDOR_FINGERPRINT": "ro.vendor.build.fingerprint",
    "B1_DEVICE_SLOT_SUFFIX": "ro.boot.slot_suffix",
    "B1_DEVICE_VBMETA_DIGEST": "ro.boot.vbmeta.digest",
}
GETPROP_RX = re.compile(r"^\s*\[([\w.]+)\]:\s*\[(.*)\]\s*$")
ASSIGN_RX = re.compile(r"^\s*([\w.]+)\s*=\s*(.*?)\s*$")


@dataclass
class Found:
    value: str
    ref: str  # path:line


def b0_collect(paths: list[Path]) -> tuple[dict[str, list[Found]], list[tuple[str, str]]]:
    found: dict[str, list[Found]] = {p: [] for p in B0_PROPS}
    files = []
    for path in paths:
        lines = read_text(path)
        files.append((str(path), file_sha256(path)))
        for no, line in enumerate(lines, 1):
            m = GETPROP_RX.match(line) or ASSIGN_RX.match(line)
            if not m:
                continue
            key = B0_ALIASES.get(m.group(1), m.group(1))
            val = m.group(2).strip().strip("'\"")
            if key in found and val and val not in ("-", "UNREADABLE"):
                found[key].append(Found(val, f"{path}:{no}"))
    return found, files


def b0_key_status(cand: list[Found], ref: list[Found]) -> str:
    cv, rv = {f.value for f in cand}, {f.value for f in ref}
    if len(cv) > 1 or len(rv) > 1:
        return "CONFLICT"
    if not cv and not rv:
        return "BOTH_UNRECOVERED"
    if not cv:
        return "CANDIDATE_UNRECOVERED"
    if not rv:
        return "REFERENCE_UNRECOVERED"
    return "MATCH" if cv == rv else "DIFFERS"


def b0_verdict(status: dict[str, str], cand_vendor: set[str], expected_vendor: str) -> str:
    if any(status[k] in ("DIFFERS", "CONFLICT") for k in B0_IDENTITY):
        return "MISMATCH"
    if expected_vendor and cand_vendor and cand_vendor != {expected_vendor}:
        return "MISMATCH"
    if all(status[k] == "MATCH" for k in B0_IDENTITY):
        return "PASS_MATCH"
    if status["ro.vendor.build.fingerprint"] == "MATCH":
        return "PARTIAL"
    return "NOT_RECOVERABLE"


def b0_causality(identity: str, logical_basis: str) -> tuple[str, str]:
    """A8: the causal exclusion rests on the logical argument (same missing components boot on
    C3A/N1F). Without a declared basis it is NOT_FULLY_PROVEN; a vendor mismatch also blocks it."""
    if not logical_basis or identity == "MISMATCH":
        return "NOT_FULLY_PROVEN", "NONE"
    if identity == "PASS_MATCH":
        return "EXCLUDED_AS_PRIMARY_CAUSE", "NONE"
    return "EXCLUDED_AS_PRIMARY_CAUSE", "VENDOR_IDENTITY_UNVERIFIED"


def cmd_b0(args) -> int:
    cand, cand_files = b0_collect(args.candidate)
    ref, ref_files = b0_collect(args.reference)
    status = {k: b0_key_status(cand[k], ref[k]) for k in B0_PROPS}
    cand_vendor = {f.value for f in cand["ro.vendor.build.fingerprint"]}
    identity = b0_verdict(status, cand_vendor, args.expected_vendor_fingerprint)
    causality, qualifier = b0_causality(identity, args.logical_basis)
    out = Output(args.out)
    try:
        rows = []
        for k in B0_PROPS:
            rows.append([k, "IDENTITY" if k in B0_IDENTITY else "CONTEXT_ONLY", status[k],
                         ",".join(sorted({f.value for f in cand[k]})) or "-",
                         ",".join(f.ref for f in cand[k]) or "-",
                         ",".join(sorted({f.value for f in ref[k]})) or "-",
                         ",".join(f.ref for f in ref[k]) or "-"])
        out.tsv("B0_IDENTITY.tsv", ["property", "role", "status", "candidate_values", "candidate_refs",
                                    "reference_values", "reference_refs"], rows)
        out.tsv("B0_INPUTS.tsv", ["side", "path", "sha256"],
                [["candidate", p, s] for p, s in cand_files] + [["reference", p, s] for p, s in ref_files])
        env = [("N1I_B0_TOOL_VERSION", TOOL_VERSION),
               ("N1I_B0_N1F_VENDOR_IDENTITY", identity),
               ("N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY", causality),
               ("N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY_QUALIFIER", qualifier),
               ("N1I_B0_LOGICAL_BASIS_REF", args.logical_basis or "NONE_DECLARED"),
               ("N1I_B0_EXPECTED_VENDOR_FINGERPRINT", args.expected_vendor_fingerprint or "NONE_DECLARED"),
               ("N1I_B0_CANDIDATE_VENDOR_EQUALS_EXPECTED",
                "UNRECOVERED" if not cand_vendor else ("YES" if cand_vendor == {args.expected_vendor_fingerprint} else "NO"))]
        env += [(f"N1I_B0_KEY_{k.upper().replace('.', '_')}", status[k]) for k in B0_PROPS]
        env += [("N1I_B0_DEVICE_CONTACT", "NO")]
        out.env("B0.env", env)
        out.commit()
    except BaseException:
        out.abort()
        raise
    print(f"N1I_B0_N1F_VENDOR_IDENTITY={identity}")
    print(f"N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY={causality}")
    print(f"OUTPUT={args.out.resolve()}")
    return 0


# =============================================================================
# APN — offline packaged-database FACTS, hypotheses kept separate
# =============================================================================
APN_FIELDS = ("carrier", "type", "protocol", "roaming_protocol", "authtype", "bearer_bitmask",
              "network_type_bitmask", "user_visible", "user_editable", "mtu", "max_conns",
              "profile_id", "modem_cognitive", "mmsc", "mmsproxy", "mmsport", "proxy", "port")
# Credentials are reported as presence only; their values are never read into output.
APN_SECRET_FIELDS = ("user", "password")
APN_HYPOTHESIS_CLASSES = ("CONFIGURATION_DIFFERENCE_ONLY", "CARRIERCONFIG_DIFFERENCE",
                          "TELEPHONY_PROVIDER_STATE_DIFFERENCE", "MTK_FRAMEWORK_GENERATED_STATE", "UNRELATED")


@dataclass(frozen=True)
class ApnRow:
    numeric: str
    apn: str
    mvno_type: str
    mvno_match_data_sha256: str   # match data may hold IMSI prefixes / GIDs: hashed, not printed
    carrier_id: str
    fields: tuple

    @property
    def key(self) -> tuple:
        return (self.numeric, self.apn.lower(), self.mvno_type, self.mvno_match_data_sha256, self.carrier_id)

    def field_map(self) -> dict:
        return dict(self.fields)


def parse_apns(path: Path, plmns: set[str]) -> list[ApnRow]:
    text = "\n".join(read_text(path))
    if re.search(r"<!DOCTYPE|<!ENTITY", text, re.I):
        raise InputError(f"DOCTYPE/ENTITY declarations refused in {path}")
    try:
        root = ET.fromstring(text)
    except ET.ParseError as e:
        raise InputError(f"apns XML parse error in {path}: {e}") from e
    rows = []
    for el in root.iter("apn"):
        a = el.attrib
        numeric = (a.get("mcc", "") + a.get("mnc", "")).strip()
        if not re.fullmatch(r"\d{5,6}", numeric):
            raise InputError(f"apn element without valid mcc/mnc in {path}: carrier={a.get('carrier', '?')}")
        if numeric not in plmns:
            continue
        if not a.get("apn"):
            raise InputError(f"apn element without apn attribute in {path} (numeric {numeric})")
        md = a.get("mvno_match_data", "")
        fields = tuple(sorted((k, ",".join(sorted(a.get(k, "").split(","))) if k == "type" else a.get(k, ""))
                              for k in APN_FIELDS))
        fields += tuple((f"{k}_present", "YES" if a.get(k) else "NO") for k in APN_SECRET_FIELDS)
        rows.append(ApnRow(numeric, a["apn"], a.get("mvno_type", ""),
                           hashlib.sha256(md.encode()).hexdigest() if md else "-",
                           a.get("carrier_id", ""), fields))
    keys = [r.key for r in rows]
    dups = {k for k in keys if keys.count(k) > 1}
    if dups:
        raise InputError(f"duplicate APN identity rows in {path}: {sorted(dups)}")
    return rows


def carrier_list_fact(stock: Path | None, c3a: Path | None, plmns: set[str]) -> list[tuple[str, str]]:
    if stock is None and c3a is None:
        return [("N1I_B1_CARRIER_ID_DB_OFFLINE", "NOT_PROVIDED")]
    if stock is None or c3a is None:
        raise InputError("--stock-carrier-list and --c3a-carrier-list must be given together")
    s, c = file_sha256(stock), file_sha256(c3a)
    rows = [("N1I_B1_CARRIER_ID_DB_STOCK_SHA256", s), ("N1I_B1_CARRIER_ID_DB_C3A_SHA256", c)]
    if s == c:
        return rows + [("N1I_B1_CARRIER_ID_DB_OFFLINE", "MATCH_BYTE_IDENTICAL")]

    def ids(path: Path):
        data = path.read_bytes()
        if b"\x00" in data[:4096] or not data.lstrip().startswith((b"carrier_id", b"#", b"version")):
            return None  # binary protobuf: not parsed by this tool
        out = {}
        for block in re.split(r"\n(?=carrier_id\s*\{)", data.decode("utf-8", "replace")):
            m = re.search(r"canonical_id:\s*(\d+)", block)
            for t in re.findall(r'mccmnc_tuple:\s*"(\d+)"', block):
                if m and t in plmns:
                    out.setdefault(t, set()).add(m.group(1))
        return out

    si, ci = ids(stock), ids(c3a)
    if si is None or ci is None:
        return rows + [("N1I_B1_CARRIER_ID_DB_OFFLINE", "DIFFERS_BINARY_NOT_PARSED")]
    rows.append(("N1I_B1_CARRIER_ID_DB_OFFLINE", "DIFFERS_BYTES"))
    for p in sorted(plmns):
        rows.append((f"N1I_B1_CARRIER_ID_{p}_STOCK", ",".join(sorted(si.get(p, set()))) or "NONE"))
        rows.append((f"N1I_B1_CARRIER_ID_{p}_C3A", ",".join(sorted(ci.get(p, set()))) or "NONE"))
    return rows


def cmd_apn(args) -> int:
    plmns = set(args.plmn or ["310240", "310260"])
    for p in plmns:
        if not re.fullmatch(r"\d{5,6}", p):
            raise InputError(f"bad --plmn {p}")
    observed = {}
    for o in args.observed_apn or []:
        m = re.fullmatch(r"(stock|c3a)=([A-Za-z0-9._-]{1,100})", o)
        if not m:
            raise InputError(f"--observed-apn must be stock=APN or c3a=APN, got {o!r}")
        observed.setdefault(m.group(1), set()).add(m.group(2).lower())
    stock = parse_apns(args.stock_apns, plmns)
    c3a = parse_apns(args.c3a_apns, plmns)
    sk, ck = {r.key: r for r in stock}, {r.key: r for r in c3a}
    only_s = sorted(set(sk) - set(ck))
    only_c = sorted(set(ck) - set(sk))
    changed = []
    for k in sorted(set(sk) & set(ck)):
        a, b = sk[k].field_map(), ck[k].field_map()
        diff = sorted(f for f in set(a) | set(b) if a.get(f) != b.get(f))
        if diff:
            changed.append((k, diff))
    ndiff = len(only_s) + len(only_c) + len(changed)

    facts: list[list] = []
    for side, rows in (("stock", stock), ("c3a", c3a)):
        for r in sorted(rows, key=lambda r: r.key):
            fm = r.field_map()
            facts.append([side, r.numeric, r.apn, r.mvno_type or "-", r.mvno_match_data_sha256, r.carrier_id or "-",
                          fm.get("type") or "-", fm.get("protocol") or "-", fm.get("roaming_protocol") or "-",
                          fm.get("user_present"), fm.get("password_present")])
    diffs = ([["ONLY_STOCK", *k, "-"] for k in only_s] + [["ONLY_C3A", *k, "-"] for k in only_c]
             + [["FIELDS_DIFFER", *k, ",".join(d)] for k, d in changed])

    env = [("N1I_B1_APN_TOOL_VERSION", TOOL_VERSION),
           ("N1I_B1_APN_EVIDENCE_KIND", "FACT_OFFLINE_PACKAGED_DATA"),
           ("N1I_B1_APN_PLMNS", ",".join(sorted(plmns))),
           ("N1I_B1_APN_STOCK_DB_SHA256", file_sha256(args.stock_apns)),
           ("N1I_B1_APN_C3A_DB_SHA256", file_sha256(args.c3a_apns)),
           ("N1I_B1_APN_DB_DIFF_OFFLINE", "MATCH" if ndiff == 0 else f"DIFFERS({ndiff})"),
           ("N1I_B1_APN_ROWS_ONLY_STOCK", str(len(only_s))),
           ("N1I_B1_APN_ROWS_ONLY_C3A", str(len(only_c))),
           ("N1I_B1_APN_ROWS_FIELDS_DIFFER", str(len(changed)))]
    for p in sorted(plmns):
        env.append((f"N1I_B1_APN_STOCK_ROWS_{p}", str(sum(1 for r in stock if r.numeric == p))))
        env.append((f"N1I_B1_APN_C3A_ROWS_{p}", str(sum(1 for r in c3a if r.numeric == p))))
    # Facts about runtime-observed APNs supplied by the caller (declared, not measured here).
    obs_facts = []
    for side in ("stock", "c3a"):
        for apn in sorted(observed.get(side, ())):
            for db_side, rows in (("stock", stock), ("c3a", c3a)):
                hits = [r for r in rows if r.apn.lower() == apn]
                key = f"N1I_B1_APN_OBSERVED_{side.upper()}_{re.sub(r'[^A-Z0-9]', '_', apn.upper())}_IN_{db_side.upper()}_DB"
                val = "ABSENT" if not hits else ";".join(
                    f"{r.numeric}/mvno={r.mvno_type or 'none'}" for r in sorted(hits, key=lambda r: r.key))
                obs_facts.append((key, val))
    env += obs_facts
    env += carrier_list_fact(args.stock_carrier_list, args.c3a_carrier_list, plmns)
    env.append(("N1I_B1_APN_DEVICE_CONTACT", "NO"))

    # ---- hypotheses: separate file, never a proven runtime cause
    def observed_apn_differs() -> bool:
        for side in ("stock", "c3a"):
            for apn in observed.get(side, ()):
                in_s = {(r.numeric, r.mvno_type, r.mvno_match_data_sha256) for r in stock if r.apn.lower() == apn}
                in_c = {(r.numeric, r.mvno_type, r.mvno_match_data_sha256) for r in c3a if r.apn.lower() == apn}
                if in_s != in_c:
                    return True
        return False

    cfg = "CANDIDATE_FROM_PACKAGED_DATA" if (ndiff and (observed_apn_differs() or not observed)) else (
        "PACKAGED_DIFFERENCE_NOT_ON_OBSERVED_APNS" if ndiff else "NOT_INDICATED_BY_PACKAGED_DATA")
    hyp = [("N1I_B1_APN_HYPOTHESIS_SOURCE", "OFFLINE_PACKAGED_DATA_ONLY"),
           ("N1I_B1_APN_HYPOTHESIS_RUNTIME_CAUSE_PROVEN", "NO"),
           ("N1I_B1_APN_HYP_CONFIGURATION_DIFFERENCE_ONLY", cfg),
           ("N1I_B1_APN_HYP_CARRIERCONFIG_DIFFERENCE", "NOT_EVALUATED_BY_THIS_TOOL"),
           ("N1I_B1_APN_HYP_TELEPHONY_PROVIDER_STATE_DIFFERENCE", "NOT_ESTABLISHABLE_OFFLINE"),
           ("N1I_B1_APN_HYP_MTK_FRAMEWORK_GENERATED_STATE", "NOT_ESTABLISHABLE_OFFLINE"),
           ("N1I_B1_APN_HYP_UNRELATED", "NOT_ESTABLISHABLE_OFFLINE"),
           ("N1I_B1_APN_OBSERVED_APNS_DECLARED",
            ";".join(f"{s}={a}" for s in sorted(observed) for a in sorted(observed[s])) or "NONE"),
           ("N1I_B1_APN_INITIAL_ATTACH_CLASSIFICATION", "PENDING_RUNTIME_EVIDENCE")]

    out = Output(args.out)
    try:
        out.env("APN_FACTS.env", env)
        out.tsv("APN_FACTS.tsv", ["side", "numeric", "apn", "mvno_type", "mvno_match_data_sha256", "carrier_id",
                                  "type", "protocol", "roaming_protocol", "user_present", "password_present"], facts)
        out.tsv("APN_DIFF.tsv", ["kind", "numeric", "apn", "mvno_type", "mvno_match_data_sha256", "carrier_id",
                                 "differing_fields"], diffs)
        out.env("APN_HYPOTHESES.env", hyp)
        out.commit()
    except BaseException:
        out.abort()
        raise
    print(f"N1I_B1_APN_DB_DIFF_OFFLINE={dict(env)['N1I_B1_APN_DB_DIFF_OFFLINE']}")
    print("N1I_B1_APN_INITIAL_ATTACH_CLASSIFICATION=PENDING_RUNTIME_EVIDENCE")
    print(f"OUTPUT={args.out.resolve()}")
    return 0


# =============================================================================
# TIMELINE — normalization, coverage and pre-registered first-divergence rules
# =============================================================================
I = re.I
APN_VALUE = re.compile(r"\bAPN\b[^A-Za-z0-9\n]{1,4}\"?([A-Za-z0-9][A-Za-z0-9._-]{0,62})", I)
IS_IMS_PDN = re.compile(r"\b(?:apn|apnName|types?)\s*[=:]\s*\[?\"?ims\b", I)
DATA_CALL = re.compile(r"SETUP_DATA_CALL|setupDataCall|onSetupDataCallDone|SetupDataCallResult|"
                       r"DataNetwork\b.*\b(?:connected|disconnected)\b", I)
RAT_VALUE = re.compile(r"\b(?:rat|accessNetwork|radioTech\w*|dataRat)\s*[=:]\s*([A-Za-z0-9_]+)", I)


@dataclass(frozen=True)
class StepRule:
    sid: int
    name: str
    line: str                       # "registration" | "ims"
    match: re.Pattern | None        # None => derived step
    fail: re.Pattern | None = None
    success: re.Pattern | None = None
    values: tuple = ()              # ((label, pattern), ...)
    require_ims: bool | None = None  # True: IMS PDN only, False: non-IMS only


STEP_RULES = (
    StepRule(1, "capability_placement", "registration",
             re.compile(r"\b(?:simswitch|c_capability_slot|main[_ ]?(?:protocol|capability)\w*|mainCapabilityPhoneId|"
                        r"mPhoneIdForMainProtocol|getMainCapabilityPhoneId)\b", I),
             fail=re.compile(r"\b(?:fail\w*|error|timeout)\b", I),
             values=(("main_sim", re.compile(r"(?:simswitch|c_capability_slot|main[_ ]?(?:protocol|capability)\w*|"
                                             r"mainCapabilityPhoneId|mPhoneIdForMainProtocol)\]?\W{0,4}\[?(\d)\b", I)),)),
    StepRule(2, "set_radio_capability", "registration",
             re.compile(r"SET_RADIO_CAPABILITY|setRadioCapability|RADIO_CAPABILITY|onSetRadioCapability", I),
             fail=re.compile(r"\b(?:fail\w*|error|abort\w*)\b", I),
             success=re.compile(r"\bsuccess\w*\b", I)),
    StepRule(3, "initial_attach_apn", "registration",
             re.compile(r"setInitialAttachApn|SET_INITIAL_ATTACH|IA MD Preferred APN|EIAAPN|initial ?attach", I),
             fail=re.compile(r"\b(?:fail\w*|error)\b", I),
             values=(("apn", APN_VALUE),)),
    StepRule(4, "default_data_setup", "registration", DATA_CALL,
             fail=re.compile(r"\bERROR_\w+|\bfail(?:ed|ure)?\b|\bcause\s*[=:]\s*(?!NONE\b|0\b)\w+|\bDISCONNECTED\b", I),
             success=re.compile(r"\bCONNECTED\b|\bcause\s*[=:]\s*(?:NONE|0)\b|\bSUCCESS\b", I),
             values=(("apn", APN_VALUE), ("rat", RAT_VALUE)), require_ims=False),
    StepRule(5, "ims_pdn_setup", "ims", DATA_CALL,
             fail=re.compile(r"\bERROR_\w+|\bfail(?:ed|ure)?\b|\bcause\s*[=:]\s*(?!NONE\b|0\b)\w+|\bDISCONNECTED\b", I),
             success=re.compile(r"\bCONNECTED\b|\bcause\s*[=:]\s*(?:NONE|0)\b|\bSUCCESS\b", I),
             values=(("apn", APN_VALUE),), require_ims=True),
    StepRule(6, "ims_provider_bind", "ims",
             re.compile(r"ImsResolver|ImsServiceController|bindImsService|ImsServiceConnection|get-ims-service", I),
             fail=re.compile(r"not found|\bnull\b|unable|\bfail\w*|could not|\bunbind\w*|\bdied\b", I),
             success=re.compile(r"\bbound\b|onServiceConnected|\bconnected\b", I),
             values=(("package", re.compile(r"\b(com\.[a-z0-9_.]*ims[a-z0-9_.]*)", I)),)),
    StepRule(7, "mmtel_feature", "ims",
             re.compile(r"MmTelFeature|\bMMTEL\b|createMmTelFeature|FEATURE_MMTEL|ImsFeature", I),
             fail=re.compile(r"UNAVAILABLE|\bfail\w*|\bnull\b", I),
             success=re.compile(r"STATE_READY|\bREADY\b", I),
             values=(("feature_state", re.compile(r"\b(STATE_(?:READY|UNAVAILABLE|INITIALIZING))\b")),)),
    StepRule(8, "vendor_volte_daemon", "ims",
             re.compile(r"\bvolte_(?:ua|imcb|stack|clientapi|imsm|imsvt)\b|\bvendor\.volte\b", I),
             fail=re.compile(r"\bdied\b|\bcrash\w*|\bexit\w*|\bfail\w*|\bkilled\b|\brestart\w*", I),
             success=re.compile(r"\bstart(?:ed|ing)?\b|\brunning\b", I)),
    StepRule(9, "ims_registration_request", "ims",
             re.compile(r"onRegistering|\bREGISTERING\b|triggerImsRegistration|register request|\bIMS_REG_REQ", I),
             fail=re.compile(r"\bfail\w*", I)),
    StepRule(10, "ims_registration_state", "ims",
             re.compile(r"onRegistered\b|onDeregistered|onRegistrationFailed|IMS_REGISTERED|NOT_REGISTERED|"
                        r"\bDEREGISTERED\b|registration failed|\bCIREGU\b", I),
             fail=re.compile(r"NOT_REGISTERED|onDeregistered|\bDEREGISTERED\b|onRegistrationFailed|registration failed|"
                             r"\bfail\w*", I),
             success=re.compile(r"onRegistered\b|IMS_REGISTERED|(?<![A-Z_])REGISTERED\b")),
    StepRule(11, "rejection_causes", "registration",
             re.compile(r"rejectCause|reasonForDenial|REG_DENIED|registration denied|ERROR_UNSPECIFIED|"
                        r"ROAMING_NOT_ALLOWED|PLMN_NOT_ALLOWED|reject cause", I)),
    StepRule(12, "recovery_to_service", "registration", None),
    StepRule(13, "ims_reregistration", "ims", None),
)
RULE = {r.sid: r for r in STEP_RULES}
REG_STEPS = tuple(r.sid for r in STEP_RULES if r.line == "registration")
IMS_STEPS = tuple(r.sid for r in STEP_RULES if r.line == "ims")
ORDER_EXEMPT = {11, 12, 13}       # rejections can occur anywhere; 12/13 are derived
KEYED_STEPS = {1, 3, 4, 5, 7}     # A4 key values: capability main_sim, APN, RAT, IMS feature state
CAUSE_NUM = re.compile(r"(?:rejectCause|reasonForDenial|reject\s*cause|mRejectCause)\s*[=:]?\s*(\d{1,3})\b", I)
CAUSE_TOKEN = re.compile(r"\b(ERROR_UNSPECIFIED|ROAMING_NOT_ALLOWED|PLMN_NOT_ALLOWED|REG_DENIED)\b")
HOME_SERVICE = re.compile(r"mDataRegState=0\(IN_SERVICE\)|\bDataRegState\W+IN_SERVICE\b|\bREG_HOME\b|"
                          r"\bREGISTERED_HOME\b|\bregState\s*[=:]\s*(?:1|HOME)\b", I)
COLLAPSE_CAUSES = {"11", "13", "15"}
RECOVERY_WINDOW_SEC = 120         # A3
TS_YEAR = re.compile(r"^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})\.(\d{3})")
TS_NOYEAR = re.compile(r"^(\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})\.(\d{3})")


@dataclass
class Event:
    step: int
    utc: dt.datetime | None
    outcome: str                      # SUCCESS | FAIL | OBSERVED
    values: tuple
    ref: str
    sha: str
    seq: int = 0


@dataclass
class Run:
    side: str
    tray: str
    label: str
    paths: list
    tz: dt.timezone
    year: int | None
    files: list = field(default_factory=list)      # (path, sha256, lines)
    events: list = field(default_factory=list)
    home: list = field(default_factory=list)       # utc of home-service evidence
    untimed: int = 0
    first: dt.datetime | None = None
    last: dt.datetime | None = None


def parse_run_spec(spec: str) -> Run:
    kv = {}
    for part in spec.split(","):
        if "=" not in part:
            raise InputError(f"--run entries are k=v pairs separated by commas: {spec!r}")
        k, v = part.split("=", 1)
        kv[k.strip()] = v.strip()
    unknown = set(kv) - {"side", "tray", "label", "path", "tz", "year"}
    if unknown:
        raise InputError(f"unknown --run keys {sorted(unknown)}")
    if kv.get("side") not in ("stock", "c3a"):
        raise InputError(f"--run side must be stock or c3a: {spec!r}")
    if kv.get("tray") not in ("1", "2"):
        raise InputError(f"--run tray must be 1 or 2: {spec!r}")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", kv.get("label", "")):
        raise InputError(f"--run label invalid: {spec!r}")
    tzs = kv.get("tz", "+0000")
    m = re.fullmatch(r"([+-])(\d{2})(\d{2})", tzs)
    if not m:
        raise InputError(f"--run tz must be +HHMM/-HHMM: {spec!r}")
    off = dt.timedelta(hours=int(m.group(2)), minutes=int(m.group(3)))
    tz = dt.timezone(off if m.group(1) == "+" else -off)
    year = kv.get("year")
    if year is not None and not re.fullmatch(r"20\d{2}", year):
        raise InputError(f"--run year invalid: {spec!r}")
    p = Path(kv.get("path", ""))
    if not p.exists():
        raise InputError(f"--run path missing: {p}")
    paths = sorted(x for x in p.rglob("*") if x.is_file()) if p.is_dir() else [p]
    if not paths:
        raise InputError(f"--run path has no files: {p}")
    return Run(kv["side"], kv["tray"], kv["label"], paths, tz, int(year) if year else None)


def parse_ts(line: str, run: Run) -> dt.datetime | None:
    m = TS_YEAR.match(line)
    if m:
        s = f"{m.group(1)} {m.group(2)}.{m.group(3)}"
    else:
        m = TS_NOYEAR.match(line)
        if not m:
            return None
        if run.year is None:
            raise InputError(f"run {run.label}: logcat lines without year need year= in --run")
        s = f"{run.year}-{m.group(1)} {m.group(2)}.{m.group(3)}"
    try:
        return dt.datetime.strptime(s, "%Y-%m-%d %H:%M:%S.%f").replace(tzinfo=run.tz).astimezone(dt.timezone.utc)
    except ValueError:
        return None


def classify_line(line: str) -> list[tuple[int, str, tuple]]:
    """Return (step, outcome, values) for every non-derived step rule the line matches."""
    hits = []
    for r in STEP_RULES:
        if r.match is None or not r.match.search(line):
            continue
        if r.require_ims is not None and bool(IS_IMS_PDN.search(line)) != r.require_ims:
            continue
        if r.sid == 11:
            causes = {c for c in CAUSE_NUM.findall(line) if int(c) != 0} | set(CAUSE_TOKEN.findall(line))
            if not causes:
                continue
            hits.append((11, "FAIL", tuple(sorted(f"cause:{c}" for c in causes))))
            continue
        if r.fail is not None and r.fail.search(line):
            outcome = "FAIL"
        elif r.success is not None and r.success.search(line):
            outcome = "SUCCESS"
        else:
            outcome = "OBSERVED"
        vals = []
        for label, rx in r.values:
            for v in rx.findall(line):
                vals.append(f"{label}:{v.lower() if label == 'apn' else v}")
        hits.append((r.sid, outcome, tuple(sorted(set(vals)))))
    return hits


def load_run(run: Run) -> None:
    seen = set()
    raw_events = []
    order = 0
    for path in run.paths:
        lines = read_text(path)
        run.files.append((str(path), file_sha256(path), len(lines)))
        for no, line in enumerate(lines, 1):
            if line.startswith("#") or not line.strip():
                continue
            ts = parse_ts(line, run)
            hits = classify_line(line)
            home = bool(HOME_SERVICE.search(line))
            if not hits and not home:
                continue
            sha = sanitized_sha256(line)
            if (ts, sha) in seen:          # overlapping buffers / stitched segments
                continue
            seen.add((ts, sha))
            if ts is not None:
                run.first = ts if run.first is None or ts < run.first else run.first
                run.last = ts if run.last is None or ts > run.last else run.last
            if home and ts is not None:
                run.home.append(ts)
            order += 1
            for sid, outcome, vals in hits:
                raw_events.append((ts, order, Event(sid, ts, outcome, vals, f"{path}:{no}", sha)))
    timed = [e for e in raw_events if e[0] is not None]
    if timed:
        run.untimed = sum(1 for e in raw_events if e[0] is None)
        raw_events = sorted(timed, key=lambda e: (e[0], e[1]))
    else:
        raw_events = sorted(raw_events, key=lambda e: e[1])
    for i, (_, _, ev) in enumerate(raw_events, 1):
        ev.seq = i
        run.events.append(ev)
    run.home.sort()


@dataclass
class StepSummary:
    outcome: str                     # SUCCESS FAIL OBSERVED ABSENT | 12: NOT_APPLICABLE UNKNOWN
    values: frozenset
    first_seq: int | None
    refs: tuple                      # ((ref, sha), ...) first few


def rejection_episodes(run: Run) -> list[dict]:
    """Group rejection events into sequences (A3) and test recovery to home service."""
    rej = [e for e in run.events if e.step == 11]
    if not rej:
        return []
    if any(e.utc is None for e in rej):
        return [{"events": rej, "result": "UNKNOWN", "causes": set().union(*[set(e.values) for e in rej])}]
    episodes, cur = [], []
    for e in rej:
        if cur:
            gap = (e.utc - cur[-1].utc).total_seconds()
            home_between = any(cur[-1].utc < h < e.utc for h in run.home)
            if gap > RECOVERY_WINDOW_SEC or home_between:
                episodes.append(cur)
                cur = []
        cur.append(e)
    episodes.append(cur)
    out = []
    for ep in episodes:
        t = ep[-1].utc
        end = t + dt.timedelta(seconds=RECOVERY_WINDOW_SEC)
        if any(t < h <= end for h in run.home):
            res = "RECOVERED"
        elif run.last is not None and run.last >= end:
            res = "NO_RECOVERY"
        else:
            res = "UNKNOWN"
        out.append({"events": ep, "result": res, "causes": set().union(*[set(e.values) for e in ep])})
    return out


def summarize(run: Run) -> dict[int, StepSummary]:
    s: dict[int, StepSummary] = {}
    for r in STEP_RULES:
        if r.match is None:
            continue
        evs = [e for e in run.events if e.step == r.sid]
        if not evs:
            s[r.sid] = StepSummary("ABSENT", frozenset(), None, ())
            continue
        outs = {e.outcome for e in evs}
        outcome = "SUCCESS" if "SUCCESS" in outs else "FAIL" if "FAIL" in outs else "OBSERVED"
        vals = frozenset(v for e in evs for v in e.values)
        s[r.sid] = StepSummary(outcome, vals, evs[0].seq, tuple((e.ref, e.sha) for e in evs[:3]))
    eps = rejection_episodes(run)
    if not eps:
        s[12] = StepSummary("NOT_APPLICABLE", frozenset(), None, ())
    else:
        results = [e["result"] for e in eps]
        outcome = "FAIL" if "NO_RECOVERY" in results else "UNKNOWN" if "UNKNOWN" in results else "SUCCESS"
        first_bad = next((e for e in eps if e["result"] != "RECOVERED"), eps[0])
        s[12] = StepSummary(outcome, frozenset(f"{k}:{results.count(k)}" for k in set(results)),
                            first_bad["events"][0].seq,
                            tuple((e.ref, e.sha) for e in first_bad["events"][:3]))
    reg = [e for e in run.events if e.step == 10]
    succ = [e for e in reg if e.outcome == "SUCCESS"]
    if not succ:
        s[13] = StepSummary("ABSENT", frozenset(), None, ())
    else:
        after = [e for e in reg if e.seq > succ[0].seq]
        last_fail = max((e.seq for e in after if e.outcome == "FAIL"), default=None)
        last_succ = max((e.seq for e in after if e.outcome == "SUCCESS"), default=None)
        if last_fail is not None and (last_succ is None or last_succ < last_fail):
            outcome = "FAIL"
        elif len(succ) >= 2:
            outcome = "SUCCESS"
        else:
            outcome = "OBSERVED"
        s[13] = StepSummary(outcome, frozenset({f"registrations:{len(succ)}"}), succ[0].seq,
                            tuple((e.ref, e.sha) for e in (after or succ)[:3]))
    return s


def collapse_in_run(run: Run) -> bool:
    return any(e["result"] == "NO_RECOVERY" and {f"cause:{c}" for c in COLLAPSE_CAUSES} & e["causes"]
               for e in rejection_episodes(run))


def _preds(summ: dict[int, StepSummary], sid: int, common: set[int]) -> set[int]:
    me = summ[sid].first_seq
    return {k for k in common if summ[k].first_seq is not None and summ[k].first_seq < me}


def diverges_from(c: dict[int, StepSummary], r: dict[int, StepSummary], sid: int) -> str | None:
    """Pre-registered A4 rule for one step against ONE stock run. None = consistent with that run."""
    cs, rs = c[sid], r[sid]
    if sid == 11:
        return "NEW_REJECTION_CAUSES" if cs.values - rs.values else None
    if sid == 12:
        if rs.outcome in ("SUCCESS", "NOT_APPLICABLE"):
            if cs.outcome == "FAIL":
                return "NO_RECOVERY"
            if cs.outcome == "UNKNOWN":
                return "INDETERMINATE"
        return None
    if sid == 13:
        if cs.outcome == "ABSENT" and rs.outcome != "ABSENT":
            return "ABSENCE"
        if cs.outcome == "FAIL" and rs.outcome in ("SUCCESS", "OBSERVED"):
            return "OUTCOME"
        return None
    if cs.outcome == "ABSENT":
        return "ABSENCE" if rs.outcome != "ABSENT" else None
    if rs.outcome == "ABSENT":
        return "OUTCOME" if cs.outcome == "FAIL" else None
    if {cs.outcome, rs.outcome} == {"SUCCESS", "FAIL"}:
        return "OUTCOME"
    if sid in KEYED_STEPS and cs.values and rs.values and not cs.values <= rs.values:
        return "KEY_VALUE"
    if sid not in ORDER_EXEMPT:
        common = {k for k in c if k not in ORDER_EXEMPT and k != sid
                  and c[k].first_seq is not None and r[k].first_seq is not None}
        if _preds(c, sid, common) != _preds(r, sid, common):
            return "ORDER"
    return None


@dataclass
class Candidate:
    sid: int
    kind: str          # CONCRETE | ABSENCE | INDETERMINATE
    bases: dict        # stock label -> basis


def line_candidates(c: dict[int, StepSummary], stocks: list[tuple[str, dict]], steps: tuple) -> list[Candidate]:
    out = []
    for sid in steps:
        bases = {label: diverges_from(c, summ, sid) for label, summ in stocks}
        if not bases or any(b is None for b in bases.values()):
            continue    # consistent with at least one stock run: within stock's normal behaviour
        kinds = set(bases.values())
        kind = "ABSENCE" if kinds == {"ABSENCE"} else "INDETERMINATE" if "INDETERMINATE" in kinds else "CONCRETE"
        out.append(Candidate(sid, kind, bases))
    return out


def line_verdict(cands: list[Candidate], has_stock: bool, has_events: bool) -> tuple[str, str]:
    if not has_stock:
        return "STOP", "NO_STOCK_CONTROL_FOR_TRAY"
    if not has_events:
        return "STOP", "NO_EVENTS_IN_RETAINED_EVIDENCE"
    if not cands:
        return "STOP", "NO_DIVERGENCE_FOUND"
    first = cands[0]
    if first.kind == "ABSENCE":
        return "STOP", f"EARLIEST_CANDIDATE_STEP_{first.sid}_NOT_IN_RETAINED_EVIDENCE"
    if first.kind == "INDETERMINATE":
        return "STOP", f"EARLIEST_CANDIDATE_STEP_{first.sid}_INDETERMINATE"
    return f"{first.sid}:{RULE[first.sid].name}", "SELECTED_FIRST_CONCRETE_CANDIDATE"


def combine(results: list[tuple[str, str, str]]) -> tuple[str, str]:
    """results: (c3a label, verdict, reason). Any STOP or disagreement => STOP (fail closed)."""
    if not results:
        return "STOP", "NO_C3A_RUN"
    stops = [f"{l}:{r}" for l, v, r in results if v == "STOP"]
    if stops:
        return "STOP", ";".join(stops)
    verdicts = {v for _, v, _ in results}
    if len(verdicts) > 1:
        return "STOP", "INCONSISTENT_ACROSS_C3A_RUNS:" + ";".join(f"{l}={v}" for l, v, _ in results)
    return verdicts.pop(), "CONSISTENT_ACROSS_C3A_RUNS"


def iso(t: dt.datetime | None) -> str:
    return t.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z" if t else "-"


def rules_rows() -> list[list]:
    rows = []
    for r in STEP_RULES:
        rows.append([r.sid, r.name, r.line, r.match.pattern if r.match else "DERIVED",
                     r.fail.pattern if r.fail else "-", r.success.pattern if r.success else "-",
                     ";".join(f"{l}={p.pattern}" for l, p in r.values) or "-",
                     {True: "IMS_PDN_ONLY", False: "NON_IMS_ONLY", None: "-"}[r.require_ims]])
    rows.append(["-", "constants", "-", f"RECOVERY_WINDOW_SEC={RECOVERY_WINDOW_SEC}",
                 f"COLLAPSE_CAUSES={','.join(sorted(COLLAPSE_CAUSES))}", f"HOME_SERVICE={HOME_SERVICE.pattern}",
                 f"KEYED_STEPS={sorted(KEYED_STEPS)}", f"ORDER_EXEMPT={sorted(ORDER_EXEMPT)}"])
    return rows


def cmd_timeline(args) -> int:
    runs = [parse_run_spec(s) for s in args.run]
    labels = [r.label for r in runs]
    if len(set(labels)) != len(labels):
        raise InputError("duplicate --run label")
    for r in runs:
        load_run(r)
    summ = {r.label: summarize(r) for r in runs}
    stock = [r for r in runs if r.side == "stock"]
    c3a = [r for r in runs if r.side == "c3a"]
    if not c3a:
        raise InputError("timeline needs at least one c3a run")

    div_rows, per_line = [], {"registration": [], "ims": []}
    for cr in c3a:
        stocks = [(s.label, summ[s.label]) for s in stock if s.tray == cr.tray]
        for line, steps in (("registration", REG_STEPS), ("ims", IMS_STEPS)):
            cands = line_candidates(summ[cr.label], stocks, steps) if stocks else []
            verdict, reason = line_verdict(cands, bool(stocks), bool(cr.events))
            per_line[line].append((cr.label, verdict, reason, cr.tray))
            for rank, cd in enumerate(cands, 1):
                cs = summ[cr.label][cd.sid]
                stock_refs = ";".join(f"{lab}:{summ[lab][cd.sid].refs[0][0]}" if summ[lab][cd.sid].refs else f"{lab}:-"
                                      for lab, _ in stocks)
                div_rows.append([cr.label, cr.tray, line, rank, "TOP3" if rank <= 3 else "-", cd.sid, RULE[cd.sid].name,
                                 cd.kind, ";".join(f"{k}={v}" for k, v in sorted(cd.bases.items())),
                                 cs.outcome, ",".join(sorted(cs.values)) or "-",
                                 cs.refs[0][0] if cs.refs else "-", cs.refs[0][1] if cs.refs else "-", stock_refs])

    reg_v, reg_r = combine([(l, v, r) for l, v, r, _ in per_line["registration"]])
    ims_v, ims_r = combine([(l, v, r) for l, v, r, _ in per_line["ims"]])
    collapse_runs = [r.label for r in c3a if collapse_in_run(r)]
    ia = {side: sorted({v.split(":", 1)[1] for r in runs if r.side == side for e in r.events if e.step == 3
                        for v in e.values if v.startswith("apn:")}) for side in ("stock", "c3a")}
    stop = "STOP" in (reg_v, ims_v)

    env = [("N1I_B1_TIMELINE_TOOL_VERSION", TOOL_VERSION),
           ("N1I_B1_TIMELINE_EVIDENCE_KIND", "RETAINED_EVIDENCE_OFFLINE"),
           ("N1I_B1_STOCK_TRAY1_RUNS", str(sum(1 for r in stock if r.tray == "1"))),
           ("N1I_B1_STOCK_TRAY2_RUNS", str(sum(1 for r in stock if r.tray == "2"))),
           ("N1I_B1_C3A_RUNS", str(len(c3a))),
           ("N1I_B1_REGISTRATION_FIRST_DIVERGENCE", reg_v),
           ("N1I_B1_REGISTRATION_FIRST_DIVERGENCE_REASON", reg_r),
           ("N1I_B1_IMS_FIRST_DIVERGENCE", ims_v),
           ("N1I_B1_IMS_FIRST_DIVERGENCE_REASON", ims_r),
           ("N1I_B1_COLLAPSE_RUNS", f"{len(collapse_runs)}/{len(c3a)}"),
           ("N1I_B1_REGISTRATION_COLLAPSE_REPRODUCED", "YES" if len(collapse_runs) >= 2 else "NO"),
           ("N1I_B1_INITIAL_ATTACH_APN_STOCK", ",".join(ia["stock"]) or "NOT_IN_RETAINED_EVIDENCE"),
           ("N1I_B1_INITIAL_ATTACH_APN_C3A", ",".join(ia["c3a"]) or "NOT_IN_RETAINED_EVIDENCE"),
           ("N1I_B1_APN_INITIAL_ATTACH_CLASSIFICATION", "PENDING_RUNTIME_EVIDENCE"),
           ("N1I_B1_TIMELINE_STOP", "YES" if stop else "NO"),
           ("N1I_B1_NEXT_ACTION", "STOP_AND_REPORT_NO_AUTOMATIC_FLASH" if stop else "REVIEW_DIVERGENCE_BEFORE_ANY_DECISION"),
           ("N1I_B1_FLASH_RECOMMENDED", "NO"),
           ("N1I_B1_ROOT_CAUSE_CONCLUDED", "NO"),
           ("N1I_B1_DECISION_GATE", "NOT_COMPUTED_REQUIRES_B2"),
           ("N1I_B1_DSDS_COVERED", "NO"),
           ("N1I_B1_DEVICE_CONTACT", "NO")]
    for line in ("registration", "ims"):
        for lab, v, r, tray in per_line[line]:
            env.append((f"N1I_B1_{line.upper()}_DIVERGENCE_RUN_{lab}", f"tray{tray}:{v}:{r}"))

    out = Output(args.out)
    try:
        out.env("TIMELINE_SUMMARY.env", env)
        out.tsv("RULES.tsv", ["step", "name", "line", "match", "fail", "success", "values", "pdn_filter"], rules_rows())
        out.tsv("INPUTS.tsv", ["run", "path", "sha256", "lines"],
                [[r.label, p, s, n] for r in runs for p, s, n in r.files])
        out.tsv("RUNS.tsv", ["run", "side", "tray", "files", "events", "first_utc", "last_utc", "span_sec",
                             "untimed_events_dropped", "home_service_evidence", "collapse"],
                [[r.label, r.side, r.tray, len(r.files), len(r.events), iso(r.first), iso(r.last),
                  int((r.last - r.first).total_seconds()) if r.first and r.last else "-", r.untimed, len(r.home),
                  "YES" if r.side == "c3a" and collapse_in_run(r) else ("NO" if r.side == "c3a" else "-")]
                 for r in runs])
        cov = []
        for r in runs:
            for st in STEP_RULES:
                ss = summ[r.label][st.sid]
                n = sum(1 for e in r.events if e.step == st.sid)
                status = ("DERIVED" if st.match is None else "OBSERVED" if n else "NOT_IN_RETAINED_EVIDENCE")
                cov.append([r.label, r.side, r.tray, st.sid, st.name, st.line, n, status, ss.outcome,
                            SAN.sanitize_strict(",".join(sorted(ss.values))) or "-", ss.refs[0][0] if ss.refs else "-"])
        out.tsv("COVERAGE.tsv", ["run", "side", "tray", "step", "name", "line", "events", "coverage", "outcome",
                                 "values", "first_ref"], cov)
        out.tsv("TIMELINE.tsv", ["run", "side", "tray", "seq", "step", "step_name", "utc", "outcome", "values",
                                 "source", "sanitized_line_sha256"],
                [[r.label, r.side, r.tray, e.seq, e.step, RULE[e.step].name, iso(e.utc), e.outcome,
                  SAN.sanitize_strict(",".join(e.values)) or "-", e.ref, e.sha] for r in runs for e in r.events])
        out.tsv("DIVERGENCE.tsv", ["c3a_run", "tray", "line", "rank", "top3", "step", "step_name", "kind",
                                   "basis_per_stock_run", "c3a_outcome", "c3a_values", "c3a_ref",
                                   "c3a_sanitized_line_sha256", "stock_refs"], div_rows)
        out.commit()
    except BaseException:
        out.abort()
        raise
    print(f"N1I_B1_REGISTRATION_FIRST_DIVERGENCE={reg_v}")
    print(f"N1I_B1_IMS_FIRST_DIVERGENCE={ims_v}")
    print(f"N1I_B1_TIMELINE_STOP={'YES' if stop else 'NO'}")
    print(f"OUTPUT={args.out.resolve()}")
    return 0


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    b0 = sub.add_parser("b0", help="historical vendor identity reconciliation")
    b0.add_argument("--candidate", type=Path, action="append", required=True,
                    help="N1F/C3A successful-boot evidence file (repeatable)")
    b0.add_argument("--reference", type=Path, action="append", required=True,
                    help="N1D pre-flash evidence file (repeatable)")
    b0.add_argument("--expected-vendor-fingerprint", default="")
    b0.add_argument("--logical-basis", default="",
                    help="reference to the evidence that the same component set booted on C3A/N1F")
    b0.add_argument("--out", type=Path, required=True)
    ap = sub.add_parser("apn", help="offline APN / carrier-ID facts")
    ap.add_argument("--stock-apns", type=Path, required=True)
    ap.add_argument("--c3a-apns", type=Path, required=True)
    ap.add_argument("--stock-carrier-list", type=Path)
    ap.add_argument("--c3a-carrier-list", type=Path)
    ap.add_argument("--plmn", action="append")
    ap.add_argument("--observed-apn", action="append", help="declared runtime observation: stock=APN | c3a=APN")
    ap.add_argument("--out", type=Path, required=True)
    tl = sub.add_parser("timeline", help="normalize retained logs, coverage, first divergence")
    tl.add_argument("--run", action="append", required=True,
                    help="side=stock|c3a,tray=1|2,label=L,path=FILE_OR_DIR[,tz=+HHMM][,year=YYYY]")
    tl.add_argument("--out", type=Path, required=True)
    args = p.parse_args(argv)
    try:
        return {"b0": cmd_b0, "apn": cmd_apn, "timeline": cmd_timeline}[args.cmd](args)
    except InputError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
