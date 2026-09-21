#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def fail(label: str, detail: str) -> None:
    print(f"{label}=FAIL {detail}", file=sys.stderr)
    raise SystemExit(1)


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        fail(label, f"missing={token!r}")


def require_file(path: pathlib.Path, label: str) -> str:
    if not path.is_file():
        fail(label, f"missing_file={path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    calculator_manifest = require_file(
        ROOT / "apps/r8/android/calculator/src/main/AndroidManifest.xml",
        "R9_ICON_CALCULATOR_MANIFEST",
    )
    calculator_icon = require_file(
        ROOT / "apps/r8/android/calculator/src/main/res/drawable/ic_sable_calculator.xml",
        "R9_ICON_CALCULATOR_ASSET",
    )

    media_manifest = require_file(
        ROOT / "apps/r8/android/media/src/main/AndroidManifest.xml",
        "R9_ICON_MEDIA_MANIFEST",
    )
    media_icon = require_file(
        ROOT / "apps/r8/android/media/src/main/res/drawable/ic_sable_media.xml",
        "R9_ICON_MEDIA_ASSET",
    )

    hub_manifest = require_file(
        ROOT / "apps/r8/android/hub/src/main/AndroidManifest.xml",
        "R9_ICON_HUB_MANIFEST",
    )
    hub_icon = require_file(
        ROOT / "apps/r8/android/hub/src/main/res/drawable/ic_sable_messages.xml",
        "R9_ICON_HUB_ASSET",
    )

    games_manifest = require_file(
        ROOT / "apps/r8/android/games/src/main/AndroidManifest.xml",
        "R9_ICON_GAMES_MANIFEST",
    )
    game_icons = [
        require_file(
            ROOT
            / "apps/r8/android/games/src"
            / flavor
            / "res/drawable/ic_sable_game.xml",
            f"R9_ICON_GAME_{flavor.upper()}_ASSET",
        )
        for flavor in ("sudoku", "minesweeper", "game2048")
    ]

    mail_apply = require_file(
        ROOT / "apps/r8/mail/apply_sable_flavor.py",
        "R9_ICON_MAIL_APPLICATOR",
    )
    mail_verify = require_file(
        ROOT / "apps/r8/mail/verify_sable_mail.py",
        "R9_ICON_MAIL_VERIFIER",
    )

    reader_apply = require_file(
        ROOT / "apps/r8/reader/apply_sable_flavor.py",
        "R9_ICON_READER_APPLICATOR",
    )

    weather_manifest = require_file(
        ROOT / "apps/r8/android/weather/src/main/AndroidManifest.xml",
        "R9_ICON_WEATHER_MANIFEST",
    )
    weather_icon = require_file(
        ROOT / "apps/r8/android/weather/src/main/res/drawable/ic_sable_weather.xml",
        "R9_ICON_WEATHER_ASSET",
    )

    for manifest, icon_ref, label in (
        (
            calculator_manifest,
            "@drawable/ic_sable_calculator",
            "R9_ICON_CALCULATOR_MANIFEST_WIRING",
        ),
        (
            media_manifest,
            "@drawable/ic_sable_media",
            "R9_ICON_MEDIA_MANIFEST_WIRING",
        ),
        (
            hub_manifest,
            "@drawable/ic_sable_messages",
            "R9_ICON_HUB_MANIFEST_WIRING",
        ),
        (
            games_manifest,
            "@drawable/ic_sable_game",
            "R9_ICON_GAMES_MANIFEST_WIRING",
        ),
        (
            weather_manifest,
            "@drawable/ic_sable_weather",
            "R9_ICON_WEATHER_MANIFEST_WIRING",
        ),
    ):
        require(
            manifest,
            f'android:icon="{icon_ref}"',
            label,
        )
        require(
            manifest,
            f'android:roundIcon="{icon_ref}"',
            label,
        )

    for icon_text, label in (
        (calculator_icon, "R9_ICON_CALCULATOR_SABLE_PALETTE"),
        (media_icon, "R9_ICON_MEDIA_SABLE_PALETTE"),
        (hub_icon, "R9_ICON_HUB_SABLE_PALETTE"),
        (weather_icon, "R9_ICON_WEATHER_SABLE_PALETTE"),
        *[
            (text, f"R9_ICON_GAME_{index}_SABLE_PALETTE")
            for index, text in enumerate(game_icons, start=1)
        ],
    ):
        if not any(
            color in icon_text
            for color in (
                "#4D9CFF",
                "#35C66B",
                "#7A42E8",
                "#F28C45",
                "#45515F",
            )
        ):
            fail(label, "missing_sable_palette_color")

    require(
        mail_apply,
        'android:icon="@drawable/ic_sable_mail"',
        "R9_ICON_MAIL_MANIFEST_WIRING",
    )
    require(
        mail_apply,
        "ic_sable_mail.xml",
        "R9_ICON_MAIL_ASSET_GENERATION",
    )
    require(
        mail_verify,
        'android:icon="@drawable/ic_sable_mail"',
        "R9_ICON_MAIL_VERIFY",
    )

    require(
        reader_apply,
        'android:icon="@drawable/ic_sable_reader"',
        "R9_ICON_READER_MANIFEST_WIRING",
    )
    require(
        reader_apply,
        'android:roundIcon="@drawable/ic_sable_reader"',
        "R9_ICON_READER_ROUND_MANIFEST_WIRING",
    )
    require(
        reader_apply,
        "ic_sable_reader.xml",
        "R9_ICON_READER_ASSET_GENERATION",
    )

    product_mk = require_file(
        ROOT / "product/r8/panther/r8-product.mk",
        "R9_ICON_PRODUCT_MANIFEST",
    )
    for package in (
        "SableCalculator",
        "SableSudoku",
        "SableMinesweeper",
        "Sable2048",
        "SableMedia",
        "SableReader",
        "SableHub",
        "SableMail",
        "SableWeather",
    ):
        require(
            product_mk,
            package,
            f"R9_ICON_PRODUCT_{package.upper()}",
        )

    print("R9_FIRST_PARTY_ICON_CALCULATOR=PASS")
    print("R9_FIRST_PARTY_ICON_MEDIA=PASS")
    print("R9_FIRST_PARTY_ICON_MESSAGES=PASS")
    print("R9_FIRST_PARTY_ICON_GAMES=PASS_3")
    print("R9_FIRST_PARTY_ICON_MAIL=PASS")
    print("R9_FIRST_PARTY_ICON_READER=PASS")
    print("R9_FIRST_PARTY_ICON_WEATHER=PASS")
    print("R9_FIRST_PARTY_ICON_PRODUCT_COVERAGE=PASS_9")
    print("R9_FIRST_PARTY_APP_ICON_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
