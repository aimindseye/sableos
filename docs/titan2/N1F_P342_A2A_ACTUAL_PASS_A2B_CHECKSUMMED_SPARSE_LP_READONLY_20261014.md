# A2A actual PASS and A2B host-only LP gate — 2026-10-14

PR #342 open/draft/unmerged. Operator selected hybrid-super deployment as strategy. No exact complete A1X-derived super or safe flash command is qualified.

## A2A real ai-g732

Package SHA integrity/syntax/36 regression tests PASS. Actual status PASS_A2A_STATIC_STOCK_INPUT_SCREEN_NOT_MATCHED_SUPER_READY; errors empty. N1C TEE14 historic sparse stock super 4,189,766,872 bytes, sparse v1 block size 4096, 97 chunks, declared raw 9,663,676,416 bytes. Six known historical stock-reference logical image paths and sizes present; odm_a remains unbound. A1X system.img 3,210,473,472 bytes; historical host hash pin 7142c10f85fc18e7a0f72101421324009a17ea2dad895c917f414997951c9a1b. LP/AVB tool executable metadata present, tools NOT RUN. Zero full stock-image SHA or LP/AVB read.

Historical size arithmetic: A1X system + six N1C candidates aligned individually to 1MiB = 6,660,554,752 bytes; vs pre-C3A main_a 9,661,579,264 leaves nominal 3,001,024,512 bytes. This does NOT qualify LP fit because odm_a/current allocation/groups/snapshot/COW/AVB/restore not bound.

## A2B sealed bounded LP next action

ZIP N1F_P342_A2B_SPARSE_LP_CHECKSUMMED_READONLY_V1.zip SHA256 56e34048b967f101a40ec1de6dc7f9cbd8ee53b7a537d380abe88a204cebdb4f, 15,763 bytes. ZIP CRC, internal SHA7, AST/compile and Bash syntax PASS. 37/37 synthetic hermetic tests PASS after fresh ZIP extraction under both umask077 and 022; includes 97-chunk simulation, LP geometry/primary+backup metadata checksums and negative tamper/symlink/format conditions. Median 0.0972ms/p95 0.1555ms for 700 synthetic 524KiB fixtures; not ai-g732 4.19GB storage performance.

After independently verifying ZIP SHA and fresh extraction, run: bash ./n1f_p342_a2b_one_command_v1.sh. Reads only the exact historical N1C sparse super via nofollow, checks 97 chunk-record bounds and read-only LP SHA256 geometry/header/tables for each metadata slot, with at most 1MiB per copy. Does not expand raw 9.66GB, hash data payloads, run lpdump/lpunpack/lpmake/avbtool, write output files, build, fetch, contact device or flash. Success gives only historical N1C LP metadata. Real ai-g732 A2B NOT EXECUTED.

Outstanding: six+odm_a actual Oct03 companion bytes, physical LP/VAB/COW, matched AVB/boot restore, selected-image G3, and any A1X hybrid-super assembly. The old N1C whole-super write failed to boot despite valid offline assembly. Device/write/flash HOLD.