#!/usr/bin/env python3
"""Titan 2 N1I-D0 host-only boot-compatibility qualification.

Consumes already materialized, SHA-bound runtime roots for the known-good N1F
control, failed C2 candidate, and pinned V01.00.14 stock partitions.

No build, device contact, network, source mutation, reboot, or flash.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

API_LEVEL = 36
SYSTEMSERVERCLASSPATH = 2
B2_PIN = "1697f21989b8ed6f1db90f8886952894592c7d0f"
CRITICAL_GATES = ("A", "B", "D", "E")


class D0Error(Exception):
    pass


@dataclass
class Result:
    gate: str
    profile: str
    state: str
    detail: str

    def row(self) -> tuple[str, str, str, str]:
        return self.gate, self.profile, self.state, self.detail


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run(cmd: list[str], *, out: Path | None = None) -> subprocess.CompletedProcess:
    if out is None:
        return subprocess.run(cmd, text=True, capture_output=True, check=False)
    with out.open("w", encoding="utf-8") as fp:
        return subprocess.run(cmd, text=True, stdout=fp, stderr=subprocess.STDOUT, check=False)


def read_first(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace").splitlines()[0].strip()


def env_write(path: Path, values: dict[str, object]) -> None:
    with path.open("w", encoding="utf-8") as fp:
        for key, value in values.items():
            fp.write(f"{key}={str(value).replace(chr(10), ' ')}\n")


def tsv_write(path: Path, header: tuple[str, ...], rows: list[tuple]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.writer(fp, delimiter="\t", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def partition_roots(system_root: Path) -> dict[str, Path]:
    return {
        "system": system_root,
        "system_ext": system_root / "system_ext",
        "product": system_root / "product",
    }


def find_files(root: Path, rel: str, pattern: str) -> list[Path]:
    base = root / rel
    if not base.is_dir():
        return []
    return sorted(p for p in base.glob(pattern) if p.is_file())


def parse_contexts(path: Path) -> list[tuple[str, str, str]]:
    rows = []
    if not path.is_file():
        return rows
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) < 2:
            continue
        rows.append((fields[0], fields[1], " ".join(fields[2:])))
    return rows


def parse_privapp_files(roots: dict[str, Path]) -> tuple[dict[tuple[str, str], set[str]], list[tuple]]:
    perms: dict[tuple[str, str], set[str]] = {}
    rows: list[tuple] = []
    for part, root in roots.items():
        for path in find_files(root, "etc/permissions", "*.xml"):
            try:
                tree = ET.parse(path)
            except ET.ParseError:
                continue
            for block in tree.findall(".//privapp-permissions"):
                package = block.attrib.get("package", "")
                if not package:
                    continue
                key = (part, package)
                allow = perms.setdefault(key, set())
                for child in block:
                    name = child.attrib.get("name", "")
                    if child.tag == "permission" and name:
                        allow.add(name)
                        rows.append((part, package, "permission", name, str(path)))
                    elif child.tag == "deny-permission" and name:
                        rows.append((part, package, "deny-permission", name, str(path)))
    return perms, rows


def aapt2_permissions(aapt2: str, apk: Path) -> set[str]:
    cp = run([aapt2, "dump", "permissions", str(apk)])
    if cp.returncode != 0:
        raise D0Error(f"aapt2_permissions_rc={cp.returncode}:{apk}")
    out = set()
    for line in cp.stdout.splitlines():
        m = re.search(r"(?:uses-permission|uses-permission-sdk-\d+):\s+name='([^']+)'", line)
        if m:
            out.add(m.group(1))
    return out


def aapt2_badging(aapt2: str, apk: Path) -> str:
    cp = run([aapt2, "dump", "badging", str(apk)])
    if cp.returncode != 0:
        raise D0Error(f"aapt2_badging_rc={cp.returncode}:{apk}")
    return cp.stdout


def aapt2_xmltree(aapt2: str, apk: Path) -> str:
    cmds = [
        [aapt2, "dump", "xmltree", "--file", "AndroidManifest.xml", str(apk)],
        [aapt2, "dump", "xmltree", str(apk), "--file", "AndroidManifest.xml"],
    ]
    for cmd in cmds:
        cp = run(cmd)
        if cp.returncode == 0 and "E: manifest" in cp.stdout:
            return cp.stdout
    raise D0Error(f"aapt2_xmltree_failed={apk}")


def xml_attr_value(line: str) -> str:
    quoted = re.search(r'="([^"]*)"', line)
    if quoted:
        return quoted.group(1)
    tail_hex = re.search(r"=\(type 0x[0-9a-fA-F]+\)(0x[0-9a-fA-F]+)", line)
    if tail_hex:
        return tail_hex.group(1)
    return line.split("=", 1)[1].strip() if "=" in line else ""


def manifest_summary(aapt2: str, apk: Path) -> dict[str, object]:
    tree = aapt2_xmltree(aapt2, apk)
    package = ""
    shared_uid = ""
    shared_uid_max = ""
    app_persistent = ""
    app_process = ""
    direct_boot = ""
    min_sdk = ""
    target_sdk = ""
    uses_lib: list[str] = []
    uses_native: list[str] = []
    uses_lib_nodes: list[dict[str, str]] = []
    uses_native_nodes: list[dict[str, str]] = []
    components: list[dict[str, str]] = []
    stack: list[tuple[int, str, dict[str, str]]] = []

    for raw in tree.splitlines():
        indent = len(raw) - len(raw.lstrip())
        line = raw.strip()
        if line.startswith("E: "):
            tag = line[3:].split(" (", 1)[0]
            while stack and stack[-1][0] >= indent:
                stack.pop()
            node: dict[str, object] = {"tag": tag}
            stack.append((indent, tag, node))
            if tag in ("service", "receiver", "provider", "activity"):
                node["actions"] = []
                components.append(node)
            elif tag in ("uses-library", "uses-static-library"):
                uses_lib_nodes.append(node)
            elif tag == "uses-native-library":
                uses_native_nodes.append(node)
        elif line.startswith("A: ") and stack:
            m = re.match(r"A: (?:android:)?([^\s(=]+)(?:\([^)]*\))?=(.*)$", line)
            if not m:
                continue
            key, value = m.group(1), xml_attr_value(line)
            stack[-1][2][key] = value
            tag = stack[-1][1]
            if tag == "manifest":
                if key == "package":
                    package = value
                elif key == "sharedUserId":
                    shared_uid = value
                elif key == "sharedUserMaxSdkVersion":
                    shared_uid_max = value
            elif tag == "uses-sdk":
                if key == "minSdkVersion":
                    min_sdk = value
                elif key == "targetSdkVersion":
                    target_sdk = value
            elif tag == "application":
                if key == "persistent":
                    app_persistent = value
                elif key == "process":
                    app_process = value
                elif key == "directBootAware":
                    direct_boot = value
            elif tag in ("uses-library", "uses-static-library") and key == "name":
                uses_lib.append(value)
            elif tag == "uses-native-library" and key == "name":
                uses_native.append(value)
            elif tag == "action" and key == "name":
                for _i, parent_tag, parent in reversed(stack[:-1]):
                    if parent_tag in (
                        "service", "receiver", "provider", "activity"
                    ):
                        parent.setdefault("actions", []).append(value)
                        break

    uses_library_details = sorted(
        {
            f"{str(node.get('name', ''))}:"
            + (
                "optional"
                if str(node.get("required", "true")).lower() in ("false", "0")
                else "required"
            )
            for node in uses_lib_nodes
            if node.get("name")
        }
    )
    uses_native_details = sorted(
        {
            f"{str(node.get('name', ''))}:"
            + (
                "optional"
                if str(node.get("required", "true")).lower() in ("false", "0")
                else "required"
            )
            for node in uses_native_nodes
            if node.get("name")
        }
    )
    return {
        "package": package,
        "shared_uid": shared_uid,
        "shared_uid_max": shared_uid_max,
        "min_sdk": min_sdk,
        "target_sdk": target_sdk,
        "persistent": app_persistent,
        "process": app_process,
        "direct_boot_aware": direct_boot,
        "uses_library": sorted(set(uses_lib)),
        "uses_library_details": uses_library_details,
        "uses_native_library": sorted(set(uses_native)),
        "uses_native_library_details": uses_native_details,
        "components": components,
    }


def protection_permissions(aapt2: str, framework_res: Path) -> tuple[set[str], str]:
    tree = aapt2_xmltree(aapt2, framework_res)
    privileged: set[str] = set()
    current = ""
    saw = 0
    for raw in tree.splitlines():
        line = raw.strip()
        if line.startswith("E: permission "):
            current = ""
            saw += 1
            continue
        if not current and line.startswith("A: android:name"):
            current = xml_attr_value(line)
            continue
        if current and line.startswith("A: android:protectionLevel"):
            value = xml_attr_value(line)
            is_priv = "privileged" in line.lower()
            m = re.search(r"0x([0-9a-fA-F]+)$", value)
            if m and int(m.group(1), 16) & 0x10:
                is_priv = True
            if is_priv:
                privileged.add(current)
            current = ""
    if saw == 0:
        return set(), "NO_PERMISSION_NODES"
    return privileged, "PARSED_FRAMEWORK_RES"


def find_ims_apk(system_root: Path) -> Path | None:
    candidates = [
        system_root / "system_ext/priv-app/ImsService/ImsService.apk",
        system_root / "system_ext/app/ImsService/ImsService.apk",
    ]
    hits = [p for p in candidates if p.is_file()]
    return hits[0] if len(hits) == 1 else None


def prop_values(roots: dict[str, Path], vendor: Path, odm: Path | None, key: str) -> list[tuple[str, str, str]]:
    out = []
    scan = dict(roots)
    scan["vendor"] = vendor
    if odm:
        scan["odm"] = odm
    for part, root in scan.items():
        for rel in ("build.prop", "etc/build.prop", "default.prop", "etc/prop.default"):
            path = root / rel
            if not path.is_file():
                continue
            for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
                if raw.startswith(key + "="):
                    out.append((part, raw.split("=", 1)[1].strip(), str(path)))
    return out


def parse_seapp_rule(line: str) -> dict[str, str]:
    rule: dict[str, str] = {}
    for token in line.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        rule[key] = value
    return rule


def selector_matches(value: str, actual: str) -> bool:
    if value.endswith("*"):
        return actual.startswith(value[:-1])
    return value == actual


def seapp_resolution(
    roots: dict[str, Path],
    *,
    package: str,
    user: str,
    seinfo: str,
    is_priv_app: bool,
) -> tuple[list[tuple], str, str]:
    rows = []
    domains: set[str] = set()
    for part, root in roots.items():
        for path in find_files(root, "etc/selinux", "*seapp_contexts"):
            for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
                line = raw.split("#", 1)[0].strip()
                if not line:
                    continue
                rule = parse_seapp_rule(line)
                if not rule:
                    continue
                if "user" in rule and not selector_matches(rule["user"], user):
                    continue
                if "seinfo" in rule and not selector_matches(
                    rule["seinfo"].split(":", 1)[0], seinfo
                ):
                    continue
                if "name" in rule and not selector_matches(rule["name"], package):
                    continue
                if "isPrivApp" in rule:
                    wanted = rule["isPrivApp"].lower() == "true"
                    if wanted != is_priv_app:
                        continue
                domain = rule.get("domain", "")
                if domain:
                    domains.add(domain)
                rows.append(
                    (
                        part,
                        str(path),
                        rule.get("user", "*"),
                        rule.get("seinfo", "*"),
                        rule.get("name", "*"),
                        rule.get("isPrivApp", "*"),
                        domain or "-",
                        line,
                    )
                )
    if not rows:
        return rows, "UNKNOWN_NO_MATCHING_SEAPP_RULE", ""
    if len(domains) == 1:
        return rows, "UNAMBIGUOUS_MATCHING_DOMAIN", next(iter(domains))
    return rows, "UNKNOWN_AMBIGUOUS_MATCHING_DOMAINS", ",".join(sorted(domains))


def mac_permissions_seinfo(
    roots: dict[str, Path],
    *,
    package: str,
    cert_sha256: str,
) -> tuple[list[tuple], str, str]:
    """Bind package seinfo to the exact signing certificate in built mac_permissions.xml."""
    rows: list[tuple] = []
    candidates: set[str] = set()
    files: list[tuple[str, Path]] = []
    for part, root in roots.items():
        files.extend(
            (part, path)
            for path in find_files(root, "etc/selinux", "*mac_permissions.xml")
        )
    if not files:
        return rows, "UNKNOWN_MAC_PERMISSIONS_MISSING", ""

    cert_sha256 = cert_sha256.lower()
    matched_signer = False
    parse_failures = 0
    for part, path in files:
        try:
            tree = ET.parse(path)
        except ET.ParseError:
            parse_failures += 1
            rows.append((part, str(path), "PARSE_FAILED", "-", "-", "-"))
            continue
        for signer in tree.findall(".//signer"):
            signature = signer.attrib.get("signature", "").strip()
            signer_digests: set[str] = set()
            if re.fullmatch(r"[0-9a-fA-F]{64}", signature):
                signer_digests.add(signature.lower())
            if re.fullmatch(r"[0-9a-fA-F]+", signature) and len(signature) % 2 == 0:
                try:
                    signer_digests.add(
                        hashlib.sha256(bytes.fromhex(signature)).hexdigest()
                    )
                except ValueError:
                    pass
            matches = cert_sha256 in signer_digests
            signer_digest = (
                cert_sha256 if matches
                else ",".join(sorted(signer_digests))
            )
            rows.append(
                (
                    part,
                    str(path),
                    "SIGNER",
                    signer_digest or "UNBOUND",
                    "YES" if matches else "NO",
                    "-",
                )
            )
            if not matches:
                continue
            matched_signer = True

            # A package-specific seinfo is more precise than the signer default.
            package_values: set[str] = set()
            for pkg in signer.findall("package"):
                if pkg.attrib.get("name", "") != package:
                    continue
                for node in pkg.findall("seinfo"):
                    value = node.attrib.get("value", "").strip()
                    if value:
                        package_values.add(value)
                        rows.append(
                            (part, str(path), "PACKAGE", signer_digest, package, value)
                        )
            if package_values:
                candidates.update(package_values)
                continue
            for node in signer.findall("seinfo"):
                value = node.attrib.get("value", "").strip()
                if value:
                    candidates.add(value)
                    rows.append(
                        (part, str(path), "SIGNER_DEFAULT", signer_digest, package, value)
                    )

    if parse_failures:
        return rows, "UNKNOWN_MAC_PERMISSIONS_PARSE_FAILURE", ""
    if not matched_signer:
        return rows, "UNKNOWN_SIGNING_CERT_NOT_BOUND_TO_MAC_PERMISSIONS", ""
    if len(candidates) != 1:
        return (
            rows,
            "UNKNOWN_SEINFO_AUTHORITY_AMBIGUOUS",
            ",".join(sorted(candidates)),
        )
    return rows, "PASS_CERT_BOUND_SEINFO", next(iter(candidates))


def git_blob(repo: Path, commit: str, rel: str) -> str:
    cp = run(["git", "-C", str(repo), "rev-parse", f"{commit}:{rel}"])
    if cp.returncode != 0:
        raise D0Error(f"git_blob_missing={commit}:{rel}")
    return cp.stdout.strip()


def current_blob(repo: Path, rel: str) -> str:
    cp = run(["git", "-C", str(repo), "hash-object", str(repo / rel)])
    if cp.returncode != 0:
        raise D0Error(f"hash_object_failed={rel}")
    return cp.stdout.strip()


def load_deriver(repo: Path):
    path = repo / "build/titan2/derive-n1i-c1-runtime-classpath.py"
    spec = importlib.util.spec_from_file_location("n1i_d0_deriver", path)
    if spec is None or spec.loader is None:
        raise D0Error(f"cannot_load_deriver={path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_static(repo: Path):
    path = repo / "build/titan2/n1i_static.py"
    spec = importlib.util.spec_from_file_location("n1i_d0_static", path)
    if spec is None or spec.loader is None:
        raise D0Error(f"cannot_load_static={path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def a0_decision(system_root: Path, vendor: Path, odm: Path | None) -> tuple[str, list[tuple]]:
    pre_root = None
    for root in (odm, vendor):
        if root and (root / "etc/selinux/precompiled_sepolicy").is_file():
            pre_root = root
            break
    rows = []
    if pre_root is None:
        return "SPLIT_COMPILE_REQUIRED", [("precompiled", "-", "-", "MISSING")]
    pre = pre_root / "etc/selinux/precompiled_sepolicy"
    pairs = [
        (
            system_root / "etc/selinux/plat_sepolicy_and_mapping.sha256",
            Path(str(pre) + ".plat_sepolicy_and_mapping.sha256"),
            "plat",
        ),
        (
            system_root / "system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256",
            Path(str(pre) + ".system_ext_sepolicy_and_mapping.sha256"),
            "system_ext",
        ),
        (
            system_root / "product/etc/selinux/product_sepolicy_and_mapping.sha256",
            Path(str(pre) + ".product_sepolicy_and_mapping.sha256"),
            "product",
        ),
    ]
    decision = "PRECOMPILED_MATCH"
    for actual, sealed, label in pairs:
        ae, se = actual.is_file(), sealed.is_file()
        if not ae:
            if se:
                decision = "SPLIT_COMPILE_REQUIRED"
                rows.append((label, str(actual), str(sealed), "ACTUAL_MISSING_PRECOMPILED_PRESENT"))
            else:
                rows.append((label, str(actual), str(sealed), "BOTH_ABSENT_IGNORED_BY_INIT"))
            continue
        if not se:
            decision = "SPLIT_COMPILE_REQUIRED"
            rows.append((label, str(actual), str(sealed), "PRECOMPILED_HASH_MISSING"))
            continue
        av, sv = read_first(actual), read_first(sealed)
        match = av != "" and av == sv
        rows.append((label, av, sv, "MATCH" if match else "MISMATCH"))
        if not match:
            decision = "SPLIT_COMPILE_REQUIRED"
    return decision, rows


def policy_version(android_root: Path) -> int:
    bp = android_root / "system/sepolicy/Android.bp"
    if not bp.is_file():
        raise D0Error("android_sepolicy_android_bp_missing")
    vals = set(int(x) for x in re.findall(r"-DSEPOLICY_VERSION=(\d+)", bp.read_text(errors="replace")))
    if len(vals) != 1:
        raise D0Error(f"sepolicy_version_ambiguity={sorted(vals)}")
    return next(iter(vals))


def build_secilc_args(
    system_root: Path,
    vendor: Path,
    odm: Path | None,
    secilc: Path,
    android_root: Path,
    output: Path,
    disable_neverallow: bool,
) -> tuple[list[str], list[Path], str]:
    init_src = android_root / "system/core/init/selinux.cpp"
    if not init_src.is_file():
        raise D0Error("init_selinux_source_missing")
    init_text = init_src.read_text(errors="replace")
    for marker in (
        '"/system/bin/secilc"',
        '"-m", "-M", "true", "-G", "-N"',
        '"/vendor/etc/selinux/plat_pub_versioned.cil"',
        '"/vendor/etc/selinux/vendor_sepolicy.cil"',
    ):
        if marker not in init_text:
            raise D0Error(f"init_selinux_semantics_marker_missing={marker}")

    vers_file = vendor / "etc/selinux/plat_sepolicy_vers.txt"
    if not vers_file.is_file():
        raise D0Error("vendor_mapping_version_missing")
    vend_vers = read_first(vers_file)
    if not vend_vers:
        raise D0Error("vendor_mapping_version_empty")

    version = policy_version(android_root)
    plat = system_root / "etc/selinux/plat_sepolicy.cil"
    mapping = system_root / f"etc/selinux/mapping/{vend_vers}.cil"
    required = [plat, mapping]
    optional = [
        system_root / f"etc/selinux/mapping/{vend_vers}.compat.cil",
        system_root / "system_ext/etc/selinux/system_ext_sepolicy.cil",
        system_root / f"system_ext/etc/selinux/mapping/{vend_vers}.cil",
        system_root / f"system_ext/etc/selinux/mapping/{vend_vers}.compat.cil",
        system_root / "product/etc/selinux/product_sepolicy.cil",
        system_root / f"product/etc/selinux/mapping/{vend_vers}.cil",
    ]
    vendor_pub = vendor / "etc/selinux/plat_pub_versioned.cil"
    vendor_cil = vendor / "etc/selinux/vendor_sepolicy.cil"
    required += [vendor_pub, vendor_cil]
    if odm and (odm / "etc/selinux/odm_sepolicy.cil").is_file():
        optional.append(odm / "etc/selinux/odm_sepolicy.cil")

    genfs_ver = "202404"
    genfs_txt = vendor / "etc/selinux/genfs_labels_version.txt"
    if genfs_txt.is_file() and read_first(genfs_txt):
        genfs_ver = read_first(genfs_txt)
    genfs = system_root / f"etc/selinux/plat_sepolicy_genfs_{genfs_ver}.cil"
    if genfs.is_file():
        optional.append(genfs)

    missing = [p for p in required if not p.is_file()]
    if missing:
        raise D0Error("secilc_required_input_missing=" + ",".join(str(p) for p in missing))

    args = [str(secilc), str(plat), "-m", "-M", "true", "-G"]
    if disable_neverallow:
        args.append("-N")
    args += ["-c", str(version), str(mapping), "-o", str(output), "-f", "/dev/null"]
    ordered_optional = optional[:6] + [p for p in optional[6:] if p.is_file()]
    for p in ordered_optional:
        if p.is_file():
            args.append(str(p))
    args += [str(vendor_pub), str(vendor_cil)]
    # odm/genfs are already in optional tail above only when present.
    tail = [p for p in optional[6:] if p.is_file()]
    # Avoid duplicates if appended before vendor in a future edit.
    for p in tail:
        if str(p) in args:
            args.remove(str(p))
        args.append(str(p))

    inputs = [Path(x) for x in args if x.endswith(".cil") and Path(x).is_file()]
    return args, inputs, vend_vers


def cil_types(paths: list[Path]) -> set[str]:
    out: set[str] = set()
    pat = re.compile(r"\(type\s+([^\s\)]+)")
    for path in paths:
        for m in pat.finditer(path.read_text(encoding="utf-8", errors="replace")):
            out.add(m.group(1))
    return out


def precompiled_policy_path(vendor: Path, odm: Path | None) -> Path | None:
    for root in (odm, vendor):
        if root is not None:
            candidate = root / "etc/selinux/precompiled_sepolicy"
            if candidate.is_file():
                return candidate
    return None


def gate_a(
    profile: str,
    system_root: Path,
    vendor: Path,
    odm: Path | None,
    secilc: Path,
    android_root: Path,
    out: Path,
) -> tuple[Result, list[Path], Path | None]:
    decision, rows = a0_decision(system_root, vendor, odm)
    tsv_write(out / f"gate-a0-{profile}.tsv", ("scope", "actual", "precompiled", "result"), rows)
    env_write(out / f"gate-a0-{profile}.env", {
        f"N1I_D0_{profile.upper()}_PRECOMPILED_POLICY": decision,
    })
    if decision == "PRECOMPILED_MATCH":
        precompiled = precompiled_policy_path(vendor, odm)
        if precompiled is None:
            return (
                Result("A", profile, "UNKNOWN", "PRECOMPILED_MATCH_WITHOUT_POLICY"),
                [],
                None,
            )
        return (
            Result("A", profile, "PASS", "PRECOMPILED_POLICY_MATCHES_INIT_HASHES"),
            [],
            precompiled,
        )

    init_out = out / f"{profile}.init-equivalent.sepolicy"
    log = out / f"gate-a1-{profile}.log"
    try:
        args, inputs, vend_vers = build_secilc_args(
            system_root, vendor, odm, secilc, android_root, init_out, True
        )
    except D0Error as exc:
        return Result("A", profile, "UNKNOWN", str(exc)), [], None

    cmd_file = out / f"gate-a1-{profile}.command.txt"
    cmd_file.write_text("\n".join(args) + "\n", encoding="utf-8")
    input_rows = [(str(p), sha256(p), p.stat().st_size) for p in inputs]
    tsv_write(out / f"gate-a1-{profile}-inputs.tsv", ("path", "sha256", "bytes"), input_rows)
    cp = run(args, out=log)
    if cp.returncode != 0 or not init_out.is_file() or init_out.stat().st_size == 0:
        return (
            Result("A", profile, "BOOT_FATAL", f"INIT_EQUIVALENT_SECILC_RC={cp.returncode}"),
            inputs,
            None,
        )

    compliance_args, _inputs2, _ = build_secilc_args(
        system_root, vendor, odm, secilc, android_root,
        out / f"{profile}.compliance.sepolicy", False
    )
    compliance_log = out / f"gate-a1-{profile}-compliance.log"
    compliance = run(compliance_args, out=compliance_log)
    compliance_state = "PASS" if compliance.returncode == 0 else "COMPLIANCE_ONLY"
    env_write(out / f"gate-a1-{profile}.env", {
        f"N1I_D0_{profile.upper()}_VENDOR_MAPPING_VERSION": vend_vers,
        f"N1I_D0_{profile.upper()}_INIT_EQUIVALENT_SECILC_RC": cp.returncode,
        f"N1I_D0_{profile.upper()}_SELINUX_COMPLIANCE": compliance_state,
    })
    return (
        Result("A", profile, "PASS", f"SPLIT_COMPILE_PASS compliance={compliance_state}"),
        inputs,
        init_out,
    )


def partition_context_files(
    part: str,
    root: Path,
    kind: str,
) -> list[Path]:
    prefixes = {
        "system": ("plat",),
        "system_ext": ("system_ext",),
        "product": ("product",),
        "vendor": ("vendor",),
        "odm": ("odm",),
    }.get(part, ())
    candidates = [
        root / f"etc/selinux/{prefix}_{kind}_contexts"
        for prefix in prefixes
    ]
    candidates.append(root / f"etc/selinux/{kind}_contexts")
    return [p for p in candidates if p.is_file()]


def context_union(
    profile: str,
    roots: dict[str, Path],
    vendor: Path,
    odm: Path | None,
    kind: str,
) -> tuple[list[tuple], list[tuple]]:
    scan = dict(roots)
    scan["vendor"] = vendor
    if odm:
        scan["odm"] = odm
    rows = []
    conflicts = []
    seen: dict[str, tuple[str, str]] = {}
    for part, root in scan.items():
        for path in partition_context_files(part, root, kind):
            for name, typ, extra in parse_contexts(path):
                rows.append((part, name, typ, extra, str(path)))
                if name in seen and seen[name][1] != typ:
                    conflicts.append(
                        (name, seen[name][0], seen[name][1], part, typ)
                    )
                else:
                    seen.setdefault(name, (part, typ))
    return rows, conflicts


def gate_b(
    profile: str,
    roots: dict[str, Path],
    vendor: Path,
    odm: Path | None,
    a_state: str,
    a_inputs: list[Path],
    policy_path: Path | None,
    property_info_checker: Path | None,
    out: Path,
) -> Result:
    rows, conflicts = context_union(profile, roots, vendor, odm, "property")
    declared = cil_types(a_inputs) if a_state == "PASS" and a_inputs else set()
    undeclared = []
    if a_state == "PASS" and a_inputs:
        for part, name, typ, extra, path in rows:
            if typ not in declared:
                undeclared.append((part, name, typ, path))
    tsv_write(
        out / f"gate-b-{profile}-property-contexts.tsv",
        ("partition", "property", "type", "extra", "path"), rows
    )
    tsv_write(
        out / f"gate-b-{profile}-conflicts.tsv",
        ("property", "first_partition", "first_type", "second_partition", "second_type"),
        conflicts,
    )
    tsv_write(
        out / f"gate-b-{profile}-undeclared-types.tsv",
        ("partition", "property", "type", "path"), undeclared,
    )
    if a_state != "PASS":
        return Result(
            "B", profile, "UNKNOWN",
            "GATE_A_NOT_PASS_PROPERTY_VALIDATION_UNAVAILABLE",
        )
    if policy_path is None or not policy_path.is_file():
        return Result(
            "B", profile, "UNKNOWN",
            "MERGED_OR_PRECOMPILED_POLICY_UNAVAILABLE",
        )
    if property_info_checker is None or not property_info_checker.is_file():
        return Result(
            "B", profile, "UNKNOWN",
            "PROPERTY_INFO_CHECKER_UNAVAILABLE",
        )

    context_files = []
    scan = dict(roots)
    scan["vendor"] = vendor
    if odm:
        scan["odm"] = odm
    for part in ("system", "system_ext", "product", "vendor", "odm"):
        root = scan.get(part)
        if root is None:
            continue
        context_files.extend(
            partition_context_files(part, root, "property")
        )
    if not context_files:
        return Result("B", profile, "UNKNOWN", "PROPERTY_CONTEXT_INPUTS_MISSING")

    checker_log = out / f"gate-b-{profile}-property-info-checker.log"
    checker = run(
        [
            str(property_info_checker),
            str(policy_path),
            *[str(p) for p in context_files],
        ],
        out=checker_log,
    )
    env_write(out / f"gate-b-{profile}.env", {
        f"N1I_D0_GATE_B_{profile.upper()}_PROPERTY_INFO_CHECKER_RC":
            checker.returncode,
        f"N1I_D0_GATE_B_{profile.upper()}_POLICY_PATH": str(policy_path),
        f"N1I_D0_GATE_B_{profile.upper()}_PROPERTY_CONTEXT_FILE_COUNT":
            len(context_files),
    })
    if checker.returncode != 0:
        return Result(
            "B", profile, "BOOT_FATAL",
            f"PROPERTY_INFO_CHECKER_RC={checker.returncode}",
        )

    # Manual collision/type reports remain explanatory. The Android
    # property_info_checker result above is the fatality authority.
    detail = (
        f"CONTEXT_ROWS={len(rows)} manual_conflicts={len(conflicts)} "
        f"cil_undeclared={len(undeclared)}"
    )
    return Result("B", profile, "PASS", detail)


def vintf_services(vendor: Path, odm: Path | None) -> set[str]:
    roots = [vendor] + ([odm] if odm else [])
    out: set[str] = set()
    for root in roots:
        vintf = root / "etc/vintf"
        paths = sorted(vintf.rglob("*.xml")) if vintf.is_dir() else []
        for path in paths:
            try:
                tree = ET.parse(path)
            except ET.ParseError:
                continue
            for hal in tree.findall(".//hal"):
                name = (hal.findtext("name") or "").strip()
                fmt = hal.attrib.get("format", "")
                for fq in hal.findall("fqname"):
                    value = (fq.text or "").strip()
                    if name and value:
                        if value.startswith("@"):
                            out.add(f"{name}{value}")
                        else:
                            out.add(f"{name}.{value}" if fmt == "aidl" else f"{name}/{value}")
                for iface in hal.findall("interface"):
                    iname = (iface.findtext("name") or "").strip()
                    for inst in iface.findall("instance"):
                        iv = (inst.text or "").strip()
                        if name and iname and iv:
                            if fmt == "aidl":
                                out.add(f"{name}.{iname}/{iv}")
                            else:
                                out.add(f"{name}::{iname}/{iv}")
    return out


def gate_c(
    profile: str,
    roots: dict[str, Path],
    vendor: Path,
    odm: Path | None,
    out: Path,
) -> Result:
    rows, conflicts = context_union(profile, roots, vendor, odm, "service")
    providers = vintf_services(vendor, odm)
    missing = []
    for part, name, typ, extra, path in rows:
        if part not in ("system_ext", "product"):
            continue
        if ("imsSlot" in name or "mtk" in name.lower() or "radio" in name.lower()):
            normalized = name.replace("::", ".")
            if name not in providers and normalized not in providers:
                missing.append((name, part, typ, "SERVICE_PROVIDER_MISSING_FUNCTIONAL_RISK"))
    tsv_write(
        out / f"gate-c-{profile}-service-contexts.tsv",
        ("partition", "service", "type", "extra", "path"), rows
    )
    tsv_write(
        out / f"gate-c-{profile}-conflicts.tsv",
        ("service", "first_partition", "first_type", "second_partition", "second_type"),
        conflicts,
    )
    tsv_write(
        out / f"gate-c-{profile}-vintf-missing.tsv",
        ("service", "partition", "type", "classification"), missing
    )
    detail = f"conflicts={len(conflicts)} provider_missing={len(missing)}"
    return Result("C", profile, "FUNCTIONAL_RISK" if conflicts or missing else "PASS", detail)


def cert_sha256(apksigner: str, apk: Path) -> str:
    cp = run([apksigner, "verify", "--print-certs", str(apk)])
    if cp.returncode != 0:
        raise D0Error(f"apksigner_verify_rc={cp.returncode}:{apk}")
    m = re.search(
        r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]{64})",
        cp.stdout,
    )
    if not m:
        raise D0Error(f"apksigner_cert_digest_missing={apk}")
    return m.group(1).lower()


def profile_allowlist_control(
    profile: str,
    roots: dict[str, Path],
    vendor: Path,
    odm: Path | None,
    aapt2: str,
    out: Path,
) -> tuple[str, str]:
    framework_res = roots["system"] / "framework/framework-res.apk"
    if not framework_res.is_file():
        return "UNKNOWN", "FRAMEWORK_RES_MISSING"
    privileged, parsed = protection_permissions(aapt2, framework_res)
    if parsed != "PARSED_FRAMEWORK_RES":
        return "UNKNOWN", f"FRAMEWORK_PERMISSION_PARSE={parsed}"

    allow, _rows = parse_privapp_files(roots)
    props = prop_values(roots, vendor, odm, "ro.control_privapp_permissions")
    values = sorted(set(v for _p, v, _f in props))
    enforcement = (
        values[0]
        if len(values) == 1
        else ("UNSPECIFIED" if not values else "CONFLICT")
    )

    rows = []
    parse_failures = 0
    missing_total = 0
    for part, root in roots.items():
        for apk in sorted(root.glob("priv-app/**/*.apk")):
            try:
                badging = aapt2_badging(aapt2, apk)
                requested = aapt2_permissions(aapt2, apk)
            except D0Error:
                parse_failures += 1
                rows.append((part, str(apk), "UNKNOWN", 0, 0, "PARSE_FAILED"))
                continue
            m = re.search(r"^package: name='([^']+)'", badging, re.M)
            if not m:
                parse_failures += 1
                rows.append((part, str(apk), "UNKNOWN", 0, 0, "PACKAGE_UNKNOWN"))
                continue
            package = m.group(1)
            required = requested & privileged
            covered = allow.get((part, package), set())
            missing = sorted(required - covered)
            missing_total += len(missing)
            rows.append(
                (
                    part,
                    package,
                    str(apk),
                    len(required),
                    len(missing),
                    ",".join(missing) or "NONE",
                )
            )

    tsv_write(
        out / f"gate-d-{profile}-all-privapp-coverage.tsv",
        (
            "partition", "package", "apk",
            "required_privileged_count", "missing_count", "missing",
        ),
        rows,
    )
    tsv_write(
        out / f"gate-d-{profile}-enforcement.tsv",
        ("partition", "value", "path"),
        props,
    )

    if parse_failures:
        return "UNKNOWN", f"PRIVAPP_PARSE_FAILURES={parse_failures}"
    if enforcement in ("CONFLICT", "UNSPECIFIED"):
        return "UNKNOWN", f"PRIVAPP_ENFORCEMENT={enforcement}"
    if enforcement == "enforce" and missing_total:
        return "BOOT_FATAL", f"PRIVAPP_MISSING_TOTAL={missing_total}"
    if missing_total:
        return "FUNCTIONAL_RISK", (
            f"PRIVAPP_MISSING_TOTAL={missing_total} mode={enforcement}"
        )
    return "PASS", f"PRIVAPP_COVERAGE_COMPLETE mode={enforcement}"


def gate_d(
    profile: str,
    roots: dict[str, Path],
    vendor: Path,
    odm: Path | None,
    stock_roots: dict[str, Path],
    aapt2: str,
    apksigner: str,
    out: Path,
) -> Result:
    control_state, control_detail = profile_allowlist_control(
        profile, roots, vendor, odm, aapt2, out
    )
    if profile == "n1f":
        return Result("D", profile, control_state, control_detail)
    if control_state in ("UNKNOWN", "BOOT_FATAL"):
        return Result("D", profile, control_state, control_detail)

    ims = find_ims_apk(roots["system"])
    if ims is None:
        return Result("D", profile, "UNKNOWN", "IMS_APK_NOT_UNIQUELY_PRESENT")
    framework_res = roots["system"] / "framework/framework-res.apk"
    stock_allow, stock_rows = parse_privapp_files(stock_roots)
    c2_allow, c2_rows = parse_privapp_files(roots)
    tsv_write(
        out / "gate-d-stock-privapp.tsv",
        ("partition", "package", "kind", "permission", "path"), stock_rows
    )
    tsv_write(
        out / f"gate-d-{profile}-privapp.tsv",
        ("partition", "package", "kind", "permission", "path"), c2_rows
    )

    stock_locations = sorted(part for (part, pkg) in stock_allow if pkg == "com.mediatek.ims")
    requested = aapt2_permissions(aapt2, ims)
    privileged, parsed = protection_permissions(aapt2, framework_res)
    if parsed != "PARSED_FRAMEWORK_RES":
        return Result("D", profile, "UNKNOWN", f"FRAMEWORK_PERMISSION_PARSE={parsed}")
    required = requested & privileged
    covered = c2_allow.get(("system_ext", "com.mediatek.ims"), set())
    missing = sorted(required - covered)

    props = prop_values(roots, vendor, odm, "ro.control_privapp_permissions")
    values = sorted(set(v for _p, v, _f in props))
    enforcement = values[0] if len(values) == 1 else ("UNSPECIFIED" if not values else "CONFLICT")
    coverage_rows = [(p, "YES" if p in covered else "NO") for p in sorted(required)]
    tsv_write(
        out / f"gate-d-{profile}-ims-coverage.tsv",
        ("privileged_permission", "system_ext_allowlisted"), coverage_rows
    )
    tsv_write(
        out / f"gate-d-{profile}-enforcement.tsv",
        ("partition", "value", "path"), props
    )

    manifest = manifest_summary(aapt2, ims)
    runtime_seapp_roots = dict(roots)
    runtime_seapp_roots["vendor"] = vendor
    if odm:
        runtime_seapp_roots["odm"] = odm
    stock_seapp_roots = dict(stock_roots)
    stock_seapp_roots["vendor"] = vendor
    if odm:
        stock_seapp_roots["odm"] = odm

    try:
        platform_cert = cert_sha256(apksigner, framework_res)
        ims_cert = cert_sha256(apksigner, ims)
        stock_framework_res = stock_roots["system"] / "framework/framework-res.apk"
        stock_ims_candidates = [
            stock_roots["system_ext"] / "priv-app/ImsService/ImsService.apk",
            stock_roots["system_ext"] / "app/ImsService/ImsService.apk",
        ]
        stock_ims_hits = [p for p in stock_ims_candidates if p.is_file()]
        stock_ims = stock_ims_hits[0] if len(stock_ims_hits) == 1 else None
        if not stock_framework_res.is_file() or stock_ims is None:
            raise D0Error("stock_signing_authority_missing")
        stock_platform_cert = cert_sha256(apksigner, stock_framework_res)
        stock_ims_cert = cert_sha256(apksigner, stock_ims)
    except D0Error as exc:
        return Result("D", profile, "UNKNOWN", str(exc))

    mac_rows, mac_state, runtime_seinfo = mac_permissions_seinfo(
        runtime_seapp_roots,
        package="com.mediatek.ims",
        cert_sha256=ims_cert,
    )
    stock_mac_rows, stock_mac_state, stock_seinfo = mac_permissions_seinfo(
        stock_seapp_roots,
        package="com.mediatek.ims",
        cert_sha256=stock_ims_cert,
    )
    mac_header = (
        "partition", "path", "rule", "signer_sha256", "package_or_match", "seinfo",
    )
    tsv_write(out / f"gate-d-{profile}-mac-permissions.tsv", mac_header, mac_rows)
    tsv_write(out / "gate-d-stock-mac-permissions.tsv", mac_header, stock_mac_rows)

    if not mac_state.startswith("PASS_") or not stock_mac_state.startswith("PASS_"):
        return Result(
            "D", profile, "UNKNOWN",
            f"SEINFO_AUTHORITY_UNCLOSED runtime={mac_state} stock={stock_mac_state}",
        )

    seapp, seapp_state, seapp_domain = seapp_resolution(
        runtime_seapp_roots,
        package="com.mediatek.ims",
        user="radio",
        seinfo=runtime_seinfo,
        is_priv_app=True,
    )
    stock_seapp, stock_seapp_state, stock_seapp_domain = seapp_resolution(
        stock_seapp_roots,
        package="com.mediatek.ims",
        user="radio",
        seinfo=stock_seinfo,
        is_priv_app=True,
    )

    phone_uid_rows = []
    phone_uid_bad_cert = []
    for part, root in roots.items():
        for top in ("app", "priv-app"):
            base = root / top
            if not base.is_dir():
                continue
            for apk in sorted(base.glob("**/*.apk")):
                try:
                    app = manifest_summary(aapt2, apk)
                except D0Error:
                    continue
                if app.get("shared_uid") != "android.uid.phone":
                    continue
                try:
                    digest = cert_sha256(apksigner, apk)
                except D0Error:
                    phone_uid_rows.append(
                        (part, str(apk), app.get("package", ""), "UNKNOWN", "UNKNOWN")
                    )
                    phone_uid_bad_cert.append(str(apk))
                    continue
                match = digest == platform_cert
                phone_uid_rows.append(
                    (
                        part,
                        str(apk),
                        app.get("package", ""),
                        digest,
                        "YES" if match else "NO",
                    )
                )
                if not match:
                    phone_uid_bad_cert.append(str(apk))
    tsv_write(
        out / f"gate-d-{profile}-phone-uid-signatures.tsv",
        ("partition", "apk", "package", "cert_sha256", "platform_match"),
        phone_uid_rows,
    )
    seapp_header = (
        "partition", "path", "user", "seinfo", "name",
        "isPrivApp", "domain", "line",
    )
    tsv_write(out / f"gate-d-{profile}-seapp.tsv", seapp_header, seapp)
    tsv_write(out / "gate-d-stock-seapp.tsv", seapp_header, stock_seapp)

    env_write(out / f"gate-d-{profile}.env", {
        "N1I_D0_GATE_D_STOCK_IMS_ALLOWLIST_PARTITIONS": ",".join(stock_locations) or "NONE",
        "N1I_D0_GATE_D_C2_IMS_APK_PARTITION": "system_ext",
        "N1I_D0_GATE_D_PRIVAPP_ENFORCEMENT": enforcement,
        "N1I_D0_GATE_D_REQUESTED_PERMISSION_COUNT": len(requested),
        "N1I_D0_GATE_D_PRIVILEGED_REQUIRED_COUNT": len(required),
        "N1I_D0_GATE_D_SYSTEM_EXT_MISSING_COUNT": len(missing),
        "N1I_D0_GATE_D_SHARED_UID": manifest.get("shared_uid", ""),
        "N1I_D0_GATE_D_PLATFORM_CERT_SHA256": platform_cert,
        "N1I_D0_GATE_D_IMS_CERT_SHA256": ims_cert,
        "N1I_D0_GATE_D_IMS_PLATFORM_CERT_MATCH": "YES" if ims_cert == platform_cert else "NO",
        "N1I_D0_GATE_D_STOCK_IMS_PLATFORM_CERT_MATCH": "YES" if stock_ims_cert == stock_platform_cert else "NO",
        "N1I_D0_GATE_D_MAC_PERMISSIONS_STATE": mac_state,
        "N1I_D0_GATE_D_SEINFO": runtime_seinfo,
        "N1I_D0_GATE_D_STOCK_MAC_PERMISSIONS_STATE": stock_mac_state,
        "N1I_D0_GATE_D_STOCK_SEINFO": stock_seinfo,
        "N1I_D0_GATE_D_PHONE_UID_MEMBER_COUNT": len(phone_uid_rows),
        "N1I_D0_GATE_D_PHONE_UID_BAD_CERT_COUNT": len(phone_uid_bad_cert),
        "N1I_D0_GATE_D_SEAPP_MATCH_COUNT": len(seapp),
        "N1I_D0_GATE_D_SEAPP_STATE": seapp_state,
        "N1I_D0_GATE_D_SEAPP_DOMAIN": seapp_domain or "UNKNOWN",
        "N1I_D0_GATE_D_STOCK_SEAPP_MATCH_COUNT": len(stock_seapp),
        "N1I_D0_GATE_D_STOCK_SEAPP_STATE": stock_seapp_state,
        "N1I_D0_GATE_D_STOCK_SEAPP_DOMAIN": stock_seapp_domain or "UNKNOWN",
    })

    if stock_ims_cert != stock_platform_cert:
        return Result("D", profile, "UNKNOWN", "STOCK_IMS_PLATFORM_CERT_MISMATCH")
    if ims_cert != platform_cert:
        return Result("D", profile, "BOOT_FATAL", "IMS_PLATFORM_CERT_MISMATCH")
    if phone_uid_bad_cert:
        return Result(
            "D", profile, "BOOT_FATAL",
            f"PHONE_UID_CERT_MISMATCH_COUNT={len(phone_uid_bad_cert)}",
        )

    state, detail = privapp_severity(
        enforcement,
        set(missing),
        str(manifest.get("shared_uid", "")),
    )
    if state == "PASS" and (
        seapp_state.startswith("UNKNOWN_")
        or stock_seapp_state.startswith("UNKNOWN_")
    ):
        return Result(
            "D", profile, "UNKNOWN",
            f"SEAPP_UNCLOSED c2={seapp_state} stock={stock_seapp_state}",
        )
    if (
        state == "PASS"
        and stock_seapp_domain
        and seapp_domain
        and stock_seapp_domain != seapp_domain
    ):
        return Result(
            "D", profile, "FUNCTIONAL_RISK",
            f"SEAPP_DOMAIN_DELTA stock={stock_seapp_domain} c2={seapp_domain}",
        )
    if state == "PASS" and control_state == "FUNCTIONAL_RISK":
        return Result("D", profile, "FUNCTIONAL_RISK", control_detail)
    return Result("D", profile, state, detail)


def map_device_jar(
    system_root: Path,
    apex_root: Path | None,
    device: str,
    runtime_roots: dict[str, Path] | None = None,
) -> Path | None:
    roots = runtime_roots or partition_roots(system_root)
    if device.startswith("/system_ext/"):
        return roots["system_ext"] / device.removeprefix("/system_ext/")
    if device.startswith("/product/"):
        return roots["product"] / device.removeprefix("/product/")
    if device.startswith("/system/"):
        return roots["system"] / device.removeprefix("/system/")
    if device.startswith("/apex/") and apex_root:
        parts = device.split("/", 3)
        if len(parts) != 4:
            return None
        module, rel = parts[2], parts[3]
        candidates = [
            apex_root / f"{module}.apex" / rel,
            apex_root / f"{module}.capex" / rel,
            apex_root / module / rel,
        ]
        hits = [p for p in candidates if p.is_file()]
        return hits[0] if len(hits) == 1 else None
    return None


def vdex_dexes(static_mod, jar: Path) -> list:
    stem = jar.stem
    for arch in ("arm64", "arm"):
        vdex = jar.parent / "oat" / arch / f"{stem}.vdex"
        if not vdex.is_file():
            continue
        data = vdex.read_bytes()
        dexes = []
        for match in re.finditer(rb"dex\\n0[0-9]{2}\\x00", data):
            start = match.start()
            if start + 0x24 > len(data):
                raise D0Error(
                    f"vdex_truncated_dex_header={vdex}:{start:#x}"
                )
            size = struct.unpack_from("<I", data, start + 0x20)[0]
            if size < 0x70 or start + size > len(data):
                raise D0Error(
                    f"vdex_invalid_dex_size={vdex}:{start:#x}:size={size}"
                )
            try:
                dexes.append(
                    static_mod.DexFile(
                        data[start : start + size],
                        f"{vdex.name}@{start:#x}",
                    )
                )
            except Exception as exc:
                raise D0Error(
                    f"vdex_dex_parse_failed={vdex}:{exc}"
                ) from exc
        if dexes:
            return dexes
        if b"cdex" in data:
            raise D0Error(f"compact_vdex_unsupported={vdex}")
        raise D0Error(f"vdex_contains_no_standard_dex={vdex}")
    return []


def class_set(static_mod, jar: Path) -> tuple[set[str], str]:
    load_error: Exception | None = None
    try:
        container = static_mod.load_container(jar)
        dexes = [dex for _entry, dex in container.dexes]
    except Exception as exc:
        load_error = exc
        dexes = []

    source = "JAR_CLASSES_DEX"
    if not dexes:
        try:
            dexes = vdex_dexes(static_mod, jar)
        except D0Error as exc:
            return set(), f"UNDECODABLE:{exc}"
        if dexes:
            source = "SIBLING_VDEX"
        elif load_error is not None:
            return set(), f"UNDECODABLE:{load_error}"
        else:
            return set(), "UNDECODABLE:NO_CLASSES_DEX_OR_VDEX"

    classes = {
        cd.descriptor
        for dex in dexes
        for cd in dex.classes
    }
    if not classes:
        return set(), "UNDECODABLE:NO_DEFINED_CLASSES"
    return classes, source


def enabled_classpath_jars(
    deriver,
    fragment: Path,
    classpath_id: int,
) -> list:
    return [
        jar
        for jar in deriver.parse_fragment(fragment)
        if jar.classpath == classpath_id
        and deriver.enabled(jar, API_LEVEL)
    ]


def systemserver_paths(
    deriver,
    system_root: Path,
    apex_root: Path | None,
) -> tuple[list[str], list[tuple]]:
    paths: list[str] = []
    rows: list[tuple] = []
    system_fragment = system_root / "etc/classpaths/systemserverclasspath.pb"
    if system_fragment.is_file():
        for jar in enabled_classpath_jars(
            deriver, system_fragment, SYSTEMSERVERCLASSPATH
        ):
            paths.append(jar.path)
            rows.append(("system", jar.path, str(system_fragment)))
    if apex_root and apex_root.is_dir():
        for fragment in sorted(
            apex_root.glob("*/etc/classpaths/systemserverclasspath.pb")
        ):
            module = fragment.parent.parent.parent.name
            for jar in enabled_classpath_jars(
                deriver, fragment, SYSTEMSERVERCLASSPATH
            ):
                paths.append(jar.path)
                rows.append((module, jar.path, str(fragment)))
    return list(dict.fromkeys(paths)), rows


def shared_library_declarations(
    system_root: Path,
    runtime_roots: dict[str, Path] | None = None,
) -> list[tuple]:
    rows: list[tuple] = []
    roots = runtime_roots or partition_roots(system_root)
    for part, root in roots.items():
        base = root / "etc/permissions"
        if not base.is_dir():
            continue
        for path in sorted(base.glob("*.xml")):
            try:
                tree = ET.parse(path)
            except ET.ParseError:
                continue
            for lib in tree.findall(".//library"):
                name = lib.attrib.get("name", "")
                file_path = lib.attrib.get("file", "")
                if name or file_path:
                    rows.append((part, name, file_path, str(path)))
    return rows


def gate_e(
    profile: str,
    system_root: Path,
    apex_root: Path | None,
    repo: Path,
    out: Path,
    control_owners: dict[str, str] | None = None,
    boot_execution_proven: bool = False,
    linkage_evidence: Path | None = None,
    runtime_roots: dict[str, Path] | None = None,
) -> tuple[Result, dict[str, str]]:
    deriver = load_deriver(repo)
    static_mod = load_static(repo)
    fragment = system_root / "etc/classpaths/bootclasspath.pb"
    if not fragment.is_file():
        return Result("E", profile, "UNKNOWN", "SYSTEM_BOOTCLASSPATH_FRAGMENT_MISSING"), {}
    try:
        system_jars = deriver.boot_jars(fragment, API_LEVEL)
    except Exception as exc:
        return Result("E", profile, "UNKNOWN", f"BOOTCLASSPATH_PARSE={exc}"), {}

    ordered: list[str] = [j.path for j in system_jars]
    apex_fragment_rows = []
    if apex_root and apex_root.is_dir():
        try:
            frags = deriver.apex_fragments(apex_root, API_LEVEL)
        except Exception as exc:
            return Result("E", profile, "UNKNOWN", f"APEX_FRAGMENT_PARSE={exc}"), {}
        art = [f for f in frags if f.module == "com.android.art"]
        other = sorted((f for f in frags if f.module != "com.android.art"), key=lambda x: x.module)
        ordered = [j.path for f in art for j in f.jars] + ordered + [j.path for f in other for j in f.jars]
        for f in frags:
            for j in f.jars:
                apex_fragment_rows.append((f.module, j.path, str(f.fragment)))
    else:
        return Result("E", profile, "UNKNOWN", "APEX_EXTRACTED_RUNTIME_ROOT_MISSING"), {}

    missing = []
    undecodable = []
    systemserver, systemserver_rows = systemserver_paths(
        deriver, system_root, apex_root
    )
    systemserver_missing = []
    for idx, device in enumerate(systemserver):
        host = map_device_jar(system_root, apex_root, device, runtime_roots)
        if host is None or not host.is_file():
            systemserver_missing.append(
                (idx, device, str(host) if host else "UNRESOLVED")
            )
    tsv_write(
        out / f"gate-e-{profile}-systemserverclasspath.tsv",
        ("source", "device_path", "fragment"),
        systemserver_rows,
    )
    tsv_write(
        out / f"gate-e-{profile}-systemserver-missing.tsv",
        ("index", "device_path", "host_path"),
        systemserver_missing,
    )

    shared_libs = shared_library_declarations(system_root, runtime_roots)
    tsv_write(
        out / f"gate-e-{profile}-shared-libraries.tsv",
        ("partition", "name", "file", "path"),
        shared_libs,
    )
    mtk_shared = [
        row for row in shared_libs
        if "mediatek-common" in row[1] or "mediatek-common" in row[2]
        or "mediatek-ims-base" in row[1]
        or "mediatek-ims-base" in row[2]
    ]

    undecodable = []
    duplicate_classes: dict[str, list[str]] = {}
    owners: dict[str, str] = {}
    jar_rows = []
    for idx, device in enumerate(ordered):
        host = map_device_jar(system_root, apex_root, device, runtime_roots)
        if host is None or not host.is_file():
            missing.append((idx, device, str(host) if host else "UNRESOLVED"))
            jar_rows.append((idx, device, "MISSING", "-", 0))
            continue
        classes, parse_state = class_set(static_mod, host)
        jar_rows.append((idx, device, parse_state, sha256(host), len(classes)))
        if parse_state.startswith("UNDECODABLE:"):
            undecodable.append((idx, device, str(host), parse_state))
            continue
        for cls in classes:
            if cls in owners:
                duplicate_classes.setdefault(cls, [owners[cls]]).append(device)
            else:
                owners[cls] = device

    tsv_write(out / f"gate-e-{profile}-classpath.tsv",
              ("index", "device_path", "parse_state", "sha256", "class_count"), jar_rows)
    tsv_write(out / f"gate-e-{profile}-missing.tsv",
              ("index", "device_path", "host_path"), missing)
    tsv_write(out / f"gate-e-{profile}-undecodable.tsv",
              ("index", "device_path", "host_path", "reason"), undecodable)
    tsv_write(out / f"gate-e-{profile}-duplicates.tsv",
              ("class", "owners"),
              [(c, ",".join(v)) for c, v in sorted(duplicate_classes.items())])
    apex_overlaps = []
    mtk_apex_overlaps = []
    mtk_paths = {
        "/system_ext/framework/mediatek-common.jar",
        "/system_ext/framework/mediatek-ims-base.jar",
    }
    for cls, providers in sorted(duplicate_classes.items()):
        has_apex = any(p.startswith("/apex/") for p in providers)
        has_non_apex = any(not p.startswith("/apex/") for p in providers)
        if not (has_apex and has_non_apex):
            continue
        row = (cls, ",".join(providers))
        apex_overlaps.append(row)
        if any(p in mtk_paths for p in providers):
            mtk_apex_overlaps.append(row)
    tsv_write(
        out / f"gate-e-{profile}-apex-overlaps.tsv",
        ("class", "providers"),
        apex_overlaps,
    )
    tsv_write(
        out / f"gate-e-{profile}-mtk-apex-overlaps.tsv",
        ("class", "providers"),
        mtk_apex_overlaps,
    )
    tsv_write(out / f"gate-e-{profile}-apex-fragments.tsv",
              ("module", "device_path", "fragment"), apex_fragment_rows)

    changed_winners = []
    if control_owners is not None:
        for cls, winner in sorted(owners.items()):
            old = control_owners.get(cls)
            if old is not None and old != winner:
                changed_winners.append((cls, old, winner))
    tsv_write(
        out / f"gate-e-{profile}-changed-winners.tsv",
        ("class", "control_winner", "candidate_winner"),
        changed_winners,
    )

    member_state = "NOT_APPLICABLE"
    if profile == "c2":
        if linkage_evidence is None or not linkage_evidence.is_dir():
            member_state = "UNKNOWN_LINKAGE_EVIDENCE_MISSING"
        else:
            linkage = linkage_evidence / "runtime-linkage.txt"
            classification = linkage_evidence.parent / "agentpremain-classification.txt"
            if not linkage.is_file():
                member_state = "UNKNOWN_LINKAGE_SUMMARY_MISSING"
            elif (
                classification.is_file()
                and "N1I_C2_AGENTPREMAIN_CLASSIFICATION=PASS_EXACT_DORMANT_NON_ANDROID_DEBUG_AGENT"
                    in classification.read_text(encoding="utf-8", errors="replace")
                and "N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT=FAIL_UNRESOLVED_MEMBERS count=8"
                    in linkage.read_text(encoding="utf-8", errors="replace")
            ):
                member_state = "PASS_ONLY_DORMANT_AGENTPREMAIN_8"
            elif "N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT=PASS_ALL_RESOLVED" in linkage.read_text(
                encoding="utf-8", errors="replace"
            ):
                member_state = "PASS_ALL_RESOLVED"
            else:
                # Gate F can prove that the package is boot-reachable/persistent,
                # but the current member resolver does not prove that the exact
                # failing callsite executes before boot completion.
                member_state = "FUNCTIONAL_RISK_MEMBER_FAILURE"

    updatable = []
    for p in (
        system_root / "etc/updatable-bcp-packages.txt",
        system_root / "etc/classpaths/updatable-bcp-packages.txt",
    ):
        if p.is_file():
            updatable += [
                line.strip() for line in p.read_text(errors="replace").splitlines()
                if line.strip() and not line.startswith("#")
            ]
    (out / f"gate-e-{profile}-updatable-bcp-packages.txt").write_text(
        "\n".join(updatable) + ("\n" if updatable else ""), encoding="utf-8"
    )

    common = "/system_ext/framework/mediatek-common.jar"
    imsbase = "/system_ext/framework/mediatek-ims-base.jar"
    env_write(out / f"gate-e-{profile}.env", {
        f"N1I_D0_GATE_E_{profile.upper()}_BOOT_JAR_COUNT": len(ordered),
        f"N1I_D0_GATE_E_{profile.upper()}_MISSING_RUNTIME_COUNT": len(missing),
        f"N1I_D0_GATE_E_{profile.upper()}_SYSTEMSERVER_JAR_COUNT": len(systemserver),
        f"N1I_D0_GATE_E_{profile.upper()}_SYSTEMSERVER_MISSING_COUNT": len(systemserver_missing),
        f"N1I_D0_GATE_E_{profile.upper()}_MTK_SHARED_LIBRARY_DECL_COUNT": len(mtk_shared),
        f"N1I_D0_GATE_E_{profile.upper()}_UNDECODABLE_COUNT": len(undecodable),
        f"N1I_D0_GATE_E_{profile.upper()}_DUPLICATE_CLASS_COUNT": len(duplicate_classes),
        f"N1I_D0_GATE_E_{profile.upper()}_CHANGED_WINNER_COUNT": len(changed_winners),
        f"N1I_D0_GATE_E_{profile.upper()}_MEMBER_STATE": member_state,
        f"N1I_D0_GATE_E_{profile.upper()}_BOOT_MEMBER_EXECUTION_PROVEN": "NO",
        f"N1I_D0_GATE_E_{profile.upper()}_MTK_COMMON_INDEX": ordered.index(common) if common in ordered else "ABSENT",
        f"N1I_D0_GATE_E_{profile.upper()}_MTK_IMS_BASE_INDEX": ordered.index(imsbase) if imsbase in ordered else "ABSENT",
        f"N1I_D0_GATE_E_{profile.upper()}_UPDATABLE_BCP_PACKAGE_COUNT": len(updatable),
        f"N1I_D0_GATE_E_{profile.upper()}_APEX_OVERLAP_COUNT": len(apex_overlaps),
        f"N1I_D0_GATE_E_{profile.upper()}_MTK_APEX_OVERLAP_COUNT": len(mtk_apex_overlaps),
    })
    if missing or systemserver_missing:
        return (
            Result(
                "E", profile, "BOOT_FATAL",
                "RUNTIME_CLASSPATH_PATH_MISSING="
                f"boot:{len(missing)}:systemserver:{len(systemserver_missing)}",
            ),
            owners,
        )
    if undecodable:
        return (
            Result("E", profile, "UNKNOWN",
                   f"BOOT_JAR_CLASS_INVENTORY_UNDECODABLE={len(undecodable)}"),
            owners,
        )
    if changed_winners:
        return (
            Result(
                "E", profile, "FUNCTIONAL_RISK",
                f"BOOTCLASSPATH_WINNER_CHANGED_UNPROVEN_BOOT_USE={len(changed_winners)}",
            ),
            owners,
        )
    if mtk_apex_overlaps:
        return (
            Result(
                "E", profile, "FUNCTIONAL_RISK",
                f"MTK_APEX_CLASS_OVERLAP_UNPROVEN_BOOT_USE={len(mtk_apex_overlaps)}",
            ),
            owners,
        )
    if member_state.startswith("UNKNOWN_"):
        return Result("E", profile, "UNKNOWN", member_state), owners
    # No member-level BOOT_FATAL is emitted without exact boot-callsite
    # execution evidence. Current B2 linkage output does not provide that.
    if profile == "n1f":
        return (
            Result(
                "E", profile, "PASS",
                f"KNOWN_GOOD_CONTROL boot_jars={len(ordered)} "
                f"baseline_duplicates={len(duplicate_classes)}",
            ),
            owners,
        )
    if duplicate_classes or member_state.startswith("FUNCTIONAL_RISK"):
        return (
            Result(
                "E", profile, "FUNCTIONAL_RISK",
                f"stable_duplicates={len(duplicate_classes)} member={member_state}",
            ),
            owners,
        )
    return Result("E", profile, "PASS", f"BOOT_JARS={len(ordered)} member={member_state}"), owners


def gate_f(system_root: Path, aapt2: str, out: Path) -> Result:
    ims = find_ims_apk(system_root)
    if ims is None:
        return Result("F", "c2", "UNKNOWN", "IMS_APK_NOT_UNIQUELY_PRESENT")
    try:
        summary = manifest_summary(aapt2, ims)
    except D0Error as exc:
        return Result("F", "c2", "UNKNOWN", str(exc))
    components = summary.pop("components")
    persistent = str(summary.get("persistent", "")).lower() in ("true", "0xffffffff", "1")
    direct = str(summary.get("direct_boot_aware", "")).lower() in ("true", "0xffffffff", "1")
    early_components = []
    for c in components:
        line = json.dumps(c, sort_keys=True)
        if any(token in line for token in (
            "LOCKED_BOOT_COMPLETED", "BOOT_COMPLETED", "BIND_IMS_SERVICE",
            "android.intent.action.PRE_BOOT_COMPLETED",
        )):
            early_components.append(c)
    boot_reachable = direct or bool(early_components)
    # Static manifest evidence proves boot-time execution only for a persistent
    # application. directBootAware, BOOT_COMPLETED and BIND_IMS_SERVICE make
    # boot execution reachable, not inevitable.
    boot_proven = persistent
    (out / "gate-f-c2-manifest.json").write_text(
        json.dumps({**summary, "components": components}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    env_write(out / "gate-f-c2.env", {
        "N1I_D0_GATE_F_PACKAGE": summary.get("package", ""),
        "N1I_D0_GATE_F_SHARED_UID": summary.get("shared_uid", ""),
        "N1I_D0_GATE_F_SHARED_UID_MAX_SDK": summary.get("shared_uid_max", ""),
        "N1I_D0_GATE_F_MIN_SDK": summary.get("min_sdk", ""),
        "N1I_D0_GATE_F_TARGET_SDK": summary.get("target_sdk", ""),
        "N1I_D0_GATE_F_PERSISTENT": summary.get("persistent", ""),
        "N1I_D0_GATE_F_DIRECT_BOOT_AWARE": summary.get("direct_boot_aware", ""),
        "N1I_D0_GATE_F_EARLY_COMPONENT_COUNT": len(early_components),
        "N1I_D0_GATE_F_BOOT_EXECUTION_PROVEN": "YES" if boot_proven else "NO",
        "N1I_D0_GATE_F_BOOT_EXECUTION_REACHABLE": "YES" if boot_reachable else "NO",
        "N1I_D0_GATE_F_USES_LIBRARY": ",".join(summary.get("uses_library", [])) or "NONE",
        "N1I_D0_GATE_F_USES_LIBRARY_DETAILS": ",".join(
            summary.get("uses_library_details", [])
        ) or "NONE",
        "N1I_D0_GATE_F_USES_NATIVE_LIBRARY": ",".join(summary.get("uses_native_library", [])) or "NONE",
        "N1I_D0_GATE_F_USES_NATIVE_LIBRARY_DETAILS": ",".join(
            summary.get("uses_native_library_details", [])
        ) or "NONE",
    })
    return Result("F", "c2", "PASS", f"BOOT_EXECUTION_PROVEN={'YES' if boot_proven else 'NO'}")


def inventory(root: Path) -> dict[str, tuple[int, str]]:
    out = {}
    if not root.is_dir():
        return out
    interesting = (
        "/etc/selinux/",
        "/etc/permissions/",
        "/etc/sysconfig/",
        "/etc/init/",
        "/framework/",
        "/priv-app/",
        "/app/",
        "/apex/",
        "/overlay/",
        "/lib64/",
    )
    exact_names = {
        "/build.prop",
        "/etc/build.prop",
        "/etc/prop.default",
    }
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        rel = "/" + str(p.relative_to(root))
        if rel in exact_names or any(x in rel for x in interesting):
            out[rel] = (p.stat().st_size, sha256(p))
    return out


def gate_b0(
    n1f: Path,
    c1: Path | None,
    c2: Path,
    repo: Path,
    out: Path,
) -> Result:
    profiles = {"n1f": inventory(n1f), "c2": inventory(c2)}
    if c1 and c1.is_dir():
        profiles["c1"] = inventory(c1)
    rows = []
    for left, right in (("n1f", "c1"), ("n1f", "c2"), ("c1", "c2")):
        if left not in profiles or right not in profiles:
            rows.append((left, right, "UNKNOWN", "-", "-", "binary_control_missing"))
            continue
        paths = sorted(set(profiles[left]) | set(profiles[right]))
        for p in paths:
            lv, rv = profiles[left].get(p), profiles[right].get(p)
            if lv == rv:
                continue
            status = "ADDED" if lv is None else "REMOVED" if rv is None else "CHANGED"
            rows.append((left, right, status, p, lv[1] if lv else "-", rv[1] if rv else "-"))
    tsv_write(out / "d0-b0-runtime-delta.tsv",
              ("left", "right", "status", "path", "left_sha256", "right_sha256"), rows)

    c1_driver = (
        repo / "build/titan2/run-n1i-c1-cellular-isolation.sh"
    ).read_text(encoding="utf-8", errors="replace")
    c2_materializer = (
        repo / "build/titan2/materialize-n1i-c2-cellular-mvp-stock.py"
    ).read_text(encoding="utf-8", errors="replace")
    patch_name = (
        "0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch"
    )
    c1_has = patch_name in c1_driver or "TelephonyMetrics.java" in c1_driver
    c2_has = (
        patch_name in c2_materializer
        and '"M004"' in c2_materializer
        and '"APPLY_PATCH"' in c2_materializer
        and "TelephonyMetrics.java" in c2_materializer
    )
    scope = (
        "COMMON_C1_C2" if c1_has and c2_has
        else "C1_ONLY" if c1_has
        else "C2_ONLY" if c2_has
        else "ABSENT"
    )
    env_write(out / "D0_B0_SOURCE_DELTA.env", {
        "N1I_D0_B0_TELEPHONYMETRICS_SCOPE": scope,
        "N1I_D0_B0_C1_BINARY_CONTROL": (
            "AVAILABLE" if c1 and c1.is_dir()
            else "UNKNOWN_NOT_RETAINED"
        ),
    })
    return Result(
        "B0", "all", "PASS",
        f"DELTA_ROWS={len(rows)} TELEPHONYMETRICS={scope}",
    )


def verdict_for(results: list[Result]) -> str:
    lookup = {(r.gate, r.profile): r for r in results}
    defect = False
    not_closed = False
    for gate in CRITICAL_GATES:
        c2 = lookup.get((gate, "c2"))
        n1f = lookup.get((gate, "n1f"))
        if c2 is None or n1f is None:
            not_closed = True
            continue
        if c2.state == "BOOT_FATAL" and n1f.state == "PASS":
            defect = True
        if c2.state == "UNKNOWN" or n1f.state != "PASS":
            not_closed = True
    if not_closed:
        return "NOT_CLOSED"
    if defect:
        return "DEFECT_FOUND"
    return "NO_FATAL_DEFECT_FOUND"


def privapp_severity(
    enforcement: str,
    missing: set[str],
    shared_uid: str,
) -> tuple[str, str]:
    if enforcement in ("CONFLICT", "UNSPECIFIED"):
        return "UNKNOWN", f"PRIVAPP_ENFORCEMENT={enforcement} missing={len(missing)}"
    if enforcement == "enforce" and missing:
        return "BOOT_FATAL", f"SYSTEM_EXT_PRIVAPP_MISSING={len(missing)}"
    if shared_uid != "android.uid.phone":
        return "BOOT_FATAL", f"SHARED_UID={shared_uid or 'MISSING'}"
    if missing:
        return "FUNCTIONAL_RISK", f"ALLOWLIST_MISSING={len(missing)} mode={enforcement}"
    return "PASS", f"ALLOWLIST_COVERED mode={enforcement}"


def summarize(results: list[Result], out: Path) -> None:
    tsv_write(out / "D0_GATE_RESULTS.tsv", ("gate", "profile", "state", "detail"),
              [r.row() for r in results])
    lookup = {(r.gate, r.profile): r for r in results}
    verdict = verdict_for(results)

    critical_candidate_pass = all(
        lookup.get((gate, "c2")) is not None
        and lookup[(gate, "c2")].state == "PASS"
        for gate in CRITICAL_GATES
    )
    f = lookup.get(("F", "c2"))
    pre_native_ready = (
        verdict == "NO_FATAL_DEFECT_FOUND"
        and critical_candidate_pass
        and f is not None and f.state == "PASS"
    )
    env_write(out / "N1I_D0_HOST_SUMMARY.env", {
        "N1I_D0_0H": verdict,
        "N1I_D0_C1J_PRE_NATIVE_READY": "YES" if pre_native_ready else "NO",
        "N1I_D0_C1J_COMPOSITION_READY": "NO_PENDING_GATE_G",
        "N1I_D0_NEXT_BUILD_AUTHORIZED": "NO",
        "N1I_D0_DEVICE_CONTACT": "NONE",
        "N1I_D0_REBOOT": "NONE",
        "N1I_D0_FLASH": "NONE",
    })


def selftest() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        p = root / "property_contexts"
        p.write_text("persist.vendor.foo u:object_r:foo_prop:s0 exact string\n")
        assert parse_contexts(p)[0][0] == "persist.vendor.foo"

        roots = {
            "system": root / "s",
            "system_ext": root / "se",
            "product": root / "p",
        }
        for r in roots.values():
            (r / "etc/permissions").mkdir(parents=True)
        x = roots["system_ext"] / "etc/permissions/x.xml"
        x.write_text(
            '<permissions><privapp-permissions package="x">'
            '<permission name="p"/>'
            '</privapp-permissions></permissions>'
        )
        allow, rows = parse_privapp_files(roots)
        assert allow[("system_ext", "x")] == {"p"}
        assert rows

        vendor = root / "vendor"
        (vendor / "etc/selinux").mkdir(parents=True)
        pre = vendor / "etc/selinux/precompiled_sepolicy"
        pre.write_text("fixture")
        system = root / "system"
        for rel, value in (
            ("etc/selinux/plat_sepolicy_and_mapping.sha256", "a"),
            ("system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256", "b"),
            ("product/etc/selinux/product_sepolicy_and_mapping.sha256", "c"),
        ):
            f = system / rel
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(value + "\n")
        Path(str(pre) + ".plat_sepolicy_and_mapping.sha256").write_text("a\n")
        Path(str(pre) + ".system_ext_sepolicy_and_mapping.sha256").write_text("b\n")
        Path(str(pre) + ".product_sepolicy_and_mapping.sha256").write_text("c\n")
        decision, _rows = a0_decision(system, vendor, None)
        assert decision == "PRECOMPILED_MATCH"
        Path(str(pre) + ".product_sepolicy_and_mapping.sha256").write_text("x\n")
        decision, _rows = a0_decision(system, vendor, None)
        assert decision == "SPLIT_COMPILE_REQUIRED"

        base = [
            Result(g, "n1f", "PASS", "-")
            for g in CRITICAL_GATES
        ]
        c2_pass = [
            Result(g, "c2", "PASS", "-")
            for g in CRITICAL_GATES
        ]
        assert verdict_for(base + c2_pass) == "NO_FATAL_DEFECT_FOUND"
        fatal = [
            Result(g, "c2", "BOOT_FATAL" if g == "D" else "PASS", "-")
            for g in CRITICAL_GATES
        ]
        assert verdict_for(base + fatal) == "DEFECT_FOUND"
        bad_control = [
            Result(g, "n1f", "UNKNOWN" if g == "D" else "PASS", "-")
            for g in CRITICAL_GATES
        ]
        assert verdict_for(bad_control + fatal) == "NOT_CLOSED"
        mixed = base + [
            Result("A", "c2", "UNKNOWN", "-"),
            Result("B", "c2", "PASS", "-"),
            Result("D", "c2", "BOOT_FATAL", "-"),
            Result("E", "c2", "PASS", "-"),
        ]
        assert verdict_for(mixed) == "NOT_CLOSED"

        fatal_a = base + [
            Result("A", "c2", "BOOT_FATAL", "-"),
            Result("B", "c2", "PASS", "-"),
            Result("D", "c2", "PASS", "-"),
            Result("E", "c2", "PASS", "-"),
            Result("F", "c2", "PASS", "-"),
        ]
        assert verdict_for(fatal_a) == "DEFECT_FOUND"

        assert privapp_severity(
            "enforce", {"android.permission.READ_PRIVILEGED_PHONE_STATE"},
            "android.uid.phone",
        )[0] == "BOOT_FATAL"
        assert privapp_severity(
            "log", {"android.permission.READ_PRIVILEGED_PHONE_STATE"},
            "android.uid.phone",
        )[0] == "FUNCTIONAL_RISK"
        assert privapp_severity(
            "enforce", set(), "android.uid.phone",
        )[0] == "PASS"

        mac_root = root / "mac-system"
        (mac_root / "etc/selinux").mkdir(parents=True)
        cert_bytes = b"fixture-platform-cert"
        cert_digest = hashlib.sha256(cert_bytes).hexdigest()
        (mac_root / "etc/selinux/plat_mac_permissions.xml").write_text(
            '<policy><signer signature="' + cert_bytes.hex() + '">'
            '<seinfo value="platform"/>'
            '</signer></policy>'
        )
        _rows, mac_state, seinfo = mac_permissions_seinfo(
            {"system": mac_root},
            package="com.mediatek.ims",
            cert_sha256=cert_digest,
        )
        assert mac_state == "PASS_CERT_BOUND_SEINFO"
        assert seinfo == "platform"

        stock_layout = {
            "system": root / "stock-system",
            "system_ext": root / "stock-system-ext",
            "product": root / "stock-product",
        }
        for p in stock_layout.values():
            p.mkdir()
        stock_common = stock_layout["system_ext"] / "framework/mediatek-common.jar"
        stock_common.parent.mkdir(parents=True)
        stock_common.write_bytes(b"fixture")
        assert map_device_jar(
            stock_layout["system"],
            None,
            "/system_ext/framework/mediatek-common.jar",
            stock_layout,
        ) == stock_common

        invalid = root / "invalid.jar"
        invalid.write_text("not a dex container")
        class _Static:
            class DexFile:
                pass
            @staticmethod
            def load_container(_path):
                raise ValueError("fixture")
        classes, state = class_set(_Static, invalid)
        assert not classes
        assert state.startswith("UNDECODABLE:")

    print("N1I_D0_HOST_AUDIT_SELFTEST=PASS")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=Path)
    ap.add_argument("--android-root", type=Path)
    ap.add_argument("--n1f-root", type=Path)
    ap.add_argument("--c1-root", type=Path)
    ap.add_argument("--c2-root", type=Path)
    ap.add_argument("--n1f-apex-root", type=Path)
    ap.add_argument("--c2-apex-root", type=Path)
    ap.add_argument("--stock-apex-root", type=Path)
    ap.add_argument("--c2-linkage-evidence", type=Path)
    ap.add_argument("--stock-system", type=Path)
    ap.add_argument("--stock-system-ext", type=Path)
    ap.add_argument("--stock-product", type=Path)
    ap.add_argument("--stock-vendor", type=Path)
    ap.add_argument("--stock-odm", type=Path)
    ap.add_argument("--stock-odm-unpinned", action="store_true")
    ap.add_argument("--secilc")
    ap.add_argument("--property-info-checker")
    ap.add_argument("--aapt2")
    ap.add_argument("--apksigner")
    ap.add_argument("--out", type=Path)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    required = (
        args.repo, args.android_root, args.n1f_root, args.c2_root,
        args.stock_system, args.stock_system_ext, args.stock_product,
        args.stock_vendor, args.out,
    )
    if (
        any(x is None for x in required)
        or not args.secilc
        or not args.aapt2
        or not args.apksigner
    ):
        ap.error("all roots/tools/out are required except --c1-root/--stock-odm")

    repo = args.repo.resolve()
    out = args.out.resolve()
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f"N1I_D0_HOST_AUDIT=FAIL output_not_empty={out}")
    out.mkdir(parents=True, exist_ok=True)

    # Pin the B2 analyzers to the reviewed commit content.
    for rel in ("build/titan2/n1i-b2-members.py", "build/titan2/n1i-b2-native.py"):
        if git_blob(repo, B2_PIN, rel) != current_blob(repo, rel):
            raise SystemExit(f"N1I_D0_HOST_AUDIT=FAIL b2_pin_drift={rel}")

    n1f = args.n1f_root.resolve()
    c2 = args.c2_root.resolve()
    c1 = args.c1_root.resolve() if args.c1_root and args.c1_root.is_dir() else None
    stock_roots = {
        "system": args.stock_system.resolve(),
        "system_ext": args.stock_system_ext.resolve(),
        "product": args.stock_product.resolve(),
    }
    vendor = args.stock_vendor.resolve()
    odm = args.stock_odm.resolve() if args.stock_odm and args.stock_odm.is_dir() else None

    results: list[Result] = [gate_b0(n1f, c1, c2, repo, out)]

    a_inputs: dict[str, list[Path]] = {}
    a_policies: dict[str, Path | None] = {}
    for profile, root in (("n1f", n1f), ("c2", c2)):
        result, inputs, policy = gate_a(
            profile, root, vendor, odm, Path(args.secilc).resolve(),
            args.android_root.resolve(), out
        )
        results.append(result)
        a_inputs[profile] = inputs
        a_policies[profile] = policy

    n1f_roots = partition_roots(n1f)
    c2_roots = partition_roots(c2)
    property_checker = (
        Path(args.property_info_checker).resolve()
        if args.property_info_checker
        else None
    )
    results.append(gate_b(
        "n1f", n1f_roots, vendor, odm,
        next(r.state for r in results if r.gate == "A" and r.profile == "n1f"),
        a_inputs["n1f"], a_policies["n1f"], property_checker, out,
    ))
    results.append(gate_b(
        "c2", c2_roots, vendor, odm,
        next(r.state for r in results if r.gate == "A" and r.profile == "c2"),
        a_inputs["c2"], a_policies["c2"], property_checker, out,
    ))
    results.append(gate_c("n1f", n1f_roots, vendor, odm, out))
    results.append(gate_c("c2", c2_roots, vendor, odm, out))
    results.append(
        gate_d(
            "n1f", n1f_roots, vendor, odm, stock_roots,
            args.aapt2, args.apksigner, out,
        )
    )
    results.append(
        gate_d(
            "c2", c2_roots, vendor, odm, stock_roots,
            args.aapt2, args.apksigner, out,
        )
    )

    if args.stock_odm_unpinned:
        affected = {"A", "B", "C", "D"}
        results = [
            Result(
                r.gate,
                r.profile,
                "UNKNOWN",
                "STOCK_ODM_PRESENT_BUT_UNPINNED",
            )
            if r.gate in affected and r.profile in ("n1f", "c2")
            else r
            for r in results
        ]

    results.append(Result("F", "n1f", "NOT_APPLICABLE", "NO_OEM_IMS_IN_N1F_CONTROL"))
    f_c2 = gate_f(c2, args.aapt2, out)
    results.append(f_c2)
    boot_proven = "BOOT_EXECUTION_PROVEN=YES" in f_c2.detail

    stock_e, _stock_owners = gate_e(
        "stock",
        stock_roots["system"],
        args.stock_apex_root.resolve() if args.stock_apex_root else None,
        repo,
        out,
        runtime_roots=stock_roots,
    )
    results.append(stock_e)

    n1f_e, n1f_owners = gate_e(
        "n1f",
        n1f,
        args.n1f_apex_root.resolve() if args.n1f_apex_root else None,
        repo,
        out,
    )
    results.append(n1f_e)
    c2_e, _c2_owners = gate_e(
        "c2",
        c2,
        args.c2_apex_root.resolve() if args.c2_apex_root else None,
        repo,
        out,
        control_owners=n1f_owners if n1f_e.state == "PASS" else None,
        boot_execution_proven=boot_proven,
        linkage_evidence=(
            args.c2_linkage_evidence.resolve()
            if args.c2_linkage_evidence
            else None
        ),
    )
    results.append(c2_e)

    summarize(results, out)
    print((out / "N1I_D0_HOST_SUMMARY.env").read_text(), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
