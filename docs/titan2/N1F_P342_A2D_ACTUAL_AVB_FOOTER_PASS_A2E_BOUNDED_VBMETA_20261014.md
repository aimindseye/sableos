# A2D actual PASS and A2E bounded embedded-vbmeta handoff

Date: 2026-10-14. PR #342 remains OPEN/DRAFT/UNMERGED. User-approved hybrid-super engineering strategy remains distinct from a flash-qualified artifact or device-write authorization.

## Actual ai-g732 A2D result

Operator reported A2D inner SHA7 PASS, Python/Bash syntax PASS, 35/35 synthetic regressions PASS. Exact two-system tail/optional header inspection completed: `PASS_A2D_EXACT_TWO_IMAGE_FOOTER_CLASSIFICATION_NOT_AVB_OR_SUPER_READY`. Both A1X new system.img and historically booted Oct03 system.img have parseable AVBf footer version 1.0 and embedded AVB0 header, required libavb version 1.0, embedded vbmeta size 1728 bytes. New A1X image size 3210473472, original_image_size 3159728128, vbmeta_offset 3209797632; October 3 size 3200540672, original_image_size 3149955072, vbmeta_offset 3199864832. Full-image SHA pins historical not rehashed. No AVB cryptographic verification, no stock chain check, no matching physical Oct03 companions or restore qualification performed.

Important AVB/LP warning: A1X 3210473472-byte file length versus hypothetical 1MiB-aligned LP length 3210739712 leaves 266240 bytes, so a future LP composition that pads the partition must reconcile final AVB footer placement/size. The October 3 image also has a 1MiB-alignment difference. Do not infer from this calculation that the device failed, that 1MiB padding is mandatory, or that footer rewriting is authorized.

Prior seals remain: A1X image internals 16/16+IMS signer/SELinux PASS; A1Y GSI static skip_mount PASS; A2B three-slot historical N1C LP geometry/metadata checksums PASS; A2C six historical N1C source image -> stock-super extent bytes and SHA identities PASS. None certifies current Oct03 physical companion identity, stock verified boot chain, matched restore, G3 runtime namespace or a ready whole-super flash.

## Sealed next A2E V1

Archive `N1F_P342_A2E_EMBEDDED_VBMETA_BOUNDARY_READONLY_V1.zip`, 12101 bytes, outer SHA256 `70e862523498fa4eb09ae949e9b7121b5fbe5ac1ad467de6f5b7fb14b7d0cde0`; 8 ZIP members (7 internally SHA256-sealed plus SHA256SUMS.txt). ZIP CRC PASS, internal SHA7/7 PASS, Python AST+compile both PASS, Bash `-n` PASS. 38/38 hermetic tests PASS from checksum-verified fresh extractions under umask077 and 022. Assistant-container synthetic 700 8192-byte file inspections median 0.014712ms, p95 0.019319ms; synthetic 1000 bounded 1728-byte parser calls median 0.006570ms, p95 0.007992ms. Synthetic measurements ONLY; real ai-g732 A2E NOT EXECUTED.

Safe preflight after independent ZIP SHA check and isolated extraction: `bash ./n1f_p342_a2e_one_command_v1.sh --preflight`. This checks manifest/syntax/tests and displays ZERO production host image I/O plan. Separately flagged host-only read: `bash ./n1f_p342_a2e_one_command_v1.sh --inspect`. This reads exactly 64B AVB footer + 1728B embedded vbmeta per exact A1X and Oct03 input, total at most 3584 bytes, no full-image hashing, stock vbmeta read, avbtool, LP tools, writing, Android build, network or device. fd-relative O_NOFOLLOW, expected size and fstat identity protect bounded reads. `PASS_A2E_BOUNDED_EMBEDDED_VBMETA_METADATA_NOT_AVB_OR_SUPER_READY` is a structural metadata classification only.

Parser follows the public AOSP libavb AVB0 256-byte header/auth/aux offsets (not any custom crypto substitute), validates descriptor tags and lengths, reports alg/key-byte SHA fingerprints/flags/rollback metadata without claiming signed trust. Complete signature/root public-key, AVB chain/digest verification, exact target LP footer at final partition boundary, matching boot+vbmeta restore and current device LP/COW must be verified separately. A2E does not assemble super or mutate AVB.

STATUS: A2D_TWO_FOOTERS=PASS_ACTUAL_STRUCTURAL_ONLY; A2E_ZIP_AND_TESTS=PASS_38_BOTH_UMASKS; A2E_REAL_AI_G732=NOT_EXECUTED; A1X_HYBRID_SUPER=NOT_BUILT; MATCHED_AVB_RESTORE=HOLD; DEVICE=NO FLASH=NO.