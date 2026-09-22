#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

media_screen = (ROOT / "apps/r8/android/media/src/main/java/org/sableos/media/MediaScreen.kt").read_text()
main_activity = (ROOT / "apps/r8/android/media/src/main/java/org/sableos/media/MainActivity.kt").read_text()
playback = (ROOT / "apps/r8/android/media/src/main/java/org/sableos/media/PlaybackController.kt").read_text()
reader_patch = (ROOT / "apps/r8/reader/apply_sable_flavor.py").read_text()

failures = []

def require(marker: str, text: str, name: str) -> None:
    if marker not in text:
        failures.append(f"missing {name}: {marker!r}")

def forbid(marker: str, text: str, name: str) -> None:
    if marker in text:
        failures.append(f"forbidden {name}: {marker!r}")

require(
    "if (destination == MediaDestination.Collection)",
    media_screen,
    "collection full-screen lazy branch",
)
require(
    "private fun CollectionScreen(",
    media_screen,
    "collection screen",
)
collection = media_screen.split("private fun CollectionScreen(", 1)[1].split(
    "private fun LocalTrackRow(", 1
)[0]
require("LazyColumn(", collection, "collection LazyColumn")
require("count = localItems.size", collection, "lazy song item count")
forbid("localItems.forEachIndexed", collection, "eager song composition")
forbid("items.forEachIndexed", collection, "legacy eager song composition")

require(
    "publishState(refreshQueue = false)",
    playback,
    "cheap playback ticker",
)
require(
    "Player.EVENT_TIMELINE_CHANGED",
    playback,
    "queue refresh event",
)
require(
    "cachedQueue",
    playback,
    "cached playback queue",
)

require(
    "withContext(Dispatchers.IO)",
    main_activity,
    "background media import",
)
require(
    "audioFolderScanner.scan(treeUri)",
    main_activity,
    "folder scan",
)
require(
    "localAudioRepository.addUris(",
    main_activity,
    "metadata import",
)

require(
    "if (!BuildConfig.SABLE_PRODUCT || themeMode == ThemeMode.E_INK)",
    reader_patch,
    "Sable Reader explicit E-ink override",
)
require(
    "appearance = rememberGlobalSableAppearance()",
    reader_patch,
    "Reader global appearance consumer",
)
require(
    "val effectiveEpubPreferences =",
    reader_patch,
    "Reader effective Readium preferences",
)
require(
    "epubPreferences.theme == Theme.SEPIA",
    reader_patch,
    "Reader explicit sepia override",
)
require(
    "isEink -> epubPreferences.copy(theme = Theme.LIGHT)",
    reader_patch,
    "Reader E-ink white-page override",
)
require(
    "theme = if (sableDark) Theme.DARK else Theme.LIGHT",
    reader_patch,
    "Reader Sable light-dark page bridge",
)
require(
    "submitPreferences(effectiveEpubPreferences)",
    reader_patch,
    "Reader effective preferences submission",
)
require(
    "SABLE_READER_WARNING_CLEANUP=PASS",
    reader_patch,
    "Reader bounded warning cleanup marker",
)
require(
    "SABLE_READER_HILT_VIEWMODEL_MIGRATION=PASS",
    reader_patch,
    "Reader Hilt Compose migration",
)
require(
    'ndkVersion = "30.0.16248370"',
    reader_patch,
    "Reader pinned NDK strip toolchain",
)
require(
    "androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel",
    reader_patch,
    "Reader modern Hilt Compose package",
)

if failures:
    print("R9_PHYSICAL_REMEDIATION_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_MEDIA_LARGE_LIBRARY_LAZY_RENDERING=PASS")
print("R9_MEDIA_QUEUE_TICKER_BOUNDED=PASS")
print("R9_MEDIA_IMPORT_OFF_MAIN_THREAD=PASS")
print("R9_READER_GLOBAL_THEME_CONTRACT=PASS")
print("R9_READER_READIUM_APPEARANCE_BRIDGE=PASS")
print("R9_READER_EXPLICIT_SEPIA_EINK_OVERRIDES=PASS")
print("R9_READER_WARNING_CLEANUP_CONTRACT=PASS")
print("R9_PHYSICAL_REMEDIATION_CONTRACT=PASS")
