#!/usr/bin/env python3
"""R1-R0R2 superseding correction layer for SableOS release preflight.

R0R2 preserves the read-only R1-R0 policy while correcting the two parser defects
found by the first physical-host run and the recursive monkeypatch defect found in
R0R1. It binds the exact R1-R0 base script, captures the original base functions
before patching, installs closure-based adapters only for the duration of one
``main()`` call, and restores all patched globals in ``finally``.

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


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


def load_bound_base(
    path: Path = BASE_SCRIPT,
    expected_sha256: str = BASE_SCRIPT_SHA256,
    module_name: str = "sable_r1_r0_base_r0r2",
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
        value = match.group(1).strip()
        for product in re.split(r"[|,]", value):
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


def make_find_build_properties_adapter(
    *,
    base: ModuleType,
    original_find: Callable[[zipfile.ZipFile], tuple[dict[str, str], list[str]]],
) -> Callable[[zipfile.ZipFile], tuple[dict[str, str], list[str]]]:
    """Return a non-recursive adapter bound to the original base function."""

    expected_device = str(base.EXPECTED_DEVICE)

    def corrected(zf: zipfile.ZipFile) -> tuple[dict[str, str], list[str]]:
        # Crucially, call the captured pre-patch function, never
        # base.find_build_properties after monkeypatching.
        props, sources = original_find(zf)
        props = dict(props)
        sources = list(sources)

        android_info = _read_small_text(zf, "OTA/android-info.txt")
        if android_info is not None:
            products = parse_android_info_products(android_info)
            if products:
                chosen = expected_device if expected_device in products else products[0]
                props["ro.product.device"] = chosen
                marker = "OTA/android-info.txt(product)"
                if marker not in sources:
                    sources.append(marker)
                return props, sources

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
        # Base.main uses its module-global __file__ when sealing script identity.
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
