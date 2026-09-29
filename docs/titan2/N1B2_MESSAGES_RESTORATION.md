# N1B2 Messages module restoration

Status: **restored Gradle APK module / not product-selected / not image-selected**

This restores `:messages` as a standalone Gradle APK module under the common Sable app tree. It does not add Android product selection, image membership, role ownership, default SMS ownership, flash enablement, or runtime device evidence.

## Source references

This restoration is bound to the already-merged app restoration reference contract:

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

The restored APK is intentionally a provider-safe handoff surface. It uses Android provider handoff through `Intent.ACTION_SENDTO` with `smsto:`. It does not request `READ_SMS`, `SEND_SMS`, or `RECEIVE_SMS` in this PR.

## UX and keyboard coverage

The restored module implements the platform_sable Messages / Conversation UX that can be implemented before provider ownership:

```text
LATEST_ANCHORED_CONVERSATION=YES
LATEST_MESSAGE_ALWAYS_VISIBLE=YES
COMPOSER_VISIBLE_WITH_LATEST=YES
HISTORY_ACCESS_EXPLICIT=YES
SEARCH_IN_CONVERSATION=YES
JUMP_TO_DATE=YES
JUMP_TO_UNREAD=YES
JUMP_TO_ATTACHMENT=YES
PAGE_UP_HISTORY=OPTIONAL
PAGE_DOWN_TOWARD_LATEST=OPTIONAL
LATEST_KEY=REQUIRED
CUSTOM_SMS_STACK=NO
PROVIDER_OWNERSHIP_RETAINED=YES
```

Keyboard operations implemented in the restored activity:

```text
/                 Search in conversation
Ctrl+L or End      Return to latest
PageUp             Older discrete history slice
PageDown           Newer history slice / latest direction
N                  Next unread/new item
D                  Jump to date slice
A                  Jump to attachment slice
Back/Esc           Leave history/search and return to latest
Enter              Return to latest from history/search, or provider-safe handoff from latest
Shift+Enter        Reserved for newline text entry
```

History is modeled as discrete slices, not a precision touchpad scroll dependency. Every history/search view keeps visible focus and exposes `New message — Enter to latest` or an equivalent direct return-to-latest affordance.

## Visual confirmation coverage

The restored module follows the Titan2 visual confirmation artifacts by exposing:

```text
TITAN2_HARDWARE_TEMPLATE=PASS
SQUARE_DISPLAY_PLUS_PHYSICAL_KEYBOARD=PASS
LATEST_MESSAGE_ALWAYS_VISIBLE=PASS
ONSCREEN_KEYBOARD_FALLBACK=PASS
HISTORY_MODE_SHOWS_NEW_MESSAGE_INDICATOR=PASS
CONVERSATION_LIST_LATEST_FIRST=PASS
LOCKED_MODE_REDACTION=PASS
PRIVATE_MODE_REDACTION=PASS
MESSAGE_ACTIONS_KEYBOARD_ACCESSIBLE=PASS
UNSUPPORTED_PROVIDER_ACTIONS=NO
```

This is a buildable module restoration step, not a full SMS provider replacement.

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

This PR does not authorize Android image builds, Soong builds, device contact, adb, fastboot, flashing, factory reset, public release, or production signing.
