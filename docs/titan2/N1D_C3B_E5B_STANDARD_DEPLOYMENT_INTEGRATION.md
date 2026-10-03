# N1D C3B E5B standardized deployment integration

Status: **artifact registration + flash-plan qualified; flash execution remains fail-closed**

This phase moves C3B E5B onto the canonical SableOS operator architecture:

```text
build/sable.sh
  -> build/deploy/artifact_registry.py
  -> build/devices/titan2.sh
  -> build/titan2/prepare-n1d-c3b-e5b-flash-plan.sh
```

No standalone E5B operator script is introduced.

## Bound artifact

```text
RELEASE=N1D
BUILD_SOURCE=caf98dde723d07a071d95aaa1ef27d578d3208d8
ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
E5B_DECISION_PACKAGE_SHA256=74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926
```

N0/N1/N1B/N1B2 execution behavior remains unchanged. The global Titan adapter stays fail-closed for flash execution.

## Canonical registration

Run only after this integration is merged and the repository is on the merged commit:

```bash
bash build/sable.sh titan2 N1D register-artifact \
  --build-source caf98dde723d07a071d95aaa1ef27d578d3208d8 \
  --artifact-kind gsi-system-image \
  --primary-artifact system \
  --artifact system=/srv/sable-build/workspaces/titan2-n1d-c3b/out-c3b-engineering/e3-systemimage/20261003T014638Z/target/product/tdgsi_arm64_ab/system.img \
  --expected-sha256 system=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5 \
  --metadata e5b_authorization_json=/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z/e5b-authorization-package.json \
  --metadata e5b_authorization_sha256=74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926 \
  --metadata e5b_manual_authorization_freeze_env=/srv/sable-build/evidence/titan2/n1d-c3b-e5b-manual-authorization-freeze/20261003T061712Z/e5b-manual-authorization-freeze.env \
  --build-evidence-dir /srv/sable-build/evidence/titan2/n1d-c3b-e3-systemimage/20261003T014638Z
```

Expected terminal marker:

```text
SABLE_ARTIFACT_REGISTER=PASS
```

## Canonical flash-plan

```bash
bash build/sable.sh titan2 N1D flash-plan \
  --build-source caf98dde723d07a071d95aaa1ef27d578d3208d8
```

The flash-plan is offline. It:

- verifies the registered E3 artifact;
- derives raw vs Android-sparse image format in the common deployment layer;
- derives the exact fastboot logical image size;
- verifies the sealed E5B decision package and manual-authorization freeze;
- recomputes active-group and total-super capacity using that logical size;
- records that Android fastboot implicitly resizes a logical partition to the image logical size before writing;
- emits no adb, fastboot, reboot, resize, flash, erase, slot, AVB, or userdata command.

Required end marker:

```text
N1D_C3B_E5B_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE
```

## Execution boundary

This integration intentionally retains:

```text
SABLE_DEVICE_FLASH_SUPPORTED=NO
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO
TITAN2_FLASH_EXECUTION_SUPPORTED=NO
TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO
N1D_C3B_E5B_FLASH_EXECUTION_SUPPORTED=NO
```

Do not run `build/sable.sh titan2 N1D flash` from this phase.

The next phase may qualify N1D-only execution through the standard common deployment driver after the generated plan establishes the exact implicit logical-partition resize size and that size is covered by the owner authorization scope.

Factory reset remains separately authorized and is not part of this phase.
