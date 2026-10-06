# Titan 2 N1I-D0 IMG0 exact system_a flash

Status: **SEALED / HOST-QUALIFIED / EXACT SINGLE-WRITE EXECUTOR**

Date: 2026-10-06

## Candidate authority

```text
BUILD_SOURCE_COMMIT=defc7f9c522336732564eb11644331691dcd92a2
SYSTEM_SHA256=c3cff8cc9f0be512a721fae4c0b3c148688ef95b04c1df3981afb406bc928bd0
SYSTEM_BYTES=3200548864
BASELINE_N1F_SHA256=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a
BASELINE_N1F_BYTES=3200540672
N1F_DELTA_BYTES=8192
TARGET_PARTITION=system_a
EXPECTED_SLOT=a
CELLULAR_DELTA=C1_C2_NOT_INCLUDED
ARTIFACT=/srv/sable-build/artifacts/titan2/n1i-d0-img0/20261006T205157Z
```

The candidate passed the sealed host qualification:
`N1I_D0_IMG0_SEALED_QUALIFICATION=PASS`. The image is the boot-qualified
N1F five-app composition plus the inert D0 provenance marker. It intentionally
does not include the N1I-C1/C2 cellular runtime delta.

## Execution policy

```text
GENERIC_TITAN_FLASH=BLOCKED
EXACT_D0_IMG0_EXECUTOR=ALLOWED_REVIEWED_SCOPE_ONLY
INITIAL_MODE_ALLOWED=ANDROID_ADB|BOOTLOADER_FASTBOOT|FASTBOOTD
RECOVERY_WRITE_ENTRY=BLOCKED
FLASH_TARGET=system_a
FLASH_ATTEMPT_LIMIT=1
AUTOMATIC_RETRY=NO
FACTORY_RESET_BY_EXECUTOR=NO
USERDATA_ERASE=NO
SLOT_CHANGE=NO
AVB_MUTATION=NO
BOOT_CHAIN_MUTATION=NO
COW_DELETION=NO
MANUAL_LP_MUTATION=NO
```

The executor never assumes the current device mode. It binds the known Titan 2
transport identity, classifies Android ADB, bootloader fastboot, fastbootd, or
recovery, and only transitions Android/bootloader to verified userspace
fastbootd. Existing fastbootd is reused without a transition. Recovery and
ambiguous states fail closed.

Before the write, the executor verifies the sealed artifact metadata, exact
five-app manifest, D0 marker, source/SHA/size authority, minimum fastboot
version, Titan product/slot/unlocked state, snapshot state, logical-partition
model, zero active COWs, super capacity, projected headroom, and the reviewed
system group ceiling. The full multi-GB image SHA-256 is computed exactly once
at the immediate prewrite boundary.

After the attempt journal is armed, no automatic retry is permitted. After a
successful write, fastbootd state is requalified before exactly one reboot.
First boot is observation-only; recovery, identity mismatch, fastboot return,
or timeout is an owner-review stop and never triggers a second flash.

## Static qualification

Run before any device contact:

```bash
bash build/gates/n1i-d0-img0-flash-executor-contract.sh
python3 build/gates/titan2-flash-regression-contract.py
bash build/gates/titan2-central-flash-guard-contract.sh
```

All must pass, including `TF-026`.

## Exact flash

```bash
bash build/titan2/flash-n1i-d0-img0.sh flash \
  --authorize-device-contact YES_D0_IMG0_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE \
  --authorize-flash YES_D0_IMG0_SYSTEM_A_ONCE \
  --artifact-dir /srv/sable-build/artifacts/titan2/n1i-d0-img0/20261006T205157Z
```

Expected prewrite markers include:

```text
N1I_D0_IMG0_FLASH_HOST_AUTHORITY=PASS
N1I_D0_IMG0_FLASH_REGRESSION_PREFLIGHT=PASS
N1I_D0_IMG0_FLASH_DEVICE_BINDING=PASS
N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=PASS_NO_PRIOR_ATTEMPT
N1I_D0_IMG0_FASTBOOT_STATE=PASS phase=pre
N1I_D0_IMG0_PREFLASH_ACTIVE_COW_COUNT=0
N1I_D0_IMG0_PREFLASH=PASS
N1I_D0_IMG0_PREWRITE_ARTIFACT_HASH=PASS
N1I_D0_IMG0_FLASH_ATTEMPT_ARMED=YES
```

After `N1I_D0_IMG0_FLASH_ATTEMPT_ARMED=YES`, any failure is an owner-review
stop. Do not manually rerun the executor or issue another flash.

A successful write continues with:

```text
N1I_D0_IMG0_FASTBOOT_FLASH_SYSTEM_A_RC=0
N1I_D0_IMG0_FLASH_COMMAND_SUCCEEDED=YES
N1I_D0_IMG0_FASTBOOT_STATE=PASS phase=post
N1I_D0_IMG0_FLASH_WRITE_COMPLETED=YES
N1I_D0_IMG0_FLASH_ATTEMPT_COUNT=1
N1I_D0_IMG0_FLASH_WRITE_PROOF=PASS
N1I_D0_IMG0_POSTFLASH_REBOOT=PASS_SENT_ONCE
```

The final successful runtime marker is
`N1I_D0_IMG0_GOVERNED_FLASH=PASS_SYSTEM_A_ONCE_ANDROID_BOOT_COMPLETED`.
