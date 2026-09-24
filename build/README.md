# SableOS build entry points

## K1/K2 multi-device foundation

The active R10 tooling tranche generalizes the artifact registry and deployment
boundary without enabling unqualified devices. See
`docs/K1_K2_MULTI_DEVICE_FOUNDATION.md`.

Key rule: artifact identity is device/release/source based; physical serial is
used only for device contact. Panther remains the qualified target-files/A-B
adapter while Titan 2, Titan 2 Elite and Q27 stay fail-closed until their own
transport/restore contracts are proven.


## Canonical multi-device entry point

The operator-facing SableOS engineering entry point is now:

```text
build/sable.sh <device> <release> <function>
```

It owns the stable interface for local CI, release builds, artifact registration,
flash-plan validation, device deployment and acceptance. Device-specific behavior
is selected through `build/devices/<device>.sh`; release-specific behavior is an
input, not a new top-level script.

Examples:

```bash
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 build --tmux
bash build/sable.sh panther R9 flash --build-source <sha> --serial <serial> --preserve-data --authorize
bash build/sable.sh panther R9 accept --serial <serial> --suite launcher
```

`build/panther/run-release.sh` remains the qualified Panther release-build
implementation behind the common entry point. It is no longer the desired
cross-device operator contract.

See `docs/STANDARD_ENGINEERING_PIPELINE.md`.

SableOS local builds use repository-owned orchestration and a canonical host-tool
profile. Do not create milestone-specific /tmp build drivers or rediscover SDK,
NDK, Rust, Java or Gradle paths during a build.

## Canonical local release build contract

The user-facing release entry point is:

```text
build/panther/run-release.sh <release-version>
```

Example:

```bash
bash build/panther/run-release.sh R9
```

The release version is the release-specific input. Do not create a new build
script, a new /tmp driver, or a new command sequence for each release.

Current R8-named files remain implementation details of the present product
baseline while they are incrementally generalized:

```text
build/config/r8-host-tools.env
build/config/r8-release.env
build/host/verify-r8-host-tools.sh
build/host/migrate-r8-final-v1-host-tools.sh
build/panther/run-r8-release-candidate.sh
build/gates/r8-build-driver-contract.sh
```

`build/panther/render-r8-build-driver.sh` is retained only for compatibility
with historical PR #57 / CI-produced driver evidence. It is not the normal
operator entry point.

Host tools live outside the build farm under:

```text
/srv/data/sable-host-tools/
```

The R8 profile pins Android SDK 36, build-tools 36.0.0, NDK
30.0.16248370, Rust 1.98.1 with the aarch64-linux-android target, JDK 17
for first-party Android applications and Text Reader, JDK 21 for Reader/Mail,
and a central Gradle user home.

PR #57 originally used a CI-rendered source-bound driver. After the
repository moved to local direct CI/execution, the permanent
`run-release.sh` entry point owns source binding and tmux execution directly,
without generating a milestone-specific /tmp script.

The entry point verifies the repository source identity and passes the release
version into the repository-owned release-candidate runner.
The runner performs the host-tool gate, application builds, independent
Text Reader/Reader/Mail composition, exact eleven-APK freeze, workspace/product
preparation, exact `vendor/sable` inventory validation, the standalone
SableLauncher + Quickstep preflight, the combined module gate, and the final
Panther target-files build. Device contact and flashing remain separate
operations.

## R9 system-cohesion pre-image qualification

Before the next full Panther image, run the source-bound R9 module
qualification. This executes the integrated system-cohesion source contract,
rebuilds the eleven source-bound prebuilt application APKs, including separate
Sable Text Reader, Reader and Mail products, upgrades the recognized long-lived
Android workspace deltas, stages the source-bound bundle, and compiles
SableLauncher, Launcher3QuickStep, Settings, SystemUI and the daily-driver
module set.
It does **not** build target-files, contact a device, flash, clean or clobber.

```bash
bash build/sable.sh panther R9 qualify physical-ux
```

Required terminal marker:

```text
R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION
```

Only after those markers pass, start the one fresh R9 Panther build:

```bash
bash build/sable.sh panther R9 build --tmux
```

The Mac visual-review harness is retained as non-blocking design tooling. It
does not emulate the production Settings-hosted appearance provider and is not
an R9 release gate.

## Other stable Panther entry points

```text
build/config/panther-grapheneos-2026081300.env
build/panther/bootstrap.sh
build/panther/capture-sablestart.sh
build/panther/verify-sablestart-snapshot.sh
build/panther/sync-sablestart.sh
build/panther/build-target-files.sh
```

Authorization remains explicit inside the repository entry points. The canonical
R8 generated driver authorizes only bounded workspace source synchronization and
the build itself. It does not authorize clean, clobber, device contact or flash.

See `docs/BUILD_LAYOUT.md`, `docs/PORTABLE_DEVELOPMENT.md`, and
`docs/BUILD_PANTHER_GRAPHENE_2026081300.md`.


## R9 standalone HOME source qualification

The historical `start-preview`, `system-preview` and
`sablestart-production-check` Gradle paths are retired. Current host-side
presentation qualification mirrors only the canonical
`sable_start_presentation_srcs` filegroup, while the Android product builds
the real source module `SableLauncher`.

The local Panther build remains authoritative: before the combined module gate,
`build-r8-final-ui.sh` runs the Sable HOME + Quickstep Recents preflight with
`m SableLauncher Launcher3QuickStep` and records
`sable-home-quickstep-preflight.log`.

The R8 no-stale gate also requires the workspace `vendor/sable` tree to match
the exact canonical R8 inventory: one Android.bp, one product makefile, three
source/seal control files, and exactly eleven canonical APKs.


## SableLauncher signing/package-scan policy

The current `SableLauncher` module is source-built as a normal system
application and explicitly disables APK Signature Scheme v4 sidecar generation:

```bp
v4_signature: false,
```

The R8 physical validation on 2026-09-19 proved that packaging
`SableStart.apk.idsig` caused PackageManager to enter the v4 certificate path,
attempt fs-verity measurement of the `/system` APK, hit the current Panther
SELinux denial, and reject the package during boot.

That incident remains historical evidence. Current R9 enforcement is carried by
the active build-driver/no-stale/target-files contracts: the source module must
be `SableLauncher` with `v4_signature: false`, target-files must contain
exactly one `SableLauncher.apk`, and legacy `SableStart.apk` must be absent.

Do not replace this with an `unzip -l | grep -q` check under `pipefail`.
An early successful `grep -q` can SIGPIPE `unzip`, making the pipeline
non-zero and falsely certifying an archive that actually contains the forbidden
sidecar.

See `docs/R8_SABLESTART_V4_SIGNING_INCIDENT_20260919.md`.

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


## Legacy vendor/sable config retirement

The long-lived Panther workspace predates the canonical R8 product tree and may
still contain `vendor/sable/config/common.mk`. Historical PR #29 established
that this file existed in the workspace but did not select GrapheneOS Auditor.

The R8 product model now integrates through `vendor/sable/r8/r8-product.mk`.
Before staging that tree, the build runs
`retire-r8-legacy-vendor-config.sh`. It removes the historical
`vendor/sable/config/common.mk` only when a make/Soong reference scan finds
zero consumers. The exact file hash and content are emitted before removal.
If any reference remains, or the directory contains any other object, the build
fails closed and preserves the file.


## Legacy vendor/sable_devices Panther product retirement

The historical Panther workspace may also contain
`vendor/sable_devices/sable_panther`, an older Sable product-definition tree
that predates the canonical R8 integration through
`vendor/google_devices/panther/panther.mk` and
`vendor/sable/r8/r8-product.mk`.

Before retiring the legacy `vendor/sable/config/common.mk`, R8 now runs
`retire-r8-legacy-sable-device-product.sh`. The helper removes only the exact
`vendor/sable_devices/sable_panther` tree and only when no Make/Soong product
file outside that tree references it. If the legacy parent contains any other
unexpected device content, the build fails closed without deleting either tree.
After successful retirement, `vendor/sable_devices` must be absent.


## Presigned R8 APK preservation

The eleven staged Sable application APKs are already signed before they enter
the Panther product graph. Their `android_app_import` definitions therefore set both
`presigned: true` and `preprocessed: true`, with dex preopt disabled.

For targetSdkVersion 30 and newer, Soong requires presigned imports to be marked
preprocessed so the product build does not rewrite the APK and invalidate its
APK Signature Scheme v2+ signature.

The final product-composition gate validates this contract for all eleven
canonical APK imports before Soong module compilation begins.
