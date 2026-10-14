# PR342 — A1C actual host PASS; A1D operator plan PASS; A1E combined prebuild gates V1

Date: 2026-10-13. **Documentation-only engineering handoff**. This does not perform an Android source mutation, source integration, image build, hybrid super construction, device operation, or flash.

## Actual operator results already accepted

- A0C original stage / Oct03 archived manifest / head ledger **991/991/991**, zero revision mismatches. A1 new isolated 991-project local clone **PASS_PROVISIONAL**, dependent on original donor Git alternates; `.A1_INCOMPLETE_DO_NOT_BUILD` remains present, `out-a1` absent.
- A1B scaffold 46/46 tests and real metadata inspect PASS: five A1 scaffold leaves REGULAR of same sizes as protected donor; A1 `build/envsetup.sh` ABSENT, original protected donor symlink leaf literal target `make/envsetup.sh` (not followed).
- **A1C exact real ai-g732 authorized inspect PASS** `PASS_EXACT_MANIFEST_LINKFILE_CAUSE_SUPPORTED_NOT_BUILD_READY`. Archived Oct03 `repo-manifest-r.xml` SHA256 `ccac2b30e8433bd5b0ec20e3d9ca4a31b90c918a7d8d7608dc619af5fa071fe8`. Exactly **one** rule for `build/envsetup.sh`: project `build/make`, src `envsetup.sh`, dest `build/envsetup.sh`. Both physical A1+donor `build/make/envsetup.sh` are 39,081 bytes SHA256 `cf5d1ee8eeb737f4373182819fb8bc069e8fd8debd171d71c238fd630a518a29`. Exact symlink materialization gap proven; **not** whole-source replayability.
- **A1D package/plan actual ai-g732 PASS**: outer/inner all SHA checks PASS; **48/48 tests in 0.019s**; `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO`, max 256 declared linkfile/copyfile rules and 516 metadata leaves. **A1D real destination inspect NOT EXECUTED yet**.
- Operator authorizes **all pre-image-build gates**; image build, super, phone/flash remain excluded. Authorization to investigate does not turn an unknown source artifact into a pass.

## Next self-contained bundled deliverable

`N1F_P342_A1E_COMBINED_PREBUILD_GATES_V1.zip` (external operator package, not committed to this docs-only PR): SHA256 **`2bd61e2ac544ab770aeb77bea8c7ac8b03d8428f9304099ef2f45471d61c218e`**; 24,544 bytes. Main Python SHA256 `c00cbcd0bf126f8ef67800ad6590ed922b62a0090f689f4ff0a4a86dd77c74ba`. The original A1D Python inspector is copied **unchanged** with source SHA256 pin `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`. Zip CRC PASS, **9/9 internal SHA** PASS, Python AST+compile 4/4, Bash syntax PASS, **88/88 combined A1D/A1E local synthetic regression tests** PASS (~0.14s). Synthetic 200-fixture qualify median/p95 0.985/1.289 ms and synthetic run median/p95 1.319/1.682 ms, **NOT actual Ubuntu host throughput**. Host `A1E` execution **NOT PERFORMED** by assistant.

One `bash` launcher `n1f_p342_a1e_validate_then_run_v1.sh` verifies package members, runs 88 regressions and plan. Host read/possible write is gated by environment opt-in `N1F_P342_A1E_AUTHORIZE_ISOLATED_ONE_LINK=YES_EXACT_ONLY`. The driver reruns a **bounded** A1D-style SHA-pinned archived manifest destination census, refuses if any extra manifest-managed linkfile/copyfile gap exists, checks five original scaffold A1/donor file content identity and observed sizes, four dirty observed SHA pins, A1C 39,081-byte target SHA, and all declared copyfile content source/destination equality. Every ancestor and content leaf uses no-follow; per-file <=4 MiB, total source <=96 MiB; no 991 HEAD rescan, no images or network.

**Only if all prelink gates PASS**, new isolated A1 `build/envsetup.sh` can be created as **one exact symlink** to literal `make/envsetup.sh`. No overwrite, no other link/copy mutation, no `.repo` creation; subsequent bound manifest reinspection and marker/out protection. Additional missing manifest destinations => `REFUSED_PREBUILD_GATE_NOT_BUILD_READY` with bounded gap summary before any write. The assistant has not observed the actual A1D manifest census result and does not claim only one missing rule in the full manifest.

## Remaining gates — not waived by A1E

Original Oct03 TrebleApp post bytes independently sealed **UNBOUND**. A1 shared Git alternates not independently retained **UNBOUND**. `.repo` scaffold still absent, product graph/source integration R1/B1/C1/CW1/IMS, signing/classpath/SELinux and recursive native namespace G1/G2/G3 for the **new** image unbound. Existing M4-specific scoped G1/G2/G3 PASS reused historically but M4 physically booted into Recovery; no inherited new image effectiveness claim. Matched stock companion LP/AVB, full super and one-shot physical readiness separately held. No Android build/repack/flash permission is granted.

```text
A1C_HOST_EXACT_ARCHIVED_LINK_RULE=PASS
A1D_HOST_PACKAGE_TESTS_PLAN=PASS_48
A1D_HOST_REAL_INSPECT=NOT_EXECUTED
A1E_LOCAL_PACKAGE_AND_SYNTHETIC_TESTS=PASS_88
A1E_HOST_GATES=NOT_EXECUTED
A1E_ISOLATED_ONE_LINK_WRITE=CONDITIONAL_AUTHORIZED_NOT_EXECUTED
A1_SOURCE_REPRODUCIBILITY=UNBOUND
BUILD_READY=NO BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

Draft PR342 is the governing documentation authority; no PR merge or production release.