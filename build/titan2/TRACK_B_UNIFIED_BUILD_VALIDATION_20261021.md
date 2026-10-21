# Track B unified build wiring: validation and limits (2026-10-21)

This is an **integrated-build source change**, not a detached gate or an Android image qualification.

- Canonical driver `build/titan2/run-track-b-integrated.sh`: local `bash -n` PASS. Remote Git blob was re-fetched and exactly matched local `git hash-object`.
- Added `run_titan2_tb2_apps` CI function: exact function-body `bash -n` PASS; full remote 33KB `build/local-ci/run.sh` was not materialized into the test container for whole-file syntax parsing. Its function/stage placement was verified in GitHub source.
- Six hermetic Python unit tests on a synthetic repository: PASS in 0.210 seconds. Cases cover one full-CI run with `SABLEOS_DEVICE=titan2`, `SABLEOS_RELEASE_VERSION=TB2`; AOSP systemimage/target-files/otatools goal invocation; collection of both CI and AOSP failures; mode refusal; missing Android source refusal; absence of device/flash actions.
- Zero real ai-g732 full-CI or Soong image execution in this delivery. The mock test elapsed time is **not a performance measurement for Kotlin/Soong builds**.
- The existing full CI already owns R8 source/apps and Detekt/ktlint; do not run R8 Gradle again. The TB2-specific Titan app set (displaycompat, keyboard, camera, setup, tools) is included **once in that canonical CI**. The build driver calls the full CI once, then AOSP `m systemimage target-files-package otatools` once and retains both stage logs.
- No `N1B2` flash/image restrictions changed; no AOSP mutation by the connector commit; OEM/FLOSS IMS selected product, privileged Q25 features, HOME role, and APK installation graph remain unqualified.
- Previously encountered `SetupReader.kt` hidden constant compiler error is corrected at source (public `Settings.Secure.getInt` with key `user_setup_complete`), but integrated Kotlin compilation was not run after the change.

**Disposition:** `PASS_BUILD_ENTRYPOINT_CODE_TESTS_ONLY`; `FULL_Q25_IMS_SOURCE_CONVERGENCE=OPEN`; `IMAGE_OR_FLASH_READY=NO`. Do not convert a successful AOSP compiler run into a complete product qualification if the application/IMS installed graph is absent.
