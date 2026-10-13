# Titan 2 PR #342 — October 11 parent evidence V2 bounded handoff

Date: 2026-10-13. **Documentation-only review; no new device/source/build/flash authority.**

## Already completed — not repeated

- PR #339 [V17 operator outcome](https://github.com/aimindseye/sableos/pull/339#issuecomment-6133809041): `PASS_BOUNDED_HANDOFF_NOT_FLASH_PROOF`, `POTENTIAL_JOURNALS=0` in the R3 control directory and its immediate parent; the R3 `lpmake-command.txt` is *offline assembly*, not a flash journal.
- Existing R3/R8 inputs already qualified at their own scopes by V16/V36/V37 and PR #342 V1. The six V1 receipts were emitted, exact set verified and SHA-256 sealed. Do not repeat R3 pins, M4 file hash, 991-source project heads, native 56-edge inventory or M4 skip-mount source/staging tests.
- 2026-10-13 GSI skip-mount correction is closed at source/staging scope: actual `system/system_ext/etc/init/config/skip_mount.cfg` SHA256 `0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e`, equals GSI source; `system/etc/init/config` is its compatibility symlink. No final flashed-image/runtime conclusion.
- Oct11 **physical super SHA + flash journal still UNBOUND**, Oct03 physically booted N1F `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a` is *separate fallback*, not an Oct11 identity substitution.
- Oct13 M4 `system_a` flash transport PASS but Android entered Recovery; operator's attempted factory reset failed and phone later entered fastbootd. No Recovery logs. Rescue Party / IMS native-loader explanation remains unproven.

## New delta: only previously unsubmitted operator journal/SHA evidence

The separately distributed (not committed as Android source) bundle `N1F_P342_PARENT_CANDIDATE_V2.zip` is SHA256 `89e5a521606e679e7632c779c092642f89d939e295115901d72bdcbeb0e43849` and contains:

- `n1f_p342_oct11_parent_candidate_v2.py` SHA256 `c01587448d2f4ae271cd1baf54e475420fda65f5554822ad8aa654a9dfb32751`
- `test_n1f_p342_oct11_parent_candidate_v2.py` SHA256 `38ed61a09f969909e2546eb481c728389b9c7ffce6e49a87c314e4a71490cc73`
- README, checksum manifest, local test log.

**Local qualification**: Python AST compile PASS; 16/16 synthetic unittest PASS; measured regression process 0.65 s, max RSS about 100 MiB; filename-only 1,202-entry synthetic directory test 2.35 ms, explicit candidate adjudication 0.49 ms. These are local values **NOT execution results from ai-g732**.

Tool accepts `locate --directory <explicit new folder>`: one-level filename-only (<=1500 entries, max 40 names shown), *never* reads candidate content. Do not revisit V17's covered R3/parent directories, scan all evidence recursively, or access shell history. With **actual** explicitly selected bounded normal text files only, `adjudicate --journal <file> --sha-receipt <file>` distinguishes `fastboot flash super` from `flash system_a`, echo/dry-run and offline `lpmake`; checks literal Oct11 date, send/write OKAY and one exact-path SHA256SUMS-line candidate. A basename-only hash match is **WEAK**, never a promising exact-path candidate. It does *not* hash super image bytes, verify original timestamp, infer runtime equivalence, read host secrets or claim Oct11 parent bound. No shell/host subprocess execution, filesystem mutation or network/device operations.

**Operator command** after obtaining the ZIP from this conversation and unzipping in Downloads:

```bash
cd "$HOME/Downloads"
echo '89e5a521606e679e7632c779c092642f89d939e295115901d72bdcbeb0e43849  N1F_P342_PARENT_CANDIDATE_V2.zip' | sha256sum -c -
unzip -n N1F_P342_PARENT_CANDIDATE_V2.zip
sha256sum -c N1F_P342_PARENT_V2_SHA256SUMS.txt
python3 -B -m unittest -v test_n1f_p342_oct11_parent_candidate_v2
python3 -B n1f_p342_oct11_parent_candidate_v2.py locate --directory "$HOME/Downloads"
```

If `locate` returns no relevant new evidence, **STOP**. Do not re-run the V17 journal locator, broad directory scans or repeat R3/R8 evidence surveys. Present `OCT11_PARENT=UNBOUND` and ask the operator to **explicitly choose** either waiting for an exact parent or authorizing selection of Oct03 N1F as the distinct fallback for offline derived-image planning.

If genuine retained transcript and SHA receipt are found, use the exact paths in `adjudicate` and return the JSON candidate classification for independent review. Even a promising candidate remains `PARENT_UNBOUND` until independent artifact bytes/flash-session/R8 runtime correlation.

**Gates left open:** G1 final flashed image composition, G2 effective APK/classpath/SELinux, G3 recursive native loader/IMS namespace, parent-matched LP/AVB and matched restore. No source mutation, Android build, extraction, mount, reboot, factory reset, device contact, fastboot or flash authority.
