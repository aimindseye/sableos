# ADR-0009: Separate Sable Reader and Sable Text Reader products

Status: Accepted  
Date: 2026-09-23

## Context

The earlier R8/R9 Reader composition imported Vaachak Text Reader capabilities
into Sable Reader as internal, non-launcher activities. This allowed
`text/plain`, Android share/process-text, TTS and OCR to exist technically, but
those functions were not discoverable from the normal Sable Reader product UI.

The result was an unclear ownership boundary: Sable Reader was both a
publication reader and the hidden host for an unrelated plain-text/OCR
workflow.

## Decision

SableOS will ship two distinct first-party applications.

### Sable Reader

`org.sableos.reader` owns publication/e-book behavior:

- publication library and navigation;
- Readium/EPUB rendering;
- bookmarks and highlights;
- publication TTS;
- Sepia and E-Ink reading modes;
- global SableOS Light/Dark application appearance.

It does not compose TextReader runtime source and does not request camera
permission.

### Sable Text Reader

`org.sableos.textreader` is a standalone launcher-visible application derived
from the separately pinned Vaachak Text Reader upstream.

It owns:

- local plain-text file opening;
- `ACTION_VIEW`, `ACTION_SEND` and `ACTION_PROCESS_TEXT`;
- paste/edit workflows;
- text TTS and audio export;
- user-directed camera/gallery OCR;
- Latin and Devanagari OCR;
- global SableOS appearance.

The first Sable Text Reader product is offline-first. It removes the upstream
`INTERNET` permission, ML Kit translation dependency/UI and model-download
path. Camera hardware remains optional and camera permission is requested only
for camera OCR.

## Build and product consequences

- Text Reader has its own Sable flavor applicator and verifier.
- Reader no longer accepts a TextReader checkout as composition input.
- Full local CI has separate `TEXTREADER` and `READER` product stages.
- Panther gains the prebuilt module `SableTextReader`.
- The source-bound Panther application bundle grows from ten to eleven prebuilt
  APKs.
- Target-files qualification requires exactly one `SableTextReader.apk` with
  package `org.sableos.textreader`.
- Legacy upstream artifact names such as `VaachakTextReader.apk` and
  `TextReader.apk` remain forbidden.
- The focused entry point is
  `bash build/sable.sh panther R9 qualify textreader`.

## Rationale

A first-class application makes the capability discoverable and gives plain
text/OCR a coherent permission and UX boundary. It also lets Reader remain
focused on publications and avoids duplicating OCR/camera behavior inside two
products.

## Consequences

The split increases the staged Sable prebuilt inventory by one APK and requires
new product, bundle, target-files, icon, CI and stale-code contracts.

Publication TTS remains in Reader. Text-specific TTS belongs to Text Reader.
Translation remains deferred until SableOS has an explicit offline model and
privacy policy.
