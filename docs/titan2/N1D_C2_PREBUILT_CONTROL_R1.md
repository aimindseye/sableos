# Titan 2 N1D C2 prebuilt diagnostic control R1

Status: active C2 control path; source reconstruction blocked; no device contact; no flash.

Date: 2026-10-01

## Decision

N1D C2 remains a diagnostic/control track only. It no longer attempts to
reconstruct the exact historical Restless/Treble source graph from current
public remotes.

Two required locked source objects could not be materialized from the current
public repositories:

```text
device/phh/treble
  db688b38d729cf33e31baea47986c3fd210b671e

prebuilts/vndk/v29
  0062f4721125d68951fba37361c8204b929ae178
```

The historical sealed R6 manifest remains evidence of the source graph that was
used. It is not treated as currently reproducible source.

The exact-source path is therefore:

```text
N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE
N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED=NO
```

No current branch tip or replacement commit may be substituted for either
locked revision.

## Active C2 control

The active C2 control is the original published RestlessOS Android 16 GSI release:

```text
release tag:
  16.0.0-202606230923

release commit:
  4adc5766f457849ca37e0b318bced65aef5a2233

GrapheneOS base:
  2026061600

asset:
  RestlessOS-arm64-ab-16.0.0-202606230923.img.xz

asset size:
  920490780 bytes

asset SHA-256:
  52ea47d794faf6eafbb49a5f0d2301508757be0e30d1b73e033e1d5185bb492c
```

The published release artifact is the C2 identity. It is not a Sable release
artifact and carries no C3 security claim.

## Fetch and verify

Offline preflight:

```bash
bash build/titan2/fetch-n1d-c2-control.sh preflight
```

Network-authorized download:

```bash
bash build/titan2/fetch-n1d-c2-control.sh \
  download \
  --authorize-network
```

Offline verification of an already downloaded artifact:

```bash
bash build/titan2/fetch-n1d-c2-control.sh verify
```

The artifact is stored under:

```text
/srv/sable-build/artifacts/titan2/n1d-c2-control/
```

The driver requires the exact size and SHA-256 before accepting the control.

## Failed source-admission evidence

The failed exact-source attempts are retained as evidence:

```text
/srv/sable-build/evidence/titan2/n1d-c2-source-admission/
  20261001T054416Z-c2-admission
  20261001T095239Z-c2-resume
```

Those failures occurred before C2 admission closure. No Android build, device
contact or flash was authorized by either attempt.

## Restore the Android checkout before C3

The failed source-admission attempts left exact clean worktrees for 11 of the
13 C2 projects and the C2 local manifest in the otherwise sealed Android base.

Before any C3 source staging, run the offline retirement preflight:

```bash
bash build/titan2/retire-n1d-c2-source.sh preflight
```

Then retire the partial C2 source state:

```bash
bash build/titan2/retire-n1d-c2-source.sh retire
```

Retirement is bounded to:

```text
.repo/local_manifests/n1d-c2-public-pinned.xml
only present C2 worktrees whose HEAD exactly matches the sealed C2 ledger
```

The driver does not delete the shared repo object cache. It verifies every
1,033 base project before mutation and again after retirement. The post-state
must exactly match the accepted Graphene/AOSP base HEAD ledger.

## Product and security boundary

C2 is:

```text
N1D_C2_CONTROL_MODE=PINNED_PREBUILT_RESTLESS_GSI
N1D_C2_PRODUCT_ROLE=DIAGNOSTIC_CONTROL_ONLY
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

C2 does not authorize PHH/Treble product inheritance in C3. C3 continues from
the clean sealed Graphene/AOSP Android 16 base and the Sable-owned product
contract.
