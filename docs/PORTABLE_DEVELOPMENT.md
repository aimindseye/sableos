# Portable SableOS development

The SableOS repository defines both the source contract and the local host-tool
contract. A new build machine should reproduce the canonical directory layout
rather than inventing tool locations per build.

## Canonical roots

```text
Sable source/build data: /srv/data/sable-build
Pinned host tools:       /srv/data/sable-host-tools
```

The R8 build profile is defined by:

```text
build/config/r8-host-tools.env
build/config/r8-release.env
```

Current pinned application-build inputs are:

```text
Android platform:       36
Android build-tools:    36.0.0
Android NDK:            30.0.16248370
Rust:                   1.98.1
Rust Android target:    aarch64-linux-android
First-party app JDK:    17
Reader/Mail JDK:        21
Gradle user home:       /srv/data/sable-host-tools/gradle
```

Use `build/host/verify-r8-host-tools.sh` to prove these inputs. Do not substitute
another SDK, NDK, Rust toolchain or JDK merely because it is available on PATH.

## One-time ai-g732 migration

The historical R8 qualification tools were staged under
`/srv/data/sable-build/host-tools/r8-final-v1`. They are promoted once with:

```bash
HOST_TOOL_MIGRATION_AUTHORIZED=YES \
  bash build/host/migrate-r8-final-v1-host-tools.sh
```

The migration moves SDK, Cargo/Rustup and Gradle state to
`/srv/data/sable-host-tools`, leaves compatibility symlinks for historical
scripts/evidence, and runs the canonical host-tool gate. It performs no build,
network fetch or device contact.

## Build driver portability

Normal R8 builds do not use hand-written local scripts. The GitHub workflow
`R8 canonical local build driver` produces:

```text
sableos-panther-r8-build.sh
BUILD_DRIVER_METADATA.txt
SHA256SUMS.txt
```

The generated driver is bound to the exact GitHub source commit. It refuses to
run when the local repository is at a different commit.

The artifact defaults to a persistent tmux session, so a failed build leaves its
first error available for inspection rather than destroying the session.

GitHub Android CI compiles the complete production SableStart Kotlin tree through
`:sablestart-production-check:compileDebugKotlin`. The old Start/System preview
applications are retired. On the build host, the source-bound driver additionally
runs an authoritative `m SableStart` Soong preflight before the combined
Settings/SystemUI module build.

The workspace gate treats `vendor/sable` as an exact inventory rather than an
open staging area. Any file, directory, symlink, APK or Android.bp outside the
canonical R8 set fails qualification.

## Upstream source caches

Reader, TextReader and Thunderbird remain external pinned source inputs. Their
exact commits are repository-owned in:

```text
apps/r8/reader/upstream.env
apps/r8/textreader/upstream.env
apps/r8/mail/upstream.env
```

The canonical runner verifies the local source-cache HEADs against those pins
before building. It does not silently substitute another revision.

## Device deployment

Build authorization is not flash authorization. The CI-produced local build
driver performs no ADB, fastboot or device contact. Physical deployment remains a
separate state-bound operation after target-files and image qualification.
