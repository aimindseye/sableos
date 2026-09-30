#!/usr/bin/env python3
"""Read-only helpers for Titan 2 N1D C0 offline qualification.

This program never contacts a device, builds Android, flashes, or mutates inputs.
It only reads extracted trees / text / JSON and writes requested reports.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

TEL_RE = re.compile(
    r"tele|phone|radio|ril|ims|volte|vowifi|epdg|carrier|apn|sim|euicc|mms|stk|mediatek|mtk",
    re.I,
)

KEY_PROPS = [
    "ro.build.fingerprint",
    "ro.build.version.release",
    "ro.build.version.sdk",
    "ro.build.version.security_patch",
    "ro.product.first_api_level",
    "ro.vndk.version",
    "ro.treble.enabled",
    "ro.system.build.fingerprint",
    "ro.system.build.version.sdk",
    "ro.system.build.version.security_patch",
]

GSI_CONTRACT_KEYS = [
    "BUILDING_GSI",
    "PRODUCT_USE_DYNAMIC_PARTITIONS",
    "PRODUCT_USE_DYNAMIC_PARTITION_SIZE",
    "PRODUCT_FULL_TREBLE_OVERRIDE",
    "PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE",
    "PRODUCT_EXTRA_VNDK_VERSIONS",
    "PRODUCT_BUILD_VENDOR_IMAGE",
    "PRODUCT_BUILD_SUPER_PARTITION",
    "PRODUCT_BUILD_SYSTEM_DLKM_IMAGE",
    "PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST",
    "PRODUCT_PACKAGES",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_props(root: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    candidates = [
        root / "build.prop",
        root / "system" / "build.prop",
        root / "etc" / "build.prop",
        root / "system" / "etc" / "build.prop",
    ]
    for p in candidates:
        if not p.is_file():
            continue
        for line in p.read_text(errors="replace").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            out.setdefault(k.strip(), v.strip())
    return out


def actual_system_root(root: Path) -> Path:
    if (root / "build.prop").is_file():
        return root
    if (root / "system" / "build.prop").is_file():
        return root / "system"
    return root


def find_skip_mount(root: Path) -> List[Path]:
    r = actual_system_root(root)
    candidates = [
        r / "etc/init/config/skip_mount.cfg",
        r / "system_ext/etc/init/config/skip_mount.cfg",
    ]
    return [p for p in candidates if p.is_file()]


def system_report(root: Path, label: str, out_path: Path) -> int:
    r = actual_system_root(root)
    props = parse_props(root)
    skip_files = find_skip_mount(root)
    skip_lines: List[str] = []
    for p in skip_files:
        skip_lines += [x.strip() for x in p.read_text(errors="replace").splitlines() if x.strip() and not x.lstrip().startswith("#")]
    apex_root = r / "apex"
    apex = sorted(p.name for p in apex_root.iterdir()) if apex_root.is_dir() else []
    vndk = [x for x in apex if "vndk" in x.lower()]
    init_gsi = [p for p in [r / "etc/init/init.gsi.rc", r / "system_ext/etc/init/init.gsi.rc"] if p.is_file()]
    symlink = r / "etc/init/config"
    rows = [
        f"LABEL={label}",
        f"ROOT={r}",
        f"SYSTEM_BUILD_PROP={'YES' if (r / 'build.prop').is_file() else 'NO'}",
        f"SKIP_MOUNT_FILE_COUNT={len(skip_files)}",
        f"SKIP_PRODUCT={'YES' if '/product' in skip_lines else 'NO'}",
        f"SKIP_SYSTEM_EXT={'YES' if '/system_ext' in skip_lines else 'NO'}",
        f"INIT_GSI_RC={'YES' if init_gsi else 'NO'}",
        f"ETC_INIT_CONFIG_IS_SYMLINK={'YES' if symlink.is_symlink() else 'NO'}",
        f"ETC_INIT_CONFIG_TARGET={os.readlink(symlink) if symlink.is_symlink() else '-'}",
        f"APEX_COUNT={len(apex)}",
        f"VNDK_APEX_COUNT={len(vndk)}",
        "VNDK_APEX=" + ",".join(vndk),
    ]
    for k in KEY_PROPS:
        rows.append(f"PROP_{re.sub(r'[^A-Za-z0-9]+', '_', k).upper()}={props.get(k, '-')}")
    rows.append("SKIP_MOUNT_FILES=" + ",".join(str(p) for p in skip_files))
    rows.append("SKIP_MOUNT_LINES=" + ";".join(skip_lines))
    out_path.write_text("\n".join(rows) + "\n")
    return 0


def iter_files(root: Path) -> Iterable[Tuple[str, Path]]:
    for dp, _, fns in os.walk(root, followlinks=False):
        d = Path(dp)
        for fn in fns:
            p = d / fn
            try:
                rel = str(p.relative_to(root))
            except ValueError:
                continue
            yield rel, p


def framework_diff(gsi_root: Path, stock_root: Path, label: str, out_tsv: Path, out_md: Path) -> int:
    gf = {rel: p for rel, p in iter_files(gsi_root)} if gsi_root.is_dir() else {}
    sf = {rel: p for rel, p in iter_files(stock_root)} if stock_root.is_dir() else {}
    keys = sorted(set(gf) | set(sf))
    counts = {"GSI_ONLY": 0, "STOCK_ONLY": 0, "BOTH": 0, "BOTH_SIZE_DIFF": 0}
    tel_counts = {k: 0 for k in counts}
    with out_tsv.open("w") as f:
        f.write("class\ttelephony_relevant\trelpath\tgsi_bytes\tstock_bytes\n")
        for rel in keys:
            gp, sp = gf.get(rel), sf.get(rel)
            gs = gp.stat().st_size if gp and gp.is_file() else -1
            ss = sp.stat().st_size if sp and sp.is_file() else -1
            if gp and not sp:
                cls = "GSI_ONLY"
            elif sp and not gp:
                cls = "STOCK_ONLY"
            elif gs != ss:
                cls = "BOTH_SIZE_DIFF"
            else:
                cls = "BOTH"
            counts[cls] += 1
            tel = bool(TEL_RE.search(rel))
            if tel:
                tel_counts[cls] += 1
            f.write(f"{cls}\t{int(tel)}\t{rel}\t{gs}\t{ss}\n")
    md = [f"# Framework-side file view diff — {label}", "", "| class | all | telephony-relevant |", "|---|---:|---:|"]
    for k in ("GSI_ONLY", "STOCK_ONLY", "BOTH_SIZE_DIFF", "BOTH"):
        md.append(f"| {k} | {counts[k]} | {tel_counts[k]} |")
    md += ["", "This is an inventory/delta report, not a compatibility verdict."]
    out_md.write_text("\n".join(md) + "\n")
    return 0


def strip_make_comments(text: str) -> str:
    out = []
    for line in text.splitlines():
        s = line.split("#", 1)[0]
        out.append(s)
    return "\n".join(out)


def make_contract(path: Path) -> Dict[str, object]:
    text = strip_make_comments(path.read_text(errors="replace")) if path.is_file() else ""
    result: Dict[str, object] = {"path": str(path), "exists": path.is_file()}
    result["inherits_gsi_release"] = "gsi_release.mk" in text
    result["has_skip_mount_package"] = "gsi_skip_mount.cfg" in text
    result["has_init_gsi"] = "init.gsi.rc" in text
    result["has_vndk_extra"] = "PRODUCT_EXTRA_VNDK_VERSIONS" in text
    result["has_full_treble"] = "PRODUCT_FULL_TREBLE_OVERRIDE" in text
    result["has_dynamic_size"] = "PRODUCT_USE_DYNAMIC_PARTITION_SIZE" in text
    result["has_building_gsi"] = "BUILDING_GSI" in text
    assignments = {}
    for key in GSI_CONTRACT_KEYS:
        vals = re.findall(rf"(?m)^\s*{re.escape(key)}\s*[:+?]?=\s*(.*)$", text)
        if vals:
            assignments[key] = vals
    result["assignments"] = assignments
    return result


def gsi_contract(aosp: Path, sable_files: List[Path], out_json: Path, out_md: Path) -> int:
    refs = {"aosp": make_contract(aosp), "sable": [make_contract(p) for p in sable_files]}
    out_json.write_text(json.dumps(refs, indent=2, sort_keys=True) + "\n")
    a = refs["aosp"]
    md = ["# GSI product-contract comparison", "", f"AOSP reference: `{aosp}`", "", "| signal | AOSP | Sable files containing signal |", "|---|---|---|"]
    signals = ["inherits_gsi_release", "has_skip_mount_package", "has_init_gsi", "has_vndk_extra", "has_full_treble", "has_dynamic_size", "has_building_gsi"]
    for sig in signals:
        sable = [Path(x["path"]).name for x in refs["sable"] if x.get(sig)]
        md.append(f"| {sig} | {'YES' if a.get(sig) else 'NO'} | {', '.join(sable) or '-'} |")
    md += ["", "A missing signal is a review trigger; this report does not by itself prove the resolved product graph."]
    out_md.write_text("\n".join(md) + "\n")
    return 0


def lp_index(obj: dict) -> dict:
    out = {"partitions": {}, "groups": {}, "block_devices": {}}
    for p in obj.get("partitions", []):
        if isinstance(p, dict) and p.get("name"):
            out["partitions"][p["name"]] = p
    for g in obj.get("groups", []):
        if isinstance(g, dict) and g.get("name"):
            out["groups"][g["name"]] = g
    for b in obj.get("block_devices", []):
        if isinstance(b, dict) and b.get("name"):
            out["block_devices"][b["name"]] = b
    return out


def lp_diff(stock_json: Path, n1c_json: Path, out_json: Path, out_md: Path) -> int:
    s = lp_index(json.loads(stock_json.read_text()))
    n = lp_index(json.loads(n1c_json.read_text()))
    report = {"stock": s, "n1c": n, "diff": {}}
    rows = []
    names = sorted(set(s["partitions"]) | set(n["partitions"]))
    for name in names:
        sp, np = s["partitions"].get(name), n["partitions"].get(name)
        if sp is None:
            status = "N1C_ONLY"
        elif np is None:
            status = "STOCK_ONLY"
        else:
            fields = sorted(set(sp) | set(np))
            changes = {k: [sp.get(k), np.get(k)] for k in fields if sp.get(k) != np.get(k)}
            status = "SAME" if not changes else "DIFF"
            report["diff"][name] = changes
        rows.append((name, status, str(sp.get("size", "-") if sp else "-"), str(np.get("size", "-") if np else "-"), str(sp.get("group_name", "-") if sp else "-"), str(np.get("group_name", "-") if np else "-")))
    out_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    md = ["# Stock vs N1C logical-partition metadata", "", "| partition | status | stock size | N1C size | stock group | N1C group |", "|---|---|---:|---:|---|---|"]
    for row in rows:
        md.append("| " + " | ".join(row) + " |")
    out_md.write_text("\n".join(md) + "\n")
    return 0


def compare_system_reports(reports: List[Path], labels: List[str], out_md: Path) -> int:
    parsed = []
    for label, p in zip(labels, reports):
        d = {}
        if p.is_file():
            for line in p.read_text(errors="replace").splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    d[k] = v
        parsed.append((label, d))
    keys = [
        "SKIP_PRODUCT", "SKIP_SYSTEM_EXT", "INIT_GSI_RC", "VNDK_APEX_COUNT",
        "PROP_RO_BUILD_VERSION_SDK", "PROP_RO_BUILD_VERSION_SECURITY_PATCH",
        "PROP_RO_PRODUCT_FIRST_API_LEVEL", "PROP_RO_VNDK_VERSION",
    ]
    md = ["# System-image control comparison", "", "| signal | " + " | ".join(labels) + " |", "|---|" + "---|" * len(labels)]
    for k in keys:
        md.append("| " + k + " | " + " | ".join(d.get(k, "-") for _, d in parsed) + " |")
    out_md.write_text("\n".join(md) + "\n")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("system-report")
    p.add_argument("--root", required=True)
    p.add_argument("--label", required=True)
    p.add_argument("--out", required=True)

    p = sub.add_parser("framework-diff")
    p.add_argument("--gsi-root", required=True)
    p.add_argument("--stock-root", required=True)
    p.add_argument("--label", required=True)
    p.add_argument("--out-tsv", required=True)
    p.add_argument("--out-md", required=True)

    p = sub.add_parser("gsi-contract")
    p.add_argument("--aosp", required=True)
    p.add_argument("--sable", action="append", default=[])
    p.add_argument("--out-json", required=True)
    p.add_argument("--out-md", required=True)

    p = sub.add_parser("lp-diff")
    p.add_argument("--stock-json", required=True)
    p.add_argument("--n1c-json", required=True)
    p.add_argument("--out-json", required=True)
    p.add_argument("--out-md", required=True)

    p = sub.add_parser("compare-system-reports")
    p.add_argument("--report", action="append", required=True)
    p.add_argument("--label", action="append", required=True)
    p.add_argument("--out-md", required=True)

    a = ap.parse_args()
    if a.cmd == "system-report":
        return system_report(Path(a.root), a.label, Path(a.out))
    if a.cmd == "framework-diff":
        return framework_diff(Path(a.gsi_root), Path(a.stock_root), a.label, Path(a.out_tsv), Path(a.out_md))
    if a.cmd == "gsi-contract":
        return gsi_contract(Path(a.aosp), [Path(x) for x in a.sable], Path(a.out_json), Path(a.out_md))
    if a.cmd == "lp-diff":
        return lp_diff(Path(a.stock_json), Path(a.n1c_json), Path(a.out_json), Path(a.out_md))
    if a.cmd == "compare-system-reports":
        if len(a.report) != len(a.label):
            ap.error("--report and --label counts must match")
        return compare_system_reports([Path(x) for x in a.report], a.label, Path(a.out_md))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
