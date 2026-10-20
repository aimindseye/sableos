# Titan 2 Track B — actual source recovery for Q25 SystemUI, Dialer, Setup and keyboard Settings

2026-10-20. Scope intentionally **SOURCE RECOVERY, not Android16 runtime closure**. The actual Android source workspace is held on ai-g732 and not mounted here. The verified ai-g732 one-pass v1.1 receipt remains authoritative for the original 16 patch candidates.

## Existing implemented source, now recovered in this branch

Source origin: `aimindseye/zinwaq25-sableos@feature/sable-start-bb10-layout-20261019`; content retained as original Git blobs:
- SystemUI/Keyguard prerequisite chain: `0101` (Quick Settings tile sizes), `0102` (Quick Settings visual card), `0301` (notification-row keyboard policy, row commands and tests), followed by already present `0302` Alt-shade, `0303` Space/Alt+Enter, `0304` PIN/input hints, `0305` clock and `0501` notification LED. **0301 is an actual precondition**: `0302` modifies three existing `SableNotificationKey*` Kotlin source/test files rather than creating them.
- Dialer chain: `0703` original `SableInCallKeys.java` and in-call M/S/D behavior, followed by `0704` original Space-answer behavior. **0703 is an actual precondition**: `0704` modifies existing SableInCallKeys and the InCallActivity, so source header drift still needs real target adaptation.
- First-boot SetupWizard full original `0401`–`0408` implementation stack instead of isolated `0405` and `0408`. The user's Android16 receipt shows **the exact Lineage SetupWizard source owner path is absent**. Do not silently install this code into an unrelated provisioner or claim first-boot behavior.
- Canonical original 26-entry manifest at [PATCH_MANIFEST_OWNER_RECOVERY_V1.json](./PATCH_MANIFEST_OWNER_RECOVERY_V1.json), with exact origin SHA pins, real prerequisites and security holds. It replaces ad-hoc copy ordering; does **not** apply patches automatically.

## Real owner-code change implemented

The existing `apps/titan2/platform/keyboard` module now has:
- `core/HardwareKeyboardSummary.kt`: framework-based physical keyboard classification and explicit on-screen critical-text fallback.
- `android/HardwareKeyboardStatus.kt`: read-only `android.view.InputDevice` lookup, filtering virtual devices.
- `android/KeyboardSettingsActivity.kt`: live keyboard-status row refreshed on resume, no new permission, no fake kernel switch.
- `src/test/.../HardwareKeyboardSummaryTest.kt`: behavior and fail-closed negative input coverage.

The Q25 firmware-specific `Settings/0901` help string says Sym+0 / PaBaLF and is not a verified Titan2 keyboard shortcut. It remains pinned for provenance but is **held as device-specific**, not applied or misrepresented as an Android16 Settings feature. Real framework Settings preference-group integration remains unqualified.

## Browser and first-boot Setup owner status

Both `packages/apps/Jelly` and `packages/apps/SetupWizard` were absent in the real ai-g732 v1.1 scratch receipt. An Android WebView APK is an **engine**, not necessarily a user-facing browser; `Provision` and `ManagedProvisioning` are not by themselves proof of a full wizard. The companion read-only owner_resolver checks selected product `installed-files.json` or `installed-files.txt` for actual APK paths. Even a positive built-product listing is not a physical install/role qualification. **No installed Browser/Setup owner has been established in the evidence supplied so far**.

## Validation

Companion package `TB2_Q25_OWNER_SOURCE_RECOVERY_V1.zip`, SHA256 `6192f9cbfac9f28729d46b848ccc7008b27635eb0c7783faa5b19b2164de6bc2`, contains executable dependency-ordered read-only mirror code, owned package classifier, regression suite, and source-identical Kotlin keyboard policy. Validated:
- 26 manifest rows, Q25 Git blob identities, dependency/security/Home-exclusion invariants: **16/16** test suite PASS in approx 0.05 seconds.
- Kotlin source blob `17cf3f561fb5f19462bb167629b5231b399b8c5f` compiled with actual local kotlinc and 4 assertions PASS; Android InputDevice adapter blob `ec7bbc0baad5a45541cca6e5a158b291961f6f0b` compiled using minimal input-device test API stub and 2 assertions PASS. This is **not** an Android Gradle build.
- 80,000 owner APK path classifications 41.2ms locally; no device runtime perf assertion.
- Python compile, Bash syntax and member CRC/SHA PASS.
- **Not** compiled/applied to ai-g732 Android16 SystemUI, Keyguard, Settings, Dialer, Browser or privileged SetupWizard.

## Open for actual Android16 source completion

1. Apply/adapt 0301 before 0302 in actual `frameworks/base` SystemUI, and repair current 0304 Keyguard PIN controller hunks while maintaining safe type-ahead and no credential logging.
2. Bind or reimplement the Settings keyboard entry for the **actual Titan2** Settings hierarchy if desired. Do not import Q25 backlight firmware instructions or enable settings-only AppLock.
3. Adapt actual `Dialer/InCallActivity.java` source against 0703 then 0704 with Telecom/IMS preserved. Never force Space to answer call-waiting or answer on key repeat.
4. Bind the user-facing Browser APK and privileged first-boot setup authority to the selected new image. Existing Android Q25 Jelly/Lineage patches can only be reused if those owners are truly installed.
5. Privileged AppLock/Vault/Freezer/Dual enforcement, persistent Native34 Launcher3QuickStep HOME/Recents, effective restricted READ_SMS and selected IMS G1/G2/G3 and runtime remain independent, unqualified gates.

PR #342 historical IMS source checks are preserved; PR #344 custody report is the release-status record; PR #345 Sonar CI is independent; PR #346 is still DRAFT, UNMERGED. No active Android source mutation, no canonical `sable.sh` build, no device, no flash.
