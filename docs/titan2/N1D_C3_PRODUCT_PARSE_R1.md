# Titan 2 N1D C3 product-parse qualification R1

Status: product-config parse gate; no target compilation; no device contact; no flash.

Date: 2026-10-01

## Purpose

This gate proves that the staged Sable-owned N1D C3 product is discoverable and
resolves through the Android 16 QPR2 product configuration before any target
compilation is authorized.

The exact lunch target is:

```text
sable_titan2_n1d_arm64-bp4a-userdebug
```

Android's `lunch` command selects product, release configuration and build
variant. The follow-up `soong_ui.bash --dumpvars-mode` invocation forces the
legacy Make product configuration to resolve and records the resulting identity.

## Authorization boundary

```text
SOURCE_MUTATION_AUTHORIZED=NO
PRODUCT_PARSE_AUTHORIZED=YES_EXPLICIT
ANDROID_TARGET_COMPILATION_AUTHORIZED=NO
NINJA_BUILD_AUTHORIZED=NO
TARGET_ARTIFACT_BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
```

The qualifier must not invoke `m`, `make`, Ninja, adb, fastboot, repository sync,
curl, wget or git fetch.

Upstream build-system bootstrap activity needed by `lunch` / dumpvars is allowed
only as part of product configuration parsing. It is not authorization to
compile Android target modules or produce an image.

## Preconditions

The qualifier first re-runs the C3 staged-bundle verifier. Therefore it requires:

```text
sealed 1,033-project Graphene/AOSP base still exact
zero dirty base projects
pinned C2 control binding still valid
five staged vendor/sable/n1d files byte-identical to repository-owned sources
sealed C3 stage evidence present
no out-c2
no future C3 compilation out directory
```

## Parse output isolation

Parse-only build-system state is written to a timestamped directory beneath:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3-parse/
```

The future C3 compilation output remains reserved as:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3
```

This prevents a parse experiment from being mistaken for, or contaminating, the
first C3 compilation output.

## Required resolved identity

The parse must resolve:

```text
TARGET_PRODUCT=sable_titan2_n1d_arm64
TARGET_RELEASE=bp4a
TARGET_BUILD_VARIANT=userdebug
PRODUCT_DEVICE=mainline_arm64
PRODUCT_BRAND=SableOS
PRODUCT_MODEL=SableOS Titan 2 N1D
PRODUCT_MANUFACTURER=SableOS
```

`BUILD_ID`, `PLATFORM_VERSION` and `PRODUCT_OUT` are captured as evidence but
are not independently promoted to source-lock inputs by this gate.

## No-artifact assertion

After dumpvars, the timestamped parse output must not contain target image,
target-files or OTA artifacts. A target artifact appearing during this gate is a
failure because target compilation is not authorized.

## Execution

```bash
bash build/titan2/qualify-n1d-c3-product-parse.sh \
  --authorize-product-parse
```

Successful completion emits:

```text
N1D_C3_ENVSETUP=PASS
N1D_C3_LUNCH=PASS
N1D_C3_DUMPVARS=PASS
N1D_C3_PRODUCT_PARSE_IDENTITY=PASS
N1D_C3_PRODUCT_PARSE_NO_TARGET_ARTIFACTS=PASS
N1D_C3_PRODUCT_PARSE=PASS
```

Deterministic parse state (`product-vars.env` and `parse-state.env`) is SHA-sealed under the path below. The streaming `parse.log` is retained for diagnostics but intentionally excluded from `SHA256SUMS.txt` so post-write log flushing cannot invalidate the evidence seal.

```text
/srv/sable-build/evidence/titan2/n1d-c3-product-parse/
```

## Next boundary

A passing product parse proves product discovery and product-configuration
resolution only. It does not prove that Soong can generate the complete C3
module graph and does not prove `system.img` compilation.

The next authorization decision is a separate first C3 compile qualification.
That later gate must bind to this parse evidence and explicitly authorize only
the intended build goals. Device contact and flash remain out of scope.
