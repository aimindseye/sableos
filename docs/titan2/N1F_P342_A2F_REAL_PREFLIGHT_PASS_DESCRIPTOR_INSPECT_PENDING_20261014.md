# A2F actual ai-g732 preflight PASS — descriptor inspection remains pending

Date: 2026-10-14. PR #342 open/draft/unmerged; SableOS Titan 2 N1F engineering lane. The user approved a hybrid-super deployment strategy, not an automatic flash, AVB mutation, or image-repack authorization.

## Actual operator A2F result

The user returned the original external ZIP SHA check PASS, all eight internal SHA256 entries PASS, A2F_AST=PASS_3, A2F_BASH_SYNTAX=PASS, 37/37 hermetic tests PASS in 0.003 seconds, and final `A2F_PREFLIGHT_PASS_NO_PRODUCTION_IMAGE_BYTES_READ` after the zero-production-image-I/O plan. The selected A1X image is still 3,210,473,472 bytes with historical SHA256 7142c10f85fc18e7a0f72101421324009a17ea2dad895c917f414997951c9a1b (not rehashed by preflight). The Oct03 historical image remains 3,200,540,672 bytes and historical SHA256 dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a (not rehashed). Exact A2E embedded vbmeta SHA pins and frozen source SHA are present in the plan. No A2F production descriptor inspection has been performed.

Assistant independently checked the exact ZIP `N1F_P342_A2F_TWO_SYSTEM_AVB_DESCRIPTOR_SEMANTICS_READONLY_V1.zip`, SHA256 `2279258c40bd6fe179f6c18b84434d271775c2261b2927c015d38292b6aaf8b9`, and confirmed ZIP member inventory, SHA256SUMS 8/8, bash -n and 37/37 tests in an isolated extraction (test runtime 0.004s on assistant host). The wrapper accepts `--preflight` as default, and `--inspect` ONLY with `--authorize-a2f-two-exact-descriptor-readonly`. The inspection reads only 64 footer plus 1728 embedded vbmeta bytes from each exact SHA-pinned input, max 3584 B total, and refuses wrong/mutated byte fingerprints. It reads no entire images and does no input/output image writes or device operations.

## Next exact scoped execution

From the previously verified extracted package on ai-g732, the one read-only opt-in command is:

```bash
bash ./n1f_p342_a2f_one_command_v1.sh \
  --inspect \
  --authorize-a2f-two-exact-descriptor-readonly
```

Successful marker, if obtained: `PASS_A2F_TWO_EMBEDDED_DESCRIPTOR_SEMANTICS_NOT_AVB_OR_SUPER_READY`. A successful structural check does NOT verify AVB signatures, root trust, the full filesystem hashtree, current LP / COW, matched restore, IMS G3, or admission to hybrid-super assembly or flashing. No need to rerun the A2C six-partition 6.89 GB host comparisons, A2D tail, or A2E embedded header checks.

```text
A1X_HOST_IMAGE=PASS_PREVIOUS
A1Y_STATIC_MOUNT_LAYOUT=PASS_PREVIOUS
A2C_HISTORICAL_SIX_BYTE_EQUIVALENCE=PASS_PREVIOUS
A2D_AVB_FOOTER_STRUCTURE=PASS_PREVIOUS
A2E_EMBEDDED_VBMETA_STRUCTURE=PASS_PREVIOUS
A2F_PACKAGE_AND_HOST_PREFLIGHT=PASS_REAL
A2F_DESCRIPTOR_INSPECTION=NOT_EXECUTED
OEM_AVB_TRUST_AND_MATCHED_RESTORE=OPEN
A1X_HYBRID_SUPER=NOT_BUILT
DEVICE_CONTACT=NO FLASH=NO
```