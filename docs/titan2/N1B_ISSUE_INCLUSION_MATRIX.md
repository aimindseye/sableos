# N1B issue inclusion matrix

Status: **approved planning contract / documentation-only**

This matrix binds open `aimindseye/sableos` issues to the N1B scope. It prevents
the Titan 2 image from becoming a thin substrate or partial app bundle that misses
known Panther/Titan keyboard-first blockers.

```text
N1B_ISSUE_INCLUSION_MATRIX=YES
DOCUMENTATION_ONLY=YES
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## Inclusion categories

```text
INCLUDE_IN_N1B
  Must be implemented or have a narrowly bounded N1B-compatible fix before image
  build.

GATE_IN_N1B
  Must be represented by validation, policy, source inclusion, or artifact checks,
  but may not need full runtime completion before first UX image.

DEFER_AFTER_N1B
  May be deferred only with a written reason, fallback behavior and next stage.

EXCLUDE_FROM_DEFAULT_IMAGE
  Must not be bundled/enabled by default in N1B.

ANDROID17_PARALLEL_ONLY
  Must not alter the Android 16 R7E baseline.
```

## Open issue disposition

| Issue | Topic | N1B disposition | Required N1B treatment |
| --- | --- | --- | --- |
| #45 | Titan 2 keyboard-first interaction and physical-keyboard qualification | GATE_IN_N1B | Visible focus, type-to-search, no scan-code assumptions, keyboard validation gate |
| #48 | Keyboard devices / Sable Tools | GATE_IN_N1B | Read-only diagnostics posture only; no privileged toolbox by default |
| #79 | SystemUI / notifications / branding cohesion | INCLUDE_IN_N1B | Theme/branding/QS-shade gate; no user-facing GrapheneOS branding on Sable surfaces |
| #80 | Reader global appearance theme | INCLUDE_IN_N1B | Reader follows global appearance or full defer blocked by #123 with temporary fix |
| #81 | Media large library crash/performance | DEFER_AFTER_N1B unless evidence available | Do not block N1B without crash logs; record stress gate for next build |
| #82 | Duplicate visible Messages | INCLUDE_IN_N1B | One intentional visible messaging product; keep transport/fallback capability |
| #83 | Production icons / launch performance | INCLUDE_IN_N1B | Icon/identity audit and obvious startup stall cleanup; timing evidence when possible |
| #84 | First-run crashes during review | GATE_IN_N1B | Add historical crash capture gate; physical closure may continue after image |
| #86 | All Apps granted permission summaries | INCLUDE_IN_N1B | Granted high-signal summaries, label-first, no package-name leakage |
| #103 | Keyboard-first SableLauncher profile | INCLUDE_IN_N1B | Focus, shortcuts, square layout, no focus traps |
| #104 | Sable Camera system-image component | GATE_IN_N1B | Camera2-first inclusion or explicit N1B defer; no opaque GCam binaries |
| #105 | Sable Keyboard IME boundary | GATE_IN_N1B | Common IME/device-adapter boundary; setup usable without network |
| #106 | Titan family N0 qualification | GATE_IN_N1B | First Sable artifact gates; no inherited Titan 2 Elite/Q27 PASS |
| #112 | Weather user-managed cities | INCLUDE_IN_N1B if bounded | Add/remove city flow or explicit N1B defer with built-in defaults noted |
| #114 | KF1 device profile schema | GATE_IN_N1B | Bind N1B keyboard/device profile evidence |
| #116 | KF2 keyboard policy service | GATE_IN_N1B | Bind routing/security contract; no accessibility interception architecture |
| #118 | Titan 2 keyboard defaults | GATE_IN_N1B | Defaults recorded; runtime enablement only if safe |
| #120 | Launcher Back/Search/Peek/App security flow | INCLUDE_IN_N1B | Fix or add explicit validation/fallback before image |
| #121 | Contacts/Phone duplicate alphabet rails | INCLUDE_IN_N1B | One intentional rail or explicit removal/fix across both entry points |
| #122 | Media cramped/clipped layout | INCLUDE_IN_N1B | Portrait/Titan density fix or explicit bounded defer |
| #123 | Reader/Text Reader Vaachak import | INCLUDE_OR_DEFER_WITH_BLOCKER | Prefer import; if too large, require temporary Reader theme fix and import plan |

## Non-negotiable N1B issue gates

```text
ALL_APPS_PERMISSION_SUMMARY_REQUIRED=YES
DUPLICATE_MESSAGES_VISIBLE=NO
SETUP_AND_CRITICAL_TEXT_ENTRY_REQUIRED=YES
KEYBOARD_FIRST_LAUNCHER_REQUIRED=YES
QS_NOTIFICATION_BRANDING_THEME_GATE_REQUIRED=YES
READER_THEME_GATE_REQUIRED=YES
BROWSER_LABEL_ACCURATE_REQUIRED=YES
```

## Explicit deferral requirements

A deferral is valid only if it records all of:

```text
issue_number
reason_for_defer
temporary_N1B_behavior
risk_to_Titan2_UX
next_stage_owner
validation_or_reopen_gate
```

## Acceptance

```text
N1B_ISSUE_INCLUSION_MATRIX=PASS
AIMINDSEYE_OPEN_ISSUES_TRIAGED=YES
INCLUDE_ITEMS_HAVE_IMPLEMENTATION_OR_BLOCKED_REASON=YES
DEFERRED_ITEMS_HAVE_REASON_AND_NEXT_STAGE=YES
NO_SILENT_ISSUE_OMISSION=YES
```
