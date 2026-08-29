# S1.1 Validation — Android 14 minimal oxynoded reintegration

Status: **TARGETED BUILD / POLICY / PLACEMENT PASS — PHYSICAL DEVICE NOT YET TESTED**

Baseline:
- Device family: bramble
- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Product: `sable_bramble_s1-userdebug`
- Output directory: `out_s1`
- Sealed vanilla S0 Gold Master remains untouched.

Scope:
- Minimal `oxynoded` only.
- `system_ext` Rust binary and init rc.
- Dedicated `oxynoded` SELinux domain.
- No B2 `power.rs`, no `sable-powerd`, no vendor policy, no sysfs/radio/network/Binder/HIDL/AIDL privilege surface.

Source stage:
- S1.1 source copy: PASS
- No B2 power surface: PASS
- Corrected privilege text audit: PASS

Targeted Android 14 build:
- Product identity: PASS
- Build ID identity: PASS
- `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS` hook: PASS
- `m oxynoded oxynoded_init_rc selinux_policy -j8`: PASS
- Build return code: 0
- Build completed successfully.

Placement / ELF:
- `/system_ext/bin/oxynoded`: PASS
- `/system_ext/etc/init/oxynoded.rc`: PASS
- No `/system/bin/oxynoded`: PASS
- No `/vendor/bin/oxynoded`: PASS
- ELF64 PIE, AArch64: PASS
- Rust probe/version strings compiled into binary: PASS

Generated SELinux evidence:
- `system_ext_sepolicy.conf` contains `type oxynoded, domain, coredomain;`
- `system_ext_sepolicy.conf` contains `type oxynoded_exec, system_file_type, exec_type, file_type;`
- Generated policy contains init execute/transition rules and `type_transition init oxynoded_exec:process oxynoded;`
- `system_ext_sepolicy.cil` contains oxynoded references.
- Generated system_ext file contexts contain exactly `/system_ext/bin/oxynoded    u:object_r:oxynoded_exec:s0`.

Audit-script note:
The original S1.1 generated-policy search reported `S1_1_GENERATED_POLICY_REFERENCE=FAIL` because that search path/logic missed the generated artifacts. Direct inspection of the exact Ninja outputs proved that the policy and file contexts were generated and compiled. This is classified as an audit-script false negative, not a build or SELinux failure.

Conclusion:
S1.1 has re-established the minimal B1-style `oxynoded` build, system_ext packaging, init placement, and dedicated SELinux policy on Android 14. This is a host/build-policy gate only. No physical flash has been performed, so daemon startup, runtime domain, UID/GID, capabilities, AVC behavior, reboot persistence, and capability-regression behavior remain unproven until the next physical gate.
