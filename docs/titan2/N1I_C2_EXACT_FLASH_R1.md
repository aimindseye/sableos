# Titan 2 N1I-C2 exact system_a flash

Status: **EXACT CANDIDATE / SINGLE-WRITE EXECUTION**

Date: 2026-10-06

## Candidate authority

```text
BUILD_SOURCE_COMMIT=27d671b004f5ae7394f147018fc4fffdf4d78498
SYSTEM_SHA256=630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50
SYSTEM_BYTES=3218440192
TARGET_PARTITION=system_a
EXPECTED_SLOT=a
ADB_DEVICE_BINDING_SHA256=bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a
FASTBOOT_DEVICE_BINDING_SHA256=bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a
```

The candidate has already passed the C2 build and post-build linkage gates.
The previously installed system subsequently showed a RestlessOS-logo bootloop
during an attempted reset. That operator observation is recorded as prior-image
runtime evidence; it does not alter the sealed C2 candidate authority.

The device is currently available in userspace fastbootd. The exact executor
therefore accepts `FASTBOOTD` directly and requires zero mode-transition
commands before prewrite qualification.

## Execution policy

```text
GENERIC_TITAN_FLASH=BLOCKED
EXACT_C2_EXECUTOR=ALLOWED_REVIEWED_SCOPE_ONLY
INITIAL_MODE_ALLOWED=ANDROID_ADB|BOOTLOADER_FASTBOOT|FASTBOOTD
RECOVERY_WRITE_ENTRY=BLOCKED
FASTBOOTD_DIRECT_REUSE=YES_ZERO_TRANSITION
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

Before the write, the executor verifies the exact sealed artifact/post-build
authority, exact Titan transport binding, fastboot version, product, slot,
userspace-fastbootd, unlocked state, snapshot status, zero active COWs, logical
partition model, super capacity, projected headroom, and reviewed group ceiling.
It computes the full image SHA-256 exactly once at the immediate prewrite
boundary.

The duplicate-write guard is evidence-journal based. A live `system_a` that
happens to have the same logical byte size as the candidate is not assumed to
contain the candidate.

## Static qualification

Run this before device mutation:

```bash
bash build/gates/n1i-c2-flash-executor-contract.sh
python3 build/gates/titan2-flash-regression-contract.py
bash build/gates/titan2-central-flash-guard-contract.sh
```

All three commands must pass.

## Exact flash

With the Titan connected in the currently observed fastbootd state:

```bash
bash build/titan2/flash-n1i-c2-cellular-mvp.sh flash \
  --authorize-device-contact YES_C2_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE \
  --authorize-flash YES_C2_SYSTEM_A_ONCE \
  --artifact-dir /srv/sable-build/artifacts/titan2/n1i-c2-cellular-mvp/20261006T112224Z \
  --postbuild-evidence /srv/sable-build/evidence/titan2/n1i-c2-postbuild-linkage/20261006T142300Z-27d671b004f5
```

Expected direct-entry markers before the write include:

```text
N1I_C2_FLASH_ENTRY_MODE=PASS_FASTBOOTD_DIRECT
N1I_C2_FLASH_INITIAL_MODE=FASTBOOTD
N1I_C2_FLASH_DEVICE_BINDING=PASS
N1I_C2_FLASH_DUPLICATE_WRITE_GUARD=PASS_NO_PRIOR_ATTEMPT
N1I_C2_FLASH_MODE_TRANSITION=NONE_ALREADY_FASTBOOTD
N1I_C2_FASTBOOT_STATE=PASS phase=pre
N1I_C2_PREFLASH_ACTIVE_COW_COUNT=0
N1I_C2_PREFLASH=PASS
N1I_C2_PREWRITE_ARTIFACT_HASH=PASS
N1I_C2_FLASH_ATTEMPT_ARMED=YES
```

After `N1I_C2_FLASH_ATTEMPT_ARMED=YES`, any failure is an owner-review stop.
Do not manually rerun the executor or issue another flash.

A successful write must contain exactly one flash call and should continue with:

```text
N1I_C2_FASTBOOT_FLASH_SYSTEM_A_RC=0
N1I_C2_FLASH_COMMAND_SUCCEEDED=YES
N1I_C2_FASTBOOT_STATE=PASS phase=post
N1I_C2_FLASH_WRITE_COMPLETED=YES
N1I_C2_FLASH_ATTEMPT_COUNT=1
N1I_C2_FLASH_WRITE_PROOF=PASS
N1I_C2_POSTFLASH_REBOOT=PASS_SENT_ONCE
```

First boot is observation-only. If Android does not complete, recovery appears,
or the postboot observation times out, the executor records the state and
explicitly forbids an automatic second flash.
