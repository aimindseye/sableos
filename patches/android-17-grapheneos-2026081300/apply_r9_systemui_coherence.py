#!/usr/bin/env python3
"""Apply/verify the R9 physical SystemUI coherence overlay.

This is deliberately layered *after* the sealed R8 UI4/UI5C/UI6 cumulative
surface work. UI4 remains historical evidence. This overlay consumes the
already-qualified cumulative state and adds only:
  * Sable global-accent observation inside SystemUI
  * active Quick Settings tile colors sourced from that Sable accent
  * SableOS product identity for the framework-owned ADB developer notification

Light/dark propagation is owned by the privileged Settings-hosted Sable appearance authority through
UiModeManager; this overlay does not change SystemUI behavior/state models.
"""

from __future__ import annotations

import argparse
import importlib.util
import subprocess
import tempfile
from pathlib import Path

FRAMEWORK_HEAD = "aab06a8bd44c4c2b58eeec780fde83baa9d43a40"
FRAMEWORK_REPO = Path("frameworks/base")
TILE = Path(
    "packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/Tile.kt"
)
BRIDGE = Path(
    "packages/SystemUI/src/com/android/systemui/sable/SableSystemAppearance.kt"
)
ADB_NOTIFICATIONS = Path(
    "core/java/android/debug/AdbNotifications.java"
)

ADB_IMPORT_OLD = "import android.os.UserHandle;\n"
ADB_IMPORT_NEW = "import android.os.Bundle;\nimport android.os.UserHandle;\n"
ADB_BUILDER_OLD = """        return new Notification.Builder(context, SystemNotificationChannels.DEVELOPER_IMPORTANT)
                .setSmallIcon(com.android.internal.R.drawable.stat_sys_adb)
"""
ADB_BUILDER_NEW = """        Bundle sableIdentity = new Bundle();
        sableIdentity.putString(Notification.EXTRA_SUBSTITUTE_APP_NAME, "SableOS");

        return new Notification.Builder(context, SystemNotificationChannels.DEVELOPER_IMPORTANT)
                .addExtras(sableIdentity)
                .setSmallIcon(com.android.internal.R.drawable.stat_sys_adb)
"""

TILE_IMPORT_OLD = "import com.android.systemui.res.R\n"
TILE_IMPORT_NEW = (
    "import com.android.systemui.res.R\n"
    "import com.android.systemui.sable.rememberSableSystemAccent\n"
)

LEGACY_ACTIVE = """    /** An active tile uses a restrained accent surface with explicit active contrast. */
    @Composable
    @ReadOnlyComposable
    fun activeTileColors(): TileColors =
        TileColors(
            background = MaterialTheme.colorScheme.primaryContainer,
            iconBackground = MaterialTheme.colorScheme.primaryContainer,
            label = MaterialTheme.colorScheme.onPrimaryContainer,
            secondaryLabel = MaterialTheme.colorScheme.onPrimaryContainer,
            icon = MaterialTheme.colorScheme.onPrimaryContainer,
        )
"""

SABLE_ACTIVE = """    /** An active tile follows the Sable global accent contract. */
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
"""

LEGACY_DUAL = """    /** A dual-target active tile keeps the same active surface and a stronger toggle target. */
    @Composable
    @ReadOnlyComposable
    fun activeDualTargetTileColors(): TileColors =
        TileColors(
            background = MaterialTheme.colorScheme.primaryContainer,
            iconBackground = MaterialTheme.colorScheme.primary,
            label = MaterialTheme.colorScheme.onPrimaryContainer,
            secondaryLabel = MaterialTheme.colorScheme.onPrimaryContainer,
            icon = MaterialTheme.colorScheme.onPrimary,
        )
"""

SABLE_DUAL = """    /** A dual-target active tile follows the same Sable accent surface. */
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
"""

LEGACY_COLOR_SELECTOR = """    @Composable
    @ReadOnlyComposable
    fun getColorForState(uiState: TileUiState, iconOnly: Boolean): TileColors {
"""

SABLE_COLOR_SELECTOR = """    @Composable
    fun getColorForState(uiState: TileUiState, iconOnly: Boolean): TileColors {
"""

BRIDGE_SOURCE = """package com.android.systemui.sable

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
    Uri.parse("content://org.sableos.appearance/appearance")

private fun defaultAccent() =
    SableSystemAccent(
        color = Color(0xFF4D9CFF),
        onColor = Color(0xFF06111F),
    )

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
                            color = Color(0xFF35C66B),
                            onColor = Color(0xFF04140A),
                        )
                    "purple" ->
                        SableSystemAccent(
                            color = Color(0xFF7A42E8),
                            onColor = Color.White,
                        )
                    "orange" ->
                        SableSystemAccent(
                            color = Color(0xFFF28C45),
                            onColor = Color(0xFF1D0C02),
                        )
                    "slate" ->
                        SableSystemAccent(
                            color = Color(0xFF64748B),
                            onColor = Color.White,
                        )
                    else -> defaultAccent()
                }
            }
            ?: defaultAccent()
    }.getOrDefault(defaultAccent())

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

LEGACY_BRIDGE_SOURCE = BRIDGE_SOURCE.replace(
    "content://org.sableos.appearance/appearance",
    "content://org.sableos.start.appearance/appearance",
)


class CoherenceError(RuntimeError):
    pass


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise CoherenceError(f"MODULE_LOAD_FAIL={path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
        stderr=subprocess.STDOUT,
    ).rstrip("\n")


def status_set(repo: Path) -> set[str]:
    out = run_git(repo, "status", "--porcelain", "--untracked-files=all")
    return {line for line in out.splitlines() if line}


def assert_head(source: Path) -> None:
    actual = run_git(source / FRAMEWORK_REPO, "rev-parse", "HEAD")
    if actual != FRAMEWORK_HEAD:
        raise CoherenceError(
            f"FRAMEWORK_HEAD_MISMATCH expected={FRAMEWORK_HEAD} actual={actual}"
        )


def patch_adb_notification_text(text: str) -> str:
    replacements = (
        (ADB_IMPORT_OLD, ADB_IMPORT_NEW, "ADB notification Bundle import"),
        (ADB_BUILDER_OLD, ADB_BUILDER_NEW, "ADB notification Sable identity"),
    )
    for old, new, label in replacements:
        if new in text:
            continue
        count = text.count(old)
        if count != 1:
            raise CoherenceError(
                f"R9_ADB_NOTIFICATION_REPLACEMENT_PRECONDITION_FAIL="
                f"{label}:count={count}"
            )
        text = text.replace(old, new, 1)
    return text


def patch_text(text: str) -> str:
    replacements = (
        (TILE_IMPORT_OLD, TILE_IMPORT_NEW, "SystemUI Sable accent import"),
        (LEGACY_ACTIVE, SABLE_ACTIVE, "active tile accent"),
        (LEGACY_DUAL, SABLE_DUAL, "dual-target active tile accent"),
        (
            LEGACY_COLOR_SELECTOR,
            SABLE_COLOR_SELECTOR,
            "stateful tile color selector annotation",
        ),
    )

    for old, new, label in replacements:
        if new in text:
            continue
        count = text.count(old)
        if count != 1:
            raise CoherenceError(
                f"R9_SYSTEMUI_REPLACEMENT_PRECONDITION_FAIL="
                f"{label}:count={count}"
            )
        text = text.replace(old, new, 1)
    return text


def expected_legacy_sets(root: Path) -> tuple[set[str], ...]:
    patch_dir = root / "patches/android-17-grapheneos-2026081300"
    ui4 = load_module(patch_dir / "apply_ui4_systemui.py", "sable_r9_ui4")
    ui5c = load_module(
        patch_dir / "apply_ui5c_ui6_system_surfaces.py",
        "sable_r9_ui5c_ui6",
    )

    result = []
    for scope in ui4.ALLOWED_PREEXISTING_SCOPES:
        pre = set(ui4.UI4_DIRT) | set(scope)
        if not set(ui4.BRANDING_DIRT) <= pre:
            continue
        result.append(pre | set(ui5c.UI6_NEW_DIRT))
    return tuple(result)


def assert_legacy_cumulative_state(source: Path, root: Path) -> None:
    patch_dir = root / "patches/android-17-grapheneos-2026081300"
    ui5c = load_module(
        patch_dir / "apply_ui5c_ui6_system_surfaces.py",
        "sable_r9_ui5c_ui6_precondition",
    )
    ui5c.verify(source)
    print("R9_SYSTEMUI_COHERENCE_CUMULATIVE_PRECONDITION=PASS")


def verify(source: Path, root: Path) -> None:
    assert_head(source)
    framework = source / FRAMEWORK_REPO
    tile = (framework / TILE).read_text(encoding="utf-8")
    bridge = framework / BRIDGE
    adb_notifications = framework / ADB_NOTIFICATIONS

    if not adb_notifications.is_file():
        raise CoherenceError("R9_ADB_NOTIFICATION_SOURCE_MISSING")
    adb_text = adb_notifications.read_text(encoding="utf-8")
    for token in (
        ADB_IMPORT_NEW,
        'sableIdentity.putString(Notification.EXTRA_SUBSTITUTE_APP_NAME, "SableOS")',
        ".addExtras(sableIdentity)",
    ):
        if token not in adb_text:
            raise CoherenceError(
                f"R9_ADB_NOTIFICATION_SABLE_IDENTITY_TOKEN_MISSING={token!r}"
            )
    if ADB_BUILDER_OLD in adb_text:
        raise CoherenceError("R9_ADB_NOTIFICATION_LEGACY_BUILDER_PRESENT")

    required = (
        TILE_IMPORT_NEW,
        SABLE_ACTIVE,
        SABLE_DUAL,
        SABLE_COLOR_SELECTOR,
        "accessibilityUiState.toggleableState",
        "stateDescription = accessibilityUiState.stateDescription",
        "combinedClickable(",
        "onLongClick = onLongClick",
    )
    for token in required:
        if token not in tile:
            raise CoherenceError(
                f"R9_SYSTEMUI_COHERENCE_TOKEN_MISSING={token!r}"
            )

    for token in (LEGACY_ACTIVE, LEGACY_DUAL, LEGACY_COLOR_SELECTOR):
        if token in tile:
            raise CoherenceError(
                f"R9_SYSTEMUI_LEGACY_ACTIVE_TOKEN_PRESENT={token[:50]!r}"
            )

    if not bridge.is_file():
        raise CoherenceError("R9_SYSTEMUI_SABLE_ACCENT_BRIDGE_MISSING")
    if bridge.read_text(encoding="utf-8") != BRIDGE_SOURCE:
        raise CoherenceError("R9_SYSTEMUI_SABLE_ACCENT_BRIDGE_MISMATCH")

    actual = status_set(framework)
    overlay_marker = f"?? {BRIDGE.as_posix()}"
    adb_marker = f" M {ADB_NOTIFICATIONS.as_posix()}"
    expected = tuple(
        legacy | {overlay_marker, adb_marker}
        for legacy in expected_legacy_sets(root)
    )
    if actual not in expected:
        raise CoherenceError(
            f"R9_SYSTEMUI_COHERENCE_DIRTY_SCOPE_MISMATCH="
            f"actual={sorted(actual)!r} "
            f"expected_one_of={[sorted(x) for x in expected]!r}"
        )

    print("R9_SYSTEMUI_SABLE_ACCENT_PROVIDER=PASS")
    print("R9_SYSTEMUI_QS_ACTIVE_ACCENT=PASS")
    print("R9_ADB_NOTIFICATION_PRODUCT_IDENTITY=PASS_SABLEOS")
    print("R9_SYSTEMUI_INTERACTION_SEMANTICS_PRESERVED=PASS")
    print("R9_SYSTEMUI_COHERENCE_SOURCE_SCOPE=PASS")


def apply(source: Path, root: Path) -> None:
    assert_head(source)

    framework = source / FRAMEWORK_REPO
    bridge = framework / BRIDGE

    upgrade_legacy_bridge = False
    if bridge.exists():
        bridge_text = bridge.read_text(encoding="utf-8")
        if bridge_text == BRIDGE_SOURCE:
            print("R9_SYSTEMUI_EXISTING_OVERLAY_UPGRADE=YES_CURRENT")
        elif bridge_text == LEGACY_BRIDGE_SOURCE:
            upgrade_legacy_bridge = True
            print("R9_SYSTEMUI_EXISTING_OVERLAY_UPGRADE=YES_LEGACY_AUTHORITY")
        else:
            raise CoherenceError(
                f"R9_SYSTEMUI_BRIDGE_PREEXISTS_MISMATCH={bridge}"
            )
    else:
        assert_legacy_cumulative_state(source, root)

    tile = framework / TILE
    tile.write_text(
        patch_text(tile.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    adb_notifications = framework / ADB_NOTIFICATIONS
    adb_notifications.write_text(
        patch_adb_notification_text(
            adb_notifications.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    if not bridge.exists():
        bridge.parent.mkdir(parents=True, exist_ok=True)
    if not bridge.exists() or upgrade_legacy_bridge:
        bridge.write_text(BRIDGE_SOURCE, encoding="utf-8")

    verify(source, root)
    print("R9_SYSTEMUI_COHERENCE_APPLY=PASS")


def self_test(root: Path) -> None:
    sample = (
        TILE_IMPORT_OLD
        + LEGACY_ACTIVE
        + LEGACY_DUAL
        + LEGACY_COLOR_SELECTOR
        + "accessibilityUiState.toggleableState\n"
        + "stateDescription = accessibilityUiState.stateDescription\n"
        + "combinedClickable(\n"
        + "onLongClick = onLongClick\n"
    )
    patched = patch_text(sample)

    adb_sample = ADB_IMPORT_OLD + ADB_BUILDER_OLD
    adb_patched = patch_adb_notification_text(adb_sample)
    for token in (
        ADB_IMPORT_NEW,
        'Notification.EXTRA_SUBSTITUTE_APP_NAME, "SableOS"',
        ".addExtras(sableIdentity)",
    ):
        if token not in adb_patched:
            raise CoherenceError(
                f"R9_ADB_NOTIFICATION_SELF_TEST_TOKEN_MISSING={token!r}"
            )

    for token in (
        TILE_IMPORT_NEW,
        SABLE_ACTIVE,
        SABLE_DUAL,
        SABLE_COLOR_SELECTOR,
    ):
        if token not in patched:
            raise CoherenceError(
                f"R9_SYSTEMUI_SELF_TEST_TOKEN_MISSING={token[:60]!r}"
            )
    for token in (LEGACY_ACTIVE, LEGACY_DUAL, LEGACY_COLOR_SELECTOR):
        if token in patched:
            raise CoherenceError(
                f"R9_SYSTEMUI_SELF_TEST_LEGACY_TOKEN_PRESENT={token[:60]!r}"
            )

    if "content://org.sableos.appearance/appearance" not in BRIDGE_SOURCE:
        raise CoherenceError("R9_SYSTEMUI_SELF_TEST_PROVIDER_URI_MISSING")
    if "registerContentObserver" not in BRIDGE_SOURCE:
        raise CoherenceError("R9_SYSTEMUI_SELF_TEST_OBSERVER_MISSING")
    if "content://org.sableos.start.appearance/appearance" not in LEGACY_BRIDGE_SOURCE:
        raise CoherenceError("R9_SYSTEMUI_SELF_TEST_LEGACY_PROVIDER_URI_MISSING")
    if LEGACY_BRIDGE_SOURCE == BRIDGE_SOURCE:
        raise CoherenceError("R9_SYSTEMUI_SELF_TEST_LEGACY_BRIDGE_NOT_DISTINCT")

    # Prove that the overlay computes at least one valid cumulative scope from
    # the sealed UI4/UI5C/UI6 contracts without touching a real workspace.
    if not expected_legacy_sets(root):
        raise CoherenceError("R9_SYSTEMUI_SELF_TEST_NO_LEGACY_SCOPE")

    print("R9_SYSTEMUI_COHERENCE_REPLACEMENT_SELF_TEST=PASS")
    print("R9_ADB_NOTIFICATION_PRODUCT_IDENTITY_SELF_TEST=PASS")
    print("R9_SYSTEMUI_COHERENCE_PROVIDER_SELF_TEST=PASS")
    print("R9_SYSTEMUI_LEGACY_AUTHORITY_UPGRADE_SELF_TEST=PASS")
    print("R9_SYSTEMUI_COHERENCE_SCOPE_SELF_TEST=PASS")
    print("SELF_TEST_REAL_SOURCE_MUTATION=NONE")
    print("SELF_TEST_BUILD=NONE")
    print("SELF_TEST_DEVICE_CONTACT=NONE")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", nargs="?", choices=("apply", "verify"))
    parser.add_argument("--source", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]

    if args.self_test:
        if args.mode is not None or args.source is not None:
            parser.error("--self-test cannot be combined with mode or --source")
        self_test(root)
        return 0

    if args.mode is None or args.source is None:
        parser.error("mode and --source are required unless --self-test is used")

    source = args.source.resolve()
    if not (source / ".repo").exists():
        raise CoherenceError(f"NOT_ANDROID_REPO_ROOT={source}")

    try:
        if args.mode == "apply":
            apply(source, root)
        else:
            verify(source, root)
    except CoherenceError as exc:
        print(f"R9_SYSTEMUI_COHERENCE=FAIL {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
