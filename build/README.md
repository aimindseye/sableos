# SableOS build entry points

SableOS local builds use repository-owned orchestration and a canonical host-tool
profile. Do not create milestone-specific /tmp build drivers or rediscover SDK,
NDK, Rust, Java or Gradle paths during a build.

## Canonical R8 local build contract

The permanent R8 entry points are:

```text
build/config/r8-host-tools.env
build/config/r8-release.env
build/host/verify-r8-host-tools.sh
build/host/migrate-r8-final-v1-host-tools.sh
build/panther/run-r8-release-candidate.sh
build/panther/render-r8-build-driver.sh
build/gates/r8-build-driver-contract.sh
.github/workflows/r8-build-driver.yml
```

Host tools live outside the build farm under:

```text
/srv/data/sable-host-tools/
```

The R8 profile pins Android SDK 36, build-tools 36.0.0, NDK
30.0.16248370, Rust 1.98.1 with the aarch64-linux-android target, JDK 17
for first-party Android applications, JDK 21 for Reader/Mail, and a central
Gradle user home.

The GitHub workflow `R8 canonical local build driver` renders a
source-commit-bound `sableos-panther-r8-build.sh`, syntax-checks and contract
checks it, writes SHA-256 metadata, and uploads it as a workflow artifact.
That CI-produced artifact is the normal executable for `ai-g732`.

The generated script verifies that the local repository is at the exact GitHub
commit embedded by CI, then runs the repository-owned release-candidate runner.
The runner performs the host-tool gate, application builds, Reader/Mail
composition, exact eight-APK freeze, workspace/product preparation, exact
`vendor/sable` inventory validation, a focused production `SableStart` Soong
preflight, the combined Settings/SystemUI module gate, and the final Panther
target-files build. Device contact and flashing remain separate operations.

## Other stable Panther entry points

```text
build/config/panther-grapheneos-2026081300.env
build/panther/bootstrap.sh
build/panther/capture-sablestart.sh
build/panther/verify-sablestart-snapshot.sh
build/panther/sync-sablestart.sh
build/panther/build-sablestart.sh
build/panther/build-target-files.sh
```

Authorization remains explicit inside the repository entry points. The canonical
R8 generated driver authorizes only bounded workspace source synchronization and
the build itself. It does not authorize clean, clobber, device contact or flash.

See `docs/BUILD_LAYOUT.md`, `docs/PORTABLE_DEVELOPMENT.md`, and
`docs/BUILD_PANTHER_GRAPHENE_2026081300.md`.


## R8 production-source qualification

The historical `start-preview` and `system-preview` Gradle applications and
the Panther UI-preview build/flash/validation scripts are retired. GitHub Android
CI now compiles the complete production SableStart Kotlin source tree through
`:sablestart-production-check:compileDebugKotlin`, using the production
manifest and resources.

The local Panther build remains authoritative: after lunch and before the
combined module gate, `build-r8-final-ui.sh` runs a focused
`m SableStart` Soong preflight and stores
`sablestart-soong-preflight.log`.

The R8 no-stale gate also requires the workspace `vendor/sable` tree to match
the exact canonical R8 inventory: one Android.bp, one product makefile, three
source/seal control files, and exactly eight canonical APKs.


## Retired Gradle module residue

Git does not remove untracked files when switching between source commits.
Historical `start-preview` and `system-preview` modules can therefore leave
untracked Gradle build directories on a long-lived build host even after their
tracked source has been deleted.

The canonical R8 release driver runs
`build/panther/retire-r8-obsolete-gradle-residue.sh` immediately after source
identity and tracked-clean verification. The script is fail-closed:

- only `apps/r8/android/start-preview` and `apps/r8/android/system-preview`
  are eligible for automatic retirement;
- Git must report zero tracked files beneath each path;
- symlinks and non-directory objects are refused;
- the exact residue inventory is emitted before bounded removal;
- all other stale source/scripts remain the responsibility of the strict
  no-stale gate and are never auto-deleted.

This is bounded source-checkout hygiene, not a general clean or clobber.
