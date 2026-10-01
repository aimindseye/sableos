# Titan 2 N1D C3 first compile qualification R1

Status: first target compilation gate; `systemimage` only; no device contact; no flash.

Date: 2026-10-01

## Purpose

This gate is the first Android target compilation for the Sable-owned N1D C3
product after successful product discovery and parse qualification.

The exact target remains:

```text
sable_titan2_n1d_arm64-bp4a-userdebug
```

The only authorized build goal is:

```text
systemimage
```

Target-files packaging, OTA packaging, device contact, flashing and production
signing are intentionally deferred.

## Preconditions

The driver requires:

```text
sealed 1,033-project Graphene/AOSP base
zero dirty base projects
exact staged five-file vendor/sable/n1d bundle
successful sealed C3 product-parse evidence
no out-c2
no pre-existing out-c3
```

The parse evidence must prove:

```text
N1D_C3_PRODUCT_PARSE=PASS
N1D_C3_PRODUCT_NAME=sable_titan2_n1d_arm64
N1D_C3_RELEASE_CONFIG=bp4a
N1D_C3_BUILD_VARIANT=userdebug
ANDROID_TARGET_COMPILATION_AUTHORIZED=NO
NINJA_BUILD_AUTHORIZED=NO
TARGET_ARTIFACT_BUILD_AUTHORIZED=NO
```

That evidence is the handoff from parse-only qualification into the separately
authorized compile boundary.

## Authorization boundary

```text
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=YES_C3_SYSTEMIMAGE_ONLY
IMAGE_BUILD_AUTHORIZED=YES_C3_SYSTEMIMAGE_ONLY
TARGET_FILES_BUILD_AUTHORIZED=NO
OTA_BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
N1D_C3_BUILD_SANDBOX_REQUIRED=YES
```

Normal development/test-key signing performed intrinsically by the Android
build system is not a production-signing authorization.

## Build sandbox requirement

The product-parse qualification reported:

```text
Build sandboxing disabled due to nsjail error.
```

That warning is accepted as parse-stage diagnostic evidence only. The first
target compilation is stricter: before invoking `systemimage`, the driver runs
an Android `soong_ui --dumpvars-mode` sandbox probe and fails if Android emits
the nsjail-disabled warning. The `systemimage` command output is checked again
after the build and the qualification fails if sandboxing was disabled there.

Therefore a passing first C3 compile must emit:

```text
N1D_C3_BUILD_SANDBOX_PREFLIGHT=PASS_NSJAIL
N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=PASS_NSJAIL
```

This does not replace Android's sandbox implementation; it makes Android's own
sandbox-health signal a fail-closed Sable qualification requirement. No release-key or
production-key custody is introduced by this gate.

## Output isolation

The first compile uses the reserved C3 output directory:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3
```

The directory must not exist before the first compile. A failed first compile is
preserved for diagnosis; cleanup or retry authorization is a separate decision.

The earlier parse-only output remains isolated beneath:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3-parse/
```

## Build action

After sourcing Android envsetup and selecting the exact release-aware lunch
target, the driver resolves `PRODUCT_OUT` and invokes exactly:

```bash
m -j"$JOBS" systemimage
```

No `target-files-package`, `otatools`, `dist`, adb, fastboot, repository
sync, curl, wget or git fetch action is admitted.

## Success requirements

A successful compile must produce:

```text
$PRODUCT_OUT/system.img
```

and record:

```text
system.img SHA-256
system.img byte size
system.img file type
resolved PRODUCT_OUT
exact parse evidence directory
exact out-c3 directory
```

The output tree must not contain target-files or OTA zip artifacts.

## Post-build source integrity

After system-image compilation, the driver rechecks the Android source checkout
without treating the expected `out-c3` directory as a source mutation.

Required post-build state:

```text
project count = 1033
dirty project count = 0
all project HEADs exactly equal the sealed base ledger
Graphene manifest HEAD remains pinned
no local manifests
retired partial C2 source paths remain absent
all five staged C3 files remain byte-identical to repository sources
```

This separates legitimate build output from prohibited source drift.

## Evidence

Deterministic compile state, project-head ledgers and source-integrity evidence
are SHA-sealed beneath:

```text
/srv/sable-build/evidence/titan2/n1d-c3-first-compile/
```

The streaming `build.log` is retained for diagnostics but intentionally
excluded from `SHA256SUMS.txt` so final log flushing cannot invalidate the
deterministic evidence seal.

## Execution

```bash
bash build/titan2/build-n1d-c3-first-systemimage.sh \
  --authorize-c3-compile
```

Optional parallelism may be selected explicitly:

```bash
bash build/titan2/build-n1d-c3-first-systemimage.sh \
  --authorize-c3-compile \
  --jobs 16
```

## Passing markers

```text
N1D_C3_COMPILE_ENVSETUP=PASS
N1D_C3_COMPILE_LUNCH=PASS
N1D_C3_BUILD_SANDBOX_PREFLIGHT=PASS_NSJAIL
N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=PASS_NSJAIL
N1D_C3_SYSTEMIMAGE_BUILD=PASS
N1D_C3_POST_BUILD_PROJECT_COUNT=PASS value=1033
N1D_C3_POST_BUILD_DIRTY_PROJECT_COUNT=PASS_ZERO
N1D_C3_POST_BUILD_BASE_HEADS=PASS_EXACT
N1D_C3_POST_BUILD_STAGED_BUNDLE=PASS
N1D_C3_FIRST_COMPILE_NO_TARGET_FILES_OTA=PASS
N1D_C3_FIRST_COMPILE_SOURCE_INTEGRITY=PASS
N1D_C3_FIRST_COMPILE=PASS
```

## Next boundary

A passing first compile proves that the C3 product can generate a `system.img`
from the pinned Android 16 / BP4A source graph. It does not authorize device
deployment.

Packaging and deeper image qualification should be a separate gate. Only after
artifact structure, VINTF, SELinux, identity and compatibility evidence are
reviewed should any physical-device operation be considered.
