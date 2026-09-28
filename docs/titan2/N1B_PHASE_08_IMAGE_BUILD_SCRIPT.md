# N1B Phase 08 image build script

Status: **image-build driver / no device action**

This document records the first Phase 08 build driver. It is not a flash script,
not a public release path, and not a production signing path.

```text
N1B_PHASE_08_IMAGE_BUILD_SCRIPT=YES
DEVICE=titan2
RELEASE=N1B
ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
BUILD_AUTHORIZED=YES_N1B_IMAGE_ONLY
IMAGE_BUILD_AUTHORIZED=YES_N1B_CANDIDATE_ONLY
SOURCE_MUTATION_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Script

```text
BUILD_SCRIPT=build/titan2/build-n1b-phase-08-image-candidate.sh
CONTRACT=build/gates/n1b-phase-08-image-build-script-contract.sh
```

## Required input

The script requires an Android / RestlessOS source tree that already contains the
N1B Sable product graph. It does not patch that tree and does not inject payloads
itself.

```text
ANDROID_SRC=operator_supplied
ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk
ACTIVE_PRODUCT_GRAPH_REQUIRES_VENDOR_SABLE_INHERIT=YES
LUNCH_TARGET=treble_arm64_bvN-bp4a-userdebug
```

The script also requires a full local CI evidence directory for the current
SableOS source commit. The old Phase 07 evidence is not enough after this script
lands because the script itself changes the source tree.

```text
FULL_LOCAL_CI_REQUIRED_FOR_CURRENT_HEAD=YES
FULL_LOCAL_CI_PROFILE=full
FULL_LOCAL_CI_DEVICE=titan2
FULL_LOCAL_CI_RELEASE=N1B
FULL_LOCAL_CI_PASS_MARKER=SABLE_LOCAL_CI=PASS
FULL_LOCAL_CI_SOURCE_COMMIT_MUST_EQUAL_CURRENT_HEAD=YES
```

## Build scope

The driver builds only the N1B system image candidate and associated target-files
evidence from the supplied source tree.

```text
BUILD_GOALS=systemimage,target-files-package,otatools
SYSTEM_IMG_REQUIRED=YES
TARGET_FILES_REQUIRED=YES
TARGET_FILES_SABLE_MARKER=SYSTEM/product/etc/sableos/n1-substrate.env
SYSTEM_SHA256_REQUIRED=YES
SYSTEM_LOGICAL_BYTES_REQUIRED=YES
TARGET_FILES_SHA256_REQUIRED=YES
```

## Registration scope

By default, the script registers the built system image through the central
SableOS entrypoint as a Titan2/N1B GSI artifact.

```text
REGISTER_ENTRYPOINT=build/sable.sh titan2 N1B register-artifact
REGISTER_ARTIFACT_KIND=gsi-system-image
REGISTER_PRIMARY_ARTIFACT=system
REGISTER_METADATA_ARTIFACT_LOGICAL_BYTES=YES
REGISTER_METADATA_FULL_CI_EVIDENCE_DIR=YES
REGISTER_METADATA_IMAGE_BUILD_EVIDENCE_DIR=YES
```

The Titan2 adapter still blocks flash execution. Registration is not deployment.

```text
FLASH_EXECUTION_SUPPORTED=NO
TITAN2_N0_N1_FLASH_PLAN_REQUIRED=YES
FLASH_PLAN_ALLOWED=LEDGER_ONLY_AFTER_METADATA
```

## Explicit exclusions

```text
DEVICE_CONTACT_ALLOWED=NO
FLASH_COMMAND_ALLOWED=NO
USERDATA_WIPE_ALLOWED=NO
PUBLIC_RELEASE_ALLOWED=NO
PRODUCTION_SIGNING_ALLOWED=NO
TITAN_TOUCHPAD_DAEMON_ENABLED=NO
CUSTOM_UINPUT_DAEMON_SEPOLICY=NO
UNVALIDATED_KEYLAYOUT_MUTATION=NO
SUBSCREEN_ACTIVE_RUNTIME_UNLESS_VALIDATED=NO
BOOT_IMAGE_PATCHING_ALLOWED=NO
KERNEL_PATCHING_ALLOWED=NO
PERMISSIVE_SELINUX_ALLOWED=NO
```

## Example invocation

The operator must first rerun full local CI on the merged source commit, then use
that new evidence directory.

```bash
SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full

bash build/titan2/build-n1b-phase-08-image-candidate.sh \
  --android-src /path/to/treble_restlessos/src \
  --full-ci-evidence-dir /srv/data/sable-build/sableos/local-ci-evidence/<current-head-full-ci> \
  --out-dir /srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi
```

## Acceptance

```text
N1B_PHASE_08_IMAGE_BUILD_SCRIPT_CONTRACT=PASS
N1B_PHASE_08_IMAGE_BUILD_CANDIDATE=PASS
N1B_PHASE_08_ARTIFACT_REGISTRATION=PASS
```
