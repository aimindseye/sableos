# N1B Stage A fast-lane module matrix

Status: **real module inventory for combined Stage A app builds**

This document records the app modules that can be built from the current
`apps/r8/android` Gradle root and separates them from modules that must remain
source-binding or future-owner tasks.

```text
N1B_STAGE_A_FAST_LANE_MODULE_MATRIX=YES
N1B_STAGE_A_MODULE_INVENTORY_SOURCE=apps/r8/android/settings.gradle.kts
N1B_STAGE_A_EXACT_BUILD_ROOT=apps/r8/android
```

## Buildable Gradle modules in the current app root

```text
MODULE_design=BUILD
MODULE_calculator=BUILD
MODULE_convert=BUILD_LEGACY_UNTIL_REMOVED
MODULE_games=BUILD
MODULE_media=BUILD
MODULE_hub=BUILD
MODULE_sablestart_presentation_check=BUILD
MODULE_sablestart_visual_review=BUILD
MODULE_weather=BUILD
MODULE_calendar=BUILD
```

## Required exact app build commands

The Stage A fast-lane driver builds module tasks one module at a time so the
first failing module can be classified without hiding later failures.

```text
cd apps/r8/android

./gradlew :design:assembleDebug
./gradlew :calculator:assembleDebug
./gradlew :convert:assembleDebug
./gradlew :games:assembleDebug
./gradlew :media:assembleDebug
./gradlew :hub:assembleDebug
./gradlew :sablestart-presentation-check:assembleDebug
./gradlew :sablestart-visual-review:assembleDebug
./gradlew :weather:assembleDebug
./gradlew :calendar:assembleDebug
```

Where Kotlin/lint tasks are available, implementation PRs may add narrower
module checks such as:

```text
./gradlew :hub:compileDebugKotlin
./gradlew :hub:lintDebug
```

The fast-lane driver does not assume every module has every task beyond the
common app/library debug assemble path.

## Source-binding tasks, not current app modules

These are required N1B surfaces, but they are not currently proven as modules in
`apps/r8/android/settings.gradle.kts` and must not be faked in the first
fast-lane build sweep.

```text
SETUPWIZARD2_SOURCE_BINDING=SOURCE_BIND_ONLY
TITAN_SETUP_EXTENSION=OWNER_REQUIRED
LAUNCHER3_SABLESTART_PLATFORM_INTEGRATION=OWNER_REQUIRED
SYSTEMUI_QS_NOTIFICATION_SHADE=OWNER_REQUIRED
LOCKSCREEN_SECURE_ENTRY=OWNER_REQUIRED
READER_TEXTREADER_SOURCE_IMPORT=OWNER_REQUIRED
SABLE_CAMERA=OWNER_REQUIRED
PHONE_CONTACTS_PRODUCT_COMPOSITION=OWNER_REQUIRED
BROWSER_WEBVIEW_IDENTITY=PRODUCT_GATE_REQUIRED
MESSAGES_DUPLICATE_EXPOSURE=PRODUCT_GATE_REQUIRED
MAIL_PRODUCT_COMPOSITION=PRODUCT_GATE_REQUIRED
```

## Stage A acceptance markers

```text
N1B_FAST_LANE_APP_BUILD_ROOT_FOUND=PASS
N1B_FAST_LANE_GRADLE_SETTINGS_FOUND=PASS
N1B_FAST_LANE_REAL_MODULES_ENUMERATED=PASS
N1B_FAST_LANE_NO_FAKE_SETUPWIZARD_MODULE=PASS
N1B_FAST_LANE_NO_IMAGE_BUILD=PASS
N1B_FAST_LANE_NO_DEVICE_CONTACT=PASS
```

## Promotion boundary

```text
N1B_STAGE_A_CODE_BUILD=PASS_REQUIRED_BEFORE_STAGE_B
N1B_STAGE_B_PHYSICAL_UX=NOT_RUN_BY_FAST_LANE_DRIVER
N1B_STAGE_C_FULL_CI=NOT_RUN_BY_FAST_LANE_DRIVER
N1B_STAGE_D_IMAGE_BUILD=BLOCKED
```
