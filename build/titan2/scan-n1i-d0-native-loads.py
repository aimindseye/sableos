#!/usr/bin/env python3
"""Scan APK/JAR DEX containers for native load sites using the pinned N1I-B2 logic.

This does not perform ELF closure. It closes the specific D0 harness gap that
n1i-b2-native.py accepts only one APK root: framework JAR load sites are scanned
with the exact same decoder and backwards constant-propagation implementation.
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
STATIC = ROOT / "build/titan2/n1i_static.py"
NATIVE = ROOT / "build/titan2/n1i-b2-native.py"


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot_load={path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def scan(paths: list[Path], out: Path) -> tuple[int, int]:
    static = load_module(STATIC, "n1i_d0_static")
    native = load_module(NATIVE, "n1i_d0_native")

    rows: list[list[str]] = []
    constants = 0
    dynamic = 0

    for path in paths:
        if not path.is_file():
            raise RuntimeError(f"input_missing={path}")
        container = static.load_container(path)
        if not container.dexes:
            raise RuntimeError(f"no_dex={path}")
        for entry, dex in container.dexes:
            static.oracle_check_dex(dex)
            for site in native.load_sites(dex, entry):
                if site.status == "CONSTANT":
                    constants += 1
                else:
                    dynamic += 1
                rows.append(
                    [
                        str(path),
                        entry,
                        site.caller,
                        site.site,
                        site.api,
                        site.status,
                        site.value,
                        site.reason,
                        site.chain or "-",
                    ]
                )

    out.mkdir(parents=True)
    with (out / "LOAD_SITES.tsv").open("w", encoding="utf-8", newline="") as fp:
        writer = csv.writer(fp, delimiter="\t", lineterminator="\n")
        writer.writerow(
            [
                "container",
                "dex",
                "caller",
                "site",
                "api",
                "status",
                "value",
                "reason",
                "proof_chain",
            ]
        )
        writer.writerows(rows)

    with (out / "SUMMARY.env").open("w", encoding="utf-8") as fp:
        fp.write(f"N1I_D0_NATIVE_LOAD_SCAN_CONTAINER_COUNT={len(paths)}\n")
        fp.write(f"N1I_D0_NATIVE_LOAD_SCAN_CONSTANT={constants}\n")
        fp.write(f"N1I_D0_NATIVE_LOAD_SCAN_DYNAMIC={dynamic}\n")
        fp.write("N1I_D0_NATIVE_LOAD_SCAN_B2_LOGIC=YES\n")

    return constants, dynamic


def selftest() -> int:
    native = load_module(NATIVE, "n1i_d0_native_selftest")
    assert callable(native.load_sites)
    assert native.TOOL_VERSION == "1.0.1"
    print("N1I_D0_NATIVE_LOAD_SCAN_SELFTEST=PASS")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--container", type=Path, action="append", default=[])
    ap.add_argument("--out", type=Path)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if not args.container or args.out is None:
        ap.error("--container and --out are required")
    if args.out.exists():
        raise RuntimeError(f"output_exists={args.out}")

    constants, dynamic = scan(
        [path.resolve() for path in args.container],
        args.out.resolve(),
    )
    print(
        "N1I_D0_NATIVE_LOAD_SCAN=PASS "
        f"constant={constants} dynamic={dynamic}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"N1I_D0_NATIVE_LOAD_SCAN=FAIL reason={exc}", file=sys.stderr)
        raise SystemExit(2)
