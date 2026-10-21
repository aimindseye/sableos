# Exact Q25 design conformance → Titan 2 Track B Android 16 source reconciliation

**Source:** Owner-uploaded `DESIGN_CONFORMANCE_Q25.md`, independently SHA256 checked as `741c7f3fdd31c8740372738281da6c407d4b9f39cd1ec2448248351ca38bdae2`, same file identified by the Oct 20 second IMS admission report. This document is a Q25 port comparison against `sableos-project/platform_sable/docs/design/artifacts` on `aimindseye/zinwaq25-sableos` branch `claude/project-thread-p8uj72`, **not** an Android16 selected-image test. Its `## Fixed for the next build` is a report of Q25 *source*, not a host-flashed Titan 2 result.

**Exact source table:** 23 visible rows covering the review's stated 24 artifacts because `settings-titan2 / -approved` denotes two artifact references in one row. Counts: **18 Partial, 2 Done, 1 Done in code, 1 Missing, 1 N/A**. In the earlier two IMS JSONs, 19 pending mentions consisted of the 18 partial rows **plus a status-word definition**. Those reports inspected but did not certify Q25 or Android16 behavior. Never say that all 24 were Partial or that fixes were device-qualified.

## Already implemented in Q25 source, requiring Android16 ownership review

| Q25 report under “Fixed for the next build” | Source-port implication (not qualified for Titan2) |
|---|---|
| Sable Start Glance / Home / Hub, editable weather/apps/bar/widgets | Preserve three-page design; the *existing* PR346 SableLauncher uses different `Start, Apps, Search, Live, ...` destinations. Map behavior instead of blindly copying Lineage/Q25 Launcher3. The actual active 13-app TB2 product has **not established SableLauncher as installed HOME**. |
| PIN bouncer number-key mapping, focus and prompt | Reuse existing **7 compiled native A16 SystemUI/Dialer** changes from Phase12/13; distinguish PIN implementation from unimplemented count row and emergency shortcut. No reapply/recompile merely for proof. |
| Centered clock / swipe-to-unlock | Q25 source styling, not proof that the exact A16 SystemUI selected overlay contains it. |
| Lineage Setup/Launcher leftovers | Q25-specific Lineage owner paths; do not assume the A16 Treble base has identical SetupWizard/Launcher3 Settings/Updater. |
| Settings > Sable contains Setup only | Preserve this existing product direction; top-level Keyboard/Input and Diagnostics placement separately requires a decision. |
| Keyboard light help note instead of hardware override | Q25 hardware/FW statement; Titan 2 behavior needs owner-specific mapping. Do not create a fake backlight toggle. |
| Alerting notification LED cadence / red, amber, green | Q25 framework/source design claim, not verified on Titan 2 LED driver. |

## All artifact statuses and required A16 source owners

| Design artifact | Exact Q25 status | Evidence already in PR346 / owner to reconcile | Remaining implementation for Track B |
|---|---|---|---|
| `start-titan2-3page` | Done in code | Standalone `src/android/packages/apps/SableStart` exists; `platform_sable` specifies SableLauncher HOME, Quickstep Recents-only | Align 3-page screen model and install SableLauncher; patch A16 Launcher3 HOME, verify default role; missed-call count not assumed accessible |
| `all-apps-titan2` | Partial | Native34 Launcher3 privacy filters/classes compiled (structural APK check) | Verify and implement chips, slot picker, permission match grouping in selected launcher |
| `command-titan2` | Partial | SableStart local Search code exists | Best-match row, result commands/locked state, Alt+Space global owner |
| `hub-titan2` | Partial | `apps/r8/android/hub` present and selected as `TB2SableHub` | Filters, slash search, actions sheet and counts-only private mode; do not equate source presence to visual parity |
| `messages-conversation-titan2` | Partial | Portable Messages source exists; not selected as default SMS by current 13-app product | End/Esc, PageUp, in-thread search, new-message pill and restricted SMS role/permission policy |
| `phone-dialer-titan2` | Partial | Compiled A16 `packages/apps/Dialer` in-call-key source snapshot | Dial-screen letter-to-digit mapping and recents privacy, Telecom call-waiting protection |
| `contacts-people-titan2` | Partial | Existing A16 Contacts provider/app owners must be inspected | Route subtitle, Hub chip and locked-state presentation |
| `lockscreen-titan2` | Partial | Compiled A16 Keyguard PIN owner already in Phase13 snapshot | Counts row/private card/Locked badge and accessible emergency action; don't map E directly to emergency |
| `quick-settings-titan2` | Partial | Existing SystemUI Q25 source candidates; 2-vs-3 columns unresolved | Hub summary, help hint, slash search, decide layout; reject unsupported phone keyboard light toggle |
| `settings-titan2 / -approved` | Partial | Current A16 Settings/keyboard has not been source-qualified for Q25 visual rows | Top-level Keyboard & input / Diagnostics and consistent focus ring; preserve Setup-only Settings > Sable intent |
| `setup-wizard-titan2` | Partial | PR346 `apps/titan2/platform/setup` is **read-only Setup checklist**, not privileged first-boot SetupWizard | Step counter, Wi-Fi hints, navy cards, fail-closed restore; qualify actual Android16 first-boot owner |
| `battery-health-usage-titan2` | Done | Q25-only source claim | Check existing A16 Battery screen and device facts; no fabricated hardware readings |
| `mobile-manager-app-controls-titan2` | Partial | UI sources are not proof of privileged controls | App Control Center, Freezer and Student mode require real ActivityManager/device policy enforcement |
| `private-space-dual-work-titan2` | Partial | Q25 report explicitly says App Lock **stored but not enforced** | Real launch gate or hide toggle; Secure Vault, Dual/private profiles, SELinux/users lifecycle |
| `connectivity-otg-nfc-cast-titan2` | Partial | DisplayCompat selected APK is not proof that profile actions apply | Connectivity card hub, actual display profile enforcement |
| `camera-capture-titan2` | Partial | **Q25 said Z/R missing, but current PR346 `KeyMap.kt` already binds Z→ZoomIn, Alt+Z→ZoomOut, R→RawToggle.** Verified from actual source. | Do not redo shortcuts; verify touch/trackpad guard and focus reticle/hint dock, select Sable Camera default only after role/supported intent proof |
| `browser-webview-titan2` | Partial | Q25 Jelly assumptions do not map to missing A16 Jelly owner | T/B/L arbitration, tabs, start cards, reader mode in actual installed browser |
| `files-documents-titan2` | Partial | A16 DocumentsUI source owner exists but no compiled Q25 modifier proof | Single-key policy, 3-pane preview, J/K/T/E/V/F actions |
| `mail-calendar-titan2` | Partial | Existing `TB2SableMail`/`TB2SableCalendar` selection | Week view/NOW marker and C/T/V/J/K/R keys in actual Calendar; preserve Mail work |
| `media-gallery-titan2` | Partial | Existing `TB2SableMedia` selection | Key labels and gallery caption, resolve S=Share design conflict |
| `utilities-notes-recorder-titan2` | Missing | Existing Calculator selected, not Notes/Recorder/Clock/Home | Implement actual apps before enabling placeholders |
| `toolbox-hardware-titan2` | Done | PR346 Tools source present, selected `TB2SableTools` | Preserve deliberate grid-home design; hidden-until-TOOLS-I5 remains product decision |
| `subscreen-shortcut-keyboard-titan2` | N/A | Q25 no rear screen | Do not port rear-screen logic blindly; “Magic” key shortcuts are separate input-policy work |

## Five unresolved owner decisions from the original file

1. Emergency shortcut for lock screen: **Alt+E, Sym+E, or no shortcut**. Avoid E itself because Q25 E types digit 2. Confirm Titan 2 keyboard policy independently.
2. Diagnostics Settings location: separate top-level row or within top-level Keyboard & input; **Settings > Sable remains Setup only** unless explicitly changed.
3. Quick Settings two large columns versus the artifact's three columns.
4. Seedvault restore during Setup: leave live or **fail-closed hidden until validated** (safer provisional implementation, but requires owner choice to ship).
5. LineageOS Settings legacy rows (version, legal, contributors, Trust, statistics): retain, relocate or remove with coherent Android16 policy. Do not remove mandatory legal/attribution blindly.

No decision was silently made by this review. In particular, **platform_sable** independent design contract states `SableLauncher HOME`, `Launcher3 not HOME`, `Quickstep retained for Recents`; current A16 native manifest patch is staged on PR346 but not applied on ai-g732.

## Original priority sequence (preserved, with implementation grouping)

1. Lock-screen count line + software-keyboard text.
2. Camera Z/R, trackpad guard, default Camera (Z/R already present in PR346).
3. Settings Keyboard & input row and consistent focus ring.
4. Shade Hub summary/help.
5. Calendar week and keys.
6. Browser/Files conflicts, Command/Hub missing behavior.
7. Setup hints/step counter.
8. Only with true system enforcement: Dual apps, actual display profiles, AppLock enforcement or hide placebo.
9. Later: App Control Center, Freezer, Secure Vault, Student, connectivity cards, Notes/Recorder/Clock.

**Build strategy:** complete these as **one Android16 source convergence** on PR346 plus exact AOSP project commits, reuse existing 13 `TB2Sable*` install graph/PhhIms selection and compiled SystemUI/Dialer source, then run the one canonical `sable.sh titan2 TB2 build --direct` workflow. No parallel `SableTB2*` imported apps, no standalone quality gates, no device/flash permission implied.

**Evidence limits:** This mapping is a static source comparison and the exact uploaded Q25 review, not an application/UI runtime or all-framework source audit. `PR346_FULL_Q25_DESIGN_CONFORMANCE=OPEN` until actual owner source changes and selected image demonstrate behavior. PR342 is historical IMS/AVB provenance, PR344 custody, PR345 Sonar-only, PR346 active integration.
