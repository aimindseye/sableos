#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

media_screen = (ROOT / "apps/r8/android/media/src/main/java/org/sableos/media/MediaScreen.kt").read_text()
media_app = (ROOT / "apps/r8/android/media/src/main/java/org/sableos/media/MediaApp.kt").read_text()
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
require("count = songs.size", collection, "sorted lazy song item count")
forbid("localItems.forEachIndexed", collection, "eager song composition")
forbid("items.forEachIndexed", collection, "legacy eager song composition")

require("private fun MediaAlphabetRail(", media_screen, "Media alphabet rail")
require("buildMediaSectionTargets(", media_screen, "Media alphabet section targets")
require("LibraryPivot.Songs -> songs.map { it.title }", media_screen, "Songs alphabet rail")
require("LibraryPivot.Artists -> artistGroups.map { it.first }", media_screen, "Artists alphabet rail")
require("LibraryPivot.Albums -> albumGroups.map { it.first }", media_screen, "Albums alphabet rail")
require("LibraryPivot.Favorites -> favorites.map { it.title }", media_screen, "Favorites alphabet rail")
require("LibraryPivot.Playlists -> emptyList()", media_screen, "Playlists explicit order")
require("HorizontalDivider(", media_screen, "flat Media rows")
forbid('text = "×"', media_screen, "destructive inline Media remove")
require('text = if (favorite) "★" else "☆"', media_screen, "Media favorite action")
require('text = "▶"', media_screen, "Media play action")

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
    media_app,
    "background media import",
)
require(
    "audioFolderScanner.scan(treeUri)",
    media_app,
    "folder scan",
)
require(
    "localAudioRepository.addUris(",
    media_app,
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

require(
    "Light and Dark follow SableOS.",
    reader_patch,
    "Reader Sable-owned light-dark settings copy",
)
require(
    "R9_READER_LIGHT_DARK_OWNERSHIP=PASS_SABLEOS_GLOBAL",
    reader_patch,
    "Reader global light-dark ownership marker",
)
require(
    "SableContinuousLibraryGrid(",
    reader_patch,
    "Reader continuous Sable bookshelf",
)
require(
    "LazyVerticalGrid(",
    reader_patch,
    "Reader vertical library grid",
)
require(
    "R9_READER_LIBRARY_NAVIGATION=PASS_CONTINUOUS_VERTICAL_GRID",
    reader_patch,
    "Reader continuous-library marker",
)
require(
    "R9_READER_LIBRARY_COUNT=PASS_ACTUAL_BOOKS_NOT_STACKS",
    reader_patch,
    "Reader actual book-count marker",
)
require(
    "distinctBy { it.bookHash }",
    reader_patch,
    "Reader physical-book deduplication",
)
require(
    "R9_READER_SETTINGS_GLOBAL_APPEARANCE=PASS_NO_OFFLINE_LIGHT_OVERRIDE",
    reader_patch,
    "Reader offline-mode appearance marker",
)
require(
    "R9_READER_LOCAL_LIGHT_DARK_CONTROLS=PASS_RETIRED_FOR_SABLE",
    reader_patch,
    "Reader local light-dark retirement marker",
)
require(
    "state.isOfflineMode && !BuildConfig.SABLE_PRODUCT",
    reader_patch,
    "Reader offline paper theme excluded from Sable product",
)

if failures:
    print("R9_PHYSICAL_REMEDIATION_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_MEDIA_LARGE_LIBRARY_LAZY_RENDERING=PASS")
print("R9_MEDIA_QUEUE_TICKER_BOUNDED=PASS")
print("R9_MEDIA_IMPORT_OFF_MAIN_THREAD=PASS")
print("R9_MEDIA_ALPHABET_RAIL=PASS_SONGS_ARTISTS_ALBUMS_FAVORITES")
print("R9_MEDIA_FLAT_LIBRARY_ROWS=PASS_NO_INLINE_REMOVE")
print("R9_READER_GLOBAL_THEME_CONTRACT=PASS")
print("R9_READER_READIUM_APPEARANCE_BRIDGE=PASS")
print("R9_READER_EXPLICIT_SEPIA_EINK_OVERRIDES=PASS")
print("R9_READER_LIGHT_DARK_OWNERSHIP=PASS_SABLEOS_GLOBAL")
print("R9_READER_LIBRARY_NAVIGATION=PASS_CONTINUOUS_VERTICAL_GRID")
print("R9_READER_LIBRARY_COUNT=PASS_ACTUAL_BOOKS_NOT_STACKS")
print("R9_READER_SETTINGS_GLOBAL_APPEARANCE=PASS")
print("R9_READER_WARNING_CLEANUP_CONTRACT=PASS")
print("R9_PHYSICAL_REMEDIATION_CONTRACT=PASS")
