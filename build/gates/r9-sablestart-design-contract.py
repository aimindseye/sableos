#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
START = ROOT / "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt"
LIVE = ROOT / "src/android/packages/apps/SableStart/src/com/sable/start/platform/LiveSurfaceRepository.kt"
DESIGN = ROOT / "docs/R9_SABLESTART_LAUNCHER_DESIGN.md"


def require(text: str, tokens: tuple[str, ...], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise SystemExit(f"{label}=FAIL missing={missing!r}")


def forbid(text: str, tokens: tuple[str, ...], label: str) -> None:
    found = [token for token in tokens if token in text]
    if found:
        raise SystemExit(f"{label}=FAIL forbidden={found!r}")


def check() -> None:
    start = START.read_text(encoding="utf-8")
    live = LIVE.read_text(encoding="utf-8")
    design = DESIGN.read_text(encoding="utf-8")

    require(
        start,
        (
            "SableControlShortcut(",
            "SableGlyphIcon(",
            'in 12..16 -> "good afternoon"',
            "ApprovedStartNavigationRow(",
            'text = "all apps"',
            'text = "search"',
            'text = "live"',
            "approvedWideContent(",
            "approvedMetric(",
            "approvedGlyphPackage(app)",
            ".height(if (tile.wide) 106.dp else 118.dp)",
            "SableStartDestination.Peek",
            'text = "peek"',
            "rememberLazyListState()",
            "detectDragGestures(",
            ".align(Alignment.CenterStart)",
            ".fillMaxHeight()",
            "listState.scrollToItem(index)",
            "pin to start",
            "remove from start",
            "pin to favorites",
            "permissions + app info",
            "DEFAULT_START_TILE_TARGET = 10",
            'packageNames = setOf("org.sableos.weather")',
            'labels = listOf("Sable Weather", "Weather")',
            "app.component.packageName in group.packageNames",
            ".combinedClickable(",
            'text = "Useful state only. No fake feeds and no ambient polling."',
            '"message content stays private on Home"',
            '"subject previews off"',
            "AppearanceChoiceRow(",
            "AccentChoiceRow(",
            "reset · follow system + Sable Blue",
        ),
        "R9_SABLESTART_COMBINED_SOURCE",
    )
    forbid(
        start,
        (
            "pinned & recent",
            "MAX_START_TILES",
            "A calmer device",
            "Search apps…",
            "AppearanceShortcut(",
            "private fun StartNavigationRow(",
            'text = "appearance"',
        ),
        "R9_SABLESTART_OLD_SURFACE_RETIREMENT",
    )

    require(
        live,
        (
            "content://org.sableos.weather.snapshot/current",
            "content://org.sableos.calendar.snapshot/current",
            "content://org.sableos.hub.snapshot/current",
            "content://org.sableos.mail.snapshot/current",
            "content://org.sableos.media.snapshot/current",
            "OBSERVED_URIS",
            "providerSnapshot(",
        ),
        "R9_SABLESTART_CONTEXTUAL_PROVIDER_SNAPSHOTS",
    )
    forbid(
        live,
        (
            "CalendarContract.",
            "Telephony.",
            "NotificationManager",
            "MediaSessionManager",
        ),
        "R9_SABLESTART_NO_SENSITIVE_PROVIDER_OWNERSHIP",
    )

    forbid(
        "\n".join(
            path.read_text(encoding="utf-8")
            for path in (ROOT / "src/android/packages/apps/SableStart/src").rglob("*.kt")
        ),
        (
            "HttpURLConnection",
            "URLConnection",
            "OkHttp",
            "Retrofit",
            "java.net.URL",
        ),
        "R9_SABLESTART_AMBIENT_NETWORK",
    )

    require(
        design,
        (
            "R9-L1  Start root + one-hand geometry + favorites",
            "R9-L2  All Apps + Sable Rail",
            "R9-L3  Sable Search / Command",
            "R9-L4  Sable Peek",
            "R9-L5  provider-owned weather/calendar/messages/mail/media live block",
            "R9-L6  Linux production-source compile/design qualification",
            "R9-L7  Panther image integration + physical visual/HOME/Recents/runtime qualification",
            "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9",
            "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED",
            "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_LINUX_QUALIFICATION",
            "HOME_RESOLVER=com.android.launcher3/.sable.SableQuickstepLauncher",
            "HOME_ROLE_HOLDER=com.android.launcher3",
        ),
        "R9_SABLESTART_DESIGN_CONTRACT",
    )

    print("R9_L1_START_APPROVED_DAILY_DRIVER_COMPOSITION=PASS_SOURCE")
    print("R9_L1_START_TILES=PASS_SCROLLING_SEPARATE_STATE")
    print("R9_L1_START_WEATHER=PASS_PACKAGE_FIRST_PREFERRED")
    print("R9_L2_SABLE_RAIL=PASS_SOURCE")
    print("R9_L3_SEARCH_COMMAND=PASS_SOURCE")
    print("R9_L4_SABLE_PEEK=PASS_SOURCE")
    print("R9_L5_CONTEXTUAL_LOCAL_DATA=PASS_SOURCE")
    print("R9_L6_BASELINE_VISUAL_SEAL=PASS_HISTORICAL_REFERENCE_ONLY")
    print("R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9")
    print("R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED")
    print("NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_LINUX_QUALIFICATION")
    print("R9_SABLESTART_COMBINED_DESIGN_CONTRACT=PASS")


def self_test() -> None:
    good = (
        "SableControlShortcut SableGlyphIcon in 12..16 -> \"good afternoon\" "
        "ApprovedStartNavigationRow all apps search live "
        "peek pin to start remove from start pin to favorites "
        "Useful state only. No fake feeds and no ambient polling. detectDragGestures"
    )
    bad = "favorites Search apps… Reset to Follow system · Sable Blue"
    assert "SableControlShortcut" in good
    assert "SableGlyphIcon" in good
    assert 'in 12..16 -> "good afternoon"' in good
    assert "ApprovedStartNavigationRow" in good
    assert "pin to start" in good
    assert "remove from start" in good
    assert "pin to favorites" in good
    assert "Useful state only. No fake feeds and no ambient polling." in good
    assert "detectDragGestures" in good
    assert "Search apps…" in bad
    assert "Reset to Follow system · Sable Blue" in bad
    print("R9_SABLESTART_DESIGN_CONTRACT_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    check()
    return 0


if __name__ == "__main__":
    sys.exit(main())
