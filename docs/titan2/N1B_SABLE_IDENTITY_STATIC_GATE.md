# N1B Sable identity and app composition static gate

Status: **N1B Phase 03 static gate / no runtime claim**

This gate checks Sable-owned application source and N1B composition metadata before
N1B moves into branding/default-surface integration.

```text
N1B_SABLE_IDENTITY_STATIC_GATE=YES
N1B_PHASE=03
N1B_PHASE_NAME=SABLE_IDENTITY_AND_APP_COMPOSITION_STATIC_GATES
SOURCE_MUTATION_AUTHORIZED=NO for gate execution
BUILD_AUTHORIZED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## Required app composition

The N1B app build root remains:

```text
N1B_STAGE_A_APP_BUILD_ROOT=apps/r8/android
N1B_STAGE_A_MODULE_INVENTORY_SOURCE=apps/r8/android/settings.gradle.kts
```

These modules must remain declared before Phase 04:

```text
MODULE_design=REQUIRED
MODULE_calculator=REQUIRED
MODULE_convert=REQUIRED_UNTIL_REMOVED_BY_DEDICATED_PR
MODULE_games=REQUIRED
MODULE_media=REQUIRED
MODULE_hub=REQUIRED
MODULE_sablestart_presentation_check=REQUIRED
MODULE_sablestart_visual_review=REQUIRED
MODULE_weather=REQUIRED
MODULE_calendar=REQUIRED
```

## Identity rules

Sable-owned app source must not expose stale product identity on user-facing
surfaces.

```text
NO_USER_FACING_GRAPHENEOS_BRANDING_ON_SABLE_SURFACES=YES
NO_USER_FACING_CHROME_LABEL_ON_SABLE_SURFACES=YES
SABLE_APP_IDENTITY_STATIC_SCAN=REQUIRED
```

HTTP protocol compatibility strings are not user-facing labels. OPDS and other
network code may retain browser-shaped User-Agent strings when required for
server compatibility, provided those strings are not exposed as Sable UI labels.

Bundled data assets, dictionaries, fixture corpora, test data, protocol code, and
repository/network implementation code are not Sable browser labels. The Chrome
identity check is scoped to user-facing label surfaces such as manifests,
`res/values`, UI/presentation source, activities, and fragments.

```text
CHROME_HTTP_USER_AGENT_COMPATIBILITY_EXEMPTION=YES
N1B_IDENTITY_CHROME_USER_AGENT_COMPATIBILITY_EXEMPTION=YES
CHROME_STATIC_SCAN_SCOPE=USER_FACING_LABEL_SURFACES_ONLY
N1B_IDENTITY_CHROME_UI_LABEL_SCOPE=YES
```

This is a static source gate. It does not prove runtime labels, launcher icons,
role resolution, browser provider identity, or physical UX.

## Hub composition rules

Hub remains the aggregator for Priority, Messages, Email, and People. Mail remains
owned by Sable Mail / mail app integration, not by the Hub as a protocol engine.

```text
SABLE_HUB_AGGREGATOR_ONLY=YES
SABLE_HUB_MESSAGES_EMAIL_PEOPLE_SURFACE=REQUIRED
SABLE_MAIL_PROTOCOL_OWNER_SEPARATE=YES
```

## Browser label boundary

N1B must not call the browser Chrome on Sable-owned surfaces. The exact runtime
browser provider and package are resolved later by product/role integration.

```text
SABLE_BROWSER_LABEL_POLICY_BOUND=YES
CHROME_LABEL_ON_SABLE_SURFACES=BLOCKED
VANADIUM_OR_BROWSER_LABEL_REVIEW_REQUIRED=YES
```

## Follow-up boundary

Phase 03 is not a substitute for Phase 04/05 runtime work.

```text
PHASE_04_BRANDING_DEFAULT_SURFACE_INTEGRATION_STILL_REQUIRED=YES
PHASE_05_KEYBOARD_FIRST_SETUP_AND_LAUNCHER_BINDING_STILL_REQUIRED=YES
PHYSICAL_UX_ACCEPTANCE_STILL_REQUIRED=YES
```
