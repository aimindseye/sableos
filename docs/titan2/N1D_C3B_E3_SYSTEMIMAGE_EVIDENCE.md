# N1D C3B E3 systemimage evidence seal

Status: **SEALED PASS**  
Build timestamp: **2026-10-03T01:46:38Z**

E3 produced the first full Sable-composed Titan 2 C3B system image after the
compatibility preflight and exact five-module E2 composition qualification.

## Source binding

```text
BUILD_SOURCE_HEAD=caf98dde723d07a071d95aaa1ef27d578d3208d8
PRODUCT=sable_titan2
DEVICE=tdgsi_arm64_ab
RELEASE=bp4a
VARIANT=userdebug
GOAL=systemimage
```

The build source is the merged E3 engineering head. Later documentation-only
main commits do not change this image identity.

## Final artifact

```text
SYSTEM_IMG=/srv/sable-build/workspaces/titan2-n1d-c3b/out-c3b-engineering/e3-systemimage/20261003T014638Z/target/product/tdgsi_arm64_ab/system.img
SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
SYSTEM_BYTES=2994405376
EVIDENCE_DIR=/srv/sable-build/evidence/titan2/n1d-c3b-e3-systemimage/20261003T014638Z
BUILD_DURATION=02:21:23
```

## Exit markers

```text
N1D_C3B_E3_COMPATIBILITY_PREFLIGHT=PASS
N1D_C3B_E3_E2_COMPOSITION_QUALIFICATION=PASS
N1D_C3B_E3_PRODUCT_ROUTE=PASS_SYSTEM_PRODUCT
N1D_C3B_E3_MODULES_IN_SYSTEM_TREE=PASS count=5
N1D_C3B_E3_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT
N1D_C3B_E3_SYSTEMIMAGE=PASS
```

The five admitted E2 modules are present in the system/product tree:

```text
SableTitan2Keyboard
SableTitan2Camera
SableTitan2DisplayCompat
SableTitan2Setup
SableTitan2RadioDiag
```

## Safety boundary

E3 is an engineering artifact only.

```text
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
TARGET_FILES_AUTHORIZED=NO
OTA_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
RELEASE_ELIGIBLE=NO
```

No target-files or OTA packaging artifacts were admitted into the E3 build
output.

## Next phase

E4 is artifact seal/deployment readiness:

```text
offline artifact audit
logical-partition fit review
stock restore-path verification
fastbootd/read-only deployment plan
explicit operator authorization package
```

E4 must not infer flash permission from E3 PASS.
