# Titan 2 N1D Android 16 source lock

Status: **source identity locked / source sync not yet authorized**

Date: 2026-10-01

## Decision

N1D remains an Android 16 portability build. It must not consume the current
RestlessOS default branch or dynamically resolve the current GrapheneOS stable
release.

The reproducible source anchors are:

```text
ANDROID_MAJOR=16
PLATFORM_SDK=36
AOSP_REVISION=android-16.0.0_r4
RELEASE_CONFIG=bp4a

GRAPHENEOS_TAG=2026061600
GRAPHENEOS_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb
GRAPHENEOS_REVISION_BRANCH=16-qpr2

RESTLESSOS_TAG=16.0.0-202606230923
RESTLESSOS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233
```

The RestlessOS release above is explicitly based on GrapheneOS
`2026061600`. GrapheneOS `2026061600` is the final normal Android 16
release and its manifest declares `android-16.0.0_r4`. Its build release
configuration maps `aosp_current` to `bp4a`.

A later signed GrapheneOS tag `2026061602` also remains Android 16 /
`android-16.0.0_r4` and explains the historical R6 evidence which recorded
that tag. N1D does not use it because the final published RestlessOS Android 16
release is explicitly paired with `2026061600`; keeping the pair together
removes an unnecessary source mismatch.

GrapheneOS `2026061800` is the first Android 17 release. Current GrapheneOS
stable releases and the current RestlessOS default branch are Android 17 and are
therefore outside N1D's source contract.

## Why the upstream Restless sync script is forbidden

The Android-16 RestlessOS tag/branch contains a sync path which scrapes the
GrapheneOS releases page and chooses the numerically newest stable tag before
running `repo init`.

That behavior is not release-reproducible. Running it after GrapheneOS moved to
Android 17 can initialize an Android-17 source tree even when the Restless
checkout itself is an Android-16 branch/tag.

N1D therefore requires a repository-owned sync driver which passes the exact
GrapheneOS manifest tag from `build/titan2/n1d-source-lock.env`.

```text
N1D_RESTLESS_DYNAMIC_GRAPHENE_TAG_ALLOWED=NO
N1D_RESTLESS_UPSTREAM_SYNC_SCRIPT_ALLOWED=NO
N1D_ANDROID17_SOURCE_ALLOWED=NO
```

## RestlessOS role

RestlessOS is not treated as an opaque SableOS base image. For N1D it is a
pinned Android-16 Treble compatibility reference/source.

The product graph remains:

```text
treble_arm64_bvN
  -> device/phh/treble/base.mk
  -> AOSP gsi_release.mk
  -> Restless/Treble rom.mk product delta
  -> Sable N1D product delta
```

This preserves the Treble hierarchy which was useful in the historical Titan
work while separating it from upstream source-sync behavior and from unreviewed
patch tiers.

## Public-only source requirement

The Restless Android-16 local manifest contains a private
`vendor/cawilliamson-priv` project used by upstream signing/release tooling.
SableOS N1D must not depend on that project.

The future N1D source-sync driver must generate/use a reviewed public-only local
manifest and fail if a private remote/project is present.

```text
N1D_RESTLESS_PUBLIC_ONLY_REQUIRED=YES
N1D_RESTLESS_PRIVATE_VENDOR_ALLOWED=NO
```

## Patch policy

The Restless Android-16 release workflow applies these upstream tiers:

```text
trebledroid
trebledroid-staging
rom
personal
release-builds
```

N1D must not automatically reproduce that loop for the Sable baseline.

C3A is the explicit exception: it reproduces the exact pinned Restless patch
loop as a non-release control so C3B can stop guessing about compatibility.
C3B continues to prohibit wholesale tier inheritance.

For C3B, compatibility changes are imported only through a Sable-owned reviewed
allowlist. C3A control patches do not become C3B policy automatically. Patch pairs which form one compatibility contract must be applied
atomically. For example, v28 SELinux compatibility requires both the build-side
`PLATFORM_SEPOLICY_COMPAT_VERSIONS` change and the matching restored 28.0 CIL
policy.

The upstream `rom` tier also contains a patch allowing TrebleDroid permissive
domains (`phhsu_daemon`, `tkcore`, `ueventd`) in user builds. This is not
implicitly acceptable to SableOS and is blocked by the N1D source policy.

```text
N1D_PATCH_APPLICATION_MODE=REPO_OWNED_REVIEWED_ALLOWLIST
N1D_PATCH_TIER_AUTOAPPLY_ALLOWED=NO_FOR_C3B
N1D_C3A_PINNED_CONTROL_PATCH_TIERS_ALLOWED=YES_CONTROL_ONLY
N1D_SELINUX_PERMISSIVE_DOMAINS_ALLOWED=NO
```

## Relationship to historical SableOS work

Historical evidence established three separate facts which N1D keeps distinct:

1. clean AOSP Android 16 / BP4A could produce a generic system image;
2. Android-16 Restless/Treble product hierarchy could build a Titan-relevant
   GSI, but historical builds required local deviations and are not reused as
   source;
3. the failed N1C hybrid-super experiment does not authorize carrying its
   source workspace or partial patch state into N1D.

N1D is therefore a fresh source sync and fresh output build from the exact
source lock, not a repaired N0/N1B/N1C workspace.

## Required pre-sync gates

Before network source sync begins:

```text
canonical host-tool profile merged and verified
historical source-state/evidence seals complete
old-workspace cleanup complete with sufficient free space
Sable integration repository clean
N1D source lock contract PASS
public-only Restless local manifest defined
N1D patch allowlist defined and security-reviewed
source-sync driver bound to exact Graphene/Restless pins
```

The source-sync driver must emit a revision-pinned repo manifest immediately
after sync and require zero dirty projects before patch application.

## Build and flash boundary

This source lock does not authorize an Android build, device contact or flash.

```text
SOURCE_SYNC=HOLD_UNTIL_PRE_SYNC_GATES
BUILD=HOLD_UNTIL_SOURCE_AND_PATCH_QUALIFICATION
DEVICE_CONTACT=NO
FLASH=NO
```

The canonical end-state remains:

```text
bash build/sable.sh titan2 N1D ...
```

Source sync, patch application, build, artifact sealing, offline qualification
and later physical deployment must all be repository-owned phases behind that
interface.
