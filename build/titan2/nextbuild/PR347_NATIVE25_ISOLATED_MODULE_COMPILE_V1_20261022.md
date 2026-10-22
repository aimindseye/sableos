# TB2 PR347 — native25 isolated module compile handoff V1 (2026-10-22)

**Status: AI-G732 Native25 SOURCE ADMISSION=PASS; MODULE BUILD=NOT RUN; FULL Q25+IMS READY=NO.**

## Operator evidence
On AI-G732, user executed the source-only `TB2_PR347_NATIVE25_SEMANTIC_DEDUP_V1` operator with full `SHA256SUMS` passes, **18/18 hermetic regressions PASS** (0.071s), and both independent and test live verifications returned `PASS_25_REVIEW_ONLY_0703_DUPLICATE_OWNER_QUARANTINED`. Report: `changed_paths=25`, `old_paths=17`, `new_paths=8`, `candidate_patches=9`, `held_original_patches=16`, `quarantined_original_patch=dialer-in-call-keys`, `source_mutation=false`, `android_build=false`.

This source-context status **does not** indicate SystemUI/DocsUI/services compilation, APK provenance, roles or runtime qualification.

## New self-contained handoff
Chat-attached `TB2_PR347_NATIVE25_ISOLATED_MODULE_COMPILE_V1.zip`, SHA256 `555856259484fa019e4cac7ff27cda64a45ee166f7aee45d6e8e92a078b07f39`, 842,238 bytes. Contains exact original `TB2_PR347_NATIVE25_SEMANTIC_DEDUP_V1.zip` as immutable SHA-pinned input plus guarded operator `isolated_compile.py`, `operator.sh`, README, engineering review and tests.

- `test`: verify all package checksums, Python/Bash syntax and ten Python regressions; independently reconstruct actual 25-policy postimage from real embedded Android16 source snapshot.
- `plan ACTIVE INDEPENDENT`: read-only verify disjoint complete Android source roots, explicit sentinel, isolated `.repo` directory and missing isolated output tree; original 17 old preimages + eight expected absent new paths; no inode-shared/hardlinked changed source; original Titan2 Dialer semantic handler and preference equality; 25/25 output SHA pins.
- `stage ACTIVE INDEPENDENT RECEIPT.json`: with explicit operator-supplied acknowledgement inside wrapper, copy **only 25 staged postimage sources into a pre-provisioned independent Android checkout**, atomically, with simulated-fault-tested rollback, and write a fresh receipt **outside both Android trees**. Live PR346 checkout never mutated.
- `compile ACTIVE INDEPENDENT RECEIPT.json FRESH_EVIDENCE [JOBS]`: **separate opt-in** targeted AOSP `m -j4 SystemUI DocumentsUI services` after `source build/envsetup.sh` and canonical `lunch treble_arm64_bvN-bp4a-userdebug`, uses **fresh** `<INDEPENDENT>/out-pr347-native25` only; streams and logs results, writes exit-code/result receipt; no `systemimage`, no OTA, adb, flash, device or reboot. Module names are provisional until real AOSP host confirms them.
- Does **not create or clone** an independent checkout. One must already exist without shared hardlinks or source drift; no `cp -al`, `git clean` or `repo sync --force-sync`.

**Assistant host validation:** `python3 -m py_compile` and Bash `-n` PASS; 10/10 independently executed Python regression cases PASS (0.620s) using actual 34-source archive embedded in Native25 ZIP and two separate synthetic Android roots; explicit rollback fault injection, path/owner drift, hardlink and output alias holds. Package outer ZIP CRC PASS, all seven SHA256SUMS entries verified, artifact SHA256 matches.

No Android16 module build was executed on ai-g732 in this turn. This tool **does not close 16 held native patches**, global Alt+Space, Keyguard 0304, selected browser & first-boot wizard, privileged AppLock/Vault/Freezer/profiles, restricted SMS, full launcher Compose/Soong or IMS G1–G3. The full-image readiness gate remains HOLD. Frozen PR346 head `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`, original AOSP source and Ninja `out/` preserved.
