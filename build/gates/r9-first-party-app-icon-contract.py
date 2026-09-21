#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

DIRECT_ICONS = {
    "calculator": ROOT / "apps/r8/android/calculator/src/main/res/drawable/ic_sable_calculator.xml",
    "messages": ROOT / "apps/r8/android/hub/src/main/res/drawable/ic_sable_messages.xml",
    "media": ROOT / "apps/r8/android/media/src/main/res/drawable/ic_sable_media.xml",
    "weather": ROOT / "apps/r8/android/weather/src/main/res/drawable/ic_sable_weather.xml",
    "calendar": ROOT / "apps/r8/android/calendar/src/main/res/drawable/ic_sable_calendar.xml",
    "sudoku": ROOT / "apps/r8/android/games/src/sudoku/res/drawable/ic_sable_game.xml",
    "minesweeper": ROOT / "apps/r8/android/games/src/minesweeper/res/drawable/ic_sable_game.xml",
    "game2048": ROOT / "apps/r8/android/games/src/game2048/res/drawable/ic_sable_game.xml",
}

MANIFESTS = {
    "calculator": (
        ROOT / "apps/r8/android/calculator/src/main/AndroidManifest.xml",
        "@drawable/ic_sable_calculator",
    ),
    "messages": (
        ROOT / "apps/r8/android/hub/src/main/AndroidManifest.xml",
        "@drawable/ic_sable_messages",
    ),
    "media": (
        ROOT / "apps/r8/android/media/src/main/AndroidManifest.xml",
        "@drawable/ic_sable_media",
    ),
    "weather": (
        ROOT / "apps/r8/android/weather/src/main/AndroidManifest.xml",
        "@drawable/ic_sable_weather",
    ),
    "calendar": (
        ROOT / "apps/r8/android/calendar/src/main/AndroidManifest.xml",
        "@drawable/ic_sable_calendar",
    ),
    "games": (
        ROOT / "apps/r8/android/games/src/main/AndroidManifest.xml",
        "@drawable/ic_sable_game",
    ),
}

WEATHER_CONDITION_ICONS = (
    "ic_weather_clear.xml",
    "ic_weather_partly_cloudy.xml",
    "ic_weather_cloudy.xml",
    "ic_weather_fog.xml",
    "ic_weather_rain.xml",
    "ic_weather_snow.xml",
    "ic_weather_storm.xml",
    "ic_weather_unknown.xml",
)

PRODUCT_MODULES = (
    "SableCalculator",
    "SableSudoku",
    "SableMinesweeper",
    "Sable2048",
    "SableMedia",
    "SableReader",
    "SableHub",
    "SableMail",
    "SableWeather",
    "SableCalendar",
)


def fail(label: str, detail: str) -> None:
    print(f"{label}=FAIL {detail}", file=sys.stderr)
    raise SystemExit(1)


def read(path: pathlib.Path, label: str) -> str:
    if not path.is_file():
        fail(label, f"missing_file={path}")
    return path.read_text(encoding="utf-8")


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        fail(label, f"missing={token!r}")


def main() -> int:
    provenance = read(
        ROOT / "third_party/phosphor-icons/PROVENANCE.md",
        "R9_ICON_PHOSPHOR_PROVENANCE",
    )
    license_text = read(
        ROOT / "third_party/phosphor-icons/LICENSE",
        "R9_ICON_PHOSPHOR_LICENSE",
    )
    require(
        provenance,
        "2b75f3ad12b420c9504ef05df8d2564a28f8500e",
        "R9_ICON_PHOSPHOR_PIN",
    )
    require(license_text, "MIT License", "R9_ICON_PHOSPHOR_LICENSE")

    for name, path in DIRECT_ICONS.items():
        text = read(path, f"R9_ICON_{name.upper()}_ASSET")
        for token in (
            'android:viewportWidth="256"',
            'android:fillColor="#161C24"',
            'android:fillColor="#F7F9FC"',
            'android:pathData="M28,226h200v6H28z"',
        ):
            require(
                text,
                token,
                f"R9_ICON_{name.upper()}_APPROVED_LANGUAGE",
            )

    weather_drawable_dir =
        ROOT / "apps/r8/android/weather/src/main/res/drawable"
    for filename in WEATHER_CONDITION_ICONS:
        text = read(
            weather_drawable_dir / filename,
            "R9_ICON_WEATHER_CONDITION_ASSET",
        )
        for token in (
            'android:viewportWidth="256"',
            'android:fillColor="#FFFFFFFF"',
        ):
            require(
                text,
                token,
                "R9_ICON_WEATHER_CONDITION_PHOSPHOR_LANGUAGE",
            )

    for name, (path, ref) in MANIFESTS.items():
        text = read(path, f"R9_ICON_{name.upper()}_MANIFEST")
        require(
            text,
            f'android:icon="{ref}"',
            f"R9_ICON_{name.upper()}_MANIFEST_WIRING",
        )
        require(
            text,
            f'android:roundIcon="{ref}"',
            f"R9_ICON_{name.upper()}_ROUND_WIRING",
        )

    mail_apply = read(
        ROOT / "apps/r8/mail/apply_sable_flavor.py",
        "R9_ICON_MAIL_APPLICATOR",
    )
    for token in (
        'android:icon="@drawable/ic_sable_mail"',
        "ic_sable_mail.xml",
        'android:viewportWidth="256"',
        'android:fillColor="#161C24"',
        'android:fillColor="#F7F9FC"',
        'android:fillColor="#64748B"',
    ):
        require(mail_apply, token, "R9_ICON_MAIL_APPROVED_LANGUAGE")

    mail_verify = read(
        ROOT / "apps/r8/mail/verify_sable_mail.py",
        "R9_ICON_MAIL_VERIFIER",
    )
    require(
        mail_verify,
        'android:icon="@drawable/ic_sable_mail"',
        "R9_ICON_MAIL_VERIFY",
    )

    reader_apply = read(
        ROOT / "apps/r8/reader/apply_sable_flavor.py",
        "R9_ICON_READER_APPLICATOR",
    )
    for token in (
        'android:icon="@drawable/ic_sable_reader"',
        'android:roundIcon="@drawable/ic_sable_reader"',
        "ic_sable_reader.xml",
        'android:viewportWidth="256"',
        'android:fillColor="#161C24"',
        'android:fillColor="#F7F9FC"',
        'android:fillColor="#35C66B"',
    ):
        require(reader_apply, token, "R9_ICON_READER_APPROVED_LANGUAGE")

    product_mk = read(
        ROOT / "product/r8/panther/r8-product.mk",
        "R9_ICON_PRODUCT_MANIFEST",
    )
    for module in PRODUCT_MODULES:
        require(
            product_mk,
            module,
            f"R9_ICON_PRODUCT_{module.upper()}",
        )

    print("R9_FIRST_PARTY_ICON_SOURCE=PASS_PHOSPHOR_PINNED_MIT")
    print("R9_FIRST_PARTY_ICON_LANGUAGE=PASS_TONAL_GLYPH_ACCENT_RAIL")
    print("R9_FIRST_PARTY_ICON_CALCULATOR=PASS")
    print("R9_FIRST_PARTY_ICON_MEDIA=PASS")
    print("R9_FIRST_PARTY_ICON_MESSAGES=PASS")
    print("R9_FIRST_PARTY_ICON_GAMES=PASS_3")
    print("R9_FIRST_PARTY_ICON_MAIL=PASS")
    print("R9_FIRST_PARTY_ICON_READER=PASS")
    print("R9_FIRST_PARTY_ICON_WEATHER=PASS")\n    print("R9_WEATHER_CONDITION_ICONS=PASS_PHOSPHOR_8")
    print("R9_FIRST_PARTY_ICON_CALENDAR=PASS")
    print("R9_FIRST_PARTY_ICON_PRODUCT_COVERAGE=PASS_10")
    print("R9_FIRST_PARTY_APP_ICON_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
