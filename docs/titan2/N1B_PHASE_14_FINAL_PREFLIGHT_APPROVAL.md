# N1B Phase 14: Titan2 Final Preflight Approval Gate

## Purpose

Phase 14 is the final offline preflight gate before any separate manual authorization discussion for Titan2/N1B deployment.

It consumes evidence produced by earlier phases and determines whether the project has enough reviewed, source-bound information to proceed to a future manual authorization checkpoint.

Phase 14 does **not** execute, generate, or authorize flash, resize, erase, reboot, slot, AVB, unlock, or production-signing commands.

## Source review

```text
SOURCE_MAP_REVIEWED=YES
HISTORICAL_CHAT_CONTEXT_REVIEWED=SCOPE_LIMITED_TO_CURRENT_PROJECT_CONTEXT_AND_PASTED_VALIDATION_LOGS
UNIHERTZ_TITAN2_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
DEVICE_SABLE_TITAN2_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
PLATFORM_SABLE_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
TREBLE_RESTLESSOS_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
PLATFORM_MANIFEST_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
BUILD_REPO_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE
CURRENT_SABLEOS_REPO_REVIEWED=YES
CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_10_11_12_13_OUTPUTS
JINN_LINEAGEOS22_ISSUES_REVIEWED=YES_SCOPE_LIMITED
ATLASOS_REVIEWED=YES_SCOPE_LIMITED
```

## jinn_lineageos22 issue review

The `rumplestilzken/jinn_lineageos22` issue tracker was reviewed as an external Titan-family reference. It is useful mainly as a post-change acceptance-risk source, not as an LP/super sizing source.

Findings folded into Phase 14:

```text
JINN_TRACKPAD_POLICY_REVIEWED=YES
JINN_KEYBOARD_IMPLEMENTATION_RISK_REVIEWED=YES
JINN_PACKAGE_BOOTLOOP_AND_CORE_FUNCTION_RISK_REVIEWED=YES
JINN_PHASE14_USAGE=POST_CHANGE_ACCEPTANCE_RISK_SOURCE
```

Implications for SableOS Titan2:

```text
1. Keyboard and trackpad behavior must be explicitly accepted after any image deployment.
2. Hardware keyboard support cannot be assumed from generic Android/GSI behavior.
3. Package/component changes can break Settings, telephony, Wi-Fi, storage, OTA, Safety Center, WebView, Bluetooth, NFC, external storage, SystemUI, and other core surfaces.
4. Phase 14 must not claim user-facing readiness just because LP sizing and flash-plan proposal evidence pass.
5. Post-change acceptance must include keyboard, shortcut/trackpad behavior, Settings, storage, telephony/SIM, Wi-Fi, Bluetooth, NFC, WebView/app launch, update/restore path, and Sable app smoke checks.
```

## AtlasOS / LineageOS reference review

The `Abyss-c0re/atlasos` repository and the linked Titan2 community references were reviewed as external reference material. They are useful as architectural and process evidence, not as a SableOS product path.

Findings folded into Phase 14:

```text
ATLASOS_REVIEWED=YES_SCOPE_LIMITED
ATLASOS_PHASE14_USAGE=REFERENCE_ONLY_NOT_PRODUCT_PATH
ATLASOS_HYBRID_SUPER_APPROACH_REVIEWED=YES
ATLASOS_REGION_MATCHED_STOCK_VENDOR_BOOT_REQUIREMENT_REVIEWED=YES
ATLASOS_PRODUCT_LOCK_GATE_STYLE_REVIEWED=YES
ATLASOS_PUBLISH_HYGIENE_REVIEWED=YES
```

Implications for SableOS Titan2:

```text
1. AtlasOS validates that Titan2 hybrid-super work is possible in the community, but SableOS must not inherit its flash workflow automatically.
2. Region-matched stock vendor/boot inputs remain important evidence before mutation.
3. A product-lock style gate is useful: no invented PASS and no certification from a dirty keep-data flash.
4. Public-source hygiene matters: no stock/vendor images, proprietary blobs, serials, keys, or third-party binaries should be placed in public repos.
5. AtlasOS features such as Debian/OpenWrt LPs, Cube Flasher, HID, and touchpad forks are reference ideas only and are not part of N1B deployment authorization.
```

## Inputs

Phase 14 consumes:

```text
phase10a-adb-readonly-preflight.json
phase10b-fastboot-readonly-preflight.json
phase11-fastbootd-lp-sizing.json
phase12-lp-resize-plan.json
phase13-flash-plan-proposal.json
N1B artifact registry manifest
restore report directory
optional canonical system.img
```

## Required upstream state

```text
PHASE_08_IMAGE_BUILD=PASS
PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED_UNTIL_APPROVED_PLAN
PHASE_10A_ADB_PREFLIGHT=PASS_READ_ONLY
PHASE_10B_FASTBOOTD_PREFLIGHT=PASS_READ_ONLY
PHASE_11_LP_SUPER_SIZING=PASS_PLAN_REQUIRED
PHASE_12_LP_RESIZE_PLAN_DESIGN=PASS_REVIEW_REQUIRED
PHASE_13_FLASH_PLAN_PROPOSAL=PASS_REVIEW_REQUIRED
```

Phase 14 must accept the real emitted schemas:

```text
PHASE_12_RESULT_SOURCE=sizing_decision.plan_record
PHASE_13_RESULT_SOURCE=status
```

## Authorization boundary

```text
DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
REBOOT_COMMANDS_RUN=NO
FLASH_AUTHORIZED=NO
FLASH_COMMANDS_RUN=NO
ERASE_COMMANDS_RUN=NO
UNLOCK_COMMANDS_RUN=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
SLOT_MUTATION_AUTHORIZED=NO
COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Output states

Phase 14 may output only one of these final classifications:

```text
N1B_PHASE_14_FINAL_PREFLIGHT_APPROVAL=APPROVAL_BLOCKED
N1B_PHASE_14_FINAL_PREFLIGHT_APPROVAL=APPROVAL_READY_FOR_MANUAL_AUTHORIZATION
```

`APPROVAL_READY_FOR_MANUAL_AUTHORIZATION` means only:

```text
1. Evidence is internally complete enough for human review.
2. Manual authorization can be discussed next.
3. Flash, resize, erase, reboot, slot mutation, AVB mutation, and unlock remain unauthorized.
4. An executable deployment script still must not be generated.
```

## Non-goals

Phase 14 does not:

```text
CONTACT_DEVICE=NO
RUN_ADB=NO
RUN_FASTBOOT=NO
REBOOT_DEVICE=NO
FLASH_SYSTEM=NO
RESIZE_LOGICAL_PARTITION=NO
ERASE_USERDATA=NO
PATCH_AVB=NO
CHANGE_SLOT=NO
UNLOCK_BOOTLOADER=NO
GENERATE_EXECUTABLE_COMMANDS=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGN=NO
```

## Post-change acceptance areas captured from jinn review

The final approval record must retain these acceptance areas for any later manual authorization discussion:

```text
keyboard_input
trackpad_policy
shortcut_keys
settings_app
storage_and_documentsui
telephony_sim_sms_mms_ims
wifi_bluetooth_nfc
webview_and_app_launch
systemui_navigation
sable_apps_smoke
restore_path
ota_update_surface_not_claimed
```

## Canonical post-merge flow

After this PR is merged, run from merged `main`:

```bash
cd /srv/data/sable-build/sableos/repo

git fetch origin main
git switch main
git merge --ff-only origin/main

bash build/gates/n1b-phase-14-final-preflight-approval-contract.sh

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full
```

Then run Phase 14 offline with the canonical evidence paths:

```bash
bash build/titan2/qualify-n1b-phase-14-final-preflight-approval.sh \
  --phase10a-json /srv/data/sable-build/evidence/titan2/n1b-phase-10-readonly-preflight/20260928_192132/10a-adb/phase10a-adb-readonly-preflight.json \
  --phase10b-json /srv/data/sable-build/evidence/titan2/n1b-phase-10-readonly-preflight/20260928_193733/10b-fastboot/phase10b-fastboot-readonly-preflight.json \
  --phase11-json /srv/data/sable-build/evidence/titan2/n1b-phase-11-lp-super-sizing/20260928_195308/fastbootd-lp-sizing/phase11-fastbootd-lp-sizing.json \
  --phase12-json /srv/data/sable-build/evidence/titan2/n1b-phase-12-lp-resize-plan/20260928_201621/offline-plan/phase12-lp-resize-plan.json \
  --phase13-json /srv/data/sable-build/evidence/titan2/n1b-phase-13-flash-plan-proposal/20260928_202350/offline-proposal/phase13-flash-plan-proposal.json \
  --artifact-manifest /srv/data/sable-build/release-registry/titan2/N1B/462839cfcc362e4f4ed93d8a8dabf059885452b1.json \
  --restore-report /srv/data/sable-build/artifacts/titan2/stock-firmware/unihertz-device-fota-20260922 \
  --system-image /srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi/target/product/tdgsi_arm64_ab/system.img
```
