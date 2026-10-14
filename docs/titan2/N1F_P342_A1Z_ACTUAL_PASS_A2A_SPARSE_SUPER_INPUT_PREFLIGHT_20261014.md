# PR342: actual A1Z PASS; A2A stock-super sparse-header preflight

Date: 2026-10-14. PR open/draft/unmerged. Operator approved a hybrid-super deployment strategy, but no exact whole-super image or write command passes required companion/LP/AVB/restore gates yet.

## A1Z actual ai-g732

Outer and seven internal ZIP checksum entries PASS, Python/Bash syntax PASS and 25/25 hermetic tests PASS (0.096s). Actual result: PASS_A1Z_PINNED_N1C_RECEIPT_CLASSIFICATION_NOT_MATCHED_SUPER_READY; errors empty. Four A1Y-pinned text receipts SHA/size/lines all PASS. Six N1C TEE14 stock-reference SHA256 tokens each present once: product_a, system_ext_a, vendor_a, system_dlkm_a, vendor_dlkm_a, odm_dlkm_a. Seven rows in three receipt tables additionally name system_a. One unrecognized 64hex token is UNCLASSIFIED, not an inferred mismatch or an odm_a image identity. No stock partition image bytes were read. Same-session Oct03 companion hashes, LP/COW, AVB, matched restore, G3 remain UNBOUND.

A1X active SableOS system.img SHA256 7142c10f85fc18e7a0f72101421324009a17ea2dad895c917f414997951c9a1b, 3210473472 bytes, previously verified 16 image members, IMS signing/SELinux PASS. A1Y static installed skip_mount and compatibility symlink PASS, but real first-stage runtime mount behavior NOT TESTED. Do not rerun A1X/A1Y/A1Z or earlier stock receipt directory census.

## New A2A V1 sealed package

N1F_P342_A2A_FIXED_STOCK_SUPER_INPUT_PREFLIGHT_V1.zip — outer SHA256 8e71795d0c0519ddfdc1c7b81b684d6154a315419bceec59990ab57c4792f95c, bytes 11302, eight ZIP entries, seven internal SHA256-sealed files.

After outer ZIP checksum verification and fresh extraction run bash ./n1f_p342_a2a_one_command_v1.sh. Wrapper checks internal SHA, Python AST2, Bash syntax, 36 hermetic tests, plan, then explicitly read-authorizes a fixed-path 28-byte Android sparse header and lstat metadata screen. Direct Python unflagged invocation defaults to ZERO HOST IO PLAN.

Read-only exact inputs: historic N1C sparse super candidate /srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124/titan2-stock-v010014-super-restore-r1c.sparse.img (previous R0 metadata size 4189766872 bytes); six known TEE14 reference partition paths checked only for historical sizes; active A1X image checked ONLY for regular file size (no repeated 3.21GB hash); five canonical LP/AVB host tool file mode/size metadata only, WITHOUT EXECUTION. Sparse header expected raw super size 9663676416 bytes. No source images read beyond 28 header bytes, no recursion, no LP metadata extraction, no super repack, no network/device/flash.

Historical arithmetic using 3210473472-byte A1X system and six N1C size references: unaligned total 6656839680, 1MiB-aligned candidate sum 6660554752, arithmetic difference from pre-C3A main_a max 9661579264 is 3001024512. NOT A VALID LP FIT APPROVAL: missing odm_a and current per-slot LP, VAB COW/snapshot, reserve, AVB and physical partition matching. Successful A2A can say only PASS_A2A_STATIC_STOCK_INPUT_SCREEN_NOT_MATCHED_SUPER_READY; a malformed/unsafe candidate returns HOLD.

Local QA: ZIP CRC+SHA7, AST and compile2, Bash -n PASS; 36/36 hermetic tests PASS, and checksum-verified fresh extracted 36/36 PASS under BOTH umask077 and 022. Negative tests: malformed Android sparse v1 header, incorrect raw geometry, changed size, symlinks/path traversal, missing candidate/tool, no LP/device execution. Synthetic 700 bounded fixture inspections median 0.0963ms/p95 0.2183ms; 1000 header-only reads median 0.0084ms/p95 0.0120ms. Not measurements of ai-g732 4.19GB storage, LP analysis or build performance.

Actual ai-g732 A2A NOT RUN. No super assembled or flashed, and no device contacted by this action. G1 static PASS, G2 A1X host image PASS at bounded scope, G3 and matched stock restore still OPEN. Physical whole-super deployment cannot be admitted without exact future LP/AVB/companion matching and fresh device/restore gates.