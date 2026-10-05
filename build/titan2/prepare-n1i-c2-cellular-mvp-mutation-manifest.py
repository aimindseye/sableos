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

TOOL_VERSION = "1.1.0"

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


def validate_b2_summary(
    summary: dict[str, str],
    role: str,
    apk_sha: str,
    path: Path,
) -> None:
    actual_sha = summary.get("N1I_B2_NATIVE_APK_SHA256", "")
    if actual_sha != apk_sha:
        raise ManifestError(
            f"b2_{role}_apk_sha_mismatch={actual_sha or 'MISSING'} path={path}"
        )
    actual_side = summary.get("N1I_B2_NATIVE_SIDE", "")
    if actual_side != role:
        raise ManifestError(
            f"b2_{role}_side_mismatch={actual_side or 'MISSING'} path={path}"
        )


def b2_candidates(
    role: str,
    evidence_root: Path,
    apk_sha: str,
) -> list[Path]:
    candidates: list[Path] = []
    for summary_path in evidence_root.rglob("NATIVE_SUMMARY.env"):
        try:
            env = parse_env(summary_path)
        except ManifestError:
            continue
        if env.get("N1I_B2_NATIVE_APK_SHA256") != apk_sha:
            continue
        if env.get("N1I_B2_NATIVE_SIDE") != role:
            continue
        parent = summary_path.parent
        if (parent / "NATIVE_CLOSURE.tsv").is_file():
            candidates.append(parent.resolve())
    return sorted(set(candidates))


def resolve_b2_dir(
    explicit: Path | None,
    role: str,
    evidence_root: Path,
    apk_sha: str,
) -> Path:
    if explicit is not None:
        summary_path = explicit / "NATIVE_SUMMARY.env"
        summary = parse_env(summary_path)
        validate_b2_summary(summary, role, apk_sha, summary_path)
        require_file(explicit / "NATIVE_CLOSURE.tsv", f"b2_{role}_closure")
        return explicit.resolve()

    unique = b2_candidates(role, evidence_root, apk_sha)
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


def a4_native_superset(
    n1i_a: Path,
    repo_root: Path,
    n1i_env: dict[str, str],
) -> tuple[list[dict[str, object]], str]:
    if n1i_env.get("N1I_A_NATIVE_DEPENDENCY_CLOSURE") != "PASS":
        raise ManifestError("n1i_a_native_closure_not_pass")

    ref_path = require_file(
        repo_root / "product/titan2/n1i-c1/a4-native-superset.txt",
        "a4_native_superset_reference",
    )
    refs = [
        line.strip()
        for line in ref_path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if len(refs) != 33 or len(set(refs)) != 33:
        raise ManifestError(
            f"a4_native_superset_reference_count={len(refs)} expected=33"
        )

    env_paths = n1i_env.get(
        "MUST_BE_SUPPLIED_BY_SABLE_SYSTEM_IMAGE", ""
    ).split()
    env_set = set(env_paths)
    repo_set = set(refs)
    if env_set != repo_set:
        env_only = sorted(env_set - repo_set)
        repo_only = sorted(repo_set - env_set)
        raise ManifestError(
            "n1i_a_a4_reference_drift="
            f"env_count:{len(env_set)},repo_count:{len(repo_set)};"
            "env_only=" + (",".join(env_only) or "NONE") + ";"
            "repo_only=" + (",".join(repo_only) or "NONE")
        )

    a4_path = require_file(n1i_a / "a4-native-closure.tsv", "n1i_a_a4_native_closure")
    rows = read_tsv(a4_path)
    required = {"binary", "side", "bits", "machine", "DT_NEEDED", "present_in_c3a"}
    if rows and not required.issubset(rows[0]):
        missing = sorted(required - set(rows[0]))
        raise ManifestError("n1i_a_a4_columns_missing=" + ",".join(missing))

    by_binary = {row["binary"]: row for row in rows}
    if len(by_binary) != len(rows):
        raise ManifestError("n1i_a_a4_duplicate_binary_row")

    out: list[dict[str, object]] = []
    for target in refs:
        row = by_binary.get(target)
        if row is None:
            raise ManifestError(f"n1i_a_a4_reference_missing={target}")
        if row["side"] != "system" or row["present_in_c3a"] != "NO":
            raise ManifestError(
                f"n1i_a_a4_reference_not_stock_only={target}:"
                f"side={row['side']}:c3a={row['present_in_c3a']}"
            )
        parts = Path(target).parts
        if len(parts) < 3 or parts[1] not in SYSTEM_SIDE:
            raise ManifestError(f"n1i_a_a4_bad_target={target}")
        out.append({
            "library": Path(target).name,
            "partition": parts[1],
            "target": target,
            "stock_path": "N1I_A_ACCEPTED_STOCK_DEVICE_PATH",
            "sha256": "FREEZE_DURING_IMPLEMENTATION_MATERIALIZATION",
            "needed": row["DT_NEEDED"] or "-",
            "admitted_by": "N1I_A_A4_ACCEPTED_SYSTEM_SIDE_SUPERSET",
            "evidence_strength": "ACCEPTED_HOST_AUDIT_SUPERSET",
            "c3a_status": "ABSENT_BY_ACCEPTED_A4",
            "decision": "ADMIT_ACCEPTED_A4_COMPATIBILITY_SUPERSET",
        })
    return out, sha256_file(a4_path)


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

    repo_root = Path(__file__).resolve().parents[2]
    evidence_root = args.evidence_root.resolve()
    if (args.b2_stock_native is None) != (args.b2_c3a_native is None):
        raise ManifestError("b2_explicit_authority_requires_stock_and_c3a_together")

    stock_dir: Path | None = None
    c3a_dir: Path | None = None
    a4_sha = "-"
    if args.b2_stock_native is not None:
        stock_dir = resolve_b2_dir(
            args.b2_stock_native, "stock", evidence_root, OEM_IMS_SHA256
        )
        c3a_dir = resolve_b2_dir(
            args.b2_c3a_native, "c3a", evidence_root, OEM_IMS_SHA256
        )
        native_authority = "N1I_B2_EXACT"
    else:
        stock_candidates = b2_candidates("stock", evidence_root, OEM_IMS_SHA256)
        c3a_candidates = b2_candidates("c3a", evidence_root, OEM_IMS_SHA256)
        if len(stock_candidates) == 1 and len(c3a_candidates) == 1:
            stock_dir = stock_candidates[0]
            c3a_dir = c3a_candidates[0]
            native_authority = "N1I_B2_EXACT"
        elif not stock_candidates and not c3a_candidates:
            native_authority = "N1I_A_A4_ACCEPTED_SUPERSET"
        else:
            raise ManifestError(
                "b2_partial_or_ambiguous_authority="
                f"stock:{len(stock_candidates)},c3a:{len(c3a_candidates)}"
            )

    if native_authority == "N1I_B2_EXACT":
        assert stock_dir is not None and c3a_dir is not None
        if stock_dir == c3a_dir:
            raise ManifestError("b2_stock_and_c3a_same_directory")
        native_rows, native_blockers = native_closure(stock_dir, c3a_dir)
        if native_blockers:
            raise ManifestError(
                "b2_native_closure_not_finite=" + ",".join(native_blockers)
            )
        native_authority_detail = "EXACT_B2_STOCK_VS_C3A"
    else:
        native_rows, a4_sha = a4_native_superset(n1i_a, repo_root, n1i_env)
        native_authority_detail = (
            "ACCEPTED_N1I_A_A4_33_FILE_COMPATIBILITY_SUPERSET;"
            "B2_NOT_RETAINED_NON_BLOCKING_FOR_MVP"
        )

    tmetrics = require_file(
        android / "frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java",
        "telephonymetrics_source",
    )
    tmetrics_blob = git_blob_file(tmetrics)
    if tmetrics_blob not in {TMETRICS_BASE_BLOB, TMETRICS_POST_BLOB}:
        raise ManifestError(f"telephonymetrics_unexpected_blob={tmetrics_blob}")

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
            "authority": "NATIVE_CLOSURE",
            "path": (
                f"stock={stock_dir};c3a={c3a_dir}"
                if native_authority == "N1I_B2_EXACT"
                else str(n1i_a / "a4-native-closure.tsv")
            ),
            "sha256": a4_sha if native_authority != "N1I_B2_EXACT" else "-",
            "git_blob": "-",
            "state": native_authority,
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
        action = (
            "ADMIT_EXACT_STOCK_LIBRARY"
            if native_authority == "N1I_B2_EXACT"
            else "ADMIT_ACCEPTED_A4_COMPATIBILITY_SUPERSET"
        )
        basis = (
            f"B2 exact stock-only system-side closure; {row['evidence_strength']}"
            if native_authority == "N1I_B2_EXACT"
            else (
                "accepted N1I-A native closure PASS; exact 33-path A4 "
                "compatibility superset; per-file hashes freeze before build"
            )
        )
        add(
            f"M{next_id:03d}", "NATIVE", action,
            str(row["target"]), str(row["stock_path"]), str(row["sha256"]), basis,
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
        "N1I_C2_MANIFEST_NATIVE_AUTHORITY": native_authority,
        "N1I_C2_MANIFEST_NATIVE_AUTHORITY_DETAIL": native_authority_detail,
        "N1I_C2_MANIFEST_B2_STOCK_NATIVE_DIR": str(stock_dir or "NONE_NOT_RETAINED"),
        "N1I_C2_MANIFEST_B2_C3A_NATIVE_DIR": str(c3a_dir or "NONE_NOT_RETAINED"),
        "N1I_C2_MANIFEST_N1I_A_A4_SHA256": a4_sha,
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
