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
  +-- plain-text accessibility path
        pinned Vaachak Text Reader stream utility
        TXT / ACTION_VIEW / ACTION_SEND / ACTION_PROCESS_TEXT
        local Android text-to-speech
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
5. copies only the pinned, MIT-licensed pure `TextReaderUtil` capability from Vaachak Text Reader;
6. adds the Sable plain-text activity for TXT/view/share/process-text;
7. removes `INTERNET` from the Sable manifest;
8. does **not** import Text Reader translation, OCR, camera, launcher UI or independent theme.

The publication engine/database/Readium code remains upstream.

## Privacy and authority boundary

The first UI3 tranche requires:

```text
INTERNET permission       ABSENT
CAMERA permission         ABSENT
TXT local read            ENABLED
ACTION_VIEW text/plain    ENABLED
ACTION_SEND text/plain    ENABLED
ACTION_PROCESS_TEXT       ENABLED
local text-to-speech      ENABLED
OCR                       DEFERRED
translation/model fetch   DEFERRED
second Reader launcher    FORBIDDEN
```

Plain-text document reads are bounded to 2 MiB before the upstream stream utility receives the input.

Translation remains deferred because the pinned Text Reader translation path may acquire ML models over the network. OCR remains deferred because it introduces camera authority and model/runtime qualification requirements.

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
- proves `INTERNET` and `CAMERA` are absent;
- proves exactly one launcher component exists;
- proves the internal text activity handles VIEW, SEND and PROCESS_TEXT for `text/plain`.

Passing these gates proves the standalone Reader composition. It does not yet prove Panther product-image integration or runtime behavior on a physical device.
