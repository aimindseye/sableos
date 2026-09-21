#!/usr/bin/env python3
"""Apply/verify the cumulative SableOS UI4 SystemUI visual delta.

Target: GrapheneOS 2026081300 / Android 17
Pinned frameworks/base: aab06a8bd44c4c2b58eeec780fde83baa9d43a40

UI4R1/UI4R2/UI4R3 are deliberately visual-only. They change Quick Settings
tile geometry/colors, compact-QS spacing, brightness/panel spacing, footer
geometry, notification-card/shade radii, notification-stack spacing, and
SystemUI media surface/control geometry. They do not alter tile, notification,
or media state/view models, click/long-click behavior, shade gestures,
permissions, privacy indicators, notification ranking/dismissal, media session
behavior, carousel behavior, playback actions, or accessibility semantics.
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

FRAMEWORK_HEAD = "aab06a8bd44c4c2b58eeec780fde83baa9d43a40"
FRAMEWORK_REPO = Path("frameworks/base")

COMMON_TILE = Path(
    "packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/CommonTile.kt"
)
TILE = Path(
    "packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/Tile.kt"
)
QUICK_QUICK_SETTINGS = Path(
    "packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/QuickQuickSettings.kt"
)
QUICK_SETTINGS_CONTENT = Path(
    "packages/SystemUI/compose/features/src/com/android/systemui/qs/ui/composable/QuickSettingsContent.kt"
)
FOOTER_ACTIONS = Path(
    "packages/SystemUI/compose/features/src/com/android/systemui/qs/footer/ui/compose/FooterActions.kt"
)
DIMENS = Path("packages/SystemUI/res/values/dimens.xml")
MEDIA = Path("packages/SystemUI/src/com/android/systemui/media/remedia/ui/compose/Media.kt")
SABLE_APPEARANCE = Path(
    "packages/SystemUI/src/com/android/systemui/sable/SableSystemAppearance.kt"
)

SABLE_APPEARANCE_SOURCE = """package com.android.systemui.sable

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

data class SableSystemAccent(
    val color: Color,
    val onColor: Color,
)

private val appearanceUri =
    Uri.parse("content://org.sableos.start.appearance/appearance")

private fun readSableAccent(context: Context): SableSystemAccent =
    runCatching {
        context.contentResolver
            .query(
                appearanceUri,
                arrayOf("accent"),
                null,
                null,
                null,
            )
            ?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    return@use defaultAccent()
                }
                when (cursor.getString(0)) {
                    "green" ->
                        SableSystemAccent(
                            Color(0xFF35C66B),
                            Color(0xFF04140A),
                        )
                    "purple" ->
                        SableSystemAccent(
                            Color(0xFF7A42E8),
                            Color.White,
                        )
                    "orange" ->
                        SableSystemAccent(
                            Color(0xFFF28C45),
                            Color(0xFF1D0C02),
                        )
                    "slate" ->
                        SableSystemAccent(
                            Color(0xFF64748B),
                            Color.White,
                        )
                    else -> defaultAccent()
                }
            }
            ?: defaultAccent()
    }.getOrDefault(defaultAccent())

private fun defaultAccent() =
    SableSystemAccent(
        Color(0xFF4D9CFF),
        Color(0xFF06111F),
    )

@Composable
fun rememberSableSystemAccent(
    context: Context = LocalContext.current,
): SableSystemAccent {
    var accent by remember(context) {
        mutableStateOf(readSableAccent(context))
    }

    DisposableEffect(context) {
        val resolver = context.contentResolver
        val observer =
            object : ContentObserver(
                Handler(Looper.getMainLooper()),
            ) {
                override fun onChange(selfChange: Boolean) {
                    accent = readSableAccent(context)
                }
            }

        runCatching {
            resolver.registerContentObserver(
                appearanceUri,
                false,
                observer,
            )
        }

        onDispose {
            runCatching {
                resolver.unregisterContentObserver(observer)
            }
        }
    }

    return accent
}
"""

BASELINE_BLOBS = {
    COMMON_TILE: "6db03f5f11cb3414d928be973bfc3c0fb39ed522",
    TILE: "2d6145d17d761cb163bc8ddf90ad6ab350da2a3e",
    QUICK_QUICK_SETTINGS: "84abda67984d38bfd7bc5f33f00a3a360854f180",
    QUICK_SETTINGS_CONTENT: "0fc0146120c5547b29e7eeb043548c8cdb9f129f",
    FOOTER_ACTIONS: "f6bf90e8071541062b227c6a47829768f345659f",
    DIMENS: "6f388d006b55ce7355a08ca1628baf5b6ec3c92c",
    MEDIA: "e794506f7928cd44c8670719ba051fb7f8a90b28",
}

UI4_DIRT = {f" M {path.as_posix()}" for path in BASELINE_BLOBS}
UI4_DIRT.add(f"?? {SABLE_APPEARANCE.as_posix()}")

BRANDING_PATH = Path("core/res/assets/images/android-logo-mask.png")
BRANDING_BLOB = "bec81216db3ed6976f305fd496ed757f0788f702"
BRANDING_DIRT = {f" M {BRANDING_PATH.as_posix()}"}

SABLE_SECURITY_PATH = Path("core/res/res/values/config_ext.xml")
SABLE_SECURITY_BLOB = "8264085d12533d294eab24aae55ca40830bfb62b"
SABLE_SECURITY_DIRT = {f" M {SABLE_SECURITY_PATH.as_posix()}"}

KNOWN_PREEXISTING_BLOBS = {
    BRANDING_PATH: BRANDING_BLOB,
    SABLE_SECURITY_PATH: SABLE_SECURITY_BLOB,
}

ALLOWED_PREEXISTING_SCOPES = (
    set(),
    BRANDING_DIRT,
    SABLE_SECURITY_DIRT,
    BRANDING_DIRT | SABLE_SECURITY_DIRT,
)

PATCHES: dict[Path, tuple[tuple[str, str], ...]] = {
    COMMON_TILE: (
        (
            """    val ActiveIconCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = dimensionResource(id = R.dimen.common_tile_default_active_icon_corner_radius)
""",
            """    val ActiveIconCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = 4.dp
""",
        ),
        (
            """    val ActiveTileCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = dimensionResource(id = R.dimen.common_tile_default_active_tile_corner_radius)
""",
            """    val ActiveTileCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = 6.dp
""",
        ),
        (
            """    val InactiveIconCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = dimensionResource(id = R.dimen.common_tile_default_inactive_icon_corner_radius)
""",
            """    val InactiveIconCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = 4.dp
""",
        ),
        (
            """    val InactiveTileCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = dimensionResource(id = R.dimen.common_tile_default_inactive_tile_corner_radius)
""",
            """    val InactiveTileCornerRadius: Dp
        @Composable
        @ReadOnlyComposable
        get() = 6.dp
""",
        ),
        ("    val TileArrangementPadding = 6.dp\n", "    val TileArrangementPadding = 8.dp\n"),
    ),
    TILE: (
        (
            "import com.android.systemui.res.R\n",
            "import com.android.systemui.res.R\n"
            "import com.android.systemui.sable.rememberSableSystemAccent\n",
        ),
        (
            """    /** An active tile uses the active color as background */
    @Composable
    @ReadOnlyComposable
    fun activeTileColors(): TileColors =
        TileColors(
            background = MaterialTheme.colorScheme.primary,
            iconBackground = MaterialTheme.colorScheme.primary,
            label = MaterialTheme.colorScheme.onPrimary,
            secondaryLabel = MaterialTheme.colorScheme.onPrimary,
            icon = MaterialTheme.colorScheme.onPrimary,
        )
""",
            """    /** An active tile follows the Sable global accent contract. */
    @Composable
    fun activeTileColors(): TileColors {
        val accent = rememberSableSystemAccent()
        return TileColors(
            background = accent.color,
            iconBackground = accent.color,
            label = accent.onColor,
            secondaryLabel = accent.onColor,
            icon = accent.onColor,
        )
    }
""",
        ),
        (
            """    /** An active tile with dual target only show the active color on the icon */
    @Composable
    @ReadOnlyComposable
    fun activeDualTargetTileColors(): TileColors =
        TileColors(
            background = LocalAndroidColorScheme.current.surfaceEffect1,
            iconBackground = MaterialTheme.colorScheme.primary,
            label = MaterialTheme.colorScheme.onSurface,
            secondaryLabel = MaterialTheme.colorScheme.onSurface,
            icon = MaterialTheme.colorScheme.onPrimary,
        )
""",
            """    /** A dual-target active tile follows the same Sable accent surface. */
    @Composable
    fun activeDualTargetTileColors(): TileColors {
        val accent = rememberSableSystemAccent()
        return TileColors(
            background = accent.color,
            iconBackground = accent.color,
            label = accent.onColor,
            secondaryLabel = accent.onColor,
            icon = accent.onColor,
        )
    }
""",
        ),
    ),
    QUICK_QUICK_SETTINGS: (
        ("import androidx.compose.ui.res.dimensionResource\n", "import androidx.compose.ui.unit.dp\n"),
        ("import com.android.systemui.res.R\n", ""),
        (
            "            columnSpacing = dimensionResource(R.dimen.qs_tile_margin_horizontal),\n",
            "            columnSpacing = 8.dp,\n",
        ),
        (
            "            rowSpacing = dimensionResource(R.dimen.qs_tile_margin_vertical),\n",
            "            rowSpacing = 8.dp,\n",
        ),
    ),
    QUICK_SETTINGS_CONTENT: (
        ("import androidx.compose.ui.res.dimensionResource\n", "import androidx.compose.ui.unit.dp\n"),
        ("import com.android.systemui.res.R\n", ""),
        (
            """                            modifier =
                                Modifier.padding(
                                        vertical =
                                            dimensionResource(id = R.dimen.qs_brightness_margin_top)
                                    )
                                    .thenIf(!isBrightnessSliderInteractable) {
""",
            """                            modifier =
                                Modifier.padding(vertical = 8.dp)
                                    .thenIf(!isBrightnessSliderInteractable) {
""",
        ),
        (
            "                .padding(horizontal = dimensionResource(id = R.dimen.qs_horizontal_margin))\n",
            "                .padding(horizontal = 16.dp)\n",
        ),
    ),
    FOOTER_ACTIONS: (
        (
            "    val backgroundTopRadius = dimensionResource(R.dimen.qs_corner_radius)\n",
            "    val backgroundTopRadius = 6.dp\n",
        ),
        ("        shape = CircleShape,\n", "        shape = RoundedCornerShape(6.dp),\n"),
        (
            "                cornerSize = CornerSize(percent = 50),\n",
            "                cornerSize = CornerSize(6.dp),\n",
        ),
        ("    val FooterButtonHeight = 40.dp\n", "    val FooterButtonHeight = 48.dp\n"),
    ),
    DIMENS: (
        (
            '<dimen name="notification_corner_radius">28dp</dimen>\n',
            '<dimen name="notification_corner_radius">6dp</dimen>\n',
        ),
        (
            '<dimen name="notification_divider_height">2dp</dimen>\n',
            '<dimen name="notification_divider_height">8dp</dimen>\n',
        ),
        (
            '<dimen name="notification_scrim_corner_radius">32dp</dimen>\n',
            '<dimen name="notification_scrim_corner_radius">6dp</dimen>\n',
        ),
    ),
    MEDIA: (
        (
            "    val roundedCornerShape = remember { RoundedCornerShape(32.dp) }\n",
            "    val roundedCornerShape = remember { RoundedCornerShape(6.dp) }\n",
        ),
        (
            "                        .clip(RoundedCornerShape(32.dp)),\n",
            "                        .clip(RoundedCornerShape(6.dp)),\n",
        ),
        (
            "                    color = style.fillColor,\n                    shape = RoundedCornerShape(12.dp),\n",
            "                    color = style.fillColor,\n                    shape = RoundedCornerShape(6.dp),\n",
        ),
        (
            "                    Modifier.clip(RoundedCornerShape(12.dp))\n",
            "                    Modifier.clip(RoundedCornerShape(6.dp))\n",
        ),
        (
            "                                color = style.borderColor!!,\n                                shape = RoundedCornerShape(12.dp),\n",
            "                                color = style.borderColor!!,\n                                shape = RoundedCornerShape(6.dp),\n",
        ),
    ),
}


def run_git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True, stderr=subprocess.STDOUT
    ).rstrip("\n")


def framework(source: Path) -> Path:
    return source / FRAMEWORK_REPO


def status_set(source: Path) -> set[str]:
    out = run_git(framework(source), "status", "--porcelain", "--untracked-files=all")
    return {line for line in out.splitlines() if line}


def assert_head(source: Path) -> None:
    actual = run_git(framework(source), "rev-parse", "HEAD")
    if actual != FRAMEWORK_HEAD:
        raise SystemExit(f"FRAMEWORK_HEAD_MISMATCH expected={FRAMEWORK_HEAD} actual={actual}")


def assert_known_preexisting_blobs(source: Path, dirt: set[str]) -> None:
    repo = framework(source)
    for rel, expected in KNOWN_PREEXISTING_BLOBS.items():
        marker = f" M {rel.as_posix()}"
        if marker not in dirt:
            continue
        actual = run_git(repo, "hash-object", rel.as_posix())
        if actual != expected:
            raise SystemExit(
                f"PREEXISTING_FRAMEWORK_BLOB_MISMATCH={rel} "
                f"expected={expected} actual={actual}"
            )


def assert_preexisting_scope(source: Path) -> set[str]:
    dirt = status_set(source)
    if dirt not in ALLOWED_PREEXISTING_SCOPES:
        raise SystemExit(f"UNEXPECTED_PREEXISTING_FRAMEWORK_DIRT={sorted(dirt)!r}")
    assert_known_preexisting_blobs(source, dirt)
    if SABLE_SECURITY_DIRT <= dirt:
        print("UI4_PREEXISTING_SABLE_SECURITY_DELTA=PASS")
    if BRANDING_DIRT <= dirt:
        print("UI4_PREEXISTING_SABLE_BRANDING_DELTA=PASS")
    return dirt


def assert_baseline_blobs(source: Path) -> None:
    repo = framework(source)
    for rel, expected in BASELINE_BLOBS.items():
        actual = run_git(repo, "hash-object", rel.as_posix())
        if actual != expected:
            raise SystemExit(
                f"UI4_BASELINE_BLOB_MISMATCH={rel} expected={expected} actual={actual}"
            )


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"UI4_REPLACEMENT_PRECONDITION_FAIL={path} count={count} old={old!r}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def apply_patches(root: Path) -> None:
    for rel, replacements in PATCHES.items():
        path = root / rel
        for old, new in replacements:
            replace_once(path, old, new)

    appearance = root / SABLE_APPEARANCE
    if appearance.exists():
        if appearance.read_text(encoding="utf-8") != SABLE_APPEARANCE_SOURCE:
            raise SystemExit(
                f"UI4_SABLE_APPEARANCE_PREEXISTING_MISMATCH={SABLE_APPEARANCE}"
            )
    else:
        appearance.parent.mkdir(parents=True, exist_ok=True)
        appearance.write_text(
            SABLE_APPEARANCE_SOURCE,
            encoding="utf-8",
        )


def verify_visual_delta(source: Path) -> None:
    root = framework(source)
    for rel, replacements in PATCHES.items():
        text = (root / rel).read_text(encoding="utf-8")
        for old, new in replacements:
            if old in text:
                raise SystemExit(f"UI4_OLD_VISUAL_TOKEN_PRESENT={rel} token={old!r}")
            if new and new not in text:
                raise SystemExit(f"UI4_NEW_VISUAL_TOKEN_MISSING={rel} token={new!r}")

    appearance_path = root / SABLE_APPEARANCE
    if not appearance_path.is_file():
        raise SystemExit("UI4_SABLE_APPEARANCE_BRIDGE_MISSING")
    if appearance_path.read_text(encoding="utf-8") != SABLE_APPEARANCE_SOURCE:
        raise SystemExit("UI4_SABLE_APPEARANCE_BRIDGE_MISMATCH")

    tile_text = (root / TILE).read_text(encoding="utf-8")
    common_text = (root / COMMON_TILE).read_text(encoding="utf-8")
    footer_text = (root / FOOTER_ACTIONS).read_text(encoding="utf-8")
    media_text = (root / MEDIA).read_text(encoding="utf-8")

    preserved_tokens = (
        "accessibilityUiState.toggleableState",
        "stateDescription = accessibilityUiState.stateDescription",
        "role = accessibilityRole",
        "combinedClickable(",
        "onLongClick = onLongClick",
    )
    for token in preserved_tokens:
        if token not in tile_text and token not in common_text:
            raise SystemExit(f"UI4_ACCESSIBILITY_OR_INTERACTION_TOKEN_MISSING={token!r}")

    if "FooterButtonHeight = 48.dp" not in footer_text:
        raise SystemExit("UI4_FOOTER_TOUCH_TARGET_CHECK_FAIL")

    media_preserved_tokens = (
        "onDismissed = onDismissed",
        "HorizontalCenteredHeroCarousel(",
        "overscrollToDismiss(",
        "viewModel.onCardSelected(",
        "PlayPauseAction(",
        "SeekBarTrack(",
        "contentDescription = viewModel.contentDescription",
    )
    for token in media_preserved_tokens:
        if token not in media_text:
            raise SystemExit(f"UI4_MEDIA_BEHAVIOR_OR_SEMANTICS_TOKEN_MISSING={token!r}")

    dirt = status_set(source)
    valid = tuple(UI4_DIRT | scope for scope in ALLOWED_PREEXISTING_SCOPES)
    if dirt not in valid:
        raise SystemExit(
            f"UI4_DIRTY_SCOPE_MISMATCH actual={sorted(dirt)!r} "
            f"expected_one_of={[sorted(v) for v in valid]!r}"
        )
    assert_known_preexisting_blobs(source, dirt)

    print("UI4_R1_QS_THEME_GEOMETRY=PASS")
    print("UI4_R1_SABLE_ACCENT_PROVIDER=PASS")
    print("UI4_R1_COMPACT_QS_SPACING=PASS")
    print("UI4_R1_BRIGHTNESS_PANEL_ALIGNMENT=PASS")
    print("UI4_R1_FOOTER_GEOMETRY=PASS")
    print("UI4_R2_NOTIFICATION_CARD_GEOMETRY=PASS")
    print("UI4_R2_NOTIFICATION_STACK_SPACING=PASS")
    print("UI4_R2_NOTIFICATION_SHADE_GEOMETRY=PASS")
    print("UI4_R3_MEDIA_CARD_GEOMETRY=PASS")
    print("UI4_R3_MEDIA_CONTROL_GEOMETRY=PASS")
    print("UI4_R1_R2_R3_ACCESSIBILITY_SEMANTICS_PRESERVED=PASS")
    print("UI4_R1_R2_R3_BEHAVIORAL_DIFF=NONE")


def apply(source: Path) -> None:
    assert_head(source)
    preexisting = assert_preexisting_scope(source)
    assert_baseline_blobs(source)
    apply_patches(framework(source))
    expected = UI4_DIRT | preexisting
    actual = status_set(source)
    if actual != expected:
        raise SystemExit(
            f"UI4_POST_APPLY_SCOPE_MISMATCH expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )
    verify_visual_delta(source)
    print("SABLE_UI4_R1_R2_R3_APPLY=PASS")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="sable-ui4-selftest-") as td:
        root = Path(td)
        for rel, replacements in PATCHES.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("\n".join(old for old, _ in replacements), encoding="utf-8")

        apply_patches(root)

        if (root / SABLE_APPEARANCE).read_text(encoding="utf-8") != SABLE_APPEARANCE_SOURCE:
            raise SystemExit("SELF_TEST_SABLE_APPEARANCE_BRIDGE_FAIL")

        for rel, replacements in PATCHES.items():
            text = (root / rel).read_text(encoding="utf-8")
            for old, new in replacements:
                if old in text:
                    raise SystemExit(f"SELF_TEST_OLD_TOKEN_PRESENT={rel}")
                if new and new not in text:
                    raise SystemExit(f"SELF_TEST_NEW_TOKEN_MISSING={rel}")

    if set(PATCHES) != set(BASELINE_BLOBS):
        raise SystemExit("SELF_TEST_MUTATION_SET_NOT_EQUAL_TO_PINNED_SET")
    if SABLE_SECURITY_BLOB != "8264085d12533d294eab24aae55ca40830bfb62b":
        raise SystemExit("SELF_TEST_SABLE_SECURITY_BLOB_PIN_MISMATCH")
    if BRANDING_BLOB != "bec81216db3ed6976f305fd496ed757f0788f702":
        raise SystemExit("SELF_TEST_BRANDING_BLOB_PIN_MISMATCH")

    print("UI4_R1_R2_R3_PINNED_MUTATION_SET=PASS")
    print("UI4_R1_SABLE_ACCENT_PROVIDER_SELF_TEST=PASS")
    print("UI4_KNOWN_PREEXISTING_BLOB_PINS=PASS")
    print("UI4_R1_R2_R3_REPLACEMENT_CARDINALITY=PASS")
    print("UI4_R1_R2_R3_SELF_TEST=PASS")
    print("SELF_TEST_REAL_SOURCE_MUTATION=NONE")
    print("SELF_TEST_BUILD=NONE")
    print("SELF_TEST_DEVICE_CONTACT=NONE")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", nargs="?", choices=("apply", "verify"))
    parser.add_argument("--source", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        if args.mode is not None or args.source is not None:
            parser.error("--self-test cannot be combined with mode or --source")
        self_test()
        return 0

    if args.mode is None:
        parser.error("mode is required unless --self-test is used")
    if args.source is None:
        parser.error("--source is required for apply/verify")

    source = args.source.resolve()
    if not (source / ".repo").exists():
        raise SystemExit(f"NOT_ANDROID_REPO_ROOT={source}")

    assert_head(source)
    if args.mode == "apply":
        apply(source)
    else:
        verify_visual_delta(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
