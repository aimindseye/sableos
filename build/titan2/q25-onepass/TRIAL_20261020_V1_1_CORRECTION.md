# Titan 2 Q25 source-context trial — verified ai-g732 receipt and V1.1 correction

**Source:** operator's actual 2026-10-20 `TB2_Q25_ONEPASS_TRIAL_WITH_BLOBS_20261020.json`. Original Git objects are available locally after a successful fetch; no need to re-fetch or rescan source. Trial runtime **76.318 ms**; no Android tree mutation, no build/device/flash.

## Actual V1 receipt: 16 patches

| Status | Count | IDs and meaning |
|---|---:|---|
| `PASS_SCRATCH_CONTEXT_ONLY` | **5** | `systemui-toggle`, `keyguard-clock`, `systemui-led`, `files-policy`, `files-keys`; **not Android compilation** |
| `HOLD_ANDROID16_CONTEXT_MISMATCH` | **5** | `systemui-alt-shade`, `systemui-hints`, `settings-keyboard-info`, `settings-setup-only`, `dialer-space-answer` |
| `HOLD_OWNER_NOT_PRESENT` | **4** | `browser-policy`, `browser-keys` missing exact `packages/apps/Jelly`; `setup-privacy`, `setup-remove-lineage` missing exact `packages/apps/SetupWizard` |
| `HOLD_NO_PRIVILEGED_ENFORCEMENT` | **2** | `settings-mobile-policy`, `settings-mobile-pages`; original Q25 UI alone cannot enforce security |

## Tooling correction (V1.1)

**First genuine V1 false-context diagnostic:** `systemui-alt-shade`'s patch creates nested `packages/SystemUI/src/.../SableNotificationKeyRouter.kt` and `multivalentTests/.../SableNotificationKeyRouterTest.kt`. The V1 mirror copied existing files but did not create parents of new files, producing misleading `No such file or directory`. V1.1 creates missing parent directories **in temporary scratch only** before running the existing git-apply test. It does not assume that all SystemUI hunks will now apply.

**Second V1 source-dependency misclassification:** `settings-setup-only` references files created by the withheld `settings-mobile-pages` 1102 patch (e.g. `SableSettingsFragment` and `strings_sable_mobile_manager.xml`). V1.1 declares 1103's dependency on 1102, and returns `HOLD_DEPENDENCY_WITHHELD` unless 1102 is admitted. The security gate is **not weakened**.

Other actual context holds (`systemui-hints`, `settings-keyboard-info`, `dialer-space-answer`) remain open and require Android16 source adaptation; exact Jelly and Lineage SetupWizard paths are absent, **not proof that browser/setup functionality does not exist elsewhere**.

## Tested operator handoff

`TB2_Q25_ONEPASS_REUSE_INTEGRATION_V1_1.zip` SHA-256 `5518f8ba62350dd878bd45d875d8481b4487f026591aee9763917dc764bb4a95`. Sealed SHA manifest / ZIP CRC PASS, **16/16 hermetic regressions** PASS (including nested new files, dependency-held and allowed, real Git blob and symlink failures), Python compilation and Bash syntax PASS. 200 isolated scratch trials **0.553s** locally (not Android runtime performance). One read-only trial command after archive extraction:

```bash
bash operator.sh trial \
  --source /srv/sable-build/sableos/repo \
  --android /srv/sable-build/workspaces/titan2-track-b/android \
  --output "$HOME/Downloads/TB2_Q25_ONEPASS_TRIAL_V1_1_20261020.json"
```

**No more Git fetch, checkout, host-tool discovery or requalification of already passed Native34/IMS prior scopes.** Source-only scratch results cannot establish full Q25 implementation, privileged AppLock/Freezer/Vault/Dual enforcement, selected new-image `READ_SMS` effective grant, Launcher3QuickStep HOME runtime, or IMS/VoLTE. Per owner, canonical `sable.sh` full build remains deferred until integrated source closure. PR #342 historical IMS; #344 status custody; #345 Sonar workflow; #346 draft Q25 source.
