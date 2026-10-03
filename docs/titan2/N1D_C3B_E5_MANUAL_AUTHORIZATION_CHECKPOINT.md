# N1D C3B E5 manual authorization checkpoint

Status: **E5A AUTHORIZED / E5B NOT AUTHORIZED**

E4 is sealed PASS. E5A read-only device-state revalidation is explicitly authorized. E5B deployment remains separately unauthorized.

## E5A — fresh read-only device-state revalidation

Purpose: determine whether the current Titan 2 still matches the historical
deployment assumptions before any mutation is considered.

E5A is authorized as **device contact, read-only only**, including reboot to bootloader and userspace fastbootd.

Required fresh observations:

```text
ADB/Android baseline before reboot, if currently booted
serial binding / device identity without publishing the serial
battery/power sanity
current slot / slot suffix
bootloader unlocked state
verified-boot state
dynamic-partition state
snapshot / virtual A/B / update state
fastbootd userspace state
logical partition names and current sizes
system_a/system_b current allocation
super total size and group allocation
free/available dynamic-partition capacity
product/vendor/system_ext allocations
current stock version / fingerprint
restore artifact availability still present
```

E5A authorization does **not** authorize:

```text
flash
erase
logical-partition resize/delete/create
AVB/vbmeta mutation
slot change
bootloader unlock/lock
factory reset
booting or flashing a custom image
```

If reaching fastbootd requires rebooting the device, that reboot is considered a
device-state transition and must be explicitly included in the E5A authorization.
The authorized E5A runner leaves the phone in userspace fastbootd for evidence review and must not emit or execute deployment commands. Reboot back to Android is outside the current authorization.

## E5B — first physical C3B deployment

E5B is not authorized by E5A PASS.

After reviewing fresh E5A evidence, a separate manual authorization must identify:

```text
exact E3 system SHA256
fresh active slot
exact logical system partition to resize
fresh current system allocation
exact planned target allocation
fresh super/group headroom after proposed growth
exact stock-super restore artifact/hash
exact boot/AVB restore artifacts/hashes
rollback stop conditions
userdata policy
AVB/vbmeta policy
slot policy
post-write first-boot acceptance sequence
```

No executable write-capable deployment script should be produced before that
separate authorization.

## Current state

```text
E4_DEPLOYMENT_READINESS=PASS_REVIEW_READY
E5A_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY
E5A_REBOOT_BOOTLOADER_AUTHORIZED=YES
E5A_REBOOT_FASTBOOTD_AUTHORIZED=YES
E5A_REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED
E5B_FLASH_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
```
