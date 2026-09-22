# R9 Platform Surface Classification

Status: **WS6 source classification / physical confirmation required**

This document classifies visible Android 17 / GrapheneOS-derived surfaces for
SableOS R9. The goal is product-shell coherence without renaming internal
security implementation, package namespaces, provider authorities, APIs, URLs
or service ownership when those identifiers remain technically GrapheneOS or
Android.

Classification values:

- `SABLE_OWNED` — SableOS owns the user-facing product surface and copy.
- `SABLE_PRESENTED_ANDROID` — Android/GrapheneOS implementation remains
  authoritative, but it is reached through Sable presentation and must follow
  Sable system appearance where upstream DayNight support permits it.
- `INTENTIONALLY_UPSTREAM` — the surface or identifier remains upstream
  because replacing or cosmetically renaming it would be misleading, unsafe,
  or outside the bounded R9 presentation scope.

## Surface matrix

| Surface | Classification | R9 ownership rule |
| --- | --- | --- |
| HOME / Start | SABLE_OWNED | Sable Start owns Start, All Apps, Search, Peek and Appearance navigation. Native Launcher3 workspace/app drawer must not escape. |
| Recents / Overview | SABLE_PRESENTED_ANDROID | Quickstep retains task/gesture implementation. It may become visible only for Recents/Overview, not as an alternate launcher. |
| Sable first-party apps | SABLE_OWNED | Sable labels/icons/theme contract; one system appearance authority. |
| Settings home header | SABLE_OWNED | SableOS presentation with real Android Settings fragments underneath. |
| Settings Appearance | SABLE_OWNED | Backed by `content://org.sableos.appearance/appearance`; Settings owns persistence and boot restoration. |
| Settings Applications | SABLE_OWNED | App name plus effective sensitive-permission summary; package details remain in deeper evidence surfaces. |
| Settings App Security & Privacy | SABLE_OWNED | Read-only evidence assembled from Android PackageManager/AppOps/local APK metadata. |
| About SableOS | SABLE_OWNED | Sable title/presentation, real device/build properties. |
| SetupWizard welcome/finish | SABLE_OWNED | SableOS name/icon/presentation. Backup compatibility copy must not falsely claim GrapheneOS-only ownership. |
| Quick Settings / notification shade | SABLE_PRESENTED_ANDROID | SystemUI behavior, ranking, tile state and privacy semantics remain Android/GrapheneOS; appearance follows Sable system mode/accent. |
| Lockscreen / keyguard | SABLE_PRESENTED_ANDROID | Upstream authentication, falsing, emergency and security logic retained; bounded presentation may be Sable. |
| Phone / Contacts | SABLE_PRESENTED_ANDROID | Upstream telephony/contact behavior retained; bounded presentation and system night mode. |
| Files / DocumentsUI | SABLE_PRESENTED_ANDROID | Upstream document/provider behavior retained; bounded presentation and system night mode. |
| Clock | SABLE_PRESENTED_ANDROID | Upstream alarm/timer behavior retained; bounded presentation and system night mode. |
| Photos / Gallery | SABLE_PRESENTED_ANDROID | Upstream media behavior retained; bounded presentation and system night mode. |
| Vanadium | SABLE_PRESENTED_ANDROID | Vanadium identity is retained. SableOS does not rename it to Chrome or to a fake Sable browser. |
| Camera | INTENTIONALLY_UPSTREAM | Security-sensitive/preprocessed upstream pipeline remains intact; no binary patching for cosmetic parity. |
| PermissionController | INTENTIONALLY_UPSTREAM | Android permission semantics and security wording remain authoritative; generic Android wording is acceptable. |
| Package installer / package verifier flows | INTENTIONALLY_UPSTREAM | Installation/security semantics remain upstream. No cosmetic rewrite that could misrepresent enforcement. |
| Chooser / Sharesheet | INTENTIONALLY_UPSTREAM | Platform behavior and accessibility semantics retained. |
| Accounts / credential provider flows | INTENTIONALLY_UPSTREAM | Provider identity and security semantics remain truthful to the implementation. |
| Accessibility service flows | INTENTIONALLY_UPSTREAM | Android accessibility semantics retained. |
| GrapheneOS package names / Java namespaces / service names | INTENTIONALLY_UPSTREAM | Internal implementation identity; never globally search/replace. |
| GrapheneOS URLs or provider/service ownership that remain technically GrapheneOS | INTENTIONALLY_UPSTREAM | Keep truthful attribution where it describes the actual upstream service or implementation. |

## Branding rules

R9 does **not** perform a repository-wide replacement of the word
`GrapheneOS`. That would corrupt truthful upstream implementation identity.

The following user-facing Sable-owned surfaces must not present GrapheneOS as
the product name:

- SetupWizard welcome/finish;
- Settings Sable header;
- About SableOS;
- Sable-owned launcher surfaces;
- Sable first-party application labels/copy;
- Sable-owned appearance controls.

The branding applicator is deliberately bounded. Its source preconditions may
contain old GrapheneOS strings because those are exact replacement anchors;
that is not runtime branding leakage.

Generic Android wording such as `Android System`, permission names, platform
component names or compatibility/security descriptions is not automatically a
failure. A failure is an unintended alternate **product identity** in a surface
classified `SABLE_OWNED`.

## Physical WS6 audit

Source classification is necessary but not sufficient. On the final Panther
candidate, capture at minimum:

1. SetupWizard first/finish surfaces when naturally reachable;
2. Settings home;
3. Appearance;
4. Applications;
5. per-app Security & Privacy;
6. About SableOS;
7. notification shade / Quick Settings;
8. lockscreen;
9. Phone, Contacts, Files, Clock, Photos/Gallery, Vanadium;
10. any unexpected GrapheneOS-branded surface encountered during normal
    daily-driver traversal.

Required final marker:

```text
R9_SABLE_USER_VISIBLE_BRANDING_AUDIT=PASS
```

An internal package/service identifier is not by itself a branding failure.
Unexpected GrapheneOS **product-shell copy** in a `SABLE_OWNED` surface is.

## WS6 exit

Source-side closure requires:

```text
R9_PLATFORM_SURFACE_CLASSIFICATION=PASS
R9_SABLE_OWNED_BRANDING_CONTRACT=PASS
R9_INTENTIONAL_UPSTREAM_BOUNDARY=PASS
R9_WS6_SOURCE_AUDIT=PASS
```

Physical closure remains deferred to the fresh Panther candidate.
