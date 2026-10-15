# PR342 A2C full historical byte-equivalence PASS and A2D AVB-footer boundary handoff

Date: 2026-10-14. Open/draft/unmerged. Operator-selected hybrid-super strategy is unchanged. This is host-side engineering only, not any write or deployment admission.

## Actual A2C ai-g732 result

Explicitly authorized A2C full read-only stream completed with status PASS_A2C_N1C_SIX_REFERENCE_TO_SUPER_BYTES_NOT_OCT03_MATCHED. Script and ZIP internal hashes PASS, Python/Bash syntax PASS, 32/32 hermetic tests PASS (0.098s). All six TEE14 source image contents are byte-for-byte identical to their logical partition extents inside the historical N1C sparse stock super, and each matched the previous SHA256 pin:

- product_a: 1842647040 bytes, de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37
- system_ext_a: 704434176 bytes, 1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170
- vendor_a: 873082880 bytes, cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada
- system_dlkm_a: 7487488 bytes, 2752d357dc698db0967a3bbc9de2204127eab69fa28f7d3471d3e039e4a2946f
- vendor_dlkm_a: 18366464 bytes, 1fc51fb7a2f089b3d9255d00944bda711e64b297daf2ecf687abeae17e0a4936
- odm_dlkm_a: 348160 bytes, ebe714d1ed41742eeb87fa06674900703af97f90f729420fe37555bd02338723

Total comparison = 3446366208 source image bytes plus 3446366208 historical N1C sparse-super logical bytes; no writes, network, device or flash. This closes the historical N1C source-to-super six-partition byte equivalence question. It does NOT establish Oct03 current/physical companion hashes, current LP/VAB/snapshot/COW, OEM IMS native G3, stock boot/AVB/restore chain, or a boot-safe new hybrid super. Do not repeat this expensive six-file verification.

## New A2D V1 next host-only boundary

Package N1F_P342_A2D_TWO_SYSTEM_AVB_FOOTER_BOUNDARY_V1.zip; 12056 bytes; outer SHA256 cbb9c786d8f5725decf0f54c7d10accfd19c060a74aa3d41eaa80f3ce7d232aa. 8 ZIP members: 7 internally SHA256-sealed files plus SHA256SUMS.txt. ZIP CRC PASS. Python AST syntax 2/2 PASS, Bash -n PASS, 35/35 hermetic tests PASS under umask 077 and 022 and 35/35 in fresh checksum-verified ZIP extractions under both. Synthetic 1000 small 8KiB fixture full 320-byte tail inspections median 0.0097ms, p95 0.0176ms in assistant container only, not ai-g732 I/O.

Preflight command after outer ZIP SHA check and fresh extraction: bash ./n1f_p342_a2d_one_command_v1.sh --preflight. It validates package integrity, syntax and tests, and prints a historical LP scenario; it does not access production host images.

Optional explicitly flagged read-only inspect command: bash ./n1f_p342_a2d_one_command_v1.sh --inspect --authorize-a2d-two-system-tail-readonly. It opens exactly two known, historical SHA-pinned system.img paths: active A1X 3210473472 bytes (historical SHA 7142c10f85fc18e7a0f72101421324009a17ea2dad895c917f414997951c9a1b), and the Oct03 historically booted parent 3200540672 bytes (historical SHA dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a), with fd-relative O_NOFOLLOW and exact-size/fstat change guards. Reads at most 64 tail bytes + optional 256-byte vbmeta header for each = at most 640 image bytes. Does not rehash the complete system images. Recognizes AOSP AVBf footer version/offsets and AVB0 header lengths, or reports no-footer; malformed data fail closed. Reports a historical arithmetic seven-candidate LP blueprint only. No avbtool, stock vbmeta chain/signature checks, resized final LP boundary, image mutation, super build, network, device or flash.

A2D positive status PASS_A2D_EXACT_TWO_IMAGE_FOOTER_CLASSIFICATION_NOT_AVB_OR_SUPER_READY is a bounded footer-layout observation ONLY, not cryptographic AVB verification, stock chain match, physical current super matching, first-stage runtime proof or flash authority. Real ai-g732 A2D has NOT been run. N1C historical whole-super flash failed boot; do not repeat any physical action on the basis of this static footer classification.

STATUS: A2C_ACTUAL_N1C_SIX_PARTITION_BYTES=PASS; A2D_PACKAGE_TESTS=PASS_35_BOTH_UMASKS; A2D_AI_G732=NOT_EXECUTED; MATCHED_OCT03_COMPANIONS=UNBOUND; MATCHED_AVB_AND_RESTORE=HOLD; A1X_HYBRID_SUPER=NOT_BUILT; DEVICE=NO; FLASH=NO.