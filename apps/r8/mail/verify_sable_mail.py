#!/usr/bin/env python3
from __future__ import annotations

import os
import pathlib
import subprocess
import sys

EXPECTED_COMMIT = "c733317d933c22bcd790a4790306f30ccf2026b8"
EXPECTED_PACKAGE = "org.sableos.mail"


def fail(marker: str, detail: str = "") -> None:
    suffix = f" {detail}" if detail else ""
    raise SystemExit(f"{marker}=FAIL{suffix}")


def require_text(path: pathlib.Path, needle: str, marker: str) -> None:
    text = path.read_text(encoding="utf-8")
    if needle not in text:
        fail(marker, f"path={path} missing={needle!r}")


def reject_text(path: pathlib.Path, needle: str, marker: str) -> None:
    text = path.read_text(encoding="utf-8")
    if needle in text:
        fail(marker, f"path={path} forbidden={needle!r}")


def main() -> None:
    if len(sys.argv) not in (2, 3):
        fail("SABLE_MAIL_VERIFY_USAGE", "verify_sable_mail.py <root> [apk]")

    root = pathlib.Path(sys.argv[1]).resolve()
    app = root / "app-thunderbird"

    actual = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        text=True,
    ).strip()
    if actual != EXPECTED_COMMIT:
        fail(
            "SABLE_MAIL_UPSTREAM_COMMIT",
            f"expected={EXPECTED_COMMIT} actual={actual}",
        )
    print(f"SABLE_MAIL_UPSTREAM_COMMIT=PASS value={actual}")

    build = app / "build.gradle.kts"
    require_text(
        build,
        'applicationId = "org.sableos.mail"',
        "SABLE_MAIL_APPLICATION_ID_SOURCE",
    )
    require_text(
        build,
        '"fossImplementation"(projects.feature.funding.noop)',
        "SABLE_MAIL_FUNDING_NOOP",
    )
    reject_text(
        build,
        "projects.feature.thundermail",
        "SABLE_MAIL_THUNDERMAIL_DEPENDENCY",
    )
    require_text(
        build,
        'applicationIdSuffix = ""',
        "SABLE_MAIL_DEBUG_PACKAGE_SUFFIX",
    )
    print("SABLE_MAIL_BUILD_CONFIGURATION=PASS")

    strings = app / "src/main/res/values/strings.xml"
    require_text(strings, ">Sable Mail</string>", "SABLE_MAIL_BRANDING")
    reject_text(strings, ">Thunderbird</string>", "SABLE_MAIL_BRANDING")
    print("SABLE_MAIL_BRANDING=PASS")

    feature_module = (
        app
        / "src/main/kotlin/net/thunderbird/android/feature/FeatureModule.kt"
    )
    reject_text(
        feature_module,
        "featureThundermailModule",
        "SABLE_MAIL_THUNDERMAIL_MODULE",
    )
    print("SABLE_MAIL_THUNDERMAIL=PASS_ABSENT")

    for variant in ("debug", "beta", "daily", "release"):
        oauth = (
            app
            / f"src/{variant}/kotlin/net/thunderbird/android/auth/"
            "TbOAuthConfigurationFactory.kt"
        )
        require_text(oauth, "emptyMap()", "SABLE_MAIL_OAUTH_DISABLED")
        reject_text(oauth, "clientId =", "SABLE_MAIL_INHERITED_OAUTH_CLIENT")
    print("SABLE_MAIL_INHERITED_OAUTH_CLIENTS=PASS_ABSENT")

    appearance = (
        app
        / "src/main/kotlin/net/thunderbird/android/SableMailAppearance.kt"
    )
    for needle in (
        "org.sableos.start.appearance",
        '"follow-system"',
        '"light"',
        '"dark"',
        '"green"',
        '"purple"',
        '"orange"',
        '"slate"',
        "resumedActivity.get()?.recreate()",
    ):
        require_text(
            appearance,
            needle,
            "SABLE_MAIL_GLOBAL_APPEARANCE_SOURCE",
        )

    provider = (
        app
        / "src/main/kotlin/net/thunderbird/android/provider/TbThemeProvider.kt"
    )
    require_text(
        provider,
        "SableMailThemeResources.main(context)",
        "SABLE_MAIL_GLOBAL_THEME_PROVIDER",
    )

    themes = app / "src/main/res/values/sable_mail_themes.xml"
    for accent in ("Blue", "Green", "Purple", "Orange", "Slate"):
        require_text(
            themes,
            f"Theme.SableMail.Light.{accent}",
            "SABLE_MAIL_THEME_SET",
        )
        require_text(
            themes,
            f"Theme.SableMail.Dark.{accent}",
            "SABLE_MAIL_THEME_SET",
        )
    print("SABLE_MAIL_GLOBAL_APPEARANCE_SOURCE=PASS")

    manifest = app / "src/main/AndroidManifest.xml"
    require_text(
        manifest,
        'android:icon="@drawable/ic_sable_mail"',
        "SABLE_MAIL_ICON",
    )
    require_text(
        manifest,
        'android:theme="@style/Theme.SableMail.Startup"',
        "SABLE_MAIL_STARTUP_THEME",
    )
    print("SABLE_MAIL_PRODUCT_BRANDING_SOURCE=PASS")

    if len(sys.argv) == 3:
        apk = pathlib.Path(sys.argv[2]).resolve()
        if not apk.is_file():
            fail("SABLE_MAIL_APK", f"path={apk}")

        apkanalyzer = os.environ.get("APKANALYZER", "apkanalyzer")
        package = subprocess.check_output(
            [apkanalyzer, "manifest", "application-id", str(apk)],
            text=True,
        ).strip()
        if package != EXPECTED_PACKAGE:
            fail(
                "SABLE_MAIL_APK_PACKAGE",
                f"expected={EXPECTED_PACKAGE} actual={package}",
            )

        digest = subprocess.check_output(
            ["sha256sum", str(apk)],
            text=True,
        ).split()[0]
        print(f"SABLE_MAIL_APK_PACKAGE=PASS value={package}")
        print(f"SABLE_MAIL_APK_SHA256={digest}")

    print("SABLE_MAIL_POLICY=PASS")


if __name__ == "__main__":
    main()
