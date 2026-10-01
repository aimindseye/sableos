# SableOS build entry points

## Current status — 2026-09-25

The canonical multi-device operator interface is:

```text
build/sable.sh <device> <release> <function> [options]
```

Current Panther R9 is frozen after the Sable Hub V1 closure:

```text
R9_PANTHER_HUB_V1_CLOSURE=MERGED
R9_PANTHER_ACCEPTED_SOURCE=edf62e5bb08372a1395841d6cc5d78d3148a7695
R9_PANTHER_TARGET_FILES_SHA256=a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285
R9_PANTHER_STANDARD_PRESERVED_DATA_FLASH=PASS
R9_PANTHER_PHYSICAL_ACCEPTANCE=PASS_WITH_PRESERVED_PLAY_STATE
```

Later documentation and keyboard-first design commits do not become new Panther
image qualification sources.

## Canonical multi-device entry point

Examples:

```bash
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 qualify physical-ux
bash build/sable.sh panther R9 build --tmux
bash build/sable.sh panther R9 flash --build-source <sha> --serial <serial> --preserve-data --authorize
bash build/sable.sh panther R9 accept --serial <serial> --suite launcher
```

For Titan-family work, keep the same interface but preserve the fail-closed
adapter boundary until physical restore/partition/AVB/transport evidence exists:

```bash
bash build/sable.sh titan2 R10 ci full
bash build/sable.sh titan2 R10 build --tmux
bash build/sable.sh titan2 R10 flash --build-source <sha> --serial <serial> --preserve-data --authorize
```

Titan 2, Titan 2 Elite and Q27 commands must fail closed until their device
adapter contracts are proven.

## Device IDs

```text
panther
titan2
titan2-elite
q27
```

A physical serial is never build/image/artifact identity. It is required only
for device-contact operations. Flash/acceptance commands must bind exactly one
selected serial and must not fall back to the first globally attached device.

## Artifact and deployment architecture

Artifact identity is based on device + release + source + exact artifact hashes.
Supported artifact classes include:

```text
target-files
full-device-images
gsi-system-image
system-product-bundle
boot-recovery-bundle
```

Panther is the qualified `target-files` / A-B fastboot adapter. Titan 2, Titan 2
Elite and Q27 remain fail-closed for artifact registration, flash planning and
flashing until independently qualified.

Common deployment policy owns authorization, artifact verification, serial
binding, evidence sealing, preserved/destructive-data policy, baseline capture
where applicable, bounded failure recovery and callback dispatch. Device adapters
own artifact kind, partition/slot model, fastboot/fastbootd/vendor transport,
AVB/vbmeta prerequisites, writable images, restore strategy and target-specific
post-boot acceptance.

## Panther implementation detail

`build/panther/run-release.sh` remains the qualified Panther release-build
implementation behind the common entry point. It is not the desired cross-device
operator contract.

Legacy implementation syntax retained for the Panther build-driver contract:

```text
build/panther/run-release.sh <release-version>
```

Do not create a new build driver for Panther release work. Use the canonical
operator command instead:

```bash
bash build/sable.sh panther R9 build --tmux
```

Current R8-named files remain implementation details while the product baseline
is incrementally generalized:

```text
build/config/r8-host-tools.env
build/config/r8-release.env
build/host/verify-r8-host-tools.sh
build/host/migrate-r8-final-v1-host-tools.sh
build/panther/run-r8-release-candidate.sh
build/gates/r8-build-driver-contract.sh
```

Do not recommend `run-r8-release-candidate.sh` directly as the operator command.
Use `bash build/sable.sh panther R9 build --tmux`.

## Host tools and CI

SableOS local builds use repository-owned orchestration and one canonical,
device/release-independent host-tool profile:

```text
build/config/host-tools.env
```

All Sable-managed tools live under:

```text
/srv/data/sable-host-tools/
├── android/
│   ├── sdk/
│   └── aosp-host/{bin,lib,lib64}/
├── java/{jdk17,jdk21}/
├── repo/repo
├── rust/<tool-version>/
├── gradle/
└── security/
```

Tool-version directories are allowed; device, release, milestone and build names
are not. Do not create paths such as `android/r8`, `panther-r9`,
`titan2-n1c` or `n1d` beneath the canonical host-tool root.

`build/sable.sh` sources the global profile. Build and qualification scripts
must consume the exported `SABLE_*` paths directly. In particular, Android
partition/VINTF/AVB tooling uses `SABLE_LPDUMP`, `SABLE_LPUNPACK`,
`SABLE_LPMAKE`, `SABLE_SIMG2IMG`, `SABLE_AVBTOOL`,
`SABLE_CHECKVINTF`, `SABLE_SECILC` and `SABLE_UNPACK_BOOTIMG`.
Normal build/qualification flows must not search historical Android OUT
directories to discover replacement tools.

The AOSP-host bundle is installed from a qualified clean build into
`android/aosp-host`; the build that produced it is recorded as provenance, not
encoded into the installation path. Use:

```bash
bash build/host/verify-host-tools.sh core
bash build/host/verify-host-tools.sh aosp-host
```

The historical `build/config/r8-host-tools.env` remains only as a compatibility
profile for accepted Panther R8/R9 scripts and delegates to the global profile.
It is not a separate tool installation.

Do not create milestone-specific `/tmp` build drivers or rediscover SDK, NDK,
Rust, Java, Gradle, repo or AOSP host-tool paths during a build.

GitHub remains source/review/issues/documentation infrastructure. Release-critical
qualification is local-direct on the controlled build host.

For Titan 2 N1B, full local CI must be run with explicit device/release context:

```bash
SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

The STATIC stage runs `build/gates/sable-pipeline-contract.sh`. That contract is
now responsible for binding the Titan2/N1B static contract family through
`build/gates/n1b-titan2-local-ci-static-contracts.sh`, while preserving no image,
no device-contact, no flash and no public-release scope.

## Validation discipline

Before providing or accepting a build/script deliverable, validate at minimum:

```bash
git diff --check
python3 -m py_compile <changed-python-files>
bash -n <changed-shell-files>
bash build/gates/sable-pipeline-contract.sh
```

For Panther image work, require source-bound module qualification, a fresh
canonical release build, artifact registration and preserved-data deployment
acceptance before making image claims.

## Historical notes

Historical R8/R9 build-driver, v4 signature, stale product-code, vendor/sable
retirement and presigned APK details remain in Git history and milestone docs.
They are evidence for why the current canonical entry point is strict, but they
are not the current operator workflow.

## Titan2 N1B2 product composition

Titan2/N1B2 product composition is routed through the canonical engineering
entrypoint, not a device-specific standalone workflow:

    bash build/sable.sh titan2 N1B2 product-composition \
      --android-root <android source root> \
      --active-product-mk device/phh/treble/treble_arm64_bvN.mk

The command is offline and fail-closed. It does not build, contact a device, run
adb or fastboot, flash, erase userdata, authorize public release, or authorize
production signing.

For Phase 1, the allowed selected product module is `SableLauncher`.
`SableDesign` must exist as source/dependency support. Other Sable app modules
remain blocked from N1B2 product selection until their Android modules, product
wiring, and validation evidence exist.
