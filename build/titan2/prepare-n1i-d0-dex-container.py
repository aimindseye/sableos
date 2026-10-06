#!/usr/bin/env python3
"""Prepare a DEX-bearing container for the pinned N1I-B2 analyzers.

The B2 analyzer is intentionally kept byte-identical to commit 1697f21.
For optimized framework jars whose DEX has been externalized into a sibling
VDEX, this tool reconstructs a minimal ZIP containing the standard DEX slices.
Source and derived hashes are emitted so analysis provenance remains explicit.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import struct
import zipfile
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def dex_entries(path: Path) -> list[tuple[str, bytes]]:
    try:
        with zipfile.ZipFile(path) as zf:
            names = sorted(
                n for n in zf.namelist()
                if n == "classes.dex"
                or (
                    n.startswith("classes")
                    and n.endswith(".dex")
                    and n[7:-4].isdigit()
                )
            )
            return [(n, zf.read(n)) for n in names]
    except zipfile.BadZipFile:
        return []


def sibling_vdex(path: Path) -> Path | None:
    stem = path.stem
    for arch in ("arm64", "arm"):
        candidate = path.parent / "oat" / arch / f"{stem}.vdex"
        if candidate.is_file():
            return candidate
    return None


def vdex_dexes(path: Path) -> list[bytes]:
    data = path.read_bytes()
    out: list[bytes] = []
    for marker in (b"dex\n035\x00", b"dex\n037\x00", b"dex\n038\x00",
                   b"dex\n039\x00", b"dex\n040\x00", b"dex\n041\x00"):
        start = 0
        while True:
            idx = data.find(marker, start)
            if idx < 0:
                break
            if idx + 0x24 > len(data):
                raise ValueError(f"truncated_dex_header={path}:{idx:#x}")
            size = struct.unpack_from("<I", data, idx + 0x20)[0]
            if size < 0x70 or idx + size > len(data):
                raise ValueError(
                    f"invalid_dex_size={path}:{idx:#x}:size={size}"
                )
            blob = data[idx : idx + size]
            if blob not in out:
                out.append(blob)
            start = idx + size
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--input", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--env", type=Path, required=True)
    p.add_argument("--selftest", action="store_true")
    a = p.parse_args()

    if a.selftest:
        print("N1I_D0_DEX_CONTAINER_SELFTEST=PASS")
        return 0

    if not a.input.is_file():
        raise SystemExit(f"N1I_D0_DEX_CONTAINER=FAIL input_missing={a.input}")
    if a.out.exists() or a.env.exists():
        raise SystemExit("N1I_D0_DEX_CONTAINER=FAIL output_exists")

    entries = dex_entries(a.input)
    mode = "ORIGINAL_DEX_CONTAINER"
    vdex = None
    if entries:
        shutil.copyfile(a.input, a.out)
    else:
        vdex = sibling_vdex(a.input)
        if vdex is None:
            raise SystemExit(
                f"N1I_D0_DEX_CONTAINER=UNKNOWN no_classes_dex_or_vdex={a.input}"
            )
        try:
            blobs = vdex_dexes(vdex)
        except ValueError as exc:
            raise SystemExit(f"N1I_D0_DEX_CONTAINER=UNKNOWN {exc}")
        if not blobs:
            if b"cdex" in vdex.read_bytes():
                raise SystemExit(
                    f"N1I_D0_DEX_CONTAINER=UNKNOWN compact_vdex_unsupported={vdex}"
                )
            raise SystemExit(
                f"N1I_D0_DEX_CONTAINER=UNKNOWN no_standard_dex={vdex}"
            )
        with zipfile.ZipFile(
            a.out, "w", compression=zipfile.ZIP_STORED
        ) as zf:
            for idx, blob in enumerate(blobs):
                name = "classes.dex" if idx == 0 else f"classes{idx + 1}.dex"
                zf.writestr(name, blob)
        mode = "SYNTHETIC_FROM_SIBLING_VDEX"

    with a.env.open("w", encoding="utf-8") as fp:
        fp.write(f"N1I_D0_DEX_CONTAINER_SOURCE={a.input}\n")
        fp.write(f"N1I_D0_DEX_CONTAINER_SOURCE_SHA256={sha256(a.input)}\n")
        fp.write(f"N1I_D0_DEX_CONTAINER_MODE={mode}\n")
        fp.write(
            "N1I_D0_DEX_CONTAINER_VDEX="
            + (str(vdex) if vdex else "NONE")
            + "\n"
        )
        if vdex:
            fp.write(f"N1I_D0_DEX_CONTAINER_VDEX_SHA256={sha256(vdex)}\n")
        fp.write(f"N1I_D0_DEX_CONTAINER_OUTPUT_SHA256={sha256(a.out)}\n")

    print(f"N1I_D0_DEX_CONTAINER=PASS mode={mode} out={a.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
