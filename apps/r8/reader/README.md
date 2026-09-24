# R9 Sable Reader composition and qualification

Sable Reader is the SableOS publication/e-book application built from the
pinned Vaachak Mobile / Readium-derived reader path.

## Product identity

```text
name     Sable Reader
package  org.sableos.reader
module   SableReader
```

R9 deliberately separates Reader from Sable Text Reader:

```text
Sable Reader
  publication library
  EPUB / Readium
  bookmarks / highlights
  publication TTS
  Sepia / E-Ink reading modes

Sable Text Reader
  text/plain
  VIEW / SEND / PROCESS_TEXT
  paste / edit
  text TTS / audio export
  camera + gallery OCR
```

There is no hidden TextReader runtime inside Sable Reader.

## Upstream pin and composition

The Reader upstream identity is recorded in `upstream.env`.
`apply_sable_flavor.py` mutates only an ephemeral Reader checkout. It:

1. adds the `sable` product flavor with application ID
   `org.sableos.reader`;
2. composes the canonical Sable design source;
3. keeps the upstream publication/database/Readium engine;
4. applies the qualified Reader API/warning migrations;
5. routes ordinary Light/Dark application chrome through Sable global
   appearance;
6. retains Sepia and E-Ink as explicit reading-surface modes;
7. keeps the continuous actual-book library/navigation behavior;
8. removes `INTERNET` from the Sable product manifest;
9. does not compose TextReader, OCR or camera runtime code.

Publication TTS remains a Reader feature because speaking the current
publication is part of the book-reading experience. Plain-text TTS belongs to
Sable Text Reader.

## Product policy

```text
package                    org.sableos.reader
launcher surfaces          exactly one
INTERNET permission        ABSENT
CAMERA permission          ABSENT
SableTextActivity          ABSENT
SableOcrActivity           ABSENT
plain-text intent filters  ABSENT from Sable-specific overlay
ordinary Light/Dark        SableOS global appearance
Sepia                      Reader reading override
E-Ink                      Reader reading override
```

This separation avoids duplicate plain-text/OCR surfaces, duplicate camera
authority and two competing places for the same task.

## Qualification

The full local-CI `READER` stage now checks out only the pinned Reader
upstream. It no longer checks out or composes Vaachak Text Reader.

It runs Reader unit tests, Sable-flavor unit tests, lint, merged-manifest
verification and `:leisure:assembleSableDebug`. The manifest gate requires:

```text
SABLE_READER_CAMERA_PERMISSION=PASS_ABSENT
SABLE_READER_TEXTREADER_COMPONENTS=PASS_ABSENT
SABLE_READER_SINGLE_LAUNCHER=PASS
SABLE_READER_PUBLICATION_FOCUS=PASS
SABLE_READER_TEXTREADER_RUNTIME=PASS_ABSENT
```

The resulting Reader APK is independently source-bound into the Panther bundle
as `SableReader.apk`.
