# R8 SableStart HOME / startup incident — 2026-09-20

## Status

Physical Panther validation exposed two distinct SableStart launcher defects after the
R8 v4-signing/package-scan fix:

1. SableStart was installed and HOME-capable, but preserved user state still resolved
   HOME to `com.android.launcher3/.uioverrides.QuickstepLauncher`.
2. After assigning the HOME role to `org.sableos.start`, SableStart crashed during
   `Activity.onCreate()`.

Both are release-blocking. Package presence alone is not accepted as launcher closure.

## Physical evidence

The corrected R8 image booted slot B with encrypted userdata, all nine Sable packages
registered, and `SableStart.apk.idsig` absent. HOME resolution nevertheless remained:

```text
com.android.launcher3/.uioverrides.QuickstepLauncher
```

Available HOME activities included:

```text
com.android.launcher3/.uioverrides.QuickstepLauncher
org.sableos.start/.SableStartActivity
com.android.settings/.FallbackHome
```

After explicitly assigning SableStart as the HOME role holder, cold launch repeatedly
failed with:

```text
java.lang.NullPointerException:
Attempt to invoke virtual method
'android.view.WindowInsetsController
 com.android.internal.policy.DecorView.getWindowInsetsController()'
on a null object reference

at com.android.internal.policy.PhoneWindow.getInsetsController(...)
at org.sableos.design.SableSystemBarsKt.applySableSystemBars(...)
at org.sableos.start.SableStartActivity.applyCurrentSystemBars(...)
at org.sableos.start.SableStartActivity.onCreate(...)
```

The native SableStart JNI library loaded successfully before the exception. The crash
is therefore in Java/Kotlin window initialization, not JNI loading.

## Root cause

`applySableSystemBars()` accessed `window.insetsController` during
`SableStartActivity.onCreate()`.

On this Android 17 Panther runtime, `PhoneWindow.getInsetsController()` dereferences
the window's `DecorView`. At this early lifecycle point the framework had not yet
installed that DecorView, producing the null dereference.

Separately, SableStart's HOME intent had the same resolver priority as
Launcher3QuickStep. Product composition proved that SableStart was present but did not
prove launcher ownership.

## Source correction

The shared Sable system-bar helper now resolves `window.decorView` explicitly and
uses `decorView.windowInsetsController`. If the view is not attached yet, icon
appearance is deferred with `decorView.post { ... }`.

Direct `window.insetsController` access is forbidden in that helper.

SableStart's HOME intent-filter now has `android:priority="1"`, making it the unique
HOME fallback over the retained priority-0 Quickstep launcher for fresh/no-holder
users. Quickstep remains installed because it also participates in Android overview
and gesture behavior.

Preserved-data validation still requires explicit HOME-role migration/verification;
priority alone must not be treated as migration of an existing holder.

## Permanent gates

R8 source/CI gates now require:

- explicit DecorView-based system-bar access;
- no direct `window.insetsController` use in `SableSystemBars.kt`;
- attached/deferred controller application path;
- SableStart HOME intent priority 1;
- SableStart HOME category;
- product-composition and CI markers for both runtime contracts.

Physical launcher acceptance must separately prove:

```text
HOME resolver = org.sableos.start/.SableStartActivity
HOME role holder = org.sableos.start
cold HOME launch = no org.sableos.start APP CRASH
SableStart visible and interactive after KEYCODE_HOME
```

## Release rule

R8 physical UI qualification is not complete until the corrected source is rebuilt,
deployed, HOME ownership is verified, and SableStart survives a cold HOME launch on
Panther.
