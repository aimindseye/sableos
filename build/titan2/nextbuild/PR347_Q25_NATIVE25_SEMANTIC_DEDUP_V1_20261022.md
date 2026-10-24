# PR347 Q25 native 27 -> 25 semantic collision correction — 2026-10-22

**STATUS: PASS_25_REVIEW_ONLY_0703_DUPLICATE_OWNER_QUARANTINED; AOSP_MODULE_COMPILE=NOT_RUN; FULL_Q25_IMS_HOLD.**

## Why 10 source-context patch passes are not 10 safe promotion candidates

Operator's 2026-10-22 AI-G732 `ANDROID_ROOT=... bash operator.sh verify` on native27: 16/16 Python regression PASS, 25/25 Q25 native pure Java policy assertions PASS, 22/22 Files policy assertions PASS, source preimages matched (18 prior source files + 9 absent new paths), no source mutation, no build, no device.

The next review uncovered *actual semantic overlap* in the original A16 source snapshot and PR346 retained native source:

- `packages/apps/Dialer/java/com/android/incallui/InCallActivity.java` original snapshot already contains exactly one `dispatchKeyEvent` handling Space only for single ringing call, consuming subsequent release/repeats, plus `sableHandleActiveKey` M/S/D routing through `SableTitanInCallKeys`. Existing method prevents a ringing/in-progress conflict and preserves system Telecom controls.
- `sound_settings.xml` already includes `sable_space_answers` switch, `sable_strings.xml` already defines its title and summary. This explains original Q25 0704 source-context mismatch; *behavior appears implemented at source level*, but not proven on a device, in a selected APK or with user/role controls.
- Prior PR346 retained source `build/titan2/q25-onepass/native-owner-merge/dialer/SableTitanInCallKeys.java`, exact Git blob `b03d1183b160623db567f9dd9c10a20dec3a6909`, implements `ANSWER`, `TOGGLE_MUTE`, `TOGGLE_SPEAKER`, `SHOW_DIALPAD`. Q25 original 0703 adds a *different*, generic `SableInCallKeys.java` plus a second `handleSableInCallKey` method; both compile context may apply cleanly but would introduce duplicate key handlers and possible divergent speaker-route behavior.
- **Do not directly promote the former 27-file native candidate** despite its passing patch context. Quarantine original Q25 `dialer-in-call-keys` 0703 from source promotion. Do not force original 0704.

## Corrected exact output

Self-contained conversation handoff: `TB2_PR347_NATIVE25_SEMANTIC_DEDUP_V1.zip` SHA256 `ea53ce44507575d9bf9fb399f4a8f63ab6c1e4c330428d69f469f8dbc1ee12f0`. Nested `ADMITTED_25_REVIEW_ONLY.zip` SHA256 `7141dd7ce9b82216edabc544f3349601a4e5da47afb8af99b8508d20869113d3`, unified review diff SHA256 `3c65607db1a06ba10e02a624ef05e4fd59a1f8d0a2028b9f7f97a40e588a1495`. Original pinned exact owner snapshot (34 sources) and original native27 review ZIP retained as inputs.

Quarantined native postimages (two exact paths):
1. `packages/apps/Dialer/java/com/android/dialer/sable/SableInCallKeys.java` (Q25 duplicate generic handler).
2. `packages/apps/Dialer/java/com/android/incallui/InCallActivity.java` (Q25 new handler + existing Titan2 handler conflict).

Keep source-qualified Q25 patches **0101, 0102, 0301, 0302, 0303, 0305, 0501, 1001, 1002**, resulting in **25 review-only paths: 17 existing preimages + 8 newly added paths**. Exactly 16 remaining original manifest patches stay HOLD by context/privilege/absent owners, plus 0703 quarantined for semantic duplication. This is a **9-patch source candidate**, not an Android module or runtime pass.

### Verified assistant-host boundary
- Original 27 inputs (postimage bytes, old hash pins and original diff) revalidated against the original 34 captured source files.
- Corrected 25 diff `git apply --check` and `git apply` executed only in disposable scratch, all 25 postimages byte-identical to original, exactly two paths removed.
- **18/18 Python standard-library regressions PASS**, including negative owner drift, source mismatch, path/symlink, tamper, new-path collision and absent Titan policy guards.
- Python syntax PASS; Bash syntax PASS; package ZIP CRC/SHA256 PASS; freshly extracted ZIP independently tested PASS; 20 repeated scratch verifications 17.436s total on assistant host (~0.872s per process invocation).
- Dedicated **read-only A16 live source verifier** additionally checks the original `InCallActivity.java`, `sound_settings.xml`, `sable_strings.xml` byte-for-byte and existence/source-semantic policy of actual `SableTitanInCallKeys.java`. An unexpected value returns HOLD (78). No source apply/promote subcommand.
- Not run on AI-G732 yet. No AOSP Soong module compile/Android ROM rebuild, no device or flash, no source changes. PR346 remains frozen at `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`.

## Required next native work

Do not repeat earlier 27 scratch tests if unchanged. First run the correction's `operator.sh test` and `ANDROID_ROOT=... bash operator.sh verify` on AI-G732, and inspect any new HOLDS. Then pursue A16 module-only compilation in an independently staged next-build workspace with prior seven native source files reconciled, without restarting the full image yet. Remaining open A16 ownership: Q25 0304 Keyguard adaptation, true global Alt+Space Command owner, actual browser and first-boot SetupWizard, privileged AppLock/Vault/Freezer, default SMS restricted role and IMS G1/G2/G3. Fail-closed PR347 full-build gate stays enabled.
