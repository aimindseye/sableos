# Titan 2 N1D C3B E1 engineering transition

Status: **E1 source/build transition proposed; no device contact or flash**

Date: 2026-10-02

## Purpose

E1 consumes the sealed C3A control evidence and activates a separate C3B
engineering lane.

C3A proved that the pinned public Restless/TrebleDroid topology can produce an
Android 16 system image. C3B does not inherit that topology wholesale.

E1 deliberately separates three concerns:

```text
C3A control
    sealed comparison evidence
    no longer the active engineering lane

C3B E1 engineering baseline
    pinned GrapheneOS Android 16 base
    minimal pinned Treble build/parse scaffold
    zero Restless runtime patches
    broad PHH runtime/control behavior reduced
    generated Treble engineering product
    build/parse only

C3B E2 product admission
    Sable product identity
    Sable source modules
    Launcher3-hosted Sable Start
    product/partition ownership
    canonical product integration
```

E1 is not a release transition and is not a flash authorization.

## C3A prerequisite

E1 is bound to the sealed C3A evidence:

```text
N1D_C3A_CONTROL_EVIDENCE=PASS
N1D_C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE
```

The C3A image remains evidence only.

## Separate C3B workspace

C3B does not try to undo the C3A-mutated source tree.

Canonical E1 workspace:

```text
/srv/sable-build/workspaces/titan2-n1d-c3b/
    android/
    out-c3b-engineering/
```

This keeps the C3A 991-project control graph, its archived Graphene projects,
369 control patches, TrebleApp residue and Soong fixes isolated from C3B.

## C3B source graph

E1 starts from a new exact GrapheneOS Android 16 checkout:

```text
GrapheneOS tag:             2026061600
manifest commit:            5d82aa9610855bc0b43b9eb7ca4470d30455cfeb
base project count:         1033
Graphene project removals:  0
```

It then adds five pinned build/parse-scaffold projects:

```text
device/phh/treble
prebuilts/vndk/v28
prebuilts/vndk/v29
vendor/interfaces
vendor/lptools
```

The VNDK 28/29 prebuilts and `lptools` are retained because the exact pinned
PHH `base.mk` directly requests them. The pinned interface definitions are
kept for the generic compatibility modules still named by that base. The
external `vendor/hardware_overlay` inheritance is removed before product
generation, so that repository is not part of the E1 graph.

Expected managed project count:

```text
1033 + 5 = 1038
```

C3B does not inherit the C3A 54-project Restless removal set.

## C3A additions not inherited by default

The following C3A projects are intentionally absent from the E1 scaffold:

```text
packages/apps/QcRilAm
prebuilts/vndk/v30
treble_app
vendor/apn
vendor/hardware_overlay
vendor/magisk
vendor/vndk-tests
```

Reasons are recorded in:

```text
build/titan2/n1d-c3b-scaffold-decisions.tsv
```

Absence at E1 is not a permanent claim that every item is unnecessary.
A non-forbidden component may be reconsidered if product parse/build/runtime
failure provides evidence.

`vendor/magisk` is outside the C3B security boundary.

## Restless patch boundary

E1 applies none of the 369 C3A Restless control patches.

```text
N1D_C3B_C3A_CONTROL_PATCH_STACK_INHERITED=NO
N1D_C3B_RESTLESS_PATCH_COUNT=0
N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
```

Any later runtime patch requires the normal C3B sequence:

```text
reproduce failure
  -> identify smallest relevant compatibility change
  -> security/runtime review
  -> explicit allowlist admission
  -> rebuild
  -> evidence
```

## PHH runtime reduction

The pinned `device/phh/treble/base.mk` is used as a build-compatibility
substrate, not accepted wholesale as Sable runtime policy.

Android product inheritance is resolved after `inherit-product` tagging, so a
later product fragment is not a reliable way to subtract packages already
introduced by the PHH base. E1 therefore applies an exact, fail-closed
Sable-owned transformation to the pinned `base.mk` **before** generation:

```text
build/titan2/apply-n1d-c3b-phh-base-hardening.py
```

The applicator is bound to:

```text
device/phh/treble commit:
39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed

base.mk git blob:
a29e402009d449150f1216e5d517ec0c9b36bfbd

security transforms:
14
```

It removes the highest-risk broad control/runtime behavior from the first C3B
engineering product, including:

- PHH private sepolicy and the external broad hardware-overlay inheritance;
- `ro.adb.secure=0` and adb-by-default USB;
- rw-system / boot / data / property-handler mutation hooks;
- TWRP/busybox payloads;
- `SELINUX_IGNORE_NEVERALLOWS := true`;
- PHH MTK SMS helper;
- resetprop, securize, PHH OTA and remove-telephony hooks;
- PHH custom adbd service;
- TrebleApp privileged permission/sysconfig payloads;
- PHH remote debugging;
- PHH OTA service;
- QcRilAm;
- unrelated Samsung boot and PHH MTK in-call helpers.

E1 deliberately retains the pinned base's VNDK 28/29 requirement, `lptools`,
`Iwlan`, `QualifiedNetworksService` and other compatibility code not yet
shown to violate the C3B security boundary. Their presence is not a permanent
release admission: E1 is the first compile baseline, and later build/runtime
evidence decides what else is removed, retained or replaced.

The generator config:

```text
build/titan2/n1d-c3b-engineering.mk
```

is intentionally composition-neutral in E1. It exists to bind the generated
configuration name; Sable application/product admission belongs to E2.

If this hardening makes the image fail to parse or compile, that failure is
useful C3B evidence. E1 does not pre-emptively restore the removed behavior.

## Host-layout patches

Two C3A-discovered Soong patches are admitted into E1 separately from runtime
patch policy:

```text
0001-soong-ci-tests-skip-out-of-tree-host-paths.patch
0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch
```

They are allowed because they address the canonical out-of-tree `OUT_DIR`
build environment and do not change Android runtime behavior.

Their patch blobs and expected Graphene base/post blobs remain exact-pinned.

```text
N1D_C3B_HOST_LAYOUT_PATCH_ROLE=BUILD_ENVIRONMENT_COMPATIBILITY_ONLY
N1D_C3B_HOST_LAYOUT_PATCH_COUNT=2
```

Application requires explicit build-driver authorization.

## First C3B engineering identity

E1 intentionally keeps the generated Treble identity while the Sable product
admission model is defined in E2.

```text
generator:       device/phh/treble/generate.sh
config:          sable-c3b-engineering
product:         treble_arm64_bvN
device:          tdgsi_arm64_ab
release config:  bp4a
variant:         userdebug
goal:            systemimage
```

This is an **engineering build identity**, not final Sable product identity.

The earlier handcrafted `sable_titan2_n1d_arm64` implementation remains
retired. E2 will define how accepted Sable source modules and product identity
enter the generated C3B product without returning to the failed handcrafted
GSI graph.

## Authorization boundary

E1 authorizes only:

```text
new C3B workspace creation
pinned Graphene repo init/sync with explicit network authorization
five-project scaffold sync with explicit network authorization
bounded source generation in device/phh/treble
product parse with explicit authorization
systemimage compile with explicit authorization
two exact host-layout source mutations with explicit authorization
```

E1 does not authorize:

```text
target-files
OTA
dist
release packaging
device contact
adb
fastboot
flash
development/release signing
production signing
physical runtime qualification
release
```

A successful E1 system image is therefore still:

```text
N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO
N1D_C3B_RELEASE_ELIGIBLE=NO
```

## Driver sequence

Repository/static qualification:

```bash
bash build/gates/n1d-c3b-transition-contract.sh
bash build/gates/n1d-c3b-engineering-contract.sh
bash build/gates/sable-pipeline-contract.sh
```

Offline preflight:

```bash
bash build/titan2/prepare-n1d-c3b-engineering.sh preflight
```

Initialize the separate Graphene workspace:

```bash
bash build/titan2/prepare-n1d-c3b-engineering.sh \
  init-base \
  --authorize-network \
  --authorize-source-mutation
```

Synchronize and seal the 1033-project base:

```bash
bash build/titan2/prepare-n1d-c3b-engineering.sh \
  sync-base \
  --authorize-network \
  --authorize-source-mutation
```

Stage the five-project C3B scaffold, harden the pinned PHH base, and generate the engineering product:

```bash
bash build/titan2/prepare-n1d-c3b-engineering.sh \
  stage \
  --authorize-network \
  --authorize-source-mutation
```

Offline verification:

```bash
bash build/titan2/prepare-n1d-c3b-engineering.sh verify
```

Product parse:

```bash
bash build/titan2/qualify-n1d-c3b-product-parse.sh \
  --authorize-product-parse
```

First C3B engineering compile:

```bash
bash build/titan2/build-n1d-c3b-systemimage.sh \
  --authorize-c3b-compile \
  --authorize-host-layout-source-mutation \
  --jobs 16
```

No network authorization is accepted by the build driver.

## E1 exit criteria

E1 source transition is complete when:

```text
N1D_C3B_TRANSITION_CONTRACT=PASS
N1D_C3B_ENGINEERING_CONTRACT=PASS
N1D_C3B_SCAFFOLD_STAGE=PASS
N1D_C3B_PREP_VERIFY=PASS
N1D_C3B_PRODUCT_PARSE=PASS
```

The first compile then has two valid outcomes.

If it fails:

```text
preserve exact failure
classify missing build/runtime compatibility
do not import the C3A stack wholesale
admit only the smallest evidence-supported change
```

If it succeeds:

```text
N1D_C3B_SYSTEMIMAGE=PASS
N1D_C3B_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT
N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO
N1D_C3B_RELEASE_ELIGIBLE=NO
```

E2 product admission and later runtime/security gates remain separate.
