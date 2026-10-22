# PR347 — existing Track B Native25 module operator V1.1 symlink preflight correction
Date: 2026-10-22; **AOSP module build not yet started**.

## Operator observed
Actual AI-G732 output:
```
NATIVE25_EVIDENCE=/srv/sable-build/evidence/titan2/pr347-native25-20261022T150925Z
TRACK_B_NATIVE25=HOLD_ValueError symlink in source path: build/envsetup.sh
```
Cause: `source_root()` wrongly applied the intended **writable source** no-symlink rule to AOSP's read-only build infrastructure `build/envsetup.sh`, which may be a repo-managed symlink into `build/make/envsetup.sh`. The failure happens **before any source staging and before evidence creation**. It was not an Android source/compiler error, nor a need to create another checkout.

## Exact V1.1 correction
- Preserve exact Native25 input Git/snapshot/overlay SHA256 `ea53ce44507575d9bf9fb399f4a8f63ab6c1e4c330428d69f469f8dbc1ee12f0`, 25 qualified postimages, 17 replacements, eight new source paths, and quarantine of generic Dialer Q25 0703.
- Only in `source_root()`, allow `build/envsetup.sh` to be a symlink **if** `resolve(strict=True)` produces a real regular file contained within the same Track B `android/build/` directory. Regular envsetup files remain valid.
- Fail closed for escaping symlinks, other checkouts, missing/broken links, directory targets; keep the original no-symlink rule in all 25 staged and backup/restore source paths and their ancestors. No generic symlink bypass.
- No `repo sync`, checkout creation, source clean/reset, `OUT_DIR` override, image build, device action or flash. User's next `bash operator.sh run <FRESH_EVIDENCE> 4` will intentionally stage approved source into Track B after normal SHA guard and run targeted incremental `m -j4 SystemUI DocumentsUI services` in existing `out/`. Protect with external tmux.
- V1.1 replaces V1; the old evidence name may be unused but always choose a fresh evidence path.

## Delivered artifact and validation
`TB2_PR347_TRACK_B_NATIVE25_MODULE_V1_1.zip` SHA256 `4cc3ab04eee61eacf528493d848196e5390318303626bc248efec90c8fbdf389` (829,479 bytes, 9 files). Includes full corrected script, source diff V1→V1.1, test suite, unchanged sealed Native25 archive, README and validation log.

Assistant-host validation:
- **21/21 Python tests PASS**, including original 15 rollback/drift/restore/compile-mock regressions plus six new symlink cases.
- Positive: AOSP-style relative envsetup symlink `build/envsetup.sh -> make/envsetup.sh` sources through the normal mock `bash -c` build path, compiles all three mocked module names, preserves existing incremental `out/`, and restores all 25 originals.
- Negative: outside checkout, other checkout, broken/missing target, directory target, and staged-source symlink all HOLD before Android writes.
- Python py_compile, Bash `-n`, SHA256SUMS (8 members), ZIP CRC (9 members) PASS. Extracted ZIP independently rerun **21/21 PASS**.
- 12 repeated sealed Native25 contract decodes: **0.053 seconds total** on assistant host (metadata+input hashing), not actual Soong compile performance.
- **No AI-G732 execution or native AOSP module result** in this correction turn. PR347 full Q25/IMS readiness gate remains HOLD, and pinned PR346 remote HEAD remains `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`.
