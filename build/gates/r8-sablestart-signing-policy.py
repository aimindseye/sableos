#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import tempfile
import zipfile


TRUE_RE = re.compile(r"\bv4_signature\s*:\s*true\s*,?")
FALSE_RE = re.compile(r"\bv4_signature\s*:\s*false\s*,?")


class PolicyError(RuntimeError):
    pass


def check_source(path: pathlib.Path) -> None:
    text = path.read_text(encoding="utf-8")
    if TRUE_RE.search(text):
        raise PolicyError(
            f"R8_SABLESTART_V4_SOURCE_POLICY=FAIL reason=v4_true path={path}"
        )
    if not FALSE_RE.search(text):
        raise PolicyError(
            f"R8_SABLESTART_V4_SOURCE_POLICY=FAIL reason=explicit_false_missing path={path}"
        )
    print(f"R8_SABLESTART_V4_SOURCE_POLICY=PASS path={path}")


def check_target_files(path: pathlib.Path) -> None:
    with zipfile.ZipFile(path) as zf:
        names = set(zf.namelist())

    apks = sorted(
        name
        for name in names
        if name.endswith("/SableStart/SableStart.apk")
    )
    if len(apks) != 1:
        raise PolicyError(
            f"R8_SABLESTART_V4_TARGET_POLICY=FAIL reason=apk_count matches={apks!r}"
        )

    idsig = apks[0] + ".idsig"
    if idsig in names:
        raise PolicyError(
            f"R8_SABLESTART_V4_TARGET_POLICY=FAIL reason=idsig_present member={idsig}"
        )

    print(
        "R8_SABLESTART_V4_TARGET_POLICY=PASS "
        f"apk_member={apks[0]} idsig_present=NO"
    )


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="r8-sablestart-signing-") as tmp:
        root = pathlib.Path(tmp)

        good_bp = root / "good.bp"
        good_bp.write_text(
            'android_app {\n    name: "SableStart",\n    v4_signature: false,\n}\n',
            encoding="utf-8",
        )
        check_source(good_bp)

        bad_bp = root / "bad.bp"
        bad_bp.write_text(
            'android_app {\n    name: "SableStart",\n    v4_signature: true,\n}\n',
            encoding="utf-8",
        )
        try:
            check_source(bad_bp)
        except PolicyError:
            pass
        else:
            raise PolicyError(
                "R8_SABLESTART_SIGNING_SELF_TEST=FAIL reason=v4_true_not_rejected"
            )

        good_zip = root / "good.zip"
        with zipfile.ZipFile(good_zip, "w") as zf:
            zf.writestr("SYSTEM/app/SableStart/SableStart.apk", b"apk")
        check_target_files(good_zip)

        bad_zip = root / "bad.zip"
        with zipfile.ZipFile(bad_zip, "w") as zf:
            zf.writestr("SYSTEM/app/SableStart/SableStart.apk", b"apk")
            zf.writestr("SYSTEM/app/SableStart/SableStart.apk.idsig", b"idsig")
        try:
            check_target_files(bad_zip)
        except PolicyError:
            pass
        else:
            raise PolicyError(
                "R8_SABLESTART_SIGNING_SELF_TEST=FAIL reason=idsig_not_rejected"
            )

    print("R8_SABLESTART_SIGNING_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Enforce the R8 SableStart APK v4-signing policy."
    )
    parser.add_argument("--source-bp", type=pathlib.Path)
    parser.add_argument("--target-files", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if not (args.source_bp or args.target_files or args.self_test):
        parser.error("at least one check is required")

    try:
        if args.self_test:
            self_test()
        if args.source_bp:
            check_source(args.source_bp)
        if args.target_files:
            check_target_files(args.target_files)
    except (OSError, zipfile.BadZipFile, PolicyError) as exc:
        print(exc)
        return 1

    print("R8_SABLESTART_SIGNING_POLICY=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
