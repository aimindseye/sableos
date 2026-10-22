# PR347 — selected browser/first-boot owners, launcher profile guard, effective SMS and IMS G1–G3 handoff (2026-10-22)

## Scope of this deliverable: honest partial implementation

Owner asked to **bind the actual browser and first-boot owners, implement enforceable profile/security behavior, qualify the effective SMS role, and close IMS G1–G3**. The selected AI-G732 product filesystem / image contents and physical Titan2 are NOT accessible in the assistant environment. **This deliverable implements the source-side private-profile launch safeguard and operational tools to bind named selected-product artifacts. It does NOT certify privileged security or G1–G3 runtime closure.** Product and device authority is required to satisfy the rest.

### GitHub source implementation (draft PR347 branch)

- `src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherProfileSecurityGate.kt` **new**, Git blob `f9b6b955bedb43321192e0ae5d83bd43cff92f94`; pure policy denies unknown/quiet/unsupported secondary users and stale activity launches; only actual private profile can toggle.
- `src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt` **modified**, final Git blob `43115b4eaea43f04e8ffaea57f9bec9c6d8268cd`, current update commit `2199ea2b162fa6d488fe3b7890c3201273cd4f7c`. `launch(entry)` now invokes fail-closed just-in-time `UserManager.userProfiles` membership and **per-package** `LauncherApps.getActivityList(entry.component.packageName, entry.user)` visibility checks, plus `isQuietModeEnabled` on secondary users. `setLocked` restricts `requestQuietModeEnabled` to Android's identified private profile; no app-controlled bypass. Android remains the privileged launch/credential authority. No privileged AppLock claim.
- `tests/titan2/q25-nextbuild/ProfileSecuritySmoke.kt` and `run-profile-security-smoke.sh` committed for independently runnable pure JVM security gate. Source code **not yet Android/Soong-compiled** nor flashed; actual launcher integration still needs selected target and runtime tests.

### New self-contained handoff

`TB2_PR347_OWNER_SECURITY_SMS_IMS_BINDING_V1.zip` SHA256 `f278fca4fd1dac9ba05ec61eca9d63a9f8bfae326c85359568b0441f034a622b`, **22,544 bytes**, 13 exact ZIP members, CRC/SHA256SUMS PASS. Contents: read-only `selected_owners.py`, `ims_static.py`, `operator.sh`, embedded exact Git-blob-identical Kotlin policy, 43 positive/negative regressions, 12 Kotlin tests, `reports/RELEASE_GATES.json`, README, engineering review and local validation record.

Run on existing Track B source and selected output — **not** another repo checkout, audit loop, rebuild, device or flash:

```bash
cd ~/Downloads
unzip -q TB2_PR347_OWNER_SECURITY_SMS_IMS_BINDING_V1.zip
cd TB2_PR347_OWNER_SECURITY_SMS_IMS_BINDING_V1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
PRODUCT="$ANDROID/out/target/product/tdgsi_arm64_ab"
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-owner-binding-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
bash operator.sh report --android "$ANDROID" --product "$PRODUCT" --out "$EVIDENCE/SELECTED_OWNERS.json"
```

The report only reads **bounded** installed-files.json/txt plus two fixed effective-source selection makefile paths (`device/phh/treble/rom.mk`, `vendor/sable/trackb13ims/track-b.mk`). If no installed manifest exists, writes source-only HOLD report. WebView is NOT user-facing browser, `ManagedProvisioning` and `Sable Setup` are not first-boot authority. Current legacy Q25 Jelly/Lineage target owners were missing from native source snapshot. Selected manifest candidate path still needs package manager resolver/first-boot privilege runtime binding.

For an **exactly identified current selected IMS APK only**, `bash operator.sh ims-static --product "$PRODUCT" --provider-apk /real/selected/provider.apk --out "$EVIDENCE/IMS_STATIC.json"` collects APK digest, aapt2 service declaration hints, apksigner signer fingerprints (and optional selected platform signer match), bundled native ELF `DT_NEEDED`/readelf, known staged framework JARs. No provenance substitutions from old OEM stock or other build outputs. Service/classloader/privapp grants **G1** still HOLD, ABI/linker namespaces **G2** HOLD, vendor IMS IPC/IMS registration/SIM1/SIM2/DSDS **G3** HOLD. Source-selected FLOSS Phh candidate and historical OEM shared-UID/stock admission MUST NOT be treated as simultaneously installed or qualified.

### Security and SMS boundaries

- Android quiet mode / user profile is actual OS-enforced primitive used by new launcher check. This is a launcher-side TOCTOU defense-in-depth; *system-wide* AppLock, Secure Vault, Freezer, Dual Apps, CE-backed isolation, recents/notification privacy still require actual privileged enforcement code and runtime tests; no fake Settings-only toggles promoted.
- Sable Messages is currently a read-only SMS provider observer; sends through user's installed SMS app via ACTION_SENDTO. `READ_SMS` is hard-restricted, and default `RoleManager.ROLE_SMS` effective owner / installer allowlist / per-user grant are NOT proven from a manifest or installed-files list. Never force `WRITE_SMS`, pretend observer becomes default handler, or silently install new messaging stack.

### Author-host qualification

**43/43 Python regression tests PASS**, including 14 actual selected-APK G1/G2/G3 static boundary test scenarios; **12/12 Kotlin policy assertions PASS** built via `kotlinc`. `git hash-object` of ZIP Kotlin policy matches GH blob `f9b6...`. Python AST/bytecode, Bash syntax, ZIP member CRC and full SHA256SUMS PASS. Independently extracted full ZIP `bash operator.sh test` **PASS 43 + PASS 12**, no host-path dependencies. 40,000 synthetic installed manifest entries parsed+classified in **0.541 seconds** on author host; no hardware build performance claim.

**Native25/Command/Keyguard earlier module PASS receipts remain preserved and were NOT repeated.** Existing `out/` unchanged. Full 23-row Q25 design release gate and browser/setup/profile/SMS/IMS G1–G3 qualifications remain open. No full image build, device access, flash, security policy bypass, vendor binary copying, or synthetic production-grant evidence. PR347 stays draft. Frozen PR346 remote Git HEAD still `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`.
