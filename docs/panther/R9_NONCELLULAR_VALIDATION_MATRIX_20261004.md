# R9 Panther non-cellular validation matrix

Status: **operator validation plan — no Titan telephony dependency**  
Date: **2026-10-04**

This matrix is the physical/common-product validation target for the Panther R9
release candidate built while Titan 2 cellular work is held.

## Identity prerequisites

Every session records:

~~~text
SABLEOS_SOURCE_COMMIT
TARGET_FILES_SHA256
FLASHED_BUILD_FINGERPRINT
SLOT
DEVICE_SERIAL_SHA256
UTC_START
PRESERVED_DATA_STATE
~~~

Do not use a Panther result as Titan keyboard or cellular evidence.

## Pre-device gates

The same source commit must first pass:

~~~text
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 qualify physical-ux
bash build/sable.sh panther R9 build --tmux
~~~

The first two are mandatory before the full release-candidate build. A flash is
separately authorized only after the registered artifact is reviewed.

## Issue matrix

### #120 — Search / Peek / App security info / Back

Reproduce:

~~~text
HOME
 -> Search
 -> Peek
 -> Search
 -> Peek
 -> App security/privacy info
 -> Back gesture
~~~

Repeat at least five times without rebooting. Record which surface receives Back,
whether predictive-back animation appears, whether Search/Peek overlay state
restores correctly, whether subsequent Back still works, and whether keyboard
Back/Escape and touch gesture agree where applicable.

PASS requires no trap, stale overlay or broken subsequent Back behavior.

### #121 — Contacts/Phone duplicate alphabet rails

Test both Contacts directly and Phone -> Contacts at normal font scale and one
larger accessibility font scale. Record screenshots and whether the remaining
alphabet/fast-scroll affordance actually navigates.

PASS requires exactly one intentional index/rail treatment and consistent
behavior between both entry paths.

### #122 — Media portrait navigation and mini-player

Exercise Music, Podcasts, Radio, Now Playing, Settings, active mini-player and
inactive mini-player. Record top-navigation clipping, mini-player state,
podcast/radio trailing-action spacing, font-scale behavior and resume behavior.

PASS requires no accidental label clipping, no meaningless solid mini-player
bar, and usable touch targets.

### #82 — duplicate visible Messages experience

Record launcher activities/packages for every visible Messages entry and classify
each package as PRIMARY_PRODUCT_UI, TRANSPORT_PROVIDER, FALLBACK_ONLY or
ACCIDENTAL_VISIBLE_PRODUCT.

PASS requires one intentional visible Messages product while retaining required
SMS/MMS transport/provider behavior. No backend package may be removed merely
to hide a launcher icon.

### #84 — first-run crash evidence

Capture historical evidence before any command clears logs:

~~~text
adb shell dumpsys dropbox
adb shell dumpsys activity exit-info
adb logcat -b crash -d
tombstone inventory where shell access permits
~~~

Then run repeated boot -> unlock -> HOME -> Recents -> app-launch cycles.
PASS requires the original crash source to be identified/fixed or explicitly
ruled out and no Launcher crash in the bounded stress run.

Acceptance tooling must never erase pre-existing crash history before capture.

### #83 — first-party icons and launch performance

Audit Calculator, Sudoku, Minesweeper, 2048, Media, Reader, Hub/Messages, Mail,
Weather, Calendar and Text Reader when included. Record launcher icon, Settings
icon, Recents presentation, package identity, warm launch time, authorized cold
launch time and visible startup stall.

PASS requires approved adaptive identity and no generic/upstream placeholder.
Performance PASS requires measured evidence.

### #86 — All Apps granted privacy summary

Exercise zero, one and multiple high-signal grants, a permission change followed
by launcher model refresh, and a work/profile case where available.

PASS requires label-first presentation, human-readable groups, no package-name
leakage, correct user/profile state, truthful no-sensitive-grants state, and App
info remaining authoritative.

## Cross-cutting physical checks

Exercise Light, Dark, at least two Sable accents, normal and larger font, touch
navigation, Back, and rotation/resume where meaningful. Record branding leakage,
focus loss, contrast/accessibility regression, ANR/crash and stale state after
process recreation.

## Result format

~~~text
ISSUE=
SOURCE_COMMIT=
TARGET_FILES_SHA256=
RESULT=PASS|FAIL|BLOCKED
EVIDENCE_DIR=
OBSERVATION=
REGRESSION_FOUND=YES|NO
FOLLOWUP=
~~~

A source/static PASS must not substitute for required Panther physical evidence.

## Titan cellular firewall

This Panther validation must not modify or investigate Titan N1I, IMS, APN,
QNS, IWLAN, MTK/vendor telephony, Titan radio SELinux, Titan partitions or
Titan flash state.
