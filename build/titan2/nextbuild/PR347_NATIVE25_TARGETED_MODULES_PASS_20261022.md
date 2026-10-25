# Track B PR347 Native25 targeted Android module compilation receipt — 2026-10-22

## Operator-reported result

The owner executed the one-file `TB2_PR347_PWM_SHADE_SCOPE_FIX_V1` operator against the existing Track B Android 16 checkout and provided its `RESULT.json`:

```json
{
  "status": "MODULES_PASS",
  "exit_code": 0,
  "targets": ["services", "SystemUI", "DocumentsUI"],
  "source_sha256": "5b45a3a980af5854c4f52b056ee64fe2d9a9f27b8d2cdc6cbbead8a576204b08",
  "out_preserved": true,
  "full_image": false,
  "device_contact": false,
  "flash": false
}
```

This is **actual incremental Android module compilation PASS**, not only a `git apply --check`, stub compilation or source-context trial. The previously observed `PhoneWindowManager.java` four-symbol javac failure is resolved at the selected corrected source SHA256.

## Exact scope qualified

- Native25: nine nonduplicating upstream Q25 patch candidates staged in the original Track B Android workspace, touching 25 source paths. The Q25 0703 generic Dialer duplicate remains quarantined in favor of existing `SableTitanInCallKeys`.
- Exactly **three requested module targets**: `services`, `SystemUI`, and `DocumentsUI` returned combined exit code zero.
- Native PWM correction exact SHA256: `5b45a3a980af5854c4f52b056ee64fe2d9a9f27b8d2cdc6cbbead8a576204b08`.
- Original `out/` preserved and reused; no clean, full system image, OTA, device or flash.

## Evidence boundary

This receipt was copied from the owner's AI-G732 console; the complete `module.log` and resulting selected APK/image artifacts were **not independently examined** for this record. Do **not** construe the target PASS as installation, product makefile inclusion, updated signed image, system boot, keyboard/role runtime correctness, or mobile network/IMS working.

This passes the previously open **Native25 module compilation** sub-gate, but does not close the remaining Q25 conformance checklist or security/role/IMS source or device qualifications. At original `build/titan2/nextbuild/Q25_SOURCE_READINESS.json`, 22/23 feature items are still `open` (one N/A), plus eight further `requirements` `open`. Do not silently mark these as done, relax `check-ready.py`, authorize full image/flash or close PR347.

Pinned upstream PR346 Git HEAD remains `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`, while the owner's local Track B Android source and incremental output have intentionally been advanced for PR347 staging and module compilation.

## Next engineering objective

Address remaining higher-risk native behavior and owner identification in PR347 (Keyguard 0304/Alt+Space framework routing, installed browser and actual first-boot wizard, privileged security/profile enforcement, SMS role, IMS G1/G2/G3), while preserving successful incremental module state. Avoid repeating Native25 source-admission tests or rebuilding the entire ROM solely for this module status.
