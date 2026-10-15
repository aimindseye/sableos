# PR342 — Actual A2G preflight PASS; bounded self-signature run pending

Date: 2026-10-14. PR remains open/draft/unmerged. This is Titan 2 N1F host-only engineering, not whole-super flash approval.

## Real ai-g732 operator A2G preflight

User supplied actual output: outer `N1F_P342_A2G_EMBEDDED_VBMETA_SIGNATURE_SELFCHECK_V1.zip` SHA PASS, all nine internal SHA256 member checks PASS, `A2G_AST=PASS_4`, `A2G_BASH_SYNTAX=PASS`, 48/48 hermetic tests PASS (0.020 seconds), zero-I/O JSON plan and `A2G_PREFLIGHT_PASS_NO_PRODUCTION_IMAGE_READ`. Production image metadata/header/vbmeta reads were NOT performed in preflight. The full actual A2G inspect result remains PENDING.

Sealed package distribution SHA256 `1c4a0c76254c19e57c80200a70c8297a232296bf35e3ff0ff0bc0e03f2075553` and size 21,969 bytes reconfirmed via independent assistant-container inspection of the exact ZIP. `SHA256SUMS.txt` 9/9 PASS, Bash -n PASS, 48/48 hermetic tests PASS (0.028 seconds assistant environment). Wrapper's exact `--inspect --authorize-a2g-two-embedded-signature-reads` gate was reviewed; direct Python parser defaults to plan and explicitly refuses inspect without flag. Python stdlib SHA256_RSA2048 self-check tests AOSP AVB0 header+aux SHA field and RSA2048 PKCS#1 v1.5 digest signature against the EMBEDDED public key. It checks pinned A2E+F frozen sources and exact A2F vbmeta SHA, reads exactly 64B footer + 1728B vbmeta from each of two existing system images (max 3,584B combined), with fixed nofollow paths/size and fstat identity guards.

Next operator action, from the already verified A2G extraction:

```bash
bash ./n1f_p342_a2g_one_command_v1.sh \
  --inspect \
  --authorize-a2g-two-embedded-signature-reads
```

Expected success marker only if both cryptographic self-signatures pass: `PASS_A2G_BOTH_EMBEDDED_VBMETA_SELF_SIGNATURES_NOT_STOCK_CHAIN_READY`. Any mismatch is HOLD. A pass does not establish verified OEM/stock root of trust, vbmeta_system/vbmeta_vendor chain, true full filesystem hashtree validity, current LP final system_a footer position, matched restore, IMS native G3 or on-device flash readiness. A1X-derived whole super NOT BUILT; no Android builds, output image modification, network, ADB/fastboot, device contact or flash.

Prior A2F actual descriptor classification PASS, A2E embedded metadata structural PASS and A2C historic N1C six-partition source-to-super byte equivalence PASS. Do not rerun full hashes or previous image scans merely to repeat already qualified scope.

```text
A2G_ZIP_AND_ACTUAL_PREFLIGHT=PASS
A2G_CRYPTO_SELF_SIGNATURE_REAL_HOST=NOT_EXECUTED
STOCK_OEM_TRUST_CHAIN=OPEN
FINAL_LP_AVB_BOUNDARY=OPEN
MATCHED_RESTORE_AND_G3=OPEN
HYBRID_SUPER_A1X=NOT_BUILT
DEVICE=NO FLASH=NO
```