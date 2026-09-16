# R8 standalone application qualification workspace

This directory is the source/application qualification side of the R8 split pipeline. It is intentionally independent from the Panther/AOSP image build.

## Pipelines

| Lane | Purpose | GitHub workflow |
| --- | --- | --- |
| Rust correctness | format, Clippy, host tests | `R8 Rust correctness` |
| Rust security | RustSec + dependency inventory | `R8 Rust security` |
| Android build | design tests + Kotlin/Java/Compose APK compilation | `R8 Android compile and tests` |
| Android static | Android Lint independent of build success | `R8 Android static analysis` |
| Reader build | pinned Vaachak core/Sable flavor tests + APK compile | `R8 Reader compile and tests` |
| Reader policy | Sable Reader lint + offline-manifest policy | `R8 Reader static and policy` |
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
  :convert:assembleDebug \
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

Reader CI intentionally clones the exact Vaachak SHA from `reader/upstream.env` and applies `reader/apply_sable_flavor.py`. Use the workflow as the canonical recipe rather than maintaining a second copied reader tree.

## Integration boundary

The Android shells currently establish package identity, lifecycle, Compose/design consumption, Media3 playback ownership, and build/test seams. Portable Rust domains are host-qualified separately. Android-native FFI/JNI binding is an explicit follow-on gate and must be tested before any claim that Calculator/Convert/Games consume the Rust domain at runtime.

This distinction is intentional: a compiling shell does not prove a native binding, and a passing Rust core does not prove Android packaging.
