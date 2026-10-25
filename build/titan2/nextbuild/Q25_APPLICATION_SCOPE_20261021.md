# Titan 2 next-build Q25 application conformance — source-completion ledger
Date: 2026-10-21
Base: `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`
Development: `titan2/nextbuild-q25-app-conformance-20261021`
Current-build custody: **PR 346 and its running Android16 AOSP workspace must not be modified by this branch.**

## Authority and meaning
- Q25: `aimindseye/zinwaq25-sableos`, upstream `sable-src` sources.
- Design: `sableos-project/platform_sable/docs/design` plus the original `DESIGN_CONFORMANCE_Q25.md` SHA256 `741c7f3fdd31c8740372738281da6c407d4b9f39cd1ec2448248351ca38bdae2`.
- Current Android16 code: `aimindseye/sableos` PR346 base commit above, canonical stage plus retained host AOSP local commits.
- Original review: **23 rows / 24 artifact references: 18 Partial, 2 Done, 1 Done in code, 1 Missing, 1 N/A**. The historical statuses describe Q25 source, **not** completed Android16 runtime.
- A row's old `Done` status is not enough to mark selected-image closure. This table does not claim completion of all portable features.

## Exact 23-row mapping and current next-build disposition

| # | Exact Q25 artifact row | Q25 review | What is reused or newly implemented | Next-build closure still required |
|---:|---|---|---|---|
| 1 | `start-titan2-3page` | Done in code | Q25 16-file SableLauncher port: Glance/Home/Hub, BB10 dashboard, ordered quick bar, persisted Home and Glance edits | Native selected HOME/Quickstep role, APK/Soong compile, runtime and visual acceptance open |
| 2 | `all-apps-titan2` | Partial | Q25 profile-aware LauncherApps/permission/AppOps readers and caches, privacy detail/actions, private-space state; PR347 keyboard/chip policy retained | Verify Android16 signature permissions, locked profile lifecycle, UI compile and physical input |
| 3 | `command-titan2` | Partial | Q25 Command query/ranking and full upstream screen; explicit cross-app OPEN_COMMAND activity entry plus Hub > Command action | System-wide Alt+Space still requires A16 global input policy; People/SMS runtime gates |
| 4 | `hub-titan2` | Partial | Hub Q25 semantics already present; added explicit Hub > Command action with fail-closed unavailable state | Verify subfilters, locked-state redaction, refresh and keyboard runtime, true SMS role |
| 5 | `messages-conversation-titan2` | Partial | Q25 `MessagesInteractionModel.kt` identical Git blob `66cf923d1b8b6185adb461be1347bdf2336d49ae` | End/Esc latest, PageUp, in-thread search/new-message pill, selected default SMS role/READ_SMS policy |
| 6 | `phone-dialer-titan2` | Partial | Existing seven SystemUI/Dialer native edits compiled and local-committed on AI-G732 | Dial screen letters/recents privacy, Telecom/role/source-owner runtime |
| 7 | `contacts-people-titan2` | Partial | Existing Android16 Contacts provider owner | Route subtitle, Hub route chip, private work profile lock states |
| 8 | `lockscreen-titan2` | Partial | Native A16 PIN source compiled/committed | Count row, private cards/Locked badge, accessible emergency input policy |
| 9 | `quick-settings-titan2` | Partial | Historical Q25 framework patch candidates | Hub summary, slash search/hint, decide 2-v-3 layout; actual A16 SystemUI integration |
| 10 | `settings-titan2 / -approved` | Partial | Titan Keyboard Settings and read-only Setup status | Keyboard/Input/Diagnostics approved placement, focus-ring parity without counterfeit privileges |
| 11 | `setup-wizard-titan2` | Partial | Read-only post-provision Setup helper now has review step labels and keyboard-first Android Wi-Fi instructions | Actual privileged first-boot wizard unknown; do not claim provisioning, restore or device owner |
| 12 | `battery-health-usage-titan2` | Done | Historical Q25 source only | Verify selected Android16 battery screen and real available measurements |
| 13 | `mobile-manager-app-controls-titan2` | Partial | UI/Settings concepts retained | Privileged App Control/Freezer/Student lifecycle enforcement, not placebo UI |
| 14 | `private-space-dual-work-titan2` | Partial | Q25 acknowledged stored-but-unenforced AppLock | Real AppLock/secure Vault/private profiles/Dual state or hide unimplemented controls |
| 15 | `connectivity-otg-nfc-cast-titan2` | Partial | DisplayCompat state source and package | OTG/NFC/Cast hub, and actual WindowManager display-profile enforcement |
| 16 | `camera-capture-titan2` | Partial | Preserved already implemented Z/Alt+Z zoom and R RAW; added direct-touch-only preview guard tested in JVM | Focus reticle/hint dock, actual Camera role and HAL/touchpad device qualification open |
| 17 | `browser-webview-titan2` | Partial | Q25 Jelly 1041/1042 patches already retained; prior host source report has no Jelly owner | Identify selected browser owner; real T/B/L, tabs/start cards/reader A16 integration open |
| 18 | `files-documents-titan2` | Partial | Q25 DocumentsUI 1001/1002 patches already retained, prior A16 scratch-context PASS | Adapt to exact ai-g732 selected DocumentsUI source; compile J/K/T/E/V/F and preview SAF policy |
| 19 | `mail-calendar-titan2` | Partial | Current Calendar already implements Week mode, NOW row and browse keyboard policy; no downgrade to older Q25 | Selected Calendar APK freshness and full keyboard/viewport runtime qualification open |
| 20 | `media-gallery-titan2` | Partial | Selected TB2SableMedia prebuilt | Key labels, caption strip, conflict over S=Share |
| 21 | `utilities-notes-recorder-titan2` | Missing | Calculator present, Tools existing | Notes/Recorder/Clock app implementations; do not expose empty placeholders as complete |
| 22 | `toolbox-hardware-titan2` | Done | Selected TB2SableTools; strict Detekt/ktlint/unit/debug APK PASS | Verify selected APK freshness and hardware capability gates |
| 23 | `subscreen-shortcut-keyboard-titan2` | N/A | No Q25 rear display | Not applicable; Titan 2 magic key is separate feature and must not inherit false Q25 assumptions |

## PR347 code-first delivery now in scope

- `model/CommandQuery.kt`: **byte-identical Q25 upstream file**, Git blob `76d67ab365ec20fc9d54ca7afbeba82638f7efa4`; pure Kotlin (no Android permission/telephony access).
- `privacy/AllAppsInteraction.kt`: **byte-identical Q25 upstream file**, Git blob `18591715002707aa5878266c34f795e357e7b573`; keyboard policy, focus protection, and confirmation contract.
- Existing `SableStartScreen.kt` uses parsed query scopes, Settings destinations, recency/prefix-aware app ranking and All Apps Search/type-to-jump. It **does not** treat people/SMS content as generally searchable; the owner app stays authoritative.
- Existing `SableStartActivity.kt` opens only approved public Settings action strings with fallback to Settings; no private API/role elevation.
- Existing Soong `Android.bp` includes the two pinned Q25 policy owners plus a local-only granted-permission chip policy. The chip filter never treats unknown profile permission state as a grant and does not claim AppOps activity. Host-only pure Kotlin smoke test exercises 28 assertions, no device/flash.

## Reuse checks and build boundary

- Q25 `HubScreen.kt` and PR346 are close but not byte-identical; do not overwrite PR346 Hub enhancements without semantic diff.
- `MessagesInteractionModel.kt` is byte-identical and **must not** be reimplemented.
- Q25 vs PR346 Calendar and Camera differ significantly; preserve later Android16/provider/quality fixes. No blind full-file swap.
- 13 `TB2Sable*` source graph, SableLauncher/Quickstep roles and PhhIms/Iwlan selected source are retained from PR346. APK existence is not proof of fresh source identity or installed functionality.
- IMS source closure remains open for service/package/signer/privapp/classloader/vendor-ABI G1/G2/G3 before the next qualifying full build. Live IMS/VoLTE requires later device evidence.
- No changes in this branch to the running AOSP workspace, Soong image outputs, PR346 or hardware. The next-build readiness check is intentionally **HOLD** until all required rows and IMS source contracts have evidence.

## Five explicit product decisions still needed

1. Emergency shortcut: Alt+E, Sym+E or none (never unmodified E).
2. Diagnostics placement: top-level Settings or under Keyboard/Input.
3. Quick Settings: 2 versus 3 columns.
4. Seedvault restore: fail-closed hidden until true provisioning authority established versus shipping active validated restore.
5. Legacy LineageOS Settings rows: preserve mandatory legal attribution while deciding retained/replaced layout.

**Status: FIRST_SOURCE_SLICE_PORTED; FULL_23_ROW_Q25_CONFORMANCE=OPEN; NEXT_AOSP_BUILD=HOLD.**
