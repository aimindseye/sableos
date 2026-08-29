# S1.0 Validation — Android 14 oxynoded migration audit

Status: **PASS — READY FOR MINIMAL OXYNODED REINTEGRATION**

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
- Held source history/worktree integrity audit: PASS

Android 14 interface findings:
- `rust_binary` remains registered in Soong.
- `system_ext_specific` remains a recognized module property and is the expected partition direction for oxynoded.
- `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS` remains active in the Android 14 product configuration.
- Android 14 vendor Rust support is materially improved versus the Android 12 baseline, but vendor helper integration is not part of this gate and must be revalidated separately when sable-powerd returns.
- The old product/SELinux hooks must be re-derived and proved by generated-policy/image evidence rather than copied by assumption.

Source lineage finding:
The follow-up git-history/worktree audit showed that the earlier apparent malformed `main.rs` output was an audit-output artifact, not source corruption. The held worktree `bramble/oxynoded/src/main.rs` is syntactically intact and contains the expected `match service.read_state()` / `Ok(state)` / `Err(error)` structure. Its SHA256 is `13f236c45ac6712de52aa0d839597b5e90cdb41354019d5bd5281e4d2608f3b8`.

The held repository HEAD contains the clean B1 oxynoded-only entrypoint (`c5bb032228dcf9b6aa507a5b43a9abec396831e0f3c00bbf3988eede533328b8` when streamed through SHA256). `power.rs` is not present at HEAD; it is a later untracked B2 worktree addition with SHA256 `aeb63277cd25685817be459fb1d9553d64ba507ea507a1d12c386645c98ff26c`.

S1.1 therefore starts from the B1 oxynoded-only lineage and re-establishes the Android 14 system_ext/init/SELinux confinement boundary before any B2 power semantics or sable-powerd integration is restored.
