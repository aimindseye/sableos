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

The restored module now treats `MESSAGES_CONVERSATION_UX.md` and `MESSAGES_CONVERSATION_VISUAL_CONFIRMATION.md` as the acceptance contract, not as copy-only guidance.

Coverage is split across:

```text
apps/r8/android/messages/src/main/java/org/sableos/messages/MessagesInteractionModel.kt
apps/r8/android/messages/src/main/java/org/sableos/messages/MainActivity.kt
apps/r8/android/messages/src/test/java/org/sableos/messages/MessagesInteractionModelTest.kt
build/gates/n1b2-messages-module-contract.sh
```

The interaction model covers:

```text
OPEN_THREAD_AT_LATEST=PASS
RESTORE_THREAD_AT_LATEST=PASS
AUTO_ADVANCE_TO_LATEST_ON_INCOMING=PASS
AUTO_ADVANCE_TO_LATEST_ON_SEND=PASS
LATEST_MESSAGE_ALWAYS_VISIBLE=PASS
COMPOSER_VISIBLE_WITH_LATEST=PASS
SEARCH_IN_CONVERSATION=PASS
JUMP_TO_DATE=PASS
JUMP_TO_UNREAD=PASS
JUMP_TO_ATTACHMENT=PASS
PAGE_UP_HISTORY=OPTIONAL
PAGE_DOWN_TOWARD_LATEST=OPTIONAL
LATEST_KEY=REQUIRED
CONVERSATION_LIST_LATEST_FIRST=PASS
OPEN_SELECTED_THREAD_AT_LATEST=PASS
TYPE_TO_FILTER_OR_SEARCH=PASS
PHYSICAL_KEYBOARD_COMPOSITION=PASS
ALT_SYM_FN_TEXT_ENTRY=PASS
ONSCREEN_KEYBOARD_FALLBACK=PASS
PHYSICAL_AND_ONSCREEN_DRAFT_SHARE_STATE=PASS
DRAFT_PERSISTENCE=PASS
ATTACHMENT_ACTIONS_PROVIDER_SAFE=PASS
CAMERA_HANDOFF_PROVIDER_SAFE=PASS
MEDIA_PICKER_PERMISSION_AWARE=PASS
MESSAGE_ACTIONS_KEYBOARD_ACCESSIBLE=PASS
COPY_TEXT=PASS
REPLY_IF_PROVIDER_SAFE=PASS
FORWARD_IF_PROVIDER_SAFE=PASS
DELETE_IF_PROVIDER_SAFE=PASS
DETAILS_IF_PROVIDER_SAFE=PASS
CONTACTS_HANDOFF=PASS
PHONE_HANDOFF=PASS
HUB_HANDOFF=PASS
COMMAND_SEARCH_HANDOFF=PASS
NOTIFICATION_SHADE_HANDOFF=PASS
LOCKSCREEN_HANDOFF=PASS
LOCKED_MODE_REDACTION=PASS
PRIVATE_MODE_REDACTION=PASS
SOURCE_RESTRICTED_MODE=PASS
MESSAGE_BODY_HIDDEN_WHEN_LOCKED=PASS
CONTACT_NAME_POLICY_AWARE=PASS
HUB_PRIVACY_COMPATIBLE=PASS
NOTIFICATION_SHADE_PRIVACY_COMPATIBLE=PASS
RETURN_FROM_ACTIONS_TO_COMPOSER=PASS
RETURN_FROM_HISTORY_TO_LATEST=PASS
RETURN_FROM_CONTACT_TO_THREAD_LATEST=PASS
RETURN_FROM_ATTACHMENT_TO_COMPOSER=PASS
NO_FOCUS_TRAPS=PASS
NO_MESSAGE_DEAD_ENDS=PASS
CUSTOM_SMS_STACK=NO
CUSTOM_RCS_STACK=NO
CUSTOM_MMS_STACK=NO
CUSTOM_CARRIER_STACK=NO
UNSUPPORTED_PROVIDER_ACTIONS=NO
SILENT_MESSAGE_IMPORT=NO
```

Keyboard operations implemented in the restored activity:

```text
/                  Search in conversation
Ctrl+L or End      Return to latest
PageUp             Older discrete history slice
PageDown           Newer history slice / latest direction
N                  Next unread/new item
D                  Jump to date slice
A                  Jump to attachment slice
Up/Down            Conversation rows or visible message focus
Home               First conversation row
Enter              Send/open/details/return-to-latest by mode
Shift+Enter        Insert newline
Alt+Enter          Provider-safe secondary send
Space              Provider-safe preview/select
Menu/Fn+Enter      Message/composer action sheet
Back/Esc           Leave history/search/actions and return to latest
Backspace/Delete   Edit draft text
Letters            Type/filter depending focus mode
```

History is modeled as discrete slices, not a precision touchpad scroll dependency. Every history/search/action view keeps visible focus and exposes a direct return-to-latest path such as `New message — Enter to latest`.

## Visual confirmation coverage

The restored module follows the Titan2 visual confirmation artifacts by exposing:

```text
TITAN2_HARDWARE_TEMPLATE=PASS
SQUARE_DISPLAY_PLUS_PHYSICAL_KEYBOARD=PASS
NO_SLAB_PHONE_VISUAL_TARGET=PASS
NO_STRETCHED_SCREEN_TARGET=PASS
LATEST_MESSAGE_ALWAYS_VISIBLE=PASS
ONSCREEN_KEYBOARD_FALLBACK=PASS
HISTORY_MODE_SHOWS_NEW_MESSAGE_INDICATOR=PASS
CONVERSATION_LIST_LATEST_FIRST=PASS
LOCKED_MODE_REDACTION=PASS
PRIVATE_MODE_REDACTION=PASS
SOURCE_RESTRICTED_MODE=PASS
MESSAGE_ACTIONS_KEYBOARD_ACCESSIBLE=PASS
UNSUPPORTED_PROVIDER_ACTIONS=NO
```

This is a buildable module restoration step, not a full SMS provider replacement.

## Release validation block

The code and tests now carry the release validation block from the platform_sable documents:

```text
MESSAGES_CONVERSATION_UX=PASS
MESSAGES_CONVERSATION_VISUAL_ARTIFACT_SOURCE_CONTROLLED=PASS
TITAN2_MESSAGES_VISUAL_TARGET=PASS
ANDROID_MESSAGES_MENTAL_MODEL=PASS
KEYBOARD_FIRST_COMPOSITION=PASS
PHYSICAL_KEYBOARD_COMPOSITION=PASS
ONSCREEN_KEYBOARD_FALLBACK=PASS
ALT_SYM_FN_TEXT_ENTRY=PASS
LATEST_ANCHORED_CONVERSATION=PASS
LATEST_MESSAGE_ALWAYS_VISIBLE=PASS
OPEN_THREAD_AT_LATEST=PASS
RESTORE_THREAD_AT_LATEST=PASS
AUTO_ADVANCE_TO_LATEST_ON_INCOMING=PASS
AUTO_ADVANCE_TO_LATEST_ON_SEND=PASS
SCROLLING_REQUIRED_TO_SEE_LATEST_MESSAGE=NO
CONTINUOUS_TOUCHPAD_SCROLLING_REQUIRED=NO
HISTORY_ACCESS_EXPLICIT=PASS
SEARCH_IN_CONVERSATION=PASS
JUMP_TO_UNREAD=PASS
RETURN_TO_LATEST_KEY=PASS
CONVERSATION_LIST_LATEST_FIRST=PASS
MESSAGE_ACTIONS_KEYBOARD_ACCESSIBLE=PASS
CONTACTS_HANDOFF=PASS
PHONE_HANDOFF=PASS
HUB_HANDOFF=PASS
COMMAND_SEARCH_HANDOFF=PASS
NOTIFICATION_SHADE_HANDOFF=PASS
LOCKSCREEN_PRIVACY_COMPATIBLE=PASS
LOCKED_MODE_REDACTION=PASS
PRIVATE_MODE_REDACTION=PASS
SOURCE_RESTRICTED_MODE=PASS
NO_FOCUS_TRAPS=PASS
NO_MESSAGE_DEAD_ENDS=PASS
CUSTOM_SMS_STACK=NO
CUSTOM_RCS_STACK=NO
CUSTOM_MMS_STACK=NO
UNSUPPORTED_PROVIDER_ACTIONS=NO
TITAN2_HARDWARE_TEMPLATE=PASS
SQUARE_DISPLAY_PLUS_PHYSICAL_KEYBOARD=PASS
NO_SLAB_PHONE_VISUAL_TARGET=PASS
NO_STRETCHED_SCREEN_TARGET=PASS
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
FLASH_ENABLEMENT=NO
```

`BUILD_CODE_CHANGED=NO`, `DEVICE_CODE_CHANGED=NO`, and `FLASH_ENABLEMENT=NO` are interpreted here as no Android image/product/device/flash enablement changes. This PR intentionally changes only the common app module and its local Gradle/test surface.

## Gate

Validation gate:

```text
build/gates/n1b2-messages-module-contract.sh
```

Inventory-only mode:

```text
bash build/gates/n1b2-messages-module-contract.sh
```

Build mode runs the interaction tests and APK assembly:

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
