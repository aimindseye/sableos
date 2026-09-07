#!/usr/bin/env python3
"""Apply/verify the SableOS D2+D3 branding delta on GrapheneOS 2026081300.

This intentionally changes only seven source files:
  packages/apps/SetupWizard2/res/values/strings.xml
  packages/apps/SetupWizard2/res/layout/activity_welcome.xml
  packages/apps/SetupWizard2/res/layout/activity_finish.xml
  packages/apps/SetupWizard2/res/drawable-nodpi/sableos_icon.png
  packages/apps/Settings/res/values/strings_app_exploit_protection.xml
  packages/apps/Settings/res/values/strings_ext.xml
  frameworks/base/core/res/assets/images/android-logo-mask.png

Internal GrapheneOS package/API identifiers, provider/service ownership wording and
GrapheneOS URLs are deliberately not globally rebranded.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path

SETUP_HEAD = "3982cfc3536620c17b2ec5c3494af0fb2a58a633"
SETTINGS_HEAD = "71bd21cda07f4dfdcec2aabb16bc570be5bd8d35"
FRAMEWORK_HEAD = "aab06a8bd44c4c2b58eeec780fde83baa9d43a40"

SETUP_ICON_SHA = "eed1b1277a77fa1f94b514585622c403c85c95191cfa3ba90edf526d02e5aea7"
OLD_BOOT_MASK_SHA = "75efac98abbc429c9aaa4c1aea918014aaead364b802ecec493c70c2d000df41"
NEW_BOOT_MASK_SHA = "dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e"
BOOT_SHINE_SHA = "73c2cb640b053c29ec8be308892759a33cd6ed5aa85283cca2a456d208ccd4fb"

SETUP_REPO = Path("packages/apps/SetupWizard2")
SETTINGS_REPO = Path("packages/apps/Settings")
FRAMEWORK_REPO = Path("frameworks/base")

SETUP_STRINGS = SETUP_REPO / "res/values/strings.xml"
WELCOME_LAYOUT = SETUP_REPO / "res/layout/activity_welcome.xml"
FINISH_LAYOUT = SETUP_REPO / "res/layout/activity_finish.xml"
SETUP_ICON_DST = SETUP_REPO / "res/drawable-nodpi/sableos_icon.png"
SETTINGS_EXPLOIT = SETTINGS_REPO / "res/values/strings_app_exploit_protection.xml"
SETTINGS_EXT = SETTINGS_REPO / "res/values/strings_ext.xml"
BOOT_MASK_DST = FRAMEWORK_REPO / "core/res/assets/images/android-logo-mask.png"
BOOT_SHINE = FRAMEWORK_REPO / "core/res/assets/images/android-logo-shine.png"

EXPECTED_DIRT = {
    SETUP_REPO: {
        " M res/layout/activity_finish.xml",
        " M res/layout/activity_welcome.xml",
        " M res/values/strings.xml",
        "?? res/drawable-nodpi/sableos_icon.png",
    },
    SETTINGS_REPO: {
        " M res/values/strings_app_exploit_protection.xml",
        " M res/values/strings_ext.xml",
    },
    FRAMEWORK_REPO: {
        " M core/res/assets/images/android-logo-mask.png",
    },
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run_git(repo: Path, *args: str) -> str:
    # Preserve leading spaces: git status --porcelain uses the first two
    # columns as meaningful index/worktree state. Only remove trailing newlines.
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True, stderr=subprocess.STDOUT
    ).rstrip("\n")


def assert_head(source: Path, repo_rel: Path, expected: str) -> None:
    actual = run_git(source / repo_rel, "rev-parse", "HEAD")
    if actual != expected:
        raise SystemExit(
            f"HEAD_MISMATCH={repo_rel} expected={expected} actual={actual}"
        )


def status_set(source: Path, repo_rel: Path) -> set[str]:
    out = run_git(source / repo_rel, "status", "--porcelain", "--untracked-files=all")
    return {line for line in out.splitlines() if line}


def require_clean(source: Path) -> None:
    for repo_rel in (SETUP_REPO, SETTINGS_REPO, FRAMEWORK_REPO):
        dirt = status_set(source, repo_rel)
        if dirt:
            raise SystemExit(f"SOURCE_NOT_CLEAN={repo_rel}:" + "|".join(sorted(dirt)))


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"REPLACEMENT_PRECONDITION_FAIL={path} count={count} old={old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def assets_dir() -> Path:
    return Path(__file__).resolve().parent / "assets"


def verify_assets() -> tuple[Path, Path]:
    setup = assets_dir() / "sableos_setupwizard_icon.png"
    mask = assets_dir() / "sableos_boot_fallback_mask_448x605.png"
    if sha256(setup) != SETUP_ICON_SHA:
        raise SystemExit("SETUP_ICON_ASSET_SHA_MISMATCH")
    if sha256(mask) != NEW_BOOT_MASK_SHA:
        raise SystemExit("BOOT_MASK_ASSET_SHA_MISMATCH")
    return setup, mask


def verify_heads(source: Path) -> None:
    assert_head(source, SETUP_REPO, SETUP_HEAD)
    assert_head(source, SETTINGS_REPO, SETTINGS_HEAD)
    assert_head(source, FRAMEWORK_REPO, FRAMEWORK_HEAD)


def verify_final(source: Path) -> None:
    verify_heads(source)
    setup_asset, mask_asset = verify_assets()

    checks = [
        (source / SETUP_STRINGS, "Welcome to SableOS", 1),
        (source / SETUP_STRINGS, "SableOS icon", 1),
        (
            source / SETUP_STRINGS,
            "If you have a compatible backup from a previous device, you can restore it here.",
            1,
        ),
        (source / WELCOME_LAYOUT, '@drawable/sableos_icon', 1),
        (source / FINISH_LAYOUT, '@drawable/sableos_icon', 1),
        (
            source / SETTINGS_EXPLOIT,
            "Improves compatibility by disabling some of the SableOS exploit protections for this app",
            1,
        ),
        (source / SETTINGS_EXT, "SableOS will remain installed.", 1),
    ]
    for path, needle, expected in checks:
        actual = path.read_text(encoding="utf-8").count(needle)
        if actual != expected:
            raise SystemExit(
                f"FINAL_TEXT_CHECK_FAIL={path} needle={needle!r} expected={expected} actual={actual}"
            )

    if sha256(source / SETUP_ICON_DST) != SETUP_ICON_SHA:
        raise SystemExit("FINAL_SETUP_ICON_SHA_MISMATCH")
    if sha256(source / BOOT_MASK_DST) != NEW_BOOT_MASK_SHA:
        raise SystemExit("FINAL_BOOT_MASK_SHA_MISMATCH")
    if sha256(source / BOOT_SHINE) != BOOT_SHINE_SHA:
        raise SystemExit("BOOT_SHINE_CHANGED")

    for repo_rel, expected in EXPECTED_DIRT.items():
        actual = status_set(source, repo_rel)
        if actual != expected:
            raise SystemExit(
                f"DIRTY_SCOPE_MISMATCH={repo_rel} expected={sorted(expected)!r} actual={sorted(actual)!r}"
            )

    print("SABLE_D2_D3_SOURCE_SCOPE=PASS")
    print(f"setupwizard_icon_sha256={sha256(setup_asset)}")
    print(f"boot_fallback_mask_sha256={sha256(mask_asset)}")
    print(f"boot_shine_sha256={sha256(source / BOOT_SHINE)}")


def apply(source: Path) -> None:
    verify_heads(source)
    require_clean(source)
    setup_asset, mask_asset = verify_assets()

    if sha256(source / BOOT_MASK_DST) != OLD_BOOT_MASK_SHA:
        raise SystemExit("OLD_GRAPHENE_BOOT_MASK_PRECONDITION_FAIL")
    if sha256(source / BOOT_SHINE) != BOOT_SHINE_SHA:
        raise SystemExit("BOOT_SHINE_PRECONDITION_FAIL")

    replace_once(
        source / SETUP_STRINGS,
        '<string name="welcome_to_grapheneos">Welcome to GrapheneOS</string>',
        '<string name="welcome_to_grapheneos">Welcome to SableOS</string>',
    )
    replace_once(
        source / SETUP_STRINGS,
        '<string name="grapheneos_icon">GrapheneOS icon</string>',
        '<string name="grapheneos_icon">SableOS icon</string>',
    )
    replace_once(
        source / SETUP_STRINGS,
        '<string name="data_restore_desc">If you have a backup from your previous GrapheneOS device, you can restore it here.</string>',
        '<string name="data_restore_desc">If you have a compatible backup from a previous device, you can restore it here.</string>',
    )

    replace_once(
        source / WELCOME_LAYOUT,
        'android:src="@drawable/grapheneos_icon"',
        'android:src="@drawable/sableos_icon"',
    )
    replace_once(
        source / FINISH_LAYOUT,
        'android:src="@drawable/grapheneos_icon"',
        'android:src="@drawable/sableos_icon"',
    )

    replace_once(
        source / SETTINGS_EXPLOIT,
        "Improves compatibility by disabling some of the GrapheneOS exploit protections for this app",
        "Improves compatibility by disabling some of the SableOS exploit protections for this app",
    )
    replace_once(
        source / SETTINGS_EXT,
        "GrapheneOS will remain installed.",
        "SableOS will remain installed.",
    )

    (source / SETUP_ICON_DST).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(setup_asset, source / SETUP_ICON_DST)
    shutil.copyfile(mask_asset, source / BOOT_MASK_DST)

    verify_final(source)
    print("SABLE_D2_D3_APPLY=PASS")


def self_test() -> None:
    setup_asset, mask_asset = verify_assets()
    with tempfile.TemporaryDirectory(prefix="sable-brand-selftest-") as td:
        root = Path(td)

        p = root / "x.txt"
        p.write_text("alpha GrapheneOS omega", encoding="utf-8")
        replace_once(p, "GrapheneOS", "SableOS")
        if p.read_text(encoding="utf-8") != "alpha SableOS omega":
            raise SystemExit("SELF_TEST_REPLACE_FAIL")

        # Regression test for the porcelain-leading-space parser bug. The
        # worktree-only modification must remain exactly " M ..." rather than
        # being collapsed to "M ..." by output trimming.
        repo = root / "repo"
        repo.mkdir()
        run_git(repo, "init", "-q")
        run_git(repo, "config", "user.email", "sable-selftest@example.invalid")
        run_git(repo, "config", "user.name", "Sable self-test")
        (repo / "tracked.txt").write_text("baseline\n", encoding="utf-8")
        run_git(repo, "add", "tracked.txt")
        run_git(repo, "commit", "-q", "-m", "self-test baseline")
        (repo / "tracked.txt").write_text("changed\n", encoding="utf-8")
        (repo / "new.txt").write_text("untracked\n", encoding="utf-8")

        porcelain = status_set(root, Path("repo"))
        expected_porcelain = {" M tracked.txt", "?? new.txt"}
        if porcelain != expected_porcelain:
            raise SystemExit(
                f"SELF_TEST_PORCELAIN_FAIL expected={sorted(expected_porcelain)!r} actual={sorted(porcelain)!r}"
            )

    print(f"SELF_TEST_SETUP_ICON_SHA={sha256(setup_asset)}")
    print(f"SELF_TEST_BOOT_MASK_SHA={sha256(mask_asset)}")
    print("SELF_TEST_PORCELAIN_COLUMNS=PASS")
    print("SABLE_D2_D3_APPLY_SELF_TEST=PASS")
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

    if args.mode is None:
        parser.error("mode is required unless --self-test is used")
    if args.source is None:
        parser.error("--source is required for apply/verify")

    source = args.source.resolve()
    if not (source / ".repo").exists():
        raise SystemExit(f"NOT_ANDROID_REPO_ROOT={source}")

    if args.mode == "apply":
        apply(source)
    else:
        verify_final(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
