# R8 standalone application qualification workspace

## R8-F — Sable Hub / Messages

R8-F adds `org.sableos.hub` as the common central communication surface before the final Panther build.

The standalone Android module provides:

- Metro/Sable ALL / MESSAGES / PEOPLE / SERVICES pivots;
- Android Telephony SMS history/send capability when the Sable build/user grants it;
- ContactsProvider person display without creating a separate cloud/history database;
- explicit fallback to the proven Android messaging transport for MMS/RCS and when restricted SMS access is unavailable;
- isolated WEB provider processes for WhatsApp, Instagram, Facebook/Messenger and LinkedIn;
- truthful provider capability classification rather than private-protocol scraping;
- common semantics intended for later Titan 2/Q27 keyboard-first presentation.

R8-F does not take the default SMS role in this tranche. Full default-handler SMS/MMS ownership is a later independent qualification gate.

The final Panther bundle/product/target-files gates require `SableHub.apk` / `org.sableos.hub`.

## 2026-09-19 final Pixel integration requirement

The standalone qualification boundary remains useful, but the next Panther build is now gated by `docs/R8_PIXEL_UI_PRODUCT_CLOSURE.md`.

Current classification:

```text
R8-B Calculator + Convert       standalone/emulator PASS; Panther integration missing
R8-C Games                      standalone/emulator PASS; Panther integration missing
R8-D Reader publication        standalone CI qualified; product/physical review pending
R8-D2 TXT/share/process/TTS     composed
R8-D2 OCR                       NOT integrated
R8-E Media                      standalone/emulator PASS; Panther integration missing
```

OCR is required for the current R8-D2 UI closure. Translation/model download is not. The OCR integration must keep camera permission optional, support user-directed camera/gallery inputs, qualify Latin and Devanagari recognition, and define truthful offline/model-availability behavior without silent network fallback.

A successful standalone APK build is no longer sufficient to authorize the final Panther UI build. The generated Panther product graph/target-files must prove the exact intended Sable APK set before the full build begins.

This directory is the source/application qualification side of the R8 split pipeline. It is intentionally independent from the Panther/AOSP image build.

## Pipelines

| Lane | Purpose | GitHub workflow |
| --- | --- | --- |
| Rust correctness | format, Clippy, host tests | `R8 Rust correctness` |
| Rust security | RustSec + dependency inventory | `R8 Rust security` |
| Android build | design tests + Kotlin/Java/Compose APK compilation | `R8 Android compile and tests` |
| Android static | Android Lint independent of build success | `R8 Android static analysis` |
| Reader build | pinned Vaachak Mobile core/Sable flavor tests + APK compile | `R8 Reader compile and tests` |
| Reader policy | Sable Reader lint + offline-manifest policy | `R8 Reader static and policy` |
| Text Reader build | pinned Vaachak Text Reader unit tests + qualification APK | `R8 Text Reader compile and tests` |
| Text Reader policy | lint + TXT/share/TTS/OCR capability/provenance checks | `R8 Text Reader static and capability policy` |
| Artifact seal | package IDs, permissions, APK SHA-256 + uploaded qualification artifacts | `R8 APK artifact seal` |

No lane authorizes a Panther full image build by itself. Product integration begins only after the selected R8 workstreams pass and exact artifacts are frozen.

## Local macOS/Linux preflight

Local runs are useful for fast iteration. GitHub CI remains the freeze authority.

### Rust

```bash
cd apps/r8/rust
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-targets
```

For the dependency/security lane:

```bash
cd apps/r8/rust
cargo generate-lockfile
cargo install cargo-audit --locked
cargo audit --deny warnings
cargo tree --locked
```

### Android

Requirements: JDK 17, Android SDK platform 36/build-tools 36.0.0, Gradle 8.13.

```bash
gradle -p apps/r8/android :design:testDebugUnitTest \
  :calculator:assembleDebug \
  :games:assembleSudokuDebug \
  :games:assembleMinesweeperDebug \
  :games:assembleGame2048Debug \
  :media:assembleDebug

gradle -p apps/r8/android \
  :design:lintDebug \
  :calculator:lintDebug \
  :convert:lintDebug \
  :games:lintSudokuDebug \
  :games:lintMinesweeperDebug \
  :games:lintGame2048Debug \
  :media:lintDebug
```

### Reader

Reader CI intentionally clones the exact Vaachak Mobile SHA from `reader/upstream.env` and applies `reader/apply_sable_flavor.py`. Use the workflow as the canonical recipe rather than maintaining a second copied reader tree.

### Text Reader capability

Text Reader CI clones the exact `vaachak-platform/vaachak-textreader` SHA from `textreader/upstream.env`. It is qualified as a capability source, not as a second launcher-visible Sable Reader.

The intended composition is:

```text
Sable Reader
  +-- Vaachak Mobile / Readium publication path
  +-- Vaachak Text Reader text-accessibility path
        TXT / share / process-text / TTS / OCR
```

Upstream currently declares `INTERNET`, and the translation path downloads ML Kit models when needed. A passing upstream Text Reader qualification therefore does not prove strict Sable offline policy. Translation/model acquisition and OCR model availability remain explicit integration gates.

## Integration boundary

The Android shells establish package identity, lifecycle, Compose/design consumption, Media3 playback ownership, and build/test seams. Calculator, conversion, and Games have JNI wiring to the portable Rust domains.

Sable Convert is no longer intended to be a separate launcher-visible APK. The `:convert` Android module is an internal Calculator feature library, and Sable Calculator owns the Regular, Scientific, and Converter surfaces. The qualification APK set is therefore Calculator, Sable Sudoku, Sable Minesweeper, Sable 2048, and Media, with Reader qualified through its separate pinned upstream lanes.

UI2 is merged. UI2G packages the shared touch-first Sudoku, Minesweeper and 2048 screens as three distinct launcher APKs using product flavors in the qualified `:games` module. The three APKs retain one Rust/JNI implementation boundary while receiving distinct package identities and launcher labels. Reader/Text Reader composition follows UI2/UI2G, then the existing standalone qualification and exact artifact-freeze gates apply.

UI3 composes one Sable Reader qualification APK from the pinned Vaachak Mobile publication path plus the bounded Vaachak Text Reader plain-text stream capability. The composed manifest must prove one launcher, no INTERNET/CAMERA authority, and text/plain VIEW/SEND/PROCESS_TEXT support. OCR and translation remain deferred gates.

INFRA5 encrypted trusted-runner activation is intentionally deferred and does not block this R8 work. Current qualification remains on GitHub-hosted CI; see `docs/INFRA5_DEFERRED_TRUSTED_RUNNER.md`.

This distinction is intentional: a compiling shell does not by itself prove runtime native behavior, a passing Rust core does not prove Android packaging, and a passing upstream capability does not prove product integration.
