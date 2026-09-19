# UI5A production: Settings home + Applications list

Status: **production applicator ready for source qualification**

Base Settings repository:

```text
GrapheneOS/platform_packages_apps_Settings
71bd21cda07f4dfdcec2aabb16bc570be5bd8d35
```

UI5A intentionally modifies only `packages/apps/Settings` and assumes the existing
Sable D2+D3 branding delta is already applied.

## User-visible behavior

### Settings home

UI5A adds the approved Sable hierarchy without replacing Android Settings:

- SableOS / settings header above the existing search surface;
- Applications is moved into the privacy/security group;
- Applications opens the real installed-app list directly;
- the Applications summary is derived from the current user's installed-app count;
- all existing Settings destinations and Android enforcement remain intact.

### Applications list

The normal main application list continues to use Android's real
`ApplicationsState` labels and icons.

The secondary line changes from storage size to a concise summary of **effective
sensitive Android permission grants** such as:

```text
Camera · Microphone · Photos & videos
Location · Contacts · +2 more
No sensitive permissions granted
```

This summary is deliberately narrow. UI5A does **not** claim runtime use,
tracker execution, network destinations, exported-component risk, AppOps state,
or security history. Those belong to UI5B and must carry the evidence classes
defined in `APPLICATION_SECURITY_PRIVACY_TRANSPARENCY.md`.

## Source delta

Modified:

```text
res/layout/settings_homepage_container.xml
res/xml/top_level_settings.xml
res/xml/top_level_settings_expressive.xml
res/xml/top_level_settings_expressive_desktop.xml
src/com/android/settings/applications/manageapplications/ManageApplications.java
```

Added:

```text
res/layout/sable_settings_home_header.xml
res/values/colors_sable_ui5a.xml
res/values/strings_sable_ui5a.xml
src/com/android/settings/applications/TopLevelApplicationsPreferenceController.java
src/com/android/settings/applications/manageapplications/SableSensitiveAccessSummary.java
```

The applicator verifies the exact post-branding dirty scope before mutation and
the exact UI5A dirty scope afterward.

## Apply

First run the repository-only self-test:

```bash
python3 patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py --self-test
```

Then on the pinned Panther Android workspace:

```bash
python3 patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py \
  --source /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300 apply

python3 patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py \
  --source /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300 verify
```

## Build gate

UI5A requires only an incremental Settings build:

```bash
cd /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300
source build/envsetup.sh
lunch sable_panther-userdebug

OUT_DIR=out_sable_ui_preview m -j8 Settings
```

Do not clean or clobber the existing output tree.

The full Panther build remains deferred until UI5B, UI5C and UI6 are integrated.
