# N1D C3B E4 deployment-readiness evidence seal

Status: **SEALED PASS / REVIEW READY**  
Evidence timestamp: **2026-10-03T04:45:03Z**

E4 completed offline and read-only against the sealed E3 system image.

## Artifact identity

```text
SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
SYSTEM_BYTES=2994405376
SYSTEM_AVB_INFO=PASS
```

## Restore evidence

Stock super resolved to the proven N1C stock-super restore artifact:

```text
STOCK_SUPER_SHA256=f2af77fa8187ee55b301ae7fc343b5fbde6182abc8fe3c4071e2d3c31d7897aa
STOCK_SUPER_RESOLUTION=PASS
```

Six matched boot/AVB restore artifacts resolved from the proven TEE14 evidence:

```text
boot.img
vendor_boot.img
init_boot.img
vbmeta.img
vbmeta_system.img
vbmeta_vendor.img
```

```text
STOCK_BOOT_AVB_RESOLUTION=PASS count=6
STOCK_RESTORE_PROOF=PASS
```

## Partition-fit result

Historical read-only fastbootd evidence recorded:

```text
HISTORICAL_CURRENT_SLOT=a
HISTORICAL_SYSTEM_CURRENT_BYTES=756441088
HISTORICAL_SUPER_HEADROOM_BYTES=5510365184
```

For the sealed E3 image:

```text
REQUIRED_SYSTEM_BYTES=2994405376
SYSTEM_MARGIN_BYTES=268435456
ALIGNMENT_BYTES=1048576
PLANNED_SYSTEM_TARGET_BYTES=3263168512
PLANNED_SYSTEM_GROWTH_BYTES=2506727424
ESTIMATED_REMAINING_SUPER_HEADROOM_BYTES=3003637760
DIRECT_FIT=NO
PARTITION_FIT=PASS_RESIZE_CAPACITY_APPEARS_AVAILABLE_REVIEW_REQUIRED
```

This is a planning result, not mutation authorization. The active slot,
userspace-fastboot state, snapshot/update state, current logical partition sizes
and current super capacity must be freshly read from the device before any
resize/flash discussion.

## Safety boundary

```text
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
SLOT_MUTATION_AUTHORIZED=NO
RELEASE_ELIGIBLE=NO
```

E4 did not contact the device.

## Next boundary

E5 is split into two explicit checkpoints:

```text
E5A  fresh read-only device-state revalidation
     requires explicit device-contact authorization
     no flash / erase / resize / AVB / slot mutation

E5B  first physical C3B deployment + boot
     considered only after E5A evidence review
     requires separate explicit mutation authorization
```

E4 PASS does not authorize either checkpoint automatically.
