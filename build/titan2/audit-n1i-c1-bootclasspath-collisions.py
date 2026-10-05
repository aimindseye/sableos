#!/usr/bin/env python3
"""Titan 2 N1I-C1 bootclasspath duplicate-class safety audit.

Offline/read-only. This audit answers one narrow question before any further
physical action: do the two OEM MediaTek jars promoted into the C1 bootclasspath
define classes that are already owned by an earlier C3A/AOSP boot jar, or by
each other?

It deliberately does not infer that omitted stock MTK boot jars are required.
The earlier N1I-A audit already handled APK type-reference closure. This audit
covers the separate first-definition-wins bootclasspath ownership boundary that
N1I-A did not qualify.

No device contact, network access, build, source mutation, image mutation, or
flash operation is performed.
"""

from __future__ import annotations

import argparse
import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "build" / "titan2"))

import n1i_static as S  # noqa: E402

COMMON = "/system_ext/framework/mediatek-common.jar"
IMS_BASE = "/system_ext/framework/mediatek-ims-base.jar"
BOOTPB_REL = Path("system/etc/classpaths/bootclasspath.pb")
PATH_RE = re.compile(
    rb"/(?:system|system_ext|product|apex)/[A-Za-z0-9_@.+\-/]+\.jar"
)


class AuditError(Exception):
    pass


@dataclass(frozen=True)
class Result:
    entry_count: int
    common_index: int
    ims_base_index: int
    base_class_count: int
    common_class_count: int
    ims_base_class_count: int
    common_vs_base: tuple[str, ...]
    ims_base_vs_base: tuple[str, ...]
    mutual: tuple[str, ...]


def parse_boot_entries(path: Path) -> list[str]:
    data = path.read_bytes()
    out: list[str] = []
    seen: set[str] = set()
    for match in PATH_RE.finditer(data):
        value = match.group(0).decode("utf-8", "strict")
        if value not in seen:
            seen.add(value)
            out.append(value)
    if not out:
        raise AuditError(f"no bootclasspath jar paths in {path}")
    return out


def product_path(product_out: Path, device_path: str) -> Path | None:
    if device_path.startswith("/system_ext/"):
        return (
            product_out
            / "system"
            / "system_ext"
            / device_path.removeprefix("/system_ext/")
        )
    if device_path.startswith("/system/"):
        return product_out / "system" / device_path.removeprefix("/system/")
    if device_path.startswith("/product/"):
        return (
            product_out
            / "system"
            / "product"
            / device_path.removeprefix("/product/")
        )
    # C1's imported jars are before the only observed /apex boot entry.
    # APEX extraction is therefore unnecessary for the first-definition
    # collision question this audit answers.
    return None


def vdex_dexes(path: Path) -> list[S.DexFile]:
    stem = path.stem
    for arch in ("arm64", "arm"):
        vdex = path.parent / "oat" / arch / f"{stem}.vdex"
        if not vdex.is_file():
            continue
        data = vdex.read_bytes()
        dexes: list[S.DexFile] = []
        for match in re.finditer(rb"dex\n0[0-9]{2}\x00", data):
            start = match.start()
            if start + 0x24 > len(data):
                raise AuditError(f"vdex_truncated_dex_header={vdex}:{start:#x}")
            size = struct.unpack_from("<I", data, start + 0x20)[0]
            if size < 0x70 or start + size > len(data):
                raise AuditError(
                    f"vdex_invalid_dex_size={vdex}:{start:#x}:size={size}"
                )
            try:
                dexes.append(
                    S.DexFile(
                        data[start : start + size],
                        f"{vdex.name}@{start:#x}",
                    )
                )
            except S.DexError as exc:
                raise AuditError(f"vdex_dex_parse_failed={vdex}:{exc}") from exc
        if dexes:
            return dexes
        if b"cdex" in data:
            raise AuditError(f"compact_vdex_unsupported={vdex}")
        raise AuditError(f"vdex_contains_no_standard_dex={vdex}")
    return []


def defined_classes(path: Path) -> tuple[set[str], str]:
    container = None
    load_error = None
    try:
        container = S.load_container(path)
    except (OSError, S.DexError) as exc:
        load_error = exc

    dexes = list(container.dexes) if container is not None else []
    source = "JAR_CLASSES_DEX"
    if not dexes:
        fallback = vdex_dexes(path)
        if fallback:
            dexes = [(dex.name, dex) for dex in fallback]
            source = "SIBLING_VDEX"
        elif load_error is not None:
            raise AuditError(f"dex_load_failed={path}:{load_error}") from load_error
        else:
            raise AuditError(f"no_classes_dex_or_vdex={path}")

    out = {
        cd.descriptor
        for _entry, dex in dexes
        for cd in dex.classes
    }
    if not out:
        raise AuditError(f"no_defined_classes={path}")
    return out, source


def analyse(
    entries: list[str],
    classes: dict[str, set[str]],
) -> Result:
    if entries.count(COMMON) != 1:
        raise AuditError(f"common_entry_count={entries.count(COMMON)}")
    if entries.count(IMS_BASE) != 1:
        raise AuditError(f"ims_base_entry_count={entries.count(IMS_BASE)}")

    common_index = entries.index(COMMON)
    ims_base_index = entries.index(IMS_BASE)
    if common_index >= ims_base_index:
        raise AuditError(
            f"import_order_invalid=common:{common_index},ims_base:{ims_base_index}"
        )

    needed = entries[: ims_base_index + 1]
    missing = [p for p in needed if p not in classes]
    if missing:
        raise AuditError("class_inventory_missing=" + ",".join(missing))

    base_classes: set[str] = set()
    for entry in entries[:common_index]:
        base_classes.update(classes[entry])

    common = classes[COMMON]
    ims_base = classes[IMS_BASE]

    return Result(
        entry_count=len(entries),
        common_index=common_index,
        ims_base_index=ims_base_index,
        base_class_count=len(base_classes),
        common_class_count=len(common),
        ims_base_class_count=len(ims_base),
        common_vs_base=tuple(sorted(common & base_classes)),
        ims_base_vs_base=tuple(sorted(ims_base & base_classes)),
        mutual=tuple(sorted(common & ims_base)),
    )


def emit_collision(prefix: str, values: tuple[str, ...]) -> None:
    print(f"{prefix}_COUNT={len(values)}")
    for index, value in enumerate(values[:100]):
        print(f"{prefix}[{index}]={value}")
    if len(values) > 100:
        print(f"{prefix}_TRUNCATED={len(values) - 100}")


def run(product_out: Path) -> int:
    product_out = product_out.resolve()
    bootpb = product_out / BOOTPB_REL
    if not product_out.is_dir():
        raise AuditError(f"product_out_missing={product_out}")
    if not bootpb.is_file():
        raise AuditError(f"bootclasspath_pb_missing={bootpb}")

    entries = parse_boot_entries(bootpb)
    if COMMON not in entries or IMS_BASE not in entries:
        raise AuditError("required_imported_boot_jars_missing")

    common_index = entries.index(COMMON)
    ims_base_index = entries.index(IMS_BASE)

    inventories: dict[str, set[str]] = {}
    for index, device_path in enumerate(entries[: ims_base_index + 1]):
        host = product_path(product_out, device_path)
        if host is None:
            raise AuditError(
                f"unmapped_pre_import_boot_entry=index:{index},path:{device_path}"
            )
        if not host.is_file():
            raise AuditError(
                f"boot_jar_missing=index:{index},device:{device_path},host:{host}"
            )
        classes, source = defined_classes(host)
        inventories[device_path] = classes
        print(
            "N1I_C1_BCP_CLASS_INVENTORY="
            f"index={index} device={device_path} "
            f"classes={len(classes)} source={source}"
        )

    result = analyse(entries, inventories)

    print("===== N1I-C1 BOOTCLASSPATH DUPLICATE-CLASS SAFETY AUDIT =====")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print(f"PRODUCT_OUT={product_out}")
    print(f"N1I_C1_BCP_ENTRY_COUNT={result.entry_count}")
    print(f"N1I_C1_BCP_COMMON_INDEX={result.common_index}")
    print(f"N1I_C1_BCP_IMS_BASE_INDEX={result.ims_base_index}")
    print(f"N1I_C1_BCP_BASE_CLASS_COUNT={result.base_class_count}")
    print(f"N1I_C1_BCP_COMMON_CLASS_COUNT={result.common_class_count}")
    print(f"N1I_C1_BCP_IMS_BASE_CLASS_COUNT={result.ims_base_class_count}")

    emit_collision(
        "N1I_C1_BCP_COMMON_SHADOWED_BY_BASE",
        result.common_vs_base,
    )
    emit_collision(
        "N1I_C1_BCP_IMS_BASE_SHADOWED_BY_BASE",
        result.ims_base_vs_base,
    )
    emit_collision(
        "N1I_C1_BCP_IMPORTED_MUTUAL_DUPLICATES",
        result.mutual,
    )

    total = (
        len(result.common_vs_base)
        + len(result.ims_base_vs_base)
        + len(result.mutual)
    )
    if total:
        print(
            "N1I_C1_BOOTCLASSPATH_COLLISION_AUDIT="
            f"FAIL_DUPLICATE_CLASS_OWNERSHIP total={total}"
        )
        return 1

    print("N1I_C1_BOOTCLASSPATH_COLLISION_AUDIT=PASS_NO_DUPLICATE_CLASS_OWNERSHIP")
    print("N1I_C1_DEVICE_CONTACT=NONE")
    print("N1I_C1_FLASH=NONE")
    return 0


def selftest() -> int:
    base = "/system/framework/framework.jar"
    entries = [base, COMMON, IMS_BASE]

    good = {
        base: {"Ljava/lang/Base;"},
        COMMON: {"Lcom/mediatek/Common;"},
        IMS_BASE: {"Lcom/mediatek/ImsBase;"},
    }
    r = analyse(entries, good)
    assert not r.common_vs_base
    assert not r.ims_base_vs_base
    assert not r.mutual

    common_collision = {
        base: {"Ljava/lang/Base;", "Ldup/Base;"},
        COMMON: {"Lcom/mediatek/Common;", "Ldup/Base;"},
        IMS_BASE: {"Lcom/mediatek/ImsBase;"},
    }
    r = analyse(entries, common_collision)
    assert r.common_vs_base == ("Ldup/Base;",)

    mutual_collision = {
        base: {"Ljava/lang/Base;"},
        COMMON: {"Lcom/mediatek/Common;", "Ldup/Mutual;"},
        IMS_BASE: {"Lcom/mediatek/ImsBase;", "Ldup/Mutual;"},
    }
    r = analyse(entries, mutual_collision)
    assert r.mutual == ("Ldup/Mutual;",)

    try:
        analyse([base, IMS_BASE, COMMON], good)
    except AuditError:
        pass
    else:
        raise AssertionError("invalid imported jar order was accepted")

    print("N1I_C1_BOOTCLASSPATH_COLLISION_AUDIT_SELFTEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--product-out", type=Path)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    try:
        if args.selftest:
            return selftest()
        if args.product_out is None:
            parser.error("--product-out is required unless --selftest is used")
        return run(args.product_out)
    except (AuditError, OSError, S.DexError) as exc:
        print(
            f"N1I_C1_BOOTCLASSPATH_COLLISION_AUDIT=FAIL reason={exc}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
