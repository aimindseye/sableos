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

## Canonical build storage

The dedicated SableOS build filesystem is canonically addressed as:

```text
/srv/sable-build
```

Historical scripts may temporarily continue to use:

```text
/srv/data/sable-build
```

During migration, the two paths must resolve to the same filesystem. New build
logic must source `build/config/storage.env` and use `SABLE_BUILD_ROOT` or
one of its derived variables. Do not add new hard-coded
`/srv/data/sable-build` paths.

The canonical profile defines:

```text
SABLE_BUILD_ROOT=/srv/sable-build
SABLE_BUILD_LEGACY_ROOT=/srv/data/sable-build
SABLE_WORKSPACES_ROOT=/srv/sable-build/workspaces
SABLE_EVIDENCE_ROOT=/srv/sable-build/evidence
SABLE_ARTIFACTS_ROOT=/srv/sable-build/artifacts
SABLE_RELEASE_REGISTRY_ROOT=/srv/sable-build/release-registry
SABLE_BUILD_FS_LABEL_EXPECTED=sable-build
SABLE_BUILD_FS_TYPE_EXPECTED=ext4
SABLE_BUILD_MIN_FREE_GIB=250
```

Runtime verification:

```bash
bash build/host/verify-storage-root.sh runtime
```

Migration is staged. The live transition creates a bind mount at the canonical
path without unmounting the existing filesystem or disturbing nested evidence
mounts. `build/host/migrate-storage-root.sh fstab-plan` only prints the
persistent target state; it never edits `/etc/fstab`.

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

## Titan 2 N1D source identity

N1D is locked to Android 16 before any fresh source sync:

```text
build/titan2/n1d-source-lock.env
```

The source lock pins GrapheneOS `2026061600` / AOSP
`android-16.0.0_r4` / release config `bp4a` and RestlessOS
`16.0.0-202606230923`. Do not use the Restless default branch, its
latest-Graphene resolver, or any Android 17 source for N1D.

Restless source is a pinned Treble compatibility reference and C2/C3A
diagnostic control. C3A is sealed historical evidence.

C3B E1 starts from a separate clean pinned GrapheneOS Android 16 checkout and
adds only the five pinned Treble build-scaffold projects required by the current
generated-product path. The pinned `device/phh/treble/base.mk` is used as a
build-compatibility substrate, but it is transformed by the exact repository
applicator `build/titan2/apply-n1d-c3b-phh-base-hardening.py` before product
generation. The applicator removes the highest-risk PHH security/control
defaults instead of treating the PHH base as Sable runtime policy.

Compatibility Peel R2 pre-audits the pinned C3A compatibility corpus before the
next E1 compile. The complete 369-patch Restless control inventory is
deny-by-default and has zero verbatim C3B admissions. The focused R2 ledger
admits only Sable-owned narrow build-graph/security reimplementations while the
runtime patch allowlist remains empty.

C3B E1 keeps the generated `treble_arm64_bvN` identity only as an engineering
build identity. E2 now preserves that generated product as its proven base graph
and defines a thin Sable wrapper product, `sable_titan2-bp4a-userdebug`.
The qualified parallel source is canonically imported at
`aafb543565c9d59ed5e0d9cda876aabb4967f8aa`; five non-privileged product apps
are built offline from that source into unsigned APKs and imported into Android
with `default_dev_cert` for the userdebug engineering image. Presigned APKs,
platform-certificate signing, target-files/OTA, device contact, flash and release
remain unauthorized.

The source and security boundaries are enforced by:

```bash
bash build/gates/n1d-restless-security-boundary-contract.sh
bash build/gates/n1d-source-lock-contract.sh
```

Source sync, Android build and device deployment remain separate gated phases.
These contracts authorize none of them.

Fresh N1D source preparation is defined by:

```text
build/titan2/n1d-fresh-source.env
build/titan2/prepare-n1d-fresh-source.sh
docs/titan2/N1D_FRESH_SOURCE_WORKFLOW_R1.md
```

The workflow uses one fresh checkout at
`/srv/sable-build/workspaces/titan2-n1d/android`. Offline preflight and C2
public-pin derivation do not authorize network access. Graphene base
initialization and sync require the explicit `--authorize-network` flag. The
driver never runs an Android build, adb, fastboot, or the Restless upstream sync
script.

The fresh-source contract is enforced by:

```bash
bash build/gates/n1d-fresh-source-contract.sh
```

After the Graphene/AOSP base is sealed, the historical exact-source C2
admission path remains preserved for audit evidence but is now fail-closed.
Two locked source objects could not be reconstructed from current public
remotes, so source-admission retries are prohibited.

The active C2 diagnostic control is the original published RestlessOS
`16.0.0-202606230923` ARM64 A/B GSI, pinned by release tag, commit, size and
SHA-256. See:

```text
build/titan2/n1d-c2-prebuilt-control.env
docs/titan2/N1D_C2_PREBUILT_CONTROL_R1.md
```

```bash
bash build/titan2/fetch-n1d-c2-control.sh preflight

bash build/titan2/fetch-n1d-c2-control.sh \
  download \
  --authorize-network

bash build/titan2/retire-n1d-c2-source.sh preflight
bash build/titan2/retire-n1d-c2-source.sh retire
```

The historical locked revisions remain evidence and are not replaced with
current branch tips. The published release asset is now the C2 control
identity. Before C3, the partial 11-project C2 source state is retired offline
and the checkout must return exactly to the sealed 1,033-project base.

C2 remains diagnostic/control-only. The control download and source retirement
authorize no Android build, device contact, flash, or C3 inheritance of
PHH/Restless product policy.

The admission contract is enforced by:

```bash
bash build/gates/n1d-c2-source-admission-contract.sh
```

The earlier handcrafted `build/titan2/n1d-c3-product/` /
`vendor/sable/n1d/` product path is retired and must not be revived as the
active C3B product implementation.

Current C3B composition authority is:

```text
build/titan2/n1d-c3b-transition.env
build/titan2/n1d-c3a-control-patch-inventory-r2.tsv
build/titan2/n1d-c3b-compatibility-peel-r2.tsv
build/titan2/n1d-c3b-scaffold-add.xml
build/titan2/n1d-c3b-scaffold-decisions.tsv
build/titan2/apply-n1d-c3b-phh-base-hardening.py
build/titan2/n1d-c3b-engineering.mk
```

The E1 composition gate remains:

```bash
bash build/gates/n1d-c3-product-composition-contract.sh
```

E2 source admission and product composition are enforced separately:

```bash
bash build/gates/n1d-c3b-e2-product-admission-contract.sh
bash build/gates/n1d-c3b-e2-product-composition-contract.sh
```

The E2 product template and execution drivers are:

```text
product/titan2/c3b/
build/titan2/build-n1d-c3b-e2-product-apps.sh
build/titan2/stage-n1d-c3b-e2-product-composition.sh
build/titan2/qualify-n1d-c3b-e2-product-parse.sh
build/titan2/build-n1d-c3b-e2-modules.sh
```

E1 authorizes only the separate C3B source graph, product parse and engineering
`systemimage` compilation. E2 is now the canonical Sable identity/module
composition lane, but remains non-release until its parse, module build, image
build and physical runtime evidence close.

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


## Titan 2 N1D local-CI scope

For `bash build/sable.sh titan2 N1D ci full`, Panther-R9-only launcher and
physical-acceptance contracts are not N1D requirements. Shared application,
Rust, security, supply-chain and N1D product contracts remain active.

The boundary is guarded by:

```text
build/gates/n1d-local-ci-scope-contract.sh
```


## Titan 2 N1D C3B E1 engineering transition

E1 uses a separate workspace at
`/srv/sable-build/workspaces/titan2-n1d-c3b` and does not roll back or reuse
the sealed C3A Android tree.

The E1 graph is the pinned GrapheneOS 1,033-project base plus five pinned Treble
build/parse-scaffold projects, for 1,038 managed projects. It inherits zero C3A
Graphene removals and zero Restless runtime patches. The exact pinned PHH
`base.mk` is hardened before generation with 14 fail-closed security/control
transformations.

R2 also binds a complete 369-patch C3A control-corpus inventory and an 11-row
focused semantic compatibility ledger. The next build applies the complete
admitted E1 set before Soong: two non-Titan LGE graph quarantines, two Soong
host-layout fixes, and two Sable-owned build/make compatibility patches.

Entry points:

```text
build/gates/n1d-c3b-transition-contract.sh
build/gates/n1d-c3b-engineering-contract.sh
build/titan2/prepare-n1d-c3b-engineering.sh
build/titan2/qualify-n1d-c3b-product-parse.sh
build/titan2/build-n1d-c3b-systemimage.sh
```

The first target is the generated
`treble_arm64_bvN-bp4a-userdebug` engineering `systemimage`.
Final Sable product admission is E2. Device contact, flash, signing and release
remain blocked.
