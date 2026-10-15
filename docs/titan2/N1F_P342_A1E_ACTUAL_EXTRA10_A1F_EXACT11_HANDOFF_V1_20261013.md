# PR #342 — actual A1E 10-gap refusal; A1F exact-11 destination replay handoff V1

Date: 2026-10-13 engineering lane (UTC activity also falls on Oct14). **Draft docs-only status; no GitHub-host source execution or Android build.**

## Operator actual A1E execution

`N1F_P342_A1E_COMBINED_PREBUILD_GATES_V1.zip` ZIP integrity and 9/9 internal member SHA256 **PASS**; ai-g732 A1D/A1E synthetic tests **88/88 PASS (0.092 seconds)**; default `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO` PASS. Actual combined read-only prelink gate refused `REFUSED_PREBUILD_GATE_NOT_BUILD_READY`, `additional_manifest_destination_gaps.total=10`, `one_link_created_before_failure=false`. Thus **NO link was written, no cleanup/rollback performed, no build/device/flash**. SSH exited after controlled nonzero script; do not infer host crash.

Nine newly reported missing linkfile destinations with protected donor literal targets matched: `Android.bp`, `bootstrap.bash`, `build/CleanSpec.mk`, `build/buildspec.mk.default`, `build/core`, `build/target`, `build/tools`, `trusty/.bazelrc`, `trusty/WORKSPACE.bazel`. One missing copyfile with original donor REGULAR: `lk_inc.mk`. Together with exact A1C archived linkfile rule for missing `build/envsetup.sh` (A1 underlying target/donor bytes SHA256 `cf5d1ee8eeb737f4373182819fb8bc069e8fd8debd171d71c238fd630a518a29`, 39081 bytes), **11 total manifest-managed root checkout artifacts** are identified. These are not 11 missing Git projects. 991 new local Git clones remain provisional; no new 991 census required.

## New bundled A1F distribution — source-only exact-11 gates

`N1F_P342_A1F_EXACT_11_MANIFEST_REPLAY_V1.zip`, **SHA256 `7293570a0be52c2835f6b8938622ba067185f05d415b39a0df006858b1fe1cec`** (35,535 bytes). A1F new Python main SHA256 `f09b5e2e6bf21b7d6f4eb6b574198b93a2f06e8a615661c5cecc5ec197780bd2`. Bundled A1D and A1E Python source bytes **unchanged**, respective SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777` and `c00cbcd0bf126f8ef67800ad6590ed922b62a0090f689f4ff0a4a86dd77c74ba`. ZIP CRC PASS, **11/11 internal SHA entries PASS**, Python AST/bytecode 6/6 PASS, README Bash and wrapper syntax PASS, **132/132 synthetic combined regressions PASS** (88 inherited, 44 new; assistant host 0.512s). 100 synthetic fixture read-only qualifications median/p95 3.4851/3.8556 ms and 60 synthetic fixture guarded replays median/p95 6.9427/7.4342 ms; **NOT ai-g732 host timing**. A1F real ai-g732 NOT EXECUTED.

The single `n1f_p342_a1f_validate_then_run_v1.sh` launcher verifies package members, runs 132 regressions, emits plan zero host evidence IO, and under exact opt-in `N1F_P342_A1F_AUTHORIZE_EXACT_11_A1_ONLY=YES_EXACT_11_ONLY`:
1. Performs fresh SHA-pinned Oct03 archived repo-manifest-r.xml content read <=4 MiB + bounded declaration census <=256. Inspects only declared A1/donor destination metadata with fd nofollow.
2. Requires **exact** set of 11 reported missing destinations, source/owner/root/guard invariants, no unexpected destination gaps, valid literal donor symlinks; verifies A1/donor regular/dir source types and bytes for five scaffold, four dirty sources, A1C 39,081B target, and all copyfile sources/current donor copied bytes. Max 4MiB per source leaf / 96MiB per source-content verification pass, with pre-read cap; repeated checks bound each pass.
3. If **and only if all prewrite checks PASS**, materializes 10 manifest-computed literal symlinks into the isolated **A1** root and one `lk_inc.mk` A1 regular copy whose SHA/content and permissions agree with donor/source, through exclusive staging+hardlink publish. No overwrites, no broad checkout restoration, **no cleanup/rollback/retry/resume** for partial writes; marker remains.
4. Re-inspects bounded manifest destinations and source byte pins after creation. On any drift/failure, `REFUSED_OR_PARTIAL_NO_BUILD_ADMISSION` and observed created leaves + staging state are reported, operator must STOP.

All operations are excluded for original donor, Oct03/Oct11/M4 protected source/OUT, `.repo`, `out-a1`, build-system source integration, Git/repo fetching/cloning, Android compilation, super/LP/AVB, device/flash. Persistent `.A1_INCOMPLETE_DO_NOT_BUILD` remains.

## Not closed by A1F

- Independent original Oct03 TrebleApp `sdk/.knownPackages` post-residue byte proof **UNBOUND**.
- Shared Git alternate object-store self-containment **UNBOUND**.
- `.repo` and full product/Soong functional source graph **NOT_RECONSTRUCTED**; original 369 patch stack replay/new-build attestation **NOT_PERFORMED**.
- R1/B1/C1/CW1/IMS new A1 source integration, new-image effective G1/G2/G3 signing/classloader/native namespace/SELinux **NOT_EXECUTED**. Historic M4 scoped evidence reused only as separate evidence; M4 physical Recovery failure not erased.
- New `system.img` build and matched hybrid super, full companion LP/AVB, phone, flash and public release **NOT AUTHORIZED**.

```text
A1E_REAL_HOST=REFUSED_EXTRA_10_GAPS_CORRECT_NO_MUTATION
A1C_EXACT_MISSING_LINK=PASS
TOTAL_EXACT_ARCHIVED_MANIFEST_MISSING=11
A1F_ASSISTANT_PACKAGE=PASS_ZIP_SHA11_AST_BASH_TEST132
A1F_HOST_QUALIFY=NOT_EXECUTED
A1F_HOST_EXACT_11_REPLAY=NOT_EXECUTED
A1_NO_BUILD_MARKER=PRESERVE
BUILD_READY=NO BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

Keep PR342 **open/draft/unmerged** pending operator output.