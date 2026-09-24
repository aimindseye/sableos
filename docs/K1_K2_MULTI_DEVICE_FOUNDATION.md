# K1/K2 multi-device artifact and deployment foundation

Status: **implemented in source; host-only qualification required before merge**

## K1 — artifact registry v2

The registry key remains:

```text
device + release + build source
```

Physical device serial is never part of artifact identity.

Schema v2 adds:

```text
artifact_kind
primary_artifact
artifacts.<name>.path
artifacts.<name>.sha256
artifacts.<name>.size
tool_source
metadata
```

Supported kinds are currently:

```text
target-files
full-device-images
gsi-system-image
system-product-bundle
boot-recovery-bundle
```

Panther compatibility is preserved. Target-files records retain the legacy
`target_files`, `target_files_sha256`, `android_info` and
`android_info_sha256` aliases, and schema-1 manifests remain readable and
verifiable.

The registry self-test covers both:

- legacy-compatible Panther target-files registration/verification;
- generic Titan-style GSI registration/verification;
- primary-artifact SHA mismatch rejection.

Release artifact registration is separately capability-gated by each device
adapter. Generic schema support does not make an unqualified device releasable.

## K2 — common deployment policy vs device transport

`build/deploy/flash.sh` now owns only common policy/orchestration:

- explicit `--authorize`;
- preserved-data-only policy;
- exact registered artifact verification;
- artifact-kind support check;
- selected ADB serial exact-once binding;
- source checkout cleanliness;
- evidence capture/sealing;
- preserved-data baseline;
- adapter callback dispatch;
- bounded pre-write recovery;
- common Android boot / credential-encrypted-data return;
- final device identity capture.

Device adapters own these callbacks:

```text
sable_device_flash_prepare_artifact
sable_device_flash_preflight
sable_device_flash_execute
sable_device_flash_postboot
optional sable_device_flash_recover_prewrite
```

Panther additionally owns:

```text
sable_device_flash_plan
artifact kind = target-files
A/B slot validation
android-info bootloader/baseband/partition requirements
fastboot serial binding
staged target-files payload verification
current-slot fastboot flashall
skip-secondary / skip-reboot
post-flash slot preservation
target-files-aware sablectl smoke
```

The common flash driver is statically forbidden from containing Panther
`flashall` or `has-slot` semantics.

## Current adapter state

```text
panther
  artifact registration      YES
  flash plan                 YES
  flash                      YES
  artifact kind              target-files
  transport                  fastboot-ab-target-files

titan2
  artifact registration      NO
  flash plan                 NO
  flash                      NO
  artifact kind              none
  transport                  UNQUALIFIED

titan2-elite
  artifact registration      NO
  flash plan                 NO
  flash                      NO
  artifact kind              none
  transport                  UNQUALIFIED

q27
  artifact registration      NO
  flash plan                 NO
  flash                      NO
  artifact kind              none
  transport                  UNQUALIFIED
```

This is intentional. K1/K2 provides the framework; Titan enablement requires
separate device evidence and adapter qualification.

## Required host-only qualification

No device contact, build or flash is required for K1/K2 source qualification.

```bash
bash build/gates/sable-pipeline-contract.sh
```

New required markers include:

```text
SABLE_ARTIFACT_REGISTRY_SCHEMA=PASS_V2_BACKWARD_COMPATIBLE
SABLE_ARTIFACT_REGISTRY_GENERIC_GSI_SELF_TEST=PASS
SABLE_PIPELINE_MULTI_DEVICE_ARTIFACT_SCHEMA=PASS
SABLE_PIPELINE_COMMON_FLASH_DEVICE_SEMANTICS=PASS_ISOLATED
SABLE_PIPELINE_MULTI_DEVICE_SERIAL_SCOPE=PASS
SABLE_PIPELINE_DEVICE_DEPLOYMENT_CALLBACK_BOUNDARY=PASS
SABLE_STANDARD_PIPELINE_CONTRACT=PASS
```

After that passes, run local CI before merge. Panther image rebuild/flash is not
required because this tranche changes deployment/tooling contracts, not the
already frozen Panther image source.
