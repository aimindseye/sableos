# B2.5A validation — sable-powerd policy/pre-flash gate

Status: **PASS**.

B2.5A is the first B2 checkpoint that introduces runtime privilege for the dedicated `sable-powerd` helper, while keeping `oxynoded` isolated from the helper and from direct hardware access.

Validated results:

- B2.5A preflight confirmed the expected B2.4 source state;
- pre-policy checkpoint created at `/srv/data/sableos_checkpoints/B2.5/pre-policy-20260828-233131`;
- all 16 helper mapper/protocol/error host tests passed;
- host `sable-powerd` mock probe returned `OK battery_percent=42 charging=1 source=Usb`;
- `sable-powerd`, init RC, and SELinux policy compiled successfully for `sable_bramble_b2-userdebug`;
- B2 product packaging includes `sable-powerd` and `sable_powerd_init_rc`;
- init runs `sable-powerd` as UID/GID `system`, not root;
- dedicated `sable_powerd` SELinux domain and executable type are defined;
- policy grants the helper read-only access to the existing `sysfs_batteryinfo` interface and required sysfs traversal only;
- `oxynoded` received no new `sable_powerd`, sysfs, or battery permission;
- helper source contains exactly five validated `/sys/class/power_supply` paths;
- installed helper binary and init RC are present in `out_b2`.

Validated output hashes:

- `sable-powerd`: `45a14a288860a30fc6e5ea2c5b04aeab0f51f31a1ec6f59d9ceca63bde84dc57`
- `sable-powerd.rc`: `7ea5407db3f7024ac3a6847cd231e30a582226329673d150bdb9c9a5c8fdb7c7`

No full B2 image has been flashed at this checkpoint. Physical validation remains pending.

Next gate: build and audit the complete B2 image and target-files package before any physical flash.
