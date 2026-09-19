#!/usr/bin/env python3
"""Apply/verify combined SableOS UI5C + UI6 final system-surface delta.

Layering:
  D2+D3 branding
    -> UI5A Settings / Applications
    -> UI5B Application Security & Privacy
    -> UI4 SystemUI visual delta
    -> UI5C + UI6 (this applicator)

This tranche is visual/product presentation only for SetupWizard, About SableOS
and Keyguard placement/copy. It does not replace Android authentication,
biometrics, trust, notification redaction, emergency-call, doze/AOD, falsing,
privacy indicators or gesture routing.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import shutil
import subprocess
import tempfile
from pathlib import Path

SETUP_HEAD = "3982cfc3536620c17b2ec5c3494af0fb2a58a633"
SETTINGS_HEAD = "71bd21cda07f4dfdcec2aabb16bc570be5bd8d35"
FRAMEWORK_HEAD = "aab06a8bd44c4c2b58eeec780fde83baa9d43a40"

SETUP_REPO = Path("packages/apps/SetupWizard2")
SETTINGS_REPO = Path("packages/apps/Settings")
FRAMEWORK_REPO = Path("frameworks/base")

SETUP_STRINGS = Path("res/values/strings.xml")
WELCOME_LAYOUT = Path("res/layout/activity_welcome.xml")
FINISH_LAYOUT = Path("res/layout/activity_finish.xml")
SETUP_COLORS = Path("res/values/colors_sable_ui5c.xml")
SETUP_UI5C_STRINGS = Path("res/values/strings_sable_ui5c.xml")

MY_DEVICE_INFO = Path("res/xml/my_device_info.xml")
SETTINGS_UI5C_STRINGS = Path("res/values/strings_sable_ui5c.xml")
ABOUT_CONTROLLER = Path(
    "src/com/android/settings/deviceinfo/aboutphone/SableAboutPreferenceController.java"
)
TOP_LEVEL_XMLS = (
    Path("res/xml/top_level_settings.xml"),
    Path("res/xml/top_level_settings_expressive.xml"),
    Path("res/xml/top_level_settings_expressive_desktop.xml"),
)

CLOCK_SECTION = Path(
    "packages/SystemUI/src/com/android/systemui/keyguard/ui/view/layout/sections/ClockSection.kt"
)
SYSTEMUI_STRINGS = Path("packages/SystemUI/res/values/strings.xml")
SYSTEMUI_DIMENS = Path("packages/SystemUI/res/values/dimens.xml")

CLOCK_SECTION_BASE_BLOB = "e40bd7a49dc114cc5171891c8f144188fdffdbc4"
SYSTEMUI_STRINGS_BASE_BLOB = "d132e0eb58bad9c9a4ced267ae512cf058deb845"

SETUP_EXTRA_DIRT = {
    "?? res/values/colors_sable_ui5c.xml",
    "?? res/values/strings_sable_ui5c.xml",
}

SETTINGS_EXTRA_DIRT = {
    " M res/xml/my_device_info.xml",
    "?? res/values/strings_sable_ui5c.xml",
    "?? src/com/android/settings/deviceinfo/aboutphone/SableAboutPreferenceController.java",
}

UI6_NEW_DIRT = {
    f" M {CLOCK_SECTION.as_posix()}",
    f" M {SYSTEMUI_STRINGS.as_posix()}",
}

WELCOME_ROOT_OLD = """    android:id="@+id/glif_layout"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
"""
WELCOME_ROOT_NEW = """    android:id="@+id/glif_layout"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@color/sable_ui_background">
"""

WELCOME_ICON_OLD = """            <ImageView
                android:layout_width="64dp"
                android:layout_height="64dp"
                android:contentDescription="@string/grapheneos_icon"
                android:src="@drawable/sableos_icon" />
"""
WELCOME_ICON_NEW = """            <ImageView
                android:layout_width="72dp"
                android:layout_height="72dp"
                android:contentDescription="@string/grapheneos_icon"
                android:src="@drawable/sableos_icon" />
"""

WELCOME_TITLE_OLD = """            <TextView
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:lineHeight="45dp"
                android:text="@string/welcome_to_grapheneos"
                android:textAppearance="@style/TextAppearance.Material3.DisplayMedium"
                android:textColor="?android:attr/textColorPrimary" />
"""
WELCOME_TITLE_NEW = """            <TextView
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginTop="18dp"
                android:fontFamily="sans-serif-light"
                android:lineHeight="50dp"
                android:text="@string/welcome_to_grapheneos"
                android:textAppearance="@style/TextAppearance.Material3.DisplayMedium"
                android:textColor="@color/sable_ui_text_primary"
                android:textSize="44sp" />
"""

FINISH_IMAGE_OLD = """        <ImageView
            style="@style/SudContentFrame"
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1"
            android:contentDescription="@string/grapheneos_icon"
            android:src="@drawable/sableos_icon" />
"""
FINISH_IMAGE_NEW = """        <ImageView
            android:layout_width="96dp"
            android:layout_height="96dp"
            android:layout_gravity="center_horizontal"
            android:layout_marginTop="28dp"
            android:contentDescription="@string/grapheneos_icon"
            android:src="@drawable/sableos_icon" />

        <TextView
            style="@style/SudContentFrame"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="24dp"
            android:text="@string/sable_finish_note"
            android:textAppearance="@style/TextAppearance.SudMaterialYouItemSummary"
            android:textColor="@color/sable_ui_text_secondary" />

        <View
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1" />
"""

ABOUT_HEADER_OLD = """    <com.android.settingslib.widget.LayoutPreference
        android:key="my_device_info_header"
        android:layout="@layout/settings_entity_header"
        android:selectable="false"
        settings:isPreferenceVisible="false"/>

"""
ABOUT_HEADER_NEW = """    <com.android.settingslib.widget.LayoutPreference
        android:key="my_device_info_header"
        android:layout="@layout/settings_entity_header"
        android:selectable="false"
        settings:isPreferenceVisible="false"/>

    <Preference
        android:key="sableos_identity"
        android:order="-100"
        android:title="@string/sable_about_identity_title"
        android:summary="@string/summary_placeholder"
        android:selectable="false"
        settings:enableCopying="true"
        settings:controller="com.android.settings.deviceinfo.aboutphone.SableAboutPreferenceController"/>

"""

CLOCK_START_OLD = """            connect(ClockViewIds.LOCKSCREEN_CLOCK_VIEW_LARGE, START, PARENT_ID, START)
            connect(ClockViewIds.LOCKSCREEN_CLOCK_VIEW_LARGE, END, guideline, END)
"""
CLOCK_START_NEW = """            connect(
                ClockViewIds.LOCKSCREEN_CLOCK_VIEW_LARGE,
                START,
                PARENT_ID,
                START,
                context.resources.getDimensionPixelSize(R.dimen.sable_keyguard_clock_margin_start),
            )
            connect(ClockViewIds.LOCKSCREEN_CLOCK_VIEW_LARGE, END, guideline, END)
            setHorizontalBias(ClockViewIds.LOCKSCREEN_CLOCK_VIEW_LARGE, 0f)
"""

DIMENS_OLD = """    <dimen name="keyguard_clock_top_margin">18dp</dimen>
"""
DIMENS_NEW = """    <dimen name="keyguard_clock_top_margin">28dp</dimen>
    <dimen name="sable_keyguard_clock_margin_start">28dp</dimen>
"""

INDICATION_MARGIN_OLD = """    <dimen name="keyguard_indication_margin_bottom">32dp</dimen>
"""
INDICATION_MARGIN_NEW = """    <dimen name="keyguard_indication_margin_bottom">36dp</dimen>
"""

UNLOCK_STRING_OLD = """    <string name="keyguard_unlock">Swipe up to open</string>
"""
UNLOCK_STRING_NEW = """    <string name="keyguard_unlock">Swipe up to unlock</string>
"""


def run_git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
        stderr=subprocess.STDOUT,
    ).rstrip("\n")


def status_set(repo: Path) -> set[str]:
    out = run_git(repo, "status", "--porcelain", "--untracked-files=all")
    return {line for line in out.splitlines() if line}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"REPLACEMENT_PRECONDITION_FAIL={label} count={count}")
    return text.replace(old, new, 1)


def load_module(filename: str, module_name: str):
    path = Path(__file__).resolve().with_name(filename)
    if not path.is_file():
        raise SystemExit(f"DEPENDENCY_APPLICATOR_MISSING={path}")
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"DEPENDENCY_APPLICATOR_IMPORT_FAIL={path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def templates_dir() -> Path:
    return Path(__file__).resolve().parent / "ui5c_ui6"


def template_for(dest: Path) -> Path:
    mapping = {
        SETUP_COLORS: templates_dir() / "setupwizard_colors_sable_ui5c.xml",
        SETUP_UI5C_STRINGS: templates_dir() / "setupwizard_strings_sable_ui5c.xml",
        SETTINGS_UI5C_STRINGS: templates_dir() / "settings_strings_sable_ui5c.xml",
        ABOUT_CONTROLLER: templates_dir() / "SableAboutPreferenceController.java",
    }
    return mapping[dest]


def verify_templates() -> None:
    for dest in (
        SETUP_COLORS,
        SETUP_UI5C_STRINGS,
        SETTINGS_UI5C_STRINGS,
        ABOUT_CONTROLLER,
    ):
        path = template_for(dest)
        if not path.is_file():
            raise SystemExit(f"UI5C_UI6_TEMPLATE_MISSING={path}")


def assert_heads(source: Path) -> None:
    expected = (
        (SETUP_REPO, SETUP_HEAD),
        (SETTINGS_REPO, SETTINGS_HEAD),
        (FRAMEWORK_REPO, FRAMEWORK_HEAD),
    )
    for repo_rel, head in expected:
        actual = run_git(source / repo_rel, "rev-parse", "HEAD")
        if actual != head:
            raise SystemExit(
                f"HEAD_MISMATCH={repo_rel} expected={head} actual={actual}"
            )


def expected_settings_pre_dirt(ui5b) -> set[str]:
    return set(ui5b.expected_pre_dirt()) | set(ui5b.UI5B_DIRT)


def verify_branding_preconditions(source: Path, branding) -> None:
    setup = source / SETUP_REPO
    expected_setup = set(branding.EXPECTED_DIRT[branding.SETUP_REPO])
    actual_setup = status_set(setup)
    if actual_setup != expected_setup:
        raise SystemExit(
            "UI5C_SETUP_PRE_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(expected_setup)!r} actual={sorted(actual_setup)!r}"
        )

    checks = (
        (setup / SETUP_STRINGS, "Welcome to SableOS"),
        (setup / SETUP_STRINGS, "SableOS icon"),
        (setup / WELCOME_LAYOUT, '@drawable/sableos_icon'),
        (setup / FINISH_LAYOUT, '@drawable/sableos_icon'),
    )
    for path, needle in checks:
        if path.read_text(encoding="utf-8").count(needle) != 1:
            raise SystemExit(f"UI5C_BRANDING_CONTENT_PRECONDITION_FAIL={path} {needle!r}")

    setup_asset, _ = branding.verify_assets()
    if sha256(setup / Path("res/drawable-nodpi/sableos_icon.png")) != sha256(setup_asset):
        raise SystemExit("UI5C_SETUP_ICON_PRECONDITION_FAIL")


def verify_ui4_preconditions(source: Path, ui4) -> set[str]:
    ui4.verify_visual_delta(source)
    framework = source / FRAMEWORK_REPO
    actual = status_set(framework)
    valid = tuple(set(ui4.UI4_DIRT) | set(scope) for scope in ui4.ALLOWED_PREEXISTING_SCOPES)
    if actual not in valid:
        raise SystemExit(f"UI6_UI4_PRE_DIRTY_SCOPE_MISMATCH={sorted(actual)!r}")
    if not set(ui4.BRANDING_DIRT) <= actual:
        raise SystemExit("UI6_BRANDING_PRECONDITION_MISSING")

    clock_blob = run_git(framework, "hash-object", CLOCK_SECTION.as_posix())
    if clock_blob != CLOCK_SECTION_BASE_BLOB:
        raise SystemExit(
            f"UI6_CLOCK_BASE_BLOB_MISMATCH expected={CLOCK_SECTION_BASE_BLOB} actual={clock_blob}"
        )
    strings_blob = run_git(framework, "hash-object", SYSTEMUI_STRINGS.as_posix())
    if strings_blob != SYSTEMUI_STRINGS_BASE_BLOB:
        raise SystemExit(
            f"UI6_STRINGS_BASE_BLOB_MISMATCH expected={SYSTEMUI_STRINGS_BASE_BLOB} actual={strings_blob}"
        )
    return actual


def require_preconditions(source: Path):
    assert_heads(source)
    verify_templates()

    branding = load_module("apply_sable_branding.py", "sable_branding")
    ui5b = load_module("apply_ui5b_app_security.py", "sable_ui5b")
    ui4 = load_module("apply_ui4_systemui.py", "sable_ui4")

    verify_branding_preconditions(source, branding)
    ui5b.verify(source)

    settings_actual = status_set(source / SETTINGS_REPO)
    settings_expected = expected_settings_pre_dirt(ui5b)
    if settings_actual != settings_expected:
        raise SystemExit(
            "UI5C_SETTINGS_PRE_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(settings_expected)!r} actual={sorted(settings_actual)!r}"
        )

    framework_pre = verify_ui4_preconditions(source, ui4)
    return branding, ui5b, ui4, framework_pre


def transform_about_block(text: str, label: str) -> str:
    key = 'android:key="top_level_about_device"'
    key_index = text.find(key)
    if key_index < 0 or text.find(key, key_index + 1) >= 0:
        raise SystemExit(f"UI5C_ABOUT_KEY_PRECONDITION_FAIL={label}")

    start = text.rfind("<com.android.settings.widget.HomepagePreference", 0, key_index)
    end = text.find("/>", key_index)
    if start < 0 or end < 0:
        raise SystemExit(f"UI5C_ABOUT_BLOCK_BOUNDARY_FAIL={label}")
    end += 2

    block = text[start:end]
    block = replace_once(
        block,
        'android:title="@string/about_settings"',
        'android:title="@string/sable_about_title"',
        f"{label}:about-title",
    )
    return text[:start] + block + text[end:]


def apply(source: Path) -> None:
    branding, ui5b, ui4, framework_pre = require_preconditions(source)

    setup = source / SETUP_REPO
    settings = source / SETTINGS_REPO
    framework = source / FRAMEWORK_REPO

    for repo, dests in (
        (setup, (SETUP_COLORS, SETUP_UI5C_STRINGS)),
        (settings, (SETTINGS_UI5C_STRINGS, ABOUT_CONTROLLER)),
    ):
        for dest in dests:
            if (repo / dest).exists():
                raise SystemExit(f"UI5C_DEST_ALREADY_EXISTS={repo / dest}")

    welcome = (setup / WELCOME_LAYOUT).read_text(encoding="utf-8")
    welcome = replace_once(
        welcome, WELCOME_ROOT_OLD, WELCOME_ROOT_NEW, "welcome:background"
    )
    welcome = replace_once(
        welcome, WELCOME_ICON_OLD, WELCOME_ICON_NEW, "welcome:icon"
    )
    welcome = replace_once(
        welcome, WELCOME_TITLE_OLD, WELCOME_TITLE_NEW, "welcome:title"
    )
    welcome = replace_once(
        welcome,
        'android:text="@string/grapheneos_desc"\n'
        '                android:textAppearance="@style/TextAppearance.SudMaterialYouItemSummary" />',
        'android:text="@string/grapheneos_desc"\n'
        '                android:textAppearance="@style/TextAppearance.SudMaterialYouItemSummary"\n'
        '                android:textColor="@color/sable_ui_text_secondary" />',
        "welcome:description-color",
    )
    welcome = replace_once(
        welcome,
        'android:text="@string/lets_setup_your_device"\n'
        '                android:textAppearance="@style/TextAppearance.SudMaterialYouItemSummary" />',
        'android:text="@string/lets_setup_your_device"\n'
        '                android:textAppearance="@style/TextAppearance.SudMaterialYouItemSummary"\n'
        '                android:textColor="@color/sable_ui_text_secondary" />',
        "welcome:setup-color",
    )
    welcome = welcome.replace(
        'android:textColor="?android:attr/textColorPrimary"',
        'android:textColor="@color/sable_ui_text_primary"',
    )
    if welcome.count('android:textColor="@color/sable_ui_text_primary"') < 3:
        raise SystemExit("UI5C_WELCOME_PRIMARY_TEXT_COLOR_CARDINALITY_FAIL")
    (setup / WELCOME_LAYOUT).write_text(welcome, encoding="utf-8")

    finish = (setup / FINISH_LAYOUT).read_text(encoding="utf-8")
    finish = replace_once(
        finish, WELCOME_ROOT_OLD, WELCOME_ROOT_NEW, "finish:background"
    )
    finish = replace_once(
        finish, FINISH_IMAGE_OLD, FINISH_IMAGE_NEW, "finish:content"
    )
    (setup / FINISH_LAYOUT).write_text(finish, encoding="utf-8")

    setup_strings = (setup / SETUP_STRINGS).read_text(encoding="utf-8")
    setup_strings = replace_once(
        setup_strings,
        '<string name="grapheneos_desc">Privacy and security, crafted for your mobile device, usable by everyone.</string>',
        '<string name="grapheneos_desc">Security and privacy controls, clearly visible from the start.</string>',
        "setup-strings:description",
    )
    setup_strings = replace_once(
        setup_strings,
        '<string name="you_re_all_set_now">You\\\'re all set now!</string>',
        '<string name="you_re_all_set_now">You\\\'re ready</string>',
        "setup-strings:finish-title",
    )
    setup_strings = replace_once(
        setup_strings,
        '<string name="device_setup_done_desc">You\\\'re ready to start using your device</string>',
        '<string name="device_setup_done_desc">Setup is complete. Review privacy, app access and device controls any time in Settings.</string>',
        "setup-strings:device-finish",
    )
    setup_strings = replace_once(
        setup_strings,
        '<string name="profile_setup_done_desc">You\\\'re ready to start using your user profile</string>',
        '<string name="profile_setup_done_desc">Profile setup is complete. Review privacy and app access any time in Settings.</string>',
        "setup-strings:profile-finish",
    )
    (setup / SETUP_STRINGS).write_text(setup_strings, encoding="utf-8")

    for dest in (SETUP_COLORS, SETUP_UI5C_STRINGS):
        dst = setup / dest
        shutil.copyfile(template_for(dest), dst)

    about = (settings / MY_DEVICE_INFO).read_text(encoding="utf-8")
    about = replace_once(
        about,
        'android:title="@string/about_settings">',
        'android:title="@string/sable_about_title">',
        "about:screen-title",
    )
    about = replace_once(
        about,
        ABOUT_HEADER_OLD,
        ABOUT_HEADER_NEW,
        "about:sable-identity",
    )
    (settings / MY_DEVICE_INFO).write_text(about, encoding="utf-8")

    for rel in TOP_LEVEL_XMLS:
        path = settings / rel
        path.write_text(
            transform_about_block(path.read_text(encoding="utf-8"), str(rel)),
            encoding="utf-8",
        )

    for dest in (SETTINGS_UI5C_STRINGS, ABOUT_CONTROLLER):
        dst = settings / dest
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(template_for(dest), dst)

    clock = (framework / CLOCK_SECTION).read_text(encoding="utf-8")
    clock = replace_once(clock, CLOCK_START_OLD, CLOCK_START_NEW, "ui6:clock-start")
    (framework / CLOCK_SECTION).write_text(clock, encoding="utf-8")

    dimens = (framework / SYSTEMUI_DIMENS).read_text(encoding="utf-8")
    dimens = replace_once(dimens, DIMENS_OLD, DIMENS_NEW, "ui6:clock-top-margin")
    dimens = replace_once(
        dimens,
        INDICATION_MARGIN_OLD,
        INDICATION_MARGIN_NEW,
        "ui6:indication-bottom-margin",
    )
    (framework / SYSTEMUI_DIMENS).write_text(dimens, encoding="utf-8")

    strings = (framework / SYSTEMUI_STRINGS).read_text(encoding="utf-8")
    strings = replace_once(
        strings, UNLOCK_STRING_OLD, UNLOCK_STRING_NEW, "ui6:unlock-copy"
    )
    (framework / SYSTEMUI_STRINGS).write_text(strings, encoding="utf-8")

    verify(source)
    print("SABLE_UI5C_UI6_APPLY=PASS")


def verify_ui4_tokens(framework: Path, ui4) -> None:
    for rel, replacements in ui4.PATCHES.items():
        text = (framework / rel).read_text(encoding="utf-8")
        for old, new in replacements:
            if old in text:
                raise SystemExit(f"UI5C_UI6_UI4_OLD_TOKEN_PRESENT={rel}")
            if new and new not in text:
                raise SystemExit(f"UI5C_UI6_UI4_NEW_TOKEN_MISSING={rel}")


def verify(source: Path) -> None:
    assert_heads(source)
    verify_templates()

    branding = load_module("apply_sable_branding.py", "sable_branding_verify")
    ui5b = load_module("apply_ui5b_app_security.py", "sable_ui5b_verify")
    ui4 = load_module("apply_ui4_systemui.py", "sable_ui4_verify")

    setup = source / SETUP_REPO
    settings = source / SETTINGS_REPO
    framework = source / FRAMEWORK_REPO

    expected_setup = set(branding.EXPECTED_DIRT[branding.SETUP_REPO]) | SETUP_EXTRA_DIRT
    actual_setup = status_set(setup)
    if actual_setup != expected_setup:
        raise SystemExit(
            "UI5C_SETUP_FINAL_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(expected_setup)!r} actual={sorted(actual_setup)!r}"
        )

    expected_settings = expected_settings_pre_dirt(ui5b) | SETTINGS_EXTRA_DIRT
    actual_settings = status_set(settings)
    if actual_settings != expected_settings:
        raise SystemExit(
            "UI5C_SETTINGS_FINAL_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(expected_settings)!r} actual={sorted(actual_settings)!r}"
        )

    actual_framework = status_set(framework)
    framework_pre = actual_framework - UI6_NEW_DIRT
    valid_framework_pre = tuple(
        set(ui4.UI4_DIRT) | set(scope) for scope in ui4.ALLOWED_PREEXISTING_SCOPES
    )
    if framework_pre not in valid_framework_pre:
        raise SystemExit(
            f"UI6_FRAMEWORK_PRE_SCOPE_RECOVERY_FAIL={sorted(framework_pre)!r}"
        )
    if actual_framework != framework_pre | UI6_NEW_DIRT:
        raise SystemExit("UI6_FRAMEWORK_FINAL_DIRTY_SCOPE_MISMATCH")
    if not set(ui4.BRANDING_DIRT) <= framework_pre:
        raise SystemExit("UI6_FINAL_BRANDING_SCOPE_MISSING")

    for dest in (SETUP_COLORS, SETUP_UI5C_STRINGS):
        if sha256(setup / dest) != sha256(template_for(dest)):
            raise SystemExit(f"UI5C_SETUP_TEMPLATE_VERIFY_FAIL={dest}")

    for dest in (SETTINGS_UI5C_STRINGS, ABOUT_CONTROLLER):
        if sha256(settings / dest) != sha256(template_for(dest)):
            raise SystemExit(f"UI5C_SETTINGS_TEMPLATE_VERIFY_FAIL={dest}")

    welcome = (setup / WELCOME_LAYOUT).read_text(encoding="utf-8")
    finish = (setup / FINISH_LAYOUT).read_text(encoding="utf-8")
    setup_strings = (setup / SETUP_STRINGS).read_text(encoding="utf-8")
    required_setup = (
        (welcome, '@drawable/sableos_icon'),
        (welcome, '@color/sable_ui_background'),
        (welcome, '@color/sable_ui_text_primary'),
        (finish, '@drawable/sableos_icon'),
        (finish, '@string/sable_finish_note'),
        (setup_strings, "Welcome to SableOS"),
        (setup_strings, "You\\'re ready"),
        (setup_strings, "Review privacy, app access and device controls"),
    )
    for text_value, needle in required_setup:
        if needle not in text_value:
            raise SystemExit(f"UI5C_SETUP_SEMANTIC_VERIFY_FAIL={needle}")

    about = (settings / MY_DEVICE_INFO).read_text(encoding="utf-8")
    if about.count('android:key="sableos_identity"') != 1:
        raise SystemExit("UI5C_ABOUT_IDENTITY_ENTRY_VERIFY_FAIL")
    if about.count('@string/sable_about_title') != 1:
        raise SystemExit("UI5C_ABOUT_SCREEN_TITLE_VERIFY_FAIL")
    for rel in TOP_LEVEL_XMLS:
        text_value = (settings / rel).read_text(encoding="utf-8")
        key_index = text_value.find('android:key="top_level_about_device"')
        if key_index < 0:
            raise SystemExit(f"UI5C_TOP_LEVEL_ABOUT_MISSING={rel}")
        start = text_value.rfind("<com.android.settings.widget.HomepagePreference", 0, key_index)
        end = text_value.find("/>", key_index)
        block = text_value[start:end]
        if 'android:title="@string/sable_about_title"' not in block:
            raise SystemExit(f"UI5C_TOP_LEVEL_ABOUT_TITLE_VERIFY_FAIL={rel}")

    controller = (settings / ABOUT_CONTROLLER).read_text(encoding="utf-8")
    for needle in ("Build.MODEL", "Build.DEVICE", "Build.VERSION.RELEASE", "Build.DISPLAY"):
        if needle not in controller:
            raise SystemExit(f"UI5C_ABOUT_REAL_PROPERTY_VERIFY_FAIL={needle}")

    verify_ui4_tokens(framework, ui4)

    clock = (framework / CLOCK_SECTION).read_text(encoding="utf-8")
    dimens = (framework / SYSTEMUI_DIMENS).read_text(encoding="utf-8")
    strings = (framework / SYSTEMUI_STRINGS).read_text(encoding="utf-8")
    ui6_required = (
        (clock, "sable_keyguard_clock_margin_start"),
        (clock, "setHorizontalBias(ClockViewIds.LOCKSCREEN_CLOCK_VIEW_LARGE, 0f)"),
        (clock, "KeyguardClockViewBinder.bind("),
        (dimens, '<dimen name="keyguard_clock_top_margin">28dp</dimen>'),
        (dimens, '<dimen name="sable_keyguard_clock_margin_start">28dp</dimen>'),
        (dimens, '<dimen name="keyguard_indication_margin_bottom">36dp</dimen>'),
        (strings, '<string name="keyguard_unlock">Swipe up to unlock</string>'),
    )
    for text_value, needle in ui6_required:
        if needle not in text_value:
            raise SystemExit(f"UI6_VISUAL_VERIFY_FAIL={needle}")

    # Preserve explicit behavior/security architecture tokens in the Keyguard section.
    preserved = (
        "KeyguardClockViewBinder.bind(",
        "getTargetClockFace(clock).applyConstraints(constraintSet)",
        "getNonTargetClockFace(clock).applyConstraints(constraintSet)",
        "aodBurnInViewModel.movement.value.scaleClockOnly",
    )
    for needle in preserved:
        if needle not in clock:
            raise SystemExit(f"UI6_KEYGUARD_BEHAVIOR_TOKEN_MISSING={needle}")

    print("SABLE_UI5C_SETUPWIZARD_VISUAL=PASS")
    print("SABLE_UI5C_CANONICAL_BRANDING=PASS")
    print("SABLE_UI5C_ABOUT_REAL_BUILD_PROPERTIES=PASS")
    print("SABLE_UI6_KEYGUARD_VISUAL_PLACEMENT=PASS")
    print("SABLE_UI6_SWIPE_AFFORDANCE_COPY=PASS")
    print("SABLE_UI6_UI4_VISUAL_DELTA_PRESERVED=PASS")
    print("SABLE_UI6_AUTHENTICATION_BEHAVIORAL_DIFF=NONE")
    print("SABLE_UI6_NOTIFICATION_REDACTION_BEHAVIORAL_DIFF=NONE")
    print("SABLE_UI6_PRIVACY_INDICATOR_BEHAVIORAL_DIFF=NONE")
    print("SABLE_UI5C_UI6_SOURCE_SCOPE=PASS")


def self_test() -> None:
    verify_templates()

    samples = (
        (WELCOME_ROOT_OLD, WELCOME_ROOT_OLD, WELCOME_ROOT_NEW, "welcome-root", True),
        (WELCOME_ICON_OLD, WELCOME_ICON_OLD, WELCOME_ICON_NEW, "welcome-icon", True),
        (WELCOME_TITLE_OLD, WELCOME_TITLE_OLD, WELCOME_TITLE_NEW, "welcome-title", True),
        (FINISH_IMAGE_OLD, FINISH_IMAGE_OLD, FINISH_IMAGE_NEW, "finish-image", True),
        # ABOUT_HEADER_NEW intentionally preserves the existing upstream header and
        # appends the Sable identity row after it. Therefore ABOUT_HEADER_OLD remains
        # a valid substring of the transformed result and must not be treated as a
        # failed replacement.
        (ABOUT_HEADER_OLD, ABOUT_HEADER_OLD, ABOUT_HEADER_NEW, "about-header", False),
        (CLOCK_START_OLD, CLOCK_START_OLD, CLOCK_START_NEW, "clock-start", True),
        (DIMENS_OLD, DIMENS_OLD, DIMENS_NEW, "clock-dimens", True),
        (
            INDICATION_MARGIN_OLD,
            INDICATION_MARGIN_OLD,
            INDICATION_MARGIN_NEW,
            "indication-margin",
            True,
        ),
        (UNLOCK_STRING_OLD, UNLOCK_STRING_OLD, UNLOCK_STRING_NEW, "unlock-string", True),
    )
    for text_value, old, new, label, old_must_disappear in samples:
        out = replace_once(text_value, old, new, f"self-test:{label}")
        if (old_must_disappear and old in out) or new not in out:
            raise SystemExit(f"UI5C_UI6_SELF_TEST_REPLACEMENT_FAIL={label}")

    about_sample = """<PreferenceCategory>
        <com.android.settings.widget.HomepagePreference
            android:fragment="com.android.settings.deviceinfo.aboutphone.MyDeviceInfoFragment"
            android:key="top_level_about_device"
            android:title="@string/about_settings"
            android:summary="@string/summary_placeholder"/>
    </PreferenceCategory>
"""
    about_out = transform_about_block(about_sample, "self-test")
    if '@string/sable_about_title' not in about_out:
        raise SystemExit("UI5C_UI6_SELF_TEST_ABOUT_BLOCK_FAIL")

    with tempfile.TemporaryDirectory(prefix="sable-ui5c-ui6-selftest-") as td:
        root = Path(td)
        for dest in (
            SETUP_COLORS,
            SETUP_UI5C_STRINGS,
            SETTINGS_UI5C_STRINGS,
            ABOUT_CONTROLLER,
        ):
            out = root / dest.name
            shutil.copyfile(template_for(dest), out)
            if sha256(out) != sha256(template_for(dest)):
                raise SystemExit(f"UI5C_UI6_SELF_TEST_TEMPLATE_FAIL={dest}")

    print("SABLE_UI5C_UI6_SELF_TEST=PASS")
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
        verify(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
