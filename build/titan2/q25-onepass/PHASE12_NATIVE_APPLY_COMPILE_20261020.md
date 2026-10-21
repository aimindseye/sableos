# Titan 2 Track B — combined Phase 1 + Phase 2 source promotion and module compilation

Date: 2026-10-20. Actual host source precondition is the user's **successful seven-file V1.1 staging receipt** `TB2_A16_NATIVE_OWNER_STAGE_V1_1_20261020/RESULT.json`: `STAGED_NOT_COMPILED`, seven files (four modify, three add), no source mutation, build, device contact or flash, 5.705 ms. Earlier V1.1 source-integrator regression tests and ZIP/member hashes PASS. **This does not mean any A16 module compiled.**

This entry records the **sealed standalone executable** `TB2_A16_PHASE12_INTEGRATE_COMPILE_V1.zip` SHA-256 `679cf9f24cbcd703fd1fdbba0688476769a71034800c104bf1380db5030ebb47`. Source `integrate_compile.py`, `operator.sh`, tests, engineering review and README are in the archive, **not misrepresented as committed Android source**. The previous staged A16 target files remain the input; no new Q25 inventory/source rebase or git checkout is required.

## One acknowledged source + compile operation

```bash
cd "$HOME/Downloads"
sha256sum -c TB2_A16_PHASE12_INTEGRATE_COMPILE_V1.zip.sha256
unzip -q TB2_A16_PHASE12_INTEGRATE_COMPILE_V1.zip
cd TB2_A16_PHASE12_INTEGRATE_COMPILE_V1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
bash operator.sh run \
  --android /srv/sable-build/workspaces/titan2-track-b/android \
  --stage "$HOME/Downloads/TB2_A16_NATIVE_OWNER_STAGE_V1_1_20261020" \
  --out "$HOME/Downloads/TB2_A16_PHASE12_RESULT_20261020" \
  --lunch-target treble_arm64_bvN-bp4a-userdebug \
  --jobs 4 \
  --ack INTEGRATE_AND_COMPILE_Q25_A16_NATIVE_SEVEN_ONLY
```

The generated Treble engineering **lunch product** is `treble_arm64_bvN`, with Android 16 `bp4a` release and `userdebug` variant; `tdgsi_arm64_ab` is its `PRODUCT_DEVICE` and output-directory name, NOT its lunch name. The later Sable wrapper uses `sable_titan2-bp4a-userdebug` only when its product graph is present. Verify the registered product/release using `source build/envsetup.sh; list_products; list_releases treble_arm64_bvN` and a read-only lunch before invoking `run`. Do not silently switch products. It calls `source build/envsetup.sh; lunch <target>; m -j4 SystemUI Dialer`, **not** `m systemimage` or the full `sable.sh` release/image builder.

The runner strictly pins all seven V1.1 before and after SHA256 values and source actions, checks candidate and backup bytes, symlinks and all exact current A16 file hashes before mutating. Atomic source writes preserve modes; on native compilation failure/timeout/interruption it restores originals and removes new helpers only if promoted hashes remain unchanged. Concurrent modifications stop with `HOLD_ROLLBACK_INCOMPLETE`. Native build outputs in Android `out/` are not removed. Successful module build leaves the seven source changes applied **uncommitted**, without firmware/device/image side effects. `RESULT.json` and `native-modules.log` preserve actual results.

**Optional same-run offline Q25 app Gradle quality**: append `--with-q25-apps --sable-repo /srv/sable-build/sableos/repo` **only if** the existing canonical worktree already contains PR#346's app source (remote Git objects alone are insufficient). It checks exact expected local files before source write, then runs `assembleDebug`, `testDebugUnitTest`, `lint`, `detekt`, `ktlintCheck` on keyboard/camera/setup/tools and hub/messages/calendar using `build/config/host-tools.env`, JDK17, SDK and existing offline Gradle cache. Any failure rolls back the native source. This optional pass does not install its APKs into AOSP or prove product integration.

## Local validation and performance

- `python3 -m py_compile` of Python source and tests PASS; `bash -n operator.sh` PASS.
- **12/12 hermetic regression tests PASS in ~0.6 seconds**: exact source and stage hash checks; run success against fake `envsetup/lunch/m`; compilation-failure rollback of all 7; original/candidate drift, unapproved paths, symlinks, output inside Android, missing acknowledgment, optional Q25 app source preflight and read-only plan.
- **250 seven-path digest preflight iterations ~0.59 seconds locally**, not a Soong/Gradle performance claim.
- ZIP SHA256 and all seven member SHAs/CRC PASS.
- **Actual ai-g732 native SystemUI/Dialer module build and Q25 app Gradle quality have NOT RUN for this operator**; no `RESULT.json` receipt from them exists yet.

## PR and release boundaries

Reviewed existing scope: PR #342 is historical OEM IMS qualification, not selected new-image G1/G2/G3; PR #344 Track B custody; PR #345 Sonar CI is not native/image qualification; PR #346 draft unmerged portable Q25 source and Native34 candidates. The exact Q25 upstream SystemUI patch 0301 was verified in `aimindseye/zinwaq25-sableos`. Canonical host tool configuration remains `build/config/host-tools.env`; no new compiler installation/bootstrap.

**Q25 full source completion remains OPEN** for privileged AppLock/Freezer/Vault/Dual, installed Browser and first-boot Setup owner, full Keyguard type-ahead, Phone/Contacts, permanent Launcher3QuickStep HOME/Recents, effective installed READ_SMS, Camera2/QuickReview and platform product wiring. IMS provider selection (FLOSS vs OEM), selected G1/G2/G3 and live registration/VoLTE remain separate. The script does **not** claim any of those gates passed and does not invoke `sable.sh`, create an image, or flash.

**Final archive safety correction:** The verified operator also resolves output directory parents before confinement checks and, on failed compilation, removes newly created empty source directories (never recursively deleting populated directories). Added regression coverage for symlinked output parents and exact rollback of newly added directory trees. Final local suite **12/12 PASS**, latest local 250× seven-file SHA preflight ~0.585s. This supersedes earlier 11-test artifact/hash referenced in preliminary PR discussion; no host native run has occurred.

## 2026-10-20 actual ai-g732 RC=1 adjudication — build never reached Soong

Actual 12/12 regression suite PASS; operator applied all seven staged source candidates, then exited in 0.114 seconds from AOSP `lunch` with: `Invalid lunch combo: tdgsi_arm64_ab-userdebug; Valid combos must be of the form <product>-<release>-<variant>`. **Soong never ran**, module compilation status FAIL denotes *environment selection failure*, not a Java/Kotlin error. The runner restored all seven originals and deleted three new files: `rollback=PASS`, `rollback_errors=[]`, `source_mutation=false`, every original SHA256 verified by user. No image/device/flash. This failure was introduced by the default target used in the assistant handoff, **not** the Q25 source candidate.

Historical canonical proof: `build/titan2/build-n1b2-image-candidate.sh` defines `DEFAULT_LUNCH_TARGET=treble_arm64_bvN-bp4a-userdebug` and `DEFAULT_PRODUCT_OUT_REL=target/product/tdgsi_arm64_ab`; `build/titan2/run-n1g-sable-product-identity.sh` describes the later wrapper `sable_titan2-bp4a-user`. The active Track B repo must resolve the chosen *actual* product. **Correction**: run read-only AOSP envsetup + `lunch treble_arm64_bvN-bp4a-userdebug` and confirm `TARGET_PRODUCT=treble_arm64_bvN`, `TARGET_RELEASE=bp4a`, `TARGET_BUILD_VARIANT=userdebug` before a new seven-source apply/compile run. If the generated Treble product is missing, HOLD and inspect the current product graph; do not substitute a random combo. Use a **fresh** out receipt path.

The standalone Phase12 V1 ZIP previously distributed defaults incorrectly to `tdgsi_arm64_ab-userdebug` when `--lunch-target` is omitted; always pass a verified explicit three-part target until the operator itself is revised. No repeat hash/bootstrap scan or immediate image build.
