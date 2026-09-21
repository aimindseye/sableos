#!/usr/bin/env python3
from __future__ import annotations

import argparse
import tempfile
from pathlib import Path

EXPECTED_DIRS = {
    "r8",
    "r8/prebuilt",
}

EXPECTED_FILES = {
    "r8/Android.bp",
    "r8/r8-product.mk",
    "r8/manifest.tsv",
    "r8/SHA256SUMS.txt",
    "r8/SABLEOS_SOURCE_COMMIT.txt",
    "r8/prebuilt/SableCalculator.apk",
    "r8/prebuilt/SableSudoku.apk",
    "r8/prebuilt/SableMinesweeper.apk",
    "r8/prebuilt/Sable2048.apk",
    "r8/prebuilt/SableMedia.apk",
    "r8/prebuilt/SableReader.apk",
    "r8/prebuilt/SableHub.apk",
    "r8/prebuilt/SableMail.apk",
    "r8/prebuilt/SableWeather.apk",
}


def inspect(root: Path) -> tuple[set[str], set[str], list[str]]:
    actual_dirs: set[str] = set()
    actual_files: set[str] = set()
    special: list[str] = []

    if not root.is_dir() or root.is_symlink():
        special.append(f"{root}:invalid-root")
        return actual_dirs, actual_files, special

    for path in root.rglob("*"):
        rel = path.relative_to(root).as_posix()
        if path.is_symlink():
            special.append(f"{rel}:symlink")
        elif path.is_dir():
            actual_dirs.add(rel)
        elif path.is_file():
            actual_files.add(rel)
        else:
            special.append(f"{rel}:special")

    return actual_dirs, actual_files, special


def validate(root: Path) -> tuple[bool, str]:
    actual_dirs, actual_files, special = inspect(root)

    missing_dirs = EXPECTED_DIRS - actual_dirs
    extra_dirs = actual_dirs - EXPECTED_DIRS
    missing_files = EXPECTED_FILES - actual_files
    extra_files = actual_files - EXPECTED_FILES

    ok = not (missing_dirs or extra_dirs or missing_files or extra_files or special)
    detail = (
        f"missing_dirs={sorted(missing_dirs)!r} "
        f"extra_dirs={sorted(extra_dirs)!r} "
        f"missing_files={sorted(missing_files)!r} "
        f"extra_files={sorted(extra_files)!r} "
        f"special={sorted(special)!r}"
    )
    return ok, detail


def materialize_canonical(root: Path) -> None:
    for rel in EXPECTED_DIRS:
        (root / rel).mkdir(parents=True, exist_ok=True)
    for rel in EXPECTED_FILES:
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"canonical-test\n")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="sable-r8-vendor-inventory-") as td:
        root = Path(td) / "vendor" / "sable"
        materialize_canonical(root)

        ok, detail = validate(root)
        if not ok:
            raise SystemExit(f"R8_VENDOR_SABLE_SELF_TEST_CANONICAL=FAIL {detail}")

        extra = root / "legacy.txt"
        extra.write_text("stale\n", encoding="utf-8")
        ok, _ = validate(root)
        if ok:
            raise SystemExit("R8_VENDOR_SABLE_SELF_TEST_EXTRA_FILE=FAIL")
        extra.unlink()

        missing = root / "r8/prebuilt/SableMail.apk"
        missing.unlink()
        ok, _ = validate(root)
        if ok:
            raise SystemExit("R8_VENDOR_SABLE_SELF_TEST_MISSING_FILE=FAIL")
        missing.write_bytes(b"canonical-test\n")

        link = root / "r8/prebuilt/legacy-link.apk"
        link.symlink_to(root / "r8/prebuilt/SableMail.apk")
        ok, _ = validate(root)
        if ok:
            raise SystemExit("R8_VENDOR_SABLE_SELF_TEST_SYMLINK=FAIL")
        link.unlink()

        extra_dir = root / "prebuilts"
        extra_dir.mkdir()
        ok, _ = validate(root)
        if ok:
            raise SystemExit("R8_VENDOR_SABLE_SELF_TEST_EXTRA_DIR=FAIL")

    print("R8_VENDOR_SABLE_SELF_TEST_CANONICAL=PASS")
    print("R8_VENDOR_SABLE_SELF_TEST_EXTRA_FILE=PASS_REJECTED")
    print("R8_VENDOR_SABLE_SELF_TEST_MISSING_FILE=PASS_REJECTED")
    print("R8_VENDOR_SABLE_SELF_TEST_SYMLINK=PASS_REJECTED")
    print("R8_VENDOR_SABLE_SELF_TEST_EXTRA_DIR=PASS_REJECTED")
    print("R8_VENDOR_SABLE_INVENTORY_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        if args.root is not None:
            parser.error("--self-test cannot be combined with root")
        self_test()
        return 0

    if args.root is None:
        parser.error("root is required unless --self-test is used")

    root = args.root.resolve()
    ok, detail = validate(root)
    if not ok:
        print(f"R8_VENDOR_SABLE_EXACT_INVENTORY=FAIL path={root} {detail}")
        return 1

    print("R8_VENDOR_SABLE_EXACT_INVENTORY=PASS")
    print(f"R8_VENDOR_SABLE_CANONICAL_FILE_COUNT={len(EXPECTED_FILES)}")
    print("R8_VENDOR_SABLE_CANONICAL_APK_COUNT=9")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
