# Titan 2 evidence index and branch handoff (2026-10-12)

**Authoritative path root:** `/srv/data/sable-build/evidence/titan2` on ai-g732, unless explicitly shown otherwise. Evidence stays on host; GitHub contains references/checksums only.

| Milestone / artifact | Retained source | Evidence / boundary |
|---|---|---|
| October 3 physically booted N1F | `docs/titan2/N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md` | `system.img` SHA `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`; **system_a** flash, not proof of October 11 whole-super write |
| Atlas-inspired hybrid control R2 | `n1f-atlas-hybrid-control-r2-20261011/authority.env` | `PHYSICAL_BOOT=NOT_QUALIFIED` offline authority |
| Atlas-inspired hybrid control R3 | `n1f-atlas-hybrid-control-r3-virtual-ab-20261011/authority.env`, `source-sha256.tsv`, `lpmake-command.txt` | Seven recorded partition hashes; original R3 authority `CURRENT_DEVICE_MATCHED_FIRMWARE=NOT_QUALIFIED`, `LP_METADATA_INDEPENDENTLY_PARSED=NO` |
| R8Q2 | `n1f-pr339-r8q2-mount-apk-20261011/mount_summary.json`, `relevant_packages.txt` | Mount/package snapshot |
| R8Q3 | `n1f-pr339-r8q3-adb-shell-20261011/live_paths.tsv`, `mounts_full.txt`, `mounts_relevant.txt`, `pm_all.txt`, `classpath_env.txt`, `SHA256SUMS` | `/system_ext` points to embedded `/system/system_ext` in **observed running image** |
| R8R | `n1f-pr339-r8r-oem-presence-20261011/live_components.tsv`, `stock_components.tsv`, `SHA256SUMS` | OEM `ImsService.apk` not accessible/listed at tested live locations, while stock reference has APK |
| Runtime bridge | `n1f-pr339-runtime-bridge-r1-20261011/summary.txt` | Device/slot and package output; `FLASH_EXECUTED=NO` scoped to bridge script |
| R8M | `n1f-r3-r8m-radio-diagnostics-20261011/properties.txt`, `subscription.txt`, `phone.txt`, `telephony-registry.txt`, `radio-logcat.txt`, `main-logcat.txt` | `sys.boot_completed=1`; SIM slot 1 loaded; brief voice/data service then registration lost around 20:01:02 |
| P0-BB Oct11 runtime consolidation | Operator P0-BB transcript, October 12 | Evidence path SHA pins; classification `PASS_READONLY_CHECKPOINT_NOT_FLASH_PROOF`; no runtime re-execution |
| P0-AX historical C1 image | `/srv/data/sable-build/workspaces/titan2-n1d/out-n1i-c1-a745c7daa082/target/product/tdgsi_arm64_ab/system.img` | Host hash PASS: `137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160`; not the default parent |
| R1 (P0-AE) | Existing P0-AE static proof in engineering transcripts | Exact `WfcHandler.registerForBroadcast` flagless 5-action filter, one candidate protected broadcast |
| R2 P0-AV | Exact stock five imports in `/srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp-stock/20261005T231205Z/files/system_ext/lib64/` | Five pinned file hashes / AArch64 / direct dependencies 20,15,6,8,7; no full recursive symbol-scope PASS |
| CW1, IMS1-A through D / IMS1-R | [PR #339](https://github.com/aimindseye/sableos/pull/339) documents and linked manifest files | Static/compiled research, not integrated runtime qualification |
| IMS1 D7 | [PR #340](https://github.com/aimindseye/sableos/pull/340) | Separate frozen provenance, 29 operator-pinned identities |

## GitHub branch and PR policy

- Primary research branch: `n1i-d1r4-cw1-compiled-checkpoint-20261011` / [draft PR #339](https://github.com/aimindseye/sableos/pull/339). New October 12 documentation is a **checkpoint on that branch**, not an implementation or flash authorization.
- PR #340 stays separate D7 provenance and must not be misrepresented as merged.
- C1/C2 stack: PRs [#321](https://github.com/aimindseye/sableos/pull/321), [#328](https://github.com/aimindseye/sableos/pull/328), [#329](https://github.com/aimindseye/sableos/pull/329), [#330](https://github.com/aimindseye/sableos/pull/330), [#331](https://github.com/aimindseye/sableos/pull/331), [#332](https://github.com/aimindseye/sableos/pull/332), [#333](https://github.com/aimindseye/sableos/pull/333), [#334](https://github.com/aimindseye/sableos/pull/334) retain historical evidence. Do not merge, close or reuse their image/flash tooling without review.
- Independent security PR [#316](https://github.com/aimindseye/sableos/pull/316) remains separately reviewable.
- The October 11 **Atlas hybrid-super construction branch name was not found** among inspected local/remote ref names, and no independent flashed image seal has been attached. Do not create a false source-commit lineage; recover the source-ref/journal from operator evidence if available.

## Existing evidence SHA pins (operator P0-BB)

```text
R8Q3/live_paths.tsv ee8c81ce85048d9255961a3a87e7c906d8fde050258a833254780244d9b917ac
R8Q3/mounts_relevant.txt af9fcb6f14752fdce3024bc29db7abe2b102bcbff09a81625ee8736997ddb728
R8R/live_components.tsv fe8799f4fb9478adb37d0ea02aa37988903dcb5553b638673d8ff3e6d76bd62f
BRIDGE/summary.txt 3c58e72804f69db926e0e93235cea1f1a25451175e6b53fa5b474ce99093c25a
R8M/properties.txt 019a898387a0fcec4ee60cb3a75a2934cacb3aac136a350ec9e371d60af936ad
R8M/telephony-registry.txt a0b2d247c1129fb70ea9770b35134071d8462cb822271d3285294cbd00aaaf40
R8M/radio-logcat.txt 292517b96805436f6dbe4f706f25fd2d69e35e657bdf300a7e026698d893347a
R3/authority.env 326d6f890a18686b1e72ded58e7be25240fb4887c7168d50e6d3fbb48c970804
R3/source-sha256.tsv 034ceb5e0c3f8825276720c1070c374125536a4abd5a68dc3f8aa008b7c83525
```

## Immediate engineering handoff

**Do not run P0-AZ or another broad discovery loop.** Read retained R8Q3/R8R and operator's October 11 flash/ADB diagnostic cellular-toggle script logs (temporary activation followed by renewed disablement; not a working workaround) to identify the actual mounted composition and reproduction procedure. Then scope only the static R1 policy plus five-library R2 transitive/symbol/namespace checks for that parent. The next source change requires a distinct approval; this index does not authorize it.
