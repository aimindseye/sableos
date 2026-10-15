# N1F PR342 — actual A2H E4 stock-vbmeta provenance PASS; A2I bounded chain self-check handoff

2026-10-14 Titan2 engineering only. PR #342 remains OPEN/DRAFT/UNMERGED. No source/image mutation, LP/AVB mutation, network, build, device contact, restore or flash authority.

## Actual A2H ai-g732 report

Package N1F_P342_A2H_E4_STOCK_VBMETA_RECEIPT_PROVENANCE_V1.zip passed seven internal SHA256 seals, Python AST2+Bash syntax, 42/42 hermetic tests (0.074s). Actual `--inspect --authorize-a2h-e4-small-receipt-readonly` returned `PASS_A2H_ONE_HISTORICAL_E4_RECEIPT_LOCATED_NOT_STOCK_TRUST_READY`, no image bytes read. Exactly one historical E4 six-row SHA256 receipt: `/srv/sable-build/evidence/titan2/n1d-c3b-e4-deployment-readiness/20261003T044503Z/stock-boot-avb.sha256`, SHA256 `c26642d46f2278e76bfe5093659741c6f0d308986f58958a85e4e2f143de1f42`. Two other direct stamp dirs `20261003T043550Z`, `20261003T044032Z` had no exact receipt; correctly classified NOT_EXACT, not ambiguous qualified duplicates.

Three existing regular historical TEE14 stock vbmeta candidates, path root `/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-reference` (NOT earlier `TEE14-large-reference` six dynamic stock image directory):

- `vbmeta.img`: 8192 B; historical E4 SHA256 `58db651a312f3f3f350d11142de55f8c37e1394f1ecea870e6b97a5ae7e0edac`;
- `vbmeta_system.img`: 4096 B; historical E4 SHA256 `4dda8ebc659f2e1db9fdf2977a16224521b738e74ced387caa2bab9f7dfede7e`;
- `vbmeta_vendor.img`: 4096 B; historical E4 SHA256 `5d01ab8a94fcf642d8197a759394541d2aa4689858d8f92283a808ea6f5ca9b7`.

Additional historical E4 restore hash tokens in same validated text ledger: boot.img `cdc1ab40b7016bb3da0713c872e165506f1a29c89259fc2dc8c5539930e96df8`, init_boot.img `35c5219672c8ca1809c1c6c67adbc28c98d83f70fd2c75df010e18d2528bf300`, vendor_boot.img `370b649b6fe1213467f9758fdda89c0c4c86a8c1b770e562b352cf955a6171de`. No current content hashes recomputed. E4 historical validation ≠ Oct03 physical same-session receipt nor proof of OEM bootloader root trust or full matched restore.

## A2I next package (assistant-container validation only)

`N1F_P342_A2I_STOCK_THREE_VBMETA_CHAIN_BOUNDED_V1.zip`, 14,525 B, SHA256 `2467118f6ca6451ff06579a5bd9cdbfe78cfc796405a95d5490d770b0469770b`. ZIP CRC PASS, seven inner SHA256 pins PASS plus SHA256SUMS.txt, Python AST/compile2 PASS, Bash -n PASS, hermetic 44/44 tests from fresh extracted package under umask077 and umask022, including refusal of inspect without exact opt-in. 150 synthetic signed root+two child chain tests after 20 warmups median 0.4967ms/p95 0.6082ms in assistant container, NOT actual ai-g732 production I/O.

**Preflight is ZERO stock image I/O:** verify outer ZIP SHA, fresh unzip, `bash ./n1f_p342_a2i_one_command_v1.sh --preflight`. This reruns manifest SHA7, syntax and tests, prints exact 3 image/path/size/SHA pin plan, expected `A2I_PREFLIGHT_PASS_NO_STOCK_VBMETA_IMAGE_BYTES_READ`.

**Separate stage-specific operator approval required** before `bash ./n1f_p342_a2i_one_command_v1.sh --inspect --authorize-a2i-three-stock-vbmeta-16k-readonly`. Reads exactly 8192+4096+4096=16384 bytes of three specified, previously E4-identified host files; no-follow ancestors/leaf, fstat before/after, compares full file SHA256 against historical E4 pins; parses AVB0, RSA PKCS#1 v1.5 SHA256/SHA512 algorithms 1..6 with embedded UNTRUSTED pubkey, and tag4 root chain-descriptor key hashes for two exact stock vbmeta children. Unsupported/unsigned algorithm, missing/mismatched direct root links, changed images or malformed metadata produce explicit HOLD. If stock OEM uses other chain topology A2I status HOLD is a *scope admission mismatch* needing manual engineering review, NOT permission to modify stock images or proof that device chain is invalid.

Even a future A2I PASS is historical stock host-image SHA equality and crypto self-signature/parent-to-child key structure only: OEM bootloader trust and rollback policy, actual Oct03 physical byte match, candidate A1X 1MiB/AVB footer final LP boundary and matched whole restore remain UNPROVEN. No A1X-derived complete hybrid super is built; historical N1C whole-super wrote but failed boot. Current device/flash actions remain on HOLD.

STATUS: A2H_ACTUAL_RECEIPT_PROVENANCE=PASS; A2I_PACKAGE=SEALED_LOCAL_44_TESTS_PASS; A2I_ACTUAL_HOST=NOT_EXECUTED; STOCK_OEM_TRUST=OPEN; FINAL_LP_AVB=OPEN; MATCHED_RESTORE=OPEN; HYBRID_SUPER_A1X=NOT_BUILT; DEVICE=NO FLASH=NO.