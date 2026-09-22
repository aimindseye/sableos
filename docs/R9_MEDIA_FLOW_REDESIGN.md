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
- direct episode playback.

References used for interaction research:

- https://arstechnica.com/information-technology/2010/02/microsoft-unveils-windows-phone-7-series/
- https://antennapod.org/documentation/getting-started
- https://antennapod.org/documentation/getting-started/home
- https://pocketcasts.com/podcast-player
- https://support.pocketcasts.com/knowledge-base/playing-episodes-and-managing-your-queue/

## Privacy and security boundary

Podcast support is deliberately explicit-network-action only.

Current R9 Media Flow behavior:

- the user pastes a publisher RSS or Atom feed URL;
- feed refresh happens only when subscribing or pressing Refresh;
- only HTTP(S) feed and episode URLs are accepted;
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
The existing queue remains the common playback queue.

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
R9_PODCAST_EXPLICIT_SUBSCRIPTION=PASS
R9_PODCAST_MANUAL_REFRESH=PASS
R9_PODCAST_FEED_SIZE_BOUND=PASS
R9_PODCAST_XML_DOCTYPE_REJECTED=PASS
R9_PODCAST_NO_AMBIENT_DIRECTORY=PASS
R9_PODCAST_NO_BACKGROUND_POLLING=PASS
R9_PODCAST_NO_ANALYTICS_SDK=PASS
R9_PODCAST_STORAGE_PERMISSION_EXPANSION=PASS_ABSENT
R9_MEDIA_FLOW_CONTRACT=PASS
```

The gate is also required by
`build/panther/qualify-r9-physical-ux.sh` and checked by the canonical
pipeline contract.

## Module qualification

Before a fresh Panther image, this branch must pass at minimum:

```text
:media:assembleDebug
R9_MEDIA_FLOW_STATIC_CONTRACT=PASS
R9_LAUNCHER3_HOME_PREFLIGHT=PASS
R8_UI_MODULE_BUILD=PASS
R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS
```

Because Sable Media is one of the ten source-bound first-party APKs, final WS7
qualification must regenerate the ten-APK bundle at the exact final Media Flow
source commit.

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
