#!/usr/bin/env python3
"""Verify the pinned GrapheneOS Messaging prebuilt substrate for R9.

GrapheneOS 2026081300 ships Messaging as an android_app_import containing a
prebuilt APK. There is no source AndroidManifest.xml in this project to patch.

Sable therefore preserves the GrapheneOS Messaging package exactly as pinned
for mature SMS/MMS/default-app behavior and owns duplicate-launcher suppression
in the Sable Launcher3 presentation layer.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

MESSAGING_REPO = Path("external/Messaging")
MESSAGING_HEAD = "d125442740e85c8c630c6b3c1091046166b99187"
ANDROID_BP = MESSAGING_REPO / "Android.bp"
PREBUILT_APK = MESSAGING_REPO / "prebuilt/Messaging.apk"
WHITELIST = MESSAGING_REPO / "whitelist_com.android.messaging.xml"

BP_REQUIRED = (
    "android_app_import {",
    'name: "Messaging"',
    'apk: "prebuilt/Messaging.apk"',
    "preprocessed: true",
    '"whitelist_com.android.messaging.xml"',
)

WHITELIST_REQUIRED = (
    '<allow-in-power-save package="com.android.messaging" />',
)


class VisibilityError(RuntimeError):
    pass


def run_git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
        stderr=subprocess.STDOUT,
    ).strip()


def verify_text(bp_text: str, whitelist_text: str) -> None:
    for token in BP_REQUIRED:
        if token not in bp_text:
            raise VisibilityError(
                f"MESSAGING_PREBUILT_BP_TOKEN_MISSING={token}"
            )
    for token in WHITELIST_REQUIRED:
        if token not in whitelist_text:
            raise VisibilityError(
                f"MESSAGING_WHITELIST_TOKEN_MISSING={token}"
            )


def verify(source: Path) -> None:
    repo = source / MESSAGING_REPO
    if not repo.is_dir():
        raise VisibilityError(f"MESSAGING_SOURCE_MISSING={repo}")

    actual = run_git(repo, "rev-parse", "HEAD")
    if actual != MESSAGING_HEAD:
        raise VisibilityError(
            f"MESSAGING_HEAD_MISMATCH expected={MESSAGING_HEAD} actual={actual}"
        )

    dirt = run_git(repo, "status", "--porcelain", "--untracked-files=all")
    if dirt:
        raise VisibilityError(
            "MESSAGING_SOURCE_NOT_CLEAN=" + "|".join(dirt.splitlines())
        )

    bp = source / ANDROID_BP
    apk = source / PREBUILT_APK
    whitelist = source / WHITELIST

    for path in (bp, apk, whitelist):
        if not path.is_file():
            raise VisibilityError(f"MESSAGING_PREBUILT_FILE_MISSING={path}")

    verify_text(
        bp.read_text(encoding="utf-8"),
        whitelist.read_text(encoding="utf-8"),
    )

    print("R9_GRAPHENE_MESSAGING_HEAD=PASS")
    print("R9_GRAPHENE_MESSAGING_PREBUILT_IMPORT=PASS")
    print("R9_GRAPHENE_MESSAGING_PACKAGE_RETAINED=PASS_PREBUILT")
    print("R9_GRAPHENE_MESSAGING_SOURCE_MUTATION=NONE")
    print(
        "R9_GRAPHENE_MESSAGING_LAUNCHER_EXPOSURE_OWNER="
        "SABLE_LAUNCHER_PRESENTATION"
    )


def self_test() -> None:
    bp = """android_app_import {
    name: "Messaging",
    apk: "prebuilt/Messaging.apk",
    preprocessed: true,
    required: ["whitelist_com.android.messaging.xml"],
}
"""
    whitelist = """<config>
    <allow-in-power-save package="com.android.messaging" />
</config>
"""
    verify_text(bp, whitelist)
    print("R9_MESSAGING_PREBUILT_SELF_TEST=PASS")
    print("SELF_TEST_REAL_SOURCE_MUTATION=NONE")
    print("SELF_TEST_BUILD=NONE")
    print("SELF_TEST_DEVICE_CONTACT=NONE")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", nargs="?", choices=("apply", "verify"))
    parser.add_argument("--source", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        if args.mode is not None or args.source is not None:
            parser.error("--self-test cannot be combined with mode or --source")
        self_test()
        return 0

    if args.mode is None or args.source is None:
        parser.error("mode and --source are required unless --self-test is used")

    source = args.source.resolve()
    if not (source / ".repo").exists():
        print(f"R9_MESSAGING_VISIBILITY=FAIL NOT_ANDROID_REPO_ROOT={source}")
        return 1

    try:
        # "apply" is intentionally verification-only. The GrapheneOS prebuilt
        # remains untouched; launcher visibility is owned by Sable Launcher3.
        verify(source)
    except (VisibilityError, subprocess.CalledProcessError) as exc:
        print(f"R9_MESSAGING_VISIBILITY=FAIL {exc}")
        return 1

    if args.mode == "apply":
        print("R9_MESSAGING_VISIBILITY_APPLY=NO_SOURCE_MUTATION_REQUIRED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
