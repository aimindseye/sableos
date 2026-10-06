# Titan 2 N1I-D0 IMG0 — Consolidated Image Build R1

Status: **BUILD AUTHORIZED — DEVICE ACTIONS NOT AUTHORIZED**

Date: 2026-10-06

## Canonical branch

`n1i-d0-0h-host-closure-20261006`

This is the sole active N1I-D0 implementation branch. PR #335 merged the three N1I-D0 histories into this branch. The latest
D0-0H implementation remains the source authority; non-overlapping host-audit
assets from the two older branches are retained for evidence/review rather than
replacing newer shared build or flash logic.

## IMG0 composition

IMG0 closes the image-build path without reintroducing the C1/C2 boot-risk
surface:

- exact boot-qualified C3A substrate;
- exactly the five N1F Sable product applications;
- one inert product marker at `/product/etc/sable/n1i-d0-image`;
- no C1/C2 OEM IMS, Java, SELinux, JNI or native-library delta.

The marker makes the built image branch-identifiable while remaining outside
runtime service/classpath admission.

## Execution boundary

```text
SOURCE_MUTATION_AUTHORIZED=YES_EXACT_IMG0_STAGE
BUILD_AUTHORIZED=YES_ONE_SYSTEMIMAGE
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
MODE_TRANSITION_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

The driver uses the validated warm C3A output and performs one incremental
`systemimage` build. It installs the source-restore trap before staging, runs the
shared build-regression contract and an IMG0-specific static contract, seals the
artifact, then restores the Android source staging.

## Operator command

```bash
cd /srv/sable-build/sableos/repo

git fetch origin n1i-d0-0h-host-closure-20261006
git checkout n1i-d0-0h-host-closure-20261006
git reset --hard origin/n1i-d0-0h-host-closure-20261006

bash build/gates/n1i-d0-image-build-contract.sh
python3 build/gates/build-regression-contract.py

bash build/titan2/run-n1i-d0-image-build.sh \
  --tmux \
  --authorize-source-mutation \
  --authorize-build
```

The start command prints the retained tmux session and attach command.

## Required success markers

```text
N1I_D0_IMAGE_BUILD_CONTRACT=PASS
SABLE_BUILD_REGRESSION_CONTRACT=PASS
N1I_D0_IMAGE_SELFTEST=PASS
N1I_D0_IMAGE_SOURCE_RESTORE=PASS
N1I_D0_IMAGE_BUILD=PASS sha256=<sha256> bytes=<bytes>
N1I_D0_IMAGE_ARTIFACT=<artifact-dir>
N1I_D0_IMAGE_EVIDENCE=<evidence-dir>
DEVICE_CONTACT=NONE
FLASH=NONE
```

The sealed image is written below
`$SABLE_ARTIFACTS_ROOT/titan2/n1i-d0-img0/<UTC-stamp>/system.img`.

A successful IMG0 build authorizes no flash or reboot. Physical qualification is
a separate explicitly authorized deliverable.
