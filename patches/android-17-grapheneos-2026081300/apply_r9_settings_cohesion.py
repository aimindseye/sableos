#!/usr/bin/env python3
"""Apply/verify R9 Settings-hosted Sable system appearance + control surface.

Layering:
  D2+D3 branding -> UI5A -> UI5B -> UI5C -> this applicator.

The appearance provider is hosted by the privileged Settings package so global
Sable presentation state is not owned by Launcher3. It persists in device-
protected storage and restores explicit light/dark through UiModeManager during
locked boot, normal boot and Settings package replacement.
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
FRAMEWORK_MANIFEST = Path("frameworks/base/core/res/AndroidManifest.xml")

MANIFEST = Path("AndroidManifest.xml")
SETTINGS_GATEWAY = Path("src/com/android/settings/core/gateway/SettingsGateway.java")
TOP_LEVEL_XMLS = (
    Path("res/xml/top_level_settings.xml"),
    Path("res/xml/top_level_settings_expressive.xml"),
    Path("res/xml/top_level_settings_expressive_desktop.xml"),
)

CONTRACT = Path("src/com/android/settings/sable/SableAppearanceContract.java")
PROVIDER = Path("src/com/android/settings/sable/SableAppearanceProvider.java")
BOOT_RECEIVER = Path("src/com/android/settings/sable/SableAppearanceBootReceiver.java")
SETTINGS_FRAGMENT = Path("src/com/android/settings/sable/SableAppearanceSettings.java")
NETWORK_MANAGER_FRAGMENT = Path(
    "src/com/android/settings/sable/SableNetworkManagerSettings.java"
)
APPEARANCE_XML = Path("res/xml/sable_appearance_settings.xml")
NETWORK_MANAGER_XML = Path("res/xml/sable_network_manager_settings.xml")
STRINGS = Path("res/values/strings_sable_cohesion.xml")

NEW_FILES = (
    CONTRACT,
    PROVIDER,
    BOOT_RECEIVER,
    SETTINGS_FRAGMENT,
    NETWORK_MANAGER_FRAGMENT,
    APPEARANCE_XML,
    NETWORK_MANAGER_XML,
    STRINGS,
)

COHESION_DIRT = {
    " M AndroidManifest.xml",
    " M src/com/android/settings/core/gateway/SettingsGateway.java",
    " M res/xml/top_level_settings.xml",
    " M res/xml/top_level_settings_expressive.xml",
    " M res/xml/top_level_settings_expressive_desktop.xml",
    "?? res/xml/sable_appearance_settings.xml",
    "?? res/xml/sable_network_manager_settings.xml",
    "?? res/values/strings_sable_cohesion.xml",
    "?? src/com/android/settings/sable/SableAppearanceBootReceiver.java",
    "?? src/com/android/settings/sable/SableAppearanceContract.java",
    "?? src/com/android/settings/sable/SableAppearanceProvider.java",
    "?? src/com/android/settings/sable/SableAppearanceSettings.java",
    "?? src/com/android/settings/sable/SableNetworkManagerSettings.java",
}

PERMISSION_ANCHOR = '    <uses-permission android:name="android.permission.WRITE_SETTINGS" />\n'
PERMISSION_BLOCK = (
    PERMISSION_ANCHOR
    + '    <uses-permission android:name="android.permission.MODIFY_DAY_NIGHT_MODE" />\n'
    + '    <uses-permission android:name="android.permission.GRANT_RUNTIME_PERMISSIONS" />\n'
    + '    <uses-permission android:name="android.permission.REVOKE_RUNTIME_PERMISSIONS" />\n'
)

APP_ANCHOR = '        <uses-library android:name="org.apache.http.legacy" />\n'
APP_BLOCK = APP_ANCHOR + '''
        <provider
            android:name=".sable.SableAppearanceProvider"
            android:authorities="org.sableos.appearance"
            android:exported="true"
            android:directBootAware="true"
            android:grantUriPermissions="false" />

        <receiver
            android:name=".sable.SableAppearanceBootReceiver"
            android:exported="false"
            android:directBootAware="true">
            <intent-filter>
                <action android:name="android.intent.action.LOCKED_BOOT_COMPLETED" />
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
'''

GATEWAY_IMPORT_OLD = "import com.android.settings.safetycenter.MoreSecurityPrivacyFragment;\n"
GATEWAY_IMPORT_NEW = (
    GATEWAY_IMPORT_OLD
    + "import com.android.settings.sable.SableAppearanceSettings;\n"
    + "import com.android.settings.sable.SableNetworkManagerSettings;\n"
)
GATEWAY_ENTRY_OLD = """    public static final String[] ENTRY_FRAGMENTS = {
            com.android.settings.applications.AppNativeDebuggingFragment.class.getName(),
"""
GATEWAY_ENTRY_NEW = """    public static final String[] ENTRY_FRAGMENTS = {
            SableAppearanceSettings.class.getName(),
            SableNetworkManagerSettings.class.getName(),
            com.android.settings.applications.AppNativeDebuggingFragment.class.getName(),
"""

APPEARANCE_BLOCK = '''        <com.android.settings.widget.HomepagePreference
            android:fragment="com.android.settings.sable.SableAppearanceSettings"
            android:icon="@drawable/ic_settings_display_filled"
            android:key="top_level_sable_appearance"
            android:order="-70"
            android:title="@string/sable_appearance_title"
            android:summary="@string/sable_appearance_summary"
            settings:highlightableMenuKey="@string/menu_key_display"/>

'''

NETWORK_MANAGER_BLOCK = '''        <com.android.settings.widget.HomepagePreference
            android:fragment="com.android.settings.sable.SableNetworkManagerSettings"
            android:icon="@drawable/ic_settings_wireless_filled"
            android:key="top_level_sable_network_manager"
            android:order="-25"
            android:title="@string/sable_network_manager_title"
            android:summary="@string/sable_network_manager_summary"
            settings:highlightableMenuKey="@string/menu_key_privacy"/>

'''

MESSAGES_BLOCK = '''        <com.android.settings.widget.HomepagePreference
            android:icon="@drawable/ic_settings_privacy_filled"
            android:key="top_level_sable_messages"
            android:order="-24"
            android:title="@string/sable_messages_settings_title"
            android:summary="@string/sable_messages_settings_summary"
            settings:highlightableMenuKey="@string/menu_key_privacy">
            <intent
                android:action="org.sableos.hub.action.CONNECTED_APPS"
                android:targetPackage="org.sableos.hub"
                android:targetClass="org.sableos.hub.ConnectedAppsActivity" />
        </com.android.settings.widget.HomepagePreference>

'''


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


def load_module(filename: str, module_name: str):
    path = Path(__file__).resolve().with_name(filename)
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"MODULE_IMPORT_FAIL={path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def templates_dir() -> Path:
    return Path(__file__).resolve().parent / "r9_settings_cohesion"


def template_for(dest: Path) -> Path:
    mapping = {
        CONTRACT: templates_dir() / "SableAppearanceContract.java",
        PROVIDER: templates_dir() / "SableAppearanceProvider.java",
        BOOT_RECEIVER: templates_dir() / "SableAppearanceBootReceiver.java",
        SETTINGS_FRAGMENT: templates_dir() / "SableAppearanceSettings.java",
        NETWORK_MANAGER_FRAGMENT: templates_dir() / "SableNetworkManagerSettings.java",
        APPEARANCE_XML: templates_dir() / "sable_appearance_settings.xml",
        NETWORK_MANAGER_XML: templates_dir() / "sable_network_manager_settings.xml",
        STRINGS: templates_dir() / "strings_sable_cohesion.xml",
    }
    return mapping[dest]


def expected_pre_dirt() -> set[str]:
    ui5b = load_module("apply_ui5b_app_security.py", "sable_ui5b_for_cohesion")
    ui5c = load_module(
        "apply_ui5c_ui6_system_surfaces.py",
        "sable_ui5c_for_cohesion",
    )
    return set(ui5c.expected_settings_pre_dirt(ui5b)) | set(ui5c.SETTINGS_EXTRA_DIRT)


def classify_dirty_scope(actual: set[str]) -> str:
    pre = expected_pre_dirt()
    final = pre | COHESION_DIRT
    if actual == pre:
        return "PRE_COHESION"
    if actual == final:
        return "FINAL_COHESION"
    raise SystemExit(
        "R9_SETTINGS_COHESION_DIRTY_SCOPE_MISMATCH="
        f"expected_pre={sorted(pre)!r} expected_final={sorted(final)!r} "
        f"actual={sorted(actual)!r}"
    )


def assert_head(source: Path) -> None:
    actual = run_git(source / SETTINGS_REPO, "rev-parse", "HEAD")
    if actual != SETTINGS_HEAD:
        raise SystemExit(
            f"HEAD_MISMATCH={SETTINGS_REPO} expected={SETTINGS_HEAD} actual={actual}"
        )


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"REPLACEMENT_PRECONDITION_FAIL={label} count={count}")
    return text.replace(old, new, 1)


def insert_into_category(
    text: str,
    category_key: str,
    entry_key: str,
    block: str,
    label: str,
) -> str:
    if entry_key in text:
        return text

    key_index = text.find(category_key)
    if key_index < 0 or text.find(category_key, key_index + 1) >= 0:
        raise SystemExit(f"SABLE_SETTINGS_CATEGORY_PRECONDITION_FAIL={label}:{category_key}")

    category_end = text.find(">", key_index)
    if category_end < 0:
        raise SystemExit(f"SABLE_SETTINGS_CATEGORY_BOUNDARY_FAIL={label}:{category_key}")

    insertion = category_end + 1
    return text[:insertion] + "\n" + block + text[insertion:]


def transform_top_level(text: str, label: str) -> str:
    text = insert_into_category(
        text,
        'android:key="top_level_personalize_category"',
        'android:key="top_level_sable_appearance"',
        APPEARANCE_BLOCK,
        label,
    )
    text = insert_into_category(
        text,
        'android:key="top_level_security_privacy_category"',
        'android:key="top_level_sable_network_manager"',
        NETWORK_MANAGER_BLOCK,
        label,
    )
    text = insert_into_category(
        text,
        'android:key="top_level_security_privacy_category"',
        'android:key="top_level_sable_messages"',
        MESSAGES_BLOCK,
        label,
    )
    return text


def verify_templates() -> None:
    for dest in NEW_FILES:
        path = template_for(dest)
        if not path.is_file():
            raise SystemExit(f"SABLE_SETTINGS_COHESION_TEMPLATE_MISSING={path}")


def apply(source: Path) -> None:
    assert_head(source)
    verify_templates()
    settings = source / SETTINGS_REPO

    actual = status_set(settings)
    scope = classify_dirty_scope(actual)
    print(f"R9_SETTINGS_COHESION_INPUT_SCOPE={scope}")

    if scope == "PRE_COHESION":
        for dest in NEW_FILES:
            if (settings / dest).exists():
                raise SystemExit(
                    f"R9_SETTINGS_COHESION_DEST_ALREADY_EXISTS={dest}"
                )
    else:
        print("R9_SETTINGS_COHESION_UPGRADE_IN_PLACE=AUTHORIZED_BOUNDED_FINAL_SCOPE")

    manifest_path = settings / MANIFEST
    manifest = manifest_path.read_text(encoding="utf-8")
    manifest = replace_once(
        manifest,
        PERMISSION_ANCHOR,
        PERMISSION_BLOCK,
        "settings:modify-day-night-permission",
    )
    manifest = replace_once(
        manifest,
        APP_ANCHOR,
        APP_BLOCK,
        "settings:sable-appearance-components",
    )
    manifest_path.write_text(manifest, encoding="utf-8")

    for rel in TOP_LEVEL_XMLS:
        path = settings / rel
        path.write_text(
            transform_top_level(path.read_text(encoding="utf-8"), str(rel)),
            encoding="utf-8",
        )

    gateway_path = settings / SETTINGS_GATEWAY
    gateway = gateway_path.read_text(encoding="utf-8")
    gateway = replace_once(
        gateway,
        GATEWAY_IMPORT_OLD,
        GATEWAY_IMPORT_NEW,
        "settings-gateway:appearance-import",
    )
    gateway = replace_once(
        gateway,
        GATEWAY_ENTRY_OLD,
        GATEWAY_ENTRY_NEW,
        "settings-gateway:appearance-entry",
    )
    gateway_path.write_text(gateway, encoding="utf-8")

    for dest in NEW_FILES:
        dst = settings / dest
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(template_for(dest), dst)

    verify(source)
    if scope == "FINAL_COHESION":
        print("R9_SETTINGS_COHESION_UPGRADE_IN_PLACE=PASS")
    print("R9_SETTINGS_COHESION_APPLY=PASS")


def verify(source: Path) -> None:
    assert_head(source)
    verify_templates()
    settings = source / SETTINGS_REPO

    expected = expected_pre_dirt() | COHESION_DIRT
    actual = status_set(settings)
    if actual != expected:
        raise SystemExit(
            "R9_SETTINGS_COHESION_FINAL_DIRTY_SCOPE_MISMATCH="
            f"expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )

    framework_manifest = (source / FRAMEWORK_MANIFEST).read_text(encoding="utf-8")
    network_permission_anchor = '<permission android:name="android.permission.INTERNET"'
    network_index = framework_manifest.find(network_permission_anchor)
    if network_index < 0:
        raise SystemExit("R9_GRAPHENE_NETWORK_PERMISSION_MISSING")
    network_end = framework_manifest.find("/>", network_index)
    if network_end < 0:
        raise SystemExit("R9_GRAPHENE_NETWORK_PERMISSION_DEFINITION_INVALID")
    network_definition = framework_manifest[network_index:network_end + 2]
    if 'android:protectionLevel="dangerous|instant"' not in network_definition:
        raise SystemExit(
            "R9_GRAPHENE_NETWORK_PERMISSION_NOT_RUNTIME_REVOKABLE="
            + network_definition.replace("\n", " ")
        )

    manifest = (settings / MANIFEST).read_text(encoding="utf-8")
    required_manifest = (
        'android.permission.MODIFY_DAY_NIGHT_MODE',
        'android.permission.GRANT_RUNTIME_PERMISSIONS',
        'android.permission.REVOKE_RUNTIME_PERMISSIONS',
        'android:name=".sable.SableAppearanceProvider"',
        'android:authorities="org.sableos.appearance"',
        'android:name=".sable.SableAppearanceBootReceiver"',
        'android.intent.action.LOCKED_BOOT_COMPLETED',
        'android.intent.action.BOOT_COMPLETED',
        'android.intent.action.MY_PACKAGE_REPLACED',
    )
    for needle in required_manifest:
        if needle not in manifest:
            raise SystemExit(f"R9_SETTINGS_COHESION_MANIFEST_MISSING={needle}")

    gateway = (settings / SETTINGS_GATEWAY).read_text(encoding="utf-8")
    for needle in (
        "import com.android.settings.sable.SableAppearanceSettings;",
        "import com.android.settings.sable.SableNetworkManagerSettings;",
        "SableAppearanceSettings.class.getName(),",
        "SableNetworkManagerSettings.class.getName(),",
    ):
        if gateway.count(needle) != 1:
            raise SystemExit(f"R9_SETTINGS_GATEWAY_APPEARANCE_ENTRY_FAIL={needle}")

    for rel in TOP_LEVEL_XMLS:
        text = (settings / rel).read_text(encoding="utf-8")
        if text.count('android:key="top_level_sable_appearance"') != 1:
            raise SystemExit(f"R9_SETTINGS_APPEARANCE_ENTRY_FAIL={rel}")
        if "com.android.settings.sable.SableAppearanceSettings" not in text:
            raise SystemExit(f"R9_SETTINGS_APPEARANCE_FRAGMENT_FAIL={rel}")
        if text.count('android:key="top_level_sable_network_manager"') != 1:
            raise SystemExit(f"R9_SETTINGS_NETWORK_MANAGER_ENTRY_FAIL={rel}")
        if "com.android.settings.sable.SableNetworkManagerSettings" not in text:
            raise SystemExit(f"R9_SETTINGS_NETWORK_MANAGER_FRAGMENT_FAIL={rel}")
        if text.count('android:key="top_level_sable_messages"') != 1:
            raise SystemExit(f"R9_SETTINGS_MESSAGES_ENTRY_FAIL={rel}")
        for needle in (
            'android:action="org.sableos.hub.action.CONNECTED_APPS"',
            'android:targetPackage="org.sableos.hub"',
            'android:targetClass="org.sableos.hub.ConnectedAppsActivity"',
        ):
            if needle not in text:
                raise SystemExit(f"R9_SETTINGS_MESSAGES_INTENT_FAIL={rel}:{needle}")

    for dest in NEW_FILES:
        installed = settings / dest
        if sha256(installed) != sha256(template_for(dest)):
            raise SystemExit(f"R9_SETTINGS_COHESION_TEMPLATE_COPY_FAIL={dest}")

    contract = (settings / CONTRACT).read_text(encoding="utf-8")
    if 'AUTHORITY = "org.sableos.appearance"' not in contract:
        raise SystemExit("R9_SETTINGS_APPEARANCE_AUTHORITY_CONTRACT_MISSING")
    if 'Uri.parse("content://" + AUTHORITY + "/" + PATH_APPEARANCE)' not in contract:
        raise SystemExit("R9_SETTINGS_APPEARANCE_CONTENT_URI_CONTRACT_MISSING")

    provider = (settings / PROVIDER).read_text(encoding="utf-8")
    required_provider = (
        "createDeviceProtectedStorageContext()",
        "MODE_NIGHT_NO",
        "MODE_NIGHT_YES",
        "KEY_NIGHT_MODE_BEFORE_OVERRIDE",
        'contains("org.sableos.launcher")',
        "notifyChange(",
    )
    # AUTHORITY lives in the contract; the provider must reference the contract.
    if "SableAppearanceContract.CONTENT_URI" not in provider:
        raise SystemExit("R9_SETTINGS_APPEARANCE_PROVIDER_CONTRACT_MISSING")
    if 'contains("com.android.launcher3")' in provider:
        raise SystemExit("R9_SETTINGS_APPEARANCE_PROVIDER_STALE_LAUNCHER3_WRITER")
    if "private Context requireContext()" in provider:
        raise SystemExit("R9_SETTINGS_PROVIDER_REQUIRE_CONTEXT_COLLISION")
    if "private Context requireProviderContext()" not in provider:
        raise SystemExit("R9_SETTINGS_PROVIDER_CONTEXT_HELPER_MISSING")
    for needle in required_provider:
        if needle not in provider:
            raise SystemExit(f"R9_SETTINGS_APPEARANCE_PROVIDER_MISSING={needle}")

    receiver = (settings / BOOT_RECEIVER).read_text(encoding="utf-8")
    if "SableAppearanceProvider.applyStoredMode(context)" not in receiver:
        raise SystemExit("R9_SETTINGS_APPEARANCE_BOOT_RESTORE_MISSING")

    network_manager = (settings / NETWORK_MANAGER_FRAGMENT).read_text(encoding="utf-8")
    for needle in (
        "Manifest.permission.INTERNET",
        "PermissionManager",
        "grantRuntimePermission(",
        "revokeRuntimePermission(",
        "FLAG_PERMISSION_SYSTEM_FIXED",
        "FLAG_PERMISSION_POLICY_FIXED",
        "PackageManager.GET_PERMISSIONS",
    ):
        if needle not in network_manager:
            raise SystemExit(f"R9_SETTINGS_NETWORK_MANAGER_MISSING={needle}")

    print("R9_SYSTEM_APPEARANCE_AUTHORITY=PASS_SETTINGS_HOSTED")
    print("R9_SYSTEM_APPEARANCE_DEVICE_PROTECTED_STORAGE=PASS")
    print("R9_SYSTEM_APPEARANCE_BOOT_RESTORE_SOURCE=PASS")
    print("R9_SETTINGS_PROVIDER_CONTENTPROVIDER_API_COMPAT=PASS")
    print("R9_SETTINGS_APPEARANCE_ENTRY=PASS")
    print("R9_SETTINGS_APPEARANCE_GATEWAY=PASS")
    print("R9_GRAPHENE_NETWORK_PERMISSION_BASE=PASS_DANGEROUS_INSTANT")
    print("R9_SETTINGS_NETWORK_MANAGER=PASS_GRAPHENE_NETWORK_PERMISSION")
    print("R9_SETTINGS_NETWORK_MANAGER_TRANSPORT_SCOPE=ALL_NETWORKS_NOT_MOBILE_WIFI_SPLIT")
    print("R9_SETTINGS_MESSAGES_CONNECTED_APPS_ENTRY=PASS")
    print("R9_SETTINGS_COHESION=PASS")


def self_test() -> None:
    verify_templates()

    sample_manifest = (
        '<manifest>\n'
        + PERMISSION_ANCHOR
        + '<application>\n'
        + APP_ANCHOR
        + '</application>\n'
        + '</manifest>\n'
    )
    out = replace_once(
        sample_manifest,
        PERMISSION_ANCHOR,
        PERMISSION_BLOCK,
        "self-test-permission",
    )
    out = replace_once(out, APP_ANCHOR, APP_BLOCK, "self-test-components")
    for needle in (
        "MODIFY_DAY_NIGHT_MODE",
        "SableAppearanceProvider",
        "SableAppearanceBootReceiver",
    ):
        if needle not in out:
            raise SystemExit(f"R9_SETTINGS_COHESION_SELF_TEST_MANIFEST_FAIL={needle}")

    sample_xml = """<PreferenceScreen>
    <PreferenceCategory
        android:order="-120"
        android:key="top_level_personalize_category">
    </PreferenceCategory>
    <PreferenceCategory
        android:order="-100"
        android:key="top_level_security_privacy_category">
    </PreferenceCategory>
</PreferenceScreen>
"""
    transformed = transform_top_level(sample_xml, "self-test")
    for needle in (
        "top_level_sable_messages",
        "org.sableos.hub.action.CONNECTED_APPS",
        "org.sableos.hub.ConnectedAppsActivity",
    ):
        if needle not in transformed:
            raise SystemExit(f"R9_SETTINGS_COHESION_SELF_TEST_MESSAGES_FAIL={needle}")
    if transformed.count('android:key="top_level_sable_appearance"') != 1:
        raise SystemExit("R9_SETTINGS_COHESION_SELF_TEST_TOP_LEVEL_FAIL")
    if transformed.count('android:key="top_level_sable_network_manager"') != 1:
        raise SystemExit("R9_SETTINGS_COHESION_SELF_TEST_NETWORK_MANAGER_FAIL")

    gateway_sample = GATEWAY_IMPORT_OLD + GATEWAY_ENTRY_OLD
    gateway_sample = replace_once(
        gateway_sample,
        GATEWAY_IMPORT_OLD,
        GATEWAY_IMPORT_NEW,
        "self-test-gateway-import",
    )
    gateway_sample = replace_once(
        gateway_sample,
        GATEWAY_ENTRY_OLD,
        GATEWAY_ENTRY_NEW,
        "self-test-gateway-entry",
    )
    if "SableAppearanceSettings.class.getName()," not in gateway_sample:
        raise SystemExit("R9_SETTINGS_COHESION_SELF_TEST_GATEWAY_FAIL")
    if "SableNetworkManagerSettings.class.getName()," not in gateway_sample:
        raise SystemExit("R9_SETTINGS_COHESION_SELF_TEST_NETWORK_GATEWAY_FAIL")

    if "FINAL_COHESION" not in classify_dirty_scope.__code__.co_consts:
        raise SystemExit("R9_SETTINGS_COHESION_SELF_TEST_SCOPE_CLASSIFIER_FAIL")
    print("R9_SETTINGS_COHESION_SELF_TEST_UPGRADE_SCOPE=PASS")
    print("R9_SETTINGS_COHESION_SELF_TEST=PASS")
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
