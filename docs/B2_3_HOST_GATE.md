# B2.3 host-only power mapper gate

Status: **PASS**.

B2.3 validates the helper-side bramble power-state parser/mapper and the initial private request/response protocol without adding a daemon, init service, socket, SELinux rule, Soong packaging, or physical power privilege.

## Toolchain

- pinned AOSP Rust compiler: `rustc 1.51.0-dev`
- Rust edition: 2018

## Source

- `device/sable/bramble/sable-powerd/src/lib.rs`
- SHA-256: `f60e7443cf4c7ae2d928e3e1dce918d86e28e9ba1f296766d505e296da23bf9b`

## Host gate results

```text
B2_3_POWER_LIB_BUILD_RC=0
B2_3_MAPPER_TEST_BUILD_RC=0
test result: ok. 16 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
B2_3_TEST_RC=0
B2_3_HOST_GATE=PASS
```

The tests cover:

- observed unplugged bramble state -> `Battery`;
- observed ThinkPad USB-C/PD state -> `Usb`;
- observed PC-port online state -> `Usb`;
- wireless source precedence;
- charging/full semantics;
- charging without a recognized source -> `Unknown`;
- invalid or malformed capacity;
- malformed online state;
- malformed battery status;
- missing reader values;
- deterministic reader success;
- exact private request parsing;
- stable success/error response encoding.

## Privilege status

B2.3 is host-only. It introduces no new device privilege.

No init, SELinux, Binder/HIDL/AIDL, network, radio, telephony, sysfs access, Linux capability, root execution, or physical flash/build milestone is implied by this PASS.

The next B2 step is Soong packaging plus helper execution/IPC design review before any SELinux permission is granted.
