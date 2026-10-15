# A2J real preflight PASS — exact system AVB comparison remains pending

Date: 2026-10-14. PR342 OPEN/DRAFT/UNMERGED. Current A2J preflight does not authorize image assembly, writing, device contact or flash.

## Actual operator A2J preflight result

User supplied `N1F_P342_A2J_STOCK_SYSTEM_AVB_LP_ADMISSION_V1.zip: OK`, eleven internally SHA256-sealed member checks PASS, `A2J_AST=PASS_6`, `A2J_BASH_SYNTAX=PASS`, hermetic `Ran 79 tests in 2.217s OK`, and `A2J_PREFLIGHT_PASS_ZERO_PRODUCTION_IMAGE_IO`. No production image byte reads. Printed LP numbers are HISTORICAL_ARITHMETIC_NOT_LP_BUILDER_ADMISSION, not actual LP geometry or current device free-space qualification.

Assistant independently verified the exact external ZIP SHA256 `fc16473284c43904b8637e3e8b8e51ea1e4802ef2041b69de0964c45884d1ef5`, size 29,733 bytes; fresh extraction hash manifest eleven PASS, `bash -n` PASS, combined inherited A2I+A2J 79/79 tests PASS (3.384s in independent assistant environment). Confirmed wrapper requires the exact `--inspect --authorize-a2j-system-avb-5888b-readonly` opt-in; inspect mode is not a default side effect.

## Exact next stage, NOT YET EXECUTED

From operator's existing checksum-verified A2J extraction, the bounded host read-only operation is:

```bash
bash ./n1f_p342_a2j_one_command_v1.sh \
  --inspect \
  --authorize-a2j-system-avb-5888b-readonly
```

It reads at most 5,888 image bytes total: precisely 4,096B historical E4-pinned TEE14-reference/vbmeta_system.img plus A1X exact system.img 64B AVB footer and 1,728B embedded vbmeta. It compares the stock signed hashtree semantics with A1X self-signed descriptor and independently reports candidate exact 4KiB logical-size vs hypothetical 1MiB rounded footer geometry. It does NOT read stock super, reconstruct super, rehash large files, write data, use network, modify AVB, build Android, contact device, or flash. Operator preflight does not itself grant separate stock/A1X byte-read permission.

Potential success status `PASS_A2J_STOCK_VS_A1X_AVB_DIFFERENCE_RECORDED_OFFLINE_SUPER_BUILD_HOLD` means the difference is recorded, **not** compatible verified boot, lpmake admission or permission to build. Missing input or changed metadata => HOLD, not guessed paths or repairs.

## Retained blockers

A2I historical 16KiB stock vbmeta SHA and three embedded RSA signatures PASS; root vbmeta to system/vendor child public-key links PASS, root→boot link inventoried only. A2G A1X/Oct03 embedded system signatures PASS with untrusted embedded key, which differs from stock `vbmeta_system` child signing key. Bootloader root trust/rollback and verified-boot policy are not established. A1X file exact length 3,210,473,472 B and hypothetical 1MiB LP length 3,210,739,712 B differ by 266,240 B, requiring final footer-at-logical-end proof. Historical six reference stock companions and old LP arithmetic do not demonstrate Oct03 same-session physical contents or current COW/snapshot. No A1X-derived complete hybrid-super artifact built. No matched full restore including dtbo, fresh read-only Titan2 state, or IMS G3 closure. Historical N1C whole-super flash and Oct13 M4 system_a flash failed to boot. Keep offline build authority and physical flash authority distinct.

```text
A2J_REAL_PREFLIGHT=PASS_79
A2J_ACTUAL_SYSTEM_AVB_COMPARE=NOT_EXECUTED
A2J_PRODUCTION_IMAGE_READ=NO
LP_BUILDER_ADMISSION=NOT_EXECUTED
HYBRID_SUPER_A1X=NOT_BUILT
DEVICE=NO FLASH=NO
```