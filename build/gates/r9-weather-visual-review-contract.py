#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

SETTINGS = ROOT / "apps/r8/android/settings.gradle.kts"
BUILD = ROOT / "apps/r8/android/weather-visual-review/build.gradle.kts"
MANIFEST = ROOT / "apps/r8/android/weather-visual-review/src/main/AndroidManifest.xml"
SRC = (
    ROOT
    / "apps/r8/android/weather-visual-review/src/main/java"
    / "org/sableos/weather/visualreview"
)
DOC = ROOT / "docs/R9_SABLE_WEATHER_VISUAL_REVIEW.md"
RUNNER = ROOT / "build/macos/prepare-r9-weather-visual-review.sh"


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
    doc = DOC.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    require(
        settings,
        'include(":weather-visual-review")',
        "R9_WEATHER_REVIEW_MODULE_REGISTERED",
    )
    require(
        build,
        'applicationId = "org.sableos.weather.visualreview"',
        "R9_WEATHER_REVIEW_APP_ID",
    )
    require(
        build,
        'implementation(project(":design"))',
        "R9_WEATHER_REVIEW_SABLE_DESIGN",
    )

    for token in (
        "android.permission.INTERNET",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
    ):
        forbid(
            manifest,
            token,
            "R9_WEATHER_REVIEW_NO_RUNTIME_PERMISSIONS",
        )

    for token in (
        "HttpURLConnection",
        "URLConnection",
        "OkHttp",
        "Retrofit",
        "java.net.URL",
        "LocationManager",
        "FusedLocationProvider",
        "api.open-meteo.com",
    ):
        forbid(
            source,
            token,
            "R9_WEATHER_REVIEW_NO_NETWORK_OR_LOCATION",
        )

    for token in (
        'title = "weather"',
        'title = "hourly"',
        'title = "7 days"',
        'title = "locations"',
        'title = "weather setup"',
        '"offline forecast"',
        '"Jersey City · cached · last live 47 min ago"',
        '"approximate device location"',
        '"precise location is never required for weather"',
        '"Open-Meteo · cached locally · manual location"',
        "WeatherGlyph(",
        "SableTheme(appearance = appearance)",
    ):
        require(
            source,
            token,
            "R9_WEATHER_REVIEW_VISUAL_CONTRACT",
        )

    for token in (
        "ESP32-S3-Touch-LCD-1.85C-Assistant",
        "c247b208f2a64921cc5b99b516c8a09234a76f50",
        "weather-core",
        "HTTPS transport",
        "LOCAL",
        "FETCHING",
        "LIVE",
        "STALE",
        "FAILED",
        "Sable Start consumes a local Weather snapshot",
    ):
        require(
            doc,
            token,
            "R9_WEATHER_RUST_LINEAGE_CONTRACT",
        )

    for frame in (
        "00-weather-current-light",
        "01-weather-hourly-light",
        "02-weather-daily-light",
        "03-weather-locations-light",
        "04-weather-privacy-light",
        "05-weather-stale-light",
        "06-weather-current-dark",
        "07-weather-daily-dark",
    ):
        require(
            runner,
            frame,
            "R9_WEATHER_REVIEW_CAPTURE_SET",
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
            "weather-visual-review",
            "R9_WEATHER_REVIEW_ABSENT_FROM_PRODUCT",
        )
        forbid(
            text,
            "org.sableos.weather.visualreview",
            "R9_WEATHER_REVIEW_ABSENT_FROM_PRODUCT",
        )

    print("R9_WEATHER_REVIEW_MODULE_REGISTERED=PASS")
    print("R9_WEATHER_REVIEW_SABLE_DESIGN=PASS")
    print("R9_WEATHER_REVIEW_NO_RUNTIME_PERMISSIONS=PASS")
    print("R9_WEATHER_REVIEW_NO_NETWORK_OR_LOCATION=PASS")
    print("R9_WEATHER_RUST_LINEAGE_CONTRACT=PASS")
    print("R9_WEATHER_REVIEW_CAPTURE_SET=PASS")
    print("R9_WEATHER_REVIEW_ABSENT_FROM_PRODUCT=PASS")
    print("R9_WEATHER_PRODUCTION_IMPLEMENTATION=NOT_STARTED_VISUAL_PHASE")
    print("R9_WEATHER_VISUAL_REVIEW_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
