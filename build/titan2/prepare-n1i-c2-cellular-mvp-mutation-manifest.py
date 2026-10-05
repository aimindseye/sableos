#!/usr/bin/env python3
"""Prepare the Titan 2 N1I-C2 Cellular MVP Mutation Manifest R1.

Host-only/read-only authority resolver. This tool does not mutate Android source,
build an image, contact a device, reboot, fetch from the network, or flash.

It binds the already-reviewed C1 OEM IMS island to:
  * exact B2 native stock-only system-side closure,
  * TelephonyMetrics legacy ABI source authority,
  * Restless incoming-call compatibility authority,
  * PHH mtkmal IMS-disable behavior,
  * stock-attributed vendor IMS/VoLTE UA service inventory.

The output is a finite implementation manifest, not execution authorization.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import os
import re
import shutil
import sys
from pathlib import Path

TOOL_VERSION = "1.0.0"

DEFAULT_ANDROID_ROOT = Path("/srv/sable-build/workspaces/titan2-n1d/android")
DEFAULT_N1I_A = Path("/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z")
DEFAULT_EVIDENCE_ROOT = Path("/srv/sable-build/evidence/titan2")

OEM_IMS_SHA256 = "30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539"
COMMON_JAR_SHA256 = "511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549"
IMS_BASE_JAR_SHA256 = "bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab"

TMETRICS_BASE_BLOB = "27638e5be9c008101c2f9b8f1e7a9af49d94f838"
TMETRICS_POST_BLOB = "9d5108e0ddb8d4960d21cda021813b53dbbf4da8"
TMETRICS_PATCH_BLOB = "ee353caded6dd07318991eb52d66687e06034c30"

SYSTEM_SIDE = {"system", "system_ext", "product", "system_dlkm"}
VENDOR_SIDE = {"vendor", "odm", "vendor_dlkm", "odm_dlkm"}
UA_RE = re.compile(r"volte|imcb|clientapi|(?:^|[_-])ua(?:$|[_-])|ims", re.I)
PROP_RE = re.compile(r"property:([A-Za-z0-9_.-]+)")


class ManifestError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git_blob_file(path: Path) -> str:
    data = path.read_bytes()
    h = hashlib.sha1()
    h.update(f"blob {len(data)}\0".encode())
    h.update(data)
    return h.hexdigest()


def parse_env(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise ManifestError(f"missing_env={path}")
    out: dict[str, str] = {}
    for no, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in out:
            raise ManifestError(f"duplicate_env_key={key} file={path} line={no}")
        out[key] = value
    return out


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise ManifestError(f"missing_tsv={path}")
    with path.open(encoding="utf-8", newline="") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        if reader.fieldnames is None:
            raise ManifestError(f"missing_tsv_header={path}")
        return list(reader)


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({key: str(row.get(key, "")) for key in fields})


def require_file(path: Path, label: str) -> Path:
    if not path.is_file():
        raise ManifestError(f"{label}_missing={path}")
    return path


def find_unique(root: Path, name: str) -> Path:
    hits = sorted(
        p for p in root.rglob(name)
        if "/out" not in p.as_posix() and "/.git/" not in p.as_posix()
    )
    if len(hits) != 1:
        raise ManifestError(
            f"source_authority_{name}_count={len(hits)} paths="
            + ",".join(str(p) for p in hits[:20])
        )
    return hits[0]


def classify_b2_candidate(path: Path) -> str | None:
    parts = [p.lower() for p in path.parts]
    if any("stock" in p for p in parts):
        return "stock"
    if any("c3a" in p for p in parts):
        return "c3a"
    return None


def resolve_b2_dir(
    explicit: Path | None,
    role: str,
    evidence_root: Path,
    apk_sha: str,
) -> Path:
    if explicit is not None:
        summary = parse_env(explicit / "NATIVE_SUMMARY.env")
        if summary.get("N1I_B2_NATIVE_APK_SHA256") != apk_sha:
            raise ManifestError(
                f"b2_{role}_apk_sha_mismatch={summary.get('N1I_B2_NATIVE_APK_SHA256', 'MISSING')}"
            )
        require_file(explicit / "NATIVE_CLOSURE.tsv", f"b2_{role}_closure")
        return explicit.resolve()

    candidates: list[Path] = []
    for summary_path in evidence_root.rglob("NATIVE_SUMMARY.env"):
        try:
            env = parse_env(summary_path)
        except ManifestError:
            continue
        if env.get("N1I_B2_NATIVE_APK_SHA256") != apk_sha:
            continue
        parent = summary_path.parent
        if classify_b2_candidate(parent) == role and (parent / "NATIVE_CLOSURE.tsv").is_file():
            candidates.append(parent.resolve())
    unique = sorted(set(candidates))
    if len(unique) != 1:
        raise ManifestError(
            f"b2_{role}_authority_count={len(unique)} "
            f"pass_--b2-{role}-native explicitly candidates="
            + ",".join(str(p) for p in unique[:20])
        )
    return unique[0]


def native_closure(stock_dir: Path, c3a_dir: Path) -> tuple[list[dict[str, object]], list[str]]:
    stock_env = parse_env(stock_dir / "NATIVE_SUMMARY.env")
    c3a_env = parse_env(c3a_dir / "NATIVE_SUMMARY.env")
    ssha = stock_env.get("N1I_B2_NATIVE_APK_SHA256", "")
    csha = c3a_env.get("N1I_B2_NATIVE_APK_SHA256", "")
    if ssha != csha or ssha != OEM_IMS_SHA256:
        raise ManifestError(f"b2_native_apk_authority_mismatch=stock:{ssha},c3a:{csha}")

    required = {
        "library", "status", "partition", "path", "sha256", "needed",
        "admitted_by", "namespace_visibility", "evidence_strength",
    }
    sr = read_tsv(stock_dir / "NATIVE_CLOSURE.tsv")
    cr = read_tsv(c3a_dir / "NATIVE_CLOSURE.tsv")
    for role, rows in (("stock", sr), ("c3a", cr)):
        if rows and not required.issubset(rows[0]):
            missing = sorted(required - set(rows[0]))
            raise ManifestError(f"b2_{role}_closure_columns_missing={','.join(missing)}")

    sm = {r["library"]: r for r in sr}
    cm = {r["library"]: r for r in cr}
    if len(sm) != len(sr) or len(cm) != len(cr):
        raise ManifestError("b2_native_duplicate_library_row")

    out: list[dict[str, object]] = []
    blockers: list[str] = []
    for name in sorted(sm):
        s = sm[name]
        c = cm.get(name)
        if s["status"] != "FOUND":
            continue
        if s["partition"] not in SYSTEM_SIDE:
            continue
        cstatus = c["status"] if c else "NOT_FOUND"
        if cstatus == "FOUND":
            continue
        if cstatus not in {"NOT_FOUND", "NOT_ANALYSED"}:
            blockers.append(f"{name}:{cstatus}")
            continue
        if s["namespace_visibility"] != "EXPLICIT":
            blockers.append(f"{name}:stock_namespace={s['namespace_visibility']}")
            continue
        sha = s["sha256"]
        if not re.fullmatch(r"[0-9a-f]{64}", sha):
            blockers.append(f"{name}:bad_sha256={sha}")
            continue
        target = f"/{s['partition']}/lib64/{name}"
        out.append({
            "library": name,
            "partition": s["partition"],
            "target": target,
            "stock_path": s["path"],
            "sha256": sha,
            "needed": s["needed"],
            "admitted_by": s["admitted_by"],
            "evidence_strength": s["evidence_strength"],
            "c3a_status": cstatus,
            "decision": "ADMIT_EXACT_STOCK_ONLY_SYSTEM_DEPENDENCY",
        })
    return out, blockers


def vendor_ua_inventory(n1i_a: Path) -> list[dict[str, object]]:
    services = read_tsv(n1i_a / "a5-init-services.tsv")
    setters = read_tsv(n1i_a / "a5-trigger-property-setters.tsv")
    setter_map: dict[str, str] = {}
    for row in setters:
        prop = row.get("property", "")
        if prop:
            setter_map[prop] = row.get("set_by", "")

    out: list[dict[str, object]] = []
    for row in services:
        name = row.get("service", "")
        exe = row.get("exec", "")
        part = row.get("partition", "")
        if part not in VENDOR_SIDE or not UA_RE.search(f"{name} {exe}"):
            continue
        triggers = row.get("triggers", "")
        props = sorted(set(PROP_RE.findall(triggers)))
        attributed = [
            p for p in props
            if "SYSTEM_SIDE_OEM_IMS_CODE" in setter_map.get(p, "")
        ]
        start_mode = row.get("start_mode", "")
        decision = "OBSERVE_READINESS"
        if start_mode == "disabled" and attributed:
            decision = "ALLOW_BOUNDED_START_IF_NOT_READY"
        out.append({
            "service": name,
            "exec": exe,
            "partition": part,
            "start_mode": start_mode,
            "triggers": triggers or "-",
            "system_attributed_trigger_properties": ",".join(attributed) or "NONE",
            "decision": decision,
        })
    return out


def relevant_phh_lines(path: Path) -> list[tuple[int, str]]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    indexes = {
        i for i, line in enumerate(lines)
        if "mtkmal" in line or "persist.mtk_ims_support" in line or "persist.mtk_epdg_support" in line
    }
    expanded: set[int] = set()
    for i in indexes:
        expanded.update(range(max(0, i - 3), min(len(lines), i + 5)))
    return [(i + 1, lines[i]) for i in sorted(expanded)]


def seal_dir(out: Path) -> None:
    seal = out / "SHA256SUMS.txt"
    names = sorted(
        p.name for p in out.iterdir()
        if p.is_file() and p.name != seal.name
    )
    with seal.open("w", encoding="utf-8") as fp:
        for name in names:
            fp.write(f"{sha256_file(out / name)}  {name}\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--android-root", type=Path, default=DEFAULT_ANDROID_ROOT)
    ap.add_argument("--n1i-a", type=Path, default=DEFAULT_N1I_A)
    ap.add_argument("--evidence-root", type=Path, default=DEFAULT_EVIDENCE_ROOT)
    ap.add_argument("--b2-stock-native", type=Path)
    ap.add_argument("--b2-c3a-native", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    android = args.android_root.resolve()
    n1i_a = args.n1i_a.resolve()
    out = args.out

    print("===== N1I-C2 CELLULAR MVP MUTATION MANIFEST R1 =====")
    print("SOURCE_MUTATION_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("REBOOT_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print(f"TOOL_VERSION={TOOL_VERSION}")
    print(f"ANDROID_ROOT={android}")
    print(f"N1I_A={n1i_a}")

    if out.exists():
        raise ManifestError(f"out_already_exists={out}")
    if not android.is_dir():
        raise ManifestError(f"android_root_missing={android}")

    n1i_env = parse_env(n1i_a / "n1i-a-v010014-oem-ims.env")
    if n1i_env.get("N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE") != "PASS":
        raise ManifestError("accepted_n1i_a_not_pass")
    if n1i_env.get("OEM_IMS_APK_SHA256") != OEM_IMS_SHA256:
        raise ManifestError(
            f"n1i_a_oem_ims_sha_mismatch={n1i_env.get('OEM_IMS_APK_SHA256', 'MISSING')}"
        )
    require_file(n1i_a / "a5-init-services.tsv", "n1i_a_init_services")
    require_file(n1i_a / "a5-trigger-property-setters.tsv", "n1i_a_trigger_setters")

    stock_dir = resolve_b2_dir(
        args.b2_stock_native, "stock", args.evidence_root.resolve(), OEM_IMS_SHA256
    )
    c3a_dir = resolve_b2_dir(
        args.b2_c3a_native, "c3a", args.evidence_root.resolve(), OEM_IMS_SHA256
    )
    if stock_dir == c3a_dir:
        raise ManifestError("b2_stock_and_c3a_same_directory")

    native_rows, native_blockers = native_closure(stock_dir, c3a_dir)
    if native_blockers:
        raise ManifestError("b2_native_closure_not_finite=" + ",".join(native_blockers))

    tmetrics = require_file(
        android / "frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java",
        "telephonymetrics_source",
    )
    tmetrics_blob = git_blob_file(tmetrics)
    if tmetrics_blob not in {TMETRICS_BASE_BLOB, TMETRICS_POST_BLOB}:
        raise ManifestError(f"telephonymetrics_unexpected_blob={tmetrics_blob}")

    repo_root = Path(__file__).resolve().parents[2]
    tmetrics_patch = require_file(
        repo_root / "patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch",
        "telephonymetrics_patch",
    )
    patch_blob = git_blob_file(tmetrics_patch)
    if patch_blob != TMETRICS_PATCH_BLOB:
        raise ManifestError(f"telephonymetrics_patch_blob={patch_blob}")

    incoming = find_unique(android / "frameworks/opt/telephony", "ImsPhoneCallTracker.java")
    incoming_text = incoming.read_text(encoding="utf-8", errors="replace")
    incoming_prop = "ro.telephony.block_binder_thread_on_incoming_calls"
    if incoming_prop not in incoming_text:
        raise ManifestError("incoming_call_compat_property_missing")
    default_true = bool(
        re.search(
            r'ro\.telephony\.block_binder_thread_on_incoming_calls["\s,]+true',
            incoming_text,
            re.S,
        )
    )

    phh = require_file(android / "device/phh/treble/phh-on-boot.sh", "phh_on_boot")
    phh_text = phh.read_text(encoding="utf-8", errors="replace")
    phh_branch_present = all(
        token in phh_text
        for token in ("/vendor/bin/mtkmal", "persist.mtk_ims_support", "persist.mtk_epdg_support")
    )
    if not phh_branch_present:
        raise ManifestError("phh_mtkmal_ims_disable_branch_not_found")

    ua_rows = vendor_ua_inventory(n1i_a)

    out.mkdir(parents=True)
    write_tsv(
        out / "CELLULAR_MVP_NATIVE_CLOSURE.tsv",
        [
            "library", "partition", "target", "stock_path", "sha256", "needed",
            "admitted_by", "evidence_strength", "c3a_status", "decision",
        ],
        native_rows,
    )
    write_tsv(
        out / "CELLULAR_MVP_VENDOR_UA.tsv",
        [
            "service", "exec", "partition", "start_mode", "triggers",
            "system_attributed_trigger_properties", "decision",
        ],
        ua_rows,
    )

    phh_rows = [
        {"line": no, "text": text}
        for no, text in relevant_phh_lines(phh)
    ]
    write_tsv(out / "CELLULAR_MVP_PHH_MTKMAL_CONTEXT.tsv", ["line", "text"], phh_rows)

    source_rows = [
        {
            "authority": "TELEPHONYMETRICS",
            "path": str(tmetrics),
            "sha256": sha256_file(tmetrics),
            "git_blob": tmetrics_blob,
            "state": "BASE_NEEDS_PATCH" if tmetrics_blob == TMETRICS_BASE_BLOB else "ALREADY_PATCHED",
        },
        {
            "authority": "IMSPHONECALLTRACKER",
            "path": str(incoming),
            "sha256": sha256_file(incoming),
            "git_blob": git_blob_file(incoming),
            "state": "COMPAT_PRESENT_DEFAULT_TRUE" if default_true else "COMPAT_PRESENT_DEFAULT_NOT_TRUE",
        },
        {
            "authority": "PHH_ON_BOOT",
            "path": str(phh),
            "sha256": sha256_file(phh),
            "git_blob": git_blob_file(phh),
            "state": "MTKMAL_IMS_DISABLE_BRANCH_PRESENT",
        },
        {
            "authority": "N1I_A",
            "path": str(n1i_a),
            "sha256": "-",
            "git_blob": "-",
            "state": "PASS_ACCEPTED",
        },
        {
            "authority": "B2_STOCK_NATIVE",
            "path": str(stock_dir),
            "sha256": "-",
            "git_blob": "-",
            "state": "PASS_BOUND",
        },
        {
            "authority": "B2_C3A_NATIVE",
            "path": str(c3a_dir),
            "sha256": "-",
            "git_blob": "-",
            "state": "PASS_BOUND",
        },
    ]
    write_tsv(
        out / "CELLULAR_MVP_SOURCE_AUTHORITY.tsv",
        ["authority", "path", "sha256", "git_blob", "state"],
        source_rows,
    )

    manifest: list[dict[str, object]] = []
    def add(mid: str, domain: str, action: str, target: str, source: str, digest: str, basis: str) -> None:
        manifest.append({
            "id": mid,
            "domain": domain,
            "action": action,
            "target": target,
            "source": source,
            "sha256_or_blob": digest,
            "basis": basis,
            "status": "PROPOSED_NOT_AUTHORIZED",
        })

    add(
        "M001", "OEM_IMS", "RETAIN",
        "/system_ext/priv-app/ImsService/ImsService.apk",
        "V01.00.14 accepted stock authority", OEM_IMS_SHA256,
        "N1I-A package/signature/shared-UID closure",
    )
    add(
        "M002", "JAVA", "RETAIN",
        "/system_ext/framework/mediatek-common.jar",
        "V01.00.14 accepted stock authority", COMMON_JAR_SHA256,
        "N1I-A/V6 Java member closure",
    )
    add(
        "M003", "JAVA", "RETAIN",
        "/system_ext/framework/mediatek-ims-base.jar",
        "V01.00.14 accepted stock authority", IMS_BASE_JAR_SHA256,
        "N1I-A/V6 Java member closure",
    )
    add(
        "M004", "FRAMEWORK", "APPLY_PATCH" if tmetrics_blob == TMETRICS_BASE_BLOB else "RETAIN_PATCHED",
        str(tmetrics),
        str(tmetrics_patch), TMETRICS_PATCH_BLOB,
        "V6F stock OEM caller requires writeRilAnswer(II)V",
    )
    add(
        "M005", "TELEPHONY", "SET_PRODUCT_PROPERTY_FALSE",
        incoming_prop,
        "Titan 2 product property", git_blob_file(incoming),
        "existing Restless incoming-call compatibility path is inert when default=true",
    )
    add(
        "M006", "PHH", "TITAN_GUARD_MTKMAL_IMS_DISABLE_BRANCH",
        str(phh),
        "device/phh/treble/phh-on-boot.sh", git_blob_file(phh),
        "OEM-IMS MVP must not disable MTK IMS/ePDG through generic mtkmal branch",
    )

    next_id = 7
    for row in native_rows:
        add(
            f"M{next_id:03d}", "NATIVE", "ADMIT_EXACT_STOCK_LIBRARY",
            str(row["target"]), str(row["stock_path"]), str(row["sha256"]),
            f"B2 exact stock-only system-side closure; {row['evidence_strength']}",
        )
        next_id += 1

    add(
        f"M{next_id:03d}", "INTEGRATION", "ADD_SABLE_TITAN_CELLULAR_INTEGRATION_PACKAGE",
        "vendor/sable/titan2/n1i-c2",
        "SableOS source", "-",
        "provider/MMTEL binding, vendor-UA readiness, diagnostics, bounded rearm",
    )
    next_id += 1
    add(
        f"M{next_id:03d}", "HEALER", "SHIP_DISABLED_BY_DEFAULT",
        "Sable Titan cellular integration package",
        "SableOS source", "-",
        "state-triggered bounded recovery without blind property/RIL loops",
    )

    write_tsv(
        out / "CELLULAR_MVP_MUTATION_MANIFEST.tsv",
        ["id", "domain", "action", "target", "source", "sha256_or_blob", "basis", "status"],
        manifest,
    )

    attributed = sum(
        1 for row in ua_rows
        if row["decision"] == "ALLOW_BOUNDED_START_IF_NOT_READY"
    )
    summary = {
        "N1I_C2_MANIFEST_TOOL_VERSION": TOOL_VERSION,
        "N1I_C2_MANIFEST_OEM_IMS_SHA256": OEM_IMS_SHA256,
        "N1I_C2_MANIFEST_B2_STOCK_NATIVE_DIR": str(stock_dir),
        "N1I_C2_MANIFEST_B2_C3A_NATIVE_DIR": str(c3a_dir),
        "N1I_C2_MANIFEST_NATIVE_IMPORT_COUNT": str(len(native_rows)),
        "N1I_C2_MANIFEST_NATIVE_CLOSURE": "PASS_FINITE",
        "N1I_C2_MANIFEST_TELEPHONYMETRICS_STATE":
            "BASE_NEEDS_PATCH" if tmetrics_blob == TMETRICS_BASE_BLOB else "ALREADY_PATCHED",
        "N1I_C2_MANIFEST_INCOMING_CALL_COMPAT":
            "PASS_PRESENT_DEFAULT_TRUE" if default_true else "PASS_PRESENT_NONTRUE",
        "N1I_C2_MANIFEST_PHH_MTKMAL_BRANCH": "PASS_PRESENT_REQUIRES_TITAN_GUARD",
        "N1I_C2_MANIFEST_VENDOR_UA_CANDIDATE_COUNT": str(len(ua_rows)),
        "N1I_C2_MANIFEST_VENDOR_UA_SYSTEM_ATTRIBUTED_DISABLED_COUNT": str(attributed),
        "N1I_C2_MANIFEST_MUTATION_COUNT": str(len(manifest)),
        "N1I_C2_MANIFEST_MUTATION_SET": "PASS_FINITE_REVIEWABLE",
        "N1I_C2_MANIFEST_SOURCE_MUTATION_AUTHORIZED": "NO",
        "N1I_C2_MANIFEST_BUILD_AUTHORIZED": "NO",
        "N1I_C2_MANIFEST_DEVICE_CONTACT_AUTHORIZED": "NO",
        "N1I_C2_MANIFEST_FLASH_AUTHORIZED": "NO",
        "N1I_C2_CELLULAR_MVP_MUTATION_MANIFEST": "PASS",
    }
    with (out / "CELLULAR_MVP_SUMMARY.env").open("w", encoding="utf-8") as fp:
        for key, value in summary.items():
            fp.write(f"{key}={value}\n")

    seal_dir(out)

    for key, value in summary.items():
        print(f"{key}={value}")
    print(f"N1I_C2_MANIFEST_OUT={out}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ManifestError as exc:
        print(f"N1I_C2_CELLULAR_MVP_MUTATION_MANIFEST=FAIL reason={exc}", file=sys.stderr)
        raise SystemExit(2)
