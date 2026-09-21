#!/usr/bin/env python3
"""Static contract for the R9 daily-driver visual-design review tranche."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

ACTIVITY = ROOT / "apps/r8/android/sablestart-visual-review/src/main/java/org/sableos/start/visualreview/R9DailyDriverDesignReviewActivity.kt"
MANIFEST = ROOT / "apps/r8/android/sablestart-visual-review/src/main/AndroidManifest.xml"
CAPTURE = ROOT / "build/macos/capture-r9-daily-driver-design-review.sh"
DOC = ROOT / "docs/R9_DAILY_DRIVER_VISUAL_REVIEW.md"
LICENSE = ROOT / "apps/r8/android/sablestart-visual-review/src/main/res/raw/phosphor_icons_license.txt"

PRODUCT_SURFACES = (
    ROOT / "product/r8/panther/r8-product.mk",
    ROOT / "apps/r8/export-panther-app-bundle.sh",
    ROOT / "build/panther/build-r8-final-ui.sh",
    ROOT / "build/panther/prepare-r8-final-ui.sh",
)


def require(path: Path, *needles: str) -> None:
    text = path.read_text(encoding="utf-8")
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"R9_DAILY_DRIVER_DESIGN_CONTRACT=FAIL missing={path}:{needle}")


def forbid(path: Path, *needles: str) -> None:
    text = path.read_text(encoding="utf-8")
    for needle in needles:
        if needle in text:
            raise SystemExit(f"R9_DAILY_DRIVER_DESIGN_CONTRACT=FAIL forbidden={path}:{needle}")


def main() -> int:
    for path in (ACTIVITY, MANIFEST, CAPTURE, DOC, LICENSE, *PRODUCT_SURFACES):
        if not path.is_file():
            raise SystemExit(f"R9_DAILY_DRIVER_DESIGN_CONTRACT=FAIL missing_file={path}")

    require(
        ACTIVITY,
        "class R9DailyDriverDesignReviewActivity",
        "static fixture · visual approval only · no product plumbing",
        "2b75f3ad12b420c9504ef05df8d2564a28f8500e",
        'Icons("icons", "icon system")',
        'StartDark("start-dark", "start · dark")',
        'StartLight("start-light", "start · light")',
        'Live("live", "live")',
        'Calendar("calendar", "calendar")',
        'Clock("clock", "clock")',
        'Camera("camera", "camera")',
        'Files("files", "files")',
        'Photos("photos", "photos")',
        'Browser("browser", "vanadium")',
        'Messages("messages", "messages")',
        "DimensionalLiveTile(",
        "DimensionalWideTile(",
        "SableAppIcon(",
        "PhosphorGlyph(",
        '"message content stays private on Home"',
        '"subject previews off"',
    )

    require(
        MANIFEST,
        'android:name=".R9DailyDriverDesignReviewActivity"',
        'android:label="Sable R9 Daily Driver Design Review"',
    )

    require(
        CAPTURE,
        ":sablestart-visual-review:assembleDebug",
        ".R9DailyDriverDesignReviewActivity",
        "R9_DAILY_DRIVER_VISUAL_DESIGN=PENDING_USER_REVIEW",
        "R9_DAILY_DRIVER_PRODUCTION_PLUMBING_AUTHORIZED=NO",
        "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO",
    )

    require(
        DOC,
        "design-only Mac mini approval tranche / no Panther product plumbing",
        "R9_DAILY_DRIVER_VISUAL_DESIGN=APPROVED",
        "R9_DAILY_DRIVER_PRODUCTION_PLUMBING_AUTHORIZED=YES",
        "R9_DAILY_DRIVER_PRODUCTION_PLUMBING_AUTHORIZED=NO",
    )

    require(
        LICENSE,
        "MIT License",
        "Copyright (c) 2023 Phosphor Icons",
    )

    for surface in PRODUCT_SURFACES:
        forbid(
            surface,
            "R9DailyDriverDesignReviewActivity",
            "r9-daily-driver-design-review",
        )

    print("R9_DAILY_DRIVER_ICON_SOURCE=PASS_PHOSPHOR_PINNED_MIT")
    print("R9_DAILY_DRIVER_REVIEW_FRAME_SET=PASS_11")
    print("R9_DAILY_DRIVER_STATIC_FIXTURE_BOUNDARY=PASS")
    print("R9_DAILY_DRIVER_PRODUCT_GRAPH_INCLUSION=PASS_ABSENT")
    print("R9_DAILY_DRIVER_PRODUCTION_PLUMBING=PASS_NOT_YET_AUTHORIZED")
    print("R9_DAILY_DRIVER_DESIGN_REVIEW_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
