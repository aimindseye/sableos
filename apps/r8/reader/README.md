# R8 Sable Reader composition and qualification

Sable Reader is composed from pinned upstream capability sources rather than maintained as a forked/copy-pasted reader engine.

## Product identity

UI3 produces **one launcher-visible Sable Reader**:

```text
org.sableos.reader
  |
  +-- publication path
  |     Vaachak Mobile / Readium
  |     EPUB / bookshelf / progress / bookmarks / highlights / search / TOC
  |
  +-- text/accessibility path
        pinned Vaachak Text Reader capability
        TXT / ACTION_VIEW / ACTION_SEND / ACTION_PROCESS_TEXT
        local Android text-to-speech
        user-directed camera/gallery OCR
        Latin + Devanagari recognition
```

The plain-text path is an internal Sable-flavor activity. It has no launcher intent and therefore does not create a second Reader product.

## Pinned inputs

- Vaachak Mobile identity: `upstream.env`
- Vaachak Text Reader identity: `../textreader/upstream.env`
- Sable UI implementation: `src/android/shared/sabledesign` from this repository

CI verifies both upstream SHAs before composition.

## UI3 composition

`apply_sable_flavor.py` mutates only ephemeral CI checkouts and:

1. adds the `sable` product flavor with application ID `org.sableos.reader`;
2. composes the canonical Sable design source into the ephemeral Reader build;
3. leaves Vaachak's own flavor visually unchanged;
4. routes Sable light/dark Reader surfaces through the Sable design system while preserving the upstream E-ink theme;
5. composes the pinned MIT-licensed `TextReaderUtil` and `CameraScannerView` capabilities from Vaachak Text Reader;
6. adds the Sable plain-text activity for TXT/view/share/process-text/TTS;
7. adds an internal non-launcher OCR activity for camera/gallery recognition;
8. requests camera permission only when camera OCR is selected and keeps camera hardware optional;
9. uses the pinned bundled ML Kit Latin and Devanagari recognizers;
10. removes `INTERNET` from the Sable manifest and does not import the translation/model-download path, Text Reader launcher UI or independent theme.

The publication engine/database/Readium code remains upstream.

## Privacy and authority boundary

The first UI3 tranche requires:

```text
INTERNET permission       ABSENT
CAMERA permission         DECLARED / REQUESTED ONLY FOR CAMERA OCR
camera hardware feature   OPTIONAL
TXT local read            ENABLED
ACTION_VIEW text/plain    ENABLED
ACTION_SEND text/plain    ENABLED
ACTION_PROCESS_TEXT       ENABLED
local text-to-speech      ENABLED
gallery OCR               ENABLED
camera OCR                ENABLED
Latin OCR                 ENABLED
Devanagari OCR            ENABLED
translation/model fetch   DEFERRED / NOT COMPOSED
second Reader launcher    FORBIDDEN
```

Plain-text document reads are bounded to 2 MiB before the upstream stream utility receives the input.

Translation remains deferred because the pinned Text Reader translation path may acquire ML models over the network. OCR is composed with the non-Play-Services ML Kit recognizer artifacts from the pinned capability source; the Sable flavor removes INTERNET and has no OCR network fallback. Physical-device runtime qualification still verifies both scripts and failure behavior before R8-D2 is closed.

## Qualification

The Reader build lane:

- verifies both upstream commits;
- applies the composition;
- runs Vaachak core tests;
- runs Sable-flavor unit tests, including the composed text utility;
- assembles exactly one Sable Reader qualification APK;
- seals its SHA-256 and uploads the APK.

The Reader static/policy lane:

- lints the composed Sable flavor;
- builds the merged manifest;
- proves `INTERNET` is absent;
- proves camera hardware remains optional and the OCR activity is internal;
- proves exactly one launcher component exists;
- proves the internal text activity handles VIEW, SEND and PROCESS_TEXT for `text/plain`;
- proves the composed Gradle graph uses the pinned Latin/Devanagari ML Kit recognizers and does not import the translation path.

Passing these gates proves the standalone Reader composition. It does not yet prove Panther product-image integration or runtime behavior on a physical device.
