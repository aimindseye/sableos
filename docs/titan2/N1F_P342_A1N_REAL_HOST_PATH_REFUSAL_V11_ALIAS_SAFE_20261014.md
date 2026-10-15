# PR #342 — A1N actual host path refusal; V1.1 exact alias-safe evidence binder

Date: 2026-10-14 (US/Eastern). **This is a docs-only PR change**; operator's isolated A1 source remains frozen after A1F–A1L. User requires all PRE-build gates before host-only image build, regardless of earlier build authorization. Never device/super/flash.

## Actual ai-g732 A1N V1 operator evidence

- Outer `N1F_P342_A1N_RETAINED_PROVENANCE_BIND_V1.zip` SHA PASS; bundled 11 SHA256 checks PASS; inherited A1D+A1M+A1N regression tests **137/137 PASS (0.052s)**; plan `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO` PASS.
- Real `inspect` **REFUSED**: `REFUSED_A1N_UNSAFE_OR_SOURCE_DRIFT` with `reason=unsafe_run_root:UNSAFE_NON_DIRECTORY_ANCESTOR:/srv/sable-build/artifacts/titan2/n1i-c1-five-app-bundle`.
- This means a strict no-follow path walker encountered a non-directory intermediate component while inspecting the first optional historic artifact parent. **Its identity is unknown from this output**; it may be a symlink/alias or a different non-directory obstruction. Do not call it a proven link, missing bundle, payload corruption, or A1 source drift.
- A1N V1 stopped before app-manifest/CIL attribution; it does not supersede actual A1M 13 gate / 11 open results. A1F–A1L completed, A1M source pins/receipt checks PASS; no Android source writes, build, network, super, device, flash.

## Existing implementations reviewed (no duplication)

- Main `build/config/storage.env` explicitly defines canonical `/srv/sable-build` and legacy `/srv/data/sable-build` storage profiles; actual A1/M4 source rooted in `/srv/data/sable-build` passed earlier nofollow reads.
- Main `build/titan2/run-n1i-c1-cellular-isolation.sh` defines timestamped `/srv/sable-build/artifacts/titan2/n1i-c1-five-app-bundle` root; main `build/titan2/build-n1d-c3b-e2-product-apps.sh` defines `n1d-c3b-e2-product-apps/<exact import commit>/<run stamp>`. Both historical paths are **candidate producers, not certified extant receipts**.
- Original A1D `classify_exact_leaf` and A1M source/payload checks already reject symlink traversal; do not replace them with `realpath`, `find /`, or any unbounded source scan. Historical PR #339 M4 physical Recovery image is not a valid boot baseline. PR #342 earlier A1F–A1M scopes remain complete; no new Android source mutation is required for this path error.

## A1N V1.1 external package

`N1F_P342_A1N_RETAINED_PROVENANCE_BIND_V1_1.zip`, exact **SHA256 `6d3f9c1ad432901648b31abd6dd936c0e5547ba9f84de111d7f6268b0717ea0d`**, **33,952 bytes**, 12 ZIP members (11 internally sealed + `SHA256SUMS.txt`). New main `n1f_p342_a1n_retained_provenance_bind_v1_1.py` SHA256 **`d9e9468828d2f62ca080559baf6c443ba21dbcc88c308335bba854fa4b5c498a`**. Included inherited A1D SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777` and A1M SHA256 `00fd3edd2b5b842bbb24a8fab9838063846e962464f14c69ba4bf591186da544`, **both unchanged**.

New `first_obstruction()` diagnoses first offending component using `dirfd`, `os.stat(follow_symlinks=False)` and `os.readlink` without ever following it. `guarded_stamped_dirs()` allows **only a literal allowlisted** Sable canonical-to-compatibility storage alias; after matching, independently reopens physical target path through unchanged O_NOFOLLOW directory walker. Unknown symlink target/regular-file ancestor or symlink within a physical alternative => `HOLD_UNQUALIFIED_STORAGE_PATH_NOT_FOLLOWED` with `first_obstruction` and **zero candidates admitted** from that root. It can continue independently safe app and CIL checks instead of aborting the entire report. Unexpected run members, symlinks inside an allowed physical root, size limits, more than 24 immediate entries, and hash candidate caps remain refusal conditions. There is **no general symlink following, no arbitrary realpath, no new build or stock-import authority**.

Scopes and caps unchanged from V1: fixed two app artifact parent roots, one fixed historical CIL evidence parent and one exact prior audit CIL path, at most 24 immediate directory entries per run root, four manifest-bearing app candidate bundles hashed, four CIL candidates, a 10-byte `system_ext.img` filesystem-header probe. Matching 5-APK manifest or generated `property.te` demonstrates bounded content equivalence only, never independently stock extraction provenance, signedness, release identity or build readiness.

## Syntax, test and performance validation

- Actual archived ZIP CRC PASS and all **11/11 internal SHA256 PASS**; 6 Python AST+`compile()` PASS; `bash -n` PASS; no bytecode emitted.
- In local assistant container, **149/149 synthetic tests PASS under `umask 077` (0.2258s wall) and `022` (0.2369s wall)**. Fresh exact ZIP extracted under each umask: SHA11 PASS, 149/149 tests PASS and Bash PASS.
- Added 12 independent fixture tests for first alias metadata obstruction; allowed literal alias re-open nofollow, disallowed alias, symlink within allowed target, symlink stamped run refusal, regular-file ancestor, absent path, unsafe/valid independent roots, CIL candidate symlink HOLD; retained other A1D/A1M/A1N negative cases. Original V1 CIL symlink test updated to assert nofollow HOLD rather than whole-inspector exception because that optional path is not read.
- Synthetic 500-run metadata timing for alias-safe 20-stamped-run directory: median **0.10908ms**, p95 **0.19480ms**, excluding any real APK hashing. No verified real ai-g732 timings or physical storage alias identity as of package generation.

## Next ai-g732 operator action

Verify outer ZIP SHA, fresh unzip, run `bash ./n1f_p342_a1n_verify_then_inspect_v1_1.sh` from extracted directory. The script checks 11 inner SHAs, 149 tests, plan, then exact read-only inspect. Return **full JSON**, especially `app_bundle.roots[].first_obstruction`, `selected_physical_root`, `alias_accepted_no_symlink_follow`, `selinux_cil.matched_paths` and `app_bundle.matching_paths`. Expected overall **`HOLD_A1N_PREBUILD_ORIGIN_BINDING_INCOMPLETE`**; any unrecognized path is not opened or promoted. If real report still `REFUSED_A1N_UNSAFE_OR_SOURCE_DRIFT`, preserve state and review exact reason. **A1N V1.1 host execution NOT YET OBSERVED.**

All PRE-build gates still open except previously completed bounded source and sealed audit-file checks: stock-to-six-payload attribution, 5-app original release build seal/signing, stock CIL policy derivation, independent 991 `.repo`/Git objects, selected patch/TrebleApp fidelity and config-only Kati/Soong product graph. These must be satisfied BEFORE host-only image build; compiled policy and complete final-image G1/G2/G3 are required AFTER qualified image creation but BEFORE device/flash. Guard file `.A1_INCOMPLETE_DO_NOT_BUILD` stays, `out-a1` stays absent, NO build/device/flash.

```text
A1N_V1_OPERATOR=REFUSED_UNSAFE_NON_DIRECTORY_ANCESTOR_ON_APP_ROOT
A1N_V1_OPERATOR_SOURCE_DRIFT=NOT_PROVEN
A1N_V1_OPERATOR_INSPECTION=NOT_COMPLETED
A1N_V11_LOCAL=PASS_ZIP_CRC_SHA11_AST6_BASH_TEST149_TWO_UMASKS
A1N_V11_HOST=NOT_EXECUTED
BUILD_TECHNICAL_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 remains OPEN/DRAFT/UNMERGED.