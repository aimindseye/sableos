# Panther D4-R0 — read-only package, branding and functional baseline audit

Date: 2026-09-07

Status: **NEXT / AUTHORIZATION REQUIRED FOR DEVICE CONTACT**

D4-R0 is intentionally non-mutating. It must not modify Android source, build output, device partitions, slot state, userdata or metadata. Its purpose is to establish the exact D3 baseline that D4 will change against.

## Authorization model

The executor should use an explicit authorization banner. Default policy:

```text
SOURCE_MUTATION_AUTHORIZED=NO
WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
CLEAN_OR_CLOBBER_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=<explicit>
DEVICE_REBOOT_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
PURPOSE=D4_R0_READ_ONLY_PACKAGE_BRANDING_AND_FUNCTIONAL_BASELINE_AUDIT
```

D4-R0 should be split into a host/source audit and a live-device audit. The host portion can run without device contact; the live portion requires explicit device-contact authorization.

## Host/source audit

Workspace:

```text
/srv/data/sableos_panther_graphene_2026081300_workspace
```

The audit should bind the canonical source/target-files state already recorded by D3 and then collect bounded evidence for:

- all `PRODUCT_PACKAGES` and inheritance lines relevant to user-facing apps, Graphene Apps/app-store, updater and browser/WebView components;
- Graphene-branded package projects and package names;
- package install partition (`system`, `product`, `system_ext`, vendor where relevant);
- app/priv-app image contents from target-files;
- privapp permissions;
- overlays and overlay targets;
- SELinux type/domain/file-context references for candidate removals;
- SetupWizard/Settings references;
- updater/update URL/server metadata;
- Graphene Apps/app-store provenance;
- remaining user-visible `GrapheneOS` strings in bounded app/framework sources.

The search must distinguish user-visible strings from:

- package names/namespaces;
- source project paths;
- API identifiers;
- SELinux identifiers;
- service ownership wording;
- functional URLs;
- comments/test data.

Output candidate classifications:

```text
REBRAND_TO_SABLE
KEEP_TRUTHFUL_GRAPHENE_SERVICE_OWNERSHIP
KEEP_INTERNAL_IDENTIFIER
KEEP_FUNCTIONAL_URL
DEPRECATED_OR_DROP
REQUIRES_SABLE_SERVICE_BEFORE_REBRAND
```

Candidate app/component classifications:

```text
KEEP_REQUIRED_PLATFORM_COMPONENT
KEEP_TEMPORARILY
REMOVE_FROM_SABLE_DEFAULT
REPLACE_WITH_SABLE_COMPONENT
REQUIRES_DEPENDENCY_FORENSICS
```

## Live D3 package/role baseline

With device contact explicitly authorized, require the known D3 runtime identity before collecting evidence:

```text
product=panther
sys.boot_completed=1
ro.boot.slot_suffix=_b
ro.build.id=CP2A.260705.006
ro.build.version.incremental=2026090500
ro.crypto.state=encrypted
```

Collect read-only package state including:

- `pm list packages -f`;
- system packages and third-party packages separated where useful;
- package install paths;
- current HOME/launcher role or resolved home activity;
- browser/default browser role;
- dialer role;
- SMS role;
- other role holders relevant to default applications;
- WebView provider;
- Settings/SetupWizard package identity;
- Graphene Apps/app-store package presence;
- updater package/service presence;
- disabled/enabled package state for candidate defaults.

## Live D3 connectivity/phone baseline

Collect read-only diagnostics, with sensitive identifiers redacted from public artifacts:

```text
getprop
dumpsys telephony.registry
dumpsys telecom
dumpsys wifi
dumpsys connectivity
dumpsys role
dumpsys package
```

Bounded summaries should capture where available:

```text
SIM_PRESENT
VOICE_REGISTRATION
DATA_REGISTRATION
NETWORK_TYPE
IMS_REGISTRATION
DEFAULT_DATA_SUBSCRIPTION_PRESENT
DEFAULT_SMS_SUBSCRIPTION_PRESENT
APN_STATE_PRESENT
WIFI_ENABLED
WIFI_CONNECTED
DEFAULT_NETWORK_PRESENT
```

Do not publish IMSI, ICCID, phone number, subscriber ID, Wi-Fi MAC, precise location, account identifiers or other unnecessary personal data.

## Human D3 functional baseline

The executor can collect machine-readable state, but several D4 acceptance tests require human/device interaction. D4-R0 should emit a checklist/evidence file for manual PASS/FAIL/NOT_TESTED recording.

Mandatory baseline tests:

```text
VOICE_OUT
VOICE_IN
SMS_OUT
SMS_IN
CELLULAR_DATA
WIFI
```

Additional target tests:

```text
MMS
IMS_VOLTE
HOTSPOT
BLUETOOTH_PAIR_RECONNECT
BLUETOOTH_AUDIO
AUDIO_SPEAKER
AUDIO_MIC
CAMERA_REAR_PHOTO
CAMERA_FRONT_PHOTO
CAMERA_VIDEO
LOCATION_FIX
NFC_BASIC
USB_ADB
USB_CHARGING
ROTATION_SENSOR
PROXIMITY_SENSOR
FINGERPRINT
APK_INSTALL_LAUNCH
RUNTIME_PERMISSION_GRANT_REVOKE
BROWSER_HTTPS
WEBVIEW_SANITY
NOTIFICATION_DELIVERY
CHARGING_STATE
PERSISTENCE_AFTER_REBOOT
```

No live emergency-services call is part of normal D4-R0 acceptance.

## Required deliverables

D4-R0 should produce, under a timestamped `/tmp` evidence directory:

```text
host/source provenance report
remaining branding hits + classifications
candidate app inventory + dependency classifications
installed package inventory
role/default-app inventory
connectivity/telephony redacted summary
raw local-only diagnostic captures where safe
manual functional baseline checklist
proposed D4-R1 mutation set
unresolved dependency list
final summary
post-finalization SHA-256 evidence seal
```

The host/source report should be suitable for committing to GitHub after sensitive paths/identifiers are reviewed. Raw device diagnostics should remain local unless explicitly sanitized.

## D4-R0 completion gate

D4-R0 is complete only when it can answer:

```text
WHAT_GRAPHENE_USER_FACING_APPS_ARE_PRESENT
WHICH_ARE_SAFE_REMOVAL_CANDIDATES
WHAT_DEPENDENCIES_BLOCK_REMOVAL
WHAT_DEFAULT_APPS_SABLE_CURRENTLY_SHIPS
WHAT_REMAINING_GRAPHENE_BRANDING_IS_USER_VISIBLE
WHAT_BRANDING_MUST_REMAIN_TRUTHFUL
WHETHER_D3_CORE_PHONE_FUNCTIONS_PASS_BEFORE_D4
WHAT_EXACT_COMBINED_D4_R1_SOURCE_MUTATION_IS_PROPOSED
```

Target result markers:

```text
D4_R0_HOST_PROVENANCE=PASS
D4_R0_LIVE_PACKAGE_BASELINE=PASS
D4_R0_CONNECTIVITY_BASELINE=PASS
D4_R0_FUNCTIONAL_BASELINE=PASS_OR_EXPLICIT_PARTIAL
D4_R0_D4_R1_PLAN=READY_OR_BLOCKED_WITH_REASONS
SOURCE_MUTATION=NONE
BUILD=NONE
FLASH=NONE
SLOT_CHANGE=NONE
```
