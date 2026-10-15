# A2I real ai-g732 preflight PASS; exact 16 KiB historical stock AVB inspection awaits approval

Date: 2026-10-14. Titan 2 PR342 OPEN/DRAFT/UNMERGED. This is read-only host engineering; no source mutation, Android build, LP/AVB mutation, device contact, recovery, reset, slot switch, or flashing.

## Actual operator report

User reported external `N1F_P342_A2I_STOCK_THREE_VBMETA_CHAIN_BOUNDED_V1.zip: OK`; seven sealed inner members SHA256 PASS, Python AST2/Bash syntax PASS, 44/44 hermetic regressions PASS (1.997s), zero-production-host-image-I/O JSON plan and terminal `A2I_PREFLIGHT_PASS_NO_STOCK_VBMETA_IMAGE_BYTES_READ`. No actual `--inspect` JSON yet. The preflight **does not rehash or inspect** three historical stock vbmeta images or re-open the historical E4 SHA256 receipt.

Assistant independently verified exact archived ZIP SHA256 `2467118f6ca6451ff06579a5bd9cdbfe78cfc796405a95d5490d770b0469770b`, extracted fresh and checked SHA256SUMS 7/7, AST2, Bash `-n`, 44/44 tests (3.028s assistant host), wrapper default preflight (44/44 tests again), and explicit refusal of `--inspect` lacking exact authorization flag. Local read of frozen shipped A2I source shows exact three fixed nofollow paths, before/after fstat identity, complete bounded file read of three files of 8192+4096+4096=16384 bytes, SHA256 equality to historic E4 pin, AVB0 header/descriptor and embedded RSA check for supported AOSP alg IDs 1..6, and direct root tag4 key/partition references to vbmeta_system and vbmeta_vendor. Unexpected missing direct links, unsigned alg or unsupported algorithms yield HOLD; this is a *script's narrow expected topology*, not evidence that alternate OEM AVB layouts are invalid.

## Exact next scoped action, NOT YET AUTHORIZED

Existing A2I extracted package only; operator must separately explicitly authorize the following **one bounded read-only** command before execution:

```bash
bash ./n1f_p342_a2i_one_command_v1.sh \
  --inspect \
  --authorize-a2i-three-stock-vbmeta-16k-readonly
```

Root `/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-reference`, three exact leaves: `vbmeta.img` 8192B historical E4 SHA 58db651a312f3f3f350d11142de55f8c37e1394f1ecea870e6b97a5ae7e0edac; `vbmeta_system.img` 4096B SHA 4dda8ebc659f2e1db9fdf2977a16224521b738e74ced387caa2bab9f7dfede7e; `vbmeta_vendor.img` 4096B SHA 5d01ab8a94fcf642d8197a759394541d2aa4689858d8f92283a808ea6f5ca9b7. Previous A2H identified unique historical E4 receipt `.../20261003T044503Z/stock-boot-avb.sha256` SHA256 c26642d46f2278e76bfe5093659741c6f0d308986f58958a85e4e2f143de1f42. No other image reads, directory recursion, network, build, output writes, device operations or flash.

Only if real stock run returns `PASS_A2I_HISTORICAL_STOCK_SELF_SIGNATURES_AND_TWO_CHAIN_KEYS_NOT_OEM_TRUST_READY` can the restricted host historical chain topology be marked PASS. No OEM root-of-trust or device rollback fuse observation, Oct03 physically matched companions, final A1X LP/AVB footer position, full filesystem hashtree, stock recovery or flash authority can follow. The offline A1X-derived complete hybrid super has NOT been assembled; N1C whole-super physical write historically failed to boot.

```text
A2I_REAL_PREFLIGHT=PASS_44_OF_44
A2I_REAL_STOCK_IMAGE_INSPECTION=NOT_EXECUTED
A2I_16K_READ_STAGE_APPROVAL=NOT_YET_GRANTED
HISTORICAL_A2H_E4_RECEIPT=PASS
A2G_TWO_EMBEDDED_VBMETA_SELF_SIGNATURES=PASS_PREVIOUS
STOCK_OEM_TRUST_AND_FINAL_AVB_LP=OPEN
HYBRID_SUPER_A1X=NOT_BUILT
DEVICE=NO FLASH=NO
```