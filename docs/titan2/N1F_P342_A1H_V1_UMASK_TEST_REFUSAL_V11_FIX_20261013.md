# PR342 — actual operator A1H V1 regression refusal; V1.1 synthetic test-fixture repair

Date: 2026-10-13 operator local (UTC Oct14). **Source integration did not occur**. Image build was explicitly authorized earlier but technically blocked; no Android build/OUT, super, device, or flash work was undertaken.

## Operator actual A1H V1 results

- Outer `N1F_P342_A1H_EXACT_R1_B1_BUILD_PREP_V1.zip` SHA256 PASS; internal 11 entries SHA256 PASS.
- In **first mandatory A1D+A1G+A1H 128-test suite**, `test_34_apply_tracked_mode` FAILED: expected 420 decimal (octal `0644`), got 384 decimal (octal `0600`). Other 127 tests PASS; full suite FAIL in 0.152s. It is incorrect to continue citing the assistant's prior local 128/128 PASS as actual operator qualification.
- Frozen V1 Bash wrapper starts with `umask 077` and `set -euo pipefail`, followed by `sha256sum -c`, unit tests, zero-I/O plan, then host real readonly inspection. **Therefore the real Ubuntu session stopped before A1H host plan, readonly inspect, apply or any source mutation**. There is no evidence of real A1 source permission error: synthetic source fixtures created by `Path.write_bytes` inherited `0600` because test did not explicitly set a desired canonical Git-tracked `0644` mode. Frozen production source `commit_file` correctly uses `stat.S_IMODE` and `safe_new_file` invokes `os.fchmod` to preserve original permitted modes. This is the same category of fixture-host mismatch experienced earlier on macOS `/var`, but a distinct permission bug.

## Correction — A1H V1.1, independently sealed

External operator ZIP (no executable source committed to PR): `N1F_P342_A1H_EXACT_R1_B1_BUILD_PREP_V1_1.zip` SHA256 **`f35b79ead2f2edf07bece4b4a800c3f88b840e68e4075ce37460fcfbef5605b8`**, **32,454 bytes**. Main `n1f_p342_a1h_exact_r1_b1_v1_1.py` SHA256 `fda0d0edf71d46b9f6413625be020ea59da650fb0c8e899414995c838601814a`.

**Production algorithm byte identity check PASS:** original A1H V1 main vs V1.1 main differ only in `VERSION = '1.0'` to `VERSION = '1.1'`; exact R1/B1 PRE/POST pins, selected physical A1 root, dirfd `O_NOFOLLOW`, write staging/fsync, original-mode preservation, marker and out-a1 protection, non-resume policy remain unchanged. Reused A1D inspector SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777` and A1G SHA256 `9fb76d6dfedc2675a76da84f6b5c4d1e8fa64e9a0c90f41dcebc72c4b7aeca6b` unchanged.

The **test fixture only** now explicitly `os.chmod(f, 0o644)` for constructed R1 and B1 PRE files before tests; `test_34` checks **both** original `0644` modes after replay. Four additional regressions: `0600` source mode preserved with restrictive umask; `0444` mode preserved; unexpected `0755` input refuses without source change; fixture mode is explicit. No production `chmod 0644` or weakening of `umask`.

Local assistant validation: ZIP CRC and **11/11 inner SHA256 PASS**, AST+compile 6/6 PASS, Bash syntax PASS; **132/132 A1D+A1G+A1H regressions PASS under `umask 077` (0.258s) AND `umask 022` (0.256s)**. Additional freshly unzipped archive, `umask 077`, **132/132 PASS (0.264s)**, default plan `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO`, `build_ready=false`, version `1.1`. A synthetic 541,677-byte R1 preview 220-run median/p95 0.75867/0.88978ms is **not** actual ai-g732 performance. V1.1 real ai-g732 host inspect/source apply NOT EXECUTED.

## Next ai-g732 action

Discard V1 attempt, preserve the original A1 checkout, no-build marker and missing `out-a1`. Verify **new V1.1** outer ZIP checksum, extract to a **new** temp directory, `sha256sum -c SHA256SUMS.txt`, then run `bash ./n1f_p342_a1h_validate_and_inspect_v1_1.sh`; this reruns QA with **same restrictive umask** and only performs the previously authorized exact selected A1 read-only R1/B1 post preview. When and ONLY when the wrapper reports `PASS_EXACT_R1_B1_POST_PREVIEW_NOT_BUILD_READY`, user may run `python3 -S -B n1f_p342_a1h_exact_r1_b1_v1_1.py apply --authorize-exact-a1-r1-b1-source-replay` under previously granted exact A1-only source prep authority. Partial or refused output => STOP, preserve evidence, do not blindly rerun/cleanup.

Even a full A1H PASS is **SOURCE_ONLY_NOT_BUILD_READY**; `.repo`/Kati/Soong, staged six C1 IMS modules and exact APK/JAR/XML, PHH marker, G1/G2/G3 new artifact, original Oct03 TrebleApp post-state/369 patch and Git object independence all remain separate; image build technically held, while user build authorization remains granted. Never run historical combined N1F build+flash driver as a build-only workaround. No device/flash/super authority.

```
A1H_V1_REAL_UBUNTU_PACKAGE=PASS
A1H_V1_REAL_UBUNTU_SYNTHETIC=FAIL_1_OF_128_UMASK_FIXTURE
A1H_V1_REAL_HOST_PLAN_INSPECT_APPLY=NOT_EXECUTED
A1H_V11_ASSISTANT_ZIP_AST_BASH=PASS
A1H_V11_ASSISTANT_SYNTHETIC_UMASK077=PASS_132_OF_132
A1H_V11_ASSISTANT_SYNTHETIC_UMASK022=PASS_132_OF_132
A1H_V11_OPERATOR_REAL=NOT_EXECUTED
A1_NO_BUILD_MARKER=PRESERVE
BUILD_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 remains OPEN/DRAFT/UNMERGED; this document records a real refusal and repair validation, not a retroactive PASS.