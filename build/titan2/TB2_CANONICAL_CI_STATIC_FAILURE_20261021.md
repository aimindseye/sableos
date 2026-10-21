# TB2 first canonical integrated build — STATIC failure and release applicability fix

**Actual owner build evidence:** `/srv/sable-build/evidence/titan2/track-b-unified-build/20261021T152224Z` from PR346 source revision `4d1b29df627c41c596f74a38c666e4f458949dcc`. Five uploaded files match their recorded hashes for `ci.log` (`88a623f7cd220dbfa046b02250390105e8ec108af29a74673839d93877a22f05`), `product-stage.log` (`3a93a9c47665f6fc45fb38993333023b0b451513da2b89cff8c20ff96eb3b5fd`), `aosp-image.log` (`1eb070aae6ff461b3dc287ab3ea2e4eef759e2907f5ccbec348b9141034f9584`), and `EXIT_CODES.tsv` (`d153cdb3e60ebee7833ea308df7df4fe393d5d0ed6758d5a991bc0ebedac8059`). The host's parent `integrated.log` is textually consistent; independently calculated uploaded SHA256 `336ace4f0d7881211876576ad762f53536640f2646c48629990382ff18ef88b9`.

## What actually failed

- `SABLE_LOCAL_CI_STAGE_POLICY=PASS` and canonical build-regression checks PASS (19 total).
- `SABLE_LOCAL_CI_STAGE_STATIC=FAIL` with **four** active contracts, before any Gradle, Titan2 application task, product stage or Soong system image build.
- `sable-pipeline`: `N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL qualified_product_source_drift_after_import`. This is the **historical N1D-C3B E2** product's immutable source snapshot, **not** the selected TB2 `rom.mk`/13-app/PhhIms product.
- `r9-first-party-app-icon`: R9 contract expects `android:icon="@drawable/ic_sable_messages"` on the Hub's AndroidManifest; PR346 selected Hub intentionally labels itself **Sable Hub** and has `@mipmap/ic_sable_messages` icon while separate `apps/r8/android/messages` has the expected drawable tag. This legacy R9 Hub-as-Messages assumption does not describe the TB2 installed source graph.
- `r9-messages-native-first`: missing R9 `HubPivot.Messages`, Search conversations, `PeopleAlphabetRail` source tokens from the restructured PR346 Hub. **Do not create placeholder UI tokens to appease a historical test.**
- `r9-messages-local-conversation`: missing R9 connected-message retention/reply/history source tokens, again a distinct older Hub-as-Messages contract. The absent UI/privilege functions are **not** automatically considered implemented in TB2; the Q25 Hub and Messages backlog remains OPEN.
- Other visible `FAIL` text (`SABLE_ARTIFACT_REGISTER=FAIL_SHA256` and `FAIL: local CI contract token missing ...`) belongs to intentionally exercised negative fixtures; the enclosing self-tests/policy returned PASS, so not independent build failures.

Observed exit codes: `ci=1`, `product_stage=78`, `aosp_image=78`. The latter two are **skipped due to failed CI**, not separately diagnosed Soong/IMS compile errors. `TB2_BUILD=FAIL_INTEGRATED_BUILD_REVIEW_ALL_LOGS` was the correct stop; no image, device or flash operation occurred.

## PR346 direct canonical source correction

1. `build/local-ci/run.sh`: explicitly propagates device/release to `sable-pipeline-contract.sh`; for **only `titan2 TB2`**, records a visible scope exclusion of three **R9-only** icon/Hub-as-Messages static contracts. On R9 and every other release their original checks remain active. Shared Python/shell syntax, Sable layout, source/Style, security/quality checks and canonical full CI task graph remain unchanged.
2. `build/gates/sable-pipeline-contract.sh`: for **only `titan2 TB2`**, skips the nonselected N1D-C3B E2–E6 historical immutable product, image and deployment lineage contracts. The original checks remain active for R9/N1I and other releases. The global `titan2-flash-regression-contract.py`, general source, host-tool, readiness/security and remaining shared regressions remain in the execution path.
3. `build/titan2/run-track-b-integrated.sh`: now truthfully identifies `IMS_SOURCE_SELECTION=PhhIms_Iwlan_FLOSS_SELECTED_RUNTIME_UNQUALIFIED` and `APP_SOURCE_SELECTION=13_TB2Sable_MODULES_IMAGE_UNQUALIFIED` instead of incorrectly reporting both source selections as pending. No authority or package selection changed.

**No gate has been globally disabled or marked PASS on failure.** The three R9 Hub contracts are **historically inapplicable** to the distinct TB2 Hub+Messages design. Actual TB2 Hub Q25 parity, restricted SMS role and connected conversations are still **source/runtime requirements**, not silently waived. The preconverged AOSP four project commits (`5c3b1776d534`, `b3f1545af6a1`, `807e4aaa29f6`, `f2e4af4caa5d`) and selected product are untouched by this GitHub-only CI source correction.

## Validation and next operation

Original `ci.log` already confirms 262 tracked active Bash scripts had `bash -n` PASS and 93 Python files compiled before failure on the prior revision. Modified branch's *scoped Bash fragments* separately passed local `bash -n`; synthetic execution for `titan2 TB2`, `panther R9`, `titan2 N1I` demonstrated selective skipping only on TB2 and preservation of shared/media/flash-regression paths. Read-only GitHub checks confirmed canonical `run.sh` still executes **one** local full CI and the build driver invokes **one** `m systemimage target-files-package otatools`, after source preflight. No real re-run or Gradle/Soong performance measurement occurred after this fix. A full-file `bash -n` on actual host revision remains to be run, inside the same next canonical workflow preparation.

From the existing clean PR346 checkout `/srv/sable-build/workspaces/titan2-track-b/tb2-pr346-converged-source`, `git pull --ff-only` the branch, `bash -n` the two changed CI Bash files, and run the **same single canonical `bash build/sable.sh titan2 TB2 build --direct`** with retained AOSP root. Do **not** run old `converge-track-b-source.sh --commit` again. The next build may uncover real CI/Gradle/Soong errors; report those from its single integrated evidence directory, no separate module gates.

**Disposition:** `FIRST_CANONICAL_CI=FAIL_STATIC_WRONG_RELEASE_CONTRACTS`; `TB2_RELEASE_SCOPE_FIX_COMMITTED`; `AOSP_NATIVE_COMMITTED_4_PROJECTS_UNCHANGED`; `NEXT_FULL_BUILD_NOT_EXECUTED`; `IMS_Q25_AND_IMAGE_RUNTIME_OPEN`.
