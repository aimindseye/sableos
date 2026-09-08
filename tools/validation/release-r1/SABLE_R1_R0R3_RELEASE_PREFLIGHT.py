#!/usr/bin/env python3
"""R1-R0R3 superseding correction layer for SableOS release preflight.

R0R3 preserves the read-only R1-R0 policy and the non-recursive R0R2 patch
lifecycle while correcting target-files device identity using the exact
partition-scoped property contract from the pinned GrapheneOS 2026081300
platform_build source.

No build, signing, key generation, OTA generation, device contact, reboot,
fastboot, flash, slot change, erase, unlock, or wipe action is added here.
"""

from __future__ import annotations

import hashlib
import importlib.util
import re
import sys
import zipfile
from pathlib import Path
from types import ModuleType
from typing import Callable

BASE_SCRIPT = Path(__file__).with_name("SABLE_R1_R0_RELEASE_PREFLIGHT.py")
BASE_SCRIPT_SHA256 = "cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7"

# Exact Android/Graphene target-files partition property contract. The pinned
# GrapheneOS 2026081300 build/make core/sysprop.mk emits
# ro.product.<partition>.device=$(TARGET_DEVICE). Product/ODM/system_ext build
# properties live below etc/; system and vendor are at the partition root.
PARTITION_DEVICE_SOURCES = (
    ("SYSTEM/build.prop", "ro.product.system.device"),
    ("SYSTEM/system/build.prop", "ro.product.system.device"),
    ("VENDOR/build.prop", "ro.product.vendor.device"),
    ("PRODUCT/etc/build.prop", "ro.product.product.device"),
    ("ODM/etc/build.prop", "ro.product.odm.device"),
    ("SYSTEM_EXT/etc/build.prop", "ro.product.system_ext.device"),
)


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


def load_bound_base(
    path: Path = BASE_SCRIPT,
    expected_sha256: str = BASE_SCRIPT_SHA256,
    module_name: str = "sable_r1_r0_base_r0r3",
) -> ModuleType:
    if not path.is_file():
        raise RuntimeError(f"base preflight missing: {path}")
    actual = sha256_file(path)
    if actual != expected_sha256:
        raise RuntimeError(
            "base preflight binding mismatch: "
            f"expected={expected_sha256} actual={actual}"
        )

    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load bound R1-R0 base preflight")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(spec.name, None)
        raise
    return module


def parse_key_generator_subject(path: Path) -> str | None:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        r'''^\s*CN\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s#]+))\s*(?:#.*)?$''',
        text,
        re.M,
    )
    if not match:
        return None
    return next(group.strip() for group in match.groups() if group is not None)


def parse_android_info_products(text: str) -> tuple[str, ...]:
    products: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        match = re.match(r"^require\s+product\s*=\s*(.+?)\s*$", line)
        if not match:
            continue
        for product in re.split(r"[|,]", match.group(1).strip()):
            product = product.strip()
            if product and product not in products:
                products.append(product)
    return tuple(products)


def _read_small_text(
    zf: zipfile.ZipFile,
    name: str,
    max_size: int = 1024 * 1024,
) -> str | None:
    try:
        info = zf.getinfo(name)
    except KeyError:
        return None
    if info.file_size > max_size:
        return None
    return zf.read(name).decode("utf-8", errors="replace")


def _parse_properties(text: str) -> dict[str, str]:
    props: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        props[key.strip()] = value.strip()
    return props


def collect_partition_device_evidence(
    zf: zipfile.ZipFile,
) -> tuple[tuple[str, str, str], ...]:
    evidence: list[tuple[str, str, str]] = []
    for name, key in PARTITION_DEVICE_SOURCES:
        text = _read_small_text(zf, name)
        if text is None:
            continue
        value = _parse_properties(text).get(key, "").strip()
        if value:
            evidence.append((name, key, value))
    return tuple(evidence)


def _conflict_value(values: set[str]) -> str:
    return "CONFLICT[" + ",".join(sorted(values)) + "]"


def resolve_target_device(
    zf: zipfile.ZipFile,
    *,
    expected_device: str,
) -> tuple[str | None, list[str]]:
    """Resolve target device from bounded authoritative target-files metadata.

    Partition-scoped identities are treated as the actual built device identity.
    OTA/android-info product requirements are treated as an allowed-product set
    when present. Conflicting non-generic evidence is surfaced as a synthetic
    value so the bound base gate fails closed at artifact.device.
    """

    markers: list[str] = []
    ota_products: tuple[str, ...] = ()
    android_info = _read_small_text(zf, "OTA/android-info.txt")
    if android_info is not None:
        ota_products = parse_android_info_products(android_info)
        if ota_products:
            markers.append("OTA/android-info.txt(product=" + "|".join(ota_products) + ")")

    evidence = collect_partition_device_evidence(zf)
    partition_values: set[str] = set()
    for name, key, value in evidence:
        markers.append(f"{name}({key}={value})")
        if value != "generic":
            partition_values.add(value)

    if len(partition_values) > 1:
        return _conflict_value(partition_values), markers

    if len(partition_values) == 1:
        device = next(iter(partition_values))
        if ota_products and device not in ota_products:
            return _conflict_value(set(ota_products) | {device}), markers
        return device, markers

    # If partition-scoped evidence is absent, use OTA product constraints only
    # when they identify one product or explicitly include the expected device.
    if ota_products:
        if expected_device in ota_products:
            return expected_device, markers
        if len(ota_products) == 1:
            return ota_products[0], markers
        return _conflict_value(set(ota_products)), markers

    return None, markers


def make_find_build_properties_adapter(
    *,
    base: ModuleType,
    original_find: Callable[[zipfile.ZipFile], tuple[dict[str, str], list[str]]],
) -> Callable[[zipfile.ZipFile], tuple[dict[str, str], list[str]]]:
    """Return a non-recursive adapter bound to the original base function."""

    expected_device = str(base.EXPECTED_DEVICE)

    def corrected(zf: zipfile.ZipFile) -> tuple[dict[str, str], list[str]]:
        # Call only the captured pre-patch function. Never dereference the
        # mutable base.find_build_properties global after installing this adapter.
        props, sources = original_find(zf)
        props = dict(props)
        sources = list(sources)

        device, markers = resolve_target_device(zf, expected_device=expected_device)
        if device is not None:
            # Preserve the bound base policy by changing only the value consumed
            # by its existing artifact.device check.
            props["ro.product.device"] = device
        for marker in markers:
            if marker not in sources:
                sources.append(marker)
        return props, sources

    return corrected


def run_with_base(base: ModuleType, argv: list[str] | None = None) -> int:
    """Run one corrected preflight invocation and restore the base module exactly."""

    original_subject = base.parse_key_generator_subject
    original_find = base.find_build_properties
    original_file = base.__file__

    corrected_find = make_find_build_properties_adapter(
        base=base,
        original_find=original_find,
    )

    try:
        base.parse_key_generator_subject = parse_key_generator_subject
        base.find_build_properties = corrected_find
        base.__file__ = __file__
        return int(base.main(argv))
    finally:
        base.parse_key_generator_subject = original_subject
        base.find_build_properties = original_find
        base.__file__ = original_file


def main(argv: list[str] | None = None) -> int:
    base = load_bound_base()
    return run_with_base(base, argv)


if __name__ == "__main__":
    raise SystemExit(main())
