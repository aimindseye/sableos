# Titan 2 C3A V01.00.14 fresh live preflight

Status: **authorized read-only device revalidation / no write / no reset**

Updated: **2026-10-03 ET**

This is the next canonical Titan 2 engineering step after the sealed offline C3A
control preparation.

Bound offline evidence:

```text
EVIDENCE_DIR=/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan
EVIDENCE_SEAL_SHA256=e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57
C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_SYSTEM_BYTES=3146977280
CURRENT_FIRMWARE=V01.00.14
```

## Implementation

The device-facing path reuses the previously audited E5A Phase-10/11
collectors. Their default C3B behavior remains unchanged; only three sealed
image/target values are now overrideable by environment for this control:

```text
SABLE_E5A_SYSTEM_IMG
SABLE_E5A_EXPECTED_SYSTEM_SHA256
SABLE_E5A_EXPECTED_SYSTEM_BYTES
SABLE_E5A_PLANNED_SYSTEM_TARGET_BYTES
```

C3A passes the exact same image byte count as both file identity and planned
logical-system target. The existing E5B offline parser is reused for active-COW,
active-group and total-super capacity math. A final C3A-specific qualifier then
fails closed unless all of the following are true:

```text
stock fingerprint/incremental = sealed V01.00.14
fresh fastboot device binding = prior sealed binding
current slot = a
product = Titan_2
userspace fastbootd = yes
bootloader unlocked = yes
snapshot/update state = idle/none
logical allocation = complete
target = system_a
planned target bytes = 3146977280
active COW count = 0
COW cleanup required = no
active-group capacity = safe
total-super capacity = safe
```

## Authorization boundary

Authorized:

```text
read-only ADB
read-only fastboot getvar
adb reboot bootloader
fastboot reboot fastboot
```

Not authorized:

```text
flash
erase / format / factory reset
logical-partition resize/create/delete
COW cleanup
AVB/vbmeta mutation
slot change
unlock/lock
custom boot
reboot back to Android
```

The successful terminal device mode is userspace fastbootd.

## Run

Start with Titan 2 booted into recovered stock V01.00.14 with USB debugging
authorized.

```bash
cd /srv/sable-build/sableos/repo

bash build/gates/c3a-v010014-live-preflight-contract.sh

bash build/titan2/collect-c3a-v010014-live-preflight.sh \
  --authorize-readonly-device-contact \
  --authorize-reboot-to-fastbootd
```

Expected clean result:

```text
C3A_V010014_LIVE_PREFLIGHT=PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW
C3A_V010014_LIVE_TARGET_PARTITION=system_a
C3A_V010014_LIVE_ACTIVE_COW_COUNT=0
C3A_V010014_LIVE_ACTIVE_GROUP_CAPACITY_SAFE=YES
C3A_V010014_LIVE_SUPER_CAPACITY_SAFE=YES
C3A_V010014_LIVE_PREFLIGHT_FLASH_AUTHORIZED=NO
C3A_V010014_LIVE_PREFLIGHT_FACTORY_RESET_AUTHORIZED=NO
C3A_V010014_LIVE_PREFLIGHT_FINAL_DEVICE_MODE=FASTBOOTD
```

Any BLOCKED result stops the control. In particular, a nonzero active COW count
does **not** authorize cleanup; it requires a new reviewed decision.

A PASS still does not authorize the system write. The next deliverable after a
clean PASS is a separately gated C3A physical-control execution package for the
exact sealed image and active `system_a`, with factory reset remaining a
separate explicit authorization.
