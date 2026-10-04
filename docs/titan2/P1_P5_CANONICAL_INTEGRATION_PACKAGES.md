# P1-P5 canonical integration packages

Status: **replacement-developer handoff / source frozen / canonical admission pending**  
Date: **2026-10-04**

This document turns the completed `aimindseye/titan2-temp` P1-P5 source work into
canonical integration packages for replacement developers.

It does not authorize Titan 2 cellular mutation, a Titan flash, production signing
or release.

## Source authorities

```text
SABLEOS_MAIN_AT_HANDOFF=708c49731fd361b20f7315ec914e09f70c3eb00d
TITAN2_TEMP_MAIN=7570470d1c5a27ef94ed4751f5ccb91af41761fe

P1_PR=19  source_head=97cec2ceb9b86699b6de5b36b6012aaa793bec2c
P2_PR=20  source_head=912d0cb8802504f06a1c77ada630c3c834a68715
P3_PR=21  source_head=832106e2e590d7aba3289f464b220836ce1c56f2
P4_PR=22  source_head=7dcf17a2b70ea42553c19f1c2678bd3ac95c51c4
P5E_PR=27 qualified_feature_baseline=4089c1274a9e4a402a2c617cc00a7c166112f195
P5F_ORIGINAL_PR=28 runtime_readiness_head=e8a5ddd374a0d78ca175b2137cf73707150ca28a
P5F_QUALIFIED_PR=32 merged_head=2f232a1c2883ab9b88f89a08d859a5329b03c5da
```

P1-P4 are merged in `titan2-temp/main`. P5A-P5E are merged. P5F operator
qualification is complete and merged via PR #32; physical runtime remains separate.

## Common admission rule

Every package follows:

```text
SOURCE_PROVENANCE
 -> SOURCE/STATIC_GATE
 -> ANDROID_COMPILE
 -> UNIT_TESTS
 -> LINT/DETEKT/KTLINT where configured
 -> MERGED_MANIFEST / PRIVILEGE AUDIT
 -> CANONICAL OWNER INTEGRATION
 -> REFERENCE_DEVICE_RUNTIME
 -> TARGET_DEVICE_RUNTIME
```

A Panther/common-product PASS is not a Titan keyboard PASS. A Titan keyboard
PASS is not a Titan cellular PASS.

No package in this document may mutate:

```text
IMS
APN
QNS
IWLAN
vendor telephony
radio capability policy
Titan SELinux telephony policy
```

while the N1I lane is held for BE2.

---

## P1 — Launcher3/QuickStep-hosted Sable Start

### Source

```text
source_repo=aimindseye/titan2-temp
source_path=reference/sable-start-type-to-find
source_head=97cec2ceb9b86699b6de5b36b6012aaa793bec2c
handoff_doc=docs/SABLE_START_KEYBOARD_FIRST_SOURCE.md
primary_ir=IR-002
```

The source is framework-free reference logic, not an Android module.

### Canonical owner

```text
HOME_OWNER=Launcher3QuickStep
CANONICAL_PRESENTATION=Sable Start hosted by Launcher3/QuickStep
STANDALONE_HOME_REINTRODUCTION=FORBIDDEN
```

The replacement developer must integrate the semantics into the existing
Launcher3/QuickStep Sable Start owner. They may port the Kotlin model, create a
small internal library, or reimplement the same state machine, but must not add a
second HOME package.

### Required behavior

- first printable key opens Search and preserves that character;
- deterministic visible focus;
- Up/Down/Left/Right and Tab traversal;
- Enter/numpad Enter/D-pad center activate;
- Space activates outside editors and remains text inside editors;
- Back/Escape moves one semantic level and is not consumed at root;
- `KEYCODE_MOVE_HOME/END` are local movement, never system HOME;
- `KEYCODE_HOME` remains system/framework-owned;
- PageUp/PageDown remain unconsumed unless a canonical paging UX is deliberately added;
- physical typing does not invoke the soft IME;
- touch remains complete;
- app shortcuts remain subordinate to editors/navigation.

### Canonical validation

```text
P1_CANONICAL_RUNTIME_INTEGRATION=PASS
P1_FIRST_CHARACTER_PRESERVED=PASS
P1_SYSTEM_HOME_NOT_APP_LOCAL_ROOT=PASS
P1_MOVE_HOME_MOVE_END_SPLIT=PASS
P1_DETERMINISTIC_FOCUS=PASS
P1_NO_STANDALONE_HOME=PASS
```

Panther can validate common Launcher behavior before Titan cellular is solved.
Titan keyboard physical delivery remains a later target-device check.

---

## P2 — Sable Keyboard provisioning / IR-005

### Source

```text
source_repo=aimindseye/titan2-temp
source_path=apps/titan2/platform/keyboard
source_head=912d0cb8802504f06a1c77ada630c3c834a68715
handoff_doc=docs/C3B_IR005_SABLE_IME_PROVISIONING_HANDOFF.md
component=org.sableos.titan2.keyboard/.android.SableImeService
primary_ir=IR-005
```

The canonical source tree already contains the keyboard module under
`apps/titan2/platform/keyboard`; this package is about first-boot/default
provisioning and canonical behavior, not a second keyboard implementation.

### Required policy

```text
FACTORY_DEFAULT=Sable Keyboard
FIRST_BOOT_ENABLED=YES
FIRST_BOOT_SELECTED=YES
DIRECT_BOOT_AWARE=YES
FACTORY_DEFAULT_ONLY=YES
USER_CHANGE_PRESERVED=YES
FORCE_SABLE_IME_AFTER_USER_SELECTION=NO
SOFTWARE_KEYBOARD_FALLBACK=YES
```

The canonical mechanism may use product configuration / SettingsProvider
defaults / an equivalent first-boot default path, but must not add an app-side
settings writer, boot-time reset loop, accessibility service, root helper or
periodic enforcement.

### Required Android qualification

- compile the real Android glue;
- verify application/service/settings activity direct-boot attributes;
- verify device-protected preferences;
- verify no new privilege;
- verify software keyboard fallback;
- verify default provisioning is one-shot;
- verify a later user-selected third-party IME remains selected.

### Runtime boundary

Lockscreen/Setup pre-unlock typing is target-device runtime evidence, but the
source/Android provisioning path can be completed before Titan cellular.

---

## P3 — SetupWizard2 keyboard-first integration / IR-014

### Source

```text
source_repo=aimindseye/titan2-temp
source_path=reference/sable-setup-keyboard-first-flow
source_head=832106e2e590d7aba3289f464b220836ce1c56f2
handoff_doc=docs/SABLE_SETUP_KEYBOARD_FIRST_FLOW_SPEC.md
primary_ir=IR-014
related_ir=IR-003,IR-005
canonical_owner=GrapheneOS SetupWizard2
```

### Canonical rule

Keep `app.grapheneos.setupwizard` / SetupWizard2 as the setup owner. Do not
create a second Sable setup wizard. The existing Sable Setup app remains a
post-provisioning readiness helper.

### Required behavior

- keyboard focus on all first-boot controls;
- Wi-Fi and account editors remain normal Android editors;
- Tab/Shift+Tab never trap focus;
- MoveHome/MoveEnd move local focus only when an editor does not own them;
- system HOME is not intercepted;
- physical keyboard does not force soft IME;
- software IME is available when required;
- SIM/network page is always continuable;
- Setup completion never depends on cellular or IMS registration;
- square/compact layout scrolls focused controls into view;
- orientation changes preserve state/focus.

### Validation

Panther/Graphene SetupWizard2 compile and UI validation can proceed independently
of Titan telephony. Titan first-boot keyboard acceptance comes later.

---

## P4 — Weather user-managed cities / IR-015

### Source

```text
source_repo=aimindseye/titan2-temp
source_path=reference/sable-weather-cities
source_head=7dcf17a2b70ea42553c19f1c2678bd3ac95c51c4
handoff_doc=docs/SABLE_WEATHER_CITIES_SOURCE.md
canonical_target=aimindseye/sableos/apps/r8/android/weather
primary_ir=IR-015
```

### Canonical integration

Integrate the portable city model into canonical Weather, not a Titan fork.

Required:

- persist the complete city list and selected city;
- add/remove/select/reset;
- retain precise coordinates and timezone;
- no location permission requirement for manual entry;
- keep existing HTTPS/Open-Meteo transport;
- notify Start/Live when active city changes;
- **cache per city**.

The per-city cache rule is a release blocker for this package. Canonical Weather
currently must not display a previous city's cached forecast under a newly
selected city's name.

### Validation

- pure model/JVM tests;
- Android compile/lint/unit tests of canonical Weather;
- persistence restart test;
- offline cache-key test;
- Start/Live notification test;
- keyboard/touch city-management test;
- Panther physical test before Titan target validation.

No cellular dependency.

---

## P5 — Sable Reader v2 / IR-011

### Source

```text
source_repo=aimindseye/titan2-temp
source_path=apps/common/reader
qualified_feature_baseline=4089c1274a9e4a402a2c617cc00a7c166112f195
runtime_readiness_head=e8a5ddd374a0d78ca175b2137cf73707150ca28a
application_id=org.sableos.reader
handoff_doc=docs/P5F_READER_ADMISSION_HANDOFF.md
primary_ir=IR-011
```

P5A-P5E are merged. P5F source/JVM/Android qualification is complete; physical runtime remains pending.

### Product capability

P5 includes:

- EPUB;
- PDF;
- CBZ/image comics;
- manga/webtoon reading modes;
- local audiobooks;
- Media3 background playback;
- chapters/resume/speed/sleep timer/bookmarks;
- unified library;
- backup/restore;
- accessibility and privacy closure.

Text Reader remains separate.

### Security/permission contract

Effective Reader permissions are exactly:

```text
android.permission.FOREGROUND_SERVICE
android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK
android.permission.POST_NOTIFICATIONS
android.permission.WAKE_LOCK
```

Forbidden:

```text
INTERNET
ACCESS_NETWORK_STATE
CAMERA
```

No presigned APK, keystore or private signing material enters source.

### Canonical source-path decision

Preferred long-term source location is the P5 common tree:

```text
apps/common/reader
```

Before canonical import, audit the existing legacy
`aimindseye/sableos/apps/r8/android/reader` ownership. Do not keep two
independent Sable Reader implementations.

The integration change must explicitly choose one canonical source owner and
retire or convert the other into non-product historical/adaptation material.

### Admission prerequisite

Operator-qualified P5F evidence required before canonical import is now satisfied:

```text
P5F_STATIC_GATE=PASS
P5F_JVM_TESTS=PASS
P5F_DEVELOPER_ANDROID_COMPILE=PASS
P5F_LINT=PASS
P5F_ANDROID_UNIT_TESTS=PASS
P5F_MERGED_MANIFEST=PASS_PERMISSION_DELTA_EXACT
P5F_DEVICE_RUNTIME_VALIDATED=NO
```

Device runtime remains a separate stage.

---

## Replacement-developer execution order

```text
1. PR #28/#29 operator qualification — COMPLETE via #32/#34
2. exact evidence frozen
3. P1 canonical Launcher3 integration
4. P2 canonical IME first-boot provisioning
5. P3 SetupWizard2 keyboard integration
6. P4 Weather canonical city integration
7. P5 Reader canonical source-owner/import decision and admission
8. Panther common-product runtime qualification
9. Titan keyboard/runtime qualification after the cellular image lane is safe
```

P1-P4 may be divided among replacement developers, but each must remain a
separate source-bound integration change. Do not create another stacked
`titan2-temp` development train.

## Stop conditions

Stop and return for review if any package requires:

- new system/shared UID;
- new signature/privileged permission;
- a new HOME owner;
- a second SetupWizard;
- direct vendor device-node access;
- raw common-UI sysfs write;
- radio/IMS/APN/QNS/IWLAN/vendor-telephony change;
- Titan flash;
- production signing.

