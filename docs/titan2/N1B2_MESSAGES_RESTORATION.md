# N1B2 Messages module restoration

Status: **restored Gradle APK module / not product-selected / not image-selected**

This restores `:messages` as a standalone Gradle APK module under the common
Sable app tree. It does not add Android product selection, image membership, role
ownership, default SMS ownership, flash enablement, or runtime device evidence.

## Source references

This restoration is bound to the already-merged app restoration reference
contract:

```text
docs/titan2/N1B2_APP_RESTORATION_REFERENCE.tsv
```

The Messages row requires:

```text
RESTORE_FROM_HUB_MESSAGES_REFERENCE
```

The concrete implementation references are:

```text
apps/r8/android/hub
platform_sable/docs/SABLE_APP_REUSE_AND_INTEGRATION_PLAN.md
platform_sable/docs/design/MESSAGES_CONVERSATION_UX.md
platform_sable/docs/design/MESSAGES_CONVERSATION_VISUAL_CONFIRMATION.md
platform_sable/docs/design/artifacts/sable-messages-conversation-titan2.svg
platform_sable/docs/design/artifacts/sable-hub-titan2.svg
```

## Scope

```text
MESSAGES_GRADLE_MODULE=YES
MESSAGES_DEBUG_APK=YES
MESSAGES_PRODUCT_SELECTION=NO
MESSAGES_IMAGE_MEMBERSHIP=NO
MESSAGES_DEFAULT_SMS_ROLE=NO
CUSTOM_SMS_STACK=NO
CUSTOM_RCS_STACK=NO
CUSTOM_MMS_STACK=NO
PROVIDER_OWNERSHIP_RETAINED=YES
PROVIDER_SAFE_HANDOFF=YES
```

The restored APK is intentionally a provider-safe handoff surface. It uses Android
provider handoff through `Intent.ACTION_SENDTO` with `smsto:`. It does not request
`READ_SMS`, `SEND_SMS`, or `RECEIVE_SMS` in this PR.

## Visual and UX alignment

The first restored UI intentionally mirrors the source-controlled Titan2 Messages
and Hub artifacts within the limits of a normal Android APK module:

```text
TITAN2_VISUAL_TARGET=YES
SQUARE_DISPLAY_PLUS_PHYSICAL_KEYBOARD_REFERENCE=YES
HUB_MESSAGES_REFERENCE=YES
LATEST_ANCHORED_CONVERSATION=YES
LATEST_MESSAGE_ALWAYS_VISIBLE=YES
COMPOSER_VISIBLE_WITH_LATEST=YES
ONSCREEN_KEYBOARD_FALLBACK=YES
HISTORY_ACCESS_EXPLICIT=YES
RETURN_TO_LATEST_INDICATOR=YES
CONVERSATION_LIST_LATEST_FIRST=YES
LOCKED_MODE_REDACTION=YES
PRIVATE_MODE_REDACTION=YES
SOURCE_RESTRICTED_MODE=YES
PROVIDER_OWNERSHIP_RETAINED=YES
CUSTOM_SMS_STACK=NO
UNSUPPORTED_PROVIDER_ACTIONS=NO
```

The UI includes these visible contract elements:

- latest-anchored conversation panel;
- newest message marked `Latest msg` and kept with the composer;
- composer with physical-keyboard-primary copy;
- onscreen keyboard fallback copy;
- explicit `New message — Enter to latest` history indicator;
- latest-first Hub-style conversation list;
- locked/private redaction panel with message body hidden;
- provider-safe `smsto:` handoff.

This is still a buildable module restoration step, not a full SMS provider
replacement and not product/image selection.

## Gate

Validation gate:

```text
build/gates/n1b2-messages-module-contract.sh
```

Inventory-only mode:

```text
bash build/gates/n1b2-messages-module-contract.sh
```

Build mode:

```text
PLATFORM_SABLE_ROOT=/srv/data/sable-build/platform_sable \
  bash build/gates/n1b2-messages-module-contract.sh --build YES
```

Expected build marker:

```text
N1B2_MESSAGES_MODULE_BUILD=PASS
```

## Safety posture

This PR does not authorize Android image builds, Soong builds, device contact,
adb, fastboot, flashing, factory reset, public release, or production signing.
