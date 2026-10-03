# Titan 2 C3A on V01.00.14 runtime control

Status: **replacement compatibility control / offline preparation PASS / fastboot-entry recovery preflight next**

Updated: **2026-10-03 ET**

## Why this replaces the exact N1B control

The exact historical N1B system image and target-files archive are no longer
retained. Reconstruction was then tested through three independent paths:

```text
retained local artifacts                     NOT_FOUND
surviving worktrees / Repo object stores     NOT_FOUND
provider-native source-object existence      BOTH_CRITICAL_OBJECTS_ABSENT
```

Sealed provider evidence:

```text
EVIDENCE_DIR=
/srv/sable-build/evidence/titan2/n1b-provider-object-existence/20261003T191916Z

EVIDENCE_SEAL_SHA256=
fce7ed70c41ef99ccfa0ff4ec9e8c5a39a738cef6cdb266fc1ba3496c0203730

N1B_TREBLE_EXACT_OBJECT_EXISTENCE=
ABSENT_FROM_CHECKED_AUTHENTIC_GITHUB_LINEAGE

N1B_VNDK29_EXACT_OBJECT_EXISTENCE=
ABSENT_CONFIRMED

N1B_PROVIDER_OBJECT_EXISTENCE=
BLOCKED_BOTH_EXACT_OBJECTS_NOT_ADDRESSABLE
```

Therefore:

```text
N1B_EXACT_RECONSTRUCTION=RETIRED
N1B_V010014_PHYSICAL_CONTROL=RETIRED_UNEXECUTABLE
N1E=RETIRED_EXACT_N1B_PREREQUISITE_UNAVAILABLE
```

No branch tip, nearby Restless build, C2 prebuilt or C3A artifact is relabeled
as N1B.

## Replacement control: C3A

C3A is the strongest available source-built compatibility control already
sealed by Sable engineering.

It is:

```text
CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION
MANAGED_PROJECT_COUNT=991
RESTLESS_PUBLIC_CONTROL_PATCH_COUNT=369
VARIANT=treble_arm64_bvN-bp4a-user
SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
SYSTEM_BYTES=3146977280
```

C3A is not N1B and is not a Sable release baseline. It excludes the private
Restless vendor repository and mutable Pixel GSans branding input. It does,
however, reproduce the public functional Restless/TrebleDroid source/build
topology and full ordered 369-patch control stack on the canonical build host.

That makes it suitable for the next narrower question:

> Can the current Titan 2 V01.00.14 vendor/device state boot a current
> source-built Android 16 Restless/TrebleDroid compatibility control?

A C3A boot would materially strengthen the hypothesis that the N1D reboot loop
is caused by the broad removal of the compatibility substrate, while still not
proving that any single patch or `COUNT=0` alone is causal.

A C3A failure does not prove that V01.00.14 is the sole cause. It triggers review
of the independent published C2 RestlessOS prebuilt as the second control.

## Control ladder

```text
CONTROL_1=C3A_SOURCE_BUILT_PUBLIC_FUNCTIONAL_REPRODUCTION

if C3A boots on V01.00.14:
    compatibility-control-on-current-vendor = PASS
    reserve N1F as C3A-derived minimal Sable-app isolation
    do not use C2 unless an independent cross-check becomes useful

if C3A is unavailable or result is inconclusive/fails:
    review CONTROL_2=C2_PINNED_PUBLISHED_RESTLESSOS_PREBUILT
    keep C2 explicitly diagnostic-only
```

C2 is not pre-authorized by this document.

## N1F reservation

N1E is not redefined.

If C3A boots, the next isolation phase is reserved as:

```text
N1F =
  exact qualified C3A compatibility baseline
  + exact C3A generated product/lunch identity
  + only the five already-qualified C3B Sable application modules
  + no wrapper identity initially
```

The exact N1F construction contract will be written only after C3A physically
boots and after the C3A source/provenance state required for a reproducible
derivative is captured.

Until then:

```text
N1F_BUILD_AUTHORIZED=NO
N1F_FLASH_AUTHORIZED=NO
```

## Offline preparation

The preparation package first binds the provider evidence that retires exact
N1B reconstruction, then the sealed C3A build evidence, then the sealed
V01.00.14 E5A/E5B device evidence.

Expected C3A artifact:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3a-td/target/product/tdgsi_arm64_ab/system.img
```

If that path moved, the preparation script searches local Sable workspaces and
artifact storage but accepts only the exact C3A byte size and SHA-256.

Run:

```bash
PROVIDER=/srv/sable-build/evidence/titan2/n1b-provider-object-existence/20261003T191916Z
E5A=/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z

bash build/gates/c3a-v010014-control-contract.sh

bash build/titan2/prepare-c3a-v010014-runtime-control.sh \
  --provider-evidence-dir "$PROVIDER" \
  --e5a-json "$E5A/e5a-readonly-device-state.json" \
  --e5b-json "$E5A/e5b-authorization-package.json"
```

## Offline preparation result

The offline preparation completed successfully and is sealed:

```text
EVIDENCE_DIR=/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan
EVIDENCE_SEAL_SHA256=e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57
C3A_V010014_CONTROL_ARTIFACT=PASS_EXACT_SEALED_C3A
C3A_V010014_CONTROL_CURRENT_FIRMWARE_EVIDENCE=PASS_SEALED_V010014
C3A_V010014_CONTROL_PLAN=PASS_PREPARED_NO_WRITE
```

The phone is currently bootlooping and already in fastboot, so the Android/ADB
entry path is not the current operator path. The next authorized step is the
fastboot-entry recovery preflight documented at
`docs/titan2/N1D_C3A_V010014_FASTBOOT_ENTRY_PREFLIGHT.md`. It may collect
read-only fastboot evidence and transition bootloader fastboot to userspace
fastbootd if required, but it may not flash, clean COWs,
resize logical partitions or factory-reset the device.

## Physical scope recorded but not authorized

The no-write plan records the same conservative active-system model already
proven by the Titan 2 deployment work:

```text
ENTRY_MODE=userspace fastbootd
TARGET=system_a
KEEP_CURRENT_SLOT=YES
FRESH_DEVICE_BINDING_REQUIRED=YES
FRESH_SNAPSHOT_NONE_REQUIRED=YES
FRESH_ACTIVE_COW_COUNT_ZERO_REQUIRED=YES
FRESH_CAPACITY_CHECK_REQUIRED=YES
MANUAL_PRE_RESIZE=NO
COW_DELETION=NO
AVB_MUTATION=NO
BOOT_CHAIN_FLASH=NO
WHOLE_SUPER_FLASH=NO
AUTOMATIC_RETRY=NO
FACTORY_RESET_DURING_SYSTEM_WRITE=NO
```

A future physical execution deliverable must still perform a fresh live
preflight. Factory reset remains a separate explicit destructive authorization.

## Safety boundary

```text
C3A_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO
C3A_V010014_FLASH_AUTHORIZED=NO
C3A_V010014_FACTORY_RESET_AUTHORIZED=NO
C2_FALLBACK_FLASH_AUTHORIZED=NO
N1F_BUILD_AUTHORIZED=NO
N1F_FLASH_AUTHORIZED=NO
N1D_REFLASH_AUTHORIZED=NO
N1E_BUILD_AUTHORIZED=NO_RETIRED
```
