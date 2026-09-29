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

## UX constraints

The first restored UI follows the platform_sable Messages / Conversation UX constraints that can be implemented without provider ownership:

```text
LATEST_ANCHORED_CONVERSATION=YES
LATEST_MESSAGE_ALWAYS_VISIBLE=YES
COMPOSER_VISIBLE_WITH_LATEST=YES
HISTORY_ACCESS_EXPLICIT=YES
CUSTOM_SMS_STACK=NO
PROVIDER_OWNERSHIP_RETAINED=YES
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
