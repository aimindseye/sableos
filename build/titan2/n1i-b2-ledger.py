#!/usr/bin/env python3
"""Titan 2 N1I-B2 dependency ledger and evidence coverage matrix.

Offline aggregation only. This tool consumes the outputs of:
  - n1i-b2-members.py stock resolve, C3A resolve and compare
  - n1i-b2-native.py stock and C3A derive
  - n1i-b2-census.py reverse vendor->system census

It does not discover new dependencies, import any component, mutate source, contact a
device or authorize a B3 experiment. Its job is to preserve evidence strength, reject
inconsistent upstream outputs, and make remaining coverage gaps explicit.

Outputs:
  DEPENDENCY_LEDGER.tsv
  COVERAGE_MATRIX.tsv
  LEDGER_SUMMARY.env

Exit codes: 0 completed; 2 invalid or inconsistent input (nothing written).
"""
from __future__ import annotations

import argparse
import csv
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

TOOL_VERSION = "1.0.0"

MEMBER_RESULTS = {
    "RESOLVED",
    "CLASS_MISSING",
    "METHOD_MISSING",
    "FIELD_MISSING",
    "DESCRIPTOR_MISMATCH",
    "STATIC_INSTANCE_MISMATCH",
    "ACCESS_VIOLATION",
    "ICCE_KIND",
}
CENSUS_STATUSES = {
    "VENDOR_SELF_PROVIDED",
    "NO_SYSTEM_PRODUCER_ON_STOCK",
    "SATISFIED_ON_C3A",
    "MISSING_ON_C3A_OPTIONAL",
    "MISSING_ON_C3A_STRING_ONLY_CANDIDATE",
    "MISSING_ON_C3A_CANDIDATE",
    "MISSING_ON_C3A_RUNTIME_CONFIRMED",
    "MTK_SYSTEM_EDGE_PROVEN",
}
NATIVE_STATUSES = {
    "FOUND",
    "NOT_FOUND",
    "WRONG_ABI",
    "FILE_PRESENT_NAMESPACE_UNPROVEN",
}


class InputError(Exception):
    pass


@dataclass(frozen=True)
class LedgerRow:
    ledger_id: str
    domain: str
    component_kind: str
    name: str
    status: str
    evidence_strength: str
    stock_evidence: str
    c3a_evidence: str
    note: str


@dataclass(frozen=True)
class Coverage:
    area: str
    state: str
    critical: str
    detail: str


def clean(value: object) -> str:
    return str(value).replace("\t", " ").replace("\n", " ")


def env_file(path: Path, required: set[str]) -> dict[str, str]:
    if not path.is_file():
        raise InputError(f"missing summary {path}")
    out: dict[str, str] = {}
    for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise InputError(f"{path}:{no}: expected KEY=VALUE")
        key, value = line.split("=", 1)
        if key in out:
            raise InputError(f"{path}:{no}: duplicate key {key}")
        out[key] = value
    missing = sorted(required - set(out))
    if missing:
        raise InputError(f"{path}: missing keys {missing}")
    return out


def int_value(env: dict[str, str], key: str) -> int:
    try:
        value = int(env[key])
    except (KeyError, ValueError) as exc:
        raise InputError(f"{key}: expected integer") from exc
    if value < 0:
        raise InputError(f"{key}: negative count")
    return value


def tsv(path: Path, required: set[str], unique: str | None = None) -> list[dict[str, str]]:
    if not path.is_file():
        raise InputError(f"missing table {path}")
    with path.open(encoding="utf-8", newline="") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        if reader.fieldnames is None:
            raise InputError(f"{path}: missing header")
        missing = sorted(required - set(reader.fieldnames))
        if missing:
            raise InputError(f"{path}: missing columns {missing}")
        rows = list(reader)
    if unique is not None:
        seen: set[str] = set()
        for row in rows:
            value = row[unique]
            if value in seen:
                raise InputError(f"{path}: duplicate {unique} {value}")
            seen.add(value)
    return rows


def require_sha(value: str, label: str) -> None:
    if len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
        raise InputError(f"{label}: expected lowercase SHA-256")


def comma_values(value: str) -> list[str]:
    return [] if value in ("", "NONE", "NOT_PROVIDED") else [x for x in value.split(",") if x]


def coverage(area: str, ok: bool, critical: bool, detail: str) -> Coverage:
    return Coverage(area, "PASS" if ok else "GAP", "YES" if critical else "NO", detail)


def member_rows(stock: Path, c3a: Path, compare: Path) -> tuple[list[LedgerRow], list[Coverage], str]:
    req = {
        "N1I_B2_MEMBERS_APP_SHA256",
        "N1I_B2_MEMBERS_DEXDUMP_ORACLE",
        "N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE",
        "N1I_B2_MEMBERS_UNRESOLVED",
    }
    se = env_file(stock / "MEMBERS_SUMMARY.env", req)
    ce = env_file(c3a / "MEMBERS_SUMMARY.env", req)
    me = env_file(
        compare / "MEMBERS_COMPARE.env",
        {
            "N1I_B2_MEMBERS_COMPARE_APP_SHA256",
            "N1I_B2_MEMBERS_GAP_IS_IMPORT_AUTHORIZATION",
            "N1I_B2_CORE_AOSP_BINARY_IMPORT_AUTHORIZED",
        },
    )
    hashes = {
        se["N1I_B2_MEMBERS_APP_SHA256"],
        ce["N1I_B2_MEMBERS_APP_SHA256"],
        me["N1I_B2_MEMBERS_COMPARE_APP_SHA256"],
    }
    if len(hashes) != 1:
        raise InputError("member outputs refer to different APK bytes")
    app_sha = next(iter(hashes))
    require_sha(app_sha, "member APK SHA-256")
    if me["N1I_B2_MEMBERS_GAP_IS_IMPORT_AUTHORIZATION"] != "NO":
        raise InputError("member compare attempts to authorize import")
    if me["N1I_B2_CORE_AOSP_BINARY_IMPORT_AUTHORIZED"] != "NO":
        raise InputError("member compare authorizes core AOSP binary import")

    rows = tsv(
        compare / "BEHAVIOR_GAP_CANDIDATES.tsv",
        {
            "caller",
            "ref_kind",
            "owner",
            "name",
            "descriptor",
            "stock_result",
            "c3a_result",
            "comparison",
            "candidate_class",
            "stock_provider",
            "c3a_detail",
        },
    )
    out: list[LedgerRow] = []
    seen: set[str] = set()
    for row in rows:
        if row["stock_result"] not in MEMBER_RESULTS and row["stock_result"] != "NOT_REFERENCED":
            raise InputError(f"unknown member stock result {row['stock_result']}")
        if row["c3a_result"] not in MEMBER_RESULTS and row["c3a_result"] != "NOT_REFERENCED":
            raise InputError(f"unknown member C3A result {row['c3a_result']}")
        if row["comparison"] != "STOCK_ONLY_RESOLVES":
            continue
        if row["stock_result"] != "RESOLVED" or row["c3a_result"] in ("RESOLVED", "NOT_REFERENCED"):
            raise InputError("invalid STOCK_ONLY_RESOLVES member row")
        if row["candidate_class"] != "AOSP_EQUIVALENT_WITH_BEHAVIOR_GAP(candidate)":
            raise InputError("member behavior gap lost candidate-only classification")
        lid = "MEMBER:" + "|".join(
            row[k] for k in ("caller", "ref_kind", "owner", "name", "descriptor")
        )
        if lid in seen:
            raise InputError(f"duplicate member ledger id {lid}")
        seen.add(lid)
        out.append(
            LedgerRow(
                lid,
                "MEMBER",
                row["ref_kind"],
                f"{row['owner']}->{row['name']}{row['descriptor']}",
                "MEMBER_STOCK_ONLY_CANDIDATE",
                "DEX_CALLSITE",
                f"RESOLVED:{row['stock_provider']}",
                f"{row['c3a_result']}:{row['c3a_detail']}",
                "candidate only; never import authority",
            )
        )

    cov = [
        coverage(
            "MEMBERS_DEXDUMP_ORACLE",
            se["N1I_B2_MEMBERS_DEXDUMP_ORACLE"].startswith("PASS(")
            and ce["N1I_B2_MEMBERS_DEXDUMP_ORACLE"].startswith("PASS("),
            True,
            f"stock={se['N1I_B2_MEMBERS_DEXDUMP_ORACLE']} c3a={ce['N1I_B2_MEMBERS_DEXDUMP_ORACLE']}",
        ),
        coverage(
            "MEMBERS_REQUIRED_USES_LIBRARIES",
            se["N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE"] == "NONE"
            and ce["N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE"] == "NONE",
            True,
            f"stock={se['N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE']} "
            f"c3a={ce['N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE']}",
        ),
        coverage(
            "MEMBERS_STOCK_RESOLUTION",
            int_value(se, "N1I_B2_MEMBERS_UNRESOLVED") == 0,
            True,
            f"stock_unresolved={se['N1I_B2_MEMBERS_UNRESOLVED']}",
        ),
        Coverage(
            "MEMBERS_PROTECTED_TARGET_RECEIVER_VERIFIER",
            "LIMITATION",
            "NO",
            "link-time protected access is modelled; verifier-time target receiver subtype rule is not",
        ),
    ]
    return out, cov, app_sha


def native_rows(stock: Path, c3a: Path) -> tuple[list[LedgerRow], list[Coverage], str]:
    req = {
        "N1I_B2_NATIVE_APK_SHA256",
        "N1I_B2_NATIVE_DEXDUMP_ORACLE",
        "N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED",
        "N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING",
        "N1I_B2_NATIVE_JNI_CANDIDATE_ONLY",
        "N1I_B2_NATIVE_JNI_UNRESOLVED",
        "N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN",
        "N1I_B2_NATIVE_NAMESPACE_VISIBILITY_INFERRED",
        "N1I_B2_NATIVE_NAMESPACE_VISIBLE_LIBRARY_COUNT",
        "N1I_B2_NATIVE_KEYWORD_ROOTS_USED",
    }
    se = env_file(stock / "NATIVE_SUMMARY.env", req)
    ce = env_file(c3a / "NATIVE_SUMMARY.env", req)
    if se["N1I_B2_NATIVE_APK_SHA256"] != ce["N1I_B2_NATIVE_APK_SHA256"]:
        raise InputError("native outputs refer to different APK bytes")
    app_sha = se["N1I_B2_NATIVE_APK_SHA256"]
    require_sha(app_sha, "native APK SHA-256")
    for label, env in (("stock", se), ("c3a", ce)):
        if env["N1I_B2_NATIVE_NAMESPACE_VISIBILITY_INFERRED"] != "NO":
            raise InputError(f"{label} native output inferred namespace visibility")
        if env["N1I_B2_NATIVE_KEYWORD_ROOTS_USED"] != "NO":
            raise InputError(f"{label} native output used keyword roots")

    required = {
        "library",
        "status",
        "partition",
        "provider_class",
        "path",
        "sha256",
        "needed",
        "admitted_by",
        "namespace_visibility",
        "evidence_strength",
    }
    sr = tsv(stock / "NATIVE_CLOSURE.tsv", required, "library")
    cr = tsv(c3a / "NATIVE_CLOSURE.tsv", required, "library")
    sm = {r["library"]: r for r in sr}
    cm = {r["library"]: r for r in cr}
    for row in sr + cr:
        if row["status"] not in NATIVE_STATUSES:
            raise InputError(f"unknown native status {row['status']}")
        visibility = row["namespace_visibility"]
        if row["status"] == "FOUND":
            expected = "APK_PACKAGED" if row["partition"] == "apk" else "EXPLICIT"
            if visibility != expected:
                raise InputError(
                    f"{row['library']}: FOUND without {expected} namespace visibility provenance"
                )
        elif row["status"] == "FILE_PRESENT_NAMESPACE_UNPROVEN" and visibility != "UNPROVEN":
            raise InputError(f"{row['library']}: namespace-unproven row lacks UNPROVEN provenance")

    out: list[LedgerRow] = []
    for name in sorted(set(sm) | set(cm)):
        s, c = sm.get(name), cm.get(name)
        sstatus = s["status"] if s else "NOT_ANALYSED"
        cstatus = c["status"] if c else "NOT_ANALYSED"
        if sstatus != "FOUND" or cstatus == "FOUND":
            continue
        if cstatus == "FILE_PRESENT_NAMESPACE_UNPROVEN":
            status = "NATIVE_NAMESPACE_UNPROVEN"
        elif cstatus == "WRONG_ABI":
            status = "NATIVE_WRONG_ABI"
        else:
            status = "NATIVE_STOCK_ONLY_CANDIDATE"
        strength = (s or c or {}).get("evidence_strength", "-")
        out.append(
            LedgerRow(
                f"NATIVE:{name}",
                "NATIVE",
                "ELF_LIBRARY",
                name,
                status,
                strength,
                f"{sstatus}:{(s or {}).get('partition', '-')}",
                f"{cstatus}:{(c or {}).get('partition', '-')}",
                "candidate/coverage evidence only; native import not authorized",
            )
        )

    native_unproven = sorted(
        set(comma_values(se["N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN"]))
        | set(comma_values(ce["N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN"]))
    )
    required_missing = sorted(
        set(comma_values(se["N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING"]))
        | set(comma_values(ce["N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING"]))
    )
    cov = [
        coverage(
            "NATIVE_DEXDUMP_ORACLE",
            se["N1I_B2_NATIVE_DEXDUMP_ORACLE"].startswith("PASS(")
            and ce["N1I_B2_NATIVE_DEXDUMP_ORACLE"].startswith("PASS("),
            True,
            f"stock={se['N1I_B2_NATIVE_DEXDUMP_ORACLE']} c3a={ce['N1I_B2_NATIVE_DEXDUMP_ORACLE']}",
        ),
        coverage(
            "NATIVE_DYNAMIC_LOADS",
            int_value(se, "N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED") == 0
            and int_value(ce, "N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED") == 0,
            True,
            f"stock={se['N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED']} "
            f"c3a={ce['N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED']}",
        ),
        coverage(
            "NATIVE_NAMESPACE_VISIBILITY",
            not native_unproven,
            True,
            "unproven=" + (",".join(native_unproven) or "NONE")
            + f" explicit_stock={se['N1I_B2_NATIVE_NAMESPACE_VISIBLE_LIBRARY_COUNT']}"
            + f" explicit_c3a={ce['N1I_B2_NATIVE_NAMESPACE_VISIBLE_LIBRARY_COUNT']}",
        ),
        coverage(
            "NATIVE_REQUIRED_USES_LIBRARY",
            not required_missing,
            True,
            "missing=" + (",".join(required_missing) or "NONE"),
        ),
        coverage(
            "NATIVE_JNI_ATTRIBUTION",
            int_value(ce, "N1I_B2_NATIVE_JNI_CANDIDATE_ONLY") == 0
            and int_value(ce, "N1I_B2_NATIVE_JNI_UNRESOLVED") == 0,
            True,
            f"c3a_candidate_only={ce['N1I_B2_NATIVE_JNI_CANDIDATE_ONLY']} "
            f"c3a_unresolved={ce['N1I_B2_NATIVE_JNI_UNRESOLVED']}",
        ),
    ]
    return out, cov, app_sha


def census_rows(root: Path) -> tuple[list[LedgerRow], list[Coverage]]:
    env = env_file(
        root / "CENSUS_SUMMARY.env",
        {
            "N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL",
            "N1I_B2_CENSUS_RUNTIME_PROOF_VENDOR_IDENTITY_REQUIRED",
            "N1I_B2_CENSUS_UNMAPPED_POLICY_FINDS",
            "N1I_B2_CENSUS_RUNTIME_INPUTS",
            "N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT",
        },
    )
    if env["N1I_B2_CENSUS_RUNTIME_PROOF_VENDOR_IDENTITY_REQUIRED"] != "YES":
        raise InputError("census does not require vendor identity for runtime proof")
    rows = tsv(
        root / "CENSUS_EDGES.tsv",
        {
            "edge_id",
            "component_kind",
            "name",
            "status",
            "counted_as_vendor_expected_system_edge",
            "consumer_evidence_strength",
            "consumer_evidence",
            "stock_producer",
            "c3a_producer",
            "vendor_producer",
            "stock_runtime",
            "c3a_runtime",
            "vendor_wait_on_c3a",
            "optional",
        },
        "edge_id",
    )
    out: list[LedgerRow] = []
    proven = 0
    status_map = {
        "MTK_SYSTEM_EDGE_PROVEN": "VENDOR_SYSTEM_EDGE_PROVEN",
        "MISSING_ON_C3A_RUNTIME_CONFIRMED": "VENDOR_SYSTEM_EDGE_RUNTIME_CONFIRMED",
        "MISSING_ON_C3A_CANDIDATE": "VENDOR_SYSTEM_EDGE_CANDIDATE",
        "MISSING_ON_C3A_STRING_ONLY_CANDIDATE": "VENDOR_SYSTEM_EDGE_STRING_ONLY",
    }
    for row in rows:
        if row["status"] not in CENSUS_STATUSES:
            raise InputError(f"unknown census status {row['status']}")
        if row["status"] == "MTK_SYSTEM_EDGE_PROVEN":
            proven += 1
            if env["N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL"] != "YES":
                raise InputError("census contains proven edge without identical stock/C3A vendor trees")
            if not row["vendor_wait_on_c3a"] or row["vendor_wait_on_c3a"] == "-":
                raise InputError("census proven edge lacks runtime vendor wait")
        if row["status"] not in status_map:
            continue
        out.append(
            LedgerRow(
                "CENSUS:" + row["edge_id"],
                "CENSUS",
                row["component_kind"],
                row["name"],
                status_map[row["status"]],
                row["consumer_evidence_strength"],
                f"producer={row['stock_producer']} runtime={row['stock_runtime']}",
                f"producer={row['c3a_producer']} runtime={row['c3a_runtime']}",
                f"source_status={row['status']}; import not authorized",
            )
        )
    if proven != int_value(env, "N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT"):
        raise InputError("census proven count disagrees with edge table")

    runtime = set(comma_values(env["N1I_B2_CENSUS_RUNTIME_INPUTS"]))
    needed = {"stock_service_list", "c3a_service_list", "stock_lshal", "c3a_lshal"}
    cov = [
        coverage(
            "CENSUS_VENDOR_IDENTITY",
            env["N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL"] == "YES",
            True,
            env["N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL"],
        ),
        coverage(
            "CENSUS_POLICY_MAPPING",
            int_value(env, "N1I_B2_CENSUS_UNMAPPED_POLICY_FINDS") == 0,
            True,
            f"unmapped={env['N1I_B2_CENSUS_UNMAPPED_POLICY_FINDS']}",
        ),
        coverage(
            "CENSUS_RUNTIME_PRESENCE",
            needed <= runtime,
            True,
            "inputs=" + (",".join(sorted(runtime)) or "NONE"),
        ),
    ]
    return out, cov


def write_out(final: Path, files: dict[str, str]) -> None:
    final = final.resolve()
    if final.exists() and any(final.iterdir()):
        raise InputError(f"output directory must be empty or absent: {final}")
    tmp = Path(tempfile.mkdtemp(prefix=".n1ib2l-"))
    try:
        for name, text in files.items():
            (tmp / name).write_text(text, encoding="utf-8")
        final.parent.mkdir(parents=True, exist_ok=True)
        if final.exists():
            final.rmdir()
        shutil.move(str(tmp), str(final))
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--members-stock", type=Path, required=True)
    p.add_argument("--members-c3a", type=Path, required=True)
    p.add_argument("--members-compare", type=Path, required=True)
    p.add_argument("--native-stock", type=Path, required=True)
    p.add_argument("--native-c3a", type=Path, required=True)
    p.add_argument("--census", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    a = p.parse_args(argv)

    try:
        mrows, mcov, msha = member_rows(a.members_stock, a.members_c3a, a.members_compare)
        nrows, ncov, nsha = native_rows(a.native_stock, a.native_c3a)
        if msha != nsha:
            raise InputError("member and native analyses refer to different APK bytes")
        crows, ccov = census_rows(a.census)
        rows = sorted(mrows + nrows + crows, key=lambda r: r.ledger_id)
        ids = [r.ledger_id for r in rows]
        if len(ids) != len(set(ids)):
            raise InputError("duplicate dependency ledger id across domains")

        cov = mcov + ncov + ccov
        blockers = [x for x in cov if x.critical == "YES" and x.state != "PASS"]
        coverage_complete = not blockers

        proven = sum(r.status == "VENDOR_SYSTEM_EDGE_PROVEN" for r in rows)
        runtime_confirmed = sum(r.status == "VENDOR_SYSTEM_EDGE_RUNTIME_CONFIRMED" for r in rows)
        string_only = sum(r.status == "VENDOR_SYSTEM_EDGE_STRING_ONLY" for r in rows)
        candidates = sum(
            r.status
            in {
                "MEMBER_STOCK_ONLY_CANDIDATE",
                "NATIVE_STOCK_ONLY_CANDIDATE",
                "VENDOR_SYSTEM_EDGE_CANDIDATE",
            }
            for r in rows
        )
        namespace_unproven = sum(r.status == "NATIVE_NAMESPACE_UNPROVEN" for r in rows)

        ledger = [
            "ledger_id\tdomain\tcomponent_kind\tname\tstatus\tevidence_strength\t"
            "stock_evidence\tc3a_evidence\timport_authorized\tnote"
        ]
        for r in rows:
            ledger.append(
                "\t".join(
                    clean(x)
                    for x in (
                        r.ledger_id,
                        r.domain,
                        r.component_kind,
                        r.name,
                        r.status,
                        r.evidence_strength,
                        r.stock_evidence,
                        r.c3a_evidence,
                        "NO",
                        r.note,
                    )
                )
            )

        matrix = ["area\tstate\tcritical\tdetail"]
        matrix += ["\t".join(clean(x) for x in (r.area, r.state, r.critical, r.detail)) for r in cov]

        env = [
            ("N1I_B2_LEDGER_TOOL_VERSION", TOOL_VERSION),
            ("N1I_B2_LEDGER_APK_SHA256", msha),
            ("N1I_B2_LEDGER_ENTRY_COUNT", str(len(rows))),
            ("N1I_B2_LEDGER_PROVEN_EDGE_COUNT", str(proven)),
            ("N1I_B2_LEDGER_RUNTIME_CONFIRMED_COUNT", str(runtime_confirmed)),
            ("N1I_B2_LEDGER_CANDIDATE_COUNT", str(candidates)),
            ("N1I_B2_LEDGER_STRING_ONLY_COUNT", str(string_only)),
            ("N1I_B2_LEDGER_NAMESPACE_UNPROVEN_COUNT", str(namespace_unproven)),
            ("N1I_B2_LEDGER_CRITICAL_COVERAGE_GAP_COUNT", str(len(blockers))),
            ("N1I_B2_LEDGER_COVERAGE_COMPLETE", "YES" if coverage_complete else "NO"),
            ("N1I_B2_LEDGER_PROTECTED_RECEIVER_VERIFIER_LIMITATION", "YES"),
            ("N1I_B2_LEDGER_IMPORT_AUTHORIZED", "NO"),
            ("N1I_B2_LEDGER_DEVICE_MUTATION_AUTHORIZED", "NO"),
            ("N1I_B2_LEDGER_FLASH_AUTHORIZED", "NO"),
            (
                "N1I_B2_LEDGER_NEXT_STEP",
                "B3_MINIMAL_ADMISSION_REVIEW_ONLY" if coverage_complete else "HOLD_FOR_EVIDENCE",
            ),
        ]

        write_out(
            a.out,
            {
                "DEPENDENCY_LEDGER.tsv": "\n".join(ledger) + "\n",
                "COVERAGE_MATRIX.tsv": "\n".join(matrix) + "\n",
                "LEDGER_SUMMARY.env": "".join(f"{k}={clean(v)}\n" for k, v in env),
            },
        )
    except InputError as exc:
        print(f"ERROR: {exc}", file=__import__("sys").stderr)
        return 2

    print(f"N1I_B2_LEDGER_ENTRY_COUNT={len(rows)}")
    print(f"N1I_B2_LEDGER_COVERAGE_COMPLETE={'YES' if coverage_complete else 'NO'}")
    print("N1I_B2_LEDGER_IMPORT_AUTHORIZED=NO")
    print("N1I_B2_LEDGER_DEVICE_MUTATION_AUTHORIZED=NO")
    print(f"OUTPUT={a.out.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(__import__("sys").argv[1:]))
