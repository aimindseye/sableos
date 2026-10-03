# Sable Reader v2 architecture and UX

Status: **accepted P5 architecture / implementation not yet started**
Date: **2026-10-02 ET / 2026-10-03 UTC**

This document finalizes P5. It extends ADR-0009 without merging Sable Text Reader
back into Sable Reader.

## Product boundary

Sable Reader remains the first-party publication/media reading product:

~~~
Sable Reader
  books / EPUB
  PDF
  comics / manga / webtoons
  audiobooks

Sable Text Reader
  plain text
  share/process-text
  local text TTS
  OCR
  text-audio export
~~~

Text Reader remains a separate launcher-visible application. Reader must not
request camera permission merely to regain Text Reader OCR.

Canonical Reader package identity remains org.sableos.reader.

The existing Vaachak-derived Reader source is the migration substrate, not the
final product identity. Preserve upstream license/provenance while progressively
moving common product code into Sable-owned namespaces and contracts.

## Product principles

~~~
LOCAL_FIRST=YES
ACCOUNT_REQUIRED=NO
TELEMETRY=NO
REMOTE_AI_DEFAULT=NO
BACKGROUND_NETWORK_DEFAULT=NO
INTERNET_PERMISSION=ABSENT_IN_P5_V2
KEYBOARD_ONLY_OPERATION=REQUIRED
TOUCH_FALLBACK=REQUIRED
DEVICE_MODEL_BRANCHING=NO
~~~

Remote Gemini/Cloudflare-AI features are not part of Sable Reader v2. Account
login/cloud sync is not part of P5. Local backup/restore is required.

P5 v2.0 remains fully local/offline and the Sable product manifest must contain no INTERNET permission. OPDS is deferred to P5.1 so any future network/catalog capability receives a separate privacy, permission and dependency review.

## Architecture

~~~
reader-app
  ui/
    library
    item-detail
    search
    collections
    settings
    keyboard-command-surface

reader-core
  model/
    LibraryItem
    PublicationKind
    ReadingProgress
    Locator
    Bookmark
    Highlight
    Collection
    PlaybackBookmark
  repository/
    LibraryRepository
    ProgressRepository
    CollectionRepository
    BackupRepository
  storage/
    Room
    DataStore
    SAF/import

reader-engine-epub
  Readium streamer + navigator
  EPUB 2/3 reflowable + fixed layout
  bookmarks/highlights/search/TTS

reader-engine-pdf
  Android PdfRenderer
  paged renderer
  page progress/bookmarks
  no text highlight/search claim in v2.0

reader-engine-comic
  CBZ + image-directory source
  natural ordering + ComicInfo.xml metadata
  paged LTR
  paged RTL/manga
  vertical pager
  continuous/webtoon
  bounded image decode

reader-engine-audio
  Media3 ExoPlayer
  MediaSession/MediaLibraryService
  chapter/progress/bookmark/sleep timer
  background/headset/lock-screen controls
~~~

Each engine implements a small capability contract. Unsupported capabilities
must be absent/disabled rather than faked.

Example capability distinctions:

~~~
EPUB: text search/highlight/TTS = YES
PDF v2.0: text search/highlight/TTS = NO
COMIC: text search/highlight/TTS = NO
AUDIO: visual text highlight = NO
~~~

## Library model

One library owns all publication types.

Required top-level views:

~~~
Continue
All
Books
Comics
Audiobooks
Collections
Recent
Finished
~~~

A library item stores common metadata:

~~~
id
kind
title
subtitle
authors
series
series_index
cover
source_uri / managed_file
mime/format
added_at
last_opened_at
progress
finished
favorite
collection_ids
~~~

Format-specific state remains behind typed engine metadata.

No media file is silently uploaded.

## Storage and import policy

Use Android Storage Access Framework for user-directed file/folder selection.

Sable Reader may maintain app-private managed copies when random-access or
lifetime guarantees require them. The UI must make import/copy behavior clear.

Do not extract comic archives into shared storage.

Archive readers must:

~~~
reject path traversal
never write archive-relative paths directly
bound entry count and decoded image size
sample images to the viewport
avoid decoding an entire archive at once
handle malformed/truncated archives fail-closed
~~~

## Format decision

| Format | P5 decision | Engine / note |
| --- | --- | --- |
| EPUB 2 / EPUB 3 | YES | Readium |
| EPUB fixed layout | YES | Readium |
| PDF | YES | Android PdfRenderer; page reading/bookmarks/progress in v2.0 |
| CBZ | YES | Sable comic engine over ZIP |
| image directory | YES | Sable comic engine |
| CBR / RAR | DEFER | no RAR dependency in P5 |
| Readium Divina | DEFER | revisit after comic core is stable |
| DRM-free MP3 | YES | Media3 |
| AAC / M4A | YES | Media3 |
| M4B | YES | Media3, including embedded chapters where extractor exposes them |
| Ogg/Vorbis / Opus | YES | Media3 / platform decoder support |
| FLAC | YES | Media3 |
| WAV | YES | Media3 |
| multi-file audiobook folder | YES | ordered playlist + chapter model |
| zipped/readium audiobook | P5.1 | Readium parser may supply publication order; Media3 remains playback engine |
| MOBI / AZW / KFX | NO | proprietary/legacy format family not in P5 |
| DJVU | NO | separate dependency/security review required |
| DAISY | DEFER | future accessibility-specific work |
| TXT / Markdown | Text Reader | not Reader ownership |

YES means the product architecture admits the format. Device codec support may
still bound particular audio encodings.

## Comic UX

Mihon is a product/UX reference, not a runtime dependency.

Adopt these concepts:

~~~
local library
categories/collections
read/unread/finished progress
configurable reading direction
paged viewers
continuous/webtoon viewer
bookmarks
recent history
local backup
~~~

Do not adopt in P5:

~~~
download/source extension ecosystem
third-party executable plugins
tracker-account integrations
background source scraping
remote content-provider assumptions
~~~

Required comic modes:

~~~
PAGED_LTR
PAGED_RTL
VERTICAL_PAGER
CONTINUOUS_VERTICAL
WEBTOON
~~~

Per-title mode is persisted.

Comic metadata priority:

~~~
ComicInfo.xml
 -> archive/folder name
 -> user edits
~~~

User edits are local and never rewrite the source archive automatically.

## Audiobook UX

Use one persistent background playback service.

Required:

~~~
play/pause
seek forward/back
previous/next chapter
chapter list
resume position
playback speed
sleep timer
time bookmarks
finished state
headset/media-button support
lock-screen/system media controls
~~~

No streaming service account is required.

For multi-file books, each file can form a chapter when embedded chapter
metadata is absent.

For M4B/MP4 audio, use Media3 chapter metadata when available rather than adding
a separate MP4 parser dependency.

## Android audiobook service contract

Audiobook playback is not an Activity-lifetime feature. P5D must provide a
Media3 `MediaLibraryService` (or equivalently justified MediaSession service)
hosting the player/session.

For target SDK 36 the Sable Reader manifest must explicitly declare the
media-playback foreground-service boundary:

~~~
android.permission.FOREGROUND_SERVICE
android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK

service:
  exported = false
  foregroundServiceType = mediaPlayback
~~~

The service must own the active MediaSession, playback notification/system media
controls and restore current audiobook/chapter/progress state after UI
re-creation. The UI binds/controls the service; it must not create an independent
second player.

No broad background networking permission is implied by background local audio
playback.

## Keyboard-first interaction

Reader consumes common semantic actions. Do not branch on Titan model names or
hard-code scan codes.

When no editable field owns input:

| Context | Required semantic behavior |
| --- | --- |
| Library | arrows move focus; Enter opens; Search opens filter/search; Menu opens item actions |
| EPUB/PDF paged | Left/Right and PageUp/PageDown navigate; Space advances; Shift+Space reverses |
| EPUB/PDF scroll | Up/Down scroll; PageUp/PageDown page-scroll |
| Comic paged | Left/Right honor reading direction |
| Comic webtoon | Up/Down scroll; PageUp/PageDown larger scroll |
| Any visual reader | B bookmark; T contents/chapter list; F find only when engine supports it; A appearance/view settings |
| Audiobook | Space play/pause; Left/Right bounded seek; chapter actions exposed through semantic previous/next chapter |
| Any surface | Back/Escape closes transient UI before leaving the item |

Letter shortcuts yield to editable text exactly as KF2 requires.

A dismissible key-hint legend is allowed; permanent chrome is not required.

## Titan/square-display UX

The main reading surface should maximize content.

~~~
persistent side navigation=NO
transient top/bottom chrome=YES
visible keyboard focus=YES
square-display safe insets=YES
font-scale resilience=REQUIRED
touch-only hidden gesture=FORBIDDEN
~~~

Library density is profile-driven, not device-name-driven.

The comic viewer should default to one full page on square displays unless the
publication/user selects continuous/webtoon mode.

## Privacy/network changes from current Reader source

P5 should remove or retire from the Sable flavor:

~~~
Gemini Generative AI dependency
Cloudflare AI API
remote recap/Ask AI UI
account-login requirement
cloud SyncApi requirement
built-in background catalog refresh
~~~

Keep:

~~~
local dictionary
local publication TTS
local highlights/bookmarks
local backup/export
~~~

Defer:

~~~
OPDS / remote catalogs -> P5.1
~~~

A future Sable local-AI feature requires its own model/provenance/privacy
decision and is not part of P5.

## Dependency decisions

### Keep/pin for P5 baseline

~~~
Readium Kotlin Toolkit 3.1.2
Room 2.8.4
DataStore 1.2.0
Hilt 2.57.2
Coil 2.7.0 (covers/library imagery)
Kotlin serialization/coroutines already in Reader
~~~

Readium 3.1.2 remains pinned for P5 functionality so the redesign does not also
become a Readium/toolchain migration. A Readium upgrade is a separate bounded
dependency PR.

### Upgrade/add

Use a single aligned Media3 version:

~~~
androidx.media3:media3-common:1.11.1
androidx.media3:media3-exoplayer:1.11.1
androidx.media3:media3-session:1.11.1
androidx.media3:media3-extractor:1.11.1
~~~

Media3 1.11.x provides native chapter metadata for MP4/M4A/M4B and ID3 chapter
support, avoiding a new MP4 parser dependency.

Do not add DASH/HLS/Cast modules for P5 local audiobook playback.

### Do not add

~~~
Mihon runtime dependency
Mihon extension API
RAR/CBR library
FFmpeg
mp4parser
commercial PDF SDK
new analytics SDK
new cloud sync SDK
~~~

### Remove if no longer referenced

~~~
google-generativeai
remote AI repositories/APIs
readium-lcp from the Sable baseline
readium-opds from the P5 v2 baseline
Retrofit/OkHttp/Ktor app-owned network stacks when no remaining local feature requires them
commons-compress if no remaining Reader feature uses it
~~~

Readium LCP is not part of the initial Sable Reader v2 because it requires a
separate LCP binary/provisioning relationship and DRM policy decision.

## PDF choice

P5 intentionally uses Android PdfRenderer instead of adding Readium's
Pdfium/AndroidPdfViewer adapter.

Rationale:

~~~
fewer native/third-party dependencies
no commercial SDK
sufficient for page rendering/progress/bookmarks
keeps P5 focused on reading rather than PDF editing
~~~

Consequences for v2.0:

~~~
PDF_TEXT_SEARCH=NO
PDF_TEXT_HIGHLIGHT=NO
PDF_TTS=NO
PDF_PAGE_BOOKMARKS=YES
PDF_PROGRESS=YES
~~~

Those capabilities may be reconsidered later with a separately qualified PDF
engine.

## P5 delivery sequence

P5 is a sibling workstream, not stacked on P1-P4.

~~~
P5A  Reader baseline/privacy/dependency cleanup + common library model
P5B  keyboard-first EPUB/PDF UX
P5C  CBZ/image comic engine + manga/webtoon UX
P5D  audiobook engine + background MediaSession
P5E  unified backup/collections/progress + quality gates
P5F  exact-head ai-g732 Android qualification
~~~

P5 may start after this architecture is accepted, but it should not be merged
into the P1-P4 train.

## Acceptance

P5 source qualification requires:

~~~
READER_TEXTREADER_BOUNDARY=PASS_SEPARATE
READER_REMOTE_AI=PASS_ABSENT
READER_ACCOUNT_REQUIRED=NO
READER_INTERNET_PERMISSION=PASS_ABSENT
READER_OPDS=P5_1_DEFERRED
READER_TELEMETRY=PASS_ABSENT
READER_KEYBOARD_FIRST=PASS
READER_EPUB=PASS
READER_PDF_PAGE_READING=PASS
READER_CBZ=PASS
READER_COMIC_RTL=PASS
READER_WEBTOON=PASS
READER_AUDIOBOOK=PASS
READER_AUDIO_BACKGROUND_SESSION=PASS
READER_AUDIO_MEDIA_PLAYBACK_FGS=PASS
READER_M4B_CHAPTERS=PASS_WHEN_PRESENT
READER_LOCAL_BACKUP=PASS
READER_CBR=DEFERRED
READER_LCP=DEFERRED
DEVICE_RUNTIME_VALIDATED=NO_UNTIL_OPERATOR
~~~

Physical acceptance later covers keyboard ergonomics, large-library behavior,
memory pressure, long audiobook playback, sleep timer, headset controls,
rotation/insets and real large CBZ/PDF files.
