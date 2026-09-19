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

`apply_sable_branding.py` applies and verifies the text changes and exact binary asset hashes against the validated upstream repository revisions.

The two binary source assets must be present under `assets/` with the exact names and hashes listed in `assets/SHA256SUMS`:

```text
sableos_setupwizard_icon.png
sableos_boot_fallback_mask_448x605.png
```

Run `sha256sum -c assets/SHA256SUMS` before applying the delta. The applicator independently verifies both hashes and refuses to mutate the Android source tree if either asset is missing or different.

The patch deliberately keeps GrapheneOS internal package/API identifiers and truthful provider/service ownership strings stable. It does not globally replace `GrapheneOS`, does not rename `app.grapheneos.setupwizard`, does not change the OEM unlock URL, does not add a `bootanimation.zip`, and does not modify `BootAnimation.cpp` or `android-logo-shine.png`.

## Apply

From a SableOS checkout:

```bash
cd patches/android-17-grapheneos-2026081300
sha256sum -c assets/SHA256SUMS
cd ../../

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

See `BASELINE.lock` for exact source heads and validated artifact hashes, `CHANGED_FILES.md` for the exact semantic delta, `assets/README.md` for binary-asset handling, and `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` for the complete build procedure.


## UI5A Settings + Applications

UI5A is a separate, fail-closed production applicator layered **after** the
validated D2+D3 branding delta. It remains pinned to the same Settings HEAD:

```text
packages/apps/Settings
71bd21cda07f4dfdcec2aabb16bc570be5bd8d35
```

It adds the approved Sable Settings-home header, moves Applications into the
privacy/security group, opens the real installed-app list directly, reports a
real current-user app count on the homepage, and replaces the normal app-list
size subtitle with a concise summary of effective sensitive permission grants.

Run:

```bash
python3 patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py --self-test

python3 patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py \
  --source /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300 apply
```

See `docs/UI5A_SETTINGS_APPLICATIONS.md` for the bounded source ledger and
incremental Settings build gate.
