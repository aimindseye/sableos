#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

PINNED = {
    "packages/apps/DeskClock": "7e04cd4bec8c1d9e1579eaa5b3089fe6042a0cb8",
    "packages/apps/DocumentsUI": "ac4670682dd0df3a9798dfb346c57f163d42f7fc",
    "packages/apps/Gallery2": "f5518d09c6e6953eaba6d0c7c23d5a2d766b6525",
    "external/Camera": "1e8ea44155ce3c023d9b1486d57a44268276c315",
    "external/vanadium": "57c3996dfd45e8d9b6f0b15b0753c94acb4282ef",
}

SOURCE_PRESENTATION_FILES = (
    "packages/apps/DeskClock/res/values/colors.xml",
    "packages/apps/DeskClock/res/values/themes.xml",
    "packages/apps/DeskClock/res/values/styles.xml",
    "packages/apps/DocumentsUI/res/values/colors.xml",
    "packages/apps/DocumentsUI/res/values-night/colors.xml",
    "packages/apps/Gallery2/res/values/colors.xml",
    "packages/apps/Gallery2/res/values/styles.xml",
    "packages/apps/Gallery2/res/values/strings.xml",
)

# Each transform accepts either the pristine pinned source token or the exact
# prior R9 dark-only token. This makes an in-place upgrade deterministic while
# keeping a fresh baseline equally valid.
TRANSFORMS = {
    "packages/apps/DeskClock/res/values/colors.xml": (
        (('<color name="clock_gray">#B3FFFFFF</color>',
          '<color name="clock_gray">#FFAAB4C0</color>'),
         '<color name="clock_gray">#FF515B66</color>'),
        (('<color name="default_background">#1A237E</color>',
          '<color name="default_background">#05070A</color>'),
         '<color name="default_background">#F5F7F9</color>\n'
         '    <color name="sable_accent">#FF4D9CFF</color>\n'
         '    <color name="sable_clock_floating">#FFE9EDF2</color>'),
    ),
    "packages/apps/DeskClock/res/values/themes.xml": (
        (('<style name="Theme.DeskClock" parent="Theme.AppCompat.NoActionBar">',),
         '<style name="Theme.DeskClock" parent="Theme.AppCompat.DayNight.NoActionBar">'),
        (('<item name="colorAccent">#DA4336</item>',
          '<item name="colorAccent">#4D9CFF</item>'),
         '<item name="colorAccent">@color/sable_accent</item>'),
        (('<item name="colorBackgroundFloating">#303030</item>',
          '<item name="colorBackgroundFloating">#161C24</item>'),
         '<item name="colorBackgroundFloating">@color/sable_clock_floating</item>'),
        (('<item name="colorControlActivated">@android:color/white</item>',
          '<item name="colorControlActivated">#4D9CFF</item>'),
         '<item name="colorControlActivated">@color/sable_accent</item>'),
    ),
    "packages/apps/DocumentsUI/res/values/colors.xml": (
        (('<color name="primary">#1E88E5</color>',),
         '<color name="primary">#4D9CFF</color>'),
        (('<color name="secondary">#E3F2FD</color>',),
         '<color name="secondary">#E9F2FF</color>'),
    ),
    "packages/apps/DocumentsUI/res/values-night/colors.xml": (
        (('<color name="app_background_color">#202124</color>',),
         '<color name="app_background_color">#05070A</color>'),
        (('<color name="background_floating">#3C4043</color>',),
         '<color name="background_floating">#161C24</color>'),
        (('<color name="primary">#8AB4F8</color>',),
         '<color name="primary">#4D9CFF</color>'),
        (('<color name="secondary">#3D8AB4F8</color>',),
         '<color name="secondary">#334D9CFF</color>'),
        (('<color name="hairline">#5F6368</color>',),
         '<color name="hairline">#526170</color>'),
        (('<color name="doc_list_item_subtitle_enabled">#b3ffffff</color>',),
         '<color name="doc_list_item_subtitle_enabled">#FFAAB4C0</color>'),
    ),
    "packages/apps/Gallery2/res/values/colors.xml": (
        (('<color name="default_background">#000</color>',
          '<color name="default_background">#05070A</color>'),
         '<color name="default_background">#F5F7F9</color>'),
        (('<color name="ic_launcher_gallery_background">#4285f4</color>',),
         '<color name="ic_launcher_gallery_background">#7A42E8</color>'),
        (('<color name="albumset_background">#1A1A1A</color>',
          '<color name="albumset_background">#0D1117</color>'),
         '<color name="albumset_background">#F5F7F9</color>'),
        (('<color name="albumset_placeholder">#333</color>',
          '<color name="albumset_placeholder">#161C24</color>'),
         '<color name="albumset_placeholder">#E9EDF2</color>'),
        (('<color name="albumset_label_background">#EE414143</color>',
          '<color name="albumset_label_background">#EE161C24</color>'),
         '<color name="albumset_label_background">#EEFFFFFF</color>'),
        (('<color name="albumset_label_title">#FBFBFB</color>',),
         '<color name="albumset_label_title">#12171C</color>'),
        (('<color name="albumset_label_count">#A9ABAD</color>',
          '<color name="albumset_label_count">#AAB4C0</color>'),
         '<color name="albumset_label_count">#515B66</color>'),
        (('<color name="album_background">#1A1A1A</color>',
          '<color name="album_background">#0D1117</color>'),
         '<color name="album_background">#F5F7F9</color>'),
        (('<color name="album_placeholder">#333</color>',
          '<color name="album_placeholder">#161C24</color>'),
         '<color name="album_placeholder">#E9EDF2</color>'),
        (('<color name="photo_background">#1A1A1A</color>',
          '<color name="photo_background">#0D1117</color>'),
         '<color name="photo_background">#F5F7F9</color>'),
        (('<color name="photo_placeholder">#333</color>',
          '<color name="photo_placeholder">#161C24</color>'),
         '<color name="photo_placeholder">#E9EDF2</color>'),
        (('<color name="cache_background">#1A1A1A</color>',
          '<color name="cache_background">#0D1117</color>'),
         '<color name="cache_background">#F5F7F9</color>'),
        (('<color name="cache_placeholder">#333</color>',
          '<color name="cache_placeholder">#161C24</color>'),
         '<color name="cache_placeholder">#E9EDF2</color>'),
        (('<color name="bitmap_screennail_placeholder">#333</color>',),
         '<color name="bitmap_screennail_placeholder">#E9EDF2</color>'),
        (('<color name="slideshow_background">#1A1A1A</color>',
          '<color name="slideshow_background">#05070A</color>'),
         '<color name="slideshow_background">#F5F7F9</color>'),
        (('<color name="popup_title_color">#ff33b5e5</color>',
          '<color name="popup_title_color">#FF4D9CFF</color>'),
         '<color name="popup_title_color">#FF4D9CFF</color>'),
        (('<color name="popup_background">#ff282828</color>',),
         '<color name="popup_background">#FFF5F7F9</color>'),
        (('<color name="mode_selection_border">#33B5E5</color>',
          '<color name="mode_selection_border">#4D9CFF</color>'),
         '<color name="mode_selection_border">#4D9CFF</color>'),
        (('<color name="holo_blue_light">#ff33b5e5</color>',
          '<color name="holo_blue_light">#FF4D9CFF</color>'),
         '<color name="holo_blue_light">#FF4D9CFF</color>'),
    ),
    "packages/apps/Gallery2/res/values/styles.xml": (
        (('<style name="Theme.GalleryBase" parent="android:Theme.Holo">',),
         '<style name="Theme.GalleryBase" parent="android:Theme.Holo.Light">'),
        (('<style name="Theme.Gallery.Dialog" parent="android:Theme.Holo.Dialog"/>',),
         '<style name="Theme.Gallery.Dialog" parent="android:Theme.Holo.Light.Dialog"/>'),
        (('<item name="android:windowBackground">@android:color/black</item>',),
         '<item name="android:windowBackground">@color/default_background</item>'),
        (('<style name="Holo.ActionBar" parent="android:Widget.Holo.ActionBar">',),
         '<style name="Holo.ActionBar" parent="android:Widget.Holo.Light.ActionBar">'),
    ),
    "packages/apps/Gallery2/res/values/strings.xml": (
        (('<string name="app_name">Gallery</string>',),
         '<string name="app_name">Photos</string>'),
    ),
}

GENERATED_FILES = {
    "packages/apps/DeskClock/res/values-night/colors.xml": """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="clock_gray">#FFAAB4C0</color>
    <color name="default_background">#05070A</color>
    <color name="sable_accent">#FF4D9CFF</color>
    <color name="sable_clock_floating">#FF161C24</color>
</resources>
""",
    "packages/apps/Gallery2/res/values-night/colors.xml": """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="default_background">#05070A</color>
    <color name="albumset_background">#0D1117</color>
    <color name="albumset_placeholder">#161C24</color>
    <color name="albumset_label_background">#EE161C24</color>
    <color name="albumset_label_title">#F7F9FC</color>
    <color name="albumset_label_count">#AAB4C0</color>
    <color name="album_background">#0D1117</color>
    <color name="album_placeholder">#161C24</color>
    <color name="photo_background">#0D1117</color>
    <color name="photo_placeholder">#161C24</color>
    <color name="cache_background">#0D1117</color>
    <color name="cache_placeholder">#161C24</color>
    <color name="bitmap_screennail_placeholder">#161C24</color>
    <color name="slideshow_background">#05070A</color>
    <color name="popup_title_color">#FF4D9CFF</color>
    <color name="popup_background">#FF161C24</color>
    <color name="mode_selection_border">#4D9CFF</color>
    <color name="holo_blue_light">#FF4D9CFF</color>
</resources>
""",
}


class PresentationError(RuntimeError):
    pass


def git_head(path: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        text=True,
    ).strip()


def require_pins(root: Path) -> None:
    for rel, expected in PINNED.items():
        repo = root / rel
        if not (repo / ".git").exists():
            raise PresentationError(f"missing git repo: {rel}")
        actual = git_head(repo)
        if actual != expected:
            raise PresentationError(
                f"baseline mismatch: {rel} expected={expected} actual={actual}"
            )


def apply_file(
    path: Path,
    transforms: tuple[tuple[tuple[str, ...], str], ...],
) -> None:
    text = path.read_text(encoding="utf-8")
    for old_candidates, new in transforms:
        if new in text:
            continue
        matches = [old for old in old_candidates if text.count(old) == 1]
        if len(matches) != 1:
            raise PresentationError(
                f"anchor mismatch: {path} candidates={old_candidates!r} "
                f"matches={len(matches)}"
            )
        text = text.replace(matches[0], new, 1)
    path.write_text(text, encoding="utf-8")


def verify_file(
    path: Path,
    transforms: tuple[tuple[tuple[str, ...], str], ...],
) -> None:
    text = path.read_text(encoding="utf-8")
    for old_candidates, new in transforms:
        if new not in text:
            raise PresentationError(
                f"presentation token missing: {path} token={new!r}"
            )
        for old in old_candidates:
            if old != new and old in text:
                raise PresentationError(
                    f"stale presentation token remains: {path} token={old!r}"
                )


def apply_deskclock_semantic_text(root: Path) -> None:
    path = root / "packages/apps/DeskClock/res/values/styles.xml"
    text = path.read_text(encoding="utf-8")
    replacements = (
        (
            '<item name="android:textColor">@color/white_63p</item>',
            '<item name="android:textColor">?android:attr/textColorSecondary</item>',
            2,
        ),
        (
            '<item name="android:textColor">@color/white</item>',
            '<item name="android:textColor">?android:attr/textColorPrimary</item>',
            4,
        ),
    )
    for old, new, expected in replacements:
        old_count = text.count(old)
        new_count = text.count(new)
        if old_count == 0 and new_count == expected:
            continue
        if old_count != expected:
            raise PresentationError(
                f"DeskClock semantic text anchor mismatch: {old!r} "
                f"expected={expected} actual={old_count}"
            )
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")


def verify_deskclock_semantic_text(root: Path) -> None:
    text = (
        root / "packages/apps/DeskClock/res/values/styles.xml"
    ).read_text(encoding="utf-8")
    if text.count(
        '<item name="android:textColor">?android:attr/textColorPrimary</item>'
    ) < 4:
        raise PresentationError("DeskClock primary semantic text colors missing")
    if text.count(
        '<item name="android:textColor">?android:attr/textColorSecondary</item>'
    ) < 2:
        raise PresentationError("DeskClock secondary semantic text colors missing")
    for stale in (
        '<style name="Theme.DeskClock" parent="Theme.AppCompat.NoActionBar">',
        '<item name="android:textColor">@color/white</item>',
        '<item name="android:textColor">@color/white_63p</item>',
    ):
        if stale in text:
            raise PresentationError(f"DeskClock stale light-invisible token: {stale}")


def gallery_night_styles(root: Path) -> str:
    text = (
        root / "packages/apps/Gallery2/res/values/styles.xml"
    ).read_text(encoding="utf-8")
    replacements = (
        (
            '<style name="Theme.GalleryBase" parent="android:Theme.Holo.Light">',
            '<style name="Theme.GalleryBase" parent="android:Theme.Holo">',
        ),
        (
            '<style name="Theme.Gallery.Dialog" parent="android:Theme.Holo.Light.Dialog"/>',
            '<style name="Theme.Gallery.Dialog" parent="android:Theme.Holo.Dialog"/>',
        ),
        (
            '<style name="Holo.ActionBar" parent="android:Widget.Holo.Light.ActionBar">',
            '<style name="Holo.ActionBar" parent="android:Widget.Holo.ActionBar">',
        ),
    )
    for old, new in replacements:
        if text.count(old) != 1:
            raise PresentationError(
                f"Gallery day-night style anchor mismatch: {old!r}"
            )
        text = text.replace(old, new, 1)
    return text


def apply_gallery_night_styles(root: Path) -> None:
    path = root / "packages/apps/Gallery2/res/values-night/styles.xml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(gallery_night_styles(root), encoding="utf-8")


def verify_gallery_night_styles(root: Path) -> None:
    path = root / "packages/apps/Gallery2/res/values-night/styles.xml"
    expected = gallery_night_styles(root)
    if not path.is_file() or path.read_text(encoding="utf-8") != expected:
        raise PresentationError("Gallery night style resource drift")


def apply_generated(root: Path) -> None:
    for rel, expected in GENERATED_FILES.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
    apply_gallery_night_styles(root)


def verify_generated(root: Path) -> None:
    for rel, expected in GENERATED_FILES.items():
        path = root / rel
        if not path.is_file():
            raise PresentationError(f"night resource missing: {rel}")
        if path.read_text(encoding="utf-8") != expected:
            raise PresentationError(f"night resource drift: {rel}")
    verify_gallery_night_styles(root)


def verify_binary_boundaries(root: Path) -> None:
    camera_bp = (root / "external/Camera/Android.bp").read_text(encoding="utf-8")
    if 'apk: "prebuilt/app-release.apk"' not in camera_bp:
        raise PresentationError("Camera prebuilt boundary changed")
    if "preprocessed: true" not in camera_bp:
        raise PresentationError("Camera preprocessed boundary changed")

    print("R9_CAMERA_PRESENTATION_BOUNDARY=PASS_UPSTREAM_PREPROCESSED_APK")
    print("R9_VANADIUM_PRESENTATION_BOUNDARY=PASS_UPSTREAM_SECURITY_BUILD")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("mode", choices=("apply", "verify"))
    args = parser.parse_args()

    root = args.source.resolve()
    require_pins(root)

    for rel in SOURCE_PRESENTATION_FILES:
        path = root / rel
        if not path.is_file():
            raise PresentationError(f"missing presentation file: {rel}")

    if args.mode == "apply":
        for rel, transforms in TRANSFORMS.items():
            apply_file(root / rel, transforms)
        apply_deskclock_semantic_text(root)
        apply_generated(root)

    for rel, transforms in TRANSFORMS.items():
        verify_file(root / rel, transforms)
    verify_deskclock_semantic_text(root)
    verify_generated(root)
    verify_binary_boundaries(root)

    print("R9_CLOCK_PRESENTATION=PASS_RESOURCE_ONLY")
    print("R9_CLOCK_DAY_NIGHT_PRESENTATION=PASS_SEMANTIC_TEXT_AND_BACKGROUND")
    print("R9_FILES_PRESENTATION=PASS_RESOURCE_ONLY")
    print("R9_PHOTOS_PRESENTATION=PASS_RESOURCE_ONLY")
    print("R9_PHOTOS_DAY_NIGHT_PRESENTATION=PASS_LIGHT_BASE_DARK_NIGHT_THEME")
    print("R9_CORE_APP_BEHAVIORAL_MUTATION=PASS_ABSENT")
    print("R9_DAILY_DRIVER_CORE_PRESENTATION=PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PresentationError as error:
        print(f"R9_DAILY_DRIVER_CORE_PRESENTATION=FAIL {error}")
        raise SystemExit(1)
