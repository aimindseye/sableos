# sablectl v0.3.1 — D4 boot-control observability correction

Date: 2026-09-08

## Trigger

The first live `sablectl release d4` run on Panther returned `rc=70` for all three `bootctl` probes:

- `get-current-slot`
- `is-slot-bootable 1`
- `is-slot-marked-successful 1`

All other release checks were healthy: 55 PASS, 3 SKIP, 0 MANUAL, with only those three bootctl-derived checks failing.

## Root classification

Current AOSP `bootctl` uses `EX_SOFTWARE` (70) for boot-control client/RPC failure. Boolean queries also use 70 for a legitimate `false` result, but print literal `0` in that case.

`get-current-slot` is different: once a boot-control client exists, it prints the current slot and returns success. Therefore `get-current-slot rc=70` means boot-control metadata was not observable from the caller; it is not evidence that slot B is unbootable or unsuccessful.

## v0.3.1 semantics

The release gate now:

1. Always verifies `ro.boot.slot_suffix` as the authoritative runtime-slot check available to ordinary ADB shell.
2. Reads `ro.boot.slot_successful` as bounded boot-time evidence:
   - `yes/true/1` => PASS positive evidence;
   - `no/false/0` => SKIP because Android may mark the slot successful later during the same boot;
   - absent/unknown => SKIP.
3. Probes `bootctl get-current-slot` once.
4. If that probe is unavailable, all current boot-control metadata checks become explicit SKIP and the more specific bootable/successful probes are not issued.
5. If boot_control is observable, boolean `bootctl` results are interpreted as:
   - rc=0 / stdout `1` => PASS;
   - stdout `0` => FAIL;
   - rc!=0 without boolean stdout => SKIP/unobservable.

This is fail-closed: v0.3.1 never fabricates bootable/successful state.

## D4 closure boundary

A release run may be healthy while current boot-control metadata remains unobservable from ordinary ADB shell. In that state:

```text
D4_RUNTIME_SLOT=PASS
D4_BOOT_CONTROL_METADATA=UNOBSERVED
D4_SLOT_MARKED_SUCCESSFUL=CURRENT_STATE_NOT_PROVEN
```

Do not convert a SKIP into a claim that the slot is marked successful.
