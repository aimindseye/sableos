# N1D C3B E4 deployment readiness

Status: **operator-ready, offline/read-only**

E4 consumes the sealed E3 image and existing read-only Titan 2 partition/restore
evidence. It does not contact or mutate the device.

## Inputs

Sealed E3 image:

```text
SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
BYTES=2994405376
```

Historical read-only fastbootd sizing evidence:

```text
/srv/data/sable-build/evidence/titan2/n1b-phase-11-lp-super-sizing/20260928_195308/fastbootd-lp-sizing/phase11-fastbootd-lp-sizing.json
```

Stock restore evidence defaults to the inspected TEE14 reference and N1C proven
restore evidence. Local paths may be overridden explicitly.

## Current sizing expectation

From the historical read-only fastbootd evidence:

```text
historical system logical bytes=756441088
historical estimated super headroom=5510365184
E3 image bytes=2994405376
safety margin=268435456
alignment=1048576
planned target bytes=3263168512
planned growth bytes=2506727424
estimated remaining super headroom=3003637760
```

Therefore the expected classification is:

```text
DIRECT_FIT=NO
PARTITION_FIT=PASS_RESIZE_CAPACITY_APPEARS_AVAILABLE_REVIEW_REQUIRED
```

This is not resize authorization. Active slot, snapshot state, logical sizes and
available capacity must be freshly revalidated at the later explicitly authorized
device-contact boundary before any LP mutation.

## E4 gates

The qualifier verifies:

1. exact E3 SHA-256 and byte size;
2. E3 evidence contract;
3. parseable AVB metadata for the sealed system image;
4. stock super/boot/vbmeta restore components are present;
5. prior stock super and boot/AVB restore proof is recorded;
6. E3 partition-fit calculation against historical read-only fastbootd evidence;
7. no device/build/network/mutation authorization.

## Run

After merging the E4 package:

```bash
cd /srv/sable-build/sableos/repo

git fetch origin main
git switch main
git pull --ff-only origin main

bash build/gates/n1d-c3b-e4-deployment-readiness-contract.sh

bash build/titan2/qualify-n1d-c3b-e4-deployment-readiness.sh
```

If local historical evidence is stored elsewhere, use the explicit path options.

## Success boundary

Expected final marker:

```text
N1D_C3B_E4_DEPLOYMENT_READINESS=PASS_REVIEW_READY
```

Even after PASS:

```text
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
RELEASE_ELIGIBLE=NO
```

A later E5 authorization package must perform fresh read-only device checks
before any mutation is discussed.
