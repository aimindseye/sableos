# R9 Media Flow — Music + Podcasts + Radio

Status: **implementation branch / pre-full-image qualification required**

Date: 2026-09-22

Branch:

```text
r9/media-flow-redesign-20260922
```

Qualified parent source:

```text
5e8ceb737c7dc4d2b858509e97027921bd2d53f9
```

The parent source completed R9 Panther module-only qualification with:

```text
R9_LAUNCHER3_HOME_PREFLIGHT=PASS
R8_UI_MODULE_BUILD=PASS
R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION
```

The Media Flow branch intentionally reopens that authorization boundary. A new
full Panther target-files build is blocked by process until this branch passes
its own static and module build qualification.

## Product direction

Sable Media is one player with three first-class content modes:

```text
music  ·  podcasts  ·  radio  ·  now playing
```

The presentation takes interaction lessons from the Zune / early Metro media
model: oversized typography, panorama-style pivots, content-first navigation,
and a persistent relationship to the now-playing queue.

The podcast model takes workflow lessons from mature podcast clients without
copying their code:

- explicit subscriptions;
- a latest-episode view;
- a saved listening list;
- a visible queue / now-playing path;
- direct episode playback;
- an explicit "+" action that sends podcast episodes into the same Up Next queue as local music.

References used for interaction research:

- https://arstechnica.com/information-technology/2010/02/microsoft-unveils-windows-phone-7-series/
- https://antennapod.org/documentation/getting-started
- https://antennapod.org/documentation/getting-started/home
- https://pocketcasts.com/podcast-player
- https://support.pocketcasts.com/knowledge-base/playing-episodes-and-managing-your-queue/

## Privacy and security boundary

Podcast support is deliberately explicit-network-action only and HTTPS-only.

Current R9 Media Flow behavior:

- the user pastes a publisher RSS or Atom feed URL;
- feed refresh happens only when subscribing or pressing Refresh;
- only HTTP(S) feed and episode URLs are accepted, including the final URL after redirects;
- no podcast account is required;
- no analytics SDK is introduced;
- no podcast recommendation/discovery directory is queried;
- no periodic WorkManager/AlarmManager refresh is introduced;
- no broad storage/media permission is added;
- feed bodies are bounded to 4 MiB;
- cached episodes are bounded to 200 per feed;
- XML document-type declarations are rejected;
- a failed refresh retains the prior cached feed;
- saved episodes are local bookmarks, not claims of offline download.

Sable Media already declares the GrapheneOS-revocable
`android.permission.INTERNET`; the new flow does not add a second network
permission model.

## Playback ownership

There remains exactly one playback substrate:

```text
PlaybackService
  -> MediaSessionService
  -> one ExoPlayer
  -> local music / podcast episode / user-managed radio stream
```

Podcast playback does not introduce a second service/player stack. Podcast
episodes enter the existing Now Playing surface through `ACTION_PLAY_URI`.
The podcast `+` action uses the existing MediaController to append an episode
to the same Up Next queue used by local music. No podcast-specific player or
queue service is introduced.

## Persistence

Podcast data is local application state:

- subscribed feed metadata and bounded episode cache;
- saved episode IDs;
- played episode IDs.

No remote sync account is introduced in this tranche.

## Visual model

Top-level navigation changes from compact tab-like controls to a scrollable
panorama pivot:

```text
music   podcasts   radio   now playing
```

Music keeps:

- local SAF file import;
- folder import;
- songs / artists / albums / favorites / playlists;
- user-owned playlists.

Podcasts adds:

- latest;
- shows;
- saved;
- manual feed subscription;
- explicit refresh;
- direct playback through the shared player.

Radio keeps the user-managed direct stream model.

Remote podcast artwork is intentionally not fetched in this tranche. Podcast
cards use deterministic Sable color/monogram artwork so opening the podcast
surface does not contact image/CDN hosts beyond the feed and episode actions
the user explicitly requests.

## Static contract

Mandatory source gate:

```bash
python3 build/gates/r9-media-flow-contract.py
```

Required markers:

```text
R9_MEDIA_FLOW_PANORAMA_NAVIGATION=PASS
R9_MEDIA_FLOW_SINGLE_MEDIA3_SESSION=PASS
R9_MEDIA_FLOW_SHARED_UP_NEXT=PASS
R9_PODCAST_EXPLICIT_SUBSCRIPTION=PASS
R9_PODCAST_MANUAL_REFRESH=PASS
R9_PODCAST_FEED_SIZE_BOUND=PASS
R9_PODCAST_HTTPS_ONLY=PASS
R9_PODCAST_XML_DOCTYPE_REJECTED=PASS
R9_PODCAST_NO_AMBIENT_DIRECTORY=PASS
R9_PODCAST_NO_BACKGROUND_POLLING=PASS
R9_PODCAST_NO_ANALYTICS_SDK=PASS
R9_PODCAST_STORAGE_PERMISSION_EXPANSION=PASS_ABSENT
R9_MEDIA_FLOW_CANONICAL_SDK_QUALIFIER=PASS
R9_MEDIA_FLOW_CONTRACT=PASS
```

The gate is also required by
`build/panther/qualify-r9-physical-ux.sh` and checked by the canonical
pipeline contract.

## Kotlin quality closure

The first canonical focused build completed successfully and produced a valid
Media APK, but its quality tasks exposed substantial pre-existing and new
Kotlin debt: oversized lifecycle/UI functions, long parameter lists, parser
complexity, loop jump density, magic numbers, line-length/formatting issues,
and five compiler warnings in the initial podcast parser.

Those findings are treated as product-quality defects rather than accepted
warnings. The Media Flow implementation now:

- moves Compose state/event orchestration out of `MainActivity` into
  `MediaApp`, leaving the Activity as a lifecycle/service host;
- uses immutable `MediaScreenState` / `MediaScreenActions` and
  `PodcastScreenState` / `PodcastScreenActions` contracts instead of
  dozens of individual composable parameters;
- extracts RSS/Atom parsing into `PodcastFeedParser` with bounded event
  handlers and a separate HTTPS URL policy;
- decomposes playback-state assembly, local metadata inspection, folder
  traversal, playlist decoding, snapshot formatting, and persistence helpers;
- replaces anonymous timing/size values with named constants where they carry
  domain meaning;
- uses a schema-valid, presentation-file-scoped detekt policy for generic
  complexity/naming rules that detekt 1.23.8 cannot exempt by `@Composable`,
  while ktlint uses its supported annotation-aware Compose naming option;
- does not create a detekt baseline or blanket-disable the Media quality tasks;
- enables Kotlin compiler `allWarningsAsErrors` for the Media module;
- makes Media detekt and ktlint tasks fail the build on findings.

The detekt policy is intentionally narrow: only
`MediaApp.kt`, `MediaScreen.kt`, `MediaC2Screens.kt`, and
`PodcastScreen.kt` are excluded from generic UI-incompatible
`CyclomaticComplexMethod` / `LongMethod` / `LongParameterList` /
`FunctionNaming` checks. All other detekt rules still apply to those files,
and all rules remain active for repositories, playback, parsers, scanners,
services, and providers.

The focused qualifier must therefore be warning-clean. A valid result contains
no Kotlin compiler `w:` diagnostics, no detekt finding list, and no ktlint
violation list, and ends with:

```text
R9_MEDIA_FLOW_KOTLIN_WARNINGS_AS_ERRORS=PASS
R9_MEDIA_FLOW_DETEKT_FAIL_CLOSED=PASS
R9_MEDIA_FLOW_KTLINT_FAIL_CLOSED=PASS
R9_MEDIA_FLOW_COMPOSE_NAMING_POLICY=PASS
BUILD SUCCESSFUL
R9_MEDIA_FLOW_APK=PASS
R9_MEDIA_FLOW_KOTLIN_QUALITY=PASS_WARNINGS_DETEKT_KTLINT
R9_MEDIA_FLOW_FOCUSED_QUALIFICATION=PASS
```

## Strict-quality qualification correction

The strict focused qualifier was run against
`508a5fa1853f2af71bb339aa78a6d084c9f7c2e4`. The source/static contracts
passed, and the fail-closed Gradle phase then correctly rejected the candidate
before producing new qualification evidence.

Two bounded defect classes were exposed:

- detekt reported six findings: `PlaybackController` had eleven visible
  functions at a threshold of eleven; four persisted-state decoder functions
  exceeded the return-count limit; and the large artwork ratio remained an
  anonymous numeric literal;
- Kotlin compilation found four call sites where `MediaHostServices`
  function-valued actions were invoked with named arguments. Kotlin function
  types do not permit named-argument invocation.

The correction keeps the quality policy intact:

- playback previous/next are consolidated behind
  `PlaybackSkip.Previous` / `PlaybackSkip.Next` and one `skip` command;
- persisted-state decoders use expression-style nullable decoding rather than
  stacked guard returns;
- the large artwork ratio is a named constant;
- function-valued Media host actions are called positionally.

No detekt rule, ktlint rule, compiler warning policy, or fail-closed qualifier
was weakened to obtain this correction. The failed run does not authorize WS7
or a Panther image; qualification must be repeated at the new immutable head.

## Module qualification

The first manual focused-build attempt proved the static Media Flow and pipeline
contracts, but Gradle stopped before Kotlin/Java compilation because no Android
SDK location was exported. That invocation then printed a false PASS marker
because its final echo was unconditional. Neither outcome is valid build
evidence.

Focused qualification is therefore owned by the checked-in fail-closed driver:

```bash
EXPECTED_SOURCE_COMMIT="$(git rev-parse HEAD)" \
  bash build/panther/qualify-r9-media-flow.sh
```

The driver:

- uses `set -euo pipefail`;
- sources `build/config/r8-host-tools.env`;
- verifies the canonical host-tool installation;
- exports `ANDROID_HOME` and `ANDROID_SDK_ROOT` from `SABLE_ANDROID_SDK`;
- keeps Gradle offline;
- builds only the Media module plus its lint/detekt/ktlint gates;
- emits PASS only after the APK exists.

Before a fresh Panther image, this branch must pass at minimum:

```text
R9_MEDIA_FLOW_ANDROID_SDK=PASS
R9_MEDIA_FLOW_KOTLIN_WARNINGS_AS_ERRORS=PASS
R9_MEDIA_FLOW_DETEKT_FAIL_CLOSED=PASS
R9_MEDIA_FLOW_KTLINT_FAIL_CLOSED=PASS
R9_MEDIA_FLOW_COMPOSE_NAMING_POLICY=PASS
R9_MEDIA_FLOW_CONTRACT=PASS
BUILD SUCCESSFUL
R9_MEDIA_FLOW_APK=PASS
R9_MEDIA_FLOW_KOTLIN_QUALITY=PASS_WARNINGS_DETEKT_KTLINT
R9_MEDIA_FLOW_FOCUSED_QUALIFICATION=PASS
R9_MEDIA_FLOW_STATIC_CONTRACT=PASS
R9_LAUNCHER3_HOME_PREFLIGHT=PASS
R8_UI_MODULE_BUILD=PASS
R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS
```

Because Sable Media is one of the ten source-bound first-party APKs, final WS7
qualification must regenerate the ten-APK bundle at the exact final Media Flow
source commit.

## WS7 appearance-consumer gate correction

The first source-bound WS7 run after focused Media Flow qualification reached
final product composition with the ten-APK bundle correctly bound to
`463f36dd30d0fe24474e19984c0917fe6ec830b0`, including the qualified
`SableMedia.apk`.

The run then failed only at:

```text
R8_GLOBAL_APPEARANCE_CONSUMER=FAIL
R8_NO_STALE_PRODUCT_CODE=FAIL
R8_FINAL_UI_PRODUCT_COMPOSITION=FAIL
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```

This was a stale gate-owner assumption introduced by the Kotlin quality
refactor. `SableGlobalTheme(window = window)` moved from
`media/MainActivity.kt` to `media/MediaApp.kt` when the Activity was reduced
to lifecycle/service hosting. Runtime appearance ownership remained present.

The correction updates both:

- `build/gates/r8-no-stale-product-code.sh`;
- `build/gates/r8-final-product-composition.sh`;

to verify the actual Media appearance owner in `MediaApp.kt`. The Media Flow
contract now also requires the theme call in `MediaApp.kt`, forbids the old
ownership in `MainActivity.kt`, and emits:

```text
R9_MEDIA_FLOW_GLOBAL_APPEARANCE_OWNER=PASS_MEDIA_APP
```

No application behavior or APK source was changed by this gate correction.
However, release evidence remains repository-source-bound, so the prior
`463f36d...` focused/WS7 source identity does not authorize the new gate-fix
head. Focused Media qualification and WS7 must be rerun at the new immutable
source before a full Panther target-files build is authorized.

## Large-library physical regression hardening

Physical testing with a large local music library exposed ANR-class UI-thread
saturation rather than a Media3 decoder failure. R9 now treats large-library
behavior as a source and quality contract:

- Songs, Artists, Albums and Favorites are lazy-rendered;
- Up Next and playlist editing are lazy-rendered rather than eagerly composing
  every queue/library row;
- persisted collection loading runs off the UI thread;
- song sorting, artist/album grouping, source-index mapping and A-Z section
  construction run on `Dispatchers.Default` into an immutable collection index;
- playback-position ticks are enabled only while Now Playing is visible, so
  browse surfaces do not recompose every 500 ms;
- local queue launch sends one process-local opaque token rather than three
  whole-library string arrays through an Intent/Binder transaction;
- Media3 queue construction occurs off-main and is generation-guarded before
  main-thread player mutation;
- playlist membership/count checks use indexed/set lookup rather than nested
  whole-library scans;
- folder import remains deliberately bounded to 2,000 audio files until a
  larger persistence/storage design is separately qualified;
- A-Z navigation uses named structural constants and the same flat-row model as
  the R9 HOME/Contacts navigation language.

The fail-closed source contracts require markers including:

```text
R9_MEDIA_LARGE_LIBRARY_LAZY_RENDERING=PASS
R9_MEDIA_LARGE_LIBRARY_INDEX_OFF_MAIN=PASS
R9_MEDIA_PROGRESS_RECOMPOSITION=PASS_NOW_PLAYING_ONLY
R9_MEDIA_QUEUE_BINDER_PAYLOAD=PASS_TOKEN_ONLY
R9_MEDIA_QUEUE_BUILD=PASS_BACKGROUND
R9_MEDIA_LIBRARY_STARTUP_LOAD=PASS_OFF_MAIN
R9_MEDIA_FOLDER_IMPORT_BOUND=PASS_2000
```

Kotlin warnings, Detekt and KtLint remain fail-closed. These gates are not
weakened to make the Media build pass.

## Physical Panther acceptance

After a fresh image is eventually built and flashed through the standard Sable
pipeline, verify:

```text
R9_MEDIA_FLOW_MUSIC_NAVIGATION=PASS
R9_MEDIA_FLOW_PODCAST_NAVIGATION=PASS
R9_MEDIA_FLOW_RADIO_NAVIGATION=PASS
R9_MEDIA_FLOW_NOW_PLAYING=PASS
R9_MEDIA_FLOW_LOCAL_IMPORT=PASS
R9_MEDIA_FLOW_PODCAST_SUBSCRIBE=PASS
R9_MEDIA_FLOW_PODCAST_MANUAL_REFRESH=PASS
R9_MEDIA_FLOW_PODCAST_STREAM_PLAYBACK=PASS
R9_MEDIA_FLOW_PODCAST_SAVED_STATE=PASS
R9_MEDIA_FLOW_PODCAST_REMOVE_SUBSCRIPTION=PASS
R9_MEDIA_FLOW_SHARED_QUEUE=PASS
R9_MEDIA_FLOW_GLOBAL_LIGHT_DARK=PASS
R9_MEDIA_FLOW_GLOBAL_ACCENT=PASS
R9_MEDIA_FLOW_NETWORK_PERMISSION_REVOKED=PASS_EXPECTED_NETWORK_FAILURE
R9_MEDIA_FLOW_NETWORK_PERMISSION_RESTORED=PASS
```

Offline podcast download management, automatic refresh, discovery/search
directories, cross-device sync, and chapter rendering are explicitly outside
this pre-image tranche. They can be added later only with their own privacy,
storage, and lifecycle contracts.
