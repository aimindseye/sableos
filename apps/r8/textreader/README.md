# R8-D2 Vaachak Text Reader capability qualification

This directory qualifies reusable text-accessibility capability from `vaachak-platform/vaachak-textreader` without treating it as a second Sable Reader product.

## Product role

The primary Sable Reader remains the Vaachak Mobile / Readium-derived reader path. Vaachak Text Reader is a complementary capability source for plain text, accessibility, OCR, text-to-speech and Android text-sharing integration.

Candidate capabilities for Sable Reader composition:

- local `text/plain` document ingestion through Android's document picker;
- `ACTION_SEND` share-target ingestion;
- `ACTION_PROCESS_TEXT` / selected-text handoff;
- Android `TextToSpeech` playback;
- user-directed WAV export through the Storage Access Framework;
- CameraX live-scanner flow;
- gallery image OCR;
- Latin and Devanagari ML Kit text-recognition paths;
- local-translation UX/state patterns where product/privacy policy permits them.

The text stream reader (`TextReaderUtil`) is especially suitable for extraction into a small independently testable adapter because it has no Android-context dependency.

## Privacy / offline boundary

Upstream currently declares `android.permission.INTERNET`, and its translation flow calls ML Kit `downloadModelIfNeeded`. Therefore a strict offline Sable Reader must not import the translation path unchanged or claim offline closure merely because translation executes on-device after model acquisition.

The Sable integration gate must separately decide whether translation is:

1. omitted from the first offline Reader tranche;
2. retained only behind an explicit network/model-acquisition policy; or
3. accepted after a reproducible pre-provisioned-model design is proven.

OCR model packaging/runtime behavior also requires verification in the qualified APK before an offline claim is made.

Camera permission belongs only to the OCR capability and must remain optional. Plain-text/TTS reading must not require camera authority.

## Qualification boundary

The pinned source identity lives in `upstream.env`. CI clones exactly that SHA and runs upstream unit tests, debug APK assembly and lint independently from the Panther/AOSP image build.

A passing capability APK proves the upstream code compiles and its source behavior is inspectable. It does **not** prove that Sable Reader has integrated the capability, that Internet permission has been removed, or that all ML models are available offline.

## Integration direction

Preferred R8 composition:

```text
Sable Reader
  |
  +-- publication path
  |     Vaachak Mobile / Readium
  |     EPUB, library, progress, bookmarks, highlights, search
  |
  +-- text accessibility path
        Vaachak Text Reader capability
        TXT / share / process-text / TTS / OCR
```

UI3 now composes the pinned pure `TextReaderUtil` stream capability into the Sable Reader flavor for local TXT/view/share/process-text handling. The Text Reader launcher UI, translation path, OCR/camera path and theme remain outside the composed product.

The integration target remains one product identity and one launcher-visible Sable Reader. OCR and translation require separate privacy/offline gates before later composition.
