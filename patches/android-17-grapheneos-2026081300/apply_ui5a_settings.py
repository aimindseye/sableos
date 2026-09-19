#!/usr/bin/env python3
"""Apply/verify SableOS UI5A Settings + Applications on pinned Android 17 Settings.

UI5A is intentionally bounded to packages/apps/Settings. It assumes the
existing Sable D2+D3 branding delta has already been applied and refuses to
start from any other dirty scope.

Production behavior added by this applicator:
  * top-level Applications entry moves into the privacy/security group;
  * Applications opens the real ManageApplications list directly;
  * top-level Applications summary reports the current-user installed-app count;
  * normal main app rows show concise effective sensitive-permission grants;
  * all other specialized ManageApplications list summaries remain upstream.

UI5B owns deeper AppOps/component/provenance/runtime-evidence presentation.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path

SETTINGS_HEAD = "71bd21cda07f4dfdcec2aabb16bc570be5bd8d35"
SETTINGS_REPO = Path("packages/apps/Settings")

TOP_LEVEL_XMLS = (
    Path("res/xml/top_level_settings.xml"),
    Path("res/xml/top_level_settings_expressive.xml"),
    Path("res/xml/top_level_settings_expressive_desktop.xml"),
)
MANAGE_APPLICATIONS = Path(
    "src/com/android/settings/applications/manageapplications/ManageApplications.java"
)
SUMMARY_HELPER = Path(
    "src/com/android/settings/applications/manageapplications/"
    "SableSensitiveAccessSummary.java"
)
TOP_LEVEL_CONTROLLER = Path(
    "src/com/android/settings/applications/TopLevelApplicationsPreferenceController.java"
)
UI5A_STRINGS = Path("res/values/strings_sable_ui5a.xml")

BRANDING_DIRT = {
    " M res/values/strings_app_exploit_protection.xml",
    " M res/values/strings_ext.xml",
}

UI5A_DIRT = {
    " M res/xml/top_level_settings.xml",
    " M res/xml/top_level_settings_expressive.xml",
    " M res/xml/top_level_settings_expressive_desktop.xml",
    " M src/com/android/settings/applications/manageapplications/ManageApplications.java",
    "?? res/values/strings_sable_ui5a.xml",
    "?? src/com/android/settings/applications/TopLevelApplicationsPreferenceController.java",
    "?? src/com/android/settings/applications/manageapplications/"
    "SableSensitiveAccessSummary.java",
}

MANAGE_OLD = """                case LIST_TYPE_TURN_SCREEN_ON:
                    holder.setSummary(TurnScreenOnDetails.getSummary(mContext, entry));
                    break;
                default:
                    holder.updateSizeText(entry, mManageApplications.mInvalidSizeStr, mWhichSize);
                    break;
"""

MANAGE_NEW = """                case LIST_TYPE_TURN_SCREEN_ON:
                    holder.setSummary(TurnScreenOnDetails.getSummary(mContext, entry));
                    break;
                case LIST_TYPE_MAIN:
                    holder.setSummary(
                            SableSensitiveAccessSummary.getSummary(mContext, entry.info));
                    break;
                default:
                    holder.updateSizeText(entry, mManageApplications.mInvalidSizeStr, mWhichSize);
                    break;
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
        raise SystemExit(
            f"REPLACEMENT_PRECONDITION_FAIL={label} count={count}"
        )
    return text.replace(old, new, 1)


def templates_dir() -> Path:
    return Path(__file__).resolve().parent / "ui5a"


def template_for(dest: Path) -> Path:
    mapping = {
        SUMMARY_HELPER: templates_dir() / "SableSensitiveAccessSummary.java",
        TOP_LEVEL_CONTROLLER:
            templates_dir() / "TopLevelApplicationsPreferenceController.java",
        UI5A_STRINGS: templates_dir() / "strings_sable_ui5a.xml",
    }
    return mapping[dest]


def assert_settings_head(source: Path) -> None:
    actual = run_git(source / SETTINGS_REPO, "rev-parse", "HEAD")
    if actual != SETTINGS_HEAD:
        raise SystemExit(
            f"HEAD_MISMATCH={SETTINGS_REPO} expected={SETTINGS_HEAD} actual={actual}"
        )


def require_branding_only_dirt(source: Path) -> None:
    actual = status_set(source / SETTINGS_REPO)
    if actual != BRANDING_DIRT:
        raise SystemExit(
            "UI5A_PRE_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(BRANDING_DIRT)!r} actual={sorted(actual)!r}"
        )


def extract_apps_block(text: str, label: str) -> tuple[str, int, int]:
    key = 'android:key="top_level_apps"'
    key_index = text.find(key)
    if key_index < 0 or text.find(key, key_index + 1) >= 0:
        raise SystemExit(f"TOP_LEVEL_APPS_KEY_PRECONDITION_FAIL={label}")

    start_token = "        <com.android.settings.widget.HomepagePreference"
    start = text.rfind(start_token, 0, key_index)
    if start < 0:
        raise SystemExit(f"TOP_LEVEL_APPS_START_PRECONDITION_FAIL={label}")

    end = text.find("/>", key_index)
    if end < 0:
        raise SystemExit(f"TOP_LEVEL_APPS_END_PRECONDITION_FAIL={label}")
    end += 2
    if end < len(text) and text[end] == "\n":
        end += 1

    block = text[start:end]
    required = (
        'android:fragment="com.android.settings.applications.AppDashboardFragment"',
        'android:title="@string/apps_dashboard_title"',
        'android:summary="@string/app_and_notification_dashboard_summary"',
        'settings:highlightableMenuKey="@string/menu_key_apps"',
    )
    for needle in required:
        if needle not in block:
            raise SystemExit(
                f"TOP_LEVEL_APPS_BLOCK_PRECONDITION_FAIL={label} missing={needle}"
            )

    return block, start, end


def transform_apps_xml(text: str, label: str) -> str:
    block, start, end = extract_apps_block(text, label)
    text = text[:start] + text[end:]

    block = replace_once(
        block,
        'android:fragment="com.android.settings.applications.AppDashboardFragment"',
        'android:fragment="com.android.settings.applications.manageapplications.'
        'ManageApplications"',
        f"{label}:fragment",
    )
    block = replace_once(
        block,
        'android:title="@string/apps_dashboard_title"',
        'android:title="@string/sable_applications_title"',
        f"{label}:title",
    )
    block = replace_once(
        block,
        'android:summary="@string/app_and_notification_dashboard_summary"',
        'android:summary="@string/sable_applications_summary_loading"',
        f"{label}:summary",
    )
    block = replace_once(
        block,
        'settings:highlightableMenuKey="@string/menu_key_apps"/>',
        'settings:highlightableMenuKey="@string/menu_key_apps"\n'
        '            settings:controller="com.android.settings.applications.'
        'TopLevelApplicationsPreferenceController"/>',
        f"{label}:controller",
    )

    security_key = 'android:key="top_level_security_privacy_category"'
    key_index = text.find(security_key)
    if key_index < 0 or text.find(security_key, key_index + 1) >= 0:
        raise SystemExit(f"SECURITY_CATEGORY_PRECONDITION_FAIL={label}")

    category_start = text.rfind("\n    <", 0, key_index)
    category_end = text.find(">", key_index)
    if category_start < 0 or category_end < 0:
        raise SystemExit(f"SECURITY_CATEGORY_BOUNDARY_FAIL={label}")

    header = text[category_start:category_end + 1]
    header = replace_once(
        header,
        'android:order="-100"',
        'android:order="-125"',
        f"{label}:security-order",
    )
    text = text[:category_start] + header + text[category_end + 1:]

    # category_end may have shifted only by equal-width order replacement.
    key_index = text.find(security_key)
    category_end = text.find(">", key_index)
    insertion = category_end + 1
    text = text[:insertion] + "\n" + block + text[insertion:]
    return text


def verify_templates() -> None:
    for dest in (SUMMARY_HELPER, TOP_LEVEL_CONTROLLER, UI5A_STRINGS):
        template = template_for(dest)
        if not template.is_file():
            raise SystemExit(f"UI5A_TEMPLATE_MISSING={template}")


def apply(source: Path) -> None:
    assert_settings_head(source)
    require_branding_only_dirt(source)
    verify_templates()

    settings = source / SETTINGS_REPO

    for dest in (SUMMARY_HELPER, TOP_LEVEL_CONTROLLER, UI5A_STRINGS):
        if (settings / dest).exists():
            raise SystemExit(f"UI5A_DEST_ALREADY_EXISTS={dest}")

    manage_path = settings / MANAGE_APPLICATIONS
    manage = manage_path.read_text(encoding="utf-8")
    manage = replace_once(
        manage,
        MANAGE_OLD,
        MANAGE_NEW,
        "ManageApplications.main-summary",
    )
    manage_path.write_text(manage, encoding="utf-8")

    for rel in TOP_LEVEL_XMLS:
        path = settings / rel
        text = path.read_text(encoding="utf-8")
        path.write_text(
            transform_apps_xml(text, str(rel)),
            encoding="utf-8",
        )

    for dest in (SUMMARY_HELPER, TOP_LEVEL_CONTROLLER, UI5A_STRINGS):
        dst = settings / dest
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(template_for(dest), dst)

    verify(source)
    print("SABLE_UI5A_APPLY=PASS")


def verify(source: Path) -> None:
    assert_settings_head(source)
    verify_templates()
    settings = source / SETTINGS_REPO

    expected_dirt = BRANDING_DIRT | UI5A_DIRT
    actual_dirt = status_set(settings)
    if actual_dirt != expected_dirt:
        raise SystemExit(
            "UI5A_FINAL_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(expected_dirt)!r} actual={sorted(actual_dirt)!r}"
        )

    manage = (settings / MANAGE_APPLICATIONS).read_text(encoding="utf-8")
    if manage.count(
        "SableSensitiveAccessSummary.getSummary(mContext, entry.info)"
    ) != 1:
        raise SystemExit("UI5A_MANAGE_APPLICATIONS_SUMMARY_VERIFY_FAIL")
    if MANAGE_OLD in manage:
        raise SystemExit("UI5A_MANAGE_APPLICATIONS_OLD_PATH_REMAINS")

    for rel in TOP_LEVEL_XMLS:
        text = (settings / rel).read_text(encoding="utf-8")
        checks = (
            'android:fragment="com.android.settings.applications.manageapplications.'
            'ManageApplications"',
            'android:title="@string/sable_applications_title"',
            'android:summary="@string/sable_applications_summary_loading"',
            'settings:controller="com.android.settings.applications.'
            'TopLevelApplicationsPreferenceController"',
        )
        for needle in checks:
            if text.count(needle) != 1:
                raise SystemExit(
                    f"UI5A_XML_VERIFY_FAIL={rel} needle={needle!r}"
                )

        key = 'android:key="top_level_security_privacy_category"'
        key_index = text.find(key)
        category_end = text.find(">", key_index)
        close_candidates = (
            "</PreferenceCategory>",
            "</com.android.settingslib.widget.UntitledPreferenceCategory>",
        )
        closes = [text.find(x, category_end) for x in close_candidates]
        closes = [x for x in closes if x >= 0]
        if not closes:
            raise SystemExit(f"UI5A_SECURITY_CATEGORY_CLOSE_FAIL={rel}")
        close = min(closes)

        app_index = text.find('android:key="top_level_apps"')
        if not (category_end < app_index < close):
            raise SystemExit(f"UI5A_APPS_NOT_IN_SECURITY_CATEGORY={rel}")

        category_start = text.rfind("\n    <", 0, key_index)
        header = text[category_start:category_end + 1]
        if 'android:order="-125"' not in header:
            raise SystemExit(f"UI5A_SECURITY_ORDER_VERIFY_FAIL={rel}")

    for dest in (SUMMARY_HELPER, TOP_LEVEL_CONTROLLER, UI5A_STRINGS):
        installed = settings / dest
        template = template_for(dest)
        if sha256(installed) != sha256(template):
            raise SystemExit(f"UI5A_TEMPLATE_COPY_VERIFY_FAIL={dest}")

    print("SABLE_UI5A_SETTINGS_SCOPE=PASS")
    print("SABLE_UI5A_REAL_APP_LABELS=UPSTREAM_APPLICATIONS_STATE")
    print("SABLE_UI5A_APP_COUNT=PACKAGE_MANAGER_CURRENT_USER")
    print("SABLE_UI5A_SENSITIVE_SUMMARY=EFFECTIVE_PERMISSION_GRANTS_ONLY")
    print("SABLE_UI5A_DEEP_EVIDENCE=DEFERRED_TO_UI5B")


def self_test() -> None:
    sample = """<PreferenceScreen>
    <PreferenceCategory
        android:order="-120"
        android:key="top_level_personalize_category">
        <com.android.settings.widget.HomepagePreference
            android:fragment="com.android.settings.applications.AppDashboardFragment"
            android:icon="@drawable/ic_apps_filled"
            android:key="top_level_apps"
            android:order="-60"
            android:title="@string/apps_dashboard_title"
            android:summary="@string/app_and_notification_dashboard_summary"
            settings:highlightableMenuKey="@string/menu_key_apps"/>
    </PreferenceCategory>
    <PreferenceCategory
        android:order="-100"
        android:key="top_level_security_privacy_category">
    </PreferenceCategory>
</PreferenceScreen>
"""
    transformed = transform_apps_xml(sample, "self-test")
    required = (
        "ManageApplications",
        "@string/sable_applications_title",
        "TopLevelApplicationsPreferenceController",
        'android:order="-125"',
    )
    for needle in required:
        if needle not in transformed:
            raise SystemExit(f"UI5A_SELF_TEST_FAIL={needle}")

    with tempfile.TemporaryDirectory(prefix="sable-ui5a-selftest-") as td:
        p = Path(td) / "manage.java"
        p.write_text(MANAGE_OLD, encoding="utf-8")
        p.write_text(
            replace_once(
                p.read_text(encoding="utf-8"),
                MANAGE_OLD,
                MANAGE_NEW,
                "self-test-manage",
            ),
            encoding="utf-8",
        )
        if "SableSensitiveAccessSummary" not in p.read_text(encoding="utf-8"):
            raise SystemExit("UI5A_SELF_TEST_MANAGE_FAIL")

    verify_templates()
    print("SABLE_UI5A_SELF_TEST=PASS")
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
