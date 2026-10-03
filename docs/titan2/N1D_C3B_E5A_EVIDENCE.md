# N1D C3B E5A read-only device-state evidence seal

Status: **PASS / SEALED**  
Evidence timestamp: **2026-10-03T05:34:41Z**

E5A completed from exact canonical operator head:

```text
OPERATOR_HEAD=602fca81ffc43e8731342b96b6945ab9ef9642b6
WORKTREE=PASS_CLEAN
DIFF_CHECK=PASS
STATIC_SAFETY_CONTRACT=PASS
```

Evidence directory:

```text
/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z
```

Raw serial-bearing Phase 10/11 evidence remains local/private and is not
published.

## Device and stock identity

```text
N1D_C3B_E5A_DEVICE_BINDING_VERIFIED=PASS
N1D_C3B_E5A_STOCK_FINGERPRINT_MATCH=PASS
N1D_C3B_E5A_STOCK_INCREMENTAL_MATCH=PASS
N1D_C3B_E5A_ADB_CURRENT_SLOT=a
N1D_C3B_E5A_FASTBOOTD_CURRENT_SLOT=a
N1D_C3B_E5A_FASTBOOTD_IS_USERSPACE=yes
N1D_C3B_E5A_FASTBOOTD_UNLOCKED=yes
N1D_C3B_E5A_VERIFIED_BOOT_STATE=orange
N1D_C3B_E5A_VBMETA_DEVICE_STATE=unlocked
N1D_C3B_E5A_BATTERY_PERCENT=100
```

The ADB and fastboot binding hashes matched in this run, but the contract does
not depend on transport strings being identical.

## Snapshot/update state

```text
N1D_C3B_E5A_SNAPSHOT_UPDATE_REVIEW=PASS_IDLE_OR_NONE
```

No manual snapshot/update review remained.

## Fresh dynamic-partition evidence

```text
N1D_C3B_E5A_SYSTEM_CURRENT_BYTES=757059584
N1D_C3B_E5A_SUPER_BYTES=9663676416
N1D_C3B_E5A_ALLOCATION_BASIS=GETVAR_ALL_LOGICAL_PARTITIONS_COMPLETE
N1D_C3B_E5A_ALLOCATION_COMPLETE=YES
N1D_C3B_E5A_ALL_SLOTS_REPORTED_DYNAMIC_TOTAL_BYTES=4203425792
N1D_C3B_E5A_FRESH_SUPER_HEADROOM_BYTES=5460250624
N1D_C3B_E5A_PLANNED_SYSTEM_TARGET_BYTES=3263168512
N1D_C3B_E5A_PLANNED_SYSTEM_GROWTH_BYTES=2506108928
N1D_C3B_E5A_REMAINING_HEADROOM_AFTER_PLANNED_GROWTH_BYTES=2954141696
N1D_C3B_E5A_CAPACITY_SAFE=YES
```

The measured post-growth total-`super` headroom remains well above the
536870912-byte planning floor.

## Restore evidence

```text
N1D_C3B_E4_EVIDENCE_CONTRACT=PASS
N1D_C3B_E5A_OFFLINE_RESTORE_ARTIFACTS=PASS
```

The sealed E3 system image and E4 stock `super` / boot / AVB recovery
artifacts remained unchanged before device contact.

## Final E5A state

```text
N1D_C3B_E5A_PHASE10A=PASS_READ_ONLY
N1D_C3B_E5A_PHASE10B=PASS_READ_ONLY_FASTBOOTD
N1D_C3B_E5A_PHASE11=PASS_READ_ONLY_FASTBOOTD
N1D_C3B_E5A_READONLY_DEVICE_STATE=PASS_REVIEW_READY
N1D_C3B_E5A_FINAL_DEVICE_MODE=FASTBOOTD
```

E5A is therefore sealed cleanly with no outstanding manual-review condition.

## E5B boundary

E5A PASS is not E5B authorization.

```text
E5B_FLASH_AUTHORIZED=NO
E5B_ERASE_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
E5B_UNLOCK_LOCK_AUTHORIZED=NO
E5B_FACTORY_RESET_AUTHORIZED=NO
```

The next step is offline-only preparation of an E5B authorization package from
the sealed E5A JSON. It must compare the active and inactive system-slot
candidates and require fresh logical-partition group-capacity review before any
write authorization is considered.
