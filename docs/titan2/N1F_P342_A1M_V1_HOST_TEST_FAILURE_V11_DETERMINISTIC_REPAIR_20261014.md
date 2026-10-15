# PR342 A1M V1 real-host test isolation refusal and corrected V1.1 package

Date 2026-10-14, ai-g732. A1L source POST and A1F–A1L remain complete and frozen. Operator requires **all technical gates closed before build**.

## Exact operator result

Original `N1F_P342_A1M_ALL_GATES_READONLY_V1.zip` checksum and all 9 internal member hashes PASS. In `===== A1D / A1M PREBUILD REGRESSIONS =====` the 103-case test suite failed exactly one case:

```
FAIL: test_cli_missing_path_explicit (test_n1f_p342_a1m_all_gates_readonly_v1.PathsAndPlan.test_cli_missing_path_explicit)
AssertionError: 0 != 4
Ran 103 tests in 0.166s
FAILED (failures=1)
```

The original test `with redirect_stdout(...): self.assertEqual(m.main(['inspect',m.FLAG]),4)` **incorrectly used the real default A1/BOX/M4/AUDIT paths**, expecting they would be missing because they had been absent in the assistant-local sandbox. On the populated build host, production `inspect()` was invoked read-only during the test and `main()` returned **0**, which is the correct success code for a complete controlled `HOLD_A1M_ALL_PREBUILD_GATES_NOT_COMPLETE` report as well as other non-refused read-only output. The test suppressed its own stdout, and wrapper `set -e` terminated before the separately labeled actual inspected JSON was printed. **Do NOT conclude build-ready or infer complete gate outcomes from return code 0 alone**. This failure does not indicate source drift; it is a test-environment isolation defect. No Android source writes, staging, build, super, device, flash or network executed.

## V1.1 corrected external package

`N1F_P342_A1M_ALL_GATES_READONLY_V1_1.zip`, **SHA256 `0a932398bd2c9c6d3ea8084e0ea5f568d9c7fb403adb896f59832faea0793b93`**, **24,890 bytes**. **Production A1M inspector unchanged, SHA256 `00fd3edd2b5b842bbb24a8fab9838063846e962464f14c69ba4bf591186da544`**. Original A1D nofollow helper unchanged, SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`. No change to 10 exact selected-source SHA pins, B1 blob, six C1 payload candidate pins, five app model, five N1I-A evidence pins, 13 admission gate categories, refusal status, version `1.0` of unchanged inspector, safe path reads or permanent build_ready=false.

Only QA/test/packaging changed: CLI missing A1 path test injects explicit freshly allocated **nonexistent temporary source paths** into original inspect, expecting exit 4 and exact JSON refusal; new CLI-HOLD fixture tests expected exit 0, build_ready=false/writes=false; optional bundle missing test now operates under its own fresh temp directory. New wrapper `n1f_p342_a1m_validate_and_inspect_v1_1.sh` runs SHA, tests, zero-I/O plan, then actual bounded read-only inspection; ZIP docs explain outputs. Synthetic suite increases from 103 to **104** tests.

Assistant-local validation (NOT real ai-g732): ZIP CRC PASS (10 members), **9/9** inner SHA256 PASS, Python AST+bytecode **4/4** PASS, Bash `bash -n` PASS, **104/104 tests PASS under both `umask 077` and `022`** (roughly 0.08–0.09s), fresh ZIP extracted under each umask 104/104 PASS (0.094s each), zero-host-I/O `plan` PASS. No Android build or A1 read was attempted in these local tests.

**Next ai-g732 command**: independently verify ZIP SHA, fresh unzip, run `bash ./n1f_p342_a1m_validate_and_inspect_v1_1.sh`. Expected consolidated JSON `HOLD_A1M_ALL_PREBUILD_GATES_NOT_COMPLETE`; it is a successful **inspection**, not build permission. `REFUSED_A1M_SOURCE_DRIFT_OR_UNSAFE_INPUT_STOP` remains terminal and requires independent investigation. No user-supplied app-bundle/stock-CIL path has yet been qualified; do not guess optional arguments or import retained M4 payloads merely by content match.

Outstanding prebuild requirements remain: stock extraction/provenance binding for six C1 payload files, five Sable unsigned app build receipts, C1 property.te stock CIL attribution, compiled policy and signing, independent 991 project Git `.repo` metadata and object stores, Oct03 patch/TrebleApp exact source fidelity, evaluated Android16 product graph; then postbuild effective skip_mount/marker/BCP/G1/G2/G3 before device decision. User host-only image build authorization remains recorded but **technical BUILD_READY=NO**. Preserve `.A1_INCOMPLETE_DO_NOT_BUILD` and no `out-a1`; no build/device/super/flash.

```text
A1L_ACTUAL_HOST_SOURCE=PASS_POST
A1M_V1_ACTUAL_HOST_REGRESSION=FAIL_NONISOLATED_TEST_EXPECTED_4_GOT_0
A1M_V1_ACTUAL_HOST_FORMAL_REPORT=NOT_CAPTURED
A1M_V11_ASSISTANT_PACKAGE=PASS_ZIP_SHA9_PY4_BASH_TEST104_TWO_UMASKS
A1M_V11_ACTUAL_HOST=NOT_EXECUTED
BUILD_AUTHORIZED_HOST_ONLY=YES
BUILD_TECHNICAL_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 remains OPEN/DRAFT/UNMERGED.