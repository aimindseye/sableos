#!/usr/bin/env python3
"""Derive the Titan 2 N1I-C1 full runtime BOOTCLASSPATH.

Uses the retained N1I-A stock/C3A work tree as the qualified APEX extraction
control and the current C1 PRODUCT_OUT for the system bootclasspath fragment.

Android derive_classpath merge order is reproduced:
  1. com.android.art bootclasspath fragment
  2. /system/etc/classpaths/bootclasspath.pb
  3. all other APEX bootclasspath fragments sorted by APEX module name

The retained C3A extraction may supply a host copy of an APEX boot jar only
after a fresh, sealed C1 APEX parity audit proves that the exact C1 bootclasspath
fragment, exported boot-jar paths, and boot-jar bytes are identical. Whole APEX
container or payload equality is not required because independently built APEX
packages may differ outside the Java boot runtime surface.

Offline/read-only: no device, network, build, flash or source mutation.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path

COMMON = "/system_ext/framework/mediatek-common.jar"
IMS_BASE = "/system_ext/framework/mediatek-ims-base.jar"
BOOTCLASSPATH = 1
EXPECTED_C1_SHA = (
    "137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
)

DEFAULT_N1I_A = Path(
    "/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z"
)


class DeriveError(Exception):
    pass


@dataclass(frozen=True)
class Jar:
    path: str
    classpath: int
    min_sdk: str
    max_sdk: str


@dataclass(frozen=True)
class ApexFragment:
    module: str
    root: Path
    fragment: Path
    jars: tuple[Jar, ...]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_varint(data: bytes, pos: int) -> tuple[int, int]:
    value = 0
    shift = 0
    while True:
        if pos >= len(data) or shift > 63:
            raise DeriveError("invalid_protobuf_varint")
        b = data[pos]
        pos += 1
        value |= (b & 0x7F) << shift
        if b < 0x80:
            return value, pos
        shift += 7


def read_len(data: bytes, pos: int) -> tuple[bytes, int]:
    length, pos = read_varint(data, pos)
    end = pos + length
    if end > len(data):
        raise DeriveError("truncated_protobuf_length_delimited")
    return data[pos:end], end


def skip_field(data: bytes, pos: int, wire: int) -> int:
    if wire == 0:
        _value, pos = read_varint(data, pos)
        return pos
    if wire == 1:
        end = pos + 8
    elif wire == 2:
        payload, end = read_len(data, pos)
        _ = payload
    elif wire == 5:
        end = pos + 4
    else:
        raise DeriveError(f"unsupported_protobuf_wire_type={wire}")
    if end > len(data):
        raise DeriveError("truncated_protobuf_field")
    return end


def parse_jar(data: bytes) -> Jar:
    path = ""
    classpath = 0
    min_sdk = ""
    max_sdk = ""
    pos = 0
    while pos < len(data):
        key, pos = read_varint(data, pos)
        field = key >> 3
        wire = key & 7
        if field in (1, 3, 4) and wire == 2:
            payload, pos = read_len(data, pos)
            value = payload.decode("utf-8", "strict")
            if field == 1:
                path = value
            elif field == 3:
                min_sdk = value
            else:
                max_sdk = value
        elif field == 2 and wire == 0:
            classpath, pos = read_varint(data, pos)
        else:
            pos = skip_field(data, pos, wire)
    if not path:
        raise DeriveError("classpath_jar_missing_path")
    return Jar(path, classpath, min_sdk, max_sdk)


def parse_fragment(path: Path) -> list[Jar]:
    data = path.read_bytes()
    jars: list[Jar] = []
    pos = 0
    while pos < len(data):
        key, pos = read_varint(data, pos)
        field = key >> 3
        wire = key & 7
        if field == 1 and wire == 2:
            payload, pos = read_len(data, pos)
            jars.append(parse_jar(payload))
        else:
            pos = skip_field(data, pos, wire)
    if not jars:
        raise DeriveError(f"classpath_fragment_empty={path}")
    return jars


def sdk_int(value: str, label: str) -> int | None:
    if not value:
        return None
    if not value.isdigit():
        raise DeriveError(f"non_numeric_{label}_sdk={value}")
    return int(value)


def enabled(jar: Jar, api: int) -> bool:
    minimum = sdk_int(jar.min_sdk, "min")
    maximum = sdk_int(jar.max_sdk, "max")
    if minimum is not None and api < minimum:
        return False
    if maximum is not None and api > maximum:
        return False
    return True


def boot_jars(fragment: Path, api: int) -> list[Jar]:
    return [
        jar
        for jar in parse_fragment(fragment)
        if jar.classpath == BOOTCLASSPATH and enabled(jar, api)
    ]


def system_root(tree: Path) -> Path:
    nested = tree / "system"
    if (nested / "build.prop").is_file():
        return nested
    return tree


def read_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        out[key] = value.strip().strip('"')
    return out


def module_from_apex_path(device: str) -> str:
    m = re.match(r"^/apex/([^/]+)/", device)
    if not m:
        raise DeriveError(f"not_an_apex_path={device}")
    return m.group(1)


def find_archive(apex_dir: Path, module: str) -> Path:
    exact = [
        apex_dir / f"{module}.apex",
        apex_dir / f"{module}.capex",
    ]
    hits = [p for p in exact if p.is_file()]
    if not hits:
        hits = sorted(
            p
            for p in apex_dir.glob(f"{module}*")
            if p.is_file() and p.suffix in (".apex", ".capex")
        )
    if len(hits) != 1:
        raise DeriveError(
            f"apex_archive_count={module}:{len(hits)}:root={apex_dir}"
        )
    return hits[0]


def apex_fragments(root: Path, api: int) -> list[ApexFragment]:
    found: list[ApexFragment] = []
    for fragment in sorted(root.glob("*/etc/classpaths/bootclasspath.pb")):
        jars = tuple(boot_jars(fragment, api))
        if not jars:
            continue
        if any(not j.path.startswith("/apex/") for j in jars):
            raise DeriveError(
                f"apex_fragment_exports_non_apex_path={fragment}"
            )
        modules = {module_from_apex_path(j.path) for j in jars}
        if len(modules) != 1:
            raise DeriveError(
                f"apex_fragment_module_ambiguity={fragment}:{sorted(modules)}"
            )
        module = next(iter(modules))
        archive_name = fragment.parent.parent.parent.name
        declared_module = re.sub(r"\.(?:c?apex)$", "", archive_name)
        if declared_module != module:
            raise DeriveError(
                f"apex_fragment_cross_module_export="
                f"{archive_name}:{module}"
            )
        found.append(
            ApexFragment(
                module=module,
                root=fragment.parent.parent.parent,
                fragment=fragment,
                jars=jars,
            )
        )
    if not found:
        raise DeriveError(f"no_apex_bootclasspath_fragments={root}")
    modules = [x.module for x in found]
    if len(modules) != len(set(modules)):
        raise DeriveError("duplicate_apex_bootclasspath_module")
    return found


def find_extracted_apex_root(root: Path, module: str) -> Path:
    exact = [
        root / f"{module}.apex",
        root / f"{module}.capex",
    ]
    hits = [path for path in exact if path.is_dir()]
    if not hits:
        hits = sorted(
            path
            for path in root.glob(f"{module}*")
            if path.is_dir()
            and re.sub(r"\.(?:c?apex)$", "", path.name) == module
        )
    if len(hits) != 1:
        raise DeriveError(
            f"retained_apex_root_count={module}:{len(hits)}:root={root}"
        )
    return hits[0]


def c3a_apex_jar_from_root(root: Path, module: str, device: str) -> Path:
    actual_module = module_from_apex_path(device)
    if actual_module != module:
        raise DeriveError(
            f"apex_root_cross_module_export={module}:{device}"
        )
    rel = device.split("/", 3)[3]
    host = root / rel
    if not host.is_file():
        raise DeriveError(f"retained_apex_jar_missing={device}:{host}")
    return host


def map_system_jar(product_out: Path, device: str) -> Path:
    if device.startswith("/system_ext/"):
        host = (
            product_out
            / "system"
            / "system_ext"
            / device.removeprefix("/system_ext/")
        )
    elif device.startswith("/product/"):
        host = (
            product_out
            / "system"
            / "product"
            / device.removeprefix("/product/")
        )
    elif device.startswith("/system/"):
        host = product_out / "system" / device.removeprefix("/system/")
    elif device.startswith("/apex/"):
        raise DeriveError(
            f"system_fragment_apex_entry_requires_control_mapping={device}"
        )
    else:
        raise DeriveError(f"unsupported_system_boot_path={device}")
    if not host.is_file():
        raise DeriveError(f"system_boot_jar_missing={device}:{host}")
    return host


def c3a_apex_jar(fragment: ApexFragment, device: str) -> Path:
    return c3a_apex_jar_from_root(
        fragment.root,
        fragment.module,
        device,
    )


def compare_system_delta(
    c3a_fragment: Path,
    c1_fragment: Path,
    api: int,
) -> tuple[list[str], list[str]]:
    c3a = [j.path for j in boot_jars(c3a_fragment, api)]
    c1 = [j.path for j in boot_jars(c1_fragment, api)]
    stripped = [p for p in c1 if p not in (COMMON, IMS_BASE)]
    if stripped != c3a:
        raise DeriveError(
            "c1_system_bootclasspath_not_c3a_plus_imports"
        )
    if c1.count(COMMON) != 1 or c1.count(IMS_BASE) != 1:
        raise DeriveError("c1_imported_boot_jar_count_not_exact")
    if c1.index(COMMON) >= c1.index(IMS_BASE):
        raise DeriveError("c1_imported_boot_jar_order_invalid")
    return c3a, c1


def validate_apex_parity(
    parity_evidence: Path,
    product_out: Path,
    n1i_a_evidence: Path,
    expected_modules: set[str],
    expected_devices: set[str],
    expected_system_sha: str,
) -> dict[str, str]:
    summary = parity_evidence / "summary.env"
    module_tsv = parity_evidence / "apex-module-parity.tsv"
    jar_tsv = parity_evidence / "apex-boot-jar-parity.tsv"
    seal = parity_evidence / "SHA256SUMS.txt"
    for path in (summary, module_tsv, jar_tsv, seal):
        if not path.is_file():
            raise DeriveError(f"apex_parity_input_missing={path}")

    for raw in seal.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        try:
            want, rel = raw.split("  ", 1)
        except ValueError as exc:
            raise DeriveError("apex_parity_seal_row_invalid") from exc
        target = (parity_evidence / rel).resolve()
        try:
            target.relative_to(parity_evidence.resolve())
        except ValueError as exc:
            raise DeriveError(
                f"apex_parity_sealed_path_escape={rel}"
            ) from exc
        if not target.is_file():
            raise DeriveError(f"apex_parity_sealed_file_missing={rel}")
        got = sha256(target)
        if got != want:
            raise DeriveError(
                f"apex_parity_seal_mismatch={rel}:expected={want}:actual={got}"
            )

    values = read_env(summary)
    required = {
        "N1I_C1_APEX_FRAGMENT_MISMATCH_COUNT": "0",
        "N1I_C1_APEX_BOOT_JAR_PATH_MISMATCH_COUNT": "0",
        "N1I_C1_APEX_BOOT_JAR_HASH_MISMATCH_COUNT": "0",
        "N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY": "PASS",
        "N1I_C1_APEX_PARITY_C1_SYSTEM_SHA256": expected_system_sha,
    }
    for key, expected in required.items():
        actual = values.get(key)
        if actual != expected:
            raise DeriveError(
                f"apex_parity_summary_mismatch={key}:"
                f"expected={expected}:actual={actual}"
            )

    for key in (
        "N1I_C1_APEX_OUTER_MISMATCH_COUNT",
        "N1I_C1_APEX_INNER_MISMATCH_COUNT",
        "N1I_C1_APEX_PAYLOAD_MISMATCH_COUNT",
    ):
        raw = values.get(key, "")
        if not raw.isdigit():
            raise DeriveError(f"apex_parity_count_invalid={key}:{raw}")

    try:
        module_count = int(values.get("N1I_C1_APEX_MODULE_COUNT", ""))
    except ValueError as exc:
        raise DeriveError("apex_parity_module_count_invalid") from exc
    if module_count != len(expected_modules):
        raise DeriveError(
            f"apex_parity_module_count_mismatch="
            f"expected={len(expected_modules)}:actual={module_count}"
        )

    bound_product = values.get("N1I_C1_APEX_PARITY_PRODUCT_OUT", "")
    if not bound_product:
        raise DeriveError("apex_parity_product_out_binding_missing")
    if Path(bound_product).resolve() != product_out.resolve():
        raise DeriveError(
            f"apex_parity_product_out_binding_mismatch={bound_product}"
        )

    bound_v6 = values.get("N1I_C1_APEX_PARITY_V6_EVIDENCE", "")
    if not bound_v6:
        raise DeriveError("apex_parity_v6_binding_missing")
    if (Path(bound_v6).resolve() / "n1i-a-replay") != n1i_a_evidence.resolve():
        raise DeriveError(
            f"apex_parity_v6_binding_mismatch={bound_v6}"
        )

    c1_system = product_out / "system.img"
    if not c1_system.is_file():
        raise DeriveError(f"c1_system_missing={c1_system}")
    actual_system_sha = sha256(c1_system)
    if actual_system_sha != expected_system_sha:
        raise DeriveError(
            "c1_system_sha_mismatch_during_apex_parity_binding="
            f"expected:{expected_system_sha}:actual:{actual_system_sha}"
        )

    with module_tsv.open(newline="", encoding="utf-8") as fp:
        module_rows = list(csv.DictReader(fp, delimiter="\t"))
    if len(module_rows) != len(expected_modules):
        raise DeriveError(
            f"apex_parity_module_rows_mismatch="
            f"expected={len(expected_modules)}:actual={len(module_rows)}"
        )
    actual_modules = {row.get("module", "") for row in module_rows}
    if actual_modules != expected_modules:
        raise DeriveError(
            "apex_parity_module_set_mismatch="
            f"expected={sorted(expected_modules)}:"
            f"actual={sorted(actual_modules)}"
        )
    for row in module_rows:
        module = row.get("module", "")
        if row.get("fragment_match") != "YES":
            raise DeriveError(f"apex_parity_fragment_mismatch={module}")
        if row.get("boot_jar_paths_match") != "YES":
            raise DeriveError(f"apex_parity_boot_jar_paths_mismatch={module}")
        if row.get("boot_jar_hash_mismatch_count") != "0":
            raise DeriveError(f"apex_parity_boot_jar_hash_mismatch={module}")

    with jar_tsv.open(newline="", encoding="utf-8") as fp:
        jar_rows = list(csv.DictReader(fp, delimiter="\t"))
    if not jar_rows:
        raise DeriveError("apex_parity_boot_jar_rows_empty")
    actual_devices = {row.get("device_path", "") for row in jar_rows}
    if actual_devices != expected_devices:
        raise DeriveError(
            "apex_parity_boot_jar_device_set_mismatch="
            f"expected={sorted(expected_devices)}:"
            f"actual={sorted(actual_devices)}"
        )
    for row in jar_rows:
        if row.get("match") != "YES":
            raise DeriveError(
                "apex_parity_boot_jar_row_mismatch="
                + row.get("device_path", "UNKNOWN")
            )

    return values


def derive(
    product_out: Path,
    evidence: Path,
    apex_parity_evidence: Path,
    api: int,
    expected_system_sha: str,
) -> tuple[list[tuple[str, Path, str]], dict[str, str]]:
    env_file = evidence / "n1i-a-v010014-oem-ims.env"
    work = evidence / "work"
    c3a_tree = work / "c3a" / "system_img"
    c3a_apex_root = work / "apex" / "c3a"

    for path in (env_file, c3a_tree, c3a_apex_root):
        if not path.exists():
            raise DeriveError(f"retained_n1i_a_input_missing={path}")

    env = read_env(env_file)
    if env.get("N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE") != "PASS":
        raise DeriveError("retained_n1i_a_authority_not_pass")
    if env.get("APK_REFS_UNRESOLVED_COUNT") != "0":
        raise DeriveError("retained_n1i_a_apk_refs_not_closed")
    if env.get("APK_REFS_UNRESOLVED_MEDIATEK_COUNT") != "0":
        raise DeriveError("retained_n1i_a_mtk_refs_not_closed")

    required = env.get("REQUIRED_JARS", "").split()
    if required != [COMMON, IMS_BASE]:
        raise DeriveError(
            "retained_n1i_a_required_jars_changed=" + ",".join(required)
        )

    c3a_sys = system_root(c3a_tree)
    c3a_system_fragment = c3a_sys / "etc/classpaths/bootclasspath.pb"
    c1_system_fragment = (
        product_out / "system/etc/classpaths/bootclasspath.pb"
    )
    if not c3a_system_fragment.is_file():
        raise DeriveError(
            f"retained_c3a_system_fragment_missing={c3a_system_fragment}"
        )
    if not c1_system_fragment.is_file():
        raise DeriveError(
            f"c1_system_fragment_missing={c1_system_fragment}"
        )

    c3a_system, c1_system = compare_system_delta(
        c3a_system_fragment,
        c1_system_fragment,
        api,
    )

    fragments = apex_fragments(c3a_apex_root, api)
    art = [f for f in fragments if f.module == "com.android.art"]
    if len(art) != 1:
        raise DeriveError(f"art_fragment_count={len(art)}")
    other = sorted(
        (f for f in fragments if f.module != "com.android.art"),
        key=lambda f: f.module,
    )

    fragment_modules = {fragment.module for fragment in fragments}
    system_apex_modules = {
        module_from_apex_path(device)
        for device in c3a_system
        if device.startswith("/apex/")
    }
    runtime_apex_modules = fragment_modules | system_apex_modules
    runtime_apex_devices = {
        jar.path
        for fragment in fragments
        for jar in fragment.jars
    } | {
        device
        for device in c3a_system
        if device.startswith("/apex/")
    }

    parity = validate_apex_parity(
        apex_parity_evidence,
        product_out,
        evidence,
        runtime_apex_modules,
        runtime_apex_devices,
        expected_system_sha,
    )

    rows: list[tuple[str, Path, str]] = []
    for fragment in art:
        for jar in fragment.jars:
            rows.append(
                (jar.path, c3a_apex_jar(fragment, jar.path), "APEX_ART_C1_PARITY_PROVEN")
            )

    for device in c1_system:
        if device.startswith("/apex/"):
            module = module_from_apex_path(device)
            fragment = next((f for f in fragments if f.module == module), None)
            if fragment is not None:
                root = fragment.root
            else:
                root = find_extracted_apex_root(c3a_apex_root, module)
            host = c3a_apex_jar_from_root(root, module, device)
            rows.append(
                (
                    device,
                    host,
                    "APEX_SYSTEM_FRAGMENT_C1_PARITY_PROVEN",
                )
            )
        else:
            rows.append(
                (device, map_system_jar(product_out, device), "C1_SYSTEM")
            )

    for fragment in other:
        for jar in fragment.jars:
            # A jar exported by the system fragment is already in its exact
            # derive_classpath position and must not be emitted twice.
            if any(device == jar.path for device, _host, _role in rows):
                continue
            rows.append(
                (jar.path, c3a_apex_jar(fragment, jar.path), "APEX_C1_PARITY_PROVEN")
            )

    devices = [d for d, _h, _r in rows]
    if len(devices) != len(set(devices)):
        raise DeriveError("duplicate_final_bootclasspath_entry")
    if COMMON not in devices or IMS_BASE not in devices:
        raise DeriveError("final_bootclasspath_missing_imports")
    return rows, parity


def write_manifest(
    rows: list[tuple[str, Path, str]],
    out: Path,
) -> None:
    with out.open("w", encoding="utf-8") as fp:
        for device, host, _role in rows:
            fp.write(f"{device}\t{host}\n")


def selftest() -> int:
    # ExportedClasspathsJars{jars:[Jar{path:"/x",classpath:1}]}
    jar = b"\x0a\x02/x\x10\x01"
    proto = b"\x0a" + bytes([len(jar)]) + jar
    parsed = parse_fragment_bytes(proto)
    assert parsed == [Jar("/x", 1, "", "")]

    # A non-boot entry must parse but be filtered by boot_jars semantics.
    jar2 = b"\x0a\x02/y\x10\x03"
    proto2 = b"\x0a" + bytes([len(jar2)]) + jar2
    assert parse_fragment_bytes(proto2) == [Jar("/y", 3, "", "")]

    assert enabled(Jar("/x", 1, "35", "36"), 36)
    assert not enabled(Jar("/x", 1, "37", ""), 36)
    assert not enabled(Jar("/x", 1, "", "35"), 36)

    print("N1I_C1_RUNTIME_CLASSPATH_DERIVER_SELFTEST=PASS")
    return 0


def parse_fragment_bytes(data: bytes) -> list[Jar]:
    jars: list[Jar] = []
    pos = 0
    while pos < len(data):
        key, pos = read_varint(data, pos)
        field = key >> 3
        wire = key & 7
        if field == 1 and wire == 2:
            payload, pos = read_len(data, pos)
            jars.append(parse_jar(payload))
        else:
            pos = skip_field(data, pos, wire)
    return jars


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--product-out", type=Path)
    parser.add_argument("--n1i-a-evidence", type=Path, default=DEFAULT_N1I_A)
    parser.add_argument("--apex-parity-evidence", type=Path)
    parser.add_argument("--api-level", type=int, default=36)
    parser.add_argument(
        "--expected-system-sha",
        default=EXPECTED_C1_SHA,
        help="Expected SHA-256 of product_out/system.img; defaults to sealed C1.",
    )
    parser.add_argument("--out", type=Path)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    try:
        if args.selftest:
            return selftest()
        if (
            args.product_out is None
            or args.apex_parity_evidence is None
            or args.out is None
        ):
            parser.error(
                "--product-out, --apex-parity-evidence and --out are required"
            )
        if (
            len(args.expected_system_sha) != 64
            or any(
                ch not in "0123456789abcdef"
                for ch in args.expected_system_sha
            )
        ):
            parser.error(
                "--expected-system-sha must be 64 lowercase hex characters"
            )
        product_out = args.product_out.resolve()
        evidence = args.n1i_a_evidence.resolve()
        apex_parity_evidence = args.apex_parity_evidence.resolve()
        if not product_out.is_dir():
            raise DeriveError(f"product_out_missing={product_out}")
        rows, parity = derive(
            product_out,
            evidence,
            apex_parity_evidence,
            args.api_level,
            args.expected_system_sha,
        )
        write_manifest(rows, args.out)
        art_count = sum(
            1 for _d, _h, role in rows
            if role == "APEX_ART_C1_PARITY_PROVEN"
        )
        apex_count = sum(1 for _d, _h, role in rows if role.startswith("APEX"))
        print("N1I_C1_RUNTIME_CLASSPATH_N1I_A_AUTHORITY=PASS")
        print("N1I_C1_RUNTIME_CLASSPATH_C3A_SYSTEM_DELTA=PASS_EXACT_PLUS_TWO_MTK")
        print(
            "N1I_C1_RUNTIME_CLASSPATH_APEX_BOOT_JAR_PARITY="
            "PASS_EXACT_C1_JAVA_RUNTIME"
        )
        print(
            "N1I_C1_RUNTIME_CLASSPATH_APEX_OUTER_MISMATCH_COUNT="
            + parity["N1I_C1_APEX_OUTER_MISMATCH_COUNT"]
        )
        print(
            "N1I_C1_RUNTIME_CLASSPATH_APEX_PAYLOAD_MISMATCH_COUNT="
            + parity["N1I_C1_APEX_PAYLOAD_MISMATCH_COUNT"]
        )
        print(f"N1I_C1_RUNTIME_CLASSPATH_ENTRY_COUNT={len(rows)}")
        print(f"N1I_C1_RUNTIME_CLASSPATH_ART_ENTRY_COUNT={art_count}")
        print(f"N1I_C1_RUNTIME_CLASSPATH_APEX_ENTRY_COUNT={apex_count}")
        for index, (device, host, role) in enumerate(rows):
            print(
                f"N1I_C1_RUNTIME_CLASSPATH[{index}]="
                f"{device}|role={role}|host={host}"
            )
        print("N1I_C1_RUNTIME_CLASSPATH_DERIVATION=PASS")
        return 0
    except (DeriveError, OSError, UnicodeError) as exc:
        print(
            f"N1I_C1_RUNTIME_CLASSPATH_DERIVATION=FAIL reason={exc}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
