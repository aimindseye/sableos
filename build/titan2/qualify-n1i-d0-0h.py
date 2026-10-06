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


def run(cmd: list[str], out: Path | None = None) -> tuple[int, str]:
    p = subprocess.run(cmd, capture_output=True, text=True, check=False)
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


def verify_b2_provenance() -> bool:
    p = subprocess.run(
        ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", B2_PROVENANCE, "HEAD"],
        check=False,
    )
    return p.returncode == 0


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
) -> tuple[Gate, Gate, Path | None]:
    mode, why, pre = precompiled_authority(side_root, stock_vendor, stock_odm)
    (out / f"gate-a0-{side}.env").write_text(
        f"MODE={mode}\nDETAIL={why}\n",
        encoding="utf-8",
    )
    if mode == "PRECOMPILED_MATCH":
        return Gate("A", side, PASS, why), Gate("A2", side, NOT_APPLICABLE, "precompiled_used"), pre

    init_src = android_root / "system/core/init/selinux.cpp"
    if not init_src.is_file():
        return Gate("A", side, UNKNOWN, "android_init_selinux_source_missing"), Gate("A2", side, UNKNOWN, "a1_not_run"), None
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
        return Gate("A", side, UNKNOWN, "init_semantics_unrecognized:" + ",".join(missing_markers)), Gate("A2", side, UNKNOWN, "a1_not_run"), None

    f = policy_files(side_root, stock_vendor, stock_odm)
    required = ("plat", "vendor", "plat_pub", "vendor_vers")
    missing = [k for k in required if f[k] is None or not f[k].is_file()]
    if missing:
        return Gate("A", side, UNKNOWN, "policy_inputs_missing:" + ",".join(missing)), Gate("A2", side, UNKNOWN, "a1_not_run"), None

    vers = f["vendor_vers"].read_text().splitlines()[0].strip()
    mapping = root_path(side_root, "system", f"etc/selinux/mapping/{vers}.cil")
    if mapping is None:
        return Gate("A", side, UNKNOWN, f"platform_mapping_missing={vers}"), Gate("A2", side, UNKNOWN, "a1_not_run"), None
    plat_compat = root_path(side_root, "system", f"etc/selinux/mapping/{vers}.compat.cil")
    sext_map = root_path(side_root, "system_ext", f"etc/selinux/mapping/{vers}.cil")
    sext_compat = root_path(side_root, "system_ext", f"etc/selinux/mapping/{vers}.compat.cil")
    product_map = root_path(side_root, "product", f"etc/selinux/mapping/{vers}.cil")

    pv = init_sepolicy_version(android_root)
    if pv is None:
        return Gate("A", side, UNKNOWN, "init_sepolicy_version_unknown"), Gate("A2", side, UNKNOWN, "a1_not_run"), None

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
        return Gate("A", side, BOOT_FATAL, f"init_equivalent_secilc_rc={rc}"), Gate("A2", side, UNKNOWN, "a1_failed"), None

    compliance = out / f"gate-a2-{side}.policy"
    compliance_fc = out / f"gate-a2-{side}.file_contexts"
    ccmd = [x for x in cmd if x != "-N"]
    ccmd[ccmd.index(str(compiled))] = str(compliance)
    ccmd[ccmd.index(str(fc))] = str(compliance_fc)
    crc, _ = run(ccmd, out / f"gate-a2-{side}.log")
    cgate = Gate("A2", side, PASS if crc == 0 else COMPLIANCE_ONLY, f"neverallow_secilc_rc={crc}")
    return Gate("A", side, PASS, f"split_compile_pass genfs={genfs_version}"), cgate, compiled


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
    for path in root.rglob("*.prop"):
        if path.stat().st_size > 4 * 1024 * 1024:
            continue
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if raw.startswith(key + "="):
                vals.add(raw.split("=", 1)[1].strip())
    for name in ("build.prop", "default.prop"):
        for path in root.rglob(name):
            if path.stat().st_size > 4 * 1024 * 1024:
                continue
            for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
                if raw.startswith(key + "="):
                    vals.add(raw.split("=", 1)[1].strip())
    return vals


def privapp_blocks(roots: list[tuple[str, Path]], package: str | None = None) -> list[tuple[str, str, set[str], set[str]]]:
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
                allow = {n.attrib.get("name", "") for n in node.findall("permission") if n.attrib.get("name")}
                deny = {n.attrib.get("name", "") for n in node.findall("deny-permission") if n.attrib.get("name")}
                found.append((part, pkg, allow, deny))
    return found


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


def gate_d_n1f(root: Path, aapt2: Path, out: Path) -> Gate:
    framework = find_framework(root)
    if framework is None:
        return Gate("D", "n1f", UNKNOWN, "framework_res_missing")
    try:
        privileged = privileged_framework_permissions(aapt2, framework)
    except D0Error as exc:
        return Gate("D", "n1f", UNKNOWN, str(exc))
    system_root = root_path(root, "system", "")
    sext_root = root_path(root, "system_ext", "")
    if system_root is None or sext_root is None:
        return Gate("D", "n1f", UNKNOWN, "partition_roots_missing")
    blocks = privapp_blocks([("system", system_root), ("system_ext", sext_root)])
    rows = []
    failures = []
    for apk in sorted(sext_root.glob("priv-app/**/*.apk")):
        try:
            pkg, _ = aapt_badging(aapt2, apk)
            req = requested_permissions(aapt2, apk) & privileged
        except D0Error:
            continue
        matches = [b for b in blocks if b[1] == pkg]
        allowed = set().union(*(b[2] for b in matches if b[0] == "system_ext")) if matches else set()
        wrong = set().union(*(b[2] for b in matches if b[0] != "system_ext")) if matches else set()
        missing = req - allowed
        rows.append([pkg, len(req), len(allowed), len(wrong), ",".join(sorted(missing)) or "NONE"])
        if missing:
            failures.append(pkg)
    write_tsv(out / "gate-d-n1f-privapp.tsv", ["package", "required_privileged", "system_ext_allow", "other_partition_allow", "missing"], rows)
    return Gate("D", "n1f", PASS if not failures else UNKNOWN, "control_missing=" + (",".join(failures) or "NONE"))


def gate_d_c2(root: Path, stock_system: Path, stock_system_ext: Path, stock_product: Path, aapt2: Path, apksigner: Path, out: Path) -> Gate:
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
        return Gate("D", "c2", BOOT_FATAL, f"unexpected_ims_package={package}")

    sext = root_path(root, "system_ext", "")
    system = root_path(root, "system", "")
    product = root_path(root, "product", "")
    if sext is None or system is None:
        return Gate("D", "c2", UNKNOWN, "candidate_partition_roots_missing")

    candidate_blocks = privapp_blocks([("system", system), ("system_ext", sext), ("product", product or Path("/nonexistent"))], package)
    stock_blocks = privapp_blocks([
        ("system", stock_system),
        ("system_ext", stock_system_ext),
        ("product", stock_product),
    ], package)
    required = req & privileged
    c2_allow = set().union(*(b[2] for b in candidate_blocks if b[0] == "system_ext")) if candidate_blocks else set()
    c2_wrong = set().union(*(b[2] for b in candidate_blocks if b[0] != "system_ext")) if candidate_blocks else set()
    missing = required - c2_allow

    enforcement = prop_values(root, "ro.control_privapp_permissions")
    write_tsv(
        out / "gate-d-c2-privapp.tsv",
        ["source", "partition", "allow_count", "deny_count", "permissions"],
        [["C2", b[0], len(b[2]), len(b[3]), ",".join(sorted(b[2]))] for b in candidate_blocks]
        + [["STOCK", b[0], len(b[2]), len(b[3]), ",".join(sorted(b[2]))] for b in stock_blocks],
    )
    (out / "gate-d-c2-badging.txt").write_text(badging, encoding="utf-8")
    (out / "gate-d-c2-manifest-tree.txt").write_text(mtext, encoding="utf-8")
    write_tsv(out / "gate-d-c2-permissions.tsv", ["kind", "permission"], [["REQUIRED_PRIVILEGED", p] for p in sorted(required)] + [["MISSING_SYSTEM_EXT", p] for p in sorted(missing)])

    sig_result = "UNKNOWN"
    if apksigner.is_file():
        rc1, t1 = run([str(apksigner), "verify", "--print-certs", str(ims)])
        rc2, t2 = run([str(apksigner), "verify", "--print-certs", str(framework)])
        d1 = re.search(r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)", t1)
        d2 = re.search(r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)", t2)
        if rc1 == 0 and rc2 == 0 and d1 and d2:
            sig_result = "PASS" if d1.group(1).lower() == d2.group(1).lower() else "FAIL"
    (out / "gate-d-c2-shareduid.env").write_text(
        f"PLATFORM_SIGNATURE_MATCH={sig_result}\n"
        f"SHARED_UID_PHONE={'YES' if 'android.uid.phone' in mtext else 'UNKNOWN'}\n",
        encoding="utf-8",
    )

    seapp_files = find_all(root, ("plat_seapp_contexts", "system_ext_seapp_contexts", "product_seapp_contexts"))
    seapp_lines = []
    for path in seapp_files:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "user=radio" in line or "name=com.mediatek.ims" in line:
                seapp_lines.append(f"{path}\t{line}")
    (out / "gate-d-c2-seapp.txt").write_text("\n".join(seapp_lines) + ("\n" if seapp_lines else ""), encoding="utf-8")

    enforce = "enforce" in enforcement
    if len(enforcement) != 1:
        return Gate("D", "c2", UNKNOWN, "privapp_enforcement_values=" + ",".join(sorted(enforcement)) or "NONE")
    if sig_result == "FAIL":
        return Gate("D", "c2", BOOT_FATAL, "ims_platform_signature_mismatch")
    if enforce and missing:
        return Gate("D", "c2", BOOT_FATAL, f"system_ext_privapp_missing={len(missing)} wrong_partition_entries={len(c2_wrong)}")
    if missing:
        return Gate("D", "c2", FUNCTIONAL_RISK, f"missing_allowlist={len(missing)} enforcement={next(iter(enforcement))}")
    return Gate("D", "c2", PASS, f"required={len(required)} system_ext_covered={len(c2_allow)} signature={sig_result}")


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


def gate_g_c2(root: Path, aapt2: Path, out: Path) -> Gate:
    ims = find_ims(root)
    if ims is None:
        return Gate("G", "c2", UNKNOWN, "ims_apk_missing")
    tool = ROOT / "build/titan2/n1i-b2-native.py"
    badging = out / "gate-g-c2-badging.txt"
    rc, text = run([str(aapt2), "dump", "badging", str(ims)], badging)
    if rc != 0:
        return Gate("G", "c2", UNKNOWN, f"aapt2_badging_rc={rc}")
    lib_args = []
    for part, dirs in (
        ("system", [root_path(root, "system", "lib64")]),
        ("system_ext", [root_path(root, "system_ext", "lib64")]),
        ("product", [root_path(root, "product", "lib64")]),
    ):
        for d in dirs:
            if d is not None and d.is_dir():
                lib_args += ["--lib-dir", f"{part}={d}"]
    g_out = out / "gate-g-c2-native"
    cmd = [sys.executable, str(tool), "--side", "c3a", "--apk", str(ims), "--badging", str(badging), "--search-superset", str(ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"), "--out", str(g_out), *lib_args]
    rc, _ = run(cmd, out / "gate-g-c2.log")
    if rc != 0:
        return Gate("G", "c2", UNKNOWN, f"b2_native_rc={rc}")
    env = read_env(g_out / "NATIVE_SUMMARY.env")
    unresolved = env.get("N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED", "UNKNOWN")
    missing = env.get("N1I_B2_NATIVE_NOT_FOUND", "UNKNOWN")
    (out / "gate-g2-status.env").write_text(
        "SYMBOL_VERSION_CHECK=UNKNOWN_NOT_IMPLEMENTED\n"
        "LINKER_NAMESPACE_CHECK=UNKNOWN_NOT_IMPLEMENTED\n",
        encoding="utf-8",
    )
    result = PASS if unresolved == "0" and missing == "NONE" else FUNCTIONAL_RISK
    return Gate("G", "c2", result, f"dynamic_unresolved={unresolved} native_not_found={missing}")


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
    rc, _ = run(["sha256sum", "-c", str(sums)], None)
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
    if not args.android_root.is_dir():
        raise D0Error("android_root_missing")

    out = args.out.resolve()
    if out.exists():
        raise D0Error(f"output_exists={out}")
    out.mkdir(parents=True)

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
    print("N1I_D0_B0_COMPOSITION=PASS")
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
        ag, a2, policy = compile_policy(side, root, roots["STOCK_VENDOR_ROOT"], stock_odm, args.android_root.resolve(), secilc, out)
        gates.extend((ag, a2))
        policies[side] = policy
        gates.append(gate_b(side, root, roots["STOCK_VENDOR_ROOT"], stock_odm, policy, property_checker, out, ag.result))
        gates.append(gate_c(side, root, roots["STOCK_VENDOR_ROOT"], stock_odm, policy, checkfc, out))

    gates.append(gate_d_n1f(roots["N1F_ROOT"], aapt2, out))
    gates.append(gate_d_c2(roots["C2_ROOT"], roots["STOCK_SYSTEM_ROOT"], roots["STOCK_SYSTEM_EXT_ROOT"], roots["STOCK_PRODUCT_ROOT"], aapt2, apksigner, out))

    # Gate E must analyze each side's own pinned APEX runtime view.
    e_rows: dict[str, list[tuple[str, Path]]] = {}
    for side, root in (
        ("n1f", roots["N1F_ROOT"]),
        ("c2", roots["C2_ROOT"]),
        ("stock", roots["STOCK_RUNTIME_ROOT"]),
    ):
        eg, rows = classpath_for_side(side, root, apex_roots[side], out)
        if eg.result == PASS:
            ndup, _ = duplicate_classes(side, rows, out)
            if ndup < 0:
                eg = Gate("E", side, UNKNOWN, "duplicate_class_engine_unavailable")
            elif ndup:
                # A duplicate is a real classpath difference but is not boot-fatal
                # without proof that boot-reachable code resolves through it.
                eg = Gate("E", side, FUNCTIONAL_RISK, f"bootclasspath_duplicate_classes={ndup}")
        gates.append(eg)
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

    gates.append(Gate("F", "n1f", NOT_APPLICABLE, "OEM_IMS_ABSENT"))
    gates.append(gate_f_c2(roots["C2_ROOT"], aapt2, out))
    gates.append(Gate("G", "n1f", NOT_APPLICABLE, "OEM_IMS_ABSENT"))
    gates.append(gate_g_c2(roots["C2_ROOT"], aapt2, out))

    verdict, reason = overall(gates)
    c1j_ready = "NO"
    if verdict != "NOT_CLOSED":
        d = next((g for g in gates if g.name == "D" and g.side == "c2"), None)
        e = next((g for g in gates if g.name == "E" and g.side == "c2"), None)
        g = next((g for g in gates if g.name == "G" and g.side == "c2"), None)
        if d and d.result == PASS and e and e.result == PASS and g and g.result in (PASS, FUNCTIONAL_RISK):
            c1j_ready = "YES" if g.result == PASS else "NO"

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
