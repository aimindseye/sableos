# PR #342 — A1R V1.2 real 61-file PASS and Android graph post-parse release-gate false negative; A1S V1

Date: 2026-10-14 America/New_York. PR #342 stays OPEN/DRAFT/UNMERGED. User directs no repeated stock, Git, app, policy or generated source audits. No image build or device action has been run.

## Actual ai-g732 A1R V1.2 operator result (new evidence)

Outer ZIP SHA256, 13 internal SHA256, Python and Bash syntax PASS; 43/43 focused tests PASS (0.765s), no-I/O plan PASS. Real A1R V1.2 created **61/61** generated source files: one `AndroidProducts.mk`, 60 `treble_*.mk`, `already_exact=[]`. Historical donor generated mk members missing `59`, so the exact generator script from pinned TrebleDroid Git blob `8f24152e399360831f344c0759afd266493ab869` was executed in isolated scratch. Generated registry SHA256 `7ed5196fb0b34e7132b3c22673d5c62a4b48a74721e45df6b304f429a42d4ea3`; selected `treble_arm64_bvN.mk` SHA256 `9f38361f92428ca4cfdf05d68818f1c93aa794b7bb2e59e2504368b9adf83385`; generator SHA256 `a1a6679893cbdbf53d72b0a1d4a29d69eead0d2684c89d54ce48cb1e9f060c8a`. A1R original A1P 12 staged files and A1Q independent 3 Git stores remained untouched. `no_build_marker=PRESERVED`, `out_a1=ABSENT`, `systemimage=false`, network/device/super/flash all false.

A1R V1.2 end state **`INCOMPLETE_STOP_PRESERVE_GENERATED_PRODUCT_AND_EVIDENCE`**, `reason=graph_var_wrong:TARGET_RELEASE:`, `build_ready=false`. This is a **post-graph parser failure**, not a failed graph-generation subprocess: exact unchanged q.configure_graph Python SHA256 `5aeffe93740b53f9ec707c8100dc41ae6e3cc40bf8b8568b4df5bff9e6d1e118` performs `lunch treble_arm64_bvN-bp4a-user`, captures eleven `get_build_var` outputs, invokes `m -j4 nothing`, returns error if subprocess rc nonzero, checks graph log size and **only then** calls `parse_vars`. That last function checks `get_build_var TARGET_RELEASE` equals `bp4a`; actual returned empty. The observed exact suffix `graph_var_wrong:TARGET_RELEASE:` proves that prior `m nothing` subprocess returned 0 and the issue is a shell-vs-Make release-variable representation. The product graph itself was generated/evaluated successfully at the level of `m nothing`; all other captured variables must still be checked for C1/C3B inclusion.

## Existing SableOS GitHub history confirms correct shell release authority

Canonical SableOS `build/titan2/qualify-n1d-c3-product-parse.sh`, `build/titan2/qualify-n1d-c3b-e2-product-parse.sh` and `build/titan2/run-n1g-sable-product-identity.sh` each check **`${TARGET_RELEASE:-}`** in the shell after `lunch`, not just `get_build_var TARGET_RELEASE`. Some prior N1F scripts did use the latter, so the correct fallback requires an independently observed actual shell `bp4a`, never an assumption based on the target name. Product/variant, Android16, boot JARs, location overrides, C1/C3B modules, marker copy and SELinux variable contract remain in unchanged `q.parse_vars`. A1F–A1P, A1Q Git and A1R generated source work are CLOSED; **never rerun**.

## A1S V1 external one-use graph-certification handoff

ZIP **`N1F_P342_A1S_EXISTING_GRAPH_RELEASE_ADMISSION_V1.zip` SHA256 `d8943dad5b42a85488f61192f97cedfd14d537b95e8ee29f877c10f9fc21cb70`**, **48,733 bytes**, 14 members (13 SHA256 sealed + `SHA256SUMS.txt`). New main source `n1f_p342_a1s_postgraph_release_admission_v1.py`, wrapper `n1f_p342_a1s_one_command_v1.sh`. Inherited A1D/A1M/A1O/A1P/A1Q/A1R Python sources copied byte-for-byte unchanged from A1R V1.2.

**New operation does not rerun `m nothing`.** Before any new evidence write, A1S reuses A1P completed source receipt and exact 12 file pins, A1R one-use receipt and SHA256 of all 61 restored PHH files, previous A1Q 3 independent-project status, intact no-build guard and absent `out-a1`, and already captured 11 `config-vars.tsv` variables. Temporarily uses expected `bp4a` ONLY to invoke the original unchanged `q.parse_vars` on remaining 10 variable gates; records original Make release value as `MAKE_UNSET_SHELL_PROBE_REQUIRED` rather than certifying a release from that temporary substitution. A1S insists original Make `TARGET_RELEASE` be empty or `bp4a`, then executes only `source build/envsetup.sh; lunch treble_arm64_bvN-bp4a-user` in the EXISTING A1R config-only out dir, captures and requires shell `TARGET_PRODUCT=treble_arm64_bvN`, `TARGET_RELEASE=bp4a`, `TARGET_BUILD_VARIANT=user`, and writes one-use evidence `.A1S_POSTGRAPH_RELEASE_ADMISSION_NO_IMAGE_V1/RECEIPT.json` with pass/fail and release log. **No Git, stock, APK, CIL audit, generator, product mk write, m nothing, systemimage, Repo init/sync, network fetch, super, device, flash.** Config-only `lunch` may touch existing A1R config cache; no Android source or out-a1 modifications.

Success status `PASS_A1S_EXISTING_GRAPH_RELEASE_SHELL_CERTIFIED_HOST_IMAGE_CANDIDATE`, `build_ready=true` **scoped strictly to an engineering host-only image candidate**, not production signoff, physical boot, or flash. Failure status `REFUSED_A1S_PREFLIGHT_NO_NEW_EVIDENCE` before evidence creation, or `INCOMPLETE_A1S_PRESERVE_RELEASE_EVIDENCE` after one-use evidence; never rerun after evidence exists. Preserve `.A1_INCOMPLETE_DO_NOT_BUILD`. A separate exact host-only image driver still required, and compiled image/SELinux/G1/G2/G3 device decisions remain post-build.

## Validation

- Local assistant-container ZIP CRC PASS; all **13/13 bundled SHA256 PASS**; Python AST and compilation, Bash -n PASS; `plan` zero host I/O PASS.
- **29/29 focused fixture regressions PASS** on original and on fresh extracted ZIP at both umask 077 and 022 (fresh synthetic roughly 0.05–0.07 sec). Includes a synthetic A1R 61-file receipt with full hash readback, incomplete/corrupt receipt refusal, changed/symlinked/missing generated source denial, all unchanged q.parse_vars bootjar/package/marker/policy checks, shell release success/failure, one-use receipt, no m goal, and wrapper CLI authority.
- Synthetic 11-var parser 150 iterations median 0.132 ms/p95 0.355 ms; 61-file evidence fixture preflight 20 iterations median 3.318 ms/p95 4.111 ms, not actual ai-g732 system configuration runtime.
- **A1S real ai-g732 NOT EXECUTED**. The shell release validation result cannot be predicted. If it is unset or changed, honor HOLD; do not fabricate bp4a.

One operator command after verify ZIP outer SHA and fresh unzip: `bash ./n1f_p342_a1s_one_command_v1.sh --authorize-a1s-existing-graph-release-check-only`. Do not rerun A1R V1.2 or the completed earlier operations.

```text
A1R_V12_ACTUAL_61_SOURCE=PASS
A1R_V12_ACTUAL_M_NOTHING=PASS_SUBPROCESS_RETURNED_0
A1R_V12_POSTGRAPH_TARGET_RELEASE_MAKE=EMPTY
A1S_LOCAL=PASS_ZIP_SHA13_SYNTAX_TEST29_BOTH_UMASKS
A1S_AI_G732=NOT_EXECUTED
BUILD_READY=NO_PENDING_SHELL_RELEASE_CERT
IMAGE_BUILD=NO DEVICE=NO SUPER=NO FLASH=NO
```