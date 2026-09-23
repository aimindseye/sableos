# R9 Sable Text Reader

Sable Text Reader is a standalone SableOS application for plain text,
accessibility-oriented reading and user-directed OCR.

## Product identity

```text
name     Sable Text Reader
package  org.sableos.textreader
module   SableTextReader
```

It is intentionally separate from Sable Reader. Sable Reader owns publications
and Readium-based book reading; Sable Text Reader owns plain-text workflows.

## Upstream pin

The product is composed from the pinned Vaachak Text Reader source recorded in
`upstream.env`:

```text
repository  https://github.com/vaachak-platform/vaachak-textreader.git
commit      50fca365baae9869264716569830690fb62029a7
```

The upstream checkout is ephemeral build input. SableOS does not vendor a
copy-pasted fork into this repository.

## Product surface

The standalone application provides:

- one launcher-visible Text Reader activity;
- local text-file opening with `ACTION_VIEW` / `text/plain`;
- Android `ACTION_SEND` text ingestion;
- Android `ACTION_PROCESS_TEXT` selected-text handoff;
- paste/edit text;
- Android text-to-speech playback;
- WAV audio export through the Android document picker;
- user-directed live camera OCR;
- user-directed gallery/image OCR;
- Latin and Devanagari OCR;
- Sable global Light/Dark/accent appearance.

The product API floor is Android 11 / API 30, matching the current SableOS
application baseline.

## Privacy boundary

The Sable flavor is offline-first:

```text
INTERNET permission       ABSENT
translation dependency    ABSENT
translation UI            ABSENT
model download path       ABSENT
camera permission          DECLARED; runtime-requested for camera OCR
camera hardware            OPTIONAL
gallery OCR                ENABLED without camera permission
backup                      DISABLED
```

The pinned upstream application includes ML Kit translation and calls
`downloadModelIfNeeded`. Those paths are deliberately removed from the Sable
product. Translation can only be reconsidered later with an explicit offline
model-packaging and privacy design.

OCR remains local to the application. The current product uses the pinned Latin
and Devanagari recognizer dependencies and has no Sable network fallback.

## Appearance

`apply_sable_flavor.py` composes the canonical Sable design sources into the
ephemeral Text Reader checkout and routes the application through
`SableGlobalTheme(window = window)`. Settings remains the persisted global
appearance authority at `content://org.sableos.appearance/appearance`.

## Qualification

Focused qualification:

```bash
bash build/sable.sh panther R9 qualify textreader
```

The focused gate is source-bound, offline, non-device and non-image. It:

1. verifies the standalone Text Reader architecture contract;
2. verifies system-cohesion and physical-UX source contracts;
3. verifies the exact pinned upstream cache;
4. applies the Sable flavor in a temporary checkout;
5. verifies the composed source policy;
6. runs upstream/Sable unit tests;
7. runs Android lint;
8. assembles the debug qualification APK;
9. verifies APK package identity as `org.sableos.textreader`;
10. records its SHA-256.

Expected final marker:

```text
R9_TEXT_READER_FOCUSED_QUALIFICATION=PASS
```

Full local CI independently repeats the Text Reader product build in the
`TEXTREADER` stage. The release-candidate path then source-binds its qualified
APK into the eleven-APK Panther bundle as `SableTextReader.apk`.

A focused Text Reader pass does not authorize target-files generation, device
contact or flashing.
