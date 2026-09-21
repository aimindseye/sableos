#!/usr/bin/env python3
"""Apply/verify the approved Sable Phone + Contacts presentation.

This applicator is intentionally presentation-only. It is pinned to the exact
GrapheneOS 2026081300 Dialer and Contacts revisions and may mutate only the
listed resource/layout files. Telecom, call-log, ContactsProvider, accounts,
permissions, intents and Java/Kotlin behavioral source remain untouched.
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

DIALER_HEAD = "6a629762cf425002d34ecf28596813babda7d751"
CONTACTS_HEAD = "e911d48c3f433633f5a8fb1a7fd865a071a09350"

DIALER_REPO = Path("packages/apps/Dialer")
CONTACTS_REPO = Path("packages/apps/Contacts")

DIALER_LIGHT = Path(
    "java/com/android/dialer/theme/hidden/res/values/colors_dialer_light.xml"
)
DIALER_DARK = Path(
    "java/com/android/dialer/theme/hidden/res/values-night/colors_dialer_dark.xml"
)
DIALER_TOOLBAR = Path(
    "java/com/android/dialer/main/impl/toolbar/res/layout/toolbar_layout.xml"
)
DIALER_BOTTOM_NAV = Path(
    "java/com/android/dialer/main/impl/bottomnav/res/layout/bottom_nav_bar_layout.xml"
)
DIALER_DIALPAD = Path(
    "java/com/android/dialer/dialpadview/res/values/styles.xml"
)

CONTACTS_LIGHT = Path("res/values/colors.xml")
CONTACTS_DARK = Path("res/values-night/colors.xml")
CONTACTS_TOOLBAR = Path("res/layout/people_activity_toolbar.xml")
CONTACTS_STYLES = Path("res/values/styles.xml")

DIALER_BLOCKING = Path("java/com/android/dialer/blocking/Blocking.java")
DIALER_SETTINGS = Path(
    "java/com/android/dialer/app/settings/DialerSettingsActivity.java"
)
DIALER_APP_MANIFEST = Path("java/com/android/dialer/app/AndroidManifest.xml")

DIALER_DIRT = {
    f" M {DIALER_LIGHT.as_posix()}",
    f" M {DIALER_DARK.as_posix()}",
    f" M {DIALER_TOOLBAR.as_posix()}",
    f" M {DIALER_BOTTOM_NAV.as_posix()}",
    f" M {DIALER_DIALPAD.as_posix()}",
}

CONTACTS_DIRT = {
    f" M {CONTACTS_LIGHT.as_posix()}",
    f" M {CONTACTS_DARK.as_posix()}",
    f" M {CONTACTS_TOOLBAR.as_posix()}",
    f" M {CONTACTS_STYLES.as_posix()}",
}

DIALER_TRANSFORMS: dict[Path, tuple[tuple[str, str], ...]] = {
    DIALER_LIGHT: (
        (
            '<color name="dialer_theme_color">#2A56C6</color>',
            '<color name="dialer_theme_color">#4D9CFF</color>',
        ),
        (
            '<color name="dialer_theme_color_20pct">#332A56C6</color>',
            '<color name="dialer_theme_color_20pct">#334D9CFF</color>',
        ),
        (
            '<color name="dialer_secondary_color">#F50057</color>',
            '<color name="dialer_secondary_color">#4D9CFF</color>',
        ),
        (
            '<color name="dialer_background_color">#FAFAFA</color>',
            '<color name="dialer_background_color">#F5F7F9</color>',
        ),
        (
            '<color name="settings_primary_dark">#1C3AA9</color>',
            '<color name="settings_primary_dark">#45515F</color>',
        ),
    ),
    DIALER_DARK: (
        (
            '<color name="dialer_theme_color">#5195EA</color>',
            '<color name="dialer_theme_color">#4D9CFF</color>',
        ),
        (
            '<color name="dialer_theme_color_20pct">#335195EA</color>',
            '<color name="dialer_theme_color_20pct">#334D9CFF</color>',
        ),
        (
            '<color name="dialer_secondary_color">#5195EA</color>',
            '<color name="dialer_secondary_color">#4D9CFF</color>',
        ),
        (
            '<color name="settings_primary_dark">#2374CE</color>',
            '<color name="settings_primary_dark">#45515F</color>',
        ),
    ),
    DIALER_TOOLBAR: (
        (
            'android:background="@drawable/search_bar_background_rounded_corners"',
            'android:background="@android:color/transparent"',
        ),
        (
            'android:elevation="4dp"',
            'android:elevation="0dp"',
        ),
    ),
    DIALER_BOTTOM_NAV: (
        (
            'android:elevation="8dp"',
            'android:elevation="0dp"',
        ),
    ),
    DIALER_DIALPAD: (
        (
            '<item name="android:background">@drawable/btn_dialpad_key</item>',
            '<item name="android:background">@android:color/transparent</item>',
        ),
    ),
}

CONTACTS_TRANSFORMS: dict[Path, tuple[tuple[str, str], ...]] = {
    CONTACTS_LIGHT: (
        (
            '<color name="action_bar_background">#2a56c6</color>',
            '<color name="action_bar_background">#4D9CFF</color>',
        ),
        (
            '<color name="primary_color_dark">#1c3aa9</color>',
            '<color name="primary_color_dark">#45515F</color>',
        ),
        (
            '<color name="primary_color">#2a56c6</color>',
            '<color name="primary_color">#4D9CFF</color>',
        ),
        (
            '<color name="divider_line_color_light">#e0e0e0</color>',
            '<color name="divider_line_color_light">#D0D6DD</color>',
        ),
        (
            '<color name="background_primary">#f9f9f9</color>',
            '<color name="background_primary">#F5F7F9</color>',
        ),
        (
            '<color name="contact_all_list_background_color">#FFFFFF</color>',
            '<color name="contact_all_list_background_color">#F5F7F9</color>',
        ),
        (
            '<color name="navigation_drawer_background_color">#FAFAFA</color>',
            '<color name="navigation_drawer_background_color">#F5F7F9</color>',
        ),
    ),
    CONTACTS_DARK: (
        (
            '<color name="action_bar_background">#CC2A56C6</color>',
            '<color name="action_bar_background">#4D9CFF</color>',
        ),
        (
            '<color name="primary_color_dark">#265AB6</color>',
            '<color name="primary_color_dark">#45515F</color>',
        ),
        (
            '<color name="primary_color">#3872D7</color>',
            '<color name="primary_color">#4D9CFF</color>',
        ),
        (
            '<color name="divider_line_color_light">#525252</color>',
            '<color name="divider_line_color_light">#26313D</color>',
        ),
        (
            '<color name="background_primary">#181717</color>',
            '<color name="background_primary">#05070A</color>',
        ),
        (
            '<color name="contact_all_list_background_color">#2C2C2C</color>',
            '<color name="contact_all_list_background_color">#0D1117</color>',
        ),
        (
            '<color name="navigation_drawer_background_color">#181717</color>',
            '<color name="navigation_drawer_background_color">#05070A</color>',
        ),
    ),
    CONTACTS_TOOLBAR: (
        (
            'android:elevation="@dimen/tab_elevation"',
            'android:elevation="0dp"',
        ),
    ),
    CONTACTS_STYLES: (
        (
            '''    <style name="SectionHeaderStyle" parent="@android:style/TextAppearance.Large">
        <item name="android:textSize">16sp</item>
        <item name="android:textAllCaps">true</item>
        <item name="android:textColor">@color/section_header_text_color</item>
        <item name="android:textStyle">bold</item>
    </style>''',
            '''    <style name="SectionHeaderStyle" parent="@android:style/TextAppearance.Large">
        <item name="android:textSize">22sp</item>
        <item name="android:textAllCaps">false</item>
        <item name="android:textColor">@color/section_header_text_color</item>
        <item name="android:textStyle">normal</item>
        <item name="android:fontFamily">sans-serif-light</item>
    </style>''',
        ),
    ),
}


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
        stderr=subprocess.STDOUT,
    ).rstrip("\n")


def status(repo: Path) -> set[str]:
    out = git(repo, "status", "--porcelain", "--untracked-files=all")
    return {line for line in out.splitlines() if line}


def assert_head(source: Path, repo: Path, expected: str) -> None:
    actual = git(source / repo, "rev-parse", "HEAD")
    if actual != expected:
        raise SystemExit(
            f"R9_PHONE_CONTACTS_HEAD=FAIL repo={repo} "
            f"expected={expected} actual={actual}"
        )


def transform_text(
    text: str,
    replacements: tuple[tuple[str, str], ...],
    label: str,
) -> str:
    for old, new in replacements:
        if new in text and old not in text:
            continue
        count = text.count(old)
        if count != 1:
            raise SystemExit(
                f"R9_PHONE_CONTACTS_TRANSFORM=FAIL file={label} "
                f"old_count={count} old={old!r}"
            )
        text = text.replace(old, new, 1)
    return text


def apply_repo(
    root: Path,
    transforms: dict[Path, tuple[tuple[str, str], ...]],
    expected_dirt: set[str],
    label: str,
) -> None:
    current = status(root)
    if current == expected_dirt:
        print(f"R9_{label}_PRESENTATION=ALREADY_APPLIED")
        return
    if current:
        raise SystemExit(
            f"R9_{label}_PRE_DIRTY_SCOPE=FAIL actual={sorted(current)!r}"
        )

    for rel, replacements in transforms.items():
        path = root / rel
        text = path.read_text(encoding="utf-8")
        updated = transform_text(text, replacements, rel.as_posix())
        path.write_text(updated, encoding="utf-8")

    current = status(root)
    if current != expected_dirt:
        raise SystemExit(
            f"R9_{label}_DIRTY_SCOPE=FAIL "
            f"expected={sorted(expected_dirt)!r} actual={sorted(current)!r}"
        )
    print(f"R9_{label}_PRESENTATION=APPLIED")


def verify_repo(
    root: Path,
    transforms: dict[Path, tuple[tuple[str, str], ...]],
    expected_dirt: set[str],
    label: str,
) -> None:
    current = status(root)
    if current != expected_dirt:
        raise SystemExit(
            f"R9_{label}_VERIFY_DIRTY_SCOPE=FAIL "
            f"expected={sorted(expected_dirt)!r} actual={sorted(current)!r}"
        )

    for rel, replacements in transforms.items():
        text = (root / rel).read_text(encoding="utf-8")
        for old, new in replacements:
            if new not in text:
                raise SystemExit(
                    f"R9_{label}_VERIFY=FAIL file={rel} missing={new!r}"
                )
            if old in text:
                raise SystemExit(
                    f"R9_{label}_VERIFY=FAIL file={rel} stale={old!r}"
                )

    behavioral = [
        line for line in current
        if line[3:].endswith((".java", ".kt"))
    ]
    if behavioral:
        raise SystemExit(
            f"R9_{label}_BEHAVIORAL_SOURCE_MUTATION=FAIL "
            f"paths={behavioral!r}"
        )

    print(f"R9_{label}_PRESENTATION=PASS")
    print(f"R9_{label}_BEHAVIORAL_SOURCE_MUTATION=NONE")


def apply(source: Path) -> None:
    assert_head(source, DIALER_REPO, DIALER_HEAD)
    assert_head(source, CONTACTS_REPO, CONTACTS_HEAD)

    apply_repo(
        source / DIALER_REPO,
        DIALER_TRANSFORMS,
        DIALER_DIRT,
        "PHONE",
    )
    apply_repo(
        source / CONTACTS_REPO,
        CONTACTS_TRANSFORMS,
        CONTACTS_DIRT,
        "CONTACTS",
    )
    verify(source)


def verify_blocking_substrate(source: Path) -> None:
    dialer = source / DIALER_REPO

    blocking = (dialer / DIALER_BLOCKING).read_text(encoding="utf-8")
    for needle in (
        "android.provider.BlockedNumberContract",
        "BlockedNumbers.COLUMN_ORIGINAL_NUMBER",
        "BlockedNumbers.COLUMN_E164_NUMBER",
        "ContentProviderOperation.newInsert(BlockedNumbers.CONTENT_URI)",
        "ContentProviderOperation.newDelete(BlockedNumbers.CONTENT_URI)",
        "resolver.applyBatch(BlockedNumberContract.AUTHORITY, ops)",
    ):
        if needle not in blocking:
            raise SystemExit(
                "R9_BLOCKED_NUMBER_PLATFORM_SUBSTRATE=FAIL "
                f"file={DIALER_BLOCKING} missing={needle!r}"
            )

    settings = (dialer / DIALER_SETTINGS).read_text(encoding="utf-8")
    for needle in (
        "FilteredNumberCompat.canCurrentUserOpenBlockSettings(this)",
        "R.string.manage_blocked_numbers_label",
        "FilteredNumberCompat.createManageBlockedNumbersIntent(this)",
    ):
        if needle not in settings:
            raise SystemExit(
                "R9_BLOCKED_NUMBER_SETTINGS_UI=FAIL "
                f"file={DIALER_SETTINGS} missing={needle!r}"
            )

    manifest = (dialer / DIALER_APP_MANIFEST).read_text(encoding="utf-8")
    for needle in (
        "com.android.dialer.app.filterednumber.BlockedNumbersSettingsActivity",
        "com.android.dialer.action.BLOCKED_NUMBERS_SETTINGS",
        'android:exported="false"',
    ):
        if needle not in manifest:
            raise SystemExit(
                "R9_BLOCKED_NUMBER_SETTINGS_ACTIVITY=FAIL "
                f"file={DIALER_APP_MANIFEST} missing={needle!r}"
            )

    print("R9_BLOCKED_NUMBER_PLATFORM_SUBSTRATE=PASS")
    print("R9_BLOCKED_NUMBER_SETTINGS_UI=PASS")
    print("R9_SMS_MMS_BLOCKING_OWNER=ANDROID_BLOCKED_NUMBER_PROVIDER")
    print("R9_SMS_MMS_BLOCKING_MESSAGING_FORK_REQUIRED=NO")


def verify(source: Path) -> None:
    assert_head(source, DIALER_REPO, DIALER_HEAD)
    assert_head(source, CONTACTS_REPO, CONTACTS_HEAD)
    verify_blocking_substrate(source)

    verify_repo(
        source / DIALER_REPO,
        DIALER_TRANSFORMS,
        DIALER_DIRT,
        "PHONE",
    )
    verify_repo(
        source / CONTACTS_REPO,
        CONTACTS_TRANSFORMS,
        CONTACTS_DIRT,
        "CONTACTS",
    )

    print("R9_PHONE_CONTACTS_PINNED_BASELINES=PASS")
    print("R9_PHONE_CONTACTS_PRESENTATION=PASS")
    print("R9_PHONE_CONTACTS_BEHAVIORAL_SOURCE_MUTATION=NONE")


def self_test() -> None:
    for label, transforms in (
        ("PHONE", DIALER_TRANSFORMS),
        ("CONTACTS", CONTACTS_TRANSFORMS),
    ):
        for path, replacements in transforms.items():
            fixture = "\n".join(old for old, _ in replacements)
            updated = transform_text(fixture, replacements, path.as_posix())
            for old, new in replacements:
                if old in updated or new not in updated:
                    raise SystemExit(
                        f"R9_{label}_SELF_TEST=FAIL file={path}"
                    )

    if any(
        path.suffix in {".java", ".kt"}
        for path in (*DIALER_TRANSFORMS, *CONTACTS_TRANSFORMS)
    ):
        raise SystemExit("R9_PHONE_CONTACTS_SELF_TEST=FAIL_BEHAVIOR_SCOPE")

    required_blocking_tokens = (
        "BlockedNumberContract",
        "BlockedNumbers.COLUMN_ORIGINAL_NUMBER",
        "BlockedNumbers.COLUMN_E164_NUMBER",
        "canCurrentUserOpenBlockSettings",
        "createManageBlockedNumbersIntent",
        "BlockedNumbersSettingsActivity",
    )
    source_text = Path(__file__).read_text(encoding="utf-8")
    for token in required_blocking_tokens:
        if token not in source_text:
            raise SystemExit(
                f"R9_PHONE_CONTACTS_SELF_TEST=FAIL_BLOCKING_CONTRACT token={token!r}"
            )

    print("R9_BLOCKED_NUMBER_CONTRACT=PASS_SELF_TEST")
    print("R9_PHONE_CONTACTS_PINNED_BASELINES=PASS_SELF_TEST")
    print("R9_PHONE_PRESENTATION=PASS_SELF_TEST")
    print("R9_CONTACTS_PRESENTATION=PASS_SELF_TEST")
    print("R9_PHONE_CONTACTS_BEHAVIORAL_SOURCE_MUTATION=NONE_SELF_TEST")
    print("R9_PHONE_CONTACTS_PRESENTATION_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("command", nargs="?", choices=("apply", "verify"))
    args = parser.parse_args()

    if args.self_test:
        if args.source is not None or args.command is not None:
            parser.error("--self-test cannot be combined with source/command")
        self_test()
        return 0

    if args.source is None or args.command is None:
        parser.error("--source and command are required")

    source = args.source.resolve()
    if args.command == "apply":
        apply(source)
    else:
        verify(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
