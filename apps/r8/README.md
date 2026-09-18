# R8 standalone application qualification workspace

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
  :games:assembleDebug \
  :media:assembleDebug

gradle -p apps/r8/android \
  :design:lintDebug \
  :calculator:lintDebug \
  :convert:lintDebug \
  :games:lintDebug \
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

Sable Convert is no longer intended to be a separate launcher-visible APK. The `:convert` Android module is an internal Calculator feature library, and Sable Calculator owns the Regular, Scientific, and Converter surfaces. The qualification APK set is therefore Calculator, Games, and Media, with Reader qualified through its separate pinned upstream lanes.

UI2 is migrating Calculator, Converter, Games and Media onto the shared Sable design contract. The Games module now hosts reusable touch-first Sudoku, Minesweeper and 2048 screens; those screens are transitional shared implementation and do not change the product requirement for three separate launcher APKs. The separate game APK shells are the UI2G follow-on before final product integration. Reader/Text Reader composition follows UI2/UI2G, then the existing standalone qualification and exact artifact-freeze gates apply.

Reader capability qualification remains distinct from Reader composition: Vaachak Mobile and Vaachak Text Reader may both pass independently without proving that one Sable Reader APK contains both paths or that its final manifest satisfies Sable privacy policy.

INFRA5 encrypted trusted-runner activation is intentionally deferred and does not block this R8 work. Current qualification remains on GitHub-hosted CI; see `docs/INFRA5_DEFERRED_TRUSTED_RUNNER.md`.

This distinction is intentional: a compiling shell does not by itself prove runtime native behavior, a passing Rust core does not prove Android packaging, and a passing upstream capability does not prove product integration.
