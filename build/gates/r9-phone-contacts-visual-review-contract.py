#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

SETTINGS = ROOT / "apps/r8/android/settings.gradle.kts"
BUILD = ROOT / "apps/r8/android/phone-contacts-visual-review/build.gradle.kts"
MANIFEST = ROOT / "apps/r8/android/phone-contacts-visual-review/src/main/AndroidManifest.xml"
SRC = (
    ROOT
    / "apps/r8/android/phone-contacts-visual-review/src/main/java"
    / "org/sableos/phonecontacts/visualreview"
)
RUNNER = ROOT / "build/macos/prepare-r9-phone-contacts-visual-review.sh"


def fail(label: str, detail: str) -> None:
    print(f"{label}=FAIL {detail}", file=sys.stderr)
    raise SystemExit(1)


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        fail(label, f"missing={token!r}")


def forbid(text: str, token: str, label: str) -> None:
    if token in text:
        fail(label, f"forbidden={token!r}")


def main() -> int:
    settings = SETTINGS.read_text(encoding="utf-8")
    build = BUILD.read_text(encoding="utf-8")
    manifest = MANIFEST.read_text(encoding="utf-8")
    source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(SRC.glob("*.kt"))
    )
    runner = RUNNER.read_text(encoding="utf-8")

    require(
        settings,
        'include(":phone-contacts-visual-review")',
        "R9_PHONE_CONTACTS_REVIEW_MODULE_REGISTERED",
    )
    require(
        build,
        'applicationId = "org.sableos.phonecontacts.visualreview"',
        "R9_PHONE_CONTACTS_REVIEW_APP_ID",
    )
    require(
        build,
        'implementation(project(":design"))',
        "R9_PHONE_CONTACTS_REVIEW_SABLE_DESIGN",
    )
    forbid(
        manifest,
        "android.intent.category.HOME",
        "R9_PHONE_CONTACTS_REVIEW_NOT_HOME",
    )

    for token in (
        'title = "phone"',
        'title = "dial"',
        'title = "call"',
        'title = "contacts"',
        'title = "contact"',
        '"favorites", "recent", "contacts", "voicemail"',
        'FlatPrimaryAction(text = "dialpad")',
        'FlatDangerAction(text = "end call")',
        'title = "search + add"',
        'FlatPrimaryAction(text = "new contact")',
        '"call"',
        '"message"',
        '"email"',
        "SableTheme(appearance = appearance)",
        "applySableSystemBars(window = window, darkTheme = dark)",
    ):
        require(
            source,
            token,
            "R9_PHONE_CONTACTS_REVIEW_VISUAL_CONTRACT",
        )

    for token in (
        "Android Telecom session",
        "private calls · Android Telecom",
        "account-backed data",
    ):
        forbid(
            source,
            token,
            "R9_PHONE_CONTACTS_REVIEW_NO_IMPLEMENTATION_JARGON",
        )

    for token in (
        'CircleGlyph(glyph = glyph)',
        'ContactAction(glyph = "☎", label = "call")',
        'ContactAction(glyph = "…", label = "message")',
        'ContactAction(glyph = "@", label = "email")',
    ):
        require(
            source,
            token,
            "R9_PHONE_CONTACTS_REVIEW_VISIBLE_ACTION_GLYPHS",
        )

    for token in (
        "HttpURLConnection",
        "URLConnection",
        "OkHttp",
        "Retrofit",
        "java.net.URL",
        "TelecomManager",
        "ContactsContract",
        "CallLog.Calls",
    ):
        forbid(
            source,
            token,
            "R9_PHONE_CONTACTS_REVIEW_NO_RUNTIME_DATA_OR_NETWORK",
        )

    for frame in (
        "00-phone-recents-light",
        "01-phone-dialpad-light",
        "02-phone-in-call-light",
        "03-contacts-list-light",
        "04-contact-detail-light",
        "05-phone-recents-dark",
        "06-contacts-list-dark",
    ):
        require(
            runner,
            frame,
            "R9_PHONE_CONTACTS_REVIEW_CAPTURE_SET",
        )

    product_surfaces = (
        ROOT / "product/r8/panther/r8-product.mk",
        ROOT / "apps/r8/export-panther-app-bundle.sh",
        ROOT / "build/panther/prepare-r8-final-ui.sh",
        ROOT / "build/panther/build-r8-final-ui.sh",
    )
    for path in product_surfaces:
        text = path.read_text(encoding="utf-8")
        forbid(
            text,
            "phone-contacts-visual-review",
            "R9_PHONE_CONTACTS_REVIEW_ABSENT_FROM_PRODUCT",
        )
        forbid(
            text,
            "org.sableos.phonecontacts.visualreview",
            "R9_PHONE_CONTACTS_REVIEW_ABSENT_FROM_PRODUCT",
        )

    print("R9_PHONE_CONTACTS_REVIEW_MODULE_REGISTERED=PASS")
    print("R9_PHONE_CONTACTS_REVIEW_SABLE_DESIGN=PASS")
    print("R9_PHONE_CONTACTS_REVIEW_NOT_HOME=PASS")
    print("R9_PHONE_CONTACTS_REVIEW_NO_RUNTIME_DATA_OR_NETWORK=PASS")
    print("R9_PHONE_CONTACTS_REVIEW_NO_IMPLEMENTATION_JARGON=PASS")
    print("R9_PHONE_CONTACTS_REVIEW_VISIBLE_ACTION_GLYPHS=PASS")
    print("R9_PHONE_CONTACTS_REVIEW_CAPTURE_SET=PASS")
    print("R9_PHONE_CONTACTS_REVIEW_ABSENT_FROM_PRODUCT=PASS")
    print("R9_PHONE_CONTACTS_PLATFORM_SOURCE_MUTATION=NONE_VISUAL_PHASE")
    print("R9_PHONE_CONTACTS_VISUAL_REVIEW_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
