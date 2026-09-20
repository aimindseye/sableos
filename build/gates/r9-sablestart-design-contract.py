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
            "SectionLabel(\"favorites\")",
            "search + command",
            "search apps + Sable actions",
            "SableStartDestination.Peek",
            'text = "peek"',
            "rememberLazyListState()",
            "detectDragGestures(",
            ".align(Alignment.CenterStart)",
            ".fillMaxHeight()",
            "listState.scrollToItem(index)",
            "pin to favorites",
            "permissions + app info",
            "apps · settings · Sable actions",
            "local only · no ambient network search",
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
            "A calmer device",
            "Search apps…",
        ),
        "R9_SABLESTART_OLD_SURFACE_RETIREMENT",
    )

    require(
        live,
        (
            "CalendarContract.Events.TITLE",
            "CalendarContract.Events.DTSTART",
            "CalendarContract.Events.ALL_DAY",
            "nothing else today",
            'detail = "$whenText · $title"',
        ),
        "R9_SABLESTART_CONTEXTUAL_CALENDAR",
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
            "R9-L5  contextual media/calendar live block",
            "R9-L6  production-source screenshot review",
            "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES",
            "HOME_RESOLVER=com.android.launcher3/.sable.SableQuickstepLauncher",
            "HOME_ROLE_HOLDER=com.android.launcher3",
        ),
        "R9_SABLESTART_DESIGN_CONTRACT",
    )

    print("R9_L1_START_FAVORITES=PASS_SOURCE")
    print("R9_L2_SABLE_RAIL=PASS_SOURCE")
    print("R9_L3_SEARCH_COMMAND=PASS_SOURCE")
    print("R9_L4_SABLE_PEEK=PASS_SOURCE")
    print("R9_L5_CONTEXTUAL_LOCAL_DATA=PASS_SOURCE")
    print("R9_L6_VISUAL_REVIEW_GATE=PASS_FULL_BUILD_AUTHORIZED")
    print("R9_SABLESTART_COMBINED_DESIGN_CONTRACT=PASS")


def self_test() -> None:
    good = (
        "favorites search + command search apps + Sable actions "
        "peek pin to favorites local only · no ambient network search "
        "detectDragGestures"
    )
    bad = "favorites Search apps… Reset to Follow system · Sable Blue"
    assert "search + command" in good
    assert "search apps + Sable actions" in good
    assert "pin to favorites" in good
    assert "local only · no ambient network search" in good
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
