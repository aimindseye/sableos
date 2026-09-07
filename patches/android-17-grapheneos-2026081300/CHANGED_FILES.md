# D2+D3 changed-file ledger

Canonical base: GrapheneOS `2026081300`

## SetupWizard2

Base HEAD:

```text
3982cfc3536620c17b2ec5c3494af0fb2a58a633
```

Changed:

```text
res/values/strings.xml
res/layout/activity_welcome.xml
res/layout/activity_finish.xml
res/drawable-nodpi/sableos_icon.png (new)
```

Exact visible mutations:

```text
Welcome to GrapheneOS -> Welcome to SableOS
GrapheneOS icon -> SableOS icon
@drawable/grapheneos_icon -> @drawable/sableos_icon (welcome + finish)
If you have a backup from your previous GrapheneOS device, you can restore it here.
  -> If you have a compatible backup from a previous device, you can restore it here.
```

## Settings

Base HEAD:

```text
71bd21cda07f4dfdcec2aabb16bc570be5bd8d35
```

Changed:

```text
res/values/strings_app_exploit_protection.xml
res/values/strings_ext.xml
```

Exact visible mutations:

```text
GrapheneOS exploit protections -> SableOS exploit protections
GrapheneOS will remain installed. -> SableOS will remain installed.
```

## frameworks/base

Base HEAD:

```text
aab06a8bd44c4c2b58eeec780fde83baa9d43a40
```

Changed:

```text
core/res/assets/images/android-logo-mask.png
```

Exact asset transition:

```text
old Graphene mask SHA-256
75efac98abbc429c9aaa4c1aea918014aaead364b802ecec493c70c2d000df41

new Sable mask SHA-256
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e
```

Unchanged shine asset:

```text
73c2cb640b053c29ec8be308892759a33cd6ed5aa85283cca2a456d208ccd4fb
```

## Binary assets stored in this repository

```text
assets/sableos_setupwizard_icon.png
eed1b1277a77fa1f94b514585622c403c85c95191cfa3ba90edf526d02e5aea7

assets/sableos_boot_fallback_mask_448x605.png
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e
```

Use `apply_sable_branding.py`, rather than broad search-and-replace, to reconstruct the exact changed source scope from the pinned base.
