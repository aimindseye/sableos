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
pre-existing failed out-c3 is allowed only with explicit retirement authorization
```

The parse evidence must prove:

```text
N1D_C3_PRODUCT_PARSE=PASS
N1D_C3_PRODUCT_NAME=sable_titan2_n1d_arm64
N1D_C3_PRODUCT_DEVICE=gsi_arm64
N1D_C3_BUILDING_GSI=false
N1D_C3_SOONG_AOSP_SYSTEM_IMAGE_ENABLED=NO
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
N1D_C3_BUILD_SANDBOX_POLICY=ADVISORY_HOST_DEPENDENT
```

Normal development/test-key signing performed intrinsically by the Android
build system is not a production-signing authorization.

## Build sandbox policy

The product-parse and host diagnostics established that this Ubuntu 26.04 host
can report:

```text
Build sandboxing disabled due to nsjail error.
```

The host diagnostics attribute that condition to the host AppArmor /
unprivileged-user-namespace policy rather than to the Sable product graph.
Previous Panther and Titan 2 Android builds on this host have also completed
without requiring Sable to weaken the host AppArmor policy.

For N1D C3, nsjail availability is therefore **advisory host evidence**, not a
compile authorization gate. Sable does not disable AppArmor, change sysctls, or
grant broader namespace privileges. Android is allowed to use its normal
fallback when nsjail is unavailable.

The driver records one of:

```text
N1D_C3_BUILD_SANDBOX_LUNCH=PASS_NSJAIL
N1D_C3_BUILD_SANDBOX_LUNCH=WARN_UNAVAILABLE_HOST_POLICY

N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=PASS_NSJAIL
N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=WARN_UNAVAILABLE_HOST_POLICY
```

and persists the aggregate status as either:

```text
N1D_C3_BUILD_SANDBOX_STATUS=PASS_NSJAIL
N1D_C3_BUILD_SANDBOX_STATUS=WARN_UNAVAILABLE_HOST_POLICY
```

Neither status changes the hard qualification requirements: exact source state,
exact product identity, systemimage-only build scope, successful image output,
no network/device/flash actions, and post-build source-integrity proof.

## Output isolation

The first compile uses the reserved C3 output directory:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3
```

A fresh compile still requires this path to be absent. If a previous failed
compile created it, retry requires `--authorize-failed-out-retirement`. The
driver verifies that no Soong/Ninja process is using the path, then moves the
failed output (without deleting it) beneath:

```text
/srv/sable-build/workspaces/titan2-n1d/retired-out-c3/
```

and SHA-seals a retirement record beneath
`evidence/titan2/n1d-c3-failed-out-retirement/` before creating a fresh
`out-c3`.

The earlier parse-only output remains isolated beneath:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3-parse/
```

## Graphene GSI module-graph remediation

The first live compile reached Soong graph generation and showed that
build/make's `aosp_system_image` expected AOSP application modules intentionally
absent from the pinned Graphene source graph (WebView, Browser2, Camera2,
Messaging and QuickSearchBox).

Sable does not restore those removed apps and does not inherit the PHH product.
Product contract v4 instead:

```text
PRODUCT_DEVICE=gsi_arm64
BUILDING_GSI=false
N1D_C3_SOONG_AOSP_SYSTEM_IMAGE_ENABLED=NO
```

The sealed Graphene `gsi_arm64` BoardConfig supplies GSI board/copy-out
semantics. The non-empty Make value `BUILDING_GSI=false` preserves
`BoardConfigGsiCommon.mk`'s `ifdef BUILDING_GSI` behavior while the Soong
config conversion, which tests specifically for literal `true`, disables the
incompatible `aosp_system_image` module.

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
  --authorize-failed-out-retirement \
  --jobs 16
```

## Passing markers

```text
N1D_C3_COMPILE_ENVSETUP=PASS
N1D_C3_COMPILE_LUNCH=PASS
N1D_C3_BUILD_SANDBOX_LUNCH=PASS_NSJAIL|WARN_UNAVAILABLE_HOST_POLICY
N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=PASS_NSJAIL|WARN_UNAVAILABLE_HOST_POLICY
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
