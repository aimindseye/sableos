#!/usr/bin/env python3
"""R1-R0R1 correction layer for the SableOS release-engineering preflight.

This module deliberately reuses the already-audited R1-R0 preflight and changes
only two parsing semantics proven defective by the first physical-host run:

1. accept indentation around the upstream ``CN=GrapheneOS`` assignment;
2. resolve target product identity from ``OTA/android-info.txt`` first, with a
   partition-property fallback, instead of trusting generic SYSTEM/build.prop.

It remains read-only. No build, signing, key generation, OTA generation, device
contact, reboot, fastboot, flash, or wipe action is added here.
"""

from __future__ import annotations

import hashlib
import importlib.util
import re
import sys
import zipfile
from pathlib import Path

BASE_SCRIPT = Path(__file__).with_name("SABLE_R1_R0_RELEASE_PREFLIGHT.py")
BASE_SCRIPT_SHA256 = "cf94b3a37529b63f6e72ebd5899cfe34d2a7e232f33a99396832773926a4dbe7"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_base():
    if not BASE_SCRIPT.is_file():
        raise RuntimeError(f"base preflight missing: {BASE_SCRIPT}")
    actual = sha256_file(BASE_SCRIPT)
    if actual != BASE_SCRIPT_SHA256:
        raise RuntimeError(
            "base preflight binding mismatch: "
            f"expected={BASE_SCRIPT_SHA256} actual={actual}"
        )

    spec = importlib.util.spec_from_file_location("sable_r1_r0_base", BASE_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load bound R1-R0 base preflight")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
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
        value = match.group(1).strip()
        for product in re.split(r"[|,]", value):
            product = product.strip()
            if product and product not in products:
                products.append(product)
    return tuple(products)


def _read_small_text(zf: zipfile.ZipFile, name: str, max_size: int = 1024 * 1024) -> str | None:
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


def find_build_properties(zf: zipfile.ZipFile) -> tuple[dict[str, str], list[str]]:
    # Start with the bound R1-R0 implementation so build type/tags/fingerprint
    # semantics remain unchanged.
    props, sources = BASE.find_build_properties(zf)

    android_info = _read_small_text(zf, "OTA/android-info.txt")
    if android_info is not None:
        products = parse_android_info_products(android_info)
        if products:
            chosen = BASE.EXPECTED_DEVICE if BASE.EXPECTED_DEVICE in products else products[0]
            props["ro.product.device"] = chosen
            if "OTA/android-info.txt(product)" not in sources:
                sources.append("OTA/android-info.txt(product)")
            return props, sources

    # Fallback only if OTA product metadata is unavailable. Prefer
    # product/vendor/odm partition identity and reject the generic system value.
    preferred = (
        "PRODUCT/build.prop",
        "VENDOR/build.prop",
        "ODM/build.prop",
        "SYSTEM_EXT/build.prop",
        "SYSTEM/system/build.prop",
        "SYSTEM/build.prop",
    )
    for name in preferred:
        text = _read_small_text(zf, name)
        if text is None:
            continue
        candidate = _parse_properties(text).get("ro.product.device")
        if candidate and candidate != "generic":
            props["ro.product.device"] = candidate
            marker = f"{name}(product)"
            if marker not in sources:
                sources.append(marker)
            break
    return props, sources


def main(argv: list[str] | None = None) -> int:
    # Patch only the two defective parsers. The base main continues to own
    # authorization, evidence, blocker policy, bounded ZIP behavior, and exits.
    BASE.parse_key_generator_subject = parse_key_generator_subject
    BASE.find_build_properties = find_build_properties

    # Make the evidence context bind this correction layer rather than the
    # superseded base entrypoint. Both files remain independently bound because
    # this layer refuses to load an unexpected base SHA-256.
    BASE.__file__ = __file__
    return BASE.main(argv)


BASE = load_base()


if __name__ == "__main__":
    raise SystemExit(main())
