# PR #342 — October 3 N1F parent/source and LP/AVB planning matrix V1

Date: 2026-10-13. **Review only; no source mutation, image read/extraction, build, offline super repack, network, device, reset, restore, fastboot or flash authority.**

## Confirmed selected parent

Operator explicitly selected the physically boot-qualified **October 3 N1F C3A-derived C3B5 `system.img`** as an independent **offline planning parent**. Historic digest: `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`; bytes: **3,200,540,672**; physically successful `system_a` boot. Exact October 11 hybrid `super.img` physical SHA/journal remains **UNBOUND**, and October 13 M4 `system.img` remains **BOOT_FAIL_RECOVERY**, not a parent.

## Existing authority reused — no repeated tests

- [N1F Oct03 build/boot ledger](N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md) and existing [N1F R2 build/flash runner](https://github.com/aimindseye/sableos/blob/main/build/titan2/run-n1f-c3a-derived-c3b5-r2.sh) sealed `artifact.env`, `SHA256SUMS.txt`, derived module and package manifest records, archived C3A `repo-manifest-r.xml` and `all-project-heads.tsv`, `sableos-integration-head.txt` and run evidence. The C3A manifest is captured *before* N1F's seven-file + one-product-inherit delta; file presence alone does not establish subsequent M4 source equivalence.
- Existing N1C postmortem, N1D C0/ E5B Virtual A/B and LP assessments, stock TEE14 recovery evidence and PR #339 R3 LP metadata are **historical references only**. A physically booted Oct03 `system_a` does not prove all `vendor_a/product_a/system_ext_a/odm_a/*_dlkm_a` byte identities and LP group sizes match archived stock or R3.
- PR #339 V17 journal search already negative in its two scoped directories; PR #342 V2 negative filename-only scan in Downloads already sealed. Do not repeat source 991-head audits, targeted M11 compile, five ELF SHA / 56 DT_NEEDED, R3/R8 provenance, V1 receipts or M4 `skip_mount.cfg` source/staging check. The latter is **PASS**, SHA `0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e`, but not flashed-image proof.

## Planning matrix — open exact assertions

| Area | Reusable evidence | Open specific gap |
|---|---|---|
| Oct03 `system.img` | Historic physical boot PASS and archived SHA/size | Current named archive path, small ledger consistency and stat size; **no new image hash** |
| Source lineage | C3A archived resolved manifest/project heads, N1F five-app runner and exact changes | Exact Oct03 derived source relation to later isolated M4 source is not bound merely by file presence |
| Seven logical companion partitions | Historical Titan 2 Virtual A/B slot-A partition list | Oct03-matched bytes, LP group/snapshot state, provider partition identities still NOT_BOUND |
| LP / Virtual A/B | N1D E5B and offline Oct11 R3 layout research | A reproducible Oct03-matched `super.img` recipe/metadata and unchanged partition controls not proven |
| AVB / restore | N1C failed whole-super and qualified historic stock restore materials | Exact matched descriptor chain, boundaries, and restoration plan remain OPEN |
| IMS island | R1/C1 static and targeted M11 compilation, partial R2 native evidence | Preserve embedded `/system/system_ext` and `/system/product`, final G1/G2 and recursive G3 namespace all OPEN |

## Exact next host-only tool

The separately downloadable **`N1F_P342_OCT03_PARENT_MATRIX_V1.zip`** has SHA256 `d2f6e397301d0080ed8a3de3ee25f2e5ee0456ab31e1eb87f2bf1fa9481b086d`. Script `n1f_p342_oct03_parent_matrix_v1.py` SHA256 `7c71d3fd14c58a7f8b43299ee37481b90e26bb31a8193222ff18d0f7ec11aabc`; tests `test_n1f_p342_oct03_parent_matrix_v1.py` SHA256 `f7a7ad9b148c16ab182430f310945f9d6d9db4038aa2f196b879bfb2c19d9535`.

Local Python AST syntax **PASS** both files; synthetic regression **23/23 PASS**, wall **1.31 seconds**, max RSS **97,168 KiB**; local `inspect` wall **0.65 seconds**, RSS **96,268 KiB**. **ai-g732 has not run this V1 tool.** Python 3 stdlib only: fixed exact-path `lstat` and three bounded (<=128 KiB) textual receipts; no project enumeration, image byte read/hash, ELF parsing, `lpdump`, `lpmake`, subprocess, file creation, network, or device action. Captured text receipts are not cryptographic verification of the actual 3.2 GB image.

Run from extracted ZIP in Downloads:

```bash
cd "$HOME/Downloads"
echo 'd2f6e397301d0080ed8a3de3ee25f2e5ee0456ab31e1eb87f2bf1fa9481b086d  N1F_P342_OCT03_PARENT_MATRIX_V1.zip' | sha256sum -c -
unzip -n N1F_P342_OCT03_PARENT_MATRIX_V1.zip
sha256sum -c N1F_P342_OCT03_PARENT_MATRIX_V1_SHA256SUMS.txt
python3 -B -m unittest -v test_n1f_p342_oct03_parent_matrix_v1
python3 -B n1f_p342_oct03_parent_matrix_v1.py inspect
```

Tool stdout reports historical versus current metadata, archived source snapshot, exact-path stock/R3 evidence **as reference only**, and seven `NOT_BOUND_TO_OCT03_PHYSICAL_SYSTEM_PARENT` LP entries. It does **not** make an image or evidence write. If documented `/srv/sable-build` is not the actual operator mount prefix, use only an independently known exact `--artifact-dir`/`--c3a-dir`/`--run-dir` override; no broad search.

**After execution:** identify only the missing exact Oct03 source/LP/AVB authority, or state `UNBOUND`; request separate explicit approval before any image byte inspection, source patch, Android build, offline whole-super assembly, or physical deployment.

```text
SELECTED_PARENT=OCT03_N1F_OFFLINE_PLANNING_ONLY
OCT11_ACTUAL_FLASH_PARENT=UNBOUND
OCT03_MATCHED_SUPER_LP=NOT_BOUND
G1=OPEN_FINAL_IMAGE
G2=OPEN
G3=OPEN
V1_LOCAL_SYNTAX=PASS
V1_LOCAL_TESTS=PASS_23_OF_23
V1_AI_G732=NOT_EXECUTED
SOURCE_MUTATION=NO BUILD=NO IMAGE_READ=NO SUPER_REPACK=NO DEVICE=NO FLASH=NO
```
