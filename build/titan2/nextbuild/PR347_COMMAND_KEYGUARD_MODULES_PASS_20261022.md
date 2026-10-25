# PR347 Command + Keyguard Android 16 native modules — operator compile PASS (2026-10-22)

## Actual AI-G732 receipt

The operator resumed the already-staged source via `TB2_PR347_COMMAND_MODULE_RESUME_V1_1` in the existing `/srv/sable-build/workspaces/titan2-track-b/android`, using its existing incremental `out/`. Full console result supplied:

```
#### build completed successfully (04:18 (mm:ss)) ####
PR347_COMMAND_KEYGUARD_MODULE_RESUME_RC=0
```

```json
{
  "status": "MODULES_PASS",
  "exit_code": 0,
  "targets": ["services", "SystemUI"],
  "new_module_log": "resume-module.log",
  "original_result_preserved": true,
  "original_module_log_preserved": true,
  "out_preserved": true,
  "source_mutation": false,
  "full_image": false,
  "device_contact": false,
  "flash": false
}
```

**Decision:** actual Android16 module compilation PASS, **not** just host-side Java/Kotlin smoke. `PhoneWindowManager.java` physical Alt+Space Command case at SHA256 `6ebb07b1241222d51c5401ff6165046d708c790bc953cab030313d36f8fa01ad` was staged earlier; `KeyguardKeyEventInteractor.kt` hardware Escape-to-Back case at SHA256 `bea9759c81e251bf6d1a1da4b606985b15cf21c197482d1a6dd165fdd911681e` was staged earlier. Corrected resume wrapper does not mutate those sources. Compiled targets are `services` and `SystemUI`; exit code 0.

## Historical context retained

The first module operator already staged both source paths, then failed **before Ninja** while sourcing `build/envsetup.sh` with Bash `set -u` (`TOP: unbound variable`). The V1.1 retry ran normal Android shell setup with `nounset` disabled, preserved original failed `RESULT.json` and `module.log`, and produced `RESUME_RESULT.json`/`resume-module.log` separately. This new receipt supersedes the earlier failure status **for the retry**; it does not overwrite the historical failure evidence.

Prior Native25 `services/SystemUI/DocumentsUI` source revision compiled successfully, and is not regressed merely by this reported result. Duplicate generic Q25 Dialer owner 0703 remains quarantined.

## Limits / still-open requirements

This is owner-provided `RESUME_RESULT.json` and a success line. The full `resume-module.log`, selected packaged APKs, effective image, user role/provisioning, and hardware runtime have not been independently examined for this receipt.

Actual global Command invocation must still be exercised on an unlocked, setup-complete Titan 2 with an installed exported Sable Start activity, alongside IME text-entry/keyguard behavior and event consumption. Keyguard Escape must be validated on the physical keyboard and with secure bouncer/back behavior, not just built.

Q25 selected browser ownership, first-boot privileged wizard, AppLock/Vault/Freezer/profile enforcement, hard-restricted SMS/default role, and IMS G1 service/classloader, G2 linker ABI, G3 vendor transport + live registration are OPEN. Keep PR347 draft and the full-image `check-ready.py` gate fail-closed; do not claim ready to flash. PR346 pinned remote HEAD `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab` has not been modified, although the owner's local Track B Android checkout/out intentionally contains PR347 changes.
