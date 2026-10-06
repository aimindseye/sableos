# Titan 2 N1I-C2 recovery-entry qualification

Status: **READ-ONLY PHYSICAL ENTRY GATE — NO MODE TRANSITION / NO FLASH**

Date: 2026-10-06

## Purpose

The N1I-C2 Cellular MVP candidate has completed build and post-build linkage
qualification. The physical Titan 2 is currently in recovery. This gate records
that state without assuming Android, bootloader fastboot, or fastbootd and
without attempting to fix forward from recovery.

The canonical rule remains:

```text
RECOVERY_ADB
  -> observe and seal
  -> owner review
  -> separately authorized recovery-to-fastbootd procedure
  -> fresh fastbootd prewrite qualification
  -> only then may a bounded system_a write be considered
```

Recovery is **not** an automatically transitional state.

## Candidate authority

```text
BUILD_SOURCE_COMMIT=27d671b004f5ae7394f147018fc4fffdf4d78498
SYSTEM_SHA256=630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50
SYSTEM_BYTES=3218440192
TARGET_PARTITION=system_a
EXPECTED_SLOT=a
ANDROID_PRODUCT=Titan_2
BOOTLOADER_PRODUCT=g71v78c2k_dfl_tee
FASTBOOTD_PRODUCT=Titan_2
```

The successful post-build evidence remains the authority for the candidate's
41-row implementation receipt, 28+5 native realization, IMS identity/signature,
Java/APEX parity, and exact AgentPremain full classification.

## Read-only device contact

Run only after the static contract passes:

```bash
bash build/titan2/qualify-n1i-c2-recovery-entry.sh \
  --bind-sealed-recovery \
  --source-commit 27d671b004f5ae7394f147018fc4fffdf4d78498 \
  --artifact-dir /srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp/20261006T112224Z \
  --postbuild-evidence /srv/sable-build/evidence/titan2/n1i-c2-postbuild-linkage/20261006T142300Z-27d671b004f5 \
  --expected-system-sha 630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50 \
  --expected-system-bytes 3218440192
```

The qualifier uses bounded read-only `adb devices` / `fastboot devices`
discovery only. Titan 2 recovery is a known ADB-shell-unreadable state, so the
sealed transport state `recovery` is authoritative and no recovery
`adb shell getprop` probe is attempted. Product, slot, verified-boot state,
and geometry are deferred to the fastbootd prewrite gate. `--bind-sealed-recovery` does not select
the first connected device: it searches for the one ADB transport whose serial
hash equals the previously sealed Titan binding and fails if that exact binding
is absent or ambiguous. The raw serial is not printed in normal evidence.
An explicit `--serial` remains supported for controlled debugging, but the two
binding modes are mutually exclusive.

Expected successful terminal state:

```text
N1I_C2_RECOVERY_POSTBUILD_AUTHORITY=PASS
N1I_C2_RECOVERY_DEVICE_BINDING=PASS
N1I_C2_RECOVERY_TRANSPORT=PASS state=recovery
N1I_C2_RECOVERY_ADB_PROPERTIES=NOT_REQUIRED_KNOWN_UNREADABLE
N1I_C2_RECOVERY_PRODUCT=DEFERRED_TO_FASTBOOTD_PREWRITE
N1I_C2_RECOVERY_SLOT=DEFERRED_TO_FASTBOOTD_PREWRITE
N1I_C2_RECOVERY_SIMULTANEOUS_FASTBOOT=PASS_ABSENT
N1I_C2_RECOVERY_MODE_TRANSITION=BLOCKED_BY_POLICY
N1I_C2_RECOVERY_FLASH=BLOCKED_BY_POLICY
N1I_C2_RECOVERY_ENTRY_EVIDENCE_SEAL=PASS_EXCLUDES_QUALIFY_LOG
N1I_C2_RECOVERY_ENTRY_QUALIFICATION=PASS_RECOVERY_CONFIRMED_NO_TRANSITION
N1I_C2_READY_FOR_RECOVERY_TO_FASTBOOTD_REVIEW=YES
N1I_C2_READY_FOR_FLASH_WRITE=NO
N1I_C2_REBOOT=NONE
N1I_C2_FLASH=NONE
```

## Fail-closed conditions

The gate fails if any of the following occurs:

- the sealed Titan binding cannot be found exactly once, or an explicitly
  requested serial does not match that sealed binding;
- the device is absent, ambiguous, unauthorized, or simultaneously visible
  through ADB and fastboot;
- the bound ADB transport state is anything other than `recovery`;
- recovery unexpectedly becomes dependent on ADB shell/property readability;
- the post-build evidence no longer binds the exact C2 build source, image
  authority, 41-row receipt, 28+5 native split, APEX parity, and accepted runtime
  linkage classification;
- the system image byte size differs from the sealed candidate;
- the qualifier or shared mode helper gains an unreviewed mutating transport
  command.

A full system-image hash is deliberately **not** recomputed in this recovery
observation gate. The post-build authority has already sealed the image, and the
fresh fastbootd prewrite gate must re-hash the exact artifact immediately before
any write authorization.

## Authorization boundary

```text
BUILD_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_RECOVERY_STATE_ONLY
MODE_TRANSITION_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
```

A PASS from this gate authorizes only review of the recovery-to-fastbootd
transition. It does not authorize the transition itself and does not authorize a
flash.
