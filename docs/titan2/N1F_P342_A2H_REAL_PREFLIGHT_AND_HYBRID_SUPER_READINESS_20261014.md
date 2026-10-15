# A2H actual preflight PASS and hybrid-super versus physical-flash readiness

Date: 2026-10-14. PR #342 OPEN/DRAFT/UNMERGED. Engineering status only. No Android build, AVB mutation, LP mutation, device contact, reset or flash.

## Actual ai-g732 A2H outcome

Operator verified external N1F_P342_A2H_E4_STOCK_VBMETA_RECEIPT_PROVENANCE_V1.zip SHA, seven internal ZIP SHA256 members, AST2/Bash syntax, 42/42 hermetic regressions PASS in 0.073s; A2H_REGRESSIONS=PASS_42; zero-host-I/O plan; final `A2H_PREFLIGHT_PASS_NO_HISTORICAL_EVIDENCE_OR_IMAGE_BYTES_READ`. Actual historical E4 SHA256 receipt inspection **NOT RUN**, no stock vbmeta image bytes read. Exact bounded next opt-in from existing verified extracted ZIP is `bash ./n1f_p342_a2h_one_command_v1.sh --inspect --authorize-a2h-e4-small-receipt-readonly`; reads fixed E4 text receipts <=8192B each in <=32 timestamp subfolders, requires exactly one six-row ledger, no old image byte rehash, no recursive broad scan, no stock chain cryptographic claim.

## What is actually complete

A1X new 3210473472-byte system.img previously host SHA/16 internal Sable/IMS paths/signing PASS. A1Y static GSI skip_mount and embedded system_ext source/image evidence PASS (not runtime mounting). A2B historical N1C TEE14 97-chunk sparse super LP 10.2, 3 slots and primary/backup metadata SHA checks PASS; historical main_a max 9661579264. A2C six preserved TEE14 source images byte-for-byte equal matching extents inside historical N1C stock super; six SHA identities verified. A2D A1X and Oct03 source-image AVB footers and embedded headers parse. A2E A1X and Oct03 embedded vbmeta key bytes, flags, rollback, 4 descriptor tags parse. A2F one hashtree + 3 properties, SHA256/4096, FEC bounds, difference in root digests and fingerprints classified. A2G both SHA256_RSA2048 embedded vbmeta RSA-PKCS1v1.5 self-signatures verified using their own UNTRUSTED embedded keys; OEM chain not authenticated. No current A1X-derived complete hybrid super has yet been built.

Historical seven-candidate images 1MiB-aligned sum 6660554752 bytes compared with historical main_a max 9661579264 leaves 3001024512 nominal bytes. This arithmetic is NOT real lpmake extent/metadata/free-COW/AVB admission. A1X source length 3210473472 is already divisible by 4096 but rounds up by 266240 to a hypothetical 1MiB LP size 3210739712; original source AVB footer at source EOF, not proven final LP boundary. Do not pad/re-sign by fiat.

## Distinct remaining gates: OFFLINE hybrid super

(1) A2H actual E4 receipt path inventory; then verify exact TEE14 stock vbmeta, vbmeta_system, vbmeta_vendor metadata, chain descriptor paths, signatures/trust context, rollback policy and source freshness using only selected existing files, without repeating old broad E4 recursion or image SHA. A2H alone does not establish root trust. (2) Freeze a full LP/AVB composition contract for candidate A1X system_a at exact intended LP size and footer boundary, groups/metadata slots, seven known partition extents, correct snapshot/COW and no invented odm_a. (3) Obtain **separate explicit authority** to assemble only one bounded OFFLINE whole-super artifact from pinned input files, then independently lpdump/lpunpack and hash each preserved/extracted partition; no device commands. Existing N1C offline lpmake precedent does not prove boot-safe deployment.

## Distinct remaining gates: PHYSICAL deployment and useful system

(4) Seal complete matched same-region stock super and boot/init_boot/vendor_boot/dtbo/vbmeta* restore set, prove recovery and userdata/factory-reset policy; E4 older six boot/AVB excludes dtbo and Oct03 physical same-session identity is not proven. (5) Requalify actual Titan2 current mode (last reported fastbootd, not fresh), active slot, dynamic LP/snapshot/COW/free extents, AVB/unlocked verified-boot state, special fastboot limitations and transport readiness with separately approved read-only device contact; mode-aware driver necessary. (6) Reconcile N1F G3 native/IMS runtime namespace closure (boot qualification may be staged separately from cellular completeness). (7) Only after all physical stop checks and independent explicit operator write authority consider one frozen safe deployment attempt with rollback/matched recovery controls. The historical N1C whole-super write failed boot, N1B COW-aware system_a success and Oct13 M4 system_a recovery boot failure all remain live negative/positive evidence; do not assume generic A/B or inactive system_b path.

Answer for schedule: offline assembly is a nearby subsequent ENGINEERING stage but not currently admitted; physical flash is materially farther away and NO percent/timeline can be honestly guaranteed. Avoid arbitrary percentage as status metric. A2H metadata preflight success itself advances receipt tool readiness, not stock chain readiness.

```text
A2H_REAL_PREFLIGHT=PASS_42
A2H_E4_RECEIPT_INSPECTION=NOT_EXECUTED
A2G_EMBEDDED_VBMETA_SELF_SIGNATURES=PASS_REAL
STOCK_TRUST_CHAIN=OPEN
LP_FINAL_AVB_BOUNDARY=OPEN
OFFLINE_A1X_HYBRID_SUPER=NOT_ASSEMBLED
STOCK_MATCHED_RESTORE=OPEN
FRESH_DEVICE_MODE_SLOT_COW=OPEN
IMS_G3=OPEN
FLASH=NO
```