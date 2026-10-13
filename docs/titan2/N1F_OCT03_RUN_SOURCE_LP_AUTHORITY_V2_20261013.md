# PR #342 — Oct03 N1F run-log, source, LP authority V2 handoff

Date: 2026-10-13. **Tool produced and locally validated; operator ai-g732 execution NOT RUN.** Documentation-only PR; external Python evidence tool is distributed in the ChatGPT bundle, **not added to the Android/build/flash path**.

## What previous research already did

1. Oct03 N1F `system_a` historical physical boot PASS and five-app presence; sealed historical digest `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, 3,200,540,672 bytes, operator-selected as independent **offline planning** parent. The actual Oct11 hybrid super flash-journal and SHA remain unbound. The Oct13 M4 candidate entered Recovery and is not a booted parent.
2. The existing `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh` **already** enforced exact device fastbootd mode, current-slot `a`, snapshot-update-status `none`, preflash `system_a` size, no active-slot COWs, a **single** `flash system_a`, postflash size/slot/snapshot, reboot and `sys.boot_completed=1` with five apps. These historical *script semantics* and prior boot result must not be confused with new device or LP state; nothing needs to rerun physically.
3. The original runner saved `run.log` under `/srv/sable-build/evidence/titan2/n1f-c3a-derived-c3b5-r2/20261003T221350Z` and C3A source snapshots under `/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z`. It copied the **exact pre-N1F C3A control/fastboot preflight directories** into that C3A archive, and captured its C3A project heads before the seven-file + one-inherit N1F delta.
4. PR #342 Oct03 matrix V1 **operator PASS 23/23** already established the archived `system.img` regular-file stat size, `artifact.env` and `SHA256SUMS.txt` consistency, and manifest/run-evidence file presence, with **NO image byte reads**. All seven companion LP inputs, LP/Virtual A/B groups, AVB/restore **UNBOUND**. Existing N1C/N1D E5B/Oct11 R3 controls cannot be silently attributed to the Oct03 physical session.
5. Do not repeat: 991-source head census, repo sync, M11 compile, R2 five native identities/56 edges, M4 skip-mount source/staging SHA, Oct11 journal V17/V2 searches, system image hashing, E5B geometry/device probes, or broad directory inventories.

## Exact V2 new delta

**Bundle** `N1F_P342_OCT03_RUN_AUTHORITY_V2.zip` SHA256 `585b4729925812993e8e6a451a484344ed8983b64d5ab0c43bb3cf7e7dc125a9`.

- `n1f_p342_oct03_run_authority_v2.py`: SHA256 `aaddec645a3dc583bf4d612d5bcffb54bbc1f0878c4df4f2ab3c8a16c9e85559`; Python 3 stdlib only, no subprocess.
- `test_n1f_p342_oct03_run_authority_v2.py`: SHA256 `408383ec8c7c3d3264bb0c7f0ea3ccd76a5d1f9fc16867d67f6edfefa89359db`.
- README, engineering review, test log and SHA256 manifest included; ZIP archive integrity and manifest were verified.

The script does precisely three things in bounded fixed locations: (a) read **first and last 96 KiB** of the Oct03 archived `run.log` (or whole log if at most 192 KiB), classify six literal run-script status lines and their order; (b) read a <=256 KiB archived C3A `all-project-heads.tsv` for *counts only*, and check the exact original copied C3A preflight directories via metadata; (c) optionally compare a **user-supplied exact existing** M4 two-column project-heads TSV or an exact text Oct03 LP receipt, explicitly *without* promoting either to derived artifact equivalence or seven-partition LP evidence. Optional paths are NOT searched or guessed.

**Local validation:** Python AST syntax PASS both Python files; **27/27 unittest PASS**; test process 0.86 seconds max RSS 100,760 KiB; synthetic 991-head TSV + 1 MiB log, 100 timed inspections median **1.711 ms** and p95 **2.193 ms**; local default inspect 0.69 seconds and 96,520 KiB. Bash operator command snippet syntax PASS. **ai-g732 run NOT EXECUTED yet.** Local benchmarks are not host performance claims.

**Boundary:** status-line sequence consistent with `N1F_R2=PASS` is an archived **system_a-only runner observation**, not independent original physical flash-byte audit or LP/AVB snapshot. Refuse binary/symlink/oversize inputs, restrict optional types to small explicit text, print no raw logs, serials, or paths discovered from content. No Android source writes, build, system.img read or hash, `git`, `repo`, `lpdump`, `lpmake`, flash, device, network or output file creation.

## Operator commands (only after downloading ZIP from this conversation)

```bash
cd "$HOME/Downloads"
echo '585b4729925812993e8e6a451a484344ed8983b64d5ab0c43bb3cf7e7dc125a9  N1F_P342_OCT03_RUN_AUTHORITY_V2.zip' | sha256sum -c -
unzip -n N1F_P342_OCT03_RUN_AUTHORITY_V2.zip
sha256sum -c N1F_P342_OCT03_RUN_AUTHORITY_V2_SHA256SUMS.txt
python3 -B -m unittest -v test_n1f_p342_oct03_run_authority_v2
python3 -B n1f_p342_oct03_run_authority_v2.py inspect
```

**Stop criteria:** If the Oct03 run log is missing/oversize or the six exact markers are not observed in the bounded window, classify `NOT_QUALIFIED` or `NOT_OBSERVED_IN_BOUNDED_EXCERPTS`, do not infer a failed historical boot. If markers are ordered, mark only `HISTORICAL_RUN_SCRIPT_SYSTEM_A_ONLY_STATUS_NOT_LP_BYTES`. All seven slot-A companion partitions stay `NOT_BOUND_TO_OCT03`; no Oct03-matched LP/AVB or restore PASS, no unified embedded IMS G1/G2/G3 PASS. Subsequent image extraction, source changes, offline `super.img` assembly, device contact, or flash require **distinct, explicit approval**.

```text
OCT03_SELECTED_PARENT=OFFLINE_PLANNING_ONLY
OCT11_FLASHED_HYBRID_PARENT=UNBOUND
V2_LOCAL_SYNTAX=PASS
V2_LOCAL_TESTS=PASS_27_OF_27
V2_AI_G732=NOT_EXECUTED
OCT03_SEVEN_LP=UNBOUND
OCT03_LP_AVB_RESTORE=UNBOUND
G1_FINAL_IMAGE=OPEN G2_EFFECTIVE_POLICY=OPEN G3_IMS_NAMESPACE=OPEN
SOURCE_MUTATION=NO BUILD=NO IMAGE_READ=NO SUPER_REPACK=NO DEVICE=NO FLASH=NO
```
