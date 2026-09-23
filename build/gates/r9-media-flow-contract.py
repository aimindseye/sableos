#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
failures: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing_file={rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(rel: str, *needles: str) -> None:
    text = read(rel)
    for needle in needles:
        if needle not in text:
            failures.append(f"missing_token={rel}:{needle}")


def forbid(rel: str, *needles: str) -> None:
    text = read(rel)
    for needle in needles:
        if needle in text:
            failures.append(f"forbidden_token={rel}:{needle}")


MEDIA = "apps/r8/android/media/src/main"
MEDIA_KT = f"{MEDIA}/java/org/sableos/media"

require(
    f"{MEDIA_KT}/MediaScreen.kt",
    'Podcasts("podcasts")',
    "MediaDestination.Podcasts",
    "PodcastScreen(",
    "MediaDestination.Collection,",
    "MediaDestination.Radio,",
    "MediaDestination.NowPlaying,",
    "MaterialTheme.typography.headlineSmall",
    "Music, podcasts, and radio in one private playback flow.",
    "MediaScreenState(",
    "MediaScreenActions(",
)

# Large-library safety: the two physical ANRs were main-thread Compose
# saturation failures. Queue/playlist rendering must stay lazy, library indexing
# must stay off main, playback progress ticks must not invalidate browse screens,
# and full libraries must never be serialized through Binder Intent extras.
require(
    f"{MEDIA_KT}/MediaScreen.kt",
    "produceState<MediaCollectionIndex?>",
    "withContext(Dispatchers.Default)",
    "buildMediaCollectionIndex(",
    "MediaCollectionIndex.Empty",
    "count = songs.size",
    "count = artistGroups.size",
    "count = albumGroups.size",
    "upNextCount = playback.upNextCount()",
)
require(
    f"{MEDIA_KT}/MediaC2Screens.kt",
    "internal fun QueueScreen(",
    "internal fun PlaylistEditorScreen(",
    "LazyColumn(",
    "count = upcomingCount",
    "items = localItems",
)
forbid(
    f"{MEDIA_KT}/MediaC2Screens.kt",
    "upcomingItems.forEachIndexed",
    "localItems.forEach { item ->",
)
require(
    f"{MEDIA_KT}/PlaybackController.kt",
    "progressUpdatesEnabled",
    "fun setProgressUpdatesEnabled(enabled: Boolean)",
    "if (closed || !progressUpdatesEnabled)",
)
forbid(
    f"{MEDIA_KT}/PlaybackController.kt",
    "handler.post(ticker)",
)
require(
    f"{MEDIA_KT}/MediaApp.kt",
    "LaunchedEffect(localAudioRepository, libraryStateRepository)",
    "localLibraryLoading",
    "withContext(Dispatchers.IO)",
    "playbackController.setProgressUpdatesEnabled(",
    "destination == MediaDestination.NowPlaying",
)
require(
    f"{MEDIA_KT}/PlaybackQueueRequestStore.kt",
    "AtomicReference<PlaybackQueueRequest?>",
    "fun publish(",
    "fun consume(token: String)",
    "items = items",
)
require(
    f"{MEDIA_KT}/MainActivity.kt",
    "PlaybackQueueRequestStore.publish(",
    "PlaybackService.EXTRA_QUEUE_TOKEN",
)
forbid(
    f"{MEDIA_KT}/MainActivity.kt",
    "putStringArrayListExtra",
    "PlaybackService.EXTRA_URIS",
    "PlaybackService.EXTRA_TITLES",
    "PlaybackService.EXTRA_ARTISTS",
)
require(
    f"{MEDIA_KT}/PlaybackService.kt",
    "PlaybackQueueRequestStore::consume",
    "serviceScope.launch",
    "Dispatchers.Default",
    "withContext(Dispatchers.Main.immediate)",
    "EXTRA_QUEUE_TOKEN",
)
forbid(
    f"{MEDIA_KT}/PlaybackService.kt",
    "EXTRA_URIS",
    "EXTRA_TITLES",
    "EXTRA_ARTISTS",
    "EXTRA_START_INDEX",
)
require(
    f"{MEDIA_KT}/AudioFolderScanner.kt",
    "MAX_AUDIO_FILES = 2_000",
)

require(
    f"{MEDIA_KT}/PodcastScreen.kt",
    'Latest("latest")',
    'Shows("shows")',
    'Saved("saved")',
    "PodcastStatusDeck(",
    "PodcastEpisodeRow(",
    "PodcastFeedEntry(",
    "onQueueEpisode",
    "No podcast account, analytics SDK, recommendation profile,",
    "or automatic directory query is built into this flow.",
    "Saved does not imply downloaded.",
    "PodcastScreenState(",
    "PodcastScreenActions(",
)

require(
    f"{MEDIA_KT}/PodcastRepository.kt",
    "HttpURLConnection",
    "application/rss+xml",
    "application/atom+xml",
    "MAX_FEED_BYTES",
    "PodcastFeedParser.parse(",
    "Podcast feed redirected to a non-HTTPS URL.",
    "resolvedFeedUrl",
    "Podcast feed must use HTTPS.",
    "PodcastUrlPolicy.isHttpsUrl",
    "PodcastStateRepository",
    "loadSavedEpisodeIds",
    "loadPlayedEpisodeIds",
)
require(
    f"{MEDIA_KT}/PodcastFeedParser.kt",
    "PodcastUrlPolicy",
    '== HTTPS_SCHEME',
    "Podcast feed document types are not accepted.",
    "MAX_EPISODES_PER_FEED",
    "PROLOG_SCAN_BYTES",
    "PodcastUrlPolicy::isHttpsUrl",
    "consumeStartTag(",
    "consumeText(",
    "consumeEndTag(",
)
require(
    f"{MEDIA_KT}/MediaApp.kt",
    "MediaRepositories(",
    "MediaHostServices(",
    "onAddPodcastFeed",
    "onRefreshPodcasts",
    "withContext(Dispatchers.IO)",
    "podcastRepository.subscribe(",
    "podcastRepository.refreshAll(",
    "podcastStateRepository.toggleSaved(",
    "podcastStateRepository.markPlayed(",
    "playbackController.addToQueue(",
    "destination = MediaDestination.NowPlaying",
    "SableGlobalTheme(window = window)",
)
require(
    f"{MEDIA_KT}/MainActivity.kt",
    "MediaRepositories(",
    "MediaHostServices(",
    "MediaApp(",
    "playUri = ::playUri",
    "playLocalQueue = ::playLocalQueue",
)

forbid(
    f"{MEDIA_KT}/MainActivity.kt",
    "SableGlobalTheme(window = window)",
)
require(
    "build/gates/r8-no-stale-product-code.sh",
    'apps/r8/android/media/src/main/java/org/sableos/media/MediaApp.kt',
)
require(
    "build/gates/r8-final-product-composition.sh",
    'apps/r8/android/media/src/main/java/org/sableos/media/MediaApp.kt',
)

require(
    f"{MEDIA_KT}/PlaybackController.kt",
    "internal enum class PlaybackSkip",
    "fun skip(direction: PlaybackSkip)",
    "fun addToQueue(",
    "player.addMediaItem(item)",
    "publishState(refreshQueue = true)",
)
forbid(
    f"{MEDIA_KT}/PlaybackController.kt",
    "fun previous()",
    "fun next()",
)
require(
    f"{MEDIA_KT}/MediaApp.kt",
    "playbackController.skip(PlaybackSkip.Previous)",
    "playbackController.skip(PlaybackSkip.Next)",
)

require(
    f"{MEDIA_KT}/PlaybackService.kt",
    "class PlaybackService : MediaSessionService()",
    "ExoPlayer.Builder(this)",
    "ACTION_PLAY_URI",
    "ACTION_PLAY_QUEUE",
)

require(
    f"{MEDIA}/AndroidManifest.xml",
    'android.permission.INTERNET',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android:name=".PlaybackService"',
)

forbid(
    f"{MEDIA}/AndroidManifest.xml",
    "READ_EXTERNAL_STORAGE",
    "WRITE_EXTERNAL_STORAGE",
    "MANAGE_EXTERNAL_STORAGE",
    "READ_MEDIA_AUDIO",
)

for rel in (
    f"{MEDIA_KT}/PodcastRepository.kt",
    f"{MEDIA_KT}/PodcastScreen.kt",
    f"{MEDIA_KT}/MainActivity.kt",
    f"{MEDIA_KT}/MediaApp.kt",
    f"{MEDIA_KT}/PodcastFeedParser.kt",
):
    forbid(
        rel,
        "WorkManager",
        "PeriodicWorkRequest",
        "AlarmManager",
        "FirebaseAnalytics",
        "GoogleAnalytics",
        "WebView",
    )

require(
    "apps/r8/android/media/build.gradle.kts",
    "versionCode = 2",
    'versionName = "0.2.0"',
    "allWarningsAsErrors.set(true)",
    'config.setFrom(rootProject.file("config/detekt.yml"))',
    "ignoreFailures = false",
    "ignoreFailures.set(false)",
)
require(
    "apps/r8/android/config/detekt.yml",
    "CyclomaticComplexMethod:",
    "LongMethod:",
    "LongParameterList:",
    "TooManyFunctions:",
    "FunctionNaming:",
    '"**/media/MediaApp.kt"',
    '"**/media/MediaScreen.kt"',
    '"**/media/MediaC2Screens.kt"',
    '"**/media/PodcastScreen.kt"',
    "ignoreAnnotatedFunctions:",
    "- Composable",
    "ignorePrivate: true",
    "ignorePropertyDeclaration: true",
)
require(
    "apps/r8/android/media/.editorconfig",
    "ktlint_function_naming_ignore_when_annotated_with = Composable",
)

require(
    "build/panther/qualify-r9-media-flow.sh",
    "set -euo pipefail",
    'source "$ROOT/build/config/r8-host-tools.env"',
    'export ANDROID_HOME="$SABLE_ANDROID_SDK"',
    'export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"',
    "NETWORK_FETCH_AUTHORIZED=NO",
    "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO",
    "R9_MEDIA_FLOW_ANDROID_SDK=PASS",
    "R9_MEDIA_FLOW_KOTLIN_QUALITY=PASS_WARNINGS_DETEKT_KTLINT",
    "R9_MEDIA_FLOW_FOCUSED_QUALIFICATION=PASS",
)

forbid(
    "apps/r8/android/media/build.gradle.kts",
    "coil",
    "glide",
    "picasso",
    "firebase-analytics",
    "work-runtime",
)

if failures:
    print("R9_MEDIA_FLOW_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_MEDIA_FLOW_PANORAMA_NAVIGATION=PASS")
print("R9_MEDIA_FLOW_SINGLE_MEDIA3_SESSION=PASS")
print("R9_MEDIA_FLOW_SHARED_UP_NEXT=PASS")
print("R9_MEDIA_LARGE_LIBRARY_LAZY_RENDERING=PASS")
print("R9_MEDIA_LARGE_LIBRARY_INDEX_OFF_MAIN=PASS")
print("R9_MEDIA_PROGRESS_RECOMPOSITION=PASS_NOW_PLAYING_ONLY")
print("R9_MEDIA_QUEUE_BINDER_PAYLOAD=PASS_TOKEN_ONLY")
print("R9_MEDIA_QUEUE_BUILD=PASS_BACKGROUND")
print("R9_MEDIA_LIBRARY_STARTUP_LOAD=PASS_OFF_MAIN")
print("R9_MEDIA_FOLDER_IMPORT_BOUND=PASS_2000")
print("R9_PODCAST_EXPLICIT_SUBSCRIPTION=PASS")
print("R9_PODCAST_MANUAL_REFRESH=PASS")
print("R9_PODCAST_FEED_SIZE_BOUND=PASS")
print("R9_PODCAST_HTTPS_ONLY=PASS")
print("R9_PODCAST_XML_DOCTYPE_REJECTED=PASS")
print("R9_PODCAST_NO_AMBIENT_DIRECTORY=PASS")
print("R9_PODCAST_NO_BACKGROUND_POLLING=PASS")
print("R9_PODCAST_NO_ANALYTICS_SDK=PASS")
print("R9_PODCAST_STORAGE_PERMISSION_EXPANSION=PASS_ABSENT")
print("R9_MEDIA_FLOW_KOTLIN_WARNINGS_AS_ERRORS=PASS")
print("R9_MEDIA_FLOW_DETEKT_FAIL_CLOSED=PASS")
print("R9_MEDIA_FLOW_KTLINT_FAIL_CLOSED=PASS")
print("R9_MEDIA_FLOW_COMPOSE_NAMING_POLICY=PASS")
print("R9_MEDIA_FLOW_GLOBAL_APPEARANCE_OWNER=PASS_MEDIA_APP")
print("R9_MEDIA_FLOW_CANONICAL_SDK_QUALIFIER=PASS")
print("R9_MEDIA_FLOW_CONTRACT=PASS")
