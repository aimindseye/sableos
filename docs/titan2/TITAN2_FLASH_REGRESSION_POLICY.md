# Titan 2 flash regression policy

Status: **ACTIVE FAIL-CLOSED DEPLOYMENT MEMORY**

Date: 2026-10-05

## Purpose

Titan 2 flashing is not a generic Android/Pixel operation. This policy turns
the project's successful and failed physical deployment history into executable
regression constraints so future builds are not wasted by rediscovering device
quirks during a write.

The canonical operator path remains:

```text
build/sable.sh
 -> build/deploy/flash.sh
 -> build/devices/titan2.sh
 -> Titan flash-regression preflight
 -> exact sealed scope policy
 -> Titan adapter preflight
 -> bounded Titan adapter write
 -> bounded post-write observation
```

No separate ad-hoc Titan write script is authorized by this document.

## Source authority reviewed

Exact repository heads reviewed for this policy:

```text
SABLEOS_REVIEWED_MAIN=177ef4fb76d661725165c5224f6a8495b2b420ec
UNIHERTZ_TITAN2_RESEARCH_REVIEWED_MAIN=7e21667bc37b3fc80ef39d0b9e1c9a71a28cbec5
TITAN2_TEMP_REVIEWED_MAIN=7570470d1c5a27ef94ed4751f5ccb91af41761fe
```

Repository roles:

```text
aimindseye/unihertz-titan2=DEVICE_BOOT_FLASH_RESTORE_RESEARCH_AUTHORITY
aimindseye/titan2-temp=PRODUCT_SOURCE_HANDOFF_REFERENCE
aimindseye/sableos=CANONICAL_BUILD_DEPLOYMENT_AND_EVIDENCE_AUTHORITY
```

The current `titan2-temp` main was explicitly searched for fastboot,
fastbootd, `fastboot boot`, Virtual A/B, `system_a`, recovery, flash and
restore material. It contains the current P1-P5 product-source handoffs, not the
device flash research. Flash-mode facts therefore come from
`aimindseye/unihertz-titan2` plus SableOS physical evidence.

Historical SableOS PRs reviewed:

```text
PR142=Titan 2 N0/N1 flash-plan ledger; no Pixel assumptions
PR143=central Titan flash guards
PR183=Phase 14 final preflight/restore acceptance gate
PR262=standardized N1D artifact registration + no-write flash plan
PR264=qualified exact canonical N1D active-system execution
PR309=kept no-write plan contract aligned with scoped execution policy
```

Successful physical reference:
`docs/titan2/N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md`.

Failed/recovery references:
`aimindseye/unihertz-titan2/docs/SABLEOS_N1C_FIRST_WRITE_POSTMORTEM_20260930.md`
and the stock-system-only recovery checkpoint in `CURRENT_STATUS.md`.

## Hard Titan device model

These are regression inputs, not reminders for the operator:

```text
DEVICE=titan2
BOARD_PRODUCT_BOOTLOADER=g71v78c2k_dfl_tee
FASTBOOTD_PRODUCT=Titan_2
ANDROID_MAJOR=16
DYNAMIC_PARTITIONS=YES
VIRTUAL_AB=YES
SUPER_BYTES=9663676416
FASTBOOTD_SUPPORTED=YES
FASTBOOT_BOOT_SUPPORTED=NO
DSU_AVAILABLE=NO_ON_TESTED_STOCK
STANDALONE_RECOVERY_PARTITION_OBSERVED=NO
RECOVERY_LOCATION=vendor_boot_recovery_vendor_ramdisk
AVB_TOPOLOGY=CHAINED_BOOT_VBMETA_SYSTEM_VBMETA_VENDOR
```

HOST_OKAY_IS_NOT_DEVICE_STATE_PROOF=YES
SYSTEM_B_MAY_BE_NOT_MATERIALIZED_WHILE_SLOT_A_ACTIVE=YES

Bootloader fastboot and userspace fastbootd are different execution modes.
Logical-partition topology is taken from fastbootd / LP evidence. The screen UI
is not proof of mode: `getvar is-userspace` must report `yes`.

Virtual A/B does not guarantee a materialized inactive `system_b`.
A missing/zero-sized inactive logical partition is not a safe alternate target.

## Proven successful Sable deployment behavior

N1F physically passed with this bounded model:

```text
TARGET_PARTITION=system_a
ENTRY_MODE=userspace-fastbootd
EXPLICIT_SERIAL=YES
CURRENT_SLOT=a
UNLOCKED=yes
SNAPSHOT_UPDATE_STATUS=none
ACTIVE_COW_COUNT=0
ARTIFACT_HASH_VERIFIED=YES
PREWRITE_SYSTEM_SIZE_VERIFIED=YES
FLASH_COUNT=1
AUTOMATIC_FLASH_RETRY=NO
SLOT_CHANGE=NO
AVB_MUTATION=NO
BOOT_CHAIN_MUTATION=NO
WHOLE_SUPER_WRITE=NO
FACTORY_RESET=NO
POSTWRITE_SIZE_VERIFIED=YES
POSTWRITE_SLOT_VERIFIED=YES
POSTWRITE_FASTBOOTD_VERIFIED=YES
POSTWRITE_SNAPSHOT_VERIFIED=YES
POST_WRITE_REBOOT_COUNT=1
FIRST_BOOT_ANDROID=PASS
```

A later deployment may supersede one of these values only with explicit new
physical evidence and a simultaneous ledger/gate update. It must never drift
silently.

## Negative evidence that must remain executable knowledge

### N1C whole-super failure

The N1C hybrid `super` write was accepted by fastbootd but failed to return to
Android. Recovery required the matched stock super plus matching
boot/init_boot/vendor_boot/dtbo/vbmeta/vbmeta_system/vbmeta_vendor set and then
a separately performed recovery factory reset.

Therefore:

```text
WHOLE_SUPER_PRIMARY_SABLE_PATH=NO
RETRY_SAME_FAILED_ARTIFACT=NO
AUTOMATIC_FIX_FORWARD_FLASH=NO
VERIFIED_MATCHED_STOCK_RESTORE_SET_REQUIRED=YES
```

### Stock system-only recovery failure

Flashing only retained stock `system_a` over a GSI composition produced an
invalid mixed-partition test and booted recovery. Recovery ADB was not a
reliable route back into usable fastboot for the planned restore.

Therefore:

```text
STOCK_SYSTEM_A_ONLY_RESTORE_ALLOWED=NO
MATCHED_STOCK_RESTORE_PROCEDURE_REQUIRED=YES
RECOVERY_ADB_ASSUMED_TO_REENTER_FASTBOOT=NO
```

### N1I-C2 recovery-entry handling

A qualified N1I-C2 candidate may observe and seal a current recovery state, but
recovery never becomes an implicit transition authority.

```text
N1I_C2_RECOVERY_ENTRY_READ_ONLY_ALLOWED=YES
N1I_C2_RECOVERY_AUTOMATIC_REBOOT_ALLOWED=NO
N1I_C2_RECOVERY_AUTOMATIC_FASTBOOTD_TRANSITION_ALLOWED=NO
N1I_C2_RECOVERY_FLASH_WRITE_ALLOWED=NO
N1I_C2_RECOVERY_PASS_ADVANCES_TO=OWNER_REVIEW_OF_RECOVERY_TO_FASTBOOTD
```

The recovery-entry qualifier must bind the exact previously sealed Titan
transport and require its ADB transport state to be `recovery`. Titan 2
recovery is known to enumerate through ADB while rejecting shell/property
queries, so recovery qualification must not depend on `adb shell getprop`.
Live product, slot, verified-boot, snapshot/COW and LP geometry are deferred to
the fastbootd prewrite gate. The recovery gate must reject simultaneous
ADB/fastboot visibility, preserve the post-build C2 image authority, and stop
before any mode transition or write.

### N1I-C2 exact mode-aware write exception

After explicit owner authorization, N1I-C2 has one source/SHA-scoped exact
executor:

```text
N1I_C2_EXACT_WRITE_EXECUTOR=build/titan2/flash-n1i-c2-cellular-mvp.sh
N1I_C2_BUILD_SOURCE=27d671b004f5ae7394f147018fc4fffdf4d78498
N1I_C2_SYSTEM_SHA256=630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50
N1I_C2_SYSTEM_BYTES=3218440192
N1I_C2_TARGET=system_a
N1I_C2_EXPECTED_SLOT=a
N1I_C2_AUTOMATIC_RETRY=NO
```

This does not enable generic Titan flashing. The executor may begin from normal
Android ADB, bootloader fastboot, or already-active userspace fastbootd. Android
and bootloader entries use the shared Titan mode helper to reach verified
fastbootd; existing fastbootd is reused with zero transitions. Recovery remains
blocked. Before the write, the executor re-reads live LP/snapshot/slot/unlocked
state, enforces the reviewed super/group headroom, computes the exact image SHA
once at the immediate prewrite boundary, and seals a one-attempt journal.
Exactly one `fastboot flash system_a` call exists. Factory reset, userdata
erase, slot change, AVB/boot-chain writes, COW deletion and manual LP mutation
remain forbidden inside the executor.

## COW, snapshot and LP rules

COW logical partitions may exist even when
`snapshot-update-status=none`. They are not blindly deleted because their
presence alone is not proof of stale OTA state.

Current scoped execution that requires zero active COWs must fail preflight if
they are present. Any future COW cleanup/resize sequence requires its own
reviewed evidence and explicit scope.

The artifact is bound by both SHA-256 and logical byte size. Super capacity,
active-group capacity and current materialized LP state must match the reviewed
plan immediately before mutation.

## AVB, boot chain, slot and userdata rules

The default Sable system-only scope does not mutate:

```text
boot
init_boot
vendor_boot
dtbo
vbmeta
vbmeta_system
vbmeta_vendor
vendor
vendor_dlkm
odm_dlkm
modem/firmware
active slot
```

A userdata wipe/factory reset is never hidden inside a normal flash operation.
If one is required, it is a separate destructive decision with explicit owner
authorization.

Relocking is outside the Sable bring-up path and must not occur unless a fully
stock, internally consistent firmware state has first been restored and
verified.

## Device-mode discovery and transition

The canonical Titan flash path must not require the operator to remember which
USB transport mode the phone is currently in.

Immediately before live prewrite validation, the adapter discovers the bound
device by the previously sealed ADB and fastboot serial hashes and classifies
the current transport state.

Supported starting states:

```text
ANDROID_ADB
  -> adb reboot bootloader
  -> verify bound bootloader-fastboot serial
  -> verify product=g71v78c2k_dfl_tee and is-userspace=no
  -> fastboot reboot fastboot
  -> verify product=Titan_2 and is-userspace=yes
  -> FASTBOOTD

BOOTLOADER_FASTBOOT
  -> verify product=g71v78c2k_dfl_tee and is-userspace=no
  -> fastboot reboot fastboot
  -> verify product=Titan_2 and is-userspace=yes
  -> FASTBOOTD

FASTBOOTD
  -> verify product=Titan_2 and is-userspace=yes
  -> no reboot
```

Recovery is intentionally different:

```text
RECOVERY_ADB
  -> BLOCK
  -> no automatic adb reboot bootloader
```

Prior Titan recovery evidence showed that recovery ADB was not a reliable
automatic path back to a usable flashing state. A recovery observation therefore
requires explicit owner review rather than a scripted fix-forward transition.

Unknown, unavailable, multiply-bound, wrong-product, or ambiguous simultaneous
ADB/fastboot states also block before any write.

Mode verification never trusts the screen UI. Userspace fastbootd is proven by
`getvar is-userspace=yes`.

### Bounded transition performance

The mode helper has no unbounded wait:

```text
PER_COMMAND_TIMEOUT_SECONDS=8
ANDROID_TO_BOOTLOADER_WAIT_SECONDS=45
BOOTLOADER_TO_FASTBOOTD_WAIT_SECONDS=60
POLL_INTERVAL_SECONDS=1
```

Each individual transport command runs under a host timeout. Transition waits
poll only the required transport rather than repeatedly running full `getvar all`.
The expensive full fastboot state inventory is taken once after fastbootd has
been reached and bound.

The flash-regression contract runs `bash -n` over the canonical deployment
script, Titan adapter, mode helper, mode self-test and central guard. It also
executes a fake-device offline state-machine test under a 15-second hard timeout.
A syntax failure, state-machine regression or hang closes the flash policy
before device contact.

## Execution stop rules

After the single bounded write:

1. verify post-write logical size;
2. verify slot did not change;
3. verify the device is still in userspace fastbootd;
4. verify snapshot status is still none;
5. send exactly one reboot;
6. observe.

If fastboot returns, recovery is observed, or no terminal Android state is
reached before timeout:

```text
AUTOMATIC_REFLASH=NO
AUTOMATIC_FACTORY_RESET=NO
AUTOMATIC_SLOT_CHANGE=NO
AUTOMATIC_AVB_OR_BOOT_WRITE=NO
FURTHER_MUTATION=BLOCKED_OWNER_REVIEW_REQUIRED
```

A visible Android boot with incomplete ADB evidence is reported as observation;
it is not a reason to immediately reset or reflash.

## Script-quality lessons from N1C

New Titan device/recovery helpers must follow:

```text
NO_AD_HOC_DEVICE_SCRIPT_WITHOUT_REVIEW_PACKET=YES
NO_SET_EUO_PIPEFAIL_IN_DEVICE_OR_RECOVERY_SCRIPTS=YES
NO_STDOUT_LOGGING_FROM_FUNCTIONS_USED_IN_COMMAND_SUBSTITUTION=YES
NO_HARDCODED_HOST_TOOL_WITHOUT_RESOLVER_FALLBACK=YES
NO_WRITE_CAPABLE_SCRIPT_WITHOUT_VERIFIED_RESTORE_PATH=YES
NO_AUTOMATIC_FLASH_RETRY=YES
```

Historical sealed scripts are evidence and are not mass-rewritten solely for
style. New active Titan-specific helpers and future replacements must comply.

## Titan 2 Elite boundary

Titan 2 Elite requires independent device research and physical evidence.

```text
TITAN2_ELITE_INHERITS_TITAN2_FLASH_PASS=NO
TITAN2_ELITE_FLASH_AUTHORIZED_BY_TITAN2_EVIDENCE=NO
```

## Regression execution

The machine-readable ledger is:

```text
build/TITAN2_FLASH_REGRESSIONS.tsv
```

The executable contract is:

```text
build/gates/titan2-flash-regression-contract.py
```

The Titan adapter runs this contract before generating a Titan flash plan and
again before any scoped flash policy can open. The shared static pipeline also
runs it.

A regression invariant may be changed only when newer evidence explicitly
supersedes it. The evidence, ledger and executable assertion must change
together.
