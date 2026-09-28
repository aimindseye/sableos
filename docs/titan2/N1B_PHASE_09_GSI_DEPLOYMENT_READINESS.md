# N1B Phase 09: Titan2 GSI Deployment Readiness

N1B Phase 09 is a readiness gate for the registered Titan2/N1B `system.img` GSI candidate. It is not a flash execution step.

```text
DEVICE=titan2
RELEASE=N1B
PHASE=N1B_PHASE_09
ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
FLASH_EXECUTION_SUPPORTED=NO
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
FLASH_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Relationship to N1A

N1A was the earlier active-product-graph and Sable overlay proof. N1B is the current registered GSI candidate built from the advanced source graph.

N1B does not combine a second N1A image. N1A is lineage and substrate context; N1B is the deployable `system.img` GSI candidate.

```text
N1A=lineage/context
N1B=current registered system GSI candidate
N1B_COMBINES_N1A_IMAGE=NO
```

## Phase 08 input

Phase 09 consumes the registered N1B artifact produced by Phase 08.

Required Phase 08 build/registry metadata:

```text
schema
device
release
build_source
tool_source
out_dir
primary_artifact
metadata.active_product_mk
metadata.artifact_logical_bytes
metadata.n1b_full_local_ci_evidence_dir
metadata.n1b_full_local_ci_profile
metadata.n1b_phase_08_image_build_evidence_dir
metadata.device_contact_authorized=NO
metadata.flash_authorized=NO
metadata.public_release=NO
metadata.production_signing=NO
```

## Physical preflight metadata required before flash-plan

Phase 09 is expected to remain blocked until physical preflight metadata is available. The metadata must be explicitly collected and recorded before a flash-plan can be generated.

Required physical metadata:

```text
active_slot
avb_action
bootloader_preflight
explicit_titan_serial
fastbootd_preflight
lp_action
restore_path_verified
restore_report
snapshot_update_status
stock_baseline
system_current_bytes
userdata_policy
```

## Expected current result

For the current N1B registered image, the correct result is blocked because the artifact registry intentionally does not contain physical device preflight metadata.

```text
N1B_PHASE_09_MANIFEST_SCHEMA=PASS
N1B_PHASE_09_BUILD_METADATA=PASS
N1B_PHASE_09_BOUNDARY=PASS
N1B_PHASE_09_PHYSICAL_PREFLIGHT_METADATA=BLOCKED_MISSING_METADATA
N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED
N1B_PHASE_09_FLASH_PLAN_ALLOWED=NO
FLASH_AUTHORIZED=NO
```

This blocked state is a successful safety result, not a source/build failure.

## Ready result

Phase 09 may report ready only when all required physical metadata is present and internally consistent. Even then, the result authorizes only flash-plan generation, not flash execution.

```text
N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=PASS
N1B_PHASE_09_FLASH_PLAN_ALLOWED=YES_PLAN_ONLY
FLASH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
```

## Non-goals

Phase 09 does not:

```text
CONTACT_DEVICE=NO
RUN_ADB=NO
RUN_FASTBOOT=NO
FLASH_SYSTEM=NO
ERASE_USERDATA=NO
PATCH_BOOT=NO
PATCH_VENDOR_BOOT=NO
PATCH_KERNEL=NO
PRODUCTION_SIGN=NO
PUBLISH_RELEASE=NO
```
