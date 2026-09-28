# N1B platform_sable traceability

Status: **approved planning contract / documentation-only**

N1B is the first Titan 2 SableOS UX-evaluation image candidate. It must be
derived from the approved common SableOS design and portability contracts in
`sableos-project/platform_sable`, the Titan 2 device gates in
`sableos-project/device_sable_titan2`, the integration issues in
`aimindseye/sableos`, and the bounded Titan 2 research handoff in
`aimindseye/unihertz-titan2`.

```text
N1B_PLATFORM_SABLE_TRACEABILITY=YES
DOCUMENTATION_ONLY=YES
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
PUBLIC_RELEASE=NO
```

## Authority order

```text
1. sableos-project/platform_sable
   Common architecture, semantic, UX, visual, portability and release contracts.

2. sableos-project/device_sable_titan2
   Titan 2 / Titan 2 Elite public device-adapter boundary, R7E pass seal,
   deployment gates and N0C research posture.

3. aimindseye/unihertz-titan2
   Bounded private-evidence research handoff, stock/vendor/AVB/super constraints,
   N0 acceptance matrix and first-Sable bring-up contract.

4. aimindseye/sableos
   Private integration implementation, open issues, build evidence and N1B code.
```

Cross-repo documents may cite or summarize the platform contracts, but must not
copy profile facts as an independent source of truth.

## Platform design contracts bound to N1B

N1B must trace to these `platform_sable` contracts before product code is treated
as image-ready:

```text
ARCHITECTURE.md
DEVICE_SUPPORT_LEVELS.md
PORTABILITY_RULES.md
RELEASE_MODEL.md
CRITICAL_TEXT_ENTRY_GATES.md
KEYBOARD_FIRST_DEVICE_PROFILE_MODEL.md
KEYBOARD_AND_POINTER_PROFILE_MODEL.md
DISPLAY_AND_ATTENTION_PROFILE_MODEL.md
KEYBOARD_DEVICE_TOOLS.md

docs/design/SETUP_WIZARD_FIRST_BOOT_UX.md
docs/design/LOCKSCREEN_SECURE_ENTRY_UX.md
docs/design/QUICK_SETTINGS_NOTIFICATION_SHADE_UX.md
docs/design/SABLE_START_KEYBOARD_FIRST_UX.md
docs/design/ALL_APPS_PRIVACY_UX.md
docs/design/SABLE_COMMAND_SEARCH_UX.md
docs/design/SABLE_HUB_KEYBOARD_FIRST_UX.md
docs/design/SABLE_PHONE_DIALER_UX.md
docs/design/CONTACTS_PEOPLE_UX.md
docs/design/MESSAGES_CONVERSATION_UX.md
docs/design/BROWSER_WEBVIEW_UX.md
docs/design/MAIL_CALENDAR_PRODUCTIVITY_UX.md
docs/design/MEDIA_GALLERY_UX.md
docs/design/CAMERA_CAPTURE_QUALITY_UX.md
docs/design/FILES_DOCUMENTS_UX.md
docs/design/UTILITIES_NOTES_RECORDER_UX.md
```

If a referenced design file is renamed, the N1B matrix must bind to the current
approved replacement before implementation begins.

## Device and substrate contracts bound to N1B

N1B uses the Android 16 Restless R7E internal candidate as the substrate unless a
later approved document explicitly changes the baseline.

```text
N1B_BASELINE=N0B_R7E_ANDROID16_RESTLESS
ANDROID_RELEASE=16
ANDROID_VERSION_TAG=bp4a
BUILD_ID=BP4A.251205.006
PRIMARY_INTERNAL_CANDIDATE=N0B_ANDROID16_R7E
ANDROID17_BASELINE_PIVOT=NO
PUBLIC_RELEASE=NO
```

The following R7E deviations remain part of the N1B evidence envelope:

```text
GOODIX_PATCH_SKIPPED=YES
PLATFORM_TESTING_GATE=Android.bp_placeholder_from_R7D
TREBLEAPP_DEXPREOPT_DISABLED=YES
```

## Must-not-regress source authority

N1B must not infer implementation permission from design-only PRs. Every design
contract whose PR body says `BUILD_CODE_CHANGED=NO`, `DEVICE_CODE_CHANGED=NO` or
`FLASH_ENABLEMENT=NO` remains non-implementation evidence until the matching
implementation PR/build gate lands in `aimindseye/sableos`.

## Traceability matrix

| Source | Requirement class | N1B handling |
| --- | --- | --- |
| `platform_sable` Setup Wizard / First Boot | First-run system UX | Include or explicitly block N1B |
| `platform_sable` Critical Text Entry | Launch blocker | Include as hard gate |
| `platform_sable` Lockscreen / Secure Entry | Security/text-entry UX | Include/gate before image |
| `platform_sable` Quick Settings / Notification Shade | SystemUI/theme/Hub handoff | Include/gate before image |
| `platform_sable` Sable Start | Keyboard-first HOME | Include |
| `platform_sable` All Apps | App privacy and actions | Include |
| `platform_sable` Sable Command | Local command/search | Include/gate |
| `platform_sable` Sable Hub | Communications and attention | Include |
| `platform_sable` Phone / Contacts / Messages | Core phone UX | Include or explicit bounded defers |
| `platform_sable` Browser / WebView | Browser identity and text input | Include label and prompt gates |
| `platform_sable` Mail / Calendar | Productivity UX | Include app composition/gate |
| `platform_sable` Media / Gallery | Media UX | Include or explicit bounded defers |
| `platform_sable` Camera | Camera2-first system-image app | Include or explicit bounded defer |
| `device_sable_titan2` R7E pass seal | Substrate identity | Include evidence binding |
| `device_sable_titan2` Developer tools | Policy only | Do not bundle by default |
| `unihertz-titan2` bring-up contract | Restore/AVB/super/userdata | Gate before device action |
| `aimindseye/sableos` open issues | Implementation blockers | Include matrix and PR sequence |

## Acceptance

```text
N1B_PLATFORM_SABLE_TRACEABILITY=PASS
PLATFORM_SABLE_DOCS_BOUND=YES
DEVICE_TITAN2_GATES_BOUND=YES
UNIHERTZ_TITAN2_RESEARCH_BOUND=YES
AIMINDSEYE_OPEN_ISSUES_BOUND=YES
ANDROID16_R7E_SUBSTRATE_BOUND=YES
ANDROID17_BASELINE_PIVOT=NO
PUBLIC_RELEASE=NO
FLASH_AUTHORIZED=NO
```
