# Titan 2 N1D C2 source admission R1

Status: source admission only; no Android build; no device contact; no flash.

Date: 2026-10-01

## Purpose

C2 is the bounded Restless/Treble diagnostic control used to distinguish
generic Treble compatibility behavior from the Sable-owned C3 baseline.

The C2 source-admission phase starts only after the fresh Graphene/AOSP Android
16 base has been synchronized and sealed.

Canonical base:

```text
/srv/sable-build/workspaces/titan2-n1d/android
```

Base evidence:

```text
/srv/sable-build/evidence/titan2/n1d-source-prep/
  20261001T045509Z-graphene-base
```

Base seal:

```text
365780be847eba999a72603c501a0f3afcac30dc61f71ce35165d8271dfbf830
```

The sealed base contains 1,033 projects, zero dirty projects, no
`device/phh/treble`, and no private Restless vendor.

## Admission source of truth

C2 does not consume the mutable Restless local manifest directly.

The repository-owned derivation tool reads the sealed historical public R6
`repo manifest -r`, requires each selected project revision to be an exact
40-hex commit, rejects private/SSH/mutable source identity, and emits exactly
13 project paths.

For installation into the Graphene checkout, all historical remote names are
rewritten with the `n1d-c2-` prefix. Every selected project receives an
explicit remote, including projects whose historical remote came from the
manifest `<default>`.

This prevents local-manifest remote-name collisions with Graphene's base
manifest.

## Exact admission set

The bounded C2 project paths are:

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

The pinned Graphene base manifest does not own any of these 13 paths.

## Pre-admission proof

Before the local C2 manifest is installed, the driver requires:

```text
Graphene manifest HEAD == 5d82aa9610855bc0b43b9eb7ca4470d30455cfeb
base seal SHA256 == 365780be847eba999a72603c501a0f3afcac30dc61f71ce35165d8271dfbf830
base project count == 1033
base dirty project count == 0
current base HEAD ledger == sealed base HEAD ledger
no local manifests
no device/phh/treble
no private Restless vendor
no Android OUT
no out-c2
no out-c3
```

## Admission operation

Offline qualification:

```bash
bash build/titan2/admit-n1d-c2-source.sh preflight
```

Network-authorized admission:

```bash
bash build/titan2/admit-n1d-c2-source.sh \
  admit \
  --authorize-network
```

The network-authorized action may mutate only:

```text
.repo/local_manifests/n1d-c2-public-pinned.xml
the 13 exact C2 project paths
```

It runs `repo sync` with those 13 paths explicitly supplied.

## Post-admission proof

After sync, the driver captures the complete project HEAD ledger and requires:

```text
base project count == 1033
C2 project count == 13
total project count == 1046
all 1033 base HEADs unchanged
all 13 C2 HEADs exactly equal the pinned revisions
base/C2 path overlap == 0
unexpected project paths == 0
dirty project count == 0
private Restless vendor absent
```

The resulting source-composition evidence is sealed beneath:

```text
/srv/sable-build/evidence/titan2/n1d-c2-source-admission/
```

## Security/product boundary

Presence of a project in C2 does not authorize it for C3.

In particular, C2 may contain PHH/Treble compatibility code, legacy VNDK
packages, QcRilAm, TrebleApp, vendor Magisk source, and other diagnostic
compatibility components which remain outside the C3 baseline unless a
separate evidence-admission decision explicitly permits a narrowly scoped
change.

C2 remains:

```text
N1D_C2_PRODUCT_ROLE=DIAGNOSTIC_CONTROL_ONLY
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

C2 build composition and C2-to-C3 source retirement are later, separate gated
phases.
