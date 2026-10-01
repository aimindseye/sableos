# Titan 2 N1D C3 product composition R1

Status: source-staging contract; no Android build; no device contact; no flash.

Date: 2026-10-01

## Purpose

C3 is the actual SableOS N1D system image. It starts from the accepted clean
GrapheneOS/AOSP Android 16 base and does not inherit the Restless/PHH universal
product hierarchy.

Prerequisites already established:

```text
GrapheneOS manifest commit:
  5d82aa9610855bc0b43b9eb7ca4470d30455cfeb

AOSP:
  android-16.0.0_r4

release config:
  bp4a

accepted base project count:
  1033

accepted base dirty project count:
  0

accepted base seal:
  365780be847eba999a72603c501a0f3afcac30dc61f71ce35165d8271dfbf830
```

The C2 diagnostic control is the separately pinned published RestlessOS GSI.
C2 source worktrees have been retired from the Android checkout before C3.

## C3 product chain

The intended product chain is exactly:

```text
build/make/target/product/generic_system_arm64.mk
  -> build/make/target/product/gsi_release.mk
  -> BUILDING_GSI := false
  -> vendor/sable/n1d/treble_compat.mk
  -> vendor/sable/n1d/sable_n1d_product_delta.mk
```

The product is registered by:

```text
vendor/sable/n1d/AndroidProducts.mk
```

and named:

```text
sable_titan2_n1d_arm64
```

Its resolved board device is:

```text
gsi_arm64
```

which uses the pinned Graphene/AOSP
`build/make/target/board/gsi_arm64/BoardConfig.mk` and
`BoardConfigGsiCommon.mk` semantics.

Android 16 QPR2 uses release config `bp4a`. The first engineering build
variant is `userdebug`; the release-security variant remains `user`. Product
composition staging itself authorizes neither build.

## Why this base is sufficient

The pinned Android 16 `generic_system_arm64.mk` is system-only. It does not
build vendor, product, system_ext, userdata or super images.

The pinned `gsi_release.mk` supplies GSI release behavior, including
`gsi_skip_mount.cfg` and current extra VNDK support for versions 31 through
34.

The first live C3 compile also established that Graphene intentionally lacks
several AOSP application modules referenced by build/make's Soong-defined GSI
image. C3 therefore sets `BUILDING_GSI := false` after inheriting
`gsi_release.mk`. The value remains non-empty for
`BoardConfigGsiCommon.mk`'s Make-side `ifdef BUILDING_GSI` handling, while
the Soong config conversion uses `filter true`; therefore `false` becomes an empty `SOONG_CONFIG_gsi_building_gsi` value and does not enable the incompatible `aosp_system_image` module.

Titan 2 vendor/VNDK API is 34, so C3 does not restore legacy VNDK 28/29 as a
baseline compatibility mechanism.

## Initial compatibility state

C3 intentionally begins with:

```text
N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT=0
N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0
```

Therefore:

```text
vendor/sable/n1d/treble_compat.mk
```

contains no active compatibility declarations, and:

```text
vendor/sable/n1d/restless-patch-allowlist.txt
```

is empty.

A compatibility change may be admitted only after a reproduced build/runtime
failure or a separately reviewed Titan-specific requirement.

## Hard exclusions

The staged C3 bundle must not contain or directly inherit:

```text
device/phh/treble/base.mk
device/phh/treble/rom.mk
SELinux neverallow bypasses
unauthenticated/default USB ADB policy
PHH root/securize/OTA/remote-debug tooling
TrebleApp
legacy VNDK 28/29 additions
vendor Magisk
QcRilAm
private Restless vendor content
```

The existing N1D Restless security-boundary contract remains authoritative.

## Repository-owned source bundle

The canonical bundle is:

```text
build/titan2/n1d-c3-product/
  AndroidProducts.mk
  sable_titan2_n1d_arm64.mk
  treble_compat.mk
  sable_n1d_product_delta.mk
  restless-patch-allowlist.txt
```

It is copied into the Android checkout only by the repository-owned staging
driver.

## Staging workflow

Offline preflight:

```bash
bash build/titan2/stage-n1d-c3-product.sh preflight
```

Source mutation requires explicit authorization:

```bash
bash build/titan2/stage-n1d-c3-product.sh \
  stage \
  --authorize-source-mutation
```

Post-stage offline verification:

```bash
bash build/titan2/stage-n1d-c3-product.sh verify
```

After the first compile exposed the Graphene/AOSP Soong GSI mismatch, the
already-staged product may be refreshed only through the bounded remediation
action:

```bash
bash build/titan2/stage-n1d-c3-product.sh \
  refresh \
  --authorize-source-mutation
```

The refresh is limited to `sable_titan2_n1d_arm64.mk`. It requires the
currently staged product file to match the exact pre-remediation SHA-256 and
requires the other four staged files to remain byte-identical. Existing failed
`out-c3` is tolerated for source verification but is neither read nor modified
by the refresh.

The stage action may create only:

```text
/srv/sable-build/workspaces/titan2-n1d/android/vendor/sable/n1d/
```

with the five files listed above.

## Pre-stage requirements

The driver requires:

```text
canonical storage verified
accepted base seal verified
all 1033 base project HEADs exactly equal the sealed ledger
base dirty project count = 0
Graphene manifest HEAD = pinned manifest commit
no local manifests
all retired C2 source paths absent
no Android out
no out-c2
no out-c3
pinned C2 control artifact present at exact size and SHA-256
stage target absent
```

## Post-stage requirements

After copying the bundle, the driver requires:

```text
all five staged files byte-identical to repository-owned sources
base project count remains 1033
all base HEADs remain exact
base dirty project count remains 0
no local manifests
no build output for the initial stage; refresh may coexist with preserved failed out-c3
zero active Treble compatibility items
zero Restless patch allowlist entries
```

The stage evidence is sealed under:

```text
/srv/sable-build/evidence/titan2/n1d-c3-product-composition/
```

## Next phase

A successful stage does not prove the product parses or builds.

The next gate is a separate product-parse qualification using the staged
product and `bp4a`, still with no device contact or flash. Only after product
parse succeeds should C3 compilation be authorized.

## Authorization boundary

```text
NETWORK_FETCH_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
```
