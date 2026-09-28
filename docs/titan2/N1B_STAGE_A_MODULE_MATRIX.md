# N1B Stage A module matrix

Status: **contract / module inventory seed**

This file seeds the Stage A module-family matrix. Implementation PRs must replace
or extend placeholder paths with exact repository paths and build commands as
code lands.

```text
N1B_STAGE_A_MODULE_MATRIX=YES
N1B_STAGE_A_MODULE_INVENTORY_REQUIRED=YES
N1B_STAGE_A_EXACT_BUILD_COMMANDS_REQUIRED=YES
```

## Matrix rules

Each row has one of the following N1B Stage A classifications:

```text
INCLUDE_REQUIRED
INCLUDE_IF_IMPLEMENTED
EXPLICIT_DEFER_ALLOWED
POLICY_GATE_ONLY
BLOCK_IF_MISSING
```

A required row cannot silently disappear from the N1B image plan. If not
implemented in Stage A, it must have a defer row with owner, reason, issue/doc
reference, and next stage.

## Required rows

| module_family | Stage A classification | profile scope | Panther risk | Titan 2 risk | Stage A requirement |
| --- | --- | --- | --- | --- | --- |
| Setup Wizard / First Boot | BLOCK_IF_MISSING | shared + keyboard-first | medium | critical | build/wire first-run flow or record temporary fallback with blocker |
| Critical text-entry plumbing | BLOCK_IF_MISSING | shared + keyboard-first | medium | critical | build fallback path for setup/system text-entry surfaces or block |
| Sable Start / Launcher | INCLUDE_REQUIRED | shared with profile behavior | high | high | build touch-first and keyboard-first paths without globalizing Titan defaults |
| All Apps privacy summaries | INCLUDE_REQUIRED | shared | medium | high | build granted-permission summary path and no package-name default leakage |
| App favorites / sorting | INCLUDE_REQUIRED | shared | low | medium | build favorites-first sorting with Panther-safe behavior |
| Sable Command / Search | INCLUDE_REQUIRED | shared + keyboard-first | medium | high | build profile-safe type-to-command/search behavior |
| Sable Hub | INCLUDE_REQUIRED | shared | medium | high | build Hub with people/app favorites and provider-safe boundaries |
| Messages product composition | INCLUDE_REQUIRED | shared | high | high | remove duplicate visible Messages path or record bounded defer |
| Sable Mail integration | INCLUDE_REQUIRED | shared | medium | high | build Hub-to-Mail integration and provider ownership boundaries |
| Contacts / Phone / People | INCLUDE_REQUIRED | shared | medium | high | build people model and rail/entry-point fixes or explicit defer |
| Quick Settings / Notification Shade | EXPLICIT_DEFER_ALLOWED | system surface | high | high | include if bounded; otherwise record explicit defer and no branding regression |
| Lockscreen / Secure Entry | EXPLICIT_DEFER_ALLOWED | system surface | high | critical | include if bounded; otherwise explicit defer with critical text-entry block noted |
| Browser / WebView identity | INCLUDE_REQUIRED | shared | low | medium | build accurate Vanadium/browser label path where Sable owns UX |
| Reader / Text Reader | EXPLICIT_DEFER_ALLOWED | shared | medium | medium | build global theme fix or record Vaachak import defer |
| Media / Gallery | EXPLICIT_DEFER_ALLOWED | shared | medium | medium | build portrait/square density fix or explicit defer |
| Weather / utilities | EXPLICIT_DEFER_ALLOWED | shared | low | medium | build city management if bounded or explicit defer |
| Settings profile policy | INCLUDE_REQUIRED | shared + profile | medium | high | build/record profile-aware surfaces and no duplicate network authority |
| Sable Keyboard / IME boundary | POLICY_GATE_ONLY | keyboard-first | low | critical | record boundary and build only if implementation is ready |
| Sable Camera | EXPLICIT_DEFER_ALLOWED | shared + device profile | medium | medium | include ordinary Camera2 path if ready; privileged paths deferred |
| Developer Profile tools | POLICY_GATE_ONLY | keyboard-first/work profile | low | low | no personal-profile bundle; policy only |
| Titan touchpad daemon | POLICY_GATE_ONLY | Titan hardware | low | high | remain disabled until physical validation |
| Android 17 N0C | POLICY_GATE_ONLY | research | low | low | parallel only, no baseline pivot |

## Stage A inventory output

The Stage A implementation branch must create a TSV inventory:

```text
N1B_STAGE_A_MODULE_INVENTORY_PATH=docs/titan2/N1B_STAGE_A_MODULE_INVENTORY.tsv
```

Required header:

```text
module_family	repo_path	build_command	profile_scope	panther_gate	titan2_gate	status	defer_reason	issue_or_doc_reference
```

## Build evidence rule

Each row promoted to PASS must point to a build command and result. Documentation
intent alone does not satisfy Stage A.

```text
N1B_STAGE_A_BUILD_EVIDENCE_REQUIRED=YES
N1B_STAGE_A_STATIC_ONLY_IS_NOT_PASS=YES
N1B_STAGE_A_DEFER_REQUIRES_REASON=YES
```

## Guardrails

```text
DOCUMENTATION_ONLY=YES
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
```
