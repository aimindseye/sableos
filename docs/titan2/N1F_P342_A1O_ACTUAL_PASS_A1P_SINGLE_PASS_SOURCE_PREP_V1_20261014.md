# PR342 — A1O actual PASS; A1P single-command source assembly handoff and hard repository blocker

Date: 2026-10-14 US/Eastern. Per operator request, **STOP serial audit-only gates**; reuse existing source/stock/app/CIL evidence and combine actionable operations. Host-only Android image build remains authorized in principle, but no source build is technically admitted; no device/super/flash.

## Actual A1O result closes six-file stock partition content authority

Operator on ai-g732 reported checksum/11 internal SHA PASS, **130/130 regression tests PASS (0.234s)**, real `PASS_A1O_SIX_STOCK_PARTITION_FILE_CONTENT_MATCH_NOT_BUILD_READY`. Pinned EROFS images: system.img SHA256 `b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd` (757059584B); system_ext.img SHA256 `1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170` (704434176B). All exact 6 IMSSvc APK/2 framework JARs/3 XML bytes were streamed from these partition images and SHA-matched M4 payloads. No mount/extract/write/build/device/flash. **Close this evidence question; do not repeat the stock stream/checksum census.**

Prior A1N V1.1 actual ai-g732: 4 byte-identical historical 5-APK bundles (canonical source import `aafb543565c9d59ed5e0d9cda876aabb4967f8aa`) and 3 matching original extracted CILs SHA256 `7a11c43133cae9fb1588cc53b4fb750ca89453228a0df44af1aa5d6a01f33c51` yielding property.te SHA256 `d33ee56221c83108e814dcb0052092f9e40d0b72e8a81fba6b030d784327f89e`. Deterministic earliest complete matching app bundle `20261005T020625Z` is selected in A1P. Source/PIN A1F–A1L = PASS. Historical PR339 is closed; its failed M4 physical image is not a boot baseline.

## External A1P single-pass preparation ZIP

`N1F_P342_A1P_SINGLE_PASS_BUILD_PREP_V1.zip` **SHA256 `28a17299c6fff1ff8f917613d57080555c0a76cf623e8b032e8cc7cb32f30e6f`**, size 434xx bytes; main source `n1f_p342_a1p_build_prep_v1.py` and operator `n1f_p342_a1p_one_command_v1.sh`. Exact ZIP `SHA256SUMS.txt` pins 8 Python files, shell wrapper, README/plan/review, validation log. **15 sources/docs and SHA manifest? Confirm ZIP contents in operator receipt; use actual SHA not size as primary identity.**

One exact opt-in command, from SHA-verified fresh ZIP extraction: `bash ./n1f_p342_a1p_one_command_v1.sh --authorize-a1p-a1-only-offline-materialization`. Wrapper checks internal hashes, Python compile and Bash syntax, inherited and new 152 synthetic regression tests, source operation plan; loads canonical trusted SableOS `build/config/host-tools.env` and passes `SABLE_ANDROID_BUILD_TOOLS/{aapt2,apksigner}`. Single guarded prepare operation first reconfirms the frozen 11 A1 source pins+no-build marker/out/.repo, exact retained M4 six stock-derived input SHA values (A1O proven), deterministic five-app bundle SHA manifest+canonical imported source Git diff, each app package ID and APK unsigned, original IMS package/shared UID, original CIL SHA/policy.te derived bytes. Then checks all 12 outputs absent and hashes all 12 input files *before any A1 write*.

With explicit operator flag, this creates exactly 12 isolated A1 leaves: 6 `vendor/sable/titan2/n1i-c1/prebuilt/...` original stock bytes (NO .so), 5 `vendor/sable/titan2/c3b/prebuilt/SableTitan2*.apk` unsigned source bytes, and one generated `vendor/sable/titan2/n1i-c1/sepolicy/system_ext/private/property.te`. Uses fd directory no-follow, exclusive `O_EXCL`, hash after write, fsync, one-use A1 container evidence `.A1P_SINGLE_PASS_BUILD_PREP_NO_BUILD_V1/RECEIPT.json`, no retry/resume/cleanup/automatic rollback. Then one bounded pinned Oct03 manifest 991 Git HEAD census via max 12 parallel workers and 160s aggregate timer, logs alternate object-store dependency and `.repo` metadata absence. **Never creates/copies `.repo`, git objects, A1 out, builds, network fetches, changes donor/M4/canonical source, devices/fastboot/flash.** It returns `PASS_A1P_OFFLINE_PAYLOAD_AND_POLICY_STAGED_BUILD_HELD` with `created_count=12` but **`BUILD_READY=false` by design**. Fails closed on unexpected source drift, required tools unavailable or existing target. If partial, stop and preserve state, no rerun.

**Known structural blocker, NOT another missing APK SHA check:** A1 was created with local provisional Git project stores using donor alternate references; `.repo` is absent and a complete independently sealed 991 project object/metadata checkout has not yet been restored. Building after merely fabricating `.repo` or deleting alternates would be incorrect. Oct03 patch/TrebleApp exact source closure and configuration-only Android16 Soong/Kati graph are also still open. These cannot be asserted from prior chat/GitHub without actual host source metadata. User's request to have all prebuild gates closed is respected, and therefore **this single-source-operation is NOT a build green light**. Compiled SELinux and final image G1/G2/G3 checks follow a technically admitted image build and precede any device action.

## Independent script validation and performance

Local assistant archive ZIP CRC PASS, internal SHA256 pins checked, Python AST/compile 8 files PASS, Bash syntax PASS. **152/152 synthetic regressions PASS under umask 077 (14.746 sec) and 022 (14.555 sec)**; extracted ZIP separately sha256sum -c PASS, 152/152 tests PASS under 077 (22.745sec) and 022 (14.943sec). End-to-end simulated creation of exactly 12 leaves PASS; negative tests include signed app, wrong package, source byte mismatch, preexisting leaf, symlink ancestor, missing tools and one-use receipt refusal. Tiny 12-path metadata map benchmark 1000 iterations median 0.002517 ms/p95 0.002735ms, **not** a real 991-Git/large APK host workload. **A1P has not executed on ai-g732.**

```text
A1F_TO_A1L_SOURCE_STATE=PASS_FROZEN
A1O_SIX_PINNED_STOCK_FILE_CONTENT=PASS_REAL_HOST
A1P_ASSISTANT_PACKAGE=PASS_ZIP_SYNTAX_TESTS_152_BOTH_UMASKS
A1P_REAL_HOST_SOURCE_PREP=NOT_EXECUTED
A1_PAYLOAD_AND_POLICY_STAGE=OPEN_UNTIL_A1P_RESULT
A1_INDEPENDENT_991_REPO_GIT_OBJECT_CLOSURE=OPEN
A1_SOONG_KATI_GRAPH=OPEN
BUILD_AUTHORIZED_HOST_ONLY=YES BUILD_READY=NO BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 stays OPEN/DRAFT/UNMERGED.