# PR347 — AI-G732 exact Q25 Quick Settings + DocumentsUI source admission V2

Date: 2026-10-21, based on owner-supplied scratch result.
**Status:** `PASS_4_ORIGINAL_Q25_PATCHES_SCRATCH_APPLIED`; `NEXT_FULL_AOSP_BUILD=HOLD_Q25_IMS`.
**PR346 frozen** source `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`; this V2 did not touch the original Android16 checkout.

## Actual operator receipt
The user successfully ran the first handoff `TB2_Q25_A16_NATIVE_SNAPSHOT_V1`:
- SHA256SUMS all passed; Python regressions **12/12 PASS** (0.106s on AI-G732).
- `QS_KOTLIN=HOLD_KOTLINC`: `kotlinc` executable absent from user's shell PATH for standalone Kotlin stub smoke. **Not a Kotlin source failure**. Real AOSP SystemUI compilation was not attempted.
- Ran `native_trial.py --snapshot TB2_Q25_A16_OWNER_SNAPSHOT.zip --repo TB2_Q25_NEXTBUILD_PR347 --out TB2_Q25_NATIVE_TRIAL_REVIEW.zip`.
- `TRIAL_REPORT.json`: `PASS_REVIEW_PATCH_CREATED`, **four of four `PASS_SCRATCH_APPLIED`** using pinned original Q25 Git blobs:
  - QS large tiles `0e779818de67225e1b420a2ef73c2a31a95b3ab5`.
  - QS shapes `d55456db82beac4af48c64abdda38fbb58b2eca2`.
  - Files keyboard policy `66087905a2cd83eedcc5816e5e2fedfff86b8c60`.
  - Files keyboard wiring `6ce014c1d12dd2caf4ecd682b13210fe2281c5b9`.
- Result contains **12 Android source paths**: five `frameworks/base/packages/SystemUI` and seven `packages/apps/DocumentsUI`; **two new source files**, one QS config XML and one pure Java Files key policy.
- `input_requested=100`, `input_captured=34`, `input_missing=66`; unchanged original owner census.
- Trial explicitly reports `source_mutation=false`, `android_build=false`, `device_contact=false`, `flash=false`.

## Exact artifact SHA256
| Artifact | SHA256 |
|---|---|
| Uploaded owner snapshot `TB2_Q25_A16_OWNER_SNAPSHOT.zip` | `a287e8e06daa2cf867aa174c7d0c12ecedf770c9f9b9f534f8829661aa` |
| Uploaded successful trial `TB2_Q25_NATIVE_TRIAL_REVIEW.zip` | `42d5c2719768686866ac76cab7cd2da6f41f695923da0a64da19edda417ecebd` |
| Internal `SOURCE_DIFF_REVIEW_ONLY.patch` | `071a34f93c4eef448e8d3d452780fff16a2bac5ab1fc1a4258e054224716f4f0` |
| Next sealed V2 review-admission package `TB2_Q25_A16_QS_FILES_ADMISSION_V2.zip` | `a3c1742d0dd2f0519f0d92e4235f7c6a2663995eb828ba20dccd61fb973923e4` |

V2 package is a conversation download, not native source committed to a full Android workspace. It retains the exact Q25 12-path patch in `Q25_QS_FILES_REVIEW_ONLY.patch`, the original receipt, a SHA256 manifest and a **read-only preimage freshness checker**.
It verifies SHA256 for **34/34** source snapshot entries; exact source/trial ZIP bytes; four original patch blobs and scratch success; 10 preexisting source SHA pins + two expected absent new paths; applies all changes **only to a disposable temp directory**. A source drift, collision, path escape or symlink causes `HOLD` (exit 78); no live-source write path exists.

Assistant-host V2 verification: Python syntax PASS, **10/10** actual regression tests PASS (0.080s), real `javac` compile of the **actual generated Q25 `SableFilesKeys.java`** and **22/22** pure Java assertions PASS (text-field focus, Alt shortcuts, selection, delete confirmation routing, Ctrl/Meta passthrough); 15 scratch verification repeats averaged **0.964 seconds per invocation** on assistant host. Review ZIP member CRC PASS and packaged SHA256SUMS PASS. No need for the unavailable `kotlinc` for these Java checks.

## Engineering decision
These patches are **source-context eligible for native compile** on exactly the pinned owner source. `PASS_SCRATCH_APPLIED` is not module compilation, image inclusion, installed role or runtime proof; no full AOSP `build --direct` until original remaining Q25/IMS scope is completed. Promotion to the next-build Android source must preserve the original PR346 interrupted-build workspace and existing output, and must be performed through an explicitly reviewed isolated workspace/revision. No blind native `git apply` or automatic promotion on this receipt.

Open source owners: global Alt+Space framework policy; existing SystemUI Keyguard/QS notification keyboard; Settings UI/privilege; Browser actual installed handler; privileged first-boot SetupWizard; AppLock/Freezer/Vault/profile enforcement; Android 16 SMS role; selected IMS G1/G2/G3. Existing ported PR347 Glance/Home/Hub/Camera/Setup source still needs actual Android compilation and installed runtime acceptance. PR347 pre-build gate remains fail-closed.
