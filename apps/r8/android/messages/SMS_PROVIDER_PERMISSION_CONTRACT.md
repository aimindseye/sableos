# Sable Messages — Android 16 SMS provider authority

## Decision (2026-10-20)

- **READ_SMS:** Declared in the current Sable Messages AndroidManifest.xml. Its real Android grant is not proven merely by the manifest or a dialog. Android 16 marks READ_SMS `dangerous` and `hardRestricted`; the selected installation path, applicable role, or installer restriction allowlisting **and** the effective per-user runtime permission must be qualified. The app's `LiveSmsProvider` fails closed when access is unavailable. The post-provision Sable Setup status now reads the package's effective READ_SMS grant without changing it.
- **WRITE_SMS:** **Do not declare or try to grant** `android.permission.WRITE_SMS`. On Android 16 the framework preserves it solely as a compatibility declaration with `android:permissionFlags="removed"`. It is not an effective user-grantable write permission. Android's Telephony provider grants actual write ownership through the user-selected **default SMS handler**. See official AOSP Android 16 `frameworks/base/core/res/AndroidManifest.xml` and Android Developers `android.provider.Telephony` reference.
- **Current send/write model:** Sable Messages is a **read-only** SMS provider observer. Outgoing drafts go to the user's installed SMS application through `Intent.ACTION_SENDTO` with `smsto:` and `sms_body`. Only the owner can send/store/update/deliver. Sable never inserts, updates, deletes, or marks SMS provider rows read. Opening an SMS composer does not prove delivery; the draft stays in Sable until the user edits it.
- **Alternative owner model, NOT implemented:** A full user-selectable default-SMS app requires RoleManager/default-app eligibility, actual handling of SMS_DELIVER and MMS WAP_PUSH, inbound persistence, send/receive semantics, support for `smsto:` targets and `RESPOND_VIA_MESSAGE`, device/MMS parity, dual-SIM handling, and tests. A manifest `WRITE_SMS` request is not a substitute. Choosing this route would supersede the existing C3B provider-owned integration decision and requires explicit engineering approval.
- **Privacy:** The screen uses `FLAG_SECURE`, a locked-user gate, and blanks content on pause; this is app-screen enforcement only, not privileged App Lock, private profile/lockscreen, or SystemUI notification policy. The Android SDK/ROM must separately qualify it.
- **Historical pin:** `docs/C3B_MESSAGES_CANONICAL_BINDING.env` and `build/titan2/qualify-c3b-product-source.sh` qualify an older **fixture-only/no-SMS-permission** commit and are not evidence that the new candidate passed its source admission. Reconcile the new production pin/IR-012 while preserving historical evidence. Do not weaken its checks silently.

## Acceptance still pending

1. Exact selected Track B system image source/manifest installed `org.sableos.messages`, unique package identity, grants and relevant installer/role restriction allowlists (the app may intentionally remain denied).
2. Actual `READ_SMS` grant and ContentResolver query on device, locked/unlocked/profile transitions, keyguard screenshot/recents privacy, user-permission revocation and errors.
3. Real Android16 Gradle `compileDebugKotlin`, `testDebugUnitTest`, detekt/ktlint/lint; these source changes were not built into the system image.
4. No new custom IMS, SMS transport, WRITE_SMS, system SMS role takeover or flash authorization from this source change.

Sources: https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-qpr2-release/core/res/AndroidManifest.xml and https://developer.android.com/reference/android/provider/Telephony
