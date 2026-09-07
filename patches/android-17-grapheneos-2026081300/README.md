# SableOS Android 17 / GrapheneOS 2026081300 delta

This directory is the canonical, bounded Sable-specific source delta currently validated on Pixel 7 (`panther`). The Android/Pixel substrate is the signed GrapheneOS `2026081300` release tag. Sable does **not** replay the old `/srv/data/aosp_panther17_workspace` commit history onto this base.

## Changed source files

Exactly seven source files are changed by the D2+D3 branding batch:

1. `packages/apps/SetupWizard2/res/values/strings.xml`
2. `packages/apps/SetupWizard2/res/layout/activity_welcome.xml`
3. `packages/apps/SetupWizard2/res/layout/activity_finish.xml`
4. `packages/apps/SetupWizard2/res/drawable-nodpi/sableos_icon.png` (new)
5. `packages/apps/Settings/res/values/strings_app_exploit_protection.xml`
6. `packages/apps/Settings/res/values/strings_ext.xml`
7. `frameworks/base/core/res/assets/images/android-logo-mask.png`

The exact binary assets are stored in `assets/`. `apply_sable_branding.py` applies and verifies the text changes and assets against exact upstream repository revisions.

The patch deliberately keeps GrapheneOS internal package/API identifiers and truthful provider/service ownership strings stable. It does not globally replace `GrapheneOS`, does not rename `app.grapheneos.setupwizard`, does not change the OEM unlock URL, does not add a `bootanimation.zip`, and does not modify `BootAnimation.cpp` or `android-logo-shine.png`.

## Apply

From a SableOS checkout:

```bash
python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py --self-test

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace apply

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace verify
```

Expected final dirty scope:

```text
packages/apps/SetupWizard2:
 M res/layout/activity_finish.xml
 M res/layout/activity_welcome.xml
 M res/values/strings.xml
?? res/drawable-nodpi/sableos_icon.png

packages/apps/Settings:
 M res/values/strings_app_exploit_protection.xml
 M res/values/strings_ext.xml

frameworks/base:
 M core/res/assets/images/android-logo-mask.png
```

See `BASELINE.lock` for exact source heads and validated artifact hashes and `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` for the complete build procedure.
