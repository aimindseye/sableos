# S1.1 Validation — Android 14 minimal oxynoded host/package gate

Status: **PASS — HOST/PACKAGE ONLY; NOT YET PHYSICAL**

Baseline:
- Device family: bramble
- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Product: `sable_bramble_s1-userdebug`
- OUT_DIR: `out_s1`

Evidence:
- Minimal source reintegration scope: PASS
- No B2 power surface (`power.rs`, `sable-powerd`, vendor policy): PASS
- Targeted oxynoded/init/SELinux build: PASS
- Full Android 14 product build: PASS
- Full build runtime: 05:21:59
- `oxynoded` final install path: `/system_ext/bin/oxynoded`
- init rc final install path: `/system_ext/etc/init/oxynoded.rc`
- ELF: AArch64 PIE, dynamically linked
- Generated Android 14 policy includes `type oxynoded, domain, coredomain;`
- Generated init transition to `oxynoded`: PASS
- Generated file context: `/system_ext/bin/oxynoded u:object_r:oxynoded_exec:s0`
- S1.1 `system_ext.img` SHA256: `165714e02f6381a139daa6b6fc20cb6c85979ac72768bae7f40b9d69943c4c60`
- S1.1 target-files: `sable_bramble_s1-target_files-eng.mindseye73.zip`
- Target-files SHA256: `cd28d54980d55e9bc9db6eb19af878959d0ed38803e328602dc6ec35308d3a0c`
- Target-files ZIP integrity: PASS
- Target-files contains `SYSTEM_EXT/bin/oxynoded`: PASS
- Target-files contains `SYSTEM_EXT/etc/init/oxynoded.rc`: PASS
- Target-files contains exact oxynoded SELinux file context: PASS

This gate proves the minimal B1-style oxynoded boundary survives Android 14 source integration, Soong, SELinux policy generation, final image construction, and target-files packaging.

It does **not** prove physical boot, init startup, runtime SELinux domain, UID/GID, capabilities, AVC cleanliness, reboot persistence, or hardware capability parity. Those require the next controlled pre-flash and physical validation gates.
