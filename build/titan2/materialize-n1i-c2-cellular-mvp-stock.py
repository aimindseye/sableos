#!/usr/bin/env python3
"""Freeze the proprietary stock payload for the Titan 2 Cellular MVP.

Host-only materialization. Reads a sealed N1I-C2 mutation manifest plus a
qualified N1I-A replay extraction and writes a sealed stock bundle outside the
source tree. It never mutates Android source, builds, contacts a device, uses
the network, reboots, or flashes.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
import struct
import sys
from pathlib import Path

TOOL_VERSION = "1.1.0"

EXPECTED_OEM_IMS_SHA = "30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539"
EXPECTED_COMMON_JAR_SHA = "511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549"
EXPECTED_IMS_BASE_JAR_SHA = "bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab"
EXPECTED_A4_SHA = "6dad2e573b912d6a20fd5b16cb667dc15b9d43cb1f831fa2751830282e437fd4"
EXPECTED_A4_REFERENCE_BLOB = "4eaa02f10b6732c07ffe2fa2e244824297da1cb3"

EXPECTED_STOCK_SYSTEM_SHA = "b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd"
EXPECTED_STOCK_PRODUCT_SHA = "de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37"
EXPECTED_STOCK_SYSTEM_EXT_SHA = "1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170"
EXPECTED_STOCK_VENDOR_SHA = "cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada"
EXPECTED_C3A_SHA = "4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"

EXPECTED_TMETRICS_PATCH_BLOB = "ee353caded6dd07318991eb52d66687e06034c30"
EXPECTED_IMS_CALL_TRACKER_BLOB = "5f97183b6f8c80859adf3f4922b3f9f56687bab5"
EXPECTED_PHH_ON_BOOT_BLOB = "9f65610762fec239638bb269b8c72d6cabfc6d7e"

EXPECTED_MUTATION_IDS = {f"M{i:03d}" for i in range(1, 42)}
EXPECTED_NON_STOCK_MUTATIONS = {
    "M004": {
        "domain": "FRAMEWORK",
        "action": "APPLY_PATCH",
        "target_suffix": "/frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java",
        "sha256_or_blob": EXPECTED_TMETRICS_PATCH_BLOB,
    },
    "M005": {
        "domain": "TELEPHONY",
        "action": "SET_PRODUCT_PROPERTY_FALSE",
        "target": "ro.telephony.block_binder_thread_on_incoming_calls",
        "sha256_or_blob": EXPECTED_IMS_CALL_TRACKER_BLOB,
    },
    "M006": {
        "domain": "PHH",
        "action": "TITAN_GUARD_MTKMAL_IMS_DISABLE_BRANCH",
        "target_suffix": "/device/phh/treble/phh-on-boot.sh",
        "sha256_or_blob": EXPECTED_PHH_ON_BOOT_BLOB,
    },
    "M040": {
        "domain": "INTEGRATION",
        "action": "ADD_SABLE_TITAN_CELLULAR_INTEGRATION_PACKAGE",
        "target": "vendor/sable/titan2/n1i-c2",
        "sha256_or_blob": "-",
    },
    "M041": {
        "domain": "HEALER",
        "action": "SHIP_DISABLED_BY_DEFAULT",
        "target": "Sable Titan cellular integration package",
        "sha256_or_blob": "-",
    },
}

EXPECTED_NATIVE_COUNT = 33
EXPECTED_STOCK_FILE_COUNT = 36
EXPECTED_MUTATION_COUNT = 41

SYSTEM_SIDE = {"system", "system_ext", "product"}


class MaterializeError(RuntimeError):
    pass


def require_safe_output(out: Path, protected: list[Path]) -> Path:
    resolved = out.resolve()
    for base in protected:
        base_resolved = base.resolve()
        if resolved == base_resolved:
            raise MaterializeError(f"output_overlaps_protected={resolved}")
        try:
            resolved.relative_to(base_resolved)
        except ValueError:
            pass
        else:
            raise MaterializeError(
                f"output_inside_protected={resolved}:protected:{base_resolved}"
            )
    return resolved


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


def canonical_a4_targets(repo_root: Path) -> set[str]:
    path = repo_root / "product/titan2/n1i-c1/a4-native-superset.txt"
    if not path.is_file():
        raise MaterializeError(f"a4_reference_missing={path}")
    blob = git_blob_file(path)
    if blob != EXPECTED_A4_REFERENCE_BLOB:
        raise MaterializeError(
            f"a4_reference_blob_drift=expected:{EXPECTED_A4_REFERENCE_BLOB}:actual:{blob}"
        )
    targets = {
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    if len(targets) != EXPECTED_NATIVE_COUNT:
        raise MaterializeError(
            f"a4_reference_target_count={len(targets)} expected={EXPECTED_NATIVE_COUNT}"
        )
    return targets


def parse_env(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise MaterializeError(f"missing_env={path}")
    out: dict[str, str] = {}
    for no, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in out:
            raise MaterializeError(f"duplicate_env_key={key} file={path} line={no}")
        if value.startswith('"'):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError as exc:
                raise MaterializeError(
                    f"invalid_json_env_value={key} file={path} line={no}: {exc}"
                ) from exc
            if not isinstance(decoded, str):
                raise MaterializeError(f"non_string_env_value={key} file={path} line={no}")
            value = decoded
        out[key] = value
    return out


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise MaterializeError(f"missing_tsv={path}")
    with path.open(encoding="utf-8", newline="") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        if reader.fieldnames is None:
            raise MaterializeError(f"missing_tsv_header={path}")
        return list(reader)


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: str(row.get(field, "")) for field in fields})


def verify_sha256s(root: Path) -> None:
    seal = root / "SHA256SUMS.txt"
    if not seal.is_file():
        raise MaterializeError(f"seal_missing={seal}")
    for no, raw in enumerate(seal.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        try:
            digest, rel = line.split(None, 1)
        except ValueError as exc:
            raise MaterializeError(f"bad_seal_line={no}:{line}") from exc
        rel = rel.lstrip("*")
        target = (root / rel).resolve()
        try:
            target.relative_to(root.resolve())
        except ValueError as exc:
            raise MaterializeError(f"seal_path_escape={rel}") from exc
        if not target.is_file():
            raise MaterializeError(f"sealed_file_missing={rel}")
        actual = sha256_file(target)
        if actual != digest:
            raise MaterializeError(f"seal_mismatch={rel}:expected:{digest}:actual:{actual}")


def inputs_map(path: Path) -> dict[str, dict[str, str]]:
    rows = read_tsv(path)
    required = {"input", "path", "sha256", "pinned", "match"}
    if rows and not required.issubset(rows[0]):
        raise MaterializeError(
            "replay_inputs_columns_missing=" + ",".join(sorted(required - set(rows[0])))
        )
    out: dict[str, dict[str, str]] = {}
    for row in rows:
        name = row["input"]
        if name in out:
            raise MaterializeError(f"replay_duplicate_input={name}")
        out[name] = row
    return out


def verify_replay(replay: Path) -> None:
    env = parse_env(replay / "n1i-a-v010014-oem-ims.env")
    for key, expected in (
        ("N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE", "PASS"),
        ("N1I_A_NATIVE_DEPENDENCY_CLOSURE", "PASS"),
        ("OEM_IMS_APK_SHA256", EXPECTED_OEM_IMS_SHA),
    ):
        actual = env.get(key, "")
        if actual != expected:
            raise MaterializeError(f"replay_env_mismatch={key}:expected:{expected}:actual:{actual}")

    inputs = inputs_map(replay / "inputs.tsv")
    expected = {
        "stock-system.img": EXPECTED_STOCK_SYSTEM_SHA,
        "product.img": EXPECTED_STOCK_PRODUCT_SHA,
        "system_ext.img": EXPECTED_STOCK_SYSTEM_EXT_SHA,
        "vendor.img": EXPECTED_STOCK_VENDOR_SHA,
        "c3a-system.img": EXPECTED_C3A_SHA,
    }
    for name, digest in expected.items():
        row = inputs.get(name)
        if row is None:
            raise MaterializeError(f"replay_input_missing={name}")
        if row["sha256"] != digest:
            raise MaterializeError(
                f"replay_input_sha_mismatch={name}:expected:{digest}:actual:{row['sha256']}"
            )
        if name != "stock-system.img" and row["match"] != "YES":
            raise MaterializeError(f"replay_pinned_input_not_match={name}:{row['match']}")

    work = replay / "work" / "stock"
    required_dirs = [
        work / "system_img",
        work / "system_ext",
        work / "product",
    ]
    for directory in required_dirs:
        if not directory.is_dir():
            raise MaterializeError(f"replay_extracted_tree_missing={directory}")


def system_root(replay: Path) -> Path:
    root = replay / "work" / "stock" / "system_img"
    nested = root / "system"
    return nested if (nested / "build.prop").is_file() else root


def partition_root(replay: Path, partition: str) -> Path:
    if partition == "system":
        return system_root(replay)
    if partition in {"system_ext", "product"}:
        return replay / "work" / "stock" / partition
    raise MaterializeError(f"unsupported_partition={partition}")


def source_for_target(replay: Path, target: str) -> tuple[str, Path]:
    p = Path(target)
    if not p.is_absolute() or len(p.parts) < 3:
        raise MaterializeError(f"bad_target={target}")
    partition = p.parts[1]
    if partition not in SYSTEM_SIDE:
        raise MaterializeError(f"target_partition_not_system_side={target}")
    root = partition_root(replay, partition).resolve()
    rel = Path(*p.parts[2:])
    candidate = root / rel
    if candidate.is_symlink():
        raise MaterializeError(f"stock_source_symlink={target}:path:{candidate}")
    source = candidate.resolve()
    try:
        source.relative_to(root)
    except ValueError as exc:
        raise MaterializeError(f"target_source_escape={target}") from exc
    if not source.is_file():
        raise MaterializeError(f"stock_source_missing={target}:resolved:{source}")
    return partition, source


def elf64_aarch64(path: Path) -> tuple[str, int]:
    with path.open("rb") as fp:
        data = fp.read(20)
    if len(data) < 20 or data[:4] != b"\x7fELF":
        raise MaterializeError(f"native_not_elf={path}")
    elf_class = data[4]
    endian = data[5]
    if elf_class != 2 or endian != 1:
        raise MaterializeError(f"native_not_elf64_le={path}:class:{elf_class}:endian:{endian}")
    machine = struct.unpack_from("<H", data, 18)[0]
    if machine != 183:
        raise MaterializeError(f"native_not_aarch64={path}:machine:{machine}")
    return "ELF64", machine


def validate_manifest(
    manifest: Path,
    repo_root: Path,
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    verify_sha256s(manifest)
    summary = parse_env(manifest / "CELLULAR_MVP_SUMMARY.env")
    expected = {
        "N1I_C2_MANIFEST_OEM_IMS_SHA256": EXPECTED_OEM_IMS_SHA,
        "N1I_C2_MANIFEST_NATIVE_AUTHORITY": "N1I_A_A4_ACCEPTED_SUPERSET",
        "N1I_C2_MANIFEST_N1I_A_A4_SHA256": EXPECTED_A4_SHA,
        "N1I_C2_MANIFEST_NATIVE_IMPORT_COUNT": str(EXPECTED_NATIVE_COUNT),
        "N1I_C2_MANIFEST_NATIVE_CLOSURE": "PASS_FINITE",
        "N1I_C2_MANIFEST_MUTATION_COUNT": str(EXPECTED_MUTATION_COUNT),
        "N1I_C2_MANIFEST_MUTATION_SET": "PASS_FINITE_REVIEWABLE",
        "N1I_C2_CELLULAR_MVP_MUTATION_MANIFEST": "PASS",
    }
    for key, want in expected.items():
        got = summary.get(key, "")
        if got != want:
            raise MaterializeError(f"manifest_summary_mismatch={key}:expected:{want}:actual:{got}")

    mutations = read_tsv(manifest / "CELLULAR_MVP_MUTATION_MANIFEST.tsv")
    natives = read_tsv(manifest / "CELLULAR_MVP_NATIVE_CLOSURE.tsv")
    if len(mutations) != EXPECTED_MUTATION_COUNT:
        raise MaterializeError(f"mutation_count={len(mutations)}")
    if len(natives) != EXPECTED_NATIVE_COUNT:
        raise MaterializeError(f"native_count={len(natives)}")

    native_targets = {row.get("target", "") for row in natives}
    expected_targets = canonical_a4_targets(repo_root)
    if native_targets != expected_targets:
        raise MaterializeError(
            "native_target_authority_drift="
            f"missing:{','.join(sorted(expected_targets - native_targets)) or 'NONE'};"
            f"extra:{','.join(sorted(native_targets - expected_targets)) or 'NONE'}"
        )

    by_id = {row.get("id", ""): row for row in mutations}
    if len(by_id) != len(mutations):
        raise MaterializeError("duplicate_mutation_id")
    if set(by_id) != EXPECTED_MUTATION_IDS:
        missing = sorted(EXPECTED_MUTATION_IDS - set(by_id))
        extra = sorted(set(by_id) - EXPECTED_MUTATION_IDS)
        raise MaterializeError(
            "mutation_id_set_drift="
            f"missing:{','.join(missing) or 'NONE'};"
            f"extra:{','.join(extra) or 'NONE'}"
        )
    for mid, expected_row in EXPECTED_NON_STOCK_MUTATIONS.items():
        row = by_id[mid]
        for field in ("domain", "action", "sha256_or_blob"):
            if row.get(field) != expected_row[field]:
                raise MaterializeError(
                    f"mutation_semantic_drift={mid}:{field}:"
                    f"expected:{expected_row[field]}:actual:{row.get(field, '')}"
                )
        if "target" in expected_row and row.get("target") != expected_row["target"]:
            raise MaterializeError(
                f"mutation_semantic_drift={mid}:target:"
                f"expected:{expected_row['target']}:actual:{row.get('target', '')}"
            )
        suffix = expected_row.get("target_suffix")
        if suffix is not None and not row.get("target", "").endswith(str(suffix)):
            raise MaterializeError(
                f"mutation_semantic_drift={mid}:target_suffix:"
                f"expected:{suffix}:actual:{row.get('target', '')}"
            )
    if any(row.get("status") != "PROPOSED_NOT_AUTHORIZED" for row in mutations):
        raise MaterializeError("mutation_input_status_not_proposed")

    return mutations, natives


def expected_stock_rows(
    mutations: list[dict[str, str]],
    natives: list[dict[str, str]],
) -> list[dict[str, str]]:
    by_id = {row["id"]: row for row in mutations}

    expected_core = {
        "M001": (
            "OEM_IMS", "RETAIN",
            "/system_ext/priv-app/ImsService/ImsService.apk",
            EXPECTED_OEM_IMS_SHA, "APK",
        ),
        "M002": (
            "JAVA", "RETAIN",
            "/system_ext/framework/mediatek-common.jar",
            EXPECTED_COMMON_JAR_SHA, "JAR",
        ),
        "M003": (
            "JAVA", "RETAIN",
            "/system_ext/framework/mediatek-ims-base.jar",
            EXPECTED_IMS_BASE_JAR_SHA, "JAR",
        ),
    }
    rows: list[dict[str, str]] = []
    for mid, (domain, action, target, digest, kind) in expected_core.items():
        row = by_id.get(mid)
        if row is None:
            raise MaterializeError(f"core_mutation_missing={mid}")
        if (
            row.get("domain") != domain
            or row.get("action") != action
            or row.get("target") != target
            or row.get("sha256_or_blob") != digest
        ):
            raise MaterializeError(f"core_mutation_drift={mid}")
        rows.append({
            "mutation_id": mid,
            "target": target,
            "expected_sha256": digest,
            "kind": kind,
            "authority": row.get("basis", ""),
        })

    native_targets = {row["target"] for row in natives}
    if len(native_targets) != EXPECTED_NATIVE_COUNT:
        raise MaterializeError("native_target_duplicate")
    native_mutations = [
        row for row in mutations
        if row.get("domain") == "NATIVE"
        and row.get("action") == "ADMIT_ACCEPTED_A4_COMPATIBILITY_SUPERSET"
    ]
    if len(native_mutations) != EXPECTED_NATIVE_COUNT:
        raise MaterializeError(f"native_mutation_count={len(native_mutations)}")
    expected_native_ids = {f"M{i:03d}" for i in range(7, 40)}
    actual_native_ids = {row["id"] for row in native_mutations}
    if actual_native_ids != expected_native_ids:
        raise MaterializeError(
            "native_mutation_id_set_drift="
            f"missing:{','.join(sorted(expected_native_ids - actual_native_ids)) or 'NONE'};"
            f"extra:{','.join(sorted(actual_native_ids - expected_native_ids)) or 'NONE'}"
        )
    if {row["target"] for row in native_mutations} != native_targets:
        raise MaterializeError("native_manifest_target_set_mismatch")

    for row in sorted(native_mutations, key=lambda r: r["id"]):
        if row.get("sha256_or_blob") != "FREEZE_DURING_IMPLEMENTATION_MATERIALIZATION":
            raise MaterializeError(f"native_not_pending_freeze={row['id']}")
        rows.append({
            "mutation_id": row["id"],
            "target": row["target"],
            "expected_sha256": "",
            "kind": "NATIVE",
            "authority": row.get("basis", ""),
        })
    return rows


def seal_output(out: Path) -> None:
    seal = out / "SHA256SUMS.txt"
    files = sorted(
        p for p in out.rglob("*")
        if p.is_file() and p != seal
    )
    with seal.open("w", encoding="utf-8") as fp:
        for path in files:
            rel = path.relative_to(out)
            fp.write(f"{sha256_file(path)}  {rel.as_posix()}\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest-evidence", type=Path, required=True)
    ap.add_argument("--replay-evidence", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    manifest = args.manifest_evidence.resolve()
    replay = args.replay_evidence.resolve()
    repo_root = Path(__file__).resolve().parents[2]
    out = require_safe_output(args.out, [repo_root, manifest, replay])

    print("===== N1I-C2 CELLULAR MVP STOCK MATERIALIZATION =====")
    print("SOURCE_MUTATION_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("REBOOT_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print(f"TOOL_VERSION={TOOL_VERSION}")
    print(f"MANIFEST_EVIDENCE={manifest}")
    print(f"REPLAY_EVIDENCE={replay}")

    if out.exists():
        raise MaterializeError(f"out_already_exists={out}")

    mutations, natives = validate_manifest(manifest, repo_root)
    verify_replay(replay)
    planned = expected_stock_rows(mutations, natives)

    out.mkdir(parents=True)
    file_root = out / "files"
    materialized: list[dict[str, object]] = []
    hash_by_target: dict[str, str] = {}

    for row in planned:
        target = row["target"]
        partition, source = source_for_target(replay, target)
        digest = sha256_file(source)
        expected = row["expected_sha256"]
        if expected and digest != expected:
            raise MaterializeError(
                f"stock_hash_mismatch={target}:expected:{expected}:actual:{digest}"
            )

        kind = row["kind"]
        elf_class = "-"
        machine: object = "-"
        if kind == "NATIVE":
            elf_class, machine = elf64_aarch64(source)

        destination = file_root / target.lstrip("/")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        os.chmod(destination, 0o644)
        copied = sha256_file(destination)
        if copied != digest:
            raise MaterializeError(f"copy_hash_mismatch={target}")

        hash_by_target[target] = digest
        materialized.append({
            "mutation_id": row["mutation_id"],
            "kind": kind,
            "partition": partition,
            "target": target,
            "source": str(source),
            "bundle_path": str(destination.relative_to(out)),
            "sha256": digest,
            "bytes": source.stat().st_size,
            "elf_class": elf_class,
            "elf_machine": machine,
            "authority": row["authority"],
        })

    if len(materialized) != EXPECTED_STOCK_FILE_COUNT:
        raise MaterializeError(f"stock_file_count={len(materialized)}")
    native_count = sum(1 for row in materialized if row["kind"] == "NATIVE")
    if native_count != EXPECTED_NATIVE_COUNT:
        raise MaterializeError(f"materialized_native_count={native_count}")

    write_tsv(
        out / "CELLULAR_MVP_STOCK_MATERIALIZATION.tsv",
        [
            "mutation_id", "kind", "partition", "target", "source", "bundle_path",
            "sha256", "bytes", "elf_class", "elf_machine", "authority",
        ],
        materialized,
    )

    frozen: list[dict[str, object]] = []
    for row in mutations:
        new = dict(row)
        target = row.get("target", "")
        if target in hash_by_target:
            new["sha256_or_blob"] = hash_by_target[target]
            new["source"] = f"SEALED_STOCK_BUNDLE:files/{target.lstrip('/')}"
            new["status"] = "MATERIALIZED_VERIFIED"
        frozen.append(new)

    write_tsv(
        out / "CELLULAR_MVP_FROZEN_MUTATION_MANIFEST.tsv",
        ["id", "domain", "action", "target", "source", "sha256_or_blob", "basis", "status"],
        frozen,
    )

    native_hash_count = sum(
        1 for row in frozen
        if row.get("domain") == "NATIVE"
        and row.get("status") == "MATERIALIZED_VERIFIED"
        and len(str(row.get("sha256_or_blob", ""))) == 64
    )
    if native_hash_count != EXPECTED_NATIVE_COUNT:
        raise MaterializeError(f"frozen_native_hash_count={native_hash_count}")

    summary = {
        "N1I_C2_MATERIALIZATION_TOOL_VERSION": TOOL_VERSION,
        "N1I_C2_MATERIALIZATION_MANIFEST_EVIDENCE": str(manifest),
        "N1I_C2_MATERIALIZATION_REPLAY_EVIDENCE": str(replay),
        "N1I_C2_MATERIALIZATION_STOCK_FILE_COUNT": str(len(materialized)),
        "N1I_C2_MATERIALIZATION_CORE_FILE_COUNT": "3",
        "N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT": str(native_count),
        "N1I_C2_MATERIALIZATION_NATIVE_HASH_COUNT": str(native_hash_count),
        "N1I_C2_MATERIALIZATION_MUTATION_COUNT": str(len(frozen)),
        "N1I_C2_MATERIALIZATION_STOCK_SYSTEM_SHA256": EXPECTED_STOCK_SYSTEM_SHA,
        "N1I_C2_MATERIALIZATION_STOCK_SYSTEM_EXT_SHA256": EXPECTED_STOCK_SYSTEM_EXT_SHA,
        "N1I_C2_MATERIALIZATION_STOCK_PRODUCT_SHA256": EXPECTED_STOCK_PRODUCT_SHA,
        "N1I_C2_MATERIALIZATION_STOCK_VENDOR_SHA256": EXPECTED_STOCK_VENDOR_SHA,
        "N1I_C2_MATERIALIZATION_C3A_SHA256": EXPECTED_C3A_SHA,
        "N1I_C2_MATERIALIZATION_SOURCE_MUTATION_AUTHORIZED": "NO",
        "N1I_C2_MATERIALIZATION_BUILD_AUTHORIZED": "NO",
        "N1I_C2_MATERIALIZATION_DEVICE_CONTACT_AUTHORIZED": "NO",
        "N1I_C2_MATERIALIZATION_FLASH_AUTHORIZED": "NO",
        "N1I_C2_CELLULAR_MVP_STOCK_MATERIALIZATION": "PASS",
    }
    with (out / "CELLULAR_MVP_MATERIALIZATION_SUMMARY.env").open("w", encoding="utf-8") as fp:
        for key, value in summary.items():
            fp.write(f"{key}={value}\n")

    seal_output(out)

    for key, value in summary.items():
        print(f"{key}={value}")
    print(f"N1I_C2_MATERIALIZATION_OUT={out}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MaterializeError as exc:
        print(f"N1I_C2_CELLULAR_MVP_STOCK_MATERIALIZATION=FAIL reason={exc}", file=sys.stderr)
        raise SystemExit(2)
