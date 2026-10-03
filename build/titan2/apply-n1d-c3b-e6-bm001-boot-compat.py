#!/usr/bin/env python3
"""Apply/verify the Titan 2 N1D C3B BM-001 boot-compat transform.

This is the Sable-owned admission of the semantics from the pinned control
patch 0001-Remove-init.vndk-nodef.rc.patch. It removes only the GSI nodef
fallback that can reboot to bootloader when ro.vndk.version is undefined.
"""
from __future__ import annotations

import argparse
import pathlib
import tempfile

ANDROID_BP = pathlib.Path("target/product/gsi/Android.bp")
INIT_GSI_RC = pathlib.Path("target/product/gsi/init.gsi.rc")
INIT_NODEF_RC = pathlib.Path("target/product/gsi/init.vndk-nodef.rc")
GSI_RELEASE_MK = pathlib.Path("target/product/gsi_release.mk")

PREBUILT_BLOCK = """prebuilt_etc {
    name: "init.vndk-nodef.rc",
    src: "init.vndk-nodef.rc",
    system_ext_specific: true,
    relative_install_path: "gsi",
}

"""
FS_LIST_LINE = '        "init.vndk-nodef.rc",\n'
IMPORT_LINE = 'import /system/system_ext/etc/gsi/init.vndk-${ro.vndk.version:-nodef}.rc\n'
PACKAGE_LINE = '    init.vndk-nodef.rc \\\n'
NODEF_EXACT = """on early-init
    # Reboot if BOARD_VNDK_VERSION is not defined
    exec - root -- /system/bin/reboot bootloader
"""


def fail(msg: str) -> None:
    raise SystemExit(f"N1D_C3B_E6_BM001=FAIL {msg}")


def read(root: pathlib.Path, rel: pathlib.Path) -> str:
    path = root / rel
    if not path.is_file():
        fail(f"missing_file={rel}")
    return path.read_text(encoding="utf-8")


def verify(root: pathlib.Path) -> None:
    bp = read(root, ANDROID_BP)
    init = read(root, INIT_GSI_RC)
    release = read(root, GSI_RELEASE_MK)

    if PREBUILT_BLOCK in bp or FS_LIST_LINE in bp:
        fail("android_bp_nodef_reference_present")
    if IMPORT_LINE in init:
        fail("init_gsi_nodef_import_present")
    if PACKAGE_LINE in release:
        fail("gsi_release_nodef_package_present")
    if (root / INIT_NODEF_RC).exists():
        fail("init_vndk_nodef_rc_present")

    print("N1D_C3B_E6_BM001_ANDROID_BP=PASS_ABSENT")
    print("N1D_C3B_E6_BM001_INIT_IMPORT=PASS_ABSENT")
    print("N1D_C3B_E6_BM001_NODEF_RC=PASS_ABSENT")
    print("N1D_C3B_E6_BM001_RELEASE_PACKAGE=PASS_ABSENT")
    print("N1D_C3B_E6_BM001=PASS_VERIFIED")


def apply(root: pathlib.Path) -> None:
    nodef = root / INIT_NODEF_RC
    already = (
        nodef.exists() is False
        and PREBUILT_BLOCK not in read(root, ANDROID_BP)
        and FS_LIST_LINE not in read(root, ANDROID_BP)
        and IMPORT_LINE not in read(root, INIT_GSI_RC)
        and PACKAGE_LINE not in read(root, GSI_RELEASE_MK)
    )
    if already:
        verify(root)
        print("N1D_C3B_E6_BM001=PASS_ALREADY_APPLIED")
        return

    if not nodef.is_file():
        fail("nodef_source_missing_partial_state")
    if nodef.read_text(encoding="utf-8") != NODEF_EXACT:
        fail("nodef_source_content_mismatch")

    bp = read(root, ANDROID_BP)
    init = read(root, INIT_GSI_RC)
    release = read(root, GSI_RELEASE_MK)

    if bp.count(PREBUILT_BLOCK) != 1:
        fail(f"android_bp_prebuilt_count={bp.count(PREBUILT_BLOCK)}")
    if bp.count(FS_LIST_LINE) != 1:
        fail(f"android_bp_list_count={bp.count(FS_LIST_LINE)}")
    if init.count(IMPORT_LINE) != 1:
        fail(f"init_import_count={init.count(IMPORT_LINE)}")
    if release.count(PACKAGE_LINE) != 1:
        fail(f"release_package_count={release.count(PACKAGE_LINE)}")

    (root / ANDROID_BP).write_text(
        bp.replace(PREBUILT_BLOCK, "", 1).replace(FS_LIST_LINE, "", 1),
        encoding="utf-8",
    )
    (root / INIT_GSI_RC).write_text(init.replace(IMPORT_LINE, "", 1), encoding="utf-8")
    (root / GSI_RELEASE_MK).write_text(
        release.replace(PACKAGE_LINE, "", 1),
        encoding="utf-8",
    )
    nodef.unlink()

    verify(root)
    print("N1D_C3B_E6_BM001=PASS_APPLIED")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="sable-bm001-") as td:
        root = pathlib.Path(td)
        for rel in (ANDROID_BP, INIT_GSI_RC, INIT_NODEF_RC, GSI_RELEASE_MK):
            (root / rel).parent.mkdir(parents=True, exist_ok=True)

        (root / ANDROID_BP).write_text(
            "header\n" + PREBUILT_BLOCK + "list = [\n" + FS_LIST_LINE + "]\n",
            encoding="utf-8",
        )
        (root / INIT_GSI_RC).write_text("# gsi\n" + IMPORT_LINE, encoding="utf-8")
        (root / INIT_NODEF_RC).write_text(NODEF_EXACT, encoding="utf-8")
        (root / GSI_RELEASE_MK).write_text(
            "PRODUCT_PACKAGES += \\\n"
            "    gsi_skip_mount.cfg \\\n"
            "    init.gsi.rc \\\n"
            + PACKAGE_LINE
            + "\n# Overlay\n",
            encoding="utf-8",
        )

        apply(root)
        verify(root)
        apply(root)

    print("N1D_C3B_E6_BM001_SELF_TEST=PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("apply", "verify", "self-test"))
    parser.add_argument("--repo", type=pathlib.Path)
    args = parser.parse_args()

    if args.action == "self-test":
        self_test()
        return
    if args.repo is None:
        fail("--repo_required")
    root = args.repo.resolve()
    if args.action == "apply":
        apply(root)
    else:
        verify(root)


if __name__ == "__main__":
    main()
