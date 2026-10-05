#!/usr/bin/env python3
"""Titan 2 N1I-C1 exact runtime member-linkage audit.

Consumes a materialized C1 bootclasspath manifest plus the built ImsService APK.
It reuses the N1I-B2 resolver's ART/JVM linkage model and analyzes code belonging
to the two imported MTK boot jars and to the IMS APK in the actual C1 runtime
world.

Offline/read-only: no device, network, build, image mutation or source mutation.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MEMBERS_TOOL = ROOT / "build" / "titan2" / "n1i-b2-members.py"

COMMON = "/system_ext/framework/mediatek-common.jar"
IMS_BASE = "/system_ext/framework/mediatek-ims-base.jar"

MEMBERS = None

RESULTS = (
    "RESOLVED",
    "CLASS_MISSING",
    "METHOD_MISSING",
    "FIELD_MISSING",
    "DESCRIPTOR_MISMATCH",
    "STATIC_INSTANCE_MISMATCH",
    "ACCESS_VIOLATION",
    "ICCE_KIND",
)


class AuditError(Exception):
    pass


def load_members_tool():
    global MEMBERS
    if MEMBERS is not None:
        return MEMBERS
    spec = importlib.util.spec_from_file_location("n1i_c1_members_base", MEMBERS_TOOL)
    if spec is None or spec.loader is None:
        raise AuditError(f"member_resolver_import_failed={MEMBERS_TOOL}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except Exception as exc:
        raise AuditError(f"member_resolver_import_failed={MEMBERS_TOOL}:{exc}") from exc
    MEMBERS = module
    return module


def parse_manifest(path: Path) -> list[tuple[str, Path]]:
    rows: list[tuple[str, Path]] = []
    seen: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        device, sep, host = raw.partition("\t")
        if not sep:
            raise AuditError(f"bad_bootclasspath_manifest_row={raw}")
        if device in seen:
            raise AuditError(f"duplicate_bootclasspath_device_path={device}")
        p = Path(host)
        if not p.is_file():
            raise AuditError(f"bootclasspath_host_file_missing={device}:{p}")
        rows.append((device, p))
        seen.add(device)
    if not rows:
        raise AuditError("bootclasspath_manifest_empty")
    if COMMON not in seen or IMS_BASE not in seen:
        raise AuditError("required_imported_boot_jars_missing")
    devices = [device for device, _host in rows]
    if devices.index(COMMON) >= devices.index(IMS_BASE):
        raise AuditError("imported_boot_jar_order_invalid")
    return rows


def parse_badging_uses(path: Path) -> list[tuple[str, bool]]:
    out: list[tuple[str, bool]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("uses-static-library"):
            raise AuditError(f"unmodeled_static_uses_library={line}")
        m = re.match(r"^uses-library(-not-required)?:'([^']+)'", line)
        if m:
            out.append((m.group(2), m.group(1) is None))
    return out


def classify_uses(
    uses: list[tuple[str, bool]],
) -> tuple[list[str], list[str]]:
    required = sorted(name for name, is_required in uses if is_required)
    optional = sorted(name for name, is_required in uses if not is_required)
    if required:
        raise AuditError(
            "unmodeled_required_uses_libraries=" + ",".join(required)
        )
    return required, optional


def clean(value: object) -> str:
    return str(value).replace("\t", " ").replace("\n", " ")


def duplicate_involves_import(
    first: str,
    second: str,
    imported_paths: set[str],
) -> bool:
    return any(path in first or path in second for path in imported_paths)


def require_core_runtime(world) -> None:
    required = (
        "Ljava/lang/Object;",
        "Ljava/lang/String;",
        "Ljava/lang/Class;",
        "Ljava/util/ArrayList;",
        "Ldalvik/system/PathClassLoader;",
    )
    missing = [desc for desc in required if world.klass(desc) is None]
    if missing:
        raise AuditError(
            "runtime_core_class_missing=" + ",".join(missing)
        )


def analyze_container(m, world, container, provider: str, label: str):
    counts = Counter({r: 0 for r in RESULTS})
    rows: dict[tuple, tuple[object, int]] = {}
    checks = []
    shadowed = []

    for entry, dex in container.dexes:
        for cd in dex.classes:
            k = world.klass(cd.descriptor)
            if k is None:
                raise AuditError(f"{label}_class_absent_from_world={cd.descriptor}")
            if k.cd is not cd or k.provider != provider:
                shadowed.append(
                    (cd.descriptor, k.provider, k.path)
                )
                continue
            for kind, target, out in m.class_checks(world, k):
                checks.append((k.desc, kind, target, out))
                counts[out.result] += 1
            for method in cd.methods:
                for row in m.references(world, k, dex, method):
                    key = (
                        row.caller,
                        row.ref_kind,
                        row.owner,
                        row.name,
                        row.desc,
                    )
                    if key in rows:
                        prior, n = rows[key]
                        rows[key] = (prior, n + 1)
                    else:
                        rows[key] = (row, 1)

    detail_rows = []
    for key in sorted(rows):
        row, occurrences = rows[key]
        out = row.out
        counts[out.result] += 1
        detail_rows.append(
            (
                row.caller,
                row.site,
                row.ref_kind,
                row.owner,
                row.name or "-",
                row.desc or "-",
                out.result,
                out.detail or "-",
                out.decl.desc if out.decl else "-",
                out.decl.provider if out.decl else "-",
                out.decl.path if out.decl else "-",
                occurrences,
            )
        )

    unresolved = sum(counts[r] for r in RESULTS if r != "RESOLVED")
    return counts, detail_rows, checks, shadowed, unresolved


def emit_target(label, counts, detail_rows, checks, shadowed, unresolved):
    prefix = f"N1I_C1_LINKAGE_{label}"
    print(f"{prefix}_REFERENCES={len(detail_rows)}")
    print(f"{prefix}_CLASS_CHECKS={len(checks)}")
    for result in RESULTS:
        print(f"{prefix}_{result}={counts[result]}")
    print(f"{prefix}_SHADOWED_CLASS_COUNT={len(shadowed)}")
    for i, (desc, provider, path) in enumerate(shadowed[:100]):
        print(
            f"{prefix}_SHADOWED[{i}]="
            f"class={desc} winner_provider={provider} winner_path={path}"
        )
    failures = [r for r in detail_rows if r[6] != "RESOLVED"]
    class_failures = [
        row for row in checks if row[3].result != "RESOLVED"
    ]
    print(f"{prefix}_UNRESOLVED={unresolved}")
    for i, row in enumerate(class_failures[:100]):
        caller, kind, target, out = row
        print(
            f"{prefix}_CLASS_FAILURE[{i}]="
            f"caller={clean(caller)}|check={clean(kind)}|"
            f"target={clean(target)}|result={clean(out.result)}|"
            f"detail={clean(out.detail or '-')}"
        )
    for i, row in enumerate(failures[:100]):
        print(
            f"{prefix}_FAILURE[{i}]="
            + "|".join(clean(x) for x in row)
        )


def run(manifest: Path, ims_apk: Path, badging: Path) -> int:
    m = load_members_tool()
    entries = parse_manifest(manifest)

    if not ims_apk.is_file():
        raise AuditError(f"ims_apk_missing={ims_apk}")
    if not badging.is_file():
        raise AuditError(f"ims_badging_missing={badging}")

    uses = parse_badging_uses(badging)
    required_uses, optional_uses = classify_uses(uses)

    # Optional shared libraries are deliberately omitted from this minimal
    # linkage world. That is conservative for unresolved-reference analysis:
    # they may satisfy additional references if present, but are not required
    # for package loading. C1's N1I-A authority admitted no optional jar and
    # reported zero unresolved APK type references.
    world = m.World()
    boot_containers = {}
    base_duplicate_count = 0
    imported_duplicate_count = 0
    post_import_duplicate_count = 0
    imported_paths: set[str] = set()
    common_index = next(i for i, (d, _h) in enumerate(entries) if d == COMMON)
    ims_base_index = next(i for i, (d, _h) in enumerate(entries) if d == IMS_BASE)

    for index, (device, host) in enumerate(entries):
        container = m.load(host)
        provider = "APEX" if device.startswith("/apex/") else "BOOT"
        if device in (COMMON, IMS_BASE):
            imported_paths.add(str(host))
        before = len(world.duplicates)
        world.add(container, "boot", provider)
        new_dups = world.duplicates[before:]
        added = len(new_dups)
        if index < common_index:
            base_duplicate_count += added
        elif index in (common_index, ims_base_index):
            imported_duplicate_count += added
        else:
            post_import_duplicate_count += added
            for _desc, first, second in new_dups:
                if duplicate_involves_import(first, second, imported_paths):
                    imported_duplicate_count += 1
        boot_containers[device] = (container, provider, host)

    common_container, common_provider, _ = boot_containers[COMMON]
    imsbase_container, imsbase_provider, _ = boot_containers[IMS_BASE]

    require_core_runtime(world)

    # Boot-loader code must never resolve against app-loader classes. Analyze
    # the imported boot jars before adding ImsService.apk to the visible world.
    common = analyze_container(
        m, world, common_container, common_provider, "COMMON"
    )
    imsbase = analyze_container(
        m, world, imsbase_container, imsbase_provider, "IMS_BASE"
    )

    ims = m.load(ims_apk)
    before_app = len(world.duplicates)
    world.add(ims, "app", "APP")
    app_duplicate_count = len(world.duplicates) - before_app
    app = analyze_container(m, world, ims, "APP", "IMS_APK")

    print("===== N1I-C1 EXACT RUNTIME MEMBER LINKAGE AUDIT =====")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print(f"N1I_C1_LINKAGE_BOOTCLASSPATH_ENTRY_COUNT={len(entries)}")
    print(f"N1I_C1_LINKAGE_REQUIRED_USES_LIBRARY_COUNT={len(required_uses)}")
    print(f"N1I_C1_LINKAGE_OPTIONAL_USES_LIBRARY_COUNT={len(optional_uses)}")
    for index, name in enumerate(optional_uses):
        print(
            f"N1I_C1_LINKAGE_OPTIONAL_USES_LIBRARY[{index}]="
            f"{name}|status=OMITTED_OPTIONAL_MINIMAL_MODEL"
        )
    print(
        "N1I_C1_LINKAGE_BASELINE_BOOT_DUPLICATE_CLASS_COUNT="
        f"{base_duplicate_count}"
    )
    print(
        "N1I_C1_LINKAGE_IMPORTED_BOOT_DUPLICATE_CLASS_COUNT="
        f"{imported_duplicate_count}"
    )
    print(
        "N1I_C1_LINKAGE_POST_IMPORT_BOOT_DUPLICATE_CLASS_COUNT="
        f"{post_import_duplicate_count}"
    )
    print(
        "N1I_C1_LINKAGE_APP_DUPLICATE_CLASS_COUNT="
        f"{app_duplicate_count}"
    )
    print(
        "N1I_C1_LINKAGE_APP_SHADOWED_POLICY="
        "REPORT_ONLY_PARENT_FIRST_ART"
    )
    print("N1I_C1_LINKAGE_RUNTIME_CORE_SANITY=PASS")

    emit_target("COMMON", *common)
    emit_target("IMS_BASE", *imsbase)
    emit_target("IMS_APK", *app)

    unresolved = common[-1] + imsbase[-1] + app[-1]

    if imported_duplicate_count:
        print(
            "N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT="
            f"FAIL_IMPORTED_BOOT_DUPLICATE_CLASSES count={imported_duplicate_count}"
        )
        return 1
    if unresolved:
        print(
            "N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT="
            f"FAIL_UNRESOLVED_MEMBERS count={unresolved}"
        )
        return 1

    print("N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT=PASS_ALL_RESOLVED")
    print("N1I_C1_DEVICE_CONTACT=NONE")
    print("N1I_C1_FLASH=NONE")
    return 0


def selftest() -> int:
    optional_only = parse_badging_uses(
        _SelfTestPath("uses-library-not-required:'two'\n")
    )
    required, optional = classify_uses(optional_only)
    assert required == []
    assert optional == ["two"]

    required_only = parse_badging_uses(
        _SelfTestPath("uses-library:'one'\n")
    )
    try:
        classify_uses(required_only)
    except AuditError as exc:
        assert "unmodeled_required_uses_libraries=one" in str(exc)
    else:
        raise AssertionError("required uses-library was silently accepted")

    try:
        parse_badging_uses(_SelfTestPath("uses-static-library:'three'\n"))
    except AuditError:
        pass
    else:
        raise AssertionError("static uses-library was silently accepted")

    class _World:
        def __init__(self, present):
            self.present = set(present)

        def klass(self, desc):
            return object() if desc in self.present else None

    core = {
        "Ljava/lang/Object;",
        "Ljava/lang/String;",
        "Ljava/lang/Class;",
        "Ljava/util/ArrayList;",
        "Ldalvik/system/PathClassLoader;",
    }
    require_core_runtime(_World(core))
    try:
        require_core_runtime(_World(core - {"Ljava/lang/Object;"}))
    except AuditError as exc:
        assert "runtime_core_class_missing=Ljava/lang/Object;" in str(exc)
    else:
        raise AssertionError("missing core runtime class was silently accepted")

    imports = {"/product/system_ext/framework/mediatek-common.jar"}
    assert duplicate_involves_import(
        "BOOT:/product/system_ext/framework/mediatek-common.jar!classes.dex",
        "APEX:/tmp/core-icu4j.jar!classes.dex",
        imports,
    )
    assert not duplicate_involves_import(
        "BOOT:/product/system/framework/framework.jar!classes.dex",
        "BOOT:/product/system/framework/ext.jar!classes.dex",
        imports,
    )

    print("N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT_SELFTEST=PASS")
    return 0


class _SelfTestPath:
    def __init__(self, text: str):
        self.text = text

    def read_text(self, **_kwargs):
        return self.text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootclasspath-manifest", type=Path)
    parser.add_argument("--ims-apk", type=Path)
    parser.add_argument("--badging", type=Path)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    try:
        if args.selftest:
            return selftest()
        if not (
            args.bootclasspath_manifest
            and args.ims_apk
            and args.badging
        ):
            parser.error(
                "--bootclasspath-manifest, --ims-apk and --badging are required"
            )
        return run(
            args.bootclasspath_manifest,
            args.ims_apk,
            args.badging,
        )
    except (AuditError, OSError, ValueError) as exc:
        print(
            f"N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT=FAIL reason={exc}",
            file=sys.stderr,
        )
        return 2
    except Exception as exc:
        m = MEMBERS
        if m is not None and isinstance(exc, m.S.DexError):
            print(
                f"N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT=FAIL reason={exc}",
                file=sys.stderr,
            )
            return 2
        raise


if __name__ == "__main__":
    raise SystemExit(main())
