# S1.0 Validation — Android 14 oxynoded migration audit

Status: **AUDIT COMPLETE — SOURCE INTEGRITY BLOCKER BEFORE REINTEGRATION**

Baseline:
- Device family: bramble
- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Sealed vanilla GM remains present and read-only.
- Live Android 14 tree remains vanilla with `device/sable` absent.
- Held Android 12 Sable source is present as a git work tree at HEAD `da17105a04cf61024527b376c4ea06888456a5e0`.

Audit gates:
- S1.0 preflight: PASS
- Held oxynoded inventory audit: PASS
- Android 14 interface audit: PASS

Android 14 interface findings:
- `rust_binary` remains registered in Soong.
- `system_ext_specific` remains a recognized module property and is the expected partition direction for oxynoded.
- `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS` remains active in the Android 14 product configuration.
- Android 14 vendor Rust support is materially improved versus the Android 12 baseline, but vendor helper integration is not part of this gate and must be revalidated separately when sable-powerd returns.
- The old product/SELinux hooks must be re-derived and proved by generated-policy/image evidence rather than copied by assumption.

Source integrity blocker:
The held `bramble/oxynoded/src/main.rs` printed by the audit is not syntactically self-consistent around `run_power_mock_probe()`: after `let service = PowerService::new(backend);` the expected read-state/match arm is absent while later code references `state` and contains an `Err(error)` arm. Therefore the held B2 worktree must not be copied into Android 14 as-is.

The next action is a read-only git-history/worktree comparison of the held oxynoded source to determine whether the malformed `main.rs` is a working-tree edit or already present at HEAD, and to identify the last clean B1.1 oxynoded-only source. S1.1 reintegration must start from oxynoded-only confinement, without carrying B2 power semantics or sable-powerd until that source lineage is resolved.
