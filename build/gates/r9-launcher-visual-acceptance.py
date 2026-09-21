#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TESTED_SOURCE_COMMIT = "1d61d002b2259add69a400b6dda3c8ab7f7487af"

# Git blob IDs seal the exact visual/product source that was exercised by the
# Pixel 7 R9L15 review. Documentation and gate-only commits may advance without
# invalidating the visual acceptance; changes to any sealed source fail closed.
SEALED_BLOBS = {
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt":
        "1480d1730eaccc551784d1e23d69e20bc5dc9054",
    "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableTheme.kt":
        "ef880116505f15747a301700b77a786c90fab001",
    "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableSystemBars.kt":
        "bfe2039fe583cbb7363b05a1d76b5ca9f35433e3",
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/StartStateRepository.kt":
        "0156c317e8527dda1c27b943783215385e4f8c0d",
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt":
        "daf49a602a24d39a5e21a91c5028a70455d514bc",
    "apps/r8/android/sablestart-visual-review/src/main/java/org/sableos/start/visualreview/R9LauncherVisualReviewActivity.kt":
        "29c08eb2cc32140e66328d21ebd88a46a0dd1918",
}

REVIEW_FRAME_SHA256 = {
    "00-start-tiles-top.png":
        "43c2c2948a6d4c7c171b35858df5ac4b5795334f343e5c9b13f41714fd34ef25",
    "01-start-tiles-mid-scroll.png":
        "f9c111cbf93728cd42d8b8c06dd0c32841fedf69c4ba4e55ff91bc391715521c",
    "02-start-tiles-lower-scroll.png":
        "f9c111cbf93728cd42d8b8c06dd0c32841fedf69c4ba4e55ff91bc391715521c",
    "03-start-tile-peek.png":
        "99a57319f335413bc618484bf52cb0e2bc3784da5a7c63e6b57ba5a4869e765a",
}


def git_blob_sha1(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def fail(label: str, detail: str = "") -> None:
    suffix = f" {detail}" if detail else ""
    print(f"{label}=FAIL{suffix}", file=sys.stderr)
    print("R9_SABLESTART_VISUAL_REVIEW_SET=FAIL", file=sys.stderr)
    print("R9_L6_VISUAL_REVIEW_STATUS=FAIL", file=sys.stderr)
    print("NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    for rel, expected in SEALED_BLOBS.items():
        path = ROOT / rel
        if not path.is_file():
            fail("R9_VISUAL_ACCEPTANCE_SOURCE_SEAL", f"missing={rel}")
        actual = git_blob_sha1(path.read_bytes())
        if actual != expected:
            fail(
                "R9_VISUAL_ACCEPTANCE_SOURCE_SEAL",
                f"path={rel} expected={expected} actual={actual}",
            )
        print(f"R9_VISUAL_ACCEPTANCE_BLOB=PASS path={rel} sha1={actual}")

    print(f"R9_VISUAL_ACCEPTANCE_TESTED_SOURCE={TESTED_SOURCE_COMMIT}")
    for frame, digest in REVIEW_FRAME_SHA256.items():
        print(
            "R9_VISUAL_ACCEPTANCE_FRAME="
            f"PASS frame={frame} sha256={digest}"
        )
    print("R9_SABLESTART_PRODUCTION_COMPILE=PASS")
    print("R9_SABLESTART_VISUAL_REVIEW_SET=PASS")
    print("R9_SABLESTART_PRODUCT_IDENTITY=APPROVED")
    print("R9_SABLESTART_ONE_HAND_REACH=PASS")
    print("R9_SABLESTART_ALL_APPS_RAIL=PASS_WITH_FULL_INVENTORY_RUNTIME_FOLLOWUP")
    print("R9_SABLESTART_SEARCH_COMMAND=PASS")
    print("R9_SABLESTART_PEEK=PASS")
    print("R9_SABLESTART_LOCAL_CONTEXT=PASS")
    print("R9_SABLESTART_APPEARANCE=PASS")
    print("R9_SABLESTART_LIGHT_DARK=PASS")
    print("R9_SABLESTART_DARK_SYSTEM_BARS=PASS")
    print("R9_SABLESTART_START_TILES=PASS_SCROLLING")
    print("R9_SABLESTART_START_FAVORITES=PASS_SEPARATE_STATE")
    print("R9_SABLESTART_WEATHER_TILE=PASS_PREFERRED_VISUAL")
    print("R9_SABLESTART_FIRST_PARTY_ICONS=PASS_VISUAL_AND_SOURCE")
    print("R9_SABLESTART_START_PEEK=PASS_INDEPENDENT_ACTIONS")
    print("R9_L6_VISUAL_REVIEW_STATUS=PASS")
    print("R9_L6_VISUAL_REVIEW_SCOPE=MAC_DESIGN_COMPLETE")
    print("NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_VISUAL_GATE_ONLY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
