# Titan 2 N1D fresh-source workflow R1

Status: **base source workflow; Graphene/AOSP base sealed**

Date: 2026-10-01

## Purpose

N1D uses one fresh Android 16 source checkout on the canonical WD_BLACK build
filesystem. Historical Android workspaces are not source inputs. Historical
sealed metadata may be used only to recover exact public project revisions for
the C2 diagnostic control.

Canonical layout:

```text
/srv/sable-build/workspaces/titan2-n1d/
  android/   # one fresh pinned Android 16 checkout
  out-c2/    # C2 output only
  out-c3a-td/ # C3A control output only
```

The SableOS repository remains separate:

```text
/srv/sable-build/sableos/repo
```

Canonical host tools remain separate:

```text
/srv/data/sable-host-tools
```

## Base source identity

The base checkout is initialized directly from the pinned GrapheneOS Android 16
manifest. Git LFS is not a source-sync prerequisite for this stage. GrapheneOS
documents git-lfs as an additional Vanadium/Chromium build dependency, so N1D
does not require it unless a later workflow explicitly builds Vanadium from
source.


```text
manifest repository:
  https://github.com/GrapheneOS/platform_manifest.git

manifest ref:
  refs/tags/2026061600

manifest commit:
  5d82aa9610855bc0b43b9eb7ca4470d30455cfeb

AOSP revision:
  android-16.0.0_r4

release config:
  bp4a
```

The manifest itself pins GrapheneOS projects to exact release commits and uses
the AOSP Android 16 tag for the default upstream.

## Why the Restless sync script is not used

The pinned Restless Android-16 repository contains a convenience sync script
which resolves the newest GrapheneOS stable release at runtime. That is
incompatible with the N1D source lock.

Restless `configs/manifests/default.xml` contains mutable `main` / `master`
revisions and a private SSH vendor remote, so N1D never copies that add manifest
directly. C3A separately pins the exact Restless `remove.xml`, which contains
only deterministic project removals.

## Historical C2 public compatibility pins

The sealed public R6 `repo manifest -r` remains audit evidence for the
historical Restless/Treble source graph. It is no longer the active C2 build
input because exact reconstruction proved incomplete from current public
remotes.

The source of truth is:

```text
/srv/sable-build/evidence/titan2/
  n1d-precleanup-source-state-20261001T022132Z/
    n0b-restless-r6/
      repo-manifest-pinned.xml
      all-project-heads.tsv
```

The enclosing evidence package is bound to:

```text
SHA256(SHA256SUMS.txt) =
6973822165e95de5874870fb2b19ea4e812842abf6e8044130970fd1b5467c5c
```

The repository-owned derivation tool extracts exactly these public project
paths and requires every revision to be a 40-hex commit:

```text
device/phh/treble
packages/apps/QcRilAm
prebuilts/vndk/v28
prebuilts/vndk/v29
prebuilts/vndk/v30
treble_app
vendor/apn
vendor/hardware_overlay
vendor/interfaces
vendor/lptools
vendor/magisk
vendor/pixel/gsans
vendor/vndk-tests
```

`vendor/cawilliamson-priv`, SSH remotes, `main`, and `master` are rejected.

The presence of these projects in C2 does not make them acceptable C3 product
content. C3 remains governed by the separate Restless security boundary.

## One-checkout lifecycle

The intended lifecycle is:

```text
fresh Graphene/AOSP Android 16 base
  -> seal pinned manifest and zero-dirty state
  -> audit bounded historical C2 source reconstruction
  -> fail closed when two historical source objects are unavailable
  -> use pinned published RestlessOS GSI as C2 diagnostic control
  -> retire partial C2 source paths
  -> restore and verify the same checkout against the pinned 1033-project base
  -> stage pinned TrebleDroid/Restless C3A control inputs
     (54 Restless removals + 12 public additions = 991 managed C3A projects)
  -> parse/qualify C3A generated product
  -> build/seal C3A control system.img
  -> use C3A evidence to peel toward minimal C3B Sable baseline
```

The C2-to-C3 transition begins from the exact sealed 1,033-project base.
C3A then applies the pinned Restless remove manifest and public add manifest.
Because the base is already synchronized, the 54 removed working trees are
moved to a reversible artifact archive rather than deleted. The resulting C3A
managed graph contains 991 projects. The fresh-source preparation driver itself
still performs no build.

## Driver actions

Offline preflight:

```bash
bash build/titan2/prepare-n1d-fresh-source.sh preflight
```

Derive and seal the exact public C2 pin manifest without network access:

```bash
bash build/titan2/prepare-n1d-fresh-source.sh derive-c2-manifest
```

Network actions require explicit authorization:

```bash
bash build/titan2/prepare-n1d-fresh-source.sh \
  init-base \
  --authorize-network

bash build/titan2/prepare-n1d-fresh-source.sh \
  sync-base \
  --authorize-network
```

An already synchronized base can be sealed again offline:

```bash
bash build/titan2/prepare-n1d-fresh-source.sh seal-base
```

## Base seal requirements

The base seal requires:

```text
canonical build filesystem verified
Graphene manifest checkout HEAD == pinned manifest commit
repo manifest -r emitted
all project HEADs recorded
dirty project count == 0
generic_system_arm64.mk present
gsi_release.mk present
device/phh/treble absent from base
private Restless vendor absent
pre-existing Android OUT absent
out-c2 absent
out-c3 absent
```

## Authorization boundary

The contract and offline actions authorize no network fetch, Android build,
device contact, or flash.

Only `init-base --authorize-network` and
`sync-base --authorize-network` authorize the network activity required by
those specific invocations.

Neither action authorizes an Android build.

```text
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```
