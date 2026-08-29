# B2.4 validation — sable-powerd Soong target-build gate

Status: **PASS**.

B2.4 proved that the host-tested `sable-powerd` mapper can be built as a real Android ARM64 `rust_binary` for the isolated `sable_bramble_b2-userdebug` product without introducing runtime privilege.

Validated results:

- B2.4 host mapper/protocol regression gate passed;
- all 16 mapper/protocol/error tests passed;
- host `sable-powerd` mock probe returned `OK battery_percent=42 charging=1 source=Usb`;
- Soong target build completed successfully;
- target binary installed to `out_b2/target/product/bramble/system_ext/bin/sable-powerd`;
- `sable-powerd` was not yet included in the B2 product image;
- Rust source referenced exactly five validated power-supply sysfs paths;
- corrected source privilege audit passed;
- target ELF is ARM64 PIE and depends only on `libc.so` and `libdl.so`;
- no Binder/HIDL/AIDL/radio/network dependency was introduced.

Target binary SHA256 from the validated B2.4 build:

`8a181efe7423925fab9ac1fb2e047b13820cc061f34ddb8d028d38a9cb218092`

B2.4 did not add init startup, SELinux policy, a Unix socket, physical runtime sysfs access, or any new `oxynoded` permission.

The next gate is B2.5: package and start `sable-powerd` in its own SELinux domain with read-only battery-information access, while keeping `oxynoded` isolated from the helper.
