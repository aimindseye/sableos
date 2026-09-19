#!/usr/bin/env python3
"""Apply/verify SableOS UI5B Application Security & Privacy on pinned Settings.

UI5B layers on top of the validated UI5A Settings delta. It adds a read-only
per-app evidence surface backed by PackageManager/AppOps/package metadata and
bounded local APK inspection. Unsupported evidence is rendered UNKNOWN.

No package, permission, AppOp, component, or private-data mutation is performed.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import shutil
import subprocess
import tempfile
from pathlib import Path

SETTINGS_HEAD = "71bd21cda07f4dfdcec2aabb16bc570be5bd8d35"
SETTINGS_REPO = Path("packages/apps/Settings")

APP_INFO_DASHBOARD = Path(
    "src/com/android/settings/applications/appinfo/AppInfoDashboardFragment.java"
)
APP_INFO_XML = Path("res/xml/app_info_settings.xml")

EVIDENCE_FRAGMENT = Path(
    "src/com/android/settings/applications/appinfo/SableAppSecurityPrivacyFragment.java"
)
EVIDENCE_CONTROLLER = Path(
    "src/com/android/settings/applications/appinfo/"
    "SableAppSecurityPrivacyPreferenceController.java"
)
EVIDENCE_XML = Path("res/xml/sable_app_security_privacy.xml")
UI5B_STRINGS = Path("res/values/strings_sable_ui5b.xml")

UI5B_DIRT = {
    " M res/xml/app_info_settings.xml",
    " M src/com/android/settings/applications/appinfo/AppInfoDashboardFragment.java",
    "?? res/values/strings_sable_ui5b.xml",
    "?? res/xml/sable_app_security_privacy.xml",
    "?? src/com/android/settings/applications/appinfo/SableAppSecurityPrivacyFragment.java",
    "?? src/com/android/settings/applications/appinfo/"
    "SableAppSecurityPrivacyPreferenceController.java",
}

DASHBOARD_OLD = """        use(AppPermissionPreferenceController.class).setParentFragment(this);
        use(AppPermissionPreferenceController.class).setPackageName(packageName);
        use(ManageAgentAppFunctionAccessPreferenceController.class).setParentFragment(this);
"""

DASHBOARD_NEW = """        use(AppPermissionPreferenceController.class).setParentFragment(this);
        use(AppPermissionPreferenceController.class).setPackageName(packageName);
        use(SableAppSecurityPrivacyPreferenceController.class).setParentFragment(this);
        use(ManageAgentAppFunctionAccessPreferenceController.class).setParentFragment(this);
"""

XML_ANCHOR = """    <com.android.settingslib.widget.ActionButtonsPreference
        android:key="action_buttons"
        android:order="-9998" />

"""

XML_INSERT = """    <com.android.settingslib.widget.ActionButtonsPreference
        android:key="action_buttons"
        android:order="-9998" />

    <Preference
        android:key="sable_app_security_privacy"
        android:title="@string/sable_app_security_privacy_entry_title"
        android:summary="@string/sable_app_security_privacy_entry_summary"
        android:order="-9997"
        settings:controller="com.android.settings.applications.appinfo.SableAppSecurityPrivacyPreferenceController" />

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
    return Path(__file__).resolve().parent / "ui5b"


def template_for(dest: Path) -> Path:
    mapping = {
        EVIDENCE_FRAGMENT: templates_dir() / "SableAppSecurityPrivacyFragment.java",
        EVIDENCE_CONTROLLER:
            templates_dir() / "SableAppSecurityPrivacyPreferenceController.java",
        EVIDENCE_XML: templates_dir() / "sable_app_security_privacy.xml",
        UI5B_STRINGS: templates_dir() / "strings_sable_ui5b.xml",
    }
    return mapping[dest]


def load_ui5a():
    path = Path(__file__).resolve().with_name("apply_ui5a_settings.py")
    if not path.is_file():
        raise SystemExit(f"UI5A_APPLICATOR_MISSING={path}")
    spec = importlib.util.spec_from_file_location("sable_ui5a_applicator", path)
    if spec is None or spec.loader is None:
        raise SystemExit("UI5A_APPLICATOR_IMPORT_FAIL")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_settings_head(source: Path) -> None:
    actual = run_git(source / SETTINGS_REPO, "rev-parse", "HEAD")
    if actual != SETTINGS_HEAD:
        raise SystemExit(
            f"HEAD_MISMATCH={SETTINGS_REPO} expected={SETTINGS_HEAD} actual={actual}"
        )


def verify_templates() -> None:
    for dest in (
        EVIDENCE_FRAGMENT,
        EVIDENCE_CONTROLLER,
        EVIDENCE_XML,
        UI5B_STRINGS,
    ):
        template = template_for(dest)
        if not template.is_file():
            raise SystemExit(f"UI5B_TEMPLATE_MISSING={template}")


def expected_pre_dirt() -> set[str]:
    ui5a = load_ui5a()
    return set(ui5a.BRANDING_DIRT) | set(ui5a.UI5A_DIRT)


def require_ui5a_state(source: Path) -> None:
    ui5a = load_ui5a()
    ui5a.verify(source)
    actual = status_set(source / SETTINGS_REPO)
    expected = expected_pre_dirt()
    if actual != expected:
        raise SystemExit(
            "UI5B_PRE_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )


def apply(source: Path) -> None:
    assert_settings_head(source)
    verify_templates()
    require_ui5a_state(source)

    settings = source / SETTINGS_REPO
    for dest in (
        EVIDENCE_FRAGMENT,
        EVIDENCE_CONTROLLER,
        EVIDENCE_XML,
        UI5B_STRINGS,
    ):
        if (settings / dest).exists():
            raise SystemExit(f"UI5B_DEST_ALREADY_EXISTS={dest}")

    dashboard_path = settings / APP_INFO_DASHBOARD
    dashboard = dashboard_path.read_text(encoding="utf-8")
    dashboard = replace_once(
        dashboard,
        DASHBOARD_OLD,
        DASHBOARD_NEW,
        "AppInfoDashboardFragment.controller",
    )
    dashboard_path.write_text(dashboard, encoding="utf-8")

    xml_path = settings / APP_INFO_XML
    xml = xml_path.read_text(encoding="utf-8")
    xml = replace_once(
        xml,
        XML_ANCHOR,
        XML_INSERT,
        "app_info_settings.evidence-entry",
    )
    xml_path.write_text(xml, encoding="utf-8")

    for dest in (
        EVIDENCE_FRAGMENT,
        EVIDENCE_CONTROLLER,
        EVIDENCE_XML,
        UI5B_STRINGS,
    ):
        dst = settings / dest
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(template_for(dest), dst)

    verify(source)
    print("SABLE_UI5B_APPLY=PASS")


def verify(source: Path) -> None:
    assert_settings_head(source)
    verify_templates()
    settings = source / SETTINGS_REPO

    expected = expected_pre_dirt() | UI5B_DIRT
    actual = status_set(settings)
    if actual != expected:
        raise SystemExit(
            "UI5B_FINAL_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )

    dashboard = (settings / APP_INFO_DASHBOARD).read_text(encoding="utf-8")
    if dashboard.count(
        "use(SableAppSecurityPrivacyPreferenceController.class).setParentFragment(this);"
    ) != 1:
        raise SystemExit("UI5B_DASHBOARD_CONTROLLER_VERIFY_FAIL")
    if DASHBOARD_OLD in dashboard:
        raise SystemExit("UI5B_DASHBOARD_OLD_PATH_REMAINS")

    xml = (settings / APP_INFO_XML).read_text(encoding="utf-8")
    if xml.count('android:key="sable_app_security_privacy"') != 1:
        raise SystemExit("UI5B_APP_INFO_ENTRY_VERIFY_FAIL")
    if xml.count(
        "com.android.settings.applications.appinfo."
        "SableAppSecurityPrivacyPreferenceController"
    ) != 1:
        raise SystemExit("UI5B_APP_INFO_CONTROLLER_VERIFY_FAIL")

    for dest in (
        EVIDENCE_FRAGMENT,
        EVIDENCE_CONTROLLER,
        EVIDENCE_XML,
        UI5B_STRINGS,
    ):
        installed = settings / dest
        template = template_for(dest)
        if sha256(installed) != sha256(template):
            raise SystemExit(f"UI5B_TEMPLATE_COPY_VERIFY_FAIL={dest}")

    fragment = (settings / EVIDENCE_FRAGMENT).read_text(encoding="utf-8")
    required_semantics = (
        "PackageManager.GET_SIGNING_CERTIFICATES",
        "AppOpsManager.permissionToOp",
        "unsafeCheckOpNoThrow",
        "FLAG_UPDATED_SYSTEM_APP",
        "getInstallSourceInfo",
        "firstInstallTime",
        "lastUpdateTime",
        "ZipFile",
        "sable_unknown_tracker_summary",
        "sable_unknown_network_usage_summary",
        "sable_unknown_history_summary",
    )
    for needle in required_semantics:
        if needle not in fragment:
            raise SystemExit(f"UI5B_SEMANTIC_VERIFY_FAIL={needle}")

    print("SABLE_UI5B_SETTINGS_SCOPE=PASS")
    print("SABLE_UI5B_IDENTITY_PROVENANCE=PACKAGE_MANAGER_BACKED")
    print("SABLE_UI5B_EFFECTIVE_AUTHORITY=PERMISSION_AND_APPOPS_BACKED")
    print("SABLE_UI5B_COMPONENT_SURFACE=PACKAGE_MANAGER_BACKED")
    print("SABLE_UI5B_NATIVE_CODE=LOCAL_APK_STATIC_INFERENCE")
    print("SABLE_UI5B_INSTALL_UPDATE_TIMES=LOCAL_PACKAGE_MANAGER_OBSERVED")
    print("SABLE_UI5B_TRACKER_EXECUTION=UNKNOWN_NOT_INFERRED")
    print("SABLE_UI5B_NETWORK_DESTINATIONS=UNKNOWN_NOT_COLLECTED")
    print("SABLE_UI5B_PERMISSION_HISTORY=UNKNOWN_NOT_RETAINED")
    print("SABLE_UI5B_MUTATING_CONTROLS=NONE")


def self_test() -> None:
    verify_templates()

    dashboard = replace_once(
        DASHBOARD_OLD,
        DASHBOARD_OLD,
        DASHBOARD_NEW,
        "self-test-dashboard",
    )
    if "SableAppSecurityPrivacyPreferenceController" not in dashboard:
        raise SystemExit("UI5B_SELF_TEST_DASHBOARD_FAIL")

    xml = replace_once(
        XML_ANCHOR,
        XML_ANCHOR,
        XML_INSERT,
        "self-test-xml",
    )
    if 'android:key="sable_app_security_privacy"' not in xml:
        raise SystemExit("UI5B_SELF_TEST_XML_FAIL")

    with tempfile.TemporaryDirectory(prefix="sable-ui5b-selftest-") as td:
        root = Path(td)
        for dest in (
            EVIDENCE_FRAGMENT,
            EVIDENCE_CONTROLLER,
            EVIDENCE_XML,
            UI5B_STRINGS,
        ):
            out = root / dest.name
            shutil.copyfile(template_for(dest), out)
            if sha256(out) != sha256(template_for(dest)):
                raise SystemExit(f"UI5B_SELF_TEST_TEMPLATE_FAIL={dest}")

    print("SABLE_UI5B_SELF_TEST=PASS")
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
