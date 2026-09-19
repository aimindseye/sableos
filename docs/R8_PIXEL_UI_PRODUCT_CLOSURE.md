# R8 Pixel UI Product Closure

Status: **active / final source-bound app refreeze, module compile, full build and physical acceptance pending**

Date: 2026-09-19


Current execution evidence:

```text
R8_STANDALONE_RUST_QUALIFICATION=PASS
R8_STANDALONE_ANDROID_QUALIFICATION=PASS
R8_READER_QUALIFICATION=PASS
R8_PRE_PR53_SEVEN_APK_FREEZE=PASS_HISTORICAL_EVIDENCE
R8_FINAL_MEDIA_PREVIEW_CLEANUP=PENDING_PR53_MERGE
R8_FINAL_SOURCE_BOUND_SEVEN_APK_FREEZE=PENDING
R8_FINAL_UI_PREPARE=PASS_AT_PRE_PR53_SOURCE
R8_FINAL_UI_PRODUCT_COMPOSITION=PASS_AT_PRE_PR53_SOURCE
R8_UI_MODULE_BUILD=PENDING_RERUN_AFTER_PR53_REFREEZE_RESTAGE
PANTHER_FINAL_UI_BUILD=PENDING
PANTHER_FINAL_UI_PHYSICAL_ACCEPTANCE=PENDING
```

The previously frozen seven-APK bundle at `/srv/data/sable-build/artifacts/panther/r8-final-app-bundle/20260919_113505` remains valid historical qualification evidence, but it is not the final R8 bundle after removal of the obsolete Media UI-C1A preview source. PR #53 adds an exact SableOS source-commit identity to new bundles; the final bundle must be regenerated from the merged PR #53 source, restaged, and pass product composition again before the corrected module gate.

This document is the execution authority for completing the current Pixel 7 / Panther UI refresh before the next full Panther build.

The governing rule is:

> A successful standalone Gradle/Compose build, emulator review, incremental platform compile, or Panther target-files build does not prove that the intended UI set is present in the product image.

The next Panther build is blocked until every required R8 application/system surface below is implemented, qualified, integrated into the Panther product graph, and proven by generated-artifact inspection.

## Why this gate exists

The 2026-09-19 sandbox-qualified Panther build and preserved-data flash both succeeded, but physical review showed that the flashed image still contained an older SableStart presentation and GrapheneOS/AOSP `ExactCalculator` rather than the completed standalone Sable Calculator.

The build/deployment pipeline is therefore considered proven for development use, while that image is classified as:

```text
R8_SANDBOX_QUALIFICATION_BUILD=PASS
R8_PANTHER_FLASH_AND_BOOT=PASS
R8_PRESERVED_DATA=PASS
R8_FINAL_UI_PRODUCT_COMPOSITION=FAIL
R8_FINAL_UI_RELEASE_CANDIDATE=NO
```

The sandbox-qualified target-files used for that diagnostic flash was:

```text
sha256=b5c9d9804db8ac3173f2b17c3c95dd02925880b001b7ef9ead1d7b5388bc5cbd
```

It remains useful build/flash evidence but must not be reused as the final R8 UI candidate.

## Required closure matrix

### R8-A — shared design and appearance

Current status: **SOURCE/PRODUCT COMPOSITION PASS / PHYSICAL ACCESSIBILITY ACCEPTANCE PENDING**

Already implemented:

- shared Sable typography, spacing, geometry and component primitives;
- semantic light and dark color roles;
- stable appearance values for `FollowSystem`, `Light` and `Dark`;
- bounded accent presets: Sable Blue, Green, Purple, Orange and Slate;
- minimum 48dp touch-target contract;
- safe-drawing/IME helpers used by standalone first-party apps.

Required before closure:

- Follow system must be the normal default unless a surface has an explicit reviewed exception;
- a user-facing appearance control must expose Follow system / Light / Dark;
- a bounded accent selector must expose only the approved preset set;
- Reset must restore Follow system + Sable Blue and clear local appearance overrides;
- SableStart must consume the shared semantic theme/appearance contract rather than owning an unrelated hard-coded dark palette;
- first-party apps must consume shared semantic roles instead of independent local palettes except for bounded content-specific color (for example game values or album art);
- accessibility review must cover contrast, font scaling, touch targets, selected/disabled state, content descriptions/focus order and non-color state cues.

Closure marker:

```text
R8_A_SHARED_DESIGN=PASS
```

### UI-A / SableStart — production Metro HOME

Current status: **PANTHER PRODUCT INTEGRATION PASS / PHYSICAL ACCEPTANCE PENDING**

Merged implementation includes:

- production Metro HOME surface;
- time-aware greeting;
- installed-app-aware featured tiles;
- All Apps as a secondary transition;
- application search;
- app context actions;
- local pinned state;
- session-only recent state;
- local Photos/Music/Calendar live surface with explicit permission handling;
- Settings/app-info routing;
- shared production/Android Studio preview surface.

Required before closure:

- canonical Panther workspace must contain the current merged `SableStartScreen` production source;
- HOME activity must render the production Metro surface;
- obsolete list-only HOME must not remain the packaged production path;
- launcher fallback/rollback remains available during development;
- appearance contract from R8-A must be applied.

Closure marker:

```text
R8_START_PRODUCT_INTEGRATION=PASS
```

### R8-B — Calculator + Convert

Current status: **STANDALONE + PANTHER PRODUCT INTEGRATION PASS / PHYSICAL ACCEPTANCE PENDING**

Already implemented:

- one Sable Calculator shell;
- Basic, Scientific and Convert modes;
- touch-first keypad;
- Rust-backed exact arithmetic/scientific paths;
- Converter integrated as a Calculator mode;
- Pixel 7 emulator visual review.

Required before closure:

- package `org.sableos.calculator` integrated into Panther;
- legacy `ExactCalculator` removed from the intended product/default application set or otherwise explicitly retained as a non-conflicting fallback;
- Calculator APK identity sealed in the product image;
- physical Pixel functional/visual acceptance after final flash.

Closure marker:

```text
R8_B_CALCULATOR_CONVERT=PASS
```

### R8-C — Sudoku, Minesweeper and 2048

Current status: **STANDALONE + PANTHER PRODUCT INTEGRATION PASS / PHYSICAL ACCEPTANCE PENDING**

Already implemented:

- three separate launcher APK identities;
- `org.sableos.sudoku`;
- `org.sableos.minesweeper`;
- `org.sableos.game2048`;
- shared qualified Rust/JNI domain boundary;
- professional touch-first game surfaces;
- Pixel 7 emulator visual review.

Required before closure:

- all three APKs integrated into Panther;
- exact package/artifact identities sealed;
- launcher presentation verified through SableStart;
- physical Pixel smoke/visual acceptance.

Closure marker:

```text
R8_C_GAMES=PASS
```

### R8-D — Reader publication path

Current status: **COMPOSED/QUALIFIED + PANTHER PRODUCT INTEGRATION PASS / PHYSICAL REVIEW PENDING**

Already implemented:

- one Sable Reader product identity;
- pinned Vaachak Mobile / Readium publication path;
- EPUB/library/progress/bookmarks/highlights/search/TOC retained from the pinned publication engine;
- Sable flavor and shared visual language;
- separate E-ink compatibility mode retained;
- standalone Reader CI and static/policy gates.

Required before closure:

- current composed Reader APK frozen and integrated into Panther;
- publication-path visual/runtime review on Pixel;
- open/read/navigation/progress/bookmark/search smoke coverage;
- exact upstream source identities recorded in the product-integration evidence.

Closure marker:

```text
R8_D_READER_PUBLICATION=PASS
```

### R8-D2 — Reader text/accessibility capability

Current status: **SOURCE/PRODUCT STAGED PASS / PHYSICAL OCR ACCEPTANCE PENDING**

Already implemented in the composed Sable Reader:

- bounded local TXT ingestion;
- `ACTION_VIEW` for `text/plain`;
- `ACTION_SEND`;
- `ACTION_PROCESS_TEXT`;
- local Android TTS;
- one launcher-visible Reader identity;
- no mandatory INTERNET permission in the composed Sable flavor.

Completed in the current composed Sable Reader:

- user-directed camera and gallery OCR are composed;
- bundled ML Kit Latin and Devanagari recognizers are qualified by the Reader build/policy gates;
- camera permission is requested only for the optional camera OCR flow;
- ordinary TXT/EPUB/TTS and gallery OCR remain camera-independent;
- the Sable flavor removes INTERNET and has no network OCR fallback;
- translation/model-download behavior remains deliberately excluded from R8.

R8-D2 physical closure still requires on-device OCR/accessibility acceptance, but does **not** require translation.

Required OCR gate:

- user-directed camera and gallery image sources;
- optional camera permission requested only for camera OCR;
- plain TXT/TTS use must remain camera-independent;
- Latin and Devanagari recognition paths;
- explicit offline/model-availability behavior;
- no silent model download/network fallback;
- failure/unsupported-model state surfaced truthfully;
- accessibility and physical Pixel validation.

Closure marker:

```text
R8_D2_READER_TEXT_ACCESSIBILITY_OCR=PASS
```

### R8-E — Media

Current status: **STANDALONE + PANTHER PRODUCT INTEGRATION PASS / PHYSICAL ACCEPTANCE PENDING**

Already implemented:

- local Music collection;
- Android document picker and recursive SAF folder import;
- local metadata extraction;
- Media3 playback/session ownership;
- queue / previous / play-pause / next / stop / seek;
- Up Next editing;
- playlists and local favorites;
- Internet Radio with explicit locally stored HTTP(S) stream presets;
- radio favorites and station management;
- truthful LIVE state;
- configurable Media start screen and local settings;
- Pixel 7 emulator functional/visual review.

Required before closure:

- Sable Media APK integrated into Panther;
- exact artifact/package identity sealed;
- Android Media3/system media integration validated on physical Pixel;
- local playback, queue, folder import and radio physical smoke test.

Closure marker:

```text
R8_E_MEDIA=PASS
```

### R8-F — Sable Hub / central messaging baseline

Current status: **SOURCE/PRODUCT INTEGRATION PASS / PHYSICAL ACCEPTANCE PENDING**

This promotes the previously accepted Sable Hub communication model into the first usable R8 product gate.

Required product identity:

```text
user-visible: Sable Messages
architecture: Sable Hub
package: org.sableos.hub
```

Required before closure:

- one Sable communication surface with ALL / MESSAGES / PEOPLE / SERVICES;
- SMS conversation presentation over Android Telephony provider data;
- SMS text compose/send through Android telephony APIs;
- ContactsProvider identity/display integration;
- retain the proven underlying Android messaging transport for MMS/RCS until Sable owns those responsibilities completely;
- do not become the default SMS handler until full default-handler SMS/MMS responsibilities are qualified;
- isolated web capability capsules for WhatsApp, Instagram, Facebook/Messenger and LinkedIn where a suitable consumer API is unavailable;
- provider capability classification remains truthful: NATIVE_DATA / ANDROID_NOTIFICATION / SUPPORTED_API / WEB / UNAVAILABLE;
- no private third-party database/protocol scraping;
- no claim that WEB capability is a native unified inbox;
- Start Messages tile routes into Sable Hub;
- shared R8-A visual/accessibility contract;
- interaction semantics are capability-driven so Titan 2 can use the same app with keyboard-first presentation later.

Closure marker:

```text
R8_F_SABLE_HUB_MESSAGES=PASS
```

Tracking: issue #47.

## System surfaces

The final R8 UI build also requires closure of the already-implemented platform/system work.

### UI4 — SystemUI

Source/incremental-build status:

- Quick Settings visual geometry implemented;
- notification shade geometry implemented;
- SystemUI media geometry implemented;
- cumulative fail-closed source qualification passed;
- SystemUI incremental compile passed.

Required final physical acceptance:

- compact and expanded Quick Settings;
- active/inactive tile state;
- brightness/volume placement;
- notifications/grouping/actions;
- SystemUI media controls and output routing;
- privacy indicators;
- accessibility/state descriptions;
- gestures and motion.

Marker:

```text
R8_UI4_SYSTEMUI=PASS
```

### UI5A/UI5B — Settings + Application Security & Privacy

Source/incremental-build status:

- Sable Settings home;
- Applications moved into privacy/security grouping;
- sensitive effective-access summary;
- read-only Application Security & Privacy evidence;
- identity/signing/install source;
- permission/AppOps evidence;
- components/exported surface inventory;
- special-access declarations;
- native-library inspection;
- INTERNET/battery/stopped state;
- explicit UNKNOWN for unsupported evidence;
- incremental Settings builds passed.

Required final physical acceptance:

- Settings home;
- Applications list;
- accurate sensitive-access summaries;
- Application Security & Privacy details;
- navigation to Android controls;
- no fabricated risk score or unsupported inference.

Marker:

```text
R8_UI5_SETTINGS=PASS
```

### UI5C/UI6 — SetupWizard, About and Keyguard

Source/incremental-build status:

- Sable SetupWizard welcome/finish;
- Sable branding;
- About SableOS with real build/device properties;
- Keyguard visual refresh;
- live clock/date placement;
- swipe-up affordance;
- authentication/redaction/privacy behavior preservation checks;
- combined `SetupWizard2 Settings SystemUI` incremental compile passed.

Required final physical acceptance:

- SetupWizard surfaces where safely reachable;
- About SableOS;
- lockscreen/Keyguard;
- PIN/password/biometric authentication;
- emergency-call path preserved;
- notification redaction;
- privacy indicators;
- accessibility/motion.

Marker:

```text
R8_UI5C_UI6_SYSTEM_SURFACES=PASS
```

## Mandatory pre-build product composition gate

No new full Panther build may start until a generated-artifact/product-graph audit proves the intended package/source set.

At minimum:

```text
SableStart             PRESENT / CURRENT MERGED SOURCE
Sable Calculator       PRESENT
Sable Sudoku           PRESENT
Sable Minesweeper      PRESENT
Sable 2048             PRESENT
Sable Media            PRESENT
Sable Reader           PRESENT
Sable Hub / Messages   PRESENT

ExactCalculator         ABSENT_AS_PRODUCT_REPLACEMENT
legacy list-only Start  ABSENT_AS_PRODUCTION_HOME

SystemUI UI4           CURRENT
Settings UI5A/UI5B     CURRENT
SetupWizard UI5C       CURRENT
Keyguard UI6           CURRENT
```

The gate must bind:

- canonical source commit/blob or applicator identity;
- exact APK package name;
- exact built APK hash;
- expected install partition/path;
- target-files membership;
- intended launcher/default role;
- absence or intentional retention of replaced legacy packages.

Required marker:

```text
R8_FINAL_UI_PRODUCT_COMPOSITION=PASS
```

Only then is the final sandboxed Panther target-files build authorized.

## Final Panther sequence

```text
R8-A appearance/accessibility closure
    -> final SableStart Metro HOME reconciliation
    -> R8-D2 OCR composition/qualification
    -> freeze Calculator/Games/Reader/Media artifacts
    -> R8-F Sable Hub / Messages implementation and qualification
    -> Panther product integration for all R8 apps
    -> verify UI4/UI5/UI6 source identities
    -> generated product-composition gate
    -> targeted/incremental compile gates
    -> one fresh sandbox-qualified Panther target-files build
    -> exact artifact/image audit
    -> preserved-data Pixel flash
    -> full physical UI/runtime acceptance
    -> Panther final UI closure
```

Do not run a full Panther build merely to discover missing application integration.

## Titan 2 handoff

Titan 2 is expected to become physically available on 2026-09-19.

Read-only T0 qualification may begin immediately after the device arrives:

- exact model/build identity;
- stock Android/security patch;
- Treble/VINTF/VNDK;
- partition/A-B/dynamic-super topology;
- bootloader state/unlock behavior;
- stock recovery/restore artifacts;
- kernel/module identity;
- vendor/ODM/HAL inventory;
- modem/IMS/firmware inventory;
- physical keyboard/keylayout/input devices;
- display geometry/density/rotation;
- pointer/trackpad behavior where exposed.

T0 does not require Panther final UI closure because it is observational.

Titan 2 GSI mutation/flash work remains blocked until:

```text
R8_FINAL_UI_PRODUCT_COMPOSITION=PASS
PANTHER_FINAL_UI_BUILD=PASS
PANTHER_FINAL_UI_PHYSICAL_ACCEPTANCE=PASS
```

The purpose is to carry the same semantic UI/application stack to Titan 2 and learn from square/QWERTY behavior, not to fork a separate Titan UI.

## Final closure markers

The Pixel UI milestone is complete only when:

```text
R8_A_SHARED_DESIGN=PASS
R8_START_PRODUCT_INTEGRATION=PASS
R8_B_CALCULATOR_CONVERT=PASS
R8_C_GAMES=PASS
R8_D_READER_PUBLICATION=PASS
R8_D2_READER_TEXT_ACCESSIBILITY_OCR=PASS
R8_E_MEDIA=PASS
R8_F_SABLE_HUB_MESSAGES=PASS
R8_UI4_SYSTEMUI=PASS
R8_UI5_SETTINGS=PASS
R8_UI5C_UI6_SYSTEM_SURFACES=PASS
R8_FINAL_UI_PRODUCT_COMPOSITION=PASS
PANTHER_FINAL_UI_BUILD=PASS
PANTHER_FINAL_UI_PHYSICAL_ACCEPTANCE=PASS
```

Current operational state:

```text
R8_FINAL_UI_PRODUCT_COMPOSITION=PASS_PRE_PR53_EVIDENCE
R8_FINAL_SOURCE_BOUND_SEVEN_APK_FREEZE=PENDING
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO_PENDING_REFREEZE_RESTAGE_AND_CORRECTED_MODULE_GATE
```

After the corrected combined module compile gate passes, the one final sandbox-qualified Panther target-files build is authorized.
