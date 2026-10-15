# A1Y actual static G1 PASS and A1Z four exact stock receipt classifier

**Date:** 2026-10-14. **PR:** #342 open, draft, unmerged. **Current engineering lane:** isolated Titan 2 A1. No super assembly, source changes, new Android image build, stock extraction, network, device contact, reboot or flash.

## Actual operator A1Y results — do not mistake static PASS for deployment

The operator verified the full sealed package (7/7 inner SHA, AST2/Bash, 30/30 tests in 0.252 seconds), then ran read-only A1Y against ai-g732. Status: **PASS_A1Y_STATIC_G1_AND_HISTORICAL_RECEIPTS_NOT_MATCHED_SUPER_READY**, errors empty, elapsed **1.461 seconds**. Active A1X system.img: **3210473472 bytes**, SHA256 **7142c10f85fc18e7a0f72101421324009a17ea2dad895c917f414997951c9a1b**, independent host fd hash matched.

**G1 static config PASS:** embedded `system/system_ext/etc/init/config/skip_mount.cfg` equals build tree and exact source, 220 bytes, 12 lines, SHA256 **0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e**, with four required skip rules for /product, /system_ext and subtrees. `system/etc/init/config` compatibility symlink target exact both in output tree and in image. **First-stage runtime mount behavior NOT_TESTED_HOST_ONLY**; this result does not establish actual stock fstab precedence or final deployed Android boots.

**N1C historical receipt pins:** four exact fixed-path text files were read, hashed and recorded PASS_BOUNDED_TEXT_ONLY, **not parsed or bound to Oct03 device session**:
- stock ledger: 1267 bytes, 48 lines, SHA256 **67e49eaa76a29d280775226475ba52dcd97dcbc5f54de6a79f6f368a8efaff08**
- partition hashes: 542 bytes, 7 lines, SHA256 **d170afccdec48a90a86a552b8ea4d9ff10cf6e21309b2daa83b404469c101b96**
- partition map: 1105 bytes, 7 lines, SHA256 **08996720a4f90540d7efe3aef2f884aa999d66dbde28959dfcf0ec7940e90187**
- sizes: 1625 bytes, 7 lines, SHA256 **7143c9b85d86f481f1a93e582e036f1dd4b6e8291cc1e526ff80e821b74cf48b**

Seven exact boot/AVB direct leaf names `boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img` each returned **NOT_VERIFIED_AT_DIRECT_ROOT**. This is **not global file absence**. Previously recovered R0 evidence root itself has many nested entries and the original R0 refused its 64-entry cap. Do not broaden that scan or use unverified TEE13 files instead of TEE14. Historical N1C stock super sparse candidate metadata: `titan2-stock-v010014-super-restore-r1c.sparse.img`, size 4189766872 bytes from prior R0; not freshly read, parsed or SHA verified. N1C complete old super offline assembly PASS, but whole-super physical flash **FAILED to boot**; N1F Oct03 parent host hash PASS (historical reference only), seven Oct03 same-session companion identities **UNBOUND**, postflash LP/VAB, AVB, matched restore and IMS G3 still OPEN. Operator preference for hybrid-super deployment is recorded; no safe candidate exists yet.

## New A1Z V1 deliverable, actual host NOT EXECUTED

**Archive:** `N1F_P342_A1Z_N1C_EXACT_RECEIPT_CLASSIFIER_V1.zip`, **10987 bytes**, outer SHA256 **66a2fc5787e5b0b0538bd5cfd4a5c9983da4dcbe48a727502b16c195239ce560**, ZIP CRC PASS. 8 archive members; 7 SHA256-sealed members + `SHA256SUMS.txt`.

Runner from fresh outer-checksum-verified extraction: `bash ./n1f_p342_a1z_one_command_v1.sh`, verifies inner SHA, Python AST2, Bash syntax, 25 hermetic tests, zero-I/O plan, then explicitly opts into read-only host parsing with `--authorize-a1z-exact-four-readonly-receipts`. Direct Python script defaults to `plan`, no host read and refuses unflagged inspect.

A1Z opens **only the same four** direct receipt leaves with fd-relative no-follow and a hard <=16KiB/file cap. Requires exact **A1Y-observed** byte size, line count, SHA256 and UTF8. It outputs only recognized partition label counts and six N1C stock-reference SHA256 token-occurrence counts, plus unrecognized token count; never outputs untrusted text lines, paths embedded in receipts, stock-sensitive serial/log contents, unknown SHA values, or follows any identified path. It does not read a partition image, hash a full system image again, enumerate directories, run LP/AVB tools, build/repack or contact the phone.

**Hard qualification limit:** Even a complete six-for-six token presence means `N1C_REFERENCE_HASH_TOKENS_OBSERVED` only, **not verification of actual available partition image bytes, Oct03 physical same-session identities, LP/AVB chain or matched restore**. `odm_a` has no historical N1C reference pin and must remain UNBOUND. Successful receipt identity + conservative token classification gives `PASS_A1Z_PINNED_N1C_RECEIPT_CLASSIFICATION_NOT_MATCHED_SUPER_READY`; mismatch returns HOLD with nonzero exit.

**Independent validation:** ZIP CRC and 7/7 inner SHA PASS; Python AST PASS and Bash -n PASS; **25/25 hermetic tests PASS** under umask077 and umask022, and **25/25 PASS from freshly extracted ZIP under both**. Negative cases cover mutated equal-size receipts, missing/oversized directories/leaves, symlink ancestor/leaf, embedded NUL/nonUTF8, wrong line count, no-match and unknown hash tokens, redaction, explicit access flag, and default plan without host I/O. Synthetic 1000 x 1.6KiB nofollow read median **0.0084ms**, p95 **0.0091ms** (assistant host only; not ai-g732 stock image throughput).

## Next decisions after A1Z

Use the actual four-file token/classification outcome to pin a fixed next candidate-input matrix. Separately scope actual existing region-matched stock-super and companion image bytes, `lpdump` group/snapshot rules, AVB descriptor chain, same-version boot/restore files and G3 native/provider runtime. Then **separately** authorize one offline `lpmake` build and per-partition `lpunpack` round-trip hashing for the A1X SHA-pinned system image. No whole-super device write command before exact recovery and current device-mode gates.

```text
A1W_BUILD=PASS_REAL
A1X_IMAGE_CONTENTS=PASS_REAL_16_OF_16
A1Y_STATIC_G1=PASS_REAL
A1Y_RUNTIME_MOUNTS=NOT_TESTED
A1Z_PACKAGE_TESTS=PASS_25_BOTH_UMASKS
A1Z_REAL_HOST=NOT_EXECUTED
HYBRID_SUPER_MATCHED_INPUTS=UNBOUND
HYBRID_SUPER_A1X_ARTIFACT=NOT_BUILT
DEVICE=NO FLASH=NO
```
