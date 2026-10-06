#!/usr/bin/env python3
"""Titan 2 N1I-D0-0H host-only boot compatibility qualifier.

Consumes only prepared host inputs from prepare-n1i-d0-0h-inputs.sh.
No build, network, device contact, reboot, flash, mount, or source mutation.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass

ROOT = Path(__file__).resolve().parents[2]
C2_BUILD_SOURCE = "27d671b004f5ae7394f147018fc4fffdf4d78498"
B2_PROVENANCE = "1697f21989b8ed6f1db90f8886952894592c7d0f"
N1F_SHA = "dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a"
C2_SHA = "630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50"
COMMON = "/system_ext/framework/mediatek-common.jar"
IMS_BASE = "/system_ext/framework/mediatek-ims-base.jar"

PASS = "PASS"
BOOT_FATAL = "BOOT_FATAL"
FUNCTIONAL_RISK = "FUNCTIONAL_RISK"
COMPLIANCE_ONLY = "COMPLIANCE_ONLY"
UNKNOWN = "UNKNOWN"
NOT_APPLICABLE = "NOT_APPLICABLE"


class D0Error(Exception):
    pass


@dataclass
class Gate:
    name: str
    side: str
    result: str
    detail: str


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k] = v.strip().strip('"')
    return out


def run(
    cmd: list[str],
    out: Path | None = None,
    cwd: Path | None = None,
) -> tuple[int, str]:
    p = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=False,
        cwd=str(cwd) if cwd is not None else None,
    )
    text = p.stdout + p.stderr
    if out is not None:
        out.write_text(text, encoding="utf-8")
    return p.returncode, text


def first_existing(*paths: Path) -> Path | None:
    for path in paths:
        if path.is_file():
            return path
    return None


def root_path(root: Path, partition: str, rel: str) -> Path | None:
    relp = Path(rel.lstrip("/"))
    candidates: list[Path] = []
    if partition == "system":
        candidates = [root / "system" / relp, root / relp]
    elif partition == "system_ext":
        candidates = [
            root / "system" / "system_ext" / relp,
            root / "system_ext" / relp,
            root / relp,
        ]
    elif partition == "product":
        candidates = [
            root / "system" / "product" / relp,
            root / "product" / relp,
            root / relp,
        ]
    else:
        candidates = [root / partition / relp, root / relp]
    for path in candidates:
        if path.exists():
            return path
    return None


def find_all(root: Path, names: tuple[str, ...]) -> list[Path]:
    out: list[Path] = []
    for name in names:
        out.extend(root.rglob(name))
    return sorted(set(p for p in out if p.is_file()))


def parse_contexts(paths: list[Path]) -> dict[str, list[tuple[str, str]]]:
    rows: dict[str, list[tuple[str, str]]] = {}
    for path in paths:
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            fields = line.split()
            if len(fields) < 2:
                continue
            rows.setdefault(fields[0], []).append((fields[1], str(path)))
    return rows


def context_conflicts(rows: dict[str, list[tuple[str, str]]]) -> list[tuple[str, str]]:
    out = []
    for key, values in sorted(rows.items()):
        labels = sorted({v for v, _p in values})
        if len(labels) > 1:
            out.append((key, ",".join(labels)))
    return out


def write_tsv(path: Path, header: list[str], rows: list[list[object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp, delimiter="\t", lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def git_clean() -> bool:
    p = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain=v1", "--untracked-files=all"],
        capture_output=True, text=True, check=True,
    )
    return not p.stdout.strip()


PINNED_B2_FILES = (
    "build/titan2/n1i_static.py",
    "build/titan2/n1i-b2-members.py",
    "build/titan2/n1i-b2-native.py",
)


def verify_b2_provenance() -> bool:
    p = subprocess.run(
        [
            "git",
            "-C",
            str(ROOT),
            "merge-base",
            "--is-ancestor",
            B2_PROVENANCE,
            "HEAD",
        ],
        check=False,
    )
    if p.returncode != 0:
        return False
    for rel in PINNED_B2_FILES:
        probe = subprocess.run(
            [
                "git",
                "-C",
                str(ROOT),
                "cat-file",
                "-e",
                f"{B2_PROVENANCE}:{rel}",
            ],
            check=False,
        )
        if probe.returncode != 0:
            return False
    return True


def materialize_pinned_b2(out: Path) -> Path:
    tool_dir = out / "pinned-b2"
    tool_dir.mkdir()
    manifest = []
    for rel in PINNED_B2_FILES:
        blob = subprocess.check_output(
            [
                "git",
                "-C",
                str(ROOT),
                "rev-parse",
                f"{B2_PROVENANCE}:{rel}",
            ],
            text=True,
        ).strip()
        content = subprocess.check_output(
            [
                "git",
                "-C",
                str(ROOT),
                "show",
                f"{B2_PROVENANCE}:{rel}",
            ]
        )
        dest = tool_dir / Path(rel).name
        dest.write_bytes(content)
        manifest.append(
            [
                rel,
                blob,
                hashlib.sha256(content).hexdigest(),
                str(dest),
            ]
        )
    write_tsv(
        out / "PINNED_B2_TOOLS.tsv",
        ["source_path", "git_blob", "sha256", "materialized_path"],
        manifest,
    )
    return tool_dir


def load_deriver():
    path = ROOT / "build/titan2/derive-n1i-c1-runtime-classpath.py"
    spec = importlib.util.spec_from_file_location("n1i_d0_deriver", path)
    if spec is None or spec.loader is None:
        raise D0Error(f"cannot_load_deriver={path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod


def source_composition(out: Path) -> dict[str, str]:
    c1 = (ROOT / "product/titan2/n1i-c1/sable-titan2-n1i-c1.mk").read_text()
    c2 = (ROOT / "product/titan2/n1i-c2/sable-titan2-n1i-c2.mk").read_text()
    c1_driver = (ROOT / "build/titan2/run-n1i-c1-cellular-isolation.sh").read_text()
    c2_driver = (ROOT / "build/titan2/run-n1i-c2-cellular-mvp.sh").read_text()
    bp1 = (ROOT / "product/titan2/n1i-c1/Android.bp").read_text()
    bp2 = (ROOT / "product/titan2/n1i-c2/Android.bp").read_text()

    telephony_patch = "0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch"
    values = {
        "C1_OEM_IMS": "YES" if "ImsService" in bp1 else "NO",
        "C2_OEM_IMS": "YES" if "ImsService" in c2 or "n1i-c1" in c2 else "YES_INHERITED",
        "C1_TELEPHONYMETRICS": "YES" if telephony_patch in c1_driver else "NO",
        "C2_TELEPHONYMETRICS": "YES" if telephony_patch in c2_driver else "INHERITED_FROM_C1"
        if "sable-titan2-n1i-c1.mk" in c2 else "NO",
        "C1_STOCK_NATIVE_IMPORTS": "0" if "cc_prebuilt_library_shared {" not in bp1 else "NONZERO",
        "C2_STOCK_NATIVE_IMPORTS": str(bp2.count("cc_prebuilt_library_shared {")),
        "C2_INHERITS_C1": "YES" if "sable-titan2-n1i-c1.mk" in c2 else "NO",
    }
    rows = [[k, v] for k, v in values.items()]
    write_tsv(out / "composition-common-delta.tsv", ["field", "value"], rows)
    return values



def relevant_inventory(root: Path) -> dict[str, tuple[int, str, str]]:
    rows: dict[str, tuple[int, str, str]] = {}
    categories = (
        ("system", "etc/selinux"),
        ("system", "etc/permissions"),
        ("system", "etc/sysconfig"),
        ("system", "etc/init"),
        ("system", "framework"),
        ("system", "lib64"),
        ("system", "apex"),
        ("system_ext", "etc/selinux"),
        ("system_ext", "etc/permissions"),
        ("system_ext", "etc/sysconfig"),
        ("system_ext", "etc/init"),
        ("system_ext", "framework"),
        ("system_ext", "lib64"),
        ("system_ext", "priv-app/ImsService"),
        ("product", "etc/selinux"),
        ("product", "etc/permissions"),
        ("product", "etc/sysconfig"),
        ("product", "etc/init"),
        ("product", "framework"),
        ("product", "lib64"),
    )
    for part, rel in categories:
        base = root_path(root, part, rel)
        if base is None:
            continue
        files = [base] if base.is_file() else sorted(base.rglob("*"))
        for path in files:
            if not path.is_file():
                continue
            part_root = root_path(root, part, "")
            if part_root is None:
                continue
            relpath = path.relative_to(part_root)
            runtime = (
                "/" + str(relpath)
                if part == "system"
                else f"/{part}/" + str(relpath)
            )
            try:
                size = path.stat().st_size
                digest = sha256(path)
            except OSError:
                continue
            rows[runtime] = (size, digest, part)
    return rows


def composition_delta(
    n1f: Path,
    c2: Path,
    c1: Path | None,
    out: Path,
) -> None:
    inventories = {
        "N1F": relevant_inventory(n1f),
        "C2": relevant_inventory(c2),
    }
    if c1 is not None and c1.is_dir():
        inventories["C1"] = relevant_inventory(c1)

    for left, right in (
        ("N1F", "C2"),
        ("N1F", "C1"),
        ("C1", "C2"),
    ):
        dest = out / f"composition-{left.lower()}-to-{right.lower()}.tsv"
        if left not in inventories or right not in inventories:
            write_tsv(
                dest,
                ["status", "reason"],
                [["UNKNOWN", "binary_control_not_retained"]],
            )
            continue
        a = inventories[left]
        b = inventories[right]
        rows = []
        for runtime_path in sorted(set(a) | set(b)):
            av = a.get(runtime_path)
            bv = b.get(runtime_path)
            if av == bv:
                continue
            if av is None:
                status = "ADDED"
            elif bv is None:
                status = "REMOVED"
            else:
                status = "CHANGED"
            rows.append(
                [
                    runtime_path,
                    status,
                    av[0] if av else "-",
                    av[1] if av else "-",
                    bv[0] if bv else "-",
                    bv[1] if bv else "-",
                ]
            )
        write_tsv(
            dest,
            [
                "runtime_path",
                "status",
                f"{left}_bytes",
                f"{left}_sha256",
                f"{right}_bytes",
                f"{right}_sha256",
            ],
            rows,
        )

def policy_files(side_root: Path, stock_vendor: Path, stock_odm: Path | None) -> dict[str, Path | None]:
    files = {
        "plat": root_path(side_root, "system", "etc/selinux/plat_sepolicy.cil"),
        "plat_hash": root_path(side_root, "system", "etc/selinux/plat_sepolicy_and_mapping.sha256"),
        "system_ext": root_path(side_root, "system_ext", "etc/selinux/system_ext_sepolicy.cil"),
        "system_ext_hash": root_path(side_root, "system_ext", "etc/selinux/system_ext_sepolicy_and_mapping.sha256"),
        "product": root_path(side_root, "product", "etc/selinux/product_sepolicy.cil"),
        "product_hash": root_path(side_root, "product", "etc/selinux/product_sepolicy_and_mapping.sha256"),
        "vendor": root_path(stock_vendor, "vendor", "etc/selinux/vendor_sepolicy.cil"),
        "plat_pub": root_path(stock_vendor, "vendor", "etc/selinux/plat_pub_versioned.cil"),
        "vendor_vers": root_path(stock_vendor, "vendor", "etc/selinux/plat_sepolicy_vers.txt"),
        "genfs_vers": root_path(stock_vendor, "vendor", "etc/selinux/genfs_labels_version.txt"),
    }
    files["odm"] = (
        root_path(stock_odm, "odm", "etc/selinux/odm_sepolicy.cil")
        if stock_odm is not None and stock_odm.exists()
        else None
    )
    return files


def precompiled_authority(side_root: Path, stock_vendor: Path, stock_odm: Path | None) -> tuple[str, str, Path | None]:
    pre = None
    if stock_odm is not None and stock_odm.exists():
        pre = root_path(stock_odm, "odm", "etc/selinux/precompiled_sepolicy")
    if pre is None:
        pre = root_path(stock_vendor, "vendor", "etc/selinux/precompiled_sepolicy")
    if pre is None:
        return "SPLIT_COMPILE_REQUIRED", "precompiled_sepolicy_absent", None

    pairs = [
        (
            root_path(side_root, "system", "etc/selinux/plat_sepolicy_and_mapping.sha256"),
            Path(str(pre) + ".plat_sepolicy_and_mapping.sha256"),
            "plat",
        ),
        (
            root_path(side_root, "system_ext", "etc/selinux/system_ext_sepolicy_and_mapping.sha256"),
            Path(str(pre) + ".system_ext_sepolicy_and_mapping.sha256"),
            "system_ext",
        ),
        (
            root_path(side_root, "product", "etc/selinux/product_sepolicy_and_mapping.sha256"),
            Path(str(pre) + ".product_sepolicy_and_mapping.sha256"),
            "product",
        ),
    ]
    for actual, compiled, label in pairs:
        a = actual.is_file() if actual else False
        b = compiled.is_file()
        if not a and not b:
            continue
        if a != b:
            return "SPLIT_COMPILE_REQUIRED", f"{label}_hash_presence_mismatch", pre
        av = actual.read_text().splitlines()[0].strip()
        bv = compiled.read_text().splitlines()[0].strip()
        if not av or av != bv:
            return "SPLIT_COMPILE_REQUIRED", f"{label}_hash_mismatch", pre
    return "PRECOMPILED_MATCH", f"precompiled={pre}", pre


def init_sepolicy_version(android_root: Path) -> int | None:
    bp = android_root / "system/core/init/Android.bp"
    if not bp.is_file():
        return None
    text = bp.read_text(encoding="utf-8", errors="replace")
    values = {
        int(v)
        for v in re.findall(r"-DSEPOLICY_VERSION=(\d+)", text)
    }
    if len(values) != 1:
        return None
    return next(iter(values))


def compile_policy(
    side: str,
    side_root: Path,
    stock_vendor: Path,
    stock_odm: Path | None,
    android_root: Path,
    secilc: Path,
    out: Path,
) -> tuple[Gate, Gate, Gate, Path | None]:
    mode, why, pre = precompiled_authority(
        side_root,
        stock_vendor,
        stock_odm,
    )
    (out / f"gate-a0-{side}.env").write_text(
        f"MODE={mode}\nDETAIL={why}\n",
        encoding="utf-8",
    )
    a0 = Gate("A0", side, PASS, f"mode={mode}:{why}")
    if mode == "PRECOMPILED_MATCH":
        return (
            a0,
            Gate("A", side, PASS, why),
            Gate("A2", side, NOT_APPLICABLE, "precompiled_used"),
            pre,
        )

    init_src = android_root / "system/core/init/selinux.cpp"
    if not init_src.is_file():
        return a0, Gate("A", side, UNKNOWN, "android_init_selinux_source_missing"), Gate("A2", side, UNKNOWN, "a1_not_run"), None
    init_text = init_src.read_text(encoding="utf-8", errors="replace")
    required_source_markers = [
        "FindPrecompiledSplitPolicy",
        "plat_sepolicy_and_mapping.sha256",
        "system_ext_sepolicy_and_mapping.sha256",
        "product_sepolicy_and_mapping.sha256",
        '"-m", "-M", "true", "-G", "-N"',
        "plat_pub_versioned.cil",
        "vendor_sepolicy.cil",
        "odm_sepolicy.cil",
        "get_genfs_labels_version",
    ]
    missing_markers = [m for m in required_source_markers if m not in init_text]
    if missing_markers:
        return a0, Gate("A", side, UNKNOWN, "init_semantics_unrecognized:" + ",".join(missing_markers)), Gate("A2", side, UNKNOWN, "a1_not_run"), None

    f = policy_files(side_root, stock_vendor, stock_odm)
    required = ("plat", "vendor", "plat_pub", "vendor_vers")
    missing = [k for k in required if f[k] is None or not f[k].is_file()]
    if missing:
        return a0, Gate("A", side, UNKNOWN, "policy_inputs_missing:" + ",".join(missing)), Gate("A2", side, UNKNOWN, "a1_not_run"), None

    vers = f["vendor_vers"].read_text().splitlines()[0].strip()
    mapping = root_path(side_root, "system", f"etc/selinux/mapping/{vers}.cil")
    if mapping is None:
        return a0, Gate("A", side, UNKNOWN, f"platform_mapping_missing={vers}"), Gate("A2", side, UNKNOWN, "a1_not_run"), None
    plat_compat = root_path(side_root, "system", f"etc/selinux/mapping/{vers}.compat.cil")
    sext_map = root_path(side_root, "system_ext", f"etc/selinux/mapping/{vers}.cil")
    sext_compat = root_path(side_root, "system_ext", f"etc/selinux/mapping/{vers}.compat.cil")
    product_map = root_path(side_root, "product", f"etc/selinux/mapping/{vers}.cil")

    pv = init_sepolicy_version(android_root)
    if pv is None:
        return a0, Gate("A", side, UNKNOWN, "init_sepolicy_version_unknown"), Gate("A2", side, UNKNOWN, "a1_not_run"), None

    genfs_version = "202404"
    genfs_source = "DEFAULT_ANDROID_FALLBACK"
    if f["genfs_vers"] and f["genfs_vers"].is_file():
        raw = f["genfs_vers"].read_text().strip()
        if raw.isdigit():
            genfs_version = raw
            genfs_source = "VENDOR_FILE"
    genfs = root_path(side_root, "system", f"etc/selinux/plat_sepolicy_genfs_{genfs_version}.cil")

    inputs = [f["plat"], mapping]
    for path in (plat_compat, f["system_ext"], sext_map, sext_compat, f["product"], product_map, f["plat_pub"], f["vendor"], f["odm"], genfs):
        if path is not None and path.is_file():
            inputs.append(path)

    compiled = out / f"gate-a1-{side}.policy"
    fc = out / f"gate-a1-{side}.file_contexts"
    cmd = [str(secilc), str(inputs[0]), "-m", "-M", "true", "-G", "-N", "-c", str(pv), str(inputs[1]), "-o", str(compiled), "-f", str(fc)]
    cmd += [str(p) for p in inputs[2:]]
    rc, log = run(cmd, out / f"gate-a1-{side}.log")
    write_tsv(
        out / f"gate-a1-{side}-inputs.tsv",
        ["path", "sha256"],
        [[str(p), sha256(p)] for p in inputs],
    )
    (out / f"gate-a1-{side}-command.txt").write_text(" ".join(cmd) + "\n", encoding="utf-8")
    (out / f"gate-a1-{side}-meta.env").write_text(
        f"VENDOR_MAPPING_VERSION={vers}\nINIT_SEPOLICY_VERSION={pv}\nGENFS_VERSION={genfs_version}\nGENFS_SOURCE={genfs_source}\n",
        encoding="utf-8",
    )
    if rc != 0 or not compiled.is_file():
        return a0, Gate("A", side, BOOT_FATAL, f"init_equivalent_secilc_rc={rc}"), Gate("A2", side, UNKNOWN, "a1_failed"), None

    compliance = out / f"gate-a2-{side}.policy"
    compliance_fc = out / f"gate-a2-{side}.file_contexts"
    ccmd = [x for x in cmd if x != "-N"]
    ccmd[ccmd.index(str(compiled))] = str(compliance)
    ccmd[ccmd.index(str(fc))] = str(compliance_fc)
    crc, _ = run(ccmd, out / f"gate-a2-{side}.log")
    cgate = Gate("A2", side, PASS if crc == 0 else COMPLIANCE_ONLY, f"neverallow_secilc_rc={crc}")
    return a0, Gate("A", side, PASS, f"split_compile_pass genfs={genfs_version}"), cgate, compiled


def collect_context_files(side_root: Path, stock_vendor: Path, stock_odm: Path | None, kind: str) -> list[Path]:
    names = {
        "property": (
            ("system", "etc/selinux/plat_property_contexts"),
            ("system_ext", "etc/selinux/system_ext_property_contexts"),
            ("product", "etc/selinux/product_property_contexts"),
        ),
        "service": (
            ("system", "etc/selinux/plat_service_contexts"),
            ("system_ext", "etc/selinux/system_ext_service_contexts"),
            ("product", "etc/selinux/product_service_contexts"),
        ),
    }[kind]
    out = []
    for part, rel in names:
        p = root_path(side_root, part, rel)
        if p is not None and p.is_file():
            out.append(p)
    v = root_path(stock_vendor, "vendor", f"etc/selinux/vendor_{kind}_contexts")
    if v is not None and v.is_file():
        out.append(v)
    if stock_odm is not None and stock_odm.exists():
        o = root_path(stock_odm, "odm", f"etc/selinux/odm_{kind}_contexts")
        if o is not None and o.is_file():
            out.append(o)
    return out


def gate_b(side: str, side_root: Path, stock_vendor: Path, stock_odm: Path | None, policy: Path | None, tool: Path, out: Path, a_result: str) -> Gate:
    paths = collect_context_files(side_root, stock_vendor, stock_odm, "property")
    rows = parse_contexts(paths)
    conflicts = context_conflicts(rows)
    write_tsv(out / f"gate-b-{side}-conflicts.tsv", ["property", "labels"], [[a, b] for a, b in conflicts])
    if a_result != PASS or policy is None:
        return Gate("B", side, UNKNOWN, f"effective_policy_unavailable gate_a={a_result}")
    if not tool.is_file():
        return Gate("B", side, UNKNOWN, f"property_info_checker_missing={tool}")
    rc, _ = run([str(tool), str(policy), *map(str, paths)], out / f"gate-b-{side}.log")
    if rc != 0:
        return Gate("B", side, BOOT_FATAL, f"property_info_checker_rc={rc}")
    return Gate("B", side, PASS, f"context_files={len(paths)} exact_conflicts={len(conflicts)}")


def vintf_text(stock_vendor: Path, stock_odm: Path | None) -> str:
    pieces = []
    for root in [stock_vendor, stock_odm]:
        if root is None or not root.exists():
            continue
        for path in root.rglob("manifest*.xml"):
            if "vintf" in str(path):
                pieces.append(path.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(pieces)


def gate_c(side: str, side_root: Path, stock_vendor: Path, stock_odm: Path | None, policy: Path | None, checkfc: Path, out: Path) -> Gate:
    paths = collect_context_files(side_root, stock_vendor, stock_odm, "service")
    rows = parse_contexts(paths)
    conflicts = context_conflicts(rows)
    write_tsv(out / f"gate-c-{side}-conflicts.tsv", ["service", "labels"], [[a, b] for a, b in conflicts])
    merged = out / f"gate-c-{side}-merged-service-contexts"
    with merged.open("w", encoding="utf-8") as fp:
        for src in paths:
            text = src.read_text(encoding="utf-8", errors="replace")
            fp.write(text)
            if text and not text.endswith("\n"):
                fp.write("\n")
    if policy is None or not checkfc.is_file():
        result = UNKNOWN
        detail = "effective_policy_or_checkfc_missing"
    elif not paths:
        result = UNKNOWN
        detail = "service_context_inputs_missing"
    else:
        rc, _ = run(
            [str(checkfc), "-s", str(policy), str(merged)],
            out / f"gate-c-{side}.log",
        )
        result = PASS if rc == 0 else FUNCTIONAL_RISK
        detail = f"checkfc_rc={rc}"
    vt = vintf_text(stock_vendor, stock_odm)
    missing = []
    if side == "c2":
        for key in rows:
            if ("imsSlot" in key or "mtkradioex" in key) and key not in vt:
                missing.append(key)
    write_tsv(out / f"gate-c-{side}-missing-vintf.tsv", ["service"], [[x] for x in missing])
    if result == PASS and missing:
        return Gate("C", side, FUNCTIONAL_RISK, f"missing_vintf_instances={len(missing)}")
    return Gate("C", side, result, detail + f" missing_vintf={len(missing)}")


def prop_values(root: Path, key: str) -> set[str]:
    vals = set()
    search_roots = [root]
    search_roots += [path for _part, path in partition_roots(root)]
    seen: set[Path] = set()
    for base in search_roots:
        try:
            base = base.resolve()
        except OSError:
            continue
        if base in seen or not base.is_dir():
            continue
        seen.add(base)
        candidates = list(base.rglob("*.prop"))
        candidates += list(base.rglob("build.prop"))
        candidates += list(base.rglob("default.prop"))
        for path in sorted(set(candidates)):
            if not path.is_file() or path.stat().st_size > 4 * 1024 * 1024:
                continue
            for raw in path.read_text(
                encoding="utf-8",
                errors="replace",
            ).splitlines():
                if raw.startswith(key + "="):
                    vals.add(raw.split("=", 1)[1].strip())
    return vals


def privapp_blocks(
    roots: list[tuple[str, Path]],
    package: str | None = None,
) -> list[tuple[str, str, set[str], set[str], str]]:
    found = []
    for part, root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*.xml"):
            if "permissions" not in str(path):
                continue
            try:
                tree = ET.parse(path)
            except ET.ParseError:
                continue
            for node in tree.getroot().iter("privapp-permissions"):
                pkg = node.attrib.get("package", "")
                if package is not None and pkg != package:
                    continue
                allow = {
                    n.attrib.get("name", "")
                    for n in node.findall("permission")
                    if n.attrib.get("name")
                }
                deny = {
                    n.attrib.get("name", "")
                    for n in node.findall("deny-permission")
                    if n.attrib.get("name")
                }
                found.append((part, pkg, allow, deny, str(path)))
    return found


def partition_roots(root: Path) -> list[tuple[str, Path]]:
    out = []
    for part in ("system", "system_ext", "product"):
        path = root_path(root, part, "")
        if path is not None and path.is_dir():
            out.append((part, path))
    return out


def privileged_apks(root: Path) -> list[tuple[str, Path]]:
    out = []
    for part, base in partition_roots(root):
        for path in sorted((base / "priv-app").glob("**/*.apk")):
            if path.is_file():
                out.append((part, path))
    return out


def cert_digest(apksigner: Path, apk: Path) -> str | None:
    if not apksigner.is_file():
        return None
    rc, text = run([str(apksigner), "verify", "--print-certs", str(apk)])
    if rc != 0:
        return None
    match = re.search(
        r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)",
        text,
    )
    return match.group(1).lower() if match else None


def seapp_candidates(root: Path, package: str) -> list[tuple[str, str]]:
    rows = []
    for path in find_all(
        root,
        (
            "plat_seapp_contexts",
            "system_ext_seapp_contexts",
            "product_seapp_contexts",
        ),
    ):
        for raw in path.read_text(
            encoding="utf-8",
            errors="replace",
        ).splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            fields = dict(
                token.split("=", 1)
                for token in line.split()
                if "=" in token
            )
            user = fields.get("user", "")
            name = fields.get("name", "")
            seinfo = fields.get("seinfo", "")
            if user and user != "radio":
                continue
            if name and name != package:
                continue
            if seinfo and not seinfo.startswith("platform"):
                continue
            domain = fields.get("domain", "")
            if domain:
                rows.append((domain, f"{path}:{line}"))
    return rows


def aapt_badging(aapt2: Path, apk: Path) -> tuple[str, str]:
    rc, text = run([str(aapt2), "dump", "badging", str(apk)])
    if rc != 0:
        raise D0Error(f"aapt2_badging_rc={rc}:{apk}")
    m = re.search(r"package:\s+name='([^']+)'", text)
    if not m:
        raise D0Error(f"package_name_missing={apk}")
    return m.group(1), text


def requested_permissions(aapt2: Path, apk: Path) -> set[str]:
    rc, text = run([str(aapt2), "dump", "permissions", str(apk)])
    if rc != 0:
        raise D0Error(f"aapt2_permissions_rc={rc}:{apk}")
    return set(re.findall(r"name='([^']+)'", text))


def manifest_tree(aapt2: Path, apk: Path) -> str:
    commands = [
        [str(aapt2), "dump", "xmltree", "--file", "AndroidManifest.xml", str(apk)],
        [str(aapt2), "dump", "xmltree", str(apk), "--file", "AndroidManifest.xml"],
    ]
    for cmd in commands:
        rc, text = run(cmd)
        if rc == 0 and "manifest" in text:
            return text
    raise D0Error(f"aapt2_xmltree_failed={apk}")


def privileged_framework_permissions(aapt2: Path, framework: Path) -> set[str]:
    text = manifest_tree(aapt2, framework)
    blocks = re.split(r"(?=\n\s*E: permission\b)", "\n" + text)
    out = set()
    for block in blocks:
        if "E: permission" not in block:
            continue
        name = re.search(r"android:name[^=]*=\"([^\"]+)\"", block)
        level = re.search(r"android:protectionLevel[^=]*=([^\n]+)", block)
        if not name or not level:
            continue
        raw = level.group(1)
        privileged = "privileged" in raw.lower()
        m = re.search(r"0x([0-9a-fA-F]+)", raw)
        if m and (int(m.group(1), 16) & 0x10):
            privileged = True
        if privileged:
            out.add(name.group(1))
    return out


def find_framework(root: Path) -> Path | None:
    return root_path(root, "system", "framework/framework-res.apk")


def find_ims(root: Path) -> Path | None:
    for rel in (
        "priv-app/ImsService/ImsService.apk",
        "priv-app/ImsService/ImsService-resigned.apk",
    ):
        p = root_path(root, "system_ext", rel)
        if p is not None and p.is_file():
            return p
    hits = list(root.rglob("ImsService*.apk"))
    return hits[0] if len(hits) == 1 else None


def gate_d_n1f(
    root: Path,
    aapt2: Path,
    apksigner: Path,
    out: Path,
) -> Gate:
    framework = find_framework(root)
    if framework is None:
        return Gate("D", "n1f", UNKNOWN, "framework_res_missing")
    try:
        privileged = privileged_framework_permissions(aapt2, framework)
    except D0Error as exc:
        return Gate("D", "n1f", UNKNOWN, str(exc))

    roots = partition_roots(root)
    blocks = privapp_blocks(roots)
    enforcement = prop_values(root, "ro.control_privapp_permissions")
    if len(enforcement) != 1:
        return Gate(
            "D",
            "n1f",
            UNKNOWN,
            "privapp_enforcement_values="
            + (",".join(sorted(enforcement)) or "NONE"),
        )
    enforce = "enforce" in next(iter(enforcement)).lower()

    rows = []
    contradictions = []
    for part, apk in privileged_apks(root):
        try:
            pkg, _ = aapt_badging(aapt2, apk)
            required = requested_permissions(aapt2, apk) & privileged
        except D0Error as exc:
            return Gate("D", "n1f", UNKNOWN, f"control_apk_parse={apk}:{exc}")
        matches = [b for b in blocks if b[1] == pkg and b[0] == part]
        allow = set().union(*(b[2] for b in matches)) if matches else set()
        deny = set().union(*(b[3] for b in matches)) if matches else set()
        missing = required - allow - deny
        rows.append(
            [
                part,
                pkg,
                len(required),
                len(allow),
                len(deny),
                ",".join(sorted(missing)) or "NONE",
            ]
        )
        if enforce and missing:
            contradictions.append(f"{part}:{pkg}")

    write_tsv(
        out / "gate-d-n1f-privapp.tsv",
        [
            "partition",
            "package",
            "required_privileged",
            "allow",
            "deny",
            "missing",
        ],
        rows,
    )
    (out / "gate-d-n1f.env").write_text(
        "PRIVAPP_ENFORCEMENT="
        + next(iter(enforcement))
        + "\n"
        + f"PRIVILEGED_APP_COUNT={len(rows)}\n",
        encoding="utf-8",
    )
    if contradictions:
        # N1F physically booted; an apparent fatal contradiction means the
        # harness has not modelled permission enforcement correctly.
        return Gate(
            "D",
            "n1f",
            UNKNOWN,
            "known_good_control_permission_contradiction="
            + ",".join(contradictions),
        )
    return Gate(
        "D",
        "n1f",
        PASS,
        f"privileged_apps={len(rows)} enforcement={next(iter(enforcement))}",
    )


def gate_d_c2(
    root: Path,
    stock_runtime: Path,
    aapt2: Path,
    apksigner: Path,
    out: Path,
) -> Gate:
    ims = find_ims(root)
    framework = find_framework(root)
    if ims is None or framework is None:
        return Gate("D", "c2", UNKNOWN, "ims_or_framework_missing")
    try:
        package, badging = aapt_badging(aapt2, ims)
        req = requested_permissions(aapt2, ims)
        privileged = privileged_framework_permissions(aapt2, framework)
        mtext = manifest_tree(aapt2, ims)
    except D0Error as exc:
        return Gate("D", "c2", UNKNOWN, str(exc))
    if package != "com.mediatek.ims":
        return Gate(
            "D",
            "c2",
            BOOT_FATAL,
            f"unexpected_ims_package={package}",
        )

    candidate_blocks = privapp_blocks(partition_roots(root), package)
    stock_blocks = privapp_blocks(partition_roots(stock_runtime), package)

    required = req & privileged
    c2_same = [b for b in candidate_blocks if b[0] == "system_ext"]
    c2_wrong = [b for b in candidate_blocks if b[0] != "system_ext"]
    c2_allow = set().union(*(b[2] for b in c2_same)) if c2_same else set()
    c2_deny = set().union(*(b[3] for b in c2_same)) if c2_same else set()
    c2_wrong_covered = (
        set().union(*(b[2] | b[3] for b in c2_wrong))
        if c2_wrong
        else set()
    )
    missing = required - c2_allow - c2_deny

    c2_enforcement = prop_values(root, "ro.control_privapp_permissions")
    stock_enforcement = prop_values(
        stock_runtime,
        "ro.control_privapp_permissions",
    )

    write_tsv(
        out / "gate-d-c2-privapp.tsv",
        ["source", "partition", "path", "allow", "deny"],
        [
            [
                "C2",
                b[0],
                b[4],
                ",".join(sorted(b[2])) or "NONE",
                ",".join(sorted(b[3])) or "NONE",
            ]
            for b in candidate_blocks
        ]
        + [
            [
                "STOCK",
                b[0],
                b[4],
                ",".join(sorted(b[2])) or "NONE",
                ",".join(sorted(b[3])) or "NONE",
            ]
            for b in stock_blocks
        ],
    )
    (out / "gate-d-c2-badging.txt").write_text(
        badging,
        encoding="utf-8",
    )
    (out / "gate-d-c2-manifest-tree.txt").write_text(
        mtext,
        encoding="utf-8",
    )
    write_tsv(
        out / "gate-d-c2-permissions.tsv",
        ["kind", "permission"],
        [["REQUIRED_PRIVILEGED", p] for p in sorted(required)]
        + [["SYSTEM_EXT_ALLOW", p] for p in sorted(c2_allow)]
        + [["SYSTEM_EXT_DENY", p] for p in sorted(c2_deny)]
        + [["WRONG_PARTITION_COVERAGE", p] for p in sorted(c2_wrong_covered)]
        + [["MISSING_SYSTEM_EXT", p] for p in sorted(missing)],
    )

    ims_digest = cert_digest(apksigner, ims)
    framework_digest = cert_digest(apksigner, framework)
    sig_result = "UNKNOWN"
    if ims_digest and framework_digest:
        sig_result = "PASS" if ims_digest == framework_digest else "FAIL"

    seapp = seapp_candidates(root, package)
    domains = sorted({domain for domain, _line in seapp})
    seapp_result = (
        "PASS_UNIQUE_DOMAIN"
        if len(domains) == 1
        else "UNKNOWN_NO_MATCH"
        if not domains
        else "UNKNOWN_AMBIGUOUS_DOMAIN"
    )
    write_tsv(
        out / "gate-d-c2-seapp.tsv",
        ["domain", "matching_rule"],
        [[domain, rule] for domain, rule in seapp],
    )

    (out / "gate-d-c2-shareduid.env").write_text(
        f"PLATFORM_SIGNATURE_MATCH={sig_result}\n"
        f"IMS_CERT_SHA256={ims_digest or 'UNKNOWN'}\n"
        f"FRAMEWORK_CERT_SHA256={framework_digest or 'UNKNOWN'}\n"
        f"SHARED_UID_PHONE={'YES' if 'android.uid.phone' in mtext else 'NO_OR_UNPROVEN'}\n"
        f"SEAPP_RESULT={seapp_result}\n"
        f"SEAPP_DOMAINS={','.join(domains) or 'NONE'}\n"
        f"C2_PRIVAPP_ENFORCEMENT={','.join(sorted(c2_enforcement)) or 'NONE'}\n"
        f"STOCK_PRIVAPP_ENFORCEMENT={','.join(sorted(stock_enforcement)) or 'NONE'}\n",
        encoding="utf-8",
    )

    if len(c2_enforcement) != 1:
        return Gate(
            "D",
            "c2",
            UNKNOWN,
            "privapp_enforcement_values="
            + (",".join(sorted(c2_enforcement)) or "NONE"),
        )
    enforcement_value = next(iter(c2_enforcement))
    enforce = "enforce" in enforcement_value.lower()

    if sig_result == "FAIL":
        return Gate("D", "c2", BOOT_FATAL, "ims_platform_signature_mismatch")
    if sig_result == "UNKNOWN":
        return Gate("D", "c2", UNKNOWN, "ims_platform_signature_unproven")
    if "android.uid.phone" not in mtext:
        return Gate("D", "c2", BOOT_FATAL, "ims_shared_uid_phone_missing")
    if enforce and missing:
        return Gate(
            "D",
            "c2",
            BOOT_FATAL,
            f"system_ext_privapp_missing={len(missing)} "
            f"wrong_partition_coverage={len(c2_wrong_covered)}",
        )
    if missing:
        return Gate(
            "D",
            "c2",
            FUNCTIONAL_RISK,
            f"missing_allowlist={len(missing)} enforcement={enforcement_value}",
        )
    if not stock_blocks:
        return Gate("D", "c2", UNKNOWN, "stock_ims_privapp_authority_missing")
    return Gate(
        "D",
        "c2",
        PASS,
        f"required={len(required)} covered={len(c2_allow | c2_deny)} "
        f"signature=PASS seapp={seapp_result}",
    )


def classpath_for_side(side: str, root: Path, apex_root: Path, out: Path) -> tuple[Gate, list[tuple[str, Path]]]:
    try:
        deriver = load_deriver()
    except Exception as exc:
        return Gate("E", side, UNKNOWN, f"deriver_load={exc}"), []
    fragment = root_path(root, "system", "etc/classpaths/bootclasspath.pb")
    if fragment is None:
        return Gate("E", side, UNKNOWN, "system_bootclasspath_fragment_missing"), []
    if not apex_root.is_dir():
        return Gate("E", side, UNKNOWN, f"side_apex_root_missing={apex_root}"), []
    try:
        system_jars = deriver.boot_jars(fragment, 36)
        apex_fragments = deriver.apex_fragments(apex_root, 36)
    except Exception as exc:
        return Gate("E", side, UNKNOWN, f"classpath_parse={exc}"), []

    art = [f for f in apex_fragments if f.module == "com.android.art"]
    other = sorted((f for f in apex_fragments if f.module != "com.android.art"), key=lambda f: f.module)
    if len(art) != 1:
        return Gate("E", side, UNKNOWN, f"art_fragment_count={len(art)}"), []

    rows: list[tuple[str, Path]] = []
    try:
        for frag in art:
            for jar in frag.jars:
                rows.append((jar.path, deriver.c3a_apex_jar(frag, jar.path)))
    except Exception as exc:
        return Gate("E", side, UNKNOWN, f"art_apex_jar_resolve={exc}"), []
    for jar in system_jars:
        device = jar.path
        if device.startswith("/apex/"):
            module = deriver.module_from_apex_path(device)
            frag = next((f for f in apex_fragments if f.module == module), None)
            try:
                aroot = frag.root if frag is not None else deriver.find_extracted_apex_root(apex_root, module)
                host = deriver.c3a_apex_jar_from_root(aroot, module, device)
            except Exception as exc:
                return Gate("E", side, UNKNOWN, f"apex_path_resolve={device}:{exc}"), []
        elif device.startswith("/system_ext/"):
            host = root_path(root, "system_ext", device.removeprefix("/system_ext/"))
        elif device.startswith("/product/"):
            host = root_path(root, "product", device.removeprefix("/product/"))
        elif device.startswith("/system/"):
            host = root_path(root, "system", device.removeprefix("/system/"))
        else:
            host = None
        if host is None or not host.is_file():
            return Gate("E", side, BOOT_FATAL, f"runtime_classpath_entry_missing={device}"), []
        rows.append((device, host))
    try:
        for frag in other:
            for jar in frag.jars:
                if any(d == jar.path for d, _h in rows):
                    continue
                rows.append((jar.path, deriver.c3a_apex_jar(frag, jar.path)))
    except Exception as exc:
        return Gate("E", side, UNKNOWN, f"apex_boot_jar_resolve={exc}"), []

    devices = [d for d, _h in rows]
    if len(devices) != len(set(devices)):
        return Gate("E", side, BOOT_FATAL, "duplicate_runtime_classpath_path"), []
    write_tsv(out / f"gate-e-{side}-classpath.tsv", ["device_path", "host_path", "sha256"], [[d, str(h), sha256(h)] for d, h in rows])
    updatable = root_path(root, "system", "etc/updatable-bcp-packages.txt")
    prop_refs = prop_values(root, "dalvik.vm.dex2oat-updatable-bcp-packages-file")
    updatable_status = "PRESENT" if updatable is not None and updatable.is_file() else "ABSENT"
    (out / f"gate-e-{side}-updatable-bcp.env").write_text(
        f"UPDATABLE_BCP_PACKAGES={updatable_status}\n"
        f"UPDATABLE_BCP_PROPERTY_VALUES={','.join(sorted(prop_refs)) or 'NONE'}\n",
        encoding="utf-8",
    )
    if prop_refs and updatable_status == "ABSENT":
        return Gate("E", side, BOOT_FATAL, "configured_updatable_bcp_packages_file_missing"), rows
    return Gate("E", side, PASS, f"classpath_entries={len(rows)} updatable_bcp={updatable_status}"), rows


def duplicate_classes(side: str, rows: list[tuple[str, Path]], out: Path) -> tuple[int, list[list[str]]]:
    static_path = ROOT / "build/titan2/n1i_static.py"
    spec = importlib.util.spec_from_file_location("n1i_d0_static", static_path)
    if spec is None or spec.loader is None:
        return -1, []
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    owners: dict[str, list[str]] = {}
    for device, host in rows:
        try:
            container = mod.load_container(host)
        except Exception:
            continue
        for _entry, dex in container.dexes:
            for cd in dex.classes:
                owners.setdefault(cd.descriptor, []).append(device)
    dup = [[cls, ";".join(v)] for cls, v in sorted(owners.items()) if len(v) > 1]
    write_tsv(out / f"gate-e-{side}-duplicates.tsv", ["class", "owners"], dup)
    return len(dup), dup



def gate_e_member_c2(
    root: Path,
    rows: list[tuple[str, Path]],
    aapt2: Path,
    pinned_b2: Path,
    out: Path,
) -> Gate:
    devices = [device for device, _host in rows]
    if COMMON not in devices or IMS_BASE not in devices:
        return Gate(
            "E_MEMBER",
            "c2",
            FUNCTIONAL_RISK,
            "mtk_jars_not_both_on_current_bootclasspath",
        )

    ims = find_ims(root)
    if ims is None:
        return Gate("E_MEMBER", "c2", UNKNOWN, "ims_apk_missing")

    manifest = out / "gate-e-c2-bootclasspath-manifest.tsv"
    manifest.write_text(
        "".join(f"{device}\t{host}\n" for device, host in rows),
        encoding="utf-8",
    )
    badging = out / "gate-e-c2-ims-badging.txt"
    rc, _ = run(
        [str(aapt2), "dump", "badging", str(ims)],
        badging,
    )
    if rc != 0:
        return Gate(
            "E_MEMBER",
            "c2",
            UNKNOWN,
            f"aapt2_badging_rc={rc}",
        )

    audit = ROOT / "build/titan2/audit-n1i-c1-runtime-linkage.py"
    log = out / "gate-e-c2-member-linkage.txt"
    rc, text = run(
        [
            sys.executable,
            str(audit),
            "--bootclasspath-manifest",
            str(manifest),
            "--ims-apk",
            str(ims),
            "--badging",
            str(badging),
            "--members-tool",
            str(pinned_b2 / "n1i-b2-members.py"),
        ],
        log,
    )
    if rc == 0 and "PASS_ALL_RESOLVED" in text:
        return Gate("E_MEMBER", "c2", PASS, "all_members_resolved")
    if rc == 1:
        unresolved = re.search(
            r"N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT="
            r"FAIL_UNRESOLVED_MEMBERS count=(\d+)",
            text,
        )
        duplicates = re.search(
            r"N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT="
            r"FAIL_IMPORTED_BOOT_DUPLICATE_CLASSES count=(\d+)",
            text,
        )
        if unresolved:
            return Gate(
                "E_MEMBER",
                "c2",
                FUNCTIONAL_RISK,
                "unresolved_members="
                + unresolved.group(1)
                + ":boot_caller_not_proven",
            )
        if duplicates:
            return Gate(
                "E_MEMBER",
                "c2",
                FUNCTIONAL_RISK,
                "imported_boot_duplicate_classes="
                + duplicates.group(1)
                + ":boot_effect_not_proven",
            )
        return Gate(
            "E_MEMBER",
            "c2",
            FUNCTIONAL_RISK,
            "member_audit_nonzero_without_boot_reachability_proof",
        )
    return Gate(
        "E_MEMBER",
        "c2",
        UNKNOWN,
        f"member_audit_rc={rc}",
    )


def combine_gate_e(base: Gate, member: Gate | None) -> Gate:
    if base.result in (BOOT_FATAL, UNKNOWN):
        return base
    if member is None:
        return base
    if member.result == UNKNOWN:
        return Gate(
            "E",
            base.side,
            UNKNOWN,
            f"{base.detail};member={member.detail}",
        )
    if base.result == FUNCTIONAL_RISK or member.result == FUNCTIONAL_RISK:
        return Gate(
            "E",
            base.side,
            FUNCTIONAL_RISK,
            f"{base.detail};member={member.detail}",
        )
    return Gate(
        "E",
        base.side,
        PASS,
        f"{base.detail};member={member.detail}",
    )

def gate_f_c2(root: Path, aapt2: Path, out: Path) -> Gate:
    ims = find_ims(root)
    if ims is None:
        return Gate("F", "c2", UNKNOWN, "ims_apk_missing")
    try:
        _pkg, badging = aapt_badging(aapt2, ims)
        tree = manifest_tree(aapt2, ims)
    except D0Error as exc:
        return Gate("F", "c2", UNKNOWN, str(exc))
    flags = {
        "PERSISTENT": "android:persistent" in tree and ("0xffffffff" not in tree),
        "DIRECT_BOOT_AWARE": "directBootAware" in tree,
        "SHARED_UID_PHONE": "android.uid.phone" in tree,
        "PROCESS_PHONE": "com.android.phone" in tree,
        "USES_LIBRARY": "uses-library" in tree or "uses-library" in badging,
        "USES_NATIVE_LIBRARY": "uses-native-library" in tree or "uses-native-library" in badging,
    }
    (out / "gate-f-c2.env").write_text("".join(f"{k}={'YES' if v else 'NO'}\n" for k, v in flags.items()), encoding="utf-8")
    boot_reachable = flags["PERSISTENT"] or flags["DIRECT_BOOT_AWARE"] or flags["PROCESS_PHONE"]
    return Gate("F", "c2", PASS, f"boot_reachable={'YES' if boot_reachable else 'NO'}")


def find_mtk_jars(root: Path) -> tuple[Path | None, Path | None]:
    return (
        root_path(root, "system_ext", "framework/mediatek-common.jar"),
        root_path(root, "system_ext", "framework/mediatek-ims-base.jar"),
    )


def apex_lib_dirs(apex_root: Path) -> list[Path]:
    out = []
    if not apex_root.is_dir():
        return out
    for path in sorted(apex_root.glob("*.apex")):
        for rel in ("lib64", "lib"):
            candidate = path / rel
            if candidate.is_dir():
                out.append(candidate)
    return out


def gate_g_c2(
    root: Path,
    stock_vendor: Path,
    stock_odm: Path | None,
    apex_root: Path,
    aapt2: Path,
    pinned_b2: Path,
    out: Path,
) -> Gate:
    ims = find_ims(root)
    common, ims_base = find_mtk_jars(root)
    if ims is None:
        return Gate("G", "c2", UNKNOWN, "ims_apk_missing")
    if common is None or ims_base is None:
        return Gate("G", "c2", UNKNOWN, "mtk_framework_jar_missing")

    scanner = ROOT / "build/titan2/scan-n1i-d0-native-loads.py"
    scan_out = out / "gate-g-c2-jar-loads"
    rc, _ = run(
        [
            sys.executable,
            str(scanner),
            "--container",
            str(common),
            "--container",
            str(ims_base),
            "--out",
            str(scan_out),
            "--tool-dir",
            str(pinned_b2),
        ],
        out / "gate-g-c2-jar-loads.log",
    )
    if rc != 0:
        return Gate("G", "c2", UNKNOWN, f"jar_native_load_scan_rc={rc}")
    scan_env = read_env(scan_out / "SUMMARY.env")
    jar_constant = int(
        scan_env.get("N1I_D0_NATIVE_LOAD_SCAN_CONSTANT", "-1")
    )
    jar_dynamic = int(
        scan_env.get("N1I_D0_NATIVE_LOAD_SCAN_DYNAMIC", "-1")
    )
    if jar_constant < 0 or jar_dynamic < 0:
        return Gate("G", "c2", UNKNOWN, "jar_native_load_scan_summary_missing")

    tool = pinned_b2 / "n1i-b2-native.py"
    badging = out / "gate-g-c2-badging.txt"
    rc, _ = run(
        [str(aapt2), "dump", "badging", str(ims)],
        badging,
    )
    if rc != 0:
        return Gate("G", "c2", UNKNOWN, f"aapt2_badging_rc={rc}")

    lib_args: list[str] = []
    for part in ("system", "system_ext", "product"):
        d = root_path(root, part, "lib64")
        if d is not None and d.is_dir():
            lib_args += ["--lib-dir", f"{part}={d}"]

    vendor_lib = root_path(stock_vendor, "vendor", "lib64")
    if vendor_lib is not None and vendor_lib.is_dir():
        lib_args += ["--lib-dir", f"vendor={vendor_lib}"]
    if stock_odm is not None:
        odm_lib = root_path(stock_odm, "odm", "lib64")
        if odm_lib is not None and odm_lib.is_dir():
            lib_args += ["--lib-dir", f"odm={odm_lib}"]
    for d in apex_lib_dirs(apex_root):
        lib_args += ["--lib-dir", f"apex={d}"]

    visible_args: list[str] = []
    for part in ("system", "system_ext", "product"):
        for rel in (
            "etc/public.libraries.txt",
            "etc/public.libraries-company.txt",
        ):
            candidate = root_path(root, part, rel)
            if candidate is not None and candidate.is_file():
                visible_args += [
                    "--namespace-visible-list",
                    str(candidate),
                ]

    a4 = ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"
    a4_rows = [
        line.strip()
        for line in a4.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    a4_basename = out / "gate-g-a4-basenames.txt"
    a4_basename.write_text(
        "".join(f"{Path(row).name}\n" for row in a4_rows),
        encoding="utf-8",
    )

    g_out = out / "gate-g-c2-native"
    cmd = [
        sys.executable,
        str(tool),
        "--side",
        "c3a",
        "--apk",
        str(ims),
        "--badging",
        str(badging),
        "--search-superset",
        str(a4_basename),
        "--out",
        str(g_out),
        *lib_args,
        *visible_args,
    ]
    rc, _ = run(cmd, out / "gate-g-c2.log")
    if rc != 0:
        return Gate("G", "c2", UNKNOWN, f"b2_native_rc={rc}")

    env = read_env(g_out / "NATIVE_SUMMARY.env")
    unresolved = env.get(
        "N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED",
        "UNKNOWN",
    )
    missing = env.get("N1I_B2_NATIVE_NOT_FOUND", "UNKNOWN")
    namespace_unproven = env.get(
        "N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN",
        "UNKNOWN",
    )
    candidate_count = env.get(
        "N1I_B2_NATIVE_EVIDENCE_CANDIDATE_COUNT",
        "UNKNOWN",
    )

    closure_rows: dict[str, dict[str, str]] = {}
    closure = g_out / "NATIVE_CLOSURE.tsv"
    if closure.is_file():
        with closure.open(encoding="utf-8", newline="") as fp:
            reader = csv.DictReader(fp, delimiter="\t")
            for row in reader:
                closure_rows[row["library"]] = row

    retirement = []
    for original in a4_rows:
        name = Path(original).name
        row = closure_rows.get(name)
        if row is None or row.get("status") != "FOUND":
            cls = "SEARCH_SUPERSET_ONLY"
            evidence = "NOT_IN_B2_CLOSURE"
        else:
            admitted_by = row.get("admitted_by", "")
            if "DT_NEEDED" in admitted_by:
                cls = "TRANSITIVE_REQUIRED"
            else:
                cls = "B2_REQUIRED"
            evidence = admitted_by or "B2_FOUND"
        retirement.append([original, name, cls, evidence])
    write_tsv(
        out / "A4_RETIREMENT.tsv",
        ["a4_path", "library", "classification", "evidence"],
        retirement,
    )

    g2_status = (
        "NOT_APPLICABLE_NO_NONPLATFORM_NATIVE"
        if candidate_count == "0"
        else "UNKNOWN_NOT_IMPLEMENTED"
    )
    (out / "gate-g2-status.env").write_text(
        f"SYMBOL_VERSION_CHECK={g2_status}\n"
        f"LINKER_NAMESPACE_CHECK={g2_status}\n"
        f"N1I_D0_G2_NATIVE_CANDIDATE_COUNT={candidate_count}\n",
        encoding="utf-8",
    )

    if jar_constant or jar_dynamic:
        return Gate(
            "G",
            "c2",
            UNKNOWN,
            f"framework_jar_native_loads_unclosed="
            f"constant:{jar_constant},dynamic:{jar_dynamic}",
        )
    if unresolved == "UNKNOWN" or missing == "UNKNOWN":
        return Gate("G", "c2", UNKNOWN, "b2_summary_incomplete")
    if unresolved != "0":
        return Gate(
            "G",
            "c2",
            FUNCTIONAL_RISK,
            f"dynamic_load_unresolved={unresolved}",
        )
    if missing != "NONE":
        return Gate(
            "G",
            "c2",
            FUNCTIONAL_RISK,
            f"native_not_found={missing}",
        )
    if namespace_unproven not in ("NONE", "UNKNOWN"):
        return Gate(
            "G",
            "c2",
            FUNCTIONAL_RISK,
            f"namespace_unproven={namespace_unproven}",
        )
    return Gate(
        "G",
        "c2",
        PASS,
        f"evidence_candidates={candidate_count} "
        "jar_native_loads=0",
    )


def overall(gates: list[Gate]) -> tuple[str, str]:
    by = {(g.name, g.side): g for g in gates}
    critical = ("A", "B", "D", "E")
    for name in critical:
        c = by.get((name, "c2"))
        n = by.get((name, "n1f"))
        if c is None or c.result == UNKNOWN or n is None or n.result in (UNKNOWN, BOOT_FATAL):
            return "NOT_CLOSED", f"critical_gate_unclosed={name}"
    defects = []
    for name in critical:
        c = by[(name, "c2")]
        n = by[(name, "n1f")]
        if c.result == BOOT_FATAL and n.result == PASS:
            defects.append(name)
    if defects:
        return "DEFECT_FOUND", "boot_fatal_gates=" + ",".join(defects)
    return "NO_FATAL_DEFECT_FOUND", "critical_gates_closed_without_candidate_only_fatal"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs-dir", type=Path, required=True)
    ap.add_argument("--android-root", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--c1-root", type=Path)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        assert context_conflicts({"x": [("a", "1"), ("b", "2")]}) == [("x", "a,b")]
        assert context_conflicts({"x": [("a", "1"), ("a", "2")]}) == []
        print("N1I_D0_0H_SELFTEST=PASS")
        return 0

    if not git_clean():
        raise D0Error("source_worktree_not_clean")
    if not verify_b2_provenance():
        raise D0Error("b2_provenance_not_ancestor")

    inputs = args.inputs_dir.resolve()
    env_path = inputs / "INPUTS.env"
    sums = inputs / "SHA256SUMS.txt"
    if not env_path.is_file() or not sums.is_file():
        raise D0Error("prepared_input_manifest_missing")
    rc, _ = run(
        ["sha256sum", "-c", "SHA256SUMS.txt"],
        None,
        cwd=inputs,
    )
    if rc != 0:
        raise D0Error("prepared_input_manifest_seal_invalid")
    env = read_env(env_path)
    if env.get("C2_BUILD_SOURCE_COMMIT") != C2_BUILD_SOURCE:
        raise D0Error("c2_build_source_binding_mismatch")
    if env.get("N1F_SYSTEM_SHA256") != N1F_SHA or env.get("C2_SYSTEM_SHA256") != C2_SHA:
        raise D0Error("system_image_authority_mismatch")

    roots = {k: Path(env[k]) for k in ("N1F_ROOT", "C2_ROOT", "STOCK_SYSTEM_ROOT", "STOCK_SYSTEM_EXT_ROOT", "STOCK_PRODUCT_ROOT", "STOCK_VENDOR_ROOT", "STOCK_RUNTIME_ROOT")}
    apex_roots = {
        "n1f": Path(env.get("N1F_APEX_ROOT", "")),
        "c2": Path(env.get("C2_APEX_ROOT", "")),
        "stock": Path(env.get("STOCK_APEX_ROOT", "")),
    }
    stock_odm = Path(env.get("STOCK_ODM_ROOT", ""))
    stock_odm = stock_odm if stock_odm.is_dir() else None
    for k, p in roots.items():
        if not p.is_dir():
            raise D0Error(f"prepared_root_missing={k}:{p}")
    for side, apex_root in apex_roots.items():
        if not apex_root.is_dir():
            raise D0Error(f"prepared_apex_root_missing={side}:{apex_root}")
        apex_sums = apex_root / "SHA256SUMS.txt"
        if not apex_sums.is_file():
            raise D0Error(f"prepared_apex_seal_missing={side}")
        arc, _ = run(
            ["sha256sum", "-c", "SHA256SUMS.txt"],
            None,
            cwd=apex_root,
        )
        if arc != 0:
            raise D0Error(f"prepared_apex_seal_invalid={side}")
    if not args.android_root.is_dir():
        raise D0Error("android_root_missing")

    out = args.out.resolve()
    if out.exists():
        raise D0Error(f"output_exists={out}")
    out.mkdir(parents=True)
    pinned_b2 = materialize_pinned_b2(out)

    print("===== TITAN 2 N1I-D0-0H HOST BOOT-COMPATIBILITY CLOSURE =====")
    print("BUILD_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("MODE_TRANSITION_AUTHORIZED=NO")
    print("REBOOT_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print(f"C2_BUILD_SOURCE_COMMIT={C2_BUILD_SOURCE}")
    print(f"B2_ANALYZER_PROVENANCE_COMMIT={B2_PROVENANCE}")

    composition = source_composition(out)
    c1_root = (
        args.c1_root.resolve()
        if args.c1_root is not None and args.c1_root.is_dir()
        else None
    )
    composition_delta(
        roots["N1F_ROOT"],
        roots["C2_ROOT"],
        c1_root,
        out,
    )
    print("N1I_D0_B0_COMPOSITION=PASS")
    print(
        "N1I_D0_B0_C1_BINARY_CONTROL="
        + (
            "PRESENT"
            if c1_root is not None
            else "UNKNOWN_NOT_RETAINED"
        )
    )
    print(f"N1I_D0_B0_TELEPHONYMETRICS_C1={composition['C1_TELEPHONYMETRICS']}")
    print(f"N1I_D0_B0_TELEPHONYMETRICS_C2={composition['C2_TELEPHONYMETRICS']}")

    aosp_bin = Path(os.environ.get("SABLE_AOSP_HOST_BIN", "/srv/data/sable-host-tools/android/aosp-host/bin"))
    secilc = Path(os.environ.get("SABLE_SECILC", str(aosp_bin / "secilc")))
    property_checker = aosp_bin / "property_info_checker"
    checkfc = aosp_bin / "checkfc"
    aapt2 = Path(os.environ.get("SABLE_ANDROID_BUILD_TOOLS", "/srv/data/sable-host-tools/android/sdk/build-tools/36.0.0")) / "aapt2"
    apksigner = aapt2.parent / "apksigner"

    for p, label in ((secilc, "secilc"), (aapt2, "aapt2")):
        if not p.is_file():
            raise D0Error(f"required_canonical_tool_missing={label}:{p}")

    gates: list[Gate] = []
    policies: dict[str, Path | None] = {}
    for side, root in (("n1f", roots["N1F_ROOT"]), ("c2", roots["C2_ROOT"])):
        a0, ag, a2, policy = compile_policy(
            side,
            root,
            roots["STOCK_VENDOR_ROOT"],
            stock_odm,
            args.android_root.resolve(),
            secilc,
            out,
        )
        gates.extend((a0, ag, a2))
        policies[side] = policy
        gates.append(gate_b(side, root, roots["STOCK_VENDOR_ROOT"], stock_odm, policy, property_checker, out, ag.result))
        gates.append(gate_c(side, root, roots["STOCK_VENDOR_ROOT"], stock_odm, policy, checkfc, out))

    gates.append(gate_d_n1f(roots["N1F_ROOT"], aapt2, apksigner, out))
    gates.append(
        gate_d_c2(
            roots["C2_ROOT"],
            roots["STOCK_RUNTIME_ROOT"],
            aapt2,
            apksigner,
            out,
        )
    )

    # Gate F emits C2 boot-role evidence consumed by Gate E severity
    # review. N1F has no OEM IMS package by design.
    gates.append(Gate("F", "n1f", NOT_APPLICABLE, "OEM_IMS_ABSENT"))
    f_c2 = gate_f_c2(roots["C2_ROOT"], aapt2, out)
    gates.append(f_c2)

    # Gate E must analyze each side's own pinned APEX runtime view.
    e_rows: dict[str, list[tuple[str, Path]]] = {}
    for side, root in (
        ("n1f", roots["N1F_ROOT"]),
        ("c2", roots["C2_ROOT"]),
        ("stock", roots["STOCK_RUNTIME_ROOT"]),
    ):
        base_e, rows = classpath_for_side(
            side,
            root,
            apex_roots[side],
            out,
        )
        if base_e.result == PASS:
            ndup, _ = duplicate_classes(side, rows, out)
            if ndup < 0:
                base_e = Gate(
                    "E",
                    side,
                    UNKNOWN,
                    "duplicate_class_engine_unavailable",
                )
            elif ndup:
                base_e = Gate(
                    "E",
                    side,
                    FUNCTIONAL_RISK,
                    f"bootclasspath_duplicate_classes={ndup}:"
                    "boot_effect_not_proven",
                )

        member = None
        if side == "c2" and base_e.result not in (UNKNOWN, BOOT_FATAL):
            member = gate_e_member_c2(
                root,
                rows,
                aapt2,
                pinned_b2,
                out,
            )
            gates.append(member)
        gates.append(combine_gate_e(base_e, member))
        e_rows[side] = rows

    mtk_rows = []
    for side in ("stock", "n1f", "c2"):
        devices = [d for d, _h in e_rows.get(side, [])]
        for jar in (COMMON, IMS_BASE):
            mtk_rows.append(
                [
                    side,
                    jar,
                    devices.index(jar) if jar in devices else -1,
                    "YES" if jar in devices else "NO",
                ]
            )
    write_tsv(
        out / "gate-e-mtk-jar-membership.tsv",
        ["side", "jar", "index", "on_bootclasspath"],
        mtk_rows,
    )

    gates.append(Gate("G", "n1f", NOT_APPLICABLE, "OEM_IMS_ABSENT"))
    gates.append(
        gate_g_c2(
            roots["C2_ROOT"],
            roots["STOCK_VENDOR_ROOT"],
            stock_odm,
            apex_roots["c2"],
            aapt2,
            pinned_b2,
            out,
        )
    )

    verdict, reason = overall(gates)
    c1j_ready = "NO"
    if verdict != "NOT_CLOSED":
        required_ready = [
            next(
                (
                    g
                    for g in gates
                    if g.name == name and g.side == "c2"
                ),
                None,
            )
            for name in ("A", "B", "D", "E", "F", "G")
        ]
        g2_env = read_env(out / "gate-g2-status.env") if (
            out / "gate-g2-status.env"
        ).is_file() else {}
        g2_closed = all(
            g2_env.get(key, "").startswith("NOT_APPLICABLE_")
            for key in (
                "SYMBOL_VERSION_CHECK",
                "LINKER_NAMESPACE_CHECK",
            )
        )
        if (
            all(g is not None and g.result == PASS for g in required_ready)
            and g2_closed
        ):
            c1j_ready = "YES"

    write_tsv(out / "GATES.tsv", ["gate", "side", "result", "detail"], [[g.name, g.side, g.result, g.detail] for g in gates])
    with (out / "SUMMARY.env").open("w", encoding="utf-8") as fp:
        fp.write(f"N1I_D0_0H={verdict}\n")
        fp.write(f"N1I_D0_0H_REASON={reason}\n")
        fp.write(f"N1I_D0_C1J_COMPOSITION_READY={c1j_ready}\n")
        fp.write("N1I_D0_A4_IMPORT_AUTHORITY=RETIRED\n")
        for g in gates:
            fp.write(f"N1I_D0_GATE_{g.name}_{g.side.upper()}={g.result}\n")

    (out / "TOOL_AUTHORITY.env").write_text(
        f"TOOL_SOURCE_COMMIT={subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'], text=True).strip()}\n"
        f"C2_BUILD_SOURCE_COMMIT={C2_BUILD_SOURCE}\n"
        f"B2_ANALYZER_PROVENANCE_COMMIT={B2_PROVENANCE}\n",
        encoding="utf-8",
    )
    with (out / "SHA256SUMS.txt").open("w", encoding="utf-8") as fp:
        for path in sorted(p for p in out.rglob("*") if p.is_file() and p.name != "SHA256SUMS.txt"):
            fp.write(f"{sha256(path)}  {path.relative_to(out)}\n")

    if not git_clean():
        raise D0Error("source_worktree_changed_during_audit")

    for g in gates:
        print(f"N1I_D0_GATE_{g.name}_{g.side.upper()}={g.result} detail={g.detail}")
    print(f"N1I_D0_C1J_COMPOSITION_READY={c1j_ready}")
    print(f"N1I_D0_0H={verdict} reason={reason}")
    print(f"N1I_D0_EVIDENCE_DIR={out}")
    return 0 if verdict in ("DEFECT_FOUND", "NO_FATAL_DEFECT_FOUND") else 3


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (D0Error, OSError, subprocess.SubprocessError, ET.ParseError) as exc:
        print(f"N1I_D0_0H=FAIL_TOOLING reason={exc}", file=sys.stderr)
        raise SystemExit(2)
