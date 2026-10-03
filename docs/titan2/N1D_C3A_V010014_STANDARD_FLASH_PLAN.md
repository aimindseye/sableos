# Titan 2 C3A V01.00.14 standard flash plan

Status: **canonical registration + sealed no-write plan / physical execution still closed**

Updated: **2026-10-03 ET**

## Purpose

The C3A compatibility control has passed its fresh fastboot-entry preflight on
the current Titan 2 state:

```text
PREFLIGHT_EVIDENCE_DIR=
/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z

PREFLIGHT_EVIDENCE_SEAL_SHA256=
47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893

C3A_FASTBOOT_ENTRY_PREFLIGHT=PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW
CURRENT_SLOT=a
IS_USERSPACE=yes
PRODUCT=Titan_2
SNAPSHOT_UPDATE_STATUS=none
ACTIVE_COW_COUNT=0
SUPER_CAPACITY_SAFE=YES
ACTIVE_GROUP_CAPACITY_SAFE=YES
```

The next step is deliberately **not** the write. It is:

```text
1. register the exact C3A artifact and sealed control evidence
2. generate the canonical standard flash plan
3. obtain the resulting flash-plan evidence seal
4. stop
```

Physical execution remains unavailable until a later change binds the standard
Titan executor to that exact plan seal.

## C3A identity

```text
SYSTEM_IMG=
/srv/sable-build/workspaces/titan2-n1d/out-c3a-td/target/product/tdgsi_arm64_ab/system.img

SYSTEM_SHA256=
4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16

SYSTEM_BYTES=3146977280
CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION
CONTROL_PATCH_COUNT=369
MANAGED_PROJECT_COUNT=991
```

The artifact registry requires a 40-hex `build-source` key. The historical C3A
build driver did not record the integration-repository HEAD in its build-state,
so this plan does **not** infer one from timestamps.

The canonical registry key is:

```text
C3A_REGISTRY_BUILD_SOURCE=
e6bcd76885c6048da7cbd9f200a9b1102e6d91a2

C3A_REGISTRY_BUILD_SOURCE_ROLE=
POSTBUILD_EVIDENCE_SEAL_COMMIT_NOT_RECORDED_BUILD_START_HEAD
```

This is the commit that sealed the successful C3A systemimage evidence. It is an
artifact-authority/registry identity, not a claim that it was the source HEAD at
build start.

## Bound evidence

Offline C3A control:

```text
/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan
seal=e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57
```

Fresh fastboot-entry preflight:

```text
/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z
seal=47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893
```

Sealed V01.00.14 E5A/E5B baseline:

```text
/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z
e5b_sha256=74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926
```

C3A build evidence:

```text
/srv/sable-build/evidence/titan2/n1d-c3a-trebledroid-build/20261001T214611Z-trebledroid-systemimage
```

The plan generator requires the preflight JSON to be the canonical named member
of the exact preflight seal directory, and the offline plan to be the canonical
named member of the exact offline-control seal directory. A valid seal cannot
be paired with an unrelated look-alike JSON/plan file.

## Canonical path

Registration and planning use the standard Sable interface:

```text
build/sable.sh
  -> artifact registry
  -> build/devices/titan2.sh
  -> prepare-c3a-v010014-standard-flash-plan.sh
```

C3A is admitted to the Titan artifact gate only as a diagnostic control.

The adapter intentionally does **not** admit the C3A registry identity in
`sable_device_flash_policy()`.

Therefore:

```text
C3A_ARTIFACT_REGISTRATION_SUPPORTED=YES
C3A_STANDARD_FLASH_PLAN_SUPPORTED=YES

C3A_STANDARD_FLASH_EXECUTION_SUPPORTED=NO_PENDING_PLAN_SCOPE
C3A_FLASH_AUTHORIZED=NO
C3A_FACTORY_RESET_AUTHORIZED=NO
```

## Plan contents

A clean plan records:

```text
TARGET_PARTITION=system_a
EXPECTED_ACTIVE_SLOT=a
EXPECTED_FASTBOOT_PRODUCT=Titan_2
EXPECTED_SYSTEM_CURRENT_BYTES=2994388992
SYSTEM_LOGICAL_BYTES=3146977280
EXPECTED_ACTIVE_COW_COUNT=0
FLASH_ENTRY_MODE=userspace-fastbootd
FASTBOOT_IMPLICIT_RESIZE=YES
MANUAL_PRE_RESIZE_REQUIRED=NO
COW_DELETION_ALLOWED=NO
SLOT_CHANGE_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO
BOOT_CHAIN_FLASH_ALLOWED=NO
WHOLE_SUPER_FLASH_ALLOWED=NO
USERDATA_ERASE_ALLOWED=NO
FACTORY_RESET_ALLOWED=NO
AUTOMATIC_FLASH_RETRY_ALLOWED=NO
```

The plan is sealed with `SHA256SUMS.txt`. That seal—not merely the system
image SHA—is the future one-use execution-scope authority.

## Operator sequence

The operator should run the static contract, register the seven artifacts,
verify the registry entry, and generate the plan.

No device command is part of this stage. The phone may remain in fastbootd.

After the plan is generated, report:

```text
C3A_V010014_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE
C3A_V010014_STANDARD_FLASH_PLAN_EVIDENCE_SEAL_SHA256=<sha256>
C3A_V010014_STANDARD_FLASH_PLAN_EXECUTION_SUPPORTED=NO_PENDING_SCOPE_BINDING
```

Do not run `build/sable.sh ... flash` for this C3A identity yet.

## Safety boundary

```text
DEVICE_CONTACT_AUTHORIZED=NO_FOR_THIS_STAGE
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
COW_CLEANUP_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
SLOT_MUTATION_AUTHORIZED=NO
WRITE_CAPABLE_SCRIPT_CREATED=NO

NEXT_AFTER_PLAN_PASS=
  bind exact plan seal into canonical Titan execution scope
  then separately authorize one system_a write
```

Factory reset remains a distinct later destructive decision after the system
write and first boot observation.
