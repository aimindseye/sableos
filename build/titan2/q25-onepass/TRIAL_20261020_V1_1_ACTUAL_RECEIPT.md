# Track B Q25 one-pass V1.1 — actual host receipt and source-aware reclassification

Date: 2026-10-20. Input: user-provided `TB2_Q25_ONEPASS_TRIAL_V1_1_20261020.json` (ai-g732), schema `sableos-q25-onepass-v1.1`. This is a **source-context trial**, not a feature, image, or device qualification.

## Verified observed outcomes

| State | Count | Patch IDs |
|---|---:|---|
| `PASS_SCRATCH_CONTEXT_ONLY` | **5** | `systemui-toggle`, `keyguard-clock`, `systemui-led`, `files-policy`, `files-keys` |
| `HOLD_ANDROID16_CONTEXT_MISMATCH` | **4** | `systemui-alt-shade`, `systemui-hints`, `settings-keyboard-info`, `dialer-space-answer` |
| `HOLD_OWNER_NOT_PRESENT` | **4** | `browser-policy`, `browser-keys` (Jelly), `setup-privacy`, `setup-remove-lineage` (Lineage SetupWizard) |
| `HOLD_NO_PRIVILEGED_ENFORCEMENT` | **2** | `settings-mobile-policy`, `settings-mobile-pages` |
| `HOLD_DEPENDENCY_WITHHELD` | **1** | `settings-setup-only` requires withheld `settings-mobile-pages` |

Elapsed: **65.727 ms**; operator test suite **16/16 PASS** in **0.453 s**, with 200-trial synthetic benchmark **0.426 s** on ai-g732. `source_mutation`, `build`, `device_contact`, `flash`: all `false`. No PR #346 Android source actually applied/compiled.

## IMPORTANT correction to earlier V1/V1.1 interpretation

The unchanged `systemui-alt-shade` failure is **not merely a missing scratch parent directory**. Inspection of the **exact pinned original Q25 0302 Git blob** `363c8cec1851cfcf53311340dc6391532b04428c` shows three ordinary *modifications* (`index old..new 100644`, `--- a/...`, not `new file mode`) of:

- `packages/SystemUI/src/com/android/systemui/statusbar/notification/row/SableNotificationKeyCommands.kt`
- `packages/SystemUI/src/com/android/systemui/statusbar/notification/row/SableNotificationKeyRouter.kt`
- `packages/SystemUI/multivalentTests/src/com/android/systemui/statusbar/notification/row/SableNotificationKeyRouterTest.kt`

Those files are **pre-existing upstream-Q25 Sable keyboard-policy sources** expected by 0302, but they are absent from the scratch copy of the current selected Android16 owner. V1.1 correctly creates directories for genuine added files, but that cannot supply the **contents of missing preconditions**. Only `services/core/java/com/android/server/policy/sable/SableShadeKeys.java` is a new file in 0302. Do not run another unchanged trial or label this fixed. Locate/reuse the earlier Q25 owner source with precise provenance or adapt the feature in the real Android16 owner; preserve keyguard/IME security restrictions.

`dialer-space-answer` 0704 similarly modifies an existing `java/com/android/dialer/sable/SableInCallKeys.java` (ordinary `index old..new 100644`) and also has *real* `sound_settings.xml` and `InCallActivity.java` hunk mismatches; do not fix this with mkdir either.

`systemui-hints` and `settings-keyboard-info` are genuine source-context mismatches on the observed checkout and require owner adaptation. `settings-setup-only` now correctly records `HOLD_DEPENDENCY_WITHHELD` due to AppLock/Settings 1102, not an independent merge failure. Jelly and Lineage SetupWizard are absent under those exact paths (other owner implementations not disproven).

## Decision

`ONEPASS_V11_RECEIPT=VALID`; `ALTSHADE_PARENT_MKDIR_FIX=INSUFFICIENT_NOT_A_SOURCE_CLOSURE`; `AUTO_PROMOTE=NO`; `Q25_FULL_IMPLEMENTATION=OPEN`. Do **not** re-fetch Q25 Git blobs, repeat host tool scans or redo the same scratch test. Next source work: bind actual Android16 SystemUI notification keyboard prerequisite implementation, adjust PIN/Settings/Dialer hunks to the current owner, resolve Browser/Setup ownership, implement real privileged Mobile Manager enforcement, preserve Launcher3QuickStep HOME and existing IMS authority, and only then qualify actual Android build/image/runtime.

PR #342 IMS historical scope remains independent, #344 custody updated, #345 CI Sonar unaffected, #346 actual application and original patch-source custody remains draft/unmerged. No `sable.sh`, image, device, flash, or PR merge reported.
