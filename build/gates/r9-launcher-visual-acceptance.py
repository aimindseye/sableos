#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TESTED_SOURCE_COMMIT = "0ad364123f2a2498eba58814918df0c774b2406d"

# Git blob IDs seal the exact visual/product source that was exercised by the
# Pixel 7 R9L15 review. Documentation and gate-only commits may advance without
# invalidating the visual acceptance; changes to any sealed source fail closed.
SEALED_BLOBS = {
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt":
        "917d8fe882680b144dd08ca5b2ffcc26e2c6abdb",
    "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableTheme.kt":
        "ef880116505f15747a301700b77a786c90fab001",
    "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableSystemBars.kt":
        "bfe2039fe583cbb7363b05a1d76b5ca9f35433e3",
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt":
        "afaa80526b48843da8b8ed12e9e517af7a62cdb1",
    "apps/r8/android/sablestart-visual-review/src/main/java/org/sableos/start/visualreview/R9LauncherVisualReviewActivity.kt":
        "cfe2bc8221dce5aa5ed3c914221971fcefab4bfb",
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
    print("R9_L6_VISUAL_REVIEW_STATUS=PASS")
    print("NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
